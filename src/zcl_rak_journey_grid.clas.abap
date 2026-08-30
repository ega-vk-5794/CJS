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

*   Round-6 finding 1. A row that comes to exist OUTSIDE
*   ENGINE~ENSURE_GRID_STATES( )'s own render-time pass - GRID_ADD( )'s
*   fresh row, or every row GRID_FROM_JSON( ) rebuilds from a
*   SET_GRID_DATA( ) payload that only ever carries the configured
*   columns - has its NUMBER/INPUT _VS at the type's technical initial
*   value, blank, same crash ENSURE_GRID_STATES( ) exists to prevent.
*   Same rule: 'None', not blank, and only where genuinely unset.
    METHODS seed_row_states IMPORTING it_gc  TYPE zif_rak_cjs_types=>tt_gcol
                            CHANGING  cs_row TYPE any.
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    seed_row_states( EXPORTING it_gc = grid_cols( ls_gaf ) CHANGING cs_row = <row> ).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( ls_fld-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
*     FIVE slots now, not four: name:label:type:src:label_ar
*
*     The fifth is the ARABIC COLUMN HEADING, and it is the answer to "how do I
*     translate a grid column" for a grid still on this packed spec. Until it
*     existed there was no answer: the renderer reads GC-LABEL_AR when MV_LANG is
*     A, but only COL_ROWS_OF( ) - the ZRAK_T_JNY_COL path - ever filled it, so a
*     DEFAULT_VAL grid showed English headings in an Arabic journey and nothing
*     anywhere said why.
*
*     A SPLIT with FIVE targets, and that matters. ABAP puts the unsplit REMAINDER
*     into the last target, so with four targets a five-part spec put "src:label_ar"
*     into SRC and the Arabic silently became part of a data element name.
*
*     Existing four-part specs are unaffected - LV_A comes back blank and LABEL_AR
*     stays initial, which is exactly the state they are in today.
*
*     Note this is the SECOND-best way to do it. ZRAK_T_JNY_COL has ZLABEL_AR as a
*     real column, maintained in the Studio as "Label (AR)" on the column editor,
*     and COL_ROWS_OF( ) reads it. That path wins whenever the grid has rows there.
*     Use the spec slot for a grid not yet migrated; use the table for a new one.
      SPLIT lv_cc AT ':' INTO DATA(lv_n) DATA(lv_l) DATA(lv_t) DATA(lv_s) DATA(lv_a).

      DATA(lv_nn) = condense( lv_n ).
      DATA(lv_ll) = condense( lv_l ).
      DATA(lv_tt) = condense( lv_t ).
      DATA(lv_ss) = condense( lv_s ).
      DATA(lv_aa) = condense( lv_a ).
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
*     COMP_NAME( ), matching COL_ROWS_OF( ) - see the note there. This is the
*     older, packed DEFAULT_VAL path for a grid not yet migrated to
*     ZRAK_T_JNY_COL, but it feeds the identical CL_ABAP_STRUCTDESCR=>CREATE( )
*     in BUILD_MODEL( ), so a hyphen here dumps exactly the same way.
      APPEND VALUE #(
        name  = zcl_rak_journey_util=>comp_name( lv_nn )
        label = COND #( WHEN lv_ll IS NOT INITIAL THEN lv_ll ELSE lv_nn )
        ctype = COND #( WHEN lv_hid = abap_true    THEN 'INPUT'
                        WHEN lv_up  IS NOT INITIAL THEN lv_up
                        ELSE 'INPUT' )
        hide  = lv_hid
*       NOT upper-cased, unlike SRC. SRC is a DDIC name; this is text a citizen
*       reads.
        label_ar = lv_aa
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

    DATA(lv_journey) = mo_e->mv_journey.
    DATA(lv_field)   = to_upper( is_field-name ).

    SELECT * FROM zrak_t_jny_col
      INTO TABLE @DATA(lt_col)
      WHERE journey_id = @lv_journey
        AND step_id    = @lv_step
        AND field_name = @lv_field
      ORDER BY seqnr.

    LOOP AT lt_col INTO DATA(ls_col).
