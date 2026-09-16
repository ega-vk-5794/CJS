CLASS zcl_rak_cj_project DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& THE PROJECT SELECTOR - a searchable, paged card list.
*&
*& WHY IT EXISTS. M028 step 1 asks "which of your projects", and the
*& citizen who prompted this owns 207. CJS drew them as a sap.m.Select:
*& the binding was correct, the list was correct, and the control was
*& wrong - 207 items of XML in every round trip, no search, and a closed
*& dropdown that shows nothing until it is opened, which read on screen as
*& an empty list and cost a round to rule out. The live portal screen is a
*& card list with a search box and a count, and that is what this draws.
*&
*& IT IS THE PARCEL SELECTOR'S SHAPE, ON PURPOSE. Same interface, same
*& rakPcl* CSS, same page size, same red left edge. Two card lists in one
*& product that differ only because they were written on different days is
*& a worse outcome than either of them; where this one is simpler - no
*& map, no favourites, no owner switch, no multi-select - it is because
*& projects have none of those, not because it is a rougher draft.
*&
*& WHAT A CARD SHOWS IS WHAT THE SERVICE RETURNS, AND NO MORE. ProjectSet
*& answers ProjectNo, OpenDate, Parcel and Permits with values, and
*& Owner, Address and ArcObjects EMPTY - on the live portal too, which is
*& why the real screen shows those as bare captions. They are drawn the
*& same way here. Inventing a value for a column the department leaves
*& blank would be the one change nobody could spot as wrong.
*&
*& EVERY CELL IS READ BY ASSIGN COMPONENT OVER A CANDIDATE LIST, never by
*& naming a component of the generated MPC structure. Same rule as
*& ZCL_RAK_CJ_OPTS->ROW_PICK( ): the row type comes from a generated class
*& this environment cannot open, and a guessed component name is a
*& syntax error that takes the whole class - and so the renderer - down.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    INTERFACES zif_rak_cj_control.

    "! The ftype this control answers. Anything else is not ours and the
    "! engine's own renderer draws it - that is the interface's contract
    "! and it is what lets a second control coexist with the parcel one.
    CONSTANTS c_ftype TYPE string VALUE 'PROJECT'.

    "! Event prefix. Three characters, tested by the engine before the
    "! control is even asked, so an unrelated event costs one comparison.
    CONSTANTS c_pfx TYPE string VALUE 'PRJ'.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

  PRIVATE SECTION.

    DATA mo_e   TYPE REF TO zcl_rak_journey_engine.
    DATA mv_fld TYPE string.

    "! Whether this instance owns the shared browse state. Copied from the
    "! parcel control, and for the reason written there: two selectors on
    "! one step used to share one page number, so the second overwrote the
    "! first and both toolbars drove the second list.
    DATA mv_mine TYPE abap_bool.

    DATA mt_row  TYPE zcl_rak_fees_api=>tt_project_rows.
    DATA mv_read TYPE abap_bool.
    DATA mv_note TYPE string.

    "! Six, matching the parcel control. Every page press is a round trip
    "! and every round trip re-reads the list, so this is a compromise
    "! between XML size and reads - not a considered number of its own.
    CONSTANTS c_page_size TYPE i VALUE 6.

    METHODS t
      IMPORTING iv_en        TYPE string
                iv_ar        TYPE string
      RETURNING VALUE(rv)    TYPE string.

    "! One cell, by candidate component name. Returns blank when none of
    "! the candidates exists - which is correct for Owner and ArcObjects.
    METHODS cell
      IMPORTING is_row    TYPE any
                iv_names  TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS rows RETURNING VALUE(rt) TYPE zcl_rak_fees_api=>tt_project_rows.
    METHODS hits RETURNING VALUE(rt) TYPE zcl_rak_fees_api=>tt_project_rows.

    METHODS term RETURNING VALUE(rv) TYPE string.
    METHODS page RETURNING VALUE(rv) TYPE i.

    METHODS ev
      IMPORTING iv_name   TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS toolbar IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view
                              iv_n   TYPE i.
    METHODS card    IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view
                              is_row TYPE any.
    METHODS pager   IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view
                              iv_n   TYPE i.
    METHODS pick    IMPORTING iv_field TYPE string
                              iv_key   TYPE string.

