class ZCL_E030_NEW_HOUSING_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E030 - Issue Housing Contract Fisherman Labour
*   (legacy NE030_1_*, seeded by ZRAK_E030_LOAD).
*
*   ZCL_E028_BERTH_NEW_LOGIC is the REFERENCE HANDLER for this family and
*   the reasoning behind the shared shapes is written out there, once.
*   Read it first. Only what differs is commented here - and on this
*   journey a lot differs.
*
*   ---- STEP INDICES ARE NOT E028'S. READ THIS PARAGRAPH. ---------------
*   E030 has FOUR steps where the rest of the family has three, because
*   NE030_1_2 is an accommodations step with no counterpart elsewhere. The
*   berth/storage block that E028 validates at step index 1 is at index 2
*   HERE. Copying E028's c_step_lease = 1 across would run the berth check
*   against the accommodations step, where none of those fields exist:
*   every value would read blank, the at-least-one test would fire on
*   every attempt, and nobody would get past step 2. The constants below
*   are the whole reason to read this comment.
*
*   NO PAYMENT. No RAKPAY, no RAKREMAININGFEES and no fee CLIST anywhere
*   in NE030_1_* - confirmed against the export. So no on_init, no
*   PAY_SCREEN, no PAY_BUKRS. If a fee is introduced later, that goes here
*   and STP4 needs NEXT_REQUIRES = 'PAYFEE' in the feeder at the same time.
*
*   Four things config cannot express:
*
*   1. TWO segmented fields, NINE backend flags. Two applicant-type
*      buttons and SEVEN validity buttons (3 months, 6 months, 1 to 5
*      years), each bound to its own GS_DATA-* flag. A segmented field
*      carries ONE value, so both groups have to be fanned back out or the
*      backend receives nothing for either. Note the validity control is
*      named V_3MONTH, after the lowest-sequence legacy button - NOT
*      VALIDITY_YEAR1 as on E028 and E128.
*
*   2. The declaration sentence, as everywhere in this family.
*
*   3. The accommodations grid cannot be checked by configuration.
*      REQUIRED does not reach grid rows - the grid field holds no scalar,
*      so an empty grid passes field validation silently. This journey
*      exists to house a crew, so submitting with nobody housed is the one
*      failure worth catching. See on_custom_validate.
*
*   4. The berth AND storage either/or, on step index 2. E028 has the
*      berth half of this; the storage half is E030's own.
*
*   NOTE for anyone adding a show/hide here later: set_hidden( ) OUTRANKS
*   the rules for the rest of the session. OWNER_1 and
*   CB_DOK_PARKING_NUMBER_2 are already governed by rules R01 and R04, so
*   calling set_hidden( ) on either from this class would not add to them
*   - it would silently take the decision away from them. That is the
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
  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
protected section.
private section.

  constants C_APPLICANT_TYPE type STRING value 'PARTNER_OWNER_1' ##NO_TEXT.
*   The validity group is named after V_3MONTH, its lowest-sequence
*   member, so the option keys in the feeder and the fan-out below agree
*   on one source field name.
  constants C_VALIDITY type STRING value 'V_3MONTH' ##NO_TEXT.
