CLASS zcl_rak_cj_parcel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& RAKPARCELSELECTOR, rebuilt as a CJS control.
*&
*& THE LEGACY CONTROL IS NOT A DROPDOWN, and that is the whole reason this
*& class exists. Screenshots of the live control (doc/controls/
*& shapeit-reads.md) show a paginated card list with Owned / Property
*& Agent tabs, an owner picker, a favourites toggle and a search box -
*& 677 properties over 136 pages on a property-agent account, five cards
*& to a page. A ComboBox holding 677 items is not a smaller version of
*& that; it is a different, unusable control, and on abap2UI5 it is also
*& 677 items of XML in every round trip.
*&
*& SO ONLY ONE PAGE IS EVER RENDERED. The read returns the whole list -
*& that is what the DPC does and what the ShapeIt control does too, which
*& then pages client side - but the view is built from C_PAGE_SIZE rows
*& and nothing else. A citizen with ten thousand parcels costs the same
*& markup as one with five.
*&
*& AND NOTHING IS CACHED ACROSS ROUND TRIPS. The engine CLEARs its helper
*& objects before serializing (see ENSURE_PARTS( ) and its counterpart),
*& so MT_ROWS lives for one request: read once per round trip, reused by
*& every method inside it, gone afterwards. Holding 677 wide MPC rows in
*& the serialized app state instead would put them on the wire twice per
*& click. What DOES survive is the eight scalars on the engine
*& (MV_PCL_MODE, _PAGE, _TERM ...), which is all the state a list view
*& actually has.
*&
*& REACHED DYNAMICALLY, ALWAYS. This class statically references
*& ZCL_RAK_PROPERTY_API, which inherits the generated legacy DPC. The
*& engine must therefore never name this class in a declaration - it holds
*& a ZIF_RAK_CJ_CONTROL reference and creates it with CREATE OBJECT ...
*& TYPE ('ZCL_RAK_CJ_PARCEL') inside a TRY. See the interface header.
*&
*& WHAT THE CITIZEN'S PRESS STORES is the PARCEL ID, never the internal
*& INTRENO - a draft written by ShapeIt and one written by CJS have to
*& hold the same value. The Intreno is carried separately, for the details
*& dialog only.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    INTERFACES zif_rak_cj_control.

*   The engine's popup kind for this control's details dialog.
    CONSTANTS c_popup TYPE string VALUE 'PCLDET'.

*   Event prefix. Three characters, checked before any offset is taken -
*   an offset past the end of a STRING raises CX_SY_RANGE_OUT_OF_BOUNDS,
*   and event names are short.
    CONSTANTS c_pfx TYPE string VALUE 'PCL'.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

  PRIVATE SECTION.

    CONSTANTS c_page_size TYPE i VALUE 5.

    CONSTANTS: c_owned TYPE string VALUE 'OWNED',
               c_agent TYPE string VALUE 'AGENT',
               c_grant TYPE string VALUE 'GRANTS'.

    DATA mo_e     TYPE REF TO zcl_rak_journey_engine.

*   One round trip's read, and the flag that says it happened. A read that
*   legitimately answers no rows must not be repeated by every caller.
    DATA mt_rows  TYPE zcl_rak_property_api=>tt_prop_rows.
    DATA mv_read  TYPE abap_bool.
    DATA mv_note  TYPE string.
    DATA mt_own   TYPE zcl_rak_property_api=>tt_partner_rows.
    DATA mv_ownrd TYPE abap_bool.

    METHODS api  RETURNING VALUE(ro) TYPE REF TO zcl_rak_property_api.
    METHODS rows RETURNING VALUE(rt) TYPE zcl_rak_property_api=>tt_prop_rows.
    METHODS hits RETURNING VALUE(rt) TYPE zcl_rak_property_api=>tt_prop_rows.
    METHODS owners RETURNING VALUE(rt) TYPE zcl_rak_property_api=>tt_partner_rows.

*   Every component read by NAME and never by a hard-coded move: the row
*   type is generated from the service model and gains columns without
*   this class being touched. A component that is not there yields blank.
    METHODS cell
      IMPORTING is_row    TYPE any
                iv_comp   TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS t
      IMPORTING iv_en     TYPE string
                iv_ar     TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS mode RETURNING VALUE(rv) TYPE string.

    METHODS toolbar IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view.
    METHODS card    IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view
                              is_row TYPE any.
    METHODS pager   IMPORTING io_box   TYPE REF TO z2ui5_cl_xml_view
                              iv_pages TYPE i.
    METHODS pick    IMPORTING iv_field TYPE string
                              iv_key   TYPE string.

