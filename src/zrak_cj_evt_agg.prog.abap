REPORT zrak_cj_evt_agg.

*&---------------------------------------------------------------------*
*& Rolls one day of raw events into ZRAK_T_CJ_AGG. Schedule daily, after
*& midnight, in SM36.
*&
*& ROLE is an aggregate dimension. ROLEBP deliberately is NOT: a specific
*& partner is an individual, and individuals do not belong in a table that
*& is kept forever - that is what the 90 day raw table is for. ROLE is a
*& category and worth keeping, because "consultants complete 45% of trade
*& licence journeys and owners complete 80%" is a service design finding
*& and no other system at RAK Digital can produce it.
*&
*& Percentiles, not means only. One citizen who left a payment tab open
*& overnight moves a mean and tells you nothing; P95 is the number that
*& corresponds to somebody's actual bad morning.
*&
*& P_DATE means THE DATE TO AGGREGATE, and defaults to yesterday. It used
*& to mean "the day after the one you want", which is correct for a
*& nightly job and confusing for everyone running it by hand - including
*& the person who wrote it.
*&---------------------------------------------------------------------*

PARAMETERS p_date TYPE dats OBLIGATORY.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.

TYPES: BEGIN OF ty_pct,
         sysid      TYPE zrak_t_cj_evt-sysid,
         journey_id TYPE zrak_t_cj_evt-journey_id,
         step_no    TYPE zrak_t_cj_evt-step_no,
         evt_type   TYPE zrak_t_cj_evt-evt_type,
         langu      TYPE zrak_t_cj_evt-langu,
         channel    TYPE zrak_t_cj_evt-channel,
         role       TYPE zrak_t_cj_evt-role,
         p50        TYPE i,
         p95        TYPE i,
       END OF ty_pct.

INITIALIZATION.
* DEFAULT on PARAMETERS takes a literal or a constant, not an expression, so
* yesterday has to be set here.
  p_date = sy-datum - 1.

START-OF-SELECTION.

  DATA(lv_lo) = CONV timestampl( |{ p_date }000000| ).
  DATA(lv_hi) = CONV timestampl( |{ CONV dats( p_date + 1 ) }000000| ).

  SELECT sysid, journey_id, step_no, evt_type, langu, channel, role,
         COUNT( * )                     AS cnt,
         COUNT( DISTINCT sess_id )      AS sess_cnt,
         AVG( duration AS DEC( 11,0 ) ) AS dur_avg,
         MAX( duration )                AS dur_max
    FROM zrak_t_cj_evt
    WHERE tstamp >= @lv_lo AND tstamp < @lv_hi
    GROUP BY sysid, journey_id, step_no, evt_type, langu, channel, role
    INTO TABLE @DATA(lt_g).

  IF lt_g IS INITIAL.
    WRITE: / 'No events for', p_date.
    RETURN.
  ENDIF.

* One pass for the durations, not one SELECT per group. The previous version
* re-read the raw table inside the group loop, which is a full range scan per
* group - and adding ROLE multiplies the group count by the number of roles in
* play. At a million rows a day that is the difference between a job that
* finishes before the morning and one that does not.
  SELECT sysid, journey_id, step_no, evt_type, langu, channel, role, duration
    FROM zrak_t_cj_evt
    WHERE tstamp >= @lv_lo AND tstamp < @lv_hi
      AND duration > 0
    ORDER BY sysid, journey_id, step_no, evt_type, langu, channel, role, duration
    INTO TABLE @DATA(lt_dur).

  DATA lt_pct TYPE SORTED TABLE OF ty_pct
       WITH UNIQUE KEY sysid journey_id step_no evt_type langu channel role.

  LOOP AT lt_dur INTO DATA(ls_dur)
       GROUP BY ( sysid      = ls_dur-sysid
                  journey_id = ls_dur-journey_id
                  step_no    = ls_dur-step_no
                  evt_type   = ls_dur-evt_type
                  langu      = ls_dur-langu
                  channel    = ls_dur-channel
                  role       = ls_dur-role )
       REFERENCE INTO DATA(lr_grp).

    DATA lt_mem TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    CLEAR lt_mem.

    LOOP AT GROUP lr_grp INTO DATA(ls_mem).
      APPEND ls_mem-duration TO lt_mem.
    ENDLOOP.

    DATA(lv_n)  = lines( lt_mem ).
    DATA(lv_i5) = CONV i( lv_n / 2 ).
    DATA(lv_i9) = CONV i( lv_n * 95 / 100 ).
    IF lv_i5 < 1.
      lv_i5 = 1.
    ENDIF.
    IF lv_i9 < 1.
      lv_i9 = 1.
    ENDIF.

    INSERT VALUE ty_pct( sysid      = lr_grp->sysid
                         journey_id = lr_grp->journey_id
                         step_no    = lr_grp->step_no
                         evt_type   = lr_grp->evt_type
                         langu      = lr_grp->langu
                         channel    = lr_grp->channel
                         role       = lr_grp->role
                         p50        = lt_mem[ lv_i5 ]
                         p95        = lt_mem[ lv_i9 ] ) INTO TABLE lt_pct.
  ENDLOOP.

  DATA lt_agg TYPE STANDARD TABLE OF zrak_t_cj_agg WITH EMPTY KEY.

  LOOP AT lt_g INTO DATA(ls_g).

    DATA lv_p50 TYPE i.
    DATA lv_p95 TYPE i.
    CLEAR: lv_p50, lv_p95.

    READ TABLE lt_pct INTO DATA(ls_p)
         WITH TABLE KEY sysid      = ls_g-sysid
                        journey_id = ls_g-journey_id
                        step_no    = ls_g-step_no
                        evt_type   = ls_g-evt_type
                        langu      = ls_g-langu
                        channel    = ls_g-channel
                        role       = ls_g-role.
    IF sy-subrc = 0.
      lv_p50 = ls_p-p50.
      lv_p95 = ls_p-p95.
    ENDIF.

    APPEND VALUE zrak_t_cj_agg(
      agg_date   = p_date
      sysid      = ls_g-sysid
      journey_id = ls_g-journey_id
      step_no    = ls_g-step_no
      evt_type   = ls_g-evt_type
      langu      = ls_g-langu
      channel    = ls_g-channel
      role       = ls_g-role
      cnt        = ls_g-cnt
      sess_cnt   = ls_g-sess_cnt
      dur_avg    = ls_g-dur_avg
      dur_p50    = lv_p50
      dur_p95    = lv_p95
      dur_max    = ls_g-dur_max ) TO lt_agg.
  ENDLOOP.

  WRITE: / 'Date', p_date, '- rows', lines( lt_agg ).

  IF p_test = abap_true.
    WRITE: / 'Test mode - nothing written. Untick to commit.'.
    RETURN.
  ENDIF.

* Delete then insert, for the day being rebuilt only. Re-running a day must be
* safe and must not leave yesterday's row shape behind when a dimension is added
* - which is exactly what happens the first time this runs after ROLE.
  DELETE FROM zrak_t_cj_agg WHERE agg_date = @p_date.
  MODIFY zrak_t_cj_agg FROM TABLE @lt_agg.

  IF sy-subrc = 0.
    COMMIT WORK AND WAIT.
    WRITE: / 'Written.'.
  ELSE.
    ROLLBACK WORK.
    WRITE: / 'Failed - nothing committed.'.
  ENDIF.