*   Zero-based, as the hooks count them:
*     0 = STP1 Select License
*     1 = STP2 Accommodation Details
*     2 = STP3 Lease Details      <- the berth/storage step
*     3 = STP4 Documents
  constants C_STEP_ACCOMM type I value 1 ##NO_TEXT.
  constants C_STEP_LEASE type I value 2 ##NO_TEXT.
   CONSTANTS c_default_idtype TYPE string VALUE 'YFS002'.
   CONSTANTS c_owner_bp       TYPE string VALUE 'OWNER_BP'.
   CONSTANTS c_app_name       TYPE string VALUE 'APP_NAME'.
  constants C_APP_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APP_MOBILE type STRING value 'APP_MOBILE' ##NO_TEXT.
  constants C_APP_EMAIL type STRING value 'APP_EMAIL' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_APP_ROLE type STRING value 'APP_ROLE' ##NO_TEXT.
  CONSTANTS c_owner_bp_idtype  TYPE string VALUE 'OWNER_BP_IDTYPE'.
  constants C_OWNER_NAME type STRING value 'OWNER_NAME' ##NO_TEXT.
  constants C_OWNER_MOBILE type STRING value 'OWNER_MOBILE' ##NO_TEXT.
  constants C_OWNER_EMAIL type STRING value 'OWNER_EMAIL' ##NO_TEXT.
  constants C_OWNER_DOB type STRING value 'OWNER_DOB' ##NO_TEXT.
  constants C_OWNER_NATIONALITY type STRING value 'OWNER_NATIONALITY' ##NO_TEXT.
  constants C_OWNER_SEG type STRING value 'APP_ROLE' ##NO_TEXT.
  constants C_OWNER type STRING value 'OWNER' ##NO_TEXT.
  constants C_REP type STRING value 'REP' ##NO_TEXT.

*   Write EVERY flag in a group on every change, not only the chosen one.
*   The citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both - and the same for a validity changed from
*   5 years down to 3 months.
  methods SET_GROUP
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_PICK type STRING
      !IT_MAP type ZIF_RAK_JOURNEY=>TT_KV .
ENDCLASS.



CLASS ZCL_E030_NEW_HOUSING_LOGIC IMPLEMENTATION.


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
**** Added Newly
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_applicant_type )
                   it_map  = VALUE #(
                     ( key = `OWNER` value = `GS_DATA-PARTNER_OWNER` )
                     ( key = `REP`   value = `GS_DATA-PARTNER_REP` ) ) ).

*     SEVEN options, and the first two have no counterpart on any other
*     journey in the family: GS_DATA-VALIDITY_3MONTH and
*     GS_DATA-VALIDITY_6MONTH exist for the housing pair only. E028 and
*     E128 have five flags, E029 two. Do not lift this map into a shared
*     superclass without checking each caller.
      WHEN c_validity.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_validity )
                   it_map  = VALUE #(
                     ( key = `V_3MONTH` value = `GS_DATA-VALIDITY_3MONTH` )
                     ( key = `V_6MONTH` value = `GS_DATA-VALIDITY_6MONTH` )
                     ( key = `V_YEAR1`  value = `GS_DATA-VALIDITY_YEAR1` )
                     ( key = `V_YEAR2`  value = `GS_DATA-VALIDITY_YEAR2` )
                     ( key = `V_YEAR3`  value = `GS_DATA-VALIDITY_YEAR3` )
                     ( key = `V_YEAR4`  value = `GS_DATA-VALIDITY_YEAR4` )
                     ( key = `V_YEAR5`  value = `GS_DATA-VALIDITY_YEAR5` ) ) ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   super-> FIRST. The base implementation is the PAID gate, and a
*   redefinition replaces it. This journey has no payment today, so the
*   gate has nothing to refuse - but calling it costs one compare and
*   keeps the protection if a fee is ever added. It also has to come
*   BEFORE the step tests below, because a failing CHECK exits the method.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx iv_step = iv_step ).

*   TWO steps to guard on this journey, so this is a CASE rather than
*   E028's single CHECK. Adding a second CHECK below the first would make
*   the second unreachable.
    CASE iv_step.

*     ---- step 1: the accommodations grid -------------------------------
*     REQUIRED does not reach grid rows: the grid field holds no scalar,
*     so an empty grid passes field validation with nothing said. The
*     legacy screen relied on ACCOMMODATION_DETAILS_1 being MANDATORY to
*     force at least one assignment, and that control is a JavaScript
*     composite the export does not describe - so its enforcement did not
*     survive the migration and has to be done here instead.
*
*     Checked against the GRID rather than against the placeholder link,
*     because the grid is the thing that actually posts. When the
*     composite is rebuilt this test keeps working unchanged, whatever it
*     is rebuilt as.
      WHEN c_step_accomm.
