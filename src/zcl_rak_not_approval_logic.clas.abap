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
*&   render_field       - claims PARTY1/PARTY2 to draw the list with its
*&                        per-row View and Contact actions; CALLS SUPER for
*&                        every other field so the base keeps PAYFEE
*&   on_render_end      - the Add Party button under the party form
*&   on_render_popup    - the View and Contact dialogs, read-only, re-read
*&                        from the API rather than remembered
*&   on_popup_event     - PADD_ / PVIEW_ / PCONT_; CALLS SUPER so the base
*&                        keeps PAYNOW and PAYPOLL
*&   on_before_fields   - renames the P1_/P2_ form onto the party_* payload
*&                        the Notary API expects; CALLS SUPER so the base
*&                        still strips PAY_*
*&
*& NOT redefined on purpose: on_before_post (the base strips PAY_* there),
*& wants_feedback (feedback stays automatic).
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
    METHODS zif_rak_journey_logic~render_field       REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_end      REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup    REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event     REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_fields   REDEFINITION.

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

*   'P1_' for anything on the First Party step, 'P2_' for the Second Party
*   step, empty for a field on neither. The two steps are the same form twice,
*   so every method that touches a party field derives its prefix here rather
*   than branching on the step - which is what stops the second party quietly
*   writing over the first.
    METHODS party_prefix
      IMPORTING iv_name   TYPE string
      RETURNING VALUE(rv) TYPE string.

*   The request the parties hang off. REQUEST_ID once the draft exists, and
*   the launch parameter before that - a resumed application arrives with
*   draftid or caseid set and REQUEST_ID still blank.
    METHODS request_id
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE string.

*   The parties on this request, filtered to the side asked for.
    METHODS party_rows
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_first  TYPE abap_bool
      RETURNING VALUE(rt) TYPE zcl_rak_be_not=>tt_party_row.

*   Copy a business-partner row onto one party form.
    METHODS fill_party_form
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_prefix TYPE string
                is_bp     TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner.

*   Post the form as a party on the request, then clear it for the next one.
    METHODS add_party
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_prefix TYPE string.

*   Which party step is being drawn, set by RENDER_FIELD( ) and read by
*   ON_RENDER_END( ). GET_STEP( ) answers an index, not a step id, so the
*   Add Party button has no other way to know which form it belongs under.
*   Safe as instance state because both run in the same round trip - unlike
*   ZCL_RAK_BE_NOT's GV_SUB_CUR, which is CLASS-DATA and does not survive one.
    DATA mv_party_pfx TYPE string.

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

      WHEN 'PARTY1' OR 'PARTY2'.

*       Nothing answered these before, so both tables drew "No data" over a
*       request that plainly had a party - the draft reply names it in
*       firstPartyDetails. GET /request/{id}/party was documented at the top
*       of ZCL_RAK_BE_NOT from the start and never implemented; PARTIES( ) is
*       that call.
*       Column KEYS, not labels. ZCL_RAK_JOURNEY_RENDER matches these against
*       the NAME:Label:TYPE spec on the field and only falls back to taking
*       cells by position - with a gate warning - when nothing matches.
        rs_data-columns = VALUE #( ( `NAME` ) ( `MOBILE` ) ( `NAT` ) ).

        DATA(lt_pt) = party_rows( io_ctx   = io_ctx
                                  iv_first = xsdbool( to_upper( iv_name ) = 'PARTY1' ) ).

        LOOP AT lt_pt INTO DATA(ls_pt).
          APPEND VALUE #( ( ls_pt-party_name )
                          ( ls_pt-mobile )
                          ( ls_pt-nationality ) ) TO rs_data-rows.
        ENDLOOP.

    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   Preserve the base payment PAID-gate first.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx
                                                          iv_step = iv_step ).

