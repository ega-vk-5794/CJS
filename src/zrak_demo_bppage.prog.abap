REPORT zrak_demo_bppage.

* Seeds one self-contained journey that exercises the R18-2 paging
* contract, the search/filter mechanism and a dependent table, over
* BUT000 - the only table in this system with enough rows to tell a
* working window from a broken one.
*
* A DEMO OVER TEN ROWS PROVES NOTHING. That is not a general remark: the
* GROWING attempt withdrawn in R17-2 was tested with a threshold of 50
* against 55 rows and "everything rendered" was read as working, when it
* would have looked identical broken. BUT000 makes the difference
* visible, because page 2 either shows different partners or it does not.
*
* WHAT TO LOOK AT, in order:
*
*   1. Open it. BP_LIST shows 25 partners and a pager reading "1-25 / n"
*      where n is every partner in the client. Back is disabled, Next is
*      not.
*
*   2. Press Next. The partners change and the pager reads 26-50. Nothing
*      else on the page moves - that is MT_PAGE being per field and
*      riding the serialized instance.
*
*   3. Type three letters of a name into Search. The list narrows, the
*      TOTAL drops to the matches, and the page goes back to 1 - the
*      handler's ON_CHANGE( ) does that, and without it a citizen on page
*      7 would be answered with a blank table.
*
*   4. Put a group into Filter as well. The two narrowings compose; they
*      are separate WHERE clauses on one SELECT, not two passes.
*
*   5. Press Select on a row. BP_ADDR fills with that partner's addresses
*      - a second table driven by the pick target of the first. That is
*      the dependent-list case in its table form; the parcel selector
*      does the same thing for options with Sector=@FIELD.
*
*   6. Page to the last page and press Next. Nothing breaks: PAGE_MOVE( )
*      does not clamp upwards because the total is the handler's and is
*      only known once GET_TABLE( ) has answered, so the RENDERER clamps
*      and writes the corrected offset back on the same round trip.
*
* TO SEE THE WINDOW ITSELF rather than its effect, launch with &trace=x.
* PAGE lines report the offset on every move, and a handler that ignored
* the window would show the renderer's "handler returned N rows for a
* window of 25" line instead.
*
* BKND_ACTIVE is blank, so this journey posts nowhere and creates no
* case. It reads BUT000, BUT020 and ADRC and writes nothing anywhere.
*
* Re-runnable: deletes its own rows first. Nothing outside journey_id
* 'ZDEMOBPPAGE' is touched.

START-OF-SELECTION.

  DATA(lv_jny)  = 'ZDEMOBPPAGE'.
  DATA(lv_step) = 'FIND'.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = lv_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = lv_jny.
  COMMIT WORK AND WAIT.

  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = lv_jny
    title         = 'Demo: paged business partner search'
    subtitle      = 'Paging, search, filter and a dependent table over BUT000'
    active        = 'X'
    layout_mode   = 'WIZARD'
*   THE HANDLER IS THE POINT. Without it GET_TABLE( ) answers nothing and
*   both tables render empty - which is what a journey with a TABLE field
*   and no handler always does, and is worth knowing is the same symptom.
    handler_class = 'ZCL_DEMO_BP_PAGE_LOGIC' ) ).

  INSERT zrak_t_jny_step FROM @( VALUE #(
    mandt      = sy-mandt
    journey_id = lv_jny
    step_id    = lv_step
    seqnr      = 1
    title      = 'Find a partner'
*   NO_ACTION: this step is answered by acting on the page - searching and
*   picking - not by a footer button. Without it the citizen gets a Close
*   button that abandons a journey they have not started.
    no_action  = 'X'
    active     = 'X' ) ).

  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(

*   SEARCH AND FILTER ARE PLAIN INPUTS. There is no search control and no
*   search event: the handler reads these two fields inside GET_TABLE( ),
*   and ON_CHANGE( ) already forces the round trip that re-renders the
*   table. That is the same shape the parcel selector uses with
*   Search=@FIELD, one layer down.
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BP_FIND'
      seqnr = 1 zlabel = 'Search (name or partner number)'
      placeholder = 'Type three letters and watch the total move' )

    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BP_GROUP'
      seqnr = 2 zlabel = 'Filter by BP group'
      placeholder = 'e.g. 0001 - leave blank for all' )

*   GROW_THRESH IS THE PAGE SIZE and the only thing that turns paging on.
*   Blank or zero here and this renders as a plain table of everything,
*   which is what every other TABLE in the system still does.
*
*   DEFAULT_VAL IS THE PICK SPEC, not a column spec. A TABLE cannot carry
*   both: RENDER_BLOCK( ) treats a DEFAULT_VAL containing ':' as columns
*   and clears the pick. The columns come from the handler instead, which
*   is where they belong when the rows do.
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BP_LIST'
      seqnr = 3 zlabel = 'Business partners' ftype = 'TABLE'
      grow_thresh = 25
      default_val = 'BP_SEL|Select|اختيار' )

*   The pick target. Hidden because it holds a partner number the citizen
*   never types - the row-pick writes it and BP_ADDR reads it.
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BP_SEL'
      seqnr = 4 zlabel = 'Selected partner' ftype = 'READONLY' )

*   The dependent table. No GROW_THRESH: a partner has a handful of
*   addresses and paging three rows is the mistake R17-2 documented.
    ( mandt = sy-mandt journey_id = lv_jny step_id = lv_step field_name = 'BP_ADDR'
      seqnr = 5 zlabel = 'Addresses of the selected partner' ftype = 'TABLE' ) ) ).

  COMMIT WORK AND WAIT.

  SELECT COUNT( * ) FROM but000 INTO @DATA(lv_n).

  WRITE: / 'Seeded journey', lv_jny.
  WRITE: / 'BUT000 in this client:', lv_n, 'partner(s) - page size 25'.
  ULINE.
  WRITE: / 'Open with:'.
  WRITE: / '  ...egardcjs?sap-client=200&app_start=ZCL_RAK_JOURNEY_ENGINE&journey=' && lv_jny.
  WRITE: / '  add &trace=x to see the PAGE lines on every move'.
  ULINE.
  WRITE: / '1. Pager reads 1-25 of', lv_n, '- Back disabled, Next not'.
  WRITE: / '2. Next -> different partners, pager reads 26-50'.
  WRITE: / '3. Type in Search -> list narrows, total drops, page resets to 1'.
  WRITE: / '4. Add a BP group -> the two narrowings compose'.
  WRITE: / '5. Select a row -> the address table below fills'.
  WRITE: / '6. Next on the last page -> corrects itself, no empty page'.
  ULINE.
  WRITE: / 'Activate ZIF_RAK_JOURNEY_LOGIC and ZIF_RAK_JOURNEY first, then'.
  WRITE: / 'ZCL_RAK_JOURNEY_LOGIC, the engine classes, and this handler.'.
  WRITE: / 'ZRAK_T_JNY_FLD needs GROW_THRESH activated and the table adjusted,'.
  WRITE: / 'or the INSERT above fails on an unknown field.'.