*        IF io_ctx->get_rows( 'ACCOMMODATIONS' ) IS INITIAL.
*          rt = VALUE #( BASE rt
*            ( type = 'Error'
*              text = 'Add at least one accommodation assignment before continuing.' ) ).
*        ENDIF.

*     ---- step 2: the berth and storage choices -------------------------
*     Two independent either/or tests, neither of which a rule can
*     express: ZRAK_T_JNY_RULE compares ONE source against ONE literal,
*     and these are "at least one of three" and "these two must differ".
*
*     The berth half is E028's, unchanged in substance - see
*     ZCL_E028_BERTH_NEW_LOGIC for the legacy UPDATE code it comes from.
*     The storage half is E030's own: E028 leases no storage unit.
*
*     Rules R02/R03/R05 grey the dropdowns out when a Waiting List is
*     ticked, and R06/R07 drop their REQUIRED flags so the citizen can get
*     past the required-check. That is exactly why these tests are needed:
*     with REQUIRED dropped, nothing else stops somebody leaving the step
*     having chosen no berth AND joined no queue.
      WHEN c_step_lease.
        DATA(lv_wait_berth) = io_ctx->get_val( 'WAITING_1' ).
        DATA(lv_berth1)     = io_ctx->get_val( 'DOK_PARKING_NUMBER_1' ).
        DATA(lv_berth2)     = io_ctx->get_val( 'CB_DOK_PARKING_NUMBER_2' ).
        DATA(lv_wait_store) = io_ctx->get_val( 'WAITING_2' ).
        DATA(lv_storage)    = io_ctx->get_val( 'STORAGE' ).

        IF lv_wait_berth IS INITIAL AND lv_berth1 IS INITIAL AND lv_berth2 IS INITIAL.
          rt = VALUE #( BASE rt
            ( type = 'Error'
              text = 'Choose a dock/parking number, or tick Waiting List to join the queue.' ) ).
        ENDIF.

*       Only meaningful when a berth was actually chosen - two blanks are
*       equal, but that case is already covered above.
        IF lv_wait_berth IS INITIAL AND lv_berth1 IS NOT INITIAL AND lv_berth1 = lv_berth2.
          rt = VALUE #( BASE rt
            ( type = 'Error'
              text = 'The second dock/parking number must be different from the first.' ) ).
        ENDIF.

*       The storage half. Note this does NOT return early on the berth
*       failure above: a citizen who has both wrong should be told both at
*       once rather than made to submit twice to find out. (E028 returns
*       early because its two berth messages contradict each other; these
*       two are independent.)
        IF lv_wait_store IS INITIAL AND lv_storage IS INITIAL.
          rt = VALUE #( BASE rt
            ( type = 'Error'
              text = 'Choose a storage number, or tick Waiting List to join the queue.' ) ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .
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


  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
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

    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*    .
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

    ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
*  EXPORTING
*    IO_CTX   =
*    IV_FIELD =
*  RECEIVING
*    RT       =
*    .

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

  endmethod.


  method ZIF_RAK_JOURNEY_LOGIC~GET_TABLE.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
*  EXPORTING
*    IO_CTX  =
*    IV_NAME =
*  RECEIVING
*    RS_DATA =
*    .
    CHECK to_upper( iv_name ) = 'ACCOMMODATIONS'.
    rs_data-columns = VALUE #( ( `Building` ) ( `Room` ) ( `Bed` ) ( `Worker` ) ).
    DATA(lt_rows) = io_ctx->get_val( 'ACCOMMODATIONS' ).
    LOOP AT VALUE string_table( ) INTO DATA(lv_dummy).   " placeholder loop — replace with real row source
      APPEND VALUE #( ( `` ) ( `` ) ( `` ) ( `` ) ) TO rs_data-rows.
    ENDLOOP.
  endmethod.
ENDCLASS.