ENDCLASS.


CLASS zcl_rak_cj_project IMPLEMENTATION.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD t.
    rv = COND string( WHEN sy-langu = 'E' THEN iv_en ELSE iv_ar ).
  ENDMETHOD.


  METHOD cell.
*   ASSIGN COMPONENT, NEVER ASSIGN (name). Assign-by-name resolves the
*   string against data objects visible in the CALLING program and writes
*   into whatever it finds - the mechanism that dumped every DOK journey
*   with MOVE_TO_LIT_NOTALLOWED_NODATA. Component assignment cannot reach
*   outside the structure it is given.
    CLEAR rv.
    SPLIT iv_names AT ',' INTO TABLE DATA(lt_n).
    LOOP AT lt_n INTO DATA(lv_n).
      ASSIGN COMPONENT lv_n OF STRUCTURE is_row TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0 AND <v> IS ASSIGNED.
        rv = |{ <v> }|.
        CONDENSE rv.
        IF rv IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDIF.
      UNASSIGN <v>.
    ENDLOOP.
  ENDMETHOD.


  METHOD rows.
*   ONCE PER ROUND TRIP. The control is rebuilt by ENSURE_PARTS( ) on every
*   request, so this cache spans one render and no more - the same
*   limitation the parcel control carries and for the same reason: there is
*   nowhere to put a cache that survives a round trip without it becoming
*   state that can go stale against the backend.
    IF mv_read = abap_true.
      rt = mt_row.
      RETURN.
    ENDIF.
    mv_read = abap_true.

    TRY.
*       Identity is built by ZCL_RAK_CJ_CTX, never assembled here - it is
*       the one place that knows the session key is not the &userdata=
*       envelope and that the partner guid has to be derived.
*       NAMED, though the constructor takes only IS_CTX today: a second
*       importing parameter added later turns a positional call into a
*       syntax error rather than a silent rebinding.
        DATA(lo_api) = NEW zcl_rak_fees_api( is_ctx = zcl_rak_cj_ctx=>build( mo_e ) ).

*       NO FILTERS. The live portal screen sends Partner and nothing else;
*       PROJECTS( ) adds that from the context. Passing the journey's case
*       here is what emptied the list before - see the header on PROJECTS( ).
        DATA(ls_res) = lo_api->projects( ).
        mt_row = ls_res-rows.

*       THE FILTER STRING IS A DEVELOPER'S NOTE AND IS GATED AS ONE. It
*       names a partner number, which is exactly the technical disclosure
*       that was swept off production screens.
        IF ls_res-flt CS 'TEST PARTNER'
           AND zcl_rak_journey_util=>is_dev( ) = abap_true.
          mv_note = |Showing TEST data - { ls_res-flt }|.
        ENDIF.
      CATCH cx_root INTO DATA(lx).
        CLEAR mt_row.
        IF zcl_rak_journey_util=>is_dev( ) = abap_true.
          mv_note = |Project read failed - { lx->get_text( ) }|.
        ENDIF.
    ENDTRY.

    rt = mt_row.
  ENDMETHOD.


  METHOD hits.
    DATA(lv_t) = to_upper( term( ) ).
    IF lv_t IS INITIAL.
      rt = rows( ).
      RETURN.
    ENDIF.

