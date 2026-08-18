CLASS zcl_rak_journey_grid DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
*   EDITABLE_TABLE: column spec, row add/delete, the SEL: selection directive,
*   JSON round trip and the renderer.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

    METHODS grid_cols     IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                          RETURNING VALUE(rt) TYPE zif_rak_cjs_types=>tt_gcol.
    METHODS grid_check     IMPORTING iv_field     TYPE string
                           EXPORTING et_cols      TYPE zif_rak_cjs_types=>tt_gcol
                           RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS grid_add      IMPORTING iv_field TYPE string.
    METHODS grid_del      IMPORTING iv_field TYPE string
                                    iv_uid   TYPE string.
    METHODS grid_to_json  IMPORTING iv_field  TYPE string
                          RETURNING VALUE(rv) TYPE string.
    METHODS grid_from_json IMPORTING iv_field TYPE string
                                     iv_json  TYPE string.
*   FIX in the spec - a directive, like SEL:, not a column. Fixed rows: the Add
*   button and the per-row Delete are not drawn, and the cells stay editable.
*
*   Not the same thing as READONLY, which is why it is a second switch and not a
*   mode of the first. READONLY takes away the chrome AND the controls; FIX takes
*   away only the chrome. A fee matrix is exactly the gap between them - the three
*   rows are given, the numbers in them are the whole point.
    METHODS grid_fix     IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                         RETURNING VALUE(rv) TYPE abap_bool.
    METHODS grid_sel     IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                         EXPORTING ev_mode   TYPE string
                                   ev_target TYPE string.
    METHODS grid_sel_sync    IMPORTING is_field TYPE zif_rak_journey=>ty_field.
    METHODS grid_sel_pick    IMPORTING iv_field TYPE string
                                       iv_uid   TYPE string.
    METHODS grid_sel_collect IMPORTING iv_field TYPE string.
    METHODS grid_react   IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                         RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.
    METHODS grid_index   IMPORTING iv_field  TYPE string
                                   iv_uid    TYPE string
                         RETURNING VALUE(rv) TYPE i.
    METHODS render_grid   IMPORTING io_parent TYPE REF TO z2ui5_cl_xml_view
                                    is_field  TYPE zif_rak_journey=>ty_field.

  PRIVATE SECTION.
    DATA mo_e TYPE REF TO zcl_rak_journey_engine.

*   ZRAK_T_JNY_COL support. Additive only: a grid with no rows there falls
*   straight back to the DEFAULT_VAL parse above, unchanged.
    METHODS col_rows_of  IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                         RETURNING VALUE(rt) TYPE zif_rak_cjs_types=>tt_gcol.
    METHODS step_id_of   IMPORTING iv_field  TYPE string
                         RETURNING VALUE(rv) TYPE string.
    METHODS apply_grid_rules IMPORTING iv_grid TYPE string
                             CHANGING  ct_gc   TYPE zif_rak_cjs_types=>tt_gcol.
    METHODS row_hit_expr IMPORTING iv_field  TYPE string
                                   iv_op     TYPE string
                                   iv_value  TYPE string
                         RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_GRID IMPLEMENTATION.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD grid_add.
*   A read-only grid draws no Add button, but the event can still arrive from a
*   stale page. Refusing it here means the render and the handler agree on one
*   rule rather than two.
*
*   FIX is refused for the same reason and it is not optional politeness: a grid
*   whose rows are given by the domain must not gain a fourth one because a stale
*   tab still had the button on it. Not drawing a button is a rendering decision;
*   this is where the rule lives.
    DATA(ls_gaf) = mo_e->safe_field( iv_field ).
    IF ls_gaf-readonly = abap_true OR grid_fix( ls_gaf ) = abap_true.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    APPEND INITIAL LINE TO <t> ASSIGNING FIELD-SYMBOL(<row>).
    ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
    IF sy-subrc = 0.
      TRY.
          <uid> = cl_system_uuid=>create_uuid_c32_static( ).
        CATCH cx_uuid_error.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD grid_check.
