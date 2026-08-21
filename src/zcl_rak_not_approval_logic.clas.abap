*&---------------------------------------------------------------------*
*& ZCL_RAK_NOT_APPROVAL_LOGIC
*&
*& Handler for the Notary declaration journeys (NOT_* family).
*& Inherits ZCL_RAK_JOURNEY_LOGIC and redefines only what Notary needs:
*&   on_value_help      - resolves every list live from the Notary static
*&                        endpoints; nothing is held here
*&   on_search          - BP party lookup, pre-fills the party form
*&   get_table          - RO_PANEL body for the legal text, from the API
*&   on_custom_validate - Notary field checks; CALLS SUPER so the base
*&                        payment PAID-gate is preserved
*&
*& NOT redefined on purpose: on_before_post / on_before_fields (the base
*& strips PAY_* there), wants_feedback (feedback stays automatic).
*&---------------------------------------------------------------------*
CLASS zcl_rak_not_approval_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start    REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help      REDEFINITION.
    METHODS zif_rak_journey_logic~on_search          REDEFINITION.
    METHODS zif_rak_journey_logic~get_table          REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PRIVATE SECTION.

    CONSTANTS mc_sub TYPE string VALUE '90'.

*   The Declaration Attestation pair, used to filter the declaration list.
*   Taken from the shared collection's own sub-service call -
*   /subservice/?classfication_Id=27&applicant_type_id=1&mainService_Id=1 -
*   and NOT from a document that states them, so treat them as the first
*   thing to check if the Sub Service dropdown comes back empty against a
*   live tenant. The collection's main-service call uses classfication_Id=31,
*   which is a different classification, so 27 is not simply "the only one".
    CONSTANTS mc_class_decl TYPE string VALUE '27'.
    CONSTANTS mc_main_decl  TYPE string VALUE '1'.

    METHODS blueprint_legal_text
      IMPORTING io_be          TYPE REF TO zcl_rak_be_not
      RETURNING VALUE(rv_text) TYPE string.

*   One value off a business-partner row, by candidate component name. See the
*   method body for why the names cannot simply be hard-coded.
    METHODS bp_pick
      IMPORTING is_bp        TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner
                iv_names     TYPE string
      RETURNING VALUE(rv)    TYPE string.

ENDCLASS.



CLASS ZCL_RAK_NOT_APPROVAL_LOGIC IMPLEMENTATION.


  METHOD blueprint_legal_text.

    DATA(lv_json) = io_be->subservice_json( ).
    IF lv_json IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_res, legal_text TYPE string, END OF ty_res,
           BEGIN OF ty_root, result TYPE ty_res, END OF ty_root.

    DATA ls_r TYPE ty_root.

    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_r ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    rv_text = ls_r-result-legal_text.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.

    CASE to_upper( iv_name ).

      WHEN 'ARABICLEGALTEXT'.

        DATA(lo_be) = NEW zcl_rak_be_not( iv_subservice = mc_sub ).

        DATA(lv_req) = io_ctx->get_val( 'REQUEST_ID' ).
        IF lv_req IS INITIAL.
          lv_req = io_ctx->get_param( 'draftid' ).
        ENDIF.
        IF lv_req IS INITIAL.
          lv_req = io_ctx->get_param( 'caseid' ).
        ENDIF.

        DATA lv_txt TYPE string.

        IF lv_req IS NOT INITIAL.
          lv_txt = lo_be->legal_text( lv_req ).
        ENDIF.

        IF lv_txt IS INITIAL.
          lv_txt = blueprint_legal_text( lo_be ).
        ENDIF.

        IF lv_txt IS INITIAL.
          RETURN.
        ENDIF.

        rs_data-columns = VALUE #( ( `Legal Text` ) ).

        SPLIT lv_txt AT '</p>' INTO TABLE DATA(lt_para).

        LOOP AT lt_para INTO DATA(lv_p).
          REPLACE ALL OCCURRENCES OF '<p>'   IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '<br>'  IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '<br/>' IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '&nbsp;' IN lv_p WITH ` `.
          CONDENSE lv_p.
          IF lv_p IS NOT INITIAL.
            APPEND VALUE #( ( lv_p ) ) TO rs_data-rows.
          ENDIF.
        ENDLOOP.

    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   Preserve the base payment PAID-gate first.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx
                                                          iv_step = iv_step ).

