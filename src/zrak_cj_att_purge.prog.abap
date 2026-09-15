REPORT zrak_cj_att_purge.

*&---------------------------------------------------------------------*
*& CJS RETENTION - abandoned drafts and the files staged against them
*&
*& ZCL_RAK_CJ_ATT_STORE has carried the line "HOUSEKEEPING: schedule
*& ZRAK_CJ_ATT_PURGE daily" since it was written, and this report did not
*& exist. So nothing has ever purged ZRAK_CJ_ATTX: every file uploaded to a
*& journey that was then abandoned is still there, in full, with its
*& base64 content and the uploader's user name.
*&
*& That is the leak this closes. It is not only a table growing - a staged
*& Emirates ID scan that nobody submitted is a copy of someone's identity
*& document held for no reason and against no case.
*&
*& WHAT IT READS
*&
*& Per journey, ZIF_RAK_JOURNEY_LOGIC~RETENTION( ) - the handler's own
*& policy, in days, separately for drafts and for files. The handler is
*& instantiated with NO context: IO_CTX is omitted and arrives unbound,
*& because there is no session here, no model and no user. A handler that
*& reads it dumps, and dumps in a background job where nobody is looking.
*&
*& WHAT IT CANNOT DO YET, AND WHY
*&
*& ZRAK_CJ_ATTX is GUID / UNAME / FILE_NAME / MIMETYPE / ERDAT / CONTENT.
*& There is no journey column, so a file cannot be traced back to the
*& journey that staged it, so per-journey ATTACH_DAYS cannot be honoured.
*& This report therefore purges files on ONE age, from P_ADAYS, and prints
*& what each journey asked for so the difference is visible rather than
*& quietly ignored. Add JOURNEY_ID to ZRAK_CJ_ATTX and this becomes a
*& per-journey purge without changing the policy hook.
*&
*& Drafts are the other half and are not purged here at all: there is no
*& CJS-side draft store to purge. DRAFT_MODE is DELEGATE for every journey
*& that has a backend, which means the backend holds the draft and its
*& retention is the backend's business. The draft columns of RETENTION( )
*& are read and reported so the policy is recorded, and will be acted on
*& when a NATIVE store exists.
*&
*& TEST RUN IS THE DEFAULT. A report that deletes should never do so
*& because someone pressed F8 to see what it did.
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_adays TYPE i DEFAULT 7 OBLIGATORY.
*   FILED ONLY, AND ON BY DEFAULT. A filed file has a second copy on the case,
*   so removing it loses nothing. An UNFILED one exists nowhere else - it was
*   uploaded to a journey that never posted, which is either abandoned or a
*   draft somebody means to come back to, and age cannot tell those apart.
*   Untick only to clear genuinely abandoned staging, and pick an age longer
*   than any realistic draft-resume window when you do.
PARAMETERS p_filed TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
*   PER-JOURNEY RETENTION, now that ZRAK_CJ_ATTX carries JOURNEY_ID. Each
*   handler's own RETENTION( )-attach_days is used where it states one, and
*   P_ADAYS covers the rest - journeys with no handler, no policy, and every
*   row staged before the column existed, which have no journey to ask.
PARAMETERS p_perjn TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_test  TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_pol TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b2.

*&---------------------------------------------------------------------*
CLASS lcl_purge DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.
  PRIVATE SECTION.
    CLASS-METHODS report_policies.
    CLASS-METHODS purge_files.

*   ONE READER FOR THE POLICY, because REPORT_POLICIES( ) prints it and
*   PURGE_FILES( ) now acts on it, and a report whose printed policy and
*   applied policy could differ would be worse than one that never applied it.
    TYPES: BEGIN OF ty_pol,
             journey TYPE zrak_journey_id,
             handler TYPE string,
             days    TYPE i,
             action  TYPE string,
             note    TYPE string,
           END OF ty_pol,
           tt_pol TYPE STANDARD TABLE OF ty_pol WITH EMPTY KEY.
    CLASS-METHODS policies RETURNING VALUE(rt) TYPE tt_pol.

*   "90 days, archive" / "framework default" / "keep" - one column of the
*   policy table, rendered so a blank policy reads as a decision not to act
*   rather than as a zero-day purge.
    CLASS-METHODS describe IMPORTING iv_days       TYPE i
                                     iv_action     TYPE string
                           RETURNING VALUE(rv_txt) TYPE string.
ENDCLASS.

