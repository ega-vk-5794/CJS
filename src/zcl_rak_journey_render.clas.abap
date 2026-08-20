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
    METHODS req_label   IMPORTING io_form  TYPE REF TO z2ui5_cl_xml_view
                                  is_field TYPE zif_rak_journey=>ty_field.
    METHODS before_field IMPORTING io_view  TYPE REF TO z2ui5_cl_xml_view
                                   is_field TYPE zif_rak_journey=>ty_field.
    METHODS after_field  IMPORTING io_view  TYPE REF TO z2ui5_cl_xml_view
                                   is_field TYPE zif_rak_journey=>ty_field.
    METHODS f4_opts    IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS bind_of IMPORTING iv_name TYPE string RETURNING VALUE(rv_bind) TYPE string.
    METHODS bind_state IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE string.
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
    DATA mv_in_cell TYPE abap_bool.
    METHODS pay_field IMPORTING iv_index       TYPE i
                      RETURNING VALUE(rv_name) TYPE string.
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
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
    IF sy-subrc = 0.
      rv_bind = mo_e->mo_client->_bind_edit( <f> ).
    ENDIF.
  ENDMETHOD.


  METHOD bind_state.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
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
      mo_e->mo_client->view_display( view->stringify( ) ).
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
      mo_e->mo_client->view_display( view->stringify( ) ).
      render_popup( ).
      RETURN.
    ENDIF.

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

    mo_e->mo_client->view_display( view->stringify( ) ).

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
    io_form->label(
      text  = zcl_rak_journey_util=>esc( COND #( WHEN is_field-attach_label IS NOT INITIAL
                           THEN is_field-attach_label ELSE |{ is_field-label } - attachment| ) )
      class = COND string( WHEN mo_e->mo_rules->is_required( is_field ) = abap_true
                           THEN 'rakReq sapUiFormLabelNoColon'
                           ELSE 'sapUiFormLabelNoColon' ) ).
    DATA(lo_box) = io_form->vbox( ).

    DATA(lv_count) = render_chips( io_box = lo_box iv_field = is_field-name ).

    IF is_field-attach_multi = abap_true OR lv_count = 0.
      render_uploader( io_box   = lo_box
                       iv_field = is_field-name
                       iv_types = is_field-attach_types
                       iv_maxmb = is_field-attach_maxmb ).
    ENDIF.
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
        DATA(lo_idt) = lo_box->combobox( selectedkey = bind_of( |{ is_field-name }_IDTYPE| ) width = '12rem' ).
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
             OR ls_rqf-type = 'PAYFEE' OR ls_rqf-type = 'REQPANEL'.
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
            SPLIT lv_csraw AT ':' INTO DATA(lv_csn) DATA(lv_csh).
            lv_csn = to_upper( condense( lv_csn ) ).
            lv_csh = condense( lv_csh ).
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

    DATA(lo_grid) = io_parent->grid( default_span = 'XL12 L12 M12 S12'
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


  METHOD render_cell.

    DATA(lv_align) = COND string( WHEN is_cell-attr-align = zcl_rak_cj_lay=>c_align-center THEN 'Center'
                                  WHEN is_cell-attr-align = zcl_rak_cj_lay=>c_align-end    THEN 'End'
                                  ELSE 'Start' ).

    DATA(lv_width) = COND string( WHEN is_cell-attr-width IS NOT INITIAL
                                  THEN CONV string( is_cell-attr-width )
                                  ELSE '100%' ).

    DATA(lo_cell) = io_parent->vbox( class      = 'rakCell'
                                     width      = lv_width
                                     alignitems = lv_align ).

    lo_cell->layout_data( )->grid_data(
      span      = zcl_rak_cj_lay=>span_str( is_cell-attr-col_span )
      linebreak = COND string( WHEN iv_break = abap_true THEN 'true' ELSE 'false' ) ).

    mv_in_cell = abap_true.
    before_field( io_view = lo_cell is_field = is_field ).

    IF zcl_rak_journey_util=>is_block( is_field-type ) = abap_true.
      render_block( io_parent = lo_cell is_field = is_field ).
    ELSE.
      render_one( io_form = lo_cell is_field = is_field ).
    ENDIF.

    after_field( io_view = lo_cell is_field = is_field ).
    CLEAR mv_in_cell.

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

    lo_card->button( text    = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-fb_send iv_default = 'Send feedback' )
                     type    = 'Emphasized'
                     icon    = 'sap-icon://feedback'
                     class   = 'sapUiSmallMarginTop'
                     enabled = xsdbool( mo_e->mv_fb_rating IS NOT INITIAL )
                     press   = mo_e->btn_evt( 'FBSEND' ) ).
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
        lv_paid = abap_true.
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

    IF iv_linear = abap_true AND mo_e->mv_step > 0.
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
      lo_r->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-save_draft iv_default = 'Save as Draft' )
                    icon  = 'sap-icon://save'
                    type  = 'Transparent'
                    class = 'sapUiSmallMarginBegin'
                    press = mo_e->btn_evt( 'SAVE' ) ).
      lo_r->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-delete iv_default = 'Delete' )
                    icon  = 'sap-icon://delete'
                    type  = 'Transparent'
                    class = 'sapUiSmallMarginBegin'
                    press = mo_e->btn_evt( 'ASKDEL' ) ).
    ENDIF.

    DATA(lv_sub) = COND string(
      WHEN sy-langu = 'A' AND mo_e->ms_config-theme-subtitle_ar IS NOT INITIAL
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

    DATA(lv_bind) = bind_of( is_field-name ).
    DATA(lv_vs)   = bind_state( |{ is_field-name }_VS| ).
    DATA(lv_vst)  = bind_state( |{ is_field-name }_VST| ).
    DATA(lv_edit) = xsdbool( mo_e->mo_rules->is_readonly( is_field ) = abap_false ).
    DATA(lv_min)  = COND string( WHEN is_field-validation-min_val IS NOT INITIAL THEN is_field-validation-min_val ELSE '0' ).
    DATA(lv_max)  = COND string( WHEN is_field-validation-max_val IS NOT INITIAL THEN is_field-validation-max_val ELSE '100' ).
    DATA(lv_w)    = zcl_rak_journey_util=>ctrl_width( is_field ).
    IF mv_in_cell = abap_true.
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
      WHEN 'SELECT'.
        req_label( io_form = io_form is_field = is_field ).
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
        mo_e->val_set( iv_name = |{ is_field-name }_IX| iv_value = |{ lv_rsel }| ).

        DATA(lo_rg) = io_form->radio_button_group( selectedindex = bind_of( |{ is_field-name }_IX| )
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
                                       expanded   = bind_of( |{ is_field-name }_EXP| ) ).
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
                              valueformat    = 'yyyy-MM-dd'
                              displayformat  = 'dd/MM/yyyy' ).

      WHEN 'TIME'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->time_picker( value = lv_bind enabled = lv_edit valuestate = lv_vs valuestatetext = lv_vst width = lv_w ).

      WHEN 'DATETIME'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->date_time_picker( value = lv_bind enabled = lv_edit valuestate = lv_vs ).

      WHEN 'CHECKBOX'.
        DATA(lo_cbx) = io_form->hbox( alignitems = 'Start' width = '100%' ).
