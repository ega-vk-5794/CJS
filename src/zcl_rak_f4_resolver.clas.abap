CLASS zcl_rak_f4_resolver DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Resolves F4 options for a config field, in this order:
    "! 1. domname -> domain fixed values (DD07L/DD07T) - direct
    "! 2. rollname -> domain fixed values behind the data element
    "! 3. rollname -> data element's own default search help (DD04L-SHLPNAME)
    "! 4. explicit shlp -> F4IF hit list (collective helps: first elementary)
    "! Returns empty table when nothing resolves - caller falls back to input.
*   The row cap, and it is public so a caller can tell a full list from a cut
*   one. Every SELECT / SHLP / DOMAIN read below is UP TO IV_MAX ROWS, and a
*   truncated list looks exactly like a complete one on screen.
*
*   Was 50. That is fine for a status domain and wrong for anything real: there
*   are about 250 countries and as many nationalities, so a nationality field
*   pointed at T005T silently offered the first 50 and the citizen could not pick
*   their own country. 500 clears every DDIC list this engine asks for while
*   still refusing to pull an unbounded table into a dropdown.
    CONSTANTS c_max TYPE i VALUE 500.

    METHODS resolve
      IMPORTING iv_rollname       TYPE string OPTIONAL
                iv_shlp           TYPE string OPTIONAL
                iv_domname        TYPE string OPTIONAL
                iv_max            TYPE i DEFAULT c_max
      RETURNING VALUE(rt_options) TYPE zif_rak_journey=>tt_option.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache,
        id      TYPE string,
        options TYPE zif_rak_journey=>tt_option,
      END OF ty_cache.
    " per-request cache only: the engine's private refs are not serialized
    " between z2ui5 round-trips, so this instance lives for one request.
    " Still pays off when several fields share a rollname/shlp/domain.
    DATA mt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY id.

    METHODS from_rollname
      IMPORTING iv_rollname TYPE string
                iv_max      TYPE i
      RETURNING VALUE(rt)   TYPE zif_rak_journey=>tt_option.
    METHODS from_domain
      IMPORTING iv_domname TYPE domname
                iv_max     TYPE i
      RETURNING VALUE(rt)  TYPE zif_rak_journey=>tt_option.
    METHODS from_shlp
      IMPORTING iv_shlp   TYPE string
                iv_max    TYPE i
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
ENDCLASS.