*   Emirates ID shape.
    DATA(lv_eid) = io_ctx->get_val( 'PARTY_IDNUMBER' ).
    IF lv_eid IS NOT INITIAL AND strlen( lv_eid ) <> 15.
      APPEND VALUE #( type = 'Error' text = 'Emirates ID must be 15 digits.' ) TO rt.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.

*   BP party lookup. The id type chosen drives the Notary search type; a hit
*   pre-fills the party form so the citizen confirms rather than retypes.
    DATA(lv_id) = io_ctx->get_val( 'PARTY_IDNUMBER' ).
    IF lv_id IS INITIAL.
      lv_id = io_ctx->get_val( 'PARTY_PASSPORTNUMBER' ).
    ENDIF.
    IF lv_id IS INITIAL.
      lv_id = io_ctx->get_val( 'PARTY_UNIFIEDNUMBER' ).
    ENDIF.
    IF lv_id IS INITIAL.
      RETURN.
    ENDIF.

*   The id-type combobox holds SAP identification types (YFS002 and the
*   like) because the engine's own BP browse searches BUT0ID with them.
*   They map onto ZCL_RAK_BP_SEARCH's own request fields, not onto Notary
*   searchType strings: party identity is resolved in SAP.
    DATA(lv_idtype) = to_upper( io_ctx->get_val( 'PARTY_SEARCH_IDTYPE' ) ).

*   ------------------------------------------------------------------
*   Party identity is resolved in SAP, not by the Notary portal.
*
*   This used to POST to Notary's search-party endpoint and pre-fill the form
*   from its answer. Two reasons that is the wrong side of the boundary:
*
*     Notary's search does not carry the checks SAP does. ZCL_RAK_BP_SEARCH
*     calls MOI, updates the BP from it, and refuses an expired Emirates ID or
*     trade licence. A party that SAP would reject was being accepted here and
*     the declaration then carried it all the way to the officer.
*
*     It made party identification depend on a credential that does not
*     currently work - Q1 in the clarification document, still open - so the
*     search could not be exercised at all.
*
*   ZCL_RAK_BE_NOT->SEARCH_PARTY( ) is deliberately left in place. It still
*   documents Notary's contract and the pre-check in step 5a of the API flow may
*   yet need it; nothing calls it for search any more.
*   ------------------------------------------------------------------
    DATA ls_req TYPE zcl_rak_bp_search=>ty_req.

    ls_req-idtype      = lv_idtype.
    ls_req-dob         = io_ctx->get_val( 'PARTY_DOB' ).
    ls_req-nationality = io_ctx->get_val( 'PARTY_NATIONALITY' ).

    IF lv_idtype = 'TL' OR lv_idtype = 'TRADELICENSE' OR lv_idtype = 'COMPANYBYTL'.
      ls_req-trade_licence = lv_id.
    ELSE.
*     EID, passport and unified number all go in EID - the same thing
*     ZCL_RAK_BP_POPUP does, and for the same reason: which request field a
*     passport or a unified number really belongs in is the one part of that
*     contract nobody has been able to confirm.
      ls_req-eid = lv_id.
*     Full verification, deliberately. A notary party is being identified for a
*     legal instrument, so MOI is called and a date-of-birth or nationality
*     mismatch rejects - which is what asking for those two on this form is FOR.
*     If Notary confirm a party may be merely looked up rather than verified,
*     this is the one line to change: NO_MOI_CALL on the request suppresses the
*     call, SKIP_MOI_MISMATCH keeps it but tolerates a mismatch.
      IF lv_idtype IS INITIAL OR lv_idtype = 'YFS002' OR lv_idtype = 'EID'
         OR lv_idtype = 'EMIRATESID'.
        ls_req-call_moi = abap_true.
      ENDIF.
    ENDIF.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

