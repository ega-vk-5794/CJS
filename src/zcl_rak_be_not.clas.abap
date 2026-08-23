*&---------------------------------------------------------------------*
*& ZCL_RAK_BE_NOT   -   Notary Portal REST backend adapter
*&---------------------------------------------------------------------*
*& Every value this journey shows and every value it stores comes from
*& the Notary REST API. Nothing is read from or written to an SAP table
*& by this class: no /QNV/ export, no search help, no BAdI, no FI-CA.
*& SAP is the UI and nothing else.
*&
*& API surface implemented here (see Notary_Portal collection):
*&   POST   /client/authenticate
*&   GET    /subservice/{id}                       blueprint: BO fields + documents
*&   POST   /request/events/draft                  create request
*&   GET    /request/{id}                          resume / read
*&   DELETE /request/{id}                          discard
*&   POST   /party/search?searchType=              party lookup
*&   POST   /request/{id}/party/exist?searchType=  duplicate pre-check
*&   POST   /request/{id}/party[/{bpId}]?partyType= add party
*&   GET    /request/{id}/party                    parties on the request
*&   POST | PUT /request/{id}/businessobject[/{boId}]
*&   GET    /request/{id}/businessobject
*&   POST   /request/{id}/attachment               multipart
*&   GET    /request/{id}/attachment               attachments on the request
*&   POST | PUT /request/{id}/transfer/selection | /transfer     visit request
*&   GET  | PUT /request/{id}/legaltext
*&   GET    /request/{id}/fetchPossibleBillingDocumentOwners
*&   POST   /request/{id}/bill/owner
*&   POST | PUT /request/{id}/events/submit
*&   GET  | POST /request/{id}/payment/initial?paymentType=1      calc | create BD
*&   GET    /request/{id}/transaction/{bdo}/status
*&   PUT    /request/{id}/payment/transaction/{bdo}/event/lock
*&   PUT    /request/{id}/payment/transaction/{bdo}/event/paid
*&   GET    /static/nationalities | occupation | countries | region
*&   GET    /static/regionbycountry/{c} | /static/{c}/cities/{r}
*&
*& THREE THINGS THAT WERE WRONG AND ARE NOW FIXED
*&
*& 1. Authorization was sent as the raw token with no prefix, on the
*&    strength of the shared collection. The login response settles it:
*&    it returns "type":"Bearer", so the prefix belongs there and
*&    mc_bearer is abap_true. The earlier 401 on every call after login
*&    was this, not an expired credential.
*&
*& 3. Success was decided from the HTTP status alone. Notary answers
*&    200 OK to logical failures and puts the real outcome in the
*&    envelope, so a rejected request read as a successful one and every
*&    result downstream of it was untrustworthy. ok_of( ) now decides.
*&    Proven on the live QA API 15 Aug 2026, requests 13301-13304:
*&      success   statusCode 201, respMessage CREATED, notaryCode 10007
*&      failure   statusCode and respMessage absent, notaryCode 7006 or
*&                7018, notaryDescription carrying the text
*&    notaryCode is present on both and cannot decide alone; the
*&    envelope's own statusCode is the discriminator wherever it appears.
*&
*& 2. The BO payload quoted every value. The collection posts numbers
*&    unquoted (caseNumber: 1111, saleAmountValue: 5000.00, caseType: 1).
*&    bo_json( ) now takes the type from the blueprint and quotes only
*&    what is genuinely text.
*&
*& CACHING. The static tables below live for one round trip, which is the
*& useful unit: a render that draws three country dropdowns costs one call,
*& not three. Nothing survives the round trip, so nothing can go stale.
*&---------------------------------------------------------------------*
CLASS zcl_rak_be_not DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_rak_journey_backend.

*   One required / optional document as the blueprint describes it.
    TYPES: BEGIN OF ty_doc,
             conf_id   TYPE string,        " attachmentConfId - the API's document code
             name      TYPE string,
             name_ar   TYPE string,
             required  TYPE abap_bool,
             extension TYPE string,        " 'pdf,jpg,png' when the API says
           END OF ty_doc,
           tt_doc TYPE STANDARD TABLE OF ty_doc WITH EMPTY KEY.

    METHODS constructor
      IMPORTING iv_subservice TYPE string OPTIONAL
                iv_loginbp    TYPE string OPTIONAL
                iv_userdata   TYPE string OPTIONAL.

*   ---- lookups, all live -------------------------------------------------
*   iv_list: NATIONALITY | OCCUPATION | COUNTRY | REGION | CITY | CLASSIFICATION
*   iv_arg1: country code (REGION by country, CITY)
*   iv_arg2: region id    (CITY)
    METHODS lookup
      IMPORTING iv_list       TYPE string
                iv_arg1       TYPE string OPTIONAL
                iv_arg2       TYPE string OPTIONAL
      RETURNING VALUE(rt_opt) TYPE zif_rak_journey_backend=>tt_dyn_opt.

*   Which live list, if any, a blueprint field name belongs to. This is the
*   only place a field name is tied to a list, and it returns a list NAME,
*   never list CONTENT - the content is always fetched by lookup( ).
*   rv_dependent = the list needs values this method cannot see (country,
*   region), so it must be filled after the citizen picks its parent.
*   The declaration the citizen chose on step 1.
*
*   ZCL_RAK_BE_FACTORY builds this class with iv_subservice = BKND_JOURNEY off
*   the journey header, which is a STATIC value - fine for a backend that
*   serves one thing, wrong here. One Notary journey serves every declaration
*   type and the blueprint is per declaration, so the sub-service cannot be
*   known until the citizen picks one. Left to the header alone it is blank,
*   and BLUEPRINT( ) then GETs /subservice/ with an empty id and takes a 400
*   on every render of step 1.
*
*   Static because the blueprint cache beside it already is: the engine drops
*   its backend reference between round trips, so an instance attribute would
*   not survive to the next one.
    CLASS-METHODS set_subservice
      IMPORTING iv_sub TYPE string.

    METHODS dyn_list_for
      IMPORTING iv_name        TYPE string
      EXPORTING ev_dependent   TYPE abap_bool
      RETURNING VALUE(rv_list) TYPE string.

*   Party search. Returns the raw response so the handler can decide what
*   to pre-fill; parse_party( ) below turns it into name/value pairs.
*   Notary's own party search. NOT called any more: party identity is resolved in
*   SAP, by ZCL_RAK_BP_SEARCH, so that MOI runs and an expired Emirates ID or
*   trade licence is refused before the party can reach a declaration - see
*   ZCL_RAK_NOT_APPROVAL_LOGIC->ON_SEARCH( ).
*
*   Kept rather than deleted for two reasons: it is the only place Notary's
*   searchType contract is written down, and step 5a of the API flow (pre-check
*   party existence) may still want it.
    METHODS search_party
      IMPORTING iv_search_type     TYPE string
                it_fields          TYPE zif_rak_journey_backend=>tt_field
                iv_request_id      TYPE string OPTIONAL
      RETURNING VALUE(rv_response) TYPE string.

*   The searched party as flat pairs, field names matching the journey's
*   own PARTY_* fields, plus BPID and BPSTATUS.
    METHODS parse_party
      IMPORTING iv_response      TYPE string
      RETURNING VALUE(rt_fields) TYPE zif_rak_journey_backend=>tt_field.

*   The documents this sub-service asks for, from the blueprint.
    METHODS doc_types
      RETURNING VALUE(rt_doc) TYPE tt_doc.

*   Default legal text for the request (GET /legaltext).
    METHODS legal_text
      IMPORTING iv_request_id  TYPE string
      RETURNING VALUE(rv_text) TYPE string.

*   The parties already on the request (GET /request/{id}/party).
*
*   The endpoint was documented at the top of this class from the start and
*   never implemented, so the First Party and Second Party tables had nothing
*   behind them and drew "No data" over a request that demonstrably had a
*   party - the draft response names it.
*   Wider than the three columns the list shows on purpose. The view dialog
*   restates a party the API already holds, and a dialog that can only repeat
*   the row above it is not worth opening - so the read takes everything the
*   endpoint offers and the list picks three of them.
    TYPES: BEGIN OF ty_party_row,
             party_id     TYPE string,
             party_name   TYPE string,
             name_ar      TYPE string,
             mobile       TYPE string,
             email        TYPE string,
             nationality  TYPE string,
             id_number    TYPE string,
             party_kind   TYPE string,
             first_party  TYPE abap_bool,
             second_party TYPE abap_bool,
           END OF ty_party_row,
           tt_party_row TYPE STANDARD TABLE OF ty_party_row WITH EMPTY KEY.

    METHODS parties
      IMPORTING iv_request_id TYPE string
      RETURNING VALUE(rt)     TYPE tt_party_row.

*   Who may own the billing document.
    METHODS billing_owners
      IMPORTING iv_request_id TYPE string
      RETURNING VALUE(rt_opt) TYPE zif_rak_journey_backend=>tt_dyn_opt.

*   Payment status for the billing document currently on the handle.
    METHODS payment_status
      IMPORTING is_handle        TYPE zif_rak_journey_backend=>ty_handle
      RETURNING VALUE(rv_status) TYPE string.

*   Raw sub-service blueprint. Public because the Studio and the trace
*   both want to see exactly what the API answered.
    METHODS subservice_json
      RETURNING VALUE(rv_json) TYPE string.

protected section.
  PRIVATE SECTION.

    CONSTANTS mc_api        TYPE string VALUE 'NOTARY_ES'.
    CONSTANTS mc_bearer     TYPE abap_bool VALUE abap_true.
*   Used ONLY when the portal session supplies no BP. Must be a real BP on
*   the target box. Remove before PROD.
    CONSTANTS mc_dev_bp     TYPE string VALUE '1000000226'.

    DATA mv_subservice TYPE string.
    DATA mv_loginbp    TYPE string.
    DATA mv_userdata   TYPE string.

*   ---- per-round-trip caches --------------------------------------------
    CLASS-DATA gv_token TYPE string.
    CLASS-DATA gv_bp_sub TYPE string.
*   Set by SET_SUBSERVICE( ) from the handler. Wins over the constructor's
*   value, which is the journey header's static one.
    CLASS-DATA gv_sub_cur TYPE string.
    CLASS-DATA gv_bp_json TYPE string.
    CLASS-DATA: BEGIN OF gs_lk_line,
                  key  TYPE string,
                  opts TYPE zif_rak_journey_backend=>tt_dyn_opt,
                END OF gs_lk_line.
    CLASS-DATA gt_lk LIKE STANDARD TABLE OF gs_lk_line WITH EMPTY KEY.

*   Blueprint field, normalised. mv_map is what turns the engine's
*   upper-case model member back into the API's exact camelCase key.
    TYPES: BEGIN OF ty_map,
             upper TYPE string,
             json  TYPE string,
             num   TYPE abap_bool,
           END OF ty_map,
           tt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.
    CLASS-DATA gt_map TYPE tt_map.
    CLASS-DATA gt_doc TYPE tt_doc.

*   ---- shared response shapes -------------------------------------------
    TYPES: BEGIN OF ty_party_r,   party_id TYPE string, business_partner_id TYPE string, END OF ty_party_r,
           BEGIN OF ty_party_resp, result  TYPE ty_party_r, END OF ty_party_resp.
    TYPES: BEGIN OF ty_bo_r,      business_object_id TYPE string, id TYPE string, END OF ty_bo_r,
           BEGIN OF ty_bo_resp,   result             TYPE ty_bo_r, END OF ty_bo_resp.
    TYPES: BEGIN OF ty_calc_r,    total_amount TYPE string, amount TYPE string, END OF ty_calc_r,
           BEGIN OF ty_calc_resp, result       TYPE ty_calc_r,
                                  total_amount TYPE string, amount TYPE string, END OF ty_calc_resp.
    TYPES: BEGIN OF ty_bd_r,      sap_billing_number TYPE string, payment_url TYPE string,
                                  application_url    TYPE string, END OF ty_bd_r,
           BEGIN OF ty_bd_resp,   result             TYPE ty_bd_r,
                                  sap_billing_number TYPE string, END OF ty_bd_resp.

    METHODS authenticate
      IMPORTING iv_force  TYPE abap_bool DEFAULT abap_false
      EXPORTING et_return TYPE bapiret2_t
      CHANGING  cs_handle TYPE zif_rak_journey_backend=>ty_handle.

    METHODS reauth
      EXPORTING et_return TYPE bapiret2_t
      CHANGING  cs_handle TYPE zif_rak_journey_backend=>ty_handle.

    METHODS ensure_token
      EXPORTING et_return TYPE bapiret2_t
      CHANGING  cs_handle TYPE zif_rak_journey_backend=>ty_handle.

    METHODS auth_hdr
      IMPORTING is_handle        TYPE zif_rak_journey_backend=>ty_handle
      RETURNING VALUE(rt_header) TYPE tihttpnvp.

    METHODS field
      IMPORTING it_fields       TYPE zif_rak_journey_backend=>tt_field
                iv_name         TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    METHODS today
      RETURNING VALUE(rv_d) TYPE string.
    METHODS now_ts
      RETURNING VALUE(rv_ts) TYPE string.

    METHODS party_json
      IMPORTING it_fields      TYPE zif_rak_journey_backend=>tt_field
                iv_first       TYPE abap_bool
      RETURNING VALUE(rv_json) TYPE string.

    METHODS company_json
      IMPORTING it_fields      TYPE zif_rak_journey_backend=>tt_field
                iv_first       TYPE abap_bool
      RETURNING VALUE(rv_json) TYPE string.

    METHODS transfer_json
      IMPORTING it_fields      TYPE zif_rak_journey_backend=>tt_field
      RETURNING VALUE(rv_json) TYPE string.

*   Business-object payload: blueprint field names, blueprint types.
    METHODS bo_json
      IMPORTING it_fields      TYPE zif_rak_journey_backend=>tt_field
      RETURNING VALUE(rv_json) TYPE string.

    METHODS blueprint
      RETURNING VALUE(rv_json) TYPE string.
    METHODS parse_blueprint.

*   A blueprint key made safe to be an ABAP structure component: upper case,
*   only letters digits and underscore, never longer than 30 characters. See the
*   method - a 35-character jsonKey took the whole app down with
*   CX_SY_STRUCT_COMP_NAME. The API key itself is never changed.
    METHODS model_name
      IMPORTING iv_key    TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS to_options
      IMPORTING iv_json       TYPE string
      RETURNING VALUE(rt_opt) TYPE zif_rak_journey_backend=>tt_dyn_opt.

    METHODS esc
      IMPORTING iv_in         TYPE string
      RETURNING VALUE(rv_out) TYPE string.

    METHODS msg
      IMPORTING iv_type   TYPE bapiret2-type
                iv_text   TYPE string
      CHANGING  ct_return TYPE bapiret2_t.

*   Did the call actually work? HTTP first, then the Notary envelope.
*   ev_code is handed back so a caller can wave through a code that is
*   benign at that one call site - 7006 on a party the draft already
*   created, 9042 on a business object this sub-service does not take.
*   Nothing is waved through centrally.
    METHODS ok_of
      IMPORTING iv_resp      TYPE string
                iv_status    TYPE i
      EXPORTING ev_code      TYPE string
                ev_msg       TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS json_scalar
      IMPORTING iv_json   TYPE string
                iv_key    TYPE string
      RETURNING VALUE(rv) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_BE_NOT IMPLEMENTATION.


  METHOD authenticate.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

*   The credential is still the collection's. Q1 in the clarification
*   document is a blocker precisely because this one returns notaryCode
*   2014 from Postman as well - so a failure here is expected until
*   Notary answers, and the message says which call failed rather than
*   surfacing as an empty screen three steps later.
    DATA: BEGIN OF ls_cfg,
            username TYPE string,
            password TYPE string,
          END OF ls_cfg.
    ls_cfg-username = 'notaryuser1'.
    ls_cfg-password = 'hPlfkpZOnZuY1GXA04nKdbyfBp9+nxOqX5Rjm7iUjE7UAuxURPi5fbO5kVO2XmWAiCuO8czx2z2ama7FeCuS5YwA3fO3K1XtmsmNUjLSr6wDFYFQXgMtW7z7rnYtCOj1a1GxWpI0gBOa1vWKEvjRiLHAd3GpDevVhVlg3BEs5fs='.

    IF iv_force = abap_true.
      CLEAR: gv_token, cs_handle-token.
    ENDIF.

    IF gv_token IS NOT INITIAL.
      zcl_rak_not_trace=>add( 'AUTH reusing cached static token - no call to /client/authenticate' ).
      cs_handle-token = gv_token.
      RETURN.
    ENDIF.

