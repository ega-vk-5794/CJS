CLASS zcl_rak_cj_cts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& CJS CONFIGURATION INTO A CUSTOMIZING REQUEST
*&
*& WHY THIS EXISTS. The Studio writes ZRAK_T_JNY* with a direct INSERT and
*& deletes with a plain DELETE FROM. No maintenance dialog, so no recording
*& routine, so NOTHING IT DOES IS EVER WRITTEN TO A TRANSPORT. Changes made
*& through the SM34 view cluster are recorded; changes made in the Studio -
*& which is where the work actually happens - are not.
*&
*& ADDS PARTLY SURVIVE THAT AND DELETIONS NEVER DO. A later touch on the same
*& row in SM34 picks that row up; a row deleted in the Studio cannot be touched
*& in SM34 afterwards, because there is nothing left to open. So the target
*& system only ever grows: fields removed in development are still live in
*& quality, still rendering, still posting. That is the junk, and the
*& wipe-and-reload everyone reaches for is a workaround for a move that cannot
*& delete.
*&
*& A GENERIC KEY IS THE WHOLE TRICK. This records ONE key entry per table per
*& journey - client plus journey id plus '*' - rather than one per row. On
*& import a generic key replaces every target row matching it with what the
*& request carries, so a journey that lost a field in development loses it in
*& quality too. No deletion log, no tracking table, nothing to keep in step:
*& for that journey the source system is simply the truth. It also matches
*& exactly what the Studio already does locally, which is delete every row of
*& the journey and insert the current set.
*&
*& THE ONE THING HERE THAT IS NOT VERIFIED. The CTS function module's name and
*& signature cannot be read from the environment this was written in, and
*& guessing at a standard SAP interface is what cost ZCL_RAK_CJ_REQ_CTX three
*& activations. So the call is DYNAMIC - CALL FUNCTION (name) PARAMETER-TABLE -
*& and every candidate name set is tried in turn inside CATCH cx_root. A wrong
*& guess is then a caught runtime error that returns a message, never a class
*& that will not activate and never a short dump in front of an author who was
*& only pressing Save.
*&
*& Run ZRAK_CJ_CTS_DIAG to print the candidates as this system declares them;
*& one run settles which row below is the right one.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   One row per (function, parameter-name set) to try, in order of preference.
*   K_TAB is how the two object tables are BOUND, not what they are called:
*   a classic TABLES parameter and an IMPORTING table of the same name need
*   different kinds, and passing the wrong one raises rather than misbehaves.
*
*   A plain comment, not ABAP Doc - the Class Builder rejects a "! block in
*   front of a TYPES: chain as "ABAP Doc comment is in the wrong position".
    TYPES: BEGIN OF ty_cand,
             fm     TYPE string,
             p_req  TYPE string,
             p_e071 TYPE string,
             p_key  TYPE string,
             k_tab  TYPE c LENGTH 1,
           END OF ty_cand.
    TYPES tt_cand TYPE STANDARD TABLE OF ty_cand WITH EMPTY KEY.

    "! Every CJS configuration table, header first so an import never has a
    "! child without its parent. ZRAK_T_MIG_RAW is deliberately absent: it is
    "! migration staging, not configuration, and nothing reads it at runtime.
    CLASS-METHODS tables
      RETURNING VALUE(rt) TYPE string_table.

    CLASS-METHODS candidates
      RETURNING VALUE(rt) TYPE tt_cand.

    "! Records one journey's whole configuration into IV_TRKORR.
    "! RV_MSG is blank on success and carries the reason on failure - the
    "! caller decides whether that is a warning or a refusal.
    CLASS-METHODS record_journey
      IMPORTING iv_trkorr     TYPE string
                iv_journey    TYPE string
      RETURNING VALUE(rv_msg) TYPE string.

    "! Which function module and name set answered. Set by the last
    "! RECORD_JOURNEY( ), read by the diagnostic report and by nothing else.
    CLASS-DATA gv_last_api TYPE string READ-ONLY.

  PRIVATE SECTION.

    CLASS-METHODS append_key
      IMPORTING iv_trkorr     TYPE string
                iv_table      TYPE string
                iv_key        TYPE string
      RETURNING VALUE(rv_msg) TYPE string.

ENDCLASS.


CLASS zcl_rak_cj_cts IMPLEMENTATION.


  METHOD tables.
