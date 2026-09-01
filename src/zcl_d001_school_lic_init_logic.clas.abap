CLASS zcl_d001_school_lic_init_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS zif_rak_journey_logic~get_table
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_before_fields
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_before_post
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_before_tables
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_change
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_custom_validate
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_init
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_popup_event
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_before_field
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_popup
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_start
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_search
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_value_help
        REDEFINITION .
    METHODS zif_rak_journey_logic~render_field
        REDEFINITION .
    METHODS zif_rak_journey_logic~on_render_end
        REDEFINITION .
  PROTECTED SECTION.

    METHODS build_pay_url
        REDEFINITION .
    METHODS pay_render
        REDEFINITION .
    METHODS prepare_payment
        REDEFINITION .
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
* Position was the bug. OWN_FORM_SAVE( ) appended nine cells - key, name, mobile,
* e-mail, share, id type, Emirates ID, passport, nationality - but the grid is
* whatever ZRAK_T_JNY_COL says it is, and for OWNERS_SEARCH that is FIVE columns:
* NAME, MOBILE_NUMBER, EMAIL_ADDRESS, SHARE_PER, NATIONALITY. (The field's
* DEFAULT_VAL still lists a leading PARTNER column, but ZRAK_T_JNY_COL wins
* whenever it has rows - see GRID_COLS( ) - so that entry is dead.)
*
* SET_GRID_DATA( ) walks the CONFIGURED columns and takes cell N from the row, so
* the nine cells landed one place to the left of where they read: the stored
* Owner Name was the row key, Mobile held the name, Share held the e-mail, and
* Nationality held the share. RENDER_OWN_LIST( ) then read one place to the right
* again, so the screen looked correct while the POST carried shifted data.
*
* Naming the columns removes the whole class of fault: a column that moves, or
* that is added to the spec later, is followed rather than silently mis-read, and
* one that is absent resolves to 0 and is skipped instead of shifting its
* neighbours.
  constants C_COL_PARTNER type STRING value 'PARTNER' ##NO_TEXT.
  constants C_COL_NAME    type STRING value 'NAME' ##NO_TEXT.
  constants C_COL_MOBILE  type STRING value 'MOBILE_NUMBER' ##NO_TEXT.
  constants C_COL_EMAIL   type STRING value 'EMAIL_ADDRESS' ##NO_TEXT.
  constants C_COL_SHARE   type STRING value 'SHARE_PER' ##NO_TEXT.
  constants C_COL_NAT     type STRING value 'NATIONALITY' ##NO_TEXT.
  constants C_COL_EID     type STRING value 'EMIRATES_ID' ##NO_TEXT.
  constants C_COL_DOB     type STRING value 'BIRTH_DATE' ##NO_TEXT.
  constants C_OWN_ID type STRING value 'OWN_ID' ##NO_TEXT.
  constants C_EVT_OWNEW type STRING value 'OWN_NEW' ##NO_TEXT.
  constants C_POP_OWN type STRING value 'TRIGGER_POPUP' ##NO_TEXT.
  constants C_TRIGGER_POPUP type STRING value 'TRIGGER_POPUP' ##NO_TEXT.

* The owner row the backend prefills carries the name and nothing else. Fill in
* what a BP lookup can supply so the citizen is not asked for data the register
* already holds - and so the Nationality column is not blank on arrival.
  methods FILL_OWNER_GAPS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
  methods FILL_CELL
    importing
      !IV_POS type I
      !IV_VAL type STRING
    changing
      !CT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
      !CV_TOUCHED type ABAP_BOOL .
* Position of a named column in the grid's own spec, or 0 when the spec has no
* such column. 0 is a legitimate answer, not an error: OWNERS_SEARCH genuinely
* has nowhere to keep an Emirates ID or a birth date today.
  methods COL_IX
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
    returning
      value(RV) type I .
* Place a value in the named column. A column the spec does not define is
* skipped, never appended - appending is what shifted every later cell.
  methods PUT_CELL
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
      !IV_VAL type STRING
    changing
      !CT_ROW type ZIF_RAK_JOURNEY=>TT_STRING .
