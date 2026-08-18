CLASS zcl_rak_cjs_showcase DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Seeds (or re-seeds) the reference journey ZDEMO_SHOWCASE.
    "! Run from SE24 (F8 -> seed) or a 3-line report:
    "!   START-OF-SELECTION. zcl_rak_cjs_showcase=>seed( ).
    "! Then open the Studio, pick ZDEMO_SHOWCASE, Load, and explore.
    CLASS-METHODS seed
      RETURNING VALUE(rv_msg) TYPE string.
    CLASS-METHODS teardown
      RETURNING VALUE(rv_msg) TYPE string.

  PRIVATE SECTION.
    CONSTANTS c_jny TYPE string VALUE 'ZDEMO_SHOWCASE'.
ENDCLASS.



CLASS ZCL_RAK_CJS_SHOWCASE IMPLEMENTATION.


  METHOD seed.
    DATA(jid) = CONV zrak_t_jny-journey_id( c_jny ).

    DELETE FROM zrak_t_jny      WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_step WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_fld  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_opt  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_rule WHERE journey_id = @jid.

    INSERT zrak_t_jny FROM @( VALUE #(
      mandt = sy-mandt journey_id = jid
      title = 'CJS Showcase - all controls' title_ar = 'عرض كامل لجميع عناصر التحكم'
      layout_mode = 'WIZARD' theme_variant = 'PREMIUM'
      accent_type = 'Emphasized' brand_color = 'rgb(196,30,38)' navy_color = 'rgb(16,35,62)'
      density = 'Cozy'
      subtitle = 'Every field type and capability, in one journey - for developer reference'
      subtitle_ar = 'كل عنصر تحكم وقدرة في رحلة واحدة'
      handler_class = 'ZCL_RAK_SHOWCASE_LOGIC'
      show_actions = 'X' active = 'X' bknd_active = ' ' ) ).

    DATA lt_step TYPE STANDARD TABLE OF zrak_t_jny_step.
    lt_step = VALUE #( journey_id = jid mandt = sy-mandt
      ( step_id = 'STP1' seqnr = 10 title = 'Text & numbers'   title_ar = 'النص والأرقام'  icon = 'sap-icon://person-placeholder' columns = 2 )
      ( step_id = 'STP2' seqnr = 20 title = 'Dates & choices'  title_ar = 'التواريخ والخيارات' icon = 'sap-icon://calendar' columns = 2 )
      ( step_id = 'STP3' seqnr = 30 title = 'Scales & display' title_ar = 'المقاييس والعرض' icon = 'sap-icon://measure' columns = 2 )
      ( step_id = 'STP4' seqnr = 40 title = 'Data blocks'      title_ar = 'كتل البيانات'  icon = 'sap-icon://table-view' columns = 1 )
      ( step_id = 'STP5' seqnr = 50 title = 'Rules & custom'   title_ar = 'القواعد والمخصص' icon = 'sap-icon://accept' columns = 1 ) ).
    INSERT zrak_t_jny_step FROM TABLE @lt_step.

    DATA lt_fld TYPE STANDARD TABLE OF zrak_t_jny_fld.
    lt_fld = VALUE #( journey_id = jid mandt = sy-mandt

      " ---- STP1 : text & numbers ----
      ( step_id = 'STP1' field_name = 'FULL_NAME' seqnr = 10 ftype = 'INPUT' zsection = 'Identity'
        zlabel = 'Full name' zlabel_ar = 'الاسم الكامل' placeholder = 'As per Emirates ID'
        required = 'X' min_len = 3 max_len = 40 tech_name = 'GS_DATA-NAME' )
      ( step_id = 'STP1' field_name = 'EMAIL' seqnr = 20 ftype = 'EMAIL' zsection = 'Identity'
        zlabel = 'Email' zlabel_ar = 'البريد الإلكتروني' required = 'X'
        regex = '.+@.+\..+' msg = 'Enter a valid email address' tech_name = 'GS_DATA-EMAIL' )
      ( step_id = 'STP1' field_name = 'MOBILE' seqnr = 30 ftype = 'PHONE' zsection = 'Identity'
        zlabel = 'Mobile' placeholder = '+9715XXXXXXXX' )
      ( step_id = 'STP1' field_name = 'AGE' seqnr = 40 ftype = 'NUMBER' zsection = 'Identity'
        zlabel = 'Age' min_val = '18' max_val = '120' )
      ( step_id = 'STP1' field_name = 'FEE_AMOUNT' seqnr = 50 ftype = 'CURRENCY' zsection = 'Identity'
        zlabel = 'Budget' placeholder = 'AED' )
      ( step_id = 'STP1' field_name = 'BIO' seqnr = 60 ftype = 'TEXTAREA' zsection = 'Identity'
        zlabel = 'About you' max_len = 200 )
      ( step_id = 'STP1' field_name = 'WANT_CONTACT' seqnr = 70 ftype = 'CHECKBOX' zsection = 'Consent'
        fgroup = 'Consent' zlabel = 'Please contact me' )
      ( step_id = 'STP1' field_name = 'NEWSLETTER' seqnr = 80 ftype = 'SWITCH' zsection = 'Consent'
        fgroup = 'Consent' zlabel = 'Subscribe to newsletter' )

      " ---- STP2 : dates & choices ----
      ( step_id = 'STP2' field_name = 'BIRTH_DATE' seqnr = 10 ftype = 'DATE' zlabel = 'Date of birth' )
      ( step_id = 'STP2' field_name = 'MEETING_TIME' seqnr = 20 ftype = 'TIME' zlabel = 'Preferred time' )
      ( step_id = 'STP2' field_name = 'SLOT' seqnr = 30 ftype = 'DATETIME' zlabel = 'Appointment slot' )
      ( step_id = 'STP2' field_name = 'PRIORITY' seqnr = 40 ftype = 'SELECT' zlabel = 'Priority' default_val = 'MED' )
      ( step_id = 'STP2' field_name = 'COUNTRY' seqnr = 50 ftype = 'SELECT' zlabel = 'Country' )
      ( step_id = 'STP2' field_name = 'SKILLS' seqnr = 60 ftype = 'MULTISELECT' zlabel = 'Skills' )
      ( step_id = 'STP2' field_name = 'GENDER' seqnr = 70 ftype = 'RADIO' zlabel = 'Gender' )
      ( step_id = 'STP2' field_name = 'PLAN' seqnr = 80 ftype = 'SEGMENTED' zlabel = 'Plan' default_val = 'BASIC' )
      ( step_id = 'STP2' field_name = 'PRO_SEATS' seqnr = 90 ftype = 'NUMBER' zlabel = 'Pro seats' hidden = 'X'
        min_val = '1' max_val = '500' )

      " ---- STP3 : scales & display ----
      ( step_id = 'STP3' field_name = 'SATISFACTION' seqnr = 10 ftype = 'SLIDER' zsection = 'Scales'
        zlabel = 'Satisfaction' min_val = '0' max_val = '10' )
      ( step_id = 'STP3' field_name = 'QTY_STEP' seqnr = 20 ftype = 'STEPPER' zsection = 'Scales'
        zlabel = 'Quantity' default_val = '1' min_val = '1' max_val = '20' )
      ( step_id = 'STP3' field_name = 'STARS' seqnr = 30 ftype = 'RATING' zsection = 'Scales'
        zlabel = 'Rating' max_val = '5' )
      ( step_id = 'STP3' field_name = 'PROGRESS_PCT' seqnr = 40 ftype = 'PROGRESS' zsection = 'Display only'
        zlabel = 'Completion' default_val = '60' fstate = 'Information' )
      ( step_id = 'STP3' field_name = 'APP_STATUS' seqnr = 50 ftype = 'STATUS' zsection = 'Display only'
        zlabel = 'Status' default_val = 'In review' fstate = 'Warning' )
      ( step_id = 'STP3' field_name = 'BALANCE' seqnr = 60 ftype = 'OBJNUM' zsection = 'Display only'
        zlabel = 'Balance' default_val = '1250.00' placeholder = 'AED' )
      ( step_id = 'STP3' field_name = 'REF_NOTE' seqnr = 70 ftype = 'DISPLAY' zsection = 'Display only'
        zlabel = 'Note' default_val = 'This is a display-only text row.' )
      ( step_id = 'STP3' field_name = 'READ_ONLY_ID' seqnr = 80 ftype = 'READONLY' zsection = 'Display only'
        zlabel = 'Reference no.' default_val = 'RO-12345' )
      ( step_id = 'STP3' field_name = 'HELP_LINK' seqnr = 90 ftype = 'LINK' zsection = 'Display only'
        zlabel = 'Open guide' default_val = 'https://docs.claude.com' )

      " ---- STP4 : data blocks ----
      ( step_id = 'STP4' field_name = 'BP_PARTNER' seqnr = 10 ftype = 'SEARCH'
        zlabel = 'Business partner' placeholder = 'Partner / name / Emirates ID' )
      ( step_id = 'STP4' field_name = 'MATERIALS' seqnr = 20 ftype = 'EDITABLE_TABLE'
        zlabel = 'Materials' attach_label = 'Add material'
        default_val = 'MTYPE:Material Type:INPUT|QTY:Quantity:NUMBER|UNIT:Units:SELECT' )
      ( step_id = 'STP4' field_name = 'FEE_TABLE' seqnr = 30 ftype = 'TABLE' zlabel = 'Fee schedule' )
      ( step_id = 'STP4' field_name = 'DEPARTMENT' seqnr = 40 ftype = 'SELECT' zlabel = 'Department' )
      ( step_id = 'STP4' field_name = 'CERT' seqnr = 50 ftype = 'UPLOAD' zlabel = 'Certificate'
        has_attach = 'X' attach_types = 'pdf,jpg,png' attach_maxmb = 5 )
      ( step_id = 'STP4' field_name = 'PHOTO' seqnr = 60 ftype = 'INPUT' zlabel = 'Photo ID'
        has_attach = 'X' attach_label = 'Attach photo' attach_types = 'jpg,png' )

      " ---- STP5 : rules & custom ----
      ( step_id = 'STP5' field_name = 'CUSTOM_CARD' seqnr = 10 ftype = 'DISPLAY' zlabel = 'Account summary' )
      ( step_id = 'STP5' field_name = 'VAT_NOTE' seqnr = 20 ftype = 'DISPLAY' zlabel = 'Tax note' hidden = 'X' )
      ( step_id = 'STP5' field_name = 'APPROVAL_NOTE' seqnr = 30 ftype = 'TEXTAREA' zlabel = 'Approval note'
        placeholder = 'Required when Plan = Professional with more than 10 seats' )
      ( step_id = 'STP5' field_name = 'POP_NOTE' seqnr = 40 ftype = 'TEXTAREA' zlabel = 'Popup note' hidden = 'X' ) ).
    INSERT zrak_t_jny_fld FROM TABLE @lt_fld.

    DATA lt_opt TYPE STANDARD TABLE OF zrak_t_jny_opt.
    lt_opt = VALUE #( journey_id = jid mandt = sy-mandt
      ( step_id = 'STP2' field_name = 'PRIORITY' opt_key = 'LOW'  seqnr = 10 opt_text = 'Low' )
      ( step_id = 'STP2' field_name = 'PRIORITY' opt_key = 'MED'  seqnr = 20 opt_text = 'Medium' )
      ( step_id = 'STP2' field_name = 'PRIORITY' opt_key = 'HIGH' seqnr = 30 opt_text = 'High' )
      ( step_id = 'STP2' field_name = 'COUNTRY'  opt_key = 'AE' seqnr = 10 opt_text = 'United Arab Emirates' opt_text_ar = 'الإمارات العربية المتحدة' )
      ( step_id = 'STP2' field_name = 'COUNTRY'  opt_key = 'US' seqnr = 20 opt_text = 'United States' )
      ( step_id = 'STP2' field_name = 'COUNTRY'  opt_key = 'IN' seqnr = 30 opt_text = 'India' )
      ( step_id = 'STP2' field_name = 'SKILLS'   opt_key = 'ABAP' seqnr = 10 opt_text = 'ABAP' )
      ( step_id = 'STP2' field_name = 'SKILLS'   opt_key = 'UI5'  seqnr = 20 opt_text = 'SAPUI5' )
      ( step_id = 'STP2' field_name = 'SKILLS'   opt_key = 'BTP'  seqnr = 30 opt_text = 'BTP' )
      ( step_id = 'STP2' field_name = 'GENDER'   opt_key = 'M' seqnr = 10 opt_text = 'Male' )
      ( step_id = 'STP2' field_name = 'GENDER'   opt_key = 'F' seqnr = 20 opt_text = 'Female' )
      ( step_id = 'STP2' field_name = 'GENDER'   opt_key = 'O' seqnr = 30 opt_text = 'Other' )
      ( step_id = 'STP2' field_name = 'PLAN'     opt_key = 'BASIC' seqnr = 10 opt_text = 'Basic' )
      ( step_id = 'STP2' field_name = 'PLAN'     opt_key = 'PRO'   seqnr = 20 opt_text = 'Professional' )
      ( step_id = 'STP4' field_name = 'BP_PARTNER' opt_key = 'YFS002' seqnr = 10 opt_text = 'Emirates ID' )
      ( step_id = 'STP4' field_name = 'BP_PARTNER' opt_key = 'YFS001' seqnr = 20 opt_text = 'Passport' ) ).
    INSERT zrak_t_jny_opt FROM TABLE @lt_opt.

    DATA lt_rule TYPE STANDARD TABLE OF zrak_t_jny_rule.
    lt_rule = VALUE #( journey_id = jid mandt = sy-mandt
      ( rule_id = 'R10' src_field = 'PLAN'         src_op = 'EQ'         src_value = 'PRO' action = 'SHOW'     tgt_field = 'PRO_SEATS' )
      ( rule_id = 'R20' src_field = 'PLAN'         src_op = 'NE'         src_value = 'PRO' action = 'CLEAR'    tgt_field = 'PRO_SEATS' )
      ( rule_id = 'R30' src_field = 'WANT_CONTACT' src_op = 'EQ'         src_value = 'X'   action = 'REQUIRE'  tgt_field = 'MOBILE' )
      ( rule_id = 'R40' src_field = 'WANT_CONTACT' src_op = 'INITIAL'                      action = 'OPTIONAL' tgt_field = 'MOBILE' )
      ( rule_id = 'R50' src_field = 'COUNTRY'      src_op = 'NOTINITIAL'                   action = 'SHOW'     tgt_field = 'VAT_NOTE' )
      ( rule_id = 'R60' src_field = 'COUNTRY'      src_op = 'EQ'         src_value = 'AE'  action = 'SET'      tgt_field = 'VAT_NOTE' tgt_value = 'VAT applies at 5%' )
      ( rule_id = 'R70' src_field = 'NEWSLETTER'   src_op = 'EQ'         src_value = 'X'   action = 'HIDE'     tgt_field = 'REF_NOTE' ) ).
    INSERT zrak_t_jny_rule FROM TABLE @lt_rule.

    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = c_jny ).

    rv_msg = |{ c_jny } seeded: { lines( lt_step ) } steps, { lines( lt_fld ) } fields, | &&
             |{ lines( lt_opt ) } options, { lines( lt_rule ) } rules. Open it in the Studio.|.
  ENDMETHOD.


  METHOD teardown.
    DATA(jid) = CONV zrak_t_jny-journey_id( c_jny ).
    DELETE FROM zrak_t_jny      WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_step WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_fld  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_opt  WHERE journey_id = @jid.
    DELETE FROM zrak_t_jny_rule WHERE journey_id = @jid.
    COMMIT WORK.
    zcl_rak_cj_cfg_cache=>invalidate( iv_journey = c_jny ).
    rv_msg = |{ c_jny } removed|.
  ENDMETHOD.
ENDCLASS.
