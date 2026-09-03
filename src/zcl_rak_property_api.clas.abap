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
*& THE FULL-DETAILS DIALOG IS NOW HERE TOO - see DETAILS( ). This block
*& used to list it under "deliberately not here", behind an expand object
*& that could not be built from this environment. It turned out not to
*& need one: the six children are plain method calls on
*& ZCL_EGA_MUN_CJ_ODATA_API, which is what GET_EXPANDED_ENTITY itself
*& calls. The reasoning is at DETAILS( ) rather than repeated here.
*&
*& WHAT IS STILL DELIBERATELY NOT HERE.
*&   - FloorSet. It exists ONLY inside GET_EXPANDED_ENTITYSET - the
*&     PLURAL method - under iv_entity_name = gc_floor, and nothing in
*&     that branch resolves to a legacy class the way the Properties
*&     branch does. So RAK_FLOORUNIT still has no read to wrap, and it is
*&     the one place the expand-object question genuinely remains.
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

*   The six child lists of one property, each an ANONYMOUS data object
*   holding a copy of what the legacy read returned.
*
*   REFERENCES, NOT TYPED TABLES, and CREATE DATA rather than GET
*   REFERENCE OF a local. Two reasons, and both are load-bearing.
*
*   The types are unknowable from here: the row structures live on
*   ZCL_EGA_MUN_CJ_ODATA_API's own method signatures, and naming them
*   would be six more generated shapes to get wrong - which this class's
*   header already records the cost of. DETAILS( ) never declares one; it
*   takes what the method returns with an inline DATA( ) and copies it
*   into an anonymous object of the same type via CREATE DATA ... LIKE.
*
*   And a reference to a local variable would DANGLE. Only anonymous data
*   objects are kept alive by the reference itself; a method's own locals
*   go when the method does, so GET REFERENCE OF one and handing it back
*   is a reference to reclaimed memory.
*
*   UNBOUND MEANS NOT READ, empty means read and genuinely nothing - a
*   distinction a tab needs, because "this parcel has no buildings" and
*   "we could not ask" are different sentences to show a citizen.
    TYPES: BEGIN OF ty_detail_res,
             partners TYPE REF TO data,   " ToPartner      get_partners( )
             landuse  TYPE REF TO data,   " ToLandUse      get_chars( )
             measure  TYPE REF TO data,   " ToMeasurement  get_meas( )
             develop  TYPE REF TO data,   " ToDevelopment  get_assobj( )
             project  TYPE REF TO data,   " ToProject      get_projects( )
             attach   TYPE REF TO data,   " ToAttachment   get_filenet_docs( )
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

