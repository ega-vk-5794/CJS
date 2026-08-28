*----------------------------------------------------------------------*
* RECONSTRUCTION NOTE — READ BEFORE REPLACING ANYTHING                 *
* This repo was regenerated from the known ZRAK_T_* columns and the   *
* engine/CJS usage, not from your activated source. DIFF it against   *
* your active ZCL_RAK_JOURNEY_REPO first. Two known uncertainty spots  *
* are marked with "&&& VERIFY":                                        *
*   1. min_len/max_len/min_val/max_val columns on ZRAK_T_JNY_FLD       *
*   2. exact bool helper / language fallback you implemented           *
*                                                                      *
* THIS VERSION also fixes two mapping gaps:                            *
*   A. AND active = 'X' on the header SELECT. Without it the Studio's  *
*      Deactivate wrote the flag but the engine ignored it, so the      *
*      journey still ran for anyone with the URL. NOTE: an inactive     *
*      journey can now no longer be previewed in the Studio either.     *
*   B. state = ls_f-fstate. The Studio stored fstate and the engine     *
*      reads is_field-state for STATUS / PROGRESS, but nothing joined   *
*      the two, so both always fell back to 'None'.                     *
*                                                                      *
* DOMAIN-DIRECT CHANGE (earlier version): one line added —             *
*   domname = ls_f-domname  in the ty_field mapping.                   *
* Requires a new CHAR30 (DOMNAME) column 'domname' on ZRAK_T_JNY_FLD.  *
* Resolution is left to the engine's F4 resolver at render time, the   *
* same way SHLP is handled here (repo pre-resolves ROLLNAME only).     *
* If your live repo differs, apply ONLY that one line.                 *
*----------------------------------------------------------------------*
CLASS zcl_rak_journey_repo DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS load_config
      IMPORTING iv_journey_id    TYPE string
                iv_lang          TYPE sy-langu DEFAULT sy-langu
      RETURNING VALUE(rs_config) TYPE zif_rak_journey=>ty_config.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS bool
      IMPORTING iv        TYPE clike
      RETURNING VALUE(rv) TYPE abap_bool.
    METHODS pick
      IMPORTING iv_en     TYPE clike
                iv_ar     TYPE clike
                iv_lang   TYPE sy-langu
      RETURNING VALUE(rv) TYPE string.
    METHODS domain_fixed_values
      IMPORTING iv_rollname TYPE clike
                iv_lang     TYPE sy-langu
      RETURNING VALUE(rt)   TYPE zif_rak_journey=>tt_option.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_REPO IMPLEMENTATION.


  METHOD bool.
    rv = xsdbool( iv = 'X' ).
  ENDMETHOD.


  METHOD pick.
    " Arabic preferred when lang = 'A', falling back to English
    rv = COND #( WHEN iv_lang = 'A' AND iv_ar IS NOT INITIAL THEN iv_ar
                 ELSE iv_en ).

    " OTR:<alias> lets a config text stay single-sourced with an SAP OTR
    " concept instead of being frozen at whatever it was when someone last
    " typed it into the Studio - the same choice a Studio-editable text and
    " a runtime-resolved one used to force, never both at once. Every
    " bilingual text column passes through PICK( ), and PICK( ) runs every
    " time BUILD_CONFIG( ) rebuilds MS_CONFIG - which ENSURE_CONFIG( ) does
    " on every round trip, nothing here is cached across requests - so this
    " already IS "resolved at render time", not merely at Studio save.
    " A missing or deleted OTR concept falls back to the stored literal
    " (prefix and all) rather than an empty label, so the failure is a
    " visible "OTR:..." on screen, not a blank one nobody can explain.
    IF strlen( rv ) > 4 AND substring( val = rv len = 4 ) = 'OTR:'.
      DATA(lv_alias) = substring( val = rv off = 4 ).
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
    ENDIF.
  ENDMETHOD.


  METHOD load_config.
    DATA(lv_id) = to_upper( iv_journey_id ).

    SELECT SINGLE * FROM zrak_t_jny INTO @DATA(ls_h)
      WHERE journey_id = @lv_id AND active = 'X'.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rs_config-journey_id    = ls_h-journey_id.
    rs_config-title         = pick( iv_en = ls_h-title iv_ar = ls_h-title_ar iv_lang = iv_lang ).
    rs_config-cj_type       = ls_h-cj_type.
    rs_config-handler_class = ls_h-handler_class.
    rs_config-draft_mode    = to_upper( ls_h-draft_mode ).
    rs_config-attach_mode   = to_upper( ls_h-attach_mode ).

    rs_config-theme = VALUE #(
      variant      = ls_h-theme_variant
      layout_mode  = ls_h-layout_mode
      accent_type  = ls_h-accent_type
      brand_color  = ls_h-brand_color
      navy_color   = ls_h-navy_color
      density      = ls_h-density
      subtitle     = pick( iv_en = ls_h-subtitle iv_ar = ls_h-subtitle_ar iv_lang = iv_lang )
      show_actions = bool( ls_h-show_actions ) ).

    rs_config-backend = VALUE #(
      active   = bool( ls_h-bknd_active )
      category = ls_h-bknd_category
      journey  = ls_h-bknd_journey
      fm_post  = ls_h-bknd_fm_post
      fm_read  = ls_h-bknd_fm_read ).

    " ---- steps -----------------------------------------------------------
    SELECT * FROM zrak_t_jny_step INTO TABLE @DATA(lt_step)
      WHERE journey_id = @lv_id ORDER BY seqnr.

    " ---- fields ----------------------------------------------------------
    SELECT * FROM zrak_t_jny_fld INTO TABLE @DATA(lt_fld)
      WHERE journey_id = @lv_id ORDER BY step_id, seqnr.

    " ---- options ---------------------------------------------------------
    SELECT * FROM zrak_t_jny_opt INTO TABLE @DATA(lt_opt)
      WHERE journey_id = @lv_id ORDER BY step_id, field_name, seqnr.

    " ---- rules -----------------------------------------------------------
    SELECT * FROM zrak_t_jny_rule INTO TABLE @DATA(lt_rule)
      WHERE journey_id = @lv_id ORDER BY rule_id.
    LOOP AT lt_rule INTO DATA(ls_r).
      APPEND VALUE #( rule_id   = ls_r-rule_id
                      src_field = ls_r-src_field
                      src_op    = ls_r-src_op
                      src_value = ls_r-src_value
                      action    = ls_r-action
                      tgt_field = ls_r-tgt_field
                      tgt_value = ls_r-tgt_value ) TO rs_config-rules.
    ENDLOOP.

    LOOP AT lt_step INTO DATA(ls_s).
      DATA(ls_cstep) = VALUE zif_rak_journey=>ty_step(
        id          = ls_s-step_id
        title       = pick( iv_en = ls_s-title iv_ar = ls_s-title_ar iv_lang = iv_lang )
        icon        = ls_s-icon
        columns     = ls_s-columns
        bknd_screen = ls_s-bknd_screen
        next_req    = to_upper( ls_s-next_requires )
        no_forward  = ls_s-no_forward ).

      LOOP AT lt_fld INTO DATA(ls_f) WHERE step_id = ls_s-step_id.
        DATA(ls_cfld) = VALUE zif_rak_journey=>ty_field(
          name         = ls_f-field_name
          label        = pick( iv_en = ls_f-zlabel iv_ar = ls_f-zlabel_ar iv_lang = iv_lang )
          type         = ls_f-ftype
          placeholder  = pick( iv_en = ls_f-placeholder iv_ar = ls_f-placeholder_ar iv_lang = iv_lang )
          default      = ls_f-default_val
          group        = ls_f-fgroup
          section      = pick( iv_en = ls_f-zsection iv_ar = ls_f-zsection_ar iv_lang = iv_lang )
          has_attach   = bool( ls_f-has_attach )
          attach_label = ls_f-attach_label
          attach_types = ls_f-attach_types
          attach_maxmb = ls_f-attach_maxmb
          attach_multi = bool( ls_f-attach_multi )
          rollname     = ls_f-rollname
          shlp         = ls_f-shlp
          domname      = ls_f-domname
          tech_name    = ls_f-tech_name
          state        = ls_f-fstate
          hidden       = bool( ls_f-hidden )
          readonly     = bool( ls_f-readonly )
          validation   = VALUE #(
            required = bool( ls_f-required )
            regex    = ls_f-regex
            min_len  = ls_f-min_len
            max_len  = ls_f-max_len
            min_val  = |{ ls_f-min_val }|
            max_val  = |{ ls_f-max_val }|
            msg      = pick( iv_en = ls_f-msg iv_ar = ls_f-msg_ar iv_lang = iv_lang ) ) ).

        " options: explicit rows win; otherwise derive from the data
        " element's domain fixed values. A directly-configured domain
        " (ls_f-domname) is resolved by the engine's F4 resolver at render,
        " same as SHLP - not pre-resolved here.
        LOOP AT lt_opt INTO DATA(ls_o)
             WHERE step_id = ls_s-step_id AND field_name = ls_f-field_name.
          APPEND VALUE #( key  = ls_o-opt_key
                          text = pick( iv_en = ls_o-opt_text iv_ar = ls_o-opt_text_ar iv_lang = iv_lang ) )
            TO ls_cfld-options.
        ENDLOOP.
        IF ls_cfld-options IS INITIAL AND ls_f-rollname IS NOT INITIAL.
          ls_cfld-options = domain_fixed_values( iv_rollname = ls_f-rollname iv_lang = iv_lang ).
        ENDIF.

        APPEND ls_cfld TO ls_cstep-fields.
      ENDLOOP.

      APPEND ls_cstep TO rs_config-steps.
    ENDLOOP.
  ENDMETHOD.


  METHOD domain_fixed_values.
    SELECT SINGLE domname FROM dd04l INTO @DATA(lv_dom)
      WHERE rollname = @iv_rollname.
    IF sy-subrc <> 0 OR lv_dom IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_langu) = COND sy-langu( WHEN iv_lang = 'A' THEN 'A' ELSE 'E' ).
    SELECT a~domvalue_l AS key, b~ddtext AS text
      FROM dd07l AS a
      LEFT JOIN dd07t AS b
        ON  b~domname    = a~domname
        AND b~valpos     = a~valpos
        AND b~as4local   = a~as4local
        AND b~ddlanguage = @lv_langu
      WHERE a~domname = @lv_dom AND a~as4local = 'A'
      ORDER BY a~valpos
      INTO TABLE @DATA(lt).
    LOOP AT lt INTO DATA(ls).
      APPEND VALUE #( key  = ls-key
                      text = COND #( WHEN ls-text IS NOT INITIAL THEN ls-text ELSE ls-key ) ) TO rt.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
