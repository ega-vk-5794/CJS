REPORT zrak_cj_cts_diag.

*&---------------------------------------------------------------------*
*& WHICH CTS FUNCTION THIS SYSTEM HAS, AND WHAT IT CALLS ITS PARAMETERS
*&
*& ZCL_RAK_CJ_CTS guesses at a standard interface it could not read from
*& where it was written, and tries four (function, name set) rows in turn.
*& That degrades safely, but it degrades in silence: nobody finds out which
*& row answered unless they ask. This asks.
*&
*& It prints, for every candidate, the function's own declared parameters as
*& FUPARAREF holds them - name, kind, type, optional - so one run replaces
*& the whole guess with a fact. Cut CANDIDATES( ) down to the row that works
*& afterwards and the runtime stops trying the others.
*&
*& NOTHING HERE WRITES. The optional test below appends a real key to a real
*& request and is off unless asked for, because a diagnostic that modifies a
*& transport is not a diagnostic.
*&---------------------------------------------------------------------*

PARAMETERS p_test AS CHECKBOX DEFAULT ' '.
PARAMETERS p_trk  TYPE trkorr.
PARAMETERS p_jny  TYPE c LENGTH 20.

START-OF-SELECTION.

  DATA lt_seen TYPE STANDARD TABLE OF string WITH EMPTY KEY.

  WRITE: / 'CTS candidates as this system declares them'.
  ULINE.

  DATA(lt_cand) = zcl_rak_cj_cts=>candidates( ).
  LOOP AT lt_cand INTO DATA(ls_c).

*   One function can appear on several rows (two name sets each), and its
*   signature does not change between them - print it once.
    IF line_exists( lt_seen[ table_line = ls_c-fm ] ).
      CONTINUE.
    ENDIF.
    APPEND ls_c-fm TO lt_seen.

    DATA lv_fname TYPE rs38l-name.
    lv_fname = ls_c-fm.

    SELECT SINGLE funcname FROM tfdir
      WHERE funcname = @lv_fname
      INTO @DATA(lv_hit).
    IF sy-subrc <> 0.
      WRITE: / ls_c-fm, '-- DOES NOT EXIST on this system'.
      SKIP.
      CONTINUE.
    ENDIF.

    WRITE: / ls_c-fm, '-- exists'.

*   FUPARAREF is the function's own parameter list. PARAMTYPE is the kind:
*   I importing, E exporting, C changing, T tables, X exceptions.
    SELECT parameter, paramtype, structure, optional
      FROM fupararef
      WHERE funcname = @lv_fname
      ORDER BY paramtype, parameter
      INTO TABLE @DATA(lt_p).
    IF sy-subrc <> 0.
      WRITE: /4 '(no parameters read from FUPARAREF)'.
      SKIP.
      CONTINUE.
    ENDIF.

    LOOP AT lt_p INTO DATA(ls_p).
      WRITE: /4 ls_p-paramtype,
              7 ls_p-parameter,
             42 ls_p-structure,
             75 COND string( WHEN ls_p-optional = 'X' THEN 'optional' ).
    ENDLOOP.
    SKIP.
  ENDLOOP.

  ULINE.
  WRITE: / 'Tables ZCL_RAK_CJ_CTS records per journey:'.
  DATA(lt_t) = zcl_rak_cj_cts=>tables( ).
  LOOP AT lt_t INTO DATA(lv_t).
    WRITE: /4 lv_t.
  ENDLOOP.

  IF p_test = abap_false.
    SKIP.
    WRITE: / 'Tick the test box with a request and a journey to actually record one.'.
    RETURN.
  ENDIF.

  IF p_trk IS INITIAL OR p_jny IS INITIAL.
    SKIP.
    WRITE: / 'Test needs both a request and a journey.'.
    RETURN.
  ENDIF.

  SKIP.
  ULINE.
  DATA(lv_msg) = zcl_rak_cj_cts=>record_journey( iv_trkorr  = CONV string( p_trk )
                                                 iv_journey = CONV string( p_jny ) ).
  IF lv_msg IS INITIAL.
    WRITE: / 'Recorded. Answered by:', zcl_rak_cj_cts=>gv_last_api.
    WRITE: / 'Check SE01 ->', p_trk, '-> the seven TABU entries and their keys.'.
  ELSE.
    WRITE: / 'Not recorded:', lv_msg.
  ENDIF.
