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

*   TWO SELECTORS ON ONE STEP. M012 carries PARCELSELECTOR and ADDPRCLCTL
*   side by side, and the browse state on the engine is one set of scalars.
*   Left as it was, paging the first list paged the second, and switching
*   the first to Grants re-read the second against a role it never asked
*   for.
*
*   MV_FLD is the field being drawn right now; MV_MINE says whether the
*   engine's shared state belongs to it. Every event name now carries the
*   field, so a press MOVES ownership to the list that was pressed, and a
*   list that does not own the state draws itself from the defaults -
*   Owned, page 1, no favourites filter, no search term.
*
*   ONE RESIDUE, DELIBERATELY LEFT: the search box and the owner dropdown
*   are TWO-WAY BOUND, and z2ui5 binds to a PUBLIC CLASS ATTRIBUTE - it
*   resolves the binding by searching the app's attributes for the data
*   reference (Z2UI5_CL_CORE_SRV_BIND->MAIN( )), so a per-field value held
*   in an internal table cannot be bound at all. Both boxes therefore show
*   the same text. The list that does not own the state IGNORES it, so no
*   list is ever filtered by a term typed into another one; only the text
*   in the box is shared. Backlog 4.4 - the real answer is probably one
*   multi-select list rather than two.
    DATA mv_fld  TYPE string.
    DATA mv_mine TYPE abap_bool.

*   The list/map toggle. MAP draws the same owned parcels as ArcGIS
*   features and takes the selection from a click on the map, which is
*   what RakMap.Map does in the ShapeIt app; LIST is the card list and
*   stays the default, because a map needs a working GIS configuration
*   and the list needs nothing.
    CONSTANTS c_vlist TYPE string VALUE 'LIST'.
    CONSTANTS c_vmap  TYPE string VALUE 'MAP'.
    METHODS view RETURNING VALUE(rv) TYPE string.
*   The map, drawn from the parcels currently in view.
    METHODS map_block IMPORTING io_box TYPE REF TO z2ui5_cl_xml_view
                                it_hit TYPE zcl_rak_property_api=>tt_prop_rows.

*   The read is cached for the round trip, and the cache is keyed by what
*   the read actually depends on. Two selectors in one round trip can ask
*   for two different modes, and an unkeyed flag handed the second one the
*   first one's rows.
    DATA mv_key   TYPE string.

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

*   The effective browse state for the list being drawn: the engine's
*   shared scalars when this list owns them, the defaults when it does not.
    METHODS mode RETURNING VALUE(rv) TYPE string.
    METHODS term RETURNING VALUE(rv) TYPE string.
    METHODS fav  RETURNING VALUE(rv) TYPE abap_bool.
    METHODS page RETURNING VALUE(rv) TYPE i.
    METHODS owner RETURNING VALUE(rv) TYPE string.
*   <event>~<field>. Every browse event carries the field it belongs to so
*   the press can claim the shared state before it is read.
    METHODS ev IMPORTING iv_name  TYPE string
               RETURNING VALUE(rv) TYPE string.

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
    IF mv_mine = abap_false.
      rv = c_owned.
      RETURN.
    ENDIF.
    rv = mo_e->mv_pcl_mode.
    IF rv IS INITIAL.
      rv = c_owned.
    ENDIF.
  ENDMETHOD.


  METHOD term.
    IF mv_mine = abap_true.
      rv = mo_e->mv_pcl_term.
    ENDIF.
  ENDMETHOD.


  METHOD view.
