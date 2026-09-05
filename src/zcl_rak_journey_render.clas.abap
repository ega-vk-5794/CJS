CLASS zcl_rak_journey_render DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

    METHODS render.
    METHODS render_header    IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_wizard    IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_wizard_left IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
*   Hidden buttons the stepper markup fires - see RENDER_GOTO.
    METHODS render_goto      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_tabs      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_accordion IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_single    IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_step      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                       is_step   TYPE zif_rak_journey=>ty_step
                                       iv_index  TYPE i.
    METHODS render_one       IMPORTING io_form  TYPE REF TO z2ui5_cl_xml_view
                                       is_field TYPE zif_rak_journey=>ty_field.
    METHODS render_block     IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                       is_field  TYPE zif_rak_journey=>ty_field.
    METHODS render_pay       IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                       is_field  TYPE zif_rak_journey=>ty_field.
    METHODS render_captcha   IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                       is_field  TYPE zif_rak_journey=>ty_field.
*   The challenge as a base64 SVG data URI, drawn from the engine's
*   current code and seed. Never the answer in text form - see the method.
    METHODS captcha_svg      RETURNING VALUE(rv) TYPE string.
    METHODS render_attach    IMPORTING io_form  TYPE REF TO z2ui5_cl_xml_view
                                       is_field TYPE zif_rak_journey=>ty_field.
    METHODS render_uploader  IMPORTING io_box   TYPE REF TO z2ui5_cl_xml_view
                                       iv_field TYPE string
                                       iv_types TYPE string
                                       iv_maxmb TYPE i DEFAULT 0
                                       iv_scope TYPE string OPTIONAL
                                       iv_key   TYPE string OPTIONAL.
    METHODS render_chips     IMPORTING io_box          TYPE REF TO z2ui5_cl_xml_view
                                       iv_field        TYPE string
                                       iv_key          TYPE string OPTIONAL
                             RETURNING VALUE(rv_count) TYPE i.
    METHODS render_popup.
    METHODS render_footer    IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                       iv_linear TYPE abap_bool.
    METHODS render_feedback IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view.

    METHODS is_result_step IMPORTING iv_step      TYPE i
                           RETURNING VALUE(rv_is) TYPE abap_bool.

    METHODS journey_done RETURNING VALUE(rv) TYPE abap_bool.

    METHODS disp IMPORTING iv_value  TYPE string
                 RETURNING VALUE(rv) TYPE string.

    METHODS render_result IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                    is_field  TYPE zif_rak_journey=>ty_field.
*   THE 150-CHARACTER CEILING, AND THE WAY ROUND IT.
*
*   ZLABEL is CHAR(150). A consent declaration is not 150 characters, so it
*   arrives cut mid-sentence - and cut on INSERT, in the database, which is
*   why no amount of wrapping or CSS in the renderer brings the rest back.
*   EC01's certification lands at exactly 150, ending "...responsible for".
*
*   DEFAULT_VAL is CHAR(1000) and already carries prefixed instructions
*   rather than plain values - see the CHK: convention in the engine's
*   ROWCHK_ handler. TEXT: is the same idea for long field text:
*
*     TEXT:I hereby certify that ...        the paragraph, literally
*     TEXT:@042                             message 042 from ZRAK_T_CJ_TXT
*
*   The @ form is the one to reach for when the text must be bilingual.
*   DEFAULT_VAL has no _AR twin, so a literal paragraph is language-neutral
*   and will show its English to an Arabic reader; ZRAK_T_CJ_TXT holds
*   TEXT_EN and TEXT_AR and is resolved by sy-langu, at CHAR(255) each.
*
*   Returns the ordinary label when no TEXT: is present, so every journey
*   configured before this existed renders exactly as it did.
    METHODS long_text IMPORTING is_field       TYPE zif_rak_journey=>ty_field
                     RETURNING VALUE(rv_text) TYPE string.
    METHODS req_label   IMPORTING io_form  TYPE REF TO z2ui5_cl_xml_view
                                  is_field TYPE zif_rak_journey=>ty_field.
    METHODS before_field IMPORTING io_view  TYPE REF TO z2ui5_cl_xml_view
                                   is_field TYPE zif_rak_journey=>ty_field.
    METHODS after_field  IMPORTING io_view  TYPE REF TO z2ui5_cl_xml_view
                                   is_field TYPE zif_rak_journey=>ty_field.
    METHODS f4_opts    IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
*   PREFERRED PARAMETER IV_NAME - BIND_OF( name ) is called as a single-value
*   functional call throughout this class and from ZCL_RAK_JOURNEY_ENGINE;
*   without this addition, adding IV_SUFFIX as a second IMPORTING parameter
*   would turn every one of those into a syntax error (see the note on
*   VAL_GET( ) in ZCL_RAK_JOURNEY_ENGINE for the full reasoning).
    METHODS bind_of IMPORTING iv_name         TYPE string
                               iv_suffix       TYPE string OPTIONAL
                       PREFERRED PARAMETER iv_name
                     RETURNING VALUE(rv_bind)  TYPE string.
    METHODS bind_state IMPORTING iv_name   TYPE string
                                 iv_suffix TYPE string OPTIONAL
                       RETURNING VALUE(rv) TYPE string.
    METHODS render_block_laid_out
      IMPORTING io_parent  TYPE REF TO z2ui5_cl_xml_view
                iv_journey TYPE zcl_rak_cj_lay=>ty_key
                iv_step    TYPE zcl_rak_cj_lay=>ty_key
                iv_block   TYPE zcl_rak_cj_lay=>ty_key
                it_fields  TYPE zif_rak_journey=>ty_step-fields.

    METHODS render_cell
      IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                is_cell   TYPE zcl_rak_cj_lay=>ty_cell
                is_field  TYPE zif_rak_journey=>ty_field
                iv_break  TYPE abap_bool DEFAULT abap_false.
  PRIVATE SECTION.
    CLASS-DATA gt_f4c TYPE zif_rak_cjs_types=>tt_f4c.
    DATA mo_e TYPE REF TO zcl_rak_journey_engine.
*   Set by RENDER_STEP( ) when it has printed the file-type hint once at the top
*   of the step, so RENDER_UPLOADER( ) does not repeat it under every button.
*   Recomputed per step, so a step whose uploaders disagree still gets its own.
    DATA mv_att_hint_hide TYPE abap_bool.
    DATA mv_in_cell TYPE abap_bool.
*   Set while rendering a FLOW cell. MV_FLOW_CELL stops RENDER_ONE forcing the
*   control to 100%, which in a flex row would squeeze the button to nothing.
*   MO_LBL_TGT is where REQ_LABEL puts the label - the cell itself, so the
*   label stays ABOVE while the control and the button pair up beside it.
    DATA mv_flow_cell TYPE abap_bool.
    DATA mo_lbl_tgt   TYPE REF TO z2ui5_cl_xml_view.
*   A field that must own its row whatever the layout says - see the
*   implementation for which those are and why the layout cannot be trusted
*   to know it.
    METHODS wide_field IMPORTING is_field     TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rv_on) TYPE abap_bool.
    METHODS pay_field IMPORTING iv_index       TYPE i
                      RETURNING VALUE(rv_name) TYPE string.
*   {FIELDNAME} in a resolved LONG_TEXT( ) - e.g. a declaration reading
*   "I, {APPLICANTNAME}, certify..." - substituted with that field's
*   current value. Only ever touches text that actually contains braces,
*   so a journey with no placeholders renders exactly as it did before
*   this existed. This is what D001 and E026 both left an unimplemented
*   "REVIEW: substitute {APPLICANT_NAME}" comment waiting on.
    METHODS subst_fields CHANGING cv_text TYPE string.
*   The one place the finished view leaves the engine. See MV_VIEW_SIG on
*   ZCL_RAK_JOURNEY_ENGINE for why it is not always VIEW_DISPLAY( ).
    METHODS send_view IMPORTING iv_xml TYPE string.
*   Resolves one TABLE column header through ZRAK_T_CJ_TXT when it is written
*   as @nnn. See the method for why the spec cannot carry an Arabic twin.
    METHODS col_header IMPORTING iv_raw   TYPE string
                       RETURNING VALUE(rv) TYPE string.
    METHODS status_state IMPORTING iv_value     TYPE string
                                   iv_map       TYPE string OPTIONAL
                         RETURNING VALUE(rv_st) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_RENDER IMPLEMENTATION.


  METHOD after_field.
    IF mo_e->mo_logic IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        mo_e->mo_logic->on_render_after_field( io_ctx = mo_e io_view = io_view is_field = is_field ).
      CATCH cx_root INTO DATA(lx_af).
        mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
          text = |on_render_after_field failed for { is_field-name }: { lx_af->get_text( ) }| ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD before_field.
    IF mo_e->mo_logic IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        mo_e->mo_logic->on_render_before_field( io_ctx = mo_e io_view = io_view is_field = is_field ).
      CATCH cx_root INTO DATA(lx_bf).
        mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
          text = |on_render_before_field failed for { is_field-name }: { lx_bf->get_text( ) }| ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bind_of.
*   COMP_NAME( ), matching VAL_GET( )/VAL_SET( )/BUILD_MODEL( ) - see the note on
*   BUILD_MODEL( ). A bare TO_UPPER( ) here would try to bind a control straight
*   to a component name the model never has, on any field whose name needed
*   sanitising - CX_SY_STRUCT_COMP_NAME, uncaught, on the first render.
*
*   IV_SUFFIX is appended AFTER COMP_NAME( ), matching how BUILD_MODEL( ) builds
*   a companion component ( _IDTYPE, _IX, _EXP ): COMP_NAME( base name ) then the
*   raw suffix. Passing an already-suffixed string as IV_NAME instead - the
*   pattern this replaces - hashes a different, longer string once base name
*   plus suffix exceeds 23 characters, and the ASSIGN COMPONENT below then finds
*   nothing: the control silently binds to no value.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    DATA(lv_comp) = zcl_rak_journey_util=>comp_name( iv_name ) && iv_suffix.
    ASSIGN COMPONENT lv_comp OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
    IF sy-subrc = 0.
      rv_bind = mo_e->mo_client->_bind_edit( <f> ).
    ENDIF.
  ENDMETHOD.


  METHOD bind_state.
*   Same key BIND_OF( ) computes - see the note there.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    DATA(lv_comp) = zcl_rak_journey_util=>comp_name( iv_name ) && iv_suffix.
    ASSIGN COMPONENT lv_comp OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
    IF sy-subrc = 0.
      rv = mo_e->mo_client->_bind( <f> ).
    ENDIF.
  ENDMETHOD.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD disp.
    rv = iv_value.
    IF rv CO '0123456789' AND rv IS NOT INITIAL.
      SHIFT rv LEFT DELETING LEADING '0'.
      IF rv IS INITIAL.
        rv = '0'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD f4_opts.
    DATA(lv_key) = mo_e->mv_lang && '#' && to_upper( is_field-rollname )
                            && '#' && to_upper( is_field-shlp )
                            && '#' && to_upper( is_field-domname ).
    READ TABLE gt_f4c INTO DATA(ls_c) WITH TABLE KEY key = lv_key.
    IF sy-subrc = 0.
      rt = ls_c-opts.
      RETURN.
    ENDIF.
    IF mo_e->mo_f4 IS INITIAL.
      CREATE OBJECT mo_e->mo_f4.
    ENDIF.
    rt = mo_e->mo_f4->resolve( iv_rollname = is_field-rollname
                               iv_shlp     = is_field-shlp
                               iv_domname  = is_field-domname ).
    IF mo_e->mv_trace = abap_true.
      mo_e->trace( |F4      { is_field-name } · rollname { COND string( WHEN is_field-rollname IS NOT INITIAL THEN is_field-rollname ELSE '(none)' ) }| &&
                   | · shlp { COND string( WHEN is_field-shlp IS NOT INITIAL THEN is_field-shlp ELSE '(none)' ) }| &&
                   | · domain { COND string( WHEN is_field-domname IS NOT INITIAL THEN is_field-domname ELSE '(none)' ) }| &&
                   | · resolved { lines( rt ) } option(s)| ).
*     A list that came back exactly at the cap was almost certainly cut, and a cut
*     list is indistinguishable from a complete one by looking at it - the citizen
*     cannot find their entry and nothing on the page says why.
*
*     A GATE rather than a plain trace line, so it lands in the blocker list next
*     to the zero-options gate below it - the two failures are siblings and belong
*     in the same place. Both are inside the trace guard, so both need trace=x:
*     that is a real limitation, not a design decision, and if truncation ever
*     bites in production this is the check to lift out of the guard.
      IF lines( rt ) >= zcl_rak_f4_resolver=>c_max.
        mo_e->trace_gate( |Field { is_field-name } resolved { lines( rt ) } options, | &&
                          |which is the cap - the list is almost certainly | &&
                          |TRUNCATED and the citizen cannot pick anything past it. | &&
                          |Narrow the search help or raise ZCL_RAK_F4_RESOLVER=>C_MAX.| ).
      ENDIF.

      IF rt IS INITIAL AND ( is_field-rollname IS NOT INITIAL OR is_field-shlp IS NOT INITIAL
                             OR is_field-domname IS NOT INITIAL ).
        mo_e->trace_gate( |Field { is_field-name } asks for value help but resolved | &&
                          |ZERO options. The citizen gets an empty list with no | &&
                          |explanation. Check the search help has a selection method | &&
                          |or text table - one whose values come only from a search | &&
                          |help exit cannot be read this way.| ).
      ENDIF.
    ENDIF.
    IF lines( gt_f4c ) > 200.
      CLEAR gt_f4c.
    ENDIF.
    INSERT VALUE #( key = lv_key opts = rt ) INTO TABLE gt_f4c.
  ENDMETHOD.


  METHOD is_result_step.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_s) INDEX iv_step + 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_any) = abap_false.

    LOOP AT ls_s-fields INTO DATA(ls_f).
      IF mo_e->mo_rules->is_hidden( ls_f ) = abap_true.
        CONTINUE.
      ENDIF.
      lv_any = abap_true.
      IF ls_f-type <> 'DISPLAY' AND ls_f-type <> 'READONLY' AND ls_f-type <> 'RESULT'.
        RETURN.
      ENDIF.
    ENDLOOP.

    rv_is = lv_any.
  ENDMETHOD.


  METHOD journey_done.
*   Closed counts as done. It is a different ending from submitted - nothing was
*   created - but it is still an ending, and the auto-draw on the last step has to
*   agree with the terminal gate in RENDER( ) or the two disagree about whether the
*   journey is over.
    IF mo_e->mv_submitted = abap_true OR mo_e->mv_closed = abap_true
       OR mo_e->mv_case_number IS NOT INITIAL.
      rv = abap_true.
      RETURN.
    ENDIF.
    DATA lv_i TYPE i.
    lv_i = 0.
    WHILE lv_i < lines( mo_e->ms_config-steps ).
      DATA(lv_pf) = pay_field( lv_i ).
      IF lv_pf IS NOT INITIAL AND mo_e->zif_rak_journey~get_val( lv_pf ) = 'PAID'.
        rv = abap_true.
        RETURN.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD pay_field.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_s) INDEX iv_index + 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT ls_s-fields INTO DATA(ls_f).
      IF to_upper( ls_f-type ) = 'PAYFEE'.
        rv_name = ls_f-name.
        RETURN.
      ENDIF.
    ENDLOOP.

    IF ls_s-next_req IS NOT INITIAL.
      DATA(ls_g) = mo_e->safe_field( ls_s-next_req ).
      IF to_upper( ls_g-type ) = 'PAYFEE'.
        rv_name = ls_g-name.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page(
      title         = ` `
      shownavbutton = abap_false
      class         = mo_e->mo_css->density_class( ) ).

    IF mo_e->ms_config-journey_id IS INITIAL.
      LOOP AT mo_e->mt_msg INTO DATA(ls_e).
        page->message_strip( text = zcl_rak_journey_util=>esc( ls_e-text ) type = ls_e-type showicon = abap_true class = 'sapUiSmallMargin' ).
      ENDLOOP.
      send_view( view->stringify( ) ).
      RETURN.
    ENDIF.

    page->html( content = mo_e->mo_css->build_theme_css( ) sanitizecontent = abap_false ).
*   A blocked Next or Submit leaves an Error line in MT_MSG. That is the signal to
*   take the citizen to the field at fault instead of restoring the scroll
*   position they had - see SCROLL_KEEPER.
    DATA(lv_bad) = abap_false.
    LOOP AT mo_e->mt_msg TRANSPORTING NO FIELDS WHERE type = 'Error'.
      lv_bad = abap_true.
      EXIT.
    ENDLOOP.
    page->html( content = mo_e->mo_css->scroll_keeper( lv_bad ) sanitizecontent = abap_false ).
    IF mo_e->mv_open_url IS NOT INITIAL.
      page->html( content = zcl_rak_journey_util=>open_url_html( mo_e->mv_open_url ) sanitizecontent = abap_false ).
      CLEAR mo_e->mv_open_url.
    ENDIF.
    IF mo_e->mv_close_page = abap_true.
      page->html( content         = `<script>(function(){try{if(window.parent!==window){` &&
                                    `window.parent.postMessage({rakAction:"CLOSE"},"*");}}catch(e){}` &&
                                    `try{window.close();}catch(e){}` &&
                                    `setTimeout(function(){if(history.length>1){history.back();}},2600);})();</script>`
                  sanitizecontent = abap_false ).
      CLEAR mo_e->mv_close_page.
    ENDIF.
    render_header( page ).

    LOOP AT mo_e->mt_msg INTO DATA(ls_msg).
      page->message_strip( text     = zcl_rak_journey_util=>esc( ls_msg-text )
                           type     = ls_msg-type
                           showicon = abap_true
                           class    = 'sapUiTinyMarginBegin sapUiTinyMarginEnd' ).
    ENDLOOP.

*   Submitted OR closed. Both are terminal and both need this page - RENDER_RESULT
*   already knows the difference and draws the thank-you card for one and the
*   reference card for the other. Without MV_CLOSED here the flag was set, nothing
*   read it, and pressing Close simply redrew the step it was pressed on.
    IF mo_e->mv_submitted = abap_true OR mo_e->mv_closed = abap_true.
      render_result( io_parent = page is_field = VALUE #( name = '' type = 'RESULT' ) ).
      render_feedback( page ).
      send_view( view->stringify( ) ).
      render_popup( ).
      RETURN.
    ENDIF.

*   How many messages had been drawn before the fields were rendered. Anything
*   appended past this point was added BY the field rendering - the LIST lines
*   naming where each dropdown's options came from - and the loop above had
*   already been and gone, so those lines were collected and never shown. This
*   is the only reason they are drawn at the bottom rather than with the rest.
    DATA(lv_msg_pre) = lines( mo_e->mt_msg ).

    CASE mo_e->ms_config-theme-layout_mode.
      WHEN 'TABS'.
        render_tabs( page ).
      WHEN 'ACCORDION'.
        render_accordion( page ).
      WHEN 'SINGLE'.
        render_single( page ).
      WHEN 'WIZARD_LEFT'.
        render_wizard_left( page ).
      WHEN OTHERS.
        render_wizard( page ).
    ENDCASE.

    IF lines( mo_e->mt_msg ) > lv_msg_pre.
      LOOP AT mo_e->mt_msg INTO DATA(ls_late) FROM lv_msg_pre + 1.
        page->message_strip( text     = zcl_rak_journey_util=>esc( ls_late-text )
                             type     = ls_late-type
                             showicon = abap_true
                             class    = 'sapUiTinyMarginBegin sapUiTinyMarginEnd' ).
      ENDLOOP.
    ENDIF.

    send_view( view->stringify( ) ).

    render_popup( ).
  ENDMETHOD.


  METHOD render_accordion.
    DATA lv_i TYPE i.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
      DATA(lo_panel) = io_parent->panel(
        headertext = zcl_rak_journey_util=>esc( |{ lv_i + 1 }. { ls_step-title }| )
        expandable = abap_true
        expanded   = xsdbool( lv_i = 0 )
        class      = mo_e->mo_css->cls( 'CARD' ) ).
      render_step( io_parent = lo_panel is_step = ls_step iv_index = lv_i ).
      lv_i = lv_i + 1.
    ENDLOOP.
    render_footer( io_parent = io_parent iv_linear = abap_false ).
  ENDMETHOD.


  METHOD render_attach.
*   An attachment label is drawn here, not through REQ_LABEL( ), so it kept the
*   CSS-class marker after REQ_LABEL( ) moved to the native property - and the
*   class alone draws nothing. Same REQUIRED property, same result.
    DATA(lv_req) = mo_e->mo_rules->is_required( is_field ).
    io_form->label(
      text     = zcl_rak_journey_util=>esc( COND #( WHEN is_field-attach_label IS NOT INITIAL
                              THEN is_field-attach_label ELSE |{ is_field-label } - attachment| ) )
      class    = 'sapUiFormLabelNoColon'
      required = lv_req ).
    DATA(lo_box) = io_form->vbox( ).

    DATA(lv_count) = render_chips( io_box = lo_box iv_field = is_field-name ).

    IF is_field-attach_multi = abap_true OR lv_count = 0.
      render_uploader( io_box   = lo_box
                       iv_field = is_field-name
                       iv_types = is_field-attach_types
                       iv_maxmb = is_field-attach_maxmb ).
    ENDIF.
  ENDMETHOD.


  METHOD captcha_svg.