*   One tab of the details dialog whose data is not reachable yet. The
*   COLUMNS are the live dialog's own headers, so the tab that appears
*   when GET_EXPANDED_ENTITYSET is solved is this one with rows in it -
*   not a redesign. IV_COLS is caret-separated.
    METHODS blocked_tab
      IMPORTING io_bar  TYPE REF TO z2ui5_cl_xml_view
                iv_key  TYPE string
                iv_text TYPE string
                iv_cols TYPE string
                iv_exp  TYPE string.

ENDCLASS.



CLASS zcl_rak_cj_parcel IMPLEMENTATION.


  METHOD constructor.
    mo_e = io_engine.
  ENDMETHOD.


  METHOD t.
    rv = COND string( WHEN sy-langu = 'E' THEN iv_en ELSE iv_ar ).
  ENDMETHOD.


  METHOD cell.
    ASSIGN COMPONENT iv_comp OF STRUCTURE is_row TO FIELD-SYMBOL(<v>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv = condense( CONV string( <v> ) ).
  ENDMETHOD.


  METHOD mode.
    rv = mo_e->mv_pcl_mode.
    IF rv IS INITIAL.
      rv = c_owned.
    ENDIF.
  ENDMETHOD.


  METHOD api.
*   Identity is built by ZCL_RAK_CJ_CTX, never assembled here - it is the
*   one place that knows the session key is not the &userdata= envelope
*   and that the partner guid has to be derived.
    ro = NEW zcl_rak_property_api( zcl_rak_cj_ctx=>build( mo_e ) ).
  ENDMETHOD.


  METHOD owners.
    IF mv_ownrd = abap_true.
      rt = mt_own.
      RETURN.
    ENDIF.
    mv_ownrd = abap_true.
    TRY.
        DATA(ls) = api( )->managed_owners( ).
        mt_own = ls-rows.
      CATCH cx_root.
        CLEAR mt_own.
    ENDTRY.
    rt = mt_own.
  ENDMETHOD.


  METHOD rows.
    IF mv_read = abap_true.
      rt = mt_rows.
      RETURN.
    ENDIF.
    mv_read = abap_true.

    DATA ls TYPE zcl_rak_property_api=>ty_prop_res.
    TRY.
        DATA(lo) = api( ).
        CASE mode( ).
          WHEN c_grant.
*           GRANTS is a different Partnerrole, not a different read -
*           YTR080 against TR0800. M018, M019 and M020 use it.
            ls = lo->parcels( iv_grants = abap_true ).
          WHEN c_agent.
*           The agent path filters on the OWNER's guid, picked from the
*           managed-owner list. With none picked yet the read would fall
*           back to the citizen's own property, which is the other tab -
*           so it answers nothing instead, and the empty state says why.
            IF mo_e->mv_pcl_owner IS NOT INITIAL.
              ls = lo->parcels( iv_owner_guid = mo_e->mv_pcl_owner ).
            ENDIF.
          WHEN OTHERS.
            ls = lo->parcels( ).
        ENDCASE.
        mt_rows = ls-rows.
        LOOP AT ls-msg INTO DATA(ls_m) WHERE type CA 'EAX'.
          mv_note = ls_m-message.
          EXIT.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx).
        CLEAR mt_rows.
        mv_note = lx->get_text( ).
    ENDTRY.
    rt = mt_rows.
  ENDMETHOD.


  METHOD hits.
*   Search and favourites are applied HERE, over the fetched list, because
*   that is where the legacy control applies them - they are not filters
*   the DPC accepts. Doing it server side rather than in the browser is
*   the whole point: only the matching page is ever rendered.
    DATA(lv_term) = to_upper( condense( mo_e->mv_pcl_term ) ).

    LOOP AT rows( ) INTO DATA(ls_r).
      IF mo_e->mv_pcl_fav = abap_true AND cell( is_row = ls_r iv_comp = 'FAVOURITE' ) IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lv_term IS NOT INITIAL.
        DATA(lv_hay) = to_upper( |{ ls_r-parcelid } { ls_r-building } { ls_r-sectortext } { ls_r-landuse }| ).
        IF lv_hay NS lv_term.
          CONTINUE.
        ENDIF.
      ENDIF.
      APPEND ls_r TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_cj_control~render.
    IF io_view IS NOT BOUND OR is_field-name IS INITIAL.
      RETURN.
    ENDIF.

