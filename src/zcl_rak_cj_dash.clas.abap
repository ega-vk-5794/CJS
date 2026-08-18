*&---------------------------------------------------------------------*
*& ZCL_RAK_CJ_DASH - KPI dashboard for the Customer Journey Studio
*&---------------------------------------------------------------------*
*& Reads ZRAK_T_CJ_AGG. Start it the same way as the engine:
*&   /sap/bc/rest/egardcjs?sap-client=200&app_start=ZCL_RAK_CJ_DASH
*&
*& Charts are inline SVG through the HTML control, not sap.viz - this
*& z2ui5 build wraps no viz control, and BUILD_STEPPER already takes the
*& same route.
*&
*& Four layout decisions worth knowing, because each replaced something
*& that looked wrong on real data:
*&
*&   Bars sit in a FIXED-WIDTH track, not a fluid one. A fluid bar at 100%
*&   fills the row edge to edge and reads as a horizontal rule under the
*&   label rather than as a chart. 180px of track keeps a full bar looking
*&   like a full bar.
*&
*&   The KPI grid is four columns, not auto-fill. Auto-fill packed eight
*&   tiles as six then two, which looks like a mistake rather than a grid.
*&
*&   The hero band always carries the three headline figures beside the
*&   ring. The trend line only appears with two or more days of data, and
*&   on day one an empty half-width cell beside the ring looked broken.
*&
*&   Sections are plain cards with their own heading, not sap.m.Panel. A
*&   panel without header text renders an empty bar with a lone chevron.
*&
*& Every figure is DERIVED at read time. Nothing is stored as a KPI, so a
*& definition can be corrected without invalidating history.
*&
*& The blocking-fields panel is the one query that reads ZRAK_T_CJ_EVT
*& directly, because DETAIL is not an aggregate dimension and adding it
*& would multiply the row count by the number of distinct field names. It
*& is bounded by the date filter and served by index Z01.
*&
*& Colours and fonts come from ZCL_RAK_CJ_THEME and follow the global
*& palette.
*&---------------------------------------------------------------------*
CLASS zcl_rak_cj_dash DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES z2ui5_if_app.

    TYPES ty_pct TYPE p LENGTH 5 DECIMALS 1.

*   PUBLIC because they are two-way bound. abap2UI5 resolves a bind path by
*   walking the PUBLIC attributes of the serialised app instance, so a private
*   attribute handed to _bind_edit raises BINDING_ERROR in the browser - it
*   activates perfectly and fails at render.
    DATA mv_jny  TYPE string.
    DATA mv_sess TYPE string.

    TYPES:
      BEGIN OF ty_row,
        journey_id TYPE zrak_t_cj_agg-journey_id,
        launched   TYPE i,
        resumed    TYPE i,
        submitted  TYPE i,
        deleted    TYPE i,
        pay_start  TYPE i,
        pay_done   TYPE i,
        pay_fail   TYPE i,
        pay_stop   TYPE i,
        pay_block  TYPE i,
        pay_p95    TYPE i,
        gates      TYPE i,
        val_fails  TYPE i,
        slow_calls TYPE i,
        slow_p95   TYPE i,
        completion TYPE ty_pct,
        pay_rate   TYPE ty_pct,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_step,
        step_no TYPE i,
        views   TYPE i,
        nexts   TYPE i,
        backs   TYPE i,
        vfails  TYPE i,
        keep    TYPE ty_pct,
      END OF ty_step,
      tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_blocker,
        detail TYPE zrak_t_cj_evt-detail,
        cnt    TYPE i,
      END OF ty_blocker,
      tt_blocker TYPE STANDARD TABLE OF ty_blocker WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_reason,
        detail TYPE zrak_t_cj_evt-detail,
        cnt    TYPE i,
      END OF ty_reason,
      tt_reason TYPE STANDARD TABLE OF ty_reason WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_stuck,
        sess_id    TYPE zrak_t_cj_evt-sess_id,
        bp         TYPE zrak_t_cj_evt-bp,
        rolebp     TYPE zrak_t_cj_evt-rolebp,
        role       TYPE zrak_t_cj_evt-role,
        journey_id TYPE zrak_t_cj_evt-journey_id,
        t0         TYPE timestampl,
        t1         TYPE timestampl,
        mins       TYPE i,
        last_step  TYPE i,
        valf       TYPE i,
        payb       TYPE i,
        gate       TYPE i,
        backs      TYPE i,
        errq       TYPE i,
        done       TYPE abap_bool,
        score      TYPE i,
        worst      TYPE string,
      END OF ty_stuck,
      tt_stuck TYPE STANDARD TABLE OF ty_stuck WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_evt,
        tstamp   TYPE timestampl,
        evt_type TYPE zrak_t_cj_evt-evt_type,
        step_no  TYPE zrak_t_cj_evt-step_no,
        outcome  TYPE zrak_t_cj_evt-outcome,
        detail   TYPE zrak_t_cj_evt-detail,
        duration TYPE zrak_t_cj_evt-duration,
      END OF ty_evt,
      tt_evt TYPE STANDARD TABLE OF ty_evt WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_who,
        bp     TYPE zrak_t_cj_evt-bp,
        name   TYPE string,
        tel    TYPE string,
        mail   TYPE string,
        masked TYPE abap_bool,
      END OF ty_who.

    TYPES:
      BEGIN OF ty_day,
        agg_date  TYPE dats,
        started   TYPE i,
        submitted TYPE i,
      END OF ty_day,
      tt_day TYPE STANDARD TABLE OF ty_day WITH EMPTY KEY.

  PRIVATE SECTION.

    CONSTANTS c_circ TYPE i VALUE 264.

    DATA mo_client TYPE REF TO z2ui5_if_client.
    DATA mv_days   TYPE string.
    DATA ms_theme  TYPE zcl_rak_cj_theme=>ty_theme.

    DATA mt_row     TYPE tt_row.
    DATA mt_step    TYPE tt_step.
    DATA mt_blocker TYPE tt_blocker.
    DATA mt_reason  TYPE tt_reason.
    DATA mt_stuck   TYPE tt_stuck.
    DATA mt_evt     TYPE tt_evt.
    DATA ms_who     TYPE ty_who.
    DATA mt_day     TYPE tt_day.

    METHODS load.
    METHODS load_overview IMPORTING iv_from TYPE dats.
    METHODS load_funnel   IMPORTING iv_from TYPE dats.
    METHODS load_blockers IMPORTING iv_from TYPE dats.
    METHODS load_trend    IMPORTING iv_from TYPE dats.
    METHODS load_reasons  IMPORTING iv_from TYPE dats.
    METHODS load_stuck    IMPORTING iv_from TYPE dats.
    METHODS load_session.
    METHODS load_who      IMPORTING iv_bp TYPE zrak_t_cj_evt-bp.

    METHODS render.
    METHODS render_filter   IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_selector IMPORTING io TYPE REF TO z2ui5_cl_xml_view.

    METHODS css      RETURNING VALUE(rv) TYPE string.
    METHODS hero     RETURNING VALUE(rv) TYPE string.
    METHODS kpis     RETURNING VALUE(rv) TYPE string.
    METHODS overview RETURNING VALUE(rv) TYPE string.
    METHODS funnel   RETURNING VALUE(rv) TYPE string.
    METHODS blockers RETURNING VALUE(rv) TYPE string.
    METHODS paywall RETURNING VALUE(rv) TYPE string.
    METHODS stuck    RETURNING VALUE(rv) TYPE string.
    METHODS session  RETURNING VALUE(rv) TYPE string.
    METHODS ts       IMPORTING iv_ts TYPE timestampl
                     RETURNING VALUE(rv) TYPE string.

    METHODS sect     IMPORTING iv_title  TYPE string
                               iv_sub    TYPE string OPTIONAL
                               iv_body   TYPE string
                     RETURNING VALUE(rv) TYPE string.
    METHODS card     IMPORTING iv_label  TYPE string
                               iv_value  TYPE string
                               iv_sub    TYPE string OPTIONAL
                               iv_alert  TYPE abap_bool DEFAULT abap_false
                     RETURNING VALUE(rv) TYPE string.
    METHODS ring     IMPORTING iv_pct    TYPE ty_pct
                     RETURNING VALUE(rv) TYPE string.
    METHODS spark    RETURNING VALUE(rv) TYPE string.
    METHODS line     IMPORTING iv_pct    TYPE ty_pct
                               iv_name   TYPE string
                               iv_value  TYPE string
                     RETURNING VALUE(rv) TYPE string.
    METHODS note     IMPORTING iv_text   TYPE string
                     RETURNING VALUE(rv) TYPE string.
    METHODS safe     IMPORTING iv_html   TYPE string
                     RETURNING VALUE(rv) TYPE string.
    METHODS pct      IMPORTING iv_part   TYPE i
                               iv_whole  TYPE i
                     RETURNING VALUE(rv) TYPE ty_pct.
    METHODS totals   RETURNING VALUE(rs) TYPE ty_row.

