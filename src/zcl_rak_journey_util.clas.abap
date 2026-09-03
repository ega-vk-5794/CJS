CLASS zcl_rak_journey_util DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
*   Stateless helpers lifted out of ZCL_RAK_JOURNEY_ENGINE. Every method here
*   was verified to touch no engine attribute, which is why they are static and
*   why this class carries no reference back to the engine. Anything that needs
*   engine state does NOT belong here.

    CLASS-METHODS esc IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS esc_js IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS to_dats IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS opt_text
      IMPORTING iv_key    TYPE string
                iv_text   TYPE string
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS is_block    IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS is_scratch  IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS known_type  IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS open_url_html IMPORTING iv_url TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS att_url IMPORTING iv_guid TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS row_key     IMPORTING is_field TYPE zif_rak_journey=>ty_field RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ctrl_width IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rv) TYPE string.

*   Language fallback (Arabic when IV_LANG = 'A' and the Arabic text is
*   filled, English otherwise) plus OTR:<alias> resolution, lifted out of
*   ZCL_RAK_JOURNEY_REPO~PICK( ) so a bilingual pair that never passes
*   through REPO - ZRAK_T_JNY_COL's ZLABEL/ZLABEL_AR, read directly by
*   ZCL_RAK_JOURNEY_GRID - can still resolve an OTR alias instead of being
*   frozen at whatever was last typed into the Studio. PICK( ) itself now
*   delegates here rather than duplicating the logic.
    CLASS-METHODS pick_text
      IMPORTING iv_en     TYPE clike
                iv_ar     TYPE clike
                iv_lang   TYPE sy-langu
      RETURNING VALUE(rv) TYPE string.

*   OTR:<alias> resolution on its own, lifted out of PICK_TEXT( ) so a text
*   that has already been picked EN/AR - one clause of a per-check MSG, below -
*   can still resolve an alias without going back through a bilingual pair it
*   no longer has. PICK_TEXT( ) calls this rather than keeping a second copy.
*   A missing concept returns the stored literal, prefix and all, so a wrong
*   alias is a visible "OTR:..." on screen rather than a blank nobody can
*   explain.
    CLASS-METHODS otr_text
      IMPORTING VALUE(iv_text) TYPE string
                VALUE(iv_lang) TYPE sy-langu
      RETURNING VALUE(rv)      TYPE string.

*   ONE MESSAGE COLUMN, SEVERAL CHECKS - and now a wording for each.
*
*   ZRAK_T_JNY_FLD-MSG / MSG_AR is read as the message for MISSING_REQUIRED,
*   for MIN_VAL / MAX_VAL, for the numeric CATCH and for REGEX. The checks
*   never fire together - required needs a BLANK value and the rest need a
*   filled one - so this was never a functional bug, only a wording one: a
*   field that is both REQUIRED and format-constrained had one column and two
*   sentences to write in it. Whichever wording went in, the other check
*   borrowed it and said the wrong thing.
*
*   MSG may therefore now carry per-check clauses:
*
*     REQUIRED:Please state the number of wives;FORMAT:@201
*
*   Recognised keys: REQUIRED, LEN, RANGE, NUMBER, FORMAT, and '*' as a
*   catch-all for any check with no clause of its own. Clauses are separated by
*   ';' and each is KEY:text, split on its FIRST colon - so a clause's text may
*   itself be 'OTR:<alias>' or '@nnn', the ZRAK_T_CJ_TXT reference a TABLE
*   column header already takes (COL_HEADER( )). Both resolve per round trip and
*   per language, which is what lets a migrated WD message keep its own OTR
*   concept on the FORMAT check while REQUIRED keeps its own words.
*
*   ADDITIVE, AND THE GUARD IS DELIBERATELY NARROW. The keyed form is only
*   recognised when the text BEGINS with one of those keys immediately followed
*   by ':'. Anything else - every MSG configured today, an OTR: alias on the
*   whole column, an ordinary sentence containing a colon or a semicolon - is
*   returned unchanged to every check that reads MSG today, so a journey that
*   sets nothing new sees no change at all.
*
*   IV_KEYED_ONLY is for the checks that do NOT read MSG today (MIN_LEN /
*   MAX_LEN). There, a plain MSG must keep being ignored - honouring it would
*   silently retitle every existing length message - but an explicit 'LEN:'
*   clause is a new instruction and is honoured. A blank return means "nothing
*   configured for this check": the caller falls back to the catalogue exactly
*   as it does today.
    CLASS-METHODS msg_for
      IMPORTING VALUE(iv_msg)        TYPE string
                VALUE(iv_check)      TYPE string
                VALUE(iv_journey)    TYPE string    OPTIONAL
                VALUE(iv_lang)       TYPE sy-langu  OPTIONAL
                VALUE(iv_keyed_only) TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv)            TYPE string.