*   Which field the events belong to. A step can only show one of these at
*   a time in practice, and the event names carry no field of their own.
    mo_e->mv_pcl_field = is_field-name.
    IF mo_e->mv_pcl_page < 1.
      mo_e->mv_pcl_page = 1.
    ENDIF.

    DATA(lo_box) = io_view->vbox( class = 'sapUiTinyMarginBottom' ).

    lo_box->label( text     = is_field-label
                   required = xsdbool( is_field-validation-required = abap_true ) ).

*   What is chosen now, if anything. The citizen has to see the current
*   value without scrolling a list to find which card is highlighted.
    DATA(lv_cur) = mo_e->val_get( is_field-name ).
    IF lv_cur IS NOT INITIAL.
      DATA(lo_cur) = lo_box->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
      lo_cur->object_status( title = t( iv_en = `Selected` iv_ar = `المحدد` )
                             text  = lv_cur
                             state = 'Success'
                             icon  = 'sap-icon://accept' ).
      lo_cur->button( text  = t( iv_en = `Clear` iv_ar = `مسح` )
                      icon  = 'sap-icon://decline'
                      type  = 'Transparent'
                      class = 'sapUiTinyMarginBegin'
                      press = mo_e->mo_client->_event(
                                |{ c_pfx }PICK_{ is_field-name }~| ) ).
    ENDIF.

    IF is_field-readonly = abap_true.
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

    toolbar( lo_box ).

    DATA(lt_hit) = hits( ).
    DATA(lv_n)   = lines( lt_hit ).

    IF mv_note IS NOT INITIAL.
      lo_box->message_strip( text = mv_note type = 'Warning' showicon = abap_true
                             class = 'sapUiTinyMarginBottom' ).
    ENDIF.

    lo_box->text( text  = |{ lv_n } { t( iv_en = `properties found` iv_ar = `عقار` ) }|
                  class = 'sapUiTinyMarginBottom' ).

    IF lv_n = 0.
      lo_box->illustrated_message(
        illustrationtype = 'sapIllus-NoEntries'
        illustrationsize = 'Spot'
        title            = t( iv_en = `Nothing to show`
                              iv_ar = `لا يوجد ما يعرض` )
        description      = COND string(
          WHEN mode( ) = c_agent AND mo_e->mv_pcl_owner IS INITIAL
          THEN t( iv_en = `Pick an owner you act for.`
                  iv_ar = `اختر المالك الذي تنوب عنه.` )
          ELSE t( iv_en = `No property matches. Clear the search, or switch tab.`
                  iv_ar = `لا يوجد عقار مطابق. امسح البحث أو غيّر التبويب.` ) ) ).
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

*   ---- pages. THE ONLY ROWS THAT REACH THE VIEW ----------------------
    DATA(lv_pages) = lv_n DIV c_page_size.
    IF lv_n MOD c_page_size > 0.
      lv_pages = lv_pages + 1.
    ENDIF.
    IF mo_e->mv_pcl_page > lv_pages.
      mo_e->mv_pcl_page = lv_pages.
    ENDIF.

    DATA(lv_from) = ( mo_e->mv_pcl_page - 1 ) * c_page_size + 1.
    DATA(lv_to)   = lv_from + c_page_size - 1.
    IF lv_to > lv_n.
      lv_to = lv_n.
    ENDIF.

    DATA(lv_ix) = 0.
    LOOP AT lt_hit INTO DATA(ls_row).
      lv_ix = lv_ix + 1.
      IF lv_ix < lv_from.
        CONTINUE.
      ENDIF.
      IF lv_ix > lv_to.
        EXIT.
      ENDIF.
      card( io_box = lo_box is_row = ls_row ).
    ENDLOOP.

    IF lv_pages > 1.
      pager( io_box = lo_box iv_pages = lv_pages ).
    ENDIF.