* Read one named cell out of a row. Blank when the column is not in the spec.
  methods CELL_OF
    importing
      !IT_COLS type ZIF_RAK_JOURNEY=>TT_STRING
      !IT_ROW type ZIF_RAK_JOURNEY=>TT_STRING
      !IV_NAME type STRING
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
*   This was an EMPTY redefinition - nothing but the commented-out SE24 template
*   above. PREPARE_PAYMENT is not a hook with an empty default: the base has a
*   real 89-line body and the engine calls it on the way into the payment step.
*   Redefining it to nothing therefore switched payment preparation off on a
*   FEE-BEARING journey, silently, while BUILD_PAY_URL( ) and PAY_RENDER( ) next
*   to it both chained correctly and looked like proof that the card worked.
*
*   Nothing is added here, so it is a straight pass-through. Kept as a chaining
*   redefinition rather than deleted from the class so the intent is on the
*   record next to its two siblings.
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
        rs_data-columns = VALUE #( ( `Block Name` ) ( `No. of floors` ) ( `No. of rooms` ) ).

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

*   Runs before the step's fields are built, which is the first point at which
*   the backend's prefilled owner row is in the model and still editable.
*   Self-limiting: it only touches cells that are EMPTY, so once a row is
*   complete it does nothing, and it can never overwrite what a citizen typed.
    fill_owner_gaps( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " Real fee handling exists on this journey (PAYFEE) — do NOT blanket-
    " strip PAY_*/PAYFEE here the way the fee-less journeys did.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'DECLARE'.

*   ACCEPTTERMS is NOT stripped, though it used to be. It carries
*   TECH_NAME 'ACCEPT_TERMS' in ZRAK_T_JNY_FLD, so it is a real backend field -
*   the citizen's acceptance of the terms - and deleting it here meant the one
*   record that they accepted never left CJS.

*   The payment CONTEXT and the payment WORKING STATE, which are not the fee.
*
*   PAY_BUKRS, PAY_MATERIAL, PAY_CASES_FOR and PAY_ETISALAT tell ZCL_RAK_PAY_ENGINE
*   which department it is acting for; PAY_STARTED, PAY_REFERENCE, PAY_APPURL and
*   PAY_TOTAL are its own bookkeeping. None of them is a /QNV field, and none of
*   them belongs in the post - D026 strips exactly this set for exactly this
*   reason. D001 was stripping neither.
*
*   NAMED, not 'PAY_*'. A wildcard strip would also take PAY_TOTAL, and PAY_TOTAL
*   is NOT scratch on this journey: ZRAK_T_JNY_FLD gives it TECH_NAME
*   'TOTALFEESVALUE', so it is the fee total the backend is waiting for. Only the
*   keys with no TECH_NAME are removed.
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

*   PAYFEE itself is NOT stripped and SUPER is deliberately not called. The base
*   ON_BEFORE_POST removes PAYFEE, which is right for a journey with no fee and
*   wrong here: D001 has a real payment step and the fee has to reach the backend.

    " REVIEW: substitute {APPLICANT_NAME} in the DECLARE field's rendered
    " text once the source field for the applicant/owner name is confirmed.
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
*       DATA(lv_owners) = io_ctx->get_val( 'OWNERS_SEARCH' ).

*        DATA(lv_owners) = io_ctx->get_val( 'GS_DATA-OWNERS[]' ).
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
          rt = VALUE #( BASE rt ( type = 'Error' text = 'Select at least one education stage.' ) ).
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
*       Every field the popup marks with a star, and each one BLOCKS. The shares
*       check used to be an ELSEIF that raised a Warning and then fell straight
*       through to OWN_FORM_SAVE( ) - so "add without filling mandatory" saved
*       anyway. Two things had to change: the RETURN, and the type. The engine
*       gates on type = 'Error' only; a 'Warning' is displayed and ignored.
        IF io_ctx->get_val( c_identity )   IS INITIAL
           OR io_ctx->get_val( c_id )      IS INITIAL
           OR io_ctx->get_val( c_dob )     IS INITIAL
           OR io_ctx->get_val( c_nat )     IS INITIAL
           OR io_ctx->get_val( 'NAME_POP' ) IS INITIAL.

          io_ctx->add_msg( iv_type = 'Error'
                           iv_text = 'Fill every required field before adding the owner.' ).
          RETURN.
        ENDIF.

        IF io_ctx->get_val( c_share ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Error'
                           iv_text = 'Enter the ownership share percentage.' ).
          RETURN.
        ENDIF.

        own_form_save( io_ctx ).

        io_ctx->close_popup( ). "Close pop-up screen after adding data
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |{ io_ctx->get_val( c_id ) } added to the owner list.| ).

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
          io_ctx->set_val( iv_name = 'NAME_POP'       iv_value = |{ ev_name }| ).
          io_ctx->set_val( iv_name = 'TELEPHONE_POP'  iv_value = |{ ev_phone }| ).
          io_ctx->set_val( iv_name = 'EMAIL_POP'      iv_value = |{ ev_email }| ).
          io_ctx->set_val( iv_name = 'BIRTH_DATE'     iv_value = |{ ev_date_of_birth }| ).
