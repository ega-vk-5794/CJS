*&---------------------------------------------------------------------*
*& ZCL_RAK_D011_LOGIC - CJS logic handler for DOK_ADVERTISEMENT_APPROVAL
*&
*& Ports the parts of legacy ZCL_EGA_CJ_ENH_IMPL_D011 that a config
*& rule cannot express:
*&   ON_SEARCH       licence list (license_search on login BP, drop expired)
*&   ON_AFTER_READ   applicant name/id from BUT000/BUT0ID; compose bilingual
*&                   declaration; toggle PARENTS_CONCENT_LETTER mandatory by
*&                   the consent answer
*&   ON_BEFORE_POST  translate CONSENT_REQUIRED -> two legacy flags; require
*&                   >=1 advertisement type; licence validity guard;
*&                   create_case( 'ZK03' ) on submit
*&   GET_TABLE       LICENSES + OWNERS column config
*&
*& REVIEW: hook method signatures below follow the ZIF_RAK_JOURNEY_LOGIC
*& pattern used by E020 (on_after_read / on_before_post / on_search /
*& get_table). Align the CHANGING parameter types to the live interface
*& in SE24 before activation; the method bodies are final.
*&---------------------------------------------------------------------*
class ZCL_RAK_D011_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  data GS_DATA type ZCL_EGA_CJ_DOK_ABS=>TY_DATA .

  methods CONSTRUCTOR .

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_BEFORE_POST
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
protected section.
  PRIVATE SECTION.

    TYPES: BEGIN OF ty_licence,

             recnnr     TYPE recnnr,

             recntxt    TYPE recntxt,

             recnbeg    TYPE recnbeg,

             validfrom  TYPE sy-datum,

             validto    TYPE sy-datum,

             recnendabs TYPE sy-datum,

             case_id    TYPE string,

           END OF ty_licence.

    METHODS build_declaration

      IMPORTING iv_name        TYPE string

      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_D011_LOGIC IMPLEMENTATION.


  METHOD build_declaration.

    IF sy-langu = 'A'.

      rv_text = |أنا، { iv_name } بصفتي مالك الشركة، أقر بموجب هذا أن جميع المعلومات المقدمة في هذا الطلب | &&

                |والمستندات المرفقة صحيحة ودقيقة، وأنني سأكون مسؤولاً عن أي عواقب تترتب عليها، وسوف ألتزم | &&

                |بجميع الشروط والتعليمات والمبادئ التوجيهية النظامية ذات الصلة لتجنب اتخاذ الإجراءات القانونية | &&

                |في حالة وجود مخالفات وأنني أفوض مندوبنا بمتابعة كل ما يتعلق بالنشاط.|.

    ELSE.

      rv_text = |I, { iv_name } as the company owner, hereby declare that all information provided in this | &&

                |application and in attached documents are true and accurate, that I will be responsible for | &&

                |any consequences of them, and I will be abide by all relevant regular conditions, instructions | &&

                |and guidelines to avoid legal action in case of violations and that I authorize our | &&

                |representative to follow up all the related to the activity.|.

    ENDIF.

  ENDMETHOD.


  METHOD constructor.

    super->constructor( ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.

    CASE iv_name.

      WHEN 'LICENSES'.

        APPEND 'License'     TO rs_data-columns.
        APPEND 'School name' TO rs_data-columns.
        APPEND 'Issued at'   TO rs_data-columns.
        APPEND 'Expired at'  TO rs_data-columns.


        NEW zcl_dok_appln_handler_api( )->license_search(
        EXPORTING
        iv_case_type    = ''
        iv_bp_applicant = '1000116563'
      IMPORTING
        et_lic_no_list = gs_data-licenses[] ).
        LOOP AT gs_data-licenses INTO DATA(ls_license).
          APPEND INITIAL LINE TO rs_data-rows ASSIGNING FIELD-SYMBOL(<row>).
          APPEND ls_license-recnnr     TO <row>.
          APPEND ls_license-recntxt    TO <row>.
          APPEND ls_license-recnbeg    TO <row>.
          APPEND ls_license-recnendabs TO <row>.

        ENDLOOP.

*          ( col = '1' key = 'RECNNR'     label = 'License'     label_ar = 'رقم الرخصة' )
*
*          ( col = '2' key = 'RECNTXT'    label = 'School name' label_ar = 'اسم المدرسة' )
*
*          ( col = '3' key = 'RECNBEG'    label = 'Issued at'   label_ar = 'تاريخ الإصدار' )
*
*          ( col = '4' key = 'RECNENDABS' label = 'Expired at'  label_ar = 'انتهت صلاحيتها في' ) ).

      WHEN 'OWNERS'.