*   Every precondition a grid read or write depends on, checked once, and each
*   failure named. The four public grid methods used to return silently on all
*   of them, so a caller whose field was misspelt, was not an EDITABLE_TABLE, or
*   had no column spec got "nothing happened" and no way to tell which.
*
*   Deliberately NOT called from grid_from_json( ) itself: the engine calls that
*   internally to clear a grid and to restore one from a KV value, where a
*   message would be noise.
    CLEAR et_cols.

    DATA(ls_fld) = mo_e->safe_field( iv_field ).
    IF ls_fld-name IS INITIAL.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: no field with that name in this journey's configuration.| ) ).
      RETURN.
    ENDIF.

    IF to_upper( ls_fld-type ) <> 'EDITABLE_TABLE'.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: FTYPE is { ls_fld-type }, not EDITABLE_TABLE. Only an editable grid has rows to read or write.| ) ).
      RETURN.
    ENDIF.

    et_cols = grid_cols( ls_fld ).
    IF et_cols IS INITIAL.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: DEFAULT_VAL carries no column spec. Expected name:label:type, pipe separated.| ) ).
      RETURN.
    ENDIF.

*   The model component is created by mo_e->build_model( ) only for a field whose type
*   is EDITABLE_TABLE. If the type was changed after the model was built, or the
*   spec was empty at build time, the component is missing or is not a table -
*   and both are invisible to the caller without this.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    IF sy-subrc <> 0.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: the model does not exist yet. Call this from on_init or later, not from the constructor.| ) ).
      CLEAR et_cols.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT to_upper( ls_fld-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: no model member. The journey was loaded before the field became an EDITABLE_TABLE - reload it.| ) ).
      CLEAR et_cols.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      mo_e->mt_msg = VALUE #( BASE mo_e->mt_msg ( type = 'Warning'
        text = |Grid { iv_field }: the model member is not a table. { ls_fld-name } is in use by another control type.| ) ).
      CLEAR et_cols.
      RETURN.
    ENDIF.

    rv_ok = abap_true.
  ENDMETHOD.


  METHOD grid_cols.
*   ZRAK_T_JNY_COL first. A grid with rows there is fully migrated off the
*   packed spec; a grid with none falls straight through to the DEFAULT_VAL
*   parse below exactly as it always has - nothing already delivered through
*   DEFAULT_VAL changes.
    rt = col_rows_of( is_field ).
    IF rt IS NOT INITIAL.
      apply_grid_rules( EXPORTING iv_grid = to_upper( is_field-name )
                         CHANGING  ct_gc   = rt ).
      RETURN.
    ENDIF.

    DATA(spec) = is_field-default.
    IF spec IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT spec AT '|' INTO TABLE DATA(lt_c).
    LOOP AT lt_c INTO DATA(lv_c).
      DATA(lv_cc) = condense( lv_c ).
      IF lv_cc IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_cc AT ':' INTO DATA(lv_n) DATA(lv_l) DATA(lv_t) DATA(lv_s).
      DATA(lv_nn) = condense( lv_n ).
      DATA(lv_ll) = condense( lv_l ).
      DATA(lv_tt) = condense( lv_t ).
      DATA(lv_ss) = condense( lv_s ).
      IF lv_nn IS INITIAL.
        CONTINUE.
      ENDIF.
*     SEL: is a directive, not a column. Skipped here so every caller - the model
*     builder, the renderer, the BAdI payload, get/set_grid_data - keeps seeing
*     only real columns and needs no change. grid_sel( ) reads it instead.
      IF to_upper( lv_nn ) = 'SEL'.
        CONTINUE.
      ENDIF.
*     FIX is the other directive. Same reason it is skipped: it is not a column and
*     a column called FIX would be drawn, bound and posted.
      IF to_upper( lv_nn ) = 'FIX'.
        CONTINUE.
      ENDIF.
      IF to_upper( lv_nn ) = 'RX'.
        CONTINUE.
      ENDIF.
