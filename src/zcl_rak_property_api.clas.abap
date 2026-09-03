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
*&   - The full-details dialog. IT IS GET_EXPANDED_ENTITY, SINGULAR, and
*&     this comment said ENTITYSET until the live URL was read:
*&
*&       PropertiesSet(Intreno='I800100108658',
*&                     Partnerguid=guid'6aa93cf9-0402-1ed6-b5ca-421c803dd3ad')
*&         ?$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,
*&                  ToDevelopment,ToAttachment
*&
*&     A KEY IN THE PATH MAKES IT AN ENTITY READ. Gateway routes
*&     `EntitySet?$expand=` to GET_EXPANDED_ENTITYSET and
*&     `EntitySet(key)?$expand=` to GET_EXPANDED_ENTITY - different
*&     method, different parameters - so a wrapper written against the
*&     plural one would have called something the dialog never calls.
*&     That is why the six tabs are the ONE read this URL performs and
*&     the reason it was thought to need a set read at all was a guess.
*&
*&     AND CJS ALREADY HOLDS BOTH KEY PARTS. Intreno is on the row the
*&     card was drawn from - the parcel list reads it - and Partnerguid is
*&     MS_CTX-PARTNERGUID, derived once by ZCL_RAK_CJ_CTX. So nothing new
*&     has to be resolved; what is missing is only the method call and
*&     whatever it wants for IO_EXPAND.
*&
*&     WHETHER IO_EXPAND IS STILL NEEDED IS NOT ESTABLISHED. The plural
*&     method dereferences it unguarded; the singular one has not been
*&     read. ZRAK_CJ_EXPAND_DIAG prints the DPC's own signature for both,
*&     which settles it in one run - and guessing at a standard method's
*&     parameters is what cost three activation rounds on
*&     ZCL_RAK_CJ_REQ_CTX.
*&   - FloorSet: it exists ONLY inside GET_EXPANDED_ENTITYSET
*&     (iv_entity_name = gc_floor) - the PLURAL one - so it is behind the
*&     expand-object question in a way the details dialog may not be.
*&     RAK_FLOORUNIT therefore still has no flat read to wrap.
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

*   One expanded property. ENTITY is the whole structure the DPC built -
*   the flat TS_PROPERTIES fields plus the six child tables - and the six
*   references below point INTO it, so they stay valid exactly as long as
*   ENTITY does. A child the DPC did not fill comes back UNBOUND rather
*   than as an empty table, which is what lets a tab tell "no rows" apart
*   from "never asked for".
    TYPES: BEGIN OF ty_detail_res,
             entity   TYPE REF TO data,
             partners TYPE REF TO data,   " ToPartner
             landuse  TYPE REF TO data,   " ToLandUse
             measure  TYPE REF TO data,   " ToMeasurement
             develop  TYPE REF TO data,   " ToDevelopment
             project  TYPE REF TO data,   " ToProject
             attach   TYPE REF TO data,   " ToAttachment
             msg      TYPE bapiret2_t,
           END OF ty_detail_res.

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