*   A SEVEN-SEGMENT GLYPH, NOT AN <svg:text> ELEMENT, and that is the
*   entire security of the picture. An SVG carrying <text>5</text> puts
*   the answer in the DOM in plain sight - View Source reads it, and so
*   does the three-line script this control exists to stop. Drawn as
*   rectangles there is no character anywhere in the markup: the shape of
*   a 5 is seven boxes, and recovering the digit from them is the work
*   the citizen's eye does for free and a scraper does not.
*
*   Digits rather than letters: no case to confuse, no I/l/1 or O/0
*   lookalike pair, and the same five characters for an Arabic reader and
*   an English one.
    CONSTANTS c_w   TYPE i VALUE 208.
    CONSTANTS c_h   TYPE i VALUE 64.

    DATA lv_body TYPE string.
    DATA lv_g    TYPE string.
    DATA lv_i    TYPE i.
    DATA lv_x    TYPE i.
    DATA lv_y    TYPE i.
    DATA lv_rot  TYPE i.
    DATA lv_n    TYPE i.

*   Segments in the order a b c d e f g - top, upper right, lower right,
*   bottom, lower left, upper left, middle. Index is the digit plus one.
    DATA(lt_seg) = VALUE string_table(
      ( `1111110` ) ( `0110000` ) ( `1101101` ) ( `1111001` ) ( `0110011` )
      ( `1011011` ) ( `1011111` ) ( `1110000` ) ( `1111111` ) ( `1111011` ) ).

    DATA(lv_code) = mo_e->captcha_code( ).

*   Re-created from the seed the challenge was generated with, so a
*   repaint draws the same picture. Storing the finished SVG on the
*   instance would do the same job and park a kilobyte of markup in
*   Z2UI5_T_01 on every round trip of every journey that uses this.
    DATA(lo_r) = cl_abap_random_int=>create( seed = mo_e->mv_cap_seed
                                             min  = 0
                                             max  = 999 ).

*   Ground, then noise, then glyphs - painter's order, so the strokes
*   cross the digits instead of hiding under them.
    DATA(lv_ink) = `#2b3a4a`.
    lv_body = |<rect width="{ c_w }" height="{ c_h }" rx="8" fill="#eef1f5"/>|.

    DO 3 TIMES.
      DATA(lv_y1) = lo_r->get_next( ) MOD c_h.
      DATA(lv_y2) = lo_r->get_next( ) MOD c_h.
      DATA(lv_y3) = lo_r->get_next( ) MOD c_h.
      lv_body = |{ lv_body }<path d="M0 { lv_y1 } Q { c_w / 2 } { lv_y2 } { c_w } { lv_y3 }"| &&
                | fill="none" stroke="#b9c0cb" stroke-width="2"/>|.
    ENDDO.

    lv_i = 0.
    WHILE lv_i < strlen( lv_code ).
      lv_n   = CONV i( substring( val = lv_code off = lv_i len = 1 ) ).
      DATA(lv_f) = VALUE string( lt_seg[ lv_n + 1 ] OPTIONAL ).
*     Cannot happen while CAPTCHA_NEW( ) only ever emits 0-9, and checked
*     anyway: an offset read on an empty string is a dump, and a dump here
*     takes the whole page with it rather than one control.
      IF strlen( lv_f ) < 7.
        lv_i = lv_i + 1.
        CONTINUE.
      ENDIF.
      lv_x   = 14 + lv_i * 37.
      lv_y   = 12 + ( lo_r->get_next( ) MOD 7 ) - 3.
*     Enough tilt to defeat a fixed-grid template match, little enough
*     that the digit still reads at a glance on a phone.
      lv_rot = ( lo_r->get_next( ) MOD 31 ) - 15.

      CLEAR lv_g.
      IF substring( val = lv_f off = 0 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x + 5 }" y="{ lv_y }" width="14" height="5"/>|.
      ENDIF.
      IF substring( val = lv_f off = 1 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x + 19 }" y="{ lv_y + 5 }" width="5" height="14"/>|.
      ENDIF.
      IF substring( val = lv_f off = 2 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x + 19 }" y="{ lv_y + 21 }" width="5" height="14"/>|.
      ENDIF.
      IF substring( val = lv_f off = 3 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x + 5 }" y="{ lv_y + 35 }" width="14" height="5"/>|.
      ENDIF.
      IF substring( val = lv_f off = 4 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x }" y="{ lv_y + 21 }" width="5" height="14"/>|.
      ENDIF.
      IF substring( val = lv_f off = 5 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x }" y="{ lv_y + 5 }" width="5" height="14"/>|.
      ENDIF.
      IF substring( val = lv_f off = 6 len = 1 ) = '1'.
        lv_g = |{ lv_g }<rect x="{ lv_x + 5 }" y="{ lv_y + 17 }" width="14" height="5"/>|.
      ENDIF.

      lv_body = |{ lv_body }<g fill="{ lv_ink }" transform="rotate({ lv_rot } { lv_x + 12 }| &&
                | { lv_y + 20 })">{ lv_g }</g>|.
      lv_i = lv_i + 1.
    ENDWHILE.

    DATA(lv_svg) = |<svg xmlns="http://www.w3.org/2000/svg" width="{ c_w }" height="{ c_h }"| &&
                   | viewBox="0 0 { c_w } { c_h }">{ lv_body }</svg>|.

*   Base64 rather than a raw utf8 data URI: the SVG is going into an XML
*   attribute of the generated view, where every < and " would have to
*   survive two rounds of escaping intact. Base64 has neither.
*   Split across two statements, not one string template: an embedded
*   expression inside | | cannot contain a line break, and this call pair
*   does not fit in the 255 characters an ABAP source line allows.
    DATA(lv_x64) = z2ui5_cl_util_abap=>conv_encode_x_base64(
                     z2ui5_cl_util_abap=>conv_get_xstring_by_string( lv_svg ) ).
    rv = |data:image/svg+xml;base64,{ lv_x64 }|.

  ENDMETHOD.


  METHOD render_captcha.

*   Label, picture, answer box, refresh - in that order, and all of it
*   inside one bordered panel so it reads as a single question rather
*   than an image that happens to sit above an unrelated input.
    io_parent->title( text  = zcl_rak_journey_util=>esc( COND string(
                                WHEN is_field-label IS NOT INITIAL THEN is_field-label
                                ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-cap_title
                                                        iv_default = 'Verification' ) ) )
                      class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).

    DATA(lo_box) = io_parent->vbox( class = 'rakCaptcha' ).

*   ---- TEMPORARY PROBE - REMOVE ONCE THE REFRESH QUESTION IS SETTLED ----
*   The digits did not change after a failed attempt, and neither did the
*   noise strokes - which is the more useful half of that observation,
*   because the strokes are drawn from MV_CAP_SEED and the seed is taken
*   from the clock on every CAPTCHA_NEW( ). Identical jitter across two
*   round trips seconds apart means the seed did not move, which means
*   CAPTCHA_NEW( ) did not run in the build that is actually active.
*
*   So both halves of that go on the screen. C_BUILD answers 'is the code
*   on screen the code I just wrote' by observation instead of by trusting
*   the Class Builder, and the seed answers whether the challenge is being
*   regenerated. Neither leaks the answer: the seed drives the tilt of the
*   glyphs and the noise lines, never the digits.
*
*     build absent    the pulled render class is not active
*     seed unchanged  CAPTCHA_NEW( ) is not running - look at the engine,
*                     which is a different object and may not be active
*     seed changed    the challenge IS regenerating and the picture is
*                     stale, so the fault is in the repaint, not here
    DATA(lv_build) = `CAP-6`.
    DATA(lv_hint)  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-cap_hint
                                        iv_default = 'Type the five digits shown below.' ).
*   Built into a variable first: an embedded expression inside | | cannot
*   contain a line break, and this call does not fit on one 255-character
*   source line.
    lo_box->text( text  = |{ lv_hint }  ·  build { lv_build } · gen { mo_e->mv_cap_gen }| &&
                          | · seed { mo_e->mv_cap_seed } · len { strlen( mo_e->captcha_code( ) ) }|
                  class = 'rakCapHint' ).

    DATA(lo_row) = lo_box->hbox( alignitems = 'Center' class = 'rakCapRow' ).
    lo_row->image( src = captcha_svg( ) class = 'rakCapImg' ).

*   The refresh arrow is not a convenience. An image challenge has no
*   readable alternative, so the only thing standing between a citizen
*   who cannot resolve this particular picture and an unusable service is
*   another picture. See the note in ZCL_RAK_JOURNEY_ENGINE on what is
*   still missing for a citizen using a screen reader.
    lo_row->button( icon    = 'sap-icon://refresh'
                    type    = 'Transparent'
                    tooltip = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-cap_refresh
                                                 iv_default = 'Show a different code' )
                    press   = mo_e->mo_client->_event( 'CAPTCHA_NEW' ) ).

    lo_row->input( value       = bind_of( is_field-name )
                   width       = '9rem'
                   maxlength   = '5'
                   placeholder = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-cap_ph
                                                    iv_default = '5 digits' )
                   class       = |{ mo_e->mo_css->cls( 'INPUT' ) } sapUiSmallMarginBegin| ).

  ENDMETHOD.


  METHOD render_block.
    CASE is_field-type.
      WHEN 'PAYFEE'.
        render_pay( io_parent = io_parent is_field = is_field ).

      WHEN 'EDITABLE_TABLE'.
        mo_e->mo_grid->render_grid( io_parent = io_parent is_field = is_field ).

      WHEN 'SEARCH'.
        io_parent->title( text = zcl_rak_journey_util=>esc( is_field-label ) class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
        DATA(lo_box) = io_parent->hbox( class = 'rakSearch' alignitems = 'End' justifycontent = 'Start' ).
        DATA(lo_idt) = lo_box->combobox( selectedkey = bind_of( iv_name = is_field-name iv_suffix = '_IDTYPE' ) width = '12rem' ).
        LOOP AT is_field-options INTO DATA(ls_o).
          lo_idt->item( key = ls_o-key text = zcl_rak_journey_util=>opt_text( iv_key = ls_o-key iv_text = ls_o-text ) ).
        ENDLOOP.
        lo_box->input( value       = bind_of( is_field-name )
                       placeholder = is_field-placeholder
                       width       = '18rem'
                       submit      = mo_e->mo_client->_event( |SEARCH_{ is_field-name }| )
                       class       = 'sapUiSmallMarginBegin' ).
        lo_box->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' )
                        type  = 'Emphasized'
                        icon  = 'sap-icon://search'
                        class = 'sapUiSmallMarginBegin'
                        press = mo_e->mo_client->_event( |SEARCH_{ is_field-name }| ) ).
        lo_box->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-browse iv_default = 'Browse' )
                        icon  = 'sap-icon://value-help'
                        class = 'sapUiTinyMarginBegin'
                        press = mo_e->mo_client->_event( |BPOPEN_{ is_field-name }| ) ).

      WHEN 'UPLOAD'.
        io_parent->title( text = zcl_rak_journey_util=>esc( is_field-label ) class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
        DATA(lo_ub) = io_parent->vbox( class = 'rakSearch' ).
        render_chips( io_box = lo_ub iv_field = is_field-name ).
        render_uploader( io_box   = lo_ub
                         iv_field = is_field-name
                         iv_types = is_field-attach_types
                         iv_maxmb = is_field-attach_maxmb ).

      WHEN 'CAPTCHA'.
        render_captcha( io_parent = io_parent is_field = is_field ).

      WHEN 'REQPANEL'.
        DATA(lt_rqm) = mo_e->mo_rules->missing_required( mo_e->mv_step ).
        DATA(lo_rq)  = io_parent->vbox( class = 'rakReqPanel' ).
        lo_rq->title(
          text  = zcl_rak_journey_util=>esc( COND string( WHEN is_field-label IS NOT INITIAL
                                    THEN is_field-label ELSE 'On this step' ) )
          class = 'rakReqTitle' ).
        READ TABLE mo_e->ms_config-steps INTO DATA(ls_rqs) INDEX mo_e->mv_step + 1.
        DATA lv_rqn TYPE i.
        CLEAR lv_rqn.
        LOOP AT ls_rqs-fields INTO DATA(ls_rqf).
          IF mo_e->mo_rules->is_required( ls_rqf ) = abap_false
             OR mo_e->mo_rules->is_hidden( ls_rqf ) = abap_true
             OR ls_rqf-type = 'PAYFEE' OR ls_rqf-type = 'REQPANEL'
             OR ls_rqf-type = 'CAPTCHA'.
            CONTINUE.
          ENDIF.
          lv_rqn = lv_rqn + 1.
          DATA(lv_rqok) = xsdbool( NOT line_exists( lt_rqm[ name = ls_rqf-name ] ) ).
          DATA(lo_rqr)  = lo_rq->hbox( alignitems = 'Center' class = 'rakReqRow' ).
          lo_rqr->icon(
            src   = COND string( WHEN lv_rqok = abap_true
                                 THEN 'sap-icon://sys-enter-2' ELSE 'sap-icon://circle-task-2' )
            class = COND string( WHEN lv_rqok = abap_true THEN 'rakReqOk' ELSE 'rakReqPend' ) ).
          lo_rqr->text(
            text  = zcl_rak_journey_util=>esc( ls_rqf-label )
            class = COND string( WHEN lv_rqok = abap_true THEN 'rakReqDone' ELSE 'rakReqTodo' ) ).
        ENDLOOP.
        IF lv_rqn = 0.
          lo_rq->text( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-nothing_req iv_default = 'Nothing required on this step.' )
                       class = 'rakReqTodo' ).
        ENDIF.

      WHEN 'RECORDCARD'.
        io_parent->title( text = zcl_rak_journey_util=>esc( is_field-label ) class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
        DATA ls_rcd TYPE zif_rak_journey=>ty_table.
        CLEAR ls_rcd.
        IF mo_e->mo_logic IS BOUND.
          TRY.
              ls_rcd = mo_e->mo_logic->get_table( io_ctx = mo_e iv_name = is_field-name ).
            CATCH cx_root.
          ENDTRY.
        ENDIF.
        IF ls_rcd-rows IS INITIAL.
          io_parent->message_strip( text     = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-no_entries iv_default = 'No records available.' )
                                    type     = 'Information'
                                    showicon = abap_true
                                    class    = 'sapUiSmallMargin' ).
          RETURN.
        ENDIF.
        DATA(lv_rcs) = mo_e->val_get( is_field-name ).
        DATA(lo_rcl) = io_parent->vbox( class = 'rakRecList' ).
        LOOP AT ls_rcd-rows INTO DATA(lr_rcw).
          DATA(lv_rck) = VALUE string( lr_rcw[ 1 ] OPTIONAL ).
          DATA(lv_rc1) = VALUE string( lr_rcw[ 2 ] OPTIONAL ).
          DATA lv_rc2 TYPE string.
          CLEAR lv_rc2.
          LOOP AT lr_rcw INTO DATA(lv_rcc) FROM 3.
            lv_rc2 = COND #( WHEN lv_rc2 IS INITIAL THEN lv_rcc
                             ELSE |{ lv_rc2 }  ·  { lv_rcc }| ).
          ENDLOOP.
          IF lv_rc1 IS INITIAL.
            lv_rc1 = lv_rck.
          ENDIF.
          DATA(lv_rcon) = xsdbool( lv_rcs = lv_rck ).
          DATA(lo_rcc2) = lo_rcl->vbox(
            class = COND string( WHEN lv_rcon = abap_true THEN 'rakRecCard on' ELSE 'rakRecCard' ) ).
          lo_rcc2->button(
            text    = zcl_rak_journey_util=>esc( lv_rc1 )
            tooltip = zcl_rak_journey_util=>esc( COND string( WHEN lv_rc2 IS NOT INITIAL
                                        THEN |{ lv_rc1 } - { lv_rc2 }| ELSE lv_rc1 ) )
            type    = 'Transparent'
            icon    = COND string( WHEN lv_rcon = abap_true THEN 'sap-icon://accept' ELSE 'sap-icon://circle-task-2' )
            press   = mo_e->mo_client->_event( |ROWPICK_{ is_field-name }~{ lv_rck }| ) ).
          IF lv_rc2 IS NOT INITIAL.
            lo_rcc2->link( text  = zcl_rak_journey_util=>esc( lv_rc2 )
                           class = 'rakRecMeta'
                           press = mo_e->mo_client->_event( |ROWPICK_{ is_field-name }~{ lv_rck }| ) ).
          ENDIF.
        ENDLOOP.

      WHEN 'TABLE'.
        io_parent->title( text = zcl_rak_journey_util=>esc( is_field-label ) class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
        DATA ls_data TYPE zif_rak_journey=>ty_table.
        IF mo_e->mo_logic IS BOUND.
          TRY.
              ls_data = mo_e->mo_logic->get_table( io_ctx = mo_e iv_name = is_field-name ).
            CATCH cx_root INTO DATA(lx_tab).
              mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
                text = |Table { is_field-label } unavailable: { lx_tab->get_text( ) }| ) ).
              CLEAR ls_data.
          ENDTRY.
        ENDIF.

        IF ls_data-rows IS INITIAL.
          ls_data = mo_e->zif_rak_journey~get_backend_table( is_field-name ).
        ENDIF.

        DATA(lv_chk) = xsdbool( is_field-default CP 'CHK:*' ).
        DATA lv_setf    TYPE string.
        DATA lt_checked TYPE string_table.
        IF lv_chk = abap_true.
          lv_setf = to_upper( substring( val = is_field-default off = 4 ) ).
          SPLIT mo_e->val_get( lv_setf ) AT ',' INTO TABLE lt_checked.
        ENDIF.

        DATA lt_csn TYPE zif_rak_journey=>tt_string.
        DATA lt_csh TYPE zif_rak_journey=>tt_string.
        DATA(lv_csok) = abap_false.
        IF lv_chk = abap_false AND is_field-default CS ':'.
          lv_csok = abap_true.
          SPLIT is_field-default AT '|' INTO TABLE DATA(lt_csraw).
          LOOP AT lt_csraw INTO DATA(lv_csraw).
            DATA(lv_cstrim) = condense( lv_csraw ).
            IF lv_cstrim IS INITIAL.
              CONTINUE.
            ENDIF.
*           The spec is KEY:Label:TYPE. Split into THREE targets, not two:
*           with two, the type stayed glued to the label and the Notary party
*           table drew its headers as "Party Name:TEXT". A two-part spec is
*           still fine - the third target simply comes back empty.
            SPLIT lv_csraw AT ':' INTO DATA(lv_csn) DATA(lv_csh) DATA(lv_cstyp).
            lv_csn = to_upper( condense( lv_csn ) ).
            lv_csh = condense( lv_csh ).
            IF lv_csh IS INITIAL.
              lv_csh = lv_csn.
            ENDIF.
