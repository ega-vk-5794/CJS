REPORT zrak_seed_gridtest.

* Seeds one small, self-contained journey to exercise the new
* ZRAK_T_JNY_COL / ZRAK_T_JNY_RULE(TOTABLE) grid features end to end:
*
*   - ITEMS is an EDITABLE_TABLE grid whose columns come entirely from
*     ZRAK_T_JNY_COL, not a packed DEFAULT_VAL spec.
*   - Checking a row's "Done" box (the STATUS column) hides that row's
*     Amount cell only - a per-row rule, evaluated client-side via a UI5
*     expression binding, no server round trip per row.
*   - Typing X into "Hide Qty column?" (a header field, not a column of
*     ITEMS) hides the whole Qty column for every row - a whole-column
*     rule, evaluated once.
*
* Dev/test only. BKND_ACTIVE and HANDLER_CLASS are both left blank, so
* this journey never calls out anywhere - it only exercises the grid
* renderer and the rules engine.
*
* Re-runnable: deletes its own rows first, so running it twice is safe.
* Nothing outside journey_id 'ZGRIDTEST' is touched.

START-OF-SELECTION.

  DATA(lv_jny)  = 'ZGRIDTEST'.
  DATA(lv_step) = 'STEP1'.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = lv_jny.
  COMMIT WORK AND WAIT.

  INSERT zrak_t_jny FROM @( VALUE #(
    mandt       = sy-mandt
    journey_id  = lv_jny
    title       = 'Grid Column Feature Test'
    active      = 'X'
    layout_mode = 'WIZARD' ) ).

  INSERT zrak_t_jny_step FROM @( VALUE #(
    mandt      = sy-mandt
    journey_id = lv_jny
    step_id    = lv_step
    seqnr      = 1
    title      = 'Items'
    active     = 'X' ) ).

  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'HIDE_QTY'
      seqnr = 1 zlabel = 'Hide Qty column? (type X)' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      seqnr = 2 zlabel = 'Items' ftype = 'EDITABLE_TABLE' ) ) ).

  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'DESCRIPTION' seqnr = 1 zlabel = 'Description' ctrl = 'INPUT' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'QTY' seqnr = 2 zlabel = 'Qty' ctrl = 'NUMBER' width = '6rem' align = 'End' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'STATUS' seqnr = 3 zlabel = 'Done' ctrl = 'CHECKBOX' width = '5rem' align = 'Center' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'AMOUNT' seqnr = 4 zlabel = 'Amount' ctrl = 'NUMBER' total = 'X' ) ) ).

  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny rule_id = '0001'
      src_field = 'STATUS' src_op = 'EQ' src_value = 'X'
      action = 'HIDE' tgt_field = 'AMOUNT' totable = 'ITEMS' )
    ( mandt = sy-mandt journey_id = lv_jny rule_id = '0002'
      src_field = 'HIDE_QTY' src_op = 'EQ' src_value = 'X'
      action = 'HIDE' tgt_field = 'QTY' totable = 'ITEMS' ) ) ).

  COMMIT WORK AND WAIT.

  WRITE: / 'Seeded journey', lv_jny.
  WRITE: / 'Open it the same way you open any CJS journey, with journey=' && lv_jny.
  WRITE: / 'Add a row on the Items grid, check "Done" - that row''s Amount cell hides.'.
  WRITE: / 'Type X into "Hide Qty column?", go Next then back (or reload) - Qty disappears for every row.'.