*   The Emirates ID check that used to be here read PARTY_IDNUMBER, which is
*   not a field on this journey, so GET_VAL( ) always answered blank and the
*   check never once fired. Nothing replaces it, deliberately: the party form
*   holds a partner number resolved by ZCL_RAK_BP_SEARCH, and that search has
*   already put the Emirates ID through MOI, the expiry checks and the DOB and
*   nationality comparison. Re-checking the digit count here would be a second,
*   weaker opinion on a question already answered properly.
*
*   What is worth refusing is a party step with no party on it, which no amount
*   of field validation can see - the list comes from the API, not the model.
*   IV_STEP is an INDEX, not a step id - and a zero-based one, as the base's own
*   PAY_FIELD_STEP( ) shows by counting from zero. So the step has to be resolved
*   through the config rather than compared to 'STP3'.
*
*   BKND_SCREEN and not ID, because the id is a position in the seed and the
*   backend screen is what the step actually IS. A declaration that adds a step
*   ahead of this one renumbers every STP*; nothing renumbers PARTY1.
    DATA(lv_ix) = iv_step + 1.

    DATA(ls_cfg) = io_ctx->get_config( ).
    READ TABLE ls_cfg-steps INTO DATA(ls_step) INDEX lv_ix.
    IF sy-subrc <> 0 OR to_upper( ls_step-bknd_screen ) <> 'PARTY1'.
      RETURN.
    ENDIF.

    DATA(lt_p1) = party_rows( io_ctx = io_ctx iv_first = abap_true ).
    IF lt_p1 IS INITIAL.
      rt = VALUE #( BASE rt
        ( type = 'Error' text = 'Add the first party before continuing.' ) ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.

*   BP party lookup. The id type chosen drives the Notary search type; a hit
*   pre-fills the party form so the citizen confirms rather than retypes.
*
*   This used to read PARTY_IDNUMBER, PARTY_PASSPORTNUMBER, PARTY_UNIFIEDNUMBER
*   and PARTY_SEARCH_IDTYPE. Not one of those is a field on this journey, and a
*   name that is not on the journey makes GET_VAL( ) a legal no-op - so all
*   three came back empty, the guard below returned, and pressing Search did
*   precisely nothing with no error to show for it. That is the trap CLAUDE.md
*   names first, and it survived because a search that silently does nothing
*   looks exactly like a search that found nothing.
*
*   Read the field the citizen actually pressed Search on instead. P1_BP and
*   P2_BP are seeded SEARCH fields, so the engine also owns <FIELD>_IDTYPE and
*   the Browse button beside it, and the two steps share this one method.
    DATA(lv_pfx) = party_prefix( iv_field ).
    IF lv_pfx IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_id) = condense( io_ctx->get_val( iv_field ) ).
    IF lv_id IS INITIAL.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Enter a partner number, Emirates ID or trade licence to search.' ).
      RETURN.
    ENDIF.

*   The id-type combobox holds SAP identification types (YFS002 and the
*   like) because the engine's own BP browse searches BUT0ID with them.
*   They map onto ZCL_RAK_BP_SEARCH's own request fields, not onto Notary
*   searchType strings: party identity is resolved in SAP.
    DATA(lv_idtype) = to_upper( io_ctx->get_val( |{ iv_field }_IDTYPE| ) ).

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
    ls_req-nationality = io_ctx->get_val( |{ lv_pfx }NAT| ).

*   A pure partner number is a read, not an identification: BP_QUERY only calls
*   MOI - and only takes its five seconds and its implicit COMMIT - when an
*   Emirates ID is supplied. Browse already resolved who this is, so asking
*   again by number costs nothing.
    IF lv_id CO '0123456789' AND strlen( lv_id ) <= 10.
      ls_req-partner = lv_id.
    ELSEIF lv_idtype = 'TL' OR lv_idtype = 'TRADELICENSE' OR lv_idtype = 'COMPANYBYTL'.
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

    fill_party_form( io_ctx    = io_ctx
                     iv_prefix = lv_pfx
                     is_bp     = ls_bp ).

  ENDMETHOD.


  METHOD fill_party_form.

*   PARTNER and TELEPHONE_NUMBER are the proven component names. Everything else
*   goes through a candidate list, because the entity behind ZCL_RAK_BP_SEARCH
*   holds a person's name in parts on one category and in one field on another.
*
*   Every target below is a seeded field on STP3/STP4. That is not incidental:
*   SET_VAL( ) against a name the journey does not carry is legal and does
*   nothing, so a form filled into names that were never seeded looks in code
*   exactly like a form that filled correctly. Adding a target here means
*   adding a row to ZRAK_NOT_LOAD first.
    io_ctx->set_val( iv_name  = |{ iv_prefix }BP|
                     iv_value = condense( CONV string( is_bp-partner ) ) ).

    DATA(lv_mob) = condense( CONV string( is_bp-telephone_number ) ).
    IF lv_mob IS NOT INITIAL.
      io_ctx->set_val( iv_name = |{ iv_prefix }MOBILE| iv_value = lv_mob ).
    ENDIF.

    DATA(lv_first) = bp_pick( is_bp = is_bp iv_names = 'NAME_FIRST,FIRSTNAME' ).
    DATA(lv_last)  = bp_pick( is_bp = is_bp iv_names = 'NAME_LAST,LASTNAME' ).
    DATA(lv_full)  = bp_pick( is_bp = is_bp
                              iv_names = 'NAME,FULLNAME,NAME_ORG1,PARTNERNAME,BPNAME' ).