*   A field name, made safe to be an ABAP structure component: upper case, only
*   letters digits and underscore, never longer than 23 (so BUILD_MODEL( )'s
*   companions - _VS, _VST, _IDTYPE, _NAME, _IX, _EXP - all still fit inside the
*   30-character cap). Same algorithm as ZCL_RAK_BE_NOT~MODEL_NAME( ), which
*   exists for the same reason on Notary's own dynamic business-object fields -
*   copied rather than shared, so a change here cannot regress that already-
*   proven path. BUILD_MODEL( ) builds one ABAP component per configured field
*   name; a field named with a character outside [A-Z0-9_], or one over 30
*   characters once its companions are appended, raises CX_SY_STRUCT_COMP_NAME
*   uncaught - the whole Studio preview or app dies with "UNCAUGHT EXCEPTION -
*   Please Restart App" for every journey, not only the one field at fault.
*   VALUE( ), not plain IMPORTING. A method's IMPORTING parameter is passed BY
*   REFERENCE by default, and by reference demands type COMPATIBILITY - so a
*   DDIC character field (ZRAK_T_JNY_COL-COL_NAME, ZRAK_T_JNY_FLD-NAME, and
*   every other config column this is called with) cannot be handed to a TYPE
*   string parameter at all: "is not type-compatible with formal parameter".
*   VALUE( ) passes by value, which converts.
    CLASS-METHODS comp_name IMPORTING VALUE(iv_key) TYPE string
                             RETURNING VALUE(rv)     TYPE string.

*   The country list, keyed by T005T-LAND1 and texted in the logon language.
*
*   ONE source, because a nationality has to survive three hops that were each
*   using a different vocabulary: the dropdown the citizen picks from, the value
*   ZFE_CJ_SEARCH_BP_BY_ID fills in after a BP search, and whatever is written to
*   the owner row and posted. D001 hand-maintained 106 items keyed '1' to '106'
*   while the BP search wrote the nationality TEXT into the same field - so the
*   key never matched, the combobox rendered unselected, and the column saved
*   blank. United Arab Emirates was not in the hand-written list at all.
*
*   LAND1 is the key that makes the three agree: it is what T005T is keyed on and
*   what ZFE_CJ_SEARCH_BP_BY_ID returns as EV_NATIONALITY_KEY (BU_NATIO).
*
*   Lifted from ZCL_RAK_BP_POPUP->NATIONALITIES( ), which now delegates here
*   rather than holding a second copy - the same move PICK_TEXT( ) made.
    CLASS-METHODS nationalities
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   Addressing a grid row by COLUMN NAME instead of by position.
*
*   Every handler that maintains a grid from a popup has written its row as a run
*   of APPENDs in a fixed order, and every one of them has been wrong, because the
*   row's real width is ZRAK_T_JNY_COL - or, with no rows there, the DEFAULT_VAL
*   spec - and not the length of that run. SET_GRID_DATA( ) walks the CONFIGURED
*   columns and takes cell N from the row, so a run longer or shorter than the
*   spec puts every value in a neighbour's column and drops the tail.
*
*   It is close to invisible, which is why it survived: the hand-drawn list reads
*   the same positions back, so the screen looks right, and only the POST - which
*   reads the columns by NAME - sees the shift. D004 stored the owner's Emirates
*   ID in SHARE_PER that way, and the backend refused the step with "The Total of
*   the Share (0.00%) is not equal to 100%" while the list showed 100.
*
*   Here rather than in ZCL_RAK_JOURNEY_LOGIC so a handler can use it without a
*   redefinition, and so the grid renderer can use it too.
    CLASS-METHODS col_ix
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
                iv_name   TYPE string
      RETURNING VALUE(rv) TYPE i.

    CLASS-METHODS cell_of
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
                it_row    TYPE zif_rak_journey=>tt_string
                iv_name   TYPE string
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS put_cell
      IMPORTING it_cols TYPE zif_rak_journey=>tt_string
                iv_name TYPE string
                iv_val  TYPE string
      CHANGING  ct_row  TYPE zif_rak_journey=>tt_string.

