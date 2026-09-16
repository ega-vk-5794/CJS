class ZCL_D001_SCHOOL_LIC_INIT_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.


  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_FIELDS
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_BEFORE_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_END
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_START
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~RENDER_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_ATTACHMENTS
    redefinition .
protected section.

  methods BUILD_PAY_URL
    redefinition .
  methods PAY_RENDER
    redefinition .
  methods PREPARE_PAYMENT
    redefinition .
private section.

  types:
    BEGIN OF ty_owner_details ,
        id_type        TYPE string,
        emirates_id    TYPE string,
        birth_date     TYPE string,
        nationality    TYPE string,
        share_per      TYPE string,
        owneridcopy    TYPE string,
        ownerpasscopy  TYPE string,
        ownerintrostmt TYPE string,
        ownercrimcert  TYPE string,
        ownercurv      TYPE string,
        ownerfambook   TYPE string,
      END OF ty_owner_details .
  types:
    tt_owner_details TYPE STANDARD TABLE OF ty_owner_details WITH EMPTY KEY .

  constants C_IDENTITY type STRING value 'ID_TYPE' ##NO_TEXT.
  constants C_ID type STRING value 'EMIRATES_ID' ##NO_TEXT.
  constants C_DOB type STRING value 'BIRTH_DATE' ##NO_TEXT.
  constants C_NAT type STRING value 'NATIONALITY' ##NO_TEXT.
  constants C_SHARE type STRING value 'SHARE_PER' ##NO_TEXT.
  constants C_EVT_OWNSR type STRING value 'OWN_SEARCH' ##NO_TEXT.
  constants C_EVT_OWNOK type STRING value 'OWN_OK' ##NO_TEXT.
  constants C_EVT_OWNCX type STRING value 'OWN_CANCEL' ##NO_TEXT.
  constants C_GRID type STRING value 'OWNERS_SEARCH' ##NO_TEXT.
* The owner grid's columns, addressed by NAME rather than by position.
*
* Position could not be made to work here. OWN_FORM_SAVE( ) appended nine cells
* - key, name, mobile, e-mail, share, id type, Emirates ID, passport,
* nationality - but the grid is whatever ZRAK_T_JNY_COL says it is, and for
* OWNERS_SEARCH that is FIVE columns: NAME, MOBILE_NUMBER, EMAIL_ADDRESS,
* SHARE_PER, NATIONALITY. (The field's DEFAULT_VAL still lists a leading PARTNER
* column, but GRID_COLS( ) prefers ZRAK_T_JNY_COL whenever it has rows, so that
* entry never takes effect.)
*
* SET_GRID_DATA( ) walks the CONFIGURED columns and takes cell N from the row, so
* those nine landed one place left of where they were read: the stored Owner Name
* was the row key, Mobile held the name, Share held the e-mail, and Nationality
* held the share. The screen looked right because RENDER_OWN_LIST( ) read one
* place right again - only the POST carried the shift.
*
* The readers had also drifted apart from each other: RENDER_OWN_LIST( ) took
* nationality from column 6 and OWN_EDIT( ) from column 9, while the row buttons
* carried the NAME as their id and both methods matched it against column 1.
*
* Naming the columns settles all of it. A column that is absent resolves to 0 and
* is skipped, instead of shifting its neighbours along.
  constants C_COL_PARTNER type STRING value 'PARTNER' ##NO_TEXT.
  constants C_COL_NAME type STRING value 'NAME' ##NO_TEXT.
  constants C_COL_MOBILE type STRING value 'MOBILE_NUMBER' ##NO_TEXT.
  constants C_COL_EMAIL type STRING value 'EMAIL_ADDRESS' ##NO_TEXT.
  constants C_COL_SHARE type STRING value 'SHARE_PER' ##NO_TEXT.
  constants C_COL_NAT type STRING value 'NATIONALITY' ##NO_TEXT.
  constants C_COL_EID type STRING value 'EMIRATES_ID' ##NO_TEXT.
  constants C_COL_DOB type STRING value 'BIRTH_DATE' ##NO_TEXT.
  constants C_OWN_ID type STRING value 'OWN_ID' ##NO_TEXT.
* The BP number the Emirates ID search resolved for the owner in the dialog.
* It is what the PARTNER column - and so GS_DATA-OWNERS-PARTNER - is for.
*
* C_OWN_ID is NOT that. It is a per-press local row id (a timestamp) minted so
* the dialog's uploaders have something to key files on before the row exists,
* and OWN_FORM_SAVE used to write it straight into the PARTNER column: the
* backend was being handed a timestamp, or - once OWN_EDIT( ) had re-seeded it
* from ROW_KEY_OF( ) - the owner's NAME, in a partner field. Neither is a
* partner. ZFE_CJ_SEARCH_BP_BY_ID has always returned EV_PARTNER and it was
* being discarded.
*
* Neither key needs a ZRAK_T_JNY_FLD row: VAL_SET( ) parks a name the model
* does not carry in the engine's scratch store, which survives the round trip.
* D004 keeps the same value in a hidden READONLY field called OWNER_PARTNER.
  constants C_OWN_BP type STRING value 'OWNER_PARTNER' ##NO_TEXT.
  constants C_EVT_OWNEW type STRING value 'OWN_NEW' ##NO_TEXT.
  constants C_POP_OWN type STRING value 'TRIGGER_POPUP' ##NO_TEXT.
  constants C_TRIGGER_POPUP type STRING value 'TRIGGER_POPUP' ##NO_TEXT.
  constants C_COL_ACTIVITY type STRING value 'ACTIVITY' ##NO_TEXT.

* Position of a named column in the grid's own spec, or 0 when the spec has no
* such column. 0 is a legitimate answer: OWNERS_SEARCH has nowhere to keep an
* Emirates ID or a birth date until those ZRAK_T_JNY_COL rows are added.
  methods COL_IX
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
    returning
      value(RV) type I .
* Read one named cell out of a row. Blank when the column is not in the spec.
  methods CELL_OF
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
    returning
      value(RV) type STRING .
* Place a value in the named column. A column the spec does not define is
* skipped, never appended - appending is what shifted every later cell.
  methods PUT_CELL
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
      !IV_VAL type STRING
    changing
      !CT_ROW type ZIF_RAK_JOURNEY=>TT_STRING .
* The value the row's Edit and Delete buttons carry: the PARTNER key when the
* spec has that column, the owner's name when it does not.
  methods ROW_KEY_OF
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
    returning
      value(RV) type STRING .
  methods OWN_FORM_LOAD
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
  methods OWN_FORM_SAVE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods RENDER_OWN_LIST
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_VIEW type ref to Z2UI5_CL_XML_VIEW .
  methods RENDER_OWN_POPUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IO_POPUP type ref to Z2UI5_CL_XML_VIEW .
  methods BLOB_READ
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RT) type TT_OWNER_DETAILS .
  methods BLOB_WRITE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IT_OWNER type TT_OWNER_DETAILS .
  methods OWN_DELETE
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING .
  methods OWN_EDIT
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_ID type STRING optional .
ENDCLASS.



CLASS ZCL_D001_SCHOOL_LIC_INIT_LOGIC IMPLEMENTATION.


  METHOD build_pay_url.
    CALL METHOD super->build_pay_url
      EXPORTING
        io_ctx = io_ctx
      RECEIVING
        rv_url = rv_url.
  ENDMETHOD.


  METHOD pay_render.

*  data: lo_ctx TYPE REF TO ZIF_RAK_JOURNEY,
*  lo_view TYPE REF TO Z2UI5_CL_XML_VIEW,
*  lv_field type string,
*  lt_fee TYPE ZCL_RAK_PAY_ENGINE=>TT_FEE,
*  lv_total TYPE KBETR,
* lv_poll TYPE ABAP_BOOL.

    CALL METHOD super->pay_render
      EXPORTING
        io_ctx   = io_ctx
        io_view  = io_view
        iv_field = iv_field
        it_fee   = it_fee
        iv_total = iv_total
        iv_poll  = iv_poll.


  ENDMETHOD.


  METHOD prepare_payment.