ENDCLASS.



CLASS ZCL_RAK_CJ_DASH IMPLEMENTATION.


  METHOD blockers.
    DATA(lv_title) = COND string(
      WHEN mv_jny IS NOT INITIAL
      THEN |Fields that block citizens &middot; { mv_jny }|
      ELSE 'Fields that block citizens' ).

    IF mt_blocker IS INITIAL.
      rv = sect( iv_title = lv_title
                 iv_body  = note( 'No validation failures recorded in the window.' ) ).
      RETURN.
    ENDIF.

    DATA(lv_top) = mt_blocker[ 1 ]-cnt.

    DATA lv_body TYPE string.
    LOOP AT mt_blocker INTO DATA(ls).
      lv_body = lv_body && line( iv_pct   = pct( iv_part = ls-cnt iv_whole = lv_top )
                                 iv_name  = CONV string( ls-detail )
                                 iv_value = |{ ls-cnt } time(s)| ).
    ENDLOOP.

    rv = sect(
      iv_title = lv_title
      iv_sub   = 'The list to hand a service owner, ranked by how often each field stopped someone'
      iv_body  = lv_body && note(
        'Field names only - the event log never stores what a citizen typed.'
     && ' This panel reads the raw event table rather than the aggregate,'
     && ' because the field name is not an aggregate dimension.' ) ).
  ENDMETHOD.


  METHOD card.
    rv = safe(
      |<div class='rkC| && COND string( WHEN iv_alert = abap_true THEN | rkA| ) && |'>| &&
      |<div class='rkCL'>{ iv_label }</div>| &&
      |<div class='rkCV'>{ iv_value }</div>| &&
      COND string( WHEN iv_sub IS NOT INITIAL
                   THEN |<div class='rkCS'>{ iv_sub }</div>| ) &&
      |</div>| ).
  ENDMETHOD.


  METHOD css.
    rv = safe(
      |<style>| &&
      |.rkD\{font-family:{ ms_theme-font };color:{ ms_theme-navy };| &&
      |max-width:1120px;\}| &&
      |.rkD *\{box-sizing:border-box;\}| &&

      |.rkTop\{display:flex;align-items:flex-end;justify-content:space-between;| &&
      |flex-wrap:wrap;gap:1rem;\}| &&
      |.rkH\{font-size:1.6rem;font-weight:700;letter-spacing:-.015em;margin:0;\}| &&
      |.rkH b\{color:{ ms_theme-brand };\}| &&
      |.rkS\{font-size:.8125rem;color:{ ms_theme-navy_md };margin:.25rem 0 0;\}| &&
      |.rkRule\{width:34px;height:4px;background:{ ms_theme-brand };| &&
      |border-radius:2px;margin:.55rem 0 0;\}| &&

      |.rkCard\{background:{ ms_theme-card_bg };| &&
      |border:1px solid { ms_theme-line_clr };| &&
      |border-radius:{ ms_theme-radius };box-shadow:{ ms_theme-shadow };| &&
      |position:relative;overflow:hidden;margin:0 0 1.15rem;\}| &&
      |.rkCard::before\{content:'';position:absolute;top:0;left:0;right:0;| &&
      |height:3px;background:{ ms_theme-line_clr };\}| &&
      |.rkCard.rkA::before\{background:{ ms_theme-brand };\}| &&
      |.rkPad\{padding:1rem 1.15rem;\}| &&

      |.rkSecT\{font-size:.9375rem;font-weight:700;margin:0;\}| &&
      |.rkSecS\{font-size:.75rem;color:{ ms_theme-navy_md };margin:.1rem 0 .85rem;\}| &&

      |.rkHero\{display:grid;grid-template-columns:168px 1fr;gap:1.4rem;| &&
      |align-items:center;\}| &&
      |.rkStats\{display:grid;grid-template-columns:repeat(3,1fr);gap:1rem;\}| &&
      |.rkStat\{border-left:3px solid { ms_theme-line_clr };padding-left:.8rem;\}| &&
      |.rkStat.rkAcc\{border-left-color:{ ms_theme-brand };\}| &&
      |.rkStatV\{font-size:1.7rem;font-weight:700;line-height:1.15;| &&
      |direction:ltr;unicode-bidi:embed;\}| &&
      |.rkStatL\{font-size:.6875rem;font-weight:600;letter-spacing:.06em;| &&
      |text-transform:uppercase;color:{ ms_theme-navy_md };margin-top:.15rem;\}| &&

      |.rkG\{display:grid;gap:12px;grid-template-columns:repeat(4,1fr);\}| &&
      |@media (max-width:900px)\{.rkG\{grid-template-columns:repeat(2,1fr);\}| &&
      |.rkHero\{grid-template-columns:1fr;\}| &&
      |.rkStats\{grid-template-columns:repeat(3,1fr);\}\}| &&

      |.rkC\{background:{ ms_theme-card_bg };| &&
      |border:1px solid { ms_theme-line_clr };| &&
      |border-radius:{ ms_theme-radius };padding:.8rem .95rem;| &&
      |position:relative;overflow:hidden;min-height:86px;\}| &&
      |.rkC::before\{content:'';position:absolute;top:0;left:0;right:0;| &&
      |height:3px;background:{ ms_theme-line_clr };\}| &&
      |.rkC.rkA::before\{background:{ ms_theme-brand };\}| &&
      |.rkC.rkA .rkCV\{color:{ ms_theme-brand };\}| &&
      |.rkCL\{font-size:.6875rem;font-weight:600;letter-spacing:.06em;| &&
      |text-transform:uppercase;color:{ ms_theme-navy_md };\}| &&
      |.rkCV\{font-size:1.4rem;font-weight:700;line-height:1.35;| &&
      |direction:ltr;unicode-bidi:embed;\}| &&
      |.rkCS\{font-size:.71875rem;color:{ ms_theme-navy_md };\}| &&

      |.rkL\{display:grid;grid-template-columns:1fr 180px 128px;gap:.9rem;| &&
      |align-items:center;padding:.5rem 0;| &&
      |border-bottom:1px solid { ms_theme-line_clr };\}| &&
      |.rkL:last-child\{border-bottom:none;\}| &&
      |.rkLN\{font-size:.8125rem;font-weight:600;overflow:hidden;| &&
      |text-overflow:ellipsis;white-space:nowrap;\}| &&
      |.rkLN a\{color:{ ms_theme-navy };text-decoration:none;\}| &&
      |.rkLN a:hover\{color:{ ms_theme-brand };text-decoration:underline;\}| &&
      |.rkLV\{font-size:.75rem;color:{ ms_theme-navy_md };text-align:right;| &&
      |direction:ltr;unicode-bidi:embed;white-space:nowrap;\}| &&
      |@media (max-width:640px)\{.rkL\{grid-template-columns:1fr 90px;\}| &&
      |.rkLV\{grid-column:1 / -1;text-align:left;\}\}| &&

      |.rkNote\{font-size:.71875rem;color:{ ms_theme-navy_md };| &&
      |background:{ ms_theme-page_bg };border-radius:4px;| &&
      |padding:.5rem .7rem;margin-top:.9rem;line-height:1.5;\}| &&

      |.rkR\{display:grid;grid-template-columns:1fr auto 92px;gap:.9rem;| &&
      |align-items:center;padding:.55rem 0;| &&
      |border-bottom:1px solid { ms_theme-line_clr };\}| &&
      |.rkR:last-child\{border-bottom:none;\}| &&
      |.rkRN\{font-size:.8125rem;font-weight:700;\}| &&
      |.rkRS\{font-size:.71875rem;color:{ ms_theme-navy_md };margin-top:.1rem;\}| &&
      |.rkRV\{font-size:.71875rem;color:{ ms_theme-navy_md };text-align:right;| &&
      |direction:ltr;unicode-bidi:embed;\}| &&
      |.rkTags\{display:flex;gap:.3rem;flex-wrap:wrap;justify-content:flex-end;\}| &&
      |.rkT\{font-size:.65rem;font-weight:600;padding:.12rem .45rem;| &&
      |border-radius:999px;background:{ ms_theme-page_bg };| &&
      |color:{ ms_theme-navy_md };white-space:nowrap;\}| &&
      |.rkT.rkTa\{background:{ ms_theme-brand_lt };color:{ ms_theme-brand };\}| &&
      |.rkT.rkTok\{background:{ ms_theme-page_bg };color:{ ms_theme-navy };\}| &&

      |.rkWho\{display:flex;justify-content:space-between;align-items:center;| &&
      |gap:1rem;background:{ ms_theme-page_bg };border-radius:4px;| &&
      |padding:.7rem .85rem;margin-bottom:.9rem;\}| &&
      |.rkTel\{font-size:1.05rem;font-weight:700;direction:ltr;| &&
      |unicode-bidi:embed;white-space:nowrap;\}| &&

      |.rkE\{display:grid;grid-template-columns:86px 52px 1fr;gap:.6rem;| &&
      |align-items:baseline;padding:.3rem 0;font-size:.75rem;| &&
      |border-left:3px solid { ms_theme-line_clr };padding-left:.7rem;\}| &&
      |.rkE.rkEb\{border-left-color:{ ms_theme-brand };\}| &&
      |.rkEt\{color:{ ms_theme-navy_md };direction:ltr;unicode-bidi:embed;\}| &&
      |.rkEk\{font-weight:700;letter-spacing:.04em;\}| &&
      |.rkE.rkEb .rkEk\{color:{ ms_theme-brand };\}| &&
      |.rkEd\{color:{ ms_theme-navy_md };\}| &&

      |.rkBar\{background:{ ms_theme-card_bg };| &&
      |border:1px solid { ms_theme-line_clr };border-radius:{ ms_theme-radius };| &&
      |box-shadow:{ ms_theme-shadow };padding:.65rem .9rem;| &&
      |margin:0 0 1.15rem;gap:.55rem;flex-wrap:wrap;\}| &&
      |.rkBarL\{font-size:.6875rem;font-weight:600;letter-spacing:.06em;| &&
      |text-transform:uppercase;color:{ ms_theme-navy_md };| &&
      |white-space:nowrap;padding-inline-end:.15rem;\}| &&
      |.rkBarL2\{padding-inline-start:.9rem;\}| &&
      |.rkBar .sapMComboBox,.rkBar .sapMInputBase\{max-width:100%;\}| &&
      |.rkBar .sapMInputBaseContentWrapper\{border:1px solid { ms_theme-line_clr };| &&
      |border-radius:{ ms_theme-radius };background:{ ms_theme-card_bg };\}| &&
      |.rkBar .sapMInputBaseContentWrapper:hover\{| &&
      |border-color:{ ms_theme-navy_md };\}| &&
      |.rkBar .sapMFocus .sapMInputBaseContentWrapper,| &&
      |.rkBar .sapMInputBaseContentWrapper:focus-within\{| &&
      |border-color:{ ms_theme-brand };| &&
      |box-shadow:0 0 0 3px { ms_theme-brand_lt };\}| &&
      |.rkBar .sapMInputBaseInner\{color:{ ms_theme-navy };| &&
      |font-size:.8125rem;\}| &&

      |.rkD .sapMBtnEmphasized\{background:{ ms_theme-brand };| &&
      |border-color:{ ms_theme-brand };border-radius:999px;\}| &&
      |.rkD .sapMBtnEmphasized:hover\{background:{ ms_theme-brand_dk };| &&
      |border-color:{ ms_theme-brand_dk };\}| &&
      |.rkD .sapMBtnEmphasized .sapMBtnContent\{color:#fff;font-weight:600;\}| &&
      |.rkD .sapMBtnTransparent .sapMBtnContent\{color:{ ms_theme-navy_md };\}| &&
      |.rkD .sapMBtnTransparent:hover .sapMBtnContent\{color:{ ms_theme-brand };\}| &&
      |</style>| ).
  ENDMETHOD.


  METHOD funnel.
    IF mt_step IS INITIAL.
      rv = sect( iv_title = |Step funnel &middot; { mv_jny }|
                 iv_body  = note( 'No step events for this journey in the window.' ) ).
      RETURN.
    ENDIF.

    DATA lv_body TYPE string.
    LOOP AT mt_step INTO DATA(ls).
      lv_body = lv_body && line(
        iv_pct   = ls-keep
        iv_name  = |Step { ls-step_no }|
        iv_value = |{ ls-views } reached &middot; { ls-keep } %| &&
                   COND string( WHEN ls-vfails > 0
                                THEN | &middot; { ls-vfails } blocked| ) ).
    ENDLOOP.

    rv = sect(
      iv_title = |Step funnel &middot; { mv_jny }|
      iv_sub   = 'Share of step 0 that reached each step'
      iv_body  = lv_body && note(
        'Drop-off is measured on step views, not on Next presses. A step reached'
     && ' by a programmatic advance - the one after payment - has no Next event,'
     && ' so the two counts will not reconcile on paid journeys.' ) ).
  ENDMETHOD.


  METHOD hero.
    DATA(ls) = totals( ).
    DATA(lv_starts) = ls-launched + ls-resumed.

    DATA(lv_pay) = COND string( WHEN ls-pay_start > 0
                                THEN |{ ls-pay_rate } %| ELSE |&ndash;| ).

    rv = safe( |<div class='rkCard rkA'><div class='rkPad'><div class='rkHero'>| )
      && ring( ls-completion )
      && safe(
           |<div class='rkStats'>| &&
           |<div class='rkStat rkAcc'><div class='rkStatV'>{ lv_starts }</div>| &&
           |<div class='rkStatL'>Sessions started</div></div>| &&
           |<div class='rkStat'><div class='rkStatV'>{ ls-submitted }</div>| &&
           |<div class='rkStatL'>Submitted</div></div>| &&
           |<div class='rkStat'><div class='rkStatV'>{ lv_pay }</div>| &&
           |<div class='rkStatL'>Payment success</div></div>| &&
           |</div>| )
      && safe( |</div></div></div>| ).
  ENDMETHOD.


  METHOD kpis.
    DATA(ls) = totals( ).

    DATA(lv_lost) = ls-pay_start - ls-pay_done - ls-pay_stop.
    IF lv_lost < 0.
      lv_lost = 0.
    ENDIF.

    DATA(lv_body) = safe( |<div class='rkG'>| ) &&
      card( iv_label = 'Payment P95'
            iv_value = COND string( WHEN ls-pay_p95 > 0
                                    THEN |{ ls-pay_p95 / 1000 } s| ELSE |&ndash;| )
            iv_sub   = 'slowest 5% of payments' ) &&
      card( iv_label = 'Pop-up loss'
            iv_value = |{ lv_lost }|
            iv_sub   = 'started, never resolved'
            iv_alert = xsdbool( lv_lost > 0 ) ) &&
      card( iv_label = 'Payments taken'
            iv_value = |{ ls-pay_done }|
            iv_sub   = |of { ls-pay_start } started| ) &&
      card( iv_label = 'Abandoned waits'
            iv_value = |{ ls-pay_stop }|
            iv_sub   = 'stopped waiting'
            iv_alert = xsdbool( ls-pay_stop > 0 ) ) &&
      card( iv_label = 'Validation blocks'
            iv_value = |{ ls-val_fails }|
            iv_sub   = 'citizens stopped by a field' ) &&
      card( iv_label = 'Gate blockers'
            iv_value = |{ ls-gates }|
            iv_sub   = 'must be zero before QA'
            iv_alert = xsdbool( ls-gates > 0 ) ) &&
      card( iv_label = 'Slow backend calls'
            iv_value = |{ ls-slow_calls }|
            iv_sub   = COND string( WHEN ls-slow_p95 > 0
                                    THEN |P95 { ls-slow_p95 } ms|
                                    ELSE 'over 1500 ms' )
            iv_alert = xsdbool( ls-slow_calls > 0 ) ) &&
      card( iv_label = 'Journeys seen'
            iv_value = |{ lines( mt_row ) }|
            iv_sub   = 'with events in window' ) &&
      safe( |</div>| ).

    rv = sect( iv_title = 'Right now'
               iv_sub   = 'A red edge means the number wants attention'
               iv_body  = lv_body ).
  ENDMETHOD.


  METHOD line.
    DATA(lv_w) = iv_pct.
    IF lv_w > 100.
      lv_w = 100.
    ENDIF.
    IF lv_w < 0.
      lv_w = 0.
    ENDIF.

    DATA(lv_fill) = COND string( WHEN iv_pct < 50 THEN ms_theme-brand
                                 WHEN iv_pct < 80 THEN ms_theme-brand_hi
                                 ELSE ms_theme-navy ).

    rv = safe(
      |<div class='rkL'>| &&
      |<div class='rkLN'>{ iv_name }</div>| &&
      |<svg viewBox='0 0 100 6' preserveAspectRatio='none' | &&
      |style='width:180px;height:7px;display:block'>| &&
      |<rect x='0' y='0' width='100' height='6' rx='3' | &&
      |fill='{ ms_theme-line_clr }'/>| &&
      |<rect x='0' y='0' width='{ lv_w }' height='6' rx='3' | &&
      |fill='{ lv_fill }'/>| &&
      |</svg>| &&
      |<div class='rkLV'>{ iv_value }</div>| &&
      |</div>| ).
  ENDMETHOD.


  METHOD load.
    DATA(lv_from) = CONV dats( sy-datum - CONV i( mv_days ) + 1 ).

    load_overview( lv_from ).
    load_funnel( lv_from ).
    load_blockers( lv_from ).
    load_reasons( lv_from ).
    load_stuck( lv_from ).
    load_session( ).
    load_trend( lv_from ).
  ENDMETHOD.


  METHOD load_blockers.
    CLEAR mt_blocker.

    DATA(lv_lo) = CONV timestampl( |{ iv_from }000000| ).

    IF mv_jny IS INITIAL.
      SELECT detail, COUNT( * ) AS cnt
        FROM zrak_t_cj_evt
        WHERE tstamp  >= @lv_lo
          AND evt_type = 'VALF'
          AND detail  <> @space
        GROUP BY detail
        ORDER BY cnt DESCENDING
        INTO TABLE @mt_blocker
        UP TO 10 ROWS.
    ELSE.
      SELECT detail, COUNT( * ) AS cnt
        FROM zrak_t_cj_evt
        WHERE tstamp    >= @lv_lo
          AND evt_type   = 'VALF'
          AND journey_id = @mv_jny
          AND detail    <> @space
        GROUP BY detail
        ORDER BY cnt DESCENDING
        INTO TABLE @mt_blocker
        UP TO 10 ROWS.
    ENDIF.
  ENDMETHOD.


  METHOD load_funnel.
    CLEAR mt_step.

    IF mv_jny IS INITIAL.
      RETURN.
    ENDIF.

    SELECT step_no, evt_type, SUM( sess_cnt ) AS sess_cnt
      FROM zrak_t_cj_agg
      WHERE agg_date  >= @iv_from
        AND journey_id = @mv_jny
      GROUP BY step_no, evt_type
      ORDER BY step_no
      INTO TABLE @DATA(lt_s).

    LOOP AT lt_s INTO DATA(ls_s).
      IF NOT line_exists( mt_step[ step_no = ls_s-step_no ] ).
        APPEND VALUE ty_step( step_no = ls_s-step_no ) TO mt_step.
      ENDIF.

      READ TABLE mt_step ASSIGNING FIELD-SYMBOL(<ls>)
           WITH KEY step_no = ls_s-step_no.

      CASE ls_s-evt_type.
        WHEN 'VIEW'. <ls>-views  = ls_s-sess_cnt.
        WHEN 'NEXT'. <ls>-nexts  = ls_s-sess_cnt.
        WHEN 'BACK'. <ls>-backs  = ls_s-sess_cnt.
        WHEN 'VALF'. <ls>-vfails = ls_s-sess_cnt.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

    SORT mt_step BY step_no.

    DATA lv_first TYPE i.
    LOOP AT mt_step ASSIGNING FIELD-SYMBOL(<ls_k>).
      IF sy-tabix = 1.
        lv_first = <ls_k>-views.
      ENDIF.
      <ls_k>-keep = pct( iv_part = <ls_k>-views iv_whole = lv_first ).
    ENDLOOP.
  ENDMETHOD.


  METHOD load_overview.
    CLEAR mt_row.

    SELECT journey_id, evt_type,
           SUM( cnt )      AS cnt,
           SUM( sess_cnt ) AS sess_cnt,
           MAX( dur_p95 )  AS p95
      FROM zrak_t_cj_agg
      WHERE agg_date >= @iv_from
      GROUP BY journey_id, evt_type
      ORDER BY journey_id
      INTO TABLE @DATA(lt_g).

    LOOP AT lt_g INTO DATA(ls_g).
      IF NOT line_exists( mt_row[ journey_id = ls_g-journey_id ] ).
        APPEND VALUE ty_row( journey_id = ls_g-journey_id ) TO mt_row.
      ENDIF.

      READ TABLE mt_row ASSIGNING FIELD-SYMBOL(<ls>)
           WITH KEY journey_id = ls_g-journey_id.

      CASE ls_g-evt_type.
        WHEN 'LNCH'. <ls>-launched   = ls_g-sess_cnt.
        WHEN 'RSUM'. <ls>-resumed    = ls_g-sess_cnt.
        WHEN 'SUBM'. <ls>-submitted  = ls_g-sess_cnt.
        WHEN 'DELE'. <ls>-deleted    = ls_g-sess_cnt.
        WHEN 'PAYS'. <ls>-pay_start  = ls_g-cnt.
        WHEN 'PAYD'. <ls>-pay_done   = ls_g-cnt.
                     <ls>-pay_p95    = ls_g-p95.
        WHEN 'PAYX'. <ls>-pay_fail   = ls_g-cnt.
        WHEN 'PAYW'. <ls>-pay_stop   = ls_g-cnt.
        WHEN 'PAYB'. <ls>-pay_block  = ls_g-cnt.
        WHEN 'GATE'. <ls>-gates      = ls_g-cnt.
        WHEN 'VALF'. <ls>-val_fails  = ls_g-cnt.
        WHEN 'PERF'. <ls>-slow_calls = ls_g-cnt.
                     <ls>-slow_p95   = ls_g-p95.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

    LOOP AT mt_row ASSIGNING FIELD-SYMBOL(<ls_c>).
      <ls_c>-completion = pct( iv_part  = <ls_c>-submitted
                               iv_whole = <ls_c>-launched + <ls_c>-resumed ).
      <ls_c>-pay_rate   = pct( iv_part  = <ls_c>-pay_done
                               iv_whole = <ls_c>-pay_start ).
    ENDLOOP.

    SORT mt_row BY completion ASCENDING journey_id ASCENDING.
  ENDMETHOD.


  METHOD load_reasons.
    CLEAR mt_reason.

    DATA(lv_lo) = CONV timestampl( |{ iv_from }000000| ).

    IF mv_jny IS INITIAL.
      SELECT detail, COUNT( * ) AS cnt
        FROM zrak_t_cj_evt
        WHERE tstamp  >= @lv_lo
          AND evt_type = 'PAYB'
        GROUP BY detail
        ORDER BY cnt DESCENDING
        INTO TABLE @mt_reason
        UP TO 8 ROWS.
    ELSE.
      SELECT detail, COUNT( * ) AS cnt
        FROM zrak_t_cj_evt
        WHERE tstamp    >= @lv_lo
          AND evt_type   = 'PAYB'
          AND journey_id = @mv_jny
        GROUP BY detail
        ORDER BY cnt DESCENDING
        INTO TABLE @mt_reason
        UP TO 8 ROWS.
    ENDIF.
  ENDMETHOD.


  METHOD load_session.
    CLEAR mt_evt.
    CLEAR ms_who.

    IF mv_sess IS INITIAL.
      RETURN.
    ENDIF.

    SELECT tstamp, evt_type, step_no, outcome, detail, duration
      FROM zrak_t_cj_evt
      WHERE sess_id = @mv_sess
      ORDER BY tstamp
      INTO TABLE @mt_evt.

    READ TABLE mt_stuck INTO DATA(ls) WITH KEY sess_id = mv_sess.
    IF sy-subrc = 0 AND ls-bp IS NOT INITIAL.
      load_who( ls-bp ).
    ENDIF.
  ENDMETHOD.


  METHOD load_stuck.
*   Two steps on purpose. A single scan of the window would read every event of
*   every session; this reads the sessions that actually hit trouble, then reads
*   only those. Index Z02 serves the second half.
    CLEAR mt_stuck.

    DATA(lv_lo) = CONV timestampl( |{ iv_from }000000| ).

    SELECT DISTINCT sess_id FROM zrak_t_cj_evt
      WHERE tstamp   >= @lv_lo
        AND evt_type IN ( 'VALF', 'PAYB', 'GATE', 'PAYW', 'ERRQ' )
        AND sess_id  <> @space
      INTO TABLE @DATA(lt_cand)
      UP TO 300 ROWS.

    IF lt_cand IS INITIAL.
      RETURN.
    ENDIF.

    SELECT sess_id, bp, rolebp, role, journey_id, evt_type, step_no, tstamp, detail
      FROM zrak_t_cj_evt
      FOR ALL ENTRIES IN @lt_cand
      WHERE sess_id = @lt_cand-sess_id
      INTO TABLE @DATA(lt_e).

    LOOP AT lt_e INTO DATA(ls_e).
      IF NOT line_exists( mt_stuck[ sess_id = ls_e-sess_id ] ).
        APPEND VALUE ty_stuck( sess_id    = ls_e-sess_id
                               journey_id = ls_e-journey_id
                               t0         = ls_e-tstamp
                               t1         = ls_e-tstamp ) TO mt_stuck.
      ENDIF.

      READ TABLE mt_stuck ASSIGNING FIELD-SYMBOL(<ls>)
           WITH KEY sess_id = ls_e-sess_id.

      IF ls_e-bp IS NOT INITIAL.
        <ls>-bp = ls_e-bp.
      ENDIF.
      IF ls_e-rolebp IS NOT INITIAL.
        <ls>-rolebp = ls_e-rolebp.
      ENDIF.
      IF ls_e-role IS NOT INITIAL.
        <ls>-role = ls_e-role.
      ENDIF.
      IF ls_e-tstamp < <ls>-t0.
        <ls>-t0 = ls_e-tstamp.
      ENDIF.
      IF ls_e-tstamp > <ls>-t1.
        <ls>-t1        = ls_e-tstamp.
        <ls>-last_step = ls_e-step_no.
      ENDIF.

      CASE ls_e-evt_type.
        WHEN 'VALF'. <ls>-valf = <ls>-valf + 1.
                     IF <ls>-worst IS INITIAL.
                       <ls>-worst = |field { ls_e-detail }|.
                     ENDIF.
        WHEN 'PAYB'. <ls>-payb  = <ls>-payb + 1.
                     <ls>-worst = |payment refused: { ls_e-detail }|.
        WHEN 'GATE'. <ls>-gate  = <ls>-gate + 1.
        WHEN 'PAYW'. <ls>-worst = 'gave up waiting for payment'.
        WHEN 'BACK'. <ls>-backs = <ls>-backs + 1.
        WHEN 'ERRQ'. <ls>-errq  = <ls>-errq + 1.
                     <ls>-worst = 'system error'.
        WHEN 'SUBM'. <ls>-done  = abap_true.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

*   Weighted, not a raw count. A payment refusal or a system error is a worse
*   experience than one mistyped field, and somebody who finished anyway is not
*   waiting for a phone call.
    LOOP AT mt_stuck ASSIGNING FIELD-SYMBOL(<ls_s>).
      DATA(lv_secs) = CONV i( cl_abap_tstmp=>subtract( tstmp1 = <ls_s>-t1
                                                       tstmp2 = <ls_s>-t0 ) ).
      <ls_s>-mins  = lv_secs / 60.
      <ls_s>-score = <ls_s>-valf
                   + <ls_s>-payb  * 8
                   + <ls_s>-errq  * 8
                   + <ls_s>-gate  * 4
                   + <ls_s>-backs * 2.
      IF <ls_s>-done = abap_true.
        <ls_s>-score = <ls_s>-score / 4.
      ENDIF.
      IF <ls_s>-worst IS INITIAL.
        <ls_s>-worst = 'left without finishing'.
      ENDIF.
    ENDLOOP.

    DELETE mt_stuck WHERE score = 0.
    SORT mt_stuck BY score DESCENDING t1 DESCENDING.
  ENDMETHOD.


  METHOD load_trend.
    CLEAR mt_day.

    IF mv_jny IS INITIAL.
      SELECT agg_date, evt_type, SUM( sess_cnt ) AS sess_cnt
        FROM zrak_t_cj_agg
        WHERE agg_date >= @iv_from
        GROUP BY agg_date, evt_type
        ORDER BY agg_date
        INTO TABLE @DATA(lt_d).
    ELSE.
      SELECT agg_date, evt_type, SUM( sess_cnt ) AS sess_cnt
        FROM zrak_t_cj_agg
        WHERE agg_date  >= @iv_from
          AND journey_id = @mv_jny
        GROUP BY agg_date, evt_type
        ORDER BY agg_date
        INTO TABLE @lt_d.
    ENDIF.

    LOOP AT lt_d INTO DATA(ls_d).
      IF NOT line_exists( mt_day[ agg_date = ls_d-agg_date ] ).
        APPEND VALUE ty_day( agg_date = ls_d-agg_date ) TO mt_day.
      ENDIF.

      READ TABLE mt_day ASSIGNING FIELD-SYMBOL(<ls>)
           WITH KEY agg_date = ls_d-agg_date.

      CASE ls_d-evt_type.
        WHEN 'LNCH' OR 'RSUM'. <ls>-started   = <ls>-started + ls_d-sess_cnt.
        WHEN 'SUBM'.           <ls>-submitted = ls_d-sess_cnt.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.

    SORT mt_day BY agg_date.
  ENDMETHOD.


  METHOD load_who.
*   A citizen's telephone number is personal data and is not shown to anybody who
*   happens to open this page. Without ZRAK_CJ_PII activity 03 the number is
*   masked to its last three digits - enough for an agent to confirm they are
*   looking at the right record, not enough to call anyone.
*
*   The check fails CLOSED: if the authorisation object does not exist yet,
*   SY-SUBRC is non-zero and the number stays masked. Create it in SU21 with a
*   single ACTVT field.
    ms_who-bp = iv_bp.

    SELECT SINGLE mc_name1, name_org1, name_first, name_last
      FROM but000 WHERE partner = @iv_bp
      INTO @DATA(ls_bp).

    IF sy-subrc = 0.
      ms_who-name = COND string(
        WHEN ls_bp-name_org1 IS NOT INITIAL THEN ls_bp-name_org1
        WHEN ls_bp-name_first IS NOT INITIAL OR ls_bp-name_last IS NOT INITIAL
        THEN |{ ls_bp-name_first } { ls_bp-name_last }|
        ELSE ls_bp-mc_name1 ).
      CONDENSE ms_who-name.
    ENDIF.

    SELECT SINGLE addrnumber FROM but020
      WHERE partner = @iv_bp
      INTO @DATA(lv_adr).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE tel_number FROM adr2
      WHERE addrnumber = @lv_adr AND flgdefault = @abap_true
      INTO @DATA(lv_tel).

    SELECT SINGLE smtp_addr FROM adr6
      WHERE addrnumber = @lv_adr AND flgdefault = @abap_true
      INTO @DATA(lv_mail).

    AUTHORITY-CHECK OBJECT 'ZRAK_CJ_PII'
      ID 'ACTVT' FIELD '03'.

    IF sy-subrc = 0.
      ms_who-tel  = lv_tel.
      ms_who-mail = lv_mail.
    ELSE.
      ms_who-masked = abap_true.
      IF strlen( lv_tel ) > 3.
        ms_who-tel = |*** *** { substring( val = lv_tel off = strlen( lv_tel ) - 3 ) }|.
      ENDIF.
      IF lv_mail IS NOT INITIAL.
        ms_who-mail = `(hidden)`.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD note.
    rv = safe( |<div class='rkNote'>{ iv_text }</div>| ).
  ENDMETHOD.


  METHOD overview.
    DATA lv_body TYPE string.

    LOOP AT mt_row INTO DATA(ls) TO 15.
      DATA(lv_starts) = ls-launched + ls-resumed.
      lv_body = lv_body && line(
        iv_pct   = ls-completion
        iv_name  = CONV string( ls-journey_id )
        iv_value = |{ ls-completion } % &middot; { ls-submitted }/{ lv_starts }| ).
    ENDLOOP.

    rv = sect( iv_title = 'Completion by journey'
               iv_sub   = 'Worst first. Navy is healthy, red is not.'
               iv_body  = lv_body ).
  ENDMETHOD.


  METHOD paywall.
    DATA(ls) = totals( ).

    IF ls-pay_start = 0 AND ls-pay_block = 0.
      rv = ``.
      RETURN.
    ENDIF.

    DATA(lv_lost) = ls-pay_start - ls-pay_done - ls-pay_stop.
    IF lv_lost < 0.
      lv_lost = 0.
    ENDIF.

    DATA(lv_body) = safe( |<div class='rkG'>| ) &&
      card( iv_label = 'Pay pressed, refused'
            iv_value = |{ ls-pay_block }|
            iv_sub   = 'never reached the gateway'
            iv_alert = xsdbool( ls-pay_block > 0 ) ) &&
      card( iv_label = 'Reached gateway'
            iv_value = |{ ls-pay_start }|
            iv_sub   = 'payment page opened' ) &&
      card( iv_label = 'Paid'
            iv_value = |{ ls-pay_done }|
            iv_sub   = |{ ls-pay_rate } % of those| ) &&
      card( iv_label = 'Lost at gateway'
            iv_value = |{ lv_lost + ls-pay_stop }|
            iv_sub   = |{ lv_lost } no answer &middot; { ls-pay_stop } gave up|
            iv_alert = xsdbool( lv_lost + ls-pay_stop > 0 ) ) &&
      safe( |</div>| ).

    IF mt_reason IS NOT INITIAL.
      DATA(lv_top) = mt_reason[ 1 ]-cnt.
      DATA lv_list TYPE string.

      LOOP AT mt_reason INTO DATA(ls_r).
        DATA(lv_code) = CONV string( ls_r-detail ).
        DATA(lv_why)  = COND string(
          WHEN lv_code = 'NOFEE'
          THEN 'Fee not raised yet - workflow had not posted the open item'
          WHEN lv_code = 'INPROG'
          THEN 'A payment was already running for this application'
          WHEN lv_code = 'NOCASE'
          THEN 'No case number - the commit did not reach the backend'
          WHEN lv_code = 'NOSCREEN'
          THEN 'PAY_SCREEN not configured on the payment step'
          WHEN lv_code = 'PREPFAIL'
          THEN 'Gateway preparation failed'
          ELSE lv_code ).

        lv_list = lv_list && line( iv_pct   = pct( iv_part = ls_r-cnt iv_whole = lv_top )
                                   iv_name  = lv_why
                                   iv_value = |{ ls_r-cnt } time(s)| ).
      ENDLOOP.

      lv_body = lv_body
        && safe( |<div class='rkSecS' style='margin-top:1rem'>| &&
                 |Why a Pay press went nowhere</div>| )
        && lv_list.
    ENDIF.

    rv = sect(
      iv_title = 'Payment, end to end'
      iv_sub   = 'Where a Pay press stops. Refused means the engine never opened the gateway.'
      iv_body  = lv_body && note(
        'A refusal is not the citizen''s fault and not the gateway''s. NOFEE and'
     && ' INPROG are timing - the fee posts through workflow, billing and FI-CA'
     && ' after the case is created, so a Pay press can legitimately arrive too'
     && ' early. NOCASE, NOSCREEN and PREPFAIL are defects.' ) ).
  ENDMETHOD.


  METHOD pct.
    IF iv_whole <= 0.
      rv = 0.
      RETURN.
    ENDIF.
    rv = iv_part * 100 / iv_whole.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title         = ` `
                                       shownavbutton = abap_false
                                       class         = 'sapUiSizeCozy' ).

    page->html( content = css( ) sanitizecontent = abap_false ).

    DATA(box) = page->vbox( class = 'sapUiMediumMargin rkD' ).

    DATA(hdr) = box->hbox( justifycontent = 'SpaceBetween'
                           alignitems     = 'End'
                           class          = 'sapUiSmallMarginBottom' ).

    hdr->html( content = safe(
      |<div><div class='rkH'>Service <b>Analytics</b></div>| &&
      |<div class='rkS'>Customer Journey Studio &middot; every figure derived | &&
      |from the event log at read time</div>| &&
      |<div class='rkRule'></div></div>| ) sanitizecontent = abap_false ).

    render_filter( hdr ).

    IF mt_row IS INITIAL.
      box->message_strip(
        text     = 'No events in the selected window. Either nothing ran, or'
                && ' ZRAK_CJ_EVT_AGG has not been run for these days yet -'
                && ' the dashboard reads the aggregate, not the raw log.'
        type     = 'Information'
        showicon = abap_true ).
      mo_client->view_display( view->stringify( ) ).
      RETURN.
    ENDIF.

    render_selector( box ).

    DATA(lv_html) = hero( ) && spark( ) && kpis( ) && paywall( )
                 && stuck( ) && session( ) && overview( ).

    IF mv_jny IS NOT INITIAL.
      lv_html = lv_html && funnel( ).
    ENDIF.

    lv_html = lv_html && blockers( ).

    box->html( content = lv_html sanitizecontent = abap_false ).


    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD render_filter.
    DATA(bar) = io->hbox( alignitems = 'Center' ).

    bar->button( text  = 'Today'
                 type  = COND string( WHEN mv_days = '1' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'D1' ) ).
    bar->button( text  = '7 days'
                 type  = COND string( WHEN mv_days = '7' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'D7' ) ).
    bar->button( text  = '30 days'
                 type  = COND string( WHEN mv_days = '30' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'D30' ) ).
    bar->button( text  = '90 days'
                 type  = COND string( WHEN mv_days = '90' THEN 'Emphasized' ELSE 'Transparent' )
                 press = mo_client->_event( 'D90' ) ).

    IF mv_jny IS NOT INITIAL.
      bar->object_status( text  = mv_jny
                          state = 'Information'
                          class = 'sapUiSmallMarginBegin' ).
      bar->link( text  = 'clear'
                 press = mo_client->_event( 'CLEARJNY' )
                 class = 'sapUiTinyMarginBegin' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_selector.
*   At the top, because it is a filter and filters belong above what they filter.
*   Dropdowns rather than a button row: eleven journeys already wrap and there are
*   thirty-two departments coming, and sap.m.ComboBox type-aheads, so the free
*   search is inherent rather than something to build.
    DATA(bar) = io->hbox( alignitems = 'Center' class = 'rkBar' ).

    bar->html( content = safe( |<span class='rkBarL'>Journey</span>| )
               sanitizecontent = abap_false ).

    DATA(cbj) = bar->combobox( selectedkey = mo_client->_bind_edit( mv_jny )
                               change      = mo_client->_event( 'PICKJNY' )
                               placeholder = 'all journeys - type to search'
                               width       = '26rem' ).
    LOOP AT mt_row INTO DATA(ls_p).
      DATA(lv_starts) = ls_p-launched + ls_p-resumed.
      cbj->item( key  = CONV string( ls_p-journey_id )
                 text = |{ ls_p-journey_id }  -  { ls_p-completion } % ({ ls_p-submitted }/{ lv_starts })| ).
    ENDLOOP.

    IF mv_jny IS NOT INITIAL.
      bar->link( text  = 'clear'
                 press = mo_client->_event( 'CLEARJNY' )
                 class = 'sapUiTinyMarginBegin' ).
    ENDIF.

    IF mt_stuck IS NOT INITIAL.
      bar->html( content = safe( |<span class='rkBarL rkBarL2'>Citizen</span>| )
                 sanitizecontent = abap_false ).

      DATA(cbs) = bar->combobox( selectedkey = mo_client->_bind_edit( mv_sess )
                                 change      = mo_client->_event( 'PICKSESS' )
                                 placeholder = 'who hit trouble - type to search'
                                 width       = '28rem' ).
      LOOP AT mt_stuck INTO DATA(ls_s) TO 50.
        DATA(lv_who) = COND string( WHEN ls_s-bp IS NOT INITIAL
                                    THEN |BP { ls_s-bp }|
                                    ELSE `unidentified` ).
        cbs->item( key  = CONV string( ls_s-sess_id )
                   text = |{ lv_who }  -  { ls_s-journey_id }  -  { ls_s-worst }| ).
      ENDLOOP.

      IF mv_sess IS NOT INITIAL.
        bar->link( text  = 'close'
                   press = mo_client->_event( 'CLEARSESS' )
                   class = 'sapUiTinyMarginBegin' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD ring.
*   One text element inside the ring, sized in user units. Two of them - the
*   figure and a caption - collided at every viewport, because a font size in
*   user units scales with the viewBox and 8px became 12. The caption belongs
*   outside the circle where it has room.
    DATA(lv_p) = iv_pct.
    IF lv_p > 100.
      lv_p = 100.
    ENDIF.
    IF lv_p < 0.
      lv_p = 0.
    ENDIF.

    DATA(lv_off) = c_circ - CONV i( c_circ * lv_p / 100 ).

    DATA(lv_col) = COND string( WHEN iv_pct < 50 THEN ms_theme-brand
                                WHEN iv_pct < 80 THEN ms_theme-brand_hi
                                ELSE ms_theme-navy ).

    rv = safe(
      |<div style='text-align:center'>| &&
      |<svg viewBox='0 0 100 100' style='width:150px;height:150px;display:block'>| &&
      |<circle cx='50' cy='50' r='42' fill='none' | &&
      |stroke='{ ms_theme-line_clr }' stroke-width='9'/>| &&
      |<circle cx='50' cy='50' r='42' fill='none' stroke='{ lv_col }' | &&
      |stroke-width='9' stroke-linecap='round' stroke-dasharray='{ c_circ }' | &&
      |stroke-dashoffset='{ lv_off }' transform='rotate(-90 50 50)'/>| &&
      |<text x='50' y='56' text-anchor='middle' direction='ltr' | &&
      |font-size='17' font-weight='700' | &&
      |fill='{ ms_theme-navy }'>{ iv_pct }%</text>| &&
      |</svg>| &&
      |<div class='rkStatL' style='margin-top:.3rem'>Completion</div>| &&
      |</div>| ).
  ENDMETHOD.


  METHOD safe.
    rv = iv_html.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD sect.
    rv = safe( |<div class='rkCard'><div class='rkPad'>| &&
               |<div class='rkSecT'>{ iv_title }</div>| &&
               COND string( WHEN iv_sub IS NOT INITIAL
                            THEN |<div class='rkSecS'>{ iv_sub }</div>| ) )
      && iv_body
      && safe( |</div></div>| ).
  ENDMETHOD.


  METHOD session.
    IF mv_sess IS INITIAL OR mt_evt IS INITIAL.
      rv = ``.
      RETURN.
    ENDIF.

    READ TABLE mt_stuck INTO DATA(ls_h) WITH KEY sess_id = mv_sess.

    DATA(lv_nm) = COND string( WHEN ms_who-name IS NOT INITIAL
                               THEN ms_who-name ELSE `Name not on file` ).
    DATA(lv_bp) = COND string( WHEN ms_who-bp IS NOT INITIAL
                               THEN |BP { ms_who-bp }|
                               ELSE `no partner recorded on this session` ).
    DATA(lv_tl) = COND string( WHEN ms_who-tel IS NOT INITIAL
                               THEN ms_who-tel ELSE `no number on file` ).

    DATA(lv_who) = safe(
      |<div class='rkWho'><div>| &&
      |<div class='rkRN'>{ lv_nm }</div>| &&
      |<div class='rkRS'>{ lv_bp }</div></div>| &&
      |<div class='rkTel'>{ lv_tl }</div></div>| ).

    IF ms_who-masked = abap_true.
      lv_who = lv_who && note(
        'Number masked. Full contact details need ZRAK_CJ_PII activity 03 -'
     && ' ask Basis for the call-centre role.' ).
    ENDIF.

    DATA lv_rows TYPE string.
    LOOP AT mt_evt INTO DATA(ls).
      DATA(lv_bad) = xsdbool( ls-outcome = 'BLOCK' OR ls-outcome = 'FAIL'
                           OR ls-evt_type = 'ERRQ' ).

      lv_rows = lv_rows && safe(
        |<div class='rkE| && COND string( WHEN lv_bad = abap_true THEN | rkEb| ) && |'>| &&
        |<div class='rkEt'>{ ts( ls-tstamp ) }</div>| &&
        |<div class='rkEk'>{ ls-evt_type }</div>| &&
        |<div class='rkEd'>step { ls-step_no }| &&
        COND string( WHEN ls-detail IS NOT INITIAL THEN | &middot; { ls-detail }| ) &&
        COND string( WHEN ls-duration > 0 THEN | &middot; { ls-duration } ms| ) &&
        |</div></div>| ).
    ENDLOOP.

    rv = sect(
      iv_title = |Session &middot; { ls_h-journey_id }|
      iv_sub   = 'Everything this citizen did, in order. Red lines are where it went wrong.'
      iv_body  = lv_who && lv_rows ).
  ENDMETHOD.


  METHOD spark.
    IF lines( mt_day ) < 2.
      rv = ``.
      RETURN.
    ENDIF.

    DATA lv_max TYPE i.
    LOOP AT mt_day INTO DATA(ls_m).
      IF ls_m-started > lv_max.
        lv_max = ls_m-started.
      ENDIF.
    ENDLOOP.
    IF lv_max < 1.
      lv_max = 1.
    ENDIF.

    DATA(lv_n)   = lines( mt_day ).
    DATA(lv_gap) = CONV i( 300 / ( lv_n - 1 ) ).

    DATA lv_ps TYPE string.
    DATA lv_pu TYPE string.
    DATA lv_i  TYPE i.

    LOOP AT mt_day INTO DATA(ls_d).
      DATA(lv_x)  = lv_i * lv_gap.
      DATA(lv_ys) = 44 - CONV i( ls_d-started   * 38 / lv_max ).
      DATA(lv_yu) = 44 - CONV i( ls_d-submitted * 38 / lv_max ).
      lv_ps = |{ lv_ps } { lv_x },{ lv_ys }|.
      lv_pu = |{ lv_pu } { lv_x },{ lv_yu }|.
      lv_i = lv_i + 1.
    ENDLOOP.

    rv = sect(
      iv_title = 'Daily shape'
      iv_sub   = |Grey started, red submitted, across { lv_n } day(s)|
      iv_body  = safe(
        |<svg viewBox='0 0 300 48' preserveAspectRatio='none' | &&
        |style='width:100%;height:70px;display:block'>| &&
        |<polyline fill='none' stroke='{ ms_theme-line_clr }' stroke-width='2' | &&
        |stroke-linejoin='round' points='{ lv_ps }'/>| &&
        |<polyline fill='none' stroke='{ ms_theme-brand }' stroke-width='2' | &&
        |stroke-linejoin='round' points='{ lv_pu }'/>| &&
        |</svg>| ) ).
  ENDMETHOD.


  METHOD stuck.
    IF mt_stuck IS INITIAL.
      rv = sect( iv_title = 'Citizens who hit trouble'
                 iv_body  = note( 'Nobody hit a validation failure, a payment refusal'
                               && ' or an error in this window.' ) ).
      RETURN.
    ENDIF.

    DATA lv_rows TYPE string.
    DATA lv_i    TYPE i.

    LOOP AT mt_stuck INTO DATA(ls) TO 25.
      lv_i = lv_i + 1.

      DATA(lv_tags) = ``.
      IF ls-valf > 0.
        lv_tags = lv_tags && safe( |<span class='rkT'>{ ls-valf } field| &&
                                   COND string( WHEN ls-valf > 1 THEN |s| ) && |</span>| ).
      ENDIF.
      IF ls-payb > 0.
        lv_tags = lv_tags && safe( |<span class='rkT rkTa'>payment</span>| ).
      ENDIF.
      IF ls-gate > 0.
        lv_tags = lv_tags && safe( |<span class='rkT rkTa'>gate</span>| ).
      ENDIF.
      IF ls-errq > 0.
        lv_tags = lv_tags && safe( |<span class='rkT rkTa'>error</span>| ).
      ENDIF.
      IF ls-backs > 0.
        lv_tags = lv_tags && safe( |<span class='rkT'>{ ls-backs } back</span>| ).
      ENDIF.
      IF ls-done = abap_true.
        lv_tags = lv_tags && safe( |<span class='rkT rkTok'>finished anyway</span>| ).
      ENDIF.

      DATA(lv_wholbl) = COND string( WHEN ls-bp IS NOT INITIAL
                                     THEN |BP { ls-bp }|
                                     ELSE `unidentified visitor` ).

      IF ls-rolebp IS NOT INITIAL AND ls-rolebp <> ls-bp.
        lv_wholbl = lv_wholbl
                 && COND string( WHEN ls-role IS NOT INITIAL
                                 THEN | acting as { ls-role } for { ls-rolebp }|
                                 ELSE | acting for { ls-rolebp }| ).
      ENDIF.

      lv_rows = lv_rows
        && safe( |<div class='rkR'><div>| &&
                 |<div class='rkRN'>{ lv_wholbl }</div>| &&
                 |<div class='rkRS'>{ ls-journey_id } &middot; step { ls-last_step }| &&
                 | &middot; { ls-mins } min &middot; { ls-worst }</div></div>| &&
                 |<div class='rkTags'>| )
        && lv_tags
        && safe( |</div><div class='rkRV'>{ ts( ls-t1 ) }</div></div>| ).
    ENDLOOP.

    rv = sect(
      iv_title = 'Citizens who hit trouble'
      iv_sub   = 'Worst experience first. Pick one to see the whole session and how to reach them.'
      iv_body  = lv_rows && note(
        'Weighted, not a raw count: a payment refusal or a system error scores'
     && ' higher than one mistyped field, and somebody who finished anyway scores'
     && ' a quarter - they are not waiting for a call.' ) ).
  ENDMETHOD.


  METHOD totals.
    LOOP AT mt_row INTO DATA(ls).
      rs-launched   = rs-launched   + ls-launched.
      rs-resumed    = rs-resumed    + ls-resumed.
      rs-submitted  = rs-submitted  + ls-submitted.
      rs-pay_start  = rs-pay_start  + ls-pay_start.
      rs-pay_done   = rs-pay_done   + ls-pay_done.
      rs-pay_stop   = rs-pay_stop   + ls-pay_stop.
      rs-pay_block  = rs-pay_block  + ls-pay_block.
      rs-val_fails  = rs-val_fails  + ls-val_fails.
      rs-gates      = rs-gates      + ls-gates.
      rs-slow_calls = rs-slow_calls + ls-slow_calls.
      IF ls-pay_p95 > rs-pay_p95.
        rs-pay_p95 = ls-pay_p95.
      ENDIF.
      IF ls-slow_p95 > rs-slow_p95.
        rs-slow_p95 = ls-slow_p95.
      ENDIF.
    ENDLOOP.

    rs-completion = pct( iv_part  = rs-submitted
                         iv_whole = rs-launched + rs-resumed ).
    rs-pay_rate   = pct( iv_part  = rs-pay_done
                         iv_whole = rs-pay_start ).
  ENDMETHOD.


  METHOD ts.
    IF iv_ts IS INITIAL.
      rv = `-`.
      RETURN.
    ENDIF.
    CONVERT TIME STAMP iv_ts TIME ZONE sy-zonlo
            INTO DATE DATA(lv_d) TIME DATA(lv_t).
    rv = |{ lv_d+6(2) }.{ lv_d+4(2) } { lv_t(2) }:{ lv_t+2(2) }|.
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.

    IF mv_days IS INITIAL.
      mv_days  = '30'.
      ms_theme = zcl_rak_cj_theme=>active( ).
    ENDIF.

    DATA(lv_event) = client->get( )-event.

    CASE lv_event.
      WHEN 'D1'.  mv_days = '1'.
      WHEN 'D7'.  mv_days = '7'.
      WHEN 'D30'. mv_days = '30'.
      WHEN 'D90'. mv_days = '90'.
      WHEN 'CLEARJNY'. CLEAR mv_jny.
      WHEN 'CLEARSESS'. CLEAR mv_sess.
*     PICKJNY and PICKSESS carry no payload. The combobox is bound two-way, so
*     MV_JNY and MV_SESS already hold the new key by the time the event arrives -
*     the event exists only to force the round trip that reloads the data.
      WHEN 'PICKJNY' OR 'PICKSESS'.
      WHEN OTHERS.
    ENDCASE.

    load( ).
    render( ).
  ENDMETHOD.
ENDCLASS.