*     COMP_NAME( ), not a bare TO_UPPER( ). COL_NAME is free text on
*     ZRAK_T_JNY_COL's own column editor - nothing stops a hyphen there either,
*     and this is the actual site: BUILD_MODEL( )'s inner row/column structure
*     (CL_ABAP_STRUCTDESCR=>CREATE( LT_ROWCOMP )) is built from exactly this
*     NAME, so a column called REVIEW-GRID raised CX_SY_STRUCT_COMP_NAME here,
*     not from the field name COMP_NAME( ) already protects in BUILD_MODEL( ).
*     Confirmed live: the exception object's own COMPONENT_NAME was 'REVIEW-GRID',
*     under CX_SY_STRUCT_CREATION - a structure TYPE creation, which only the
*     two CL_ABAP_STRUCTDESCR=>CREATE( ) calls in BUILD_MODEL( ) can raise; the
*     outer one was already sanitised, so this - the inner one, fed by this
*     method - was the one still open.
      APPEND VALUE #(
        name     = zcl_rak_journey_util=>comp_name( CONV #( ls_col-col_name ) )
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


* Which step (as ZRAK_T_JNY_STEP/ZRAK_T_JNY_FLD key it by, i.e. -ID here -
* ZCL_RAK_JOURNEY_BE reads the same MS_CONFIG-STEPS row this way) a field
* belongs to. ZIF_RAK_JOURNEY carries no step id on a field itself - only on
* the step that holds it - so this recovers it from MS_CONFIG-STEPS. Checks
* the step currently being rendered first (right for WIZARD/WIZARD_LEFT/
* SINGLE, and for whichever step TABS/ACCORDION are drawing at the moment
* this is called); falls back to a full scan for the other steps TABS/
* ACCORDION draw in the same pass. Assumes field names are unique within a
* journey, same as SAFE_FIELD elsewhere in the engine.
  METHOD step_id_of.
    DATA(lv_f) = to_upper( iv_field ).

    READ TABLE mo_e->ms_config-steps INTO DATA(ls_s) INDEX mo_e->mv_step + 1.
    IF sy-subrc = 0.
      LOOP AT ls_s-fields INTO DATA(ls_f1) WHERE name = lv_f.
        rv = ls_s-id.
        RETURN.
      ENDLOOP.
    ENDIF.

    LOOP AT mo_e->ms_config-steps INTO ls_s.
      LOOP AT ls_s-fields INTO DATA(ls_f2) WHERE name = lv_f.
        rv = ls_s-id.
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
* Supported actions: HIDE, SHOW, READONLY, EDITABLE always; REQUIRE and
* OPTIONAL only for the whole-column shape - MISSING_REQUIRED checks a
* required column against every row so there is somewhere for a whole-
* column REQUIRE to be enforced. There is no equivalent per-row check
* (that would mean "this cell is required only when this row's own
* value says so"), so REQUIRE/OPTIONAL are ignored on that path, same as
* they are for anything but a plain field today. SET / CLEAR are ignored
* on both paths - a grid column is a cell per row, not a single value to
* overwrite.
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
      DATA(lv_ok) = abap_false.
      CASE ls_r-src_op.
        WHEN 'EQ'.
          lv_ok = xsdbool( lv_val = ls_r-src_value ).
        WHEN 'NE'.
          lv_ok = xsdbool( lv_val <> ls_r-src_value ).
        WHEN 'INITIAL'.
          lv_ok = xsdbool( lv_val IS INITIAL ).
        WHEN 'NOTINITIAL'.
          lv_ok = xsdbool( lv_val IS NOT INITIAL ).
        WHEN 'GT' OR 'LT' OR 'GE' OR 'LE'.
          lv_ok = mo_e->mo_rules->compare_num( iv_op = ls_r-src_op iv_lhs = lv_val iv_rhs = ls_r-src_value ).
      ENDCASE.
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
        WHEN 'REQUIRE'.
          <gc>-required = abap_true.
        WHEN 'OPTIONAL'.
          <gc>-required = abap_false.
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
      WHEN 'GT' OR 'LT' OR 'GE' OR 'LE'.
*       Number(...) on the field side, since every grid cell is a STRING
*       model field (BUILD_MODEL) and a bare string > string compares
*       lexicographically in JS, not numerically. The compared VALUE is
*       emitted unquoted so it reads as a JS number literal, not a
*       string - but only when it actually looks like one; a broken
*       config must not become broken JS on the page, so this rule
*       simply never fires instead.
        DATA(lv_num) = condense( iv_value ).
        IF lv_num IS NOT INITIAL AND lv_num CO '0123456789.-'.
          DATA(lv_jsop) = SWITCH string( iv_op
            WHEN 'GT' THEN `>` WHEN 'LT' THEN `<` WHEN 'GE' THEN `>=` WHEN 'LE' THEN `<=` ).
          rv = `Number(${` && iv_field && `}) ` && lv_jsop && ` ` && lv_num.
        ELSE.
          rv = `false`.
        ENDIF.
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
*   Round-6 finding 1. IV_JSON came from SET_GRID_DATA( ), built from
*   LT_GC - the configured columns and nothing else - so /UI2/CL_JSON's
*   DESERIALIZE just cleared and rebuilt every row without _VS/_VST ever
*   in the payload. Same fix as _UID two lines below: reissue what the
*   payload cannot carry, in the same loop.
    DATA(lt_gc) = grid_cols( mo_e->safe_field( iv_field ) ).
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      ASSIGN COMPONENT '_UID' OF STRUCTURE <row> TO FIELD-SYMBOL(<uid>).
      IF sy-subrc = 0 AND <uid> IS INITIAL.
        TRY.
            <uid> = cl_system_uuid=>create_uuid_c32_static( ).
          CATCH cx_uuid_error.
        ENDTRY.
      ENDIF.
      seed_row_states( EXPORTING it_gc = lt_gc CHANGING cs_row = <row> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD seed_row_states.
    LOOP AT it_gc INTO DATA(gc) WHERE ctype = 'NUMBER' OR ctype = 'INPUT'.
      ASSIGN COMPONENT |{ gc-name }_VS| OF STRUCTURE cs_row TO FIELD-SYMBOL(<vs>).
      IF sy-subrc = 0 AND <vs> IS INITIAL.
        <vs> = 'None'.
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( ls_f-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
      ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( ls_f-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( is_field-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( iv_field ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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
    ASSIGN COMPONENT zcl_rak_journey_util=>comp_name( is_field-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
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

*   A read-only SELECT column would otherwise show the stored KEY, not the
*   option text - the cell template below is one Text control shared by
*   every row, with no per-row place to resolve a key to its label. So
*   resolve it here instead, once per column, into the <col>_TXT companion
*   BUILD_MODEL( ) gives every SELECT column, before the table binds.
*   Same option source (ROLLNAME, else the handler) the editable combobox
*   uses further down. A key with no matching option falls back to itself,
*   same as before this existed.
    LOOP AT lt_gc INTO DATA(ls_selcol) WHERE ctype = 'SELECT'.
*     LV_RO is not a component of LT_GC, so it cannot sit in the LOOP...WHERE
*     above - every comparison there needs a table component on one side,
*     and "no component exists with the name LV_RO" is what the compiler
*     says when one doesn't. Filtered here instead, same condition as the
*     read-only cell binding further down.
      IF ls_selcol-readonly = abap_false AND lv_ro = abap_false.
        CONTINUE.
      ENDIF.
      DATA lt_sopt TYPE zif_rak_journey=>tt_option.
      CLEAR lt_sopt.
      IF ls_selcol-src IS NOT INITIAL.
        lt_sopt = mo_e->mo_render->f4_opts( VALUE #( rollname = ls_selcol-src ) ).
      ELSEIF mo_e->mo_logic IS BOUND.
        TRY.
            lt_sopt = mo_e->mo_logic->on_value_help( io_ctx = mo_e iv_field = |{ is_field-name }.{ ls_selcol-name }| ).
          CATCH cx_root.
            CLEAR lt_sopt.
        ENDTRY.
      ENDIF.
      DATA(lv_txtcomp) = |{ ls_selcol-name }_TXT|.
      LOOP AT <tab> ASSIGNING FIELD-SYMBOL(<srow>).
        ASSIGN COMPONENT ls_selcol-name OF STRUCTURE <srow> TO FIELD-SYMBOL(<skey>).
        CHECK sy-subrc = 0.
        ASSIGN COMPONENT lv_txtcomp OF STRUCTURE <srow> TO FIELD-SYMBOL(<stxt>).
        CHECK sy-subrc = 0.
        READ TABLE lt_sopt INTO DATA(ls_sopt) WITH KEY key = <skey>.
*       COND string( ), not COND #( ) - <STXT> is a field symbol from a
*       dynamic ASSIGN COMPONENT, TYPE any at compile time, so there is no
*       static target type for COND #( ) to derive its result type from
*       ("No type can be derived from the context for the operator...").
*       An explicit type gives every branch, including <SKEY> (also ANY),
*       something concrete to convert to.
        <stxt> = COND string( WHEN sy-subrc = 0
                               THEN zcl_rak_journey_util=>opt_text( iv_key = ls_sopt-key iv_text = ls_sopt-text )
                               ELSE CONV string( <skey> ) ).
      ENDLOOP.
    ENDLOOP.

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
*     Through PICK_TEXT( ), not a plain language COND - ZRAK_T_JNY_COL-ZLABEL/
*     ZLABEL_AR is read directly here, never built by ZCL_RAK_JOURNEY_REPO, so
*     this was the one bilingual pair an OTR:<alias> couldn't reach. Same
*     helper REPO's own PICK( ) now delegates to, so both stay in step.
      DATA(lv_hdr) = zcl_rak_journey_util=>pick_text( iv_en = gc-label iv_ar = gc-label_ar iv_lang = mo_e->mv_lang ).
      IF gc-required = abap_true.
        lv_hdr = lv_hdr && ` *`.
      ENDIF.
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
*   Blank-to-'None' safety net, not the round-trip sweep's job here -
*   a row built after CLEAR_FIELD_STATES( ) already ran this same round
*   trip (GRIDADD_, or rows an ON_INIT/backend read populates) still has
*   its _VS at blank, and UI5 rejects a blank VALUESTATE outright the
*   moment the row renders. Only touches the editable case - a readonly
*   grid draws cells as TEXT( ) below and never binds VALUESTATE at all.
    IF lv_ro = abap_false.
      mo_e->ensure_grid_states( is_field ).
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
*     MAXLENGTH is a CLIKE parameter; GC-MAXLEN is TYPE I and needs an
*     explicit conversion, not an implicit one, to reach it.
      DATA(lv_maxlen) = COND string( WHEN gc-maxlen > 0 THEN |{ gc-maxlen }| ELSE `` ).
      IF lv_ro = abap_true OR gc-readonly = abap_true.
*       A SELECT column binds to its resolved <col>_TXT companion instead of
*       the raw key path - populated once above, before the table bound.
*       Every other read-only ctype still shows its own stored value; there
*       is nothing to resolve for those.
        DATA(lv_rop) = COND string( WHEN gc-ctype = 'SELECT' THEN |\{{ gc-name }_TXT\}| ELSE lv_path ).
        lo_cells->text( text = lv_rop visible = lv_vis ).
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
*         VALUESTATE/VALUESTATETEXT bound per row, same trick VALUE
*         already uses - {gc-name} resolves against whichever row the
*         table binding is currently drawing, so {gc-name}_VS does too,
*         no per-row loop needed here. BUILD_MODEL( ) gives NUMBER and
*         INPUT columns these two companions; SET_CELL_STATE( ) is what
*         a handler's TY_MSG-FIELD = '<grid>.<col>#<row>' writes into them.
          lo_cells->input( value = lv_path type = 'Number' editable = lv_en change = lv_chg
                           visible = lv_vis maxlength = lv_maxlen
                           valuestate = |\{{ gc-name }_VS\}| valuestatetext = |\{{ gc-name }_VST\}| ).
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
*         VALUESTATE/VALUESTATETEXT - see the NUMBER branch above.
          lo_cells->input( value = lv_path editable = lv_en change = lv_chg
                           visible = lv_vis maxlength = lv_maxlen
                           valuestate = |\{{ gc-name }_VS\}| valuestatetext = |\{{ gc-name }_VST\}| ).
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