*   This was an EMPTY redefinition - nothing but the commented-out SE24 template.
*   PREPARE_PAYMENT is not a hook with an empty default: the base has a real
*   89-line body and the engine calls it on the way into the payment step, so
*   redefining it to nothing switched payment preparation off on a FEE-BEARING
*   journey. Silently, while BUILD_PAY_URL( ) and PAY_RENDER( ) either side of it
*   both chained correctly and looked like proof the card worked.
    CALL METHOD super->prepare_payment
      EXPORTING
        io_ctx = io_ctx.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.

*    data ls_bp type ty_bp_string.

    CASE to_upper( iv_name ).

      WHEN 'BUILDINGS'.
        " Column order matches the export's LEVEL_CON='T' children of
        " BUILDINGS: BLOCK_NAME_1, FLOORS_CNT_1, ROOMS_CNT_1.
*       NOT LITERALS. RS_DATA-COLUMNS is a plain string table with no _AR
*       twin, so a literal header shows English to an Arabic reader.
*
*       THIS IS NOT WHAT DRAWS THE BUILDINGS HEADINGS ON SCREEN, and the
*       distinction cost a round. BUILDINGS renders as a GRID, and
*       ZCL_RAK_JOURNEY_GRID->GRID_COLS( ) takes its headings from
*       ZRAK_T_JNY_COL-ZLABEL/ZLABEL_AR, or from the packed DEFAULT_VAL spec
*       when no column rows exist - it never calls GET_TABLE( ). The only
*       callers of GET_TABLE( ) are the four TABLE branches in
*       ZCL_RAK_JOURNEY_RENDER. So an Arabic BUILDINGS heading is CONFIG:
*       fill ZLABEL_AR on the three ZRAK_T_JNY_COL rows (Studio column
*       editor, "Label (AR)"), or add the fifth spec slot
*       name:label:type:src:label_ar in DEFAULT_VAL.
*
*       Kept anyway, and only because it is correct for the path it is on:
*       if BUILDINGS is ever configured as a TABLE this branch becomes live
*       and would otherwise reintroduce three English literals.
        rs_data-columns = VALUE #(
          ( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-col_block_name iv_default = `Block Name` ) )
          ( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-col_floors     iv_default = `No. of floors` ) )
          ( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-col_rooms      iv_default = `No. of rooms` ) ) ).

*       DATA(lt_bldg_rows) = io_ctx->get_val( 'BUILDINGS' ).   " REVIEW: retrieval API unconfirmed
        " ... deserialize lt_bldg_rows into rs_table-rows here ...

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.
    super->zif_rak_journey_logic~on_before_fields(
      EXPORTING
        io_ctx    = io_ctx
      CHANGING
        ct_fields = ct_fields
    ).

    LOOP AT ct_fields ASSIGNING FIELD-SYMBOL(<f>) WHERE name = 'LINE_ITEMS'.
      " <f> value is a JSON array: [{"ITEM":"..","QTY":"2","DUE":"..","ORIG":".."}]
      " /ui2/cl_json=>deserialize( json = ... changing data = lt_rows )
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " Real fee handling exists on this journey (PAYFEE) — do NOT blanket-
    " strip PAY_*/PAYFEE here the way the fee-less journeys did.

    " UI-only scratch keys with no backend meaning.
    DELETE ct_kv WHERE key = 'DECLARE'.

*   ACCEPTTERMS is NOT stripped. It carries TECH_NAME 'ACCEPT_TERMS' in
*   ZRAK_T_JNY_FLD, so it is a real backend field - the citizen's acceptance of
*   the terms - and deleting it here meant the one record that they accepted
*   never left CJS.

*   The payment CONTEXT and WORKING STATE, which are not the fee. Named rather
*   than 'PAY_*': a wildcard would also take PAY_TOTAL, and PAY_TOTAL carries
*   TECH_NAME 'TOTALFEESVALUE' - it is the fee total the backend waits for.
    DELETE ct_kv WHERE key = 'PAY_STARTED'
                    OR key = 'PAY_STARTED1'
                    OR key = 'PAY_REFERENCE'
                    OR key = 'PAY_SCREEN'
                    OR key = 'PAY_JOURNEY'
                    OR key = 'PAY_CATEGORY'
                    OR key = 'PAY_TRIES'
                    OR key = 'PAY_APPURL'
                    OR key = 'PAY_BUKRS'
                    OR key = 'PAY_MATERIAL'
                    OR key = 'PAY_CASES_FOR'
                    OR key = 'PAY_ETISALAT'.

    " {APPLICANT_NAME} in the DECLARE field's rendered text is now
    " substituted live by ZCL_RAK_JOURNEY_RENDER->LONG_TEXT( ), from the
    " APPLICANT_NAME/APPLICANTNAME values ON_INIT sets - see there.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
    sy-subrc = 0.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   'PAID'. A redefinition REPLACES it, so without this call the gate is simply
*   not there for this journey. It must come before any CHECK below: a CHECK that
*   fails exits the method, and anything after it would never run.
*
*   Self-guarding - PAY_FIELD_STEP returns -1 when the journey has no PAYFEE
*   field, so this is a no-op on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

    CASE iv_step.
      WHEN 1.   " step 2 "Partners"

        DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).

*       By column name, like every other reader of this grid. Reading cells 1 to
*       5 positionally checked the NAME as though it were a key and the SHARE as
*       though it were an e-mail, so this could block a complete row or pass an
*       incomplete one depending only on which cells happened to be filled.
*
*       An EMPTY grid is the case the message actually describes, and the LOOP
*       never ran for it - "Add at least one owner" could not fire when there
*       were no owners. That is tested first now, before the per-row check.
        IF ls_g-rows IS INITIAL.
          rt = VALUE #( BASE rt
            ( type = 'Error'
              text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-d001_need_owner
                                        iv_default = 'Add at least one owner before continuing.' ) ) ).
          RETURN.
        ENDIF.

        LOOP AT ls_g-rows INTO DATA(lt_r).
          IF cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_name )  IS INITIAL
          OR cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_email ) IS INITIAL
          OR cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_share ) IS INITIAL.
            rt = VALUE #( BASE rt
              ( type = 'Error'
                text = zcl_rak_text=>get(
                         iv_no      = zcl_rak_text=>c_no-d001_owner_incompl
                         iv_default = 'Every owner needs a name, an e-mail address and a share percentage.' ) ) ).
            RETURN.
          ENDIF.
        ENDLOOP.

*
*        IF lv_owners IS INITIAL.
*          rt = VALUE #( ( type = 'Error' text = 'Add at least one owner before continuing.' ) ).
*        ENDIF.
        " REVIEW: shares-sum-to-100 validation belongs here once
        " OWNERSTABLE's row retrieval (see get_table) is confirmed.

      WHEN 2.   " zero-based: step 3 "Academic Details"
        DATA(lv_any_stage) = abap_false.
*       "Start of change by JM
*       LOOP AT VALUE string_table( ( 'PREKG' ) ( 'KG' ) ( 'CYCLE1' ) ( 'CYCLE2' ) ( 'CYCLE3' ) ) INTO DATA(lv_stage).
        LOOP AT VALUE string_table(
          ( CONV string( 'PREKG' ) )
          ( CONV string( 'KG' ) )
          ( CONV string( 'CYCLE1' ) )
          ( CONV string( 'CYCLE2' ) )
          ( CONV string( 'CYCLE3' ) )
        ) INTO DATA(lv_stage).
*       "End of change by JM
          IF io_ctx->get_val( lv_stage ) = abap_true.
            lv_any_stage = abap_true.
          ENDIF.
        ENDLOOP.
        IF lv_any_stage = abap_false.
          rt = VALUE #( BASE rt ( type = 'Error'
            text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-d001_need_stage
                                      iv_default = 'Select at least one education stage.' ) ) ).
        ENDIF.