*   LIST unless this list owns the state AND asked for the map AND the
*   GIS endpoints are configured. Three conditions, and the last one is
*   why: ZCL_RAK_CJ_GIS refuses to draw without a feature service, and a
*   toggle that silently lands on an empty box is worse than no toggle.
    rv = c_vlist.
    IF mv_mine = abap_true AND mo_e->mv_pcl_view = c_vmap
       AND zcl_rak_cj_gis=>ready( ) = abap_true.
      rv = c_vmap.
    ENDIF.
  ENDMETHOD.


  METHOD fav.
    IF mv_mine = abap_true.
      rv = mo_e->mv_pcl_fav.
    ENDIF.
  ENDMETHOD.


  METHOD owner.
    IF mv_mine = abap_true.
      rv = mo_e->mv_pcl_owner.
    ENDIF.
  ENDMETHOD.


  METHOD page.
    IF mv_mine = abap_false.
      rv = 1.
      RETURN.
    ENDIF.
    rv = mo_e->mv_pcl_page.
    IF rv < 1.
      rv = 1.
    ENDIF.
  ENDMETHOD.


  METHOD ev.
    rv = mo_e->mo_client->_event( |{ c_pfx }{ iv_name }~{ mv_fld }| ).
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
*   KEYED, not a flag. Two selectors in one round trip can ask for two
*   different modes; a bare "already read" flag handed the second list the
*   first list's rows.
    DATA(lv_key) = |{ mode( ) }/{ owner( ) }|.
    IF mv_read = abap_true AND mv_key = lv_key.
      rt = mt_rows.
      RETURN.
    ENDIF.
    mv_read = abap_true.
    mv_key  = lv_key.
    CLEAR: mt_rows, mv_note.

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
            IF owner( ) IS NOT INITIAL.
              ls = lo->parcels( iv_owner_guid = owner( ) ).
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
    DATA(lv_term) = to_upper( condense( term( ) ) ).

    LOOP AT rows( ) INTO DATA(ls_r).
      IF fav( ) = abap_true AND cell( is_row = ls_r iv_comp = 'FAVOURITE' ) IS INITIAL.
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

*   WHICH FIELD IS BEING DRAWN, and whether it owns the engine's shared
*   browse state. Assigning MV_PCL_FIELD here unconditionally was the bug:
*   with two selectors on one step the second overwrote the first, so both
*   toolbars drove the second list. Ownership now moves on a PRESS, not on
*   a paint - the first selector to be drawn claims it only when nothing
*   holds it yet.
    mv_fld = is_field-name.
    IF mo_e->mv_pcl_field IS INITIAL.
      mo_e->mv_pcl_field = is_field-name.
    ENDIF.
    mv_mine = xsdbool( mo_e->mv_pcl_field = is_field-name ).
    IF mv_mine = abap_true AND mo_e->mv_pcl_page < 1.
      mo_e->mv_pcl_page = 1.
    ENDIF.

    DATA(lo_box) = io_view->vbox( class = 'rakPcl sapUiTinyMarginBottom' ).

*   A HEADING AND A SUBLINE, not a field label. The live screen opens the
*   step with "Parcel Selection" and "Please select a property from the
*   list" - this is a section of the page, and a form label above it reads
*   as though the whole list were one input.
    lo_box->title( text = is_field-label level = 'H4' ).
    IF is_field-placeholder IS NOT INITIAL.
      lo_box->text( text = is_field-placeholder class = 'rakPclMeta' ).
    ENDIF.

*   What is chosen now, if anything. The citizen has to see the current
*   value without scrolling a list to find which card is highlighted.
    DATA(lv_cur) = mo_e->val_get( mv_fld ).
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
                                |{ c_pfx }PICK_{ mv_fld }~| ) ).
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
                  class = 'rakPclMeta sapUiTinyMarginBottom' ).

    IF lv_n = 0.
      lo_box->illustrated_message(
        illustrationtype = 'sapIllus-NoEntries'
        illustrationsize = 'Spot'
        title            = t( iv_en = `Nothing to show`
                              iv_ar = `لا يوجد ما يعرض` )
        description      = COND string(
          WHEN mode( ) = c_agent AND owner( ) IS INITIAL
          THEN t( iv_en = `Pick an owner you act for.`
                  iv_ar = `اختر المالك الذي تنوب عنه.` )
          ELSE t( iv_en = `No property matches. Clear the search, or switch tab.`
                  iv_ar = `لا يوجد عقار مطابق. امسح البحث أو غيّر التبويب.` ) ) ).
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