*   The live list closes with this line. No link: the portal points it at a
*   Home Page CJS has no address for, and a dead link is worse than none.
    lo_box->text(
      text  = t( iv_en = `Can't find a parcel? Your properties are listed on your home page.`
                 iv_ar = `لا تجد القطعة؟ عقاراتك مدرجة في صفحتك الرئيسية.` )
      class = 'sapUiTinyMarginTop' ).

    rv_drawn = abap_true.
  ENDMETHOD.


  METHOD toolbar.
    DATA(lo_bar) = io_box->hbox( alignitems = 'Center'
                                 wrap       = 'Wrap'
                                 class      = 'sapUiTinyMarginBottom' ).

*   ->ITEMS( ) IS NOT OPTIONAL. sap.m.SegmentedButton has TWO aggregations:
*   the default one is `buttons` and takes sap.m.Button, while
*   SegmentedButtonItem belongs to `items`. Left off, UI5 refuses the whole
*   view - "Element sap.m.SegmentedButtonItem is not valid for aggregation
*   buttons" - and the citizen gets the red Application Error page rather
*   than a mis-drawn control. RENDER_ONE( )'s own SEGMENTED branch calls
*   ->items( ) for exactly this reason.
    DATA(lo_seg) = lo_bar->segmented_button( selected_key = mode( ) )->items( ).
    lo_seg->segmented_button_item( key   = c_owned
                                   text  = t( iv_en = `Owned` iv_ar = `مملوكة` )
                                   press = mo_e->mo_client->_event( |{ c_pfx }MODE_{ c_owned }| ) ).
    lo_seg->segmented_button_item( key   = c_agent
                                   text  = t( iv_en = `Property Agent` iv_ar = `وكيل عقاري` )
                                   press = mo_e->mo_client->_event( |{ c_pfx }MODE_{ c_agent }| ) ).
    lo_seg->segmented_button_item( key   = c_grant
                                   text  = t( iv_en = `Grants` iv_ar = `المنح` )
                                   press = mo_e->mo_client->_event( |{ c_pfx }MODE_{ c_grant }| ) ).

*   The owner picker belongs to the agent tab only - on the others there
*   is nobody to act for, and an empty dropdown reads as a defect.
    IF mode( ) = c_agent.
      DATA(lo_cb) = lo_bar->combobox(
        selectedkey     = mo_e->mo_client->_bind_edit( mo_e->mv_pcl_owner )
        selectionchange = mo_e->mo_client->_event( |{ c_pfx }OWN| )
        placeholder     = t( iv_en = `Owner you act for` iv_ar = `المالك الذي تنوب عنه` )
        width           = '18rem'
        class           = 'sapUiTinyMarginBegin' ).
      LOOP AT owners( ) INTO DATA(ls_o).
        DATA(lv_gid) = cell( is_row = ls_o iv_comp = 'PARTNERGUID' ).
        IF lv_gid IS INITIAL.
          lv_gid = cell( is_row = ls_o iv_comp = 'GUID' ).
        ENDIF.
        IF lv_gid IS INITIAL.
          CONTINUE.
        ENDIF.
        lo_cb->item( key  = lv_gid
                     text = |{ cell( is_row = ls_o iv_comp = 'NAME' ) } | &&
                            |({ cell( is_row = ls_o iv_comp = 'ID' ) })| ).
      ENDLOOP.
    ENDIF.

    lo_bar->button(
      icon  = 'sap-icon://favorite'
      text  = t( iv_en = `Favourites` iv_ar = `المفضلة` )
      type  = COND #( WHEN mo_e->mv_pcl_fav = abap_true THEN 'Emphasized' ELSE 'Transparent' )
      class = 'sapUiTinyMarginBegin'
      press = mo_e->mo_client->_event( |{ c_pfx }FAV| ) ).

    lo_bar->search_field(
      value       = mo_e->mo_client->_bind_edit( mo_e->mv_pcl_term )
      search      = mo_e->mo_client->_event( |{ c_pfx }FIND| )
      placeholder = t( iv_en = `Parcel, sector or land use` iv_ar = `القطعة أو القطاع أو الاستخدام` )
      width       = '20rem'
      class       = 'sapUiTinyMarginBegin' ).
  ENDMETHOD.


  METHOD card.