*         EV_NATIONALITY_KEY, not EV_NATIONALITY. The first is BU_NATIO - the
*         same LAND1 the dropdown above is keyed on, so the search result lands
*         on a real entry and the combobox shows it selected. The second is
*         NATIO50, the display text, which matched no key and left the control
*         blank - and then saved blank into the owner row.
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


*    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>)." WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
**      IF <t>-ui_table_column1 = lv_sel.
**        <t>-ui_table_column29 = 'S'.
**      ENDIF.
*    ENDLOOP.
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
      IF sy-langu = 'E'.
        io_ctx->set_val( iv_name = 'APPLICANTNAME' iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = 'APPLICANTNAME' iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

*      "Emirates Id/Applicant ID
      io_ctx->set_val( iv_name = 'APPLICANT_ID' iv_value = CONV #( ls_bp-emirates_id ) ).

*      "Login BP
      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

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
    io_ctx->set_val( iv_name = c_identity iv_value = '' ).
    io_ctx->set_val( iv_name = c_id iv_value = '' ).
    io_ctx->set_val( iv_name = c_nat iv_value = '' ).
    io_ctx->set_val( iv_name = C_DOB iv_value = '' ).
    io_ctx->set_val( iv_name = c_share iv_value = '' ).
    io_ctx->set_val( iv_name = 'NAME_POP'      iv_value = '' ).
    io_ctx->set_val( iv_name = 'TELEPHONE_POP' iv_value = '' ).
    io_ctx->set_val( iv_name = 'EMAIL_POP'     iv_value = '' ).

    IF iv_id IS INITIAL.
*     New owner. The id is minted NOW and not on save, because the uploaders in
*     the dialog key their files on it - a file attached before the row exists
*     still has to belong to the right person.
*
*     It also has to be UNIQUE, which is what was actually broken: with this
*     block commented out, OWN_ID stayed blank for every new owner, and
*     OWN_FORM_SAVE( ) matched that blank key against the blank key the previous
*     owner had written - so each new owner overwrote the one before it. The
*     row prefilled from step 1 carries a real key, which is why exactly one
*     popup-added owner ever survived alongside it.
      TRY.
          io_ctx->set_val( iv_name  = c_own_id
                           iv_value = |OWN{ cl_system_uuid=>create_uuid_c32_static( ) }| ).
        CATCH cx_uuid_error.
*         A clock-based fallback so a UUID service failure cannot silently
*         reinstate the blank key and the overwrite that came with it.
          io_ctx->set_val( iv_name  = c_own_id
                           iv_value = |OWN{ sy-datum }{ sy-uzeit }{ sy-timlo }| ).
      ENDTRY.
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
*    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).
*      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
*      io_ctx->set_val( iv_name = c_identity  iv_value = VALUE #( lt_r[ 2 ] OPTIONAL ) ).
*      io_ctx->set_val( iv_name = c_id   iv_value = VALUE #( lt_r[ 3 ] OPTIONAL ) ).
*      io_ctx->set_val( iv_name = c_nat   iv_value = VALUE #( lt_r[ 4 ] OPTIONAL ) ).
*      io_ctx->set_val( iv_name = c_share iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
*      EXIT.
*    ENDLOOP.

  ENDMETHOD.


  METHOD fill_owner_gaps.
*---------------------------------------------------------------------------------------*
* The Partner step opens with one owner already in the grid - the applicant - put
* there by the backend read. It arrives with the NAME only, which is why the
* Nationality column was reported empty on a table nobody had touched yet.
*
* The register already knows the rest. ZFE_CJ_SEARCH_BP_BY_ID is the same call the
* Add Owner popup makes, so the prefilled row ends up filled the same way a
* hand-added one does, from the same source, in the same LAND1 vocabulary.
*
* THREE THINGS KEEP THIS SAFE TO CALL ON EVERY ROUND TRIP:
*   - it writes only into cells that are EMPTY, so a citizen's own entry is never
*     replaced and an intentionally cleared field is not refilled;
*   - it does nothing at all unless some row is actually short, so once the grid
*     is complete there is no lookup and no write;
*   - it writes back only when something changed, so it cannot trigger a render
*     loop by dirtying the model on every pass.
*---------------------------------------------------------------------------------------*
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).
    CHECK ls_g-rows IS NOT INITIAL.

    DATA lv_touched TYPE abap_bool.
    DATA(lt_rows)   = ls_g-rows.

    DATA lv_ix TYPE i.

    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<row>).
*     Counted, not read from SY-TABIX. SY-TABIX is only guaranteed immediately
*     after the LOOP statement, and there are table expressions between there and
*     the test below - so the row number is kept explicitly rather than trusted.
      lv_ix = lv_ix + 1.

      DATA(lv_eid) = condense( cell_of( it_cols = ls_g-columns it_row = <row>
                                        iv_name = c_col_eid ) ).

*     The applicant's own row may not carry its Emirates ID yet either - and on
*     the current five-column spec there is no EMIRATES_ID column at all, so it
*     never does. ON_INIT put it in APPLICANT_ID from the login BP, so use that
*     for the first row rather than giving up on the one row that is certain to
*     be the applicant's.
      IF lv_eid IS INITIAL AND lv_ix = 1.
        lv_eid = condense( io_ctx->get_val( 'APPLICANT_ID' ) ).
      ENDIF.
      CHECK lv_eid IS NOT INITIAL.

*     Nothing missing on this row - do not spend a backend call on it.
      IF cell_of( it_cols = ls_g-columns it_row = <row> iv_name = c_col_mobile ) IS NOT INITIAL
         AND cell_of( it_cols = ls_g-columns it_row = <row> iv_name = c_col_email ) IS NOT INITIAL
         AND cell_of( it_cols = ls_g-columns it_row = <row> iv_name = c_col_nat ) IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_idnumber        TYPE bu_id_number.
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

      CLEAR: ev_partner, ev_id_number, ev_passport, ev_name, ev_phone, ev_email,
             ev_nationality, ev_nationality_key, ev_date_of_birth, ev_message.
      lv_idnumber = lv_eid.

      CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
        EXPORTING
          iv_type            = 'YFS002'
          iv_idnumber        = lv_idnumber
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

*     No such BP, or a register with nothing to add. Leave the row alone rather
*     than blanking cells that already hold something.
      CHECK ev_partner IS NOT INITIAL.

      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_name )
                           iv_val = |{ ev_name }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_mobile )
                           iv_val = |{ ev_phone }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_email )
                           iv_val = |{ ev_email }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_nat )
                           iv_val = |{ ev_nationality_key }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_eid )
                           iv_val = |{ ev_id_number }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
      fill_cell( EXPORTING iv_pos = col_ix( it_cols = ls_g-columns iv_name = c_col_dob )
                           iv_val = |{ ev_date_of_birth }|
                 CHANGING  ct_row = <row> cv_touched = lv_touched ).
    ENDLOOP.

    CHECK lv_touched = abap_true.

    io_ctx->set_grid_data( iv_field = c_grid
                           is_data  = VALUE #( columns = ls_g-columns rows = lt_rows ) ).
  ENDMETHOD.


  METHOD put_cell.
*   Place a value in the column that carries IV_NAME. A column the spec does not
*   define is skipped - never appended - because appending would push every
*   later cell one place along and recreate the shift this replaced.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    CHECK lines( ct_row ) >= lv_ix.

    READ TABLE ct_row INDEX lv_ix ASSIGNING FIELD-SYMBOL(<cell>).
    CHECK sy-subrc = 0.
    <cell> = iv_val.
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


  METHOD fill_cell.
*   Write only into an empty cell, and only into a cell the row actually has.
*   A row shorter than the position asked for is the grid spec being narrower
*   than this class expects - handled by OWN_FORM_SAVE( )'s width check, not by
*   silently growing the row here, which would push every later cell sideways.
    CHECK iv_val IS NOT INITIAL.
    CHECK iv_pos > 0.                  " 0 = the spec has no such column
    CHECK lines( ct_row ) >= iv_pos.

    READ TABLE ct_row INDEX iv_pos ASSIGNING FIELD-SYMBOL(<cell>).
    CHECK sy-subrc = 0.
    CHECK <cell> IS INITIAL.

    <cell>     = iv_val.
    cv_touched = abap_true.
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

*   The row is built to the SPEC's width, and each value is placed in the column
*   that carries its name. Appending in a fixed order was the defect: the grid is
*   five columns, the method appended nine, and everything landed one place left
*   of where it was read back.
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

*   These four have no column in OWNERS_SEARCH today, so PUT_CELL( ) skips them.
*   They are written anyway so that adding the ZRAK_T_JNY_COL rows is all it
*   takes to make them persist - no second code change.
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_partner iv_val = lv_id
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_eid     iv_val = lv_eid
              CHANGING  ct_row  = lt_row ).
    put_cell( EXPORTING it_cols = ls_g-columns iv_name = c_col_dob     iv_val = lv_dob
              CHANGING  ct_row  = lt_row ).