*   ---- the map, when it is the chosen view ---------------------------
*   Every hit goes to the map at once rather than a page of five: a map
*   is not paginated, and the whole point of it is seeing which of your
*   parcels is where. The cost is the id list, not the geometry - the
*   features are fetched by the browser from the feature service.
    IF view( ) = c_vmap.
      map_block( io_box = lo_box it_hit = lt_hit ).
      rv_drawn = abap_true.
      RETURN.
    ENDIF.

*   ---- pages. THE ONLY ROWS THAT REACH THE VIEW ----------------------
    DATA(lv_pages) = lv_n DIV c_page_size.
    IF lv_n MOD c_page_size > 0.
      lv_pages = lv_pages + 1.
    ENDIF.
    IF mv_mine = abap_true AND mo_e->mv_pcl_page > lv_pages.
      mo_e->mv_pcl_page = lv_pages.
    ENDIF.

    DATA(lv_from) = ( page( ) - 1 ) * c_page_size + 1.
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
      class = 'rakPclHint sapUiTinyMarginTop' ).

    rv_drawn = abap_true.
  ENDMETHOD.


  METHOD toolbar.
*   THE SEARCH SITS AT THE FAR RIGHT. On the live toolbar the tabs and the
*   favourites pill group on the left and the search box is pushed away
*   from them - .rakPclBar gives it the auto margin that does that, so the
*   row still collapses sensibly when it wraps.
    DATA(lo_bar) = io_box->hbox( alignitems = 'Center'
                                 wrap       = 'Wrap'
                                 class      = 'rakPclBar sapUiTinyMarginBottom' ).

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
                                   press = ev( |MODE_{ c_owned }| ) ).
    lo_seg->segmented_button_item( key   = c_agent
                                   text  = t( iv_en = `Property Agent` iv_ar = `وكيل عقاري` )
                                   press = ev( |MODE_{ c_agent }| ) ).
    lo_seg->segmented_button_item( key   = c_grant
                                   text  = t( iv_en = `Grants` iv_ar = `المنح` )
                                   press = ev( |MODE_{ c_grant }| ) ).

*   The owner picker belongs to the agent tab only - on the others there
*   is nobody to act for, and an empty dropdown reads as a defect.
    IF mode( ) = c_agent.
      DATA(lo_cb) = lo_bar->combobox(
        selectedkey     = mo_e->mo_client->_bind_edit( mo_e->mv_pcl_owner )
        selectionchange = ev( `OWN` )
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
      type  = COND #( WHEN fav( ) = abap_true THEN 'Emphasized' ELSE 'Transparent' )
      class = 'sapUiTinyMarginBegin'
      press = ev( `FAV` ) ).

