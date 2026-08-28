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
*   - CATEGORY is a SELECT column, ROLLNAME = MEINS (resolves through
*     H_T006 - same "unit of measure" example ZCL_RAK_TEST_ALL_LOGIC already
*     uses for a scalar field, so it needs no journey-specific DDIC object).
*     Typing X into "Lock items?" (another header field) makes the whole
*     ITEMS field READONLY via a normal field-level rule - the grid turns
*     into a display table and Category's cell should now show the unit's
*     TEXT, not the code you picked. Before this fix it showed the raw key.
*   - NOTES is an INPUT column with MAXLEN = 5. The browser's maxlength
*     attribute stops a citizen from typing past it in the rendered page,
*     so this proves nothing about the fix by itself - the point is that
*     the SERVER now also refuses a longer value for a request that did NOT
*     come from this page. See the WRITE lines at the bottom for how to
*     drive that without a browser.
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
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'LOCK_ITEMS'
      seqnr = 2 zlabel = 'Lock items? (type X)' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      seqnr = 3 zlabel = 'Items' ftype = 'EDITABLE_TABLE' ) ) ).

  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'DESCRIPTION' seqnr = 1 zlabel = 'Description' ctrl = 'INPUT' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'QTY' seqnr = 2 zlabel = 'Qty' ctrl = 'NUMBER' width = '6rem' align = 'End' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'STATUS' seqnr = 3 zlabel = 'Done' ctrl = 'CHECKBOX' width = '5rem' align = 'Center' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'AMOUNT' seqnr = 4 zlabel = 'Amount' ctrl = 'NUMBER' total = 'X' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'CATEGORY' seqnr = 5 zlabel = 'Category (unit of measure)' ctrl = 'SELECT'
      rollname = 'MEINS' )
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'ITEMS'
      col_name = 'NOTES' seqnr = 6 zlabel = 'Notes (max 5 chars, server-checked)' ctrl = 'INPUT'
      maxlen = 5 ) ) ).

  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = lv_jny rule_id = '0001'
      src_field = 'STATUS' src_op = 'EQ' src_value = 'X'
      action = 'HIDE' tgt_field = 'AMOUNT' totable = 'ITEMS' )
    ( mandt = sy-mandt journey_id = lv_jny rule_id = '0002'
      src_field = 'HIDE_QTY' src_op = 'EQ' src_value = 'X'
      action = 'HIDE' tgt_field = 'QTY' totable = 'ITEMS' )
*   Field-level, NOT totable - this is what makes the whole ITEMS grid
*   read-only (ZCL_RAK_JOURNEY_RULES~IS_READONLY on the ITEMS field itself),
*   same mechanism ZCL_RAK_JOURNEY_GRID reads as LV_RO to decide whether
*   Category should resolve its cell to text.
    ( mandt = sy-mandt journey_id = lv_jny rule_id = '0003'
      src_field = 'LOCK_ITEMS' src_op = 'EQ' src_value = 'X'
      action = 'READONLY' tgt_field = 'ITEMS' ) ) ).

  COMMIT WORK AND WAIT.

  WRITE: / 'Seeded journey', lv_jny.
  WRITE: / 'Open it the same way you open any CJS journey, with journey=' && lv_jny.
  WRITE: / 'Add a row on the Items grid, check "Done" - that row''s Amount cell hides.'.
  WRITE: / 'Type X into "Hide Qty column?", go Next then back (or reload) - Qty disappears for every row.'.
  WRITE: / ' '.
  WRITE: / 'SELECT label resolution: pick a real unit (EA, KG, PC, ...) in Category on a row,'.
  WRITE: / 'then type X into "Lock items?" and go Next. The grid turns read-only and'.
  WRITE: / 'Category''s cell should show the unit''s TEXT (e.g. "Each"), not the code you'.
  WRITE: / 'picked - that is the <col>_TXT companion resolving it.'.
  WRITE: / ' '.
  WRITE: / 'Grid MAXLEN: Notes has MAXLEN = 5, enforced by the browser, so it cannot prove'.
  WRITE: / 'the fix from this page alone. To prove the SERVER side: open the browser dev'.
  WRITE: / 'tools, find the outgoing model payload for a row under ITEMS, set that row''s'.
  WRITE: / 'NOTES to more than 5 characters, then trigger Next or Submit. Before this fix'.
  WRITE: / 'that value posted unchecked; now VALIDATE_STEP( ) should reject it.'.