*        DATA(lv_buildings) = io_ctx->get_val( 'BUILDINGS' ).
*        IF lv_buildings IS INITIAL.
*          rt = VALUE #( BASE rt ( type = 'Error' text = 'Add at least one building.' ) ).
*        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
    CALL METHOD super->zif_rak_journey_logic~on_popup_event
      EXPORTING
        io_ctx   = io_ctx
        iv_id    = iv_id
        iv_event = iv_event.

    CASE iv_event.
* On click of 'Add' in pop-up screen
      WHEN c_evt_ownew.
        own_form_load( io_ctx ).          " no id = a new owner
        io_ctx->open_popup( c_pop_own ).

      WHEN c_evt_ownok.
*       Validate before writing. Closing on an incomplete row and complaining
*       behind the dialog makes the citizen reopen it and guess what was wrong.
*       Nationality and Shares used to be able to slip through unfilled - the
*       Nationality branch didn't exist and the Shares branch never RETURNed.
        IF io_ctx->get_val( c_identity )  IS INITIAL
           OR io_ctx->get_val( c_id ) IS INITIAL
           OR io_ctx->get_val( c_dob ) IS INITIAL
           OR io_ctx->get_val( c_nat ) IS INITIAL.

          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = zcl_rak_text=>get(
                                       iv_no      = zcl_rak_text=>c_no-d001_fill_required
                                       iv_default = 'Kindly fill required details.' ) ).
          RETURN.
        ELSEIF io_ctx->get_val( c_share ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = zcl_rak_text=>get(
                                       iv_no      = zcl_rak_text=>c_no-d001_shares_100
                                       iv_default = 'Kindly enter shares as 100' ) ).
          RETURN.
        ENDIF.

*       784-XXXX-XXXXXXX-X - the same shape as the field's own placeholder.
        DATA(lv_eid_chk) = condense( io_ctx->get_val( c_id ) ).
        FIND REGEX '^784-\d{4}-\d{7}-\d$' IN lv_eid_chk.
        IF sy-subrc <> 0.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = zcl_rak_text=>get(
                                       iv_no      = zcl_rak_text=>c_no-d001_eid_format
                                       iv_default = 'Emirates ID must be in the format 784-XXXX-XXXXXXX-X.' ) ).
          RETURN.
        ENDIF.

*       THE MANDATORY DOCUMENTS, ON THE POPUP, BEFORE THE ROW IS WRITTEN.
*
*       The four uploaders below are drawn with required = abap_true, and
*       until now that asterisk promised something nothing enforced: Add
*       wrote the owner and closed the dialog with no files attached, and
*       the citizen found out at submit - behind a dialog that was no
*       longer open, against a row they could no longer see. That is the
*       marker-without-enforcement trap, and it is why the QA build shows
*       "Please upload the mandatory attachments" under each uploader
*       while this one showed nothing.
*
*       KEYED ON THIS OWNER, not on the field alone. Every uploader in the
*       dialog is drawn with iv_key = C_OWN_ID, so a file reaches the
*       backend as identifier1 = FIELD_<owner id>. Testing the field name
*       alone would let one owner's Emirates ID copy satisfy the check for
*       every other owner on the application.
*
*       ONE CALL, HELD IN A VARIABLE. GET_ATTACHMENT_FILES( ) base64-loads
*       every staged file on each call, and its own documentation says not
*       to call it per attachment - so it is called once here and the four
*       tests read the result.
        DATA(lv_own_key) = io_ctx->get_val( c_own_id ).
        DATA(lt_own_att) = io_ctx->get_attachment_files( ).
        DATA lv_miss TYPE abap_bool.
        CLEAR lv_miss.

*       THE DOCUMENT NAME TRAVELS INTO THE MESSAGE AS &1, so a literal here
*       reaches the citizen through an otherwise translated sentence - the
*       Arabic run said "يرجى إرفاق Criminal Clearance certificate." These
*       are the SAME four entries the uploader labels in the dialog use, so
*       the message and the label the citizen is hunting for cannot drift.
        DATA(lt_req_doc) = VALUE zif_rak_journey=>tt_kv(
          ( key = '60' value = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_eid
                                     iv_default = 'Emirates ID Copy' ) )
          ( key = 'FE' value = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_intro
                                     iv_default = 'Introductory Statement' ) )
          ( key = '6P' value = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_criminal
                                     iv_default = 'Criminal Clearance certificate' ) )
          ( key = 'FF' value = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_cv
                                     iv_default = 'Curriculum Vitae' ) ) ).

        LOOP AT lt_req_doc INTO DATA(ls_req_doc).
          DATA(lv_want_id1) = COND string(
            WHEN lv_own_key IS NOT INITIAL
            THEN |{ ls_req_doc-key }_{ lv_own_key }|
            ELSE ls_req_doc-key ).
          READ TABLE lt_own_att TRANSPORTING NO FIELDS
            WITH KEY identifier1 = lv_want_id1.
          IF sy-subrc <> 0.
            lv_miss = abap_true.
*           ONE MESSAGE PER MISSING DOCUMENT, naming it. A single "attach
*           the required documents" makes the citizen check all six to
*           find the two that are missing.
            io_ctx->add_msg( iv_type = 'Warning'
                             iv_text = zcl_rak_text=>get(
                                         iv_no      = zcl_rak_text=>c_no-d001_upload_doc
                                         iv_v1      = CONV string( ls_req_doc-value )
                                         iv_default = |Please upload { ls_req_doc-value }.| ) ).
          ENDIF.
        ENDLOOP.

*       RETURN BEFORE THE SAVE AND BEFORE THE CLOSE, and both matter. The
*       dialog staying open is the point - the citizen keeps what they
*       typed and can see which uploader is empty. Closing on a warning is
*       the E017 shape: a toast behind a shut dialog and a bad row saved.
        IF lv_miss = abap_true.
          RETURN.
        ENDIF.

        own_form_save( io_ctx ).

        io_ctx->close_popup( ). "Close pop-up screen after adding data
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = zcl_rak_text=>get(
                                     iv_no      = zcl_rak_text=>c_no-d001_owner_added
                                     iv_v1      = io_ctx->get_val( c_id )
                                     iv_default = |{ io_ctx->get_val( c_id ) } added to the owner list.| ) ).

* on click of 'Close' in pop-up screen
      WHEN c_evt_owncx.
        io_ctx->close_popup( ). "Close pop-up screen

      WHEN c_TRIGGER_POPUP.   "Gets trigger when user click on "Add OWner" push button.
        "This opens pop-up screen and show above mentioned fields in screen.
        io_ctx->open_popup( c_TRIGGER_POPUP ).

      WHEN c_evt_ownsr.   "On click of search icon on pop-up

        DATA(lv_eid) = io_ctx->get_val( c_id ).
        IF lv_eid IS NOT INITIAL.
          CONDENSE lv_eid .

*DATA IV_TYPE            TYPE BU_ID_TYPE.
          DATA iv_idnumber        TYPE bu_id_number.
*DATA IV_APP             TYPE STRING.
          DATA ev_partner         TYPE partner.
          DATA ev_id_number       TYPE bu_id_number.
          DATA ev_passport        TYPE bu_id_number.
          DATA ev_name            TYPE bu_name1tx.
          DATA ev_phone           TYPE farp_mobile.
          DATA ev_email           TYPE ad_smtpadr.
          DATA ev_nationality     TYPE natio50.
          DATA ev_nationality_key TYPE bu_natio.
          DATA ev_date_of_birth   TYPE bu_birthdt.
          DATA ev_message         TYPE bapiret2-message.

          iv_idnumber = lv_eid .
          CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
            EXPORTING
              iv_type            = 'YFS002'
              iv_idnumber        = iv_idnumber
*             IV_APP             = IV_APP
            IMPORTING
              ev_partner         = ev_partner
              ev_id_number       = ev_id_number
              ev_passport        = ev_passport
              ev_name            = ev_name
              ev_phone           = ev_phone
              ev_email           = ev_email
              ev_nationality     = ev_nationality
              ev_nationality_key = ev_nationality_key
              ev_date_of_birth   = ev_date_of_birth
              ev_message         = ev_message.


          io_ctx->set_val( iv_name = 'EMIRATES_ID'    iv_value = |{ lv_eid }| ).
