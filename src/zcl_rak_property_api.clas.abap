CLASS zcl_rak_property_api DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_cj_api
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& Parcels, properties and their owners, without the OData.
*&
*& This is what RAKPARCELSELECTOR actually is. The ShapeIt control looks
*& like a map widget, and the map is the part that is not the point: the
*& list beside it is ONE read of /PropertiesSet on the CUSTOMERJOURNEY
*& service, filtered by the citizen's partner guid and a role, and the
*& citizen's press writes one parcel id back into the journey. Everything
*& else in that control is presentation.
*&
*& READ OFF THE CONTROL AND THE DPC, NOT INFERRED. RAKPARCELSELECTOR.js
*& issues exactly one server read for its list -
*&
*&     this.models.doRead(this,"/PropertiesSet", T, true, "journey")
*&
*& with Partnerguid, Partnerrole and Type as server filters; Favourite,
*& ParcelId, SectorText and LandUse are applied CLIENT side to the already
*& fetched list, which is why they are search arguments here rather than
*& filters. PROPERTIESSET_GET_ENTITYSET reads exactly Partnerguid,
*& Partnerrole, Type, ApplType, ParcelId and Favourite and nothing else.
*&
*& FINDPARCELSET IS NOT THIS. It is tempting - the control is a parcel
*& selector and there is an entity set with 'FindParcel' in the name - and
*& it is wrong: FindParcel has no _GET_ENTITYSET at all. It is a
*& CREATE_DEEP_ENTITY target that opens a ZGCF case for the "I cannot find
*& my property" flow, refuses if one is already open, and takes
*& attachments. Binding a selector to it would have posted a case every
*& time a citizen looked at a list. This class does not touch it.
*&
*& PARTNERGUID IS THE IDENTITY AND IT IS MANDATORY. The DPC returns an
*& empty table if it is blank, silently - so a journey launched without a
*& partner guid would render an empty parcel list and look like a citizen
*& with no property. GUARD( ) turns that into a message instead. This is
*& the filter-based identity from ZCL_RAK_CJ_API: the DPC also calls
*& GET_BP( ) on the request headers, but only gates on it when SY-UNAME is
*& PORTAL1 or RAKDIGI_USER, which a CJS dialog user is not - so the empty
*& header table this layer supplies is not merely tolerated here, it is
*& read and correctly ignored.
*&
*& THE ROLE CODES ARE NOT INTERCHANGEABLE. TR0800 is ownership and
*& property management; YTR080 is grants, and the DPC translates it to
*& ZTR080 on the way in - so pass YTR080, the OData spelling, not the
*& table one. A journey in the GRANTS category selects with YTR080; every
*& other Municipality journey selects with TR0800.
*&
*& WHAT IS DELIBERATELY NOT HERE.
*&   - The full-details dialog. It reads PropertiesSet with
*&     $expand=ToProject,ToPartner,ToMeasurement,ToLandUse,ToDevelopment,
*&     ToAttachment, which routes to GET_EXPANDED_ENTITYSET, and that
*&     method calls IO_EXPAND->GET_CHILDREN( ) unguarded. Supplying an
*&     expand object is the same class of problem ZCL_RAK_CJ_REQ_CTX
*&     solved for the request context and it has not been solved for this
*&     one yet. The list works without it.
*&   - FloorSet, for the same reason: it exists ONLY inside
*&     GET_EXPANDED_ENTITYSET (iv_entity_name = gc_floor). RAK_FLOORUNIT
*&     therefore has no flat read to wrap and stays unbound.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   A GENERATED MPC TABLE TYPE CANNOT TYPE A DATA OBJECT. The generator
*   writes them as `TT_X type standard table of TS_X .` with no key at
*   all, which leaves the key unspecified - and a table type with an
*   unspecified key is GENERIC: legal for a formal parameter or a field
*   symbol, rejected everywhere else. Activation says it in those words:
*   "TT_FEES is a generic type. Use this type only for typing field
*   symbols and formal parameters."
*
*   So the row type is taken FROM the MPC with LINE OF - never a guessed
*   TS_ name - and the table type is completed here. The DPC's own
*   ET_ENTITYSET keeps the generic type, and a standard table of the same
*   row type binds to it, so nothing on the call side changes.
*   AND IT CANNOT BE CALLED TT_PARTNER EITHER. This class inherits the
*   generated DPC, so every type that chain declares is already in scope
*   here - "There is already a type called TT_PARTNER" is what naming one
*   of them again costs. The local types therefore carry a _ROW / _ROWS
*   suffix that the generator never emits.
    TYPES ty_prop_row    TYPE LINE OF zcl_zega_cj_mpc=>tt_properties.
    TYPES ty_partner_row TYPE LINE OF zcl_zega_cj_mpc=>tt_partner.
    TYPES ty_mapurl_row  TYPE LINE OF zcl_zega_cj_mpc=>tt_mapurl.

    TYPES tt_prop_rows    TYPE STANDARD TABLE OF ty_prop_row    WITH DEFAULT KEY.
    TYPES tt_partner_rows TYPE STANDARD TABLE OF ty_partner_row WITH DEFAULT KEY.
    TYPES tt_mapurl_rows  TYPE STANDARD TABLE OF ty_mapurl_row  WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_prop_res,
             rows TYPE tt_prop_rows,
             msg  TYPE bapiret2_t,
           END OF ty_prop_res.

    TYPES: BEGIN OF ty_partner_res,
             rows TYPE tt_partner_rows,
             msg  TYPE bapiret2_t,
           END OF ty_partner_res.

    TYPES: BEGIN OF ty_map_res,
             url    TYPE string,
             gisurl TYPE string,
             token  TYPE string,
             msg    TYPE bapiret2_t,
           END OF ty_map_res.