*   Neither half may be blank, and the reason is SERIALIZE's COMPRESS below.
*   COMPRESS omits INITIAL components, so an empty password does not send
*   "password":"" - it sends no password key at all, and the body
*   {"userCredential":{"userName":"..."}} is malformed rather than wrong. The
*   portal answers 400 Bad Request, which reads as a broken request shape and
*   sends you looking at the payload instead of at the credential.
    IF ls_cfg-username IS INITIAL OR ls_cfg-password IS INITIAL.
      zcl_rak_not_trace=>add( |AUTH not attempted - | &&
        COND string( WHEN ls_cfg-username IS INITIAL THEN 'username is blank. ' ) &&
        COND string( WHEN ls_cfg-password IS INITIAL THEN 'password is blank. ' ) &&
        |Maintain both in AUTHENTICATE( ).| ).
      RETURN.
    ENDIF.

*   Length, never the value. A credential that arrives truncated - pasted over
*   a line break, or cut by a CHAR field on the way in - looks present and
*   fails, and the length is the one thing that tells them apart without
*   putting a secret in a message strip on a citizen-facing page.
    zcl_rak_not_trace=>add( |AUTH calling /client/authenticate as '{ ls_cfg-username }' | &&
                            |(password { strlen( ls_cfg-password ) } chars)| ).

    TYPES: BEGIN OF ty_auth_cred, user_name TYPE string, password TYPE string, END OF ty_auth_cred,
           BEGIN OF ty_auth_body, user_credential TYPE ty_auth_cred, END OF ty_auth_body,
             BEGIN OF ty_auth_resp, access_token TYPE string, refresh_token TYPE string, END OF ty_auth_resp.

    DATA(ls_body) = VALUE ty_auth_body( user_credential = VALUE #(
                        user_name = ls_cfg-username
                        password  = ls_cfg-password ) ).

    DATA(lv_json) = /ui2/cl_json=>serialize( data        = ls_body
                                             compress    = abap_true
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/client/authenticate' iv_payload = lv_json ).
    DATA(lv_resp) = zcl_rak_http=>call( EXPORTING iv_api     = mc_api
                                                  iv_path    = '/client/authenticate'
                                                  iv_method  = 'POST'
                                                  iv_payload = lv_json
                                        IMPORTING ev_status  = lv_status
                                                  ev_reason  = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/client/authenticate' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).

    DATA lv_amsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_amsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Notary authenticate failed ({ lv_status }): { lv_amsg }|
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

    DATA ls_ares TYPE ty_auth_resp.
    /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                         pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                               CHANGING  data        = ls_ares ).

    IF ls_ares-access_token IS INITIAL.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Notary authenticate returned no accessToken: { lv_resp }|
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

    gv_token        = ls_ares-access_token.
    cs_handle-token = ls_ares-access_token.

  ENDMETHOD.


  METHOD auth_hdr.
    DATA(lv_val) = COND string( WHEN mc_bearer = abap_true
                                THEN |Bearer { is_handle-token }|
                                ELSE is_handle-token ).

    zcl_rak_not_trace=>auth( iv_handle_token = is_handle-token
                             iv_static_token = gv_token
                             iv_header       = lv_val ).

    rt_header = VALUE #( ( name = 'Authorization' value = lv_val ) ).
  ENDMETHOD.


  METHOD billing_owners.

    IF iv_request_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/fetchPossibleBillingDocumentOwners' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}/fetchPossibleBillingDocumentOwners'
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = VALUE #( ( name = '{reqId}' value = iv_request_id ) )
      IMPORTING
        ev_status      = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/fetchPossibleBillingDocumentOwners' iv_status = lv_status iv_resp = lv_resp ).

    IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
      rt_opt = to_options( lv_resp ).
    ENDIF.

  ENDMETHOD.


  METHOD set_subservice.
*   Nothing else to do: BLUEPRINT( ) keys its cache on the sub-service, so
*   changing this value invalidates it by itself and the next call re-reads.
    gv_sub_cur = condense( iv_sub ).
  ENDMETHOD.


  METHOD blueprint.

*   The citizen's choice first, the header's static value second.
    DATA(lv_sub) = COND string( WHEN gv_sub_cur IS NOT INITIAL
                                THEN gv_sub_cur
                                ELSE mv_subservice ).

*   No declaration chosen yet. Returning here is the whole point: the call
*   would go out as GET /subservice/ with an empty id, come back 400, and do
*   it again on every render of step 1 - which is exactly what the trace
*   showed. There is no blueprint to fetch until there is a declaration.
    IF lv_sub IS INITIAL.
      zcl_rak_not_trace=>add( 'BLUEPRINT skipped - no declaration chosen yet ' &&
                              '- BKND_JOURNEY is blank and SET_SUBSERVICE has not been called' ).
      RETURN.
    ENDIF.

    IF gv_bp_sub = lv_sub AND gv_bp_json IS NOT INITIAL.
      zcl_rak_not_trace=>add( |BLUEPRINT sub-service { lv_sub } served from cache| ).
      rv_json = gv_bp_json.
      RETURN.
    ENDIF.
    zcl_rak_not_trace=>add( |BLUEPRINT sub-service { lv_sub } | &&
      COND string( WHEN gv_sub_cur IS NOT INITIAL THEN '(chosen at runtime)' ELSE '(from BKND_JOURNEY)' ) &&
      | - fetching| ).

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.
    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.

    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/subservice/{sub}' ).
    rv_json = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/subservice/{sub}'
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = VALUE #( ( name = '{sub}' value = lv_sub ) )
      IMPORTING
        ev_status      = lv_status
        ev_reason      = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/subservice/{sub}' iv_status = lv_status iv_reason = lv_reason iv_resp = rv_json ).

    IF ok_of( iv_resp = rv_json iv_status = lv_status ) = abap_false.
      CLEAR rv_json.
      RETURN.
    ENDIF.

*   LV_SUB, not MV_SUBSERVICE. The check at the top of this method compares
*   GV_BP_SUB against LV_SUB, so storing the constructor's value here meant the
*   two never matched and the blueprint was re-fetched on every single call -
*   several times per render, since BO_JSON, DOC_TYPES, DESCRIBE_STEP and
*   LEGAL_TEXT all go through BLUEPRINT( ).
    gv_bp_sub  = lv_sub.
    gv_bp_json = rv_json.
    CLEAR: gt_map, gt_doc.
    parse_blueprint( ).

  ENDMETHOD.


  METHOD bo_json.

*   Only blueprint fields, under the API's own names, typed as the
*   blueprint types them. The engine hands over the whole flattened model
*   in upper case; posting that verbatim sends PARTY_EMAIL to a business
*   object that has never heard of it.
    blueprint( ).

    IF gt_map IS INITIAL.
      rv_json = '{}'.
      RETURN.
    ENDIF.

    DATA lv_body TYPE string.

    LOOP AT gt_map INTO DATA(ls_m).

      DATA(lv_val) = field( it_fields = it_fields iv_name = ls_m-upper ).
      IF lv_val IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_pair TYPE string.
      IF ls_m-num = abap_true AND lv_val CO '0123456789.-' AND lv_val IS NOT INITIAL.
        lv_pair = |"{ ls_m-json }":{ lv_val }|.
      ELSE.
        lv_pair = |"{ ls_m-json }":"{ esc( lv_val ) }"|.
      ENDIF.

      lv_body = COND #( WHEN lv_body IS INITIAL THEN lv_pair ELSE |{ lv_body },{ lv_pair }| ).

    ENDLOOP.

    rv_json = |\{{ lv_body }\}|.

  ENDMETHOD.


  METHOD company_json.

    TYPES: BEGIN OF ty_addr, house_number TYPE string, street TYPE string, city TYPE string,
             region TYPE string, country TYPE string, zip_code TYPE string, END OF ty_addr,
           BEGIN OF ty_cont, phone_code TYPE string, phone_number TYPE string,
             mobile_code TYPE string, mobile_number TYPE string, email TYPE string, END OF ty_cont,
           BEGIN OF ty_cinf,
             last_name TYPE string, english_first_name TYPE string, arabic_first_name TYPE string,
             english_full_name TYPE string, arabic_full_name TYPE string,
             trade_license_number TYPE string, trade_license_expire_date TYPE string,
             trade_license_start_date TYPE string, registration_number TYPE string, END OF ty_cinf,
           BEGIN OF ty_cbpi,
             business_partner_id TYPE string,
             address_info TYPE ty_addr, contact_info TYPE ty_cont, company_info TYPE ty_cinf, END OF ty_cbpi,
           BEGIN OF ty_root,
             cbp_info     TYPE ty_cbpi,
             first_party  TYPE abap_bool,
             second_party TYPE abap_bool,
           END OF ty_root.

    DATA(ls_cbpi) = VALUE ty_cbpi(
      business_partner_id = field( it_fields = it_fields iv_name = 'bpId' )
      address_info = VALUE #(
        house_number = field( it_fields = it_fields iv_name = 'party_homeNumber' )
        street       = field( it_fields = it_fields iv_name = 'party_streetName' )
        city         = field( it_fields = it_fields iv_name = 'party_livingCity' )
        region       = field( it_fields = it_fields iv_name = 'party_region' )
        country      = field( it_fields = it_fields iv_name = 'party_livingCountry' )
        zip_code     = field( it_fields = it_fields iv_name = 'party_zipCode' ) )
      contact_info = VALUE #(
        phone_code    = field( it_fields = it_fields iv_name = 'party_phoneCode' )
        phone_number  = field( it_fields = it_fields iv_name = 'party_phoneNumber' )
        mobile_code   = field( it_fields = it_fields iv_name = 'party_mobileCode' )
        mobile_number = field( it_fields = it_fields iv_name = 'party_mobileNumber' )
        email         = field( it_fields = it_fields iv_name = 'party_email' ) )
      company_info = VALUE #(
        english_first_name        = field( it_fields = it_fields iv_name = 'party_companyNameEn' )
        arabic_first_name         = field( it_fields = it_fields iv_name = 'party_companyNameAr' )
        english_full_name         = field( it_fields = it_fields iv_name = 'party_companyNameEn' )
        arabic_full_name          = field( it_fields = it_fields iv_name = 'party_companyNameAr' )
        trade_license_number      = field( it_fields = it_fields iv_name = 'party_tradeLicenseNumber' )
        trade_license_expire_date = field( it_fields = it_fields iv_name = 'party_tradeLicenseExpireDate' )
        trade_license_start_date  = field( it_fields = it_fields iv_name = 'party_tradeLicenseStartDate' )
        registration_number       = field( it_fields = it_fields iv_name = 'party_registrationNumber' ) ) ).

    DATA(ls_root) = VALUE ty_root(
      cbp_info     = ls_cbpi
      first_party  = iv_first
      second_party = xsdbool( iv_first = abap_false ) ).

    rv_json = /ui2/cl_json=>serialize(
      data          = ls_root
      compress      = abap_true
      pretty_name   = /ui2/cl_json=>pretty_mode-camel_case
      name_mappings = VALUE #( ( abap = 'CBP_INFO' json = 'companyBusinessPartnerInfo' ) ) ).

  ENDMETHOD.


  METHOD constructor.
    mv_subservice = iv_subservice.
    mv_loginbp    = iv_loginbp.
    mv_userdata   = iv_userdata.
  ENDMETHOD.


  METHOD doc_types.
    blueprint( ).
    rt_doc = gt_doc.
  ENDMETHOD.


  METHOD dyn_list_for.

*   Matched on the name the blueprint gives the field. Longest / most
*   specific patterns first: LIVINGCOUNTRY must not be caught by COUNTRY's
*   test after CITY has already claimed LIVINGCITY, and NATIONALITY must be
*   tested before COUNTRY because some blueprints name it NATIONALITYCOUNTRY.
    DATA(lv_n) = to_upper( iv_name ).

    CLEAR ev_dependent.

*   SUBSERVICE and MAINSERVICE are tested FIRST, and the order is the whole
*   point: 'SUBSERVICE' contains 'SERVICE', and 'MAINSERVICE' would also be
*   caught by a plain 'SERVICE' test - but more importantly CLASSIFICATION's
*   own test must not claim a field called SUBSERVICE_CLASSIFICATION. Both
*   are dependent: neither list means anything until its parent is chosen.
    IF lv_n CS 'SUBSERVICE'.
      rv_list      = 'SUBSERVICE'.
      ev_dependent = abap_true.
    ELSEIF lv_n CS 'MAINSERVICE'.
      rv_list      = 'MAINSERVICE'.
      ev_dependent = abap_true.
    ELSEIF lv_n CS 'NATIONALITY'.
      rv_list = 'NATIONALITY'.
    ELSEIF lv_n CS 'OCCUPATION' OR lv_n CS 'PROFESSION' OR lv_n CS 'JOB'.
      rv_list = 'OCCUPATION'.
    ELSEIF lv_n CS 'CLASSIFICATION'.
      rv_list = 'CLASSIFICATION'.
    ELSEIF lv_n CS 'CITY'.
      rv_list       = 'CITY'.
      ev_dependent  = abap_true.
    ELSEIF lv_n CS 'REGION' OR lv_n CS 'EMIRATE' OR lv_n CS 'STATE'.
      rv_list       = 'REGION'.
      ev_dependent  = abap_true.
    ELSEIF lv_n CS 'COUNTRY'.
      rv_list = 'COUNTRY'.
    ENDIF.

  ENDMETHOD.


  METHOD ensure_token.
    IF cs_handle-token IS NOT INITIAL.
      gv_token = cs_handle-token.
      RETURN.
    ENDIF.
    authenticate( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
  ENDMETHOD.


  METHOD esc.
    rv_out = iv_in.
    REPLACE ALL OCCURRENCES OF '\' IN rv_out WITH '\\'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_out WITH '\"'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN rv_out WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN rv_out WITH '\n'.
  ENDMETHOD.


  METHOD field.
    rv_value = VALUE #( it_fields[ name = to_upper( iv_name ) ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD json_scalar.

    DATA lv_off TYPE i.
    DATA lv_pos TYPE i.
    DATA lv_end TYPE i.
    DATA lv_st  TYPE i.
    DATA lv_len TYPE i.

    DATA(lv_pat) = |"{ iv_key }"|.

    FIND FIRST OCCURRENCE OF lv_pat IN iv_json MATCH OFFSET lv_off.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    lv_pos = lv_off + strlen( lv_pat ).
    lv_end = strlen( iv_json ).

    WHILE lv_pos < lv_end
      AND ( iv_json+lv_pos(1) = ` ` OR iv_json+lv_pos(1) = ':' ).
      lv_pos = lv_pos + 1.
    ENDWHILE.

    IF lv_pos >= lv_end.
      RETURN.
    ENDIF.

    IF iv_json+lv_pos(1) = '"'.
      lv_pos = lv_pos + 1.
      lv_st  = lv_pos.
      WHILE lv_pos < lv_end AND iv_json+lv_pos(1) <> '"'.
        lv_pos = lv_pos + 1.
      ENDWHILE.
    ELSE.
      lv_st = lv_pos.
      WHILE lv_pos < lv_end
        AND iv_json+lv_pos(1) <> ','
        AND iv_json+lv_pos(1) <> '}'
        AND iv_json+lv_pos(1) <> ']'.
        lv_pos = lv_pos + 1.
      ENDWHILE.
    ENDIF.

    lv_len = lv_pos - lv_st.
    IF lv_len > 0.
      rv = iv_json+lv_st(lv_len).
      CONDENSE rv.
    ENDIF.

  ENDMETHOD.


  METHOD parties.

    IF iv_request_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/party' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}/party'
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = VALUE #( ( name = '{reqId}' value = iv_request_id ) )
      IMPORTING
        ev_status      = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/party' iv_status = lv_status iv_resp = lv_resp ).

    IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_false.
      RETURN.
    ENDIF.

*   Tolerant about the wrapper, the same way every other read in this class is.
*   The draft response calls the party block firstPartyDetails; the list read
*   answers with result / parties / partyDetails depending on the endpoint, and
*   guessing one of them and being wrong is a silent empty table.
*   The name, the id and the kind each arrive under more than one key
*   depending on which endpoint answered, so every spelling seen so far is
*   declared and the first filled one wins below. A key that never arrives
*   simply stays empty - that is cheaper than a wrong guess, which shows the
*   citizen a blank view dialog with no way to tell why.
    TYPES: BEGIN OF ty_p,
             party_id            TYPE string,
             party_name          TYPE string,
             party_name_en       TYPE string,
             party_name_ar       TYPE string,
             english_name        TYPE string,
             arabic_name         TYPE string,
             mobile_number       TYPE string,
             mobile              TYPE string,
             email               TYPE string,
             email_address       TYPE string,
             id_number           TYPE string,
             eid                 TYPE string,
             passport_number     TYPE string,
             unified_number      TYPE string,
             trade_license_number TYPE string,
             party_kind          TYPE string,
             party_type          TYPE string,
             nationality_en TYPE string,
             nationality_an TYPE string,
             first_party    TYPE abap_bool,
             second_party   TYPE abap_bool,
           END OF ty_p,
           tt_p TYPE STANDARD TABLE OF ty_p WITH EMPTY KEY,
           BEGIN OF ty_w,
             result         TYPE tt_p,
             parties        TYPE tt_p,
             party_details  TYPE tt_p,
             party          TYPE tt_p,
           END OF ty_w.

    DATA ls_w TYPE ty_w.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_w ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(lt_p) = COND tt_p( WHEN ls_w-result        IS NOT INITIAL THEN ls_w-result
                            WHEN ls_w-parties       IS NOT INITIAL THEN ls_w-parties
                            WHEN ls_w-party_details IS NOT INITIAL THEN ls_w-party_details
                            ELSE ls_w-party ).

    LOOP AT lt_p INTO DATA(ls_p).
      APPEND VALUE #( party_id     = ls_p-party_id
                      party_name   = COND string( WHEN ls_p-party_name    IS NOT INITIAL THEN ls_p-party_name
                                                  WHEN ls_p-party_name_en IS NOT INITIAL THEN ls_p-party_name_en
                                                  ELSE ls_p-english_name )
                      name_ar      = COND string( WHEN ls_p-party_name_ar IS NOT INITIAL THEN ls_p-party_name_ar
                                                  ELSE ls_p-arabic_name )
                      mobile       = COND string( WHEN ls_p-mobile_number IS NOT INITIAL THEN ls_p-mobile_number
                                                  ELSE ls_p-mobile )
                      email        = COND string( WHEN ls_p-email IS NOT INITIAL THEN ls_p-email
                                                  ELSE ls_p-email_address )
                      nationality  = COND string( WHEN ls_p-nationality_en IS NOT INITIAL
                                                  THEN ls_p-nationality_en
                                                  ELSE ls_p-nationality_an )
                      id_number    = COND string( WHEN ls_p-id_number            IS NOT INITIAL THEN ls_p-id_number
                                                  WHEN ls_p-eid                  IS NOT INITIAL THEN ls_p-eid
                                                  WHEN ls_p-passport_number      IS NOT INITIAL THEN ls_p-passport_number
                                                  WHEN ls_p-unified_number       IS NOT INITIAL THEN ls_p-unified_number
                                                  ELSE ls_p-trade_license_number )
                      party_kind   = COND string( WHEN ls_p-party_kind IS NOT INITIAL THEN ls_p-party_kind
                                                  ELSE ls_p-party_type )
                      first_party  = ls_p-first_party
                      second_party = ls_p-second_party ) TO rt.
    ENDLOOP.

    zcl_rak_not_trace=>add( |PARTIES { lines( rt ) } on request { iv_request_id }| ).

  ENDMETHOD.


  METHOD legal_text.

    IF iv_request_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/legaltext' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}/legaltext'
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = VALUE #( ( name = '{reqId}' value = iv_request_id ) )
      IMPORTING
        ev_status      = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/legaltext' iv_status = lv_status iv_resp = lv_resp ).

    IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_false.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_lt, arabic_legal_text TYPE string, english_legal_text TYPE string, END OF ty_lt,
           BEGIN OF ty_w, legal_text TYPE ty_lt, result TYPE ty_lt,
                          arabic_legal_text TYPE string, END OF ty_w.
    DATA ls_w TYPE ty_w.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_w ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    rv_text = COND string(
      WHEN ls_w-legal_text-arabic_legal_text IS NOT INITIAL THEN ls_w-legal_text-arabic_legal_text
      WHEN ls_w-result-arabic_legal_text     IS NOT INITIAL THEN ls_w-result-arabic_legal_text
      ELSE ls_w-arabic_legal_text ).

  ENDMETHOD.


  METHOD lookup.

    DATA(lv_key) = |{ to_upper( iv_list ) }#{ iv_arg1 }#{ iv_arg2 }|.
    READ TABLE gt_lk INTO DATA(ls_c) WITH KEY key = lv_key.
    IF sy-subrc = 0.
*     Said out loud, because a cache hit made no HTTP call and the trace then
*     reported "NO Notary API call was made on this interaction" directly above
*     a dropdown that was visibly full. Both true, and together they read as a
*     contradiction - a populated list with no call looks like the call failed
*     and something else supplied the data.
      zcl_rak_not_trace=>add( |LOOKUP { to_upper( iv_list ) } served from cache | &&
                              |({ lines( ls_c-opts ) } option(s), no call needed)| ).
      rt_opt = ls_c-opts.
      RETURN.
    ENDIF.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_path TYPE string.
    DATA lt_rep  TYPE tihttpnvp.

    CASE to_upper( iv_list ).
      WHEN 'NATIONALITY'.
        lv_path = '/static/nationalities'.
      WHEN 'OCCUPATION'.
        lv_path = '/static/occupation'.
      WHEN 'COUNTRY'.
        lv_path = '/static/countries'.
      WHEN 'CLASSIFICATION'.
        lv_path = '/classifications'.

*     The declaration list. Without this the Sub Service dropdown on the
*     first step renders EMPTY - and since everything downstream is derived
*     from the declaration, the citizen cannot start at all.
*
*     classfication_Id is spelt exactly as the API spells it. The 'i' is
*     missing in the collection's own URL
*     (/subservice/?classfication_Id=27&applicant_type_id=1&mainService_Id=1)
*     and correcting it here would simply not filter.
*
*     applicant_type_id is fixed at 1. The call settled this: "the individual
*     all have the same permissions... usually, for the individual, all have
*     the same role", and the printing-office difference is extra fields on
*     the first-party call, not a different service list. Q3 in the
*     clarification document asks which applicant categories are in scope; if
*     the answer turns out to be more than one, this is where it becomes an
*     argument.
      WHEN 'SUBSERVICE'.
        IF iv_arg1 IS INITIAL OR iv_arg2 IS INITIAL.
*         No classification or main service yet, so there is nothing to
*         filter by. Same reasoning as CITY: an unfiltered list is worse
*         than none. Said out loud, because an empty declaration dropdown
*         with no call behind it is otherwise indistinguishable from a
*         wrong endpoint.
          zcl_rak_not_trace=>add( |LOOKUP SUBSERVICE skipped - classification | &&
            |'{ iv_arg1 }' / main service '{ iv_arg2 }', one of them is empty| ).
          RETURN.
        ENDIF.
        lv_path = '/subservice/?classfication_Id={c}&applicant_type_id=1&mainService_Id={m}'.
        lt_rep  = VALUE #( ( name = '{c}' value = iv_arg1 )
                           ( name = '{m}' value = iv_arg2 ) ).

      WHEN 'MAINSERVICE'.
        IF iv_arg1 IS INITIAL.
          RETURN.
        ENDIF.
        lv_path = '/mainservice/?classfication_Id={c}&applicant_type_id=1'.
        lt_rep  = VALUE #( ( name = '{c}' value = iv_arg1 ) ).
      WHEN 'REGION'.
        IF iv_arg1 IS NOT INITIAL.
          lv_path = '/static/regionbycountry/{c}'.
          lt_rep  = VALUE #( ( name = '{c}' value = iv_arg1 ) ).
        ELSE.
          lv_path = '/static/region'.
        ENDIF.
      WHEN 'CITY'.
        IF iv_arg1 IS NOT INITIAL AND iv_arg2 IS NOT INITIAL.
          lv_path = '/static/{c}/cities/{r}'.
          lt_rep  = VALUE #( ( name = '{c}' value = iv_arg1 )
                             ( name = '{r}' value = iv_arg2 ) ).
        ELSE.