*   LIST / MAP. Offered only where the GIS endpoints are configured -
*   see VIEW( ). A button rather than a second SegmentedButton: the
*   segmented control on the left already means "whose properties", and
*   two of them side by side read as one four-way choice.
    IF zcl_rak_cj_gis=>ready( ) = abap_true.
      lo_bar->button(
        icon  = COND #( WHEN view( ) = c_vmap THEN 'sap-icon://list' ELSE 'sap-icon://map' )
        text  = COND #( WHEN view( ) = c_vmap THEN t( iv_en = `List` iv_ar = `قائمة` )
                                              ELSE t( iv_en = `Map`  iv_ar = `خريطة` ) )
        type  = 'Transparent'
        class = 'sapUiTinyMarginBegin'
        press = ev( COND #( WHEN view( ) = c_vmap THEN |VIEW_{ c_vlist }|
                            ELSE |VIEW_{ c_vmap }| ) ) ).
    ENDIF.

    lo_bar->search_field(
      value       = mo_e->mo_client->_bind_edit( mo_e->mv_pcl_term )
      search      = ev( `FIND` )
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
    DATA(lv_sel) = xsdbool( mo_e->val_get( mv_fld ) = lv_key ).

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

*   LAID OUT LIKE THE LIVE CARD, not like a form row. Screenshots of
*   RAKPARCELSELECTOR on M016: number top left, acquisition badge top
*   right in a pale pill, one grey pipe-separated meta line beneath, and
*   the actions bottom right. The red left edge is the card's own; it is
*   what makes a list of these read as a list of properties rather than a
*   stack of panels. Layout and colour live in ZCL_RAK_JOURNEY_CSS
*   (.rakPcl*) so the markup stays readable with none of it applied.
    DATA(lo_p) = io_box->vbox( class = |{ mo_e->mo_css->cls( 'CARD' ) } rakPclCard| ).

    DATA(lo_top) = lo_p->hbox( class = 'rakPclTop' ).
    lo_top->title( text = lv_show level = 'H5' class = 'rakPclNo' ).
    IF lv_badge IS NOT INITIAL.
      lo_top->object_status( text = lv_badge class = 'rakPclBadge' ).
    ENDIF.

*   ONE meta line, pipe separated, the way the live card draws it: area,
*   land use, type. Blank parts are dropped rather than leaving a stranded
*   separator.
    DATA lt_meta TYPE string_table.
    IF lv_sec IS NOT INITIAL. APPEND lv_sec TO lt_meta. ENDIF.
    IF lv_use IS NOT INITIAL. APPEND lv_use TO lt_meta. ENDIF.
    IF lv_typ IS NOT INITIAL. APPEND lv_typ TO lt_meta. ENDIF.
    lo_p->text( text  = concat_lines_of( table = lt_meta sep = ` | ` )
                class = 'rakPclMeta' ).

    DATA(lo_act) = lo_p->hbox( class = 'rakPclAct' ).

*   Full Details FIRST and quiet, Select last and emphasised - the live
*   card puts the commitment at the end of the row, and a link beside a
*   filled button reads as the secondary action without needing to say so.
*   A row without an INTRENO gets no link rather than a link that opens an
*   empty dialog: the $expand read is addressed by that key.
    IF lv_int IS NOT INITIAL.
      lo_act->link( text  = t( iv_en = `Full Details` iv_ar = `التفاصيل الكاملة` )
                    icon  = 'sap-icon://detail-view'
                    press = mo_e->mo_client->_event(
                              |{ c_pfx }DET_{ lv_int }~{ lv_show }| ) ).
    ENDIF.

    lo_act->button(
      text  = COND #( WHEN lv_sel = abap_true THEN t( iv_en = `Selected` iv_ar = `محددة` )
                                              ELSE t( iv_en = `Select`   iv_ar = `اختيار` ) )
      icon  = COND #( WHEN lv_sel = abap_true THEN 'sap-icon://accept' ELSE '' )
      type  = COND #( WHEN lv_sel = abap_true THEN 'Success' ELSE 'Emphasized' )
      press = mo_e->mo_client->_event(
                |{ c_pfx }PICK_{ mv_fld }~{ lv_key }| ) ).
  ENDMETHOD.


  METHOD map_block.

*   THE IDS THE MAP MAY SHOW, unpadded. Map.js holds envProxy
*   .ownedProperties in the form the citizen reads and builds
*   "PARCELID IN (...)" straight out of it, so the GIS side of the join
*   is the trimmed number - not the 00000000000507060119 the DPC returns.
*   PICK( ) converts back, so what a map click STORES is still the
*   service's own form and a draft written here and one written by
*   ShapeIt hold the same value.
    DATA lt_ids TYPE string_table.
    LOOP AT it_hit INTO DATA(ls_r).
      DATA(lv_k) = cell( is_row = ls_r iv_comp = 'PARCELID' ).
      IF lv_k IS INITIAL.
        CONTINUE.
      ENDIF.
      SHIFT lv_k LEFT DELETING LEADING '0'.
      IF lv_k IS NOT INITIAL.
        APPEND lv_k TO lt_ids.
      ENDIF.
    ENDLOOP.