*           BILINGUAL HEADER. Until this call the header was whatever single
*           language someone typed into the spec, so an Arabic reader saw the
*           English column titles - the grid renderer resolves its headers
*           through PICK_TEXT( ) and this one did not.
            lv_csh = col_header( lv_csh ).
            APPEND lv_csn TO lt_csn.
            APPEND lv_csh TO lt_csh.
          ENDLOOP.
          IF lt_csn IS INITIAL.
            lv_csok = abap_false.
          ENDIF.
        ENDIF.

        IF lv_csok = abap_true.
          DATA lt_csmap TYPE STANDARD TABLE OF i WITH EMPTY KEY.
          DATA lv_csi   TYPE i.
          DATA lv_csj   TYPE i.
          DATA lv_csx   TYPE i.
          DATA lv_cshit TYPE i.
          CLEAR: lt_csmap, lv_csi, lv_cshit.
          LOOP AT lt_csn INTO DATA(lv_csname).
            lv_csi = lv_csi + 1.
            lv_csx = 0.
            lv_csj = 0.
            LOOP AT ls_data-columns INTO DATA(lv_csbc).
              lv_csj = lv_csj + 1.
              IF to_upper( condense( lv_csbc ) ) = lv_csname.
                lv_csx = lv_csj.
                EXIT.
              ENDIF.
            ENDLOOP.
            IF lv_csx > 0.
              lv_cshit = lv_cshit + 1.
            ELSE.
              lv_csx = lv_csi.
            ENDIF.
            APPEND lv_csx TO lt_csmap.
          ENDLOOP.

          IF lv_cshit = 0 AND ls_data-columns IS NOT INITIAL.
            mo_e->trace_gate( |Table { is_field-name }: none of the configured column names | &&
                              |match what the backend sent. Cells were taken by position | &&
                              |instead - check the spec against the /QNV/ table definition.| ).
          ENDIF.

          DATA lt_csrows LIKE ls_data-rows.
          DATA lt_csout  TYPE zif_rak_journey=>tt_string.
          DATA lv_cscell TYPE string.
          CLEAR lt_csrows.
          LOOP AT ls_data-rows INTO DATA(lt_csrw).
            CLEAR lt_csout.
            LOOP AT lt_csmap INTO DATA(lv_csm).
              CLEAR lv_cscell.
              lv_cscell = VALUE #( lt_csrw[ lv_csm ] OPTIONAL ).
              APPEND lv_cscell TO lt_csout.
            ENDLOOP.
            APPEND lt_csout TO lt_csrows.
          ENDLOOP.
          ls_data-rows    = lt_csrows.
          ls_data-columns = lt_csh.
        ENDIF.

        DATA(lv_pick) = COND string( WHEN lv_chk = abap_true OR lv_csok = abap_true
                                     THEN `` ELSE is_field-default ).

        DATA(lo_tab) = io_parent->table( alternaterowcolors = abap_true
                                         mode               = COND string( WHEN lv_pick IS NOT INITIAL THEN 'SingleSelectMaster' ELSE 'None' )
                                         class              = 'sapUiSmallMarginBeginEnd' ).

        DATA lt_thide TYPE STANDARD TABLE OF i WITH EMPTY KEY.
        DATA(lv_tnc) = lines( ls_data-columns ).
        IF lv_tnc > 0.
          DATA(lv_talign) = abap_true.
          LOOP AT ls_data-rows INTO DATA(lt_tprobe).
            IF lines( lt_tprobe ) <> lv_tnc.
              lv_talign = abap_false.
              EXIT.
            ENDIF.
          ENDLOOP.

          LOOP AT ls_data-columns INTO DATA(lv_thdr).
            DATA(lv_thx) = sy-tabix.
            DATA(lv_tht) = condense( lv_thdr ).
            IF lv_tht IS INITIAL OR lv_tht = '-'.
              APPEND lv_thx TO lt_thide.
            ENDIF.
          ENDLOOP.

          IF lt_thide IS NOT INITIAL AND lv_talign = abap_false.
            mo_e->trace_gate( |Table { is_field-name }: { lines( lt_thide ) } column(s) are | &&
                              |marked hidden, but the rows do not all carry { lv_tnc } cells. | &&
                              |Nothing was hidden - hiding by position on ragged rows would | &&
                              |put cells under the wrong headings.| ).
            CLEAR lt_thide.
          ENDIF.
        ENDIF.

        DATA(lo_cols) = lo_tab->columns( ).
        IF lv_chk = abap_true.
          lo_cols->column( width = '3rem' )->text( `` ).
        ENDIF.
        LOOP AT ls_data-columns INTO DATA(lv_col).
          DATA(lv_tcx) = sy-tabix.
          IF line_exists( lt_thide[ table_line = lv_tcx ] ).
            CONTINUE.
          ENDIF.
          lo_cols->column( )->text( zcl_rak_journey_util=>esc( lv_col ) ).
        ENDLOOP.
        IF lv_pick IS NOT INITIAL.
          lo_cols->column( halign = 'End' )->text( '' ).
        ENDIF.

        DATA(lo_items) = lo_tab->items( ).
        LOOP AT ls_data-rows INTO DATA(lt_row).
          DATA(lv_row_key) = COND string( WHEN lt_row IS NOT INITIAL THEN lt_row[ 1 ] ELSE `` ).
          DATA(lv_sel)     = xsdbool( lv_pick IS NOT INITIAL AND mo_e->val_get( lv_pick ) = lv_row_key ).
          DATA(lo_cells)   = lo_items->column_list_item(
                               type     = COND string( WHEN lv_pick IS NOT INITIAL THEN 'Active' ELSE 'Inactive' )
                               selected = lv_sel
                               press    = COND #( WHEN lv_pick IS NOT INITIAL
                                                  THEN mo_e->mo_client->_event( |ROWPICK_{ is_field-name }~{ lv_row_key }| ) ELSE `` )
                             )->cells( ).
          IF lv_chk = abap_true.
            lo_cells->checkbox(
              selected = xsdbool( line_exists( lt_checked[ table_line = lv_row_key ] ) )
              select   = mo_e->mo_client->_event( |ROWCHK_{ is_field-name }~{ lv_row_key }| ) ).
          ENDIF.
          LOOP AT lt_row INTO DATA(lv_cell).
            DATA(lv_tdx) = sy-tabix.
            IF line_exists( lt_thide[ table_line = lv_tdx ] ).
              CONTINUE.
            ENDIF.
            lo_cells->text( zcl_rak_journey_util=>esc( lv_cell ) ).
          ENDLOOP.
          IF lv_pick IS NOT INITIAL AND lt_row IS NOT INITIAL.
            IF lv_sel = abap_true.
              lo_cells->object_status( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-selected iv_default = 'Selected' )
                                       state = 'Success'
                                       icon  = 'sap-icon://accept'
                                       class = 'sapUiMediumMarginEnd' ).
            ELSE.
              lo_cells->button(
                text      = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-select iv_default = 'Select' )
                type      = 'Default'
                icon      = 'sap-icon://navigation-right-arrow'
                iconfirst = abap_false
                class     = 'sapUiMediumMarginEnd'
                press     = mo_e->mo_client->_event( |ROWPICK_{ is_field-name }~{ lv_row_key }| ) ).
            ENDIF.
          ENDIF.
        ENDLOOP.
    ENDCASE.
  ENDMETHOD.


  METHOD render_block_laid_out.

    DATA lt_elem  TYPE zcl_rak_cj_lay=>ty_t_elem.
    DATA lv_break TYPE abap_bool.

    LOOP AT it_fields INTO DATA(ls_scan).
      IF mo_e->mo_rules->is_hidden( ls_scan ) = abap_true.
        CONTINUE.
      ENDIF.
      APPEND CONV zcl_rak_cj_lay=>ty_key( ls_scan-name ) TO lt_elem.
    ENDLOOP.

    IF lt_elem IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_rows) = zcl_rak_cj_lay=>get_instance( )->plan( iv_journey = iv_journey
                                                           iv_step    = iv_step
                                                           iv_block   = iv_block
                                                           it_elem    = lt_elem ).

*   THE CARD, which a laid-out step never had. The unlaid path wraps its fields
*   in a SimpleForm - or a Panel for a section - carrying cls( 'CARD' ); this one
*   dropped a bare Grid onto the step body and nothing else. So a step drawn in
*   the layout designer rendered its fields directly on the page background while
*   the step before it sat in a white card, and no theme could close the gap
*   because there was no element to style.
*
*   Invisible for as long as the page behind it was white. The ATTEST variant
*   gives the page a grey, and the missing card became the first thing you see.
    DATA(lo_card) = io_parent->vbox( class = mo_e->mo_css->cls( 'CARD' ) ).

    DATA(lo_grid) = lo_card->grid( default_span = 'XL12 L12 M12 S12'
                                   hspacing     = '1'
                                   vspacing     = '1' )->content( ns = 'layout' ).

    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).

      lv_break = abap_true.

      LOOP AT <ls_row>-cells ASSIGNING FIELD-SYMBOL(<ls_cell>).

        READ TABLE it_fields INTO DATA(ls_fld)
             WITH KEY name = CONV string( <ls_cell>-elem_id ).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        render_cell( io_parent = lo_grid
                     is_cell   = <ls_cell>
                     is_field  = ls_fld
                     iv_break  = lv_break ).

        lv_break = abap_false.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD wide_field.

*   A COMPOSITE CONTROL, AND A PARAGRAPH, OWN THE WHOLE ROW.
*
*   The layout rows a migrated journey arrives with are DERIVED, not designed:
*   ZCL_RAK_MIGRATOR pairs a legacy caption row with the control it captions
*   and drops the two into two cells of the twelve-column grid, because that
*   is what the /QNV/ definition looks like. For an input and its label that
*   is right. For RAKPARCELSELECTOR it is not: the live control is a
*   full-width card list, and half a row turns it into a column of squeezed
*   cards next to a dead grey box holding the instruction text.
*
*   So the two cases that are never legitimately half-width are forced here
*   rather than in the layout: a composite that draws its own list, and a
*   DISPLAY paragraph long enough that it is prose rather than a value. An
*   author who lays a step out by hand in the Design tab keeps every other
*   cell exactly as they placed it - this overrides two shapes, not the grid.
    CASE is_field-type.
      WHEN 'PARCEL' OR 'PROPERTY' OR 'TITLEDEED'
        OR 'CONTRACT' OR 'FLOORUNIT' OR 'BUILDINGS' OR 'ACCOM'.
        rv_on = abap_true.
        RETURN.
      WHEN 'DISPLAY'.
*       Prose, not a value. A DISPLAY row takes its paragraph from
*       DEFAULT_VAL - that is where ZCL_RAK_MIGRATOR puts a guidance notice,
*       and where a TEXT: reference to ZRAK_T_CJ_TXT sits - so the length
*       test has to look there as well as at the label. Ninety characters
*       is comfortably longer than any caption and comfortably shorter than
*       the shortest notice on the migrated journeys.
        IF strlen( is_field-label ) > 90
           OR strlen( is_field-default ) > 90
           OR is_field-default CP 'TEXT:*'.
          rv_on = abap_true.
        ENDIF.
        RETURN.
      WHEN 'READONLY'.
*       A READONLY field is a VALUE, so only its label can make it prose -
*       DEFAULT_VAL there is the value itself and a long one is still a
*       field, not a paragraph.
        IF strlen( is_field-label ) > 90.
          rv_on = abap_true.
        ENDIF.
        RETURN.
      WHEN OTHERS.
        RETURN.
    ENDCASE.

  ENDMETHOD.


  METHOD render_cell.

    DATA(lv_align) = COND string( WHEN is_cell-attr-align = zcl_rak_cj_lay=>c_align-center THEN 'Center'
                                  WHEN is_cell-attr-align = zcl_rak_cj_lay=>c_align-end    THEN 'End'
                                  ELSE 'Start' ).

    DATA(lv_width) = COND string( WHEN is_cell-attr-width IS NOT INITIAL
                                  THEN CONV string( is_cell-attr-width )
                                  ELSE '100%' ).

*   FLOW - the cell's own direction.
*
*   A cell is a vbox, so everything put into it stacks: the field, then
*   whatever AFTER_FIELD( ) adds. That is why a handler's search or ADD
*   button always lands UNDER its input and never beside it - it is the
*   container, not the button, that decides.
*
*   FLOW turns the cell into an hbox, and the button lands where the reader
*   expects it. ALIGNITEMS 'End' rather than the cell's own alignment: the
*   field is label-above-input and the button is a button, so aligning
*   their bottoms puts the button level with the input rather than floating
*   next to the label.
*
*   Off by default and read from a column that is blank everywhere until
*   somebody ticks it in the Design tab, so no existing journey moves.
    DATA(lo_cell) = io_parent->vbox( class      = 'rakCell'
                                     width      = lv_width
                                     alignitems = lv_align ).

    DATA(lv_wide) = wide_field( is_field ).

*   A wide cell also forces the line break. Spanning twelve columns while
*   still sitting on the previous row would push the cell beside it out of
*   the grid entirely rather than onto its own line.
    lo_cell->layout_data( )->grid_data(
      span      = COND string( WHEN lv_wide = abap_true
                               THEN 'XL12 L12 M12 S12'
                               ELSE zcl_rak_cj_lay=>span_str( is_cell-attr-col_span ) )
      linebreak = COND string( WHEN iv_break = abap_true OR lv_wide = abap_true
                               THEN 'true' ELSE 'false' ) ).

    mv_in_cell = abap_true.
    before_field( io_view = lo_cell is_field = is_field ).

    DATA(lv_block) = zcl_rak_journey_util=>is_block( is_field-type ).

*   FLOW - the field and its buttons, side by side.
*
*   A cell is a vbox, so everything put into it stacks: the label, the
*   control, then whatever AFTER_FIELD( ) adds. That is why a handler's
*   search or ADD button always lands UNDER its input - the container
*   decides, not the button.
*
*   The cell STAYS a vbox and gains an inner row. Only the control and the
*   trailing buttons go into that row; the label is redirected back to the
*   cell through MO_LBL_TGT so it keeps sitting above, and the field goes on
*   matching every other field on the step. Making the whole cell an hbox
*   would have dragged the label alongside the input as a side effect.
*
*   Not offered for blocks - a table or a panel is already a layout of its
*   own and has nothing to sit beside.
    DATA lo_body TYPE REF TO z2ui5_cl_xml_view.
    lo_body = lo_cell.
    IF is_cell-attr-flow = abap_true AND lv_block = abap_false.
      mv_flow_cell = abap_true.

*     ORDER MATTERS. z2ui5 emits children in the order they are created, so
*     the label's container has to exist BEFORE the row that holds the
*     control - otherwise REQ_LABEL( ), which runs later from inside
*     RENDER_ONE( ), appends the label after the row and it renders UNDER
*     the field instead of above it.
*
*     An empty vbox is cheap and stays empty for the field types that never
*     call REQ_LABEL( ) at all, such as CHECKBOX and SEARCH.
      mo_lbl_tgt = lo_cell->vbox( ).

*     JUSTIFYCONTENT 'Start' keeps the button against the control. Without
*     it the row spreads its children across the full cell width and the
*     button drifts to the far edge, which is no more "next to the field"
*     than being underneath it was.
      lo_body = lo_cell->hbox( class          = 'rakCellFlow'
                               width          = '100%'
                               justifycontent = 'Start'
                               alignitems     = 'End' ).
    ENDIF.

    IF lv_block = abap_true.
      render_block( io_parent = lo_cell is_field = is_field ).
    ELSE.
      render_one( io_form = lo_body is_field = is_field ).
    ENDIF.

    after_field( io_view = lo_body is_field = is_field ).
    CLEAR: mv_in_cell, mv_flow_cell, mo_lbl_tgt.

  ENDMETHOD.


  METHOD render_chips.
    LOOP AT mo_e->mt_attach INTO DATA(ls_a).
      DATA(lv_idx) = sy-tabix.
      IF ls_a-field <> to_upper( iv_field ) OR ls_a-okey <> iv_key.
        CONTINUE.
      ENDIF.
      rv_count = rv_count + 1.
      DATA(lo_row) = io_box->hbox( alignitems = 'Center' class = 'rakFileRow' ).
      lo_row->icon( src = 'sap-icon://document' class = 'sapUiTinyMarginEnd' ).
      lo_row->link( text   = zcl_rak_journey_util=>esc( ls_a-name )
                    href   = zcl_rak_journey_util=>att_url( ls_a-guid )
                    target = '_blank'
                    class  = 'rakFileName' ).
      lo_row->button( icon    = 'sap-icon://display'
                      type    = 'Transparent'
                      tooltip = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-view iv_default = 'View' )
                      press   = mo_e->mo_client->_event( |ATTVIEW_{ lv_idx }| ) ).
      lo_row->button( icon    = 'sap-icon://decline'
                      type    = 'Transparent'
                      tooltip = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-remove_row iv_default = 'Remove' )
                      press   = mo_e->mo_client->_event( |ATTDEL_{ lv_idx }| ) ).
    ENDLOOP.

    IF mo_e->mo_logic IS BOUND.
      DATA lt_filed TYPE zif_rak_journey=>tt_attach.
      TRY.
          lt_filed = mo_e->mo_logic->get_attachments( io_ctx = mo_e iv_field = iv_field ).
        CATCH cx_root.
          CLEAR lt_filed.
      ENDTRY.
      LOOP AT lt_filed INTO DATA(ls_fl).
        DATA(lv_url) = ls_fl-url.
        IF lv_url IS INITIAL.
          TRY.
              lv_url = mo_e->mo_logic->get_attach_url( io_ctx = mo_e iv_field = iv_field ).
            CATCH cx_root.
              CLEAR lv_url.
          ENDTRY.
        ENDIF.
        rv_count = rv_count + 1.
        DATA(lo_frow) = io_box->hbox( alignitems = 'Center' class = 'rakFileRow' ).
        lo_frow->icon( src = 'sap-icon://document' class = 'sapUiTinyMarginEnd' ).
        lo_frow->link( text   = zcl_rak_journey_util=>esc( ls_fl-title )
                       href   = lv_url
                       target = '_blank'
                       class  = 'rakFileName' ).
        lo_frow->object_status( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-filed iv_default = 'Filed' )
                                state = 'Success'
                                icon  = 'sap-icon://locked'
                                class = 'sapUiTinyMarginBegin' ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD render_feedback.
    IF mo_e->mo_logic IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA lv_want TYPE abap_bool.
    lv_want = abap_true.
    TRY.
        lv_want = mo_e->mo_logic->wants_feedback( mo_e ).
      CATCH cx_root.
        lv_want = abap_true.
    ENDTRY.
    IF lv_want = abap_false.
      RETURN.
    ENDIF.

*   Declined. The card goes away entirely rather than showing a thank-you
*   for a rating nobody gave.
    IF mo_e->mv_fb_skip = abap_true.
      RETURN.
    ENDIF.

    DATA(lo_card) = io_parent->vbox( class = mo_e->mo_css->cls( 'CARD' ) ).
    IF mo_e->mv_fb_done = abap_true.
      lo_card->object_status( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_thanks iv_default = 'Thanks for your feedback' )
                              state = 'Success'
                              icon  = 'sap-icon://accept'
                              class = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

    lo_card->title( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_title iv_default = 'How was your experience?' )
                    class = 'sapUiTinyMarginBottom' ).

    DATA(lt_fb) = VALUE zif_rak_journey=>tt_option(
      ( key = 'EX' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_excellent iv_default = 'Excellent' ) )
      ( key = 'GD' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_good      iv_default = 'Good' ) )
      ( key = 'AV' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_average   iv_default = 'Average' ) )
      ( key = 'PR' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_poor      iv_default = 'Poor' ) )
      ( key = 'VP' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_verypoor  iv_default = 'Very Poor' ) ) ).

    LOOP AT lt_fb INTO DATA(ls_hb).
      lo_card->button( text  = ls_hb-key
                       class = |rakHide rakFb_{ ls_hb-key }|
                       press = mo_e->mo_client->_event( |FBRATE_{ ls_hb-key }| ) ).
    ENDLOOP.

    DATA lv_faces TYPE string.
    DATA lv_col   TYPE string.
    DATA lv_mouth TYPE string.
    DATA lv_ring  TYPE string.
    lv_faces = `<div style="display:flex;gap:14px;margin:.2rem 0 1rem;flex-wrap:wrap;">`.
    LOOP AT lt_fb INTO DATA(ls_fc).
      CASE ls_fc-key.
        WHEN 'EX'. lv_col = `#2e9e4f`. lv_mouth = `M13 25 Q22 35 31 25`.
        WHEN 'GD'. lv_col = `#7ab648`. lv_mouth = `M14 27 Q22 32 30 27`.
        WHEN 'AV'. lv_col = `#e0a800`. lv_mouth = `M14 29 L30 29`.
        WHEN 'PR'. lv_col = `#e8792b`. lv_mouth = `M14 31 Q22 26 30 31`.
        WHEN OTHERS. lv_col = `#d5342b`. lv_mouth = `M13 32 Q22 23 31 32`.
      ENDCASE.
      lv_ring = ``.
      IF mo_e->mv_fb_rating = ls_fc-key.
        lv_ring = `box-shadow:0 0 0 3px ` && lv_col && `33;background:` && lv_col && `14;`.
      ENDIF.
      lv_faces = lv_faces
        && `<div onclick="var b=document.querySelector('.rakFb_` && ls_fc-key
        && `');if(b){sap.ui.getCore().byId(b.id).firePress();}"`
        && ` style="cursor:pointer;text-align:center;padding:7px 9px;border-radius:12px;` && lv_ring && `">`
        && `<svg width="46" height="46" viewBox="0 0 44 44">`
        && `<circle cx="22" cy="22" r="20" fill="none" stroke="` && lv_col && `" stroke-width="2.6"/>`
        && `<circle cx="15" cy="18" r="2.4" fill="` && lv_col && `"/>`
        && `<circle cx="29" cy="18" r="2.4" fill="` && lv_col && `"/>`
        && `<path d="` && lv_mouth && `" fill="none" stroke="` && lv_col && `" stroke-width="2.6" stroke-linecap="round"/>`
        && `</svg>`
        && `<div style="font-size:11px;color:` && lv_col && `;margin-top:3px;font-weight:600;">` && ls_fc-text && `</div>`
        && `</div>`.
    ENDLOOP.
    lv_faces = lv_faces && `</div>`.
    REPLACE ALL OCCURRENCES OF '{' IN lv_faces WITH '\{'.
    REPLACE ALL OCCURRENCES OF '}' IN lv_faces WITH '\}'.
    lo_card->html( content = lv_faces sanitizecontent = abap_false ).

    lo_card->text_area( value       = mo_e->mo_client->_bind_edit( mo_e->mv_fb_comment )
                        rows        = '2'
                        placeholder = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_hint
                                        iv_default = 'Anything you would like us to know? (optional)' ) ).