*         No country/region chosen yet. An empty list is the honest answer:
*         the full city table is thousands of rows and means nothing until
*         the citizen has picked a region.
          RETURN.
        ENDIF.
      WHEN OTHERS.
*       A list name this method has no endpoint for. DYN_LIST_FOR( ) and this
*       CASE have to agree, and when they drift the symptom is an empty
*       dropdown and no HTTP call - which reads as a network problem.
        zcl_rak_not_trace=>add( |LOOKUP no endpoint for list '{ to_upper( iv_list ) }'| ).
        RETURN.
    ENDCASE.

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = lv_path ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = lv_path
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = lt_rep
      IMPORTING
        ev_status      = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = lv_path iv_status = lv_status iv_resp = lv_resp ).

    IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
      rt_opt = to_options( lv_resp ).
    ENDIF.

*   Cached even when empty, so a list the API cannot answer is asked for
*   once per round trip and not once per dropdown on the screen.
    APPEND VALUE #( key = lv_key opts = rt_opt ) TO gt_lk.

  ENDMETHOD.


  METHOD msg.
    APPEND VALUE bapiret2( type = iv_type id = 'ZCJS' number = '000' message = iv_text )
           TO ct_return.
  ENDMETHOD.


  METHOD now_ts.
    rv_ts = |{ today( ) } { sy-uzeit+0(2) }:{ sy-uzeit+2(2) }:{ sy-uzeit+4(2) }.000|.
  ENDMETHOD.


  METHOD ok_of.

    CLEAR: ev_code, ev_msg.
    rv_ok = abap_false.

    ev_code = json_scalar( iv_json = iv_resp iv_key = 'notaryCode' ).
    DATA(lv_desc) = json_scalar( iv_json = iv_resp iv_key = 'notaryDescription' ).
    DATA(lv_stat) = json_scalar( iv_json = iv_resp iv_key = 'statusCode' ).
    DATA(lv_rmsg) = to_upper( json_scalar( iv_json = iv_resp iv_key = 'respMessage' ) ).

    IF lv_desc IS INITIAL.
      lv_desc = json_scalar( iv_json = iv_resp iv_key = 'respMessageDetail' ).
    ENDIF.

    IF iv_status <> 200 AND iv_status <> 201.
      ev_msg = COND string( WHEN lv_desc IS NOT INITIAL
                            THEN |HTTP { iv_status } - { lv_desc }|
                            ELSE |HTTP { iv_status }| ).
      RETURN.
    ENDIF.

    IF lv_stat IS NOT INITIAL.
      IF lv_stat = '200' OR lv_stat = '201' OR lv_stat = '202' OR lv_stat = '204'.
        rv_ok = abap_true.
      ELSE.
        ev_msg = COND string( WHEN lv_desc IS NOT INITIAL
                              THEN lv_desc
                              ELSE |Notary statusCode { lv_stat }| ).
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_rmsg = 'SUCCESS' OR lv_rmsg = 'CREATED' OR lv_rmsg = 'OK'.
      rv_ok = abap_true.
      RETURN.
    ENDIF.

    IF ev_code IS INITIAL OR ev_code = '0' OR ev_code = 'null'.
      rv_ok = abap_true.
      RETURN.
    ENDIF.

    ev_msg = COND string( WHEN lv_desc IS NOT INITIAL
                          THEN lv_desc
                          ELSE |Notary code { ev_code }| ).

  ENDMETHOD.


  METHOD model_name.

*   A blueprint key, turned into something that can be an ABAP structure
*   component. It is not cosmetic: BUILD_MODEL( ) calls
*   CL_ABAP_STRUCTDESCR=>CREATE( ) with one component per field name, and a
*   component name is capped at 30 characters. A blueprint carrying
*
*     "jsonKey":"ministryOfEconomyRegistrationNumber"      (35)
*
*   raised CX_SY_STRUCT_COMP_NAME - uncaught, so the whole app died with
*   "UNCAUGHT EXCEPTION - Please Restart App" on choosing that declaration.
*   Nothing in the journey could have prevented it: the name comes from the
*   API, at runtime, and no configuration is involved.
*
*   THE API KEY IS NOT TOUCHED. Only GT_MAP-UPPER - the name the MODEL uses -
*   is shortened; GT_MAP-JSON keeps the blueprint's own key and that is what
*   BO_JSON( ) posts. The two were already separate fields for exactly this
*   kind of reason.
    DATA(lv) = to_upper( condense( iv_key ) ).

*   Anything that is not a letter, a digit or an underscore cannot be in a
*   component name either. A jsonKey is free text on the wire, so this is not
*   hypothetical - a dot or a dash would raise the same exception with a
*   different message.
    DATA lv_out TYPE string.
    DATA lv_i   TYPE i.
    CONSTANTS lc_ok TYPE string
      VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.

    WHILE lv_i < strlen( lv ).
      DATA(lv_c) = lv+lv_i(1).
      IF lc_ok CS lv_c.
        lv_out = lv_out && lv_c.
      ELSE.
        lv_out = lv_out && '_'.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

*   A component name cannot start with a digit.
    IF lv_out IS NOT INITIAL AND lv_out(1) CO '0123456789'.
      lv_out = |F{ lv_out }|.
    ENDIF.

*   23, NOT 30, and the difference is the whole of the second failure here.
*   BUILD_MODEL( ) does not create ONE component per field - it creates the field
*   and then its companions, each a suffix on the same name:
*
*     <NAME>_VS      value state          <NAME>_NAME    resolved partner name
*     <NAME>_VST     value state text     <NAME>_IX      row index
*     <NAME>_IDTYPE  ID type on a SEARCH  <NAME>_EXP     expanded flag
*
*   So a base name of exactly 30 is not safe, it is guaranteed to fail on the
*   NEXT line: MINISTRYOFECONOMYREGISTRA_6666 fitted, and _VS took it to 33.
*   _IDTYPE is the longest suffix at seven characters, so the base has to stop
*   at 23 for every companion to fit inside 30 as well.
    IF strlen( lv_out ) <= 23.
      rv = lv_out.
      RETURN.
    ENDIF.

*   Too long, so 18 characters of the name and a four-digit fingerprint of the
*   WHOLE key - 23 in total, leaving room for _IDTYPE. The fingerprint is what
*   stops two keys that share their first 18 characters collapsing onto one
*   component, which would be worse than the dump: the two fields would then
*   silently share a value.
*
*   Computed from the key ALONE and never from its position in the blueprint.
*   PARSE_BLUEPRINT( ) and DESCRIBE_STEP( ) walk the field list separately and
*   must arrive at the same name independently; anything positional would agree
*   only for as long as both lists stayed in the same order, and would put
*   values on the wrong field the day they did not.
    DATA lv_h TYPE i.
    CLEAR lv_i.
    WHILE lv_i < strlen( lv_out ).
      DATA(lv_p) = find( val = lc_ok sub = lv_out+lv_i(1) ).
      IF lv_p < 0.
        lv_p = 0.
      ENDIF.
      lv_h = ( lv_h * 31 + lv_p + 1 ) MOD 100000.
      lv_i = lv_i + 1.
    ENDWHILE.

    rv = |{ lv_out(18) }_{ lv_h MOD 10000 WIDTH = 4 PAD = '0' ALIGN = RIGHT }|.

  ENDMETHOD.


  METHOD parse_blueprint.

*   CLEARED, not appended to. GT_MAP and GT_DOC are CLASS-DATA and this method
*   only ever APPENDed, so choosing a second declaration in the same session
*   left the first one's business-object fields and documents in the table.
*   BO_JSON( ) walks GT_MAP, so the request would have carried fields the new
*   declaration has never heard of.
    CLEAR: gt_map, gt_doc.

*   ------------------------------------------------------------------
*   The blueprint's exact shape is Q4 in the clarification document and
*   is not yet answered, so this parser is deliberately shape-tolerant
*   rather than shape-guessing. /ui2/cl_json ignores JSON keys it has no
*   component for and leaves components it finds no key for initial, so
*   declaring every plausible spelling costs nothing and the first
*   non-empty one wins. When Notary answers Q4, delete the alternatives
*   that turned out not to exist - nothing else has to change.
*   ------------------------------------------------------------------
    TYPES: BEGIN OF ty_o,
             key         TYPE string, value TYPE string, id    TYPE string, code TYPE string,
             text        TYPE string, name  TYPE string, name_ar TYPE string,
             description TYPE string,
           END OF ty_o,
           tt_o TYPE STANDARD TABLE OF ty_o WITH EMPTY KEY.

    TYPES: BEGIN OF ty_f,