CLASS lcl_purge IMPLEMENTATION.

  METHOD run.
    WRITE: / 'CJS retention run', sy-datum, sy-uzeit.
    IF p_test = abap_true.
      WRITE: / 'TEST RUN - nothing is deleted.' COLOR COL_TOTAL.
    ENDIF.
    SKIP.

    IF p_pol = abap_true.
      report_policies( ).
      SKIP.
    ENDIF.

    purge_files( ).
  ENDMETHOD.


  METHOD policies.
*   Every active journey with a handler, its attach retention as the handler
*   states it. A handler that will not instantiate, or whose RETENTION( )
*   raises, is reported with DAYS 0 and a note - it is a finding, but not this
*   report's finding, and one broken journey must not stop the purge for the
*   rest.
    SELECT journey_id, handler_class FROM zrak_t_jny
      INTO TABLE @DATA(lt_jny)
      WHERE active = 'X' AND handler_class <> ''
      ORDER BY journey_id.

    LOOP AT lt_jny INTO DATA(ls_jny).
      DATA(ls_p) = VALUE ty_pol( journey = ls_jny-journey_id
                                 handler = ls_jny-handler_class ).
      DATA lo_logic TYPE REF TO zif_rak_journey_logic.
      CLEAR lo_logic.
      TRY.
          CREATE OBJECT lo_logic TYPE (ls_jny-handler_class).
        CATCH cx_root.
          ls_p-note = 'handler will not instantiate'.
          APPEND ls_p TO rt.
          CONTINUE.
      ENDTRY.

*     IO_CTX deliberately omitted - see the header. There is no session.
      DATA ls_ret TYPE zif_rak_journey=>ty_retention.
      TRY.
          ls_ret = lo_logic->retention( ).
        CATCH cx_root INTO DATA(lx_ret).
          ls_p-note = |RETENTION( ) raised: { lx_ret->get_text( ) }|.
          APPEND ls_p TO rt.
          CONTINUE.
      ENDTRY.

      ls_p-days   = ls_ret-attach_days.
      ls_p-action = ls_ret-attach_action.
      APPEND ls_p TO rt.
    ENDLOOP.
  ENDMETHOD.

  METHOD report_policies.
*   THROUGH POLICIES( ), the same reader PURGE_FILES( ) acts on. This method
*   used to do its own SELECT and its own RETENTION( ) call, which was
*   harmless while it only printed - and would not be now that the policy is
*   applied. A report whose printed policy and applied policy could differ is
*   worse than one that never applied it at all.
    WRITE: / 'Retention policy by journey' COLOR COL_HEADING.
    WRITE: / 'Journey', 12 'Handler', 52 'Files' COLOR COL_HEADING.
    ULINE.

    LOOP AT policies( ) INTO DATA(ls_p).
      IF ls_p-note IS NOT INITIAL.
        WRITE: / ls_p-journey, 12 ls_p-handler, 52 ls_p-note COLOR COL_NEGATIVE.
        CONTINUE.
      ENDIF.
      WRITE: / ls_p-journey,
             12 ls_p-handler,
             52 describe( iv_days = ls_p-days iv_action = ls_p-action ).

*     THE NOTE THIS USED TO CARRY IS GONE BECAUSE THE LIMIT IS GONE. It said
*     the journey asked for N days but ZRAK_CJ_ATTX had no journey column so
*     P_ADAYS was applied to everything. The column exists now and the policy
*     is honoured, so what is printed here is what runs - provided P_PERJN is
*     ticked, which is what this line says when it is not.
      IF ls_p-days > 0 AND p_perjn = abap_false.
        WRITE: /12 |asks for { ls_p-days } day(s); NOT applied - tick Per-journey | &&
                   |retention, otherwise { p_adays } covers this journey too| COLOR COL_TOTAL.
      ENDIF.
    ENDLOOP.

*   DRAFTS ARE STILL NOT PURGED and that has not changed: there is no CJS-side
*   draft store. DRAFT_MODE is DELEGATE wherever a backend exists, so the
*   backend owns the draft and its retention. Said once here rather than per
*   journey, which is how it used to read.
    ULINE.
    WRITE: / 'Draft retention is not applied - no CJS-side draft store; DRAFT_MODE',
           / 'DELEGATE means the backend owns the draft and its retention.'.
  ENDMETHOD.


  METHOD purge_files.
    DATA(lv_cutoff) = CONV d( sy-datum - p_adays ).

    SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_total).
    SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_old) WHERE erdat < @lv_cutoff.

