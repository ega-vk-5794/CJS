class ZCL_E028_NEW_BERTH_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E028 - Issuance of New Berth Contract
*   (legacy NE028_1_*, seeded by ZRAK_E028_LOAD).
*
*   THIS IS THE REFERENCE HANDLER for the berth/store/housing family. E128,
*   E029, E129, E030 and E130 repeat this shape with different option sets
*   and different objects; the reasoning is written out once, here.
*
*   NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere in
*   NE028_1_* - confirmed against the export. So no on_init, no PAY_SCREEN,
*   no PAY_BUKRS. If a fee is introduced later, that goes here and STP3
*   needs NEXT_REQUIRES = 'PAYFEE' in the feeder at the same time.
*
*   Three things config cannot express, and nothing else:
*
*   1. TWO segmented fields, EIGHT backend flags. The legacy screen had two
*      TBUTTONs for the applicant type and five for the validity, each
*      bound to its own GS_DATA-* flag. A segmented field carries ONE
*      value, so both groups have to be fanned back out or the backend
*      receives nothing for either.
*
*   2. The declaration sentence. The legacy DECLARATION_LONG rows are
*      invisible; what the citizen reads is DECLARATION_NAME, which the
*      BAdI composes as "I, <partner name> as the company owner, ...".
*      Config can hold the sentence but not the name.
*
*   3. The berth choice is an EITHER/OR that spans three fields. See
*      on_custom_validate.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. OWNER_1 and
*   CB_DOK_PARKING_NUMBER_2 are already governed by rules R001 and R004,
*   so calling set_hidden( ) on either from this class would not add to
*   them - it would silently take the decision away from them. That is the
*   exact mistake that had E015 and E027 showing the owner lookup
*   backwards.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_validity       TYPE string VALUE 'VALIDITY_YEAR1'  ##NO_TEXT.
*   The Lease Details step, zero-based as the hooks count them. The legacy
*   screen runs its berth check when the screen name has already advanced
*   to NE028_1_3, i.e. on the way OUT of NE028_1_2 - which is step index 1.
    CONSTANTS c_step_lease     TYPE i      VALUE 1.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_permit_yes TYPE string VALUE 'PERMIT_YES' ##NO_TEXT.
    CONSTANTS c_min_search_len TYPE i      VALUE 3.
    CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
    CONSTANTS c_owner_bp       TYPE string VALUE 'OWNER_BP'.
    CONSTANTS c_permit_no      TYPE string VALUE 'PERMIT_NUMBER'.
    CONSTANTS c_permit_detail  TYPE string VALUE 'PERMIT_DETAIL'.
    CONSTANTS c_app_name       TYPE string VALUE 'APP_NAME'.
    CONSTANTS c_app_id         TYPE string VALUE 'APP_ID'.
    CONSTANTS c_app_mobile     TYPE string VALUE 'APP_MOBILE'.
    CONSTANTS c_app_email      TYPE string VALUE 'APP_EMAIL'.
    CONSTANTS c_login_bp       TYPE string VALUE 'LOGIN_BP'.
    CONSTANTS c_lang_en        TYPE string VALUE 'E' ##NO_TEXT.
    CONSTANTS c_app_role       TYPE string VALUE 'APP_ROLE'.
    CONSTANTS c_permit_mode    TYPE string VALUE 'PERMIT_MODE'.
    CONSTANTS c_permit_number  TYPE string VALUE 'PERMIT_NUMBER'.

    CONSTANTS c_owner_bp_idtype  TYPE string VALUE 'OWNER_BP_IDTYPE'.
    CONSTANTS c_owner_name  TYPE string VALUE 'OWNER_NAME'.
    CONSTANTS c_owner_mobile  TYPE string VALUE 'OWNER_MOBILE'.
    CONSTANTS c_owner_email  TYPE string VALUE 'OWNER_EMAIL'.
    CONSTANTS c_owner_dob  TYPE string VALUE 'OWNER_DOB'.
    CONSTANTS c_owner_nationality  TYPE string VALUE 'OWNER_NATIONALITY'.
    CONSTANTS c_owner_seg  TYPE string VALUE 'APP_ROLE'.
    CONSTANTS c_owner  TYPE string VALUE 'OWNER'.
    CONSTANTS c_rep  TYPE string VALUE 'REP'.

*   Write EVERY flag in a group on every change, not only the chosen one.
*   The citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both - and the same for a validity changed from
*   5 years down to 1.
    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_map  TYPE zif_rak_journey=>tt_kv.
ENDCLASS.



