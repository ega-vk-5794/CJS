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

*   NAME THE INTERACTION. Records the journey and the key for the header
*   line; it does NOT touch ZCL_APPL_LOG, open anything or write anything.
*
*   THAT IS THE WHOLE POINT, and it was wrong in the first version. OPEN( )
*   used to create an SLG1 log and write a launch line on EVERY round trip,
*   so a citizen picking a dropdown value produced a log, a message and a
*   database save. The trace measured it: 2510 ms against 82 ms before.
*   Nothing in a plain render round trip is worth an SLG1 row, which the
*   header of this class already said and the wiring then ignored.
*
*   Everything is deferred to SAVE( ), which does nothing at all unless a
*   line was actually buffered. See there.
    CLASS-METHODS open
      IMPORTING iv_journey TYPE string
                iv_extno   TYPE string OPTIONAL.

*   BUFFER ONE LINE. IV_TYPE is a BAPI message type - 'I', 'W', 'E', 'S'.
*   Costs an APPEND and nothing else; no RTTI, no ZCL_APPL_LOG, no database.
    CLASS-METHODS add
      IMPORTING iv_type TYPE symsgty DEFAULT 'I'
                iv_text TYPE string.

*   FLUSH, AND DO NOTHING WHEN THERE IS NOTHING. Called by the engine at the
*   end of every round trip, and on most of them it returns on its first
*   line because the buffer is empty.
*
*   Only when a line was buffered does it resolve the parameter names,
*   create the log, write the lines and save - so the cost lands on the
*   round trips that produced something worth reading, which is what the
*   header of this class always claimed and what the first version did not
*   do.
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

*   THE BUFFER, and what makes this cheap. ADD( ) appends here and does
*   nothing else; SAVE( ) returns immediately when it is empty, so a render
*   round trip pays one IS INITIAL test for the whole mechanism.
    CLASS-DATA gt_buf     TYPE bal_t_msg.

*   Named by OPEN( ), used by SAVE( ) for the header line and the external
*   number. Not the log itself - nothing is created until there is content.
    CLASS-DATA gv_journey TYPE string.
    CLASS-DATA gv_extno   TYPE string.

*   RTTI ONCE PER SESSION, not once per line. DESCRIBE_BY_NAME walks the
*   whole class description and there is no reason to do it twice for an
*   answer that cannot change while the system is up.
    CLASS-DATA gv_p_inst  TYPE abap_parmname.
    CLASS-DATA gv_p_msg   TYPE abap_parmname.
*   Set when the dynamic call fails once, so a system without ZCL_APPL_LOG
*   is not asked again on every line of every round trip.
    CLASS-DATA gv_dead    TYPE abap_bool.
*   Why it died, verbatim from the exception, and which call was being made
*   when it did. Reported by STATUS( ) on the trace.
    CLASS-DATA gv_err     TYPE string.
    CLASS-DATA gv_where   TYPE string.
*   How many lines the last flush actually committed. STATUS( ) had only two
*   answers - dead, or "ready" - and "ready" was returned both when nothing
*   had been attempted AND after a flush that worked, so a working log and a
*   silent one read identically. A count is the only answer that separates
*   them.
    CLASS-DATA gv_wrote   TYPE i.

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

*   The only place ZCL_APPL_LOG is touched: resolve, create, write the whole
*   buffer in one MESSAGE_ADD, save. Reached from SAVE( ) and only with
*   something to write.
    CLASS-METHODS flush.

ENDCLASS.


CLASS zcl_rak_cj_log IMPLEMENTATION.


  METHOD open.
*   NOTE WHO WE ARE AND RETURN. No RTTI, no ZCL_APPL_LOG, no log, no
*   database - all of that is SAVE( )'s job and only when something was
*   buffered. This method is called on every round trip and must cost
*   nothing on the ones that have nothing to say.
    gv_journey = iv_journey.
    IF iv_extno IS NOT INITIAL.
      gv_extno = iv_extno.
    ENDIF.
  ENDMETHOD.


  METHOD flush.
*   THE ONLY PLACE ZCL_APPL_LOG IS TOUCHED. Reached from SAVE( ) and only
*   with a non-empty buffer.
    TRY.
        DATA lo_log TYPE REF TO object.

*       THE RETURNING PARAMETER, BY NAME THE SYSTEM GIVES. Hardcoding
*       RO_INSTANCE is what the first version did and the trace refused it.
*       Resolved once per session and remembered - DESCRIBE_BY_NAME walks
*       the whole class description and the answer cannot change while the
*       system is up.
        IF gv_p_inst IS INITIAL.
          gv_p_inst = parm_of( iv_class  = 'ZCL_APPL_LOG'
                               iv_method = 'GET_INSTANCE'
                               iv_kind   = cl_abap_objectdescr=>returning ).
        ENDIF.
        IF gv_p_inst IS INITIAL.
          gv_where = 'GET_INSTANCE'.
          gv_err   = 'no returning parameter found by RTTI'.
          gv_dead  = abap_true.
          RETURN.
        ENDIF.

        DATA lt_p TYPE abap_parmbind_tab.
*       RECEIVING is the kind a returning parameter takes in a
*       PARAMETER-TABLE - the caller receives what the method returns.
        lt_p = VALUE #( ( name  = gv_p_inst
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
            iv_extno     = CONV balnrext( gv_extno ).

        go_log  = lo_log.
        gv_open = abap_true.

*       The header line, written here rather than in OPEN( ) - it belongs to
*       a log that exists, and until now none did.
        INSERT VALUE #( msgid = c_msgid
                        msgty = 'I'
                        msgno = c_msgno
                        msgv1 = CONV symsgv( |CJS { gv_journey } { sy-sysid }{ sy-mandt }| )
                        msgv2 = CONV symsgv( |user { sy-uname }| ) )
               INTO gt_buf INDEX 1.

