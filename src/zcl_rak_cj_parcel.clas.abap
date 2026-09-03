CLASS zcl_rak_cj_parcel DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& RAKPARCELSELECTOR, rebuilt as a CJS control.
*&
*& BUILD mun-5. Missing this line means SAP has an older copy - see
*& the note on unticked 'Overwrite local object' rows in ZRAK_CJ_MAP_DIAG.
*& map-fix-9 contains: the details dialog's Map tab draws the FRAMED
*& viewer first and the in-page ArcGIS renderer only as a fallback. That
*& order was the other way round, on a reading of util/Map.js which the
*& live screen's own DOM overrules - the deployed map is an ArcGIS view
*& inside an iframe on the GIS host's origin, which is why it has no
*& proxy problem and the in-page rebuild cannot get past one.
*& map-fix-10 contains: the postMessage snippet delivered through the
*& IFRAME'S OWN ONLOAD ATTRIBUTE as well as FOLLOW_UP_ACTION( ). It had
*& only the latter, which runs from the MAIN view's onAfterRendering and
*& therefore does not fire on a round trip that only opens a dialog - so
*& the frame loaded, nothing ran, and the viewer sat on its splash logo
*& with the note line EMPTY. An earlier comment claimed the frame's own
*& onload as a second channel, but described an addEventListener INSIDE
*& the snippet, which cannot help: the snippet must run to attach it.
*& map-fix-11 contains: the viewer now RENDERS ITS CHROME and leaves the
*& canvas blank, which is a different failure from the splash logo and
*& means the postMessage was accepted. So the note reports the token by
*& LENGTH, keeps whatever the viewer posts back (the only channel a
*& cross-origin frame has), and nudges the iframe height by one pixel
*& once the dialog has finished animating - chrome without a canvas is
*& the signature of a MapView built while its container had no size.
*& This class will not compile until ZCL_RAK_CJ_GIS is ACTIVE: a class
*& with no active version has no methods, so its callers report
*& "Method SCRIPT is unknown or PROTECTED or PRIVATE" instead.
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

*   THE BUILD, ON SCREEN. Not decoration - it ends a specific and
*   expensive kind of round trip.
*
*   There is no ADT connection from where this is written, so a change
*   reaches SAP as: push, abapGit Pull with the 'Overwrite local object'
*   row ticked by hand, then activate. Any of those three can silently
*   not happen. A pull that was not ticked, and a pull that landed but
*   failed to activate, both leave the PREVIOUS ACTIVE VERSION running -
*   and CLAUDE.md is explicit that this is indistinguishable on screen
*   from code that ran and did nothing. Several rounds here have been
*   spent re-diagnosing behaviour that came from a build no longer in
*   the repository.
*
*   So the dialog states which build drew it. One glance settles whether
*   the thing being looked at is the thing that was just written, which
*   is the question that has to be answered FIRST every time and until
*   now could only be inferred. Bump it with the header stamp.
    CONSTANTS c_build TYPE string VALUE 'mun-5'.

    METHODS constructor
      IMPORTING io_engine TYPE REF TO zcl_rak_journey_engine.

  PRIVATE SECTION.

*   SIX, THE LIVE CONTROL'S OWN PAGE SIZE - measured, not chosen. The
*   working My Properties screen reports "54 properties found" over "1 / 9"
*   pages, which is six.
*
*   It was five, which is close enough to look right and is worse on a
*   large portfolio for a reason specific to this control: every page press
*   is a round trip and every round trip re-reads the whole parcel list
*   (see the note in ROWS( )). Two hundred parcels at five a page is forty
*   reads to walk the list; at six it is thirty-four. That is not the fix -
*   the fix is a cache that survives a round trip - but there is no reason
*   to be smaller than the control being replaced.
    CONSTANTS c_page_size TYPE i VALUE 6.

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

*   ONE DETAILS READ PER POPUP RENDER, SIX TABS OFF IT. DETAILS( ) does
*   six backend reads - RE-FX characteristics, measurements, partners,
*   architectural objects, the project tables, and ECM for the documents -
*   so calling it once per tab would be six times that on every round
*   trip, and every tab is drawn on every round trip whether or not it is
*   the visible one.
*
*   MV_DETRD IS NOT REDUNDANT WITH MS_DET. A parcel whose children are
*   genuinely all empty leaves MS_DET looking exactly like a read that
*   never happened, which is the same silent-repeat this class already
*   guards MT_ROWS against with MV_READ.
*
*   KEYED ON THE INTRENO, because the dialog can be closed and reopened
*   on a different parcel within one serialized instance - the control is
*   rebuilt each round trip but the ENGINE carries MV_PCL_DET across them.
    DATA ms_det   TYPE zcl_rak_property_api=>ty_detail_res.
    DATA mv_detrd TYPE abap_bool.
    DATA mv_detky TYPE string.

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

*   ---- MULTI-SELECT, WHICH IS WHAT BACKLOG 4.4 ABOVE ASKED FOR --------
*
*   FTYPE 'PARCELS' - plural - draws a CHECKBOX on every card instead of a
*   Select button, and the field then holds a '-' separated list rather
*   than one key. 'PARCEL', 'PROPERTY' and 'TITLEDEED' are unchanged and
*   still single-select, so no existing journey moves.
*
*   THE DELIMITER IS '-' BECAUSE THE BACKEND ALREADY USES IT.
*   ZIF_EGA_FW_CJI~UPDATE( ) builds the CJ02 note as
*       parcel = parcel && '-' && <fs_data>-ui_table_column1
*   and GET_PL_TABLE( ) / CREATE_DUMMY_CASE( ) both SPLIT it back at '-'.
*   So a multi-selection written in this form is the same string the
*   legacy path stores, and a parcel number cannot contain one.
*
*   WHY THE CONTROL AND NOT THE HANDLER. M012 first accumulated picks into
*   the grid from ON_CHANGE, which worked in principle and was wrong in
*   practice: a card press stored one key and the handler moved it, so the
*   cards showed nothing selected and the citizen had no way to UNPICK.
*   The legacy control has bMulti and checkboxes; a checkbox is the only
*   affordance that says "several, and you can change your mind".
    CONSTANTS c_ftype_multi TYPE string VALUE 'PARCELS'.
    CONSTANTS c_sep         TYPE string VALUE '-'.

    DATA mv_multi TYPE abap_bool.

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

*   ---- the multi-select trio -----------------------------------------
*   SEL_LIST( ) splits the field's stored value; IS_SEL( ) answers
*   membership for a card's checkbox; TOGGLE( ) adds or removes one key
*   and writes the list back.
*
*   All three compare UNPADDED. The card press carries the service's
*   padded PARCELID and a map click carries the trimmed one - PICK( )'s
*   own header explains why - so a list built from both forms would hold
*   the same parcel twice and show neither as ticked. What is STORED is
*   still the service's own form, exactly as PICK( ) stores it.
    METHODS sel_list RETURNING VALUE(rt) TYPE string_table.
    METHODS is_sel   IMPORTING iv_key    TYPE string
                     RETURNING VALUE(rv) TYPE abap_bool.
    METHODS toggle   IMPORTING iv_field  TYPE string
                               iv_key    TYPE string.

*   One tab of the details dialog whose data is not reachable yet. The
*   COLUMNS are the live dialog's own headers, so the tab that appears
*   when GET_EXPANDED_ENTITYSET is solved is this one with rows in it -
*   not a redesign. IV_COLS is caret-separated.
*   ---- General, which never needed the expand read --------------------
*   THREE OF ITS FOUR COLUMNS ARE ALREADY IN HAND. Area Name, Address and
*   Property Type are AREATEXT, ADDRESS and TYPE on the flat
*   PropertiesSet row the card in front of the citizen was drawn from -
*   ZCL_ZEGA_CJ_DPC_EXT fills all three in PROPERTIESSET_GET_ENTITYSET,
*   the read CJS already makes.
*
*   So this tab was showing "not available yet" over data it was holding.
*   It got lumped in with the other five because they are drawn by one
*   loop and ToProject is in its header, and only Active Projects
*   actually comes from ToProject.
*
*   The other five come from DETAILS( ), through CHILD_TAB( ) below.
    METHODS general_tab
      IMPORTING io_bar TYPE REF TO z2ui5_cl_xml_view
                iv_pid TYPE string.

*   The details read, once, cached for the tabs that follow it.
    METHODS detail
      RETURNING VALUE(rs) TYPE zcl_rak_property_api=>ty_detail_res.

*   ---- one child list, drawn ------------------------------------------
*   IR_DATA is one of DETAILS( )'s six references and its row type is
*   unknown here by design - so every cell is read with CELL( ), which is
*   ASSIGN COMPONENT and answers blank for a component that is not there.
*
*   IV_COLS AND IV_COMPS ARE POSITIONALLY PAIRED, both '^' separated:
*   column N is headed by the Nth label and filled from the Nth
*   component. That is the same positional coupling as a backend TABLE's
*   KEY:Label:TYPE spec, with the same hazard - a label added without its
*   component shifts every cell after it - so they are passed together at
*   one call site rather than configured apart.
*
*   THE COMPONENT NAMES ARE THE LEGACY CLASS'S OWN, not the MPC's. The
*   DPC maps ZCL_EGA_MUN_CJ_ODATA_API's raw rows into TS_PARTNER,
*   TS_MEASUREMENT and so on for OData; CJS reads the raw rows directly,
*   so what is named here is PARTNER / ZZFULL_NAME_ENG / XMMEAS - the
*   fields the DPC reads on its right-hand side, which is the only
*   evidence available for these shapes from this environment. A name
*   that turns out wrong draws an empty column, never a dump.
*
*   AN UNBOUND IR_DATA IS "NOT READ", an empty one is "none" - and the
*   two get different messages, because "this parcel has no buildings"
*   and "we could not ask" are not the same sentence to show a citizen.
    METHODS child_tab
      IMPORTING io_bar   TYPE REF TO z2ui5_cl_xml_view
                iv_key   TYPE string
                iv_text  TYPE string
                iv_cols  TYPE string
                iv_comps TYPE string
                ir_data  TYPE REF TO data.

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