*   ---- the full-details dialog: six tabs, no expand object -----------
*   THE EXPAND OBJECT TURNED OUT TO BE AVOIDABLE, which is worth more
*   than solving it would have been.
*
*   The dialog's own URL is a GET_EXPANDED_ENTITY call - singular, a key
*   in the path - and that method looked like the only way in. It has two
*   hard requirements, both read off ZCL_ZEGA_CJ_DPC_EXT rather than
*   guessed. IT_KEY_TAB must carry 'Intreno' and 'Partnerguid' in exactly
*   that mixed-case spelling, because the DPC reads them with
*   `it_key_tab[ name = 'Intreno' ]` inside TRY/CATCH
*   CX_SY_ITAB_LINE_NOT_FOUND and RETURNS on a miss - no message, no
*   exception, an empty entity. And IO_EXPAND, though declared OPTIONAL,
*   is dereferenced unconditionally: `io_expand->get_children( )` runs
*   before any child is fetched, and every child is then gated on
*   `line_exists( lt_children[ tech_nav_prop_name = 'TOPARTNER' ] )`. So
*   an expand object is required AND has to report the six nav names -
*   an empty one returns an entity with every tab blank, which looks
*   exactly like a backend holding no data.
*
*   Building one needs the method list of /IWBEP/IF_MGW_ODATA_EXPAND, and
*   that is not readable here: not in the class, not in doc/, and no
*   implementer appears in any legacy source in this repository. Guessing
*   at it is precisely what cost ZCL_RAK_CJ_REQ_CTX three activation
*   rounds.
*
*   SO READ THE SAME SOURCES THE DPC READS. Its body shows every one of
*   the six children is a plain method call on a legacy class CJS can
*   instantiate for itself:
*
*       ToPartner      lo_obj->get_partners( intreno = ... )
*       ToMeasurement  lo_obj->get_meas( intreno = ... )
*       ToLandUse      lo_obj->get_chars( intreno = ... )
*       ToDevelopment  lo_obj->get_assobj( objnr = ... )
*       ToProject      lo_obj->get_projects( IMPORTING projects = ... )
*       ToAttachment   me->get_filenet_docs( ... )
*
*   where LO_OBJ is NEW ZCL_EGA_MUN_CJ_ODATA_API( partner = ... ) and
*   GET_FILENET_DOCS is on the DPC itself - reachable because this class
*   INHERITS it, the same reason the protected _GET_ENTITYSET methods are
*   reachable.
*
*   All IO_EXPAND ever did inside GET_EXPANDED_ENTITY was let the method
*   decide WHICH children to fetch. Asking for all six directly needs no
*   such object, so the one piece that could not be built from here stops
*   being on the path at all.
*
*   READING A LEGACY CLASS IS NOT MODIFYING ONE. Nothing here writes to
*   the legacy namespace; it calls it, exactly as the whole QNV bridge
*   does.
*
*   WHAT THIS GIVES UP is the flat half of the entity - PARCELID,
*   AREATEXT, ADDRESS, TYPE and the rest - which GET_EXPANDED_ENTITY
*   would have returned alongside the children. That costs nothing: the
*   caller already holds those on the row its card was drawn from, and
*   ZCL_RAK_CJ_PARCEL->GENERAL_TAB( ) fills the General tab from exactly
*   that row.
*
*   IV_PARCEL and IV_AOID are for the attachments only - GET_FILENET_DOCS
*   keys on the parcel number and the AOID, never on the intreno.
    METHODS details
      IMPORTING iv_intreno    TYPE string
                iv_parcel     TYPE string OPTIONAL
                iv_aoid       TYPE string OPTIONAL
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


  METHOD details.

*   IDENTITY STILL GOES THROUGH GUARD( ), even though nothing below
*   filters on the guid. It is the one place that says "this journey was
*   launched without a partner" in words rather than by returning nothing,
*   and a details dialog with no partner behind it is the same defect as a
*   parcel list with none.
    guard( EXPORTING iv_owner_guid = iv_owner_guid
           IMPORTING ev_guid       = DATA(lv_guid)
           CHANGING  ct_msg        = rs-msg ).
    IF lv_guid IS INITIAL.
      RETURN.
    ENDIF.

    IF iv_intreno IS INITIAL.
      APPEND VALUE #( type = 'E' message =
        `Property details need the Intreno of the parcel. The parcel list ` &&
        `returns it on every row - carry it through with the parcel id.` )
        TO rs-msg.
      RETURN.
    ENDIF.

*   ---- the partner, as the legacy class wants it ----------------------
*   MS_CTX-PARTNER, not a BUT000 lookup. The DPC re-derives the partner
*   number from the guid because it is handed only a guid; CJS already
*   holds the number - ZCL_RAK_CJ_CTX puts the engine's MV_LOGINBP there -
*   so going back to BUT000 would mean converting the guid string to
*   BU_PARTNER_GUID, which is a raw16 and not something a 32-character hex
*   string assigns to cleanly.
*
*   TYPED BU_PARTNER, and ALPHA-padded into it. The DPC passes the value
*   straight out of a BUT000 SELECT, so that is the type the constructor
*   was written against - and it pads its own before passing one
*   elsewhere in the same class, which says the class expects the padded
*   form.
    DATA lv_bp TYPE bu_partner.
    lv_bp = |{ ms_ctx-partner ALPHA = IN }|.
    IF lv_bp IS INITIAL.
      APPEND VALUE #( type = 'E' message =
        `Property details need the business partner number, and the ` &&
        `journey context carries none. It comes from the launch ` &&
        `parameters through ZCL_RAK_CJ_CTX.` )
        TO rs-msg.
      RETURN.
    ENDIF.