*   Every finding reaches the citizen. An expired licence or a failed MOI
*   comparison is the answer to the search, not a detail to swallow.
    DATA(lv_err) = abap_false.
    LOOP AT ls_res-msg INTO DATA(ls_m).
      io_ctx->add_msg( iv_type = COND string( WHEN ls_m-type = 'E' OR ls_m-type = 'A' THEN 'Error'
                                              WHEN ls_m-type = 'W' THEN 'Warning'
                                              ELSE 'Information' )
                       iv_text = CONV string( ls_m-message ) ).
      IF ls_m-type = 'E' OR ls_m-type = 'A'.
        lv_err = abap_true.
      ENDIF.
    ENDLOOP.

*   A rejected party must NOT become a filled form. A caller that ignores the
*   findings is worse than one that never had them.
    IF lv_err = abap_true.
      RETURN.
    ENDIF.

    READ TABLE ls_res-rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc <> 0.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = 'No business partner found. Enter the party details below.' ).
      RETURN.
    ENDIF.

*   PARTNER and TELEPHONE_NUMBER are the proven component names. Everything else
*   goes through a candidate list, because the entity behind ZCL_RAK_BP_SEARCH
*   holds a person's name in parts on one category and in one field on another.
    io_ctx->set_val( iv_name = 'PARTY_BPID'
                     iv_value = CONV string( ls_bp-partner ) ).
    io_ctx->set_val( iv_name = 'PARTY_MOBILENUMBER'
                     iv_value = CONV string( ls_bp-telephone_number ) ).

    DATA(lv_first) = bp_pick( is_bp = ls_bp iv_names = 'NAME_FIRST,FIRSTNAME' ).
    DATA(lv_last)  = bp_pick( is_bp = ls_bp iv_names = 'NAME_LAST,LASTNAME' ).
    DATA(lv_email) = bp_pick( is_bp = ls_bp
                              iv_names = 'SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS' ).

    IF lv_first IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_FIRSTNAME' iv_value = lv_first ).
    ENDIF.
    IF lv_last IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_LASTNAME' iv_value = lv_last ).
    ENDIF.
    IF lv_email IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_EMAIL' iv_value = lv_email ).
    ENDIF.

*   Nationality and date of birth come back confirmed by MOI on the verified
*   path, so the form shows what was checked rather than what was typed.
    DATA(lv_nat) = bp_pick( is_bp = ls_bp iv_names = 'NATIONALITY,NATIO,COUNTRYORIGIN' ).
    IF lv_nat IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_NATIONALITY' iv_value = lv_nat ).
    ENDIF.
    DATA(lv_dob) = bp_pick( is_bp = ls_bp iv_names = 'DOB,BIRTHDT,BIRTHDATE' ).
    IF lv_dob IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_DOB' iv_value = lv_dob ).
    ENDIF.

*   PARTY_FATHERNAME and PARTY_ARABICFULLNAME are deliberately NOT set. Notary's
*   own search returned a father name; no component on the SAP row has been shown
*   to hold one, and guessing a name would either fail activation or silently
*   fill nothing. The citizen types them, which is what the documented flow says
*   happens when SAP holds no previous data.

  ENDMETHOD.


  METHOD bp_pick.
