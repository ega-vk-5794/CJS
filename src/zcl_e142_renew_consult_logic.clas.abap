class ZCL_E142_RENEW_CONSULT_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E142 - Renew Consultancy Registration
*   (legacy NE014_2_*, seeded by ZRAK_E142_LOAD).
*
*   WHY THIS CLASS EXISTS AT ALL, because the feeder used to say it did
*   not need one and that was wrong.
*
*   The argument for shipping E142 handler-less was that it has no payment
*   card and no UI_FIELD_LOGICS row to translate, so ZCL_RAK_JOURNEY_LOGIC's
*   generic behaviour was the whole journey. Both halves of that are true
*   and the conclusion still does not follow. STP2 carries the same
*   three-way applicant-type group the registration journey has -
*   PARTNER_OWNER_1 / PARTNER_PRO_1 / PARTNER_MANAGER_1, one shared legacy
*   DATA1 group, three separate GS_DATA-PARTNER_* flags in the backend -
*   and the migrated SEGMENTED field carries ONE value bound to ONE of
*   those three members.
*
*   So without this class, a citizen who renews as a PRO writes the string
*   'PARTNER_PRO_1' into GS_DATA-PARTNER_OWNER and leaves
*   GS_DATA-PARTNER_PRO blank. The application posts, nothing errors, and
*   the backend records a renewal by the owner personally. That is exactly
*   the failure ZCL_E014_CONSULT_REG_LOGIC exists to prevent, and the two
*   journeys share the legacy control group that causes it.
*
*   Everything else this journey needs IS still configuration: the licence
*   picker, the four sections, the six uploads, the read-only owner panel.
*   This class does the one thing config cannot.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_login_bp TYPE string VALUE 'LOGIN_BP' ##NO_TEXT.
    CONSTANTS c_partner_name TYPE string VALUE 'PARTNER_NAME' ##NO_TEXT.
    CONSTANTS c_PARTNER_ID TYPE string VALUE 'PARTNER_ID' ##NO_TEXT.
    CONSTANTS c_APPLICANTTYPE1 TYPE string VALUE 'APPLICANTTYPE' ##NO_TEXT.
    CONSTANTS c_lang_en TYPE string VALUE 'E' ##NO_TEXT.

*   Deliberately identical to ZCL_E014_CONSULT_REG_LOGIC's method of the
*   same name, rather than factored into a shared superclass. The two
*   journeys read the same legacy control group TODAY; they are separate
*   CJS journeys that can diverge tomorrow, and a shared base would make
*   changing one of them a change to both. Twelve duplicated lines is the
*   cheaper mistake.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E142_RENEW_CONSULT_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = c_applicant_type.
      write_role_flags( io_ctx = io_ctx iv_pick = io_ctx->get_val( c_applicant_type ) ).
    ENDIF.
  ENDMETHOD.


  METHOD write_role_flags.
*   Every flag written on every change, not just the chosen one - the
*   citizen who picks Manager after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both.
    DATA(lt_role) = VALUE zif_rak_journey=>tt_kv(
      ( key = `PARTNER_OWNER_1`   value = `GS_DATA-PARTNER_OWNER` )
      ( key = `PARTNER_PRO_1`     value = `GS_DATA-PARTNER_PRO` )
      ( key = `PARTNER_MANAGER_1` value = `GS_DATA-PARTNER_MANAGER` ) ).

    LOOP AT lt_role INTO DATA(ls_role).
      io_ctx->set_val( iv_name  = ls_role-value
                       iv_value = COND string( WHEN ls_role-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.

    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.

    DATA: lv_loginbp TYPE bu_partner.
    lv_loginbp       = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.
    DATA(lv_rolebp)  = CAST zcl_rak_journey_engine( io_ctx )->mv_rolebp.
    DATA(lv_role)    = CAST zcl_rak_journey_engine( io_ctx )->mv_role. "Owner

    IF lv_loginbp IS NOT INITIAL.
      NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
        EXPORTING
          iv_bp_id      = lv_loginbp
        IMPORTING
          es_bp_details = DATA(ls_bp) ).

      io_ctx->set_val( iv_name = c_login_bp iv_value = |{ lv_loginbp }| ).

      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_applicanttype1 iv_value = |{ lv_role }| ).

    ELSE.


      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = '1000116563' ).
*
**    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = CONV #( 'Bolar Binay Furkan Lohar' ) ).
**    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).
*      io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( '784-1981-1502090-5' ) ).
*
**    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
*      io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).

    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SEL' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSE' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