*   THE TEST RUN MUST COUNT WHAT THE REAL RUN WOULD DELETE, not what an older
*   version of this report would have. With P_FILED on, unfiled staging is
*   never touched, and reporting the plain age count would promise a deletion
*   that is not going to happen - which is the one thing a test run exists to
*   prevent.
    DATA lt_f TYPE RANGE OF zrak_cj_attx-filed.
    IF p_filed = abap_true.
      lt_f = VALUE #( ( sign = 'I' option = 'EQ' low = 'X' ) ).
    ENDIF.
    SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_due)
      WHERE erdat < @lv_cutoff AND filed IN @lt_f.

*   AND PER-JOURNEY ADDS TO IT: a journey with a SHORTER policy than P_ADAYS
*   contributes rows the cutoff above does not reach.
    DATA lv_extra TYPE i.
    IF p_perjn = abap_true.
      LOOP AT policies( ) INTO DATA(ls_pc) WHERE days > 0 AND days < p_adays.
        DATA(lv_jcut) = CONV d( sy-datum - ls_pc-days ).
        SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_jn)
          WHERE journey_id = @ls_pc-journey
            AND erdat      < @lv_jcut
            AND erdat      >= @lv_cutoff
            AND filed      IN @lt_f.
        lv_extra = lv_extra + lv_jn.
      ENDLOOP.
    ENDIF.

    WRITE: / 'Staged files in ZRAK_CJ_ATTX' COLOR COL_HEADING.
    WRITE: / 'Total', 30 lv_total.
    WRITE: / |Older than { p_adays } days|, 30 lv_old.
    WRITE: / 'Cutoff date', 30 lv_cutoff.
    WRITE: / 'Due under the current switches', 30 |{ lv_due + lv_extra }|.
    IF p_filed = abap_true AND lv_old > lv_due.
      WRITE: / |{ lv_old - lv_due } old file(s) are UNFILED and will be kept - they | &&
                 |exist nowhere else| COLOR COL_TOTAL.
    ENDIF.

    IF lv_due + lv_extra = 0.
      WRITE: / 'Nothing to remove.'.
      RETURN.
    ENDIF.

    IF p_test = abap_true.
      WRITE: / |{ lv_due + lv_extra } file(s) would be removed. Untick Test run to do it.|
             COLOR COL_TOTAL.
      RETURN.
    ENDIF.

*   PURGE( ) does the DELETE and deliberately does not COMMIT - the note in
*   the class says the commit is the caller's. This is that caller.
    DATA lv_gone TYPE i.

    IF p_perjn = abap_true.
*     EACH JOURNEY ON ITS OWN POLICY FIRST. A journey stating attach_days uses
*     it; everything left over - no handler, no policy, or staged before
*     JOURNEY_ID existed and so belonging to no journey at all - falls to the
*     P_ADAYS sweep below. Both passes honour P_FILED.
      LOOP AT policies( ) INTO DATA(ls_p) WHERE days > 0.
        DATA(lv_n) = zcl_rak_cj_att_store=>purge( iv_days       = ls_p-days
*                                                 CONV, because LS_P-JOURNEY is
*                                                 ZRAK_JOURNEY_ID and IV_JOURNEY is
*                                                 TYPE string - parameters bind BY
*                                                 REFERENCE here, so the two types
*                                                 must match exactly.
                                                  iv_journey    = CONV string( ls_p-journey )
                                                  iv_filed_only = p_filed ).
        IF lv_n > 0.
          WRITE: / |{ ls_p-journey }|, 30 |{ lv_n } removed at { ls_p-days } day(s)|.
        ENDIF.
        lv_gone = lv_gone + lv_n.
      ENDLOOP.
    ENDIF.

    lv_gone = lv_gone + zcl_rak_cj_att_store=>purge( iv_days       = p_adays
                                                     iv_filed_only = p_filed ).
    COMMIT WORK AND WAIT.

    WRITE: / |{ lv_gone } file(s) removed.| COLOR COL_POSITIVE.
    IF p_filed = abap_true.
      WRITE: / 'Unfiled staging was left alone - those files exist nowhere else.'.
    ENDIF.
  ENDMETHOD.


  METHOD describe.
    IF iv_days <= 0.
      rv_txt = 'default'.
    ELSE.
      rv_txt = |{ iv_days } d|.
    ENDIF.
    rv_txt = |{ rv_txt } { COND string( WHEN iv_action IS INITIAL THEN 'keep' ELSE iv_action ) }|.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  lcl_purge=>run( ).
