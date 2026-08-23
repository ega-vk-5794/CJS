*&---------------------------------------------------------------------*
*& ZCL_RAK_NOT_APPROVAL_LOGIC
*&
*& Handler for the Notary declaration journeys (NOT_* family).
*& Inherits ZCL_RAK_JOURNEY_LOGIC and redefines only what Notary needs:
*&   on_value_help      - resolves every list live from the Notary static
*&                        endpoints; nothing is held here
*&   get_table          - RO_PANEL body for the legal text, from the API
*&   on_custom_validate - Notary field checks; CALLS SUPER so the base
*&                        payment PAID-gate is preserved
*&   render_field       - claims PARTY1/PARTY2 to draw the list with its
*&                        per-row View and Contact actions; CALLS SUPER for
*&                        every other field so the base keeps PAYFEE
*&   on_render_end      - the Search Partner and Add Party buttons under the
*&                        party form
*&   on_render_popup    - the partner search, and the View and Contact
*&                        dialogs; CALLS SUPER
*&   on_popup_event     - BPP_* to the partner search, then PADD_ / PVIEW_ /
*&                        PCONT_; CALLS SUPER so the base keeps PAYNOW and
*&                        PAYPOLL
*&   on_before_fields   - renames the P1_/P2_ form onto the party_* payload
*&                        the Notary API expects and drops the search
*&                        criteria; CALLS SUPER so the base still strips PAY_*
*&
*& THE PARTNER SEARCH IS ZCL_RAK_BP_POPUP - the same dialog LESSOR and LESSEE
*& use in ZCL_RAK_TEST_ALL_LOGIC, opened per party with SUBJECT = P1 / P2. It
*& replaced an ftype SEARCH field, and ON_SEARCH( ) went with it.
*&
*& The reason is not tidiness. An ftype SEARCH field is one input and an
*& ID-type combobox, with nowhere to ask for a date of birth or a nationality
*& - and on the Emirates ID path those two are not search narrowing, they ARE
*& the verification: CALL_MOI sends them to MOI and rejects the partner when
*& either disagrees. So the search called MOI with a blank date of birth and
*& a nationality read off a form field the citizen had not reached yet, and
*& the one check a notary party exists to pass was asked with no answer in it.
*& It came back clean, every time, and said nothing.
*&
*& The popup asks Search By first and then exactly what that type needs, and
*& writes all five results - <S>_PARTNER, <S>_NAME, <S>_PHONE, <S>_EMAIL and
*& the <S>_NAT that was typed to find them. That is the whole add-party form,
*& which is why FILL_PARTY_FORM( ) and BP_PICK( ) are gone as well.
*&
*& NOT redefined on purpose: on_before_post (the base strips PAY_* there),
*& wants_feedback (feedback stays automatic).
*&---------------------------------------------------------------------*
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start    REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help      REDEFINITION.
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

*   The partner dialog: one event per party, and the field that says which one
*   is open. They are NOT prefixed BPP_ - that prefix belongs to
*   ZCL_RAK_BP_POPUP's own events and ON_POPUP_EVENT( ) routes anything matching
*   it straight to the dialog, so an open event called BPP_OPEN_P1 would be
*   handed to a popup that has never heard of it and silently dropped.
    CONSTANTS c_evt_bp1    TYPE string VALUE 'BP_OPEN_P1'.
    CONSTANTS c_evt_bp2    TYPE string VALUE 'BP_OPEN_P2'.

*   Which party's dialog is open. ON_POPUP_EVENT( ) is handed the event and not
*   the popup id, so without this the dialog would have to encode the party into
*   every event name and then parse its own events to find out who it is.
*   Scratch rather than a configured field: SET_VAL and GET_VAL fall through for
*   a name the journey does not carry, and nothing BINDs this one - which is the
*   difference between it and the nine <SUBJECT>_* fields, every one of which
*   has to be real.
    CONSTANTS c_bp_subject TYPE string VALUE 'BP_ACTIVE_SUBJECT'.