*   The token is read per parcel, so the focused one is asked for; with
*   nothing chosen yet the first row does, because MapUrlSet's filter is
*   mandatory and any owned parcel mints a token for the same server.
    DATA(lv_sel) = mo_e->val_get( mv_fld ).
    DATA(lv_foc) = lv_sel.
    SHIFT lv_foc LEFT DELETING LEADING '0'.

    DATA ls_map TYPE zcl_rak_property_api=>ty_map_res.
    TRY.
        ls_map = api( )->map_url( iv_parcel = COND #(
          WHEN lv_sel IS NOT INITIAL THEN lv_sel
          ELSE VALUE #( lt_ids[ 1 ] OPTIONAL ) ) ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    DATA(lv_html) = zcl_rak_cj_gis=>block(
      iv_portal = ls_map-url
      iv_server = ls_map-gisurl
      iv_token  = ls_map-token
      iv_div    = |rakGis{ to_upper( mv_fld ) }|
      it_ids    = lt_ids
      iv_focus  = lv_foc
*     A click on a parcel the citizen owns is a selection, exactly as it
*     is on a card. The event name is the card's own, so both paths meet
*     in PICK( ) and neither can drift from the other.
      iv_event  = |{ c_pfx }PICK_{ mv_fld }|
      iv_ctrl   = 'oController'
      iv_height = '30rem' ).

*   NEVER AN EMPTY BOX. BLOCK( ) answers blank when the GIS endpoints are
*   not configured; VIEW( ) already refuses the map in that case, so this
*   is the belt to that brace rather than the expected path.
    IF lv_html IS INITIAL.
      io_box->message_strip(
        text     = t( iv_en = `The map is not configured on this system.`
                      iv_ar = `الخريطة غير مهيأة على هذا النظام.` )
        type     = 'Information'
        showicon = abap_true ).
      RETURN.
    ENDIF.
    io_box->html( content = lv_html sanitizecontent = abap_false ).

    io_box->text(
      text  = t( iv_en = `Tap a parcel on the map to select it.`
                 iv_ar = `اضغط على القطعة في الخريطة لاختيارها.` )
      class = 'rakPclHint sapUiTinyMarginTop' ).

  ENDMETHOD.


  METHOD pager.
    DATA(lv_p) = page( ).
    DATA(lo_g) = io_box->hbox( alignitems = 'Center' justifycontent = 'Center' ).

    lo_g->button( icon    = 'sap-icon://close-command-field'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p > 1 )
                  press   = ev( `PAGE_1` ) ).
    lo_g->button( icon    = 'sap-icon://navigation-left-arrow'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p > 1 )
                  press   = ev( |PAGE_{ lv_p - 1 }| ) ).
    lo_g->text( text = |{ lv_p } / { iv_pages }| class = 'sapUiSmallMarginBeginEnd' ).
    lo_g->button( icon    = 'sap-icon://navigation-right-arrow'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p < iv_pages )
                  press   = ev( |PAGE_{ lv_p + 1 }| ) ).
    lo_g->button( icon    = 'sap-icon://open-command-field'
                  type    = 'Transparent'
                  enabled = xsdbool( lv_p < iv_pages )
                  press   = ev( |PAGE_{ iv_pages }| ) ).
  ENDMETHOD.


  METHOD pick.
    DATA(lv_f) = iv_field.
    IF lv_f IS INITIAL.
      lv_f = mo_e->mv_pcl_field.
    ENDIF.
    IF lv_f IS INITIAL.
      RETURN.
    ENDIF.