*   ONE TRY AROUND THE WHOLE THING, and every child inside it. These are
*   six reads against RE-FX, FI and ECM through a legacy class this
*   environment cannot compile against - so an exception is a message,
*   never a dump in a dialog the citizen opened to look at a parcel.
*   Partial results are kept deliberately: five tabs filled and one
*   explained beats six blank ones.
    TRY.
        DATA(lo_obj) = NEW zcl_ega_mun_cj_odata_api( partner = lv_bp ).

*       NARROW TO THIS PARCEL FIRST, exactly as the DPC does. The
*       constructor loads every property the partner holds, and
*       GET_PROJECTS( ) has no intreno parameter - it works off whatever
*       is left in PROPERTIES. Without this the Active Projects count is
*       every project on every parcel the citizen owns.
        DELETE lo_obj->properties WHERE intreno <> iv_intreno.

*       ---- ToPartner ----------------------------------------------
*       CONV #( ) because the formal parameter is a DDIC type and
*       IV_INTRENO is a string: parameters here bind BY REFERENCE, so a
*       string against a CHAR13 is a syntax error rather than a
*       conversion. The DPC writes CONV #( ) at the same call for the
*       same reason.
        DATA(lt_bp) = lo_obj->get_partners( intreno = CONV #( iv_intreno ) ).
        CREATE DATA rs-partners LIKE lt_bp.
        ASSIGN rs-partners->* TO FIELD-SYMBOL(<lt_bp>).
        IF <lt_bp> IS ASSIGNED.
          <lt_bp> = lt_bp.
        ENDIF.

*       ---- ToMeasurement ------------------------------------------
        DATA(lt_ms) = lo_obj->get_meas( intreno = CONV #( iv_intreno ) ).
        CREATE DATA rs-measure LIKE lt_ms.
        ASSIGN rs-measure->* TO FIELD-SYMBOL(<lt_ms>).
        IF <lt_ms> IS ASSIGNED.
          <lt_ms> = lt_ms.
        ENDIF.

*       ---- ToLandUse ----------------------------------------------
        DATA(lt_ch) = lo_obj->get_chars( intreno = CONV #( iv_intreno ) ).
        CREATE DATA rs-landuse LIKE lt_ch.
        ASSIGN rs-landuse->* TO FIELD-SYMBOL(<lt_ch>).
        IF <lt_ch> IS ASSIGNED.
          <lt_ch> = lt_ch.
        ENDIF.

*       ---- ToDevelopment ------------------------------------------
*       KEYED ON OBJNR, NOT INTRENO - the one child that is, and the DPC
*       resolves it with this same SELECT. A parcel with no VILMPL row
*       leaves the tab empty rather than reading somebody else's
*       buildings, which is what passing an initial OBJNR would risk.
        SELECT SINGLE objnr FROM vilmpl INTO @DATA(lv_objnr)
          WHERE intreno = @iv_intreno.
        IF sy-subrc = 0 AND lv_objnr IS NOT INITIAL.
          DATA(lt_dv) = lo_obj->get_assobj( objnr = lv_objnr ).
          CREATE DATA rs-develop LIKE lt_dv.
          ASSIGN rs-develop->* TO FIELD-SYMBOL(<lt_dv>).
          IF <lt_dv> IS ASSIGNED.
            <lt_dv> = lt_dv.
          ENDIF.
        ENDIF.

*       ---- ToProject ----------------------------------------------
*       EXPORTING-only, so the variable is declared rather than inlined
*       in the call - an inline DATA( ) in the IMPORTING part of a
*       functional call that is itself an assignment source is refused,
*       and this shape sidesteps that whole question.
*
*       INLINE DATA( ), AND NOT A TYPE OF MY CHOOSING. This was written
*       as `DATA lt_pj TYPE ztt_ega_ao_list` first, on the strength of an
*       `aos TYPE ztt_ega_ao_list` declaration sitting near the call in
*       the DPC - but the DPC does not pass AOS here. It writes
*       `IMPORTING projects = DATA(proj)`, so that type was a guess about
*       a shape this environment cannot read, which is the one mistake
*       this file's header is entirely about.
*
*       The inline form takes whatever the method declares and needs to
*       know nothing. CLAUDE.md's inline-DATA trap does not apply: it is
*       about an inline declaration in the IMPORTING part of a FUNCTIONAL
*       call that is itself an assignment's source, and this is a plain
*       method call statement - which is exactly how the DPC writes it.
        TRY.
            lo_obj->get_projects( IMPORTING projects = DATA(lt_pj) ).
            CREATE DATA rs-project LIKE lt_pj.
            ASSIGN rs-project->* TO FIELD-SYMBOL(<lt_pj>).
            IF <lt_pj> IS ASSIGNED.
              <lt_pj> = lt_pj.
            ENDIF.
          CATCH cx_root INTO DATA(lx_pj).
*           ITS OWN CATCH. GET_PROJECTS( ) reaches furthest of the six -
*           ZDT_EGA_CAAT_PRM, the case table and ZP00( ) - so it is the
*           most likely to raise, and one failure there should not cost
*           the five tabs already filled above.
            to_msg( EXPORTING io_exc = lx_pj CHANGING ct_msg = rs-msg ).
        ENDTRY.

*       ---- ToAttachment -------------------------------------------
*       ME->, and that is the point of inheriting the DPC:
*       GET_FILENET_DOCS is PROTECTED there, so only a subclass can call
*       it - the same reason the _GET_ENTITYSET methods are reachable
*       from this class.
*
*       PARCEL AND AOID, never the intreno. And ALPHA-padded: the DPC
*       pads PARCELID immediately before this call, so the unpadded form
*       the card displays is not what ECM is keyed on.
        IF iv_parcel IS NOT INITIAL OR iv_aoid IS NOT INITIAL.
          DATA lv_pcl TYPE string.
          lv_pcl = iv_parcel.
          IF lv_pcl IS NOT INITIAL.
            lv_pcl = |{ lv_pcl ALPHA = IN }|.
          ENDIF.
          TRY.
*             INLINE HERE TOO, same reason as GET_PROJECTS( ) above: the
*             DPC writes `IMPORTING docs = DATA(fn_docs)` and never names
*             the type, so neither does this.
              me->get_filenet_docs(
                EXPORTING partner   = lv_bp
                          iv_parcel = CONV #( lv_pcl )
                          iv_aoid   = CONV #( iv_aoid )
                IMPORTING docs      = DATA(lt_dc) ).
              CREATE DATA rs-attach LIKE lt_dc.
              ASSIGN rs-attach->* TO FIELD-SYMBOL(<lt_dc>).
              IF <lt_dc> IS ASSIGNED.
                <lt_dc> = lt_dc.
              ENDIF.
            CATCH cx_root INTO DATA(lx_dc).
*             ITS OWN CATCH TOO, and for a sharper reason than projects:
*             this one leaves the system. Every document is a separate
*             ZCL_EGA_FILENET_API read that returns the file CONTENT as
*             base64, so a slow or unreachable ECM must not take the five
*             local tabs with it.
              to_msg( EXPORTING io_exc = lx_dc CHANGING ct_msg = rs-msg ).
          ENDTRY.
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


ENDCLASS.