*       THE MARKER LEADS THE STATEMENT, unlike every other field, where
*       REQ_LABEL puts it after the label via .rakReq::after - which is what
*       sap.m.Label does for required and what the rest of the form should keep.
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
                          text     = zcl_rak_journey_util=>esc( is_field-label )
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
        io_form->input( class = mo_e->mo_css->cls( 'INPUT' ) value = lv_bind type = 'Number' placeholder = is_field-placeholder editable = lv_edit change = mo_e->opt_evt( is_field-name ) valuestate = lv_vs valuestatetext = lv_vst width = lv_w ).

      WHEN 'EMAIL'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( class = mo_e->mo_css->cls( 'INPUT' ) value = lv_bind type = 'Email' placeholder = is_field-placeholder editable = lv_edit change = mo_e->opt_evt( is_field-name ) valuestate = lv_vs valuestatetext = lv_vst width = lv_w ).

      WHEN 'PHONE'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( class = mo_e->mo_css->cls( 'INPUT' ) value = lv_bind type = 'Tel' placeholder = is_field-placeholder editable = lv_edit change = mo_e->opt_evt( is_field-name ) valuestate = lv_vs valuestatetext = lv_vst width = lv_w ).

      WHEN 'CURRENCY'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->input( value          = lv_bind
                        type           = 'Number'
                        placeholder    = COND string( WHEN is_field-placeholder IS NOT INITIAL THEN is_field-placeholder ELSE 'AED' )
                        editable       = lv_edit
                        change         = mo_e->opt_evt( is_field-name )
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
        io_form->input( value = lv_bind editable = abap_false width = lv_w class = mo_e->mo_css->cls( 'INPUT' ) ).

      WHEN 'DISPLAY'.
        req_label( io_form = io_form is_field = is_field ).
        io_form->text( text = lv_bind ).

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
          io_form->input( value          = lv_bind
                          placeholder    = is_field-placeholder
                          editable       = lv_edit
                          change         = mo_e->opt_evt( is_field-name )
                          valuestate     = lv_vs
                          valuestatetext = lv_vst
                          width          = lv_w ).
        ENDIF.
    ENDCASE.

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
    IF lv_done = abap_true.
      lv_col  = `#2e9e4f`.
      lv_head = COND string( WHEN lv_paid = abap_true
                             THEN `Payment received`
                             ELSE `Application submitted` ).
      lv_sub  = `We have everything we need. Keep the reference below for any follow-up.`
      .
    ELSE.
      lv_col  = `#e0a800`.
      lv_head = `Not submitted yet`.
      lv_sub  = `This application has not been submitted. Go back and complete the remaining steps.`.
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
    DATA lv_flex    TYPE abap_bool.

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
          DATA(lv_upn) = lv_ix.
          DATA(lv_upc) = 0.
          WHILE lv_upn <= lines( is_step-fields ).
            DATA(ls_upf) = is_step-fields[ lv_upn ].
            IF to_upper( ls_upf-type ) <> 'UPLOAD' OR ls_upf-section <> ls_f-section.
              EXIT.
            ENDIF.
            IF mo_e->mo_rules->is_hidden( ls_upf ) = abap_false.
              lv_upc = lv_upc + 1.
              IF lv_upc > is_step-columns.
                EXIT.
              ENDIF.
            ENDIF.
            lv_upn = lv_upn + 1.
          ENDWHILE.
          lv_upn = lv_upn - 1.

          IF lv_upn > lv_ix.
            lv_taken = lv_upn.
            DATA(lo_uprow) = lo_target->hbox( class          = 'rakRow rakUpRow'
                                              alignitems     = 'Start'
                                              justifycontent = 'Start' ).
            LOOP AT is_step-fields INTO DATA(ls_upr) FROM lv_ix TO lv_upn.
              IF mo_e->mo_rules->is_hidden( ls_upr ) = abap_true.
                CONTINUE.
              ENDIF.
              DATA(lo_upcell) = lo_uprow->vbox( class = 'rakCell rakUpCell' ).
              before_field( io_view = lo_upcell is_field = ls_upr ).
              render_block( io_parent = lo_upcell is_field = ls_upr ).
              after_field( io_view = lo_upcell is_field = ls_upr ).
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
        lo_cell = lo_row->vbox( class = 'rakCell' ).
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
    DATA(lo_strip) = io_parent->hbox( class = 'sapUiSmallMarginBegin sapUiSmallMarginTop' ).
    DATA lv_i TYPE i.
    LOOP AT mo_e->ms_config-steps INTO DATA(ls_step).
*     Numbered, because a tab strip says nothing about order and TABS journeys are
*     still meant to be worked through front to back. The current tab is the only
*     one carrying the accent colour, so the number is what tells the citizen how
*     far along the strip they are.
      lo_strip->button(
        text    = zcl_rak_journey_util=>esc( |{ lv_i + 1 }. { ls_step-title }| )
        icon    = ls_step-icon
        type    = COND string( WHEN lv_i = mo_e->mv_step THEN mo_e->ms_config-theme-accent_type ELSE 'Transparent' )
        tooltip = zcl_rak_journey_util=>esc( ls_step-title )
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
    io_box->text( text = |{ lv_hint } · up to { lv_mb } MB| class = 'rakAttHint' ).
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


  METHOD req_label.
    DATA(lv_req) = mo_e->mo_rules->is_required( is_field ).
    io_form->label( text  = zcl_rak_journey_util=>esc( is_field-label )
                    class = COND string( WHEN lv_req = abap_true
                                         THEN 'rakReq sapUiFormLabelNoColon'
                                         ELSE 'sapUiFormLabelNoColon' ) ).
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
