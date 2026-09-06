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

*   WHAT THIS CLASS IS ACTUALLY DOING, for the &trace=x line.
*
*   The silent failure is deliberate - a log must never be why a journey
*   stops - but it means "the logger is broken" and "there was nothing to
*   log" look identical from the outside, and that cost a round already:
*   SLG1 showed four entries, all of them the BAdI's, and nothing said
*   whether CJS had even tried.
*
*   So the exception text is kept and reported here. One launch with
*   &trace=x now names the method and parameter that did not match, which
*   is the difference between reading it and guessing at it.
    CLASS-METHODS status RETURNING VALUE(rv) TYPE string.

  PRIVATE SECTION.

*   The handle ZCL_APPL_LOG hands back, kept as a generic reference because
*   its type is not visible from here either.
    CLASS-DATA go_log     TYPE REF TO object.
    CLASS-DATA gv_open    TYPE abap_bool.
*   Set when the dynamic call fails once, so a system without ZCL_APPL_LOG
*   is not asked again on every line of every round trip.
    CLASS-DATA gv_dead    TYPE abap_bool.
*   Why it died, verbatim from the exception, and which call was being made
*   when it did. Reported by STATUS( ) on the trace.
    CLASS-DATA gv_err     TYPE string.
    CLASS-DATA gv_where   TYPE string.

*   ASK THE CLASS WHAT ITS PARAMETERS ARE CALLED, rather than guessing.
*
*   The first version of this class hardcoded RO_INSTANCE and IT_MESSAGE,
*   inferred from how ZCL_EGA_CJ_FW_RO_ABS_V1 calls ZCL_APPL_LOG - and the
*   trace answered: "The formal parameter RO_INSTANCE does not exist." A
*   second guess would have been the same mistake with different spelling.
*
*   CL_ABAP_CLASSDESCR knows. This is the shape ZCL_RAK_CJ_REQ_CTX already
*   uses for /IWBEP/CL_MGW_REQUEST - read the signature the system actually
*   declares, build a PARAMETER-TABLE from it, and call dynamically - and it
*   is in CLAUDE.md as the answer to "never hand-write the shape of a
*   standard object you cannot open from here".
*
*   IV_KIND takes CL_ABAP_OBJECTDESCR=>RETURNING or =>IMPORTING. Blank back
*   means no such method, or no parameter of that kind, and the caller
*   treats that the same as any other failure.
    CLASS-METHODS parm_of
      IMPORTING iv_class  TYPE string
                iv_method TYPE string
                iv_kind   TYPE abap_parmkind
      RETURNING VALUE(rv) TYPE abap_parmname.

ENDCLASS.


CLASS zcl_rak_cj_log IMPLEMENTATION.


  METHOD open.
    IF gv_open = abap_true OR gv_dead = abap_true.
      RETURN.
    ENDIF.

    TRY.
        DATA lo_log TYPE REF TO object.

*       THE RETURNING PARAMETER, BY NAME THE SYSTEM GIVES. Hardcoding
*       RO_INSTANCE is what the first version did and the trace refused it.
        DATA(lv_ret) = parm_of( iv_class  = 'ZCL_APPL_LOG'
                                iv_method = 'GET_INSTANCE'
                                iv_kind   = cl_abap_objectdescr=>returning ).
        IF lv_ret IS INITIAL.
          gv_where = 'GET_INSTANCE'.
          gv_err   = 'no returning parameter found by RTTI'.
          gv_dead  = abap_true.
          RETURN.
        ENDIF.

        DATA lt_p TYPE abap_parmbind_tab.
*       RECEIVING is the kind a returning parameter takes in a
*       PARAMETER-TABLE - the caller receives what the method returns.
        lt_p = VALUE #( ( name  = lv_ret
                          kind  = cl_abap_objectdescr=>receiving
                          value = REF #( lo_log ) ) ).
        CALL METHOD ('ZCL_APPL_LOG')=>('GET_INSTANCE')
          PARAMETER-TABLE lt_p.

        IF lo_log IS NOT BOUND.
          gv_where = 'GET_INSTANCE'.
          gv_err   = 'returned an unbound reference'.
          gv_dead  = abap_true.
          RETURN.
        ENDIF.