*         The BP the search resolved. Kept, not discarded: it is the value the
*         PARTNER column carries out to GS_DATA-OWNERS-PARTNER - see C_OWN_BP.
          io_ctx->set_val( iv_name = c_own_bp         iv_value = |{ ev_partner }| ).
          io_ctx->set_val( iv_name = 'NAME_POP'       iv_value = |{ ev_name }| ).
          io_ctx->set_val( iv_name = 'TELEPHONE_POP'  iv_value = |{ ev_phone }| ).
          io_ctx->set_val( iv_name = 'EMAIL_POP'      iv_value = |{ ev_email }| ).
          io_ctx->set_val( iv_name = 'BIRTH_DATE'     iv_value = |{ ev_date_of_birth }| ).
*         EV_NATIONALITY_KEY, not EV_NATIONALITY. The dropdown above is now fed
*         from T005T and keyed on LAND1; this wrote NATIO50 - the display text -
*         into the same field, so the key matched no entry, the combobox
*         rendered unselected, and the column saved blank. That is the
*         "Nationality not coming" on the Partners tab: the list was fixed, the
*         value written into it was not.
          io_ctx->set_val( iv_name = 'NATIONALITY' iv_value = |{ ev_nationality_key }| ).

        ENDIF.

      WHEN C_PAY_NOW.
        io_ctx->set_val( iv_name = 'STATUS' iv_value = 'PAY' ).
        super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).

      WHEN OTHERS.
*       Row actions carry their subject in the event id, which is how a list of
*       any length wires its buttons without a constant for each row.
        IF iv_event CP 'OWN_EDIT_*'.
          "own_form_load( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          OWN_EDIT( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          io_ctx->open_popup( c_pop_own ).
          RETURN.
        ENDIF.
        IF iv_event CP 'OWN_DEL_*'.
          own_delete( io_ctx = io_ctx iv_id = substring( val = iv_event off = 8 ) ).
          RETURN.
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   = io_ctx
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .

    DATA(lv_step) = io_ctx->get_step( ).

    CASE iv_field.
      WHEN 'ID_TYPE'.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
    CALL METHOD super->zif_rak_journey_logic~render_field
      EXPORTING
        io_ctx   = io_ctx
        io_form  = io_form
        is_field = is_field
      RECEIVING
        rv_done  = rv_done.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES(
*  EXPORTING
*    IO_CTX    = IO_CTX
*  CHANGING
*    CT_TABLES = CT_TABLES
*       ).


*----------------------------------------------------------------------------*
* NOTHING is re-laid here, and that is deliberate. ND001_1_2 is NOT ND004_1_2.
*
* This method used to carry D004's re-lay - name, nationality, share, mobile,
* e-mail, partner, Emirates ID - copied over on the assumption that the two
* school-licence screens share their /QNV/SB_UI_DEFIN sequence. They do not,
* and the copy is what distorted the owner table.
*
* Evidence, from a breakpoint in ZCL_EGA_CJ_ENH_IMPL_D001->ZIF_EGA_FW_CJI~READ
* with one owner posted (name Moaaz Hassan Al Hassan, mobile 05644X8763,
* e-mail vneugopal.a@ega.rak.ae, share 100, nationality AE):
*
*   GS_DATA-OWNERS  PARTNER = Moaaz Hassan Al Hassan   <- slot 1 (name)
*                   NAME    = AE                       <- slot 2 (nationality)
*                   MOBILE_NUMBER  = 100               <- slot 3 (share)
*                   EMAIL_ADDRESS  = 05644X8763        <- slot 4 (mobile)
*                   SHARE_PER      = vneugopal.a@...   <- slot 5 (e-mail)
*                   ID_TYPE        = Moaaz Hassan ...  <- slot 6 (row key)
*                   EMIRATES_ID    = 784-1956-...      <- slot 7 (Emirates ID)
*
* Every one of the seven re-laid slots landed in the component sitting at that
* slot's POSITION IN THE CJS SPEC. So for ND001_1_2 the write order and the
* read order are the SAME order, and it is the one OWNERS_SEARCH's
* ZRAK_T_JNY_COL rows already carry - partner, name, mobile, e-mail, share, -,
* Emirates ID, -, nationality. TABLES_FOR_BACKEND( ) fills UI_TABLE_COLUMN1..N
* in exactly that order, so the row is already correct when it gets here.
*
* D004 keeps its re-lay: there the share genuinely has LIST_SEQUENCE 3, proven
* by the backend refusing the step with "The Total of the Share (0.00%) is not
* equal to 100%" until it was moved. Two screens, two sequences. Do not copy a
* re-lay between them again without a breakpoint in that screen's own READ.
*----------------------------------------------------------------------------*
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    DATA: lv_loginbp TYPE bu_partner.

    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role.

    IF lv_loginbp IS NOT INITIAL.
      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
        EXPORTING
          iv_bp_id      = lv_loginbp
        IMPORTING
          es_bp_details = DATA(ls_bp) ).

