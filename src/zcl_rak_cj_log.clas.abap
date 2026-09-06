CLASS zcl_rak_cj_log DEFINITION
  PUBLIC
  CREATE PRIVATE.

*---------------------------------------------------------------------------------------*
* CJS application log - the SLG1 half of the story.
*
* CJS wrote NOTHING to SLG1. The BAdI has always logged to object ZEGA_CJ /
* subobject CJ through ZCL_APPL_LOG - every container case it creates, every
* draft, every failure - so support could see the backend half of a journey and
* not one thing about the half the citizen actually touched. Which step they
* reached, what was posted, whether payment was even attempted: none of it.
*
* This writes to THE SAME OBJECT on purpose. Two logs would be two half
* pictures that have to be read side by side; one log read in date order is the
* transaction. ZCL_RAK_CJ_EVT is not a substitute - it is telemetry, keyed for
* counting journeys and measuring durations, and support does not open a Z
* table to find out why one citizen's request failed at 11:04.
*
* ---- WHY EVERY CALL IS DYNAMIC --------------------------------------------
* ZCL_APPL_LOG is not in this repository. Its three methods are known only
* from reading ZCL_EGA_CJ_FW_RO_ABS_V1, which calls
*
*     zcl_appl_log=>get_instance( )
*     ->log_create( iv_object iv_subobject iv_extno )
*     ->message_add( VALUE bal_t_msg( ( msgid msgty msgno msgv1 msgv2 ) ) )
*     ->log_save( )
*
* and CLAUDE.md is explicit that hand-writing the shape of a standard object
* you cannot open costs rounds - ZCL_RAK_CJ_REQ_CTX was written three times
* against /IWBEP/CL_MGW_REQUEST before that lesson stuck. A static reference
* to a class or a method that turns out to differ is not a runtime error, it
* is a class with no active version, and this one is called from the engine -
* so getting it wrong would take every journey down rather than losing a log
* line.
*
* Dynamic, inside TRY/CATCH cx_root, means a wrong guess degrades to "no log"
* and the citizen's journey continues. A log is diagnostics; it must never be
* the reason a service stops.
*
* ---- WHAT IS LOGGED, AND WHAT IS NOT ---------------------------------------
* Logged: journey launch, every backend post, payment events, submit, and
* every error. Not logged: render round trips. A citizen picking a dropdown
* value produces a round trip and nothing worth an SLG1 row - logging those
* would bury the six lines that matter under a hundred that do not, and this
* runs per citizen per interaction.
*
* NO ENVIRONMENT GATE. Logging is the one thing on the dev/QA/prod matrix that
* belongs on EVERY system, and most of all on production - it is what support
* reads when a citizen rings up. The trace is gated because it prints to the
* citizen's screen; this writes to SLG1, which only staff can open.
*---------------------------------------------------------------------------------------*

  PUBLIC SECTION.

*   SLG1 coordinates. The same object and subobject the BAdI writes to, so
*   one SLG1 selection shows the whole transaction.
    CONSTANTS c_object    TYPE string VALUE 'ZEGA_CJ'.
    CONSTANTS c_subobject TYPE string VALUE 'CJ'.

*   The message class every line is raised under. 000 is the free-text
*   number the BAdI uses for the same purpose - four 50-character
*   variables, no message maintenance needed for a new line.
    CONSTANTS c_msgid TYPE symsgid VALUE 'ZMSG_EGA_CJ'.
    CONSTANTS c_msgno TYPE symsgno VALUE '000'.

*   START A LOG FOR ONE JOURNEY INTERACTION. Safe to call more than once -
*   the second call is a no-op, so the engine need not track whether it has
*   opened one. IV_EXTNO is the external number SLG1 shows in its list and
*   is what makes a log findable: the journey key, once there is one.
    CLASS-METHODS open
      IMPORTING iv_journey TYPE string
                iv_extno   TYPE string OPTIONAL.

*   ONE LINE. IV_TYPE is a BAPI message type - 'I', 'W', 'E', 'S'. The text
*   is split across the four message variables because 000 takes 50
*   characters each and a truncated log line is worse than a wrapped one.
    CLASS-METHODS add
      IMPORTING iv_type TYPE symsgty DEFAULT 'I'
                iv_text TYPE string.

