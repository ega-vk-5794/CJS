CLASS zcl_rak_journey_css DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
*   Theme and chrome. Produces the injected CSS, the step indicator and the
*   scroll keeper. Reads ms_config and mv_step; writes nothing.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

    METHODS build_theme_css RETURNING VALUE(rv_css) TYPE string.
    METHODS build_stepper IMPORTING iv_vertical    TYPE abap_bool DEFAULT abap_false
                          RETURNING VALUE(rv_html) TYPE string.
    METHODS density_class RETURNING VALUE(rv) TYPE string.
    METHODS scroll_keeper RETURNING VALUE(rv) TYPE string.

*   The class name a renderer should put on a control for a given semantic role,
*   in whichever vocabulary the ACTIVE theme selects. Every renderer asks for a
*   ROLE and never writes a literal class name, which is the only reason a theme
*   can switch the whole application to the legacy vocabulary at all.
    METHODS cls IMPORTING iv_role TYPE string RETURNING VALUE(rv) TYPE string.

*   The global theme, read once per instance and held. CLS( ) is called once per
*   CONTROL and ACTIVE( ) goes to the INDX cluster - without the cache that is a
*   database read per button.
    METHODS theme RETURNING VALUE(rs) TYPE zcl_rak_cj_theme=>ty_theme.

  PRIVATE SECTION.
    DATA mo_e TYPE REF TO zcl_rak_journey_engine.
    DATA ms_theme TYPE zcl_rak_cj_theme=>ty_theme.
    DATA mv_theme_read TYPE abap_bool.

*   Reads a stylesheet out of the Web Repository. Blank when the object is not
*   there, which the caller must treat as a fault rather than a preference.
    METHODS mime_css IMPORTING iv_obj TYPE string RETURNING VALUE(rv) TYPE string.

*   The rules the framework needs whatever the theme is - the stepper, the split
*   rail, the required marker, the row and upload grids, the chip rows, the hidden
*   uploader bridge. A borrowed stylesheet has never heard of any of them, so they
*   are emitted alongside it. Cosmetics belong to the borrowed sheet; structure
*   belongs here, and mixing the two is what makes a theme unmaintainable.
    METHODS legacy_chrome RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_CSS IMPLEMENTATION.


  METHOD build_stepper.
    DATA(lv) = COND string( WHEN iv_vertical = abap_true
                            THEN `<div class="rakStepper rakStepperV">`
                            ELSE `<div class="rakStepper">` ).
    DATA lv_i TYPE i.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
      DATA(lv_cls) = COND string( WHEN lv_i < mo_e->mv_step THEN 'rakStep dn'
                                  WHEN lv_i = mo_e->mv_step THEN 'rakStep on'
                                  ELSE 'rakStep' ).
*     Step titles land in RAW HTML here, so they need XML escaping as well as the
*     brace escaping zcl_rak_journey_util=>esc( ) does.
      DATA(lv_ttl) = zcl_rak_journey_util=>esc( escape( val    = ls_step-title
                                  format = cl_abap_format=>e_xml_text ) ).
      lv = lv && |<div class="{ lv_cls }"><span class="rakDot">{ lv_i + 1 }</span>| &&
                 |<span class="rakLbl">{ lv_ttl }</span></div>|.
      IF lv_i < lines( mo_e->ms_config-steps ) - 1.
        DATA(lv_bar) = COND string( WHEN lv_i < mo_e->mv_step THEN 'rakBar done' ELSE 'rakBar' ).
        lv = lv && |<span class="{ lv_bar }"></span>|.
      ENDIF.
      lv_i = lv_i + 1.
    ENDLOOP.
    rv_html = lv && `</div>`.
  ENDMETHOD.


  METHOD build_theme_css.
    DATA lv_css TYPE string.

    DATA(g)  = theme( ).

*   A ready-made stylesheet wins outright, and nothing below it runs. The LEGACY
*   theme names Z2UI5_STYLES - the very Web Repository object the ShapeIT screens
*   load - so parity comes from putting THEIR css on the page, not from anybody
*   re-deriving it here. Generating ours as well would leave two stylesheets
*   competing for the same selectors and the winner decided by load order.
    DATA(lv_legacy) = abap_false.
    IF g-css_mime IS NOT INITIAL.
      lv_css = mime_css( g-css_mime ).
      IF lv_css IS NOT INITIAL.
        lv_legacy = abap_true.
*       Structure only. See LEGACY_CHROME.
        lv_css = lv_css && legacy_chrome( ).
      ELSE.
*       A missing Web Repository object must not leave the journey with no styling
*       at all, so fall through and generate. Loud, because the journey will not
*       look like the legacy screens and nothing else on the page will say why.
        mo_e->trace_gate( |Theme { g-theme_id } names Web Repository object | &&
                          |{ g-css_mime }, which could not be read. The generated | &&
                          |stylesheet is being used instead, so this journey will | &&
                          |not look like the legacy screens.| ).
      ENDIF.
    ENDIF.

    DATA(b)  = mo_e->ms_config-theme-brand_color.
    DATA(n)  = mo_e->ms_config-theme-navy_color.
    DATA(d)  = COND string( WHEN b = g-brand THEN g-brand_dk ELSE 'rgb(166,18,22)' ).
    DATA(lt) = COND string( WHEN b = g-brand THEN g-brand_hi ELSE 'rgb(214,42,51)' ).

*   A gradient angle is absolute, so 120deg keeps running left to right on the
*   Arabic page and the dark end lands on the wrong side of the heading. The
*   mirror of Xdeg about the vertical axis is 360-X. 180deg is already vertical
*   and is left alone.
    DATA(a135) = COND string( WHEN mo_e->mv_lang = 'A' THEN '225deg' ELSE '135deg' ).
    DATA(a120) = COND string( WHEN mo_e->mv_lang = 'A' THEN '240deg' ELSE '120deg' ).
    DATA(a90)  = COND string( WHEN mo_e->mv_lang = 'A' THEN '270deg' ELSE '90deg' ).

*   THE font knob for the PORTAL variant - change this line, nothing else.
*   These are candidates, not a confirmed match: open rakdigital.rak.ae, inspect
*   the "What are you looking for?" heading and copy the computed font-family
*   here so the journey and the portal cannot drift apart.
*   A declared family only applies if the browser can actually resolve it. If
*   the citizen's machine has none of these it falls back to the system sans and
*   nothing visibly changes - see the notes on serving the font before assuming
*   this line is broken.
*   Arabic is handled separately in the RTL block at the end of this method.
    DATA(f) = g-font.

