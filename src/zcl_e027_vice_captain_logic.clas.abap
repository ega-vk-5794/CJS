class ZCL_E027_VICE_CAPTAIN_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*   Handler for E027 - Sailing of a Vice Captain
*   (legacy NE027_1_*, seeded by ZRAK_E027_LOAD).
*
*   NO PAYMENT. There is no RAKPAY, no RAKREMAININGFEES and no fee CLIST
*   anywhere in the real export, and the last screen's NEXT button carries
*   D3 = SUBMIT rather than a pay event - confirmed, not assumed. So unlike
*   E014 / E015 / E146 this class redefines no on_init and wires no
*   PAY_SCREEN, PAY_METHOD or PAY_BUKRS. If a fee is introduced later, this
*   is where that goes, and STP4 needs NEXT_REQUIRES = 'PAYFEE' in the
*   feeder at the same time.
*
*   ---------------------------------------------------------------------
*   THIS CLASS USED TO SHOW THE OWNER LOOKUP BACKWARDS - the identical
*   inversion ZCL_E015_ENV_STUDY_LOGIC carried, from the identical shared
*   legacy block. Worth recording, because it fails silently.
*
*   It had its own show/hide code, in on_after_read and on_change, that
*   revealed the OWNER_1 lookup when the applicant type was
*   PARTNER_OWNER_1 and hid it otherwise. The legacy UI_FIELD_LOGICS on
*   NE027_1_2 says the opposite, unambiguously:
*       PARTNER_OWNER_1  ->  OWNER_FINDER-V-F   (Owner  -> HIDE)
*       PARTNER_REP_1    ->  OWNER_FINDER-V-T   (Rep    -> SHOW)
*   which is counter-intuitive but correct, and doubly so here: on this
*   journey OWNER_1 is bound to GS_DATA-REPRESENT_ID, so despite the
*   container being called OWNER_FINDER and the caption reading "Owner
*   details", the field identifies the REPRESENTATIVE - which is exactly
*   why it appears only when a representative applies. The old code asked
*   the owner to identify a representative, and hid the field in the one
*   case there was one.
*
*   The visibility now lives in ZRAK_T_JNY_RULE as rule R001 (SHOW OWNER_1
*   when PARTNER_OWNER_1 = PARTNER_REP_1), with the field authored HIDDEN
*   in the feeder - the same convention E014 and E015 use. The engine
*   evaluates rules on read AND on change, so the on_after_read
*   redefinition this class used to need is gone.
*
*   DO NOT reintroduce set_hidden( ) on OWNER_1 here. It OUTRANKS the
*   rules for the rest of the session, so it would not add to R001 - it
*   would silently take the decision away from it, which is how the
*   inversion survived in the first place.
*   ---------------------------------------------------------------------
*
*   THREE separate business-partner lookups on this journey, confirmed from
*   PARENT_CONTAINER and from three DIFFERENT backend bindings rather than
*   assumed to be one reused control:
*     STP1  OWNER_ID_1  GS_DATA-OWNER_ID          standalone in VBOX_5
*                       - the boat owner.
*     STP2  OWNER_1     GS_DATA-REPRESENT_ID      inside OWNER_FINDER
*                       - the representative applying on the owner's
*                         behalf; governed by R001, see above.
*     STP3  OWNER_ID_2  GS_DATA-CAPTAIN-OWNER_ID  inside CAPTAIN_FINDER
*                       - the vice-captain nominee. Its container has no
*                         other live child, so nothing shows or hides
*                         around it and no rule governs it.
*   REVIEW-BE: none of the three has on_search wired - each renders
*   correctly (SEARCH is a recognised ftype) but a press returns nothing
*   until a search API is confirmed and one on_search here branches on
*   iv_field. LICENCE_NO_1 on STP1 is a fourth inert lookup, legacy search
*   kind 'BOAT_LICENSE'. Same open item as E014's OWNER_FINDER_BP and
*   E015's three - one API, one place to fix it.
*
*   REVIEW-F4: TYPE_1 on STP1 is a COMBOBOX with NO search help, no CLIST
*   and no value list anywhere in the export - the legacy screen filled its
*   options from ZCL_EGA_CJ_ENH_IMPL_E027 at runtime. It renders EMPTY
*   today. The fix is either a SHLP in the feeder or an on_value_help
*   redefinition here; both need the real option keys first, which is also
*   what unblocks the LICENSE_TABLE / LICENSE_SEARCH visibility rule the
*   feeder could not author.
public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
protected section.
private section.

  constants C_APPLICANT_TYPE type STRING value 'PARTNER_OWNER_1' ##NO_TEXT.
  constants C_LOGIN_BP type STRING value 'OWNER_BP' ##NO_TEXT.
  " Every other journey posts the applicant's own partner under LOGIN_BP;
  " this one only ever wrote OWNER_BP, so the record model and the backend
  " application had no applicant BP.  CJSMIG-703/704.
  constants C_APP_BP type STRING value 'LOGIN_BP' ##NO_TEXT.
  constants C_PARTNER_NAME type STRING value 'APP_NAME' ##NO_TEXT.
  constants C_PARTNER_ID type STRING value 'APP_ID' ##NO_TEXT.
  constants C_APPLICANTTYPE type STRING value 'APP_TYPE' ##NO_TEXT.
  constants C_LANG_EN type STRING value 'E' ##NO_TEXT.
  constants C_PARTNER_MOBILE type STRING value 'PARTNER_MOBILE' ##NO_TEXT.
  constants C_PARTNER_EMAIL type STRING value 'PARTNER_EMAIL' ##NO_TEXT.