*            This parser already looked under businessFields, but could not
*            name what it found: the blueprint gives each field its technical
*            key as jsonKey - caseIssuancePlace, caseNumber - and none of the
*            aliases below carry it, so every field fell out on the blank-name
*            CHECK. JSON_KEY and REG_EX are the two the live response uses.
             json_key       TYPE string,
             reg_ex         TYPE string,
             name           TYPE string,
             field_name     TYPE string,
             technical_name TYPE string,
             code           TYPE string,
             label          TYPE string,
             label_en       TYPE string,
             english_name   TYPE string,
             description    TYPE string,
             title          TYPE string,
             label_ar       TYPE string,
             arabic_name    TYPE string,
             type           TYPE string,
             data_type      TYPE string,
             field_type     TYPE string,
             control_type   TYPE string,
             mandatory      TYPE abap_bool,
             required       TYPE abap_bool,
             is_mandatory   TYPE abap_bool,
             max_length     TYPE i,
             length         TYPE i,
             options        TYPE tt_o,
             values         TYPE tt_o,
             lookup_values  TYPE tt_o,
             items          TYPE tt_o,
           END OF ty_f,
           tt_f TYPE STANDARD TABLE OF ty_f WITH EMPTY KEY.

    TYPES: BEGIN OF ty_d,
             attachment_id             TYPE string,
             attachment_conf_id        TYPE string,
             conf_id                   TYPE string,
             id                        TYPE string,
             document_id               TYPE string,
             english_title_of_document TYPE string,
             arabic_title_of_document  TYPE string,
             document_name             TYPE string,
             name                      TYPE string,
             document_name_ar          TYPE string,
             name_ar                   TYPE string,
             mandatory                 TYPE abap_bool,
             required                  TYPE abap_bool,
             is_mandatory              TYPE abap_bool,
             multiple                  TYPE abap_bool,
             valid_mime_types          TYPE string,
             extensions                TYPE string,
             allowed_extensions        TYPE string,
           END OF ty_d,
           tt_d TYPE STANDARD TABLE OF ty_d WITH EMPTY KEY.

    TYPES: BEGIN OF ty_lvl,
             business_fields        TYPE tt_f,
             business_object_fields TYPE tt_f,
             bo_fields              TYPE tt_f,
             fields                 TYPE tt_f,
             attributes             TYPE tt_f,
             blue_print             TYPE tt_f,
             service_fields         TYPE tt_f,
             attachment             TYPE tt_d,
             attachments            TYPE tt_d,
             documents              TYPE tt_d,
             required_documents     TYPE tt_d,
             attachment_conf        TYPE tt_d,
           END OF ty_lvl.

    TYPES: BEGIN OF ty_root,
             business_fields        TYPE tt_f,
             business_object_fields TYPE tt_f,
             bo_fields              TYPE tt_f,
             fields                 TYPE tt_f,
             attributes             TYPE tt_f,
             blue_print             TYPE tt_f,
             service_fields         TYPE tt_f,
             attachment             TYPE tt_d,
             attachments            TYPE tt_d,
             documents              TYPE tt_d,
             required_documents     TYPE tt_d,
             attachment_conf        TYPE tt_d,
             result                 TYPE ty_lvl,
             data                   TYPE ty_lvl,
             sub_service            TYPE ty_lvl,
             service_information    TYPE ty_lvl,
           END OF ty_root.

    DATA ls_r TYPE ty_root.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = gv_bp_json
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_r ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA lt_f TYPE tt_f.
    lt_f = COND #( WHEN ls_r-business_object_fields IS NOT INITIAL THEN ls_r-business_object_fields
                   WHEN ls_r-bo_fields              IS NOT INITIAL THEN ls_r-bo_fields
                   WHEN ls_r-fields                 IS NOT INITIAL THEN ls_r-fields
                   WHEN ls_r-attributes             IS NOT INITIAL THEN ls_r-attributes
                   WHEN ls_r-blue_print             IS NOT INITIAL THEN ls_r-blue_print
                   WHEN ls_r-service_fields         IS NOT INITIAL THEN ls_r-service_fields
                   WHEN ls_r-result-business_fields IS NOT INITIAL THEN ls_r-result-business_fields
                   WHEN ls_r-business_fields        IS NOT INITIAL THEN ls_r-business_fields
                   WHEN ls_r-result-business_fields IS NOT INITIAL THEN ls_r-result-business_fields
      WHEN ls_r-business_fields        IS NOT INITIAL THEN ls_r-business_fields
      WHEN ls_r-result-business_object_fields IS NOT INITIAL THEN ls_r-result-business_object_fields
                   WHEN ls_r-result-bo_fields       IS NOT INITIAL THEN ls_r-result-bo_fields
                   WHEN ls_r-result-fields          IS NOT INITIAL THEN ls_r-result-fields
                   WHEN ls_r-result-attributes      IS NOT INITIAL THEN ls_r-result-attributes
                   WHEN ls_r-result-blue_print      IS NOT INITIAL THEN ls_r-result-blue_print
                   WHEN ls_r-data-business_object_fields   IS NOT INITIAL THEN ls_r-data-business_object_fields
                   WHEN ls_r-data-fields            IS NOT INITIAL THEN ls_r-data-fields
                   WHEN ls_r-sub_service-fields     IS NOT INITIAL THEN ls_r-sub_service-fields
                   WHEN ls_r-sub_service-business_object_fields IS NOT INITIAL THEN ls_r-sub_service-business_object_fields
                   WHEN ls_r-service_information-fields IS NOT INITIAL THEN ls_r-service_information-fields
                   ELSE VALUE #( ) ).

    LOOP AT lt_f INTO DATA(ls_f).

      DATA(lv_name) = COND string( WHEN ls_f-json_key       IS NOT INITIAL THEN ls_f-json_key
                                   WHEN ls_f-name           IS NOT INITIAL THEN ls_f-name
                                   WHEN ls_f-field_name     IS NOT INITIAL THEN ls_f-field_name
                                   WHEN ls_f-technical_name IS NOT INITIAL THEN ls_f-technical_name
                                   ELSE ls_f-code ).
      IF lv_name IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lt_opt) = COND tt_o( WHEN ls_f-options       IS NOT INITIAL THEN ls_f-options
                                WHEN ls_f-values        IS NOT INITIAL THEN ls_f-values
                                WHEN ls_f-lookup_values IS NOT INITIAL THEN ls_f-lookup_values
                                ELSE ls_f-items ).

      DATA(lv_raw) = to_upper( COND string( WHEN ls_f-type         IS NOT INITIAL THEN ls_f-type
                                            WHEN ls_f-data_type    IS NOT INITIAL THEN ls_f-data_type
                                            WHEN ls_f-field_type   IS NOT INITIAL THEN ls_f-field_type
                                            ELSE ls_f-control_type ) ).

      DATA(lv_type) = COND string(
        WHEN lt_opt IS NOT INITIAL          THEN 'SELECT'
        WHEN lv_raw CS 'DATE'               THEN 'DATE'
        WHEN lv_raw CS 'TEXTAREA'
          OR lv_raw CS 'LONGTEXT'           THEN 'TEXTAREA'
        WHEN lv_raw CS 'NUM' OR lv_raw CS 'DEC'
          OR lv_raw CS 'INT' OR lv_raw CS 'AMOUNT'
          OR lv_raw CS 'DOUBLE' OR lv_raw CS 'FLOAT' THEN 'NUMBER'
        ELSE 'INPUT' ).

*     Numeric on the wire when the blueprint says numeric, or when every
*     option key is a number - caseType: 1 in the collection, not "1".
      DATA(lv_num) = xsdbool( lv_type = 'NUMBER' ).
      IF lv_type = 'SELECT'.
        DATA(lv_allnum) = abap_true.
        LOOP AT lt_opt INTO DATA(ls_ck).
          DATA(lv_k) = COND string( WHEN ls_ck-key   IS NOT INITIAL THEN ls_ck-key
                                    WHEN ls_ck-id    IS NOT INITIAL THEN ls_ck-id
                                    WHEN ls_ck-code  IS NOT INITIAL THEN ls_ck-code
                                    ELSE ls_ck-value ).
          IF lv_k IS INITIAL OR lv_k CN '0123456789'.
            lv_allnum = abap_false.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lt_opt IS NOT INITIAL.
          lv_num = lv_allnum.
        ENDIF.
      ENDIF.

*     UPPER is what the MODEL calls the field and JSON is what the API calls
*     it. They were always two fields; until now they always held the same text,
*     which is why a key too long to be a component had nowhere to be shortened.
      APPEND VALUE #( upper = model_name( lv_name ) json = lv_name num = lv_num ) TO gt_map.

    ENDLOOP.

*   ---- documents -------------------------------------------------------
    DATA(lt_d) = COND tt_d( WHEN ls_r-result-attachment IS NOT INITIAL THEN ls_r-result-attachment
                            WHEN ls_r-attachment        IS NOT INITIAL THEN ls_r-attachment
                            WHEN ls_r-attachments        IS NOT INITIAL THEN ls_r-attachments
                            WHEN ls_r-documents          IS NOT INITIAL THEN ls_r-documents
                            WHEN ls_r-required_documents IS NOT INITIAL THEN ls_r-required_documents
                            WHEN ls_r-attachment_conf    IS NOT INITIAL THEN ls_r-attachment_conf
                            WHEN ls_r-result-attachments IS NOT INITIAL THEN ls_r-result-attachments
                            WHEN ls_r-result-documents   IS NOT INITIAL THEN ls_r-result-documents
                            WHEN ls_r-result-required_documents IS NOT INITIAL THEN ls_r-result-required_documents
                            WHEN ls_r-result-attachment_conf    IS NOT INITIAL THEN ls_r-result-attachment_conf
                            WHEN ls_r-data-documents     IS NOT INITIAL THEN ls_r-data-documents
                            WHEN ls_r-sub_service-documents IS NOT INITIAL THEN ls_r-sub_service-documents
                            ELSE VALUE #( ) ).

    LOOP AT lt_d INTO DATA(ls_d).
      APPEND VALUE #(
        conf_id   = COND string( WHEN ls_d-attachment_id      IS NOT INITIAL THEN ls_d-attachment_id
                                 WHEN ls_d-attachment_conf_id IS NOT INITIAL THEN ls_d-attachment_conf_id
                                 WHEN ls_d-conf_id            IS NOT INITIAL THEN ls_d-conf_id
                                 WHEN ls_d-document_id        IS NOT INITIAL THEN ls_d-document_id
                                 ELSE ls_d-id )
        name      = COND string( WHEN ls_d-english_title_of_document IS NOT INITIAL THEN ls_d-english_title_of_document
                                 WHEN ls_d-document_name IS NOT INITIAL THEN ls_d-document_name
                                 ELSE ls_d-name )
        name_ar   = COND string( WHEN ls_d-arabic_title_of_document IS NOT INITIAL THEN ls_d-arabic_title_of_document
                                 WHEN ls_d-document_name_ar IS NOT INITIAL THEN ls_d-document_name_ar
                                 ELSE ls_d-name_ar )
        required  = COND abap_bool( WHEN ls_d-mandatory = abap_true OR ls_d-required = abap_true
                                      OR ls_d-is_mandatory = abap_true THEN abap_true ELSE abap_false )
        extension = COND string( WHEN ls_d-extensions IS NOT INITIAL THEN ls_d-extensions
                                 WHEN ls_d-allowed_extensions IS NOT INITIAL THEN ls_d-allowed_extensions
                                 ELSE ls_d-valid_mime_types ) ) TO gt_doc.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_party.

    IF iv_response IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_nm, first_name TYPE string, last_name TYPE string, father_name TYPE string,
             grand_father_name TYPE string, fourth_name TYPE string,
             arabic_full_name TYPE string, english_full_name TYPE string, END OF ty_nm,
           BEGIN OF ty_pi, nation TYPE string, gender TYPE string, dob TYPE string,
             occupation TYPE string, END OF ty_pi,
           BEGIN OF ty_ai, country TYPE string, city TYPE string, region TYPE string,
             house_number TYPE string, street TYPE string, END OF ty_ai,
           BEGIN OF ty_ci, mobile_number TYPE string, email TYPE string, END OF ty_ci,
           BEGIN OF ty_ei, emirates_id TYPE string, emirates_id_valid_to TYPE string, END OF ty_ei,
           BEGIN OF ty_pp, passport_id TYPE string, passport_country TYPE string,
             passport_date_to TYPE string, END OF ty_pp,
           BEGIN OF ty_r,
             business_partner_id TYPE string,
             status              TYPE string,
             first_name          TYPE string,
             last_name           TYPE string,
             father_name         TYPE string,
             grand_father_name   TYPE string,
             fourth_name         TYPE string,
             nation              TYPE string,
             gender              TYPE string,
             dob                 TYPE string,
             occupation          TYPE string,
             mobile_number       TYPE string,
             email               TYPE string,
             name_info           TYPE ty_nm,
             personal_info       TYPE ty_pi,
             address_info        TYPE ty_ai,
             contact_info        TYPE ty_ci,
             eid_info            TYPE ty_ei,
             passport_info       TYPE ty_pp,
           END OF ty_r,
           BEGIN OF ty_w, result TYPE ty_r, END OF ty_w.

    DATA ls_w TYPE ty_w.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = iv_response
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_w ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(ls_r) = ls_w-result.