*   MATCHED ON EVERYTHING THE CITIZEN CAN READ, not on the key alone. They
*   are as likely to search by parcel as by project number - both are on
*   the card - and CS rather than equality because a search box means
*   "contains" everywhere else they have used one.
    LOOP AT rows( ) ASSIGNING FIELD-SYMBOL(<r>).
      DATA(lv_hay) = to_upper(
        |{ cell( is_row = <r> iv_names = `PROJECTNO,PROJECT,ID` ) } | &&
        |{ cell( is_row = <r> iv_names = `PARCEL,PARCELID` ) } | &&
        |{ cell( is_row = <r> iv_names = `ADDRESS` ) } | &&
        |{ cell( is_row = <r> iv_names = `OWNER` ) }| ).
      IF lv_hay CS lv_t.
        APPEND <r> TO rt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD term.
    rv = COND string( WHEN mv_mine = abap_true THEN mo_e->mv_prj_term ).
  ENDMETHOD.


  METHOD page.
    IF mv_mine = abap_false.
      rv = 1.
      RETURN.
    ENDIF.
    rv = mo_e->mv_prj_page.
    IF rv < 1.
      rv = 1.
    ENDIF.
  ENDMETHOD.


  METHOD ev.
    rv = mo_e->mo_client->_event( |{ c_pfx }{ iv_name }~{ mv_fld }| ).
  ENDMETHOD.


  METHOD zif_rak_cj_control~render.

*   NOT MINE UNLESS IT IS. The engine offers every composite field to every
*   control in turn and takes the first that answers true, so this test is
*   the whole of how two controls coexist. Answering for an ftype we do not
*   serve would silently replace the parcel selector.
    IF io_view IS NOT BOUND
       OR is_field-name IS INITIAL
       OR is_field-type <> c_ftype.
      RETURN.
    ENDIF.

    mv_fld = is_field-name.

*   OWNERSHIP MOVES ON A PRESS, NOT ON A PAINT. Claiming it here
*   unconditionally is what made two selectors on one step share one page.
    IF mo_e->mv_prj_field IS INITIAL.
      mo_e->mv_prj_field = is_field-name.
    ENDIF.
    mv_mine = xsdbool( mo_e->mv_prj_field = is_field-name ).
    IF mv_mine = abap_true AND mo_e->mv_prj_page < 1.
      mo_e->mv_prj_page = 1.
    ENDIF.

    DATA(lo_box) = io_view->vbox( class = 'rakPcl sapUiTinyMarginBottom' ).

*   A HEADING AND A SUBLINE, not a field label - the live screen opens with
*   "Project Selection" over "Please select a project from the list", and a
*   form label above a card list reads as though the list were one input.
    lo_box->title( text = is_field-label level = 'H4' ).
    IF is_field-placeholder IS NOT INITIAL.
      lo_box->text( text = is_field-placeholder class = 'rakPclMeta' ).
    ENDIF.

*   WHAT IS CHOSEN NOW, above the list. On 207 cards the selected one is
*   almost never on screen, so a highlighted card is not an answer.
    DATA(lv_cur) = mo_e->val_get( mv_fld ).
    IF lv_cur IS NOT INITIAL.
      DATA(lo_cur) = lo_box->hbox( alignitems = 'Center'
                                   class      = 'sapUiTinyMarginBottom' ).
      lo_cur->object_status( title = t( iv_en = `Selected` iv_ar = `المحدد` )
                             text  = lv_cur
                             state = 'Success'
                             icon  = 'sap-icon://accept' ).
      lo_cur->button( text  = t( iv_en = `Clear` iv_ar = `مسح` )
                      icon  = 'sap-icon://decline'
                      type  = 'Transparent'
                      class = 'sapUiTinyMarginBegin'
                      press = mo_e->mo_client->_event( |{ c_pfx }PICK_{ mv_fld }~| ) ).
    ENDIF.