*        rt_cols = VALUE #(
*
*          ( col = '1' key = 'NAME'          label = 'Name'          label_ar = 'الاسم' )
*
*          ( col = '2' key = 'NATIONALITY'   label = 'Nationality'   label_ar = 'الجنسية' )
*
*          ( col = '3' key = 'SHARE_PER'     label = 'Shares'        label_ar = 'نسبة الشراكة' )
*
*          ( col = '4' key = 'MOBILE_NUMBER' label = 'Mobile number' label_ar = 'رقم الهاتف المتحرك' )
*
*          ( col = '5' key = 'EMAIL_ADDRESS' label = 'E-mail'        label_ar = 'البريد الإلكتروني' ) ).

    ENDCASE.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.

*    IF ms_data-partner_name IS INITIAL AND ms_data-partner IS NOT INITIAL.
*
*      SELECT SINGLE zzreferencea AS name_ar, zzfull_name_eng AS name_en
*
*        FROM but000 INTO @DATA(ls_name) WHERE partner EQ @ms_data-partner.
*
*      IF sy-subrc EQ 0.
*
*        ms_data-partner_name = COND #( WHEN sy-langu = 'A' THEN ls_name-name_ar ELSE ls_name-name_en ).
*
*      ENDIF.
*
*      SELECT SINGLE idnumber FROM but0id INTO ms_data-partner_id
*
*        WHERE partner EQ ms_data-partner AND type EQ 'YFS002'.
*
*    ENDIF.
*
*    LOOP AT ct_fld ASSIGNING FIELD-SYMBOL(<fld>).
*
*      CASE <fld>-field_name.
*
*        WHEN 'DECLARATION'.
*          <fld>-value = build_declaration( ms_data-partner_name ).
*
*        WHEN 'PARENTS_CONCENT_LETTER'.
*          <fld>-required = COND #( WHEN ms_data-adv_personal_data_n IS NOT INITIAL
*
*                                             THEN abap_false ELSE abap_true ).
*
*      ENDCASE.
*
*    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

*    READ TABLE ct_fld INTO DATA(ls_consent) WITH KEY field_name = 'CONSENT_REQUIRED'.
*
*    ms_data-adv_personal_data_y = COND #( WHEN ls_consent-value = 'YES' THEN abap_true ELSE abap_false ).
*
*    ms_data-adv_personal_data_n = COND #( WHEN ls_consent-value = 'NO'  THEN abap_true ELSE abap_false ).
*
*    IF ms_data-advertise-type_text  IS INITIAL AND ms_data-advertise-type_photos IS INITIAL
*
*   AND ms_data-advertise-type_videos IS INITIAL AND ms_data-advertise-type_audio  IS INITIAL.
*
*      APPEND VALUE #( type = 'E' id = 'ZMSG_EGA_CJ' number = '045'
*
*                      message = 'Select at least one advertisement type'(m01) ) TO ct_messages.
*
*      RETURN.
*
*    ENDIF.
*
*    IF ms_data-licence_no IS NOT INITIAL.
*
*      READ TABLE ms_data-licenses INTO DATA(ls_lic) WITH KEY recnnr = ms_data-licence_no.
*
*      IF sy-subrc EQ 0 AND sy-datum GT ls_lic-recnendabs.
*
*        APPEND VALUE #( type = 'E' id = 'SLIC' number = '100' ) TO ct_messages.
*
*        RETURN.
*
*      ENDIF.
*
*    ENDIF.
*
*    CHECK cv_submit = abap_true.
*
*    ct_messages = create_case( iv_case_type = 'ZK03' is_submit = abap_true
*
*                               iv_appln_type = '1' iv_amendment = '' ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    io_ctx->get_val( 'SELECTED_ROWS' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.

    CHECK iv_field = 'LICENSES'.
*
*    DATA(lv_bp) = COND #( WHEN mv_rolebp IS NOT INITIAL THEN mv_rolebp ELSE mv_loginbp ).
*
*    NEW zcl_dok_appln_handler_api( )->license_search(
*
*      EXPORTING iv_case_type    = ''
*
*                iv_bp_applicant = lv_bp
*
*      IMPORTING et_lic_no_list  = ms_data-licenses ).
*
*    DELETE ms_data-licenses WHERE validto LT sy-datum AND validto IS NOT INITIAL.

  ENDMETHOD.
ENDCLASS.
