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


  METHOD report_policies.
    WRITE: / 'Retention policy by journey' COLOR COL_HEADING.
    WRITE: / 'Journey', 12 'Handler', 52 'Draft', 68 'Files' COLOR COL_HEADING.
    ULINE.

    SELECT journey_id, handler_class FROM zrak_t_jny
      INTO TABLE @DATA(lt_jny)
      WHERE active = 'X' AND handler_class <> @space
      ORDER BY journey_id.

    LOOP AT lt_jny INTO DATA(ls_jny).
      DATA lo_logic TYPE REF TO zif_rak_journey_logic.
      CLEAR lo_logic.
      TRY.
          CREATE OBJECT lo_logic TYPE (ls_jny-handler_class).
        CATCH cx_root.
*         A handler class that no longer activates is a finding in itself,
*         but not this report's finding. Say so and carry on: one broken
*         journey must not stop the purge for every other.
          WRITE: / ls_jny-journey_id, 12 ls_jny-handler_class,
                 52 'handler will not instantiate' COLOR COL_NEGATIVE.
          CONTINUE.
      ENDTRY.

*     IO_CTX deliberately omitted - see the header. There is no session.
      DATA ls_ret TYPE zif_rak_journey=>ty_retention.
      TRY.
          ls_ret = lo_logic->retention( ).
        CATCH cx_root INTO DATA(lx_ret).
          WRITE: / ls_jny-journey_id, 12 ls_jny-handler_class,
                 52 |RETENTION( ) raised: { lx_ret->get_text( ) }| COLOR COL_NEGATIVE.
          CONTINUE.
      ENDTRY.

      DATA(lv_dpol) = describe( iv_days = ls_ret-draft_days  iv_action = ls_ret-draft_action ).
      DATA(lv_apol) = describe( iv_days = ls_ret-attach_days iv_action = ls_ret-attach_action ).
      WRITE: / ls_jny-journey_id,
             12 ls_jny-handler_class,
             52 lv_dpol,
             68 lv_apol.

      IF ls_ret-attach_days > 0 AND ls_ret-attach_days <> p_adays.
        WRITE: /12 |asked for { ls_ret-attach_days } days for files; ZRAK_CJ_ATTX has no | &&
                   |journey column, so { p_adays } is applied to all| COLOR COL_TOTAL.
      ENDIF.
      IF ls_ret-draft_action = zif_rak_journey=>c_retain-archive.
        WRITE: /12 'draft policy is ARCHIVE; ON_ARCHIVE( ) is not called yet - no draft store'
               COLOR COL_TOTAL.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD purge_files.
    DATA(lv_cutoff) = CONV d( sy-datum - p_adays ).

    SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_total).
    SELECT COUNT( * ) FROM zrak_cj_attx INTO @DATA(lv_old) WHERE erdat < @lv_cutoff.

    WRITE: / 'Staged files in ZRAK_CJ_ATTX' COLOR COL_HEADING.
    WRITE: / 'Total', 20 lv_total.
    WRITE: / |Older than { p_adays } days|, 20 lv_old.
    WRITE: / 'Cutoff date', 20 lv_cutoff.

    IF lv_old = 0.
      WRITE: / 'Nothing to remove.'.
      RETURN.
    ENDIF.

    IF p_test = abap_true.
      WRITE: / |{ lv_old } file(s) would be removed. Untick Test run to do it.| COLOR COL_TOTAL.
      RETURN.
    ENDIF.

*   PURGE( ) does the DELETE and deliberately does not COMMIT - the note in
*   the class says the commit is the caller's. This is that caller.
    zcl_rak_cj_att_store=>purge( p_adays ).
    COMMIT WORK AND WAIT.

    WRITE: / |{ lv_old } file(s) removed.| COLOR COL_POSITIVE.
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