*   Flat or nested, whichever the response used.
    DATA(lt) = VALUE zif_rak_journey_backend=>tt_field(
      ( name = 'PARTY_FIRSTNAME'       value = COND #( WHEN ls_r-name_info-first_name IS NOT INITIAL THEN ls_r-name_info-first_name ELSE ls_r-first_name ) )
      ( name = 'PARTY_LASTNAME'        value = COND #( WHEN ls_r-name_info-last_name IS NOT INITIAL THEN ls_r-name_info-last_name ELSE ls_r-last_name ) )
      ( name = 'PARTY_FATHERNAME'      value = COND #( WHEN ls_r-name_info-father_name IS NOT INITIAL THEN ls_r-name_info-father_name ELSE ls_r-father_name ) )
      ( name = 'PARTY_GRANDFATHERNAME' value = COND #( WHEN ls_r-name_info-grand_father_name IS NOT INITIAL THEN ls_r-name_info-grand_father_name ELSE ls_r-grand_father_name ) )
      ( name = 'PARTY_FOURTHNAME'      value = COND #( WHEN ls_r-name_info-fourth_name IS NOT INITIAL THEN ls_r-name_info-fourth_name ELSE ls_r-fourth_name ) )
      ( name = 'PARTY_NATIONALITY'     value = COND #( WHEN ls_r-personal_info-nation IS NOT INITIAL THEN ls_r-personal_info-nation ELSE ls_r-nation ) )
      ( name = 'GENDER'                value = COND #( WHEN ls_r-personal_info-gender IS NOT INITIAL THEN ls_r-personal_info-gender ELSE ls_r-gender ) )
      ( name = 'PARTY_DOB'             value = COND #( WHEN ls_r-personal_info-dob IS NOT INITIAL THEN ls_r-personal_info-dob ELSE ls_r-dob ) )
      ( name = 'PARTY_JOBTEXT'         value = COND #( WHEN ls_r-personal_info-occupation IS NOT INITIAL THEN ls_r-personal_info-occupation ELSE ls_r-occupation ) )
      ( name = 'PARTY_MOBILENUMBER'    value = COND #( WHEN ls_r-contact_info-mobile_number IS NOT INITIAL THEN ls_r-contact_info-mobile_number ELSE ls_r-mobile_number ) )
      ( name = 'PARTY_EMAIL'           value = COND #( WHEN ls_r-contact_info-email IS NOT INITIAL THEN ls_r-contact_info-email ELSE ls_r-email ) )
      ( name = 'PARTY_LIVINGCOUNTRY'   value = ls_r-address_info-country )
      ( name = 'PARTY_REGION'          value = ls_r-address_info-region )
      ( name = 'PARTY_LIVINGCITY'      value = ls_r-address_info-city )
      ( name = 'PARTY_STREETNAME'      value = ls_r-address_info-street )
      ( name = 'PARTY_HOMENUMBER'      value = ls_r-address_info-house_number )
      ( name = 'PARTY_IDNUMBER'        value = ls_r-eid_info-emirates_id )
      ( name = 'PARTY_IDEXPIRYDT'      value = ls_r-eid_info-emirates_id_valid_to )
      ( name = 'PARTY_PASSPORTNUMBER'  value = ls_r-passport_info-passport_id )
      ( name = 'PARTY_ISSUECOUNTRY'    value = ls_r-passport_info-passport_country )
      ( name = 'PARTY_PASSPORTEXPIRYDT' value = ls_r-passport_info-passport_date_to )
*     The BP id is the whole point of searching: with it the add-party call
*     goes to .../party/{bpId} and Notary reuses the registered partner
*     instead of creating a duplicate.
      ( name = 'BPID'                  value = ls_r-business_partner_id )
      ( name = 'BPSTATUS'              value = ls_r-status ) ).

    LOOP AT lt INTO DATA(ls).
      IF ls-value IS NOT INITIAL.
        APPEND ls TO rt_fields.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD party_json.

    DATA(lv_is_company) = xsdbool(
      to_upper( field( it_fields = it_fields iv_name = 'party_partyKind' ) ) = 'COMPANY'
      OR field( it_fields = it_fields iv_name = 'party_tradeLicenseNumber' ) IS NOT INITIAL ).

    IF lv_is_company = abap_true.
      rv_json = company_json( it_fields = it_fields iv_first = iv_first ).
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_name, arabic_full_name TYPE string, english_full_name TYPE string,
             first_name TYPE string, last_name TYPE string, fourth_name TYPE string,
             father_name TYPE string, grand_father_name TYPE string, END OF ty_name,
           BEGIN OF ty_pers, nation TYPE string, gender TYPE string, dob TYPE string,
             qualification TYPE string, occupation TYPE string, birth_place TYPE string, END OF ty_pers,
           BEGIN OF ty_addr, country TYPE string, city TYPE string, region TYPE string,
             region_id TYPE string, city_id TYPE string, house_number TYPE string,
             street TYPE string, address TYPE string, END OF ty_addr,
           BEGIN OF ty_cont, phone_code TYPE string, phone_number TYPE string,
             mobile_code TYPE string, mobile_number TYPE string, email TYPE string, END OF ty_cont,
           BEGIN OF ty_eidi, emirates_id TYPE string, emirates_id_valid_from TYPE string,
             emirates_id_valid_to TYPE string, END OF ty_eidi,
           BEGIN OF ty_pasi, passport_id TYPE string, passport_country TYPE string,
             passport_date_from TYPE string, passport_date_to TYPE string, END OF ty_pasi,
           BEGIN OF ty_bpi,
             business_partner_id TYPE string, status TYPE string,
             name_info TYPE ty_name, personal_info TYPE ty_pers, address_info TYPE ty_addr,
             contact_info TYPE ty_cont, eid_info TYPE ty_eidi, passport_info TYPE ty_pasi, END OF ty_bpi,
           BEGIN OF ty_eidr, dob TYPE string, emirates_id TYPE string, nation TYPE string, END OF ty_eidr,
           BEGIN OF ty_root,
             bp_info      TYPE ty_bpi,
             first_party  TYPE abap_bool,
             second_party TYPE abap_bool,
             eid          TYPE ty_eidr,
           END OF ty_root.

    DATA(lv_first_name) = field( it_fields = it_fields iv_name = 'party_firstName' ).
    DATA(lv_last_name)  = field( it_fields = it_fields iv_name = 'party_lastName' ).

    DATA(ls_bpi) = VALUE ty_bpi(
      business_partner_id = field( it_fields = it_fields iv_name = 'bpId' )
      status              = COND string( WHEN field( it_fields = it_fields iv_name = 'bpStatus' ) IS NOT INITIAL
                                         THEN field( it_fields = it_fields iv_name = 'bpStatus' )
                                         ELSE 'Register' )
      name_info = VALUE #(
        first_name        = lv_first_name
        last_name         = lv_last_name
        fourth_name       = field( it_fields = it_fields iv_name = 'party_fourthName' )
        father_name       = field( it_fields = it_fields iv_name = 'party_fatherName' )
        grand_father_name = field( it_fields = it_fields iv_name = 'party_grandFatherName' )
*       Both full names are in the collection's body and both are read by
*       the officer's screen. Composed rather than asked for again.
        english_full_name = condense( |{ lv_first_name } { lv_last_name }| )
        arabic_full_name  = COND string( WHEN field( it_fields = it_fields iv_name = 'party_arabicFullName' ) IS NOT INITIAL
                                         THEN field( it_fields = it_fields iv_name = 'party_arabicFullName' )
                                         ELSE condense( |{ lv_first_name } { lv_last_name }| ) ) )
      personal_info = VALUE #(
        nation        = field( it_fields = it_fields iv_name = 'party_nationality' )
        gender        = field( it_fields = it_fields iv_name = 'gender' )
        dob           = field( it_fields = it_fields iv_name = 'party_dob' )
        qualification = field( it_fields = it_fields iv_name = 'party_qualification' )
        occupation    = field( it_fields = it_fields iv_name = 'party_jobText' )
        birth_place   = field( it_fields = it_fields iv_name = 'party_birthPlace' ) )
      address_info = VALUE #(
        country      = field( it_fields = it_fields iv_name = 'party_livingCountry' )
        city         = field( it_fields = it_fields iv_name = 'party_livingCity' )
        region       = field( it_fields = it_fields iv_name = 'party_region' )
        region_id    = field( it_fields = it_fields iv_name = 'party_region' )
        city_id      = field( it_fields = it_fields iv_name = 'party_livingCity' )
        house_number = field( it_fields = it_fields iv_name = 'party_homeNumber' )
        street       = field( it_fields = it_fields iv_name = 'party_streetName' ) )
      contact_info = VALUE #(
        phone_code    = field( it_fields = it_fields iv_name = 'party_phoneCode' )
        phone_number  = field( it_fields = it_fields iv_name = 'party_phoneNumber' )
        mobile_code   = field( it_fields = it_fields iv_name = 'party_mobileCode' )
        mobile_number = field( it_fields = it_fields iv_name = 'party_mobileNumber' )
        email         = field( it_fields = it_fields iv_name = 'party_email' ) )
      eid_info = VALUE #(
        emirates_id          = field( it_fields = it_fields iv_name = 'party_idNumber' )
        emirates_id_valid_to = field( it_fields = it_fields iv_name = 'party_idExpiryDt' ) )
      passport_info = VALUE #(
        passport_id        = field( it_fields = it_fields iv_name = 'party_passportNumber' )
        passport_country   = field( it_fields = it_fields iv_name = 'party_issueCountry' )
        passport_date_from = field( it_fields = it_fields iv_name = 'party_issueDt' )
        passport_date_to   = field( it_fields = it_fields iv_name = 'party_passportExpiryDt' ) ) ).

    DATA(ls_root) = VALUE ty_root(
      bp_info      = ls_bpi
      first_party  = iv_first
      second_party = xsdbool( iv_first = abap_false )
      eid          = VALUE #( emirates_id = field( it_fields = it_fields iv_name = 'party_idNumber' )
                              dob         = field( it_fields = it_fields iv_name = 'party_dob' )
                              nation      = field( it_fields = it_fields iv_name = 'party_nationality' ) ) ).

    rv_json = /ui2/cl_json=>serialize(
      data          = ls_root
      compress      = abap_true
      pretty_name   = /ui2/cl_json=>pretty_mode-camel_case
      name_mappings = VALUE #( ( abap = 'BP_INFO' json = 'indiviudalBusinessPartnerInfo' ) ) ).

  ENDMETHOD.


  METHOD payment_status.

    IF is_handle-request_id IS INITIAL OR is_handle-bdo IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    ls_h = is_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/transaction/{bdo}/status' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}/transaction/{bdo}/status'
        iv_method      = 'GET'
        it_headers     = auth_hdr( ls_h )
        it_url_replace = VALUE #( ( name = '{reqId}' value = is_handle-request_id )
                                  ( name = '{bdo}'   value = is_handle-bdo ) )
      IMPORTING
        ev_status      = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/transaction/{bdo}/status' iv_status = lv_status iv_resp = lv_resp ).

    IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_false.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_sr, status TYPE string, payment_status TYPE string, END OF ty_sr,
           BEGIN OF ty_sw, result TYPE ty_sr, status TYPE string, payment_status TYPE string, END OF ty_sw.
    DATA ls_sw TYPE ty_sw.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_sw ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    rv_status = to_upper( COND string(
      WHEN ls_sw-result-status         IS NOT INITIAL THEN ls_sw-result-status
      WHEN ls_sw-result-payment_status IS NOT INITIAL THEN ls_sw-result-payment_status
      WHEN ls_sw-status                IS NOT INITIAL THEN ls_sw-status
      ELSE ls_sw-payment_status ) ).

  ENDMETHOD.


  METHOD reauth.
    zcl_rak_not_trace=>add( 'token rejected - discarding cached token and re-authenticating' ).
    authenticate( EXPORTING iv_force  = abap_true
                  IMPORTING et_return = et_return
                  CHANGING  cs_handle = cs_handle ).
  ENDMETHOD.


  METHOD search_party.

    DATA lv_json TYPE string.

    TYPES: BEGIN OF ty_eid,  emirates_id TYPE string, dob TYPE string, nation TYPE string, END OF ty_eid,
           BEGIN OF ty_pass, passport_id TYPE string, passport_type TYPE string, dob TYPE string, nation TYPE string, END OF ty_pass,
             BEGIN OF ty_uid,  unified_number TYPE string, dob TYPE string, nation TYPE string, END OF ty_uid,
               BEGIN OF ty_comp, trade_license_number TYPE string, END OF ty_comp.

    CASE iv_search_type.
      WHEN 'IndividualbyEID'.
        TYPES: BEGIN OF ty_be, eid TYPE ty_eid, END OF ty_be.
        DATA(ls_be) = VALUE ty_be( eid = VALUE #(
          emirates_id = field( it_fields = it_fields iv_name = 'party_idNumber' )
          dob         = field( it_fields = it_fields iv_name = 'party_dob' )
          nation      = field( it_fields = it_fields iv_name = 'party_nationality' ) ) ).
        lv_json = /ui2/cl_json=>serialize( data        = ls_be
                                           compress    = abap_true
                                           pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN 'IndividualbyPassport' OR 'Individualbypassport'.
        TYPES: BEGIN OF ty_bp, passport TYPE ty_pass, END OF ty_bp.
        DATA(ls_bp) = VALUE ty_bp( passport = VALUE #(
          passport_id = field( it_fields = it_fields iv_name = 'party_passportNumber' )
          dob         = field( it_fields = it_fields iv_name = 'party_dob' )
          nation      = field( it_fields = it_fields iv_name = 'party_nationality' ) ) ).
        lv_json = /ui2/cl_json=>serialize( data        = ls_bp
                                           compress    = abap_true
                                           pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN 'CompanybyTL'.
        TYPES: BEGIN OF ty_bc, company TYPE ty_comp, END OF ty_bc.
        DATA(ls_bc) = VALUE ty_bc( company = VALUE #(
          trade_license_number = field( it_fields = it_fields iv_name = 'party_tradeLicenseNumber' ) ) ).
        lv_json = /ui2/cl_json=>serialize( data        = ls_bc
                                           compress    = abap_true
                                           pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

      WHEN OTHERS.
        TYPES: BEGIN OF ty_bu, uid TYPE ty_uid, END OF ty_bu.
        DATA(ls_bu) = VALUE ty_bu( uid = VALUE #(
          unified_number = field( it_fields = it_fields iv_name = 'party_unifiedNumber' )
          dob            = field( it_fields = it_fields iv_name = 'party_dob' )
          nation         = field( it_fields = it_fields iv_name = 'party_nationality' ) ) ).
        lv_json = /ui2/cl_json=>serialize( data        = ls_bu
                                           compress    = abap_true
                                           pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    ENDCASE.

    DATA ls_h TYPE zif_rak_journey_backend=>ty_handle.
    authenticate( CHANGING cs_handle = ls_h ).
    IF ls_h-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_path) = COND string( WHEN iv_request_id IS NOT INITIAL
                                 THEN |/request/{ iv_request_id }/party/exist|
                                 ELSE '/party/search' ).

    DATA lv_status TYPE i.
    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = lv_path iv_payload = lv_json ).
    rv_response = zcl_rak_http=>call(
      EXPORTING
        iv_api     = mc_api
        iv_path    = lv_path
        iv_method  = 'POST'
        iv_payload = lv_json
        it_headers = auth_hdr( ls_h )
        it_params  = VALUE #( ( name = 'searchType' value = iv_search_type ) )
      IMPORTING
        ev_status  = lv_status ).
    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = lv_path iv_status = lv_status ).

    IF ok_of( iv_resp = rv_response iv_status = lv_status ) = abap_false.
      CLEAR rv_response.
    ENDIF.

  ENDMETHOD.


  METHOD subservice_json.
    rv_json = blueprint( ).
  ENDMETHOD.


  METHOD today.
    rv_d = |{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.
  ENDMETHOD.


  METHOD to_options.

    DATA(lv_json) = condense( iv_json ).
    IF lv_json IS INITIAL.
      RETURN.
    ENDIF.

*   A bare array is legal JSON and common on lookup endpoints, but
*   /ui2/cl_json wants a named table to deserialize into. Wrap it.
    IF substring( val = lv_json len = 1 ) = '['.
      lv_json = |\{"result":{ lv_json }\}|.
    ENDIF.

    TYPES: BEGIN OF ty_row,
             key              TYPE string, id TYPE string, code TYPE string, value TYPE string,
             country_code     TYPE string, region_id TYPE string, city_id TYPE string,
             nationality_code TYPE string, occupation_code TYPE string,
             text             TYPE string, name TYPE string, name_en TYPE string,
             english_name     TYPE string, description TYPE string,
*            The service lookups label their rows englishTitle / arabicTitle,
*            which nothing here read - so a sub-service row fell through every
*            candidate to LV_KEY and the dropdown would have offered "90",
*            "232", "231" instead of the declaration names.
             english_title    TYPE string, arabic_title TYPE string,
             name_ar          TYPE string, arabic_name TYPE string,
           END OF ty_row,
           tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES: BEGIN OF ty_resp,
             result TYPE tt_row,
             data   TYPE tt_row,
             items  TYPE tt_row,
             list   TYPE tt_row,
           END OF ty_resp.

*   The second shape, and the reason the service lookups returned nothing at
*   all. TY_RESP types RESULT as a TABLE, which is right for the static
*   endpoints - /static/nationalities answers "result":[...]. The service
*   endpoints do not: /subservice/ answers
*
*     "result":{"subServices":[{"id":90,"englishTitle":"..."} ...]}
*
*   an OBJECT that CONTAINS the array. /ui2/cl_json cannot map an object onto
*   a table, so RESULT came back empty, the three fallbacks were empty too,
*   and a 200 OK with ten declarations in it produced zero options.
*
*   One type cannot have RESULT as both, so this is a second attempt rather
*   than more alternatives on the first.
    TYPES: BEGIN OF ty_lvl,
             sub_services    TYPE tt_row,
             main_services   TYPE tt_row,
             classifications TYPE tt_row,
             services        TYPE tt_row,
             rows            TYPE tt_row,
             items           TYPE tt_row,
             list            TYPE tt_row,
           END OF ty_lvl,
           BEGIN OF ty_resp_n,
             result TYPE ty_lvl,
             data   TYPE ty_lvl,
           END OF ty_resp_n.

    DATA ls_resp TYPE ty_resp.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_resp ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(lt_row) = COND tt_row( WHEN ls_resp-result IS NOT INITIAL THEN ls_resp-result
                                WHEN ls_resp-data   IS NOT INITIAL THEN ls_resp-data
                                WHEN ls_resp-items  IS NOT INITIAL THEN ls_resp-items
                                ELSE ls_resp-list ).

*   Nothing at the flat level, so try the nested one before giving up.
    IF lt_row IS INITIAL.
      DATA ls_respn TYPE ty_resp_n.
      TRY.
          /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                               pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                     CHANGING  data        = ls_respn ).
        CATCH cx_root.
          RETURN.
      ENDTRY.

      lt_row = COND tt_row(
        WHEN ls_respn-result-sub_services    IS NOT INITIAL THEN ls_respn-result-sub_services
        WHEN ls_respn-result-main_services   IS NOT INITIAL THEN ls_respn-result-main_services
        WHEN ls_respn-result-classifications IS NOT INITIAL THEN ls_respn-result-classifications
        WHEN ls_respn-result-services        IS NOT INITIAL THEN ls_respn-result-services
        WHEN ls_respn-result-rows            IS NOT INITIAL THEN ls_respn-result-rows
        WHEN ls_respn-result-items           IS NOT INITIAL THEN ls_respn-result-items
        WHEN ls_respn-result-list            IS NOT INITIAL THEN ls_respn-result-list
        WHEN ls_respn-data-sub_services      IS NOT INITIAL THEN ls_respn-data-sub_services
        WHEN ls_respn-data-main_services     IS NOT INITIAL THEN ls_respn-data-main_services
        WHEN ls_respn-data-rows              IS NOT INITIAL THEN ls_respn-data-rows
        WHEN ls_respn-data-items             IS NOT INITIAL THEN ls_respn-data-items
        ELSE ls_respn-data-list ).

      zcl_rak_not_trace=>add( |TO_OPTIONS flat shape empty, nested shape gave | &&
                              |{ lines( lt_row ) } row(s)| ).
    ENDIF.

    LOOP AT lt_row INTO DATA(ls_row).

      DATA(lv_key) = COND string(
        WHEN ls_row-key              IS NOT INITIAL THEN ls_row-key
        WHEN ls_row-code             IS NOT INITIAL THEN ls_row-code
        WHEN ls_row-country_code     IS NOT INITIAL THEN ls_row-country_code
        WHEN ls_row-region_id        IS NOT INITIAL THEN ls_row-region_id
        WHEN ls_row-city_id          IS NOT INITIAL THEN ls_row-city_id
        WHEN ls_row-nationality_code IS NOT INITIAL THEN ls_row-nationality_code
        WHEN ls_row-occupation_code  IS NOT INITIAL THEN ls_row-occupation_code
        WHEN ls_row-id               IS NOT INITIAL THEN ls_row-id
        ELSE ls_row-value ).

*     Arabic last, and only as a fallback, because TO_OPTIONS has no language
*     to work with - it is called from LOOKUP( ), which knows a list name and
*     nothing about the journey. An Arabic journey therefore still gets English
*     declaration names here. Worth fixing, and it needs the language plumbed
*     into LOOKUP( ) rather than a guess at this level.
      DATA(lv_txt) = COND string(
        WHEN ls_row-text          IS NOT INITIAL THEN ls_row-text
        WHEN ls_row-english_title IS NOT INITIAL THEN ls_row-english_title
        WHEN ls_row-name_en       IS NOT INITIAL THEN ls_row-name_en
        WHEN ls_row-english_name  IS NOT INITIAL THEN ls_row-english_name
        WHEN ls_row-name          IS NOT INITIAL THEN ls_row-name
        WHEN ls_row-description   IS NOT INITIAL THEN ls_row-description
        WHEN ls_row-arabic_title  IS NOT INITIAL THEN ls_row-arabic_title
        WHEN ls_row-name_ar       IS NOT INITIAL THEN ls_row-name_ar
        WHEN ls_row-arabic_name   IS NOT INITIAL THEN ls_row-arabic_name
        ELSE lv_key ).

      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( key = lv_key text = lv_txt ) TO rt_opt.

    ENDLOOP.

  ENDMETHOD.


  METHOD transfer_json.

    TYPES: BEGIN OF ty_t,
             transfer_id          TYPE string,
             reason_id            TYPE string,
             reason_other         TYPE string,
             emirate_id           TYPE string,
             address              TYPE string,
             street_name          TYPE string,
             city                 TYPE string,
             contact_number       TYPE string,
             applicant_visit_date TYPE string,
             applicant_visit_time TYPE string,
             house_number         TYPE string,
             region               TYPE string,
             transfer_notes       TYPE string,
           END OF ty_t.

    DATA(ls_t) = VALUE ty_t(
      reason_id            = field( it_fields = it_fields iv_name = 'visit_reasonId' )
      reason_other         = field( it_fields = it_fields iv_name = 'visit_reasonOther' )
      emirate_id           = field( it_fields = it_fields iv_name = 'visit_emirateId' )
      address              = field( it_fields = it_fields iv_name = 'visit_address' )
      street_name          = field( it_fields = it_fields iv_name = 'visit_streetName' )
      city                 = field( it_fields = it_fields iv_name = 'visit_city' )
      contact_number       = field( it_fields = it_fields iv_name = 'visit_contactNumber' )
      applicant_visit_date = field( it_fields = it_fields iv_name = 'visit_date' )
      applicant_visit_time = field( it_fields = it_fields iv_name = 'visit_time' )
      house_number         = field( it_fields = it_fields iv_name = 'visit_houseNumber' )
      region               = field( it_fields = it_fields iv_name = 'visit_region' )
      transfer_notes       = field( it_fields = it_fields iv_name = 'visit_notes' ) ).

    rv_json = /ui2/cl_json=>serialize( data        = ls_t
                                       compress    = abap_true
                                       pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

  ENDMETHOD.


  METHOD zif_rak_journey_backend~attach.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    ensure_token( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

*   attachmentConfId is the API's numeric document configuration id (279
*   Signature, 198 Trade Licence, 209 Other on sub-service 90), NOT a
*   document name. Sending a name silently files the document under no
*   configuration at all. The field's TECH_NAME carries the id; if it
*   carries a name instead, look it up in the blueprint's document list.
    DATA(lv_conf) = is_file-doc_type.
    IF lv_conf IS NOT INITIAL AND lv_conf CN '0123456789'.
      DATA(lv_want) = to_upper( lv_conf ).
      REPLACE ALL OCCURRENCES OF ` ` IN lv_want WITH ``.
      REPLACE ALL OCCURRENCES OF `_` IN lv_want WITH ``.

      LOOP AT doc_types( ) INTO DATA(ls_dt).
        DATA(lv_have) = to_upper( ls_dt-name ).
        REPLACE ALL OCCURRENCES OF ` ` IN lv_have WITH ``.
        REPLACE ALL OCCURRENCES OF `_` IN lv_have WITH ``.
        IF lv_have = lv_want.
          lv_conf = ls_dt-conf_id.
          EXIT.
        ENDIF.
      ENDLOOP.

      IF lv_conf CN '0123456789'.
        zcl_rak_not_trace=>add( |ATTACH no blueprint match for doc_type '{ is_file-doc_type }' - | &&
                                |attachmentConfId will be null| ).
      ENDIF.
    ENDIF.

*   Built by hand rather than serialized: attachmentConfId is a number on
*   the wire and /ui2/cl_json would quote it.
    DATA(lv_details) =
      |\{"documentName":"{ esc( is_file-name ) }",| &&
      |"documentNameAr":"{ esc( COND string( WHEN is_file-name_ar IS NOT INITIAL
                                             THEN is_file-name_ar ELSE is_file-name ) ) }",| &&
      COND string( WHEN lv_conf CO '0123456789' AND lv_conf IS NOT INITIAL
                   THEN |"attachmentConfId":{ lv_conf }\}|
                   ELSE |"attachmentConfId":null\}| ).

