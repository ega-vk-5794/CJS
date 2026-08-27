class ZCL_EPDA_E020_BATT_SCRAP_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

*   Redefinitions, NOT "INTERFACES zif_rak_journey_logic". Declaring the interface
*   directly obliges this class to implement all ~25 of its methods; it implements
*   three, so it never activated. Inheriting the base supplies the empty defaults
*   for the rest AND the payment card - the shape every other handler in this
*   package uses, e.g. ZCL_EPDA_E022_DEV_PROJ_LOGIC.
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
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

*   REVIEW: the children of each legacy container. The export names the
*   CONTAINER only - UI_FIELD_LOGICS says OWNER_FINDER-V-T, never which
*   fields live inside it - so these lists are the migration decision that
*   most needs a second pair of eyes. A missing name leaves a field on
*   screen holding a value the citizen cannot see and the backend still gets.
    METHODS owner_finder_fields RETURNING VALUE(rt) TYPE string_table.
    METHODS permit_finder_fields RETURNING VALUE(rt) TYPE string_table.
    METHODS license_finder_fields RETURNING VALUE(rt) TYPE string_table.

    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_all  TYPE string_table
                it_tech TYPE string_table.

    METHODS show_only
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
                it_on  TYPE string_table
                it_off TYPE string_table.
ENDCLASS.



CLASS ZCL_EPDA_E020_BATT_SCRAP_LOGIC IMPLEMENTATION.


  METHOD license_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD owner_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD permit_finder_fields.
*   REVIEW-CONTAINER: fill from the legacy screen. Left deliberately empty
*   rather than guessed - a wrong name here hides the wrong field, and a
*   hidden field that still posts is the worst of both.
    CLEAR rt.
  ENDMETHOD.


  METHOD set_group.
*   Every flag in the group, every time. IT_ALL and IT_TECH are positional:
*   the nth option writes the nth technical name. A short IT_TECH would
*   silently stop writing the tail of the group, so it is checked.
    IF lines( it_all ) <> lines( it_tech ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Handler misconfigured: { lines( it_all ) } options |
                                 && |against { lines( it_tech ) } backend fields| ).
      RETURN.
    ENDIF.

    LOOP AT it_all INTO DATA(lv_opt).
      DATA(lv_i) = sy-tabix.
      io_ctx->set_val( iv_name  = it_tech[ lv_i ]
                       iv_value = COND string( WHEN lv_opt = iv_pick
                                               THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD show_only.
*   Both directions. SHOW alone leaves the other panel on screen after its
*   trigger is cleared, still holding values and still posting them.
    LOOP AT it_on INTO DATA(lv_on).
      io_ctx->set_hidden( iv_field = lv_on iv_on = abap_false ).
    ENDLOOP.
    LOOP AT it_off INTO DATA(lv_off).
      io_ctx->set_hidden( iv_field = lv_off iv_on = abap_true ).
      io_ctx->set_val( iv_name = lv_off iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   The same show/hide the change handler does, applied on arrival. Without
*   this the first render shows both panels until the citizen touches the
*   control - and a resumed draft shows both for good.
    show_only(
      io_ctx = io_ctx
      it_on  = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) = `PARTNER_REP_1`
                       THEN owner_finder_fields( ) )
      it_off = COND #( WHEN io_ctx->get_val( c_partner_owner_1 ) <> `PARTNER_REP_1`
                       THEN owner_finder_fields( ) ) ).
    IF io_ctx->get_val( c_permit_yes ) = `PERMIT_YES`.
      show_only( io_ctx = io_ctx
                 it_on  = permit_finder_fields( )
                 it_off = license_finder_fields( ) ).
    ELSE.
      show_only( io_ctx = io_ctx
                 it_on  = license_finder_fields( )
                 it_off = permit_finder_fields( ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_partner_owner_1.
        DATA(lt_partner_owner_1) = VALUE string_table( ( `PARTNER_OWNER_1` ) ( `PARTNER_REP_1` ) ).
        DATA(lt_partner_owner_1_t) = VALUE string_table( ( `GS_DATA-PARTNER_OWNER` ) ( `GS_DATA-PARTNER_REP` ) ).
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_partner_owner_1 )
                   it_all  = lt_partner_owner_1
                   it_tech = lt_partner_owner_1_t ).

        DATA(lv_owner_finder) = xsdbool(
          io_ctx->get_val( c_partner_owner_1 ) = `PARTNER_REP_1` ).
        show_only(
          io_ctx = io_ctx
          it_on  = COND #( WHEN lv_owner_finder = abap_true
                           THEN owner_finder_fields( ) )
          it_off = COND #( WHEN lv_owner_finder = abap_false
                           THEN owner_finder_fields( ) ) ).

      WHEN c_permit_yes.
        DATA(lt_permit_yes) = VALUE string_table( ( `PERMIT_YES` ) ( `PERMIT_NO` ) ).
        DATA(lt_permit_yes_t) = VALUE string_table( ( `GS_DATA-PERMIT_YES` ) ( `GS_DATA-PERMIT_NO` ) ).
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_permit_yes )
                   it_all  = lt_permit_yes
                   it_tech = lt_permit_yes_t ).