*   PARCELID for a parcel, BUILDING for a row that has none - a unit on a
*   building the citizen owns carries the building number and an empty
*   parcel id. ZCL_RAK_CJ_OPTS reads exactly this pair; so does the
*   control, and the value stored has to match.
    DATA(lv_key) = cell( is_row = is_row iv_comp = 'PARCELID' ).
    IF lv_key IS INITIAL.
      lv_key = cell( is_row = is_row iv_comp = 'BUILDING' ).
    ENDIF.
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_int) = cell( is_row = is_row iv_comp = 'INTRENO' ).
    DATA(lv_sec) = cell( is_row = is_row iv_comp = 'SECTORTEXT' ).
    DATA(lv_use) = cell( is_row = is_row iv_comp = 'LANDUSE' ).
    DATA(lv_typ) = cell( is_row = is_row iv_comp = 'TYPE' ).
    DATA(lv_sel) = xsdbool( mo_e->val_get( mo_e->mv_pcl_field ) = lv_key ).

*   THE LIVE CARD SHOWS 507060119, NOT 00000000000507060119. PropertiesSet
*   returns the padded form and the legacy control strips it for display.
*   Display only - LV_KEY, the value the citizen's press STORES, is left
*   exactly as the service returned it, because a draft written by ShapeIt
*   and one written by CJS have to hold the same value and which form
*   ShapeIt stores could not be read off a screenshot. See
*   doc/journeys/m016-change-building-regulations.md.
    DATA(lv_show) = lv_key.
    SHIFT lv_show LEFT DELETING LEADING '0'.
    IF lv_show IS INITIAL.
      lv_show = lv_key.
    ENDIF.

*   The badge the live card carries top right - Legacy / Waiver / Purchase
*   on the three test parcels. An acquisition or ownership type whose
*   component name is NOT confirmed against TS_PROPERTIES yet, so the
*   candidates are tried in order and a miss simply draws no badge. Confirm
*   the real name from ZRAK_CJ_API_DIAG's RTTI dump and cut this list down.
    DATA(lv_badge) = cell( is_row = is_row iv_comp = 'ACQUISITIONTYPE' ).
    IF lv_badge IS INITIAL.
      lv_badge = cell( is_row = is_row iv_comp = 'OWNERSHIPTYPE' ).
    ENDIF.
    IF lv_badge IS INITIAL.
      lv_badge = cell( is_row = is_row iv_comp = 'PARCELSTATUS' ).
    ENDIF.

    DATA(lo_p) = io_box->panel(
      class          = 'sapUiTinyMarginBottom'
      backgrounddesign = 'Solid' ).
    DATA(lo_h) = lo_p->hbox( alignitems = 'Center' class = 'sapUiSmallMarginBeginEnd' ).

    DATA(lo_l) = lo_h->vbox( ).
    DATA(lo_top) = lo_l->hbox( alignitems = 'Center' ).
    lo_top->title( text = lv_show level = 'H5' ).
    IF lv_badge IS NOT INITIAL.
      lo_top->object_status( text  = lv_badge
                             state = 'Information'
                             class = 'sapUiTinyMarginBegin' ).
    ENDIF.

*   ONE meta line, pipe separated, the way the live card draws it: area,
*   land use, type. Blank parts are dropped rather than leaving a stranded
*   separator.
    DATA lt_meta TYPE string_table.
    IF lv_sec IS NOT INITIAL. APPEND lv_sec TO lt_meta. ENDIF.
    IF lv_use IS NOT INITIAL. APPEND lv_use TO lt_meta. ENDIF.
    IF lv_typ IS NOT INITIAL. APPEND lv_typ TO lt_meta. ENDIF.
    DATA(lv_meta) = concat_lines_of( table = lt_meta sep = ` | ` ).
    lo_l->text( text = lv_meta ).

    DATA(lo_r) = lo_h->hbox( alignitems = 'Center' justifycontent = 'End' class = 'sapUiTinyMarginBegin' ).
    lo_r->button(
      text  = COND #( WHEN lv_sel = abap_true THEN t( iv_en = `Selected` iv_ar = `محددة` )
                                              ELSE t( iv_en = `Select`   iv_ar = `اختيار` ) )
      icon  = COND #( WHEN lv_sel = abap_true THEN 'sap-icon://accept' ELSE '' )
      type  = COND #( WHEN lv_sel = abap_true THEN 'Success' ELSE 'Emphasized' )