*   A row sized to the spec, every cell blank. Start here, then PUT_CELL( ) by
*   name - never APPEND, which is what shifts the neighbours.
    CLASS-METHODS blank_row
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

  PRIVATE SECTION.

*   The recognised per-check keys of a keyed MSG. See MSG_FOR( ).
    CLASS-METHODS msg_key
      IMPORTING VALUE(iv_key) TYPE string
      RETURNING VALUE(rv)     TYPE abap_bool.

*   One clause's text, with 'OTR:<alias>' and '@nnn' resolved. Anything else
*   comes back exactly as configured.
    CLASS-METHODS msg_token
      IMPORTING VALUE(iv_raw)     TYPE string
                VALUE(iv_lang)    TYPE sy-langu
                VALUE(iv_journey) TYPE string OPTIONAL
      RETURNING VALUE(rv)         TYPE string.

ENDCLASS.



CLASS ZCL_RAK_JOURNEY_UTIL IMPLEMENTATION.


  METHOD att_url.
*   The single place the streaming ICF node is named. Kept RELATIVE: an absolute
*   host breaks on E30 and open_new_tab rejects cross-domain absolute URLs.
    rv = |/sap/bc/rest/cjattviewer?guid={ iv_guid }|.
  ENDMETHOD.


  METHOD ctrl_width.
*   Per-field width from config is NOT wired up yet - the type defaults below are
*   the only source. To enable it, add CTRL_WIDTH to ZIF_RAK_JOURNEY=>TY_FIELD,
*   add the DDIC column, read it in the config loader, then reinstate:
*     IF is_field-ctrl_width IS NOT INITIAL.
*       rv = is_field-ctrl_width.
*       RETURN.
*     ENDIF.
*   Blank must fall through to the CASE, so journeys authored before the column
*   existed keep rendering identically. Constrain authored values to % or rem:
*   a hard px width will not collapse on a phone and is the one way to break the
*   responsive layout from config.
    CASE is_field-type.
*     Controls with no usable width property, or already at 100%. RATING was
*     here returning 10rem, which was dead: sap.m.RatingIndicator has no width
*     (it scales via iconSize), so the value could never be applied.
      WHEN 'TEXTAREA' OR 'SLIDER' OR 'PROGRESS' OR 'RATING'.
        rv = ''.
      WHEN 'DATE' OR 'TIME' OR 'DATETIME'.
        rv = '11rem'.
      WHEN 'NUMBER' OR 'STEPPER' OR 'CURRENCY'.
        rv = '10rem'.
      WHEN 'PHONE'.
        rv = '13rem'.
      WHEN 'SELECT' OR 'MULTISELECT'.
        rv = '18rem'.