*   Send and skip sit together, because they are the two ways out of this
*   page and one of them must always be available. Send stays disabled until
*   a face is picked - that part was right; what was missing is that the
*   page had no other exit, so declining to rate meant not being able to
*   leave the service at all.
    DATA(lo_fbb) = lo_card->hbox( class = 'sapUiSmallMarginTop' alignitems = 'Center' ).
    lo_fbb->button( text    = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_send iv_default = 'Send feedback' )
                    type    = 'Emphasized'
                    icon    = 'sap-icon://feedback'
                    enabled = xsdbool( mo_e->mv_fb_rating IS NOT INITIAL )
                    press   = mo_e->btn_evt( 'FBSEND' ) ).
    lo_fbb->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_skip iv_default = 'Not now' )
                    type  = 'Transparent'
                    class = 'sapUiTinyMarginBegin'
                    press = mo_e->btn_evt( 'FBSKIP' ) ).
  ENDMETHOD.


  METHOD render_footer.
    DATA(lv_open) = abap_true.
    DATA lv_why   TYPE string.
    DATA lv_pay   TYPE abap_bool.
    DATA lv_wait  TYPE abap_bool.
    DATA lv_paid  TYPE abap_bool.

    READ TABLE mo_e->ms_config-steps INTO DATA(ls_cur) INDEX mo_e->mv_step + 1.
    IF sy-subrc = 0 AND ls_cur-next_req IS NOT INITIAL.
      DATA(ls_gate) = mo_e->safe_field( ls_cur-next_req ).
      IF ls_gate-name IS INITIAL.
        mo_e->trace_gate( |Step { ls_cur-id }: NEXT_REQUIRES names { ls_cur-next_req }, | &&
                          |which is not a field on this journey. The gate is ignored | &&
                          |and the button behaves as if it were blank.| ).
      ELSEIF mo_e->zif_rak_journey~get_val( ls_gate-name ) IS INITIAL.
        lv_open = abap_false.
        IF to_upper( ls_gate-type ) = 'PAYFEE'.
          lv_pay  = abap_true.
          lv_wait = xsdbool( mo_e->zif_rak_journey~get_val( 'PAY_STARTED' ) = 'X' ).
        ELSE.
          lv_why = COND string(
            WHEN ls_gate-label IS NOT INITIAL
            THEN |{ ls_gate-label } must be completed before you can continue.|
            ELSE |This step is not finished yet.| ).
        ENDIF.
      ELSEIF to_upper( ls_gate-type ) = 'PAYFEE'.

*       A NON-BLANK fee field is not a PAID one. This branch used to take any
*       value at all as payment received, so a PAYFEE carrying anything the
*       backend read put there - or a DEFAULT_VAL on the field - opened Next and
*       relabelled it Done while the fee card two inches above it was still
*       showing the Pay button. The card tests = 'PAID' and so does the gate in
*       ON_CUSTOM_VALIDATE; the footer is the only place that did not, which is
*       how the citizen got a live Next on an unpaid step.
        IF mo_e->zif_rak_journey~get_val( ls_gate-name ) = 'PAID'.
          lv_paid = abap_true.
        ELSE.
          lv_pay  = abap_true.
          lv_open = abap_false.
          lv_wait = xsdbool( mo_e->zif_rak_journey~get_val( 'PAY_STARTED' ) = 'X' ).
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_pay = abap_false AND lv_paid = abap_false.
      DATA(lv_fee) = pay_field( mo_e->mv_step ).
      IF lv_fee IS NOT INITIAL.
        IF mo_e->zif_rak_journey~get_val( lv_fee ) = 'PAID'.
          lv_paid = abap_true.
        ELSE.
          lv_pay  = abap_true.
          lv_open = abap_false.
          lv_wait = xsdbool( mo_e->zif_rak_journey~get_val( 'PAY_STARTED' ) = 'X' ).
        ENDIF.
      ENDIF.
    ENDIF.

    IF lv_paid = abap_false AND lv_pay = abap_false.
      DATA lv_i TYPE i.
      lv_i = 0.
      WHILE lv_i < lines( mo_e->ms_config-steps ).
        DATA(lv_sf) = pay_field( lv_i ).
        IF lv_sf IS NOT INITIAL AND mo_e->zif_rak_journey~get_val( lv_sf ) = 'PAID'.
          lv_paid = abap_true.
          EXIT.
        ENDIF.
        lv_i = lv_i + 1.
      ENDWHILE.
    ENDIF.

    IF lv_open = abap_false AND lv_pay = abap_false.
      io_parent->message_strip( text     = lv_why
                                type     = 'Information'
                                showicon = abap_true
                                class    = 'sapUiSmallMarginBegin sapUiSmallMarginEnd' ).
    ENDIF.

    DATA(lo_box) = io_parent->hbox( justifycontent = 'End' alignitems = 'Center' class = mo_e->mo_css->cls( 'FOOTER' ) ).

*   NO BACK ONCE THE FEE IS PAID. The payment post is final - it carries the
*   attachments and DROP_ATTACHMENTS( ) clears the staging behind it - so an
*   earlier step is no longer a page the citizen can meaningfully return to,
*   and the Documents step in particular renders empty because its documents
*   are on the case now. Done is the only move left, which is what the button
*   beside this one already says: LV_PAID relabels Next as Done, and it is the
*   same fact, resolved a few lines above. Read through NAV_LOCKED( ) so the
*   footer, the stepper dots, the tab strip and the event handler cannot
*   disagree about it.
    IF iv_linear = abap_true AND mo_e->mv_step > 0 AND mo_e->nav_locked( ) = abap_false.
      lo_box->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-back iv_default = 'Back' )
                      icon  = 'sap-icon://nav-back'
                      class = mo_e->mo_css->cls( 'BTN_ALT' )
                      press = mo_e->btn_evt( 'BACK' ) ).
    ENDIF.

    IF ls_cur-no_forward = abap_true.
      RETURN.
    ENDIF.

    IF lv_pay = abap_true.
      DATA(lv_feefld) = pay_field( mo_e->mv_step ).
      IF lv_feefld IS NOT INITIAL
         AND mo_e->zif_rak_journey~get_backend_table( lv_feefld )-rows IS INITIAL.
        mo_e->trace_gate( |Step { ls_cur-id }: the Pay button is live but { to_upper( lv_feefld ) } | &&
                          |has no fee lines, so the total is zero. Either the backend has | &&
                          |not raised the open item by the time this step renders - check | &&
                          |WHEN the D0xx BAdI creates the fee against WHEN the case is | &&
                          |created - or this journey should not have a payment step at all.| ).
      ENDIF.
      lo_box->button(
        text    = COND #( WHEN lv_wait = abap_true
                          THEN zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-waiting iv_default = 'Waiting for payment' )
                          ELSE zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-pay     iv_default = 'Pay' ) )
        type    = mo_e->ms_config-theme-accent_type
        icon    = 'sap-icon://credit-card'
        enabled = xsdbool( lv_wait = abap_false )
        class   = |{ mo_e->mo_css->cls( 'BTN_MAIN' ) } sapUiSmallMarginBegin|
        press   = mo_e->mo_client->_event( 'HPOP_PAYNOW' ) ).
      RETURN.
    ENDIF.

    DATA(lv_tail_is_result) = abap_false.
    IF iv_linear = abap_true AND mo_e->mv_step < lines( mo_e->ms_config-steps ) - 1.
      lv_tail_is_result = abap_true.
      DATA lv_t TYPE i.
      lv_t = mo_e->mv_step + 1.
      WHILE lv_t < lines( mo_e->ms_config-steps ).
        IF is_result_step( lv_t ) = abap_false.
          lv_tail_is_result = abap_false.
          EXIT.
        ENDIF.
        lv_t = lv_t + 1.
      ENDWHILE.
    ENDIF.

    IF iv_linear = abap_true AND mo_e->mv_step < lines( mo_e->ms_config-steps ) - 1
       AND lv_tail_is_result = abap_false.
      lo_box->button( text      = COND #( WHEN lv_paid = abap_true
                                          THEN zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-done iv_default = 'Done' )
                                          ELSE zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-next iv_default = 'Next' ) )
                      type      = mo_e->ms_config-theme-accent_type
                      icon      = COND string( WHEN lv_paid = abap_true
                                          THEN 'sap-icon://accept'
                                          ELSE 'sap-icon://navigation-right-arrow' )
                      iconfirst = xsdbool( lv_paid = abap_true )
                      enabled   = lv_open
                      class     = |{ mo_e->mo_css->cls( 'BTN_MAIN' ) } sapUiSmallMarginBegin|
                      press     = mo_e->btn_evt( 'NEXT' ) ).
    ELSEIF mo_e->zif_rak_journey~get_val( 'NO_SUBMIT' ) = 'X'.
      lo_box->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-close iv_default = 'Close' )
                      type  = mo_e->ms_config-theme-accent_type
                      class = |{ mo_e->mo_css->cls( 'BTN_MAIN' ) } sapUiSmallMarginBegin|
                      press = mo_e->mo_client->_event( 'HPOP_CLOSE' ) ).
    ELSE.
      lo_box->button( text    = COND #( WHEN lv_paid = abap_true
                                        THEN zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-complete iv_default = 'Complete' )
                                        ELSE zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-submit   iv_default = 'Submit' ) )
                      type    = mo_e->ms_config-theme-accent_type
                      icon    = 'sap-icon://accept'
                      enabled = lv_open
                      class   = |{ mo_e->mo_css->cls( 'BTN_MAIN' ) } sapUiSmallMarginBegin|
                      press   = mo_e->btn_evt( 'SUBMIT' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD render_header.
    DATA(lo_h)   = io_parent->vbox( class = |{ mo_e->mo_css->cls( 'SHELL' ) } rakHdr| ).
    DATA(lo_top) = lo_h->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    lo_top->title( text = zcl_rak_journey_util=>esc( mo_e->ms_config-title ) level = 'H3' class = |{ mo_e->mo_css->cls( 'TITLE' ) } rakHdrTitle| ).

    IF mo_e->ms_config-theme-show_actions = abap_true AND mo_e->mv_submitted = abap_false.
      DATA(lo_r) = lo_top->hbox( ).
*     Save-as-Draft is gated separately from SHOW_ACTIONS, which is
*     all-or-nothing and also carries Delete. A journey that keeps no drafts
*     still wants a Delete button, so the two cannot share a switch.
*
*     This only hides the control. HANDLE_SAVE( ) refuses the event as well,
*     because a hidden button is not an unreachable one.
      IF mo_e->resolve_draft_mode( ) <> zif_rak_journey=>c_mode-off.
        lo_r->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-save_draft iv_default = 'Save as Draft' )
                      icon  = 'sap-icon://save'
                      type  = 'Transparent'
                      class = 'sapUiSmallMarginBegin'
                      press = mo_e->btn_evt( 'SAVE' ) ).
      ENDIF.
      lo_r->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-delete iv_default = 'Delete' )
                    icon  = 'sap-icon://delete'
                    type  = 'Transparent'
                    class = 'sapUiSmallMarginBegin'
                    press = mo_e->btn_evt( 'ASKDEL' ) ).
    ENDIF.