*   The four groups the View dialog draws, and the one the Contact dialog keeps.
*   Constants because the Contact dialog filters on C_GRP_CONTACT and a literal
*   there would be a heading and a filter that can drift apart silently - the
*   dialog would simply come up empty.
    CONSTANTS c_grp_identity TYPE string VALUE 'Identity'.
    CONSTANTS c_grp_contact  TYPE string VALUE 'Contact'.
    CONSTANTS c_grp_address  TYPE string VALUE 'Address'.
    CONSTANTS c_grp_docs     TYPE string VALUE 'Identification'.

*   Per-party search rules, and the title that says which party the dialog is
*   for. Both parties run the LIGHT search - see BP_OPTS( ), which is the one
*   place to change it.
    METHODS bp_opts
      IMPORTING iv_subject TYPE string
      RETURNING VALUE(rs)  TYPE zcl_rak_bp_search=>ty_req.
    METHODS bp_title
      IMPORTING iv_subject TYPE string
      RETURNING VALUE(rv)  TYPE string.

*   One business partner, read for DISPLAY. See the method for why it never
*   calls MOI.
    METHODS bp_read
      IMPORTING iv_id    TYPE string
      EXPORTING es_bp    TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner
                ev_found TYPE abap_bool.

*   The business partner as rows to draw: a group heading, a label and a value,
*   blanks already dropped. A table rather than direct rendering so the View and
*   Contact dialogs can be the same read narrowed differently.
    TYPES: BEGIN OF ty_kv,
             grp   TYPE string,
             label TYPE string,
             value TYPE string,
           END OF ty_kv,
           tt_kv TYPE STANDARD TABLE OF ty_kv WITH EMPTY KEY.

    METHODS bp_detail
      IMPORTING is_bp     TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner
      RETURNING VALUE(rt) TYPE tt_kv.

    METHODS add_kv
      IMPORTING iv_grp TYPE string
                iv_lbl TYPE string
                iv_val TYPE string
      CHANGING  ct     TYPE tt_kv.

*   1988-07-13T00:00:00 or 19880713, both to 13/07/1988.
    METHODS fmt_date
      IMPORTING iv        TYPE string
      RETURNING VALUE(rv) TYPE string.

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


  METHOD bp_opts.

*   Per-party search rules, handed to ZCL_RAK_BP_POPUP as a TEMPLATE. The popup
*   fills the five identity fields from what the citizen typed - IDTYPE, EID,
*   TRADE_LICENCE, DOB, NATIONALITY - and takes everything else from here.
*
*   ALL FOUR ID TYPES ARE SUPPORTED and none of them is special-cased here. The
*   popup offers Emirates ID, Passport, Unified ID and Trade Licence, and maps
*   each onto the request itself: a trade licence goes in TRADE_LICENCE, the
*   other three in EID, which is what the underlying OData filter is - the same
*   read as
*
*     /sap/opu/odata/sap/ZEGA_BP_SRV/BusinessPartnerSet?$filter=(EId eq '...')
*
*   only through ZCL_RAK_BP_SEARCH rather than over HTTP, so the expiry rules and
*   the findings come with it.
*
*   THE LIGHT SEARCH. NO_MOI_CALL, findings as warnings, a capped hit list -
*   the LESSEE template in ZCL_RAK_TEST_ALL_LOGIC, and picked for the same
*   reasons.
*
*   NO_MOI_CALL suppresses the MOI call itself, and that is worth doing on its
*   own terms and not only for speed: ZCRM_MOI_CR_UPD_MASS WRITES, it costs at
*   least five seconds by construction, and its WAIT UP TO ends the LUW and
*   forces an implicit COMMIT of whatever the journey had open mid-step. A party
*   step that is halfway through a draft does not want that.
    rs-no_moi_call = abap_true.

*   Findings still REACH the citizen - every message the search returns is shown
*   - but an expired trade licence reports as a warning and lets the partner
*   through rather than ending the search. 'W' is that decision, and this method
*   is where it is made.
    rs-msg_type    = 'W'.

*   A picker does not need a hundred rows. The popup takes the first hit.
    rs-max_rows    = 20.