*     RADIO inherited SELECT's 18rem, which was harmless while the value was
*     never passed. It is passed now, and 18rem is narrower than four inline
*     options need - the group wrapped. Full width, let the options flow.
      WHEN 'RADIO'.
        rv = '100%'.
      WHEN 'EMAIL'.
        rv = '22rem'.
      WHEN OTHERS.
        rv = '24rem'.
    ENDCASE.
  ENDMETHOD.


  METHOD esc.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD esc_js.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `\'`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `\"`.
  ENDMETHOD.


  METHOD is_block.
    rv = xsdbool( iv_type = 'SEARCH' OR iv_type = 'TABLE'
               OR iv_type = 'UPLOAD' OR iv_type = 'PAYFEE'
               OR iv_type = 'EDITABLE_TABLE' OR iv_type = 'RECORDCARD'
               OR iv_type = 'REQPANEL' OR iv_type = 'PDF' ).
  ENDMETHOD.


  METHOD is_scratch.
    DATA(lv_n) = to_upper( iv_name ).
*   _IX joins the framework-owned suffixes: it carries a RADIO's selected index
*   and an authored field of that name would collide with it.
    rv = xsdbool( lv_n = 'PAYFEE' OR lv_n CP 'PAY_*' OR lv_n CP '*_IX' OR lv_n CP '*_SEL' ).
  ENDMETHOD.


  METHOD known_type.
    rv = xsdbool( iv_type = '' OR iv_type = 'INPUT' OR iv_type = 'EMAIL' OR iv_type = 'PHONE'
      OR iv_type = 'NUMBER' OR iv_type = 'COUNT' OR iv_type = 'CURRENCY' OR iv_type = 'TEXTAREA' OR iv_type = 'DATE'
      OR iv_type = 'TIME' OR iv_type = 'DATETIME' OR iv_type = 'SELECT' OR iv_type = 'MULTISELECT'
      OR iv_type = 'RADIO' OR iv_type = 'CHECKBOX' OR iv_type = 'SWITCH' OR iv_type = 'SEGMENTED'
      OR iv_type = 'SLIDER' OR iv_type = 'STEPPER' OR iv_type = 'RATING' OR iv_type = 'DISPLAY'
      OR iv_type = 'READONLY' OR iv_type = 'STATUS' OR iv_type = 'OBJNUM' OR iv_type = 'PROGRESS'
      OR iv_type = 'LINK' OR iv_type = 'SEARCH' OR iv_type = 'TABLE' OR iv_type = 'UPLOAD'
      OR iv_type = 'PAYFEE' OR iv_type = 'EDITABLE_TABLE' OR iv_type = 'CHECKGROUP'
      OR iv_type = 'REVIEW' OR iv_type = 'RO_PANEL' OR iv_type = 'RECORDCARD'
      OR iv_type = 'REQPANEL'
*     The composite ftypes ZCL_RAK_MIGRATOR->CLASSIFY( ) assigns to the
*     ShapeIt controls that are not plain fields. They render through the
*     SELECT branch, off an API: binding in DEFAULT_VAL - see
*     ZCL_RAK_CJ_OPTS. Listed here so the engine's own unknown-type warning
*     stops firing on every migrated Municipality journey; a genuinely
*     unserved one still reports itself, on the field, through the note
*     ZCL_RAK_CJ_OPTS returns.
*     PARCELS IS THE MULTI-SELECT ONE AND IT WAS MISSING HERE. There are
*     THREE places an ftype has to be named and this is the third: the
*     renderer's SELECT branch (ZCL_RAK_JOURNEY_RENDER, so the field draws
*     at all), the parcel control's own condition (so the card list is
*     drawn instead of a dropdown) - both of which had it - and this list,
*     which only drives CHECK_TYPES( )'s warning.
*
*     So the symptom was cosmetic and misleading in equal measure: M012
*     drew its checkbox cards correctly AND reported "Field PARCELSELECTOR:
*     unsupported type 'PARCELS' - rendered as a plain input" above them.
*     The warning was wrong, the render was right, and the two together
*     read as the control having failed.
*
*     RE-APPLIED ONCE ALREADY. This line was added in 7f37019 and removed
*     again by a Stage from SAP, because the object was staged before it
*     was pulled - the exact hazard CLAUDE.md's abapGit section describes,
*     and the second time it has happened on this project. If the warning
*     comes back, check the stage history before re-diagnosing the code.
      OR iv_type = 'PARCELS'
      OR iv_type = 'PARCEL' OR iv_type = 'PROPERTY' OR iv_type = 'TITLEDEED'
      OR iv_type = 'FLOORUNIT' OR iv_type = 'CONTRACT' OR iv_type = 'BUILDINGS'
      OR iv_type = 'SIGN' OR iv_type = 'CHEMICALS'
      OR iv_type = 'ACCOM' OR iv_type = 'BOATS' ).
  ENDMETHOD.


  METHOD open_url_html.
    DATA(lv_js) = |window.open('| && esc_js( iv_url ) && |','_blank');this.remove();|.
    DATA(lv_html) = |<div><img src="data:," style="display:none" onerror="| && lv_js && |"/></div>|.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    rv = lv_html.
  ENDMETHOD.


  METHOD opt_text.
    rv = COND #( WHEN iv_text IS INITIAL THEN iv_key ELSE iv_text ).
  ENDMETHOD.


  METHOD row_key.
