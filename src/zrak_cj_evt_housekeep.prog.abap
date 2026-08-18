REPORT zrak_cj_evt_housekeep.

* Deletes raw events past the retention window. The aggregate is permanent;
* the raw table is not.
*
* Retention is a compliance requirement here, not housekeeping: ZRAK_T_CJ_EVT
* holds BP numbers, which are personal data. Do not extend the window without
* asking whoever owns data protection.
*
* Deletes in blocks with a commit between them. One DELETE across 30 million
* rows fills the rollback segment and locks the table against the very
* citizens it is measuring.

PARAMETERS p_days TYPE i DEFAULT 90.
PARAMETERS p_block TYPE i DEFAULT 50000.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.

START-OF-SELECTION.

  DATA(lv_cut) = CONV timestampl( |{ CONV dats( sy-datum - p_days ) }000000| ).

  SELECT COUNT( * ) FROM zrak_t_cj_evt
    WHERE tstamp < @lv_cut
    INTO @DATA(lv_n).

  WRITE: / 'Retention', p_days, 'days - candidate rows', lv_n.

  IF lv_n = 0 OR p_test = abap_true.
    IF p_test = abap_true.
      WRITE: / 'Test mode - nothing deleted.'.
    ENDIF.
    RETURN.
  ENDIF.

  DATA lv_done TYPE i.

  DO.
    SELECT evt_id FROM zrak_t_cj_evt
      WHERE tstamp < @lv_cut
      ORDER BY evt_id
      INTO TABLE @DATA(lt_id)
      UP TO @p_block ROWS.

    IF lt_id IS INITIAL.
      EXIT.
    ENDIF.

    DELETE FROM zrak_t_cj_evt WHERE evt_id IN ( SELECT evt_id FROM @lt_id AS t ).
    COMMIT WORK AND WAIT.

    lv_done = lv_done + lines( lt_id ).
  ENDDO.

  WRITE: / 'Deleted', lv_done.
