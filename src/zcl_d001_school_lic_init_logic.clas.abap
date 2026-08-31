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
  constants C_OWN_ID type STRING value 'OWN_ID' ##NO_TEXT.
  constants C_EVT_OWNEW type STRING value 'OWN_NEW' ##NO_TEXT.
  constants C_POP_OWN type STRING value 'TRIGGER_POPUP' ##NO_TEXT.
  constants C_TRIGGER_POPUP type STRING value 'TRIGGER_POPUP' ##NO_TEXT.

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
*CALL METHOD SUPER->PREPARE_PAYMENT
*  EXPORTING
*    IO_CTX =
*    .
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
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " Real fee handling exists on this journey (PAYFEE) — do NOT blanket-
    " strip PAY_*/PAYFEE here the way the fee-less journeys did.

    " UI-only scratch keys with no backend meaning.
    DELETE ct_kv WHERE key = 'DECLARE'.
    DELETE ct_kv WHERE key = 'ACCEPTTERMS'.

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

        LOOP AT ls_g-rows INTO DATA(lt_r).
          DATA(lv_id)  = VALUE string( lt_r[ 1 ] OPTIONAL ).
          DATA(lv_nam)  = VALUE string( lt_r[ 2 ] OPTIONAL ).
          DATA(lv_no) = VALUE string( lt_r[ 3 ] OPTIONAL ).
          DATA(lv_eadd)  = VALUE string( lt_r[ 4 ] OPTIONAL ).
          DATA(lv_shr) = VALUE string( lt_r[ 5 ] OPTIONAL ).

          IF lv_id IS INITIAL OR lv_nam IS INITIAL OR lv_eadd IS INITIAL OR lv_shr IS INITIAL.
            rt = VALUE #( ( type = 'Error' text = 'Add at least one owner before continuing.' ) ).
            Return.
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
*       Nationality and Shares used to be able to slip through unfilled - the
*       Nationality branch didn't exist and the Shares branch never RETURNed.
        IF io_ctx->get_val( c_identity )  IS INITIAL
           OR io_ctx->get_val( c_id ) IS INITIAL
           OR io_ctx->get_val( c_dob ) IS INITIAL
           OR io_ctx->get_val( c_nat ) IS INITIAL.

          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Kindly fill required details.' ).
          RETURN.
        ELSEIF io_ctx->get_val( c_share ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Kindly enter shares as 100' ).
          RETURN.
        ENDIF.

*       784-XXXX-XXXXXXX-X - the same shape as the field's own placeholder.
        DATA(lv_eid_chk) = condense( io_ctx->get_val( c_id ) ).
        FIND REGEX '^784-\d{4}-\d{7}-\d$' IN lv_eid_chk.
        IF sy-subrc <> 0.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Emirates ID must be in the format 784-XXXX-XXXXXXX-X.' ).
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
          io_ctx->set_val( iv_name = 'NATIONALITY' iv_value = |{ ev_nationality }| ).

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

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF VALUE string( lt_r[ 1 ] OPTIONAL ) = lv_id.
        lv_found = abap_true.
        CLEAR lt_row.
        APPEND lv_id TO lt_row.
* "Name
        APPEND lv_name TO lt_row.
* Mobile No.
        APPEND lv_mob TO lt_row.
* Email Address
        APPEND lv_eaddr TO lt_row.
* Shares
        APPEND  lv_share TO lt_row.
*ID type
        APPEND lv_IDtype  TO lt_row.
*Emirates ID
        APPEND lv_eID   TO lt_row.
*Passport
        APPEND lv_id   TO lt_row.
*Nationality
        APPEND lv_nation TO lt_row.

        APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      CLEAR lt_row.
      APPEND lv_id  TO lt_row.
* "Name
      APPEND lv_name TO lt_row.
* Mobile No.
      APPEND lv_mob TO lt_row.
* Email Address
      APPEND lv_eaddr TO lt_row.
* Shares
      APPEND  lv_share TO lt_row.
*ID type
      APPEND lv_IDtype  TO lt_row.
*Emirates ID
      APPEND lv_eID   TO lt_row.
*Passport
      APPEND lv_id   TO lt_row.
*Nationality
      APPEND lv_nation TO lt_row.

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

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      DATA(lv_id)  = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_nam)  = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(lv_no) = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_eadd)  = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_shr) = VALUE string( lt_r[ 5 ] OPTIONAL ).
*     Row layout is the one OWN_FORM_SAVE writes: 6 id type, 7 Emirates ID,
*     8 passport, 9 nationality - reading 6/7 here showed the id type under
*     the name and the Emirates ID in the Nationality column.
      DATA(lv_eid) = VALUE string( lt_r[ 7 ] OPTIONAL ).
      DATA(lv_nat) = VALUE string( lt_r[ 9 ] OPTIONAL ).

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