*     HIDE in the TYPE slot is the opposite of SEL: not skipped, flagged. The
*     column stays in this list and therefore stays in the model, in the JSON and
*     in the BAdI payload - it simply is not drawn. Skipping it the way SEL is
*     skipped would delete the data too, and the columns anybody wants hidden are
*     exactly the ones the backend needs back: the row key, a type code, a
*     sequence number.
*
*     A hidden column needs no control, so the real type is not kept. INPUT is
*     recorded so that anything downstream reading ctype still gets a valid value,
*     and turning the column back on is a one-word edit.
      DATA(lv_up) = to_upper( lv_tt ).
      DATA(lv_hid) = xsdbool( lv_up = 'HIDE' OR lv_up = 'HIDDEN' ).
      APPEND VALUE #(
        name  = to_upper( lv_nn )
        label = COND #( WHEN lv_ll IS NOT INITIAL THEN lv_ll ELSE lv_nn )
        ctype = COND #( WHEN lv_hid = abap_true    THEN 'INPUT'
                        WHEN lv_up  IS NOT INITIAL THEN lv_up
                        ELSE 'INPUT' )
        hide  = lv_hid
        src   = to_upper( lv_ss ) ) TO rt.
    ENDLOOP.

    apply_grid_rules( EXPORTING iv_grid = to_upper( is_field-name )
                       CHANGING  ct_gc   = rt ).
  ENDMETHOD.


  METHOD col_rows_of.
    DATA(lv_step) = step_id_of( to_upper( is_field-name ) ).
    IF lv_step IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zrak_t_jny_col
      INTO TABLE @DATA(lt_col)
      WHERE journey_id = @mo_e->mv_journey
        AND step_id    = @lv_step
        AND field_name = @to_upper( is_field-name )
      ORDER BY seqnr.

    LOOP AT lt_col INTO DATA(ls_col).
      APPEND VALUE #(
        name     = to_upper( ls_col-col_name )
        label    = COND #( WHEN ls_col-zlabel IS NOT INITIAL THEN ls_col-zlabel ELSE ls_col-col_name )
        label_ar = ls_col-zlabel_ar
        ctype    = COND #( WHEN ls_col-ctrl IS NOT INITIAL THEN to_upper( ls_col-ctrl ) ELSE 'INPUT' )
        src      = to_upper( ls_col-rollname )
        shlp     = to_upper( ls_col-shlp )
        width    = ls_col-width
        align    = ls_col-align
        hide     = xsdbool( ls_col-hidden   = abap_true )
        pinned   = xsdbool( ls_col-pinned   = abap_true )
        readonly = xsdbool( ls_col-readonly = abap_true )
        required = xsdbool( ls_col-required = abap_true )
        decimals = ls_col-decimals
        maxlen   = ls_col-maxlen
        total    = xsdbool( ls_col-total    = abap_true )
      ) TO rt.
    ENDLOOP.
  ENDMETHOD.


* Which step a field belongs to. ZIF_RAK_JOURNEY carries no STEP_ID on a
* field itself - only on the step that holds it - so this recovers it from
* MS_CONFIG-STEPS. Checks the step currently being rendered first (right for
* WIZARD/WIZARD_LEFT/SINGLE, and for whichever step TABS/ACCORDION are
* drawing at the moment this is called); falls back to a full scan for the
* other steps TABS/ACCORDION draw in the same pass. Assumes field names are
* unique within a journey, same as SAFE_FIELD elsewhere in the engine.
  METHOD step_id_of.
    DATA(lv_f) = to_upper( iv_field ).

    READ TABLE mo_e->ms_config-steps INTO DATA(ls_s) INDEX mo_e->mv_step + 1.
    IF sy-subrc = 0.
      LOOP AT ls_s-fields INTO DATA(ls_f1) WHERE name = lv_f.
        rv = ls_s-step_id.
        RETURN.
      ENDLOOP.
    ENDIF.

    LOOP AT mo_e->ms_config-steps INTO ls_s.
      LOOP AT ls_s-fields INTO DATA(ls_f2) WHERE name = lv_f.
        rv = ls_s-step_id.
        RETURN.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