*   One field on one category, two on another. Join what is there rather than
*   picking one shape and showing a half name for the other kind of party.
    DATA(lv_name) = COND string(
      WHEN lv_first IS NOT INITIAL AND lv_last IS NOT INITIAL THEN |{ lv_first } { lv_last }|
      WHEN lv_first IS NOT INITIAL                            THEN lv_first
      WHEN lv_last  IS NOT INITIAL                            THEN lv_last
      ELSE lv_full ).

    IF lv_name IS NOT INITIAL.
      io_ctx->set_val( iv_name = |{ iv_prefix }NAME| iv_value = lv_name ).
    ENDIF.

    DATA(lv_email) = bp_pick( is_bp = is_bp
                              iv_names = 'SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS' ).
    IF lv_email IS NOT INITIAL.
      io_ctx->set_val( iv_name = |{ iv_prefix }EMAIL| iv_value = lv_email ).
    ENDIF.

*   Nationality comes back confirmed by MOI on the verified path, so the form
*   shows what was checked rather than what was typed.
    DATA(lv_nat) = bp_pick( is_bp = is_bp iv_names = 'NATIONALITY,NATIO,COUNTRYORIGIN' ).
    IF lv_nat IS NOT INITIAL.
      io_ctx->set_val( iv_name = |{ iv_prefix }NAT| iv_value = lv_nat ).
    ENDIF.

*   A father name and an Arabic full name are deliberately NOT set. Notary's own
*   search returned both; no component on the SAP row has been shown to hold
*   either, and guessing a name would either fail activation or silently fill
*   nothing. The citizen types them, which is what the documented flow says
*   happens when SAP holds no previous data.

  ENDMETHOD.


  METHOD party_prefix.
    DATA(lv_n) = to_upper( iv_name ).
    IF strlen( lv_n ) >= 3.
      DATA(lv_head) = substring( val = lv_n len = 3 ).
      IF lv_head = 'P1_' OR lv_head = 'P2_'.
        rv = lv_head.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD request_id.
    rv = io_ctx->get_val( 'REQUEST_ID' ).
    IF rv IS INITIAL.
      rv = io_ctx->get_param( 'draftid' ).
    ENDIF.
    IF rv IS INITIAL.
      rv = io_ctx->get_param( 'caseid' ).
    ENDIF.
  ENDMETHOD.


  METHOD party_rows.

    DATA(lv_req) = request_id( io_ctx ).
    IF lv_req IS INITIAL.
      RETURN.
    ENDIF.

*   Into a variable first. LOOP AT wants an internal table operand, and a
*   functional method call is not one - unlike READ TABLE or VALUE, which do
*   take it. Same reason for the APPEND LINES OF in ON_RENDER_POPUP( ).
    DATA(lt_all) = NEW zcl_rak_be_not( iv_subservice = mc_sub )->parties( lv_req ).

    LOOP AT lt_all INTO DATA(ls_p).
      IF ( iv_first = abap_true  AND ls_p-first_party  = abap_false )
      OR ( iv_first = abap_false AND ls_p-second_party = abap_false ).
        CONTINUE.
      ENDIF.
      APPEND ls_p TO rt.
    ENDLOOP.

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