*   Returns the field's side-by-side row token, read from two sources in this
*   order. Blank means the field starts a row of its own, which is the pre-change
*   behaviour, so every journey authored before this renders identically.
*
*   1. '+' when SAME_ROW is set on the field - join the previous field's row
*      unconditionally. The component does NOT exist on TY_FIELD yet, which is
*      why it is read through ASSIGN COMPONENT instead of is_field-same_row:
*      that compiles today and starts working the moment the component and its
*      DDIC column are added, with no further change in this class. Do not
*      convert it to a direct component read until ZIF_RAK_JOURNEY carries it.
*      Values 0 and N count as not set so a CHAR1 flag column can be filled
*      either way round.
*
*   2. The GROUP value itself when it is prefixed ROW: - the no-DDIC path, so a
*      two-up row can be authored from the config tables as they stand today.
*      Consecutive fields carrying the same ROW: value share one row and the
*      group emits no core:Title. The trade-off: such a field cannot also sit
*      under a titled group, because GROUP is doing both jobs. Treat this as the
*      interim path and SAME_ROW as the target.
*
*   Never mix the two sources inside one row - source 1 joins whatever came
*   before it, source 2 joins only a matching token, and a '+' field following a
*   ROW: field will join it, which is probably not what was meant.
    DATA lv_raw TYPE string.
    FIELD-SYMBOLS <lv_sr> TYPE any.
    ASSIGN COMPONENT 'SAME_ROW' OF STRUCTURE is_field TO <lv_sr>.
    IF sy-subrc = 0.
*     Plain assignment, not a string template: <lv_sr> is generically typed and a
*     template needs the type at compile time. Wrapped because a render dump
*     takes the whole journey down, and nothing here can prove the component is
*     elementary until it exists.
      TRY.
          lv_raw = <lv_sr>.
        CATCH cx_root.
          CLEAR lv_raw.
      ENDTRY.
      DATA(lv_sr) = to_upper( condense( lv_raw ) ).
      IF lv_sr IS NOT INITIAL AND lv_sr <> '0' AND lv_sr <> 'N'.
        rv = '+'.
        RETURN.
      ENDIF.
    ENDIF.
    DATA(lv_grp) = to_upper( condense( is_field-group ) ).
    IF strlen( lv_grp ) > 4 AND lv_grp(4) = 'ROW:'.
      rv = lv_grp.
    ENDIF.
  ENDMETHOD.


  METHOD to_dats.