*     THE FIELD TRAVELS WITH THE EVENT. A step can carry more than one of
*     these - M012 draws PARCELSELECTOR and ADDPRCLCTL side by side - and
*     MV_PCL_FIELD holds only the one that rendered LAST, so a press on the
*     first list would have written the second list's field. The name is in
*     the event instead, and MV_PCL_FIELD is only the fallback.
      press = mo_e->mo_client->_event(
                |{ c_pfx }PICK_{ mo_e->mv_pcl_field }~{ lv_key }| ) ).

*   Full Details needs the INTRENO, which is the entity key the $expand
*   read is addressed with. A row without one gets no link rather than a
*   link that opens an empty dialog.
    IF lv_int IS NOT INITIAL.
      lo_r->link( text  = t( iv_en = `Full Details` iv_ar = `التفاصيل الكاملة` )
                  class = 'sapUiTinyMarginBegin'
                  press = mo_e->mo_client->_event( |{ c_pfx }DET_{ lv_int }| ) ).
    ENDIF.
  ENDMETHOD.


  METHOD pager.
    DATA(lv_p) = mo_e->mv_pcl_page.
    DATA(lo_g) = io_box->hbox( alignitems = 'Center' justifycontent = 'Center' ).

    lo_g->button( icon    = 'sap-icon://close-command-field'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p > 1 )
                  press   = mo_e->mo_client->_event( |{ c_pfx }PAGE_1| ) ).
    lo_g->button( icon    = 'sap-icon://navigation-left-arrow'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p > 1 )
                  press   = mo_e->mo_client->_event( |{ c_pfx }PAGE_{ lv_p - 1 }| ) ).
    lo_g->text( text = |{ lv_p } / { iv_pages }| class = 'sapUiSmallMarginBeginEnd' ).
    lo_g->button( icon    = 'sap-icon://navigation-right-arrow'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p < iv_pages )
                  press   = mo_e->mo_client->_event( |{ c_pfx }PAGE_{ lv_p + 1 }| ) ).
    lo_g->button( icon    = 'sap-icon://open-command-field'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p < iv_pages )
                  press   = mo_e->mo_client->_event( |{ c_pfx }PAGE_{ iv_pages }| ) ).
  ENDMETHOD.


  METHOD pick.
    DATA(lv_f) = iv_field.
    IF lv_f IS INITIAL.
      lv_f = mo_e->mv_pcl_field.
    ENDIF.
    IF lv_f IS INITIAL.
      RETURN.
    ENDIF.
    mo_e->val_set( iv_name = lv_f iv_value = iv_key ).
    mo_e->set_field_state( iv_name = lv_f iv_state = 'None' iv_text = '' ).
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_change( io_ctx = mo_e iv_field = lv_f ).
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_cj_control~on_event.
*   STRLEN FIRST. IV_EVENT is a STRING and an offset past its end raises
*   CX_SY_RANGE_OUT_OF_BOUNDS - E016 shipped exactly that bug, and the
*   engine's TRY/CATCH turned it into a warning on a successful action.
    IF strlen( iv_event ) <= strlen( c_pfx ) OR substring( val = iv_event len = 3 ) <> c_pfx.
      RETURN.
    ENDIF.

    DATA(lv) = substring( val = iv_event off = 3 ).
    rv_handled = abap_true.

*   Matched with CP throughout, so the offset that follows can never run
*   off the end - a pattern match cannot, an offset can.
    IF lv CP 'MODE_*'.
      mo_e->mv_pcl_mode = substring( val = lv off = 5 ).
      mo_e->mv_pcl_page = 1.
      CLEAR mo_e->mv_pcl_owner.

    ELSEIF lv = 'OWN' OR lv = 'FIND'.
*     The value itself arrived through _bind_edit; the event only says the
*     list has to start again from the first page.
      mo_e->mv_pcl_page = 1.

    ELSEIF lv = 'FAV'.
      mo_e->mv_pcl_fav  = xsdbool( mo_e->mv_pcl_fav = abap_false ).
      mo_e->mv_pcl_page = 1.

    ELSEIF lv CP 'PAGE_*'.
      DATA(lv_n) = substring( val = lv off = 5 ).
      IF lv_n CO '0123456789' AND lv_n IS NOT INITIAL.
        mo_e->mv_pcl_page = CONV i( lv_n ).
      ENDIF.

    ELSEIF lv CP 'PICK_*'.