*   TO GO BACK TO FULL VERIFICATION, delete the three lines above. The empty
*   template is the full-strength one: MOI is called, the BP is updated from it,
*   and a date of birth or nationality that disagrees is an error - which is what
*   the dialog asks for those two on the Emirates ID branch FOR.
*
*   There is a halfway house and it is the distinction that costs the most time:
*
*     NO_MOI_CALL       (here)  MOI is never called. Nothing read, nothing
*                               written back.
*     SKIP_MOI_MISMATCH         MOI IS called and the BP IS UPDATED from it.
*                               Only a DOB or nationality mismatch stops
*                               rejecting.
*
*   They are not degrees of one thing. SKIP_MOI_MISMATCH still pays the whole
*   cost of the call, including the implicit COMMIT; pick it when you WANT the BP
*   refreshed from MOI and only want to be lenient about the comparison.
*
*   Both parties run the same rules today, which is why nothing branches on the
*   subject. The parameter is here so that a declaration whose second party is
*   merely named rather than identified has somewhere to say so.
    CASE to_upper( iv_subject ).
      WHEN 'P1'.
*       The confessor. Same rules as P2 for now.
      WHEN 'P2'.
*       The party confessed for. Same rules as P1 for now.
      WHEN OTHERS.
*       ZP28 is deliberately not reachable from here. It makes BP_QUERY inject
*       TEMP_CASETYPE = 'ZP28' by setting paging SKIP and TOP to 999999999, which
*       is how that case type reaches partners of type YP0001. It is not a tuning
*       switch and a journey that is not ZP28 must leave it false.
    ENDCASE.

  ENDMETHOD.


  METHOD bp_title.
*   Which party the dialog is for. Without it both parties open a dialog that
*   looks identical, and a citizen halfway through the second one has no way to
*   tell which they are filling in.
    rv = SWITCH string( to_upper( iv_subject )
           WHEN 'P1' THEN 'Partner Search - First Party'
           WHEN 'P2' THEN 'Partner Search - Second Party'
           ELSE 'Partner Search' ).
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

*   NOTHING FOR THE PARTY FORM, and that is a deletion rather than an omission.
*
*   This used to re-read the partner BY NUMBER whenever P1_BP or P2_BP changed,
*   because ftype SEARCH's Browse button wrote only the number and the name while
*   the form also wanted the mobile, the nationality and the email.
*
*   ZCL_RAK_BP_POPUP writes all five itself - PARTNER, NAME, PHONE and EMAIL off
*   the row it found, and the NAT the citizen typed to find it. A second read
*   would be a second opinion on a partner already resolved, and one more
*   BP_QUERY against a field the citizen cannot even edit.

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
*   these buttons appear under the party form and nowhere else. The step index
*   would not do: GET_STEP( ) answers a number, and the numbers move whenever a
*   declaration adds or drops a step.
    IF mv_party_pfx IS INITIAL.
      RETURN.
    ENDIF.

*   'P1_' -> 'P1'. The SUBJECT is the prefix without the underscore, because
*   ZCL_RAK_BP_POPUP builds <SUBJECT>_<SUFFIX> and would otherwise go looking
*   for P1__IDNUM.
    DATA(lv_subj) = substring( val = mv_party_pfx len = 2 ).

    DATA(lo_bar) = io_view->hbox( justifycontent = 'End' class = 'sapUiSmallMarginTop' ).