*   ---- the full-details dialog: one read, six tabs --------------------
*   READ OFF ZCL_ZEGA_CJ_DPC_EXT, not inferred. The method is
*   /IWBEP/IF_MGW_APPL_SRV_RUNTIME~GET_EXPANDED_ENTITY - an INTERFACE
*   method, which is why the 30-character generated-name problem this
*   class's header worried about does not arise, and why it is PUBLIC
*   rather than protected like the _GET_ENTITYSET pair.
*
*   Three hard facts from its body, each of which is a silent empty
*   result if broken:
*
*   1  IT_KEY_TAB must carry BOTH 'Intreno' and 'Partnerguid', spelled
*      exactly like that. The DPC reads them with
*      `it_key_tab[ name = 'Intreno' ]` inside TRY/CATCH
*      CX_SY_ITAB_LINE_NOT_FOUND and RETURNS on a miss - no message, no
*      exception, an empty entity. A blank Partnerguid returns too, and
*      so does a Partnerguid with no BUT000 row.
*
*   2  IO_EXPAND IS DEREFERENCED UNGUARDED despite being declared
*      OPTIONAL: `DATA(lt_children) = io_expand->get_children( ).` runs
*      before any of the six children are fetched. Passing nothing raises
*      CX_SY_REF_IS_INITIAL. And an EMPTY expand object is not enough
*      either - each child is gated on
*      `line_exists( lt_children[ tech_nav_prop_name = 'TOPARTNER' ] )`,
*      so the object has to REPORT the six nav names or every tab comes
*      back empty while the call itself succeeds. That is the one piece
*      still missing and it is why IO_EXPAND is an importing parameter
*      here rather than something this method builds.
*
*   3  The children come back INSIDE ER_ENTITY, not as separate exports:
*      the DPC builds a local structure that INCLUDEs TS_PROPERTIES and
*      adds TOPARTNER, TOLANDUSE, TOMEASUREMENT, TODEVELOPMENT,
*      TOATTACHMENT and TOPROJECT as tables, then COPY_DATA_TO_REF's the
*      whole thing into ER_ENTITY.
*
*   RETURNED AS REFERENCES, DELIBERATELY. Typing the six child tables
*   here would mean naming TS_PARTNER, TS_LANDUSE, TS_MEASUREMENT,
*   TS_DEVELOPMENT, TS_ATTACHMENT and TS_PROJECT - six more generated
*   names to get wrong, and this class's own header records what guessing
*   a generated shape costs. The caller reads cells with ASSIGN COMPONENT
*   exactly as ZCL_RAK_CJ_PARCEL->CELL( ) already does for the flat list,
*   so nothing downstream needs the type either.
    METHODS details
      IMPORTING iv_intreno    TYPE string
                io_expand     TYPE REF TO /iwbep/if_mgw_odata_expand OPTIONAL
                iv_owner_guid TYPE string OPTIONAL
      RETURNING VALUE(rs)     TYPE ty_detail_res.

  PROTECTED SECTION.

*   The partner guid this call should filter on, and a message when there
*   is none. Every read here needs one and the DPC answers blank without
*   saying why, so the check belongs in one place.
    METHODS guard
      IMPORTING iv_owner_guid TYPE string OPTIONAL
      EXPORTING ev_guid       TYPE string
      CHANGING  ct_msg        TYPE bapiret2_t.

*   A reference to one component of the expanded entity, by name, or
*   UNBOUND when the structure has no such component. ASSIGN COMPONENT
*   sets SY-SUBRC and raises nothing, so a name that turns out to be
*   spelled differently on this MPC degrades to an empty tab rather than
*   a dump - which is the right trade for six names read off a source
*   listing rather than from the dictionary.
    METHODS child
      IMPORTING ir_entity TYPE REF TO data
                iv_comp   TYPE string
      RETURNING VALUE(rr) TYPE REF TO data.

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


  METHOD child.
    FIELD-SYMBOLS <ls_ent>  TYPE any.
    FIELD-SYMBOLS <lt_comp> TYPE ANY TABLE.

    IF ir_entity IS NOT BOUND OR iv_comp IS INITIAL.
      RETURN.
    ENDIF.

    ASSIGN ir_entity->* TO <ls_ent>.
    IF <ls_ent> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

*   TO A TABLE FIELD SYMBOL, so a component that exists but is a scalar
*   cannot be handed back as if it were a child list. The six are all
*   tables in the DPC's local TY_PROPERTY; anything else means the name
*   collided with a flat TS_PROPERTIES field.
    ASSIGN COMPONENT to_upper( iv_comp ) OF STRUCTURE <ls_ent> TO <lt_comp>.
    IF sy-subrc <> 0 OR <lt_comp> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    GET REFERENCE OF <lt_comp> INTO rr.
  ENDMETHOD.


  METHOD details.

    guard( EXPORTING iv_owner_guid = iv_owner_guid
           IMPORTING ev_guid       = DATA(lv_guid)
           CHANGING  ct_msg        = rs-msg ).
    IF lv_guid IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_intreno IS INITIAL.
*     The DPC would RETURN silently on the missing key. Say it here, where
*     the caller can still tell which parcel it asked about.
      APPEND VALUE #( type = 'E' message =
        `Property details need the Intreno of the parcel. The parcel list ` &&
        `returns it on every row - carry it through with the parcel id.` )
        TO rs-msg.
      RETURN.
    ENDIF.