* ZRAK_T_JNY_RULE rows whose TOTABLE names this grid (ZCL_RAK_JOURNEY_RULES
* has already sorted every such row into MO_E->MT_RULEGRID instead of
* evaluating it as a scalar field rule). Two shapes, told apart by whether
* SRC_FIELD is itself one of this grid's own columns:
*
*   SRC_FIELD is another column of the SAME grid -> per row. No server-side
*   loop over rows is needed: the row template is bound once, so a native UI5
*   expression binding on the cell's VISIBLE/EDITABLE evaluates independently
*   for every row on the client.
*
*   SRC_FIELD is anything else (an ordinary field) -> whole column, evaluated
*   once here via VAL_GET, same comparison EVAL_RULES uses for a scalar rule.
*
* Supported actions: HIDE, SHOW, READONLY, EDITABLE. REQUIRE / OPTIONAL / SET
* / CLEAR are not meaningful per column and are ignored here, same as they
* are for anything but a plain field today.
  METHOD apply_grid_rules.
    DATA lt_r TYPE zif_rak_cjs_types=>tt_gridrule.
    LOOP AT mo_e->mt_rulegrid INTO DATA(ls_gr) WHERE totable = iv_grid.
      APPEND ls_gr TO lt_r.
    ENDLOOP.
    IF lt_r IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_names) = VALUE string_table( FOR gc IN ct_gc ( gc-name ) ).

    LOOP AT lt_r INTO DATA(ls_r).
      READ TABLE ct_gc ASSIGNING FIELD-SYMBOL(<gc>) WITH KEY name = ls_r-tgt_field.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      IF line_exists( lt_names[ table_line = ls_r-src_field ] ).
        DATA(lv_hit) = row_hit_expr( iv_field = ls_r-src_field
                                     iv_op    = ls_r-src_op
                                     iv_value = ls_r-src_value ).
        CASE ls_r-action.
          WHEN 'HIDE'.
            <gc>-row_vis  = `{= !(` && lv_hit && `) }`.
          WHEN 'SHOW'.
            <gc>-row_vis  = `{= ` && lv_hit && ` }`.
          WHEN 'READONLY'.
            <gc>-row_edit = `{= !(` && lv_hit && `) }`.
          WHEN 'EDITABLE'.
            <gc>-row_edit = `{= ` && lv_hit && ` }`.
        ENDCASE.
        CONTINUE.
      ENDIF.

      DATA(lv_val) = mo_e->val_get( ls_r-src_field ).
      DATA(lv_ok) = COND abap_bool(
        WHEN ls_r-src_op = 'EQ'         THEN xsdbool( lv_val = ls_r-src_value )
        WHEN ls_r-src_op = 'NE'         THEN xsdbool( lv_val <> ls_r-src_value )
        WHEN ls_r-src_op = 'INITIAL'    THEN xsdbool( lv_val IS INITIAL )
        WHEN ls_r-src_op = 'NOTINITIAL' THEN xsdbool( lv_val IS NOT INITIAL )
        ELSE abap_false ).
      IF lv_ok = abap_false.
        CONTINUE.
      ENDIF.

      CASE ls_r-action.
        WHEN 'HIDE'.
          <gc>-hide     = abap_true.
        WHEN 'SHOW'.
          <gc>-hide     = abap_false.
        WHEN 'READONLY'.
          <gc>-readonly = abap_true.
        WHEN 'EDITABLE'.
          <gc>-readonly = abap_false.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD row_hit_expr.
    DATA(lv_v) = replace( val = iv_value sub = `'` with = `\'` occ = 0 ).
    CASE iv_op.
      WHEN 'EQ'.
        rv = `${` && iv_field && `} === '` && lv_v && `'`.
      WHEN 'NE'.
        rv = `${` && iv_field && `} !== '` && lv_v && `'`.
      WHEN 'INITIAL'.
        rv = `${` && iv_field && `} === ''`.
      WHEN 'NOTINITIAL'.
        rv = `${` && iv_field && `} !== ''`.
      WHEN OTHERS.
        rv = `false`.
    ENDCASE.
  ENDMETHOD.


  METHOD grid_del.
*   Same rule, same reason as grid_add. The per-row Delete is not drawn on a
*   read-only or a fixed grid, and neither is a place to enforce anything - a
*   GRIDDEL event from a stale page would otherwise remove a row the domain says
*   is always there, and the citizen would have no way to put it back.
    DATA(ls_gdf) = mo_e->safe_field( iv_field ).
    IF ls_gdf-readonly = abap_true OR grid_fix( ls_gdf ) = abap_true.
      RETURN.
    ENDIF.
    IF iv_uid IS INITIAL.
      RETURN.
    ENDIF.
    IF mo_e->safe_field( iv_field )-readonly = abap_true.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      DATA(lv_ix) = sy-tabix.
      ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
      IF sy-subrc = 0 AND <uid> = iv_uid.
        DELETE <t> INDEX lv_ix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_fix.