*   ---- Service Definition (step 2) --------------------------------------
*
*   SVC_NAME / SVC_DESC / SVC_FEE / SVC_SECONDPARTY are seeded as DISPLAY
*   fields and nothing ever filled them, so the step drew five captions with
*   nothing after the colon. The blueprint has carried the answers all along:
*
*     "englishTitle":"Declaration of a Case Waiver/ Notice Waiver",
*     "englishDescription":"", "feesDetails":{"feeType":"FIXED","feesAmount":75.0}
*
*   Read after SET_SUBSERVICE above, never before - BLUEPRINT( ) keys its cache
*   on the declaration. DESCRIBE_STEP( ) has already fetched it this round trip,
*   so this is a cache hit and costs no extra call.
    DATA(lo_be) = NEW zcl_rak_be_not( iv_subservice = mc_sub ).
    DATA(lv_bp) = lo_be->subservice_json( ).
    IF lv_bp IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_fees,
             fee_type    TYPE string,
             fees_amount TYPE string,
           END OF ty_fees,
           BEGIN OF ty_res,
             english_title       TYPE string, arabic_title       TYPE string,
             english_description TYPE string, arabic_description TYPE string,
             fees_details        TYPE ty_fees,
           END OF ty_res,
           BEGIN OF ty_root, result TYPE ty_res, END OF ty_root.

    DATA ls_bp TYPE ty_root.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_bp
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_bp ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

*   Arabic when the journey is Arabic, English otherwise - the same precedence
*   the repo's PICK( ) uses.
    DATA(lv_ar) = xsdbool( to_upper( io_ctx->get_param( 'lang' ) ) = 'A' ).

    io_ctx->set_val( iv_name  = 'SVC_NAME'
                     iv_value = COND string( WHEN lv_ar = abap_true AND ls_bp-result-arabic_title IS NOT INITIAL
                                             THEN ls_bp-result-arabic_title
                                             ELSE ls_bp-result-english_title ) ).

    io_ctx->set_val( iv_name  = 'SVC_DESC'
                     iv_value = COND string( WHEN lv_ar = abap_true AND ls_bp-result-arabic_description IS NOT INITIAL
                                             THEN ls_bp-result-arabic_description
                                             ELSE ls_bp-result-english_description ) ).

*   The declaration types differ: some are FIXED, some carry no fee block at
*   all. Show the amount when there is one and say so when there is not,
*   rather than leaving the caption bare - a blank fee reads as "not loaded".
    io_ctx->set_val( iv_name  = 'SVC_FEE'
                     iv_value = COND string(
                       WHEN ls_bp-result-fees_details-fees_amount IS NOT INITIAL
                       THEN |AED { ls_bp-result-fees_details-fees_amount }| &&
                            COND string( WHEN ls_bp-result-fees_details-fee_type IS NOT INITIAL
                                         THEN | ({ ls_bp-result-fees_details-fee_type })| )
                       ELSE 'No fee for this declaration' ) ).

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
      RETURN.
    ENDIF.

*   Browse picked a partner. The engine has already written the number into
*   P1_BP / P2_BP and the name into P1_BP_NAME / P2_BP_NAME, then called here -
*   but the form also wants the mobile, the nationality and the email, and the
*   BP dialog's hit list carries none of them.
*
*   So read the partner back BY NUMBER. That is a plain BP_QUERY read: MOI is
*   called only when an Emirates ID is supplied, so this costs neither the five
*   seconds nor the implicit COMMIT that the Emirates ID path does. It also
*   means Browse and Search leave the form in exactly the same state, which is
*   the whole point of routing both through FILL_PARTY_FORM( ).
    DATA(lv_pfx) = party_prefix( iv_field ).
    IF lv_pfx IS INITIAL OR to_upper( iv_field ) <> |{ lv_pfx }BP|.
      RETURN.
    ENDIF.

    DATA(lv_bp) = condense( io_ctx->get_val( iv_field ) ).
    IF lv_bp IS INITIAL OR lv_bp CN '0123456789'.
      RETURN.
    ENDIF.

    DATA ls_req TYPE zcl_rak_bp_search=>ty_req.
    ls_req-partner = lv_bp.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

    READ TABLE ls_res-rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc = 0.
      fill_party_form( io_ctx = io_ctx iv_prefix = lv_pfx is_bp = ls_bp ).
      RETURN.
    ENDIF.

*   No row by number. The name the BP dialog already resolved is still better
*   than an empty form, so keep that much rather than discarding it.
    DATA(lv_nm) = io_ctx->get_val( |{ iv_field }_NAME| ).
    IF lv_nm IS NOT INITIAL.
      io_ctx->set_val( iv_name = |{ lv_pfx }NAME| iv_value = lv_nm ).
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


  METHOD zif_rak_journey_logic~render_field.

*   Everything except the two party lists goes back to the base, which is what
*   keeps the payment card working - the base claims PAYFEE here, and a
*   redefinition that forgets to call it takes the pay button off the journey.
    DATA(lv_n) = to_upper( is_field-name ).
    IF lv_n <> 'PARTY1' AND lv_n <> 'PARTY2'.
      rv_done = super->zif_rak_journey_logic~render_field( io_ctx   = io_ctx
                                                           io_form  = io_form
                                                           is_field = is_field ).
      RETURN.
    ENDIF.