*       MESSAGE_ADD's name, same discipline and same cache. The BAdI calls
*       it positionally, so its call site never revealed one.
        IF gv_p_msg IS INITIAL.
          gv_p_msg = parm_of( iv_class  = 'ZCL_APPL_LOG'
                              iv_method = 'MESSAGE_ADD'
                              iv_kind   = cl_abap_objectdescr=>importing ).
        ENDIF.
        IF gv_p_msg IS INITIAL.
          gv_where = 'MESSAGE_ADD'.
          gv_err   = 'no importing parameter found by RTTI'.
          gv_dead  = abap_true.
          RETURN.
        ENDIF.

*       ONE CALL FOR THE WHOLE BUFFER. MESSAGE_ADD takes a table, so there
*       is no reason to call it per line - and the first version did,
*       through ADD( ), once per message.
        DATA lt_ap TYPE abap_parmbind_tab.
*       EXPORTING is the kind an IMPORTING parameter takes here - the caller
*       exports into it.
        lt_ap = VALUE #( ( name  = gv_p_msg
                           kind  = cl_abap_objectdescr=>exporting
                           value = REF #( gt_buf ) ) ).
        CALL METHOD go_log->('MESSAGE_ADD')
          PARAMETER-TABLE lt_ap.

        CALL METHOD go_log->('LOG_SAVE').

*       Counted only once LOG_SAVE has returned without raising, so this is
*       what was committed rather than what was attempted.
        gv_wrote = lines( gt_buf ).

      CATCH cx_root INTO DATA(lx_flush).
        IF gv_err IS INITIAL.
          gv_err   = lx_flush->get_text( ).
          gv_where = COND string( WHEN gv_open = abap_true THEN 'MESSAGE_ADD / LOG_SAVE'
                                  ELSE 'GET_INSTANCE / LOG_CREATE' ).
        ENDIF.
*       The logger is not here, or does not look the way the BAdI's calls
*       suggested. Give up permanently rather than throwing on every line,
*       and never let it reach the citizen.
        gv_dead = abap_true.
        CLEAR go_log.
    ENDTRY.
  ENDMETHOD.


  METHOD add.
*   AN APPEND, AND NOTHING ELSE. No RTTI, no dynamic call, no database -
*   this is what makes SAVE( )'s empty test worth having, and it means a
*   handler may call ADD( ) freely without wondering what it costs.
    IF gv_dead = abap_true.
      RETURN.
    ENDIF.

*   Four fifties. SPLIT would break mid-word, and OFFSET/LENGTH on a string
*   shorter than the offset RAISES rather than returning short - so each
*   slice is taken only when the text is long enough to have one.
    DATA(lv_l) = strlen( iv_text ).
    DATA lv_v1 TYPE symsgv.
    DATA lv_v2 TYPE symsgv.
    DATA lv_v3 TYPE symsgv.
    DATA lv_v4 TYPE symsgv.
    lv_v1 = iv_text.
    IF lv_l > 50.
      lv_v2 = substring( val = iv_text off = 50 len = nmin( val1 = 50 val2 = lv_l - 50 ) ).
    ENDIF.
    IF lv_l > 100.
      lv_v3 = substring( val = iv_text off = 100 len = nmin( val1 = 50 val2 = lv_l - 100 ) ).
    ENDIF.
    IF lv_l > 150.
      lv_v4 = substring( val = iv_text off = 150 len = nmin( val1 = 50 val2 = lv_l - 150 ) ).
    ENDIF.

    APPEND VALUE #( msgid = c_msgid
                    msgty = iv_type
                    msgno = c_msgno
                    msgv1 = lv_v1
                    msgv2 = lv_v2
                    msgv3 = lv_v3
                    msgv4 = lv_v4 ) TO gt_buf.
  ENDMETHOD.


  METHOD save.
*   THE GATE, AND THE WHOLE PERFORMANCE STORY IN ONE TEST. An empty buffer
*   means this round trip had nothing worth an SLG1 row - which is most of
*   them - and the method returns before touching RTTI, ZCL_APPL_LOG or the
*   database.
*
*   The first version created a log, wrote a launch line and saved on EVERY
*   round trip. It measured 2510 ms against 82 ms without, on a journey that
*   had done nothing but render. Nothing about a citizen picking a dropdown
*   value belongs in an application log, which this class's own header said
*   from the start.
    IF gt_buf IS INITIAL OR gv_dead = abap_true.
      CLEAR gt_buf.
      RETURN.
    ENDIF.

    flush( ).

*   Closed either way, and the buffer emptied whether the write worked or
*   not - a line that could not be written must not be carried into the next
*   round trip and written twice.
    CLEAR: gv_open, go_log, gt_buf.
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
*   READY, NOT WRITING. The trace line is drawn early in the round trip and
*   nothing has been buffered yet, so "writing" would be a claim about a log
*   that does not exist - and under the deferred design most round trips
*   never create one at all. What the reader needs to know here is that the
*   mechanism works and what would make it write.
*
*   GV_DEAD survives the round trip, so a failure discovered during last
*   round trip's flush is reported on this one - which is when a reader can
*   actually act on it.
    IF gv_wrote > 0.
      rv = |wrote { gv_wrote } line(s) to SLG1 object { c_object }/{ c_subobject }|.
      RETURN.
    ENDIF.

    rv = |ready, nothing written yet · SLG1 object { c_object }/{ c_subobject } · | &&
         |writes only on a round trip that has something to record (launch, | &&
         |submit, payment, or an error the citizen was shown)|.
  ENDMETHOD.


ENDCLASS.