*   MO_E->MV_LANG, not SY-LANGU - the language the engine itself resolved
*   (from &lang= on the URL, falling back to SY-LANGU only when absent),
*   the same rule ZCL_RAK_TEXT follows and for the same reason: the ICF
*   service user's own logon language has nothing to do with which
*   language the citizen asked for. The title just above this already
*   goes through PICK( )/MV_LANG via MS_CONFIG-TITLE; this subtitle was
*   the one text on the same header still keyed off SY-LANGU, so a
*   citizen could see an English title above an Arabic subtitle or the
*   reverse whenever the two languages disagreed.
    DATA(lv_sub) = COND string(
      WHEN mo_e->mv_lang = 'A' AND mo_e->ms_config-theme-subtitle_ar IS NOT INITIAL
      THEN mo_e->ms_config-theme-subtitle_ar ELSE mo_e->ms_config-theme-subtitle ).
    IF lv_sub IS NOT INITIAL.
      lo_h->text( text = zcl_rak_journey_util=>esc( lv_sub ) class = 'rakSub' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_one.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          IF mo_e->mo_logic->render_field( io_ctx = mo_e io_form = io_form is_field = is_field ) = abap_true.
            RETURN.
          ENDIF.
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF is_field-type = 'DISPLAY' AND is_field-has_attach = abap_true
       AND mo_e->val_get( is_field-name ) IS INITIAL.
      render_attach( io_form = io_form is_field = is_field ).
      RETURN.
    ENDIF.

*   EVERY FIELD THE RENDERER IS ASKED TO DRAW, and the type it was asked to
*   draw it as. Behind the trace flag, so it costs nothing normally.
*
*   This exists because "the field does not render" is otherwise unanswerable
*   from the outside: a field missing from the config, a field hidden by a
*   rule, and a field whose FTYPE does not match any branch all look identical
*   on screen - an absence. The three have completely different fixes, and
*   telling them apart took four rounds of reading source that could not be
*   run from where it was being read.
*
*   Its absence from the list is the finding. A field that appears here and
*   still shows nothing is a rendering problem; a field that never appears
*   never reached RENDER_ONE( ) at all, and the cause is upstream - config,
*   cache, or a hidden flag.
    mo_e->trace( |render { is_field-name } type=[{ is_field-type }]| ).

    DATA(lv_bind) = bind_of( is_field-name ).
    DATA(lv_vs)   = bind_state( iv_name = is_field-name iv_suffix = '_VS' ).
    DATA(lv_vst)  = bind_state( iv_name = is_field-name iv_suffix = '_VST' ).
    DATA(lv_edit) = xsdbool( mo_e->mo_rules->is_readonly( is_field ) = abap_false ).
    DATA(lv_min)  = COND string( WHEN is_field-validation-min_val IS NOT INITIAL THEN is_field-validation-min_val ELSE '0' ).
    DATA(lv_max)  = COND string( WHEN is_field-validation-max_val IS NOT INITIAL THEN is_field-validation-max_val ELSE '100' ).
    DATA(lv_w)    = zcl_rak_journey_util=>ctrl_width( is_field ).
    IF mv_in_cell = abap_true AND mv_flow_cell = abap_false.
      lv_w = '100%'.
    ENDIF.

*   Where an empty dropdown comes from. Three sources feed one list and each
*   can come back with nothing, so "No data" on screen used to be the same
*   picture whether the field had no configured options, the handler declined,
*   the handler raised, or the resolver found nothing. The exception in
*   particular was caught and cleared without a word, which is the worst of
*   the four to debug because it looks identical to a deliberate empty list.
    DATA(lt_opt) = is_field-options.
    DATA(lv_vhsrc) = COND string( WHEN lt_opt IS NOT INITIAL THEN 'config' ELSE `` ).

    IF lt_opt IS INITIAL AND mo_e->mo_logic IS BOUND.
      TRY.
          lt_opt = mo_e->mo_logic->on_value_help( io_ctx = mo_e iv_field = is_field-name ).
          lv_vhsrc = COND string( WHEN lt_opt IS NOT INITIAL
                                  THEN 'on_value_help'
                                  ELSE 'on_value_help (empty)' ).
        CATCH cx_root INTO DATA(lx_vh).
          CLEAR lt_opt.
          lv_vhsrc = |on_value_help RAISED { lx_vh->get_text( ) }|.
      ENDTRY.
    ELSEIF lt_opt IS INITIAL.
*     No handler at all. Worth saying plainly: every list on a journey whose
*     options are not configured depends on one, so an unbound handler is not
*     a detail, it is the reason nothing has any options.
      lv_vhsrc = 'no handler bound'.
    ENDIF.
*   FOURTH SOURCE: a wrapper API named in DEFAULT_VAL. This is what makes
*   a migrated composite - a parcel selector, a property list - into a
*   working control rather than an empty box: ZCL_RAK_MIGRATOR wrote
*   'API:PROPERTY:PropertiesSet::Type=Parcel' onto the field and
*   ZCL_RAK_CJ_OPTS turns that into the citizen's own parcels.
*
*   AHEAD OF THE DDIC RESOLVER, deliberately. An API-bound field must not
*   fall through to a domain or search help that happens to share its
*   name - that would answer with the wrong list rather than no list, and
*   a wrong list is the harder of the two to notice.
*   CALLED DYNAMICALLY, AND THAT IS NOT DECORATION. ZCL_RAK_CJ_OPTS leads
*   to ZCL_RAK_CJ_API, which INHERITS the legacy Gateway DPC. A static
*   reference would make this class - the renderer every journey and the
*   Studio go through - fail to load whenever anything in that chain is
*   inactive, which is the widest possible blast radius for a layer that
*   is still being built. Dynamically, an inactive wrapper is a caught
*   CX_SY_DYN_CALL_ERROR on one field: no options, a note beside it, every
*   other field on every other journey untouched.
*
*   The parameters go in a PARAMETER-TABLE because a dynamic class AND
*   method name cannot carry a static EXPORTING list. LO_IF is declared
*   rather than passing MO_E directly so the reference's type matches the
*   formal parameter exactly - a parameter table binds by type, not by the
*   up-cast a normal call would do for free.
    DATA lv_apinote TYPE string.
    IF lt_opt IS INITIAL AND strlen( is_field-default ) > 4 AND is_field-default(4) = 'API:'.
      DATA lo_if TYPE REF TO zif_rak_journey.
      lo_if = mo_e.
      DATA(lt_apb) = VALUE abap_parmbind_tab(
        ( name = 'IS_FIELD' kind = cl_abap_objectdescr=>exporting value = REF #( is_field ) )
        ( name = 'IO_CTX'   kind = cl_abap_objectdescr=>exporting value = REF #( lo_if ) )
        ( name = 'ET_OPT'   kind = cl_abap_objectdescr=>importing value = REF #( lt_opt ) )
        ( name = 'EV_NOTE'  kind = cl_abap_objectdescr=>importing value = REF #( lv_apinote ) ) ).
      TRY.
          CALL METHOD ('ZCL_RAK_CJ_OPTS')=>('RESOLVE')
            PARAMETER-TABLE lt_apb.
        CATCH cx_root INTO DATA(lx_api).
          CLEAR lt_opt.
          lv_apinote = |{ is_field-name }: the API binding could not be resolved - { lx_api->get_text( ) }|.
      ENDTRY.
      lv_vhsrc = |{ lv_vhsrc } -> API { is_field-default }| &&
                 COND string( WHEN lt_opt IS INITIAL THEN ' (empty)' ELSE `` ).
    ENDIF.

    IF lt_opt IS INITIAL
       AND ( is_field-rollname IS NOT INITIAL OR is_field-shlp IS NOT INITIAL OR is_field-domname IS NOT INITIAL ).
      lt_opt = f4_opts( is_field ).
      lv_vhsrc = |{ lv_vhsrc } -> DDIC resolver| .
    ENDIF.

*   Only for the field types that actually show a list, and only under trace.
    IF mo_e->mv_trace = abap_true
       AND ( is_field-type = 'SELECT' OR is_field-type = 'RADIO'
          OR is_field-type = 'CHECKGROUP' OR is_field-type = 'SEGMENTED' ).
      mo_e->trace( |LIST    { is_field-name } ({ is_field-type }) · { lines( lt_opt ) } option(s) · | &&
                   COND string( WHEN lv_vhsrc IS NOT INITIAL THEN lv_vhsrc ELSE 'no source tried' ) ).
    ENDIF.

    CASE is_field-type.
*     THE API-BACKED COMPOSITES DRAW AS A SELECT. RAKPARCELSELECTOR looks
*     like a map widget, and the map is the part that is not the point:
*     the citizen picks ONE parcel out of the ones they own and that id is
*     what the journey stores. A list whose options come from
*     ZCL_RAK_PROPERTY_API is that control, minus the map - and it is a
*     control, where before the migration left a grey box with a label.
*
*     Typable rather than CLOSED_LIST on purpose: these lists can be long,
*     and type-ahead on a parcel number is how a citizen with forty of
*     them finds one. A journey that wants the list closed sets
*     CLOSED_LIST on the field like any other select.
      WHEN 'SELECT' OR 'PARCEL' OR 'PARCELS' OR 'PROPERTY' OR 'TITLEDEED'
        OR 'CONTRACT' OR 'FLOORUNIT' OR 'BUILDINGS' OR 'ACCOM'.

*       THE PARCEL FAMILY IS NOT A DROPDOWN when the real control is
*       available. RAKPARCELSELECTOR is a paginated card list with an
*       owner switch, a favourites toggle and a search box - a citizen can
*       hold hundreds of parcels, and a ComboBox of them is both unusable
*       and hundreds of items of XML in every round trip. MO_PCL draws one
*       page. It answers ABAP_FALSE when it has nothing to draw, and is
*       UNBOUND whenever the wrapper chain is inactive, so the ComboBox
*       below stays the fallback rather than being replaced by it.
        IF mo_e->mo_pcl IS BOUND
           AND ( is_field-type = 'PARCEL' OR is_field-type = 'PARCELS'
                 OR is_field-type = 'PROPERTY'
                 OR is_field-type = 'TITLEDEED' ).
          TRY.
              IF mo_e->mo_pcl->render( io_view = io_form is_field = is_field ) = abap_true.
                RETURN.
              ENDIF.
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        req_label( io_form = io_form is_field = is_field ).
*       CLOSED_LIST switches this one field to sap.m.Select - not typable,
*       by design, which is the whole point of a genuinely closed list
*       (round-5 finding 3): nothing a citizen types into it can ever be
*       accepted, so the type-ahead ComboBox default only invites pointless
*       typing and pops a keyboard on a touch device. Blank behaves exactly
*       as before - ComboBox stays the default so no existing dropdown
*       loses type-ahead until an author opts it in. sap.m.Select has no
*       EDITABLE property (it is a picker, not a text field), so LV_EDIT
*       maps to ENABLED instead - a disabled Select and a non-editable
*       ComboBox read the same to the citizen either way.
        IF is_field-closed_list = abap_true.
*         FORCESELECTION = ABAP_FALSE, AND IT HAS TO BE SAID OUT LOUD.
*
*         sap.m.Select defaults forceSelection to TRUE, which means: with no
*         selectedKey matching any item, select the first one anyway. The
*         control then DRAWS the first option while the model still holds
*         nothing, so an untouched dropdown reads as answered. Everything
*         downstream disagrees with the screen - a rule keyed on the field does
*         not fire, and VALIDATE_STEP( ) refuses a required field the citizen
*         can see filled in and cannot fix. That is worse than the typable
*         ComboBox this branch exists to replace.
*
*         Not passing the parameter does NOT get the false: an unsupplied
*         OPTIONAL arrives blank, and XML_GET_PARTS( ) drops every blank
*         property from the markup rather than emitting it as "false" - so the
*         property never reaches the control and UI5's own default of true
*         applies. The code reads as "we do not set this" and behaves as "we
*         set it to true". ABAP_FALSE is typed ABAP_BOOL, so
*         BOOLEAN_ABAP_2_JSON( ) turns it into the literal string `false`,
*         which is not blank and does survive that filter.
*
*         A field whose value IS set is unaffected: its key matches an item and
*         that item is selected either way. The ComboBox branch below is
*         untouched - sap.m.ComboBox has no forceSelection and never had this
*         behaviour.
          DATA(lo_sel) = io_form->select( selectedkey    = lv_bind
                                          enabled        = lv_edit
                                          forceselection = abap_false
                                          change         = mo_e->opt_evt( is_field-name )
                                          valuestate     = lv_vs
                                          valuestatetext = lv_vst
                                          width          = lv_w
                                          class          = mo_e->mo_css->cls( 'COMBO' ) ).
          LOOP AT lt_opt INTO DATA(ls_os).
            lo_sel->item( key = ls_os-key text = zcl_rak_journey_util=>opt_text( iv_key = ls_os-key iv_text = ls_os-text ) ).
          ENDLOOP.
        ELSE.
          DATA(lo_cb) = io_form->combobox( selectedkey    = lv_bind
                                           editable       = lv_edit
                                           change         = mo_e->opt_evt( is_field-name )
                                           valuestate     = lv_vs
                                           valuestatetext = lv_vst
                                           width          = lv_w
                                           class          = mo_e->mo_css->cls( 'COMBO' ) ).
          LOOP AT lt_opt INTO DATA(ls_o).
            lo_cb->item( key = ls_o-key text = zcl_rak_journey_util=>opt_text( iv_key = ls_o-key iv_text = ls_o-text ) ).
          ENDLOOP.
        ENDIF.

      WHEN 'MULTISELECT'.
        req_label( io_form = io_form is_field = is_field ).
        DATA(lo_mc) = io_form->multi_combobox( selectedkeys    = lv_bind
                                               selectionchange = mo_e->opt_evt( is_field-name )
                                               valuestate      = lv_vs
                                               width           = lv_w
                                               class           = mo_e->mo_css->cls( 'COMBO' ) ).
        LOOP AT lt_opt INTO DATA(ls_m).
          lo_mc->item( key = ls_m-key text = zcl_rak_journey_util=>opt_text( iv_key = ls_m-key iv_text = ls_m-text ) ).
        ENDLOOP.

      WHEN 'RADIO'.
        req_label( io_form = io_form is_field = is_field ).
        DATA(lv_rkey) = mo_e->val_get( is_field-name ).
        DATA lv_rsel TYPE i.
        lv_rsel = -1.
        LOOP AT lt_opt INTO DATA(ls_rk).
          IF ls_rk-key = lv_rkey.
            lv_rsel = sy-tabix - 1.
            EXIT.
          ENDIF.
        ENDLOOP.
        mo_e->val_set( iv_name = is_field-name iv_suffix = '_IX' iv_value = |{ lv_rsel }| ).

        DATA(lo_rg) = io_form->radio_button_group( selectedindex = bind_of( iv_name = is_field-name iv_suffix = '_IX' )
                                                   editable      = lv_edit
                                                   select        = mo_e->change_evt( is_field-name )
                                                   width         = lv_w
                                                   class         = mo_e->mo_css->cls( 'RADIO' ) ).
        LOOP AT lt_opt INTO DATA(ls_r).
          lo_rg->radio_button( text = zcl_rak_journey_util=>opt_text( iv_key = ls_r-key iv_text = ls_r-text ) ).
        ENDLOOP.

      WHEN 'SEGMENTED'.
        req_label( io_form = io_form is_field = is_field ).
        DATA(lo_seg) = io_form->segmented_button( selected_key     = lv_bind
                                                  selection_change = mo_e->opt_evt( is_field-name ) )->items( ).
        LOOP AT lt_opt INTO DATA(ls_s).
          lo_seg->segmented_button_item( key = ls_s-key text = ls_s-text ).
        ENDLOOP.

      WHEN 'CHECKGROUP'.
        req_label( io_form = io_form is_field = is_field ).
        SPLIT mo_e->val_get( is_field-name ) AT ',' INTO TABLE DATA(lt_cgsel).
        DATA lv_cgmax TYPE i.
        CLEAR lv_cgmax.
        LOOP AT lt_opt INTO DATA(ls_cgm).
          DATA(lv_cglen) = strlen( zcl_rak_journey_util=>opt_text( iv_key  = ls_cgm-key
                                                                  iv_text = ls_cgm-text ) ).
          IF lv_cglen > lv_cgmax.
            lv_cgmax = lv_cglen.
          ENDIF.
        ENDLOOP.

        DATA lo_cg TYPE REF TO z2ui5_cl_xml_view.
        IF lv_cgmax > 40.
          lo_cg = io_form->vbox( ).
        ELSE.
          lo_cg = io_form->hbox( ).
        ENDIF.

        LOOP AT lt_opt INTO DATA(ls_cg).
          lo_cg->checkbox(
            text     = zcl_rak_journey_util=>opt_text( iv_key = ls_cg-key iv_text = ls_cg-text )
            selected = xsdbool( line_exists( lt_cgsel[ table_line = ls_cg-key ] ) )
            editable = lv_edit
            select   = mo_e->mo_client->_event( |ROWCHK_{ is_field-name }~{ ls_cg-key }| ) ).
        ENDLOOP.

      WHEN 'RO_PANEL'.
        DATA(lo_rop) = io_form->panel( headertext = zcl_rak_journey_util=>esc( is_field-label )
                                       expandable = abap_true
                                       expanded   = bind_of( iv_name = is_field-name iv_suffix = '_EXP' ) ).
        DATA(lo_ropc) = lo_rop->content( ).
        DATA ls_rot TYPE zif_rak_journey=>ty_table.
        IF mo_e->mo_logic IS BOUND.
          TRY.
              ls_rot = mo_e->mo_logic->get_table( io_ctx = mo_e iv_name = is_field-name ).
            CATCH cx_root.
          ENDTRY.
        ENDIF.
        IF ls_rot-rows IS INITIAL.
          lo_ropc->text( text = zcl_rak_journey_util=>esc( mo_e->val_get( is_field-name ) ) ).
        ELSE.
          LOOP AT ls_rot-rows INTO DATA(lr_ror).
            DATA(lo_rorow) = lo_ropc->hbox( class = 'sapUiTinyMarginBottom' ).
            DATA lv_roc TYPE i.
            LOOP AT lr_ror INTO DATA(lv_rocell).
              lv_roc = lv_roc + 1.
              lo_rorow->text( text  = zcl_rak_journey_util=>esc( lv_rocell )
                              class = COND string( WHEN lv_roc = 1
                                              THEN 'rakRoLbl sapUiTinyMarginEnd'
                                              ELSE 'rakVal sapUiTinyMarginEnd' ) ).
            ENDLOOP.
            CLEAR lv_roc.
          ENDLOOP.
        ENDIF.

      WHEN 'REVIEW'.
        DATA(lo_rev) = io_form->vbox( ).
        DATA lv_si TYPE i.
        LOOP AT mo_e->ms_config-steps INTO DATA(ls_rvstep).
          IF lv_si = mo_e->mv_step.
            lv_si = lv_si + 1.
            CONTINUE.
          ENDIF.
          DATA lv_rvany TYPE abap_bool.
          CLEAR lv_rvany.
          LOOP AT ls_rvstep-fields INTO DATA(ls_rvchk)
               WHERE type <> 'DISPLAY'        AND type <> 'READONLY'
                 AND type <> 'REVIEW'         AND type <> 'RO_PANEL'
                 AND type <> 'PAYFEE'         AND type <> 'REQPANEL'
                 AND type <> 'EDITABLE_TABLE' AND type <> 'TABLE'.
            IF mo_e->mo_rules->is_hidden( ls_rvchk ) = abap_false
               AND ( mo_e->val_get( ls_rvchk-name ) IS NOT INITIAL
                     OR ( ( ls_rvchk-type = 'UPLOAD' OR ls_rvchk-has_attach = abap_true )
                          AND line_exists( mo_e->mt_attach[ field = to_upper( ls_rvchk-name ) ] ) ) ).
              lv_rvany = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.

          IF lv_rvany = abap_false.
            LOOP AT ls_rvstep-fields INTO DATA(ls_rvgchk)
                 WHERE type = 'EDITABLE_TABLE' OR type = 'TABLE'.
              IF mo_e->mo_rules->is_hidden( ls_rvgchk ) = abap_true.
                CONTINUE.
              ENDIF.
              IF mo_e->zif_rak_journey~get_grid_data( ls_rvgchk-name )-rows IS NOT INITIAL
                 OR mo_e->zif_rak_journey~get_backend_table( ls_rvgchk-name )-rows IS NOT INITIAL.
                lv_rvany = abap_true.
                EXIT.
              ENDIF.
            ENDLOOP.
          ENDIF.
          IF lv_rvany = abap_false.
            lv_si = lv_si + 1.
            CONTINUE.
          ENDIF.

          DATA(lo_rvc) = lo_rev->vbox( class = |{ mo_e->mo_css->cls( 'CARD' ) } sapUiTinyMarginBottom| ).
          DATA(lo_rvh) = lo_rvc->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
          lo_rvh->title( text = ls_rvstep-title ).
          lo_rvh->link( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-edit iv_default = 'Edit' )
                        press = mo_e->mo_client->_event( |GOTO_{ lv_si }| ) ).
          LOOP AT ls_rvstep-fields INTO DATA(ls_rvf)
               WHERE type <> 'DISPLAY'        AND type <> 'READONLY'
                 AND type <> 'REVIEW'         AND type <> 'RO_PANEL'
                 AND type <> 'PAYFEE'         AND type <> 'REQPANEL'
                 AND type <> 'EDITABLE_TABLE' AND type <> 'TABLE'.
            IF mo_e->mo_rules->is_hidden( ls_rvf ) = abap_true.
              CONTINUE.
            ENDIF.
            DATA(lv_rvv) = mo_e->val_get( ls_rvf-name ).
            IF ls_rvf-type = 'UPLOAD' OR ls_rvf-has_attach = abap_true.
              CLEAR lv_rvv.
              LOOP AT mo_e->mt_attach INTO DATA(ls_rva) WHERE field = to_upper( ls_rvf-name ).
                lv_rvv = COND #( WHEN lv_rvv IS INITIAL THEN ls_rva-name ELSE |{ lv_rvv }, { ls_rva-name }| ).
              ENDLOOP.
            ENDIF.
            CHECK lv_rvv IS NOT INITIAL.
            DATA lv_rvdisp TYPE string.
            CLEAR lv_rvdisp.
            IF to_upper( ls_rvf-type ) = 'RECORDCARD'.
              IF mo_e->mo_logic IS BOUND.
                DATA ls_rvtab TYPE zif_rak_journey=>ty_table.
                CLEAR ls_rvtab.
                TRY.
                    ls_rvtab = mo_e->mo_logic->get_table( io_ctx = mo_e iv_name = ls_rvf-name ).
                  CATCH cx_root.
                ENDTRY.
                LOOP AT ls_rvtab-rows INTO DATA(lr_rvrow).
                  IF VALUE string( lr_rvrow[ 1 ] OPTIONAL ) = lv_rvv.
                    LOOP AT lr_rvrow INTO DATA(lv_rvcell) FROM 2.
                      lv_rvdisp = COND #( WHEN lv_rvdisp IS INITIAL THEN lv_rvcell ELSE |{ lv_rvdisp } · { lv_rvcell }| ).
                    ENDLOOP.
                    EXIT.
                  ENDIF.
                ENDLOOP.
              ENDIF.
              IF lv_rvdisp IS INITIAL.
                lv_rvdisp = lv_rvv.
              ENDIF.
            ELSEIF ls_rvf-options IS NOT INITIAL.
              SPLIT lv_rvv AT ',' INTO TABLE DATA(lt_rvk).
              LOOP AT lt_rvk INTO DATA(lv_rvk).
                DATA(lv_rvt) = VALUE string( ls_rvf-options[ key = lv_rvk ]-text OPTIONAL ).
                IF lv_rvt IS INITIAL.
                  lv_rvt = lv_rvk.
                ENDIF.
                lv_rvdisp = COND #( WHEN lv_rvdisp IS INITIAL THEN lv_rvt ELSE |{ lv_rvdisp }, { lv_rvt }| ).
              ENDLOOP.
            ELSE.
              lv_rvdisp = lv_rvv.
            ENDIF.
            DATA(lo_rvr) = lo_rvc->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
            lo_rvr->label( text = zcl_rak_journey_util=>esc( |{ ls_rvf-label }:| ) class = 'rakRevL' ).
            lo_rvr->text( text = zcl_rak_journey_util=>esc( lv_rvdisp ) class = 'rakVal' ).
          ENDLOOP.

          LOOP AT ls_rvstep-fields INTO DATA(ls_rvg)
               WHERE type = 'EDITABLE_TABLE' OR type = 'TABLE'.
            IF mo_e->mo_rules->is_hidden( ls_rvg ) = abap_true.
              CONTINUE.
            ENDIF.

            DATA(ls_rvgd) = mo_e->zif_rak_journey~get_grid_data( ls_rvg-name ).
            IF ls_rvgd-rows IS INITIAL.
              ls_rvgd = mo_e->zif_rak_journey~get_backend_table( ls_rvg-name ).
            ENDIF.
            IF ls_rvgd-rows IS INITIAL.
              CONTINUE.
            ENDIF.

            lo_rvc->label( text  = zcl_rak_journey_util=>esc( |{ ls_rvg-label }:| )
                           class = 'rakRevL sapUiTinyMarginTop' ).

            DATA(lo_rvt) = lo_rvc->table( items = `` class = 'sapUiTinyMarginBottom' ).
            DATA(lo_rvcols) = lo_rvt->columns( ).
            LOOP AT ls_rvgd-columns INTO DATA(lv_rvcol).
              lo_rvcols->column( )->text( text = zcl_rak_journey_util=>esc( lv_rvcol ) ).
            ENDLOOP.

            DATA(lo_rvitems) = lo_rvt->items( ).
            LOOP AT ls_rvgd-rows INTO DATA(lt_rvrow).
              DATA(lo_rvci) = lo_rvitems->column_list_item( )->cells( ).
              LOOP AT lt_rvrow INTO DATA(lv_rvc).
                lo_rvci->text( text = zcl_rak_journey_util=>esc( lv_rvc ) ).
              ENDLOOP.
            ENDLOOP.
          ENDLOOP.

          lv_si = lv_si + 1.
        ENDLOOP.

      WHEN 'DATE'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->date_picker( value          = lv_bind
                              editable       = lv_edit
                              valuestate     = lv_vs
                              valuestatetext = lv_vst
                              width          = lv_w
*                             dd.MM.yyyy, not dd/MM/yyyy. The dot form is the one
*                             the rest of the product already shows - grid DATE
*                             cells, the license list - and it is the only one
*                             the framework can read back: the grid date parser
*                             tests LV_D+2(1) = '.' and LV_D+5(1) = '.' and
*                             accepts nothing else but YYYYMMDD. A scalar date
*                             rendered with slashes therefore displayed in one
*                             format and parsed in another.
                              valueformat    = 'yyyy-MM-dd'
                              displayformat  = 'dd.MM.yyyy' ).

      WHEN 'TIME'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->time_picker( value = lv_bind enabled = lv_edit valuestate = lv_vs valuestatetext = lv_vst width = lv_w ).

      WHEN 'DATETIME'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->date_time_picker( value = lv_bind enabled = lv_edit valuestate = lv_vs ).

      WHEN 'CHECKBOX'.
        DATA(lo_cbx) = io_form->hbox( alignitems = 'Start' width = '100%' ).
*       THE MARKER LEADS THE STATEMENT, unlike every other field, where
*       REQ_LABEL sets the native sap.m.Label REQUIRED property and UI5 puts the
*       marker after the text - which is what the rest of the form should keep.
*
*       A checkbox is not a label. Its text is a whole consent sentence, and the
*       star is a SIBLING in the hbox rather than part of the text, so trailing
*       placement pushes it past the entire wrapped block - level with the first
*       line but at the far end of the row, reading as a stray character rather
*       than a marker on the statement. ALIGNITEMS 'Start' keeps it on the first
*       line here, which is where a reader looks for it.
*
*       Order is DOM order, not CSS: the hbox reverses under dir=rtl, so this is
*       leading in Arabic too, with no direction-specific rule.
        IF mo_e->mo_rules->is_required( is_field ) = abap_true.
          lo_cbx->text( text = `*` class = 'rakReqStar' ).
        ENDIF.
        lo_cbx->checkbox( class    = mo_e->mo_css->cls( 'CHECKBOX' )
                          text     = zcl_rak_journey_util=>esc( long_text( is_field ) )
                          selected = lv_bind
                          editable = lv_edit
                          wrapping = abap_true
                          select   = mo_e->opt_evt( is_field-name ) ).

      WHEN 'SWITCH'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->switch( state = lv_bind enabled = lv_edit change = mo_e->opt_evt( is_field-name ) ).

      WHEN 'TEXTAREA'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->text_area( value            = lv_bind
                            rows             = '3'
                            editable         = lv_edit
                            maxlength        = COND string( WHEN is_field-validation-max_len > 0 THEN |{ is_field-validation-max_len }| ELSE `0` )
                            showexceededtext = xsdbool( is_field-validation-max_len > 0 )
                            valuestate       = lv_vs
                            valuestatetext   = lv_vst
                            class            = mo_e->mo_css->cls( 'TEXTAREA' ) ).

      WHEN 'NUMBER'.
        req_label( io_form = io_form is_field = is_field ).
*       MAXLENGTH is passed for the same reason the TEXTAREA branch above
*       does, but on THIS type it is a no-op, not a fix: TYPE = 'Number'
*       renders an HTML <input type="number">, which ignores MAXLENGTH by
*       specification - accepted, disregarded by the browser. A bounded
*       whole number (digit count actually capped at the keyboard) is
*       FTYPE 'COUNT' below, not this one; NUMBER stays what it has
*       always been - unlimited digits, enforced only at VALIDATE_STEP.
*       Kept here anyway rather than removed, so a config already relying
*       on it for CSS/analytics reasons keeps behaving byte-identically.
        io_form->input( class          = mo_e->mo_css->cls( 'INPUT' )
                        value          = lv_bind
                        type           = 'Number'
                        placeholder    = is_field-placeholder
                        editable       = lv_edit
                        change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                        maxlength      = COND string( WHEN is_field-validation-max_len > 0 THEN |{ is_field-validation-max_len }| ELSE `0` )
                        valuestate     = lv_vs
                        valuestatetext = lv_vst
                        width          = lv_w ).

      WHEN 'COUNT'.
        req_label( io_form = io_form is_field = is_field ).
*       A bounded whole number, round-5 finding 2's actual fix - a plain
*       text input, not TYPE = 'Number', so MAXLENGTH genuinely caps what
*       can be typed (an <input type="number"> ignores it - see NUMBER
*       above). TYPE = 'Tel' only for its numeric-leaning mobile keypad;
*       it renders a normal textual input under the hood, unlike Number,
*       which is why MAXLENGTH still works here. Digits-only is NOT
*       enforced client-side - z2ui5's INPUT( ) has no keystroke filter to
*       reach for - so this still relies on VALIDATE_STEP's server check,
*       exactly as FTYPE 'INPUT' already does today. The win over INPUT is
*       real even so: MAXLENGTH plus a number-friendly keypad, in one
*       FTYPE, instead of a config author choosing which of the two to
*       give up.
*       DIGITS-ONLY AT THE KEYBOARD, where MAX_LEN says how many.
*       sap.m.MaskInput enforces its mask entirely in the browser - no event,
*       no round trip - and its built-in '9' symbol is already [0-9], so a
*       bounded count needs the mask repeated MAX_LEN times and no rule. The
*       citizen stops being able to type a letter at all, instead of being
*       told about it on Next after filling eight more fields.
*
*       ONLY WHEN EDITABLE, and that is not a preference. Z2UI5's MASK_INPUT( )
*       exposes no EDITABLE property, so a read-only COUNT drawn through it
*       would become typable - the field would go from displaying a value to
*       accepting one. The INPUT( ) below stays the read-only path and keeps
*       exactly the markup it has today.
*
*       ONLY WHEN MAX_LEN IS SET, because the mask IS the length: with no
*       MAX_LEN there is nothing to repeat, and REPEAT( occ = 0 ) is an empty
*       mask that would accept nothing at all.
*
*       PLACEHOLDERSYMBOL IS DELIBERATELY NOT PASSED. A space is the symbol
*       this would want - it keeps an empty field looking empty - and a space
*       cannot be sent: it is blank, and XML_GET_PARTS( ) drops every blank
*       property from the markup, exactly as it dropped FORCESELECTION on the
*       CLOSED_LIST branch. Passing one would leave UI5's own default applying
*       while the ABAP read as though it had been set. So the default '_'
*       applies and is handled where it lands, in NORM_MASKED( ) - an empty
*       two-digit field shows "__" until the citizen types.
        IF is_field-validation-max_len > 0 AND lv_edit = abap_true.
          io_form->mask_input( mask           = repeat( val = `9` occ = is_field-validation-max_len )
                               value          = lv_bind
                               placeholder    = is_field-placeholder
                               change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                               valuestate     = lv_vs
                               valuestatetext = lv_vst
                               width          = lv_w ).
        ELSE.
          io_form->input( class          = mo_e->mo_css->cls( 'INPUT' )
                          value          = lv_bind
                          type           = 'Tel'
                          placeholder    = is_field-placeholder
                          editable       = lv_edit
                          change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                          maxlength      = COND string( WHEN is_field-validation-max_len > 0 THEN |{ is_field-validation-max_len }| ELSE `0` )
                          valuestate     = lv_vs
                          valuestatetext = lv_vst
                          width          = lv_w ).
        ENDIF.

      WHEN 'EMAIL'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( class          = mo_e->mo_css->cls( 'INPUT' )
                        value          = lv_bind
                        type           = 'Email'
                        placeholder    = is_field-placeholder
                        editable       = lv_edit
                        change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                        valuestate     = lv_vs
                        valuestatetext = lv_vst
                        width          = lv_w ).

      WHEN 'PHONE'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( class          = mo_e->mo_css->cls( 'INPUT' )
                        value          = lv_bind
                        type           = 'Tel'
                        placeholder    = is_field-placeholder
                        editable       = lv_edit
                        change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                        valuestate     = lv_vs
                        valuestatetext = lv_vst
                        width          = lv_w ).

      WHEN 'CURRENCY'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( value          = lv_bind
                        type           = 'Number'
                        placeholder    = COND string( WHEN is_field-placeholder IS NOT INITIAL THEN is_field-placeholder ELSE 'AED' )
                        editable       = lv_edit
                        change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                        valuestate     = lv_vs
                        valuestatetext = lv_vst
                        width          = lv_w ).

      WHEN 'SLIDER'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->slider( value               = lv_bind
                         min                 = lv_min
                         max                 = lv_max
                         step                = '1'
                         enabled             = lv_edit
                         width               = '100%'
                         showadvancedtooltip = abap_true ).

      WHEN 'STEPPER'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->step_input( value                 = lv_bind
                             min                   = lv_min
                             max                   = lv_max
                             step                  = '1'
                             displayvalueprecision = '0'
                             editable              = lv_edit
                             width                 = lv_w ).

      WHEN 'RATING'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->rating_indicator( value       = lv_bind
                                   maxvalue    = COND string( WHEN is_field-validation-max_val IS NOT INITIAL THEN is_field-validation-max_val ELSE '5' )
                                   editable    = lv_edit
                                   displayonly = mo_e->mo_rules->is_readonly( is_field ) ).

      WHEN 'PROGRESS'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->progress_indicator( percentvalue = COND string( WHEN mo_e->val_get( is_field-name ) IS NOT INITIAL THEN lv_bind ELSE '0' )
                                     showvalue    = abap_true
                                     state        = COND string( WHEN is_field-state IS NOT INITIAL THEN is_field-state ELSE 'None' ) ).

      WHEN 'STATUS'.
        req_label( io_form = io_form is_field = is_field ).
        DATA(lv_sst) = COND string( WHEN is_field-state IS NOT INITIAL
                                    THEN is_field-state
                                    ELSE status_state( iv_value = mo_e->val_get( is_field-name )
                                                       iv_map   = is_field-default ) ).
        io_form->object_status( text  = lv_bind
                                state = lv_sst
                                class = 'rakStat' ).

      WHEN 'OBJNUM'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->object_number( number     = lv_bind
                                numberunit = is_field-placeholder
                                emphasized = abap_true ).

      WHEN 'LINK'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->link(
          text   = COND string( WHEN mo_e->val_get( is_field-name ) IS NOT INITIAL THEN lv_bind ELSE is_field-label )
          href   = is_field-default
          target = '_blank' ).

      WHEN 'READONLY'.
        req_label( io_form = io_form is_field = is_field ).
*       VALUESTATE/VALUESTATETEXT bound same as the plain INPUT branch below -
*       without them a REQUIRED READONLY field that fails validation has
*       nothing on screen to turn red, leaving a message with no field to
*       point at (a FTYPE 'INPUT' + READONLY='X' field renders identically
*       and already binds both, which is what masked this until now).
        io_form->input( value          = lv_bind
                        editable       = abap_false
                        width          = lv_w
                        class          = mo_e->mo_css->cls( 'INPUT' )
                        valuestate     = lv_vs
                        valuestatetext = lv_vst ).

      WHEN 'PDF'.
*       sap.m.PDFViewer, emitted through _GENERIC( ) because Z2UI5_CL_XML_VIEW
*       does not expose it directly - PDF_VIEWER( ) lives on the fragment class,
*       which is not the one the renderer builds with. _GENERIC is public and
*       takes the control name plus its properties, so nothing is lost.
*
*       WHERE THE DOCUMENT COMES FROM, in order:
*         the field's VALUE      a URL a handler resolved at runtime - an
*                                attachment just uploaded, a certificate the
*                                backend generated for this request
*         DEFAULT_VAL            a static URL from configuration - terms, a
*                                specimen form, anything the same for everyone
*
*       Value first, because a handler that resolved a document for THIS case
*       must outrank a default that describes the service in general.
        DATA(lv_pdf) = mo_e->val_get( is_field-name ).
        IF lv_pdf IS INITIAL.
          lv_pdf = is_field-default.
        ENDIF.

        IF lv_pdf IS INITIAL.
*         Say so rather than drawing an empty grey box. A viewer with no source
*         renders as a blank panel that reads as a document still loading, and
*         the citizen waits for something that is never coming.
          req_label( io_form = io_form is_field = is_field ).
          io_form->message_strip(
            text     = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pdf_none
                                          iv_default = 'No document to display yet.' )
            type     = 'Information'
            showicon = abap_true ).
        ELSE.
*         ISTRUSTEDSOURCE only for a same-origin path. sap.m.PDFViewer shows a
*         trust prompt before opening a cross-origin document, and suppressing
*         that on an arbitrary URL from configuration would be deciding, on the
*         citizen's behalf, that whatever DEFAULT_VAL points at is safe. A
*         relative path is served by this system and needs no prompt.
          DATA(lv_trusted) = COND string(
            WHEN strlen( lv_pdf ) > 0 AND lv_pdf(1) = '/' THEN 'true' ELSE 'false' ).

          io_form->_generic(
            name   = 'PDFViewer'
            t_prop = VALUE #(
              ( n = 'source'             v = lv_pdf )
              ( n = 'title'              v = zcl_rak_journey_util=>esc( is_field-label ) )
              ( n = 'height'             v = COND string( WHEN is_field-width IS NOT INITIAL
                                                          THEN is_field-width ELSE '45rem' ) )
              ( n = 'width'              v = '100%' )
              ( n = 'isTrustedSource'    v = lv_trusted )
*             The download button is the one control a reader genuinely needs -
*             a declaration they are agreeing to is one they may want to keep.
              ( n = 'showDownloadButton' v = 'true' ) ) ).
        ENDIF.

      WHEN 'DISPLAY'.
        req_label( io_form = io_form is_field = is_field ).
*       A DISPLAY field has always taken its paragraph from DEFAULT_VAL by
*       way of the model, which is why it never hit the 150-character
*       ceiling. TEXT: is accepted here too, so one convention covers both
*       and a bilingual paragraph can use the @ form; without it, nothing
*       about the old route changes.
        IF is_field-default CP 'TEXT:*'.
          io_form->text( text = long_text( is_field ) ).
        ELSE.
          io_form->text( text = lv_bind ).
        ENDIF.

      WHEN 'RESULT'.
        render_result( io_parent = io_form is_field = is_field ).

      WHEN OTHERS.
        req_label( io_form = io_form is_field = is_field ).
        IF lt_opt IS NOT INITIAL.
          DATA(lo_gcb) = io_form->combobox( selectedkey = lv_bind
                                            editable    = lv_edit
                                            change      = mo_e->opt_evt( is_field-name )
                                            valuestate  = lv_vs
                                            width       = lv_w ).
          LOOP AT lt_opt INTO DATA(ls_g).
            lo_gcb->item( key = ls_g-key text = zcl_rak_journey_util=>opt_text( iv_key = ls_g-key iv_text = ls_g-text ) ).
          ENDLOOP.
        ELSE.
*         MAXLENGTH - see the NUMBER branch above for why this and TEXTAREA
*         get it and CURRENCY deliberately does not.
          io_form->input( value          = lv_bind
                          placeholder    = is_field-placeholder
                          editable       = lv_edit
                          change         = mo_e->opt_evt( iv_name = is_field-name iv_typed = abap_true )
                          maxlength      = COND string( WHEN is_field-validation-max_len > 0 THEN |{ is_field-validation-max_len }| ELSE `0` )
                          valuestate     = lv_vs
                          valuestatetext = lv_vst
                          width          = lv_w ).
        ENDIF.
    ENDCASE.

*   WHY THE LIST IS EMPTY, on the screen rather than only in the trace.
*   An API-bound field can come back with nothing for reasons that look
*   identical otherwise - no partner on the launch, no property against
*   that partner, or an entity set no wrapper serves yet - and the whole
*   reason the directive exists is so those stop being the same picture.
    IF lv_apinote IS NOT INITIAL.
      io_form->message_strip( text     = zcl_rak_journey_util=>esc( lv_apinote )
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiTinyMarginTop' ).
    ENDIF.

    IF is_field-has_attach = abap_true.
      render_attach( io_form = io_form is_field = is_field ).
    ENDIF.
  ENDMETHOD.


  METHOD render_pay.
    IF mo_e->mo_logic IS NOT BOUND.
      io_parent->message_strip(
        text     = 'Payment is unavailable: this journey has a PAYFEE field but no handler class.'
        type     = 'Error'
        showicon = abap_true
        class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

    io_parent->title( text = COND #( WHEN is_field-label IS NOT INITIAL THEN is_field-label ELSE 'Payment' )
                      class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
    TRY.
        IF mo_e->mo_logic->render_field( io_ctx = mo_e io_form = io_parent is_field = is_field ) = abap_false.
          io_parent->message_strip(
            text     = 'The handler did not render the payment step.'
            type     = 'Error'
            showicon = abap_true
            class    = 'sapUiSmallMargin' ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_pay).
        io_parent->message_strip( text     = zcl_rak_journey_util=>esc( |Payment unavailable: { lx_pay->get_text( ) }| )
                                  type     = 'Error'
                                  showicon = abap_true
                                  class    = 'sapUiSmallMargin' ).
    ENDTRY.
  ENDMETHOD.


  METHOD render_popup.
    IF mo_e->mv_popup IS INITIAL.
      IF mo_e->mv_popup_shown = abap_true.
        mo_e->mo_client->popup_destroy( ).
        CLEAR mo_e->mv_popup_shown.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(lo_pop) = z2ui5_cl_xml_view=>factory_popup( ).

    CASE mo_e->mv_popup.
      WHEN 'PCLDET'.
*       ZCL_RAK_CJ_PARCEL=>C_POPUP, as a literal: naming the constant here
*       would be a static reference to the class the engine deliberately
*       reaches only by name. An unbound control cannot have set it.
        IF mo_e->mo_pcl IS NOT BOUND.
          CLEAR mo_e->mv_popup.
          RETURN.
        ENDIF.
        TRY.
            IF mo_e->mo_pcl->render_popup( lo_pop ) = abap_false.
              CLEAR mo_e->mv_popup.
              RETURN.
            ENDIF.
          CATCH cx_root.
            CLEAR: mo_e->mv_popup, mo_e->mv_pcl_det.
            RETURN.
        ENDTRY.

      WHEN 'CUST'.
        IF mo_e->mo_logic IS NOT BOUND.
          CLEAR: mo_e->mv_popup, mo_e->mv_popup_id.
          RETURN.
        ENDIF.
        TRY.
            mo_e->mo_logic->on_render_popup( io_ctx   = mo_e
                                             io_popup = lo_pop
                                             iv_id    = mo_e->mv_popup_id ).
          CATCH cx_root.
            CLEAR: mo_e->mv_popup, mo_e->mv_popup_id.
            IF mo_e->mv_popup_shown = abap_true.
              mo_e->mo_client->popup_destroy( ).
              CLEAR mo_e->mv_popup_shown.
            ENDIF.
            RETURN.
        ENDTRY.

      WHEN 'BP'.
        DATA(lo_dlg) = lo_pop->dialog(
          title        = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bp_find iv_default = 'Find Business Partner' )
          contentwidth = '42rem' ).
        DATA(lo_c)   = lo_dlg->content( ).

        DATA(ls_bpf) = mo_e->safe_field( mo_e->mv_pop_field ).
        IF ls_bpf-has_attach = abap_true.
          DATA(lo_up) = lo_c->vbox( class = 'sapUiSmallMarginBeginEnd' ).
          lo_up->label( text = COND #( WHEN ls_bpf-attach_label IS NOT INITIAL
                                       THEN ls_bpf-attach_label
                                       ELSE 'Supporting document' ) ).
          mo_e->zif_rak_journey~render_upload( io_view  = lo_up
                                               iv_field = ls_bpf-name ).
        ENDIF.
        DATA(lo_bar) = lo_c->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
        lo_bar->input( value       = mo_e->mo_client->_bind_edit( mo_e->mv_bp_term )
                       placeholder = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bp_hint
                                       iv_default = 'Partner no. / name / Emirates ID (min. 3 characters)' )
                       width       = '22rem'
                       submit      = mo_e->mo_client->_event( 'BPGO' ) ).
        lo_bar->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' )
                        type  = 'Emphasized'
                        icon  = 'sap-icon://search'
                        class = 'sapUiTinyMarginBegin'
                        press = mo_e->mo_client->_event( 'BPGO' ) ).
        IF mo_e->mt_bp_hits IS NOT INITIAL.
          DATA(lo_t)   = lo_c->table( class = 'sapUiSmallMarginBeginEnd' ).
          DATA(lo_col) = lo_t->columns( ).
          lo_col->column( )->text( 'Partner' ).
          lo_col->column( )->text( 'Name' ).
          lo_col->column( )->text( 'Emirates ID' ).
          lo_col->column( halign = 'End' )->text( '' ).
          DATA(lo_it) = lo_t->items( ).
          LOOP AT mo_e->mt_bp_hits INTO DATA(ls_h).
            lo_it->column_list_item( )->cells(
              )->text( ls_h-partner )->text( ls_h-name )->text( ls_h-idnum
              )->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-use iv_default = 'Use' )
                         icon  = 'sap-icon://accept'
                         type  = 'Emphasized'
                         press = mo_e->mo_client->_event( |BPPICK_{ ls_h-partner }| ) ).
          ENDLOOP.
        ENDIF.
        lo_dlg->buttons( )->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-close iv_default = 'Close' )
                                    press = mo_e->mo_client->_event( 'POPCLOSE' ) ).

      WHEN 'DELCONF'.
        DATA(lo_dc) = lo_pop->dialog(
          title        = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-del_title iv_default = 'Delete application' )
          contentwidth = '26rem' ).
        lo_dc->content( )->vbox( class = 'sapUiMediumMargin'
          )->message_strip( text     = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-del_warn
                                         iv_default = 'This permanently removes the application and any saved draft. This cannot be undone.' )
                            type     = 'Warning'
                            showicon = abap_true ).
        DATA(lo_dcb) = lo_dc->buttons( ).
        lo_dcb->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-delete iv_default = 'Delete' )
                        type  = 'Reject'
                        icon  = 'sap-icon://delete'
                        press = mo_e->mo_client->_event( 'DELETE' ) ).
        lo_dcb->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-cancel iv_default = 'Cancel' )
                        press = mo_e->mo_client->_event( 'POPCLOSE' ) ).
    ENDCASE.

    mo_e->mo_client->popup_display( lo_pop->stringify( ) ).
    mo_e->mv_popup_shown = abap_true.
  ENDMETHOD.


  METHOD render_result.

    IF mo_e->mv_closed = abap_true.
      DATA(lv_car) = COND string( WHEN mo_e->mv_lang = 'A' THEN ` dir="rtl"` ELSE `` ).
      DATA(lv_cth) = COND string( WHEN mo_e->mv_lang = 'A' THEN `شكراً لك` ELSE `Thank you` ).
      DATA(lv_cts) = COND string( WHEN mo_e->mv_lang = 'A'
                                  THEN `يمكنك إغلاق هذه الصفحة الآن.`
                                  ELSE `You can close this page now.` ).
      DATA(lo_ccard) = io_parent->vbox( class = mo_e->mo_css->cls( 'CARD' ) ).
      DATA lv_ch TYPE string.
      lv_ch = `<div` && lv_car && ` style="text-align:center;padding:2rem 1rem;">`
           && `<svg width="76" height="76" viewBox="0 0 44 44" style="margin-bottom:.7rem;">`
           && `<circle cx="22" cy="22" r="20" fill="none" stroke="#2e9e4f" stroke-width="2.6"/>`
           && `<circle cx="15.5" cy="18" r="2.1" fill="#2e9e4f"/>`
           && `<circle cx="28.5" cy="18" r="2.1" fill="#2e9e4f"/>`
           && `<path d="M13.5 26 Q22 33 30.5 26" fill="none" stroke="#2e9e4f"`
           && ` stroke-width="3" stroke-linecap="round"/>`
           && `</svg>`
           && `<div style="font-size:1.35rem;font-weight:700;color:#2e9e4f;">`
           && zcl_rak_journey_util=>esc( lv_cth ) && `</div>`
           && `<div style="font-size:.9rem;opacity:.75;margin-top:.3rem;">`
           && zcl_rak_journey_util=>esc( lv_cts ) && `</div></div>`.
      lo_ccard->html( content = lv_ch sanitizecontent = abap_false ).
      RETURN.
    ENDIF.

    DATA(lv_ref)  = mo_e->case_reference( ).
    DATA(lv_paid) = abap_false.
    DATA lv_i TYPE i.
    lv_i = 0.
    WHILE lv_i < lines( mo_e->ms_config-steps ).
      DATA(lv_pf) = pay_field( lv_i ).
      IF lv_pf IS NOT INITIAL AND mo_e->zif_rak_journey~get_val( lv_pf ) = 'PAID'.
        lv_paid = abap_true.
        EXIT.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

    DATA(lv_done) = xsdbool( lv_paid = abap_true OR mo_e->mv_submitted = abap_true
                             OR mo_e->mv_case_number IS NOT INITIAL ).

    DATA lv_col   TYPE string.
    DATA lv_head  TYPE string.
    DATA lv_sub   TYPE string.