*   READ-ONLY STOPS HERE, with the selection shown and nothing to press.
    IF is_field-readonly = abap_true.
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

    DATA(lt_hit) = hits( ).
    DATA(lv_n)   = lines( lt_hit ).

    toolbar( io_box = lo_box iv_n = lv_n ).

    IF mv_note IS NOT INITIAL.
      lo_box->message_strip( text      = mv_note
                             type      = 'Information'
                             showicon  = abap_true
                             class     = 'sapUiTinyMarginBottom' ).
    ENDIF.

    IF lv_n = 0.
      lo_box->message_strip(
        text     = COND string(
                     WHEN term( ) IS NOT INITIAL
                     THEN t( iv_en = `No project matches that search`
                             iv_ar = `لا يوجد مشروع مطابق لهذا البحث` )
                     ELSE t( iv_en = `No project is registered against this partner`
                             iv_ar = `لا يوجد مشروع مسجل لهذا الشريك` ) )
        type     = 'Information'
        showicon = abap_true ).
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

*   ---- one page of cards ---------------------------------------------
    DATA(lv_from) = ( page( ) - 1 ) * c_page_size + 1.
    DATA(lv_to)   = lv_from + c_page_size - 1.
    IF lv_to > lv_n.
      lv_to = lv_n.
    ENDIF.

    DATA lv_i TYPE i.
    LOOP AT lt_hit ASSIGNING FIELD-SYMBOL(<r>).
      lv_i = sy-tabix.
      IF lv_i < lv_from OR lv_i > lv_to.
        CONTINUE.
      ENDIF.
      card( io_box = lo_box is_row = <r> ).
    ENDLOOP.

    pager( io_box = lo_box iv_n = lv_n ).

    rv_drawn = abap_true.
  ENDMETHOD.


  METHOD toolbar.
    DATA(lo_bar) = io_box->hbox( alignitems = 'Center' class = 'rakPclBar' ).

*   THE COUNT IS THE LIVE SCREEN'S OWN, wording included - "207 Projects
*   found" sits above the list there and is the fastest confirmation a
*   citizen gets that the page is about their portfolio.
    lo_bar->text( text  = COND string(
                            WHEN sy-langu = 'E'
                            THEN |{ iv_n } { COND string( WHEN iv_n = 1
                                                          THEN `Project` ELSE `Projects` ) } found|
                            ELSE |{ iv_n } مشروع| )
                  class = 'rakPclMeta' ).

*   SEARCH IS WHY THIS CONTROL EXISTS AT ALL. Two hundred cards is six
*   pages of paging without it; with it, a citizen who knows their project
*   number is one keystroke away.
    lo_bar->search_field( value  = mo_e->mo_client->_bind_edit( mo_e->mv_prj_term )
                          search = ev( 'SRCH' )
                          width  = '16rem'
                          placeholder = t( iv_en = `Search project or parcel`
                                           iv_ar = `ابحث برقم المشروع أو القطعة` ) ).
  ENDMETHOD.


  METHOD card.

*   PROJECTNO IS THE KEY AND THE HEADING, and it is what gets STORED.
*   ZCL_EGA_CJ_FW_RO_DML_ABS_V1's UPDATE takes the posted INTRENO_PROJECT,
*   files it as CJ06, and then looks it up as SCMG_T_CASE_ATTR-EXT_KEY to
*   derive the owner and the parcel - so the value has to be the project
*   case number exactly as the service returned it, not a trimmed display
*   form. Nothing here reformats it.
    DATA(lv_key) = cell( is_row = is_row iv_names = `PROJECTNO,PROJECT,ID` ).
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_parcel) = cell( is_row = is_row iv_names = `PARCEL,PARCELID` ).
    DATA(lv_perm)   = cell( is_row = is_row iv_names = `PERMITS` ).
    DATA(lv_arc)    = cell( is_row = is_row iv_names = `ARCOBJECTS` ).
    DATA(lv_owner)  = cell( is_row = is_row iv_names = `OWNER` ).
    DATA(lv_open)   = cell( is_row = is_row iv_names = `OPENDATE` ).

