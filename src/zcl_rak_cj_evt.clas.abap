*&---------------------------------------------------------------------*
*& ZCL_RAK_CJ_EVT - telemetry collection for the Customer Journey Studio
*&---------------------------------------------------------------------*
*& Buffers events for the life of one request and flushes them once, at
*& the end, into its own logical unit of work.
*&
*& It never commits. A COMMIT WORK here would persist whatever else the
*& request had pending - mid-journey that means half a case written to the
*& database because somebody wanted a page-view counter. Every design
*& choice below follows from that one rule.
*&
*& FLUSH uses STARTING NEW TASK rather than IN UPDATE TASK or IN
*& BACKGROUND UNIT because both of those are only scheduled when the
*& CALLER commits, and most CJS requests are renders that never do. The
*& cost is one short-lived work process per request and best-effort
*& delivery. For footfall counting that is the right trade; where an exact
*& denominator matters, it is not.
*&
*& Class methods, not an instance. The rules and handler classes only ever
*& see IO_CTX, so an instance on the engine would have needed a new
*& interface method to reach it from the payment flow. BEGIN is called once
*& per request from MAIN with the session carried on the engine's own
*& instance attribute, and BEGIN clears the buffer - so the statics here
*& cannot leak one visitor's events into another's session the way a
*& static session id would.
*&
*& ROLE and ROLEBP were on the BEGIN signature but never assigned and had no
*& columns, so an agent acting for a company was indistinguishable from an owner
*& acting for themselves - and those two behave differently on most journeys.
*& Both are stored now.
*&
*& The business partner is set once in BEGIN and inherited by every event.
*& It used to be an argument on ADD, which meant two of the twenty call sites
*& passed it and the other eighteen - every validation failure, every payment
*& refusal, every gate blocker - recorded a blank partner. "Which citizen is
*& stuck" was unanswerable for exactly the events that describe being stuck.
*&
*& ADD_ONCE deduplicates across the SESSION, not the request, which is why the
*& seen-key table is not held here. The buffer is cleared every request - if the
*& keys lived here too, a step re-rendered on three round trips would log three
*& VIEW events and every drop-off percentage would be wrong in a way that still
*& looks plausible. The engine owns the table as an instance attribute so it
*& rides the serialised instance, and passes a reference to BEGIN.
*&
*& Nothing in here may raise. A telemetry fault must never reach a citizen
*& or abort a journey, so every entry point swallows its own exceptions.
*&---------------------------------------------------------------------*
CLASS zcl_rak_cj_evt DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CONSTANTS c_active  TYPE abap_bool VALUE abap_true ##NO_TEXT.
    CONSTANTS c_slow_ms TYPE i VALUE 1500.

    CONSTANTS:
      BEGIN OF c_type,
        launch    TYPE c LENGTH 4 VALUE 'LNCH',
        view      TYPE c LENGTH 4 VALUE 'VIEW',
        next      TYPE c LENGTH 4 VALUE 'NEXT',
        back      TYPE c LENGTH 4 VALUE 'BACK',
        save      TYPE c LENGTH 4 VALUE 'SAVE',
        resume    TYPE c LENGTH 4 VALUE 'RSUM',
        val_fail  TYPE c LENGTH 4 VALUE 'VALF',
        gate      TYPE c LENGTH 4 VALUE 'GATE',
        case_new  TYPE c LENGTH 4 VALUE 'CASE',
        pay_start TYPE c LENGTH 4 VALUE 'PAYS',
        pay_done  TYPE c LENGTH 4 VALUE 'PAYD',
        pay_fail  TYPE c LENGTH 4 VALUE 'PAYX',
        pay_stop  TYPE c LENGTH 4 VALUE 'PAYW',
        submit    TYPE c LENGTH 4 VALUE 'SUBM',
        delete    TYPE c LENGTH 4 VALUE 'DELE',
        error     TYPE c LENGTH 4 VALUE 'ERRQ',
        perf      TYPE c LENGTH 4 VALUE 'PERF',
        pay_block TYPE c LENGTH 4 VALUE 'PAYB',
      END OF c_type.

    CLASS-METHODS new_sess
      RETURNING VALUE(rv_sess) TYPE string.

    CLASS-METHODS begin
      IMPORTING iv_sess    TYPE string
                iv_journey TYPE string
                iv_langu   TYPE sy-langu
                ir_seen    TYPE REF TO string_table
                !iv_rolebp TYPE string OPTIONAL
                !iv_role   TYPE string OPTIONAL
                iv_bp      TYPE string OPTIONAL
                iv_channel TYPE string OPTIONAL
                iv_device  TYPE string OPTIONAL.

    CLASS-METHODS add
      IMPORTING iv_type     TYPE c
                iv_step_id  TYPE string OPTIONAL
                iv_step_no  TYPE i OPTIONAL
                iv_case     TYPE string OPTIONAL
                iv_bp       TYPE string OPTIONAL
                iv_result   TYPE string OPTIONAL
                iv_detail   TYPE string OPTIONAL
                iv_extra    TYPE string OPTIONAL
                iv_duration TYPE i OPTIONAL.

    CLASS-METHODS add_view
      IMPORTING iv_step_id TYPE string
                iv_step_no TYPE i.

    CLASS-METHODS add_once
      IMPORTING iv_type    TYPE c
                iv_key     TYPE string
                iv_step_id TYPE string OPTIONAL
                iv_step_no TYPE i OPTIONAL
                iv_case    TYPE string OPTIONAL
                iv_detail  TYPE string OPTIONAL.

    CLASS-METHODS flush.

    CLASS-METHODS buffered
      RETURNING VALUE(rv_n) TYPE i.

    CLASS-METHODS reset.

  PRIVATE SECTION.

    CLASS-DATA gt_buf   TYPE STANDARD TABLE OF zrak_t_cj_evt WITH EMPTY KEY.
    CLASS-DATA gr_seen  TYPE REF TO string_table.
    CLASS-DATA gv_rfc_ok  TYPE abap_bool.
    CLASS-DATA gv_rfc_chk TYPE abap_bool.
    CLASS-DATA gv_sess  TYPE string.
    CLASS-DATA gv_jny   TYPE string.
    CLASS-DATA gv_langu TYPE sy-langu.
    CLASS-DATA gv_bp    TYPE string.
    CLASS-DATA gv_rolebp TYPE string.
    CLASS-DATA gv_role  TYPE string.
    CLASS-DATA gv_chan  TYPE string.
    CLASS-DATA gv_dev   TYPE string.

    CLASS-METHODS scrub
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(rv_out) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_CJ_EVT IMPLEMENTATION.


  METHOD add.
    IF c_active = abap_false OR gv_sess IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        GET TIME STAMP FIELD DATA(lv_ts).

        APPEND VALUE zrak_t_cj_evt(
          evt_id     = cl_system_uuid=>create_uuid_c32_static( )
          tstamp     = lv_ts
          sess_id    = gv_sess
          journey_id = gv_jny
          step_id    = iv_step_id
          step_no    = iv_step_no
          evt_type   = iv_type
          case_guid  = iv_case
          bp         = COND string( WHEN iv_bp IS NOT INITIAL THEN iv_bp ELSE gv_bp )
          rolebp     = gv_rolebp
          role       = gv_role
          channel    = gv_chan
          device     = gv_dev
          langu      = gv_langu
          sysid      = |{ sy-sysid }{ sy-mandt }|
          duration   = iv_duration
          outcome    = iv_result
          detail     = scrub( iv_detail )
          extra      = scrub( iv_extra ) ) TO gt_buf.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD add_once.
    IF gr_seen IS NOT BOUND.
      RETURN.
    ENDIF.

    DATA(lv_k) = |{ iv_type }#{ iv_key }|.

    IF line_exists( gr_seen->*[ table_line = lv_k ] ).
      RETURN.
    ENDIF.

    APPEND lv_k TO gr_seen->*.

    add( iv_type    = iv_type
         iv_step_id = iv_step_id
         iv_step_no = iv_step_no
         iv_case    = iv_case
         iv_detail  = iv_detail ).
  ENDMETHOD.


  METHOD add_view.
    add_once( iv_type    = c_type-view
              iv_key     = |{ iv_step_no }|
              iv_step_id = iv_step_id
              iv_step_no = iv_step_no ).
  ENDMETHOD.


  METHOD begin.
    CLEAR gt_buf.
    gr_seen  = ir_seen.
    gv_sess  = iv_sess.
    gv_jny   = iv_journey.
    gv_langu = iv_langu.
    gv_bp    = iv_bp.
    gv_rolebp = iv_rolebp.
    gv_role  = to_upper( iv_role ).
    gv_chan  = COND string( WHEN iv_channel IS NOT INITIAL THEN to_upper( iv_channel ) ELSE 'PORTAL' ).
    gv_dev   = to_upper( iv_device ).
  ENDMETHOD.


  METHOD buffered.
    rv_n = lines( gt_buf ).
  ENDMETHOD.


  METHOD flush.
    IF gt_buf IS INITIAL.
      RETURN.
    ENDIF.

