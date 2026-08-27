CLASS zcl_rak_journey_designer DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_step_row,
        seqnr       TYPE string,
        step_id     TYPE string,
        title       TYPE string,
        icon        TYPE string,
        bknd_screen TYPE string,
      END OF ty_step_row,
      tt_step_row TYPE STANDARD TABLE OF ty_step_row WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_fld_row,
        seqnr        TYPE string,
        step_id      TYPE string,
        field_name   TYPE string,
        ftype        TYPE string,
        label        TYPE string,
        placeholder  TYPE string,
        default_val  TYPE string,
        fgroup       TYPE string,
        section      TYPE string,
        fstate       TYPE string,
        width        TYPE string,
        hidden       TYPE string,
        readonly     TYPE string,
        required     TYPE string,
        regex        TYPE string,
        min_len      TYPE string,
        max_len      TYPE string,
        min_val      TYPE string,
        max_val      TYPE string,
        msg          TYPE string,
        has_attach   TYPE string,
        attach_label TYPE string,
        attach_types TYPE string,
        attach_maxmb TYPE string,
        attach_multi TYPE string,
        rollname     TYPE string,
        shlp         TYPE string,
        tech_name    TYPE string,
        label_ar     TYPE string,
        place_ar     TYPE string,
        msg_ar       TYPE string,
      END OF ty_fld_row,
      tt_fld_row TYPE STANDARD TABLE OF ty_fld_row WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_opt_row,
        seqnr      TYPE string,
        step_id    TYPE string,
        field_name TYPE string,
        opt_key    TYPE string,
        opt_text   TYPE string,
      END OF ty_opt_row,
      tt_opt_row TYPE STANDARD TABLE OF ty_opt_row WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_rule_row,
        rule_id   TYPE string,
        src_field TYPE string,
        src_op    TYPE string,
        src_value TYPE string,
        action    TYPE string,
        tgt_field TYPE string,
        tgt_value TYPE string,
        totable   TYPE string,
      END OF ty_rule_row,
      tt_rule_row TYPE STANDARD TABLE OF ty_rule_row WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_jny,
        journey_id TYPE string,
        title      TYPE string,
      END OF ty_jny,
      tt_jny TYPE STANDARD TABLE OF ty_jny WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_lint,
        type TYPE string,
        text TYPE string,
      END OF ty_lint,
      tt_lint TYPE STANDARD TABLE OF ty_lint WITH EMPTY KEY.

    " --- header (bound scalars) ---
    DATA mv_sel        TYPE string.
    DATA mv_copy_to    TYPE string.
    DATA mv_journey_id TYPE string.
    DATA mv_title      TYPE string.
    DATA mv_cj_type    TYPE string.
    DATA mv_layout     TYPE string.
    DATA mv_variant    TYPE string.
    DATA mv_accent     TYPE string.
    DATA mv_brand      TYPE string.
    DATA mv_navy       TYPE string.
    DATA mv_density    TYPE string.
    DATA mv_subtitle   TYPE string.
    DATA mv_handler    TYPE string.
    DATA mv_show_act   TYPE abap_bool.
    DATA mv_active     TYPE abap_bool.

    " --- step editor scalars ---
    DATA sv_seq   TYPE string.
    DATA sv_step  TYPE string.
    DATA sv_title TYPE string.
    DATA sv_icon  TYPE string.
    DATA sv_bknd  TYPE string.

    " --- field editor scalars ---
    DATA fv_seq       TYPE string.
    DATA fv_step      TYPE string.
    DATA fv_field     TYPE string.
    DATA fv_type      TYPE string.
    DATA fv_label     TYPE string.
    DATA fv_place     TYPE string.
    DATA fv_default   TYPE string.
    DATA fv_group     TYPE string.
    DATA fv_sect      TYPE string.
    DATA fv_state     TYPE string.
    DATA fv_width     TYPE string.
    DATA fv_hidden    TYPE abap_bool.
    DATA fv_readonly  TYPE abap_bool.
    DATA fv_req       TYPE abap_bool.
    DATA fv_regex     TYPE string.
    DATA fv_minlen    TYPE string.
    DATA fv_maxlen    TYPE string.
    DATA fv_minval    TYPE string.
    DATA fv_maxval    TYPE string.
    DATA fv_msg       TYPE string.
    DATA fv_tech      TYPE string.
    DATA fv_roll      TYPE string.
    DATA fv_shlp      TYPE string.
    DATA fv_attach    TYPE abap_bool.
    DATA fv_attlabel  TYPE string.
    DATA fv_atttypes  TYPE string.
    DATA fv_attmaxmb  TYPE string.
    DATA fv_attmulti  TYPE abap_bool.
    DATA fv_label_ar  TYPE string.
    DATA fv_place_ar  TYPE string.
    DATA fv_msg_ar    TYPE string.

    " --- option editor scalars ---
    DATA ov_seq   TYPE string.
    DATA ov_step  TYPE string.
    DATA ov_field TYPE string.
    DATA ov_key   TYPE string.
    DATA ov_text  TYPE string.

    " --- rule editor scalars ---
    DATA rv_id      TYPE string.
    DATA rv_src     TYPE string.
    DATA rv_op      TYPE string.
    DATA rv_srcval  TYPE string.
    DATA rv_action  TYPE string.
    DATA rv_tgt     TYPE string.
    DATA rv_tgtval  TYPE string.
    DATA rv_totable TYPE string.

    " --- display tables ---
    DATA mt_steps  TYPE tt_step_row.
    DATA mt_fields TYPE tt_fld_row.
    DATA mt_opts   TYPE tt_opt_row.
    DATA mt_rules  TYPE tt_rule_row.

  PRIVATE SECTION.
    DATA mo_client TYPE REF TO z2ui5_if_client.
    DATA mv_init   TYPE abap_bool.
    DATA mv_msg    TYPE string.
    DATA mv_mtype  TYPE string.
    DATA mt_jny    TYPE tt_jny.

    METHODS load_list.
    METHODS load_journey.
    METHODS new_journey.
    METHODS save_journey.
    METHODS copy_journey.
    METHODS to_int      IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE i.
    METHODS type_list   RETURNING VALUE(rt) TYPE string_table.
    METHODS is_input    IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS is_choice   IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS next_fseq   IMPORTING iv_step TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS next_oseq   IMPORTING iv_step TYPE string iv_field TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS next_ruleid RETURNING VALUE(rv) TYPE string.
    METHODS field_exists IMPORTING iv_field TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    METHODS lint        RETURNING VALUE(rt) TYPE tt_lint.
    METHODS clear_field_form.
    METHODS clear_rule_form.
    METHODS render.
    METHODS render_lint   IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_fields IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_rules  IMPORTING io TYPE REF TO z2ui5_cl_xml_view.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_DESIGNER IMPLEMENTATION.


  METHOD clear_field_form.
    CLEAR: fv_seq, fv_field, fv_label, fv_place, fv_default, fv_group, fv_sect, fv_state,
           fv_width, fv_hidden, fv_readonly, fv_req, fv_regex, fv_minlen, fv_maxlen,
           fv_minval, fv_maxval, fv_msg, fv_tech, fv_roll, fv_shlp, fv_attach, fv_attlabel,
           fv_atttypes, fv_attmaxmb, fv_attmulti, fv_label_ar, fv_place_ar, fv_msg_ar.
  ENDMETHOD.


  METHOD clear_rule_form.
    CLEAR: rv_id, rv_src, rv_op, rv_srcval, rv_action, rv_tgt, rv_tgtval, rv_totable.
  ENDMETHOD.


  METHOD copy_journey.
    IF mv_sel IS INITIAL OR mv_copy_to IS INITIAL.
      mv_msg = 'Pick a source journey and enter a new ID to copy into'. mv_mtype = 'Warning'. RETURN.
    ENDIF.
    DATA(lv_to) = to_upper( mv_copy_to ).

    SELECT SINGLE @abap_true FROM zrak_t_jny WHERE journey_id = @lv_to INTO @DATA(lv_exists).
    IF lv_exists = abap_true.
      mv_msg = |{ lv_to } already exists — choose a new ID|. mv_mtype = 'Error'. RETURN.
    ENDIF.

    SELECT SINGLE * FROM zrak_t_jny INTO @DATA(h) WHERE journey_id = @mv_sel.
    h-journey_id = lv_to. h-title = |{ h-title } (copy)|.
    INSERT zrak_t_jny FROM @h.

    SELECT * FROM zrak_t_jny_step INTO TABLE @DATA(ls) WHERE journey_id = @mv_sel.
    LOOP AT ls ASSIGNING FIELD-SYMBOL(<s>). <s>-journey_id = lv_to. ENDLOOP.
    INSERT zrak_t_jny_step FROM TABLE @ls.

    SELECT * FROM zrak_t_jny_fld INTO TABLE @DATA(lf) WHERE journey_id = @mv_sel.
    LOOP AT lf ASSIGNING FIELD-SYMBOL(<f>). <f>-journey_id = lv_to. ENDLOOP.
    INSERT zrak_t_jny_fld FROM TABLE @lf.

    SELECT * FROM zrak_t_jny_opt INTO TABLE @DATA(lo) WHERE journey_id = @mv_sel.
    LOOP AT lo ASSIGNING FIELD-SYMBOL(<o>). <o>-journey_id = lv_to. ENDLOOP.
    INSERT zrak_t_jny_opt FROM TABLE @lo.

    SELECT * FROM zrak_t_jny_rule INTO TABLE @DATA(lr) WHERE journey_id = @mv_sel.
    LOOP AT lr ASSIGNING FIELD-SYMBOL(<r>). <r>-journey_id = lv_to. ENDLOOP.
    IF lr IS NOT INITIAL.
      INSERT zrak_t_jny_rule FROM TABLE @lr.
    ENDIF.

    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = lv_to ).
    load_list( ).
    mv_sel = lv_to.
    load_journey( ).
    CLEAR mv_copy_to.
    mv_msg = |Copied to { lv_to }|. mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD field_exists.
    READ TABLE mt_fields TRANSPORTING NO FIELDS WITH KEY field_name = to_upper( iv_field ).
    rv = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD is_choice.
    DATA(t) = to_upper( iv_type ).
    rv = xsdbool( t = 'SELECT' OR t = 'RADIO' OR t = 'MULTISELECT' OR t = 'SEGMENTED' ).
  ENDMETHOD.


  METHOD is_input.
    DATA(t) = to_upper( iv_type ).
    rv = xsdbool( t <> 'DISPLAY'  AND t <> 'READONLY' AND t <> 'TABLE'  AND t <> 'UPLOAD'
              AND t <> 'STATUS'   AND t <> 'OBJNUM'   AND t <> 'PROGRESS' AND t <> 'LINK' ).
  ENDMETHOD.


  METHOD lint.
    " Live pre-flight — mirrors ZRAK_CJ_MAP_AUDIT plus rule integrity (audit item B).
    LOOP AT mt_fields INTO DATA(f).
      IF is_choice( f-ftype ) = abap_true.
        DATA lv_opts TYPE i.
        lv_opts = 0.
        LOOP AT mt_opts INTO DATA(o)
          WHERE step_id = f-step_id AND field_name = f-field_name.
          lv_opts = lv_opts + 1.
        ENDLOOP.
        IF lv_opts = 0 AND f-rollname IS INITIAL AND f-shlp IS INITIAL.
          APPEND VALUE #( type = 'Error'
            text = |{ f-step_id }/{ f-field_name }: { f-ftype } has no options, rollname or search help → renders EMPTY| ) TO rt.
        ENDIF.
      ENDIF.

      IF is_input( f-ftype ) = abap_true AND f-tech_name IS INITIAL.
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: no tech_name → value won't post to the backend| ) TO rt.
      ENDIF.

      READ TABLE mt_steps TRANSPORTING NO FIELDS WITH KEY step_id = f-step_id.
      IF sy-subrc <> 0.
        APPEND VALUE #( type = 'Error'
          text = |{ f-step_id }/{ f-field_name }: references step '{ f-step_id }' which is not defined| ) TO rt.
      ENDIF.

      " required + hidden simultaneously -> unreachable required field blocks submit
      IF f-required = 'X' AND f-hidden = 'X'.
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: required AND hidden → user can never fill it, submit blocks| ) TO rt.
      ENDIF.

      " min_len > max_len sanity
      IF to_int( f-min_len ) > 0 AND to_int( f-max_len ) > 0
         AND to_int( f-min_len ) > to_int( f-max_len ).
        APPEND VALUE #( type = 'Warning'
          text = |{ f-step_id }/{ f-field_name }: min_len { f-min_len } > max_len { f-max_len }| ) TO rt.
      ENDIF.
    ENDLOOP.

    " duplicate tech_name across fields -> overwrite in backend
    LOOP AT mt_fields INTO DATA(a) WHERE tech_name IS NOT INITIAL.
      LOOP AT mt_fields INTO DATA(b)
        WHERE tech_name = a-tech_name AND field_name <> a-field_name.
        IF a-field_name < b-field_name.
          APPEND VALUE #( type = 'Error'
            text = |tech_name '{ a-tech_name }' shared by { a-field_name } and { b-field_name } → they overwrite in the backend| ) TO rt.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " mapped fields on a step with no backend screen -> POST has no target (item D)
    LOOP AT mt_steps INTO DATA(stp) WHERE bknd_screen IS INITIAL.
      LOOP AT mt_fields INTO DATA(mf) WHERE step_id = stp-step_id AND tech_name IS NOT INITIAL.
        APPEND VALUE #( type = 'Warning'
          text = |Step { stp-step_id } has mapped fields but no backend screen → their POST has no target| ) TO rt.
        EXIT.
      ENDLOOP.
    ENDLOOP.

    " rule integrity (audit item B): unknown fields, bad op/action -> rule silently never fires
    LOOP AT mt_rules INTO DATA(r).
      IF r-src_field IS NOT INITIAL AND field_exists( r-src_field ) = abap_false.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: src_field '{ r-src_field }' is not a defined field → rule never fires| ) TO rt.
      ENDIF.
      IF r-tgt_field IS NOT INITIAL AND field_exists( r-tgt_field ) = abap_false.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: tgt_field '{ r-tgt_field }' is not a defined field → no effect| ) TO rt.
      ENDIF.
      IF r-src_op <> 'EQ' AND r-src_op <> 'NE' AND r-src_op <> 'INITIAL' AND r-src_op <> 'NOTINITIAL'.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: operator '{ r-src_op }' is not one of EQ/NE/INITIAL/NOTINITIAL → never fires| ) TO rt.
      ENDIF.
      IF r-action <> 'SHOW' AND r-action <> 'HIDE' AND r-action <> 'REQUIRE'
         AND r-action <> 'OPTIONAL' AND r-action <> 'SET' AND r-action <> 'CLEAR'.
        APPEND VALUE #( type = 'Error'
          text = |Rule { r-rule_id }: action '{ r-action }' is not a valid action → no effect| ) TO rt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_journey.
    IF mv_sel IS INITIAL.
      mv_msg = 'Select a journey to load'. mv_mtype = 'Warning'. RETURN.
    ENDIF.
    SELECT SINGLE * FROM zrak_t_jny INTO @DATA(h) WHERE journey_id = @mv_sel.
    IF sy-subrc <> 0.
      mv_msg = 'Journey not found'. mv_mtype = 'Error'. RETURN.
    ENDIF.
    CLEAR: mt_steps, mt_fields, mt_opts, mt_rules.
    mv_journey_id = h-journey_id. mv_title = h-title. mv_cj_type = h-cj_type.
    mv_layout = h-layout_mode. mv_variant = h-theme_variant. mv_accent = h-accent_type.
    mv_brand = h-brand_color. mv_navy = h-navy_color. mv_density = h-density.
    mv_subtitle = h-subtitle. mv_handler = h-handler_class.
    mv_show_act = xsdbool( h-show_actions = 'X' ). mv_active = xsdbool( h-active = 'X' ).

    SELECT * FROM zrak_t_jny_step INTO TABLE @DATA(ls) WHERE journey_id = @mv_sel ORDER BY seqnr.
    LOOP AT ls INTO DATA(s).
      APPEND VALUE #( seqnr = |{ s-seqnr }| step_id = s-step_id title = s-title
                      icon = s-icon bknd_screen = s-bknd_screen ) TO mt_steps.
    ENDLOOP.

    SELECT * FROM zrak_t_jny_fld INTO TABLE @DATA(lf) WHERE journey_id = @mv_sel ORDER BY step_id, seqnr.
    LOOP AT lf INTO DATA(f).
      APPEND VALUE #( seqnr = |{ f-seqnr }| step_id = f-step_id field_name = f-field_name ftype = f-ftype
                      label = f-zlabel placeholder = f-placeholder default_val = f-default_val
                      fgroup = f-fgroup section = f-zsection fstate = f-fstate width = f-width
                      hidden = f-hidden readonly = f-readonly required = f-required
                      regex = f-regex
                      min_len = |{ f-min_len }| max_len = |{ f-max_len }|
                      min_val = f-min_val max_val = f-max_val msg = f-msg
                      has_attach = f-has_attach attach_label = f-attach_label
                      attach_types = f-attach_types attach_maxmb = |{ f-attach_maxmb }|
                      attach_multi = f-attach_multi
                      rollname = f-rollname shlp = f-shlp tech_name = f-tech_name
                      label_ar = f-zlabel_ar place_ar = f-placeholder_ar msg_ar = f-msg_ar ) TO mt_fields.
    ENDLOOP.

    SELECT * FROM zrak_t_jny_opt INTO TABLE @DATA(lo) WHERE journey_id = @mv_sel ORDER BY step_id, field_name, seqnr.
    LOOP AT lo INTO DATA(o).
      APPEND VALUE #( seqnr = |{ o-seqnr }| step_id = o-step_id field_name = o-field_name
                      opt_key = o-opt_key opt_text = o-opt_text ) TO mt_opts.
    ENDLOOP.

    SELECT * FROM zrak_t_jny_rule INTO TABLE @DATA(lr) WHERE journey_id = @mv_sel ORDER BY rule_id.
    LOOP AT lr INTO DATA(r).
      APPEND VALUE #( rule_id = r-rule_id src_field = r-src_field src_op = r-src_op
                      src_value = r-src_value action = r-action tgt_field = r-tgt_field
                      tgt_value = r-tgt_value totable = r-totable ) TO mt_rules.
    ENDLOOP.

    mv_msg = |Loaded { mv_sel }|. mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD load_list.
    SELECT journey_id, title FROM zrak_t_jny ORDER BY journey_id INTO TABLE @mt_jny.
  ENDMETHOD.


  METHOD new_journey.
    CLEAR: mv_journey_id, mv_title, mv_cj_type, mv_subtitle, mv_handler,
           mt_steps, mt_fields, mt_opts, mt_rules.
    mv_layout   = 'WIZARD'.
    mv_variant  = 'CLEAN'.
    mv_accent   = 'Emphasized'.
    mv_brand    = 'rgb(196,30,38)'.
    mv_navy     = 'rgb(16,35,62)'.
    mv_density  = 'Cozy'.
    mv_show_act = abap_true.
    mv_active   = abap_true.
  ENDMETHOD.


  METHOD next_fseq.
    DATA lv_max TYPE i.
    LOOP AT mt_fields INTO DATA(f) WHERE step_id = to_upper( iv_step ).
      DATA(n) = to_int( f-seqnr ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD next_oseq.
    DATA lv_max TYPE i.
    LOOP AT mt_opts INTO DATA(o) WHERE step_id = to_upper( iv_step ) AND field_name = to_upper( iv_field ).
      DATA(n) = to_int( o-seqnr ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD next_ruleid.
    DATA lv_max TYPE i.
    LOOP AT mt_rules INTO DATA(r).
      DATA(n) = to_int( r-rule_id ).
      IF n > lv_max. lv_max = n. ENDIF.
    ENDLOOP.
    rv = |R{ lv_max + 10 }|.
  ENDMETHOD.


  METHOD render.
    DATA(view) = z2ui5_cl_xml_view=>factory( ).
    DATA(page) = view->shell( )->page( title = 'RAK Journey Designer' class = 'sapUiSizeCompact' ).

    DATA(bar) = page->hbox( alignitems = 'Center' class = 'sapUiSmallMargin' ).
    DATA(cb) = bar->combobox( selectedkey = mo_client->_bind_edit( mv_sel ) placeholder = 'Select journey' width = '22rem' ).
    LOOP AT mt_jny INTO DATA(j).
      cb->item( key = j-journey_id text = |{ j-journey_id } — { j-title }| ).
    ENDLOOP.
    bar->button( text = 'Load' icon = 'sap-icon://open-folder' press = mo_client->_event( 'LOAD' ) class = 'sapUiTinyMarginBegin' ).
    bar->button( text = 'New'  icon = 'sap-icon://add-document' press = mo_client->_event( 'NEW' ) ).
    bar->button( text = 'Save' icon = 'sap-icon://save' type = 'Emphasized' press = mo_client->_event( 'SAVE' ) ).
    bar->input( value = mo_client->_bind_edit( mv_copy_to ) placeholder = 'New ID to copy into' width = '14rem' class = 'sapUiTinyMarginBegin' ).
    bar->button( text = 'Copy' icon = 'sap-icon://copy' press = mo_client->_event( 'COPY' ) ).
    IF mv_journey_id IS NOT INITIAL.
      DATA(cfg) = mo_client->get( )-s_config.
      bar->link( text = 'Preview' target = '_blank' class = 'sapUiSmallMarginBegin'
        href = |{ cfg-origin }{ cfg-pathname }?sap-client={ sy-mandt }&app_start=ZCL_RAK_JOURNEY_ENGINE&journey={ to_upper( mv_journey_id ) }| ).
    ENDIF.

    IF mv_msg IS NOT INITIAL.
      page->message_strip( text = mv_msg type = mv_mtype showicon = abap_true class = 'sapUiSmallMarginBegin sapUiSmallMarginEnd' ).
    ENDIF.

    render_lint( page ).

    " ---- Header ----
    DATA(ph) = page->panel( headertext = 'Journey header' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(hf) = ph->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '2' columnsl = '2' columnsm = '2' )->content( ns = 'form' ).
    hf->label( 'Journey ID' ).    hf->input( value = mo_client->_bind_edit( mv_journey_id ) ).
    hf->label( 'Title' ).         hf->input( value = mo_client->_bind_edit( mv_title ) ).
    hf->label( 'Case type' ).     hf->input( value = mo_client->_bind_edit( mv_cj_type ) ).
    hf->label( 'Subtitle' ).      hf->input( value = mo_client->_bind_edit( mv_subtitle ) ).
    hf->label( 'Layout' ).        DATA(l1) = hf->combobox( selectedkey = mo_client->_bind_edit( mv_layout ) ).
    l1->item( key = 'WIZARD' text = 'WIZARD' ). l1->item( key = 'TABS' text = 'TABS' ).
    l1->item( key = 'ACCORDION' text = 'ACCORDION' ). l1->item( key = 'SINGLE' text = 'SINGLE' ).
    hf->label( 'Theme variant' ). DATA(l2) = hf->combobox( selectedkey = mo_client->_bind_edit( mv_variant ) ).
    l2->item( key = 'CLEAN' text = 'CLEAN' ). l2->item( key = 'PREMIUM' text = 'PREMIUM' ).
    hf->label( 'Accent' ).        DATA(l3) = hf->combobox( selectedkey = mo_client->_bind_edit( mv_accent ) ).
    l3->item( key = 'Emphasized' text = 'Emphasized' ). l3->item( key = 'Accept' text = 'Accept' ).
    l3->item( key = 'Reject' text = 'Reject' ). l3->item( key = 'Attention' text = 'Attention' ).
    hf->label( 'Density' ).       DATA(l4) = hf->combobox( selectedkey = mo_client->_bind_edit( mv_density ) ).
    l4->item( key = 'Cozy' text = 'Cozy' ). l4->item( key = 'Compact' text = 'Compact' ).
    hf->label( 'Brand colour' ).  hf->input( value = mo_client->_bind_edit( mv_brand ) ).
    hf->label( 'Navy colour' ).   hf->input( value = mo_client->_bind_edit( mv_navy ) ).
    hf->label( 'Handler class' ). hf->input( value = mo_client->_bind_edit( mv_handler ) ).
    hf->label( 'Show actions' ).  hf->switch( state = mo_client->_bind_edit( mv_show_act ) ).
    hf->label( 'Active' ).        hf->switch( state = mo_client->_bind_edit( mv_active ) ).

    " ---- Steps ----
    DATA(ps) = page->panel( headertext = 'Steps' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(sf) = ps->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '4' columnsl = '4' columnsm = '2' )->content( ns = 'form' ).
    sf->label( 'Seq' ).            sf->input( value = mo_client->_bind_edit( sv_seq ) ).
    sf->label( 'Step ID' ).        sf->input( value = mo_client->_bind_edit( sv_step ) ).
    sf->label( 'Title' ).          sf->input( value = mo_client->_bind_edit( sv_title ) ).
    sf->label( 'Icon' ).           sf->input( value = mo_client->_bind_edit( sv_icon ) ).
    sf->label( 'Backend screen' ). sf->input( value = mo_client->_bind_edit( sv_bknd )
                                              placeholder = 'e.g. NE023_1 — this step POSTs here' ).
    DATA(sb) = ps->hbox( class = 'sapUiTinyMarginBegin' ).
    sb->button( text = 'Add / update step' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ADD_STEP' ) ).
    sb->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_STEP' ) class = 'sapUiTinyMarginBegin' ).
    DATA(st) = ps->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(sc) = st->columns( ).
    sc->column( )->text( 'Seq' ). sc->column( )->text( 'Step ID' ). sc->column( )->text( 'Title' ).
    sc->column( )->text( 'Icon' ). sc->column( )->text( 'Bknd screen' ). sc->column( )->text( '' ). sc->column( )->text( '' ).
    DATA(si) = st->items( ).
    LOOP AT mt_steps INTO DATA(rs).
      si->column_list_item( )->cells(
        )->text( rs-seqnr )->text( rs-step_id )->text( rs-title )->text( rs-icon )->text( rs-bknd_screen
        )->button( icon = 'sap-icon://edit'   type = 'Transparent' tooltip = 'Edit'
                   press = mo_client->_event( |ESTEP_{ rs-step_id }| )
        )->button( icon = 'sap-icon://delete' type = 'Transparent' tooltip = 'Delete'
                   press = mo_client->_event( |XSTEP_{ rs-step_id }| ) ).
    ENDLOOP.

    render_fields( page ).

    " ---- Options ----
    DATA(po) = page->panel( headertext = 'Options' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(oform) = po->simple_form( editable = abap_true layout = 'ResponsiveGridLayout' columnsxl = '3' columnsl = '3' columnsm = '1' )->content( ns = 'form' ).
    oform->label( 'Step ID' ).    oform->input( value = mo_client->_bind_edit( ov_step ) ).
    oform->label( 'Field name' ). oform->input( value = mo_client->_bind_edit( ov_field ) ).
    oform->label( 'Seq' ).        oform->input( value = mo_client->_bind_edit( ov_seq ) placeholder = 'blank = auto' ).
    oform->label( 'Option key' ). oform->input( value = mo_client->_bind_edit( ov_key ) ).
    oform->label( 'Option text' ). oform->input( value = mo_client->_bind_edit( ov_text ) ).
    DATA(ob) = po->hbox( class = 'sapUiTinyMarginBegin' ).
    ob->button( text = 'Add / update option' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ADD_OPT' ) ).
    ob->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_OPT' ) class = 'sapUiTinyMarginBegin' ).
    DATA(ot) = po->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(oc) = ot->columns( ).
    oc->column( )->text( 'Seq' ). oc->column( )->text( 'Step' ). oc->column( )->text( 'Field' ). oc->column( )->text( 'Key' ). oc->column( )->text( 'Text' ).
    oc->column( )->text( '' ). oc->column( )->text( '' ).
    DATA(oi) = ot->items( ).
    LOOP AT mt_opts INTO DATA(ro).
      oi->column_list_item( )->cells(
        )->text( ro-seqnr )->text( ro-step_id )->text( ro-field_name )->text( ro-opt_key )->text( ro-opt_text
        )->button( icon = 'sap-icon://edit'   type = 'Transparent' tooltip = 'Edit'
                   press = mo_client->_event( |EOPT_{ ro-step_id }~{ ro-field_name }~{ ro-opt_key }| )
        )->button( icon = 'sap-icon://delete' type = 'Transparent' tooltip = 'Delete'
                   press = mo_client->_event( |XOPT_{ ro-step_id }~{ ro-field_name }~{ ro-opt_key }| ) ).
    ENDLOOP.

    render_rules( page ).

    mo_client->view_display( view->stringify( ) ).
  ENDMETHOD.


  METHOD render_fields.
    DATA(pf) = io->panel( headertext = 'Fields' expandable = abap_true expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(ff) = pf->simple_form( editable = abap_true layout = 'ResponsiveGridLayout'
                                columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).

    ff->title( ns = 'core' text = 'Basics' ).
    ff->label( 'Step ID' ).    ff->input( value = mo_client->_bind_edit( fv_step ) ).
    ff->label( 'Field name' ). ff->input( value = mo_client->_bind_edit( fv_field ) ).
    ff->label( 'Seq' ).        ff->input( value = mo_client->_bind_edit( fv_seq ) placeholder = 'blank = auto' ).
    ff->label( 'Type' ).       DATA(ft) = ff->combobox( selectedkey = mo_client->_bind_edit( fv_type ) ).
    LOOP AT type_list( ) INTO DATA(t). ft->item( key = t text = t ). ENDLOOP.
    ff->label( 'Label' ).      ff->input( value = mo_client->_bind_edit( fv_label ) ).
    ff->label( 'Placeholder' ). ff->input( value = mo_client->_bind_edit( fv_place ) ).
    ff->label( 'Default value' ). ff->input( value = mo_client->_bind_edit( fv_default ) ).
    ff->label( 'Group' ).      ff->input( value = mo_client->_bind_edit( fv_group ) ).
    ff->label( 'Section' ).    ff->input( value = mo_client->_bind_edit( fv_sect ) ).
    ff->label( 'Width' ).      ff->input( value = mo_client->_bind_edit( fv_width ) placeholder = 'e.g. 12rem / 100%' ).
    ff->label( 'State' ).      DATA(fs) = ff->combobox( selectedkey = mo_client->_bind_edit( fv_state ) ).
    fs->item( key = '' text = '(none)' ). fs->item( key = 'None' text = 'None' ).
    fs->item( key = 'Success' text = 'Success' ). fs->item( key = 'Warning' text = 'Warning' ).
    fs->item( key = 'Error' text = 'Error' ). fs->item( key = 'Information' text = 'Information' ).
    ff->label( 'Hidden' ).     ff->checkbox( selected = mo_client->_bind_edit( fv_hidden ) ).
    ff->label( 'Read-only' ).  ff->checkbox( selected = mo_client->_bind_edit( fv_readonly ) ).

    ff->title( ns = 'core' text = 'Validation' ).
    ff->label( 'Required' ).   ff->checkbox( selected = mo_client->_bind_edit( fv_req ) ).
    ff->label( 'Regex' ).      ff->input( value = mo_client->_bind_edit( fv_regex ) ).
    ff->label( 'Min length' ). ff->input( value = mo_client->_bind_edit( fv_minlen ) ).
    ff->label( 'Max length' ). ff->input( value = mo_client->_bind_edit( fv_maxlen ) ).
    ff->label( 'Min value' ).  ff->input( value = mo_client->_bind_edit( fv_minval )
                                          placeholder = 'slider/stepper/number floor' ).
    ff->label( 'Max value' ).  ff->input( value = mo_client->_bind_edit( fv_maxval )
                                          placeholder = 'slider/stepper/rating ceiling' ).
    ff->label( 'Validation message' ). ff->input( value = mo_client->_bind_edit( fv_msg ) ).

    ff->title( ns = 'core' text = 'Backend & value help' ).
    ff->label( 'Tech name' ).   ff->input( value = mo_client->_bind_edit( fv_tech )
                                           placeholder = 'backend field / doc code (FR, B6...)' ).
    ff->label( 'Rollname' ).    ff->input( value = mo_client->_bind_edit( fv_roll )
                                           placeholder = 'data element → dropdown values' ).
    ff->label( 'Search help' ). ff->input( value = mo_client->_bind_edit( fv_shlp ) ).

    ff->title( ns = 'core' text = 'Attachment' ).
    ff->label( 'Has attachment' ). ff->checkbox( selected = mo_client->_bind_edit( fv_attach ) ).
    ff->label( 'Attach label' ).   ff->input( value = mo_client->_bind_edit( fv_attlabel ) ).
    ff->label( 'Allowed types' ).  ff->input( value = mo_client->_bind_edit( fv_atttypes )
                                              placeholder = 'pdf,jpg,png' ).
    ff->label( 'Max MB' ).         ff->input( value = mo_client->_bind_edit( fv_attmaxmb ) ).
    ff->label( 'Allow multiple' ). ff->checkbox( selected = mo_client->_bind_edit( fv_attmulti ) ).

    ff->title( ns = 'core' text = 'Arabic (العربية)' ).
    ff->label( 'Label (AR)' ).       ff->input( value = mo_client->_bind_edit( fv_label_ar ) ).
    ff->label( 'Placeholder (AR)' ). ff->input( value = mo_client->_bind_edit( fv_place_ar ) ).
    ff->label( 'Message (AR)' ).     ff->input( value = mo_client->_bind_edit( fv_msg_ar ) ).

    DATA(fb) = pf->hbox( class = 'sapUiTinyMarginBegin' ).
    fb->button( text = 'Add / update field' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ADD_FLD' ) ).
    fb->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_FLD' ) class = 'sapUiTinyMarginBegin' ).

    " lean table (rich form, compact grid); AR column shows a tick when present
    DATA(fdt) = pf->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(fc) = fdt->columns( ).
    fc->column( )->text( 'Seq' ). fc->column( )->text( 'Step' ). fc->column( )->text( 'Field' ). fc->column( )->text( 'Type' ).
    fc->column( )->text( 'Label' ). fc->column( )->text( 'Tech' ). fc->column( )->text( 'Roll' ).
    fc->column( )->text( 'Req' ). fc->column( )->text( 'Hid' ). fc->column( )->text( 'Att' ). fc->column( )->text( 'AR' ).
    fc->column( )->text( '' ). fc->column( )->text( '' ). fc->column( )->text( '' ).
    DATA(fi) = fdt->items( ).
    LOOP AT mt_fields INTO DATA(rf).
      fi->column_list_item( )->cells(
        )->text( rf-seqnr )->text( rf-step_id )->text( rf-field_name )->text( rf-ftype
        )->text( rf-label )->text( rf-tech_name )->text( rf-rollname
        )->text( rf-required )->text( rf-hidden )->text( rf-has_attach
        )->text( COND #( WHEN rf-label_ar IS NOT INITIAL THEN 'X' ELSE '' )
        )->button( icon = 'sap-icon://edit'      type = 'Transparent' tooltip = 'Edit'
                   press = mo_client->_event( |EFLD_{ rf-step_id }~{ rf-field_name }| )
        )->button( icon = 'sap-icon://duplicate' type = 'Transparent' tooltip = 'Duplicate'
                   press = mo_client->_event( |DFLD_{ rf-step_id }~{ rf-field_name }| )
        )->button( icon = 'sap-icon://delete'    type = 'Transparent' tooltip = 'Delete'
                   press = mo_client->_event( |XFLD_{ rf-step_id }~{ rf-field_name }| ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_lint.
    DATA(lt) = lint( ).
    DATA(lo_p) = io->panel(
      headertext = COND #( WHEN lt IS INITIAL THEN 'Validation — no issues'
                           ELSE |Validation — { lines( lt ) } issue(s)| )
      expandable = abap_true
      expanded   = xsdbool( lt IS NOT INITIAL )
      class      = 'sapUiSmallMarginBeginEnd' ).
    IF lt IS INITIAL.
      lo_p->message_strip( text = 'No structural problems detected in the current draft.'
                           type = 'Success' showicon = abap_true class = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.
    LOOP AT lt INTO DATA(m).
      lo_p->message_strip( text = m-text type = m-type showicon = abap_true
                           class = 'sapUiSmallMarginBegin sapUiSmallMarginEnd sapUiTinyMarginTop' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD render_rules.
    DATA(pr) = io->panel( headertext = 'Rules (show / hide / require / set)' expandable = abap_true
                          expanded = abap_true class = 'sapUiSmallMarginBeginEnd' ).
    DATA(rf) = pr->simple_form( editable = abap_true layout = 'ResponsiveGridLayout'
                                columnsxl = '2' columnsl = '2' columnsm = '1' )->content( ns = 'form' ).

    rf->title( ns = 'core' text = 'When (condition)' ).
    rf->label( 'Rule ID' ). rf->input( value = mo_client->_bind_edit( rv_id ) placeholder = 'blank = auto' ).
    rf->label( 'Source field' ). DATA(rs) = rf->combobox( selectedkey = mo_client->_bind_edit( rv_src ) ).
    LOOP AT mt_fields INTO DATA(sfld). rs->item( key = sfld-field_name text = sfld-field_name ). ENDLOOP.
    rf->label( 'Operator' ). DATA(rop) = rf->combobox( selectedkey = mo_client->_bind_edit( rv_op ) ).
    rop->item( key = 'EQ' text = 'equals' ). rop->item( key = 'NE' text = 'not equal' ).
    rop->item( key = 'INITIAL' text = 'is empty' ). rop->item( key = 'NOTINITIAL' text = 'is not empty' ).
    rf->label( 'Source value' ). rf->input( value = mo_client->_bind_edit( rv_srcval )
                                            placeholder = 'compared value (EQ / NE)' ).

    rf->title( ns = 'core' text = 'Then (action)' ).
    rf->label( 'Action' ). DATA(ract) = rf->combobox( selectedkey = mo_client->_bind_edit( rv_action ) ).
    ract->item( key = 'SHOW' text = 'SHOW target' ). ract->item( key = 'HIDE' text = 'HIDE target' ).
    ract->item( key = 'REQUIRE' text = 'REQUIRE target' ). ract->item( key = 'OPTIONAL' text = 'OPTIONAL target' ).
    ract->item( key = 'SET' text = 'SET target value' ). ract->item( key = 'CLEAR' text = 'CLEAR target' ).
    rf->label( 'Target field' ). DATA(rt) = rf->combobox( selectedkey = mo_client->_bind_edit( rv_tgt ) ).
    LOOP AT mt_fields INTO DATA(tfld). rt->item( key = tfld-field_name text = tfld-field_name ). ENDLOOP.
    rf->label( 'Target value' ). rf->input( value = mo_client->_bind_edit( rv_tgtval )
                                            placeholder = 'used by SET' ).
    rf->label( 'To-table' ). rf->input( value = mo_client->_bind_edit( rv_totable )
                                        placeholder = 'optional — leave blank unless needed' ).

    DATA(rb) = pr->hbox( class = 'sapUiTinyMarginBegin' ).
    rb->button( text = 'Add / update rule' icon = 'sap-icon://add' type = 'Emphasized' press = mo_client->_event( 'ADD_RULE' ) ).
    rb->button( text = 'Clear form' icon = 'sap-icon://clear-all' press = mo_client->_event( 'CLR_RULE' ) class = 'sapUiTinyMarginBegin' ).

    DATA(rdt) = pr->table( class = 'sapUiSmallMarginBeginEnd' ).
    DATA(rc) = rdt->columns( ).
    rc->column( )->text( 'Rule' ). rc->column( )->text( 'When field' ). rc->column( )->text( 'Op' ).
    rc->column( )->text( 'Value' ). rc->column( )->text( 'Action' ). rc->column( )->text( 'Target' ).
    rc->column( )->text( 'Set to' ). rc->column( )->text( '' ). rc->column( )->text( '' ).
    DATA(ri) = rdt->items( ).
    LOOP AT mt_rules INTO DATA(rr).
      ri->column_list_item( )->cells(
        )->text( rr-rule_id )->text( rr-src_field )->text( rr-src_op )->text( rr-src_value
        )->text( rr-action )->text( rr-tgt_field )->text( rr-tgt_value
        )->button( icon = 'sap-icon://edit'   type = 'Transparent' tooltip = 'Edit'
                   press = mo_client->_event( |ERULE_{ rr-rule_id }| )
        )->button( icon = 'sap-icon://delete' type = 'Transparent' tooltip = 'Delete'
                   press = mo_client->_event( |XRULE_{ rr-rule_id }| ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD save_journey.
    IF mv_journey_id IS INITIAL.
      mv_msg = 'Journey ID is required'. mv_mtype = 'Error'. RETURN.
    ENDIF.
    DATA(jid) = to_upper( mv_journey_id ).

    DELETE FROM zrak_t_jny      WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_step WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_fld  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_opt  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_rule WHERE journey_id = @jid.

    INSERT zrak_t_jny FROM @( VALUE #( mandt = sy-mandt journey_id = jid title = mv_title cj_type = mv_cj_type
      layout_mode = mv_layout theme_variant = mv_variant accent_type = mv_accent
      brand_color = mv_brand navy_color = mv_navy density = mv_density subtitle = mv_subtitle
      handler_class = to_upper( mv_handler )
      show_actions = COND #( WHEN mv_show_act = abap_true THEN 'X' ELSE ' ' )
      active       = COND #( WHEN mv_active   = abap_true THEN 'X' ELSE ' ' ) ) ).

    LOOP AT mt_steps INTO DATA(s).
      INSERT zrak_t_jny_step FROM @( VALUE #( mandt = sy-mandt journey_id = jid
        step_id = s-step_id seqnr = to_int( s-seqnr ) title = s-title icon = s-icon
        bknd_screen = s-bknd_screen ) ).
    ENDLOOP.

    LOOP AT mt_fields INTO DATA(f).
      INSERT zrak_t_jny_fld FROM @( VALUE #( mandt = sy-mandt journey_id = jid
        step_id = f-step_id field_name = f-field_name seqnr = to_int( f-seqnr ) ftype = f-ftype
        zlabel = f-label placeholder = f-placeholder default_val = f-default_val
        fgroup = f-fgroup zsection = f-section fstate = f-fstate width = f-width
        hidden = f-hidden readonly = f-readonly required = f-required
        regex = f-regex min_len = to_int( f-min_len ) max_len = to_int( f-max_len )
        min_val = f-min_val max_val = f-max_val msg = f-msg
        has_attach = f-has_attach attach_label = f-attach_label
        attach_types = f-attach_types attach_maxmb = to_int( f-attach_maxmb )
        attach_multi = f-attach_multi
        rollname = f-rollname shlp = f-shlp tech_name = f-tech_name
        zlabel_ar = f-label_ar placeholder_ar = f-place_ar msg_ar = f-msg_ar ) ).
    ENDLOOP.

    LOOP AT mt_opts INTO DATA(o).
      INSERT zrak_t_jny_opt FROM @( VALUE #( mandt = sy-mandt journey_id = jid
        step_id = o-step_id field_name = o-field_name opt_key = o-opt_key
        seqnr = to_int( o-seqnr ) opt_text = o-opt_text ) ).
    ENDLOOP.

    LOOP AT mt_rules INTO DATA(r).
      INSERT zrak_t_jny_rule FROM @( VALUE #( mandt = sy-mandt journey_id = jid
        rule_id = r-rule_id src_field = r-src_field src_op = r-src_op src_value = r-src_value
        action = r-action tgt_field = r-tgt_field tgt_value = r-tgt_value totable = r-totable ) ).
    ENDLOOP.

    COMMIT WORK.
    " PERF/PARITY: drop the per-WP config cache for this journey so Preview and
    " every runtime WP (within TTL) pick up the edit immediately.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = jid ).
    load_list( ).
    mv_sel = jid.
    mv_msg = |Saved { jid } — { lines( mt_steps ) } steps, { lines( mt_fields ) } fields, | &&
             |{ lines( mt_opts ) } options, { lines( mt_rules ) } rules|.
    mv_mtype = 'Success'.
  ENDMETHOD.


  METHOD to_int.
    IF iv IS NOT INITIAL AND iv CO '0123456789 '.
      rv = iv.
    ENDIF.
  ENDMETHOD.


  METHOD type_list.
    rt = VALUE #(
      ( `INPUT` ) ( `EMAIL` ) ( `PHONE` ) ( `NUMBER` ) ( `CURRENCY` ) ( `TEXTAREA` )
      ( `DATE` ) ( `TIME` ) ( `DATETIME` ) ( `SELECT` ) ( `MULTISELECT` ) ( `RADIO` )
      ( `CHECKBOX` ) ( `SWITCH` ) ( `SEGMENTED` ) ( `SLIDER` ) ( `STEPPER` ) ( `RATING` )
      ( `DISPLAY` ) ( `READONLY` ) ( `STATUS` ) ( `OBJNUM` ) ( `PROGRESS` ) ( `LINK` )
      ( `SEARCH` ) ( `TABLE` ) ( `UPLOAD` ) ( `PDF` ) ).
  ENDMETHOD.


  METHOD z2ui5_if_app~main.
    mo_client = client.

    IF mv_init = abap_false.
      mv_init = abap_true.
      load_list( ).
      new_journey( ).
    ENDIF.

    CLEAR: mv_msg, mv_mtype.
    DATA(ev) = mo_client->get( )-event.

    " ---- row-level edit / delete / duplicate ----
    IF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'ESTEP_'.
      DATA(lv_es) = to_upper( substring( val = ev off = 6 ) ).
      READ TABLE mt_steps INTO DATA(es) WITH KEY step_id = lv_es.
      IF sy-subrc = 0.
        sv_seq = es-seqnr. sv_step = es-step_id. sv_title = es-title.
        sv_icon = es-icon. sv_bknd = es-bknd_screen.
        mv_msg = |Editing step { lv_es } — change values, then Add / update step|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'XSTEP_'.
      DELETE mt_steps WHERE step_id = to_upper( substring( val = ev off = 6 ) ).

    ELSEIF strlen( ev ) > 5 AND substring( val = ev len = 5 ) = 'EFLD_'.
      SPLIT substring( val = ev off = 5 ) AT '~' INTO DATA(lv_efs) DATA(lv_eff).
      READ TABLE mt_fields INTO DATA(efr)
        WITH KEY step_id = to_upper( lv_efs ) field_name = to_upper( lv_eff ).
      IF sy-subrc = 0.
        fv_seq = efr-seqnr. fv_step = efr-step_id. fv_field = efr-field_name. fv_type = efr-ftype.
        fv_label = efr-label. fv_place = efr-placeholder. fv_default = efr-default_val.
        fv_group = efr-fgroup. fv_sect = efr-section. fv_state = efr-fstate. fv_width = efr-width.
        fv_hidden = xsdbool( efr-hidden = 'X' ). fv_readonly = xsdbool( efr-readonly = 'X' ).
        fv_req = xsdbool( efr-required = 'X' ). fv_regex = efr-regex.
        fv_minlen = efr-min_len. fv_maxlen = efr-max_len. fv_minval = efr-min_val. fv_maxval = efr-max_val.
        fv_msg = efr-msg. fv_tech = efr-tech_name. fv_roll = efr-rollname. fv_shlp = efr-shlp.
        fv_attach = xsdbool( efr-has_attach = 'X' ). fv_attlabel = efr-attach_label.
        fv_atttypes = efr-attach_types. fv_attmaxmb = efr-attach_maxmb.
        fv_attmulti = xsdbool( efr-attach_multi = 'X' ).
        fv_label_ar = efr-label_ar. fv_place_ar = efr-place_ar. fv_msg_ar = efr-msg_ar.
        mv_msg = |Editing field { efr-step_id }/{ efr-field_name } — change values, then Add / update field|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 5 AND substring( val = ev len = 5 ) = 'DFLD_'.
      SPLIT substring( val = ev off = 5 ) AT '~' INTO DATA(lv_dfs) DATA(lv_dff).
      READ TABLE mt_fields INTO DATA(dfr)
        WITH KEY step_id = to_upper( lv_dfs ) field_name = to_upper( lv_dff ).
      IF sy-subrc = 0.
        fv_step = dfr-step_id. fv_field = |{ dfr-field_name }2|. fv_type = dfr-ftype.
        fv_label = dfr-label. fv_place = dfr-placeholder. fv_default = dfr-default_val.
        fv_group = dfr-fgroup. fv_sect = dfr-section. fv_state = dfr-fstate. fv_width = dfr-width.
        fv_hidden = xsdbool( dfr-hidden = 'X' ). fv_readonly = xsdbool( dfr-readonly = 'X' ).
        fv_req = xsdbool( dfr-required = 'X' ). fv_regex = dfr-regex.
        fv_minlen = dfr-min_len. fv_maxlen = dfr-max_len. fv_minval = dfr-min_val. fv_maxval = dfr-max_val.
        fv_msg = dfr-msg. fv_tech = dfr-tech_name. fv_roll = dfr-rollname. fv_shlp = dfr-shlp.
        fv_attach = xsdbool( dfr-has_attach = 'X' ). fv_attlabel = dfr-attach_label.
        fv_atttypes = dfr-attach_types. fv_attmaxmb = dfr-attach_maxmb.
        fv_attmulti = xsdbool( dfr-attach_multi = 'X' ).
        fv_label_ar = dfr-label_ar. fv_place_ar = dfr-place_ar. fv_msg_ar = dfr-msg_ar.
        CLEAR fv_seq.
        mv_msg = |Duplicated { dfr-field_name } → rename '{ fv_field }' and Add / update field|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 5 AND substring( val = ev len = 5 ) = 'XFLD_'.
      SPLIT substring( val = ev off = 5 ) AT '~' INTO DATA(lv_xfs) DATA(lv_xff).
      DELETE mt_fields WHERE step_id = to_upper( lv_xfs ) AND field_name = to_upper( lv_xff ).

    ELSEIF strlen( ev ) > 5 AND substring( val = ev len = 5 ) = 'EOPT_'.
      SPLIT substring( val = ev off = 5 ) AT '~' INTO DATA(lv_eos) DATA(lv_eof) DATA(lv_eok).
      READ TABLE mt_opts INTO DATA(eor)
        WITH KEY step_id = to_upper( lv_eos ) field_name = to_upper( lv_eof ) opt_key = lv_eok.
      IF sy-subrc = 0.
        ov_seq = eor-seqnr. ov_step = eor-step_id. ov_field = eor-field_name.
        ov_key = eor-opt_key. ov_text = eor-opt_text.
        mv_msg = |Editing option { eor-opt_key } — change values, then Add / update option|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 5 AND substring( val = ev len = 5 ) = 'XOPT_'.
      SPLIT substring( val = ev off = 5 ) AT '~' INTO DATA(lv_xos) DATA(lv_xof) DATA(lv_xok).
      DELETE mt_opts WHERE step_id = to_upper( lv_xos ) AND field_name = to_upper( lv_xof ) AND opt_key = lv_xok.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'ERULE_'.
      DATA(lv_er) = to_upper( substring( val = ev off = 6 ) ).
      READ TABLE mt_rules INTO DATA(err) WITH KEY rule_id = lv_er.
      IF sy-subrc = 0.
        rv_id = err-rule_id. rv_src = err-src_field. rv_op = err-src_op. rv_srcval = err-src_value.
        rv_action = err-action. rv_tgt = err-tgt_field. rv_tgtval = err-tgt_value. rv_totable = err-totable.
        mv_msg = |Editing rule { lv_er } — change values, then Add / update rule|. mv_mtype = 'Information'.
      ENDIF.

    ELSEIF strlen( ev ) > 6 AND substring( val = ev len = 6 ) = 'XRULE_'.
      DELETE mt_rules WHERE rule_id = to_upper( substring( val = ev off = 6 ) ).

    ELSE.
      CASE ev.
        WHEN 'LOAD'. load_journey( ).
        WHEN 'NEW'.  new_journey( ).
        WHEN 'SAVE'. save_journey( ).
        WHEN 'COPY'. copy_journey( ).

        WHEN 'CLR_STEP'. CLEAR: sv_seq, sv_step, sv_title, sv_icon, sv_bknd.
        WHEN 'CLR_FLD'.  clear_field_form( ).
        WHEN 'CLR_OPT'.  CLEAR: ov_seq, ov_key, ov_text.
        WHEN 'CLR_RULE'. clear_rule_form( ).

        WHEN 'ADD_STEP'.
          IF sv_step IS NOT INITIAL.
            READ TABLE mt_steps ASSIGNING FIELD-SYMBOL(<s>) WITH KEY step_id = to_upper( sv_step ).
            IF sy-subrc <> 0.
              APPEND INITIAL LINE TO mt_steps ASSIGNING <s>.
            ENDIF.
            <s> = VALUE #( seqnr = sv_seq step_id = to_upper( sv_step ) title = sv_title
                           icon = sv_icon bknd_screen = to_upper( sv_bknd ) ).
            SORT mt_steps BY seqnr.
            CLEAR: sv_seq, sv_step, sv_title, sv_icon, sv_bknd.
          ENDIF.

        WHEN 'ADD_FLD'.
          IF fv_step IS NOT INITIAL AND fv_field IS NOT INITIAL.
            READ TABLE mt_fields ASSIGNING FIELD-SYMBOL(<f>)
              WITH KEY step_id = to_upper( fv_step ) field_name = to_upper( fv_field ).
            IF sy-subrc <> 0.
              APPEND INITIAL LINE TO mt_fields ASSIGNING <f>.
            ENDIF.
            DATA(lv_fseq) = COND string( WHEN fv_seq IS NOT INITIAL THEN fv_seq ELSE next_fseq( fv_step ) ).
            <f> = VALUE #( seqnr = lv_fseq step_id = to_upper( fv_step ) field_name = to_upper( fv_field )
                           ftype = to_upper( fv_type ) label = fv_label placeholder = fv_place default_val = fv_default
                           fgroup = fv_group section = fv_sect fstate = fv_state width = fv_width
                           hidden   = COND #( WHEN fv_hidden   = abap_true THEN 'X' ELSE '' )
                           readonly = COND #( WHEN fv_readonly = abap_true THEN 'X' ELSE '' )
                           required = COND #( WHEN fv_req      = abap_true THEN 'X' ELSE '' )
                           regex = fv_regex min_len = fv_minlen max_len = fv_maxlen
                           min_val = fv_minval max_val = fv_maxval msg = fv_msg
                           has_attach = COND #( WHEN fv_attach = abap_true THEN 'X' ELSE '' )
                           attach_label = fv_attlabel attach_types = fv_atttypes attach_maxmb = fv_attmaxmb
                           attach_multi = COND #( WHEN fv_attmulti = abap_true THEN 'X' ELSE '' )
                           tech_name = to_upper( fv_tech ) rollname = to_upper( fv_roll ) shlp = to_upper( fv_shlp )
                           label_ar = fv_label_ar place_ar = fv_place_ar msg_ar = fv_msg_ar ).
            SORT mt_fields BY step_id seqnr.
            clear_field_form( ).
          ENDIF.

        WHEN 'ADD_OPT'.
          IF ov_step IS NOT INITIAL AND ov_field IS NOT INITIAL AND ov_key IS NOT INITIAL.
            READ TABLE mt_opts ASSIGNING FIELD-SYMBOL(<o>)
              WITH KEY step_id = to_upper( ov_step ) field_name = to_upper( ov_field ) opt_key = ov_key.
            IF sy-subrc <> 0.
              APPEND INITIAL LINE TO mt_opts ASSIGNING <o>.
            ENDIF.
            DATA(lv_oseq) = COND string( WHEN ov_seq IS NOT INITIAL THEN ov_seq
                                         ELSE next_oseq( iv_step = ov_step iv_field = ov_field ) ).
            <o> = VALUE #( seqnr = lv_oseq step_id = to_upper( ov_step ) field_name = to_upper( ov_field )
                           opt_key = ov_key opt_text = ov_text ).
            SORT mt_opts BY step_id field_name seqnr.
            CLEAR: ov_seq, ov_key, ov_text.
          ENDIF.

        WHEN 'ADD_RULE'.
          IF rv_src IS NOT INITIAL AND rv_action IS NOT INITIAL.
            DATA(lv_rid) = COND string( WHEN rv_id IS NOT INITIAL THEN to_upper( rv_id ) ELSE next_ruleid( ) ).
            READ TABLE mt_rules ASSIGNING FIELD-SYMBOL(<r>) WITH KEY rule_id = lv_rid.
            IF sy-subrc <> 0.
              APPEND INITIAL LINE TO mt_rules ASSIGNING <r>.
            ENDIF.
            <r> = VALUE #( rule_id = lv_rid src_field = to_upper( rv_src ) src_op = rv_op src_value = rv_srcval
                           action = rv_action tgt_field = to_upper( rv_tgt ) tgt_value = rv_tgtval totable = rv_totable ).
            SORT mt_rules BY rule_id.
            clear_rule_form( ).
          ELSE.
            mv_msg = 'A rule needs at least a source field and an action'. mv_mtype = 'Warning'.
          ENDIF.
      ENDCASE.
    ENDIF.

    render( ).
  ENDMETHOD.
ENDCLASS.