*   Search first, then Add - the order the step is actually used in. The label
*   changes once a partner is on the form so that pressing it again reads as
*   correcting a choice rather than starting over; the dialog itself shows the
*   partner it already found and offers Resume Search.
    lo_bar->button(
      text  = COND string( WHEN io_ctx->get_val( |{ mv_party_pfx }PARTNER| ) IS INITIAL
                           THEN 'Search Partner' ELSE 'Change Partner' )
      icon  = 'sap-icon://search'
      press = io_ctx->event( COND string( WHEN lv_subj = 'P1' THEN c_evt_bp1 ELSE c_evt_bp2 ) ) ).

    lo_bar->button( text  = 'Add Party'
                    icon  = 'sap-icon://add'
                    type  = 'Emphasized'
                    class = 'sapUiSmallMarginBegin'
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

*   ---- the partner dialog's OWN events, before anything else ----------
*   Search, Resume Search and Close all arrive as BPP_*. Matched on the prefix so
*   the dialog is only constructed for its own events, and constructed fresh each
*   time: it is stateless - every value it touches is a model field - so a new
*   instance per round trip is the same instance.
*
*   Wiring the open and not the answer is a dispatch gap that looks exactly like
*   a broken dialog: it draws correctly and then Search does nothing.
    IF lv_e CP 'BPP_*'.
      DATA(lv_subj) = to_upper( io_ctx->get_val( c_bp_subject ) ).
      IF lv_subj IS INITIAL.
        RETURN.
      ENDIF.
      NEW zcl_rak_bp_popup( io_ctx     = io_ctx
                            iv_subject = lv_subj
                            iv_title   = bp_title( lv_subj )
                            is_search  = bp_opts( lv_subj ) )->handle( iv_event ).
      RETURN.
    ENDIF.

*   ---- opening it -----------------------------------------------------
*   The party goes into BOTH the subject field and the popup id. The field is
*   what the BPP_* branch above reads; the id is what ON_RENDER_POPUP( ) reads,
*   so a render arriving without an event still draws the right party.
    IF lv_e = c_evt_bp1 OR lv_e = c_evt_bp2.
      DATA(lv_open) = COND string( WHEN lv_e = c_evt_bp1 THEN 'P1' ELSE 'P2' ).
      io_ctx->set_val( iv_name = c_bp_subject iv_value = lv_open ).
      io_ctx->open_popup( |BP_{ lv_open }| ).
      RETURN.
    ENDIF.

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

*   ---- the partner search --------------------------------------------
*   One dialog per party. Same class LESSOR and LESSEE use in
*   ZCL_RAK_TEST_ALL_LOGIC, and the subject comes off the POPUP ID rather than
*   the subject field: a render that arrives without an event - a resumed draft,
*   a re-render after a validation message - still draws the right party.
    IF lv_id CP 'BP_*'.
      DATA(lv_subj) = substring_after( val = lv_id sub = 'BP_' ).
      NEW zcl_rak_bp_popup( io_ctx     = io_ctx
                            iv_subject = lv_subj
                            iv_title   = bp_title( lv_subj )
                            is_search  = bp_opts( lv_subj ) )->render( io_popup ).
      RETURN.
    ENDIF.

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
      contentwidth = '42rem' ).

    DATA(lo_box) = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   ---- the business partner behind the party --------------------------
*   The Notary party row carries six values. The BUSINESS PARTNER carries the
*   record the citizen was identified from - names in both languages, the three
*   identity documents and their expiry dates, nationality, date of birth,
*   address, every way of contacting them - and that is what View is for. A
*   dialog that can only repeat the three columns of the list above it is not
*   worth opening.
*
*   Read by the party's own ID NUMBER, which is the Emirates ID for a person and
*   the trade licence for a company - the same
*   BusinessPartnerSet?$filter=(EId eq '...') the portal does, through
*   ZCL_RAK_BP_SEARCH instead of over HTTP. NO_MOI_CALL on that read is not an
*   optimisation here, it is a correctness point: this is a VIEW. Opening it
*   must not call MOI, must not update the business partner, and must not end
*   the LUW with the implicit COMMIT that MOI's WAIT UP TO forces.
    bp_read( EXPORTING iv_id    = ls_p-id_number
             IMPORTING es_bp    = DATA(ls_bp)
                       ev_found = DATA(lv_found) ).

    IF lv_found = abap_false.