CLASS ZCL_E028_NEW_BERTH_LOGIC IMPLEMENTATION.


  METHOD set_group.
    LOOP AT it_map INTO DATA(ls_map).
      io_ctx->set_val( iv_name  = ls_map-value
                       iv_value = COND string( WHEN ls_map-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   ---- the declaration sentence ----------------------------------------
*   The legacy BAdI builds this as "I, <name> as the company owner, hereby
*   declare ...". The feeder seeds the sentence WITHOUT the name so the
*   field reads correctly even if this method never runs; here it is
*   replaced with the full version once the read has supplied a name.
*
*   Guarded on the name being present rather than on the step, because the
*   read that fills GS_DATA-PARTNER_NAME may arrive on any step and
*   overwriting a good sentence with "I,  as the company owner" would be
*   worse than leaving the seeded one alone.
    DATA(lv_name) = io_ctx->get_val( 'APP_NAME' ).
    IF lv_name IS NOT INITIAL.
      io_ctx->set_val(
        iv_name  = 'DECLARATION_NAME'
        iv_value = |I, { lv_name } as the company owner, hereby declare that all | &&
                   |information provided in this application and in attached documents | &&
                   |are true and accurate, that I will be responsible for any | &&
                   |consequences of them, and I will be abide by all relevant regular | &&
                   |conditions, instructions and guidelines to avoid legal action in | &&
                   |case of violations and that I authorize our representative to | &&
                   |follow up all the related to the activity.| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_applicant_type.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_applicant_type )
                   it_map  = VALUE #(
                     ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
                     ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ) ).

      WHEN c_validity.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_validity )
                   it_map  = VALUE #(
                     ( key = `VALIDITY_YEAR1` value = `GS_DATA-VALIDITY_YEAR1` )
                     ( key = `VALIDITY_YEAR2` value = `GS_DATA-VALIDITY_YEAR2` )
                     ( key = `VALIDITY_YEAR3` value = `GS_DATA-VALIDITY_YEAR3` )
                     ( key = `VALIDITY_YEAR4` value = `GS_DATA-VALIDITY_YEAR4` )
                     ( key = `VALIDITY_YEAR5` value = `GS_DATA-VALIDITY_YEAR5` ) ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   super-> FIRST. The base implementation is the PAID gate, and a
*   redefinition replaces it. This journey has no payment today, so the
*   gate has nothing to refuse - but calling it costs one compare and
*   keeps the protection if a fee is ever added. It also has to come
*   BEFORE the CHECK below, because a failing CHECK exits the method.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

    CHECK iv_step = c_step_lease.

*   ---- the berth choice, which config cannot express -------------------
*   Straight from ZCL_EGA_CJ_ENH_IMPL_E028->UPDATE, which runs both of
*   these when the screen name has advanced to NE028_1_3:
*
*     IF berth-waiting IS INITIAL AND berth-aoid IS INITIAL
*                                 AND berth2-aoid IS INITIAL.   -> e054
*     IF berth-waiting IS INITIAL AND berth-aoid EQ berth2-aoid
*                                 AND berth-aoid IS NOT INITIAL. -> e056
*
*   Neither is a per-field rule: the first is "at least one of three", the
*   second is "these two must differ". ZRAK_T_JNY_RULE compares one source
*   against one literal, so both need ABAP.
    DATA(lv_waiting) = io_ctx->get_val( 'WAITING_1' ).
    DATA(lv_berth1)  = io_ctx->get_val( 'DOK_PARKING_NUMBER_1' ).
    DATA(lv_berth2)  = io_ctx->get_val( 'CB_DOK_PARKING_NUMBER_2' ).

    IF lv_waiting IS INITIAL AND lv_berth1 IS INITIAL AND lv_berth2 IS INITIAL.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = 'Choose a dock/parking number, or tick Waiting List to join the queue.' ) ).
      RETURN.
    ENDIF.