*   ---- TIMED, BECAUSE THIS READ IS THE SELECTOR'S WHOLE COST ----------
*
*   THE CACHE ABOVE IS PER ROUND TRIP, NOT PER SESSION, and that is the
*   performance characteristic worth knowing about rather than guessing
*   at. ZCL_RAK_JOURNEY_ENGINE->ENSURE_PARTS( ) creates this control fresh
*   on EVERY round trip, so MV_READ and MT_ROWS start empty every time:
*   the full parcel read happens again on every page press, every search,
*   every owner switch and - now that the cards carry checkboxes - every
*   single tick.
*
*   AND THE READ IS UNBOUNDED. PROPERTIES( ) sends Partner, Partnerguid,
*   Partnerrole and Type as filters and no $top or $skip, so a partner
*   with two hundred parcels fetches two hundred rows to render five.
*   Paging and search are applied AFTER this, in HITS( ) and PAGER( ) -
*   which is correct and matches the legacy control, because neither is a
*   filter the DPC accepts - but it means neither reduces what is read.
*
*   Nothing measured it, so nobody could say whether that matters. It does
*   now: row count and milliseconds, under &trace=X, plus a gate when the
*   read is slow enough that a citizen would feel it on every tick.
    DATA(lv_t0) = mo_e->tick( ).

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

    DATA(lv_ms) = mo_e->tock( lv_t0 ).
    IF mo_e->mv_trace = abap_true.
      mo_e->trace( |PARCEL  read { mode( ) }| &&
                   COND string( WHEN owner( ) IS NOT INITIAL THEN |/{ owner( ) }| ELSE `` ) &&
                   | · { lines( mt_rows ) } row(s) · { lv_ms } ms| &&
                   | · page size { c_page_size }| ).
      mo_e->trace_perf( iv_label = |PARCEL read { mode( ) }| iv_ms = lv_ms ).

*     A GATE, NOT A TRACE LINE, ONCE IT IS BIG ENOUGH TO FEEL. The number
*     that matters is not the read on its own - it is the read multiplied
*     by the round trips, and a multi-select list turns one selection into
*     one round trip PER PARCEL. Fifty rows at 40ms is invisible; two
*     hundred rows at 400ms is four seconds spent across ten ticks.
*
*     The threshold is deliberately generous. This is here to make a real
*     problem visible on a real partner, not to complain about a
*     development client with three parcels.
      IF lines( mt_rows ) > 60 OR lv_ms > 300.
        mo_e->trace_gate( |The parcel read returned { lines( mt_rows ) } row(s) in | &&
                          |{ lv_ms } ms, and it is repeated on EVERY round trip - | &&
                          |the control is recreated per round trip, so its row | &&
                          |cache never survives one. Paging and search are applied | &&
                          |after the read and do not reduce it. At this size that | &&
                          |wants a cross-round-trip cache keyed on partner, mode | &&
                          |and owner.| ).
      ENDIF.
    ENDIF.

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

*   MULTI OR SINGLE, decided from the ftype and remembered for CARD( ).
*   Read here rather than passed down because CARD( ) is called per row
*   from two places and threading a flag through both is one more thing to
*   get wrong.
    mv_multi = xsdbool( is_field-type = c_ftype_multi ).

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
*   SELECTED - membership in multi mode, equality in single mode. The
*   single-mode comparison is left exactly as it was so no existing
*   journey changes behaviour.
    DATA lv_sel TYPE abap_bool.
    IF mv_multi = abap_true.
      lv_sel = is_sel( lv_key ).
    ELSE.
      lv_sel = xsdbool( mo_e->val_get( mv_fld ) = lv_key ).
    ENDIF.

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

*   ---- THE CHECKBOX GOES FIRST, AND LEFT ------------------------------
*   It was at the bottom right of the card, in the action row beside Full
*   Details, which is where the single-select Select BUTTON belongs and is
*   the wrong place for a checkbox. A tick box is not an action - it is the
*   row's state - and several of them have to be scannable as a COLUMN:
*   the citizen picking three parcels out of forty reads straight down the
*   left edge, ticks, and never looks at the rest of the card. At the
*   bottom right they are a different distance apart on every card,
*   because the meta line above them wraps differently.
*
*   BEFORE THE TITLE, so it renders to the left of the parcel number -
*   children render in CREATION order in z2ui5, so the order of these two
*   statements IS the layout. There is no property to move it afterwards.
*
*   NO TEXT ON IT NOW. It carried "Select" / "Selected" as its own caption
*   when it sat in the action row and had to say what it did. Beside the
*   parcel number that caption competes with the number for the first
*   thing read, and the number is what identifies the row - so the box is
*   bare and the whole card is the label. The single-select path keeps its
*   captioned button, untouched.
    IF mv_multi = abap_true.
      lo_top->checkbox(
        selected = xsdbool( lv_sel = abap_true )
        select   = mo_e->mo_client->_event(
                     |{ c_pfx }TOG_{ mv_fld }~{ lv_key }| ) ).
    ENDIF.

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

*   IN MULTI MODE THE ACTION ROW ENDS HERE - Full Details and nothing
*   else. The checkbox that used to be drawn at this point has moved to
*   the FRONT of the top row; see the block there for why. Returning
*   before the Select button is what keeps the card from offering two
*   ways to choose the same parcel, one of which would replace the whole
*   selection instead of adding to it.
*
*   SELECTED IS STILL BOUND FROM THE STORED LIST up there, so a tick
*   survives paging, searching and a round trip - it is not client-side
*   state - and the event is still a TOGGLE. PICK_ replaces the whole
*   value, which is right for one parcel and is exactly what stopped a
*   merge being assembled; TOG_ adds or removes one key and leaves the
*   rest.
    IF mv_multi = abap_true.
      RETURN.
    ENDIF.

    lo_act->button(
      text  = COND #( WHEN lv_sel = abap_true THEN t( iv_en = `Selected` iv_ar = `محددة` )
                                              ELSE t( iv_en = `Select`   iv_ar = `اختيار` ) )
      icon  = COND #( WHEN lv_sel = abap_true THEN 'sap-icon://accept' ELSE '' )
      type  = COND #( WHEN lv_sel = abap_true THEN 'Success' ELSE 'Emphasized' )
      press = mo_e->mo_client->_event(
                |{ c_pfx }PICK_{ mv_fld }~{ lv_key }| ) ).
  ENDMETHOD.


  METHOD sel_list.
    DATA(lv_v) = mo_e->val_get( mv_fld ).
    IF lv_v IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT lv_v AT c_sep INTO TABLE rt.
*   A leading or trailing separator, or a double one, leaves blanks -
*   which would otherwise count as a selected parcel with no number.
    DELETE rt WHERE table_line IS INITIAL.
  ENDMETHOD.


  METHOD is_sel.
    DATA(lv_k) = iv_key.
    SHIFT lv_k LEFT DELETING LEADING '0'.
    IF lv_k IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT sel_list( ) INTO DATA(lv_h).
      SHIFT lv_h LEFT DELETING LEADING '0'.
      IF lv_h = lv_k.
        rv = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD toggle.
    DATA(lv_f) = iv_field.
    IF lv_f IS INITIAL.
      lv_f = mv_fld.
    ENDIF.
    IF lv_f IS INITIAL OR iv_key IS INITIAL.
      RETURN.
    ENDIF.

*   MV_FLD IS SET HERE, AND IT MATTERS. This method runs from the event
*   dispatch, which is BEFORE any RENDER( ) on this round trip - and the
*   control is created fresh every round trip in
*   ZCL_RAK_JOURNEY_ENGINE->ENSURE_PARTS( ), so MV_FLD is still blank at
*   this point. SEL_LIST( ) and IS_SEL( ) both read the field through
*   MV_FLD, so without this they would read a blank field name, find no
*   selection, and every tick would look like a first tick: the toggle
*   would only ever add and an untick would silently re-add.
*
*   PICK( ) does not need this because it never reads the current value -
*   it replaces it.
    mv_fld = lv_f.

*   RESOLVE TO THE SERVICE'S OWN FORM FIRST, for the reason PICK( )'s
*   header sets out: a card press carries the padded PARCELID and a map
*   click the trimmed one, and storing whichever arrived would put the
*   same parcel in the list twice under two spellings.
    DATA(lv_key) = iv_key.
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

*   REBUILT RATHER THAN EDITED IN PLACE, so removing the only entry
*   leaves a genuinely empty value and not a lone separator.
    DATA(lv_was) = is_sel( lv_key ).
    DATA(lv_cmp) = lv_key.
    SHIFT lv_cmp LEFT DELETING LEADING '0'.

    DATA lt_out TYPE string_table.
    LOOP AT sel_list( ) INTO DATA(lv_h).
      DATA(lv_ht) = lv_h.
      SHIFT lv_ht LEFT DELETING LEADING '0'.
      IF lv_ht <> lv_cmp.
        APPEND lv_h TO lt_out.
      ENDIF.
    ENDLOOP.
    IF lv_was = abap_false.
      APPEND lv_key TO lt_out.
    ENDIF.

    DATA lv_new TYPE string.
    LOOP AT lt_out INTO DATA(lv_o).
      IF lv_new IS INITIAL.
        lv_new = lv_o.
      ELSE.
        lv_new = |{ lv_new }{ c_sep }{ lv_o }|.
      ENDIF.
    ENDLOOP.

    mo_e->val_set( iv_name = lv_f iv_value = lv_new ).
    mo_e->set_field_state( iv_name = lv_f iv_state = 'None' iv_text = '' ).