*   ---- the one thing this cannot yet build itself ---------------------
*   IO_EXPAND is OPTIONAL on the DPC and dereferenced unconditionally in
*   its body, so calling without one is a dump, not an empty result.
*   Refusing here turns that into a message that names what is missing.
*
*   Building it needs the method list of /IWBEP/IF_MGW_ODATA_EXPAND, or a
*   standard class that already implements it. ZRAK_CJ_EXPAND_DIAG prints
*   both - its own interface methods, and every implementer in the
*   repository with that implementer's CONSTRUCTOR. One run answers it.
*   Nothing is guessed here on purpose: hand-writing the shape of a
*   standard object that cannot be opened from the editing environment is
*   what cost ZCL_RAK_CJ_REQ_CTX three activation rounds.
    IF io_expand IS NOT BOUND.
      APPEND VALUE #( type = 'E' message =
        `Property details need an expand object. GET_EXPANDED_ENTITY reads ` &&
        `io_expand->get_children( ) before it fetches anything and gates each ` &&
        `of the six tabs on the nav name appearing there. Run ` &&
        `ZRAK_CJ_EXPAND_DIAG to get the implementer, then pass one in.` )
        TO rs-msg.
      RETURN.
    ENDIF.

*   ---- the key, both halves, spelled the DPC's way --------------------
*   MIXED CASE, and it is not cosmetic: the DPC reads
*   `it_key_tab[ name = 'Intreno' ]` and `[ name = 'Partnerguid' ]` on a
*   CHAR field, so 'INTRENO' misses and the method returns an empty
*   entity with no message at all.
    DATA lt_key TYPE /iwbep/t_mgw_name_value_pair.
    APPEND VALUE #( name = `Intreno`     value = iv_intreno ) TO lt_key.
    APPEND VALUE #( name = `Partnerguid` value = lv_guid )    TO lt_key.

    DATA lr_ent  TYPE REF TO data.
    DATA ls_ctx  TYPE /iwbep/if_mgw_appl_srv_runtime=>ty_s_mgw_response_entity_cntxt.
    DATA lt_cl   TYPE string_table.
    DATA lt_tcl  TYPE string_table.

    TRY.
        /iwbep/if_mgw_appl_srv_runtime~get_expanded_entity(
          EXPORTING
            iv_entity_name           = `Properties`
            iv_entity_set_name       = `PropertiesSet`
            iv_source_name           = ``
            it_key_tab               = lt_key
            it_navigation_path       = VALUE #( )
            io_expand                = io_expand
            io_tech_request_context  = mo_req
          IMPORTING
            er_entity                = lr_ent
            es_response_context      = ls_ctx
            et_expanded_clauses      = lt_cl
            et_expanded_tech_clauses = lt_tcl ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
        RETURN.
    ENDTRY.

    IF lr_ent IS NOT BOUND.
*     Every RETURN in the DPC's key handling lands here: a missing key, a
*     blank Partnerguid, a guid with no BUT000 row, or a parcel that is
*     not this partner's. They are indistinguishable from outside, so the
*     message says what was asked rather than asserting which one it was.
      APPEND VALUE #( type = 'W' message =
        |No details came back for Intreno { iv_intreno }. The read answers | &&
        |nothing when the parcel is not held by this partner, so check the | &&
        |Intreno against the parcel list this card was drawn from.| )
        TO rs-msg.
      RETURN.
    ENDIF.

    rs-entity   = lr_ent.
    rs-partners = child( ir_entity = lr_ent iv_comp = `TOPARTNER` ).
    rs-landuse  = child( ir_entity = lr_ent iv_comp = `TOLANDUSE` ).
    rs-measure  = child( ir_entity = lr_ent iv_comp = `TOMEASUREMENT` ).
    rs-develop  = child( ir_entity = lr_ent iv_comp = `TODEVELOPMENT` ).
    rs-project  = child( ir_entity = lr_ent iv_comp = `TOPROJECT` ).
    rs-attach   = child( ir_entity = lr_ent iv_comp = `TOATTACHMENT` ).
  ENDMETHOD.


ENDCLASS.
