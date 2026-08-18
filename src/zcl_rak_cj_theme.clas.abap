*&---------------------------------------------------------------------*
*& ZCL_RAK_CJ_THEME - global presentation for the Customer Journey Studio
*&---------------------------------------------------------------------*
*& No DDIC table. The RAK Digital identity lives in DEFAULTS as the one
*& source of truth, so there is nothing to create, seed, transport or
*& keep in step between clients - the class activates and every journey
*& in every client renders identically.
*&
*& LAYOUT and VARIANT are part of the theme now, not just the colours. Both are
*& set to what the citizen journeys already use - WIZARD_LEFT and PORTAL - so
*& adopting this changes nothing for a journey that was already on those two, and
*& visibly changes any journey that was not. Allowed values are the ones the
*& Studio offers: WIZARD, WIZARD_LEFT, TABS, ACCORDION, SINGLE for layout, and
*& CLEAN, PREMIUM, FLAMINGO, PORTAL for variant. Nothing validates them here, so
*& a typo produces the framework's own fallback rather than an error.
*&
*& The global palette is the default for every journey. A journey takes
*& its own colours only when its header column THEME_OWN is set, which is
*& the single switch the author sees in the Studio; the existing BRAND,
*& NAVY, ACCENT and DENSITY columns are then read as before, so nothing
*& already authored is lost. C_ALLOW_OWN set to ABAP_FALSE overrides even
*& that, locking every journey to the global palette.
*&
*& OVERRIDE is for a single request - the Studio preview showing a
*& candidate palette without persisting it. It does not survive the
*& round trip, which is deliberate.
*&
*& ACCENT and DENSITY are normalised on every read. That removes the
*& ADEM defect class at the root: 'EMPHASIZED' or 'COZY' stored in any
*& case now resolves to the exact UI5 enum member instead of silently
*& falling back to a plain Default button and the shell density.
*&
*& Wiring: CSS( ) where the existing rakCard / rakVal stylesheet is
*& emitted, ROOT_CLASS( ) on the outermost container.
*&---------------------------------------------------------------------*
CLASS zcl_rak_cj_theme DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

*   LENGTH is not permitted inline in a method signature - only in a TYPES or
*   DATA declaration - so the theme id needs a name of its own.
    TYPES ty_theme_id TYPE c LENGTH 20.

    CONSTANTS c_allow_own TYPE abap_bool VALUE abap_true ##NO_TEXT.
    CONSTANTS c_default   TYPE ty_theme_id VALUE 'RAKDIGITAL' ##NO_TEXT.

    TYPES:
      BEGIN OF ty_theme,
        theme_id  TYPE c LENGTH 20,
        name      TYPE string,
        brand     TYPE string,
        brand_dk  TYPE string,
        brand_hi  TYPE string,
        brand_lt  TYPE string,
        navy      TYPE string,
        navy_md   TYPE string,
        page_bg   TYPE string,
        card_bg   TYPE string,
        line_clr  TYPE string,
        radius    TYPE string,
        shadow    TYPE string,
        font      TYPE string,
        font_ar   TYPE string,
        font_url  TYPE string,
        layout    TYPE string,
        variant   TYPE string,
        accent    TYPE string,
        density   TYPE string,
        ui5_theme TYPE string,
*       The Web Repository object holding a ready-made stylesheet. When filled,
*       BUILD_THEME_CSS loads it and generates nothing - which is how LEGACY gets
*       parity without anybody re-deriving the legacy CSS by eye.
        css_mime  TYPE string,