*   Naming a family does not fetch it. Without this the stack above silently
*   fell through to Segoe UI on every machine that had no Montserrat installed,
*   which looks like the theme edit simply did not work.
*   Blank this to disable the request entirely; the stack above then degrades to
*   whatever the machine has.
*   PRODUCTION: self-host the woff2 behind an ICF path and point fu at that
*   instead. Same mechanism, one string - it does not have to be Google. A
*   citizen-facing government page calling out to fonts.googleapis.com on every
*   load is a privacy and availability question, not a styling one, and the
*   network may well block it.
*   NOTE the v1 (/css?family=) syntax with an escaped pipe between families. The
*   modern /css2 endpoint needs & to separate families, and a raw & inside the
*   img onerror attribute breaks the XML view this markup is injected into.
*   Tajawal carries the Arabic so the RTL journey resolves to a real face too.
    DATA(fu) = g-font_url.

    IF lv_legacy = abap_false.

      lv_css =
        |:root \{| &&
        |--sapBrandColor:{ b };--sapHighlightColor:{ b };--sapSelectedColor:{ b };--sapActiveColor:{ b };| &&
        |--sapButton_Emphasized_Background:{ b };--sapButton_Emphasized_BorderColor:{ b };| &&
        |--sapButton_Emphasized_Hover_Background:{ d };--sapButton_Emphasized_Active_Background:{ d };| &&
        |--sapButton_Emphasized_TextColor:#ffffff;--sapButton_Emphasized_Hover_TextColor:#ffffff;| &&
        |--sapButton_Selected_Background:{ b };--sapButton_Selected_BorderColor:{ b };| &&
        |--sapButton_Selected_TextColor:#ffffff;| &&
        |--sapButton_Selected_Hover_Background:{ d };--sapButton_Selected_Hover_BorderColor:{ d };| &&
        |--sapButton_Selected_Hover_TextColor:#ffffff;| &&
        |--sapContent_FocusColor:{ n };--sapContent_ContrastFocusColor:#ffffff;| &&
        |--sapTitleColor:{ n };--sapGroup_TitleTextColor:{ n };--sapList_HeaderTextColor:{ n };| &&
        |--sapProgress_Value_Background:{ b };| &&
        |--sapButton_Lite_TextColor:{ n };--sapButton_Lite_Hover_TextColor:{ n };| &&
        |--sapButton_Lite_Active_TextColor:{ d };--sapButton_Lite_Selected_TextColor:{ d };| &&
        |--sapButton_TextColor:{ n };--sapButton_Hover_TextColor:{ n };--sapButton_Active_TextColor:{ d };| &&
        |--sapLinkColor:{ n };--sapLink_Hover_Color:{ d };--sapLink_Active_Color:{ d };\}|.
      IF mo_e->ms_config-theme-variant = 'PREMIUM'.
        lv_css = lv_css &&
          |:root \{--sapButton_BorderCornerRadius:22px;--sapField_BorderCornerRadius:8px;\}| &&
          |.sapUiBody,.sapMPage,.sapMShell\{background:linear-gradient(180deg,#f6f8fb,#eef1f6)!important;\}| &&
          |.sapMBtnEmphasized,.sapMBtnEmphasized .sapMBtnInner\{background:linear-gradient({ a135 },{ lt },{ d })!important;| &&
          |border:none!important;box-shadow:0 6px 16px rgba(196,30,38,.32)!important;\}| &&
          |.rakHdr\{background:linear-gradient({ a120 },{ d } 0%,{ b } 55%,{ lt } 100%);color:#fff;| &&
          |border-radius:0 0 20px 20px;padding:18px 22px 16px;box-shadow:0 8px 26px rgba(196,30,38,.26);\}| &&
          |.rakHdrTitle,.rakHdr .sapMTitle\{color:#fff!important;font-weight:700;\}| &&
          |.rakHdr .sapMBtn,.rakHdr .sapMBtn .sapMBtnContent\{color:#fff!important;\}| &&
          |.rakSub\{color:rgba(255,255,255,.88);font-size:.82rem;\}| &&
          |.rakCard\{background:#fff;border:1px solid #eceff3;border-radius:16px;| &&
          |box-shadow:0 3px 18px rgba(16,35,62,.07);padding:6px 14px 10px;margin:12px 16px;\}| &&
          |.rakFooter\{background:#fff;border:1px solid #eceff3;border-radius:16px;| &&
          |box-shadow:0 3px 18px rgba(16,35,62,.07);margin:12px 16px;padding:8px 12px;\}| &&
          |.rakSearch\{background:#fff;border:1px solid #eceff3;border-radius:14px;| &&
          |box-shadow:0 3px 14px rgba(16,35,62,.06);padding:.85rem;margin:.4rem 1rem;\}| &&
          |.rakDot\{width:38px;height:38px;font-size:15px;border:2px solid #ccd2db;\}| &&
          |.rakStep.on .rakDot,.rakStep.dn .rakDot\{background:linear-gradient({ a135 },{ lt },{ d });| &&
          |border:none;color:#fff;box-shadow:0 4px 12px rgba(196,30,38,.4);\}| &&
          |.rakStep.on .rakDot\{transform:scale(1.12);\}| &&
          |.rakBar.done\{background:linear-gradient({ a90 },{ b },{ lt });\}|.
      ELSEIF mo_e->ms_config-theme-variant = 'FLAMINGO'.
        lv_css = lv_css &&
          |:root \{--sapButton_BorderCornerRadius:999px;--sapField_BorderCornerRadius:9px;\}| &&
          |body,.sapMText,.sapMLabel,.sapMInputBaseInner\{font-family:'Inter',system-ui,sans-serif;\}| &&
          |.sapMTitle,.rakHdrTitle,h1,h2,h3\{font-family:'Plus Jakarta Sans','Inter',sans-serif!important;font-weight:800;\}| &&
          |.sapUiBody,.sapMPage,.sapMShell\{background:#F5F6F8!important;\}| &&
          |.sapMBtnEmphasized,.sapMBtnEmphasized .sapMBtnInner\{background:#C4232B!important;border:none!important;| &&
          |box-shadow:0 6px 16px rgba(196,35,43,.28)!important;\}| &&
          |.sapMBtnEmphasized:hover .sapMBtnInner\{background:#9E1B22!important;\}| &&
          |.rakHdr\{background:#fff;padding:.7rem 1.1rem .3rem;border-bottom:1px solid #E3E6EB;\}| &&
          |.rakHdrTitle,.rakHdr .sapMTitle\{color:#10233E!important;font-weight:800;\}| &&
          |.rakSub\{color:#6B7484;font-size:.82rem;\}| &&
          |.rakCard\{background:#fff;border:1px solid #E3E6EB;border-radius:14px;| &&
          |box-shadow:0 1px 2px rgba(16,35,62,.04),0 8px 24px -12px rgba(16,35,62,.12);padding:8px 16px 12px;margin:12px 16px;\}| &&
          |.rakFooter\{background:#fff;border:1px solid #E3E6EB;border-radius:14px;| &&
          |box-shadow:0 1px 2px rgba(16,35,62,.04);margin:12px 16px;padding:8px 12px;\}| &&
          |.rakSearch\{background:#fff;border:1px solid #E3E6EB;border-radius:12px;| &&
          |box-shadow:0 1px 2px rgba(16,35,62,.04);padding:.85rem;margin:.4rem 1rem;\}| &&
          |.rakDot\{width:34px;height:34px;font-size:14px;border:2px solid #E3E6EB;\}| &&
          |.rakStep.on .rakDot\{border-color:#C4232B;color:#C4232B;background:#fff;box-shadow:0 0 0 4px rgba(196,35,43,.12);\}| &&
          |.rakStep.dn .rakDot\{background:#C4232B;border-color:#C4232B;color:#fff;\}| &&
          |.rakBar.done\{background:#C4232B;\}| &&
          |.sapMSegBBtnSel,.sapMSegBBtnSel .sapMSegBBtnInner\{background:#C4232B!important;color:#fff!important;\}|.
      ELSEIF mo_e->ms_config-theme-variant = 'PORTAL'.
        lv_css = lv_css &&
*       Field radius drops from 10px to 8px: the portal's cards and inputs are
*       nearly square, and only the pill buttons and the hero search are round.
          |:root \{--sapButton_BorderCornerRadius:999px;--sapField_BorderCornerRadius:8px;\}| &&
*       :not(.sapUiIcon) is load-bearing. UI5 renders sap-icon glyphs as a font,
*       so a blanket font-family would replace every icon in the app with the
*       literal characters behind them.
          |.sapUiBody,.sapUiBody *:not(.sapUiIcon)\{font-family:{ f }!important;\}| &&
          |.sapUiBody,.sapMPage,.sapMShell\{background:#F5F6F8!important;\}| &&
          |.rakHdr,.rakHdrTitle,.rakSub,.rakBlkTitle,.sapMTitle| &&
          |\{text-transform:none!important;\}| &&
          |.rakHdr\{background:transparent;padding:1.4rem 1.5rem .4rem;border:none;\}| &&
          |.rakHdrTitle,.rakHdr .sapMTitle\{color:{ n }!important;font-weight:800;| &&
          |font-size:2.1rem;line-height:1.15;letter-spacing:-.02em;\}| &&
          |.rakSub\{color:#6B7484;font-size:1.05rem;max-width:44rem;\}| &&
*       The short red rule the portal sets under every section subtitle. rakHdr
*       is a flex column, so ::after lands as the last item on its own line.
          |.rakHdr::after\{content:'';display:block;width:46px;height:3px;| &&
          |background:{ b };border-radius:2px;margin-top:.85rem;\}| &&
          |.rakStepper\{padding:1.2rem 1.5rem 1.4rem;\}| &&
          |.rakDot\{width:40px;height:40px;font-size:15px;border:2px solid #E3E6EB;\}| &&
          |.rakStep.on .rakDot\{background:#fff;border-color:{ b };color:{ b };| &&
          |box-shadow:0 0 0 5px rgba(196,35,43,.10);\}| &&
          |.rakStep.dn .rakDot\{background:{ b };border-color:{ b };color:#fff;\}| &&
          |.rakLbl\{font-size:.85rem;font-weight:600;\}| &&
          |.rakBar\{height:2px;margin:0 8px 26px;\}| &&
          |.rakBar.done\{background:{ b };\}| &&
*       The portal's entity tiles are barely rounded, thin-bordered, almost
*       flat, and topped with a solid brand rule. 18px and a deep shadow read as
*       a different product entirely.
          |.rakCard\{background:#fff;border:1px solid #E8EBEF;border-radius:8px;| &&
          |border-top:3px solid { b };| &&
          |box-shadow:0 1px 2px rgba(16,35,62,.04);| &&
          |padding:1.4rem 1.6rem;margin:.6rem 1.5rem;\}| &&
*       REVIEW stacks cards inside a card. Four brand rules down one screen is
*       noise, so only the outermost keeps it.
          |.rakCard .rakCard\{border-top-color:#E8EBEF;\}| &&
          |.rakFooter\{position:sticky;bottom:0;z-index:5;background:#fff;| &&
          |border-top:1px solid #E3E6EB;border-radius:0;box-shadow:none;| &&
          |margin:1rem 0 0;padding:.7rem 1.5rem;\}| &&
          |.rakSearch\{background:#fff;border:1px solid #E8EBEF;border-radius:8px;| &&
          |border-top:3px solid { b };box-shadow:0 1px 2px rgba(16,35,62,.04);| &&
          |padding:1.1rem 1.2rem;margin:.6rem 1.5rem;\}| &&
          |.rakReqPanel\{border-radius:8px;padding:1.1rem 1.2rem;margin:.6rem 1.5rem;\}| &&
          |.rakRecCard\{border-radius:8px;\}| &&
          |.sapMBtnEmphasized,.sapMBtnEmphasized .sapMBtnInner\{background:{ b }!important;| &&
          |border:none!important;box-shadow:0 6px 16px rgba(196,35,43,.24)!important;\}| &&
          |.sapMBtn .sapMBtnInner\{padding:0 1.1rem;\}|.
      ELSE.
        lv_css = lv_css &&
          |:root \{--sapButton_BorderCornerRadius:1.25rem;\}| &&
          |.rakHdr\{background:#fff;padding:.6rem 1rem .2rem;\}| &&
          |.rakHdrTitle,.rakHdr .sapMTitle\{color:{ n }!important;font-weight:700;\}| &&
          |.rakSub\{color:#6b7280;font-size:.8rem;\}| &&
          |.rakCard\{background:#fff;border:1px solid #E3E6EB;border-radius:14px;| &&
          |box-shadow:0 1px 2px rgba(16,35,62,.04),0 8px 24px -14px rgba(16,35,62,.10);| &&
          |padding:6px 14px 10px;margin:10px 16px;\}| &&
          |.rakFooter\{margin:10px 16px;padding:6px 0;\}| &&
          |.rakSearch\{background:#f4f5f7;border-radius:10px;padding:.75rem;margin:.4rem 1rem;\}| &&
          |.rakStep.on .rakDot,.rakStep.dn .rakDot\{background:{ b };border-color:{ b };color:#fff;\}| &&
          |.rakBar.done\{background:{ b };\}|.
      ENDIF.

      lv_css = lv_css &&
        |.rakStepper\{display:flex;align-items:center;padding:.8rem 1rem 1rem;flex-wrap:wrap;\}| &&
        |.rakStep\{display:flex;flex-direction:column;align-items:center;min-width:88px;\}| &&
        |.rakDot\{width:32px;height:32px;border-radius:50%;display:flex;align-items:center;| &&
        |justify-content:center;font-size:14px;font-weight:700;border:2px solid #c7ccd4;| &&
        |color:#9aa3af;background:#fff;transition:all .2s;\}| &&
        |.rakLbl\{margin-top:6px;font-size:12px;color:#9aa3af;\}| &&
        |.rakStep.on .rakLbl\{color:{ b };font-weight:700;\}| &&
        |.rakStep.dn .rakLbl\{color:{ n };\}| &&
        |.rakBar\{flex:1;height:3px;border-radius:3px;background:#e0e3e8;margin:0 5px 24px;min-width:24px;\}| &&
        |.rakVal\{color:{ n };font-weight:600;\}| &&
        |.rakReqPanel\{background:#fff;border:1px solid #E3E6EB;border-radius:14px;| &&
        |padding:.9rem 1rem;margin:.4rem 1rem;\}| &&
        |.rakReqTitle\{display:block;font-size:.75rem;font-weight:700;letter-spacing:.06em;| &&
        |text-transform:uppercase;color:#6B7484;margin-bottom:.5rem;\}| &&
        |.rakReqRow\{margin-bottom:.45rem;\}| &&
        |.rakReqOk\{color:#2e9e4f!important;font-size:1rem;margin-inline-end:.5rem;\}| &&
        |.rakReqPend\{color:#c9cfd8!important;font-size:1rem;margin-inline-end:.5rem;\}| &&
        |.rakReqDone\{color:{ n };\}| &&
        |.rakReqTodo\{color:#8a93a2;\}| &&
        |.rakSplit\{width:100%;align-items:flex-start;\}| &&
        |.rakRail\{flex:none;align-self:flex-start;position:sticky;top:0;\}| &&
        |.rakMain\{flex:1;min-width:0;\}| &&
        |.rakStepperV\{flex-direction:column;align-items:stretch;flex-wrap:nowrap;| &&
        |padding:1rem .75rem;\}| &&
        |.rakStepperV .rakStep\{flex-direction:row;align-items:center;min-width:0;\}| &&
        |.rakStepperV .rakDot\{flex:none;\}| &&
        |.rakStepperV .rakLbl\{margin-top:0;margin-inline-start:.6rem;text-align:start;| &&
        |font-size:13px;\}| &&
        |.rakStepperV .rakBar\{flex:none;width:3px;height:20px;min-width:0;| &&
        |margin:.3rem 0 .3rem 14px;\}| &&
        |@media (max-width:700px)\{| &&
        |.rakSplit\{flex-direction:column;\}| &&
        |.rakRail\{width:100%!important;position:static;\}| &&
        |.rakStepperV\{flex-direction:row;flex-wrap:wrap;align-items:center;\}| &&
        |.rakStepperV .rakStep\{flex-direction:column;min-width:88px;\}| &&
        |.rakStepperV .rakLbl\{margin-top:6px;margin-inline-start:0;text-align:center;\}| &&
        |.rakStepperV .rakBar\{flex:1;width:auto;height:3px;margin:0 5px 24px;\}| &&
        |\}| &&
*     The asterisk used to be absolutely positioned against the label's trailing
*     edge. That worked while the label was a narrow left-hand column; now that
*     labels sit ABOVE their field the label spans the full card, so the marker
*     landed at the far right, a screen away from the text it marks. Flowing it
*     inline puts it hard against the text at ANY label width - and it stops
*     being a layout dependency, which is what made it fragile in the first
*     place. nowrap and the reserved padding go with it: neither is needed once
*     the marker is in the text flow, and nowrap would clip a long top label.
        |.rakReq::after\{content:'*';color:#bb0000;font-weight:700;| &&
        |margin-inline-start:.2rem;\}| &&
        |.rakBlkTitle\{display:block;margin:.9rem 1rem .35rem;font-size:.95rem;| &&
        |font-weight:700;color:{ n };\}| &&
        |.rakRecList\{box-sizing:border-box;margin:.4rem 1rem;padding:0;\}| &&
        |.rakRecCard\{width:auto;box-sizing:border-box;background:#fff;| &&
        |border:1px solid #E3E6EB;border-radius:14px;margin:0 0 .55rem;| &&
        |padding:.5rem .3rem .45rem;transition:border-color .15s,box-shadow .15s,background .15s;\}| &&
        |.rakRecCard:hover\{border-color:#c9cfd8;box-shadow:0 4px 14px rgba(16,35,62,.07);\}| &&
        |.rakRecCard:focus-within\{border-color:{ b };box-shadow:0 0 0 3px rgba(196,35,43,.14);\}| &&
        |.rakRecCard.on\{border-color:{ b };background:rgba(196,35,43,.045);| &&
        |box-shadow:inset 0 0 0 1px { b };\}| &&
        |.rakRecCard .sapMBtn\{width:100%;margin:0;\}| &&
        |.rakRecCard .sapMBtnInner\{width:100%;box-sizing:border-box;background:transparent!important;| &&
        |border:none!important;box-shadow:none!important;justify-content:flex-start;| &&
        |padding:.1rem .7rem;height:auto;\}| &&
        |.rakRecCard .sapMBtnContent\{text-align:start;flex:1;min-width:0;\}| &&
        |.rakRecCard .sapMBtnText\{font-size:.95rem;font-weight:600;color:{ n }!important;| &&
        |overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\}| &&
        |.rakRecCard .sapMBtnIcon\{color:#cdd3dc!important;font-size:1.05rem;\}| &&
        |.rakRecCard.on .sapMBtnText\{color:{ b }!important;font-weight:700;\}| &&
        |.rakRecCard.on .sapMBtnIcon\{color:{ b }!important;\}| &&
        |.rakRecMeta,.rakRecMeta .sapMLnkText\{display:block;font-size:.78rem;| &&
        |color:#8a93a2!important;text-decoration:none!important;\}| &&
        |.rakRecMeta\{padding:0 .7rem .1rem;padding-inline-start:2.55rem;margin-top:-.2rem;\}| &&
        |.rakRecMeta:hover,.rakRecMeta:active\{text-decoration:none!important;\}| &&
        |.rakRevL\{min-width:12rem;color:#6b7484;padding-inline-end:.6rem;\}| &&
        |.sapMBtnTransparent.rakFb_EX .sapMBtnInner\{color:#2e9e4f!important;\}| &&
        |.sapMBtnTransparent.rakFb_GD .sapMBtnInner\{color:#7ab648!important;\}| &&
        |.sapMBtnTransparent.rakFb_AV .sapMBtnInner\{color:#e0a800!important;\}| &&
        |.sapMBtnTransparent.rakFb_PR .sapMBtnInner\{color:#e8792b!important;\}| &&
        |.sapMBtnTransparent.rakFb_VP .sapMBtnInner\{color:#d5342b!important;\}| &&
*     Was left:-9999px. In LTR that parks the control outside the flow and costs
*     nothing; in RTL the same offset creates 9999px of scrollable area and the
*     whole page is pushed to the right edge with a viewport of blank beside it.
*     clip-path hides the control without moving it, so it costs no layout in
*     either direction. It stays in the DOM and stays scriptable, which the
*     uploader needs - the file input and the Go button are fired from injected
*     JS, and display:none would have broken that.
        |.rakHide\{position:absolute!important;width:1px!important;height:1px!important;| &&
        |overflow:hidden!important;clip:rect(0 0 0 0)!important;| &&
        |clip-path:inset(50%)!important;white-space:nowrap!important;\}| &&
        |.rakUp input[type=file]\{padding:.4rem;border:1px dashed #c7ccd4;border-radius:8px;| &&
        |background:#fafbfc;font-size:.82rem;max-width:22rem;\}| &&
        |.sapMPageEnableScrolling\{scroll-behavior:auto!important;\}| &&
        |.sapMSegBBtn\{min-width:5.5rem;padding:0 1.2rem;font-weight:600;\}| &&
        |.sapMSegB,.sapMSegBBtn\{width:auto!important;max-width:none!important;\}| &&
        |.sapMSegBBtn,.sapMSegBBtnInner\{overflow:visible!important;text-overflow:clip!important;| &&
        |white-space:nowrap;\}| &&
        |.sapMPage>.sapMPageHeader\{display:none!important;\}| &&
        |.sapMPage>section,.sapMPage>section.sapMPageEnableScrolling\{top:0!important;\}| &&
        |.sapMInputBaseContentWrapperError,.sapMFocus.sapMInputBaseContentWrapperError| &&
        |\{border-color:#bb0000!important;\}|.

*   Appended AFTER the variant blocks, so anything here wins. Keep it to rules no
*   variant sets, or a variant will silently stop being able to override it.
      lv_css = lv_css &&
*     Everything stretched to the viewport, so on a wide monitor a card holding
*     two lines of text was 1200px across. One measure cap for every top-level
*     container - the single number to change if the content column feels wrong.
        |.rakHdr,.rakStepper,.rakCard,.rakFooter,.rakSearch,.rakReqPanel,| &&
        |.rakRecList,.rakSplit\{max-width:76rem;\}| &&
*     RO_PANEL rows emphasised the LABEL and greyed the value, the exact inverse
*     of REVIEW (rakRevL grey / rakVal bold). This is the muted-label half; the
*     class swap that applies it is in render_one. Same 12rem as rakRevL so the
*     two read as one system.
        |.rakRoLbl\{min-width:12rem;color:#6B7484;\}| &&
*     The browser's native file button was the only unstyled OS widget in the app
*     and it sat at the focal point of the Documents step.
        |.rakUp input[type=file]::file-selector-button,| &&
        |.rakUp input[type=file]::-webkit-file-upload-button| &&
        |\{margin-inline-end:.75rem;padding:.35rem 1rem;border:none;border-radius:999px;| &&
        |background:{ b };color:#fff;font-weight:600;font-size:.82rem;cursor:pointer;\}| &&
        |.rakUp input[type=file]::file-selector-button:hover\{background:{ d };\}| &&
        |.rakUpLbl\{display:inline-flex;align-items:center;cursor:pointer;\}| &&
        |.rakUpLbl>span\{display:inline-block;padding:.45rem 1.1rem;border-radius:8px;| &&
        |font-size:.82rem;font-weight:600;color:#fff;background:{ b };white-space:nowrap;\}| &&
        |.rakUpLbl:hover>span\{background:{ d };\}| &&
        |.rakUpLbl>input[type=file]\{position:absolute!important;width:1px!important;| &&
        |height:1px!important;opacity:0!important;overflow:hidden;border:0!important;padding:0!important;\}| &&
        |.rakAttHint\{display:block;font-size:.78rem;color:#8a93a2;margin-top:.4rem;\}| &&
*     Every other control is 10-22rem; the textarea alone ran the full card. Done
*     in CSS rather than through ctrl_width because the confirmation screen's
*     feedback box is not a config field and needs the same treatment.
        |.rakCard .sapMTextArea\{width:100%!important;max-width:100%!important;\}| &&
*     TYPE SCALE. UI5 ships 14px body text, tuned for dense back-office screens
*     on the 72 font - which has a tall x-height and so reads larger than it
*     measures. Swapping the face to Montserrat kept the 14px and lost the
*     x-height, which is why everything suddenly looked shrunken. 16px is both
*     the honest match for the portal and the accessible default for a
*     citizen-facing page.
*     ORDER MATTERS: the generic rule comes first and every named exception
*     after it. These all sit at the same specificity, so whichever is written
*     last wins - moving a line up here silently disables it.
        |.sapMText,.sapMLabel,.sapMInputBaseInner,.sapMBtnContent,.sapMLnk,| &&
        |.sapMObjStatusText,.sapMCbLabel,.sapMRbBLabel,.sapMSegBBtn,| &&
        |.sapMListTblCell,.sapMLIBContent,.sapMMsgStripMessage\{font-size:1rem;\}| &&
*     A message strip whose text does not wrap makes the page wider than the
*     viewport. In LTR that clips harmlessly on the right; in RTL the overflow
*     goes the other way and the page is pushed off screen. The &trace=X lines
*     are the longest strings the engine emits and the ones that trip it.
        |.sapMMsgStripMessage\{word-break:break-word;overflow-wrap:anywhere;\}| &&
        |.sapMTitle\{font-size:1.15rem;\}| &&
        |.sapMPanelHdr\{font-size:1.05rem;\}| &&
*     .rakHdr .sapMTitle is two classes deep, so the 2.1rem page title above is
*     unaffected by the .sapMTitle rule.
        |.rakSub\{font-size:1.05rem;\}| &&
        |.rakBlkTitle\{font-size:1.1rem;\}| &&
        |.rakLbl\{font-size:.9rem;\}| &&
        |.rakDot\{font-size:16px;\}| &&
        |.rakReqTitle\{font-size:.8rem;\}| &&
        |.rakAttHint\{font-size:.85rem;\}| &&
        |.rakRecCard .sapMBtnText\{font-size:1.05rem;\}| &&
        |.rakRecMeta,.rakRecMeta .sapMLnkText\{font-size:.85rem;\}| &&
*     Form labels were UI5's default grey - the lightest thing on the screen,
*     which inverts the hierarchy: the label is what you scan, the value is what
*     you read. The portal puts its card labels in navy. rakRevL is re-asserted
*     AFTER this because the REVIEW row deliberately does the opposite (grey
*     label, bold value) and this generic rule would otherwise swallow it.
        |.sapMLabel\{color:{ n };\}| &&
        |.rakRevL\{color:#6b7484;\}| &&
*     Unselected record cards used a solid grey disc that read as disabled.
        |.rakRecCard .sapMBtnIcon\{color:#dfe3e9!important;\}| &&
*     Side-by-side field rows, and the flex step card that holds them.
*     - flex-wrap carries !important because sap.m.FlexBox writes wrap NoWrap as
*       an INLINE style, and an inline style beats a class rule without it. This
*       is also why the wrap is not requested through an hbox( ) parameter: the
*       wrapper signature for it is unconfirmed in this z2ui5 version and CSS
*       needs no wrapper support. The wrap is what makes a row collapse on a
*       phone instead of overflowing the card.
*     - the child selector is .rakRow>* and NOT .rakRow>.rakCell. sap.m.FlexBox
*       renders with renderType Div by default, so every child is wrapped in its
*       own item div - the flex item is that wrapper, not the VBox, and a
*       .rakCell rule would size nothing.
*     - flex:0 1 auto, NOT a shared basis. Cells hug their control's own
*       ctrl_width, so a date pair sits at 11rem + 11rem instead of splitting
*       the whole 76rem measure into two 38rem halves with the pickers rattling
*       around inside them. It is also why render_one no longer forces 100%
*       width in a cell.
*     - rakFStep is the VBox that replaces SimpleForm on a row-bearing step.
*       VBox is already display:flex column, so gap alone gives the vertical
*       rhythm the form used to provide; rakCell gets a tighter one for the
*       label-to-control gap.
        |.rakStat .sapMObjStatusText\{font-weight:700;letter-spacing:.01em;\}| &&
        |.rakStat\{padding:.18rem .6rem;border-radius:999px;background:rgba(0,0,0,.04);\}| &&
        |.rakCard tr.sapMListTblRow:hover\{background:rgba(0,0,0,.025)!important;\}| &&
        |.rakCard th.sapMListTblHeaderCell\{letter-spacing:.02em;\}| &&
        |.rakRow\{flex-wrap:wrap!important;width:100%;gap:.75rem;\}| &&
        |.rakRow>*\{flex:0 1 auto;min-width:0;max-width:100%;\}| &&
        |.rakCell\{min-width:0;gap:.25rem;\}| &&
        |.rakRowEq>*\{flex:1 1 0;\}| &&
        |.rakRowC2>*\{flex:0 0 calc((100% - .75rem)/2);\}| &&
        |.rakRowC3>*\{flex:0 0 calc((100% - 1.5rem)/3);\}| &&
        |.rakRowC4>*\{flex:0 0 calc((100% - 2.25rem)/4);\}| &&
        |@media (max-width:700px)\{.rakRowEq>*\{flex:1 1 100%!important;\}\}| &&
*     A checkbox carries its own caption, so it has no label line above it and
*     ends up sitting a few pixels higher than its neighbours in a shared row.
*     alignitems End on the row lines the controls up; this only pads the box so
*     the caption is not jammed against it.
        |.sapMCb .sapMCbLabel\{padding-inline-start:.4rem;\}| &&
*     A checkbox must be SQUARE. Whatever theme this UI5 build resolves to is
*     drawing the box as a circle, which is the whole reason checkboxes read as
*     radio buttons - moving the caption beside the box fixed the layout but not
*     the shape.
*
*     Scoped to descendants of .sapMCb, so it cannot reach a radio button: those
*     are .sapMRb / .sapMRbBOut and keep their 50% radius. !important because it
*     has to beat a theme rule, which is the same reason every other override in
*     this block carries one.
*
*     If the circle survives this, the outline is not a border-radius at all - it
*     is a background image or an icon glyph - and the control being rendered is
*     worth confirming in the inspector before anything else is tried.
        |.sapMCb,.sapMCb *\{border-radius:3px!important;\}| &&
*     Same red and weight as .rakReq::after, so a required checkbox is marked
*     identically to every other required field.
        |.rakReqStar\{color:#bb0000!important;font-weight:700;margin-inline-start:.15rem;\}| &&
        |.rakFStep\{gap:.65rem;\}| &&

*     CONTROL WIDTH. Selects and pickers size to their own content while inputs
*     stretch to the cell, so a card reads as a straight left column with two
*     short dropdowns hanging off the bottom of it. Nothing is wrong with either
*     control - they simply have no shared width, and the eye reads the ragged
*     edge as an unfinished screen.
*
*     NO !important, deliberately, and that is the whole design of the rule.
*     ctrl_width is rendered by z2ui5 as an INLINE width, and a stylesheet
*     !important beats a non-important inline style - so an !important here
*     would override every ctrl_width an author has ever set and turn a Studio
*     knob into dead metadata. Without it the cascade does the right thing on
*     its own: a field with ctrl_width keeps it, a field without one picks this
*     up. Adding !important to "make it work" is the bug, not the fix.
*
*     No max-width either, one step further on: max-width constrains width no
*     matter where the width came from, so a cap here would quietly clamp an
*     authored ctrl_width of 30rem with nothing in the Studio to explain it. A
*     control too wide on a one-column step is fixed with ctrl_width on the
*     field, which now works.
*
*     sapMTextArea is deliberately NOT in this list. It has its own 42rem rule
*     above and shares the .sapMInputBase root, so naming the root here would
*     resize it depending only on which of the two lines was written last. Every
*     control is named explicitly for that reason - do not collapse this to
*     .sapMInputBase.
        |.rakCard .sapMInput,.rakCard .sapMSlt,.rakCard .sapMComboBox,| &&
        |.rakCard .sapMMultiComboBox,.rakCard .sapMDP,.rakCard .sapMDTP,| &&
        |.rakCard .sapMTP\{width:100%;\}| &&

*     UPLOAD CELLS. The multi-column Documents layout itself is NOT a defect and
*     is not touched here: render_step packs consecutive UPLOAD fields into a
*     rakRow when the step sets COLUMNS 2..4, on purpose, so a twelve-file step
*     is not four screens of scrolling. What was wrong is the sizing inside it.
*
*     .rakRow>* is flex:0 1 auto, so a cell hugs its content - right for a
*     paired input, where the cell hugs the control's ctrl_width. An upload cell
*     has no ctrl_width and nothing stable to hug, so it sizes to whichever
*     filename is currently attached: two uploads side by side come out at two
*     different widths and both move whenever a file is added or removed.
*
*     flex:1 1 0 - a ZERO basis, not auto. With flex-basis:auto the content
*     still sets the starting width and the grow only divides the leftover,
*     which is the same ragged result one step less obvious.
*
*     Scoped to .rakUpRow, which render_step adds ALONGSIDE .rakRow only on an
*     upload row, so no paired-input step is affected.
        |.rakUpRow>*\{flex:1 1 0;min-width:0;\}| &&
        |.rakUpCell\{min-width:0;\}| &&
*     The uploader's own 22rem cap is right full width and overflows a quarter
*     width cell. Inside a cell, the cell decides.
        |.rakUpCell .rakUp input[type=file]\{max-width:100%;\}| &&

*     CHIP ROWS. One row is icon, filename link, then buttons. In a half-width
*     cell a long citizen-supplied filename had nothing stopping it: it wrapped
*     under its own buttons, or pushed Remove past the edge of the cell. Remove
*     is the control that undoes the mistake, so it is the worst one to lose.
*
*     Named rakFile*, NOT rakAtt*. rakAttName_, rakAttB64_ and rakAttGo_ are
*     already live class PREFIXES on the hidden bridge controls in
*     render_uploader, which the injected JavaScript finds itself by with
*     document.querySelector. A .rakAttName rule would not actually collide -
*     rakAttName_D028 is a different class token - but the next person reading
*     both files will assume it does and go hunting a bug that is not there.
        |.rakFileRow\{width:100%;min-width:0;gap:.15rem;\}| &&
*     nth-child(2), NOT .rakFileName, and this is why the child order is pinned
*     in render_chips. sap.m.FlexBox at renderType Div wraps every child in its
*     own item div, so the flex item is that wrapper and not the Link - the same
*     trap documented on .rakRow>* above. The wrapper is what must grow and what
*     must be allowed to shrink. min-width:0 defeats the flex default of
*     min-width:auto, which refuses to go below the content and is precisely
*     what let the filename shove the buttons out.
*
*     Everything else on the row keeps its size: the icon, View, Remove and the
*     Filed status are all flex:0 0 auto.
        |.rakFileRow>*\{flex:0 0 auto;min-width:0;\}| &&
        |.rakFileRow>*:nth-child(2)\{flex:1 1 auto;\}| &&
*     display:block is required - text-overflow does nothing on an inline box,
*     and sap.m.Link renders an inline <a>.
        |.rakFileName,.rakFileName .sapMLnkText\{display:block;max-width:100%;| &&
        |overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\}| &&

*     Below the phone breakpoint the upload columns stack - four quarter-width
*     cells on a phone is four unreadable ones - and the full-width cell then
*     has room for the whole filename, so stop truncating something the citizen
*     can now read. Same 700px the .rakSplit stack uses.
        |@media (max-width:700px)\{| &&
        |.rakUpRow>*\{flex:1 1 100%;\}| &&
        |.rakFileName,.rakFileName .sapMLnkText\{white-space:normal;| &&
        |overflow:visible;text-overflow:clip;overflow-wrap:anywhere;\}| &&
        |\}|.

    ENDIF.

*   Was a second <style> div emitted from mo_e->mo_render->render( ) on every request. Folded in
*   here so it rides the version stamp below and is parsed once per page.
    IF mo_e->mv_lang = 'A'.
      lv_css = lv_css &&
*       Direction has to be set at the root and inherited, not sprinkled over a
*       list of UI5 classes. Setting it on .sapMPage and .sapMForm while the
*       journey's own .rakHdr, .rakStepper, .rakCard and .rakFooter stayed LTR
*       left flex rows resolving in one direction inside parents resolving in
*       the other, and the row overflowed the viewport: the page ended up hard
*       against the right edge with a screen of blank beside it. One declaration
*       on html and body, and every descendant follows.
        |html,body,.sapUiBody,.sapMShell,.sapMPage,.sapMPanel,.sapMForm,| &&
        |.sapMInputBase,.rakHdr,.rakStepper,.rakCard,.rakFooter,.rakSearch,| &&
        |.rakReqPanel,.rakRecList,.rakSplit| &&
        |\{direction:rtl;text-align:right;\}| &&
*       A guard, not a fix: if one rule still overflows, the citizen gets a
*       slightly clipped edge instead of a page they cannot find.
        |html,body,.sapUiBody\{overflow-x:hidden;\}| &&
*       Numbers, money, dates, licence and reference numbers are read left to
*       right in Arabic too. Without this a fee prints as 00,20 and a reference
*       number comes back with its segments reversed.
        |.rakLtrNum,.rakAmt,.sapMObjectNumber,.sapMObjectNumberText,| &&
        |.sapMInputBaseInner[type=tel],.sapMInputBaseInner[type=number],| &&
        |.sapMDPInnerInput,.sapMTimePickerInput| &&
        |\{direction:ltr;unicode-bidi:embed;text-align:right;\}| &&
*       The stepper is a row of numbered dots and a progress bar. Left in LTR it
*       counted away from the Arabic reading direction, so step 1 sat where a
*       reader looks for the last step.
        |.rakStepper,.rakStep,.rakBar\{direction:rtl;\}| &&
*       Montserrat has no Arabic coverage, so on the Arabic journey it would
*       silently hand every glyph to whatever the system picks - a different
*       face per device. Name Arabic-capable families first instead.
*       Not on a borrowed stylesheet. The legacy sheet already names its own Arabic
*       face, and !important here would beat it - the one declaration in this whole
*       method able to make a LEGACY journey stop matching the legacy screens.
        COND string( WHEN lv_legacy = abap_true THEN ``
          ELSE |.sapUiBody,.sapUiBody *:not(.sapUiIcon)| &&
               |\{font-family:'Dubai','Tajawal','Almarai','Segoe UI',sans-serif!important;\}| ).
    ENDIF.

*   Rewriting innerHTML on every render re-parses the whole sheet, which costs one
*   unstyled frame - the flicker seen on the first card selection. Stamp a version
*   on the element and make every later render a no-op.
*   Hash of the CSS itself, not its LENGTH. The stamp decides whether the
*   sheet is rewritten, and strlen( ) cannot see a change that does not
*   alter the character count - which is most of them:
*
*     rgb(196,30,38) -> rgb(200,30,38)   same length, no repaint
*     brand -> navy on any variable      same length, no repaint
*     density Compact -> Cozy            never in the stamp at all
*
*   The colours were never in the stamp either, only the variant name. So
*   an author who changed a colour in the Studio, saved, cleared the cache
*   and reloaded got fresh config from the server and the PREVIOUS sheet
*   from the DOM, on an element that persists across every re-render. It
*   looked exactly like the cache had not cleared.
*
*   Journey and language stay in front of the hash so the id is still
*   readable in the inspector when someone is working out which journey
*   painted the page.
*   LEGACY_CHROME goes on the end of the generated sheet as well, not only after a
*   borrowed one. Last wins, which is the point: these rules are the legacy shape
*   - stage bar, split, row grid, required marker - expressed against rak* names
*   the engine actually emits.
*
*   Keyed on THEME_ID rather than on CSS_MIME, because the borrowed stylesheet is
*   no longer used and the chrome is the whole of what LEGACY now means.
    IF lv_legacy = abap_false AND g-theme_id = 'LEGACY'.
      lv_css = lv_css && legacy_chrome( ).
    ENDIF.

    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = 'SHA1'
            if_data       = lv_css
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_root.
*       No hash is not a reason to serve a stale sheet. Fall back to a
*       value that changes on every request, which costs one re-parse per
*       render and is the behaviour this stamp was added to avoid - not
*       the behaviour it was added to cause.
        lv_hash = |{ sy-datum }{ sy-uzeit }{ strlen( lv_css ) }|.
    ENDTRY.
    DATA(lv_ver) = |{ mo_e->ms_config-journey_id }{ mo_e->mv_lang }{ lv_hash }|.
*   Guarded by id, so it survives every re-render without piling up <link> tags.
    DATA(lv_fjs) = COND string( WHEN fu IS INITIAL THEN ``
      ELSE `var fl=document.getElementById('rakFontCss');` &&
           `if(!fl){fl=document.createElement('link');fl.id='rakFontCss';` &&
           `fl.rel='stylesheet';fl.href='` && fu &&
           `';document.head.appendChild(fl);}` ).

    DATA(lv_js) = lv_fjs &&
                  `var s=document.getElementById('rakThemeCss');` &&
                  `if(!s){s=document.createElement('style');s.id='rakThemeCss';` &&
                  `document.head.appendChild(s);}` &&
                  `if(s.getAttribute('data-rakv')!=='` && lv_ver && `'){s.innerHTML=` &&
                  |`| && lv_css && |`| &&
                  `;s.setAttribute('data-rakv','` && lv_ver && `');}this.remove();`.
    DATA(lv_html) = |<div style="display:none"><img src="data:," onerror="{ lv_js }"/></div>|.
    REPLACE ALL OCCURRENCES OF '{' IN lv_html WITH '\{'.
    REPLACE ALL OCCURRENCES OF '}' IN lv_html WITH '\}'.
    rv_css = lv_html.
  ENDMETHOD.


  METHOD cls.
*   One line, and deliberately nothing more. The vocabulary itself lives in
*   ZCL_RAK_CJ_THEME so that the Studio, the renderer and this class cannot drift
*   apart; this is only the instance-side door to it with the theme already read.
    rv = zcl_rak_cj_theme=>cls( iv_role = iv_role
                                iv_set  = theme( )-cls_set ).
  ENDMETHOD.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD density_class.
    rv = SWITCH string( mo_e->ms_config-theme-density
           WHEN 'Compact' THEN 'sapUiSizeCompact'
           WHEN 'Cozy'    THEN 'sapUiSizeCozy'
           ELSE '' ).
  ENDMETHOD.


  METHOD legacy_chrome.
*   Emitted AFTER the borrowed stylesheet, so anything named in both is won here.
*   That is the wrong way round for cosmetics and the right way round for layout:
*   the only selectors below are rak* names the legacy sheet has never heard of,
*   plus the three UI5 page rules the engine needs to sit flush in the shell.
*
*   NOTHING here re-derives a legacy colour by eye. The palette values come from
*   the LEGACY preset, and the two literals - the stage green and the pending grey
*   - are read off the legacy stage bar fragment, which is where they are defined.
    DATA(g)  = theme( ).
    DATA(b)  = g-brand.
    DATA(n)  = g-navy.
    DATA(ln) = g-line_clr.
    DATA(gr) = '#53A56E'.
    DATA(gy) = '#9AA3AF'.

    rv =
*     STEP BAR. The legacy bar is built from sap.m controls carrying rak-stagebar-*
*     classes; this one is a div the engine writes itself, so the legacy rules do
*     not reach it. Same three states, same three colours, different markup.
      |.rakStepper\{display:flex;align-items:center;padding:.8rem 1rem 1rem;flex-wrap:wrap;\}| &&
      |.rakStep\{display:flex;flex-direction:column;align-items:center;min-width:88px;\}| &&
      |.rakDot\{width:1.875rem;height:1.875rem;border-radius:50%;display:flex;| &&
      |align-items:center;justify-content:center;font-size:.875rem;font-weight:600;| &&
      |border:1px solid { b };color:{ b };background:#fff;\}| &&
      |.rakStep.on .rakDot\{background:#E9730C;border-color:#E9730C;color:#fff;\}| &&
      |.rakStep.dn .rakDot\{background:{ gr };border-color:{ gr };color:#fff;\}| &&
      |.rakLbl\{margin-top:6px;font-size:.8125rem;color:{ b };\}| &&
      |.rakStep.on .rakLbl\{color:#C25A00;font-weight:600;\}| &&
      |.rakStep.dn .rakLbl\{color:{ gr };\}| &&
      |.rakBar\{flex:1;height:2px;background:#E4E7EB;margin:0 5px 24px;min-width:24px;\}| &&
      |.rakBar.done\{background:{ gr };\}| &&
      |.rakStepperV\{flex-direction:column;align-items:stretch;flex-wrap:nowrap;padding:1rem .75rem;\}| &&
      |.rakStepperV .rakStep\{flex-direction:row;align-items:center;min-width:0;\}| &&
      |.rakStepperV .rakDot\{flex:none;\}| &&
      |.rakStepperV .rakLbl\{margin-top:0;margin-inline-start:.6rem;text-align:start;\}| &&
      |.rakStepperV .rakBar\{flex:none;width:2px;height:20px;min-width:0;margin:.3rem 0 .3rem 14px;\}| &&

*     SPLIT LAYOUT. Only meaningful on WIZARD_LEFT; the LEGACY preset ships WIZARD,
*     so this is here for the journey that overrides it rather than for the default.
      |.rakSplit\{width:100%;align-items:flex-start;\}| &&
      |.rakRail\{flex:none;align-self:flex-start;position:sticky;top:0;\}| &&
      |.rakMain\{flex:1;min-width:0;\}| &&

*     REQUIRED MARKER. Inline, not absolutely positioned - labels sit above their
*     field now, so a positioned asterisk lands a card away from its text.
      |.rakReq::after\{content:'*';color:#bb0000;font-weight:700;margin-inline-start:.2rem;\}| &&
      |.rakReqStar\{color:#bb0000!important;font-weight:700;margin-inline-start:.15rem;\}| &&

*     ROW AND CELL GRID. flex-wrap carries !important because sap.m.FlexBox writes
*     NoWrap as an inline style. The child selector is .rakRow>* and not .rakCell:
*     FlexBox wraps every child in its own item div, so the flex item is the
*     wrapper and a .rakCell rule would size nothing.
      |.rakStat .sapMObjStatusText\{font-weight:700;letter-spacing:.01em;\}| &&
      |.rakStat\{padding:.18rem .6rem;border-radius:999px;background:rgba(0,0,0,.04);\}| &&
      |.rakCard tr.sapMListTblRow:hover\{background:rgba(0,0,0,.025)!important;\}| &&
      |.rakCard th.sapMListTblHeaderCell\{letter-spacing:.02em;\}| &&
      |.rakRow\{flex-wrap:wrap!important;width:100%;gap:.75rem;\}| &&
      |.rakRow>*\{flex:0 1 auto;min-width:0;max-width:100%;\}| &&
      |.rakCell\{min-width:0;gap:.25rem;\}| &&
      |.rakRowEq>*\{flex:1 1 0;\}| &&
      |.rakRowC2>*\{flex:0 0 calc((100% - .75rem)/2);\}| &&
      |.rakRowC3>*\{flex:0 0 calc((100% - 1.5rem)/3);\}| &&
      |.rakRowC4>*\{flex:0 0 calc((100% - 2.25rem)/4);\}| &&
      |@media (max-width:700px)\{.rakRowEq>*\{flex:1 1 100%!important;\}\}| &&
      |.rakFStep\{gap:.65rem;\}| &&
      |.rakUpRow>*\{flex:1 1 0;min-width:0;\}| &&
      |.rakUpCell\{min-width:0;\}| &&
      |.rakUpCell .rakUp input[type=file]\{max-width:100%;\}| &&

*     CHIP ROWS. nth-child(2) and not .rakFileName, for the same FlexBox wrapper
*     reason as .rakRow>* above: the wrapper is what grows and what must shrink.
      |.rakFileRow\{width:100%;min-width:0;gap:.15rem;\}| &&
      |.rakFileRow>*\{flex:0 0 auto;min-width:0;\}| &&
      |.rakFileRow>*:nth-child(2)\{flex:1 1 auto;\}| &&
      |.rakFileName,.rakFileName .sapMLnkText\{display:block;max-width:100%;| &&
      |overflow:hidden;text-overflow:ellipsis;white-space:nowrap;\}| &&

*     THE HIDDEN UPLOADER BRIDGE. clip-path rather than left:-9999px - the offset
*     version creates 9999px of scrollable area on the Arabic page and pushes the
*     whole journey off the viewport. It has to stay in the DOM and stay
*     scriptable, so display:none is not available either.
      |.rakHide\{position:absolute!important;width:1px!important;height:1px!important;| &&
      |overflow:hidden!important;clip:rect(0 0 0 0)!important;| &&
      |clip-path:inset(50%)!important;white-space:nowrap!important;\}| &&
      |.rakUp input[type=file]\{padding:.4rem;border:1px dashed #C9CFD8;border-radius:4px;| &&
      |background:#fafbfc;font-size:.82rem;max-width:22rem;\}| &&
      |.rakAttHint\{display:block;font-size:.8125rem;color:{ gy };margin-top:.4rem;\}| &&

*     REQUIREMENTS PANEL, RECORD LIST, REVIEW ROWS. Framework furniture with no
*     legacy counterpart at all - the legacy screens hand-build each of these per
*     journey. Kept quiet on purpose so they read as part of the legacy page.
      |.rakReqPanel\{background:#fff;border:1px solid { ln };border-radius:6px;| &&
      |padding:.9rem 1rem;margin:.4rem 1rem;\}| &&
      |.rakReqTitle\{display:block;font-size:.8rem;font-weight:600;letter-spacing:.06em;| &&
      |text-transform:uppercase;color:#6B7484;margin-bottom:.5rem;\}| &&
      |.rakReqRow\{margin-bottom:.45rem;\}| &&
      |.rakReqOk\{color:{ gr }!important;font-size:1rem;margin-inline-end:.5rem;\}| &&
      |.rakReqPend\{color:#C9CFD8!important;font-size:1rem;margin-inline-end:.5rem;\}| &&
      |.rakReqDone\{color:{ n };\}| &&
      |.rakReqTodo\{color:#8a93a2;\}| &&
      |.rakRecList\{box-sizing:border-box;margin:.4rem 1rem;padding:0;\}| &&
      |.rakRecCard\{width:auto;box-sizing:border-box;background:#fff;border:1px solid { ln };| &&
      |border-radius:6px;margin:0 0 .55rem;padding:.5rem .3rem .45rem;\}| &&
      |.rakRecCard.on\{border-color:{ b };box-shadow:inset 0 0 0 1px { b };\}| &&
      |.rakRecCard .sapMBtn\{width:100%;margin:0;\}| &&
      |.rakRecCard .sapMBtnInner\{width:100%;box-sizing:border-box;background:transparent!important;| &&
      |border:none!important;box-shadow:none!important;justify-content:flex-start;| &&
      |padding:.1rem .7rem;height:auto;\}| &&
      |.rakRecCard .sapMBtnContent\{text-align:start;flex:1;min-width:0;\}| &&
      |.rakRecMeta,.rakRecMeta .sapMLnkText\{display:block;font-size:.8125rem;| &&
      |color:#8a93a2!important;text-decoration:none!important;\}| &&
      |.rakRevL\{min-width:12rem;color:#6b7484;padding-inline-end:.6rem;\}| &&
      |.rakRoLbl\{min-width:12rem;color:#6B7484;\}| &&
      |.rakFb_EX .sapMBtnInner\{color:{ gr }!important;\}| &&
      |.rakFb_GD .sapMBtnInner\{color:#7ab648!important;\}| &&
      |.rakFb_AV .sapMBtnInner\{color:#e0a800!important;\}| &&
      |.rakFb_PR .sapMBtnInner\{color:#e8792b!important;\}| &&
      |.rakFb_VP .sapMBtnInner\{color:#d5342b!important;\}| &&

*     UNTIL THE RENDERER ASKS FOR ROLES. Every container below is one the renderer
*     still labels with a rak* name of its own, so the legacy sheet cannot reach
*     it and it would otherwise paint as a bare unstyled box on a legacy page.
*     These are the only cosmetic rules in this method and they are TEMPORARY:
*     once the renderer calls CLS( ) for CARD, FOOTER, SHELL and the rest, the
*     controls carry shapeIT-card and friends, the legacy sheet styles them, and
*     this block should be deleted rather than kept in step with two stylesheets.
      |.rakCard\{background:#fff;border:1px solid { ln };border-radius:6px;| &&
      |box-shadow:0 1px 2px rgba(16,35,62,.06);padding:1rem 1.25rem;margin:.6rem 1rem;\}| &&
      |.rakFooter\{background:#fff;border-top:1px solid { ln };margin:.6rem 1rem 0;| &&
      |padding:.7rem 1.25rem;\}| &&
*     BACK LEFT, FORWARD RIGHT - the legacy footer puts them at opposite ends, and
*     RENDER_FOOTER builds the box with justifycontent = 'End' which sap.m.FlexBox
*     emits as a class, so it has to be overridden rather than set.
*
*     Auto margin on the last child rather than SPACE-BETWEEN, and that is the whole
*     trick: with two buttons it pushes the forward one to the trailing edge and
*     leaves Back at the leading one, and on step 0 - where there is no Back - the
*     single button still lands trailing instead of drifting left.
*
*     Placement ONLY. An earlier attempt also set width:100% and box-sizing on this
*     rule to make the footer a full-bleed grey band; inside a container that already
*     carries max-width:76rem and side margins that overflowed the axis and pushed
*     the whole page sideways with a horizontal scrollbar. The band is not worth it.
      |.rakFooter\{justify-content:flex-start!important;gap:.75rem;\}| &&
      |.rakFooter>*:last-child\{margin-inline-start:auto;\}| &&
      |.rakHdr\{background:transparent;padding:1rem 1.25rem .2rem;\}| &&
      |.rakHdrTitle,.rakHdr .sapMTitle\{color:{ n }!important;font-weight:600;\}| &&
      |.rakSub\{color:#6B7484;\}| &&
      |.rakBlkTitle\{display:block;margin:.9rem 1rem .35rem;font-weight:600;color:{ n };\}| &&
      |.rakVal\{color:{ n };font-weight:500;\}| &&
      |.rakSearch\{background:#fff;border:1px solid { ln };border-radius:6px;| &&
      |padding:.85rem;margin:.4rem 1rem;\}| &&
      |.rakHdr,.rakStepper,.rakCard,.rakFooter,.rakSearch,.rakReqPanel,| &&
      |.rakRecList,.rakSplit\{max-width:76rem;\}| &&

*     SHELL. The engine renders inside a sap.m.Page whose own header is empty, and
*     the legacy screens have no such page. Without these the journey opens with a
*     blank grey band above the card.
      |.sapMPage>.sapMPageHeader\{display:none!important;\}| &&
      |.sapMPage>section,.sapMPage>section.sapMPageEnableScrolling\{top:0!important;\}| &&
      |.sapMPageEnableScrolling\{scroll-behavior:auto!important;\}| &&

      |@media (max-width:700px)\{| &&
      |.rakSplit\{flex-direction:column;\}| &&
      |.rakRail\{width:100%!important;position:static;\}| &&
      |.rakStepperV\{flex-direction:row;flex-wrap:wrap;align-items:center;\}| &&
      |.rakStepperV .rakStep\{flex-direction:column;min-width:88px;\}| &&
      |.rakStepperV .rakLbl\{margin-top:6px;margin-inline-start:0;text-align:center;\}| &&
      |.rakStepperV .rakBar\{flex:1;width:auto;height:2px;margin:0 5px 24px;\}| &&
      |.rakUpRow>*\{flex:1 1 100%;\}| &&
      |.rakFileName,.rakFileName .sapMLnkText\{white-space:normal;| &&
      |overflow:visible;text-overflow:clip;overflow-wrap:anywhere;\}| &&
      |\}|.
  ENDMETHOD.


  METHOD mime_css.
*   The same three calls the legacy classes make to load their own stylesheet, so
*   the bytes on the page are identical to the bytes on the ShapeIT page.
*   FILESIZE first, because WWWDATA_IMPORT hands back whole 255-character lines
*   and the stored length is the only way to trim the padding without cutting the
*   last rule in half.
    DATA lv_size TYPE soli-line.
    DATA ls_key  TYPE wwwdatatab.
    DATA lt_file TYPE w3html_tab.
    DATA lv_len  TYPE i.

*   WWWPARAMS_READ types OBJID as WWWDATATAB-OBJID, a CHAR field, and a function
*   module will not take a STRING there - it raises CX_SY_DYN_CALL_ILLEGAL_TYPE at
*   the call and the whole app dies with it. The legacy class never hit this only
*   because it passed the object name as a literal. So the string is moved into a
*   correctly typed field first, and upper-cased on the way: Web Repository keys
*   are stored upper case and a theme edited in the Studio can arrive in any case.
    DATA lv_objid TYPE wwwdatatab-objid.
    DATA lv_relid TYPE wwwdatatab-relid.
    DATA lv_name  TYPE wwwparams-name.

    lv_objid = to_upper( condense( iv_obj ) ).
    lv_relid = 'HT'.
    lv_name  = 'filesize'.
    IF lv_objid IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'WWWPARAMS_READ'
      EXPORTING
        relid            = lv_relid
        objid            = lv_objid
        name             = lv_name
      IMPORTING
        value            = lv_size
      EXCEPTIONS
        entry_not_exists = 1
        OTHERS           = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ls_key-relid = lv_relid.
    ls_key-objid = lv_objid.

    CALL FUNCTION 'WWWDATA_IMPORT'
      EXPORTING
        key               = ls_key
      TABLES
        html              = lt_file
      EXCEPTIONS
        wrong_object_type = 1
        import_error      = 2
        OTHERS            = 3.
    IF sy-subrc <> 0 OR lt_file IS INITIAL.
      RETURN.
    ENDIF.

    lv_len = lines( lt_file ) * 255.

    CALL FUNCTION 'SCMS_FTEXT_TO_STRING'
      EXPORTING
        length    = lv_len
      IMPORTING
        ftext     = rv
      TABLES
        ftext_tab = lt_file.

    CONDENSE rv.

*   The caller writes this into a style element through a JavaScript template
*   literal, so a backtick or a ${ sequence anywhere in the borrowed sheet would
*   close the literal and take the rest of the page with it. Neither is legal CSS,
*   so neutralising them costs nothing and removes a whole class of failure that
*   would only ever appear after somebody edited Z2UI5_STYLES.
*   SANITISE. Not defensive tidying - the difference between the stylesheet
*   arriving and the whole injection being destroyed, which looks identical to a
*   page with no styling at all.
*
*   The sheet ends up nested inside three parsers, each with its own terminator:
*
*     XML view attribute   onerror=" ... "      ends at " and rejects < and &
*     JavaScript literal   innerHTML=` ... `    ends at ` and eats \ and ${
*     the CSS itself
*
*   The GENERATED sheet never tripped any of them because it is written here and
*   uses single quotes throughout. A hand-maintained legacy sheet has content:"",
*   url("...") and [type="file"] all through it, and the first double quote closes
*   the onerror attribute - after which the rest is markup and not one rule lands.
*
*   ORDER MATTERS: backslashes are doubled FIRST, or the doubling would also double
*   backslashes introduced by a later step.

*   NO BACKSLASH DOUBLING. This was here on the assumption that the sheet passes
*   through a JavaScript template literal, which eats a lone backslash. It does
*   not - RENDER_HEADER hands the string straight to the HTML control with
*   SANITIZECONTENT = ABAP_FALSE, so it reaches the DOM as markup and backslashes
*   survive untouched.
*
*   Doubling them was therefore actively destructive. A glyph escape content:'\e924'
*   became '\\e924', which CSS reads as an escaped backslash followed by the text
*   e924 - so every icomoon icon printed its own hex code beside the control
*   instead of drawing. That is what the stray e924 next to each combobox was.

*   Both are legal CSS string delimiters and interchangeable, so the sheet renders
*   identically afterwards.
    REPLACE ALL OCCURRENCES OF '"' IN rv WITH `'`.

*   Neither is legal CSS anywhere. Their presence means something that is not a
*   stylesheet has been put into the Web Repository object.
    REPLACE ALL OCCURRENCES OF '`' IN rv WITH ''.
    REPLACE ALL OCCURRENCES OF '${' IN rv WITH '$ ('.
    REPLACE ALL OCCURRENCES OF '<' IN rv WITH ''.

*   & is the one character that must be ENCODED rather than dropped: the XML parser
*   decodes it back before the browser sees the JavaScript, so a selector or media
*   query that needs one still gets one.
    REPLACE ALL OCCURRENCES OF '&' IN rv WITH '&amp;'.
  ENDMETHOD.


  METHOD scroll_keeper.
    DATA(lv_js) =
      `var k='rakScroll_` && |{ mo_e->mv_step }| && `';` &&
      `var q=function(){return document.querySelector('.sapMPageEnableScrolling');};` &&
      `if(!window._rakScrollWired){window._rakScrollWired=1;` &&
      `document.addEventListener('scroll',function(e){var s=q();` &&
      `if(s&&e.target===s){try{sessionStorage.setItem(window._rakScrollKey,s.scrollTop);}catch(x){}}},true);}` &&
      `window._rakScrollKey=k;` &&
      `var p=0;try{p=parseInt(sessionStorage.getItem(k)||'0',10);}catch(x){}` &&
      `if(p>0){var n=0;var f=function(){var s=q();n=n+1;` &&
      `if(s&&(s.scrollHeight-s.clientHeight)>=p){s.scrollTop=p;}` &&
      `else if(n<30){requestAnimationFrame(f);}};requestAnimationFrame(f);}` &&
      `this.remove();`.
    DATA(lv_html) =
      `<div><img src="data:," style="display:none" onerror="` && lv_js && `"/></div>`.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    rv = lv_html.
  ENDMETHOD.


  METHOD theme.
    IF mv_theme_read = abap_false.
      ms_theme      = zcl_rak_cj_theme=>active( ).
      mv_theme_read = abap_true.
    ENDIF.
    rs = ms_theme.
  ENDMETHOD.
ENDCLASS.