*     <field>~<key>. A trailing empty key is the Clear button.
      SPLIT substring( val = lv off = 5 ) AT '~' INTO DATA(lv_fld) DATA(lv_key).
      pick( iv_field = lv_fld iv_key = lv_key ).

    ELSEIF lv CP 'DET_*'.
      mo_e->mv_pcl_det = substring( val = lv off = 4 ).
      mo_e->mv_pcl_tab = 'MAP'.
      mo_e->mv_popup   = c_popup.

    ELSEIF lv = 'CLOSE'.
      CLEAR: mo_e->mv_pcl_det, mo_e->mv_pcl_tab, mo_e->mv_popup.

    ELSE.
      CLEAR rv_handled.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_cj_control~render_popup.
    IF io_popup IS NOT BOUND OR mo_e->mv_pcl_det IS INITIAL.
      RETURN.
    ENDIF.

*   CONTENTHEIGHT because of the map. A dialog sized to its content gives
*   an iframe no room to be - the frame collapses and the tab looks empty.
    DATA(lo_dlg) = io_popup->dialog(
      title         = t( iv_en = `Property Details` iv_ar = `تفاصيل العقار` )
      contentwidth  = '58rem'
      contentheight = '34rem' ).
    DATA(lo_c) = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   NO select EVENT. An IconTabBar switches tabs in the browser, and every