*   The list is claimed rather than left to the engine's TABLE renderer for one
*   reason: the Action column. The live screen puts a view icon and a contact
*   icon on every row, and a generic table has no way to express a per-row
*   button - the column spec carries names, labels and types, not events.
*
*   Everything else about it stays the engine's shape, including the column
*   labels, which still come from the field's own DEFAULT_VAL spec.
    DATA(lv_first) = xsdbool( lv_n = 'PARTY1' ).
    mv_party_pfx = COND string( WHEN lv_first = abap_true THEN 'P1_' ELSE 'P2_' ).

    DATA(lo_box) = io_form->vbox( class = 'sapUiSmallMarginBottom' ).
    lo_box->label( text = is_field-label ).

    DATA(lt_rows) = party_rows( io_ctx = io_ctx iv_first = lv_first ).

    IF lt_rows IS INITIAL.
*     Say which of the two is empty. "No data" on two identical tables one step
*     apart tells the citizen nothing about what they are supposed to do next.
      lo_box->message_strip(
        text     = COND string( WHEN lv_first = abap_true
                                THEN 'No first party yet. Search for a partner below and press Add Party.'
                                ELSE 'No second party yet. Search for a partner below and press Add Party.' )
        type     = 'Information'
        showicon = abap_true ).
      rv_done = abap_true.
      RETURN.
    ENDIF.

    DATA(lo_tab) = lo_box->table( ).
    DATA(lo_col) = lo_tab->columns( ).
    lo_col->column( )->text( 'Party Name' ).
    lo_col->column( )->text( 'Mobile Number' ).
    lo_col->column( )->text( 'Nationality' ).
    lo_col->column( halign = 'End' )->text( 'Action' ).

    DATA(lo_items) = lo_tab->items( ).
    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(lo_cells) = lo_items->column_list_item( )->cells( ).
      lo_cells->text( ls_row-party_name ).
      lo_cells->text( ls_row-mobile ).
      lo_cells->text( ls_row-nationality ).
      DATA(lo_act) = lo_cells->hbox( justifycontent = 'End' ).
      lo_act->button( icon    = 'sap-icon://display'
                      tooltip = 'View party'
                      type    = 'Transparent'
                      press   = io_ctx->event( |PVIEW_{ ls_row-party_id }| ) ).
      lo_act->button( icon    = 'sap-icon://email'
                      tooltip = 'Contact details'
                      type    = 'Transparent'
                      press   = io_ctx->event( |PCONT_{ ls_row-party_id }| ) ).
    ENDLOOP.

    rv_done = abap_true.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.

    super->zif_rak_journey_logic~on_render_end( io_ctx = io_ctx io_view = io_view ).

*   MV_PARTY_PFX is set by RENDER_FIELD( ) when it draws PARTY1 or PARTY2, so
*   this button appears under the party form and nowhere else. The step index
*   would not do: GET_STEP( ) answers a number, and the numbers move whenever a
*   declaration adds or drops a step.
    IF mv_party_pfx IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_bar) = io_view->hbox( justifycontent = 'End' class = 'sapUiSmallMarginTop' ).
    lo_bar->button( text  = 'Add Party'
                    icon  = 'sap-icon://add'
                    type  = 'Emphasized'
                    press = io_ctx->event( |PADD_{ mv_party_pfx }| ) ).

    CLEAR mv_party_pfx.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.

*   The base owns PAYNOW / PAYPOLL here, so it goes first and unconditionally.
*   This hook is the sink for every handler-drawn control, not only popups.
    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).

    DATA(lv_e) = to_upper( iv_event ).

    IF strlen( lv_e ) > 5 AND substring( val = lv_e len = 5 ) = 'PADD_'.
      add_party( io_ctx = io_ctx iv_prefix = substring( val = lv_e off = 5 ) ).
      RETURN.
    ENDIF.