*   Normalize a picker date string to internal yyyymmdd. Accepts ISO (yyyy-mm-dd),
*   ABAP DATS (yyyymmdd) and day-first locale forms (dd.mm.yyyy / dd/mm/yyyy /
*   dd-mm-yyyy). ISO and day-first with '-' are told apart by separator position.
*   Returns empty when the value cannot be parsed unambiguously (incl. month-first
*   or partial dates), so callers skip - never falsely reject - such a value.
    DATA(lv) = condense( iv ).
    IF lv IS INITIAL.
      RETURN.
    ENDIF.
    DATA lv_y TYPE string.
    DATA lv_m TYPE string.
    DATA lv_d TYPE string.
    IF strlen( lv ) = 8 AND lv CO '0123456789'.
      lv_y = lv(4). lv_m = lv+4(2). lv_d = lv+6(2).
    ELSEIF strlen( lv ) = 10 AND lv+4(1) = '-' AND lv+7(1) = '-'.
      lv_y = lv(4). lv_m = lv+5(2). lv_d = lv+8(2).
    ELSEIF strlen( lv ) = 10
       AND ( lv+2(1) = '.' OR lv+2(1) = '/' OR lv+2(1) = '-' )
       AND lv+2(1) = lv+5(1).
      lv_d = lv(2). lv_m = lv+3(2). lv_y = lv+6(4).
    ELSE.
      RETURN.
    ENDIF.
    IF lv_y CO '0123456789' AND lv_m CO '0123456789' AND lv_d CO '0123456789'.
      DATA(lv_mm) = CONV i( lv_m ).
      DATA(lv_dd) = CONV i( lv_d ).
      IF lv_mm BETWEEN 1 AND 12 AND lv_dd BETWEEN 1 AND 31.
        rv = |{ lv_y }{ lv_m }{ lv_d }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD comp_name.
    DATA(lv) = to_upper( condense( iv_key ) ).

*   Anything that is not a letter, a digit or an underscore cannot be in a
*   component name either - a hyphen, a dot, a space, all raise the same
*   exception with a different offending character.
    DATA lv_out TYPE string.
    DATA lv_i   TYPE i.
    CONSTANTS lc_ok TYPE string
      VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.

    WHILE lv_i < strlen( lv ).
      DATA(lv_c) = lv+lv_i(1).
      IF lc_ok CS lv_c.
        lv_out = lv_out && lv_c.
      ELSE.
        lv_out = lv_out && '_'.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

*   A component name cannot start with a digit.
    IF lv_out IS NOT INITIAL AND lv_out(1) CO '0123456789'.
      lv_out = |F{ lv_out }|.
    ENDIF.

*   23, not 30: BUILD_MODEL( ) does not create one component per field, it
*   creates the field and then its companions on the same base name - _VS,
*   _VST, _IDTYPE, _NAME, _IX, _EXP. _IDTYPE is the longest at seven
*   characters, so the base has to stop at 23 for every companion to still
*   fit inside the 30-character cap.
    IF strlen( lv_out ) <= 23.
      rv = lv_out.
      RETURN.
    ENDIF.

*   Too long: 18 characters of the name and a four-digit fingerprint of the
*   WHOLE key - 23 in total, leaving room for _IDTYPE. The fingerprint stops
*   two keys that share their first 18 characters from collapsing onto one
*   component, which would be worse than the dump this fixes - two fields
*   would then silently share a value. Computed from the key alone, never
*   from its position in the field list, so two independent callers walking
*   the same fields arrive at the same name.
    DATA lv_h TYPE i.
    CLEAR lv_i.
    WHILE lv_i < strlen( lv_out ).
      DATA(lv_p) = find( val = lc_ok sub = lv_out+lv_i(1) ).
      IF lv_p < 0.
        lv_p = 0.
      ENDIF.
      lv_h = ( lv_h * 31 + lv_p + 1 ) MOD 100000.
      lv_i = lv_i + 1.
    ENDWHILE.

    rv = |{ lv_out(18) }_{ lv_h MOD 10000 WIDTH = 4 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.


  METHOD pick_text.
*   Arabic preferred when lang = 'A' and the Arabic text is filled, English
*   otherwise - same fallback PICK( ) always used.
    rv = COND #( WHEN iv_lang = 'A' AND iv_ar IS NOT INITIAL THEN iv_ar
                 ELSE iv_en ).