*   One value off a BP row, by the first component name in the list that exists
*   and is filled. The row type is an OData entity whose component names differ
*   by BP category, so a fixed name would work for one kind of party and quietly
*   return nothing for the other.
*
*   The same candidate-list trick ZCL_RAK_BP_POPUP->PICK( ) uses. Duplicated here
*   rather than shared because ZCL_RAK_BP_SEARCH - where a shared version belongs,
*   since it owns the row type - showed state M_ in the abapGit pull dialog, so SAP
*   holds changes git does not and editing it risks pushing an older copy over
*   them. Consolidate once that object is staged.
    SPLIT to_upper( iv_names ) AT ',' INTO TABLE DATA(lt_n).
    LOOP AT lt_n INTO DATA(lv_n).
      lv_n = condense( lv_n ).
      IF lv_n IS INITIAL.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT lv_n OF STRUCTURE is_bp TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0 AND <v> IS NOT INITIAL.
        rv = condense( CONV string( <v> ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_rak_journey_logic~on_render_start.

    super->zif_rak_journey_logic~on_render_start( io_ctx  = io_ctx
                                                  io_view = io_view ).

*   GV_SUB_CUR is CLASS-DATA and this app is stateless: /sap/bc/rest hands
*   every round trip a fresh roll area, so the value ON_CHANGE stored is gone
*   by the time the NEXT request renders. The citizen's choice does survive -
*   it is in the model, which abap2UI5 persists - but nothing was copying it
*   back into the backend.
*
*   DESCRIBE_STEP( ) cannot do that itself: it is handed a step name and
*   nothing else, so BLUEPRINT( ) has no way to reach the model. That is why
*   step 2 drew five empty labels, and why Next answered "Choose the
*   declaration before continuing" on a declaration plainly selected on step 1.
*
*   So re-seed the static from the model at the start of every render, before
*   anything asks for the blueprint. ON_CHANGE still fires on the press and is
*   what makes the change immediate; this is what makes it SURVIVE.
    DATA(lv_sub) = io_ctx->get_val( 'SUBSERVICE' ).
    IF lv_sub IS NOT INITIAL.
      zcl_rak_be_not=>set_subservice( lv_sub ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

*   The declaration drives everything after step 1 - the blueprint, the
*   business-object fields, the documents, the legal text, whether a second
*   party is needed. The backend cannot ask for it: DESCRIBE_STEP( ) is handed
*   a step name and nothing else, and the engine builds the backend from the
*   journey HEADER, whose BKND_JOURNEY is one static value for a journey that
*   serves ten declarations.
*
*   So the handler tells it, here, the moment the citizen chooses.
    IF to_upper( iv_field ) = 'SUBSERVICE'.
      zcl_rak_be_not=>set_subservice( io_ctx->get_val( 'SUBSERVICE' ) ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.

*   Every list here is resolved live. dyn_list_for( ) maps a field name to
*   a list NAME only; lookup( ) fetches the content from the Notary static
*   endpoints on each call. No list values are held in this class.
    DATA(lo_be) = NEW zcl_rak_be_not( iv_subservice = mc_sub ).

    DATA(lv_list) = lo_be->dyn_list_for( iv_name = iv_field ).
    IF lv_list IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_a1 TYPE string.
    DATA lv_a2 TYPE string.

*   Region and city are dependent lists: the endpoint needs the parent that
*   was chosen. This is the one place those values are visible.
    CASE lv_list.

*     The declaration list is filtered by classification and main service.
*     Both are fixed to Declaration Attestation on this journey - the portal
*     disables those two dropdowns for exactly that reason - so the ids come
*     off the model, and fall back to the Declaration Attestation pair when
*     the citizen has not been near them.
      WHEN 'SUBSERVICE'.
        lv_a1 = io_ctx->get_val( 'CLASSIFICATION_ID' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = mc_class_decl.
        ENDIF.
        lv_a2 = io_ctx->get_val( 'MAINSERVICE_ID' ).
        IF lv_a2 IS INITIAL.
          lv_a2 = mc_main_decl.
        ENDIF.

      WHEN 'MAINSERVICE'.
        lv_a1 = io_ctx->get_val( 'CLASSIFICATION_ID' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = mc_class_decl.
        ENDIF.

      WHEN 'REGION'.
        lv_a1 = io_ctx->get_val( 'PARTY_LIVINGCOUNTRY' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = 'AE'.
        ENDIF.

      WHEN 'CITY'.
        lv_a1 = io_ctx->get_val( 'PARTY_LIVINGCOUNTRY' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = 'AE'.
        ENDIF.
        lv_a2 = io_ctx->get_val( 'PARTY_REGION' ).
        IF lv_a2 IS INITIAL.
          RETURN.
        ENDIF.

    ENDCASE.

    DATA(lt_opt) = lo_be->lookup( iv_list = lv_list
                                  iv_arg1 = lv_a1
                                  iv_arg2 = lv_a2 ).

    rt = VALUE #( FOR o IN lt_opt ( key = o-key text = o-text ) ).

  ENDMETHOD.
ENDCLASS.