*   One segmented field on screen, TWO booleans in the backend - the same
*   two-way group E015 has, not E014's three-way. The legacy screen had two
*   separate TBUTTONs, each bound to its own GS_DATA-PARTNER_* flag, and a
*   segmented field carries ONE value, so the chosen option has to be
*   fanned back out or the backend receives nothing for the applicant's
*   role.
  methods WRITE_ROLE_FLAGS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_PICK type STRING .
ENDCLASS.



CLASS ZCL_E027_VICE_CAPTAIN_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = c_applicant_type.
      write_role_flags( io_ctx = io_ctx iv_pick = io_ctx->get_val( c_applicant_type ) ).
    ENDIF.
  ENDMETHOD.


  METHOD write_role_flags.
*   Both flags written on every change, not just the chosen one - the
*   citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both.
    DATA(lt_role) = VALUE zif_rak_journey=>tt_kv(
      ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
      ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ).

    LOOP AT lt_role INTO DATA(ls_role).
      io_ctx->set_val( iv_name  = ls_role-value
                       iv_value = COND string( WHEN ls_role-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
*  EXPORTING
*    IO_CTX =
*  CHANGING
*    CT_KV  =
*    .
*    DELETE ct_kv WHERE key CP 'PAY_*'.
*    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.
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


  METHOD zif_rak_journey_logic~on_init.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
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
      io_ctx->set_val( iv_name = c_app_bp   iv_value = |{ lv_loginbp }| ).

      IF sy-langu = c_lang_en.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name ) ).
      ELSE.
        io_ctx->set_val( iv_name = c_partner_name iv_value = CONV #( ls_bp-bp_name_ar ) ).
      ENDIF.

      io_ctx->set_val( iv_name = c_partner_id iv_value = CONV #( ls_bp-emirates_id ) ).

      io_ctx->set_val( iv_name = c_partner_mobile iv_value = CONV #( ls_bp-mobile_number ) ).
      io_ctx->set_val( iv_name = c_partner_email iv_value = CONV #( ls_bp-email_address ) ).


      io_ctx->set_val( iv_name = c_applicanttype iv_value = |{ lv_role }| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