*   The caller (ZCL_RAK_JOURNEY_BE) always hands in mime =
*   'application/octet-stream', whatever the file. Notary's own collection
*   sends a jpg as image/jpg specifically, not the browser's image/jpeg, so
*   that override happens here rather than being trusted from upstream.
    DATA(lv_mime) = COND string( WHEN to_lower( is_file-extension ) = 'jpg' OR to_lower( is_file-extension ) = 'jpeg'
                                  THEN 'image/jpg'
                                  ELSE is_file-mime ).

    DATA lt_files TYPE ztt_ega_my_attachment.
    APPEND VALUE #( file_data      = is_file-xdata
                    file_mime_type = lv_mime
                    file_name      = is_file-name
                    file_extension = is_file-extension
                    file_descr     = 'file' ) TO lt_files.

    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/attachment' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}/attachment'
        iv_method      = 'POST'
        it_headers     = auth_hdr( cs_handle )
        it_form        = VALUE #( ( name = 'attachmentDetails' value = lv_details ) )
        it_files       = lt_files
        it_url_replace = VALUE #( ( name = '{reqId}' value = cs_handle-request_id ) )
      IMPORTING
        ev_status      = lv_status
        ev_reason      = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/attachment' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).

    DATA lv_fmsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_fmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Attachment '{ is_file-name }' failed: { lv_fmsg }|
           CHANGING  ct_return = et_return ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~capabilities.
*   payment = abap_true now. The Notary API owns the initial payment end
*   to end - calculate, create the billing document, lock, mark paid - so
*   the journey does have a payment, it is simply not FI-CA's.
    rs_cap = VALUE #( immediate   = abap_true
                      resumable   = abap_true
                      attachments = abap_true
                      payment     = abap_true ).
  ENDMETHOD.


  METHOD zif_rak_journey_backend~describe_step.

    CHECK to_upper( iv_step ) = 'BO'.

*   Recover the declaration from the model before asking for the blueprint.
*
*   GV_SUB_CUR is CLASS-DATA and this app is stateless - /sap/bc/rest gives
*   every round trip a fresh roll area - so whatever ON_CHANGE stored is gone
*   by the next request. The citizen's choice does survive, in the model, and
*   IT_FIELDS is that model: BE_FIELDS( ) publishes each field under the
*   journey's own name, so the declaration arrives here as SUBSERVICE.
*
*   Without this the trace reads 'BLUEPRINT skipped - no declaration chosen
*   yet' on a declaration that was plainly chosen, and every dynamic step
*   reports 0 fields.
    IF gv_sub_cur IS INITIAL.
      DATA(lv_pick) = field( it_fields = it_fields iv_name = 'SUBSERVICE' ).
      IF lv_pick IS NOT INITIAL.
        gv_sub_cur = lv_pick.
        zcl_rak_not_trace=>add( |BLUEPRINT declaration { lv_pick } recovered from the model| ).
      ENDIF.
    ENDIF.

    DATA(lv_json) = blueprint( ).
    IF lv_json IS INITIAL.
      RETURN.
    ENDIF.

*   Re-read the blueprint through the same tolerant shapes as
*   parse_blueprint( ), this time keeping label / required / options.
    TYPES: BEGIN OF ty_o,
             key         TYPE string, value TYPE string, id TYPE string, code TYPE string,
             text        TYPE string, name  TYPE string, name_ar TYPE string,
             description TYPE string,
*            What a LOOKUP choice actually looks like on the wire:
*              {"id":1,"idStr":null,"code":null,
*               "englishValue":"Inside RAK","arabicValue":"داخل رأس الخيمة"}
*            id is the value the business object is posted with; CODE and
*            IDSTR are usually null and are kept only as fallbacks.
             id_str        TYPE string,
             english_value TYPE string, arabic_value TYPE string,
           END OF ty_o,
           tt_o TYPE STANDARD TABLE OF ty_o WITH EMPTY KEY.

    TYPES: BEGIN OF ty_f,
             name           TYPE string, field_name TYPE string, technical_name TYPE string, code TYPE string,
             label          TYPE string, label_en   TYPE string, english_name   TYPE string,
             description    TYPE string, title      TYPE string,
             label_ar       TYPE string, arabic_name TYPE string,
             type           TYPE string, data_type  TYPE string, field_type TYPE string, control_type TYPE string,
             mandatory      TYPE abap_bool, required TYPE abap_bool, is_mandatory TYPE abap_bool,
             max_length     TYPE i, length TYPE i,
*            The blueprint carries a pattern per business field. Same
*            shape-tolerant treatment as every other attribute here - Q4 is still
*            open, so the spelling is not assumed.
             regex          TYPE string, regular_expression TYPE string,
             pattern        TYPE string, validation_regex   TYPE string,
             options        TYPE tt_o, values TYPE tt_o, lookup_values TYPE tt_o, items TYPE tt_o,
*            The names the blueprint actually uses. Confirmed from the live
*            response, not guessed:
*              {"businessfieldId":7,"englishFieldName":"Case Issuance place",
*               "arabicFieldName":"...","dataType":"LOOKUP","choices":[...],
*               "jsonKey":"caseIssuancePlace","maxLength":5,
*               "regEx":"^\\d{10}$","required":true}
*
*            JSON_KEY is the important one: it is the key the business object
*            is POSTed with - caseIssuancePlace, caseNumber, caseType - so it,
*            not the label, is the field's technical name.
*
*            REG_EX is separate from REGEX on purpose. /ui2/cl_json maps
*            camelCase to underscores, so "regEx" arrives as REG_EX and the
*            existing REGEX component never filled.
             json_key           TYPE string,
             businessfield_id   TYPE string,
             english_field_name TYPE string, arabic_field_name TYPE string,
             reg_ex             TYPE string,
             choices            TYPE tt_o,
           END OF ty_f,
           tt_f TYPE STANDARD TABLE OF ty_f WITH EMPTY KEY.

    TYPES: BEGIN OF ty_lvl,
             business_fields        TYPE tt_f,
             business_object_fields TYPE tt_f, bo_fields TYPE tt_f, fields TYPE tt_f,
             attributes             TYPE tt_f, blue_print TYPE tt_f, service_fields TYPE tt_f,
           END OF ty_lvl.

    TYPES: BEGIN OF ty_root,
             business_fields        TYPE tt_f,
             business_object_fields TYPE tt_f, bo_fields TYPE tt_f, fields TYPE tt_f,
             attributes             TYPE tt_f, blue_print TYPE tt_f, service_fields TYPE tt_f,
             result                 TYPE ty_lvl, data TYPE ty_lvl, sub_service TYPE ty_lvl,
             service_information    TYPE ty_lvl,
           END OF ty_root.

    DATA ls_r TYPE ty_root.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_r ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    DATA(lt_f) = COND tt_f(
*     businessFields is the one the live blueprint uses - result.businessFields.
*     It was already declared on TY_ROOT and TY_LVL and simply never consulted
*     here, so the deserialize filled it and the pick walked straight past it.
      WHEN ls_r-result-business_fields      IS NOT INITIAL THEN ls_r-result-business_fields
      WHEN ls_r-business_fields             IS NOT INITIAL THEN ls_r-business_fields
      WHEN ls_r-data-business_fields        IS NOT INITIAL THEN ls_r-data-business_fields
      WHEN ls_r-sub_service-business_fields IS NOT INITIAL THEN ls_r-sub_service-business_fields
      WHEN ls_r-business_object_fields IS NOT INITIAL THEN ls_r-business_object_fields
      WHEN ls_r-bo_fields              IS NOT INITIAL THEN ls_r-bo_fields
      WHEN ls_r-fields                 IS NOT INITIAL THEN ls_r-fields
      WHEN ls_r-attributes             IS NOT INITIAL THEN ls_r-attributes
      WHEN ls_r-blue_print             IS NOT INITIAL THEN ls_r-blue_print
      WHEN ls_r-service_fields         IS NOT INITIAL THEN ls_r-service_fields
      WHEN ls_r-result-business_object_fields IS NOT INITIAL THEN ls_r-result-business_object_fields
      WHEN ls_r-result-bo_fields       IS NOT INITIAL THEN ls_r-result-bo_fields
      WHEN ls_r-result-fields          IS NOT INITIAL THEN ls_r-result-fields
      WHEN ls_r-result-attributes      IS NOT INITIAL THEN ls_r-result-attributes
      WHEN ls_r-result-blue_print      IS NOT INITIAL THEN ls_r-result-blue_print
      WHEN ls_r-data-business_object_fields IS NOT INITIAL THEN ls_r-data-business_object_fields
      WHEN ls_r-data-fields            IS NOT INITIAL THEN ls_r-data-fields
      WHEN ls_r-sub_service-fields     IS NOT INITIAL THEN ls_r-sub_service-fields
      WHEN ls_r-sub_service-business_object_fields IS NOT INITIAL THEN ls_r-sub_service-business_object_fields
      WHEN ls_r-service_information-fields IS NOT INITIAL THEN ls_r-service_information-fields
      ELSE VALUE #( ) ).

*   Say which wrapper matched, and how many fields came out of it. The list
*   above guesses at a dozen shapes; when the blueprint arrives 200 OK and BO
*   still describes 0 fields, the question is only ever "which key holds the
*   fields, and is it one we look under" - and without this line that is
*   indistinguishable from a call that never happened.
    IF lt_f IS INITIAL.
      zcl_rak_not_trace=>add( |BLUEPRINT parsed 0 fields - none of the known wrappers | &&
        |(businessObjectFields / boFields / fields / attributes / bluePrint / serviceFields, | &&
        |bare or under result / data / subService / serviceInformation) held anything. | &&
        |The response body is traced above - the fields are under some other key.| ).
    ELSE.
      zcl_rak_not_trace=>add( |BLUEPRINT parsed { lines( lt_f ) } field(s) from the blueprint| ).
    ENDIF.

    LOOP AT lt_f INTO DATA(ls_f).

      DATA(lv_name) = COND string( WHEN ls_f-name           IS NOT INITIAL THEN ls_f-name
                                   WHEN ls_f-field_name     IS NOT INITIAL THEN ls_f-field_name
                                   WHEN ls_f-technical_name IS NOT INITIAL THEN ls_f-technical_name
*                                  JSON_KEY is what the business object is
*                                  POSTed with - caseIssuancePlace, caseNumber,
*                                  caseType - so it is the field's real
*                                  technical name. The generic aliases below
*                                  are all empty on this blueprint.
                                   WHEN ls_f-json_key       IS NOT INITIAL THEN ls_f-json_key
                                   ELSE ls_f-code ).
      IF lv_name IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lt_opt) = COND tt_o( WHEN ls_f-options       IS NOT INITIAL THEN ls_f-options
                                WHEN ls_f-values        IS NOT INITIAL THEN ls_f-values
                                WHEN ls_f-lookup_values IS NOT INITIAL THEN ls_f-lookup_values
                                WHEN ls_f-choices       IS NOT INITIAL THEN ls_f-choices
                                ELSE ls_f-items ).