*   tab's content is already in this view - a round trip here would repaint
*   the page to show markup the client already has. SELECTEDKEY only says
*   which tab opens first.
*   ->ITEMS( ) AGAIN, for the same class of reason as the SegmentedButton
*   below: UI5's XML parser reports "Cannot add direct child without
*   default aggregation defined for control sap.m.IconTabBar", so a filter
*   written as a direct child kills the whole fragment. Both aggregations
*   here are named explicitly rather than relying on a default - a control
*   that HAS one loses nothing by being told, and one that has not takes
*   the app down.
    DATA(lo_bar) = lo_c->icon_tab_bar(
      selectedkey = COND #( WHEN mo_e->mv_pcl_tab IS INITIAL THEN 'MAP' ELSE mo_e->mv_pcl_tab ) )->items( ).

*   ---- Map. The ONLY tab CJS can serve today, because MapUrlSet has a
*   flat _GET_ENTITYSET and the other six are $expand children.
    DATA(lo_map) = lo_bar->icon_tab_filter(
      key = 'MAP' text = t( iv_en = `Map` iv_ar = `الخريطة` ) )->content( )->vbox( ).
    DATA ls_map TYPE zcl_rak_property_api=>ty_map_res.
    TRY.
        ls_map = api( )->map_url( iv_parcel = mo_e->mv_pcl_det ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.
    DATA(lv_src) = COND string( WHEN ls_map-gisurl IS NOT INITIAL
                                THEN ls_map-gisurl ELSE ls_map-url ).
    IF lv_src IS NOT INITIAL.
*     EMBEDDED, the way the legacy dialog draws it - the citizen sees the
*     parcel outlined on the map inside the tab, not a link that takes them
*     somewhere else. SANITIZECONTENT must be OFF or the iframe is stripped
*     and the tab renders blank; the engine already does exactly this for
*     its own OPEN_URL_HTML( ).
*
*     The URL goes into an HTML attribute, so a double quote in it would
*     close the attribute early and let the rest of the string become
*     markup. It is percent-encoded rather than trusted - the value comes
*     from a backend read, not from this code.
      DATA(lv_esc) = lv_src.
      REPLACE ALL OCCURRENCES OF '"' IN lv_esc WITH '%22'.

*     HTTP INSIDE AN HTTPS PAGE IS BLOCKED BY THE BROWSER, and Chrome says
*     so as "This content is blocked. Contact the site owner to fix the
*     issue." - which reads like a server problem and is not one. The
*     backend returns whatever scheme it was configured with; the frame
*     gets the secure one. The LINK below keeps the URL exactly as given,
*     because a new tab has no mixed-content rule to break.
*
*     If the frame is still blocked after this, it is the GIS host
*     refusing to be framed at all (X-Frame-Options / frame-ancestors) and
*     nothing on this page can change that - the link is then the answer,
*     which is why it is there.
      IF lv_esc CP 'http://*'.
        lv_esc = |https://{ substring( val = lv_esc off = 7 ) }|.
      ENDIF.
      lo_map->html(
        content         = |<iframe src="{ lv_esc }" title="parcel map" | &&
                          |style="width:100%;height:26rem;border:0"></iframe>|
        sanitizecontent = abap_false ).

*     AND THE LINK STAYS, underneath. The GIS viewer is a third-party page
*     that sets its own frame policy: if it refuses to be framed the iframe
*     is a blank rectangle with nothing to explain it, and this line is the
*     way out. It costs one row and it is the difference between "the map
*     is broken" and "the map opens in a tab".
      lo_map->link( text   = t( iv_en = `Open the map in a new tab`
                                iv_ar = `افتح الخريطة في تبويب جديد` )
                    href   = lv_src
                    target = '_blank'
                    icon   = 'sap-icon://map'
                    class  = 'sapUiTinyMarginTop' ).
    ELSE.
      lo_map->message_strip( text = t( iv_en = `No map is registered for this parcel`
                                       iv_ar = `لا توجد خريطة مسجلة لهذه القطعة` )
                             type = 'Information' showicon = abap_true ).
    ENDIF.

*   ---- the six behind GET_EXPANDED_ENTITYSET. Drawn with the LIVE
*   dialog's own column headers so that filling them later is a data call
*   and not a redesign - see doc/controls/shapeit-reads.md.
    blocked_tab( io_bar = lo_bar iv_key = 'GEN'  iv_exp = 'ToProject'
                 iv_text = t( iv_en = `General` iv_ar = `عام` )
                 iv_cols = `Area Name^Address^Property Type^Active Projects` ).
    blocked_tab( io_bar = lo_bar iv_key = 'BP'   iv_exp = 'ToPartner'
                 iv_text = t( iv_en = `Business Partners` iv_ar = `الشركاء` )
                 iv_cols = `Role^BP number^Name^Valid From` ).
    blocked_tab( io_bar = lo_bar iv_key = 'LAND' iv_exp = 'ToLandUse'
                 iv_text = t( iv_en = `Land` iv_ar = `الأرض` )
                 iv_cols = `Characteristic^Value^Unit^Valid From` ).
    blocked_tab( io_bar = lo_bar iv_key = 'DEV'  iv_exp = 'ToDevelopment'
                 iv_text = t( iv_en = `Development` iv_ar = `التطوير` )
                 iv_cols = `Building Type^Building Number^Building Name^Valid From` ).
    blocked_tab( io_bar = lo_bar iv_key = 'MEAS' iv_exp = 'ToMeasurement'
                 iv_text = t( iv_en = `Measurements` iv_ar = `القياسات` )
                 iv_cols = `Measurements Type^Amount^Unit^Valid From` ).
    blocked_tab( io_bar = lo_bar iv_key = 'DOC'  iv_exp = 'ToAttachment'
                 iv_text = t( iv_en = `Documents` iv_ar = `المستندات` )
                 iv_cols = `Number^Department^Issuing date^Expiry Date` ).

    lo_dlg->buttons( )->button( text  = t( iv_en = `Close` iv_ar = `إغلاق` )
                                press = mo_e->mo_client->_event( |{ c_pfx }CLOSE| ) ).
    rv_drawn = abap_true.
  ENDMETHOD.


  METHOD blocked_tab.
    DATA(lo_v) = io_bar->icon_tab_filter( key = iv_key text = iv_text )->content( )->vbox( ).

    DATA(lo_t) = lo_v->table( ).
    DATA(lo_h) = lo_t->columns( ).
    SPLIT iv_cols AT '^' INTO TABLE DATA(lt_c).
    LOOP AT lt_c INTO DATA(lv_c).
      lo_h->column( )->text( lv_c ).
    ENDLOOP.

*   Named, never blank. An empty table here would read as "this parcel has
*   none of these", which is a different statement from "CJS cannot fetch
*   them yet" - and the second one is true.
    lo_v->message_strip(
      text     = |{ t( iv_en = `Not available yet: ` iv_ar = `غير متاح بعد: ` ) }| &&
                 |{ iv_exp } | &&
                 |{ t( iv_en = `is read through GET_EXPANDED_ENTITYSET, which needs an expand object.`
                       iv_ar = `يُقرأ عبر GET_EXPANDED_ENTITYSET ويحتاج إلى كائن توسيع.` ) }|
      type     = 'Information'
      showicon = abap_true
      class    = 'sapUiTinyMarginTop' ).
  ENDMETHOD.

ENDCLASS.