*   WHAT IS STORED IS ALWAYS THE SERVICE'S OWN FORM. A card press carries
*   the padded PARCELID the DPC returned; a MAP click carries the trimmed
*   one, because that is what the GIS feature service holds and what
*   Map.js compares against. Storing whichever arrived would mean a draft
*   saved from the map and one saved from the list held different values
*   for the same parcel - the divergence 4.3 is about, arriving through
*   the back door.
*
*   So an incoming key is matched against the rows and replaced by the
*   row's own key. A key that matches nothing is stored as it came: this
*   resolves, it does not validate.
    DATA(lv_key) = iv_key.
    IF lv_key IS NOT INITIAL.
      LOOP AT rows( ) INTO DATA(ls_pr).
        DATA(lv_pk) = cell( is_row = ls_pr iv_comp = 'PARCELID' ).
        IF lv_pk IS INITIAL.
          lv_pk = cell( is_row = ls_pr iv_comp = 'BUILDING' ).
        ENDIF.
        IF lv_pk IS INITIAL.
          CONTINUE.
        ENDIF.
        DATA(lv_pt) = lv_pk.
        SHIFT lv_pt LEFT DELETING LEADING '0'.
        IF lv_pk = lv_key OR lv_pt = lv_key.
          lv_key = lv_pk.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    mo_e->val_set( iv_name = lv_f iv_value = lv_key ).
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

*   THE PRESS CLAIMS THE STATE. Every browse event is written by EV( ) as
*   <name>~<field>, so a press on the second selector of a step makes that
*   selector the owner of MV_PCL_MODE, _OWNER, _FAV, _TERM and _PAGE before
*   any of them is read again. PICK_ and DET_ carry their own payload after
*   the tilde and are split separately below.
    IF lv NP 'PICK_*' AND lv NP 'DET_*' AND lv CS '~'.
*     NOT "SPLIT lv ... INTO lv ..." - the same variable as source and as
*     first target is not something to rely on. Split into two of its own.
      SPLIT lv AT '~' INTO DATA(lv_ev) DATA(lv_own).
      lv = lv_ev.
      IF lv_own IS NOT INITIAL AND lv_own <> mo_e->mv_pcl_field.
*       A DIFFERENT LIST. Its own state starts from the defaults rather
*       than inheriting whatever the previous owner was showing - the
*       press that moved ownership is a first interaction with this list,
*       not a continuation of the other one.
*
*       MV_PCL_TERM IS NOT CLEARED HERE, and that is deliberate: it is
*       TWO-WAY BOUND, so by the time this runs the client has already
*       written whatever the citizen typed into it. Clearing it on a FIND
*       would throw away the search that caused the event. The owner guid
*       and the mode go, because the new list opens on Owned where the
*       owner dropdown is not even drawn.
        mo_e->mv_pcl_field = lv_own.
        CLEAR: mo_e->mv_pcl_mode, mo_e->mv_pcl_owner,
               mo_e->mv_pcl_fav,  mo_e->mv_pcl_view.
        mo_e->mv_pcl_page = 1.
      ENDIF.
    ENDIF.

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

    ELSEIF lv CP 'VIEW_*'.
      mo_e->mv_pcl_view = substring( val = lv off = 5 ).

    ELSEIF lv CP 'PAGE_*'.
      DATA(lv_n) = substring( val = lv off = 5 ).
      IF lv_n CO '0123456789' AND lv_n IS NOT INITIAL.
        mo_e->mv_pcl_page = CONV i( lv_n ).
      ENDIF.

    ELSEIF lv CP 'PICK_*'.
*     <field>~<key>. A trailing empty key is the Clear button.
      SPLIT substring( val = lv off = 5 ) AT '~' INTO DATA(lv_fld) DATA(lv_key).