*   ID type is deliberately not written. It is a popup control, not owner data,
*   and there is no column for it - the value that used to reach the grid under
*   its name was the one being read back as the Emirates ID.
    CLEAR lv_idtype.

*   Without a PARTNER column there is no key to match an existing owner on, so
*   the grid cannot tell one owner from another and every save appends. Say so
*   once, plainly, rather than letting Edit look broken.
    DATA(lv_keyix) = col_ix( it_cols = ls_g-columns iv_name = c_col_partner ).
    IF lv_keyix = 0.
      io_ctx->add_msg(
        iv_type = 'Warning'
        iv_text = |Owner list cannot identify rows: { c_grid } has no { c_col_partner } | &&
                  |column. Add it in ZRAK_T_JNY_COL so editing and re-saving an | &&
                  |owner updates that owner instead of adding another.| ).
    ENDIF.

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF lv_keyix > 0 AND VALUE string( lt_r[ lv_keyix ] OPTIONAL ) = lv_id.
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


  ENDMETHOD.


  METHOD render_own_list.
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_hd->title( text = 'Owner' class = 'rakBlkTitle' ).
    lo_hd->button( text  = 'Add Owner'
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add'
                   press = io_ctx->event( c_evt_ownew ) ).

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).
    lo_cl->column( )->text( 'Owner Name' ).
    lo_cl->column( )->text( 'Mobile Number' ).
    lo_cl->column( )->text( 'Email Address' ).
    lo_cl->column( )->text( 'Owner Shares' ).
    lo_cl->column( )->text( 'Nationality' ).
    lo_cl->column( halign = 'End' )->text( '' ).