*   Partnerrole, in the spelling PROPERTIESSET_GET_ENTITYSET reads.
    CONSTANTS c_role_owner TYPE string VALUE 'TR0800'.
    CONSTANTS c_role_grant TYPE string VALUE 'YTR080'.

*   Type, as the control sends it. Blank is 'All' - the control removes the
*   filter rather than sending a third value, and so does this.
    CONSTANTS c_type_parcel TYPE string VALUE 'Parcel'.
    CONSTANTS c_type_unit   TYPE string VALUE 'Unit'.

*   The relationship a property manager holds over somebody else's
*   property. PARTNERSET_GET_ENTITYSET reads it as Role.
    CONSTANTS c_rel_manager TYPE string VALUE 'Z00008'.

*   The list behind a parcel selector.
*
*   IV_OWNER_GUID is for the property-management tab ONLY: the citizen is
*   acting for somebody else, so the guid filtered on is that owner's, not
*   their own. Blank means the citizen's own, which is the normal case.
    METHODS properties
      IMPORTING iv_type       TYPE string OPTIONAL
                iv_role       TYPE string DEFAULT c_role_owner
                iv_appl_type  TYPE string OPTIONAL
                iv_favourite  TYPE abap_bool DEFAULT abap_false
                iv_owner_guid TYPE string OPTIONAL
      RETURNING VALUE(rs)     TYPE ty_prop_res.

*   PROPERTIES( ) with Type = Parcel. The one a PARCEL field calls.
*   IV_GRANTS picks the grants role, which is what the GRANTS category
*   does in the control - M018, M019 and M020 here.
    METHODS parcels
      IMPORTING iv_grants     TYPE abap_bool DEFAULT abap_false
                iv_owner_guid TYPE string OPTIONAL
      RETURNING VALUE(rs)     TYPE ty_prop_res.

*   PROPERTIES( ) with Type = Unit.
    METHODS units
      IMPORTING iv_owner_guid TYPE string OPTIONAL
      RETURNING VALUE(rs)     TYPE ty_prop_res.

*   Does this parcel number exist at all? A DIFFERENT code path in the
*   DPC: a ParcelId filter short-circuits everything above it, checks
*   VILMPL and answers one row carrying only PARCELID - no owner, no area,
*   no land use. Use it to validate a typed-in number, never to display a
*   parcel.
    METHODS parcel_exists
      IMPORTING iv_parcel_id  TYPE string
      RETURNING VALUE(rv)     TYPE abap_bool.

*   The owners whose property this citizen may act for. Feeds the
*   property-management dropdown; its selection becomes IV_OWNER_GUID
*   above. Keyed on the PARTNER NUMBER, not the guid - PARTNERSET reads ID.
    METHODS managed_owners
      RETURNING VALUE(rs) TYPE ty_partner_res.

*   The GIS viewer's url and its token, for a journey that draws the map.
*   Two reads in the control, one here: the token and the url come from
*   the same entity set.
    METHODS map_url
      IMPORTING iv_parcel TYPE string OPTIONAL
      RETURNING VALUE(rs) TYPE ty_map_res.

  PROTECTED SECTION.

*   The partner guid this call should filter on, and a message when there
*   is none. Every read here needs one and the DPC answers blank without
*   saying why, so the check belongs in one place.
    METHODS guard
      IMPORTING iv_owner_guid TYPE string OPTIONAL
      EXPORTING ev_guid       TYPE string
      CHANGING  ct_msg        TYPE bapiret2_t.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rak_property_api IMPLEMENTATION.


  METHOD guard.
    CLEAR ev_guid.

    ev_guid = COND string( WHEN iv_owner_guid IS NOT INITIAL
                           THEN iv_owner_guid
                           ELSE ms_ctx-partnerguid ).
    IF ev_guid IS NOT INITIAL.
      RETURN.
    ENDIF.