*   ZRAK_CJ_LAYOUT is in this list and is the one most often forgotten - it is
*   the only config table whose key column is JOURNEY rather than JOURNEY_ID,
*   which is why it went missing from the migrator's teardown. It is also why
*   the generic key below is built from the journey id alone and not from a
*   column name: the same string is the second key field in all seven.
    rt = VALUE #( ( `ZRAK_T_JNY` )
                  ( `ZRAK_T_JNY_STEP` )
                  ( `ZRAK_T_JNY_FLD` )
                  ( `ZRAK_T_JNY_OPT` )
                  ( `ZRAK_T_JNY_COL` )
                  ( `ZRAK_T_JNY_RULE` )
                  ( `ZRAK_CJ_LAYOUT` ) ).
  ENDMETHOD.


  METHOD candidates.
*   TWO FUNCTIONS AND TWO NAME SETS, BECAUSE THE NAMES ARE THE GUESS.
*   The function names are safe enough - both are a documented way to put a
*   TABU key into a request - but whether the tables are WT_* or IT_*, and the
*   request WI_TRKORR or IV_TRKORR, cannot be read from here. Getting one wrong
*   is not a silent miss: a dynamic call naming a parameter the function does
*   not declare RAISES, so that row simply does not match and the next is tried.
*
*   THE WT_ ROWS BIND AS **TABLES** AND THE IT_ ROWS AS EXPORTING, which is the
*   half of this the Class Builder caught. A function module's parameter table
*   is ABAP_FUNC_PARMBIND_TAB and has its own kind for a classic TABLES
*   parameter; the "a TABLES parameter binds as CHANGING" rule is the METHOD
*   rule (ABAP_PARMBIND_TAB) and does not apply here. The WT_ shape is the
*   classic TABLES signature, the IT_ shape a modern importing table.
    rt = VALUE #(
      ( fm = `TR_APPEND_TO_COMM_OBJS_KEYS` p_req = `WI_TRKORR`
        p_e071 = `WT_E071` p_key = `WT_E071K` k_tab = abap_func_tables )
      ( fm = `TR_APPEND_TO_COMM_OBJS_KEYS` p_req = `IV_TRKORR`
        p_e071 = `IT_E071` p_key = `IT_E071K` k_tab = abap_func_exporting )
      ( fm = `TRINT_APPEND_COMM_OBJS_KEYS` p_req = `WI_TRKORR`
        p_e071 = `WT_E071` p_key = `WT_E071K` k_tab = abap_func_tables )
      ( fm = `TRINT_APPEND_COMM_OBJS_KEYS` p_req = `IV_TRKORR`
        p_e071 = `IT_E071` p_key = `IT_E071K` k_tab = abap_func_exporting ) ).
  ENDMETHOD.


  METHOD record_journey.
    CLEAR gv_last_api.

    IF iv_trkorr IS INITIAL.
      rv_msg = |no transport request given, so this change is NOT recorded - | &&
               |it stays in this client only|.
      RETURN.
    ENDIF.
    IF iv_journey IS INITIAL.
      rv_msg = |no journey given|.
      RETURN.
    ENDIF.

*   CLIENT FIRST, THEN THE JOURNEY, THEN A STAR. TABKEY is the key fields
*   concatenated in DDIC order, and all seven of these tables are MANDT(3) +
*   ZRAK_JOURNEY_ID(30) + ..., so client plus journey plus '*' selects exactly
*   that journey's rows and nothing else. The star is what makes the import a
*   replace rather than a merge, which is the entire point of this class.
*
*   PADDED, AND THAT IS NOT COSMETIC. TABKEY is FIXED WIDTH per key field, so
*   the journey occupies all thirty characters whether it needs them or not.
*   Written unpadded as |600D001*| the key is a prefix match on "600D001" -
*   which would also carry away a journey called D0012, silently, on import
*   into a system where one exists. Offsets into a character field pad with
*   blanks; a string template does not, because converting a type C field to
*   a string strips the trailing blanks that are the whole point here.
    DATA lv_tabkey TYPE e071k-tabkey.
    DATA lv_jid    TYPE zrak_journey_id.

    lv_jid = to_upper( iv_journey ).

    CLEAR lv_tabkey.
    lv_tabkey(3)     = sy-mandt.
    lv_tabkey+3(30)  = lv_jid.
    lv_tabkey+33(1)  = '*'.

    DATA(lv_key) = CONV string( lv_tabkey ).

    DATA(lt_tab) = tables( ).
    LOOP AT lt_tab INTO DATA(lv_tab).
      DATA(lv_err) = append_key( iv_trkorr = iv_trkorr
                                 iv_table  = lv_tab
                                 iv_key    = lv_key ).
      IF lv_err IS NOT INITIAL.