*   Read once, not once per row - this is a ~240-row T005T select.
    DATA(lt_nat) = zcl_rak_journey_util=>nationalities( ).

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
*     By column name, so this follows the spec instead of assuming it. The
*     Emirates ID and the row key have no column in OWNERS_SEARCH today, so both
*     come back blank rather than showing a neighbouring column's value.
      DATA(lv_nam)    = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_name ).
      DATA(lv_no)     = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_mobile ).
      DATA(lv_eadd)   = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_email ).
      DATA(lv_shr)    = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_share ).
      DATA(lv_eid)    = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_eid ).
      DATA(lv_natkey) = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_nat ).

*     The row key when there is one, the name when there is not - it only has to
*     be something OWN_EDIT( ) and OWN_DELETE( ) can find the row by again.
      DATA(lv_id) = cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_partner ).
      IF lv_id IS INITIAL.
        lv_id = lv_nam.
      ENDIF.

*     The row stores LAND1; the citizen should see the country, not 'AE'.
      DATA(lv_nat) = lv_natkey.
      IF lv_natkey IS NOT INITIAL.
        lv_nat = VALUE #( lt_nat[ key = lv_natkey ]-text DEFAULT lv_natkey ).
      ENDIF.

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
      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
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
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_id }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_id }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.

  ENDMETHOD.


  METHOD render_own_popup.

    TYPES:
      BEGIN OF ty_id_type,
        key  TYPE string,
        text TYPE string,
      END OF ty_id_type.
    DATA:lt_id_type TYPE TABLE OF ty_id_type,
         ls_id_type TYPE ty_id_type.

    ls_id_type-key = 1.
    ls_id_type-text = 'EID'.

    APPEND ls_id_type TO lt_id_type.