*      "Applicant Name
*      Set under both spellings: the DECLARE field's config text carries
*      the placeholder as {APPLICANT_NAME} (with the underscore, per the
*      REVIEW comment on ON_BEFORE_POST), while this journey's own model
*      field has always been APPLICANTNAME (without it). RENDER_LONG_TEXT's
*      new {FIELDNAME} substitution reads whichever name is actually in
*      the text, so both need a value or the declaration renders with the
*      applicant's name blank instead of the placeholder text itself.
      IF sy-langu = 'E'.
        io_ctx->set_val( iv_name = 'APPLICANTNAME'  iv_value = CONV #( ls_bp-bp_name ) ).
        io_ctx->set_val( iv_name = 'APPLICANT_NAME' iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = 'APPLICANTNAME'  iv_value = CONV #( ls_bp-bp_name_ar ) ).
        io_ctx->set_val( iv_name = 'APPLICANT_NAME' iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

*      "Emirates Id/Applicant ID
      io_ctx->set_val( iv_name = 'APPLICANT_ID' iv_value = CONV #( ls_bp-emirates_id ) ).

*      "Applicant Type
      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = CONV #( 'Investor' ) ).


*      "Login BP
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

*      "Nationality
       io_ctx->set_val( iv_name = 'NATIONALITY'  iv_value = CONV #( ls_bp-NATIONALITY_TX ) ).

    ENDIF.

*   The journey's own payment step. PREPARE_PAYMENT reads this to know
*   whose read BAdI resolves the gateway, and NE014_1_4 is that screen.
    io_ctx->set_val( iv_name = c_pay_screen iv_value = 'ND001_1_5' ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_before_field.
    CALL METHOD super->zif_rak_journey_logic~on_render_before_field
      EXPORTING
        io_ctx   = io_ctx
        io_view  = io_view
        is_field = is_field.

*check is_field-name = 'BUTTON'.
*IO_VIEW->button(
*  EXPORTING
*    text             = 'Button'
*    icon             =
*    type             =
*    enabled          =
*    visible          =
*    press            = event( 'BUTTONEVENT' )
*    class            =
*    id               =
*    ns               =
*    tooltip          =
*    width            =
*    iconfirst        =
*    icondensityaware =
*    ariahaspopup     =
*    activeicon       =
*    accessiblerole   =
*    textdirection    =
*    arialabelledby   =
*    ariadescribedby  =
*  RECEIVING
*    result           =
*).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
    super->zif_rak_journey_logic~on_render_popup(
      io_ctx   = io_ctx
      io_popup = io_popup
      iv_id    = iv_id
    ).

    CASE iv_id.
      WHEN c_trigger_popup.  " On click of 'Add Owner' button on second page"
*        "Not using Dialog form here as i need search button as well.
        render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
        RETURN.

*        dialog_form(
*          io_ctx     = io_ctx
*          io_popup   = io_popup
*          iv_title   = 'Owner Details'
*          it_fields  = VALUE #(
*                                ( name = c_hs_pop           label = 'HS Code'  )
*                                ( name = c_mat_pop          label = 'Material Name' )
*                                ( name = c_chem_pop         label = 'Chemical Name' )
*                                ( name = c_cas_no_pop       label = 'CAS Number' maxlen = 20 )
*                                ( name = c_chem_form_pop    label = 'Chemical Formula' )
*                                ( name = c_packaging_pop    label = 'Packing' )
*                                ( name = c_quantity_pop     label = 'Quantity'  )
*                                ( name = c_gross_weight_pop label = 'Gross Weight'  type = 'Number' )
*                                ( name = c_unit_pop         label = 'Unit' "rollname = 'MEINS' )
*                                type = 'SELECT'
*                                options = VALUE #( ( key = 'GAL' text = 'Gallon' )
*                                                     ( key = 'KG'  text = 'Kilogram' )
*                                                     ( key = 'LIT' text = 'Liter' )
*                                                     ( key = 'MAT' text = 'Metric Ton' ) ) )
*                                ( name = c_invoice_pop      label = 'Invoice Number'  )
*                                ( name = c_import_pop       label = 'Importing Country' shlp = 'H_T005'  )
*                                ( name = c_exit_port_pop    label = 'Exit Port'  )
*                                ( name = c_bol_pop          label = 'Bill of Lading'  )
*                                ( name = c_tport_pop        label = 'Transport Details'  )
*                              )
*          iv_ok_text = 'Add'
*          iv_ok_evt  = c_evt_ownok
*          iv_cxl_evt = c_evt_owncx ).

      WHEN OTHERS.
    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    super->zif_rak_journey_logic~on_render_start(
      io_ctx  = io_ctx
      io_view = io_view
    ).
*    CHECK io_ctx->get_step( ) = material_step( io_ctx ).

*    DATA(lo_bar) = io_view->hbox( alignitems = 'Center'
*                                  class      = 'sapUiSmallMarginBegin sapUiTinyMarginTop' ).
*
*    lo_bar->button( text  = 'Add Owner'
*                    icon  = 'sap-icon://add'
*                    type  = 'Emphasized'
*                    press = io_ctx->event( 'TRIGGER_POPUP' ) ). "c_mat_add ) ).

*   ---- THE THREE ARABIC SCHOOL-NAME BOXES TAKE ARABIC ENTRY ---------------
*   THE PAGE-LEVEL RTL BLOCK ONLY FIRES WHEN MV_LANG = 'A'. On an ENGLISH run
*   these three are ordinary left-to-right inputs, so a citizen typing the
*   school's Arabic name gets the caret at the wrong edge and any digits or
*   punctuation in the name land on the wrong side of it. The field is
*   Arabic BY DEFINITION - it is the column the licence prints in Arabic -
*   so its direction follows the DATA, not the page.
*
*   A STYLE RULE, NOT RENDER_FIELD( ). Claiming the field would mean
*   redrawing label, binding, editable, valuestate and the CHANGE event
*   here, and a dropped CHANGE stops ON_CHANGE( ) for that field silently -
*   RENDER_ONE( ) swallows a failing hook and falls back to the engine, so
*   the mistake would not even show. Three CSS rules against the per-field
*   RAKF<NAME> class the renderer now emits change nothing else.
*
*   A <style> in HTML( ) DOES apply, unlike a <script>. Style elements
*   inserted as innerHTML are honoured by the browser; script elements are
*   parsed and never executed. That difference is why the map snippet needs
*   FOLLOW_UP_ACTION( ) and this does not.
*
*   NOT THE COLUMN POSITION. Moving these boxes to the left is a Design tab
*   change - swap the two cells in ZRAK_CJ_LAYOUT - and it belongs there
*   rather than here: on an Arabic run the whole page is RTL, so a position
*   pinned in CSS would put them at the END of the row, while swapping the
*   cells follows the page in both languages.
*   BACKTICKS AND REPLACE, NOT A | TEMPLATE. The braces have to reach the XML
*   as the two characters \{ and \}, because the markup travels as an XML view
*   ATTRIBUTE and UI5 reads a bare brace there as the start of a binding
*   expression - which is what "Error found in Fragment ... [object Object]"
*   is. Inside a |...| template, though, \{ is the TEMPLATE's own escape and
*   collapses to a bare { before the string is ever built, so writing the
*   escape there produces exactly the character it was meant to prevent.
*   A backtick literal does no such processing, so the brace survives to the
*   REPLACE and the REPLACE is what puts the backslash in. Same two lines
*   RENDER_UPLOADER( ) and ZCL_RAK_CJ_GIS->CONTAINER( ) use, for this reason.
*   THE WHOLE CELL, NOT ONLY THE BOX. The first version set direction on the
*   input alone, so the Arabic text flowed correctly and the label above it
*   stayed hard left with its asterisk on the wrong end - the field read as
*   two halves disagreeing. DIRECTION on the CELL carries the label, the
*   required marker and the control together, which is what an Arabic field
*   on an English page should look like.
*
*   RAKC<NAME> is the cell, RAKF<NAME> the control inside it. The input rule
*   stays: .sapMInputBase sets its own direction in places, so inheriting
*   from the cell is not something to rely on for the one part that matters.
    DATA(lv_rtl) =
      `<style>.rakCSCHOOLNAMEAR1,.rakCSCHOOLNAMEAR2,.rakCSCHOOLNAMEAR3` &&
      `{direction:rtl;text-align:right;}` &&
      `.rakFSCHOOLNAMEAR1 input,.rakFSCHOOLNAMEAR2 input,` &&
      `.rakFSCHOOLNAMEAR3 input` &&
      `{direction:rtl;text-align:right;}</style>`.
    REPLACE ALL OCCURRENCES OF `{` IN lv_rtl WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_rtl WITH `\}`.
    io_view->html( content = lv_rtl sanitizecontent = abap_false ).
  ENDMETHOD.


  METHOD blob_read.
    DATA(lv_blob) = io_ctx->get_val( 'OWNER_SEARCH' ).
    CHECK lv_blob IS NOT INITIAL.

    SPLIT lv_blob AT '|' INTO TABLE DATA(lt_row).
    LOOP AT lt_row INTO DATA(lv_row).
      IF lv_row IS INITIAL.
        CONTINUE.
      ENDIF.
      SPLIT lv_row AT '~' INTO DATA(lv_idtype) DATA(lv_eid)
      DATA(lv_dob) DATA(lv_nation) DATA(lv_share) DATA(lv_ownid) DATA(lv_pass)
      DATA(lv_intro) DATA(lv_crim) DATA(lv_curv) DATA(lv_fbook)
      DATA(lv_u).

*      IF lv_m IS INITIAL.
*        CONTINUE.
*      ENDIF.
*      APPEND VALUE #( mtype = lv_m qty = lv_q unit = lv_u ) TO rt.
      APPEND VALUE #( id_type = lv_idtype
                        emirates_id = lv_eid
                        birth_date = lv_dob
                        nationality = lv_nation
                        share_per = lv_share
                        owneridcopy = lv_ownid
                        ownerpasscopy = lv_pass
                        ownerintrostmt = lv_intro
                        ownercrimcert = lv_crim
                        ownercurv = lv_curv
                        ownerfambook = lv_fbook ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD blob_write.

    DATA lv_blob TYPE string.

    LOOP AT it_owner INTO DATA(ls).
*      DATA(lv_row) = |{ ls-ID_TYPE }{ c_colsep }
*                      { ls-EMIRATES_ID }{ c_colsep }
*                      { ls- }|.
*      lv_blob = COND #( WHEN lv_blob IS INITIAL
*                        THEN lv_row
*                        ELSE |{ lv_blob }{ '|' }{ lv_row }| ).
    ENDLOOP.
    io_ctx->set_val( iv_name = 'OWNER_SEARCH' iv_value = lv_blob ).
  ENDMETHOD.


  METHOD own_form_load.
*"Whenever ADD OWNER is clicked pop-up should not have any values.
    io_ctx->set_val( iv_name = c_identity iv_value = '1' ).    " only option (EID) - nothing to pick
    io_ctx->set_val( iv_name = c_id iv_value = '' ).
    io_ctx->set_val( iv_name = c_nat iv_value = '' ).
    io_ctx->set_val( iv_name = C_DOB iv_value = '' ).
    io_ctx->set_val( iv_name = c_share iv_value = '' ).
*   And the resolved BP with them, or the next owner is saved under the previous
*   owner's partner number.
    io_ctx->set_val( iv_name = c_own_bp iv_value = '' ).

    IF iv_id IS INITIAL.
*     New owner. The id is minted NOW and not on save, because the uploaders in
*     the dialog key their files on it - a file attached before the row exists
*     still has to belong to the right person. This used to mint the SAME
*     fixed id for every new owner, so OWN_FORM_SAVE's "does this id already
*     exist" check matched the first owner every time and every later Add
*     overwrote them instead of appending - a timestamp is unique per press.
      DATA lv_ts TYPE timestampl.
      GET TIME STAMP FIELD lv_ts.
      io_ctx->set_val( iv_name  = c_own_id
                       iv_value = |{ lv_ts }| ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
  ENDMETHOD.


  METHOD col_ix.
    LOOP AT it_cols INTO DATA(lv_c).
      IF to_upper( condense( lv_c ) ) = to_upper( iv_name ).
        rv = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD cell_of.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    rv = VALUE #( it_row[ lv_ix ] OPTIONAL ).
  ENDMETHOD.


  METHOD put_cell.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    CHECK lines( ct_row ) >= lv_ix.
    READ TABLE ct_row INDEX lv_ix ASSIGNING FIELD-SYMBOL(<cell>).
    CHECK sy-subrc = 0.
    <cell> = iv_val.
  ENDMETHOD.


  METHOD row_key_of.
*   One definition, used by the list that draws the buttons and by the two
*   methods that answer them, so the id pressed is the id searched for. They
*   disagreed before: the button carried the name, both readers matched cell 1.
    rv = cell_of( it_cols = it_cols it_row = it_row iv_name = c_col_partner ).
    IF rv IS INITIAL.
      rv = cell_of( it_cols = it_cols it_row = it_row iv_name = c_col_name ).
    ENDIF.
  ENDMETHOD.


  METHOD own_form_save.

    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.


    DATA(lv_IDtype) = condense( io_ctx->get_val( 'ID_TYPE' ) ).
    DATA(lv_eID) = condense( io_ctx->get_val( 'EMIRATES_ID') ).
    DATA(lv_dob) = condense( io_ctx->get_val( 'BIRTH_DATE' ) ).
    DATA(lv_nation) = condense( io_ctx->get_val( 'NATIONALITY' ) ).
    DATA(lv_share) = condense( io_ctx->get_val( 'SHARE_PER' ) ).
    DATA(lv_name) = condense( io_ctx->get_val( 'NAME_POP' ) ).
    DATA(lv_mob) = condense( io_ctx->get_val( 'TELEPHONE_POP' ) ).
    DATA(lv_eaddr) = condense( io_ctx->get_val( 'EMAIL_POP' ) ).

*   Built ONCE, to the SPEC's width, each value placed in the column that carries
*   its name. The two branches below used to hold the same nine APPENDs twice
*   over, which is how they could drift apart, and appending in a fixed order is
*   what put every cell one place left of where it was read back.
    CLEAR lt_row.
    DO lines( ls_g-columns ) TIMES.
      APPEND `` TO lt_row.
    ENDDO.

    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_name   iv_val = lv_name
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_mobile iv_val = lv_mob
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_email  iv_val = lv_eaddr
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_share  iv_val = lv_share
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_nat    iv_val = lv_nation
              CHANGING  ct_row  = lt_row ).

*   PARTNER takes the BP NUMBER, never LV_ID. LV_ID is the local row id, and
*   writing it here posted a timestamp - or, after an Edit, the owner's name -
*   into GS_DATA-OWNERS-PARTNER. See C_OWN_BP.
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_partner
                        iv_val  = condense( io_ctx->get_val( c_own_bp ) )
              CHANGING  ct_row  = lt_row ).

*   EMIRATES_ID has a column and persists. BIRTH_DATE has none, so PUT_CELL( )
*   skips it; written anyway so that adding the ZRAK_T_JNY_COL row is all it
*   takes to make it persist and let Edit restore the date - no code change.
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_eid     iv_val = lv_eid
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_dob     iv_val = lv_dob
              CHANGING  ct_row  = lt_row ).


    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_activity iv_val = 'X'
                 CHANGING  ct_row  = lt_row ).



*   ID type is deliberately not stored. It is a popup control, not owner data,
*   and it had no column - the value that used to travel under its position was
*   the one being read back as the Emirates ID.
    CLEAR lv_idtype.

*   Without a PARTNER column there is no key, so an owner is matched on name.
*   Say so once rather than letting Edit look broken.
    IF col_ix( it_cols = ls_g-columns iv_name = c_col_partner ) = 0.
      io_ctx->add_msg(
        iv_type = 'Warning'
        iv_text = |Owner rows are matched by name: { c_grid } has no { c_col_partner } | &&
                  |column. Add it in ZRAK_T_JNY_COL so two owners sharing a name | &&
                  |stay separate.| ).
    ENDIF.

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF row_key_of( it_cols = ls_g-columns it_row = lt_r ) = lv_id.
        lv_found = abap_true.
        APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      APPEND lt_row TO ls_new-rows.
    ENDIF.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).

*   ---- THE FILES FOLLOW THE OWNER TO THEIR REAL KEY -------------------
*   THE TWO KEYS NEVER MET. OWN_NEW( ) mints a TIMESTAMP into C_OWN_ID and
*   every uploader in the dialog stages its files under it. OWN_EDIT( ) sets
*   C_OWN_ID from ROW_KEY_OF( ), which returns the PARTNER - or the NAME when
*   there is no partner column. A timestamp is neither, so re-opening an owner
*   asked for files under a key nothing was ever stored under, and the chips
*   came back empty.
*
*   THE FILES WERE NEVER LOST, which is what made it hard to see: they stayed
*   in staging, posted correctly, and satisfied a required check that tests
*   the field. Only the chips were missing - so the citizen attached the same
*   document again.
*
*   AND IT LOOKED LIKE IT ONLY AFFECTED THE NEWEST OWNER, because
*   RENDER_CHIPS( ) also draws the BACKEND's filed list. An owner posted on an
*   earlier round trip gets their documents back from there whatever the local
*   key says; the one added since has only the staged copy, so it is the only
*   one where the broken key shows.
*
*   RE-KEYED HERE, AT THE SAVE, because this is the first moment both values
*   are known - LV_ID is what the files were staged under, and ROW_KEY_OF( )
*   on the row just built is what every later read will ask for. Field left
*   blank so all six uploaders move together.
*
*   AN EDIT MOVES NOTHING. The two keys are already equal there, and
*   REKEY_ATTACHMENTS( ) returns without touching anything when they match.
    DATA(lv_final_key) = row_key_of( it_cols = ls_g-columns it_row = lt_row ).
    IF lv_final_key IS NOT INITIAL.
      io_ctx->rekey_attachments( iv_from = lv_id
                                 iv_to   = lv_final_key ).
    ENDIF.

  ENDMETHOD.


  METHOD render_own_list.
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_hd->title( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_owner iv_default = 'Owner' ) class = 'rakBlkTitle' ).
    lo_hd->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_add_owner iv_default = 'Add Owner' )
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add'
                   press = io_ctx->event( c_evt_ownew ) ).

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).
*    lo_cl->column( )->text( 'BP' ).
    lo_cl->column( )->text( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_col_name iv_default = 'Owner Name' ) ).
    lo_cl->column( )->text( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-col_mobile_number iv_default = 'Mobile Number' ) ).
    lo_cl->column( )->text( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_col_email iv_default = 'Email Address' ) ).
    lo_cl->column( )->text( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_col_shares iv_default = 'Owner Shares' ) ).
    lo_cl->column( )->text( zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bpp_nat iv_default = 'Nationality' ) ).
    lo_cl->column( halign = 'End' )->text( '' ).