*   ONE dialog: the owner's details and their documents. No drill-down, no
*   second popup - the list is on the step behind and this is the form that
*   adds one line to it.
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Owner' contentwidth = '54rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

    lo_c->title( text = 'Owner Details' class = 'rakBlkTitle' ).

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

    lo_form->label( text = 'Identification' class = 'rakReq' ).
*   Emirates ID is the only option, and OWN_FORM_LOAD now defaults it - so
*   there is nothing left for the citizen to pick from this dropdown.
    lo_form->combobox( selectedkey = io_ctx->bind( c_identity )
                        editable    = abap_false
                        placeholder = 'select'
      )->item( key = '1'     text = 'Emirates ID' ).
*      )->item( key = '2'    text = 'Passport' ).

    lo_form->label( text = 'Emirates ID' class = 'rakReq' ).
*   The search icon and Enter both do the same thing. Somebody who has just
*   typed fifteen digits should not have to reach for the mouse.
    lo_form->input( value            = io_ctx->bind( c_id )
                    placeholder      = '784-xxxx-xxxxxxx-x'
                    showvaluehelp    = abap_true
                    valuehelprequest = io_ctx->event( c_evt_ownsr )
                    submit           = io_ctx->event( c_evt_ownsr ) ).
            lo_form->button( text = 'Check' press = io_ctx->event( c_evt_ownsr ) ).

    lo_form->label( text = 'Birth Date' class = 'rakReq' ).
    lo_form->date_picker( value         = io_ctx->bind( c_dob )
                          valueformat   = 'yyyy-MM-dd'
                          displayformat = 'dd.MM.yyyy' ).

    lo_form->label( text = 'Nationality' class = 'rakReq' ).
    DATA(lo_nat) = lo_form->combobox( selectedkey = io_ctx->bind( c_nat )
                                      placeholder = 'select' ).
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

    lo_form->label( text = 'Shares %' class = 'rakReq' ).
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
    lo_c->title( text = 'Documents' class = 'rakBlkTitle sapUiSmallMarginTop' ).

*   Two per row, the same rakRow/rakCell layout as the fields above.
    DATA(lo_dr1) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d1)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d1->label( text = 'Emirates ID Copy' ).
    io_ctx->render_upload( io_view = lo_d1 iv_field = 'MAIN_DOC' iv_key = lv_id ).
    DATA(lo_d2)  = lo_dr1->vbox( class = 'rakCell' ).
    lo_d2->label( text = 'Passport Copy' ).
    io_ctx->render_upload( io_view = lo_d2 iv_field = 'PASS' iv_key = lv_id ).

    DATA(lo_dr2) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d3)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d3->label( text = 'Introductory Statement' ).
    io_ctx->render_upload( io_view = lo_d3 iv_field = 'INTRO' iv_key = lv_id ).
    DATA(lo_d4)  = lo_dr2->vbox( class = 'rakCell' ).
    lo_d4->label( text = 'Criminal Clearance certificate' ).
    io_ctx->render_upload( io_view = lo_d4 iv_field = 'CRIMCC' iv_key = lv_id ).

    DATA(lo_dr3) = lo_c->hbox( class = 'rakRow' ).
    DATA(lo_d5)  = lo_dr3->vbox( class = 'rakCell' ).
    lo_d5->label( text = 'Curriculum Vitae' ).
    io_ctx->render_upload( io_view = lo_d5 iv_field = 'CURR' iv_key = lv_id ).
    DATA(lo_d6)  = lo_dr3->vbox( class = 'rakCell' ).
    lo_d6->label( text = 'Family Book' ).
    io_ctx->render_upload( io_view = lo_d6 iv_field = 'FBOOK' iv_key = lv_id ).


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
    LOOP AT ls_g-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) <> iv_id.
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
    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
*     Keep the row's own key so OWN_FORM_SAVE updates this row on Add rather
*     than appending a duplicate.
      io_ctx->set_val( iv_name = c_own_id  iv_value = iv_id ).
*     Row layout is the one OWN_FORM_SAVE writes: 6 id type, 7 Emirates ID,
*     8 passport, 9 nationality. Reading columns 2-4 (name/mobile/email) put
*     the mobile number into the Emirates ID field and left Identification
*     matching nothing in the dropdown, so it rendered blank.
      io_ctx->set_val( iv_name = c_identity  iv_value = VALUE #( lt_r[ 6 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_id   iv_value = VALUE #( lt_r[ 7 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_nat   iv_value = VALUE #( lt_r[ 9 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_share iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
      EXIT.
    ENDLOOP.

  endmethod.
ENDCLASS.