*       PERMIT_FINDER when the answer is PERMIT_YES, LICENSE_FINDER otherwise - the legacy
*       logic paired them, so exactly one is ever on screen.
        IF io_ctx->get_val( c_permit_yes ) = `PERMIT_YES`.
          show_only( io_ctx = io_ctx
                     it_on  = permit_finder_fields( )
                     it_off = license_finder_fields( ) ).
        ELSE.
          show_only( io_ctx = io_ctx
                     it_on  = license_finder_fields( )
                     it_off = permit_finder_fields( ) ).
        ENDIF.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate: it refuses a submit while the fee is still
*   unpaid. Redefining without calling it would silently take that gate off this
*   journey. It self-guards - PAY_FIELD_STEP returns -1 when the journey has no
*   PAYFEE field - so this costs nothing on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   REQUIRED does not reach grid rows. The grid field holds no scalar, so an
*   empty grid satisfies field validation and the application submits with
*   no rows in it - which the backend accepts.
*
*   Steps count from ZERO in hooks, so the guards below are one less than the
*   step number in the seed.

    IF io_ctx->get_step( ) = 2.
*      IF lines( io_ctx->get_grid_data( `MATERIALS_DET` )-rows ) = 0.
*        APPEND VALUE #( type = 'Error'
*                        text = |At least one row is required in Materials Det| )
*               TO rt.
*      ENDIF.
    ENDIF.
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

    ELSEIF iv_field = c_permit_no.
      DATA(lv_permit) = condense( io_ctx->get_val( c_permit_no ) ).

      IF lv_permit IS NOT INITIAL.
        SELECT SINGLE contractname FROM zv_epdapmmast INTO @DATA(lv_contrat) WHERE permitid = @lv_permit.

        IF lv_contrat IS NOT INITIAL.
          io_ctx->set_val( iv_name = c_permit_no  iv_value = |{ lv_permit }| ).
          io_ctx->set_val( iv_name = c_permit_detail  iv_value = |{ lv_contrat }| ).
*          gs_data-permit_number = lv_permit.
        ELSE.
          io_ctx->set_val( iv_name = c_permit_detail iv_value = ' ' ).
          io_ctx->add_msg( iv_type = 'Error'
                           iv_text = |Enter Valid Permit No to search| ).
        ENDIF.

      ENDIF.
    ENDIF.

  endmethod.


  METHOD zif_rak_journey_logic~on_value_help.


    DATA(lv_step) = io_ctx->get_step( ).
    CASE iv_field.
      WHEN 'MATERIALS_DET.UNIT_1'.
        rt = VALUE #(
                      ( key = 'GAL' text = 'Gallon' )
                      ( key = 'KG'  text = 'Kilogram' )
                      ( key = 'LTR' text = 'Liter' )
                      ( key = 'MT'  text = 'Metric Ton' )
                    ).
    ENDCASE.



  ENDMETHOD.
ENDCLASS.