*   Not an exception: the caller is a renderer, and a field that cannot be
*   filled has to say so on the screen rather than take the journey down.
    APPEND VALUE bapiret2(
        type       = 'E'
        id         = 'ZMSG_EGA_CJ'
        number     = '000'
        message    = COND #( WHEN sy-langu = 'E'
                             THEN 'No partner is known for this journey, so no property can be listed'
                             ELSE 'لا يوجد شريك معروف لهذه الرحلة، لذلك لا يمكن عرض العقارات' ) )
      TO ct_msg.
  ENDMETHOD.


  METHOD properties.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

    guard( EXPORTING iv_owner_guid = iv_owner_guid
           IMPORTING ev_guid       = DATA(lv_guid)
           CHANGING  ct_msg        = rs-msg ).
    IF lv_guid IS INITIAL.
      RETURN.
    ENDIF.

    filter( EXPORTING iv_property = `Partnerguid` iv_value = lv_guid      CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Partnerrole` iv_value = iv_role      CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `ApplType`    iv_value = iv_appl_type CHANGING ct_filter = lt_flt ).

*   Type is omitted, not sent blank, for 'All'. FILTER( ) already drops a
*   blank value, so passing IV_TYPE through covers both.
    filter( EXPORTING iv_property = `Type`        iv_value = iv_type      CHANGING ct_filter = lt_flt ).

    IF iv_favourite = abap_true.
      filter( EXPORTING iv_property = `Favourite` iv_value = `X` CHANGING ct_filter = lt_flt ).
    ENDIF.

    TRY.
        propertiesset_get_entityset(
          EXPORTING
            iv_entity_name           = `Properties`
            iv_entity_set_name       = `PropertiesSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD parcels.
    rs = properties(
           iv_type       = c_type_parcel
           iv_role       = COND string( WHEN iv_grants = abap_true
                                        THEN c_role_grant ELSE c_role_owner )
           iv_owner_guid = iv_owner_guid ).
  ENDMETHOD.


  METHOD units.
    rs = properties( iv_type       = c_type_unit
                     iv_owner_guid = iv_owner_guid ).
  ENDMETHOD.


  METHOD parcel_exists.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.
    DATA lt_row TYPE tt_prop_rows.

    IF iv_parcel_id IS INITIAL.
      RETURN.
    ENDIF.

*   ParcelId alone. Deliberately no Partnerguid: this path runs BEFORE the
*   partner is read in the DPC and returns before reaching it, so adding
*   one would suggest an ownership test this does not perform.
    filter( EXPORTING iv_property = `ParcelId` iv_value = iv_parcel_id CHANGING ct_filter = lt_flt ).

    TRY.
        propertiesset_get_entityset(
          EXPORTING
            iv_entity_name           = `Properties`
            iv_entity_set_name       = `PropertiesSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = lt_row ).
      CATCH cx_root.
*       An unreadable answer is not a proven absence. Say no, and let the
*       caller's own required check speak - never accept on a failed read.
        RETURN.
    ENDTRY.

    rv = xsdbool( lt_row IS NOT INITIAL ).
  ENDMETHOD.


  METHOD managed_owners.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

    IF ms_ctx-partner IS INITIAL.
      APPEND VALUE bapiret2(
          type    = 'E'
          id      = 'ZMSG_EGA_CJ'
          number  = '000'
          message = COND #( WHEN sy-langu = 'E'
                            THEN 'No partner is known for this journey, so no managed owners can be listed'
                            ELSE 'لا يوجد شريك معروف لهذه الرحلة، لذلك لا يمكن عرض المالكين' ) )
        TO rs-msg.
      RETURN.
    ENDIF.

*   ID is the partner NUMBER here, not the guid - PARTNERSET_GET_ENTITYSET
*   reads BU_PARTNER off it. The guid is what PropertiesSet wants; the two
*   are not interchangeable and this is the one read that takes the number.
    filter( EXPORTING iv_property = `ID`   iv_value = ms_ctx-partner CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Role` iv_value = c_rel_manager  CHANGING ct_filter = lt_flt ).

    TRY.
        partnerset_get_entityset(
          EXPORTING
            iv_entity_name           = `Partner`
            iv_entity_set_name       = `PartnerSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD map_url.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.
    DATA lt_row TYPE tt_mapurl_rows.

    guard( IMPORTING ev_guid = DATA(lv_guid)
           CHANGING  ct_msg  = rs-msg ).
    IF lv_guid IS INITIAL.
      RETURN.
    ENDIF.

    filter( EXPORTING iv_property = `Partnerguid` iv_value = lv_guid   CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `Parcel`      iv_value = iv_parcel CHANGING ct_filter = lt_flt ).

    TRY.
        mapurlset_get_entityset(
          EXPORTING
            iv_entity_name           = `MapUrl`
            iv_entity_set_name       = `MapUrlSet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
            io_tech_request_context  = mo_req
          IMPORTING
            et_entityset             = lt_row ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
        RETURN.
    ENDTRY.

*   The control reads results[0] for both, and the DPC answers one row.
    READ TABLE lt_row INTO DATA(ls_row) INDEX 1.
    IF sy-subrc = 0.
      rs-url    = ls_row-url.
      rs-gisurl = ls_row-gisurl.
      rs-token  = ls_row-token.
    ENDIF.
  ENDMETHOD.


ENDCLASS.