*       The first failure stops the run. A request holding four of seven tables
*       is worse than one holding none: it would import a journey with its
*       fields replaced and its rules left as they were - a shape nobody
*       designed and nobody would expect to debug.
        rv_msg = |{ lv_tab }: { lv_err }|.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_key.

*   DYNAMIC, AND THAT IS THE POINT. CALL FUNCTION with a literal name still
*   activates when the function does not exist - names resolve at runtime - but
*   a PARAMETER MISMATCH is then a short dump rather than something catchable.
*   The dynamic form with PARAMETER-TABLE raises CX_SY_DYN_CALL_* instead, which
*   the CATCH below turns into a message.
*
*   ABAP_FUNC_PARMBIND_TAB, NOT ABAP_PARMBIND_TAB. They look interchangeable
*   and are not: the second is for CALL METHOD and the Class Builder refuses it
*   here outright ("the type of LT_PARM must be compatible with
*   ABAP_FUNC_PARMBIND_TAB"). The difference that matters is that the function
*   family has a real TABLES kind, so a classic TABLES parameter is bound as
*   one rather than squeezed in as CHANGING.
    DATA lt_e071  TYPE STANDARD TABLE OF e071  WITH EMPTY KEY.
    DATA lt_e071k TYPE STANDARD TABLE OF e071k WITH EMPTY KEY.

    APPEND VALUE #( pgmid    = 'R3TR'
                    object   = 'TABU'
                    obj_name = iv_table ) TO lt_e071.

    APPEND VALUE #( pgmid      = 'R3TR'
                    object     = 'TABU'
                    objname    = iv_table
                    mastertype = 'TABU'
                    mastername = iv_table
                    tabkey     = iv_key ) TO lt_e071k.

    DATA lv_order TYPE trkorr.
    lv_order = iv_trkorr.

    DATA lt_parm TYPE abap_func_parmbind_tab.
    DATA lt_exc  TYPE abap_func_excpbind_tab.
    DATA lo_err  TYPE REF TO cx_root.
    DATA lv_last TYPE string.

*   EXCEPTION-TABLE, NOT OMITTED. Without it a classic exception raised by the
*   function is an uncatchable runtime error; with OTHERS mapped it comes back
*   as SY-SUBRC and is reported like any other refusal.
    lt_exc = VALUE #( ( name = 'OTHERS' value = 4 ) ).

    DATA(lt_cand) = candidates( ).
    LOOP AT lt_cand INTO DATA(ls_c).
      TRY.
          CLEAR lt_parm.
          lt_parm = VALUE #(
            ( name  = ls_c-p_req
              kind  = abap_func_exporting
              value = REF #( lv_order ) )
            ( name  = ls_c-p_e071
              kind  = ls_c-k_tab
              value = REF #( lt_e071 ) )
            ( name  = ls_c-p_key
              kind  = ls_c-k_tab
              value = REF #( lt_e071k ) ) ).

          CALL FUNCTION ls_c-fm
            PARAMETER-TABLE lt_parm
            EXCEPTION-TABLE lt_exc.

          IF sy-subrc <> 0.
            lv_last = |{ ls_c-fm } refused with subrc { sy-subrc }|.
            CONTINUE.
          ENDIF.

          gv_last_api = |{ ls_c-fm }( { ls_c-p_req } )|.
          CLEAR rv_msg.
          RETURN.

        CATCH cx_root INTO lo_err.
*         Try the next row. Only the LAST failure is reported: "that function
*         does not exist" is noise on a system where another candidate does.
          lv_last = |{ ls_c-fm }: { lo_err->get_text( ) }|.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    rv_msg = COND string(
      WHEN lv_last IS NOT INITIAL
      THEN |no CTS function accepted the call - { lv_last }. | &&
           |Run ZRAK_CJ_CTS_DIAG to see what this system declares|
      ELSE |no CTS function module available on this system| ).
  ENDMETHOD.


ENDCLASS.