*   Read once, not once per row - this is a ~240-row T005T select. Through the
*   shared helper rather than a third copy of the SELECT.
    DATA(lt_nat) = zcl_rak_journey_util=>nationalities( ).

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
*     By column name, so this follows the spec rather than assuming it. These
*     positions disagreed with OWN_EDIT( )'s - nationality was read from 6 here
*     and from 9 there - on a grid that has five columns and neither.
      DATA(lv_nam)  = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_name ).
      DATA(lv_no)   = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_mobile ).
      DATA(lv_eadd) = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_email ).
      DATA(lv_shr)  = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_share ).
      DATA(lv_eid)  = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_eid ).

*     The row stores LAND1; the citizen should see the country, not 'AE'. An
*     unknown code falls back to itself rather than rendering blank.
      DATA(lv_natkey) = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_nat ).
      DATA(lv_nat)    = lv_natkey.
      IF lv_natkey IS NOT INITIAL.
        lv_nat = VALUE #( lt_nat[ key = lv_natkey ]-text DEFAULT lv_natkey ).
      ENDIF.

      DATA(lv_id) = row_key_of( it_cols = ls_g-columns it_row = lt_r ).

**     How many files this owner has. Counting them here is the only way the
**     citizen can see, from the list, whose documents are still missing.
*      DATA lv_docs TYPE i.
*      CLEAR lv_docs.
*      LOOP AT io_ctx->get_attachment_files( ) INTO DATA(ls_af).
*        IF ls_af-identifier1 CS |_{ lv_id }|.
*          lv_docs = lv_docs + 1.
*        ENDIF.
*      ENDLOOP.

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
*     Name over Emirates ID, as the legacy screen had it.
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_nam ).
*      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
      lo_cells->text( lv_no ).
      lo_cells->text( lv_eadd ).
      lo_cells->text( lv_shr ).
      lo_cells->text( lv_nat ).