*       Which class-name vocabulary the renderer emits. Blank means the rak* names.
        cls_set   TYPE string,
      END OF ty_theme.

    TYPES tt_theme TYPE STANDARD TABLE OF ty_theme WITH EMPTY KEY.

    CLASS-METHODS presets
      RETURNING VALUE(rt_theme) TYPE tt_theme.

    CLASS-METHODS chosen
      RETURNING VALUE(rv_id) TYPE ty_theme_id.

    CLASS-METHODS set_chosen
      IMPORTING iv_id         TYPE ty_theme_id
      RETURNING VALUE(rv_msg) TYPE string.

    CLASS-METHODS stored
      RETURNING VALUE(rs_theme) TYPE ty_theme.

    CLASS-METHODS save
      IMPORTING is_theme      TYPE ty_theme
      RETURNING VALUE(rv_msg) TYPE string.

    CLASS-METHODS defaults
      RETURNING VALUE(rs_theme) TYPE ty_theme.

    CLASS-METHODS active
      RETURNING VALUE(rs_theme) TYPE ty_theme.

    CLASS-METHODS effective
      IMPORTING iv_own          TYPE abap_bool DEFAULT abap_false
                iv_brand        TYPE string OPTIONAL
                iv_navy         TYPE string OPTIONAL
                iv_accent       TYPE string OPTIONAL
                iv_density      TYPE string OPTIONAL
                iv_layout       TYPE string OPTIONAL
                iv_variant      TYPE string OPTIONAL
      RETURNING VALUE(rs_theme) TYPE ty_theme.

    CLASS-METHODS override
      IMPORTING is_theme TYPE ty_theme.

*   The class-name vocabulary. Here rather than in the CSS class so the Studio, the
*   renderer and the stylesheet cannot drift apart - one list, three readers.
*
*   A role with no entry in the requested set returns BLANK, never the other set's
*   name. A wrong class inside a foreign stylesheet is worse than none: none at
*   least inherits sensibly, while a name that happens to exist there picks up
*   whatever layout it was written for.
    CLASS-METHODS cls
      IMPORTING iv_role   TYPE string
                iv_set    TYPE string OPTIONAL
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS norm_accent
      IMPORTING iv_accent    TYPE string
      RETURNING VALUE(rv_ac) TYPE string.

    CLASS-METHODS norm_density
      IMPORTING iv_density   TYPE string
      RETURNING VALUE(rv_de) TYPE string.

    CLASS-METHODS root_class
      IMPORTING is_theme     TYPE ty_theme
                iv_rtl       TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_cl) TYPE string.

    CLASS-METHODS css
      IMPORTING is_theme      TYPE ty_theme
                iv_rtl        TYPE abap_bool DEFAULT abap_false
                iv_scope      TYPE string DEFAULT '.rakCjs'
      RETURNING VALUE(rv_css) TYPE string.

    CLASS-METHODS invalidate.

  PRIVATE SECTION.

    CLASS-DATA gs_over TYPE ty_theme.
    CLASS-DATA gv_over TYPE abap_bool.

ENDCLASS.



CLASS ZCL_RAK_CJ_THEME IMPLEMENTATION.


  METHOD active.
    IF gv_over = abap_true.
      rs_theme = gs_over.
    ELSE.
      rs_theme = defaults( ).
    ENDIF.

    rs_theme-accent  = norm_accent( rs_theme-accent ).
    rs_theme-density = norm_density( rs_theme-density ).
  ENDMETHOD.


  METHOD chosen.