*   OTR:<alias> lets a config text stay single-sourced with an SAP OTR
*   concept instead of being frozen at whatever it was when someone last
*   typed it into the Studio. A missing or deleted OTR concept falls back
*   to the stored literal (prefix and all) rather than an empty text, so
*   the failure is a visible "OTR:..." on screen, not a blank one nobody
*   can explain.
*   The resolution itself is OTR_TEXT( ) - one copy, so a per-check MSG clause
*   that has already been picked EN/AR can resolve an alias through the same
*   code rather than a second one that drifts from it.
    rv = otr_text( iv_text = rv iv_lang = iv_lang ).
  ENDMETHOD.


  METHOD otr_text.
    rv = iv_text.
    IF strlen( rv ) <= 4 OR substring( val = rv len = 4 ) <> 'OTR:'.
      RETURN.
    ENDIF.

*   TYPE sotr_alias, not the STRING SUBSTRING( ) returns by default - a
*   function module's import parameters are typed strictly, unlike a
*   method's by-reference binding. Passing a STRING here dumps
*   CX_SY_DYN_CALL_ILLEGAL_TYPE at runtime.
    DATA lv_alias TYPE sotr_alias.
    lv_alias = substring( val = rv off = 4 ).
    DATA lv_otr TYPE sotr_txt.
    CLEAR lv_otr.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = lv_alias
        langu           = iv_lang
      IMPORTING
        e_text          = lv_otr
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0 AND lv_otr IS NOT INITIAL.
      rv = lv_otr.
    ENDIF.
  ENDMETHOD.


  METHOD msg_key.
    DATA(lv) = to_upper( condense( iv_key ) ).
    rv = xsdbool(    lv = 'REQUIRED'
                  OR lv = 'LEN'
                  OR lv = 'RANGE'
                  OR lv = 'NUMBER'
                  OR lv = 'FORMAT'
                  OR lv = '*' ).
  ENDMETHOD.


  METHOD msg_token.
    rv = iv_raw.
    IF rv IS INITIAL.
      RETURN.
    ENDIF.

    IF strlen( rv ) > 4 AND substring( val = rv len = 4 ) = 'OTR:'.
      rv = otr_text( iv_text = rv iv_lang = iv_lang ).
      RETURN.
    ENDIF.

*   @nnn - a ZRAK_T_CJ_TXT row, the same reference COL_HEADER( ) takes for a
*   TABLE column header and LONG_TEXT( ) for a paragraph. Guarded on STRLEN( )
*   before the offset: RV is a STRING, and an offset past the end of one raises
*   CX_SY_RANGE_OUT_OF_BOUNDS rather than returning blank.
    IF strlen( rv ) > 1 AND rv(1) = '@'.
      DATA lv_no TYPE string.
      lv_no = substring( val = rv off = 1 ).
      CONDENSE lv_no.
      TRY.
          rv = zcl_rak_text=>get( iv_no      = CONV symsgno( lv_no )
                                  iv_default = iv_raw
                                  iv_journey = iv_journey ).
        CATCH cx_root.
*         An unusable number is not a reason to show the citizen nothing. The
*         raw token goes on screen so it is obvious in testing which check on
*         which field is misconfigured.
          rv = iv_raw.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD msg_for.
    CLEAR rv.

    DATA lv_raw TYPE string.
    lv_raw = iv_msg.
    SHIFT lv_raw LEFT DELETING LEADING space.
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_cl TYPE string_table.
    SPLIT lv_raw AT ';' INTO TABLE lt_cl.

*   KEYED OR NOT, DECIDED ON THE FIRST CLAUSE ONLY. The text has to BEGIN with
*   a recognised key immediately followed by ':' - so an ordinary sentence that
*   happens to contain a colon or a semicolon, and an 'OTR:' alias covering the
*   whole column, are both plain wording and take the untouched path below.
    DATA lv_first TYPE string.
    DATA lv_keyed TYPE abap_bool.
    READ TABLE lt_cl INTO lv_first INDEX 1.
    IF sy-subrc = 0.
      DATA(lv_p) = find( val = lv_first sub = ':' ).
      IF lv_p > 0.
        lv_keyed = msg_key( substring( val = lv_first len = lv_p ) ).
      ENDIF.
    ENDIF.

    IF lv_keyed = abap_false.
