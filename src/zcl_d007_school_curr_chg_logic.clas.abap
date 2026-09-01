class ZCL_D007_SCHOOL_CURR_CHG_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
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
protected section.
ENDCLASS.



CLASS ZCL_D007_SCHOOL_CURR_CHG_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.
        rs_data-columns = VALUE #( ( `License` ) ( `School name` ) ( `Issued at` ) ( `Expired at` ) ).

        " REVIEW: replace with the real school-license read (the export
        " names FM ZFM_EGA_CJ_FW_READ_TABLE_DATAN / context LICENCES).
*        SELECT license_no, school_name, issued_at, expired_at
*          FROM ztb_dok_licenses                         "#EC CI_NOORDBY
*          WHERE partner = @io_ctx->get_val( 'OWNER_BP' )
*          INTO TABLE @DATA(lt_lic).
*
*        LOOP AT lt_lic INTO DATA(ls_lic).
*          APPEND VALUE #( ( |{ ls_lic-license_no }| )
*                          ( |{ ls_lic-school_name }| )
*                          ( |{ ls_lic-issued_at DATE = USER }| )
*                          ( |{ ls_lic-expired_at DATE = USER }| ) ) TO rs_table-rows.
*        ENDLOOP.

      WHEN 'OWNERS'.
        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile Number` ) ( `E-mail` ) ).

        " REVIEW: replace with the real current-owners read for the
        " SELECTED license (export context OWNERS_DISP).
*        SELECT partner_name, nationality, share_pct, mobile, email
*          FROM ztb_dok_owners                           "#EC CI_NOORDBY
*          WHERE license_no = @io_ctx->get_val( 'LICENSE_SEL' )
*          INTO TABLE @DATA(lt_own).
*
*        LOOP AT lt_own INTO DATA(ls_own).
*          APPEND VALUE #( ( |{ ls_own-partner_name }| )
*                          ( |{ ls_own-nationality }|   )
*                          ( |{ ls_own-share_pct }|     )
*                          ( |{ ls_own-mobile }|        )
*                          ( |{ ls_own-email }|         ) ) TO rs_table-rows.
*        ENDLOOP.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    " No PAY_*/PAYFEE fields exist on this journey, but the strip is safe
    " to keep in case a future change adds fee handling.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " UI-only scratch key with no backend meaning.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'.

    " NOTE: no DECLARE checkbox to strip here — confirmed absent from the
    " export (see load report NOTE 3), not omitted by oversight.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_TABLES.
    DATA(lv_sel) = io_ctx->get_val( 'LIC_SELECT' ).
    CHECK lv_sel IS NOT INITIAL.
    LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_sel..
      IF <t>-ui_table_column1 = lv_sel.
        <t>-ui_table_column29 = 'S'.
      ENDIF.
    ENDLOOP.
  endmethod.


  METHOD zif_rak_journey_logic~on_change.
    CHECK to_upper( iv_field ) = 'LICENSE_SEL'.

    DATA(lv_license) = io_ctx->get_val( 'LICENSE_SEL' ).
    IF lv_license IS INITIAL.
      RETURN.
    ENDIF.

    " REVIEW: replace with the real license/school/manager detail read —
    " placeholder shown for the pattern only.
*    SELECT SINGLE license_no, issued_at, expired_at
*      FROM ztb_dok_licenses
*      WHERE license_no = @lv_license
*      INTO @DATA(ls_lic).
*
*    IF sy-subrc = 0.
*      io_ctx->set_val( iv_name = 'LICNO' iv_value = |{ ls_lic-license_no }| ).
*      io_ctx->set_val( iv_name = 'LICISSUED' iv_value = |{ ls_lic-issued_at DATE = USER }| ).
*      io_ctx->set_val( iv_name = 'LICEXPIRED' iv_value = |{ ls_lic-expired_at DATE = USER }| ).
*    ENDIF.

    " REVIEW: populate SCHOOLNAMEEN/AR, TRADELICNO, SCHOOLADDRESS,
    " TELEPHONE, POBOX, PARCELID, the 5 MANAGER* fields, and the current
    " CURRICULUM/CURRICULUMTYPE/LOCATION/TRADELICAUTH values here from
    " the same selected license/school record. NEWCURRICULUM (this
    " journey's actual editable field) should start blank / unset rather
    " than pre-filled with the CURRENT curriculum, so the applicant
    " actively chooses the new one rather than resubmitting the old value
    " by accident — do not set_val( 'NEWCURRICULUM' ) here.
    " io_ctx->set_val( iv_name = 'SCHOOLNAMEEN' iv_value = |{ ls_school-name_en }| ).
    " io_ctx->set_val( iv_name = 'MANAGERNAME'  iv_value = |{ ls_school-manager_name }| ).
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

    CHECK iv_step = 1.   " zero-based: step 2 "Curriculum" in the wizard

    " REVIEW: this compares NEWCURRICULUM against whatever on_change( )
    " populated as the school's CURRENT curriculum — but no separate
    " READONLY field for "current curriculum" was seeded (see load report
    " NOTE 2, the duplicate combobox was dropped rather than kept as a
    " read-only display). If a "must differ" check is wanted, either seed
    " a hidden READONLY CURRENTCURRICULUM field populated in on_change( )
    " to compare against, or remove this check entirely.
    " IF io_ctx->get_val( 'NEWCURRICULUM' ) = io_ctx->get_val( 'CURRENTCURRICULUM' ).
    "   rt_msg = VALUE #( ( type = 'Error' text = 'The new curriculum must be different from the current one.' ) ).
    " ENDIF.
  ENDMETHOD.


  method ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*CALL METHOD SUPER->ZIF_RAK_JOURNEY_LOGIC~ON_INIT
*  EXPORTING
*    IO_CTX =
*    .
    CALL METHOD super->zif_rak_journey_logic~on_init
      EXPORTING
        io_ctx = io_ctx.
*
    DATA(user_data) = io_ctx->get_param( iv_name = 'USERDATA' ).
*
    zcl_ega_cj_utility=>get_bp(
      EXPORTING
        qv_key  = user_data
      IMPORTING
        loginbp = DATA(loginbp)
        rolebp  = DATA(rolebp)
        role    = DATA(role)
    ).
*
    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).

*    io_ctx->set_val( iv_name = 'APPLICANTNM' iv_value = CONV #( ls_login_bp-bp_name_en ) ).
*   The signed-in citizen, read from the business partner register. What stood
*   here was a fixed name and Emirates ID, written AFTER the real read, so every
*   applicant saw and posted the same test person.
    NEW zcl_ega_epda_fshry_handler_api( )->get_bp_details(
      EXPORTING
        iv_bp_id      = CONV bu_partner( loginbp )
      IMPORTING
        es_bp_details = DATA(ls_bp_real) ).
    io_ctx->set_val( iv_name = 'PARTNER_NAME' iv_value = COND #(
      WHEN sy-langu <> 'E' AND ls_bp_real-bp_name_ar IS NOT INITIAL
      THEN CONV string( ls_bp_real-bp_name_ar )
      ELSE CONV string( ls_bp_real-bp_name ) ) ).
    io_ctx->set_val( iv_name = 'PARTNER_ID' iv_value = CONV #( ls_bp_real-emirates_id ) ).
*    io_ctx->set_val( iv_name = 'APPLICANTEID' iv_value = CONV #( ls_login_bp-emirates_id ) ).

*    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ loginbp }| ).
    io_ctx->set_val( iv_name = 'APPLICANTTYPE' iv_value = 'Owner' ).
  endmethod.
ENDCLASS.