*   THROUGH THE CATALOGUE, not literals. These four strings had no language test
*   at all, while the closed-card above and the Reference label below were both
*   already bilingual - so an Arabic run reached the end of a journey and was
*   told in English that it had worked. IV_DEFAULT carries the exact previous
*   wording, so a missing catalogue row shows what it showed before.
    IF lv_done = abap_true.
      lv_col  = `#2e9e4f`.
      lv_head = COND string( WHEN lv_paid = abap_true
                             THEN zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-res_paid
                                                     iv_default = 'Payment received' )
                             ELSE zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-res_submitted
                                                     iv_default = 'Application submitted' ) ).
      lv_sub  = zcl_rak_text=>get(
                  iv_no      = zcl_rak_text=>c_no-res_done_sub
                  iv_default = 'We have everything we need. Keep the reference below for any follow-up.' ).
    ELSE.
      lv_col  = `#e0a800`.
      lv_head = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-res_not_submitted
                                   iv_default = 'Not submitted yet' ).
      lv_sub  = zcl_rak_text=>get(
                  iv_no      = zcl_rak_text=>c_no-res_not_sub_sub
                  iv_default = 'This application has not been submitted. Go back and complete the remaining steps.' ).
    ENDIF.

    DATA(lv_rtl) = COND string( WHEN mo_e->mv_lang = 'A' THEN ` dir="rtl"` ELSE `` ).

    DATA(lo_card) = io_parent->vbox( class = mo_e->mo_css->cls( 'CARD' ) ).

    DATA lv_h TYPE string.
    lv_h = `<div` && lv_rtl && ` style="text-align:center;padding:1.6rem 1rem .4rem;">`
        && `<svg width="72" height="72" viewBox="0 0 44 44" style="margin-bottom:.6rem;">`
        && `<circle cx="22" cy="22" r="20" fill="none" stroke="` && lv_col && `" stroke-width="2.6"/>`
        && COND string( WHEN lv_done = abap_true
                        THEN `<path d="M13 22 L19 28 L31 16" fill="none" stroke="` && lv_col
                          && `" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>`
                        ELSE `<path d="M22 12 L22 24" stroke="` && lv_col && `" stroke-width="3" stroke-linecap="round"/>`
                          && `<circle cx="22" cy="30" r="2" fill="` && lv_col && `"/>` )
        && `</svg>`
        && `<div style="font-size:1.35rem;font-weight:700;color:` && lv_col && `;">`
        && zcl_rak_journey_util=>esc( lv_head ) && `</div>`
        && `<div style="font-size:.9rem;opacity:.75;margin-top:.3rem;max-width:34rem;`
        && `margin-left:auto;margin-right:auto;">` && zcl_rak_journey_util=>esc( lv_sub ) && `</div>`
        && `</div>`.
    lo_card->html( content = lv_h sanitizecontent = abap_false ).

    IF lv_ref IS NOT INITIAL AND lv_done = abap_true.
      DATA lv_r TYPE string.
      lv_r = `<div` && lv_rtl && ` style="text-align:center;margin:.2rem 0 1.2rem;">`
          && `<div style="font-size:.75rem;letter-spacing:.08em;text-transform:uppercase;opacity:.6;">`
          && zcl_rak_journey_util=>esc( COND string( WHEN mo_e->mv_lang = 'A'
                                                     THEN `الرقم المرجعي` ELSE `Reference` ) )
          && `</div>`
          && `<div style="font-family:monospace;font-size:1.5rem;font-weight:700;`
          && `letter-spacing:.04em;margin-top:.15rem;">`
          && zcl_rak_journey_util=>esc( lv_ref ) && `</div></div>`.
      lo_card->html( content = lv_r sanitizecontent = abap_false ).
    ENDIF.

    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX mo_e->mv_step + 1.
    DATA lv_rows TYPE string.
    LOOP AT ls_step-fields INTO DATA(ls_f)
         WHERE ( type = 'DISPLAY' OR type = 'READONLY' )
           AND name <> is_field-name AND hidden = abap_false.
      DATA(lv_v) = mo_e->zif_rak_journey~get_val( ls_f-name ).
      IF lv_v IS INITIAL.
        CONTINUE.
      ENDIF.
      IF disp( lv_v ) = lv_ref.
        CONTINUE.
      ENDIF.
      lv_rows = lv_rows
        && `<div style="display:flex;justify-content:space-between;gap:1.5rem;`
        && `padding:.65rem .2rem;border-top:1px solid rgba(0,0,0,.07);">`
        && `<span style="opacity:.7;">` && zcl_rak_journey_util=>esc( ls_f-label ) && `</span>`
        && `<span style="font-weight:600;text-align:end;">` && zcl_rak_journey_util=>esc( disp( lv_v ) ) && `</span>`
        && `</div>`.
    ENDLOOP.

    IF lv_paid = abap_true.
      DATA(lv_amt) = mo_e->zif_rak_journey~get_val( 'PAY_TOTAL' ).
      IF lv_amt IS NOT INITIAL.
        lv_rows = lv_rows
          && `<div style="display:flex;justify-content:space-between;gap:1.5rem;`
          && `padding:.65rem .2rem;border-top:1px solid rgba(0,0,0,.07);">`
          && `<span style="opacity:.7;">`
          && zcl_rak_journey_util=>esc( COND string( WHEN mo_e->mv_lang = 'A'
                                                     THEN `المبلغ المدفوع` ELSE `Amount paid` ) )
          && `</span><span style="font-weight:600;">`
          && zcl_rak_journey_util=>esc( lv_amt ) && ` AED</span></div>`.
      ENDIF.
      DATA(lv_pref) = mo_e->zif_rak_journey~get_val( 'PAY_REFERENCE' ).
      IF lv_pref IS NOT INITIAL.
        lv_rows = lv_rows
          && `<div style="display:flex;justify-content:space-between;gap:1.5rem;`
          && `padding:.65rem .2rem;border-top:1px solid rgba(0,0,0,.07);">`
          && `<span style="opacity:.7;">`
          && zcl_rak_journey_util=>esc( COND string( WHEN mo_e->mv_lang = 'A'
                                                     THEN `رقم عملية الدفع` ELSE `Payment reference` ) )
          && `</span><span style="font-family:monospace;font-weight:600;">`
          && zcl_rak_journey_util=>esc( disp( lv_pref ) ) && `</span></div>`.
      ENDIF.
    ENDIF.

    IF lv_rows IS NOT INITIAL.
      lo_card->html( content         = `<div` && lv_rtl && ` style="padding:0 1.2rem 1rem;">`
                                       && lv_rows && `</div>`
                     sanitizecontent = abap_false ).
    ENDIF.
  ENDMETHOD.


  METHOD render_single.
    DATA lv_i TYPE i.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
      io_parent->title( text = zcl_rak_journey_util=>esc( ls_step-title ) class = 'sapUiSmallMarginBegin' ).
      render_step( io_parent = io_parent is_step = ls_step iv_index = lv_i ).
      lv_i = lv_i + 1.
    ENDLOOP.
    render_footer( io_parent = io_parent iv_linear = abap_false ).
  ENDMETHOD.


  METHOD render_step.
    mo_e->zif_rak_journey~set_val( iv_name = 'PAY_FOOTER' iv_value = '' ).
    IF is_step-next_req IS NOT INITIAL.
      DATA(ls_pf) = mo_e->safe_field( is_step-next_req ).
      IF to_upper( ls_pf-type ) = 'PAYFEE'.
        mo_e->zif_rak_journey~set_val( iv_name = 'PAY_FOOTER' iv_value = 'X' ).
      ENDIF.
    ENDIF.

    DATA lo_form    TYPE REF TO z2ui5_cl_xml_view.
    DATA lo_target  TYPE REF TO z2ui5_cl_xml_view.
    DATA lo_cell    TYPE REF TO z2ui5_cl_xml_view.
    DATA lv_section TYPE string.
    DATA lv_group   TYPE string.
    DATA lv_taken   TYPE i.