*   The view and contact dialogs carry the party id in the event, which is what
*   lets them stay stateless: the id survives the round trip inside the popup
*   id, and the dialog re-reads the party from the API rather than from
*   anything held here.
    IF strlen( lv_e ) > 6 AND substring( val = lv_e len = 6 ) = 'PVIEW_'.
      io_ctx->open_popup( lv_e ).
      RETURN.
    ENDIF.

    IF strlen( lv_e ) > 6 AND substring( val = lv_e len = 6 ) = 'PCONT_'.
      io_ctx->open_popup( lv_e ).
      RETURN.
    ENDIF.

    IF lv_e = 'PCLOSE'.
      io_ctx->close_popup( ).
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.

    super->zif_rak_journey_logic~on_render_popup( io_ctx   = io_ctx
                                                  io_popup = io_popup
                                                  iv_id    = iv_id ).

    DATA(lv_id) = to_upper( iv_id ).

    DATA(lv_view) = xsdbool( strlen( lv_id ) > 6 AND substring( val = lv_id len = 6 ) = 'PVIEW_' ).
    DATA(lv_cont) = xsdbool( strlen( lv_id ) > 6 AND substring( val = lv_id len = 6 ) = 'PCONT_' ).

    IF lv_view = abap_false AND lv_cont = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_pid) = substring( val = lv_id off = 6 ).

*   Re-read rather than remember. The party was added through the API and the
*   API is the only thing that knows what it holds now - a contact edited on
*   another device, or an officer's correction, would not reach a copy kept
*   here. Both sides of the request are searched because the popup id carries
*   the party, not which list it was pressed from.
    DATA(lt_both) = party_rows( io_ctx = io_ctx iv_first = abap_true ).
    DATA(lt_second) = party_rows( io_ctx = io_ctx iv_first = abap_false ).
    APPEND LINES OF lt_second TO lt_both.

    READ TABLE lt_both INTO DATA(ls_p) WITH KEY party_id = lv_pid.
    IF sy-subrc <> 0.
      DATA(lo_miss) = io_popup->dialog( title = 'Party' contentwidth = '30rem' ).
      lo_miss->content( )->vbox( class = 'sapUiMediumMargin'
        )->message_strip( text     = |Party { lv_pid } is no longer on this request.|
                          type     = 'Warning'
                          showicon = abap_true ).
      lo_miss->buttons( )->button( text = 'Close' press = io_ctx->event( 'PCLOSE' ) ).
      RETURN.
    ENDIF.

    DATA(lo_dlg) = io_popup->dialog(
      title        = COND string( WHEN lv_cont = abap_true THEN 'Contact details' ELSE 'Party details' )
      contentwidth = '34rem' ).

*   ns = 'form' and not a positional argument: SimpleForm's content aggregation
*   lives in the form namespace, and the engine's own step renderer does the
*   same thing at ZCL_RAK_JOURNEY_RENDER's simple_form( ) call.
    DATA(lo_form) = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin'
      )->simple_form( layout   = 'ResponsiveGridLayout'
                      editable = abap_false )->content( ns = 'form' ).

*   Read-only throughout, and that is the point of a view dialog: the party was
*   identified through ZCL_RAK_BP_SEARCH and confirmed by MOI, so letting it be
*   retyped here would put a name in front of the officer that nothing checked.
*   A party that is genuinely wrong is removed and added again.
    IF lv_cont = abap_false.
      lo_form->label( text = 'Party Name' ).
      lo_form->text( COND string( WHEN ls_p-party_name IS NOT INITIAL THEN ls_p-party_name ELSE '-' ) ).

      IF ls_p-name_ar IS NOT INITIAL.
        lo_form->label( text = 'Name (Arabic)' ).
        lo_form->text( ls_p-name_ar ).
      ENDIF.

      lo_form->label( text = 'Nationality' ).
      lo_form->text( COND string( WHEN ls_p-nationality IS NOT INITIAL THEN ls_p-nationality ELSE '-' ) ).

      lo_form->label( text = 'Identification' ).
      lo_form->text( COND string( WHEN ls_p-id_number IS NOT INITIAL THEN ls_p-id_number ELSE '-' ) ).

      IF ls_p-party_kind IS NOT INITIAL.
        lo_form->label( text = 'Party Type' ).
        lo_form->text( ls_p-party_kind ).
      ENDIF.

      lo_form->label( text = 'Party Id' ).
      lo_form->text( ls_p-party_id ).
    ENDIF.

    lo_form->label( text = 'Mobile Number' ).
    lo_form->text( COND string( WHEN ls_p-mobile IS NOT INITIAL THEN ls_p-mobile ELSE '-' ) ).

    lo_form->label( text = 'Email' ).
    lo_form->text( COND string( WHEN ls_p-email IS NOT INITIAL THEN ls_p-email ELSE '-' ) ).

    lo_dlg->buttons( )->button( text  = 'Close'
                                type  = 'Emphasized'
                                press = io_ctx->event( 'PCLOSE' ) ).

  ENDMETHOD.


  METHOD add_party.

    DATA(lv_req) = request_id( io_ctx ).
    IF lv_req IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = 'The application has no request yet. Complete the earlier steps first.' ).
      RETURN.
    ENDIF.