*     A pick is an interaction with that list too, so it takes ownership -
*     without resetting the browse state, because the citizen is still
*     looking at the page they picked from.
      IF lv_fld IS NOT INITIAL.
        mo_e->mv_pcl_field = lv_fld.
      ENDIF.
      pick( iv_field = lv_fld iv_key = lv_key ).

    ELSEIF lv CP 'DET_*'.
      SPLIT substring( val = lv off = 4 ) AT '~' INTO mo_e->mv_pcl_det
                                                      mo_e->mv_pcl_pid.
      mo_e->mv_pcl_tab = 'MAP'.
      mo_e->mv_popup   = c_popup.

    ELSEIF lv = 'CLOSE'.
      CLEAR: mo_e->mv_pcl_det, mo_e->mv_pcl_pid, mo_e->mv_pcl_tab, mo_e->mv_popup.

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
*       THE PARCEL NUMBER, not the INTRENO. MapUrlSet's filter is called
*       Parcel and a parcel has two identifiers - the internal object id
*       the tabs are addressed by, and the number the citizen reads. The
*       intreno was tried and the viewer answered with its own splash
*       screen: a token was minted, so the read succeeded, but it encoded
*       no parcel. The number is the other candidate and the only one
*       left that is not a guess about URL formatting.
        ls_map = api( )->map_url( iv_parcel = COND #(
          WHEN mo_e->mv_pcl_pid IS NOT INITIAL THEN mo_e->mv_pcl_pid
          ELSE mo_e->mv_pcl_det ) ).
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.
*   THE TOKEN IS NEVER IN THE URL. GISMAPPINGIM.JS settles it:
*
*     function DefconReciveMessage(messageData, origin) {
*       if (!DefconOriginValidation(origin)) { showForbidden(); return; }
*       if (messageData.parcelId) { Param_ParcelId = messageData.parcelId; }
*       if (messageData.token)    { Param_Token    = messageData.token;    }
*       if (messageData.lang)     { App_Language   = messageData.lang;     }
*       DefconAuth();
*     }
*
*   The page is loaded BARE and the three values arrive by postMessage.
*   Any of them missing and it shows its forbidden panel; the origin is
*   checked against an allowlist that already contains devgrpportal.rak.ae.
*   Six URL shapes were tried against this and none of them could ever
*   have worked - the viewer was sitting on its splash screen waiting for
*   a message that never came.
    DATA(lv_base) = COND string( WHEN ls_map-gisurl CP 'http*' THEN ls_map-gisurl
                                 WHEN ls_map-url CP 'http*'    THEN ls_map-url ).
    DATA(lv_tok)  = COND string( WHEN ls_map-token IS NOT INITIAL THEN ls_map-token
                                 WHEN ls_map-url NP 'http*'       THEN ls_map-url ).
    DATA(lv_pid)  = mo_e->mv_pcl_pid.

*   ---- THE REAL CONTROL FIRST, the iframe only as a fallback.
*   util/Map.js settles what RakMap.Map is: an ArcGIS MapView rendered
*   INSIDE the application page, not a framed site. Where the feature
*   service is configured, CJS draws the same thing.
*
*   The iframe below is the OTHER map - gismappingIM.js, the standalone
*   Defcon viewer, which takes parcelId/token/lang by postMessage. It is
*   a real page and a real fallback, so it stays; it is simply not what
*   this dialog's map tab was.
    IF zcl_rak_cj_gis=>ready( ) = abap_true AND lv_pid IS NOT INITIAL.

      DATA(lv_gis) = zcl_rak_cj_gis=>block(
        iv_portal = ls_map-url
        iv_server = ls_map-gisurl
        iv_token  = ls_map-token
        iv_div    = |rakGisDet{ to_upper( lv_pid ) }|
        it_ids    = VALUE string_table( ( lv_pid ) )
        iv_focus  = lv_pid
*       NO CLICK EVENT. This map shows one parcel that is already chosen;
*       there is nothing here for a press to select.
        iv_event  = ``
        iv_ctrl   = 'oControllerPopup'
        iv_height = '26rem' ).
      lo_map->html( content = lv_gis sanitizecontent = abap_false ).

    ELSEIF lv_base IS NOT INITIAL AND lv_tok IS NOT INITIAL AND lv_pid IS NOT INITIAL.