*      lo_cells->object_status(
*        text  = |{ lv_docs } file(s)|
*        state = COND #( WHEN lv_docs > 0 THEN 'Success' ELSE 'Warning' )
*        icon  = COND #( WHEN lv_docs > 0 THEN 'sap-icon://attachment' ELSE 'sap-icon://alert' ) ).
*     Two buttons rather than the legacy overflow menu: one press instead of
*     two, and nothing hidden behind an icon a citizen has to discover.
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_edit_tip iv_default = 'Edit owner details' )
                      press   = io_ctx->event( |OWN_EDIT_{ lv_id }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-delete iv_default = 'Delete' )
                      press   = io_ctx->event( |OWN_DEL_{ lv_id }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip(
        text     = zcl_rak_text=>get(
                     iv_no      = zcl_rak_text=>c_no-own_none_yet
                     iv_default = 'No owners yet. Press Add Owner to enter the first one.' )
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.

  ENDMETHOD.


  METHOD render_own_popup.

*   ONE dialog: the owner's details and their documents. No drill-down, no
*   second popup - the list is on the step behind and this is the form that
*   adds one line to it.
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_owner iv_default = 'Owner' ) contentwidth = '54rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

    lo_c->title( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_details iv_default = 'Owner Details' ) class = 'rakBlkTitle' ).

    LOOP AT io_ctx->msgs( ) INTO DATA(ls_pmsg).
      lo_c->message_strip( text     = ls_pmsg-text
                           type     = COND string( WHEN ls_pmsg-type IS NOT INITIAL
                                                   THEN ls_pmsg-type ELSE 'Information' )
                           showicon = abap_true
                           class    = 'sapUiTinyMarginBottom' ).
    ENDLOOP.
*   Same two-column SimpleForm/ResponsiveGridLayout combination DIALOG_FORM( )
*   uses in ZCL_RAK_JOURNEY_LOGIC (it cannot be called directly here - it owns
*   and closes its own dialog, with no room for the Documents section below -
*   but its layout is copied so this reads like every other popup). Search
*   moves off the section header and onto the Emirates ID field's own
*   value-help icon, the same F4_EVT affordance DIALOG_FORM( ) offers per
*   field; pressing it or Enter both still fire C_EVT_OWNSR into the
*   on_popup_event handler below, unchanged.
    DATA(lo_form) = lo_c->simple_form( editable                = abap_true
                                       layout                  = 'ResponsiveGridLayout'
                                       columnsxl               = '2'
                                       columnsl                = '2'
                                       columnsm                = '2'
                                       labelspanxl             = '12'
                                       labelspanl              = '12'
                                       labelspanm              = '12'
                                       adjustlabelspan         = 'false'
                                       singlecontainerfullsize = abap_false
                                                                 )->content( ns = 'form' ).

    lo_form->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_identification iv_default = 'Identification' ) required = abap_true ).
*   Emirates ID is the only option, and OWN_FORM_LOAD now defaults it - so
*   there is nothing left for the citizen to pick from this dropdown.
    lo_form->combobox( selectedkey = io_ctx->bind( c_identity )
                       editable    = abap_false
                       placeholder = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-select iv_default = 'Select' )
                                     )->item( key = '1' text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bpp_eid iv_default = 'Emirates ID' ) ).
*      )->item( key = '2'    text = 'Passport' ).

    lo_form->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bpp_eid iv_default = 'Emirates ID' ) required = abap_true ).
*   The search icon and Enter both do the same thing. Somebody who has just
*   typed fifteen digits should not have to reach for the mouse.
    lo_form->input( value            = io_ctx->bind( c_id )
                    placeholder      = '784-xxxx-xxxxxxx-x'
                    showvaluehelp    = abap_true
                    valuehelprequest = io_ctx->event( c_evt_ownsr )
                    submit           = io_ctx->event( c_evt_ownsr ) ).
    lo_form->button( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-search iv_default = 'Search' ) press = io_ctx->event( c_evt_ownsr ) ).

    lo_form->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_dob iv_default = 'Birth Date' ) displayonly = abap_true required = abap_true ).
    lo_form->date_picker( value         = io_ctx->bind( c_dob )
                          valueformat   = 'yyyy-MM-dd'
                          displayformat = 'dd.MM.yyyy'
                          editable      = abap_false ).

    lo_form->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-bpp_nat iv_default = 'Nationality' ) required = abap_true ).
    DATA(lo_nat) = lo_form->combobox( selectedkey = io_ctx->bind( c_nat )
                                      editable    = abap_false
                                      placeholder = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-select iv_default = 'Select' ) ).
*   T005T, not a hand-typed list. The 106-item literal this replaced stopped
*   at "Kenya" and never had United Arab Emirates in it at all - or anything
*   else L through Z. Same source ZCL_RAK_BP_POPUP already reads for its own
*   nationality dropdown, so a country missing here can't happen again the
*   same way, and it comes back correctly per language for free.
    SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = @sy-langu
      ORDER BY land1 ASCENDING
      INTO TABLE @DATA(lt_nat).
    IF lt_nat IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
        FROM t005t
        WHERE spras = 'E'
        ORDER BY land1 ASCENDING
        INTO TABLE @lt_nat.
    ENDIF.
    LOOP AT lt_nat INTO DATA(ls_nat).
      lo_nat->item( key = ls_nat-key text = ls_nat-text ).
    ENDLOOP.

    lo_form->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_shares_pct iv_default = 'Shares %' ) required = abap_true ).
    lo_form->input( value = io_ctx->bind( c_share ) type = 'Number' ).

*   ---- their documents ------------------------------------------------
*   iv_key is what makes a repeating list work. Every uploader here is keyed on
*   THIS owner's id, so the chips shown are only theirs and the file reaches the
*   backend as identifier1 = MAIN_DOC_<owner id> - the shape the D0xx BAdI
*   already reads for OWNERS_SEARCH_<n>.
*
*   Without the key every owner's files would land in one chip list with nothing
*   to tell them apart, and the delete button beside a chip would remove
*   somebody else's document.
    lo_c->title( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_documents iv_default = 'Documents' ) class = 'rakBlkTitle sapUiSmallMarginTop' ).