*   FLUSH TO THE DATABASE. Called by the engine at the end of a round trip.
*   Nothing is visible in SLG1 until this runs.
    CLASS-METHODS save.

  PRIVATE SECTION.

*   The handle ZCL_APPL_LOG hands back, kept as a generic reference because
*   its type is not visible from here either.
    CLASS-DATA go_log     TYPE REF TO object.
    CLASS-DATA gv_open    TYPE abap_bool.
*   Set when the dynamic call fails once, so a system without ZCL_APPL_LOG
*   is not asked again on every line of every round trip.
    CLASS-DATA gv_dead    TYPE abap_bool.

ENDCLASS.


CLASS zcl_rak_cj_log IMPLEMENTATION.


  METHOD open.
    IF gv_open = abap_true OR gv_dead = abap_true.
      RETURN.
    ENDIF.

    TRY.
        DATA lo_log TYPE REF TO object.
        CALL METHOD ('ZCL_APPL_LOG')=>('GET_INSTANCE')
          RECEIVING
            ro_instance = lo_log.

        IF lo_log IS NOT BOUND.
          gv_dead = abap_true.
          RETURN.
        ENDIF.

        CALL METHOD lo_log->('LOG_CREATE')
          EXPORTING
            iv_object    = CONV balobj_d( c_object )
            iv_subobject = CONV balsubobj( c_subobject )
            iv_extno     = CONV balnrext( iv_extno ).

        go_log  = lo_log.
        gv_open = abap_true.

      CATCH cx_root.
*       The logger is not here, or does not look the way the BAdI's calls
*       suggested. Give up permanently rather than throwing on every line,
*       and never let it reach the citizen.
        gv_dead = abap_true.
        CLEAR go_log.
    ENDTRY.

    IF gv_open = abap_true.
      add( iv_type = 'I' iv_text = |CJS journey { iv_journey } · { sy-sysid }{ sy-mandt } · user { sy-uname }| ).
    ENDIF.
  ENDMETHOD.


  METHOD add.
    IF gv_open = abap_false OR gv_dead = abap_true OR go_log IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
*       Four fifties. SPLIT would break mid-word and OFFSET/LENGTH on a
*       string shorter than the offset raises, so each slice is taken only
*       when the text is long enough to have one.
        DATA(lv_t) = iv_text.
        DATA(lv_l) = strlen( lv_t ).
        DATA lv_v1 TYPE symsgv.
        DATA lv_v2 TYPE symsgv.
        DATA lv_v3 TYPE symsgv.
        DATA lv_v4 TYPE symsgv.
        lv_v1 = lv_t.
        IF lv_l > 50.
          lv_v2 = substring( val = lv_t off = 50 len = nmin( val1 = 50 val2 = lv_l - 50 ) ).
        ENDIF.
        IF lv_l > 100.
          lv_v3 = substring( val = lv_t off = 100 len = nmin( val1 = 50 val2 = lv_l - 100 ) ).
        ENDIF.
        IF lv_l > 150.
          lv_v4 = substring( val = lv_t off = 150 len = nmin( val1 = 50 val2 = lv_l - 150 ) ).
        ENDIF.

        DATA lt_msg TYPE bal_t_msg.
        lt_msg = VALUE #( ( msgid = c_msgid
                            msgty = iv_type
                            msgno = c_msgno
                            msgv1 = lv_v1
                            msgv2 = lv_v2
                            msgv3 = lv_v3
                            msgv4 = lv_v4 ) ).

        CALL METHOD go_log->('MESSAGE_ADD')
          EXPORTING
            it_message = lt_msg.

      CATCH cx_root.
        gv_dead = abap_true.
    ENDTRY.
  ENDMETHOD.


  METHOD save.
    IF gv_open = abap_false OR gv_dead = abap_true OR go_log IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        CALL METHOD go_log->('LOG_SAVE').
      CATCH cx_root.
        gv_dead = abap_true.
    ENDTRY.

*   Closed either way. The next interaction opens its own log, so one SLG1
*   entry is one journey interaction rather than everything a work process
*   happened to serve.
    CLEAR: gv_open, go_log.
  ENDMETHOD.


ENDCLASS.