*   Held in the INDX cluster rather than a Z table, so editing a theme needs no
*   DDIC object and no transport. The cost is that it is CLIENT LOCAL: 100 and 200
*   each keep their own, and so will production. Right trade for something set
*   once, wrong one if it ever has to travel in a release - at which point it
*   wants a table.
    DATA(ls_t) = stored( ).

    rv_id = COND #( WHEN ls_t-theme_id IS NOT INITIAL THEN ls_t-theme_id ELSE c_default ).
  ENDMETHOD.


  METHOD cls.
    DATA(lv_r) = to_upper( iv_role ).

    IF to_upper( iv_set ) = 'LEGACY'.
      CASE lv_r.
        WHEN 'SHELL'.    rv = 'shapeIT-firstContainer'.
        WHEN 'CARD'.     rv = 'shapeIT-card'.
        WHEN 'CARDTOP'.  rv = 'shapeIT-card-top'.
        WHEN 'BODY'.     rv = 'shapeIT-part2'.
        WHEN 'FOOTER'.   rv = 'shapeIT-footer'.
        WHEN 'BTN_MAIN'. rv = 'regularBTN'.
        WHEN 'BTN_ALT'.  rv = 'regularBTN_with_border'.
        WHEN 'BTN_HEAD'. rv = 'shapeIT-cardheader-topbtn'.
        WHEN 'TITLE'.    rv = 'font1375 weight600 color-dark-blue'.
        WHEN 'SECTION'.  rv = 'font1 weight600 color-dark-blue'.
        WHEN 'LABEL'.    rv = 'Body_1_3 color-gray6'.
        WHEN 'VALUE'.    rv = 'font1 weight500 color-gray7'.
        WHEN 'INPUT'.    rv = 'input noMax'.
        WHEN 'COMBO'.    rv = 'combobox noMax'.
        WHEN 'TEXTAREA'. rv = 'textarea'.
        WHEN 'CHECKBOX'. rv = 'checkbox'.
        WHEN 'RADIO'.    rv = 'radioButton'.
        WHEN OTHERS.     CLEAR rv.
      ENDCASE.
      RETURN.
    ENDIF.