*   Two per row, the same rakRow/rakCell layout as the fields above.
    DATA(lo_dr1) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d1)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d1->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_eid iv_default = 'Emirates ID Copy' ) required = abap_true ).
    io_ctx->render_upload( io_view = lo_d1 iv_field = '60' iv_key = lv_id ).
    DATA(lo_d2)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d2->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_passport iv_default = 'Passport Copy' ) ).
    io_ctx->render_upload( io_view = lo_d2 iv_field = 'NL' iv_key = lv_id ).

    DATA(lo_dr2) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d3)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d3->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_intro iv_default = 'Introductory Statement' ) required = abap_true ).
    io_ctx->render_upload( io_view = lo_d3 iv_field = 'FE' iv_key = lv_id ).
    DATA(lo_d4)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d4->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_criminal iv_default = 'Criminal Clearance certificate' ) required = abap_true ).
    io_ctx->render_upload( io_view = lo_d4 iv_field = '6P' iv_key = lv_id ).

    DATA(lo_dr3) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d5)  = lo_dr3->vbox( class = 'rakCell' ).
    lo_d5->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_cv iv_default = 'Curriculum Vitae' ) required = abap_true ).
    io_ctx->render_upload( io_view = lo_d5 iv_field = 'FF' iv_key = lv_id ).
    DATA(lo_d6)  = lo_dr3->vbox( class = 'rakCell' ).
    lo_d6->label( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_doc_family iv_default = 'Family Book' ) ).
    io_ctx->render_upload( io_view = lo_d6 iv_field = '78' iv_key = lv_id ).


* Add button on pop-up
    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-own_btn_add iv_default = 'Add' )
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
* Close button on pop-up
    lo_b->button( text = zcl_rak_text=>get( iv_no = zcl_rak_text=>c_no-close iv_default = 'Close' ) press = io_ctx->event( c_evt_owncx ) ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
    IF io_ctx->get_step( ) = 1.
      render_own_list( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD own_delete.

    DATA(ls_g)   = io_ctx->get_grid_data( c_grid ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
*   Matched the same way the button's id was built. Reading cell 1 blindly meant
*   comparing against whatever happens to sit first, which on the current
*   five-column spec is the owner's NAME, not a key.
    LOOP AT ls_g-rows INTO DATA(lt_r).
      CHECK row_key_of( it_cols = ls_g-columns it_row = lt_r ) <> iv_id.
      APPEND lt_r TO ls_new-rows.
    ENDLOOP.
    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
*   The owner is gone from the list; their FILES are not. Deleting them here
*   would be the right thing and the framework has no call for it yet, so this
*   says so rather than pretending otherwise.
*    io_ctx->add_msg( iv_type = 'Warning'
*                     iv_text = |Owner { iv_id } removed. Any documents already | &&
*                               |attached to them stay staged until the form is cleared.| )

  ENDMETHOD.


  METHOD own_edit.

    DATA iv_idnumber        TYPE bu_id_number.
    DATA ev_partner         TYPE partner.
    DATA ev_id_number       TYPE bu_id_number.
    DATA ev_passport        TYPE bu_id_number.
    DATA ev_name            TYPE bu_name1tx.
    DATA ev_phone           TYPE farp_mobile.
    DATA ev_email           TYPE ad_smtpadr.
    DATA ev_nationality     TYPE natio50.
    DATA ev_nationality_key TYPE bu_natio.
    DATA ev_date_of_birth   TYPE bu_birthdt.
    DATA ev_message         TYPE bapiret2-message.

*   "When user click on edit pencil for OWNER ROW they should be able
*   "to see existing details and edit it
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
*     Matched the way RENDER_OWN_LIST( ) built the id it put on the button.
*     This read cell 1 while the button carried the NAME from cell 2, so on the
*     five-column spec the two could never meet and Edit found nothing.
      CHECK row_key_of( it_cols = ls_g-columns it_row = lt_r ) = iv_id.

*     Keep the row's own key so OWN_FORM_SAVE updates this row on Add rather
*     than appending a duplicate.
      io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).

*     And the row's own BP, so saving the edit writes the partner number back
*     rather than blanking it. Without this the PARTNER column - and the row
*     key with it - changed on every Edit.
      io_ctx->set_val( iv_name  = c_own_bp
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_partner ) ).

*
**     "Identity
*      io_ctx->set_val( iv_name = c_identity iv_value = '1' ).
*
**      "Emirates Id
*
*
*        data(lv_eid) = io_ctx->get_val( iv_name = c_id ) .


*     By column name. Columns 6 to 9 were being read on a grid that has five, so
*     the Emirates ID and nationality came back empty; the popup then kept
*     whatever the previous owner had typed, which is the reported symptom.
      io_ctx->set_val( iv_name = 'NAME_POP'
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_name ) ).
      io_ctx->set_val( iv_name = 'TELEPHONE_POP'
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_mobile ) ).
      io_ctx->set_val( iv_name = 'EMAIL_POP'
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_email ) ).
      io_ctx->set_val( iv_name = c_share
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_share ) ).
      io_ctx->set_val( iv_name = c_nat
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_nat ) ).
      io_ctx->set_val( iv_name = c_id
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_eid ) ).
      io_ctx->set_val( iv_name = c_dob
        iv_value = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_dob ) ).
      io_ctx->set_val( iv_name = c_identity iv_value = '1' ).



*      "Get data for fields emrates id is there and edit button is clicked.
      DATA(lv_eid) = io_ctx->get_val( c_id ).
      IF lv_eid IS NOT INITIAL.
        CONDENSE lv_eid .

        iv_idnumber = lv_eid .
        CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
          EXPORTING
            iv_type            = 'YFS002'
            iv_idnumber        = iv_idnumber
*           IV_APP             = IV_APP
          IMPORTING
            ev_partner         = ev_partner
            ev_id_number       = ev_id_number
            ev_passport        = ev_passport
            ev_name            = ev_name
            ev_phone           = ev_phone
            ev_email           = ev_email
            ev_nationality     = ev_nationality
            ev_nationality_key = ev_nationality_key
            ev_date_of_birth   = ev_date_of_birth
            ev_message         = ev_message.


        io_ctx->set_val( iv_name = 'BIRTH_DATE'     iv_value = |{ ev_date_of_birth }| ).
        io_ctx->set_val( iv_name = 'NATIONALITY' iv_value = |{ ev_nationality_key }| ).
        io_ctx->set_val( iv_name = 'TELEPHONE_POP'  iv_value = |{ ev_phone }| ).
        io_ctx->set_val( iv_name = 'EMAIL_POP'      iv_value = |{ ev_email }| ).
        io_ctx->set_val( iv_name = 'EMIRATES_ID'    iv_value = |{ lv_eid }| ).
        io_ctx->set_val( iv_name = c_own_bp         iv_value = |{ ev_partner }| ).
        io_ctx->set_val( iv_name = 'NAME_POP'       iv_value = |{ ev_name }| ).

      ENDIF.

      EXIT.
    ENDLOOP.



  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_attachments.
*SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_ATTACHMENTS(
*  EXPORTING
*    IO_CTX = IO_CTX
*  CHANGING
*    CT_ATT = CT_ATT
*       ).


    LOOP AT ct_att ASSIGNING FIELD-SYMBOL(<fs_attach>) WHERE identifier2 IS INITIAL.
      CASE <fs_attach>-identifier1+0(2).
        WHEN '60'.
          <fs_attach>-identifier2 = '60'.
        WHEN 'NL'.
          <fs_attach>-identifier2 = 'NL'.
        WHEN 'FE'.
          <fs_attach>-identifier2 = 'FE'.
        WHEN '6P'.
          <fs_attach>-identifier2 = '6P'.
        WHEN 'FF'.
          <fs_attach>-identifier2 = 'FF'.
        WHEN '78'.
          <fs_attach>-identifier2 = '78'.
        WHEN OTHERS.
          CONTINUE.
      ENDCASE.
      <fs_attach>-file_name = |{ <fs_attach>-identifier1 }.pdf|.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