*   THE ONE LINE THAT SETTLES WHETHER A TICK STUCK. Three symptoms were
*   reported together - the selection "not happening properly", the card
*   vanishing, and a flicker - and they have different causes: a repaint
*   is the framework's, a lost tick would be this method's. Nothing in
*   this class traced anything, so the two were indistinguishable.
*
*   WAS -> NOW plus the resulting list answers it directly: if NOW is
*   right and the screen disagrees, the value stuck and the render is
*   wrong; if NOW is wrong, the fault is here. Under &trace=X only.
    IF mo_e->mv_trace = abap_true.
      mo_e->trace( |PARCEL  toggle { lv_f } key { lv_key }| &&
                   | · was { lv_was } · now { lines( sel_list( ) ) } selected| &&
                   | · list [{ lv_new }]| ).
    ENDIF.

*   ON_CHANGE LAST, as PICK( ) does it, so a handler that mirrors the
*   selection somewhere else sees the finished list rather than the one
*   before this tick.
    IF mo_e->mo_logic IS BOUND.
      TRY.
          mo_e->mo_logic->on_change( io_ctx = mo_e iv_field = lv_f ).
        CATCH cx_root ##NO_HANDLER.
      ENDTRY.
    ENDIF.
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

*   TWO CALLS, AND BOTH ARE REQUIRED. The markup goes through HTML( );
*   the code goes through FOLLOW_UP_ACTION( ), because a <script> written
*   into HTML( )'s content is inserted as innerHTML and a script inserted
*   that way NEVER EXECUTES. That is the defect behind every version of
*   this map so far - see ZCL_RAK_CJ_GIS's header.
    DATA(lv_div) = |rakGis{ to_upper( mv_fld ) }|.

*   TOKEN_OF( ), not -TOKEN. MapUrlSet answers the token in URL and the
*   viewer page in GISURL, and leaves TOKEN empty - measured on E10, see
*   ZCL_RAK_CJ_GIS's header. Reading the columns by name hands the map a
*   blank token and a token where a URL belongs.
    DATA(lv_js) = zcl_rak_cj_gis=>script(
      iv_token  = zcl_rak_cj_gis=>token_of( iv_url    = ls_map-url
                                            iv_gisurl = ls_map-gisurl
                                            iv_token  = ls_map-token )
      iv_viewer = zcl_rak_cj_gis=>viewer_of( iv_url    = ls_map-url
                                             iv_gisurl = ls_map-gisurl )
      iv_div    = lv_div
      it_ids    = lt_ids
      iv_focus  = lv_foc
*     A click on a parcel the citizen owns is a selection, exactly as it
*     is on a card. The event name is the card's own, so both paths meet
*     in PICK( ) and neither can drift from the other.
      iv_event  = |{ c_pfx }PICK_{ mv_fld }|
      iv_ctrl   = 'oController' ).

*   NEVER AN EMPTY BOX. SCRIPT( ) answers blank when the GIS endpoints
*   are not configured; VIEW( ) already refuses the map in that case, so
*   this is the belt to that brace rather than the expected path.
    IF lv_js IS INITIAL.
      io_box->message_strip(
        text     = t( iv_en = `The map is not configured on this system.`
                      iv_ar = `الخريطة غير مهيأة على هذا النظام.` )
        type     = 'Information'
        showicon = abap_true ).
      RETURN.
    ENDIF.

*   BOTH CHANNELS. The container's own onload= runs the snippet when the
*   markup is inserted; FOLLOW_UP_ACTION( ) runs it again after the round
*   trip. The snippet is idempotent, so whichever arrives first wins and
*   the other is a no-op - see ZCL_RAK_CJ_GIS=>CONTAINER( ) for why one
*   of them is not enough on its own.
    io_box->html( content = zcl_rak_cj_gis=>container( iv_div    = lv_div
                                                       iv_height = '30rem'
                                                       iv_script = lv_js )
                  sanitizecontent = abap_false ).
    mo_e->mo_client->follow_up_action( lv_js ).

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

    ELSEIF lv CP 'TOG_*'.
*     <field>~<key>, same payload as PICK_ and the same ownership move: a
*     tick is an interaction with that list, so it claims the shared
*     browse state without resetting the page the citizen is looking at.
*
*     BEFORE 'PICK_*' IN THIS CHAIN? It does not matter - 'TOG_' and
*     'PICK_' cannot both match, they are different prefixes. What DOES
*     matter is that the offset below is 4 and not 5: 'TOG_' is four
*     characters where 'PICK_' is five, and an offset taken on the wrong
*     one silently eats the first character of the field name.
      SPLIT substring( val = lv off = 4 ) AT '~' INTO DATA(lv_tfld) DATA(lv_tkey).
      IF lv_tfld IS NOT INITIAL.
        mo_e->mv_pcl_field = lv_tfld.
      ENDIF.
      toggle( iv_field = lv_tfld iv_key = lv_tkey ).

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
*   SIZED FOR THE MAP, which is the tab that opens. 58x34 left the map
*   about as tall as the tab strip above it once the note line and the
*   new-tab link had taken their share, and a parcel boundary needs its
*   surroundings to read as a place rather than a shape. The six blocked
*   tabs are tables and gain from the width too.
*
*   REM, NOT PERCENT, and not viewport units: a UI5 dialog with a
*   percentage CONTENTHEIGHT and a fixed-height child sizes the child
*   against a height it has not settled yet, which is one of the ways
*   this frame has already been seen to load at zero height.
    DATA(lo_dlg) = io_popup->dialog(
      title         = t( iv_en = `Property Details` iv_ar = `تفاصيل العقار` )
      contentwidth  = '76rem'
      contentheight = '46rem' ).
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
*   checked against an allowlist, and WHETHER THIS HOST IS ON IT IS NOT
*   ESTABLISHED. An earlier version of this comment asserted that it
*   already contains devgrpportal.rak.ae; nothing verified that. The one
*   trace of a working map came from a BTP dispatcher origin
*   (rakportal1-....dispatcher.ae1.hana.ondemand.com), which is
*   evidently allowlisted and is not this host. The note line under the
*   frame prints both origins so the answer is readable rather than
*   inferred, and DIV.FORBIDDEN is what the viewer shows when it
*   refuses - so a rejection is visible, not silent.
*   Six URL shapes were tried against this and none of them could ever
*   have worked - the viewer was sitting on its splash screen waiting for
*   a message that never came.
*   ONE PLACE KNOWS WHICH COLUMN IS WHICH, and it is not here. This used
*   to work out the base and the token inline, by the same shape test, and
*   the ArcGIS path next to it read the columns by name and got them
*   backwards. Both go through the helpers now.
    DATA(lv_base) = zcl_rak_cj_gis=>viewer_of( iv_url    = ls_map-url
                                               iv_gisurl = ls_map-gisurl ).
    DATA(lv_tok)  = zcl_rak_cj_gis=>token_of( iv_url    = ls_map-url
                                              iv_gisurl = ls_map-gisurl
                                              iv_token  = ls_map-token ).
    DATA(lv_pid)  = mo_e->mv_pcl_pid.

*   ---- WHAT WENT OUT, IN ABAP, WHERE A TRACE CAN SEE IT ---------------
*   THREE VALUES DECIDE WHETHER THIS MAP DRAWS and until now none of them
*   was readable server-side. The snippet puts the token in the note's
*   hover title, which is only useful if the note renders and only tells
*   you about the value that reached the BROWSER - so a token that never
*   reached CJS in the first place looked identical to one the viewer
*   rejected.
*
*   THE REASON THIS IS WORTH A LINE. The map was drawing for parcel
*   313030024 at commit A4331BE and is not now, and `git diff` over the
*   map's own path since then is two lines - `var A=0;` and a guard that
*   REDUCES posting. The parcel id, the token, the target origin, the
*   iframe url and the backoff are byte-identical to the version that
*   worked. So whatever changed is not in this code, and the candidates
*   are the token and the GIS side.
*
*   AND THE FAILURE PATTERN SAYS WHICH. 202040187 failed, then
*   313030024 - the one that demonstrably worked - failed too. A missing
*   plot fails for one parcel and not another; a rejected token fails for
*   every parcel including yesterday's. DefconReciveMessage calls
*   DefconAuth( ) before it looks anything up, so an auth failure inside
*   a cross-origin frame surfaces as exactly this: "Error In Finding Plot
*   Number".
*
*   LENGTH, NOT THE VALUE. It is a session credential and a trace is
*   rendered on screen; the length and whether it is filled answer the
*   question without putting it there.
    mo_e->trace( |PARCEL  map parcel { COND string( WHEN lv_pid IS NOT INITIAL
                                                    THEN lv_pid ELSE 'MISSING' ) }| &&
                 | · viewer { COND string( WHEN lv_base IS NOT INITIAL
                                           THEN lv_base ELSE 'MISSING' ) }| &&
                 | · token { COND string( WHEN lv_tok IS NOT INITIAL
                                          THEN |{ strlen( lv_tok ) } chars|
                                          ELSE 'MISSING - the viewer refuses without one' ) }| &&
*   BOTH RAW COLUMNS TOO. TOKEN_OF( ) and VIEWER_OF( ) work out which of
*   URL and GISURL is which by shape, and a MapUrlSet that started
*   answering differently would show up here as a swap rather than as an
*   absence - which the two resolved values above cannot distinguish.
                 | · MapUrlSet url={ COND string( WHEN ls_map-url IS NOT INITIAL THEN 'y' ELSE 'n' ) }| &&
                 | gisurl={ COND string( WHEN ls_map-gisurl IS NOT INITIAL THEN 'y' ELSE 'n' ) }| &&
                 | token={ COND string( WHEN ls_map-token IS NOT INITIAL
                                        THEN |{ strlen( ls_map-token ) }| ELSE 'n' ) }| ).

    LOOP AT ls_map-msg INTO DATA(ls_mmsg).