*     Say so rather than drawing a half-empty dialog. Then show what the Notary
*     row does hold, which is better than nothing and is all this dialog ever
*     showed before.
      lo_box->message_strip(
        text     = COND string(
          WHEN ls_p-id_number IS INITIAL
          THEN 'This party has no identification number, so the business partner cannot be read.'
          ELSE |No business partner found for { ls_p-id_number }. Showing what the request holds.| )
        type     = 'Information'
        showicon = abap_true ).

      DATA(lo_fb) = lo_box->simple_form( layout   = 'ResponsiveGridLayout'
                                         editable = abap_false )->content( ns = 'form' ).

      IF lv_cont = abap_false.
        lo_fb->label( text = 'Party Name' ).
        lo_fb->text( zcl_rak_journey_util=>esc(
          COND string( WHEN ls_p-party_name IS NOT INITIAL THEN ls_p-party_name ELSE '-' ) ) ).

        IF ls_p-name_ar IS NOT INITIAL.
          lo_fb->label( text = 'Name (Arabic)' ).
          lo_fb->text( zcl_rak_journey_util=>esc( ls_p-name_ar ) ).
        ENDIF.

        lo_fb->label( text = 'Nationality' ).
        lo_fb->text( zcl_rak_journey_util=>esc(
          COND string( WHEN ls_p-nationality IS NOT INITIAL THEN ls_p-nationality ELSE '-' ) ) ).

        lo_fb->label( text = 'Identification' ).
        lo_fb->text( zcl_rak_journey_util=>esc(
          COND string( WHEN ls_p-id_number IS NOT INITIAL THEN ls_p-id_number ELSE '-' ) ) ).

        IF ls_p-party_kind IS NOT INITIAL.
          lo_fb->label( text = 'Party Type' ).
          lo_fb->text( zcl_rak_journey_util=>esc( ls_p-party_kind ) ).
        ENDIF.

        lo_fb->label( text = 'Party Id' ).
        lo_fb->text( zcl_rak_journey_util=>esc( ls_p-party_id ) ).
      ENDIF.

      lo_fb->label( text = 'Mobile Number' ).
      lo_fb->text( zcl_rak_journey_util=>esc(
        COND string( WHEN ls_p-mobile IS NOT INITIAL THEN ls_p-mobile ELSE '-' ) ) ).

      lo_fb->label( text = 'Email' ).
      lo_fb->text( zcl_rak_journey_util=>esc(
        COND string( WHEN ls_p-email IS NOT INITIAL THEN ls_p-email ELSE '-' ) ) ).

      lo_dlg->buttons( )->button( text  = 'Close'
                                  type  = 'Emphasized'
                                  press = io_ctx->event( 'PCLOSE' ) ).
      RETURN.
    ENDIF.

*   ---- the business partner, grouped ----------------------------------
*   Read-only throughout, and that is the point of a view dialog: the party was
*   identified through ZCL_RAK_BP_SEARCH, so letting it be retyped here would put
*   a name in front of the officer that nothing checked. A party that is
*   genuinely wrong is removed and added again.
    DATA(lt_kv) = bp_detail( ls_bp ).

*   Contact is the same read, narrowed. Two dialogs over one method rather than
*   two methods that have to be kept saying the same thing.
    IF lv_cont = abap_true.
      DELETE lt_kv WHERE grp <> c_grp_contact.
    ENDIF.

    IF lt_kv IS INITIAL.
      lo_box->message_strip( text     = 'The business partner record holds nothing to show here.'
                             type     = 'Information'
                             showicon = abap_true ).
    ENDIF.

    DATA lv_grp  TYPE string.
    DATA lo_form TYPE REF TO z2ui5_cl_xml_view.

    LOOP AT lt_kv INTO DATA(ls_kv).
*     A new SimpleForm per group. One form with headings inside it would put the
*     heading in a value cell, because the grid pairs every child with the one
*     before it.
      IF ls_kv-grp <> lv_grp.
        lv_grp  = ls_kv-grp.
        lo_form = lo_box->simple_form( layout    = 'ResponsiveGridLayout'
                                       editable  = abap_false
                                       columnsxl = '2' columnsl = '2' columnsm = '1'
                              )->content( ns = 'form' ).
        lo_form->title( zcl_rak_journey_util=>esc( lv_grp ) ).
      ENDIF.
      lo_form->label( text = ls_kv-label ).
      lo_form->text( zcl_rak_journey_util=>esc( ls_kv-value ) ).
    ENDLOOP.

    lo_dlg->buttons( )->button( text  = 'Close'
                                type  = 'Emphasized'
                                press = io_ctx->event( 'PCLOSE' ) ).

  ENDMETHOD.


  METHOD bp_read.

    CLEAR: es_bp, ev_found.

    IF iv_id IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_req TYPE zcl_rak_bp_search=>ty_req.