*     The frame's own origin, which postMessage needs as its target. Sent
*     explicitly rather than as '*' - the token is a credential and a
*     wildcard target hands it to whatever happens to be framed.
      DATA(lv_org) = lv_base.
      DATA(lv_p3)  = find( val = lv_org sub = `/` occ = 3 ).
      IF lv_p3 > 0.
        lv_org = substring( val = lv_org len = lv_p3 ).
      ENDIF.

*     Single quotes and backslashes cannot reach a JS string literal
*     intact. None of these three values should contain either, but they
*     come from a backend read rather than from this code.
      DATA(lv_jtok) = lv_tok.
      DATA(lv_jpid) = lv_pid.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jtok WITH `\\`.
      REPLACE ALL OCCURRENCES OF `'` IN lv_jtok WITH `\'`.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jpid WITH `\\`.
      REPLACE ALL OCCURRENCES OF `'` IN lv_jpid WITH `\'`.
      DATA(lv_lang) = COND string( WHEN sy-langu = 'A' THEN `ar` ELSE `en` ).

*     RETRIED, not sent once. The listener is attached by the page's own
*     script, which may not have run when the frame fires load - a single
*     post would then arrive before anything was listening and the viewer
*     would wait for ever. Ten attempts half a second apart, then it stops
*     rather than polling for the life of the dialog.
      lo_map->html(
        content = |<iframe id="rakPclMap" src="{ lv_base }" title="parcel map" | &&
                  |style="width:100%;height:26rem;border:0"></iframe>| &&
                  |<script>(function()\{var f=document.getElementById("rakPclMap");| &&
                  |if(!f)return;var m=\{parcelId:'{ lv_jpid }',token:'{ lv_jtok }',| &&
                  |lang:'{ lv_lang }'\};var o='{ lv_org }';var n=0;| &&
                  |function s()\{try\{f.contentWindow.postMessage(m,o);\}catch(e)\{\}\}| &&
                  |f.addEventListener("load",s);| &&
*                 AND AGAIN WHENEVER THE FRAME SPEAKS FIRST. A viewer that
*                 announces itself when its listener is ready gets an
*                 immediate answer instead of waiting out the interval, and
*                 one that never speaks loses nothing. Origin-checked: a
*                 message from anywhere but the viewer is ignored, so this
*                 cannot be used to make the page re-post the token
*                 somewhere else.
                  |window.addEventListener("message",function(e)\{| &&
                  |if(e.origin===o)\{s();\}\});| &&
                  |var t=setInterval(function()\{if(++n>10)\{clearInterval(t);return;\}s();\},500);| &&
                  |\})();</script>|
        sanitizecontent = abap_false ).

      lo_map->link( text   = t( iv_en = `Open the map in a new tab`
                                iv_ar = `افتح الخريطة في تبويب جديد` )
                    href   = lv_base
                    target = '_blank'
                    icon   = 'sap-icon://map'
                    class  = 'sapUiTinyMarginTop' ).

    ELSE.
*     NAMED, not blank. The viewer needs all three and shows its forbidden
*     panel if any is missing, so saying WHICH one is absent is the
*     difference between a fix and another round trip.
      lo_map->message_strip(
        text     = |{ t( iv_en = `The map cannot be opened for this parcel`
                         iv_ar = `لا يمكن فتح الخريطة لهذه القطعة` ) }| &&
                   | (viewer={ COND string( WHEN lv_base IS NOT INITIAL THEN 'yes' ELSE 'MISSING' ) }| &&
                   | token={ COND string( WHEN lv_tok IS NOT INITIAL THEN 'yes' ELSE 'MISSING' ) }| &&
                   | parcel={ COND string( WHEN lv_pid IS NOT INITIAL THEN lv_pid ELSE 'MISSING' ) })|
        type     = 'Information'
        showicon = abap_true ).
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