*   Indices already drawn out of order. LV_TAKEN is a high-water mark and can
*   only skip a contiguous run; gathering uploads that are NOT adjacent needs to
*   record each one it consumed.
    DATA lt_used    TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA lv_flex    TYPE abap_bool.

*   ONE file-type hint for the step, not one under every Choose file button.
*
*   "PDF, JPG, PNG · up to 2 MB" repeated eleven times down a Documents page is
*   the same sentence eleven times; it was asked for once, in the header, for
*   every service. So the hint is emitted here when EVERY uploader on the step
*   agrees on types and size, and RENDER_UPLOADER( ) is told to stay quiet.
*
*   Only when they agree. A step where one attachment takes a different type or
*   a larger file has no single true sentence to put at the top, so those keep
*   their own hints and nothing is printed here - a wrong hint above eleven
*   uploaders is worse than a repeated right one.
    CLEAR mv_att_hint_hide.
    DATA lv_ht    TYPE string.
    DATA lv_hm    TYPE i.
    DATA lv_hn    TYPE i.
    DATA lv_hsame TYPE abap_bool VALUE abap_true.

    LOOP AT is_step-fields INTO DATA(ls_fh)
         WHERE ( type = 'UPLOAD' OR has_attach = abap_true ).
      IF mo_e->mo_rules->is_hidden( ls_fh ) = abap_true.
        CONTINUE.
      ENDIF.
      lv_hn = lv_hn + 1.
      IF lv_hn = 1.
        lv_ht = to_upper( condense( ls_fh-attach_types ) ).
        lv_hm = mo_e->att_max_mb( ls_fh-attach_maxmb ).
      ELSEIF to_upper( condense( ls_fh-attach_types ) ) <> lv_ht
          OR mo_e->att_max_mb( ls_fh-attach_maxmb ) <> lv_hm.
        lv_hsame = abap_false.
      ENDIF.
    ENDLOOP.

    IF lv_hn > 1 AND lv_hsame = abap_true.
      IF lv_ht IS INITIAL.
        lv_ht = `PDF,JPG,JPEG,PNG`.
      ENDIF.
      REPLACE ALL OCCURRENCES OF `,` IN lv_ht WITH `, `.
      io_parent->message_strip(
        text     = |{ lv_ht } · up to { lv_hm } MB|
        type     = 'Information'
        showicon = abap_true
        class    = 'sapUiSmallMarginBottom' ).
      mv_att_hint_hide = abap_true.
    ENDIF.

    LOOP AT is_step-fields INTO DATA(ls_fx).
      IF zcl_rak_journey_util=>row_key( ls_fx ) IS NOT INITIAL AND mo_e->mo_rules->is_hidden( ls_fx ) = abap_false.
        lv_flex = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    lo_target = io_parent.

    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_render_start( io_ctx = mo_e io_view = io_parent ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    DATA(lv_jid) = CONV zcl_rak_cj_lay=>ty_key( mo_e->ms_config-journey_id ).
    DATA(lv_sid) = CONV zcl_rak_cj_lay=>ty_key( is_step-id ).

    IF zcl_rak_cj_lay=>get_instance( )->has_layout( iv_journey = lv_jid
                                                    iv_step    = lv_sid ) = abap_true.

      render_block_laid_out( io_parent  = io_parent
                             iv_journey = lv_jid
                             iv_step    = lv_sid
                             iv_block   = space
                             it_fields  = is_step-fields ).

      IF mo_e->mo_logic IS BOUND.
        TRY.
            mo_e->mo_logic->on_render_end( io_ctx = mo_e io_view = io_parent ).
          CATCH cx_root INTO DATA(lx_lay).
            mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
              text = |on_render_end failed: { lx_lay->get_text( ) }| ) ).
        ENDTRY.
      ENDIF.

      RETURN.

    ENDIF.

    DATA(lv_auto_result) = abap_false.
    IF mo_e->mv_step = lines( mo_e->ms_config-steps ) - 1
       AND journey_done( ) = abap_true.
      READ TABLE is_step-fields TRANSPORTING NO FIELDS WITH KEY type = 'RESULT'.
      IF sy-subrc <> 0.
        lv_auto_result = abap_true.
        render_result( io_parent = io_parent
                       is_field  = VALUE #( name = '' type = 'RESULT' ) ).
      ENDIF.
    ENDIF.

    LOOP AT is_step-fields INTO DATA(ls_f).
      DATA(lv_ix) = sy-tabix.
      IF lv_ix <= lv_taken.
        CONTINUE.
      ENDIF.
      IF line_exists( lt_used[ table_line = lv_ix ] ).
        CONTINUE.
      ENDIF.
      IF mo_e->mo_rules->is_hidden( ls_f ) = abap_true.
        CONTINUE.
      ENDIF.

      IF lv_auto_result = abap_true
         AND ( ls_f-type = 'DISPLAY' OR ls_f-type = 'READONLY' ).
        CONTINUE.
      ENDIF.

      IF ls_f-section <> lv_section.
        CLEAR lo_form.
        CLEAR lv_group.
        IF ls_f-section IS NOT INITIAL.
          lo_target = io_parent->panel( headertext = zcl_rak_journey_util=>esc( ls_f-section )
                                        expandable = abap_true
                                        expanded   = abap_true
                                        class      = mo_e->mo_css->cls( 'CARD' ) ).
        ELSE.
          lo_target = io_parent.
        ENDIF.
        lv_section = ls_f-section.
      ENDIF.

      IF zcl_rak_journey_util=>is_block( ls_f-type ) = abap_true.
        CLEAR lo_form.

        IF to_upper( ls_f-type ) = 'UPLOAD' AND is_step-columns BETWEEN 2 AND 4.

*         Uploads pair up by SECTION now, not by being neighbours.
*
*         The old scan walked forward and stopped at the FIRST field that was not
*         an upload, so two uploads with anything at all between them each drew
*         full width and COLUMNS on the step appeared to do nothing. On E142 that
*         is CV Copy and Attested Certificate with Degree sitting between them -
*         nothing an author could see explained it, and the only fix was to
*         reorder SEQNR until the two happened to be adjacent.
*
*         Now it collects up to COLUMNS uploads from anywhere in the SAME section
*         and draws them as one row where the first of them sits. The fields it
*         skipped over are drawn afterwards in their own order, which is why
*         LT_USED exists: LV_TAKEN can only skip a contiguous run.
*
*         The section boundary is still hard. A section emits a heading, so
*         gathering an upload from the next one would file it under the wrong
*         title - which is a worse bug than a full-width control.
          DATA lt_upix TYPE STANDARD TABLE OF i WITH EMPTY KEY.
          CLEAR lt_upix.
          APPEND lv_ix TO lt_upix.

          DATA(lv_scan) = lv_ix + 1.
          WHILE lv_scan <= lines( is_step-fields )
                AND lines( lt_upix ) < is_step-columns.
            DATA(ls_scan) = is_step-fields[ lv_scan ].
            IF ls_scan-section <> ls_f-section.
              EXIT.
            ENDIF.
            IF to_upper( ls_scan-type ) = 'UPLOAD'
               AND mo_e->mo_rules->is_hidden( ls_scan ) = abap_false.
              APPEND lv_scan TO lt_upix.
            ENDIF.
            lv_scan = lv_scan + 1.
          ENDWHILE.

          IF lines( lt_upix ) > 1.
            DATA(lo_uprow) = lo_target->hbox( class          = 'rakRow rakUpRow'
                                              alignitems     = 'Start'
                                              justifycontent = 'Start' ).
            LOOP AT lt_upix INTO DATA(lv_upi).
              DATA(ls_upr) = is_step-fields[ lv_upi ].
              DATA(lo_upcell) = lo_uprow->vbox( class = 'rakCell rakUpCell' ).
              before_field( io_view = lo_upcell is_field = ls_upr ).
              render_block( io_parent = lo_upcell is_field = ls_upr ).
              after_field( io_view = lo_upcell is_field = ls_upr ).
*             Every one EXCEPT the field the outer loop is currently on, which it
*             is about to leave by itself.
              IF lv_upi <> lv_ix.
                APPEND lv_upi TO lt_used.
              ENDIF.
            ENDLOOP.
            CONTINUE.
          ENDIF.
        ENDIF.

        before_field( io_view = lo_target is_field = ls_f ).
        render_block( io_parent = lo_target is_field = ls_f ).
        after_field( io_view = lo_target is_field = ls_f ).
        CONTINUE.
      ENDIF.

      IF lo_form IS INITIAL.
        IF lv_flex = abap_true.
          lo_form = lo_target->vbox(
            class = COND string( WHEN ls_f-section IS INITIAL
                                 THEN 'rakCard rakFStep' ELSE 'rakFStep' ) ).
        ELSE.
          DATA(lv_cols) = COND string( WHEN is_step-columns BETWEEN 2 AND 4
                                       THEN |{ is_step-columns }| ELSE '1' ).
          DATA(lv_lblspan) = '12'.
          lo_form = lo_target->simple_form(
            editable        = abap_true
            layout          = 'ResponsiveGridLayout'
            columnsxl       = lv_cols
            columnsl        = lv_cols
            columnsm        = COND string( WHEN lv_cols = '1' THEN '1' ELSE '2' )
            labelspanxl     = lv_lblspan
            labelspanl      = lv_lblspan
            labelspanm      = lv_lblspan
            labelspans      = '12'
            adjustlabelspan = abap_false
            class           = COND string( WHEN ls_f-section IS INITIAL THEN 'rakCard' ELSE '' ) )->content( ns = 'form' ).
        ENDIF.
      ENDIF.

      DATA(lv_fkey) = zcl_rak_journey_util=>row_key( ls_f ).
      IF ls_f-group IS NOT INITIAL AND ls_f-group <> lv_group AND lv_fkey NP 'ROW:*'.
        IF lv_flex = abap_true.
          lo_form->title( text = zcl_rak_journey_util=>esc( ls_f-group ) class = |{ mo_e->mo_css->cls( 'SECTION' ) } rakBlkTitle| ).
        ELSE.
          lo_form->title( ns = 'core' text = zcl_rak_journey_util=>esc( ls_f-group ) ).
        ENDIF.
        lv_group = ls_f-group.
      ENDIF.

      DATA(lv_nx)  = lv_ix.
      DATA(lv_cnt) = 1.
      WHILE lv_nx < lines( is_step-fields ).
        DATA(lv_pk) = lv_nx + 1.
        DATA(ls_nf) = is_step-fields[ lv_pk ].
        DATA(lv_nk) = zcl_rak_journey_util=>row_key( ls_nf ).
        IF lv_nk <> '+' AND ( lv_nk IS INITIAL OR lv_nk <> lv_fkey ).
          EXIT.
        ENDIF.
        IF ls_nf-section <> lv_section OR zcl_rak_journey_util=>is_block( ls_nf-type ) = abap_true.
          EXIT.
        ENDIF.
        lv_nx = lv_nx + 1.
        IF mo_e->mo_rules->is_hidden( ls_nf ) = abap_false.
          lv_cnt = lv_cnt + 1.
        ENDIF.
      ENDWHILE.
      lv_taken = lv_nx.

      IF lv_cnt <= 1.
        before_field( io_view = lo_form is_field = ls_f ).
        render_one( io_form = lo_form is_field = ls_f ).
        after_field( io_view = lo_form is_field = ls_f ).
        CONTINUE.
      ENDIF.

      DATA(lv_eqc) = ``.
      IF is_step-columns BETWEEN 2 AND 4 AND mo_e->zif_rak_journey~get_val( 'ROW_FREE' ) <> 'X'.
        lv_eqc = |rakRowEq rakRowC{ is_step-columns }|.
      ENDIF.
      DATA(lo_row) = lo_form->hbox( class          = condense( |rakRow { lv_eqc }| )
                                    alignitems     = 'End'
                                    justifycontent = 'Start' ).
      LOOP AT is_step-fields INTO DATA(ls_rf) FROM lv_ix TO lv_nx.
        IF mo_e->mo_rules->is_hidden( ls_rf ) = abap_true.
          CONTINUE.
        ENDIF.
*       rakWide is the unlaid path's half of WIDE_FIELD( ): this row is a
*       flex box with rakRowCn fixing every child to a fraction of it, so a
*       composite needs the class to claim the whole line back.
        lo_cell = lo_row->vbox( class = COND string(
                                  WHEN wide_field( ls_rf ) = abap_true
                                  THEN 'rakCell rakWide' ELSE 'rakCell' ) ).
        mv_in_cell = xsdbool( lv_eqc IS NOT INITIAL ).
        before_field( io_view = lo_cell is_field = ls_rf ).
        render_one( io_form = lo_cell is_field = ls_rf ).
        after_field( io_view = lo_cell is_field = ls_rf ).
        CLEAR mv_in_cell.
      ENDLOOP.
    ENDLOOP.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_render_end( io_ctx = mo_e io_view = io_parent ).
        CATCH cx_root INTO DATA(lx_re).
          mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
            text = |on_render_end failed: { lx_re->get_text( ) }| ) ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD render_tabs.
*   Resolved once, not once per tab: NAV_LOCKED( ) walks every step's fields.
    DATA(lv_lock) = mo_e->nav_locked( ).
    DATA(lo_strip) = io_parent->hbox( class = 'sapUiSmallMarginBegin sapUiSmallMarginTop' ).
    DATA lv_i TYPE i.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