*   A pure number that is short enough to be a partner is read as one. Anything
*   else is an identification document and goes in EID - which is the field the
*   underlying filter is built from, and the same place ZCL_RAK_BP_POPUP puts a
*   passport and a unified number.
    DATA(lv_id) = condense( iv_id ).
    IF lv_id CO '0123456789' AND strlen( lv_id ) <= 10.
      ls_req-partner = lv_id.
    ELSE.
      ls_req-eid = lv_id.
    ENDIF.

*   A view must not verify. See the note at the call site: MOI writes, waits and
*   commits, and none of that belongs behind an eye icon.
    ls_req-no_moi_call = abap_true.
    ls_req-msg_type    = 'W'.
    ls_req-max_rows    = 1.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

*   Findings are deliberately NOT shown. This dialog reports what the record
*   says, and an expired Emirates ID is already visible in the record as a
*   date - raising it as a message on a read-only view would read as a refusal
*   the citizen cannot act on from here.
    READ TABLE ls_res-rows INTO es_bp INDEX 1.
    ev_found = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD bp_detail.

*   The business partner as the citizen should see it, in four groups, blanks
*   dropped. Every value goes through BP_PICK( ) - see that method for why the
*   component names cannot simply be written down - and the candidate lists here
*   are derived from the OData property names the service actually returns:
*
*     BPId, Category, CategoryDesc, SalutationDesc, EnglishFullName,
*     ArabicFullName, CompanyName1, EId, UId, Passport, TradeLicense, IdType,
*     IdNumber, Nationality, NationalityDesc, DateOfBirth, Age, GenderDesc,
*     MaritalStatusDesc, Religion, BirthPlace, Occupation, MobileNumber,
*     TelephoneNumber, EmailId, FaxNumber, CorrLanguage, Country, EmirateDesc,
*     City, Area, Street, HouseNumber, Pobox, ValidFrom, ValidTo,
*     PassValidFrom, PassValidTo, Visa, Visaexpdt, IsBlocked, DataOrigin
*
*   Each list carries the snake_case form the ABAP structure most likely uses and
*   the squashed form as a second guess, because ZCL_ZEGA_BP_MPC_EXT is outside
*   this repo and its component names cannot be read from here. A name that is
*   wrong in both costs one missing row on a dialog, which is visible; a name
*   hard-coded wrong in a decision would not be.
    DATA(lv_name_en) = bp_pick( is_bp = is_bp
                                iv_names = 'ENGLISH_FULL_NAME,ENGLISHFULLNAME,FULLNAME,NAME' ).
    DATA(lv_name_ar) = bp_pick( is_bp = is_bp iv_names = 'ARABIC_FULL_NAME,ARABICFULLNAME' ).
    DATA(lv_org)     = bp_pick( is_bp = is_bp
                                iv_names = 'COMPANY_NAME1,COMPANYNAME1,NAME_ORG1' ).