*   CALL_FUNCTION_NOT_REMOTE is a non-class-based runtime error raised before the
*   call is even attempted, so the CATCH CX_ROOT below never sees it. Without this
*   check a function module transported without its Remote-Enabled flag takes the
*   whole journey down with a 500 - which is exactly what this class promises can
*   never happen. One SELECT per work process, then cached.
    IF gv_rfc_chk = abap_false.
      SELECT SINGLE fmode FROM tfdir
        WHERE funcname = 'Z_RAK_CJ_EVT_WRITE'
        INTO @DATA(lv_fmode).
      gv_rfc_ok  = xsdbool( sy-subrc = 0 AND lv_fmode = 'R' ).
      gv_rfc_chk = abap_true.
    ENDIF.

    IF gv_rfc_ok = abap_false.
      CLEAR gt_buf.
      RETURN.
    ENDIF.

    DATA(lt_send) = gt_buf.
    CLEAR gt_buf.

    TRY.
        CALL FUNCTION 'Z_RAK_CJ_EVT_WRITE'
          STARTING NEW TASK 'RAKEVT'
          EXPORTING
            it_evt = lt_send.
      CATCH cx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD new_sess.
    TRY.
        rv_sess = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_root.
        CLEAR rv_sess.
    ENDTRY.
  ENDMETHOD.


  METHOD scrub.
    rv_out = iv_in.
    REPLACE ALL OCCURRENCES OF REGEX '[0-9]{6,}' IN rv_out WITH '#'.
    IF strlen( rv_out ) > 255.
      rv_out = rv_out(255).
    ENDIF.
  ENDMETHOD.


  METHOD reset.
    CLEAR gt_buf.
    CLEAR gr_seen.
    CLEAR gv_sess.
    CLEAR gv_rolebp.
    CLEAR gv_role.
    gv_rfc_chk = abap_false.
  ENDMETHOD.
ENDCLASS.