*   Only meaningful when a berth was actually chosen - two blanks are
*   equal but that case is already covered above.
    IF lv_waiting IS INITIAL AND lv_berth1 IS NOT INITIAL AND lv_berth1 = lv_berth2.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = 'The second dock/parking number must be different from the first.' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
    CALL METHOD super->zif_rak_journey_logic~on_before_tables
      EXPORTING
        io_ctx    = io_ctx
      CHANGING
        ct_tables = ct_tables.
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.


      DATA: lv_loginbp TYPE bu_partner.
      lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
      DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
      DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

      IF lv_loginbp IS INITIAL AND syst-sysid = 'E10'.
        lv_loginbp = '1000116563'.
      ENDIF.

      IF lv_loginbp IS NOT INITIAL.
        NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
          EXPORTING
            iv_bp_id      = lv_loginbp
          IMPORTING
            es_bp_details = DATA(ls_bp) ).

        io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).

        IF sy-langu = c_lang_en.
          io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name ) ).
        ELSE.
          io_ctx->set_val( iv_name = c_app_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
        ENDIF.

        io_ctx->set_val( iv_name = c_app_id     iv_value = CONV #( ls_bp-emirates_id ) ).
        io_ctx->set_val( iv_name = c_app_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
        io_ctx->set_val( iv_name = c_app_email  iv_value = CONV #( ls_bp-email_address ) ).
*      io_ctx->set_val( iv_name = c_app_role iv_value = |{ lv_role }| ).
        io_ctx->set_val( iv_name = c_app_role iv_value = |{ c_rep }| ).


      ELSE.


*      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '3000180559' ). "'1000116563' )
*      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '1000116563' ). "'1000116563' ).
*
**    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
**    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
*
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

      ENDIF.

  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH.



    IF iv_field = c_owner_bp.


      CHECK to_upper( iv_field ) = c_owner_bp."'OWNER_BP'.

      DATA(lv_eid) = condense( io_ctx->get_val( c_owner_bp ) ).
*    IF strlen( lv_eid ) < c_min_search_len.
*      io_ctx->add_msg( iv_type = 'Warning'
*                       iv_text = |Enter at least { c_min_search_len } characters to search| ).
*      RETURN.
*    ENDIF.

      DATA(lv_idtype) = io_ctx->get_val( c_owner_bp_idtype ).
      IF lv_idtype IS INITIAL.
        lv_idtype = c_default_idtype.
      ENDIF.

      DATA: lv_eid_no   TYPE bu_id_number,
            lv_eid_type TYPE bu_id_type.

      lv_eid_no = lv_eid.
      lv_eid_type = lv_idtype.


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

      CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
        EXPORTING
          iv_type            = lv_eid_type
          iv_idnumber        = lv_eid_no
*         IV_APP             = IV_APP
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

      io_ctx->set_val( iv_name = c_owner_name        iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_mobile      iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_email       iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_dob         iv_value = ' ' ).
      io_ctx->set_val( iv_name = c_owner_nationality iv_value = ' ' ).


      io_ctx->set_val( iv_name = c_owner_bp          iv_value = |{ lv_eid }| ).
      io_ctx->set_val( iv_name = c_owner_name        iv_value = |{ ev_name }| ).
      io_ctx->set_val( iv_name = c_owner_mobile      iv_value = |{ ev_phone }| ).
      io_ctx->set_val( iv_name = c_owner_email       iv_value = |{ ev_email }| ).
      io_ctx->set_val( iv_name = c_owner_dob         iv_value = |{ ev_date_of_birth }| ).
      io_ctx->set_val( iv_name = c_owner_nationality iv_value = |{ ev_nationality }| ).

*    ELSEIF iv_field = c_permit_no.
*      DATA(lv_permit) = condense( io_ctx->get_val( c_permit_no ) ).
*
*      IF lv_permit IS NOT INITIAL.
*        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.
*
*        IF lv_contrat IS NOT INITIAL.
*          io_ctx->set_val( iv_name = c_permit_no  iv_value = |{ lv_permit }| ).
*          io_ctx->set_val( iv_name = c_permit_detail  iv_value = |{ lv_contrat }| ).
**          gs_data-permit_number = lv_permit.
*        ELSE.
*          io_ctx->set_val( iv_name = c_permit_detail iv_value = ' ' ).
*          io_ctx->add_msg( iv_type = 'Error'
*                           iv_text = |Enter Valid Permit No to search| ).
*        ENDIF.
*
*      ENDIF.
    ENDIF.


  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.

    CONSTANTS: c_dok_id  TYPE string VALUE 'DOK_PARKING_NUMBER_1',
               c_dok_id2 TYPE string VALUE 'CB_DOK_PARKING_NUMBER_2',
               c_port_id TYPE string VALUE 'PORT_ID'.

    DATA: lv_port_id TYPE zde_ega_fshry_port,
          lt_berth   TYPE zega_cj_epda_port_objects_tt.


    CASE iv_field.
      WHEN c_dok_id OR c_dok_id2.
        DATA(lv_port) = condense( io_ctx->get_val( c_port_id ) ).
        lv_port_id = lv_port.


        CALL FUNCTION 'ZEGA_CJ_EPDA_PORT_OBJECTS'
          EXPORTING
            iv_port  = lv_port_id
          IMPORTING
            et_berth = lt_berth.

        DELETE lt_berth WHERE available NE abap_true.
        READ TABLE lt_berth WITH KEY available = abap_true TRANSPORTING NO FIELDS.

        IF lt_berth IS NOT INITIAL.
          " Build a simplified result table with VALUE and FOR
          rt = VALUE #(
                FOR ls_berth IN lt_berth
                 ( key = ls_berth-arch_object_id text =  ls_berth-arch_object_text )
                   ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.



  ENDMETHOD.
ENDCLASS.