*   The default set. Only the roles the generated stylesheet actually styles get a
*   name; the rest return blank so a control carries no class rather than a dead one.
    CASE lv_r.
      WHEN 'CARD'.    rv = 'rakCard'.
      WHEN 'FOOTER'.  rv = 'rakFooter'.
      WHEN 'TITLE'.   rv = 'rakHdrTitle'.
      WHEN 'SECTION'. rv = 'rakBlkTitle'.
      WHEN 'VALUE'.   rv = 'rakVal'.
      WHEN OTHERS.    CLEAR rv.
    ENDCASE.
  ENDMETHOD.


  METHOD css.
    DATA(lv_font) = COND string( WHEN iv_rtl = abap_true THEN is_theme-font_ar ELSE is_theme-font ).

    rv_css =
      |@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap');\n| &&
      |.rakCjs \{\n| &&
      |  --rakBrand:{ is_theme-brand };\n| &&
      |  --rakBrandDk:{ is_theme-brand_dk };\n| &&
      |  --rakBrandLt:{ is_theme-brand_lt };\n| &&
      |  --rakNavy:{ is_theme-navy };\n| &&
      |  --rakNavyMd:{ is_theme-navy_md };\n| &&
      |  --rakPage:{ is_theme-page_bg };\n| &&
      |  --rakCardBg:{ is_theme-card_bg };\n| &&
      |  --rakLine:{ is_theme-line_clr };\n| &&
      |  --rakRad:{ is_theme-radius };\n| &&
      |  --rakShadow:{ is_theme-shadow };\n| &&
      |  --rakFont:{ lv_font };\n| &&
      |  font-family:var(--rakFont);\n| &&
      |  background:var(--rakPage);\n| &&
      |  color:var(--rakNavy);\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .sapMText,.rakCjs .sapMLabel,.rakCjs .sapMTitle,\n| &&
      |.rakCjs .sapMInputBaseInner,.rakCjs .sapMBtnContent,\n| &&
      |.rakCjs .sapMSLITitleOnly,.rakCjs .sapMListTblCell \{\n| &&
      |  font-family:var(--rakFont);\n| &&
      |\}\n| &&
      |.rakCjs .sapMTitle \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |  font-weight:600;\n| &&
      |  letter-spacing:-.01em;\n| &&
      |\}\n| &&
      |.rakCjs .sapMLabel \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |  font-weight:500;\n| &&
      |  font-size:.8125rem;\n| &&
      |\}\n| &&
      |.rakCjs .rakVal \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |  font-weight:500;\n| &&
      |\}\n| &&
      |.rakCjs .rakRoLbl,.rakCjs .rakRevL \{\n| &&
      |  color:var(--rakNavyMd);\n| &&
      |  font-weight:500;\n| &&
      |\}\n| &&
      |.rakCjs .rakReqStar \{\n| &&
      |  color:var(--rakBrand);\n| &&
      |  font-weight:700;\n| &&
      |  padding-inline-start:.25rem;\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .rakCard \{\n| &&
      |  position:relative;\n| &&
      |  background:var(--rakCardBg);\n| &&
      |  border:1px solid var(--rakLine);\n| &&
      |  border-top:3px solid var(--rakBrand);\n| &&
      |  border-radius:var(--rakRad);\n| &&
      |  box-shadow:var(--rakShadow);\n| &&
      |  padding:1.25rem 1.5rem;\n| &&
      |\}\n| &&
      |.rakCjs .sapMPanel \{\n| &&
      |  background:var(--rakCardBg);\n| &&
      |  border:1px solid var(--rakLine);\n| &&
      |  border-top:3px solid var(--rakBrand);\n| &&
      |  border-radius:var(--rakRad);\n| &&
      |  box-shadow:var(--rakShadow);\n| &&
      |\}\n| &&
      |.rakCjs .sapMPanelHdr,.rakCjs .sapMPanelHdrTitle \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |  font-weight:600;\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .rakRule \{\n| &&
      |  display:block;\n| &&
      |  width:34px;\n| &&
      |  height:4px;\n| &&
      |  margin:.625rem auto 1.25rem;\n| &&
      |  background:var(--rakBrand);\n| &&
      |  border-radius:2px;\n| &&
      |\}\n| &&
      |.rakCjs .rakSectionHd \{\n| &&
      |  text-align:center;\n| &&
      |\}\n| &&
      |.rakCjs .rakSectionHd .sapMTitle \{\n| &&
      |  font-weight:700;\n| &&
      |  font-size:1.75rem;\n| &&
      |\}\n| &&
      |.rakCjs .rakSectionHd .sapMText \{\n| &&
      |  color:var(--rakNavyMd);\n| &&
      |\}\n| &&
      |.rakCjs .rakSectionHd::after \{\n| &&
      |  content:'';\n| &&
      |  display:block;\n| &&
      |  width:34px;\n| &&
      |  height:4px;\n| &&
      |  margin:.75rem auto 0;\n| &&
      |  background:var(--rakBrand);\n| &&
      |  border-radius:2px;\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .sapMInputBaseInner \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |\}\n| &&
      |.rakCjs .sapMInputBaseContentWrapper \{\n| &&
      |  border:1px solid var(--rakLine);\n| &&
      |  border-radius:var(--rakRad);\n| &&
      |  background:var(--rakCardBg);\n| &&
      |\}\n| &&
      |.rakCjs .sapMInputBaseContentWrapper:hover \{\n| &&
      |  border-color:var(--rakNavyMd);\n| &&
      |\}\n| &&
      |.rakCjs .sapMFocus .sapMInputBaseContentWrapper,\n| &&
      |.rakCjs .sapMInputBaseContentWrapper:focus-within \{\n| &&
      |  border-color:var(--rakBrand);\n| &&
      |  box-shadow:0 0 0 3px var(--rakBrandLt);\n| &&
      |\}\n| &&
      |.rakCjs .sapMInputBaseContentWrapperError \{\n| &&
      |  border-color:var(--rakBrand);\n| &&
      |  background:var(--rakBrandLt);\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .sapMBtnEmphasized \{\n| &&
      |  background:var(--rakBrand);\n| &&
      |  border-color:var(--rakBrand);\n| &&
      |  border-radius:var(--rakRad);\n| &&
      |\}\n| &&
      |.rakCjs .sapMBtnEmphasized:hover,.rakCjs .sapMBtnEmphasized:active \{\n| &&
      |  background:var(--rakBrandDk);\n| &&
      |  border-color:var(--rakBrandDk);\n| &&
      |\}\n| &&
      |.rakCjs .sapMBtnEmphasized .sapMBtnContent \{\n| &&
      |  color:#FFFFFF;\n| &&
      |  font-weight:600;\n| &&
      |\}\n| &&
      |.rakCjs .sapMBtnTransparent .sapMBtnContent,\n| &&
      |.rakCjs .sapMLnk \{\n| &&
      |  color:var(--rakNavy);\n| &&
      |\}\n| &&
      |.rakCjs .sapMLnk:hover \{\n| &&
      |  color:var(--rakBrand);\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .sapMWizardStepTitle,.rakCjs .sapMWizardProgressNavStepCurrent \{\n| &&
      |  color:var(--rakBrand);\n| &&
      |  font-weight:600;\n| &&
      |\}\n| &&
      |.rakCjs .sapMWizardProgressNavAnchor \{\n| &&
      |  color:var(--rakNavyMd);\n| &&
      |\}\n| &&
      |.rakCjs .sapMListTblHeaderCell,.rakCjs .sapMListTblHeader \{\n| &&
      |  background:var(--rakPage);\n| &&
      |  color:var(--rakNavy);\n| &&
      |  font-weight:600;\n| &&
      |\}\n| &&
      |.rakCjs .sapMListTblRow:hover \{\n| &&
      |  background:var(--rakBrandLt);\n| &&
      |\}\n|.

    rv_css = rv_css &&
      |.rakCjs .rakLtrNum \{\n| &&
      |  direction:ltr;\n| &&
      |  unicode-bidi:embed;\n| &&
      |\}\n| &&
      |@media (prefers-reduced-motion:reduce) \{\n| &&
      |  .rakCjs * \{ transition:none!important; animation:none!important; \}\n| &&
      |\}\n|.

    IF iv_rtl = abap_true.
      rv_css = rv_css &&
        |.rakRtl \{\n| &&
        |  direction:rtl;\n| &&
        |  text-align:right;\n| &&
        |\}\n| &&
        |.rakRtl .sapMInputBaseInner,.rakRtl .sapMTextArea \{\n| &&
        |  text-align:right;\n| &&
        |\}\n| &&
        |.rakRtl .rakSectionHd,.rakRtl .rakRule \{\n| &&
        |  text-align:center;\n| &&
        |\}\n|.
    ENDIF.

    IF iv_scope <> '.rakCjs'.
      REPLACE ALL OCCURRENCES OF '.rakCjs' IN rv_css WITH iv_scope.
      REPLACE ALL OCCURRENCES OF '.rakRtl' IN rv_css WITH iv_scope.
    ENDIF.
  ENDMETHOD.


  METHOD defaults.
*   What is STORED wins, because the whole theme is editable now and a stored
*   theme is somebody's deliberate edit - not a preset id to be re-resolved. A
*   preset is only the starting point the form was filled from.
    rs_theme = stored( ).
    IF rs_theme-theme_id IS NOT INITIAL.
      RETURN.
    ENDIF.

*   PRESETS( ) into a variable first. A table expression cannot be applied to a
*   functional call - presets( )[ 1 ] is not valid syntax - and one call beats four.
    DATA(lt_p) = presets( ).

    READ TABLE lt_p INTO rs_theme WITH KEY theme_id = c_default.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    READ TABLE lt_p INTO rs_theme INDEX 1.
  ENDMETHOD.


  METHOD effective.
    rs_theme = active( ).

    IF iv_own <> abap_true OR c_allow_own = abap_false.
      RETURN.
    ENDIF.

    IF iv_brand IS NOT INITIAL.
      rs_theme-brand = iv_brand.
    ENDIF.
    IF iv_navy IS NOT INITIAL.
      rs_theme-navy = iv_navy.
    ENDIF.
    rs_theme-accent  = norm_accent( iv_accent ).
    rs_theme-density = norm_density( iv_density ).

    IF iv_layout IS NOT INITIAL.
      rs_theme-layout = to_upper( iv_layout ).
    ENDIF.
    IF iv_variant IS NOT INITIAL.
      rs_theme-variant = to_upper( iv_variant ).
    ENDIF.
  ENDMETHOD.


  METHOD invalidate.
    CLEAR gs_over.
    gv_over = abap_false.
  ENDMETHOD.


  METHOD norm_accent.
    DATA(lv_in) = to_upper( condense( iv_accent ) ).

    CASE lv_in.
      WHEN 'EMPHASIZED'.  rv_ac = 'Emphasized'.
      WHEN 'DEFAULT'.     rv_ac = 'Default'.
      WHEN 'TRANSPARENT'. rv_ac = 'Transparent'.
      WHEN 'GHOST'.       rv_ac = 'Ghost'.
      WHEN 'ACCEPT'.      rv_ac = 'Accept'.
      WHEN 'REJECT'.      rv_ac = 'Reject'.
      WHEN 'ATTENTION'.   rv_ac = 'Attention'.
      WHEN 'CRITICAL'.    rv_ac = 'Critical'.
      WHEN 'NEGATIVE'.    rv_ac = 'Negative'.
      WHEN 'NEUTRAL'.     rv_ac = 'Neutral'.
      WHEN 'SUCCESS'.     rv_ac = 'Success'.
      WHEN OTHERS.        rv_ac = 'Emphasized'.
    ENDCASE.
  ENDMETHOD.


  METHOD norm_density.
    DATA(lv_in) = to_upper( condense( iv_density ) ).

    CASE lv_in.
      WHEN 'COMPACT'. rv_de = 'Compact'.
      WHEN OTHERS.    rv_de = 'Cozy'.
    ENDCASE.
  ENDMETHOD.


  METHOD override.
    gs_over = is_theme.
    gv_over = abap_true.
  ENDMETHOD.


  METHOD presets.
*   The three after RAKDIGITAL differ only in token values - same structure, same
*   names. They are starting points, not brand rulings: the hex codes belong to
*   whoever owns the brand guidelines, and this is the only place they are
*   written down. RAKCONTRAST is named for an intention I have not measured - the
*   ratios want checking against WCAG before anyone selects it on a citizen site.
    rt_theme = VALUE tt_theme(
      ( theme_id  = 'RAKDIGITAL'
      name      = 'RAK Digital'
      brand     = '#C41E26'
      brand_dk  = '#8E1116'
      brand_hi  = '#D62A33'
      brand_lt  = '#FBE9EA'
      navy      = '#10233E'
      navy_md   = '#5C6B7A'
      page_bg   = '#F5F5F6'
      card_bg   = '#FFFFFF'
      line_clr  = '#E4E7EB'
      radius    = '6px'
      shadow    = '0 1px 2px rgba(16,35,62,.06),0 10px 28px rgba(16,35,62,.07)'
      font      = `'Poppins','Montserrat','Segoe UI',Roboto,Helvetica,Arial,sans-serif`
      font_ar   = `'Dubai','Noto Kufi Arabic','Tajawal','Segoe UI',Tahoma,sans-serif`
      font_url  = `https://fonts.googleapis.com/css?family=Poppins:400,500,600,700|Tajawal:400,500,700`
      layout    = 'WIZARD_LEFT'
      variant   = 'PORTAL'
      accent    = 'Emphasized'
      density   = 'Cozy'
      ui5_theme = 'sap_horizon' )

      ( theme_id  = 'RAKNAVY'
      name      = 'Navy led, red accent'
      brand     = '#10233E'
      brand_dk  = '#081527'
      brand_hi  = '#24405F'
      brand_lt  = '#EAEEF3'
      navy      = '#10233E'
      navy_md   = '#5C6B7A'
      page_bg   = '#F5F6F8'
      card_bg   = '#FFFFFF'
      line_clr  = '#E1E5EA'
      radius    = '6px'
      shadow    = '0 1px 2px rgba(16,35,62,.06),0 10px 28px rgba(16,35,62,.07)'
      font      = `'Poppins','Montserrat','Segoe UI',Roboto,Helvetica,Arial,sans-serif`
      font_ar   = `'Dubai','Noto Kufi Arabic','Tajawal','Segoe UI',Tahoma,sans-serif`
      font_url  = `https://fonts.googleapis.com/css?family=Poppins:400,500,600,700|Tajawal:400,500,700`
      layout    = 'WIZARD_LEFT'
      variant   = 'PORTAL'
      accent    = 'Emphasized'
      density   = 'Cozy'
      ui5_theme = 'sap_horizon' )

      ( theme_id  = 'RAKQUIET'
      name      = 'Quiet, for internal screens'
      brand     = '#5C6B7A'
      brand_dk  = '#414D59'
      brand_hi  = '#77879A'
      brand_lt  = '#EEF1F4'
      navy      = '#10233E'
      navy_md   = '#6B7885'
      page_bg   = '#F7F8F9'
      card_bg   = '#FFFFFF'
      line_clr  = '#E4E7EB'
      radius    = '4px'
      shadow    = '0 1px 2px rgba(16,35,62,.05)'
      font      = `'Poppins','Montserrat','Segoe UI',Roboto,Helvetica,Arial,sans-serif`
      font_ar   = `'Dubai','Noto Kufi Arabic','Tajawal','Segoe UI',Tahoma,sans-serif`
      font_url  = `https://fonts.googleapis.com/css?family=Poppins:400,500,600,700|Tajawal:400,500,700`
      layout    = 'TABS'
      variant   = 'CLEAN'
      accent    = 'Emphasized'
      density   = 'Compact'
      ui5_theme = 'sap_horizon' )

      ( theme_id  = 'RAKCONTRAST'
      name      = 'Higher contrast'
      brand     = '#A80F1B'
      brand_dk  = '#6E0A12'
      brand_hi  = '#C41E26'
      brand_lt  = '#FBE9EA'
      navy      = '#0A1729'
      navy_md   = '#44515F'
      page_bg   = '#FFFFFF'
      card_bg   = '#FFFFFF'
      line_clr  = '#C9CFD6'
      radius    = '8px'
      shadow    = '0 1px 2px rgba(10,23,41,.10),0 10px 28px rgba(10,23,41,.10)'
      font      = `'Poppins','Montserrat','Segoe UI',Roboto,Helvetica,Arial,sans-serif`
      font_ar   = `'Dubai','Noto Kufi Arabic','Tajawal','Segoe UI',Tahoma,sans-serif`
      font_url  = `https://fonts.googleapis.com/css?family=Poppins:400,500,600,700|Tajawal:400,500,700`
      layout    = 'WIZARD_LEFT'
      variant   = 'PORTAL'
      accent    = 'Emphasized'
      density   = 'Cozy'
      ui5_theme = 'sap_horizon' )

*     LEGACY. Not a palette - a whole rendering vocabulary. The stylesheet is the one
*     the ShapeIT screens already load from the Web Repository, and CLS_SET switches
*     the renderer to the class names those screens emit. The colours below are only
*     what the Studio swatches show: the real values live in Z2UI5_STYLES, so editing
*     a hex on this preset will appear to do nothing.
      ( theme_id  = 'LEGACY'
      name      = 'Legacy - renders like the ShapeIT screens'
      brand     = '#C41E26'
      brand_dk  = '#8E1116'
      brand_hi  = '#D62A33'
      brand_lt  = '#FBE9EA'
      navy      = '#10233E'
      navy_md   = '#5C6B7A'
      page_bg   = '#F5F5F6'
      card_bg   = '#FFFFFF'
      line_clr  = '#E4E7EB'
      radius    = '6px'
      shadow    = '0 1px 2px rgba(16,35,62,.06)'
      font      = `'Poppins','Montserrat','Segoe UI',Roboto,Helvetica,Arial,sans-serif`
      font_ar   = `'Dubai','Noto Kufi Arabic','Tajawal','Segoe UI',Tahoma,sans-serif`
      font_url  = ``
*     WIZARD, not WIZARD_LEFT: the legacy screens run their stage bar across the top
*     of the card, not down the side. The other presets ship WIZARD_LEFT.
      layout    = 'WIZARD'
      variant   = 'CLEAN'
      accent    = 'Emphasized'
      density   = 'Cozy'
      ui5_theme = 'sap_horizon'
*     CSS_MIME is deliberately BLANK. Borrowing Z2UI5_STYLES was abandoned, and not
*     for want of trying: LV_CSS is injected inside a JavaScript template literal,
*     which is inside an XML attribute, which abap2UI5 then escapes again. A CSS
*     backslash passes three consumers and at least two eat it, so content:'\e924'
*     arrived as the text e924 beside every icon at every escape depth tried. The
*     generated sheet has no backslashes and never meets the problem.
*
*     CLS_SET is blank for the same reason. Emitting shapeIT-* names is only useful
*     if a stylesheet defines them, and ours defines rak*.
*
*     What makes this LEGACY is LEGACY_CHROME in ZCL_RAK_JOURNEY_CSS, appended last
*     and keyed on this THEME_ID.
      css_mime  = ``
      cls_set   = `` ) ).
  ENDMETHOD.


  METHOD root_class.
    rv_cl = |rakCjs sapUiSize{ norm_density( is_theme-density ) }|.

    IF iv_rtl = abap_true.
      rv_cl = |{ rv_cl } rakRtl|.
    ENDIF.
  ENDMETHOD.


  METHOD save.
    DATA(ls_t) = is_theme.

    IF ls_t-theme_id IS INITIAL.
      ls_t-theme_id = c_default.
    ENDIF.

*   Normalised on the way in, not only on the way out. A stored theme is read on
*   every request, so paying for the correction once at save is right - and it means
*   the Studio shows back exactly what will render.
    ls_t-accent  = norm_accent( ls_t-accent ).
    ls_t-density = norm_density( ls_t-density ).

    EXPORT theme = ls_t TO DATABASE indx(rk) ID 'ZRAK_CJ_THEME'.
    COMMIT WORK AND WAIT.
    invalidate( ).

    rv_msg = |Global theme saved. Every journey in client { sy-mandt } uses it now.|.
  ENDMETHOD.


  METHOD set_chosen.
    DATA(lt_p)  = presets( ).
    DATA(lv_in) = to_upper( iv_id ).

    IF NOT line_exists( lt_p[ theme_id = lv_in ] ).
      rv_msg = |Unknown theme { lv_in }|.
      RETURN.
    ENDIF.

*   Stores the whole preset, not just its id. Picking a preset is 'load these
*   values and use them' - after which every token is editable and the id is only
*   a label saying where the values came from.
    READ TABLE lt_p INTO DATA(ls_p) WITH KEY theme_id = lv_in.
    rv_msg = save( ls_p ).
  ENDMETHOD.


  METHOD stored.
*   The whole structure, not just an id. EXPORT/IMPORT of a flat structure to INDX
*   is one round trip and survives a component being added later - a missing field
*   comes back initial rather than raising, so an older stored theme still loads
*   after the type grows.
    DATA ls_t TYPE ty_theme.

    IMPORT theme = ls_t FROM DATABASE indx(rk) ID 'ZRAK_CJ_THEME'.
    IF sy-subrc = 0.
      rs_theme = ls_t.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