*   An organisation has no English full name, so fall back to the company name
*   rather than leaving the first row of the dialog blank.
    IF lv_name_en IS INITIAL.
      lv_name_en = lv_org.
    ENDIF.

    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Name'              iv_val = lv_name_en CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Name (Arabic)'     iv_val = lv_name_ar CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Company'
            iv_val = COND string( WHEN lv_org <> lv_name_en THEN lv_org ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Salutation'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'SALUTATION_DESC,SALUTATIONDESC' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Partner'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'PARTNER,BP_ID,BPID' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Category'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'CATEGORY_DESC,CATEGORYDESC' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Nationality'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'NATIONALITY_DESC,NATIONALITYDESC,NATIONALITY' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Date of Birth'
            iv_val = fmt_date( bp_pick( is_bp = is_bp
                                        iv_names = 'DATE_OF_BIRTH,DATEOFBIRTH' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Age'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'AGE' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Gender'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'GENDER_DESC,GENDERDESC' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Marital Status'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'MARITAL_STATUS_DESC,MARITALSTATUSDESC' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Place of Birth'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'BIRTH_PLACE,BIRTHPLACE' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_identity iv_lbl = 'Occupation'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'OCCUPATION' ) CHANGING ct = rt ).

*   Contact is its own group because the Contact icon on the list shows exactly
*   this and nothing else.
    add_kv( EXPORTING iv_grp = c_grp_contact iv_lbl = 'Mobile Number'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'MOBILE_NUMBER,MOBILENUMBER' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_contact iv_lbl = 'Telephone'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'TELEPHONE_NUMBER,TELEPHONENUMBER' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_contact iv_lbl = 'Email'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'EMAIL_ID,EMAILID,SMTP_ADDR,EMAIL' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_contact iv_lbl = 'Fax'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'FAX_NUMBER,FAXNUMBER' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_contact iv_lbl = 'Correspondence Language'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'CORR_LANGUAGE,CORRLANGUAGE' ) CHANGING ct = rt ).

    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'Emirate'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'EMIRATE_DESC,EMIRATEDESC,EMIRATE' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'City'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'CITY' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'Area'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'AREA' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'Street'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'STREET' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'House Number'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'HOUSE_NUMBER,HOUSENUMBER' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'P.O. Box'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'POBOX,PO_BOX' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_address iv_lbl = 'Country'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'COUNTRY' ) CHANGING ct = rt ).