*     ---- live lists -------------------------------------------------
*     A blueprint that inlines its own options is honoured, but the lists
*     that matter here - nationality, occupation, country, classification -
*     are never inlined; they are endpoints. Fetch them now, on this render.
*     Nothing about a list's CONTENT is ever held in configuration or in
*     this class: dyn_list_for( ) yields only a name, lookup( ) does the call.
      DATA lt_live TYPE zif_rak_journey_backend=>tt_dyn_opt.
      DATA lv_dep  TYPE abap_bool.

      IF lt_opt IS INITIAL.
        DATA(lv_list) = dyn_list_for( EXPORTING iv_name      = lv_name
                                      IMPORTING ev_dependent = lv_dep ).
        IF lv_list IS NOT INITIAL AND lv_dep = abap_false.
          lt_live = lookup( lv_list ).
        ENDIF.
      ENDIF.

      DATA(lv_raw) = to_upper( COND string( WHEN ls_f-type       IS NOT INITIAL THEN ls_f-type
                                            WHEN ls_f-data_type  IS NOT INITIAL THEN ls_f-data_type
                                            WHEN ls_f-field_type IS NOT INITIAL THEN ls_f-field_type
                                            ELSE ls_f-control_type ) ).

      DATA(lv_type) = COND string(
*       A dependent list is still a SELECT even while its options are empty:
*       the citizen must not be given a free-text box for a city that has to
*       match Notary's city table.
        WHEN lv_dep = abap_true       THEN 'SELECT'
        WHEN lt_live IS NOT INITIAL   THEN 'SELECT'
        WHEN lt_opt IS NOT INITIAL    THEN 'SELECT'
        WHEN lv_raw CS 'DATE'         THEN 'DATE'
        WHEN lv_raw CS 'TEXTAREA' OR lv_raw CS 'LONGTEXT' THEN 'TEXTAREA'
        WHEN lv_raw CS 'NUM' OR lv_raw CS 'DEC' OR lv_raw CS 'INT'
          OR lv_raw CS 'AMOUNT' OR lv_raw CS 'DOUBLE' OR lv_raw CS 'FLOAT' THEN 'NUMBER'
        ELSE 'INPUT' ).

*     A label the citizen can read, whatever the blueprint calls it. Last
*     resort is the technical name - an unlabelled input is still better
*     than a blank one, and it names the thing to ask Notary about.
      DATA(lv_label) = COND string( WHEN ls_f-label        IS NOT INITIAL THEN ls_f-label
                                    WHEN ls_f-label_en     IS NOT INITIAL THEN ls_f-label_en
                                    WHEN ls_f-english_name IS NOT INITIAL THEN ls_f-english_name
                                    WHEN ls_f-title        IS NOT INITIAL THEN ls_f-title
                                    WHEN ls_f-description  IS NOT INITIAL THEN ls_f-description
                                    WHEN ls_f-english_field_name IS NOT INITIAL THEN ls_f-english_field_name
                                    ELSE lv_name ).

      APPEND VALUE #(
*       MODEL_NAME( ) and not TO_UPPER( ). This name becomes a component on the
*       model structure, and a component name is capped at 30 characters - so a
*       jsonKey longer than that took the app down here rather than merely
*       rendering oddly. It has to be the SAME transformation PARSE_BLUEPRINT( )
*       applies to GT_MAP-UPPER, or the field would render under one name and be
*       read for the payload under another, and the value would post as blank.
        name     = model_name( lv_name )
        label    = lv_label
        label_ar = COND string( WHEN ls_f-label_ar          IS NOT INITIAL THEN ls_f-label_ar
                                WHEN ls_f-arabic_field_name IS NOT INITIAL THEN ls_f-arabic_field_name
                                ELSE ls_f-arabic_name )
        type     = lv_type
        required = COND abap_bool( WHEN ls_f-mandatory = abap_true OR ls_f-required = abap_true
                                     OR ls_f-is_mandatory = abap_true THEN abap_true ELSE abap_false )
        max_len  = COND i( WHEN ls_f-max_length > 0 THEN ls_f-max_length ELSE ls_f-length )
*       A pattern is only useful on something the citizen types. Attaching one to
*       a SELECT would let a choice the blueprint itself supplied fail validation.
        regex    = COND string(
          WHEN lv_type = 'SELECT' THEN ``
          WHEN ls_f-regex              IS NOT INITIAL THEN ls_f-regex
          WHEN ls_f-reg_ex             IS NOT INITIAL THEN ls_f-reg_ex
          WHEN ls_f-regular_expression IS NOT INITIAL THEN ls_f-regular_expression
          WHEN ls_f-validation_regex   IS NOT INITIAL THEN ls_f-validation_regex
          ELSE ls_f-pattern )
        options  = COND #( WHEN lt_live IS NOT INITIAL THEN lt_live
                           ELSE VALUE #( FOR o IN lt_opt (
*                    ID is the key the business object is posted with. CODE and
*                    IDSTR come back null on this blueprint and are fallbacks only.
                     key  = COND string( WHEN o-key IS NOT INITIAL THEN o-key
                                         WHEN o-id  IS NOT INITIAL THEN o-id
                                         WHEN o-code IS NOT INITIAL THEN o-code
                                         WHEN o-id_str IS NOT INITIAL THEN o-id_str
                                         ELSE o-value )
                     text = COND string( WHEN o-text IS NOT INITIAL THEN o-text
                                         WHEN o-name IS NOT INITIAL THEN o-name
                                         WHEN o-english_value IS NOT INITIAL THEN o-english_value
                                         WHEN o-arabic_value  IS NOT INITIAL THEN o-arabic_value
                                         WHEN o-description IS NOT INITIAL THEN o-description
                                         ELSE o-value ) ) ) ) ) TO rt_fields.

    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~discard.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    IF cs_handle-request_id IS INITIAL.
      RETURN.
    ENDIF.

    ensure_token( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    zcl_rak_not_trace=>http( iv_method = 'DELETE' iv_path = '/request/{reqId}' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}'
        iv_method      = 'DELETE'
        it_headers     = auth_hdr( cs_handle )
        it_url_replace = VALUE #( ( name = '{reqId}' value = cs_handle-request_id ) )
      IMPORTING
        ev_status      = lv_status
        ev_reason      = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'DELETE' iv_path = '/request/{reqId}' iv_status = lv_status iv_reason = lv_reason ).

*   204 carries no body, so there is no envelope to read - the HTTP
*   status is the whole answer for that one case.
    DATA lv_dmsg TYPE string.
    IF lv_status <> 204
       AND ok_of( EXPORTING iv_resp   = lv_resp
                            iv_status = lv_status
                  IMPORTING ev_msg    = lv_dmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'W'
                     iv_text   = |Discard failed ({ lv_status }): { lv_dmsg }|
           CHANGING  ct_return = et_return ).
    ELSE.
      CLEAR cs_handle.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~init.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    authenticate( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_svc, sub_service_id TYPE string, END OF ty_svc,
           BEGIN OF ty_req,
             applicant_category_id         TYPE i,
             applicant_name                TYPE string,
             applicant_business_partner_id TYPE string,
             employee_name                 TYPE string,
             employee_business_partner_id  TYPE string,
             creator_name                  TYPE string,
             creator_business_partner_id   TYPE string,
             request_date                  TYPE string,
             request_start_date            TYPE string,
           END OF ty_req,
           BEGIN OF ty_draft_body, service_info TYPE ty_svc, request_info TYPE ty_req, END OF ty_draft_body.

    TYPES: BEGIN OF ty_draft_rd, request_id TYPE string, status TYPE string, END OF ty_draft_rd,
           BEGIN OF ty_draft_fp, party_id TYPE string, business_partner_id TYPE string, END OF ty_draft_fp,
             BEGIN OF ty_draft_resp,
               request_details     TYPE ty_draft_rd,
               first_party_details TYPE ty_draft_fp,
             END OF ty_draft_resp.

*   Same precedence BLUEPRINT( ) uses, and for the same reason: the declaration
*   is chosen at runtime and neither BKND_JOURNEY nor IT_FIELDS can be relied on
*   to carry it.
*
*   IT_FIELDS in particular cannot. BE_FIELDS( ) publishes each field under
*   ls_f-NAME - the journey's field name, upper case - and FIELD( ) uppercases
*   what it is given, so asking for 'subServiceId' looks for SUBSERVICEID. A
*   field named SUBSERVICE never matches, and the draft went out as
*   "subServiceId":"" and came back notaryCode 3005 Sub Service Id Not found.
    DATA(lv_sub) = COND string( WHEN gv_sub_cur   IS NOT INITIAL THEN gv_sub_cur
                                WHEN mv_subservice IS NOT INITIAL THEN mv_subservice
                                WHEN field( it_fields = it_fields iv_name = 'SUBSERVICE' ) IS NOT INITIAL
                                  THEN field( it_fields = it_fields iv_name = 'SUBSERVICE' )
                                ELSE field( it_fields = it_fields iv_name = 'subServiceId' ) ).

*   Re-seed the static so everything later in THIS round trip - the blueprint,
*   the documents, the legal text - sees the declaration as well.
    IF gv_sub_cur IS INITIAL AND lv_sub IS NOT INITIAL.
      gv_sub_cur = lv_sub.
    ENDIF.

*   No declaration, no draft. Posting one anyway spends a call to be told 3005,
*   and leaves the citizen with an error on a step they have not reached.
    IF lv_sub IS INITIAL.
      zcl_rak_not_trace=>add( 'DRAFT not attempted - no declaration chosen yet' ).
      APPEND VALUE #( type = 'E' message = 'Choose the declaration before continuing.' ) TO et_return.
      RETURN.
    ENDIF.
    zcl_rak_not_trace=>add( |DRAFT creating for sub-service { lv_sub }| ).

    DATA(lv_cat) = COND string( WHEN field( it_fields = it_fields iv_name = 'applicantCategoryId' ) IS NOT INITIAL
                                THEN field( it_fields = it_fields iv_name = 'applicantCategoryId' )
                                ELSE '1' ).
    DATA(lv_anm) = COND string( WHEN field( it_fields = it_fields iv_name = 'applicantName' ) IS NOT INITIAL
                                THEN field( it_fields = it_fields iv_name = 'applicantName' )
                                ELSE 'Portal Applicant' ).
    DATA(lv_abp) = COND string( WHEN field( it_fields = it_fields iv_name = 'applicantBusinessPartnerId' ) IS NOT INITIAL
                                THEN field( it_fields = it_fields iv_name = 'applicantBusinessPartnerId' )
                                WHEN mv_loginbp IS NOT INITIAL THEN mv_loginbp
                                ELSE mc_dev_bp ).

*   requestDate / requestStartDate are dates in the collection, not
*   timestamps. A timestamp where a date is expected is the kind of thing
*   that validates on one environment and not the next.
    DATA(ls_body) = VALUE ty_draft_body(
      service_info = VALUE #( sub_service_id = lv_sub )
      request_info = VALUE #(
        applicant_category_id         = lv_cat
        applicant_name                = lv_anm
        applicant_business_partner_id = lv_abp
        employee_name                 = field( it_fields = it_fields iv_name = 'employeeName' )
        employee_business_partner_id  = field( it_fields = it_fields iv_name = 'employeeBusinessPartnerId' )
        creator_name                  = field( it_fields = it_fields iv_name = 'creatorName' )
        creator_business_partner_id   = field( it_fields = it_fields iv_name = 'creatorBusinessPartnerId' )
        request_date                  = now_ts( )
        request_start_date            = now_ts( ) ) ).

    DATA(lv_json) = /ui2/cl_json=>serialize( data        = ls_body
                                             compress    = abap_false
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/events/draft' iv_payload = lv_json ).
    DATA(lv_resp) = zcl_rak_http=>call( EXPORTING iv_api     = mc_api
                                                  iv_path    = '/request/events/draft'
                                                  iv_method  = 'POST'
                                                  iv_payload = lv_json
                                                  it_headers = auth_hdr( cs_handle )
                                        IMPORTING ev_status  = lv_status
                                                  ev_reason  = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/events/draft' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).

    IF lv_status = 401 OR lv_status = 403.
      reauth( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
      IF cs_handle-token IS NOT INITIAL.
        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/events/draft' iv_payload = lv_json ).
        lv_resp = zcl_rak_http=>call( EXPORTING iv_api     = mc_api
                                                iv_path    = '/request/events/draft'
                                                iv_method  = 'POST'
                                                iv_payload = lv_json
                                                it_headers = auth_hdr( cs_handle )
                                      IMPORTING ev_status  = lv_status
                                                ev_reason  = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/events/draft' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).
      ENDIF.
    ENDIF.

    DATA lv_cmsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_cmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Create draft failed: { lv_cmsg }|
           CHANGING  ct_return = et_return ).
      LOOP AT zcl_rak_not_trace=>dump( ) INTO DATA(lv_tl).
        msg( EXPORTING iv_type = 'E' iv_text = lv_tl CHANGING ct_return = et_return ).
      ENDLOOP.
      RETURN.
    ENDIF.

    DATA ls_dres TYPE ty_draft_resp.
    /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                         pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                               CHANGING  data        = ls_dres ).

    IF ls_dres-request_details-request_id IS INITIAL.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Create draft: no requestId in response: { lv_resp }|
           CHANGING  ct_return = et_return ).
      LOOP AT zcl_rak_not_trace=>dump( ) INTO DATA(lv_tn).
        msg( EXPORTING iv_type = 'E' iv_text = lv_tn CHANGING ct_return = et_return ).
      ENDLOOP.
      RETURN.
    ENDIF.

    cs_handle-request_id = ls_dres-request_details-request_id.
    CONDENSE cs_handle-request_id NO-GAPS.
    cs_handle-applicant  = lv_abp.
    cs_handle-status     = 'DRAFT'.

*   Q2 in the clarification document, answered by the response itself:
*   firstPartyDetails.partyId comes back populated, so the applicant IS
*   already the first party and posting one again would duplicate them.
    IF ls_dres-first_party_details-party_id IS NOT INITIAL.
      APPEND ls_dres-first_party_details-party_id TO cs_handle-party_ids.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~pay.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.
    DATA lv_resp   TYPE string.

    IF cs_handle-request_id IS INITIAL.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = 'Payment: no request id'
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

    ensure_token( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_rep) = VALUE tihttpnvp( ( name = '{reqId}' value = cs_handle-request_id )
                                    ( name = '{bdo}'   value = cs_handle-bdo ) ).
    DATA(lt_pt)  = VALUE tihttpnvp( ( name = 'paymentType' value = '1' ) ).

    CASE to_upper( iv_event ).

      WHEN 'CALC'.
*       GET calculates. It does not create anything, so it is safe to call
*       on every render of the fee card.
        zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/payment/initial' ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = '/request/{reqId}/payment/initial'
            iv_method      = 'GET'
            it_headers     = auth_hdr( cs_handle )
            it_params      = lt_pt
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}/payment/initial' iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          DATA ls_calc TYPE ty_calc_resp.
          /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                               pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                     CHANGING  data        = ls_calc ).
          cs_handle-amount = COND string(
            WHEN ls_calc-result-total_amount IS NOT INITIAL THEN ls_calc-result-total_amount
            WHEN ls_calc-result-amount       IS NOT INITIAL THEN ls_calc-result-amount
            WHEN ls_calc-total_amount        IS NOT INITIAL THEN ls_calc-total_amount
            ELSE ls_calc-amount ).
        ENDIF.

      WHEN 'CREATE'.
*       POST creates the billing document. Once, and only once - a second
*       POST is a second billing document for the same declaration.
        IF cs_handle-bdo IS NOT INITIAL.
          RETURN.
        ENDIF.

        DATA(lv_amt) = COND string( WHEN field( it_fields = it_fields iv_name = 'PAY_TOTAL' ) IS NOT INITIAL
                                    THEN field( it_fields = it_fields iv_name = 'PAY_TOTAL' )
                                    ELSE cs_handle-amount ).

        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/payment/initial' ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = '/request/{reqId}/payment/initial'
            iv_method      = 'POST'
            iv_payload     = |\{"totalAmount":"{ esc( lv_amt ) }"\}|
            it_headers     = auth_hdr( cs_handle )
            it_params      = lt_pt
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/payment/initial' iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          DATA ls_bd TYPE ty_bd_resp.
          /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                               pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                     CHANGING  data        = ls_bd ).
          cs_handle-bdo = COND string( WHEN ls_bd-result-sap_billing_number IS NOT INITIAL
                                       THEN ls_bd-result-sap_billing_number
                                       ELSE ls_bd-sap_billing_number ).
          IF cs_handle-bdo IS INITIAL.
            msg( EXPORTING iv_type   = 'E'
                           iv_text   = |Payment: no sapBillingNumber in response: { lv_resp }|
                 CHANGING  ct_return = et_return ).
          ENDIF.
        ENDIF.

      WHEN 'LOCK'.
*       Locks the transaction before the citizen is handed to the gateway,
*       so a second tab cannot start a parallel payment on the same
*       billing document.
        IF cs_handle-bdo IS INITIAL.
          msg( EXPORTING iv_type   = 'E'
                         iv_text   = 'Payment lock: no billing document yet'
               CHANGING  ct_return = et_return ).
          RETURN.
        ENDIF.

        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/payment/transaction/{bdo}/event/lock' ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = '/request/{reqId}/payment/transaction/{bdo}/event/lock'
            iv_method      = 'PUT'
            iv_payload     = '{}'
            it_headers     = auth_hdr( cs_handle )
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/payment/transaction/{bdo}/event/lock' iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          cs_handle-status = 'LOCKED'.
        ENDIF.

      WHEN 'PAID'.