*  ONE dialog: the owner's details and their documents. No search, no drill-
*   down, no second popup - the list is on the step behind and this is the form
*   that adds one line to it.
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Owner' contentwidth = '40rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*              )->label( text = 'Emirates ID'
*              )->input( value = io_ctx->bind( 'EMIRATES_ID' ) width      = `50%`
*              )->button( text = 'Search' press = io_ctx->event( c_evt_ownsr )  type  = 'Emphasized' icon  = 'sap-icon://search'
*
*    ).

*   Search sits ON the section title, not under the Emirates ID field, because
*   it acts on the whole form: type the ID, press Search, and the rest fills in.
    DATA(lo_hdr) = lo_c->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    lo_hdr->title( text = 'Owner Details' class = 'rakBlkTitle' ).
    lo_hdr->button( text  = 'Search'
                    type  = 'Emphasized'
                    icon  = 'sap-icon://search'
                    press = io_ctx->event( c_evt_ownsr ) ).


*   Two per row, the way the legacy dialog laid it out.
    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'Identificatoin' class = 'rakReq' ).
*    lo_c1->select( value = io_ctx->bind( c_identity ) width = '17rem' ).
    lo_c1->combobox( selectedkey = io_ctx->bind(  c_identity )
   placeholder = 'select'
      )->item( key = '1'     text = 'Emirates ID' ).
*      )->item( key = '2'    text = 'Passport' ).
    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).



    lo_c2->label( text = 'Emirates ID' class = 'rakReq' ).
*   Enter in the ID box does the same as pressing Search. Somebody who has just
*   typed fifteen digits should not have to reach for the mouse.
    lo_c2->input( value       = io_ctx->bind( c_id )
                  width       = '17rem'
                  placeholder = '784-xxxx-xxxxxxx-x'
                  submit      = io_ctx->event( c_evt_ownsr ) ).
    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).

* Birth date
    DATA(lo_c3) = lo_r2->vbox( class = 'rakCell' ).
    lo_c3->label( text = 'Birth Date' ).
    lo_c3->input( value = io_ctx->bind( c_dob ) width = '17rem' ).
*  Ntionality
    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'Nationality' class = 'rakReq' ).
*    lo_c4->input( value = io_ctx->bind( c_nat ) width = '17rem' ).
*   The country list comes from T005T through the shared helper, keyed on LAND1.
*
*   It used to be 106 items hand-written here and keyed '1' to '106'. Three
*   things were wrong with that at once: the list stopped at Kenya, United Arab
*   Emirates was not in it, and - the reason nationality saved blank - the BP
*   search writes what ZFE_CJ_SEARCH_BP_BY_ID returns into this same field, so a
*   numeric key could never match. Dropdown, search-fill and saved value now all
*   speak LAND1.
    DATA(lo_nat) = lo_c4->combobox( selectedkey = io_ctx->bind( c_nat )
                                    placeholder = 'select' ).
    LOOP AT zcl_rak_journey_util=>nationalities( ) INTO DATA(ls_nat).
      lo_nat->item( key = ls_nat-key text = ls_nat-text ).
    ENDLOOP.