*   The documents and their dates in one group, because the question a notary
*   officer asks of this dialog is whether the identification is still valid.
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Emirates ID'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'E_ID,EID' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Emirates ID Valid From'
            iv_val = fmt_date( bp_pick( is_bp = is_bp iv_names = 'VALID_FROM,VALIDFROM' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Emirates ID Valid To'
            iv_val = fmt_date( bp_pick( is_bp = is_bp iv_names = 'VALID_TO,VALIDTO' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Unified ID'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'U_ID,UID' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Passport'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'PASSPORT' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Passport Valid From'
            iv_val = fmt_date( bp_pick( is_bp = is_bp
                                        iv_names = 'PASS_VALID_FROM,PASSVALIDFROM' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Passport Valid To'
            iv_val = fmt_date( bp_pick( is_bp = is_bp
                                        iv_names = 'PASS_VALID_TO,PASSVALIDTO' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Trade Licence'
            iv_val = bp_pick( is_bp = is_bp
                              iv_names = 'TRADE_LICENSE,TRADELICENSE,TRADE_LICENCE' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Visa'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'VISA' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Visa Expires'
            iv_val = fmt_date( bp_pick( is_bp = is_bp
                                        iv_names = 'VISAEXPDT,VISA_EXP_DT' ) ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Identification Type'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'ID_TYPE,IDTYPE' ) CHANGING ct = rt ).
    add_kv( EXPORTING iv_grp = c_grp_docs iv_lbl = 'Identification Number'
            iv_val = bp_pick( is_bp = is_bp iv_names = 'ID_NUMBER,IDNUMBER' ) CHANGING ct = rt ).

*   Blocked is the one value worth showing when it is FALSE as well, so it is
*   added by hand rather than through ADD_KV( )'s blank test.
    DATA(lv_blk) = to_upper( bp_pick( is_bp = is_bp iv_names = 'IS_BLOCKED,ISBLOCKED' ) ).
    IF lv_blk IS NOT INITIAL.
      APPEND VALUE #( grp   = c_grp_docs
                      label = 'Blocked'
                      value = COND string( WHEN lv_blk = 'TRUE' OR lv_blk = 'X'
                                           THEN 'Yes' ELSE 'No' ) ) TO rt.
    ENDIF.

  ENDMETHOD.


  METHOD add_kv.
*   Blanks are dropped. A view dialog with fifteen labels and nothing after the
*   colon reads as a failed read rather than a record that simply does not carry
*   a fax number.
    IF iv_val IS INITIAL.
      RETURN.
    ENDIF.
    APPEND VALUE #( grp   = iv_grp label = iv_lbl value = iv_val ) TO ct.
  ENDMETHOD.


  METHOD fmt_date.
*   The service sends 1988-07-13T00:00:00 and an ABAP DATS component reaches here
*   as 19880713. Both become 13/07/1988; anything else is passed through
*   untouched, because a value this method does not recognise is still better
*   shown than blanked.
    DATA(lv) = condense( iv ).

    IF strlen( lv ) >= 10 AND lv+4(1) = '-' AND lv+7(1) = '-'.
      rv = |{ lv+8(2) }/{ lv+5(2) }/{ lv(4) }|.
      RETURN.
    ENDIF.

    IF strlen( lv ) = 8 AND lv CO '0123456789'.
*     00000000 is an empty DATS, not a date in the year zero.
      IF lv = '00000000'.
        RETURN.
      ENDIF.
      rv = |{ lv+6(2) }/{ lv+4(2) }/{ lv(4) }|.
      RETURN.
    ENDIF.

    rv = lv.
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
    IF io_ctx->get_val( |{ iv_prefix }PARTNER| ) IS INITIAL.
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
*
*   ALL NINE, not just the five that show. Leaving <S>_SEARCHBY and <S>_IDNUM
*   filled would make the dialog open on the previous party's Emirates ID, and
*   leaving <S>_PARTNER filled would let a second Add re-post the first party -
*   the guard above reads exactly that field.
    io_ctx->set_val( iv_name = |{ iv_prefix }PARTNER|  iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }NAME|     iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }PHONE|    iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }NAT|      iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }EMAIL|    iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }SEARCHBY| iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }IDNUM|    iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }DOB|      iv_value = '' ).
    io_ctx->set_val( iv_name = |{ iv_prefix }PPTYPE|   iv_value = '' ).

    io_ctx->add_msg( iv_type = 'Success' iv_text = 'Party added.' ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.

    super->zif_rak_journey_logic~on_before_fields( EXPORTING io_ctx    = io_ctx
                                                  CHANGING  ct_fields = ct_fields ).

*   The form is named for the dialog that fills it - P1_PARTNER, P2_PHONE - and
*   the backend is named for the API - bpId, party_fullName, party_mobileNumber.
*   Neither name should move: <SUBJECT>_<SUFFIX> is ZCL_RAK_BP_POPUP's contract
*   and the payload names are Notary's. So they are translated here, once, at the
*   last point before the adapter sees them.
*
*   Both prefixes are handled unconditionally. Only one party step commits at a
*   time, so the other prefix simply is not in the payload, and branching on
*   which one would need a step name this hook is not given.
    DATA(lt_map) = VALUE zif_rak_journey_backend=>tt_field(
      ( name = 'PARTNER' value = 'bpId' )
      ( name = 'NAME'    value = 'party_fullName' )
      ( name = 'PHONE'   value = 'party_mobileNumber' )
      ( name = 'NAT'     value = 'party_nationality' )
      ( name = 'EMAIL'   value = 'party_email' ) ).

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

*   The dialog's four search CRITERIA must not travel. They are configured
*   fields like any other, so the engine collects them, and Notary would receive
*   a party carrying a passport type and a date of birth it never asked for.
*   They exist to be handed to ZCL_RAK_BP_SEARCH and for nothing else, so they
*   are dropped here - the same thing the base does to PAY_*.
    DATA(lt_crit) = VALUE string_table( ( `SEARCHBY` ) ( `IDNUM` ) ( `DOB` ) ( `PPTYPE` ) ).
    LOOP AT lt_crit INTO DATA(lv_crit).
      DO 2 TIMES.
*       Built into a variable first. A WHERE clause on an internal table takes a
*       data object, not a string template.
        DATA(lv_drop) = |P{ sy-index }_{ lv_crit }|.
        DELETE ct_fields WHERE name = lv_drop.
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