*   Presence is the whole switch. FIX and FIX:X both mean the same thing, because
*   there is no second setting for it to carry and an author writing FIX:X should
*   not get a column called FIX for their trouble.
    IF is_field-default IS INITIAL.
      RETURN.
    ENDIF.

    SPLIT is_field-default AT '|' INTO TABLE DATA(lt_c).
    LOOP AT lt_c INTO DATA(lv_c).
      SPLIT condense( lv_c ) AT ':' INTO DATA(lv_a) DATA(lv_rest).
      IF to_upper( condense( lv_a ) ) = 'FIX'.
        rv = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_from_json.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    CLEAR <t>.
    IF iv_json IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = iv_json CHANGING data = <t> ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
      IF sy-subrc = 0 AND <uid> IS INITIAL.
        TRY.
            <uid> = cl_system_uuid=>create_uuid_c32_static( ).
          CATCH cx_uuid_error.
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_index.
    IF iv_uid IS INITIAL.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT to_upper( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      DATA(lv_ix) = sy-tabix.
      ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
      IF sy-subrc = 0 AND <uid> = iv_uid.
        rv = lv_ix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_react.
    DATA(spec) = is_field-default.
    IF spec IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT spec AT '|' INTO TABLE DATA(lt_r).
    LOOP AT lt_r INTO DATA(lv_r).
      DATA(lv_rc) = condense( lv_r ).
      IF lv_rc IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_rc AT ':' INTO DATA(lv_rk) DATA(lv_rv).
      IF to_upper( condense( lv_rk ) ) <> 'RX'.
        CONTINUE.
      ENDIF.
      SPLIT lv_rv AT ',' INTO TABLE DATA(lt_rn).
      LOOP AT lt_rn INTO DATA(lv_rn).
        DATA(lv_rnn) = to_upper( condense( lv_rn ) ).
        IF lv_rnn IS NOT INITIAL.
          APPEND lv_rnn TO rt.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_sel.
    CLEAR ev_mode.
    CLEAR ev_target.
    IF is_field-default IS INITIAL.
      RETURN.
    ENDIF.

    SPLIT is_field-default AT '|' INTO TABLE DATA(lt_c).
    LOOP AT lt_c INTO DATA(lv_c).
      SPLIT condense( lv_c ) AT ':' INTO DATA(lv_a) DATA(lv_b) DATA(lv_d).
      IF to_upper( condense( lv_a ) ) <> 'SEL'.
        CONTINUE.
      ENDIF.
      DATA(lv_m) = to_upper( condense( lv_b ) ).
      IF lv_m <> 'SINGLE' AND lv_m <> 'MULTI'.
        RETURN.
      ENDIF.
      ev_mode   = lv_m.
      ev_target = to_upper( condense( lv_d ) ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_sel_collect.
    DATA(ls_f) = mo_e->safe_field( iv_field ).
    grid_sel( EXPORTING is_field = ls_f
              IMPORTING ev_mode = DATA(lv_mode) ev_target = DATA(lv_tgt) ).
    IF lv_mode IS INITIAL OR lv_tgt IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_gc) = grid_cols( ls_f ).
    IF lt_gc IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_key) = lt_gc[ 1 ]-name.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( ls_f-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lv_out TYPE string.
    DATA lv_cell TYPE string.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      ASSIGN COMPONENT '_SEL' OF STRUCTURE <row> TO FIELD-SYMBOL(<sel>).
      IF sy-subrc <> 0 OR <sel> IS INITIAL.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT lv_key OF STRUCTURE <row> TO FIELD-SYMBOL(<k>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      lv_cell = <k>.
      CONDENSE lv_cell.
      lv_out = COND string( WHEN lv_out IS INITIAL THEN lv_cell ELSE |{ lv_out },{ lv_cell }| ).
      IF lv_mode = 'SINGLE'.
        EXIT.
      ENDIF.
    ENDLOOP.

*   Column 1 is the key, the same convention TABLE and RECORDCARD already use, so
*   there is no new rule for an author to learn.
    mo_e->val_set( iv_name = lv_tgt iv_value = lv_out ).
  ENDMETHOD.


  METHOD grid_sel_pick.
    DATA(ls_f) = mo_e->safe_field( iv_field ).
    grid_sel( EXPORTING is_field = ls_f IMPORTING ev_mode = DATA(lv_mode) ).
    IF lv_mode IS INITIAL.
      RETURN.
    ENDIF.

*   SINGLE is enforced here rather than by the control. A checkbox is used for both
*   modes because radio_button inside a bound row template needs a groupName the
*   wrapper does not expose in this z2ui5 version, and a half-working radio is
*   worse than a checkbox that behaves correctly. The clicked row wins and every
*   other row is cleared, which is why the row uid is carried on the event.
    IF lv_mode = 'SINGLE'.
      FIELD-SYMBOLS <model> TYPE any.
      ASSIGN mo_e->mr_model->* TO <model>.
      ASSIGN COMPONENT to_upper( ls_f-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
      IF sy-subrc = 0.
        FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
        ASSIGN <tab> TO <t>.
        IF sy-subrc = 0.
          LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
            ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.
            ASSIGN COMPONENT '_SEL' OF STRUCTURE <row> TO FIELD-SYMBOL(<sel>).
            IF sy-subrc <> 0.
              CONTINUE.
            ENDIF.
            <sel> = xsdbool( <uid> = iv_uid ).
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.

    grid_sel_collect( ls_f-name ).
  ENDMETHOD.


  METHOD grid_sel_sync.
    grid_sel( EXPORTING is_field = is_field
              IMPORTING ev_mode = DATA(lv_mode) ev_target = DATA(lv_tgt) ).
    IF lv_mode IS INITIAL OR lv_tgt IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_gc) = grid_cols( is_field ).
    IF lt_gc IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_key) = lt_gc[ 1 ]-name.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( is_field-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   The target field is the source of truth on the way IN, so a value put there by
*   a backend read, a rule or set_val( ) shows as a tick without the handler
*   knowing anything about _SEL.
    SPLIT mo_e->val_get( lv_tgt ) AT ',' INTO TABLE DATA(lt_want).
    LOOP AT lt_want ASSIGNING FIELD-SYMBOL(<w>).
      <w> = condense( <w> ).
    ENDLOOP.
    DELETE lt_want WHERE table_line IS INITIAL.

    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      ASSIGN COMPONENT '_SEL' OF STRUCTURE <row> TO FIELD-SYMBOL(<sel>).
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      ASSIGN COMPONENT lv_key OF STRUCTURE <row> TO FIELD-SYMBOL(<k>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA lv_k TYPE string.
      lv_k = <k>.
      <sel> = xsdbool( line_exists( lt_want[ table_line = condense( lv_k ) ] ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD grid_to_json.
    DATA(ls_fld) = mo_e->safe_field( iv_field ).
    DATA(lt_gc)  = grid_cols( ls_fld ).
    IF lt_gc IS INITIAL.
      RETURN.
    ENDIF.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_obj TYPE string_table.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      DATA lv_pairs TYPE string.
      CLEAR lv_pairs.
      LOOP AT lt_gc INTO DATA(gc).
        ASSIGN COMPONENT gc-name OF STRUCTURE <row> TO FIELD-SYMBOL(<c>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        DATA(lv_v) = escape( val = CONV string( <c> ) format = cl_abap_format=>e_json_string ).
        DATA(lv_kv) = |"{ gc-name }":"{ lv_v }"|.
        lv_pairs = COND #( WHEN lv_pairs IS INITIAL THEN lv_kv ELSE |{ lv_pairs },{ lv_kv }| ).
      ENDLOOP.
      APPEND |\{{ lv_pairs }\}| TO lt_obj.
    ENDLOOP.
    rv = |[{ concat_lines_of( table = lt_obj sep = `,` ) }]|.
  ENDMETHOD.


  METHOD render_grid.
    io_parent->title( text = zcl_rak_journey_util=>esc( is_field-label ) class = 'rakBlkTitle' ).

    DATA(lt_gc) = grid_cols( is_field ).
    IF lt_gc IS INITIAL.
      io_parent->message_strip(
        text     = |{ is_field-label }: no columns. Set Default value to name:label:type\|... in the Studio.|
        type     = 'Warning'
        showicon = abap_true
        class    = 'sapUiSmallMargin' ).
      RETURN.
    ENDIF.

*   READONLY turns the grid into a display table: no Add, no per-row Delete, and
*   cells drawn as text instead of controls. Same field type, same column spec,
*   same model rows, same route to the BAdI - only the rendering differs. It is
*   the cheap way to get a config-declared, model-backed display table without
*   collapsing the four block render paths into one.
    DATA(lv_ro) = mo_e->mo_rules->is_readonly( is_field ).

*   FIX is the other half of that. READONLY answers "may the citizen type in the
*   cells"; FIX answers "may the citizen change WHICH ROWS there are". They were
*   one answer, which left no way to express the commonest shape of all - a matrix
*   whose rows are given by the domain and whose cells are the entire question.
*   The three fee lines on a school licence are not the citizen's to add or delete;
*   the amounts are the only thing being asked for.
*
*   A FIX grid draws nothing until something seeds its rows. That is on_change or a
*   backend read, and a FIX grid nobody seeds is an empty table - worth a lint rule,
*   not a runtime guess about what the rows should have been.
    DATA(lv_chrome) = xsdbool( lv_ro = abap_false AND grid_fix( is_field ) = abap_false ).

*   Reflect the target field into _SEL before drawing, so a pick that arrived from
*   a backend read, a SET rule or set_val( ) shows as a tick.
    grid_sel( EXPORTING is_field = is_field
              IMPORTING ev_mode = DATA(lv_selmode) ev_target = DATA(lv_seltgt) ).
    IF lv_selmode IS NOT INITIAL.
      grid_sel_sync( is_field ).
    ENDIF.

    DATA(lo_box) = io_parent->vbox( class = 'rakSearch' ).
    IF lv_chrome = abap_true.
      DATA(lo_bar) = lo_box->hbox( justifycontent = 'End' alignitems = 'Center' ).
      lo_bar->button(
        text  = COND #( WHEN is_field-attach_label IS NOT INITIAL THEN is_field-attach_label ELSE |Add { is_field-label }| )
        icon  = 'sap-icon://add'
        type  = 'Emphasized'
        press = mo_e->mo_client->_event( |GRIDADD_{ is_field-name }| ) ).
    ENDIF.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mo_e->mr_model->* TO <model>.
    ASSIGN COMPONENT to_upper( is_field-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   TOTAL columns are summed once, server-side, from the bound row table
*   itself. sap.m.Table has no per-column footer cell to bind a running sum
*   to, so this shows as one line under the grid rather than aligned under
*   its own column - the closest honest fit the control allows.
    DATA lt_total_cols TYPE zif_rak_cjs_types=>tt_gcol.
    LOOP AT lt_gc INTO DATA(ls_totcol) WHERE total = abap_true.
      APPEND ls_totcol TO lt_total_cols.
    ENDLOOP.
    DATA lv_footer TYPE string.
    IF lt_total_cols IS NOT INITIAL.
      DATA lt_parts TYPE string_table.
      LOOP AT lt_total_cols INTO DATA(gt).
        DATA(lv_sum) = CONV decfloat34( 0 ).
        LOOP AT <tab> ASSIGNING FIELD-SYMBOL(<trow>).
          ASSIGN COMPONENT gt-name OF STRUCTURE <trow> TO FIELD-SYMBOL(<tcell>).
          CHECK sy-subrc = 0.
          TRY.
              lv_sum = lv_sum + CONV decfloat34( <tcell> ).
            CATCH cx_root.
          ENDTRY.
        ENDLOOP.
        APPEND |{ gt-label }: { lv_sum }| TO lt_parts.
      ENDLOOP.
      lv_footer = concat_lines_of( table = lt_parts sep = `   |   ` ).
    ENDIF.

    DATA(lo_tab) = lo_box->table( items              = mo_e->mo_client->_bind_edit( <tab> )
                                  alternaterowcolors = abap_true
                                  class              = 'sapUiSmallMarginTop'
                                  footertext         = lv_footer ).
    DATA(lo_cols) = lo_tab->columns( ).
    IF lv_selmode IS NOT INITIAL.
      lo_cols->column( width = '3rem' )->text( `` ).
    ENDIF.
*   Headers and cells are two separate loops over the same list, so a hidden
*   column has to be skipped in BOTH or every column after it shows under the
*   wrong heading. That is the only real hazard in this feature and it is why the
*   test is the same expression in both places.
    LOOP AT lt_gc INTO DATA(gc).
      IF gc-hide = abap_true.
        CONTINUE.
      ENDIF.
      DATA(lv_hdr) = COND string( WHEN mo_e->mv_lang = 'A' AND gc-label_ar IS NOT INITIAL
                                  THEN gc-label_ar ELSE gc-label ).
      lo_cols->column( width = gc-width halign = gc-align )->text( lv_hdr ).
    ENDLOOP.
    IF lv_chrome = abap_true.
      lo_cols->column( width = '4rem' halign = 'End' )->text( `` ).
    ENDIF.

    DATA(lo_cells) = lo_tab->items( )->column_list_item( )->cells( ).
    IF lv_selmode IS NOT INITIAL.
*     One checkbox for both modes. radio_button inside a bound row template needs a
*     groupName this z2ui5 version does not expose, and a half-working radio is
*     worse than a checkbox that behaves correctly - SINGLE is enforced in
*     grid_sel_pick( ), which clears the other rows. The row uid rides the event
*     because the template is one control shared by every row.
      lo_cells->checkbox(
        selected = |\{_SEL\}|
        editable = abap_true
        select   = mo_e->mo_client->_event( val   = |GRIDSEL_{ is_field-name }|
                                     t_arg = VALUE #( ( `${_UID}` ) ) ) ).
    ENDIF.
    DATA(lt_rx) = grid_react( is_field ).
    LOOP AT lt_gc INTO gc.
      IF gc-hide = abap_true.
        CONTINUE.
      ENDIF.
      DATA(lv_path) = |\{{ gc-name }\}|.
      DATA lv_en TYPE string.
      CLEAR lv_en.
      IF line_exists( lt_gc[ name = |{ gc-name }_EN| ] ).
        lv_en = |\{{ gc-name }_EN\}|.
      ELSE.
        lv_en = abap_true.
      ENDIF.
      DATA lv_chg TYPE string.
      CLEAR lv_chg.
      IF line_exists( lt_rx[ table_line = gc-name ] ).
        lv_chg = mo_e->mo_client->_event( val   = |GRIDCHG_{ is_field-name }~{ gc-name }|
                                         t_arg = VALUE #( ( `${_UID}` ) ) ).
      ENDIF.
*     A per-row EDITABLE/READONLY grid rule (ZRAK_T_JNY_RULE, TOTABLE = this
*     grid) overrides the column's own editability - same precedence a
*     scalar field rule has over its field's configured flag.
      IF gc-row_edit IS NOT INITIAL.
        lv_en = gc-row_edit.
      ENDIF.
*     Explicit 'true' rather than a blank VISIBLE for the columns with no
*     per-row rule - blank could as easily be read as false by the control
*     library as "not set", and getting that wrong hides every cell in every
*     grid rather than just the ones a rule actually targets.
      DATA(lv_vis) = COND string( WHEN gc-row_vis IS NOT INITIAL THEN gc-row_vis ELSE 'true' ).
      IF lv_ro = abap_true OR gc-readonly = abap_true.
*       One Text per cell, bound to the same model path the input would have
*       used. A SELECT column therefore shows the stored KEY, not the option
*       text: the cell template is one control for every row, so there is no
*       per-row place to resolve a key to its label. If the label matters, store
*       it in the row alongside the key.
        lo_cells->text( text = lv_path visible = lv_vis ).
        CONTINUE.
      ENDIF.
      CASE gc-ctype.
        WHEN 'TEXT' OR 'DISPLAY'.
*         A label inside an editable grid. The row's own description - School Fee,
*         Books Fee - belongs to the row and not to the citizen, and an input box
*         around it invites them to retype it and then wonder why the fee did not
*         move. Same binding as an input, so it still round-trips and still reaches
*         the backend; it just cannot be edited.
*
*         Deliberately NOT the same as HIDE. Hidden carries a value nobody sees;
*         TEXT shows a value nobody may change.
          lo_cells->text( text = lv_path visible = lv_vis ).
        WHEN 'NUMBER'.
          lo_cells->input( value = lv_path type = 'Number' editable = lv_en change = lv_chg
                           visible = lv_vis maxlength = gc-maxlen ).
        WHEN 'DATE'.
          lo_cells->date_picker( value = lv_path editable = lv_en change = lv_chg visible = lv_vis ).
        WHEN 'CHECKBOX'.
          lo_cells->checkbox( selected = lv_path editable = lv_en select = lv_chg visible = lv_vis ).
        WHEN 'SELECT'.
          DATA lt_copt TYPE zif_rak_journey=>tt_option.
          CLEAR lt_copt.
          IF gc-src IS NOT INITIAL.
            lt_copt = mo_e->mo_render->f4_opts( VALUE #( rollname = gc-src ) ).
          ELSEIF mo_e->mo_logic IS BOUND.
            TRY.
                lt_copt = mo_e->mo_logic->on_value_help( io_ctx = mo_e iv_field = |{ is_field-name }.{ gc-name }| ).
              CATCH cx_root.
                CLEAR lt_copt.
            ENDTRY.
          ENDIF.
*         SHLP is captured on the column but not yet wired to a real search-help
*         popup - a generic F4-by-search-help dialog does not exist anywhere in
*         this framework yet, so building one blind, untested, alongside
*         everything else here would be the least trustworthy part of this
*         change. Options still resolve via ROLLNAME then the handler, same as
*         today; SHLP is there for the day that popup gets built.
          DATA(lo_ccb) = lo_cells->combobox( selectedkey = lv_path
                                             editable    = lv_en
                                             change      = lv_chg
                                             visible     = lv_vis ).
          LOOP AT lt_copt INTO DATA(co).
            lo_ccb->item( key = co-key text = zcl_rak_journey_util=>opt_text( iv_key = co-key iv_text = co-text ) ).
          ENDLOOP.
        WHEN OTHERS.
          lo_cells->input( value = lv_path editable = lv_en change = lv_chg
                           visible = lv_vis maxlength = gc-maxlen ).
      ENDCASE.
    ENDLOOP.
*   The delete column and its button are one column apart in two loops, exactly
*   like the hidden columns above. Suppress one without the other and every cell in
*   the row lands under the wrong heading.
    IF lv_chrome = abap_true.
      lo_cells->button(
        icon  = 'sap-icon://delete'
        type  = 'Transparent'
        press = mo_e->mo_client->_event( val   = |GRIDDEL_{ is_field-name }|
                                   t_arg = VALUE #( ( `${_UID}` ) ) ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