*       LOG_CREATE's three names came from the BAdI's own call site, which
*       names them, so these are read rather than inferred and stay static.
        CALL METHOD lo_log->('LOG_CREATE')
          EXPORTING
            iv_object    = CONV balobj_d( c_object )
            iv_subobject = CONV balsubobj( c_subobject )
            iv_extno     = CONV balnrext( iv_extno ).

        go_log  = lo_log.
        gv_open = abap_true.

      CATCH cx_root INTO DATA(lx_open).
        gv_err   = lx_open->get_text( ).
        gv_where = 'GET_INSTANCE / LOG_CREATE'.
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

*       Same discipline as GET_INSTANCE: the BAdI calls MESSAGE_ADD
*       positionally, so its call site never revealed the parameter name and
*       IT_MESSAGE was a guess. Ask instead.
        DATA(lv_imp) = parm_of( iv_class  = 'ZCL_APPL_LOG'
                                iv_method = 'MESSAGE_ADD'
                                iv_kind   = cl_abap_objectdescr=>importing ).
        IF lv_imp IS INITIAL.
          gv_where = 'MESSAGE_ADD'.
          gv_err   = 'no importing parameter found by RTTI'.
          gv_dead  = abap_true.
          RETURN.
        ENDIF.

        DATA lt_ap TYPE abap_parmbind_tab.
*       EXPORTING is the kind an IMPORTING parameter takes here - the caller
*       exports into it.
        lt_ap = VALUE #( ( name  = lv_imp
                           kind  = cl_abap_objectdescr=>exporting
                           value = REF #( lt_msg ) ) ).
        CALL METHOD go_log->('MESSAGE_ADD')
          PARAMETER-TABLE lt_ap.

      CATCH cx_root INTO DATA(lx_add).
        IF gv_err IS INITIAL.
          gv_err   = lx_add->get_text( ).
          gv_where = 'MESSAGE_ADD'.
        ENDIF.
        gv_dead = abap_true.
    ENDTRY.
  ENDMETHOD.


  METHOD save.
    IF gv_open = abap_false OR gv_dead = abap_true OR go_log IS NOT BOUND.
      RETURN.
    ENDIF.

    TRY.
        CALL METHOD go_log->('LOG_SAVE').
      CATCH cx_root INTO DATA(lx_save).
        IF gv_err IS INITIAL.
          gv_err   = lx_save->get_text( ).
          gv_where = 'LOG_SAVE'.
        ENDIF.
        gv_dead = abap_true.
    ENDTRY.

*   Closed either way. The next interaction opens its own log, so one SLG1
*   entry is one journey interaction rather than everything a work process
*   happened to serve.
    CLEAR: gv_open, go_log.
  ENDMETHOD.


  METHOD parm_of.
    TRY.
        DATA(lo_cd) = CAST cl_abap_classdescr(
                        cl_abap_typedescr=>describe_by_name( iv_class ) ).

*       Method names are upper case in the descriptor.
        READ TABLE lo_cd->methods INTO DATA(ls_m)
             WITH KEY name = to_upper( iv_method ).
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.

*       THE FIRST PARAMETER OF THAT KIND. A returning parameter is unique by
*       definition; MESSAGE_ADD is called by the BAdI with one unnamed
*       argument, so it has exactly one importing parameter and there is
*       nothing to choose between. If a future signature adds a second, the
*       call fails on the missing mandatory one and the trace says so, which
*       is the honest outcome rather than binding to whichever came first.
        LOOP AT ls_m-parameters INTO DATA(ls_p) WHERE parm_kind = iv_kind.
          rv = ls_p-name.
          RETURN.
        ENDLOOP.

      CATCH cx_root.
*       No such class, or the descriptor is not a class descriptor. Blank
*       back; the caller reports it like any other failure.
        CLEAR rv.
    ENDTRY.
  ENDMETHOD.


  METHOD status.
    IF gv_dead = abap_true.
      rv = |not writing · { COND string( WHEN gv_where IS NOT INITIAL THEN gv_where ELSE 'unknown call' ) }| &&
           | failed · { COND string( WHEN gv_err IS NOT INITIAL THEN gv_err ELSE 'no exception text' ) }| &&
           | · SLG1 object { c_object }/{ c_subobject } will show the BAdI's lines only|.
      RETURN.
    ENDIF.
    IF gv_open = abap_true.
      rv = |writing to SLG1 object { c_object }/{ c_subobject }|.
      RETURN.
    ENDIF.
    rv = |not opened on this round trip|.
  ENDMETHOD.


ENDCLASS.