*   Refuse an empty add rather than posting a party with no name. The API would
*   accept it and the officer would receive a blank row.
    IF io_ctx->get_val( |{ iv_prefix }BP| ) IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = 'Search for a partner before adding the party.' ).
      RETURN.
    ENDIF.

*   COMMIT_STEP( ) is the whole post. ON_BEFORE_FIELDS( ) below renames the form
*   onto the party_* payload the backend expects, so the add and the Next button
*   travel the same road - which is what stops a party added by button from
*   being shaped differently to one added by advancing the step.
    IF io_ctx->commit_step( ) = abap_false.
      RETURN.
    ENDIF.

*   Clear the form so the next party starts empty. The list above it is redrawn
*   from the API on the next render, so the party that was just added appears
*   there rather than staying in the fields.
    io_ctx->set_val( iv_name = |{ iv_prefix }BP|     iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }NAME|   iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }MOBILE| iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }NAT|    iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }EMAIL|  iv_value = '' ).

    io_ctx->add_msg( iv_type = 'Success' iv_text = 'Party added.' ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.

    super->zif_rak_journey_logic~on_before_fields( EXPORTING io_ctx    = io_ctx
                                                  CHANGING  ct_fields = ct_fields ).

*   The form is named for the step it sits on - P1_NAME, P2_MOBILE - and the
*   backend is named for the API - party_fullName, party_mobileNumber, bpId.
*   Neither name should move: the field names are what the seed, the render and
*   ZRAK_T_JNY_RULE all agree on, and the payload names are Notary's contract.
*   So they are translated here, once, at the last point before the adapter
*   sees them.
*
*   Both prefixes are handled unconditionally. Only one party step commits at a
*   time, so the other prefix simply is not in the payload, and branching on
*   which one would need a step name this hook is not given.
    DATA(lt_map) = VALUE zif_rak_journey_backend=>tt_field(
      ( name = 'BP'     value = 'bpId' )
      ( name = 'NAME'   value = 'party_fullName' )
      ( name = 'MOBILE' value = 'party_mobileNumber' )
      ( name = 'NAT'    value = 'party_nationality' )
      ( name = 'EMAIL'  value = 'party_email' ) ).

    LOOP AT lt_map INTO DATA(ls_map).
      DO 2 TIMES.
        DATA(lv_src) = |P{ sy-index }_{ ls_map-name }|.
        READ TABLE ct_fields INTO DATA(ls_f) WITH KEY name = lv_src.
        IF sy-subrc <> 0 OR ls_f-value IS INITIAL.
          CONTINUE.
        ENDIF.

*       Overwrite an existing entry rather than appending a second one with the
*       same name. FIELD( ) in the backend reads the FIRST match, so a duplicate
*       does not merely waste a row - it decides the value, and which of the two
*       wins depends on insertion order.
        READ TABLE ct_fields ASSIGNING FIELD-SYMBOL(<t>) WITH KEY name = ls_map-value.
        IF sy-subrc = 0.
          <t>-value = ls_f-value.
        ELSE.
          APPEND VALUE #( name = ls_map-value value = ls_f-value ) TO ct_fields.
        ENDIF.
      ENDDO.
    ENDLOOP.

*   PARTY1 posts nothing unless told to. The applicant is already the first
*   party on the draft, so the backend skips the step - but a journey where the
*   citizen adds a first party by hand has to be able to say so, and this flag
*   is the switch ZCL_RAK_BE_NOT already reads for it.
    IF line_exists( ct_fields[ name = 'bpId' ] ).
      READ TABLE ct_fields ASSIGNING FIELD-SYMBOL(<force>) WITH KEY name = 'party_forcePost'.
      IF sy-subrc = 0.
        <force>-value = 'X'.
      ELSE.
        APPEND VALUE #( name = 'party_forcePost' value = 'X' ) TO ct_fields.
      ENDIF.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