*Shares
    DATA(lo_c5) = lo_r2->vbox( class = 'rakCell' ).
    lo_c5->label( text = 'Shares %' class = 'rakReq' ).
    lo_c5->input( value = io_ctx->bind( c_share ) type = 'Number' width = '17rem' ).

*   ---- their documents ------------------------------------------------
*   iv_key is what makes a repeating list work. Every uploader here is keyed on
*   THIS owner's id, so the chips shown are only theirs and the file reaches the
*   backend as identifier1 = MAIN_DOC_<owner id> - the shape the D0xx BAdI
*   already reads for OWNERS_SEARCH_<n>.
*
*   Without the key every owner's files would land in one chip list with nothing
*   to tell them apart, and the delete button beside a chip would remove
*   somebody else's document.
    lo_c->title( text = 'Documents' class = 'rakBlkTitle sapUiSmallMarginTop' ).
    lo_c->label( text = 'Emirates ID Copy' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'MAIN_DOC' iv_key = lv_id ).
    lo_c->label( text = 'Passport Copy' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'PASS' iv_key = lv_id ).
    lo_c->label( text = 'Introductory Statement' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'INTRO' iv_key = lv_id ).
    lo_c->label( text = 'Criminal Clearance certificate' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'CRIMCC' iv_key = lv_id ).
    lo_c->label( text = 'Curriculum Vitae' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'CURR' iv_key = lv_id ).
    lo_c->label( text = 'Family Book' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'FBOOK' iv_key = lv_id ).


* Add button on pop-up
    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Add'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
* Close button on pop-up
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_owncx ) ).

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
*   Matched the same way RENDER_OWN_LIST( ) built the id it put on the button:
*   the PARTNER column when the spec has one, the name when it does not. Reading
*   cell 1 blindly deleted by whatever happened to sit first, which on the
*   current five-column spec is the owner's NAME, not a key.
    DATA(lv_keyix) = col_ix( it_cols = ls_g-columns iv_name = c_col_partner ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      DATA(lv_rowid) = cell_of( it_cols = ls_g-columns it_row = lt_r
                                iv_name = COND #( WHEN lv_keyix > 0
                                                  THEN c_col_partner ELSE c_col_name ) ).
      CHECK lv_rowid <> iv_id.
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


  method OWN_EDIT.
    "When user click on edit pencil for OWNER ROW they should be able
    "to see existing details and edit it
*   Indices match OWN_FORM_SAVE( )'s numbered column list exactly. They did not
*   before: this read columns 2-5 as identification / EID / nationality / shares,
*   but 2-4 hold the name, the mobile and the e-mail. That is why the reported
*   symptom was "EID Number is converting to mobile number" and "Identification
*   getting blank" - the mobile landed in the Emirates ID box, and the name
*   landed in a dropdown that has no such key, so it rendered empty.
*
*   Every field the popup shows is restored. Anything left unset here keeps
*   whatever the LAST owner typed, which is the other half of the report:
*   "its showing old entered data rather than showing selected row data".
    DATA(ls_g)     = io_ctx->get_grid_data( c_grid ).
    DATA(lv_keyix) = col_ix( it_cols = ls_g-columns iv_name = c_col_partner ).

    LOOP AT ls_g-rows INTO DATA(lt_r).
*     Without a PARTNER column there is no key, so there is no way to tell which
*     row was pressed. Matching on the name is the only thing left, and it is
*     better than opening the popup on whatever the previous owner typed.
      IF lv_keyix > 0.
        CHECK VALUE string( lt_r[ lv_keyix ] OPTIONAL ) = iv_id.
      ELSE.
        CHECK cell_of( it_cols = ls_g-columns it_row = lt_r iv_name = c_col_name ) = iv_id.
      ENDIF.

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
      EXIT.
    ENDLOOP.

  endmethod.
ENDCLASS.