*       Only after the gateway has confirmed. approvalCode and
*       transactionRefNumber come from the gateway response; a PAID event
*       with invented values is a payment confirmation for a payment that
*       may not have happened.
        IF cs_handle-bdo IS INITIAL.
          msg( EXPORTING iv_type   = 'E'
                         iv_text   = 'Payment paid: no billing document'
               CHANGING  ct_return = et_return ).
          RETURN.
        ENDIF.

        DATA(lv_appr) = field( it_fields = it_fields iv_name = 'PAY_APPROVAL' ).
        DATA(lv_txn)  = field( it_fields = it_fields iv_name = 'PAY_REFERENCE' ).
        IF lv_appr IS INITIAL OR lv_txn IS INITIAL.
          msg( EXPORTING iv_type   = 'E'
                         iv_text   = 'Payment paid: gateway approval code / reference missing - not posting PAID'
               CHANGING  ct_return = et_return ).
          RETURN.
        ENDIF.

        DATA(lv_body) =
          |\{"paymentStatus":true,| &&
          |"approvalCode":"{ esc( lv_appr ) }",| &&
          |"paymentTimeStamp":"{ now_ts( ) }",| &&
          |"transactionRefNumber":"{ esc( lv_txn ) }"\}|.

        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/payment/transaction/{bdo}/event/paid' iv_payload = lv_body ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = '/request/{reqId}/payment/transaction/{bdo}/event/paid'
            iv_method      = 'PUT'
            iv_payload     = lv_body
            it_headers     = auth_hdr( cs_handle )
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/payment/transaction/{bdo}/event/paid' iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          cs_handle-status = 'PAID'.
        ENDIF.

      WHEN OTHERS.
        RETURN.

    ENDCASE.

    DATA lv_pmsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_pmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Payment { iv_event } failed: { lv_pmsg }|
           CHANGING  ct_return = et_return ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~resume.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    authenticate( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    cs_handle-request_id = iv_request_id.

    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING
        iv_api         = mc_api
        iv_path        = '/request/{reqId}'
        iv_method      = 'GET'
        it_url_replace = VALUE #( ( name = '{reqId}' value = iv_request_id ) )
        it_headers     = auth_hdr( cs_handle )
      IMPORTING
        ev_status      = lv_status
        ev_reason      = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = 'GET' iv_path = '/request/{reqId}' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).

    DATA lv_rmsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_rmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Resume failed: { lv_rmsg }|
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

*   Pick the request back up where it was: status decides POST vs PUT on
*   submit, and the BO id decides POST vs PUT on the details step. Without
*   these a resumed draft creates a second business object.
    TYPES: BEGIN OF ty_bo, business_object_id TYPE string, id TYPE string, END OF ty_bo,
           BEGIN OF ty_rd, request_id TYPE string, status TYPE string,
                           sap_billing_number TYPE string, END OF ty_rd,
           BEGIN OF ty_rr, request_details TYPE ty_rd, status TYPE string,
                           business_object TYPE ty_bo, END OF ty_rr.

    DATA ls_rr TYPE ty_rr.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_rr ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    cs_handle-status = COND string( WHEN ls_rr-request_details-status IS NOT INITIAL
                                    THEN to_upper( ls_rr-request_details-status )
                                    WHEN ls_rr-status IS NOT INITIAL THEN to_upper( ls_rr-status )
                                    ELSE 'DRAFT' ).
    cs_handle-bo_id  = COND string( WHEN ls_rr-business_object-business_object_id IS NOT INITIAL
                                    THEN ls_rr-business_object-business_object_id
                                    ELSE ls_rr-business_object-id ).
    IF ls_rr-request_details-sap_billing_number IS NOT INITIAL.
      cs_handle-bdo = ls_rr-request_details-sap_billing_number.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~step_commit.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.
    DATA lv_resp   TYPE string.

    IF cs_handle-request_id IS INITIAL.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Step { iv_step }: no request id (draft not created)|
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

    ensure_token( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_rep) = VALUE tihttpnvp( ( name = '{reqId}' value = cs_handle-request_id ) ).

    CASE to_upper( iv_step ).

      WHEN 'PARTY1' OR 'PARTY2'.

*       The applicant is already the first party (init( ) captured the
*       partyId the draft handed back), so PARTY1 posts nothing unless a
*       journey deliberately overrides. PARTY2 is the counterparty.
        DATA(lv_force) = xsdbool( field( it_fields = it_fields iv_name = 'party_forcePost' ) = 'X' ).
        IF to_upper( iv_step ) = 'PARTY1' AND lv_force = abap_false.
          RETURN.
        ENDIF.

*       Nothing typed, nothing to post. A second party is optional on most
*       declarations and an empty POST creates an empty party.
*       bpId counts as identification. The CJS form identifies a party through
*       ZCL_RAK_BP_SEARCH and ends up holding a partner number rather than the
*       Emirates ID that was typed to find it, and the POST for a known partner
*       goes to /party/{bpId} - which needs no id in the body at all. Without
*       this the whole search path fell through the guard and posted nothing.
        IF field( it_fields = it_fields iv_name = 'bpId' )                   IS INITIAL
           AND field( it_fields = it_fields iv_name = 'party_idNumber' )        IS INITIAL
           AND field( it_fields = it_fields iv_name = 'party_passportNumber' ) IS INITIAL
           AND field( it_fields = it_fields iv_name = 'party_unifiedNumber' )  IS INITIAL
           AND field( it_fields = it_fields iv_name = 'party_tradeLicenseNumber' ) IS INITIAL.
          RETURN.
        ENDIF.

        DATA(lv_is_company) = xsdbool(
          to_upper( field( it_fields = it_fields iv_name = 'party_partyKind' ) ) = 'COMPANY'
          OR field( it_fields = it_fields iv_name = 'party_tradeLicenseNumber' ) IS NOT INITIAL ).

        DATA(lv_ptype) = COND string(
          WHEN lv_is_company = abap_true                                                    THEN 'CompanybyTL'
          WHEN field( it_fields = it_fields iv_name = 'party_idNumber' ) IS NOT INITIAL      THEN 'IndividualbyEID'
          WHEN field( it_fields = it_fields iv_name = 'party_passportNumber' ) IS NOT INITIAL THEN 'IndividualbyPassport'
          ELSE 'IndividualbyUID' ).

        DATA(lv_bp)   = field( it_fields = it_fields iv_name = 'bpId' ).
        DATA(lv_path) = COND string( WHEN lv_bp IS NOT INITIAL
                                     THEN |/request/\{reqId\}/party/{ lv_bp }|
                                     ELSE '/request/{reqId}/party' ).

        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = lv_path ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING iv_api         = mc_api
                    iv_path        = lv_path
                    iv_method      = 'POST'
                    iv_payload     = party_json( it_fields = it_fields
                                                 iv_first  = xsdbool( to_upper( iv_step ) = 'PARTY1' ) )
                    it_headers     = auth_hdr( cs_handle )
                    it_params      = VALUE #( ( name = 'partyType' value = lv_ptype ) )
                    it_url_replace = lt_rep
          IMPORTING ev_status      = lv_status
                    ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = lv_path iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          DATA ls_party TYPE ty_party_resp.
          /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                               pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                     CHANGING  data        = ls_party ).
          IF ls_party-result-party_id IS NOT INITIAL.
            APPEND ls_party-result-party_id TO cs_handle-party_ids.
          ENDIF.
        ENDIF.

      WHEN 'BO'.

*       Nothing to send for a declaration with no business object
*       (sub-service 90 posts {} in the collection). Skip rather than
*       create an empty object that then has to be updated.
        DATA(lv_bo_body) = bo_json( it_fields ).
        IF lv_bo_body = '{}' AND cs_handle-bo_id IS INITIAL.
          RETURN.
        ENDIF.

        DATA(lv_bopath) = COND string( WHEN cs_handle-bo_id IS NOT INITIAL
                                       THEN |/request/\{reqId\}/businessobject/{ cs_handle-bo_id }|
                                       ELSE '/request/{reqId}/businessobject' ).

        zcl_rak_not_trace=>http( iv_method = COND string( WHEN cs_handle-bo_id IS NOT INITIAL THEN 'PUT' ELSE 'POST' ) iv_path = lv_bopath iv_payload = lv_bo_body ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = lv_bopath
            iv_method      = COND string( WHEN cs_handle-bo_id IS NOT INITIAL THEN 'PUT' ELSE 'POST' )
            iv_payload     = lv_bo_body
            it_headers     = auth_hdr( cs_handle )
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = COND string( WHEN cs_handle-bo_id IS NOT INITIAL THEN 'PUT' ELSE 'POST' ) iv_path = lv_bopath iv_status = lv_status iv_reason = lv_reason ).

        IF ok_of( iv_resp = lv_resp iv_status = lv_status ) = abap_true.
          DATA ls_bo TYPE ty_bo_resp.
          /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                               pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                     CHANGING  data        = ls_bo ).
          cs_handle-bo_id = COND #( WHEN ls_bo-result-business_object_id IS NOT INITIAL
                                    THEN ls_bo-result-business_object_id
                                    ELSE ls_bo-result-id ).
        ENDIF.

      WHEN 'VISIT' OR 'TRANSFER'.

*       Optional on-location visit. No reason chosen means the citizen
*       does not want one, which is not a step failure.
        IF field( it_fields = it_fields iv_name = 'visit_required' ) <> 'X'.
          RETURN.
        ENDIF.

*       POST creates the visit request, PUT updates one the citizen has
*       already placed. VISIT_ID is written back by the handler from the
*       create response, so re-visiting the step edits rather than stacks.
        DATA(lv_vid)   = field( it_fields = it_fields iv_name = 'visit_id' ).
        DATA(lv_tpath) = COND string( WHEN lv_vid IS NOT INITIAL
                                      THEN '/request/{reqId}/transfer'
                                      ELSE '/request/{reqId}/transfer/selection' ).

        zcl_rak_not_trace=>http( iv_method = COND string( WHEN lv_vid IS NOT INITIAL THEN 'PUT' ELSE 'POST' ) iv_path = lv_tpath ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING
            iv_api         = mc_api
            iv_path        = lv_tpath
            iv_method      = COND string( WHEN lv_vid IS NOT INITIAL THEN 'PUT' ELSE 'POST' )
            iv_payload     = transfer_json( it_fields )
            it_headers     = auth_hdr( cs_handle )
            it_url_replace = lt_rep
          IMPORTING
            ev_status      = lv_status
            ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = COND string( WHEN lv_vid IS NOT INITIAL THEN 'PUT' ELSE 'POST' ) iv_path = lv_tpath iv_status = lv_status iv_reason = lv_reason ).

      WHEN 'LEGAL'.

*       ARABICLEGALTEXT is an RO_PANEL: get_table( ) paints it straight
*       from the API and it is never held as a model value, so there is
*       nothing here to send back. PUTting the empty string overwrites
*       the API's own legal text with nothing, which is the 500. Only
*       post when a journey actually captured edited text.
        DATA(lv_ltxt) = field( it_fields = it_fields iv_name = 'arabicLegalText' ).
        IF lv_ltxt IS INITIAL.
          RETURN.
        ENDIF.

        TYPES: BEGIN OF ty_lt, arabic_legal_text TYPE string, END OF ty_lt,
               BEGIN OF ty_ltb, legal_text TYPE ty_lt, END OF ty_ltb.
        DATA(ls_lt) = VALUE ty_ltb( legal_text = VALUE #(
                        arabic_legal_text = lv_ltxt ) ).

        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/legaltext' ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING iv_api         = mc_api
                    iv_path        = '/request/{reqId}/legaltext'
                    iv_method      = 'PUT'
                    iv_payload     = /ui2/cl_json=>serialize( data = ls_lt compress = abap_true
                                                              pretty_name = /ui2/cl_json=>pretty_mode-camel_case )
                    it_headers     = auth_hdr( cs_handle )
                    it_url_replace = lt_rep
          IMPORTING ev_status      = lv_status
                    ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'PUT' iv_path = '/request/{reqId}/legaltext' iv_status = lv_status iv_reason = lv_reason ).

      WHEN 'BILLING'.

        DATA(lv_owner) = field( it_fields = it_fields iv_name = 'billingBusinessPartnerId' ).
        IF lv_owner IS INITIAL.
*         Default the payer to the applicant rather than posting a blank
*         owner: the billing document has to belong to somebody before
*         the payment can be calculated.
          lv_owner = COND string( WHEN cs_handle-applicant IS NOT INITIAL THEN cs_handle-applicant
                                  WHEN mv_loginbp IS NOT INITIAL THEN mv_loginbp
                                  ELSE mc_dev_bp ).
        ENDIF.

        TYPES: BEGIN OF ty_bill, business_partner_id TYPE string, END OF ty_bill.
        DATA(ls_bill) = VALUE ty_bill( business_partner_id = lv_owner ).

        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/bill/owner' ).
        lv_resp = zcl_rak_http=>call(
          EXPORTING iv_api         = mc_api
                    iv_path        = '/request/{reqId}/bill/owner'
                    iv_method      = 'POST'
                    iv_payload     = /ui2/cl_json=>serialize( data = ls_bill compress = abap_true
                                                              pretty_name = /ui2/cl_json=>pretty_mode-camel_case )
                    it_headers     = auth_hdr( cs_handle )
                    it_url_replace = lt_rep
          IMPORTING ev_status      = lv_status
                    ev_reason      = lv_reason ).
        zcl_rak_not_trace=>http( iv_method = 'POST' iv_path = '/request/{reqId}/bill/owner' iv_status = lv_status iv_reason = lv_reason ).

      WHEN OTHERS.
        RETURN.

    ENDCASE.

*   Two codes are benign at their own step and nowhere else. 7006 says
*   the party is already on the request, which is what the draft did for
*   the applicant and what a re-committed step does the second time.
*   9042 says this sub-service takes no business object, which is true of
*   90. Everything else, 7018 and 7034 included, is a real failure and
*   now says so instead of passing as a green screen.
    DATA lv_scode TYPE string.
    DATA lv_smsg  TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_code   = lv_scode
                        ev_msg    = lv_smsg ) = abap_false.
      IF NOT ( to_upper( iv_step ) CS 'PARTY' AND lv_scode = '7006' )
         AND NOT ( to_upper( iv_step ) = 'BO' AND lv_scode = '9042' ).
        msg( EXPORTING iv_type   = 'E'
                       iv_text   = |Step { iv_step } failed: { lv_smsg }|
             CHANGING  ct_return = et_return ).
      ELSE.
        zcl_rak_not_trace=>add( |STEP { iv_step } tolerated notaryCode { lv_scode }| ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_backend~submit.

    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    ensure_token( IMPORTING et_return = et_return CHANGING cs_handle = cs_handle ).
    IF cs_handle-token IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_sub, translation_required TYPE abap_bool, END OF ty_sub.

    DATA(lv_tr) = field( it_fields = it_fields iv_name = 'translationRequired' ).
    DATA(ls_sub) = VALUE ty_sub( translation_required =
      xsdbool( lv_tr = 'X' OR to_upper( lv_tr ) = 'TRUE' OR lv_tr = '1' ) ).

*   POST creates the submission, PUT re-submits one the officer returned.
    DATA(lv_method) = COND string( WHEN cs_handle-status = 'DRAFT' OR cs_handle-status IS INITIAL
                                   THEN 'POST' ELSE 'PUT' ).

    zcl_rak_not_trace=>http( iv_method = lv_method iv_path = '/request/{reqId}/events/submit' ).
    DATA(lv_resp) = zcl_rak_http=>call(
      EXPORTING iv_api         = mc_api
                iv_path        = '/request/{reqId}/events/submit'
                iv_method      = lv_method
                iv_payload     = /ui2/cl_json=>serialize( data = ls_sub compress = abap_true
                                                          pretty_name = /ui2/cl_json=>pretty_mode-camel_case )
                it_headers     = auth_hdr( cs_handle )
                it_url_replace = VALUE #( ( name = '{reqId}' value = cs_handle-request_id ) )
      IMPORTING ev_status      = lv_status
                ev_reason      = lv_reason ).
    zcl_rak_not_trace=>http( iv_method = lv_method iv_path = '/request/{reqId}/events/submit' iv_status = lv_status iv_reason = lv_reason iv_resp = lv_resp ).

    DATA lv_bmsg TYPE string.
    IF ok_of( EXPORTING iv_resp   = lv_resp
                        iv_status = lv_status
              IMPORTING ev_msg    = lv_bmsg ) = abap_false.
      msg( EXPORTING iv_type   = 'E'
                     iv_text   = |Submit failed: { lv_bmsg }|
           CHANGING  ct_return = et_return ).
      RETURN.
    ENDIF.

    cs_handle-status = 'SUBMITTED'.

  ENDMETHOD.
ENDCLASS.