*   THE DATE AS THE CARD SHOWS IT. ProjectSet returns Edm.DateTime, which
*   arrives here as an eight-character date followed by a time; the live
*   card prints dd/mm/yyyy and nothing else.
    DATA lv_date TYPE string.
    IF strlen( lv_open ) >= 8 AND lv_open(8) CO '0123456789'.
      lv_date = |{ lv_open+6(2) }/{ lv_open+4(2) }/{ lv_open(4) }|.
    ELSE.
      lv_date = lv_open.
    ENDIF.

    DATA(lv_sel) = xsdbool( mo_e->val_get( mv_fld ) = lv_key ).

    DATA(lo_p) = io_box->vbox(
      class = |{ mo_e->mo_css->cls( 'CARD' ) } rakPclCard| ).

    DATA(lo_top) = lo_p->hbox( class = 'rakPclTop' ).
    lo_top->title( text = lv_key level = 'H5' class = 'rakPclNo' ).
    IF lv_date IS NOT INITIAL.
      lo_top->text( text = lv_date class = 'rakPclMeta sapUiTinyMarginBegin' ).
    ENDIF.

*   PERMITS AND ARC. OBJECTS SIT RIGHT, as two stacked captions, which is
*   the live card's layout. ARCOBJECTS comes back EMPTY from the service -
*   verified against the portal's own response, not assumed - so the
*   caption draws with no figure under it exactly as the real screen does.
*   Do not substitute a zero: a zero is a count, and no count was given.
    DATA(lo_r) = lo_top->hbox( class = 'rakPclBadge' ).
    DATA(lo_c1) = lo_r->vbox( class = 'sapUiSmallMarginEnd' ).
    lo_c1->text( text = t( iv_en = `Permits` iv_ar = `التصاريح` ) class = 'rakPclMeta' ).
    IF lv_perm IS NOT INITIAL.
      lo_c1->text( text = lv_perm ).
    ENDIF.
    DATA(lo_c2) = lo_r->vbox( ).
    lo_c2->text( text = t( iv_en = `Arc. objects` iv_ar = `عناصر الأرشيف` ) class = 'rakPclMeta' ).
    IF lv_arc IS NOT INITIAL.
      lo_c2->text( text = lv_arc ).
    ENDIF.

*   ONE GREY META LINE, pipe separated, the way the parcel card does it.
    DATA lt_meta TYPE string_table.
    IF lv_parcel IS NOT INITIAL.
      APPEND |{ t( iv_en = `Parcel ID` iv_ar = `رقم القطعة` ) } { lv_parcel }| TO lt_meta.
    ENDIF.
    APPEND COND string( WHEN lv_owner IS NOT INITIAL
                        THEN |{ t( iv_en = `Owner` iv_ar = `المالك` ) } { lv_owner }|
                        ELSE t( iv_en = `Owner` iv_ar = `المالك` ) ) TO lt_meta.
    lo_p->text( text  = concat_lines_of( table = lt_meta sep = `  |  ` )
                class = 'rakPclMeta' ).

    DATA(lo_act) = lo_p->hbox( class = 'rakPclAct' ).
    lo_act->button(
      text  = COND string( WHEN lv_sel = abap_true
                           THEN t( iv_en = `Selected` iv_ar = `محدد` )
                           ELSE t( iv_en = `Select`   iv_ar = `اختيار` ) )
      icon  = COND string( WHEN lv_sel = abap_true THEN 'sap-icon://accept' )
      type  = COND string( WHEN lv_sel = abap_true THEN 'Success' ELSE 'Emphasized' )
      press = mo_e->mo_client->_event( |{ c_pfx }PICK_{ mv_fld }~{ lv_key }| ) ).
  ENDMETHOD.


  METHOD pager.
    DATA(lv_pages) = ( iv_n + c_page_size - 1 ) DIV c_page_size.
    IF lv_pages <= 1.
      RETURN.
    ENDIF.

    DATA(lo_pg) = io_box->hbox( alignitems = 'Center'
                                class      = 'rakPclBar sapUiTinyMarginTop' ).
    lo_pg->button( icon    = 'sap-icon://navigation-left-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( page( ) > 1 )
                   press   = ev( 'PREV' ) ).
    lo_pg->text( text  = |{ page( ) } / { lv_pages }| class = 'rakPclMeta' ).
    lo_pg->button( icon    = 'sap-icon://navigation-right-arrow'
                   type    = 'Transparent'
                   enabled = xsdbool( page( ) < lv_pages )
                   press   = ev( 'NEXT' ) ).
  ENDMETHOD.


  METHOD pick.
    DATA(lv_f) = iv_field.
    IF lv_f IS INITIAL.
      lv_f = mo_e->mv_prj_field.
    ENDIF.
    IF lv_f IS INITIAL.
      RETURN.
    ENDIF.

    mo_e->val_set( iv_name = lv_f iv_value = iv_key ).
    mo_e->set_field_state( iv_name = lv_f iv_state = 'None' iv_text = '' ).