*     Every check that reads MSG today gets it, exactly as before.
*     IV_KEYED_ONLY marks the checks that did NOT, and they keep not.
      IF iv_keyed_only = abap_false.
        rv = iv_msg.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(lv_want) = to_upper( condense( iv_check ) ).
    DATA lv_star TYPE string.
    DATA lv_txt  TYPE string.
    DATA lv_k    TYPE string.
    DATA lv_off  TYPE i.
    DATA lv_aft  TYPE i.

    LOOP AT lt_cl INTO DATA(lv_cl).
      lv_off = find( val = lv_cl sub = ':' ).
      IF lv_off <= 0.
        CONTINUE.
      ENDIF.
      lv_k = to_upper( condense( substring( val = lv_cl len = lv_off ) ) ).
*     The FIRST colon only, so a clause's own text may be 'OTR:<alias>'.
*     LV_AFT is computed into a variable rather than written as LV_OFF + 1
*     inline: an arithmetic expression in an actual parameter is legal from
*     7.40, and a plain variable costs nothing and cannot be the reason an
*     activation fails.
      lv_aft = lv_off + 1.
      lv_txt = substring( val = lv_cl off = lv_aft ).
      SHIFT lv_txt LEFT DELETING LEADING space.
      IF lv_k = lv_want.
        rv = lv_txt.
        EXIT.
      ELSEIF lv_k = '*'.
        lv_star = lv_txt.
      ENDIF.
    ENDLOOP.

    IF rv IS INITIAL.
      rv = lv_star.
    ENDIF.
    IF rv IS INITIAL.
*     Keyed, but nothing for THIS check. Blank on purpose: the caller falls
*     back to the catalogue, which is bilingual and already says the right
*     thing for the check that fired.
      RETURN.
    ENDIF.

    DATA lv_lang TYPE sy-langu.
    lv_lang = COND #( WHEN iv_lang IS NOT INITIAL THEN iv_lang
                      ELSE zcl_rak_text=>lang( ) ).
    rv = msg_token( iv_raw     = rv
                    iv_lang    = lv_lang
                    iv_journey = iv_journey ).
  ENDMETHOD.


  METHOD col_ix.
    LOOP AT it_cols INTO DATA(lv_c).
      IF to_upper( condense( lv_c ) ) = to_upper( iv_name ).
        rv = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD cell_of.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    rv = VALUE #( it_row[ lv_ix ] OPTIONAL ).
  ENDMETHOD.


  METHOD put_cell.
*   A column the spec does not define is SKIPPED, never appended. Appending is
*   what pushed every later cell one place along in the first place.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    CHECK lines( ct_row ) >= lv_ix.
    READ TABLE ct_row INDEX lv_ix ASSIGNING FIELD-SYMBOL(<cell>).
    CHECK sy-subrc = 0.
    <cell> = iv_val.
  ENDMETHOD.


  METHOD blank_row.
    DO lines( it_cols ) TIMES.
      APPEND `` TO rt.
    ENDDO.
  ENDMETHOD.


  METHOD nationalities.
*   SELECT ... INTO TABLE rather than SELECT ... ENDSELECT: the loop form holds a
*   database cursor open for the whole of the loop body, and this is a single
*   round trip for about 240 rows.
    SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = @sy-langu
      ORDER BY land1 ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.

*   Falling back to English rather than to nothing. A journey launched in a
*   language T005T has no rows for would otherwise show an empty nationality
*   list, which looks like a broken control rather than a missing translation.
    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
        FROM t005t
        WHERE spras = 'E'
        ORDER BY land1 ASCENDING
        INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