*     THE READ'S OWN MESSAGES, which were being dropped. MAP_URL( ) puts
*     a backend refusal on CT_MSG and nothing here ever looked - so a
*     MapUrlSet that answered with an error produced a blank token and no
*     explanation anywhere.
      DATA(lv_mtxt) = CONV string( ls_mmsg-message ).
      IF lv_mtxt IS NOT INITIAL.
        mo_e->trace( |PARCEL  map read says: { lv_mtxt }| ).
      ENDIF.
    ENDLOOP.

*   ---- THE FRAME FIRST. THIS ORDER WAS THE OTHER WAY ROUND, AND WRONG.
*
*   It was reversed on a reading of util/Map.js, which is an in-page
*   sap.ui.core.Control - so the in-page ArcGIS rebuild was made primary
*   and the frame kept as a fallback. The DOM of the live My Properties
*   screen overrules that reading:
*
*     sap-ui-preserve="__xmlview2--mapIframe"
*       #document (https://rakgisstg.rak.ae/CustomerJourneyMap/)
*         <div class="maphoc"><div id="mapViewDiv" class="esri-view ...">
*           <canvas width="941" height="915">
*
*   The ArcGIS view is real, and it is INSIDE A FRAME whose document is
*   the viewer application. WELCOME, COVER-SPIN, SWITCHOVERLAYDIV and
*   FORBIDDEN alongside it are that application's own furniture.
*
*   AND THAT IS THE WHOLE REASON THE IN-PAGE PATH CANNOT WORK HERE. In
*   the frame, the ArcGIS code runs on the GIS host's OWN origin, so
*   proxy.ashx is same-origin and the GISSERVER alias resolves. Run the
*   same code in the SAP page and every one of those calls is
*   cross-origin: the layer query dies as "Failed to fetch" against a
*   dotless alias no browser can resolve, and clearing that needs the
*   GIS side to publish CORS headers for this host. The live application
*   never has that problem because it never has that origin.
*
*   So the frame is the primary path and the in-page renderer is the
*   fallback - it stays because it is written, tested and instrumented,
*   and because it is the only route if the viewer ever refuses us.
*
*   See the CORRECTION at the top of doc/controls/gis-map.md.
    DATA(lv_frame_ok) = xsdbool( lv_base IS NOT INITIAL
                             AND lv_tok  IS NOT INITIAL
                             AND lv_pid  IS NOT INITIAL ).

    IF lv_frame_ok = abap_false
       AND zcl_rak_cj_gis=>ready( ) = abap_true AND lv_pid IS NOT INITIAL.

      DATA(lv_dvd) = |rakGisDet{ to_upper( lv_pid ) }|.
      DATA(lv_djs) = zcl_rak_cj_gis=>script(
        iv_token  = zcl_rak_cj_gis=>token_of( iv_url    = ls_map-url
                                              iv_gisurl = ls_map-gisurl
                                              iv_token  = ls_map-token )
        iv_viewer = zcl_rak_cj_gis=>viewer_of( iv_url    = ls_map-url
                                               iv_gisurl = ls_map-gisurl )
        iv_div    = lv_dvd
        it_ids    = VALUE string_table( ( lv_pid ) )
        iv_focus  = lv_pid
*       NO CLICK EVENT. This map shows one parcel that is already chosen;
*       there is nothing here for a press to select.
        iv_event  = ``
        iv_ctrl   = 'oControllerPopup' ).

*     THE ONLOAD CHANNEL MATTERS MOST HERE. This is a POPUP, and
*     FOLLOW_UP_ACTION( ) runs from the MAIN view's onAfterRendering - a
*     round trip that only opens a dialog need not re-render the main
*     view, and when it does not, the snippet never fires. That is what
*     left "Loading the map..." on screen. The container's own onload
*     does not depend on any of it.
*     SAME HEIGHT AS THE FRAME ABOVE. The two paths draw into the same
*     dialog and must not disagree about how much of it the map gets -
*     CONTAINER( )'s own default is 26rem, which was the frame's height
*     before the dialog was enlarged.
      lo_map->html( content = zcl_rak_cj_gis=>container( iv_div    = lv_dvd
                                                        iv_script = lv_djs
                                                        iv_height = '34rem' )
                    sanitizecontent = abap_false ).
      mo_e->mo_client->follow_up_action( lv_djs ).

    ELSEIF lv_frame_ok = abap_true.
*     The frame's own origin, which postMessage needs as its target. Sent
*     explicitly rather than as '*' - the token is a credential and a
*     wildcard target hands it to whatever happens to be framed.
      DATA(lv_org) = lv_base.
      DATA(lv_p3)  = find( val = lv_org sub = `/` occ = 3 ).
      IF lv_p3 > 0.
        lv_org = substring( val = lv_org len = lv_p3 ).
      ENDIF.

*     DOUBLE QUOTES ONLY, and no single quote anywhere - this snippet
*     goes to FOLLOW_UP_ACTION( ), and _runCustomJs splits on the single
*     quote character and treats what it finds as arguments to a frontend
*     action rather than as code. Backslash and double quote are escaped
*     because these values come from a backend read, not from this code;
*     a single quote in a URL, a token or a parcel number would break the
*     snippet, and none of the three can legitimately contain one.
      DATA(lv_jtok) = lv_tok.
      DATA(lv_jpid) = lv_pid.
      DATA(lv_jorg) = lv_org.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jtok WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_jtok WITH `\"`.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jpid WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_jpid WITH `\"`.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jorg WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_jorg WITH `\"`.
*     THE INTRENO TOO, for the hover title only. One parcel drawing and
*     the next not is a difference between two ROWS, and the internal
*     object id is what identifies the row in the backend - the parcel
*     number alone cannot be looked up as reliably. It is not shown on
*     screen; it goes in the title beside the rest.
*     THE ELEMENT IDS CARRY THE PARCEL, and this is the whole reason
*     only the first parcel ever rendered.
*
*     sap.ui.core.HTML is a PRESERVED control - the live viewer DOM
*     carries sap-ui-preserve on exactly this kind of node. UI5 keeps the
*     existing DOM subtree for a control it considers unchanged, and with
*     a CONSTANT element id that is what the frame was: reopening the
*     dialog on a different parcel left the first parcel's iframe in
*     place, holding the first parcel's document. No new markup was
*     applied, so the ONLOAD carrying the new parcel was never installed;
*     no navigation happened, so LOAD never fired again. Every channel
*     was working correctly on an element that no longer belonged to the
*     parcel being asked for.
*
*     THE ARCGIS BRANCH IN THIS SAME METHOD ALREADY DOES THIS - see
*     LV_DVD, |rakGisDet{ to_upper( lv_pid ) }|, a few dozen lines up.
*     The frame path used a constant instead, and that asymmetry is the
*     defect. A per-parcel id makes the element genuinely new for a new
*     parcel, and genuinely the same for the same one - which is also
*     what makes reopening on an unchanged parcel free.
      DATA(lv_sfx) = to_upper( lv_pid ).
*     ID-SAFE, WITH PLAIN STATEMENTS ONLY.
*
*     The first version of this filtered the string character by
*     character with DO strlen( lv_sfx ) TIMES. That is a SYNTAX ERROR:
*     DO ... TIMES takes a data object, not a functional expression, and
*     it is not a general expression position. Same family as the
*     TYPE HANDLE and VALUE traps in CLAUDE.md - the message names where
*     the parser gave up, not what is wrong - and the cost is the one
*     that file warns about: the class does not activate, the runtime
*     keeps the previous ACTIVE version, and nothing on screen changes,
*     so it reads exactly like a pull that never happened.
*
*     CONDENSE and REPLACE are statements and cannot fail that way. The
*     four characters removed are the only ones that could end the id
*     attribute early or inject markup; a parcel number contains none of
*     them, which is why the ArcGIS branch above gets away with no
*     filtering at all.
      CONDENSE lv_sfx NO-GAPS.
      REPLACE ALL OCCURRENCES OF `"` IN lv_sfx WITH ``.
      REPLACE ALL OCCURRENCES OF `'` IN lv_sfx WITH ``.
      REPLACE ALL OCCURRENCES OF `<` IN lv_sfx WITH ``.
      REPLACE ALL OCCURRENCES OF `>` IN lv_sfx WITH ``.

      DATA(lv_idf) = |rakPclMap{ lv_sfx }|.
      DATA(lv_idn) = |rakPclNote{ lv_sfx }|.
      DATA(lv_idw) = |rakPclWait{ lv_sfx }|.

      DATA(lv_jint) = mo_e->mv_pcl_det.
      REPLACE ALL OCCURRENCES OF `\` IN lv_jint WITH `\\`.
      REPLACE ALL OCCURRENCES OF `"` IN lv_jint WITH `\"`.
      DATA(lv_lang) = COND string( WHEN sy-langu = 'A' THEN `ar` ELSE `en` ).