*     Numbered, because a tab strip says nothing about order and TABS journeys are
*     still meant to be worked through front to back. The current tab is the only
*     one carrying the accent colour, so the number is what tells the citizen how
*     far along the strip they are.
*     Every tab but the current one goes dead once NAV_LOCKED( ) - the same
*     rule the wizard's Back button and stepper dots follow. A TABS journey has
*     no Back button at all (RENDER_FOOTER( ) draws it only on the linear
*     path), so this strip IS the way back and would otherwise be the one route
*     left open after payment.
      lo_strip->button(
        text    = zcl_rak_journey_util=>esc( |{ lv_i + 1 }. { ls_step-title }| )
        icon    = ls_step-icon
        type    = COND string( WHEN lv_i = mo_e->mv_step THEN mo_e->ms_config-theme-accent_type ELSE 'Transparent' )
        tooltip = zcl_rak_journey_util=>esc( ls_step-title )
        enabled = xsdbool( lv_i = mo_e->mv_step OR lv_lock = abap_false )
        press   = mo_e->mo_client->_event( |TAB{ lv_i }| ) ).
      lv_i = lv_i + 1.
    ENDLOOP.
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_cur) INDEX mo_e->mv_step + 1.
    render_step( io_parent = io_parent is_step = ls_cur iv_index = mo_e->mv_step ).
    render_footer( io_parent = io_parent iv_linear = abap_false ).
  ENDMETHOD.


  METHOD render_uploader.
    DATA(lv_ks) = to_upper( iv_key ).
    REPLACE ALL OCCURRENCES OF REGEX '[^A-Z0-9]' IN lv_ks WITH ``.
    DATA(lv_f)     = to_upper( iv_field ) && to_upper( iv_scope )
                     && COND string( WHEN lv_ks IS NOT INITIAL THEN |_{ lv_ks }| ).
    DATA(lv_mb)    = mo_e->att_max_mb( iv_maxmb ).
    DATA(lv_bytes) = lv_mb * 1048576.

    io_box->input( value = mo_e->mo_client->_bind_edit( mo_e->mv_att_name ) class = |rakHide rakAttName_{ lv_f }| ).
    io_box->input( value = mo_e->mo_client->_bind_edit( mo_e->mv_att_b64 )  class = |rakHide rakAttB64_{ lv_f }| ).
    io_box->button( text  = 'go'
                    class = |rakHide rakAttGo_{ lv_f }|
                    press = mo_e->mo_client->_event(
                              |ATTSAVE_{ to_upper( iv_field ) }| &&
                              COND string( WHEN iv_key IS NOT INITIAL THEN |~{ iv_key }| ) ) ).

    DATA(lv_js) =
      `var f=this.files[0];if(!f)return;` &&
      `if(f.size>` && |{ lv_bytes }| && `){alert('Maximum file size is ` && |{ lv_mb }| &&
      ` MB');this.value='';return;}` &&
      `var r=new FileReader();var me=this;` &&
      `r.onload=function(){` &&
      `var g=function(c){var el=document.querySelector(c);return sap.ui.getCore().byId(el.id);};` &&
      `g('.rakAttName_` && lv_f && `').setValue(f.name);` &&
      `g('.rakAttB64_` && lv_f && `').setValue(r.result);` &&
      `g('.rakAttGo_` && lv_f && `').firePress();me.value='';};` &&
      `r.readAsDataURL(f);`.
    DATA(lv_pick) = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-choose_file iv_default = 'Choose file' ).
    DATA(lv_html) =
      `<div class="rakUp"><label class="rakUpLbl"><span>` && lv_pick && `</span>` &&
      `<input type="file" accept="` &&
      COND string( WHEN iv_types IS NOT INITIAL
                   THEN `.` && replace( val = iv_types sub = `,` with = `,.` occ = 0 )
                   ELSE `.pdf,.jpg,.jpeg,.png` ) &&
      `" onchange="` && lv_js && `"/></label></div>`.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    io_box->html( content = lv_html sanitizecontent = abap_false ).

    DATA(lv_hint) = to_upper( COND string( WHEN iv_types IS NOT INITIAL
                                           THEN iv_types ELSE `pdf,jpg,jpeg,png` ) ).
    REPLACE ALL OCCURRENCES OF `,` IN lv_hint WITH `, `.
*   Silent when RENDER_STEP( ) has already said it once at the top of the step.
*   A popup's uploaders keep their own hint: the strip is on the step behind the
*   dialog, where the citizen cannot read it.
    IF mv_att_hint_hide = abap_false OR iv_scope IS NOT INITIAL.
      io_box->text( text = |{ lv_hint } · up to { lv_mb } MB| class = 'rakAttHint' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_wizard.
    io_parent->html( content = mo_e->mo_css->build_stepper( ) sanitizecontent = abap_false ).
    render_goto( io_parent ).
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_step) INDEX mo_e->mv_step + 1.
    render_step( io_parent = io_parent is_step = ls_step iv_index = mo_e->mv_step ).
    render_footer( io_parent = io_parent iv_linear = abap_true ).
  ENDMETHOD.


  METHOD render_goto.
*   One hidden button per step the citizen has already passed, carrying the class
*   the stepper markup fires. Raw HTML cannot raise an ABAP event, so this is the
*   same hidden-control bridge RENDER_UPLOADER uses; rakHide keeps them in the DOM
*   and scriptable rather than display:none, which would not be.
*
*   Only steps BEFORE the current one, matching what BUILD_STEPPER makes
*   clickable. A button with no markup pointing at it is harmless, but one for a
*   step ahead would be a way round the validation on NEXT.
*   And none at all once NAV_LOCKED( ) - after payment there is no step behind
*   the citizen that they may edit. BUILD_STEPPER( ) stops marking the dots
*   clickable at the same time, so nothing is left pointing at a button that
*   is not there.
    IF mo_e->nav_locked( ) = abap_true.
      RETURN.
    ENDIF.

    DATA lv_i TYPE i.
    WHILE lv_i < mo_e->mv_step.
      io_parent->button( text  = 'go'
                         class = |rakHide rakGoto_{ lv_i }|
                         press = mo_e->mo_client->_event( |GOTO_{ lv_i }| ) ).
      lv_i = lv_i + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD render_wizard_left.
    DATA(lo_split) = io_parent->hbox( alignitems = 'Stretch' class = 'rakSplit' ).
    DATA(lo_rail)  = lo_split->vbox( width = '15rem' class = 'rakRail' ).
    lo_rail->html( content = mo_e->mo_css->build_stepper( abap_true ) sanitizecontent = abap_false ).
    render_goto( lo_rail ).
    DATA(lo_main)  = lo_split->vbox( class = 'rakMain' ).
    READ TABLE mo_e->ms_config-steps INTO DATA(ls_wl) INDEX mo_e->mv_step + 1.
    render_step( io_parent = lo_main is_step = ls_wl iv_index = mo_e->mv_step ).
    render_footer( io_parent = lo_main iv_linear = abap_true ).
  ENDMETHOD.


  METHOD long_text.
*   Two routes, in this order:
*
*     TEXT: on DEFAULT_VAL          explicit config, wins outright
*     ZCL_RAK_TEXT=>LONG_TEXTS( )   journey + field, bilingual, in git
*     ZLABEL                        whatever fits in 150 characters
*
*   The second is what a truncated legal declaration needs. The first is
*   for text a consultant should be able to change without a transport.
    rv_text = is_field-label.

    IF is_field-default NP 'TEXT:*'.
*     No TEXT: instruction - ask the text service whether it holds a
*     paragraph for this journey and field. Returns the label unchanged
*     when it does not, so nothing configured before this behaves
*     differently.
      rv_text = zcl_rak_text=>long( iv_journey = mo_e->ms_config-journey_id
                                    iv_field   = is_field-name
                                    iv_default = is_field-label ).
      subst_fields( CHANGING cv_text = rv_text ).
      RETURN.
    ENDIF.

    DATA(lv_body) = substring( val = is_field-default off = 5 ).
    CONDENSE lv_body.
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_body(1) <> '@'.
*     A literal paragraph. Language-neutral: DEFAULT_VAL has no _AR twin,
*     so an Arabic reader sees whatever was configured here. Use the @ form
*     when that matters.
      rv_text = lv_body.
      subst_fields( CHANGING cv_text = rv_text ).
      RETURN.
    ENDIF.

*   TEXT:@nnn - a message number in ZRAK_T_CJ_TXT, which does have TEXT_EN
*   and TEXT_AR and is picked by sy-langu. The label stays as the fallback,
*   so a number that resolves to nothing shows the truncated text rather
*   than an empty consent statement with a tick box beside it.
    DATA(lv_no) = substring( val = lv_body off = 1 ).
    CONDENSE lv_no.
    TRY.
        rv_text = zcl_rak_text=>get( iv_no      = CONV symsgno( lv_no )
                                     iv_default = is_field-label
                                     iv_journey = mo_e->ms_config-journey_id ).
      CATCH cx_root.
        rv_text = is_field-label.
    ENDTRY.
    subst_fields( CHANGING cv_text = rv_text ).
  ENDMETHOD.


  METHOD subst_fields.
    IF cv_text NS '{'.
      RETURN.
    ENDIF.

    DATA lt_match TYPE match_result_tab.
    FIND ALL OCCURRENCES OF REGEX '\{([A-Za-z_][A-Za-z0-9_]*)\}' IN cv_text
         RESULTS lt_match.

*   Backwards, so an earlier replacement's length change never shifts the
*   offset a later one still needs. FIND ALL OCCURRENCES returns matches
*   left to right, so working from the last index down to the first walks
*   the string right to left.
    DATA(lv_ix) = lines( lt_match ).
    WHILE lv_ix > 0.
      READ TABLE lt_match INTO DATA(ls_match) INDEX lv_ix.
      DATA(lv_field) = to_upper( substring( val = cv_text
                                            off = ls_match-submatches[ 1 ]-offset
                                            len = ls_match-submatches[ 1 ]-length ) ).
      REPLACE SECTION OFFSET ls_match-offset LENGTH ls_match-length OF cv_text
              WITH mo_e->zif_rak_journey~get_val( lv_field ).
      lv_ix = lv_ix - 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD col_header.
*   A TABLE column header comes from the KEY:Label:TYPE spec in DEFAULT_VAL,
*   and DEFAULT_VAL has no _AR twin - so a literal header is frozen in whichever
*   language it was typed in and shows its English to an Arabic reader. That is
*   what made every Track Complaint / Track Suggestion details table render its
*   headers in English on an Arabic run.
*
*   @nnn is the way out, and it is the SAME mechanism LONG_TEXT( ) already uses
*   for a bilingual paragraph: a message number in ZRAK_T_CJ_TXT, which does
*   have TEXT_EN and TEXT_AR and is picked by SY-LANGU. A spec column reads
*   STATUS:@142:TEXT instead of STATUS:Status:TEXT.
*
*   OTR:<alias> deliberately is NOT accepted here, even though PICK( ) takes it
*   everywhere else: the spec splits on ':', so an alias would be torn in half
*   by the parser before it ever reached this method.
*
*   Anything not starting with @ is returned untouched, so every header
*   configured today keeps rendering exactly as it does now.
    rv = iv_raw.
    IF strlen( rv ) < 2 OR rv(1) <> '@'.
      RETURN.
    ENDIF.

    DATA(lv_no) = substring( val = rv off = 1 ).
    CONDENSE lv_no.
    TRY.
        rv = zcl_rak_text=>get( iv_no      = CONV symsgno( lv_no )
                                iv_default = iv_raw
                                iv_journey = mo_e->ms_config-journey_id ).
      CATCH cx_root.
*       An unusable number is not a reason to draw a blank header - show the
*       raw token so it is obvious in testing which column is misconfigured.
        rv = iv_raw.
    ENDTRY.
  ENDMETHOD.


  METHOD send_view.
*   WHY THIS EXISTS: VIEW_DISPLAY( ) replaces the whole XML view, so UI5 destroys
*   and rebuilds the page. On a step that is only reacting to a dropdown that is
*   a full repaint for no visual difference - the flicker, plus the lost scroll
*   position and focus that come with it. VIEW_MODEL_UPDATE( ) instead sets
*   CHECK_UPDATE_MODEL, which refreshes the bound values without touching the
*   control tree, so anything ON_CHANGE( ) wrote server-side still reaches the
*   screen. The side effects are not skipped - only the repaint is.
*
*   THE TEST IS THE MARKUP ITSELF, not a list of things that might have moved.
*   If the stringified view is byte-identical to the one already on screen, a
*   repaint would produce an identical DOM by definition, so there is nothing to
*   lose by skipping it. Anything that genuinely changes the page - a rule
*   flipping VISIBLE or REQUIRED, a dependent dropdown's options, a message
*   strip, a step change - changes the markup and takes the full path.
*
*   Two guards keep the quiet path narrow. MV_VIEW_SIG must already hold
*   something, so the first render of a session is always a real view; and
*   MV_QUIET_EVT is set only for a CHANGE_ round trip, so navigation, submit and
*   popup events always repaint even when the markup happens to match.
    DATA lv_sig TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = 'SHA1'
            if_data       = iv_xml
          IMPORTING
            ef_hashstring = lv_sig ).
      CATCH cx_root.
*       No hash means no safe comparison, so take the path that is always
*       correct rather than the one that is usually faster.
        CLEAR lv_sig.
    ENDTRY.

    IF lv_sig IS NOT INITIAL
       AND lv_sig = mo_e->mv_view_sig
       AND mo_e->mv_quiet_evt = abap_true.
      mo_e->mo_client->view_model_update( ).
      RETURN.
    ENDIF.

*   ---- KEEP THE SCROLL POSITION ACROSS THE REPAINT -------------------
*   THE HASH TEST CANNOT FIX THE PARCEL SELECTOR, and three attempts at
*   it establish why. Binding the tick box was necessary - the state is
*   no longer written into the XML - but it is not sufficient, because
*   selecting a parcel genuinely changes the page: M012's ON_CHANGE calls
*   SYNC_GRID( ), which SET_GRID_DATA( )s a new row into RAKPARCELS. The
*   markup differs, the hash cannot match, and the full repaint is
*   CORRECT. There is no version of the quiet path that helps.
*
*   SO THE REPAINT STAYS AND THE SYMPTOM GOES. What the citizen calls
*   flicker is VIEW_DISPLAY( ) tearing the control tree down and
*   rebuilding it, which drops the scroll position - the page jumps to the
*   top and the card they just ticked is off screen. That reads as "the
*   selection vanished" even when it landed perfectly, which is exactly
*   how it has been reported each time.
*
*   ON THE FULL PATH ONLY. The quiet path above does not rebuild anything,
*   so it has no scroll to restore and returns before this.
*
*   FOLLOW_UP_ACTION IS ADDITIVE - Z2UI5_CL_CORE_CLIENT does
*   `INSERT val INTO TABLE ... custom_js`, a table - so this cannot
*   displace the parcel map's own snippet. That was worth checking rather
*   than assuming: if it had been single-valued, adding one here would
*   have silently broken the map.
*
*   PLAIN '...' LITERALS, NOT A STRING TEMPLATE. Every { and } would
*   otherwise have to be escaped \{ \} because ABAP reads them as an
*   embedded expression, and a snippet of JavaScript is mostly braces.
*   And NOT ONE SINGLE QUOTE in the JavaScript: _runCustomJs splits on
*   it and calls a frontend action with the pieces instead of running the
*   code, so every string here is double-quoted.
*
*   AN EXPRESSION, because the frontend evaluates it as
*   Function( "return " + snippet )( ) - hence the IIFE - and wrapped in
*   TRY/CATCH throughout so a browser that refuses sessionStorage (a
*   private window, blocked site data) degrades to today's behaviour
*   rather than throwing on every render.
    DATA(lv_scroll) =
      '(function()' && '{' && 'try' && '{' &&
      'var K="rakScrollTop";' &&
      'var g=function()' && '{' && 'return document.scrollingElement||document.documentElement||document.body;' && '}' && ';' &&
      'if(!window.rakScrollHook)' && '{' &&
      'window.rakScrollHook=1;' &&
      'window.addEventListener("scroll",function()' && '{' &&
      'try' && '{' && 'sessionStorage.setItem(K,String(g().scrollTop));' && '}' && 'catch(e)' && '{' && '}' &&
      '}' && ',true);' &&
      '}' &&
      'setTimeout(function()' && '{' &&
      'try' && '{' && 'var v=sessionStorage.getItem(K);' &&
      'if(v)' && '{' && 'g().scrollTop=parseInt(v,10);' && '}' &&
      '}' && 'catch(e)' && '{' && '}' &&
      '}' && ',0);' &&
      'return 1;' &&
      '}' && 'catch(e)' && '{' && 'return 0;' && '}' && '}' && ')()'.

    TRY.
        mo_e->mo_client->follow_up_action( lv_scroll ).
      CATCH cx_root ##NO_HANDLER.
*       A diagnostic convenience must never be the reason a page fails to
*       render. If the client cannot take another follow-up action, the
*       view still goes out below.
    ENDTRY.

    mo_e->mv_view_sig = lv_sig.
    mo_e->mo_client->view_display( iv_xml ).
  ENDMETHOD.


  METHOD req_label.
    DATA(lv_req) = mo_e->mo_rules->is_required( is_field ).
*   In a FLOW cell the label belongs to the cell, not to the row holding the
*   control and its buttons - otherwise it lines up beside the input and that
*   one field stops matching every other field on the step.
    DATA lo_lbl TYPE REF TO z2ui5_cl_xml_view.
    lo_lbl = io_form.
    IF mo_lbl_tgt IS BOUND.
      lo_lbl = mo_lbl_tgt.
    ENDIF.
*   REQUIRED must be set as the sap.m.Label control property, not faked with a
*   CSS class - that is what actually makes UI5's own renderer draw the marker
*   (sapMLabelRequired). The CLASS-only 'rakReq'/.rakReq::after approach this
*   used to rely on never reliably reached the DOM; ZCL_CJ_DEMO_P001 (a plain,
*   non-CJS abap2UI5 screen) proves the native REQUIRED property is what works.
    lo_lbl->label( text     = zcl_rak_journey_util=>esc( is_field-label )
                    class    = 'sapUiFormLabelNoColon'
                    required = lv_req ).
  ENDMETHOD.


  METHOD status_state.

    DATA(lv_v) = to_upper( condense( iv_value ) ).
    IF lv_v IS INITIAL.
      rv_st = 'None'.
      RETURN.
    ENDIF.

    IF iv_map IS NOT INITIAL AND iv_map CS '='.
      SPLIT iv_map AT '|' INTO TABLE DATA(lt_m).
      LOOP AT lt_m INTO DATA(lv_m).
        SPLIT lv_m AT '=' INTO DATA(lv_k) DATA(lv_s).
        lv_k = to_upper( condense( lv_k ) ).
        lv_s = condense( lv_s ).
        IF lv_k = '*' OR lv_k = lv_v.
          rv_st = lv_s.
          IF lv_k = lv_v.
            RETURN.
          ENDIF.
        ENDIF.
      ENDLOOP.
      IF rv_st IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    DATA lt_ok  TYPE zif_rak_journey=>tt_string.
    DATA lt_bad TYPE zif_rak_journey=>tt_string.
    DATA lt_wrn TYPE zif_rak_journey=>tt_string.
    lt_ok  = VALUE #( ( `CLOSED` ) ( `COMPLETED` ) ( `APPROVED` ) ( `DONE` ) ( `RESOLVED` )
                      ( `PAID` ) ( `ACCEPTED` ) ( `مغلق` ) ( `منجز` ) ( `مقبول` ) ( `تم` ) ).
    lt_bad = VALUE #( ( `REJECTED` ) ( `CANCELLED` ) ( `CANCELED` ) ( `FAILED` ) ( `EXPIRED` )
                      ( `مرفوض` ) ( `ملغي` ) ( `منتهي` ) ).
    lt_wrn = VALUE #( ( `OPEN` ) ( `IN PROGRESS` ) ( `INPROGRESS` ) ( `PENDING` ) ( `SUBMITTED` )
                      ( `UNDER REVIEW` ) ( `WAITING` ) ( `NEW` ) ( `مفتوح` ) ( `قيد المعالجة` )
                      ( `قيد التنفيذ` ) ( `معلق` ) ( `جديد` ) ).

    IF line_exists( lt_ok[ table_line = lv_v ] ).
      rv_st = 'Success'.
      RETURN.
    ENDIF.
    IF line_exists( lt_bad[ table_line = lv_v ] ).
      rv_st = 'Error'.
      RETURN.
    ENDIF.
    IF line_exists( lt_wrn[ table_line = lv_v ] ).
      rv_st = 'Warning'.
      RETURN.
    ENDIF.
    rv_st = 'Information'.

  ENDMETHOD.
ENDCLASS.