*   ON_CHANGE( ) IS WHAT WRITES THE CARRIER. M028's handler copies the pick
*   into INTRENO_PROJECT, which is the item the BAdI reads - the selector
*   itself never posts. Calling the hook here is what makes a card press
*   behave exactly like a dropdown change did.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_change( io_ctx = mo_e iv_field = lv_f ).
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_cj_control~render_popup.
*   This control has no dialog. Answering false leaves the engine's own
*   popup dispatch to whatever else is open, rather than closing it.
    rv_drawn = abap_false.
  ENDMETHOD.


  METHOD zif_rak_cj_control~on_event.

*   STRLEN FIRST. IV_EVENT is a STRING and an offset past its end raises
*   CX_SY_RANGE_OUT_OF_BOUNDS - the exact bug E016 shipped, where the
*   engine's TRY/CATCH turned it into a warning on a successful action.
    IF strlen( iv_event ) <= strlen( c_pfx )
       OR substring( val = iv_event len = 3 ) <> c_pfx.
      RETURN.
    ENDIF.

    DATA(lv) = substring( val = iv_event off = 3 ).
    rv_handled = abap_true.

*   PICK_ CARRIES A PAYLOAD AFTER THE TILDE, the browse events carry an
*   OWNER. Splitting both the same way is the bug the parcel control
*   documents at length: the payload lands in the owner variable, the key
*   is thrown away, and the write silently does nothing.
    IF strlen( lv ) > 5 AND substring( val = lv len = 5 ) = 'PICK_'.
      DATA(lv_rest) = substring( val = lv off = 5 ).
      SPLIT lv_rest AT '~' INTO DATA(lv_pf) DATA(lv_pk).
      pick( iv_field = lv_pf iv_key = lv_pk ).
      RETURN.
    ENDIF.

    SPLIT lv AT '~' INTO DATA(lv_cmd) DATA(lv_own).

*   THE PRESS CLAIMS THE STATE, so a press on the second selector of a step
*   makes it the owner of the term and the page before either is read again.
    IF lv_own IS NOT INITIAL AND mo_e->mv_prj_field <> lv_own.
      mo_e->mv_prj_field = lv_own.
      mo_e->mv_prj_page  = 1.
      CLEAR mo_e->mv_prj_term.
    ENDIF.
    mv_fld  = lv_own.
    mv_mine = abap_true.

    CASE lv_cmd.
      WHEN 'SRCH'.
*       BACK TO PAGE ONE. A search that narrows 207 rows to 3 while the
*       reader is on page 12 shows an empty list and looks broken.
        mo_e->mv_prj_page = 1.
      WHEN 'PREV'.
        IF mo_e->mv_prj_page > 1.
          mo_e->mv_prj_page = mo_e->mv_prj_page - 1.
        ENDIF.
      WHEN 'NEXT'.
        mo_e->mv_prj_page = mo_e->mv_prj_page + 1.
      WHEN OTHERS.
        rv_handled = abap_false.
    ENDCASE.
  ENDMETHOD.


ENDCLASS.
