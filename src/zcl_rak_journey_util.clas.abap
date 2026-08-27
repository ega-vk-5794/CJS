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
      OR iv_type = 'NUMBER' OR iv_type = 'CURRENCY' OR iv_type = 'TEXTAREA' OR iv_type = 'DATE'
      OR iv_type = 'TIME' OR iv_type = 'DATETIME' OR iv_type = 'SELECT' OR iv_type = 'MULTISELECT'
      OR iv_type = 'RADIO' OR iv_type = 'CHECKBOX' OR iv_type = 'SWITCH' OR iv_type = 'SEGMENTED'
      OR iv_type = 'SLIDER' OR iv_type = 'STEPPER' OR iv_type = 'RATING' OR iv_type = 'DISPLAY'
      OR iv_type = 'READONLY' OR iv_type = 'STATUS' OR iv_type = 'OBJNUM' OR iv_type = 'PROGRESS'
      OR iv_type = 'LINK' OR iv_type = 'SEARCH' OR iv_type = 'TABLE' OR iv_type = 'UPLOAD'
      OR iv_type = 'PAYFEE' OR iv_type = 'EDITABLE_TABLE' OR iv_type = 'CHECKGROUP'
      OR iv_type = 'REVIEW' OR iv_type = 'RO_PANEL' OR iv_type = 'RECORDCARD'
      OR iv_type = 'REQPANEL' ).
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
ENDCLASS.
