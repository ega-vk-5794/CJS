class ZCL_D009_SCHOOL_LOCA_CHG_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for D009 - Changing the school's Location
*   (legacy ND009_1_*, seeded by ZRAK_D009_LOAD).
*
*   The one DOKSL journey in this set: CATEGORY is 'DOKSL', not 'EPDA',
*   and the legacy backend class is ZCL_EGA_CJ_ENH_IMPL_D009.
*
*   ---------------------------------------------------------------------
*   WHAT THIS CLASS NO LONGER DOES, and why each removal is a fix rather
*   than a loss. All four of these were written against an earlier,
*   migrator-generated version of the config that no longer exists, and
*   three of them referenced field names the feeder never seeds - so they
*   were dead code that read as live code, which is worse than either.
*
*   1. get_table( ) for 'LICENSES' and 'OWNERS' - GONE.
*      Both grids are now EDITABLE_TABLE + READONLY with their columns in
*      ZRAK_T_JNY_COL and their rows from the backend read
*      (D2 = LICENCES and D2 = OWNERS_DISP). The ftype decides which path
*      the renderer takes: 'TABLE' calls this method for columns AND rows,
*      'EDITABLE_TABLE' drives the grid from config. Config a functional
*      consultant can change beats ABAP that needs a transport, and the
*      old method's hard-coded column list ('License', 'School name', ...)
*      had already drifted from the legacy captions.
*
*   2. on_change( ) on 'LICENSE_SEL' - GONE.
*      There is no LICENSE_SEL field. The licence is picked in the STP1
*      grid, and what the pick has to load - the school, its address, its
*      manager - is what the ND009_1_2 read BAdI returns for the selected
*      licence. Pulling the same data forward from a UI event would give
*      the citizen two sources of truth for one screen.
*
*   3. on_before_tables( ) marking the selected row - GONE.
*      It read 'LIC_SELECT' while on_change wrote 'LICENSE_SEL' - two
*      spellings of a field that never existed, so the LOOP never matched
*      and the UI_TABLE_COLUMN29 = 'S' marker was never written. The grid
*      renders and tracks its own single-select from the legacy
*      D3 = SingleSelectLeft directive.
*
*   4. on_custom_validate( ) comparing NEWLOCATION to CURRENTLOCATION -
*      GONE, and this one is worth reading before someone writes it again.
*      Neither field exists, and no pair of fields COULD exist as the
*      config stands: the legacy screen binds the current address, parcel
*      id, telephone, location and PO box to the SAME five technical names
*      as the new ones (GS_DATA-SCHOOL-ADRESS, -PARCEL_ID, -TELEPHONE,
*      -LOCATION, -POBOX), so the feeder authors only the editable half.
*      One backend member cannot hold both the old value and the new one,
*      so there is nothing to compare against - and authoring the display
*      half back in would make it worse, not better: the engine reads each
*      field by name WITH its tech name, so both halves would come back
*      carrying the current value and the new-location inputs would arrive
*      PRE-FILLED with where the school already is. A real "must differ
*      from current" check needs the DOKSL read to expose five separate
*      read-only members first. See the REVIEW-BE note on the "New
*      Location" section in ZRAK_D009_LOAD.
*   ---------------------------------------------------------------------
*
*   What remains is on_init, and one line of it is the whole open question
*   on this journey - see the REVIEW-STUB note below.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
protected section.
private section.

  constants C_OWNER_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  constants C_APP_NAME type STRING value 'APPLICANTNAME' ##NO_TEXT.
  constants C_APP_ID type STRING value 'APPLICANT_ID' ##NO_TEXT.
  constants C_APP_MOBILE type STRING value 'APP_MOBILE' ##NO_TEXT.
  constants C_APP_EMAIL type STRING value 'APP_EMAIL' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_APP_ROLE type STRING value 'APP_ROLE' ##NO_TEXT.
  constants C_OWNER_BP_IDTYPE type STRING value 'OWNER_BP_IDTYPE' ##NO_TEXT.
  constants C_OWNER_NAME type STRING value 'OWNER_NAME' ##NO_TEXT.
  constants C_OWNER_MOBILE type STRING value 'OWNER_MOBILE' ##NO_TEXT.
  constants C_OWNER_EMAIL type STRING value 'OWNER_EMAIL' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_D009_SCHOOL_LOCA_CHG_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   No payment wiring on this journey, and that is confirmed rather than
*   omitted: there is no RAKPAY, no RAKREMAININGFEES and no fee CLIST
*   anywhere in ND009_1_*. So no PAY_SCREEN, no PAY_METHOD, no PAY_BUKRS.

*    DATA(lv_user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).

*    zcl_ega_cj_utility=>get_bp(
*      EXPORTING qv_key  = lv_user_data
*      IMPORTING loginbp = DATA(lv_loginbp)
*                rolebp  = DATA(lv_rolebp)
*                role    = DATA(lv_role) ).
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
*      io_ctx->set_val( iv_name = c_app_role iv_value = |{ c_rep }| ).

    ENDIF.

*   ---- REVIEW-STUB, and it is the reason to read this method -----------
*   This line used to be:
*
*       io_ctx->set_val( iv_name = 'LOGIN_BP'
*                        iv_value = CONV string( '3000000049' ) ). "'3000000049'
*
*   - a hard-coded business partner, with the correct line commented out
*   immediately below it. It is now the resolved LOGINBP, which is what
*   the author of that comment plainly intended.
*
*   Two things follow that a reviewer needs to know:
*
*   (a) THIS IS NOT AN ISOLATED FIX. The same hard-coded '3000000049'
*       appears in the on_init of the sibling DOKSL handlers
*       ZCL_D001_* through ZCL_D010_*, and D007 and D008 go further and
*       stub PARTNER_NAME and PARTNER_ID with a named individual and a
*       real-format Emirates ID in source. Those nine are outside this
*       change and are deliberately NOT touched here, because changing a
*       shared development stub in one journey out of ten is how a test
*       flow breaks with no obvious cause. They do need the same sweep.
*
*   (b) IF A DEV OR TEST FLOW DEPENDS ON THE STUB, this is the line that
*       breaks it, and the fix is to supply the test BP through USERDATA
*       rather than to put the literal back. A hard-coded partner that
*       reaches production does not fail loudly - it silently files every
*       citizen's application against one business partner.
*
*   ROLEBP and ROLE are resolved and not yet used. They are kept because
*   the call exports them and the applicant-type display on STP2
*   (GS_DATA-APPLICANT_TYPE, a read-only combobox) is very likely what ROLE
*   is for - but nothing in the export says so, so it is not wired blind.
*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*   No PAY_* or PAYFEE field exists on this journey, so this strip removes
*   nothing today. It is kept as a guard rather than a cleanup: if a fee is
*   ever added to this journey, the payment engine's own scratch keys
*   (PAY_TRIES, PAY_APPURL, PAY_STARTED and the rest) have no meaning to
*   the DOKSL backend and would arrive as unrecognised fields.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

*   NOTE: no DECLARE / ACCEPT_TERMS checkbox to strip here. The three
*   declaration rows on STP3 are DISPLAY text with no binding - confirmed
*   absent from the export as controls, not omitted by oversight - so
*   there is no acknowledgement flag reaching the payload.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
*  EXPORTING
*    IO_CTX    =
*  CHANGING
*    CT_TABLES =
*    .
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