CLASS ZCL_RAK_F4_RESOLVER IMPLEMENTATION.


  METHOD from_domain.
    SELECT a~domvalue_l AS key, b~ddtext AS text
      FROM dd07l AS a
      LEFT JOIN dd07t AS b
        ON  b~domname    = a~domname
        AND b~valpos     = a~valpos
        AND b~as4local   = a~as4local
        AND b~ddlanguage = @sy-langu
      WHERE a~domname  = @iv_domname
        AND a~as4local = 'A'
      ORDER BY a~valpos
      INTO TABLE @DATA(lt) UP TO @iv_max ROWS.
    LOOP AT lt INTO DATA(ls).
      APPEND VALUE #(
        key  = ls-key
        text = COND #( WHEN ls-text IS NOT INITIAL THEN ls-text ELSE ls-key )
      ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD from_rollname.
    SELECT SINGLE domname, shlpname
      FROM dd04l
      WHERE rollname = @iv_rollname
        AND as4local = 'A'
      INTO ( @DATA(lv_dom), @DATA(lv_shlp) ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF lv_dom IS NOT INITIAL.
      rt = from_domain( iv_domname = lv_dom iv_max = iv_max ).
    ENDIF.

    " no fixed values -> fall through to the data element's default shlp
    IF rt IS INITIAL AND lv_shlp IS NOT INITIAL.
      rt = from_shlp( iv_shlp = CONV #( lv_shlp ) iv_max = iv_max ).
    ENDIF.
  ENDMETHOD.


  METHOD from_shlp.
    DATA ls_shlp TYPE shlp_descr.
    DATA lt_rec  TYPE STANDARD TABLE OF seahlpres.

    TRY.
        CALL FUNCTION 'F4IF_GET_SHLP_DESCR'
          EXPORTING
            shlpname = CONV shlpname( iv_shlp )
          IMPORTING
            shlp     = ls_shlp.

        " collective search help: expand and take the first elementary one.
        " Good enough for a dropdown; a real multi-tab F4 needs a popup UX
        " (candidate for a later engine popup, same pattern as the BP dialog).
        DATA lt_exp TYPE shlp_desct.
        IF ls_shlp-shlptype = 'CT'.
          CALL FUNCTION 'F4IF_EXPAND_SEARCHHELP'
            EXPORTING
              shlp_top = ls_shlp
            IMPORTING
              shlp_tab = lt_exp.
          IF lt_exp IS INITIAL.
            RETURN.
          ENDIF.
          ls_shlp = lt_exp[ 1 ].
        ENDIF.

        " fetch the hit list (this was accidentally dropped in an edit -
        " without it lt_rec stays empty and the dropdown gets no options)
        DATA lv_max TYPE i.
        lv_max = COND #( WHEN iv_max > 0 THEN iv_max ELSE 200 ).
        CALL FUNCTION 'F4IF_SELECT_VALUES'
          EXPORTING
            shlp           = ls_shlp
            maxrows        = lv_max
            call_shlp_exit = 'X'
          TABLES
            record_tab     = lt_rec.

        " -----------------------------------------------------------
        " Read KEY + TEXT straight from record_tab-string.
        " The hit list packs each row as  <KEY><spaces><DESCRIPTION>
        " (debugger LT_REC-STRING: "1    Abu Dhabi", "6    Ras Al-Khaimah").
        " No separate output column and no reliable field offsets here
        " (the search-help exit builds the rows), so DON'T compute offsets:
        " split on the first run of whitespace -> token1 = key, rest = text.
        " -----------------------------------------------------------
        LOOP AT lt_rec INTO DATA(ls_rec).
          DATA(lv_s) = condense( CONV string( ls_rec-string ) ).
          IF lv_s IS INITIAL.
            CONTINUE.
          ENDIF.
          DATA lv_key TYPE string.
          DATA lv_txt TYPE string.
          SPLIT lv_s AT space INTO lv_key lv_txt.
          lv_key = condense( lv_key ).
          lv_txt = condense( lv_txt ).          " collapses the padding gap
          IF lv_key IS INITIAL.
            CONTINUE.
          ENDIF.
          APPEND VALUE #(
            key  = lv_key
            text = COND #( WHEN lv_txt IS NOT INITIAL THEN lv_txt ELSE lv_key )
          ) TO rt.
        ENDLOOP.

      CATCH cx_root.
        " shlp exits / exotic helps can throw - fail soft, field stays a plain input
        CLEAR rt.
    ENDTRY.
  ENDMETHOD.


  METHOD resolve.
    DATA(lv_id) = |D:{ to_upper( iv_domname ) }/R:{ to_upper( iv_rollname ) }/S:{ to_upper( iv_shlp ) }|.
    READ TABLE mt_cache INTO DATA(ls_c) WITH TABLE KEY id = lv_id.
    IF sy-subrc = 0.
      rt_options = ls_c-options.
      RETURN.
    ENDIF.

    IF iv_domname IS NOT INITIAL.
      rt_options = from_domain( iv_domname = CONV #( to_upper( iv_domname ) )
                                iv_max     = iv_max ).
    ENDIF.
    IF rt_options IS INITIAL AND iv_rollname IS NOT INITIAL.
      rt_options = from_rollname( iv_rollname = to_upper( iv_rollname )
                                  iv_max      = iv_max ).
    ENDIF.
    IF rt_options IS INITIAL AND iv_shlp IS NOT INITIAL.
      rt_options = from_shlp( iv_shlp = to_upper( iv_shlp )
                              iv_max  = iv_max ).
    ENDIF.

    INSERT VALUE #( id = lv_id options = rt_options ) INTO TABLE mt_cache.
  ENDMETHOD.
ENDCLASS.