*     THE FRAME IS MARKUP, THE POST IS NOT. This used to be one HTML( )
*     call with a <script> block in it, and that script never ran once:
*     HTML( ) sets sap.ui.core.HTML's content, which reaches the DOM as
*     innerHTML, and a script inserted that way is inert by
*     specification. The frame rendered, the viewer sat on its splash
*     screen waiting for a message nobody sent, and that read exactly
*     like a wrong URL - which is where six rounds went.
*
*     AND THEN IT HAD ONE CHANNEL, WHICH IS WHY IT STILL DID NOT RUN.
*
*     The snippet went out through FOLLOW_UP_ACTION( ) alone. That runs
*     from the MAIN view's onAfterRendering - and a round trip that only
*     opens a dialog need not re-render the main view. So on the round
*     trip that opens THIS dialog it does not fire, the snippet never
*     executes, and every listener it would have attached - including the
*     frame's own load handler and the retry interval - is never attached
*     either. The frame loaded, the viewer sat on its splash logo, and
*     the note line below stayed EMPTY: markup arrived, code did not run.
*     That empty note is what identified this, and it is the second row
*     of the table in doc/controls/gis-map.md.
*
*     A comment here already claimed "the frame's own onload" as a second
*     channel. It described the addEventListener INSIDE the snippet,
*     which cannot help: the snippet has to run before it can attach
*     anything. The claim was true of ZCL_RAK_CJ_GIS=>CONTAINER( ), which
*     carries its snippet in the onload attribute of a 1x1 data-URI
*     image, and was copied here without the mechanism.
*
*     So the snippet now rides the IFRAME'S OWN ONLOAD ATTRIBUTE - the
*     browser parsing markup rather than a framework choosing a moment,
*     the one JavaScript delivery that has always worked in this codebase
*     (RENDER_UPLOADER( )'s onchange=). It is also better TIMING than the
*     retry interval: an iframe fires load exactly when the viewer page
*     is there to be posted to. FOLLOW_UP_ACTION( ) stays as the second
*     channel, and the snippet guards on the frame's own dataset so
*     whichever arrives first wins and the other is a no-op.
*
*     ONE TEXT SERVES BOTH CHANNELS. It is already free of single quotes
*     for FOLLOW_UP_ACTION( )'s sake - _runCustomJs splits on that
*     character - so the attribute is single-quoted and needs no second
*     encoding. The braces are escaped once, over the whole markup, at
*     the end.
      DATA(lv_pjs) =
        |(function()\{var f=document.getElementById("{ lv_idf }");| &&
        |if(!f)\{return;\}| &&
*       IDEMPOTENT PER PARCEL, not once per element. This guard held a
*       bare "1", which is right for stopping the two channels from
*       setting up twice for the SAME parcel and wrong for everything
*       else: sap.ui.core.HTML is a PRESERVED control - the live viewer
*       DOM shows sap-ui-preserve on exactly this kind of node - so the
*       iframe can survive a dialog closing and reopening. A bare flag
*       then makes the second parcel a no-op against the first parcel's
*       map. Keyed on the parcel number, reopening for a different one
*       posts again and reopening for the same one still does not.
        |var m=\{parcelId:"{ lv_jpid }",token:"{ lv_jtok }",lang:"{ lv_lang }"\};| &&
*       LOAD IS THE ONE THING A CROSS-ORIGIN FRAME DOES TELL US, and it
*       is what separates "the viewer never arrived" from "the viewer
*       arrived and something inside it went wrong".
*
*       IT IS READ OFF THE ELEMENT, NOT FROM A LISTENER, and that is the
*       whole of this fix. The snippet's main delivery is the iframe's
*       ONLOAD ATTRIBUTE, so on that channel it runs AT load time - and
*       then registered addEventListener("load", ...) for an event that
*       had already fired. L stayed 0 for ever, and eight seconds later
*       the note announced "the map viewer did not load" over a viewer
*       that had loaded and drawn its own chrome.
*
*       That is why it worked exactly once. On the round trip that first
*       opens the dialog FOLLOW_UP_ACTION( ) also fires, early enough
*       that its listener was in place to catch the load. Every reopen
*       after that is a popup-only round trip, so the attribute is the
*       only channel, and the only channel could never set the flag.
*
*       The attribute therefore stamps the element before running the
*       snippet (see LV_FHTML), the listener stamps it too for the
*       follow-up channel, and L is initialised from the stamp. A
*       preserved iframe that loaded on a previous open stays stamped,
*       which is correct: it has loaded.
*       TWO COUNTERS, AND THEY WERE ONE. N counts posts, K counts retry
*       ticks. They were the same variable: S( ) did n++ on every post
*       and the interval tested ++n>10 - so each tick incremented it
*       TWICE and the retries stopped after five ticks, two and a half
*       seconds. The viewer attaches its message listener from its own
*       script after its own page has loaded and authenticated, which is
*       sometimes later than that, and a post that arrives before the
*       listener exists is simply dropped. Miss the window and the map
*       never draws; catch it and it does. That is the whole of
*       "sometimes working, sometimes not".
        |var o="{ lv_jorg }";var n=0;var k=0;var IN=[];var A=0;| &&
        |var L=(f.dataset.rakLoaded==="1")?1:0;| &&
*       THE GUARD SITS HERE, after the state it reports and before the
*       work it prevents. It used to be the first thing after the element
*       lookup, which meant the early return skipped the note as well as
*       the post - so reopening the dialog on a parcel already showing
*       left "Loading the map..." above a map that was drawn and correct.
*       R( ) is a function declaration and therefore hoisted, so it can
*       be called from here.
*       AND THE OVERLAY STILL HAS TO COME OFF ON THIS PATH. The guard
*       returns before G( ) is reached, so an already-set-up parcel used
*       to leave the wait to the other channel's listener - or, when
*       there was no other channel, to the CSS fallback fourteen seconds
*       later. If the frame has loaded, start the grace here too.
        |if(f.dataset.rakPosted===m.parcelId)\{| &&
        |if(L)\{G();\}R();return;\}| &&
        |f.dataset.rakPosted=m.parcelId;| &&
        |function s()\{try\{f.contentWindow.postMessage(m,o);n++;\}catch(e)\{\}\}| &&
        |f.addEventListener("load",function()\{| &&
        |f.dataset.rakLoaded="1";L=1;s();R();G();\});| &&
*       WHAT THE VIEWER SAYS BACK, kept and shown. The frame is
*       cross-origin, so its console and its DOM are both unreadable from
*       here - a postMessage is the ONLY thing it can tell us, and until
*       now anything it sent was used as a trigger and then discarded.
*       If it announces readiness, or an auth failure, that is the one
*       piece of evidence available about what is happening inside it.
        |window.addEventListener("message",function(e)\{| &&
        |if(e.origin!==o)\{return;\}| &&
        |try\{IN.push(typeof e.data==="string"?e.data| &&
        |:JSON.stringify(e.data));\}catch(x)\{IN.push("[unreadable]");\}| &&
        |if(IN.length>4)\{IN.shift();\}| &&
*       ONE POST IN ANSWER, AND NO MORE - AND `A` IS WHAT MAKES THAT
*       TRUE. It used to say this and not do it: s( ) ran on EVERY
*       inbound message, and the viewer's own messages are inbound
*       messages. So the viewer answering "Error In Finding Plot Number
*       202040187" triggered another post, DefconReciveMessage called
*       DefconAuth( ) again, the lookup failed again, and that error was
*       another message. A FEEDBACK LOOP with the viewer, and the five
*       stacked error toasts on screen are five laps of it - not five
*       retries, which is what it looked like and why it read as the
*       backoff being too aggressive.
*
*       The backoff was never the problem here: it already stops itself
*       on `if(IN.length){return;}` the moment anything arrives. Only
*       this handler kept posting, and nothing bounded it.
*
*       So the answering post happens once. A reply proves the listener
*       is attached, which is the one post that cannot be missed;
*       everything after that is the viewer talking to itself through
*       us. R( ) still runs each time, because the note showing what the
*       viewer said should keep up with what it last said.
*
*       IT DOES NOT DISMISS THE OVERLAY. A reply means the viewer is
*       alive and talking, which is not the same as a map that has
*       drawn - an early handshake would have taken the spinner away and
*       left a blank frame behind it. The grace and the CSS fallback own
*       that decision.
        |if(!A)\{A=1;s();\}R();\});| &&
*       A FEW POSTS ON A BACKOFF - NOT A DRUMBEAT. This matters more than
*       the window length, and getting it wrong is what turned a race
*       into a stampede.
*
*       Every message RESTARTS THE VIEWER. gismappingIM.js:
*
*           function DefconReciveMessage(messageData, origin) {
*             if (!DefconOriginValidation(origin)) { showForbidden(); return; }
*             ... DefconAuth();
*           }
*
*       DefconAuth( ) runs on EVERY message, not only the first. So a
*       500ms interval does not improve the odds of being heard - it
*       re-authenticates the viewer every half second and restarts its
*       map before the previous attempt can finish drawing. Twenty-four
*       ticks meant twenty-four restarts over twelve seconds and the map
*       never settled at all. The earlier version got away with it only
*       because its counter bug cut it to six posts in 2.5s and it then
*       went quiet long enough to draw.
*
*       THE PROPERTY THAT MATTERS IS A QUIET TAIL, not a long window.
*       Every post restarts the viewer, so the last one has to be early
*       enough that an uninterrupted run follows it. map-fix-16 worked
*       whenever it worked for exactly that reason and not for the one
*       its own comment claimed: six posts clustered inside 2.5s and
*       then silence, which gave the viewer a clear run from 2.5s on.
*       It failed only when the listener attached after the cluster.
*
*       So: four retries clustered early, the last at 3.5 seconds, then
*       nothing. That covers a listener up to a second later than the
*       version that worked, and still leaves a clear run - where seven
*       seconds of attempts would have restarted a map that had already
*       drawn at one.
*
*       THIS IS A JUDGEMENT UNDER REAL UNCERTAINTY and worth saying so:
*       there is no way to observe that the map has drawn inside a
*       cross-origin frame, so there is no signal to stop on and the
*       schedule cannot be derived. It is bounded either way - too early
*       and a slow listener misses it, too late and a drawn map is
*       restarted - and 3.5s is the least-bad point given that 2.5s was
*       observed to work more often than not.
        |var DL=[250,750,1750,3500];| &&
        |for(var i=0;i<DL.length;i++)\{| &&
        |(function(d)\{setTimeout(function()\{| &&
        |if(IN.length)\{return;\}| &&
        |k++;s();R();\},d);\}(DL[i]));\}| &&
*       A RESIZE NUDGE, once, after the dialog has finished opening.
*
*       Chrome present and canvas blank is the classic signature of an
*       ArcGIS MapView constructed while its container had no usable
*       size: the esri-ui widgets are absolutely positioned and show
*       regardless, while the view itself has nothing to draw into. A
*       UI5 dialog animates open, so a frame inside one can very
*       plausibly load at zero height.
*
*       The frame is cross-origin so nothing inside it can be called -
*       but changing the IFRAME ELEMENT's own height fires a resize
*       event in the framed document, which is what a MapView listens
*       to. One pixel out and back is enough and is invisible.
        |setTimeout(function()\{var h=f.offsetHeight;| &&
        |if(!h)\{return;\}| &&
        |f.style.height=(h+1)+"px";| &&
        |setTimeout(function()\{f.style.height=h+"px";R();\},80);| &&
        |\},1500);| &&
        |s();| &&
*       THE NOTE, REWRITABLE. It used to be written once at the end of
*       this snippet, which was enough while the only question was
*       whether the snippet ran at all. It is not enough now: the post
*       count, whatever the viewer replies, and the resize nudge all
*       arrive AFTER that point, so the line has to be re-rendered.
*       Declared as a function so it is hoisted above the handlers that
*       call it.
*
*       THE TOKEN IS REPORTED BY LENGTH, NEVER BY VALUE. It is a
*       credential; a length distinguishes "no token was passed" from
*       "a token was passed and refused", which is the only thing the
*       screen needs to tell apart, and it puts nothing on a screenshot
*       that should not be there.
*
*       WHOSE ORIGIN IS BEING JUDGED. gismappingIM.js validates the
*       SENDER against its own allowlist before it reads anything:
*
*           if (!DefconOriginValidation(origin)) { showForbidden(); return; }
*
*       so a correctly addressed, correctly timed message can still be
*       discarded, and the viewer then sits on its splash screen exactly
*       as it does when no message arrives. Both origins go in the TITLE
*       so that case stays readable: what the frame is, and what we are
*       to it.
*
*       AND IT IS QUIET WHEN THE MAP WORKS. The previous version printed
*       its whole diagnosis unconditionally, which was right while
*       nothing worked and wrong the moment something did: a correctly
*       drawn parcel sat under the sentence "chrome and a blank canvas
*       usually means the token was refused", which reads as an error
*       report on a working screen. Same rule as the ArcGIS path in
*       ZCL_RAK_CJ_GIS - an EMPTY line means it worked.
*
*       The detail is not thrown away, it moves to the element TITLE, so
*       it is one hover away rather than gone. Only two things are worth
*       saying out loud: that the map is still coming, and that the
*       viewer never arrived at all.
        |function R()\{| &&
        |var N=document.getElementById("{ lv_idn }");| &&
        |if(!N)\{return;\}| &&
        |N.title="parcel "+m.parcelId+" (intreno { lv_jint }), token "+| &&
        |m.token.length+" chars, posted "+n+"x in "+k+" tries to "+o+| &&
        |" from "+window.location.origin+| &&
        |(IN.length?(", viewer replied: "+IN.join(" / "))| &&
        |:", viewer replied nothing");| &&
*       A REPLY IS STILL WORTH SHOWING - the viewer has volunteered
*       something, and it is the only voice from inside the frame.
        |if(IN.length)\{| &&
        |N.textContent="Map: "+IN.join(" / ");return;\}| &&
*       OTHERWISE SILENT. An empty line means the map worked, the same
*       rule as the ArcGIS path in ZCL_RAK_CJ_GIS - and silent BEFORE
*       load too, because the overlay on top of the frame is what says
*       the map is coming.
*
*       THE POST COUNTER THAT WAS HERE HAS BEEN REMOVED. "map: 5x/4 L"
*       was the instrument that ended the guessing - it separated "the
*       viewer was never told" from "the viewer was told and drew
*       nothing", which no amount of reasoning had managed - but it is
*       developer text and a citizen has no use for it. The same figures
*       are still on N.title, one hover away, which is where they belong
*       once they are not being read every five minutes.
        |N.textContent="";\}| &&
*       THE WAIT OVERLAY, ON AND OFF. It ships visible in the markup, so
*       this only ever has to take it away - which means a snippet that
*       never runs leaves the wait showing rather than a bare white box,
*       and that is the correct outcome for that case too.
        |function W()\{var V=document.getElementById("{ lv_idw }");| &&
*       CLASSNAME rather than style.display: the fade is a CSS
*       transition on opacity, and the class also takes pointer-events
*       off so a faded overlay can never swallow a click meant for the
*       map underneath.
        |if(V)\{V.className="rakPclWait rakGone";\}\}| &&
*       AND WHEN TO TAKE IT AWAY. Load is not the moment the map is
*       READY - it is the moment the viewer page arrived, and the viewer
*       then authenticates, queries its layer and draws. That second
*       half happens inside a cross-origin frame and is unobservable, so
*       there is no event to wait for and a grace period is the honest
*       answer rather than a lucky one. Two and a half seconds is drawn
*       from the observed wait on this system, and it is bounded either
*       way: too short shows a map mid-draw, which is what the citizen
*       would have seen anyway; too long holds a spinner over a finished
*       map.
*       PAST THE LAST POST, not before it. The retries end at 3.5s, so a
*       2.5s grace used to uncover the frame while attempts were still
*       going out - the citizen watched a blank panel during the part of
*       the sequence most likely to be the one that works.
        |function G()\{setTimeout(W,4500);\}| &&
*       A REPLY MEANS THE VIEWER IS TALKING, so stop waiting immediately
*       rather than sitting out the grace period - whatever it said,
*       the note now carries it and the overlay would only hide it.
        |if(L)\{G();\}| &&
*       THE VIEWER NEVER ARRIVED. Eight seconds is well past a page load,
*       so at that point the frame itself did not come up - a different
*       fault from anything inside it, and the only one this line still
*       needs to spell out.
        |setTimeout(function()\{| &&
        |if(L)\{return;\}| &&
        |var N2=document.getElementById("{ lv_idn }");| &&
        |if(N2)\{N2.textContent="The map viewer did not load from "+o+| &&
        |". Opening it in a new tab will show what it says.";\}| &&
*       AND STOP WAITING. A spinner that turns for ever is a worse answer
*       than a message: the overlay comes off so whatever the frame does
*       show is visible, and the line above says what happened.
        |W();| &&
        |\},8000);| &&
        |R();| &&
        |\}())|.

*     CHANNEL ONE: the frame's own onload attribute. Single-quoted, and
*     the snippet is guaranteed free of single quotes - see above.
      DATA(lv_fhtml) =
*       THE POSITIONED WRAPPER. The overlay is absolutely positioned
*       against it, so without this it would anchor to whatever ancestor
*       happens to be positioned - which inside a UI5 dialog is the
*       dialog - and cover the tab strip and the Close button instead of
*       the map.
        |<div class="rakPclMapWrap">| &&
        |<iframe id="{ lv_idf }" src="{ lv_base }" title="parcel map" | &&
        |style="width:100%;height:34rem;border:0;display:block" | &&
*       THE STAMP GOES FIRST, and it is what tells the snippet that this
*       channel IS the load event. Without it the snippet cannot know -
*       the frame is cross-origin, so contentDocument.readyState is
*       unreadable - and it spent eight seconds concluding the viewer had
*       never arrived. THIS is the iframe inside its own onload, so the
*       stamp is simply true.
        |onload='this.dataset.rakLoaded="1";{ lv_pjs }'></iframe>| &&
*       THE WAIT OVERLAY, a SIBLING of the frame inside a positioned
*       wrapper. Everything inside the frame belongs to the other origin
*       and cannot be reached, so the only place to say "this is coming"
*       is on top of it.
*
*       It ships VISIBLE in the markup rather than being switched on by
*       the snippet, so the wait is shown even in the case where no
*       channel runs at all - which is the one case where the citizen
*       waits longest.
        |<div class="rakPclWait" id="{ lv_idw }">| &&
        |<div class="rakPclSpin"></div><div>| &&
        |{ t( iv_en = `Loading the map...` iv_ar = `جارٍ تحميل الخريطة...` ) }| &&
        |</div></div></div>| &&
*       A LINE THE SNIPPET FILLS IN, so the one thing that cannot be seen
*       from a screenshot becomes readable: the origin the message was
*       posted FROM - and, by being EMPTY, that the snippet never ran at
*       all. Both readings have now been needed.
*       AND IT SHIPS EMPTY NOW. It used to carry "Loading the map..."
*       because it was the only place that could say so; the overlay says
*       it now, on top of the frame where the citizen is already looking.
        |<div id="{ lv_idn }" class="rakPclHint"></div>|.

*     BRACES ESCAPED, ONCE, OVER THE WHOLE MARKUP - and this is not
*     optional now that a script rides in an attribute. HTML( ) sets
*     sap.ui.core.HTML's CONTENT, which travels as an XML view attribute,
*     and UI5's XML parser reads { } in an attribute value as a binding
*     expression. An unescaped snippet full of JavaScript object literals
*     parses as dozens of malformed bindings and the control never
*     renders AT ALL - a blank tab, not a broken map. CONTAINER( ) and
*     RENDER_UPLOADER( ) both carry these same two lines.
      REPLACE ALL OCCURRENCES OF `{` IN lv_fhtml WITH `\{`.
      REPLACE ALL OCCURRENCES OF `}` IN lv_fhtml WITH `\}`.

      lo_map->html( content = lv_fhtml sanitizecontent = abap_false ).

*     CHANNEL TWO: FOLLOW_UP_ACTION( ), for the round trips where it does
*     fire. Same text, and the dataset guard makes the loser a no-op.
      mo_e->mo_client->follow_up_action( lv_pjs ).

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
    general_tab( io_bar = lo_bar iv_pid = lv_pid ).
*   ONE READ FOR ALL FIVE, taken here so the order of the tabs cannot
*   decide which of them pays for it.
    DATA(ls_det) = detail( ).

*   NAME, not NAMEEN/NAMEAR. The raw partner row carries the English name
*   in ZZFULL_NAME_ENG and the Arabic in ZZREFERENCEA - the DPC maps them
*   to two MPC fields and lets the client choose. Choosing here instead
*   keeps one column where the live dialog has one.
    child_tab( io_bar = lo_bar iv_key = 'BP' ir_data = ls_det-partners
               iv_text  = t( iv_en = `Business Partners` iv_ar = `الشركاء` )
               iv_cols  = `Role^BP number^Name^Valid From`
               iv_comps = COND string( WHEN sy-langu = 'A'
                            THEN `ROLE^PARTNER^ZZREFERENCEA^VALIDFROM`
                            ELSE `ROLE^PARTNER^ZZFULL_NAME_ENG^VALIDFROM` ) ).

*   NO UNIT ON A CHARACTERISTIC. GET_CHARS( ) returns the group, its text
*   and the value text - there is no unit of measure on a land-use
*   characteristic, and the live dialog's third column is blank for the
*   same reason. Left in place rather than dropped so the tab keeps the
*   shape citizens already know.
    child_tab( io_bar = lo_bar iv_key = 'LAND' ir_data = ls_det-landuse
               iv_text  = t( iv_en = `Land` iv_ar = `الأرض` )
               iv_cols  = `Characteristic^Value^Unit^Valid From`
               iv_comps = `XRLRAGRPCHCT^XFIXFITCHARACT^^VALIDFROM` ).

    child_tab( io_bar = lo_bar iv_key = 'DEV' ir_data = ls_det-develop
               iv_text  = t( iv_en = `Development` iv_ar = `التطوير` )
               iv_cols  = `Building Type^Building Number^Building Name^Valid From`
               iv_comps = `XMAOTYPE^AOID^XAO^VALIDFROM` ).

    child_tab( io_bar = lo_bar iv_key = 'MEAS' ir_data = ls_det-measure
               iv_text  = t( iv_en = `Measurements` iv_ar = `القياسات` )
               iv_cols  = `Measurements Type^Amount^Unit^Valid From`
               iv_comps = `XMMEAS^MEASVALUE^MEASUNIT^VALIDFROM` ).

*   THE ONLY TAB WHOSE ROW TYPE CJS OWNS. The DPC's GET_FILENET_DOCS( )
*   and its TY_FNDOC are both PRIVATE, so DETAILS( ) does what that
*   method does - ZCL_EGA_FILENET_HNDLR->SEARCH_TITLE_DEED( ) plus a
*   filter on the parcel or the AOID - and answers
*   ZCL_RAK_PROPERTY_API=>TY_DOC_ROW. These four names are therefore not
*   guesses at a generated shape; they are that structure.
*
*   THE CONTENT IS NOT DRAWN, only the identity. Each row carries its
*   SAPDocId in DOCID, which is what a later per-row Open would hand to
*   ZCL_EGA_FILENET_API - fetching it here would pull every document out
*   of ECM as base64 to render a list of numbers.
    child_tab( io_bar = lo_bar iv_key = 'DOC' ir_data = ls_det-attach
               iv_text  = t( iv_en = `Documents` iv_ar = `المستندات` )
               iv_cols  = `Number^Department^Issuing date^Expiry Date`
               iv_comps = `NUMBER^DEPARTMENT^ISSUEDATE^VALIDTO` ).

*   THE READ'S OWN MESSAGES, once, under the tabs. Each child in
*   DETAILS( ) has its own CATCH so a failure is partial - five tabs
*   filled and one explained - and this is where the explanation lands.
*   Without it a tab that failed and a tab that is genuinely empty look
*   identical.
    LOOP AT ls_det-msg INTO DATA(ls_dmsg).
      DATA(lv_dtxt) = CONV string( ls_dmsg-message ).
      IF lv_dtxt IS NOT INITIAL.
        lo_bar->message_strip(
          text     = lv_dtxt
          type     = COND string( WHEN ls_dmsg-type = 'E' THEN 'Error' ELSE 'Warning' )
          showicon = abap_true
          class    = 'sapUiTinyMarginTop' ).
      ENDIF.
    ENDLOOP.

*   WHICH BUILD DREW THIS. Outside the tab bar, so it is there whichever
*   tab is open and whichever map path was taken - including the branch
*   that draws only a message. See C_BUILD: this answers "is the code on
*   screen the code that was just written" by observation instead of by
*   inference, which is the question that has had to be asked first in
*   every round of this and never had an honest answer.
*   THE PARCEL GOES ON THE LINE TOO. It was only in the note's hover
*   title, so every screenshot of this dialog has been ambiguous about
*   WHICH parcel it showed - and the open question here is now
*   parcel-specific rather than mechanical: two parcels draw and one does
*   not, on the same code and the same timing.
*
*   NO WARNING SITS HERE, deliberately. There is nothing to key one on.
*   The viewer never replies even when the map draws correctly - the note
*   is empty on every successful render - so "no reply" cannot mean
*   failure, and a line that said so would appear under working maps.
*   A cross-origin frame that draws nothing and one that draws a parcel
*   are indistinguishable from here, and claiming otherwise would be
*   worse than saying nothing.
*   UNDER TRACE ONLY. This line earned its place - it is what proved the
*   pull had activated, which had been costing whole rounds of
*   re-diagnosing a build that was not running, and it names the parcel
*   so a screenshot is never ambiguous again. But it is developer text in
*   a citizen's dialog, so it is behind MV_TRACE rather than shipped.
*
*   Switch trace on for the journey and it comes back, build and parcel
*   and intreno, which is exactly what is wanted the next time this map
*   misbehaves and nothing more than that the rest of the time.
    IF mo_e->mv_trace = abap_true.
      lo_c->text( text  = |CJS { c_build } · parcel { mo_e->mv_pcl_pid }| &&
                          | · intreno { mo_e->mv_pcl_det }|
                  class = 'rakPclHint' ).
    ENDIF.

    lo_dlg->buttons( )->button( text  = t( iv_en = `Close` iv_ar = `إغلاق` )
                                press = mo_e->mo_client->_event( |{ c_pfx }CLOSE| ) ).
    rv_drawn = abap_true.
  ENDMETHOD.


  METHOD general_tab.
    DATA(lo_v) = io_bar->icon_tab_filter(
                   key  = 'GEN'
                   text = t( iv_en = `General` iv_ar = `عام` ) )->content( )->vbox( ).

*   THE SAME PADDED/TRIMMED RESOLUTION TOGGLE( ) AND PICK( ) DO, and for
*   the same reason: a card press carries whichever form the button was
*   built with, while the row holds the service's own. Comparing one
*   spelling against the other finds nothing and draws an empty tab over
*   a parcel that is right there in the list.
    DATA(lv_want) = iv_pid.
    SHIFT lv_want LEFT DELETING LEADING '0'.

    DATA ls_hit TYPE zcl_rak_property_api=>ty_prop_row.
    LOOP AT rows( ) INTO DATA(ls_r).
      DATA(lv_k) = cell( is_row = ls_r iv_comp = 'PARCELID' ).
      IF lv_k IS INITIAL.
        lv_k = cell( is_row = ls_r iv_comp = 'BUILDING' ).
      ENDIF.
      DATA(lv_kt) = lv_k.
      SHIFT lv_kt LEFT DELETING LEADING '0'.
      IF lv_kt = lv_want AND lv_want IS NOT INITIAL.
        ls_hit = ls_r.
        EXIT.
      ENDIF.
    ENDLOOP.

*   NO ITEMS BINDING, deliberately - BLOCKED_TAB( ) calls table( ) the
*   same way. The single row below is a literal ColumnListItem in the
*   items aggregation, which UI5 renders as one static row; a binding
*   would need a model member and there is nothing to bind.
    DATA(lo_t) = lo_v->table( ).
    DATA(lo_h) = lo_t->columns( ).
    lo_h->column( )->text( t( iv_en = `Area Name`       iv_ar = `اسم المنطقة` ) ).
    lo_h->column( )->text( t( iv_en = `Address`         iv_ar = `العنوان` ) ).
    lo_h->column( )->text( t( iv_en = `Property Type`   iv_ar = `نوع العقار` ) ).
    lo_h->column( )->text( t( iv_en = `Active Projects` iv_ar = `المشاريع النشطة` ) ).

    DATA(lv_area) = cell( is_row = ls_hit iv_comp = 'AREATEXT' ).
    IF lv_area IS INITIAL.
      lv_area = cell( is_row = ls_hit iv_comp = 'SECTORTEXT' ).
    ENDIF.
    DATA(lv_addr) = cell( is_row = ls_hit iv_comp = 'ADDRESS' ).
    DATA(lv_type) = cell( is_row = ls_hit iv_comp = 'TYPE' ).

*   ONE ROW, DRAWN BY HAND. Binding the whole list here would show every
*   parcel the citizen owns inside a dialog opened about ONE of them.
    DATA(lo_row) = lo_t->items( )->column_list_item( )->cells( ).
    lo_row->text( zcl_rak_journey_util=>esc( lv_area ) ).
    lo_row->text( zcl_rak_journey_util=>esc( lv_addr ) ).
    lo_row->text( zcl_rak_journey_util=>esc( lv_type ) ).

*   ACTIVE PROJECTS IS THE ONE COLUMN THAT REALLY IS BLOCKED. It is a
*   count over ToProject, which only GET_EXPANDED_ENTITY returns, so an
*   em dash rather than a 0 - a zero here would state that this parcel
*   has no active projects, which is not something this read knows.
    lo_row->text( `—` ).

    IF lv_addr IS INITIAL AND lv_area IS INITIAL AND lv_type IS INITIAL.
*     Nothing matched. Says which parcel it looked for, because the two
*     ways this happens - a key spelled differently, and a dialog opened
*     from a list that has since been re-read - are indistinguishable
*     otherwise.
      lo_v->message_strip(
        text     = |{ t( iv_en = `No details found for parcel `
                         iv_ar = `لم يتم العثور على تفاصيل للقطعة ` ) }{ iv_pid }|
        type     = 'Warning'
        showicon = abap_true
        class    = 'sapUiTinyMarginTop' ).
    ELSE.
      lo_v->message_strip(
        text     = t( iv_en = `Active Projects comes from the PropertiesSet(key) $expand read, which is not wired yet.`
                      iv_ar = `عدد المشاريع النشطة يأتي من قراءة PropertiesSet(key) بـ $expand، وهي غير مُهيأة بعد.` )
        type     = 'Information'
        showicon = abap_true
        class    = 'sapUiTinyMarginTop' ).
    ENDIF.
  ENDMETHOD.


  METHOD detail.

*   THE INTRENO IS THE KEY, and it is what the dialog was opened with -
*   RENDER_CARD( ) raises DET_<intreno>~<parcel>, so MV_PCL_DET is the
*   intreno and MV_PCL_PID the parcel number the citizen sees.
    DATA(lv_int) = mo_e->mv_pcl_det.

    IF lv_int IS INITIAL.
      RETURN.
    ENDIF.

*   RE-READ WHEN THE PARCEL CHANGES, not on every round trip. The control
*   is rebuilt each round trip so these attributes start clear, but the
*   ENGINE carries MV_PCL_DET across them - so within one render the cache
*   holds, and reopening on a different parcel invalidates it.
    IF mv_detrd = abap_true AND mv_detky = lv_int.
      rs = ms_det.
      RETURN.
    ENDIF.

    DATA ls TYPE zcl_rak_property_api=>ty_detail_res.
    DATA(lv_t0) = mo_e->tick( ).

    TRY.
*       THE PARCEL AND THE AOID BOTH GO, because the attachments are
*       keyed on whichever the row has: a parcel row carries PARCELID and
*       a unit row AOID, and GET_FILENET_DOCS takes both and uses what it
*       is given. Sending only the parcel would leave every Unit's
*       Documents tab empty.
        DATA(lv_aoid) = ``.
        LOOP AT rows( ) INTO DATA(ls_r).
          IF cell( is_row = ls_r iv_comp = 'INTRENO' ) = lv_int.
            lv_aoid = cell( is_row = ls_r iv_comp = 'AOID' ).
            EXIT.
          ENDIF.
        ENDLOOP.

        ls = api( )->details( iv_intreno = lv_int
                              iv_parcel  = mo_e->mv_pcl_pid
                              iv_aoid    = lv_aoid ).
      CATCH cx_root INTO DATA(lx).
*       DETAILS( ) catches its own, so reaching here means the API object
*       could not be built at all - which is a different failure and
*       worth saying so rather than showing five empty tabs.
        ls-msg = VALUE #( ( type = 'E' message = lx->get_text( ) ) ).
    ENDTRY.

    ms_det   = ls.
    mv_detrd = abap_true.
    mv_detky = lv_int.
    rs       = ms_det.

    mo_e->trace( |PCL     details { lv_int } · { mo_e->tock( lv_t0 ) } ms| ).
  ENDMETHOD.


  METHOD child_tab.
    DATA(lo_v) = io_bar->icon_tab_filter( key = iv_key text = iv_text )->content( )->vbox( ).

    SPLIT iv_cols  AT '^' INTO TABLE DATA(lt_c).
    SPLIT iv_comps AT '^' INTO TABLE DATA(lt_p).

    DATA(lo_t) = lo_v->table( ).
    DATA(lo_h) = lo_t->columns( ).
    LOOP AT lt_c INTO DATA(lv_c).
      lo_h->column( )->text( lv_c ).
    ENDLOOP.

    FIELD-SYMBOLS <lt_any> TYPE ANY TABLE.
    IF ir_data IS BOUND.
      ASSIGN ir_data->* TO <lt_any>.
    ENDIF.

    IF ir_data IS NOT BOUND OR <lt_any> IS NOT ASSIGNED.
*     NOT READ. Distinct from empty, and it is the honest wording now
*     that the read exists: something stopped it, and the strips under
*     the tab bar carry the reason.
      lo_v->message_strip(
        text     = t( iv_en = `These details could not be read for this parcel. The reason is shown below the tabs.`
                      iv_ar = `لم يتم قراءة هذه التفاصيل لهذه القطعة. السبب معروض أسفل التبويبات.` )
        type     = 'Warning'
        showicon = abap_true
        class    = 'sapUiTinyMarginTop' ).
      RETURN.
    ENDIF.

*   ONE ROW AT A TIME, DRAWN. The row type is unknown here, so there is
*   nothing to bind a model to - and binding is not wanted anyway: these
*   are read-only lists inside a dialog, and drawing them costs one pass
*   over a table that a single parcel's children keep small.
    DATA(lo_items) = lo_t->items( ).
    DATA(lv_n) = 0.

    LOOP AT <lt_any> ASSIGNING FIELD-SYMBOL(<ls_row>).
      lv_n = lv_n + 1.
      DATA(lo_cells) = lo_items->column_list_item( )->cells( ).

*     POSITIONAL, and the pairing is the caller's. An empty component -
*     the third column on Land, which has no unit - draws a blank cell
*     rather than shifting the ones after it, which is the whole reason
*     the two lists are passed together.
      LOOP AT lt_c INTO DATA(lv_h2).
        DATA(lv_ix) = sy-tabix.
        DATA(lv_cp) = VALUE string( lt_p[ lv_ix ] OPTIONAL ).
        DATA(lv_val) = ``.
        IF lv_cp IS NOT INITIAL.
          lv_val = cell( is_row = <ls_row> iv_comp = lv_cp ).
*         A DATS COMPONENT READS AS 20260903 AND MUST NOT SHOW THAT WAY.
*         Every one of these children carries VALIDFROM / VALIDTO, and
*         the live dialog shows them as dates - so an eight-digit all
*         numeric value is formatted, and anything else is left exactly
*         as it came.
*
*         WRITTEN OUT RATHER THAN DELEGATED: ZCL_RAK_JOURNEY_UTIL has
*         TO_DATS( ) for the other direction and nothing for this one, and
*         the offsets are safe here because STRLEN has just been checked -
*         an offset on a short string raises CX_SY_RANGE_OUT_OF_BOUNDS,
*         which is the trap CLAUDE.md records against IV_EVENT.
*
*         A DATS OF ALL ZEROES is 'no end date', not the year zero. The
*         RE-FX tables use 00000000 that way and 00.00.0000 on screen
*         would read as data corruption.
          IF strlen( lv_val ) = 8 AND lv_val CO '0123456789'.
            IF lv_val = '00000000'.
              CLEAR lv_val.
            ELSE.
              lv_val = |{ lv_val+6(2) }.{ lv_val+4(2) }.{ lv_val(4) }|.
            ENDIF.
          ENDIF.
        ENDIF.
        lo_cells->text( zcl_rak_journey_util=>esc( lv_val ) ).
      ENDLOOP.
    ENDLOOP.

    IF lv_n = 0.
*     GENUINELY NONE, and this says so. The table's own "No data" says it
*     too, but only this distinguishes it from the not-read case above -
*     which is the distinction the whole tab was rewritten for.
      lo_v->message_strip(
        text     = t( iv_en = `This parcel has none of these on record.`
                      iv_ar = `لا يوجد أي من هذه السجلات لهذه القطعة.` )
        type     = 'Information'
        showicon = abap_true
        class    = 'sapUiTinyMarginTop' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
