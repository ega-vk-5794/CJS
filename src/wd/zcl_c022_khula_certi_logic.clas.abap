class ZCL_C022_KHULA_CERTI_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~ON_ATTACH
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_INIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_AFTER_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SUBMIT
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
    redefinition .
  PRIVATE SECTION.
    CONSTANTS c_step_marr TYPE i VALUE 0.   " MARR  Marriage Contract        (seq 10)
    CONSTANTS c_step_divo TYPE i VALUE 1.   " DIVO  Divorce Details          (seq 20)
    CONSTANTS c_step_hist TYPE i VALUE 2.   " HIST  Marital Status & History (seq 30)
    CONSTANTS c_step_prty TYPE i VALUE 3.   " PRTY  Parties (grid + parties)  (seq 40)
    CONSTANTS c_step_docs TYPE i VALUE 4.   " DOCS  Request & Documents      (seq 50, last -> Submit)
    " Partner-search popup. ZCL_RAK_BP_POPUP is a reference implementation, so the
    " popup lives here and calls the central ZCL_RAK_BP_SEARCH. Field names follow
    " <SUBJECT>_<SUFFIX>, so the result lands on the party being searched.
    CONSTANTS c_bp_eid    TYPE string VALUE 'YFS002'.   " Emirates ID
    CONSTANTS c_bp_tlic   TYPE string VALUE 'YP0001'.   " Trade licence
    CONSTANTS c_bp_pass   TYPE string VALUE 'YFS004'.   " Passport
    CONSTANTS c_bp_unif   TYPE string VALUE 'YFS005'.   " Unified ID
    CONSTANTS c_ev_bp_go  TYPE string VALUE 'BPP_SEARCH'.
    CONSTANTS c_ev_bp_new TYPE string VALUE 'BPP_RESUME'.
    CONSTANTS c_ev_bp_cxl TYPE string VALUE 'BPP_CLOSE'.
    CONSTANTS c_evt_bp_divorcee TYPE string VALUE 'BP_OPEN_DIVORCEE'.
    CONSTANTS c_evt_bp_witness1 TYPE string VALUE 'BP_OPEN_WITNESS1'.
    CONSTANTS c_evt_bp_witness2 TYPE string VALUE 'BP_OPEN_WITNESS2'.
    CONSTANTS c_default_service TYPE string VALUE 'AS3'.
    CONSTANTS c_att_key     TYPE comt_product_id VALUE 'AD01'. " doc-type DDLB key

    METHODS get_otr_text_for_alias
      IMPORTING iv_alias       TYPE sotr_alias
      RETURNING VALUE(rv_text) TYPE string.
    METHODS get_otr_text_by_alias
      IMPORTING iv_alias       TYPE sotr_alias
      RETURNING VALUE(rv_text) TYPE string.

    METHODS options_from_domain
      IMPORTING iv_domain TYPE ddobjname
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

    METHODS t100_text
      IMPORTING iv_id          TYPE symsgid
                iv_no          TYPE symsgno
      RETURNING VALUE(rv_text) TYPE string.

    " Origin: VIEW_MAIN->E_GET_HELP_URL. Maps SERVICE_TYPE to a help code
    METHODS refresh_help_url
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    " Origin: COMPONENTCONTROLLER->GET_PARTNER_FUNCTIONS. Stamp the partner
    METHODS set_partner_functions
      CHANGING cs_partners TYPE zst_ega_court_service_partners.
    " closes the gated cells of THAT row (per-row state lives in the <COL>_EN
    METHODS react_pers_info
      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                iv_field TYPE string.
    " ---- partner-search popup (drawn here; search via ZCL_RAK_BP_SEARCH) ----
    METHODS bp_fld
      IMPORTING iv_subject TYPE string
                iv_suffix  TYPE string
      RETURNING VALUE(rv)  TYPE string.
    METHODS bp_render
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                io_popup   TYPE REF TO z2ui5_cl_xml_view
                iv_subject TYPE string.
    METHODS bp_handle
      IMPORTING io_ctx       TYPE REF TO zif_rak_journey
                iv_event     TYPE string
                iv_subject   TYPE string
      RETURNING VALUE(rv_ok) TYPE abap_bool.
    METHODS bp_run_search
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                iv_subject TYPE string.
    " The ZCL_RAK_BP_SEARCH request template: everything that is NOT one of the
    " five identity fields the citizen types.
    METHODS bp_search_opts
      RETURNING VALUE(rs) TYPE zcl_rak_bp_search=>ty_req.
    METHODS bp_nationalities
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS bp_doc_types
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS bp_pick
      IMPORTING is_bp     TYPE zcl_zega_bp_mpc_ext=>ts_businesspartner
                iv_names  TYPE string
      RETURNING VALUE(rv) TYPE string.
    METHODS bp_button_text
      IMPORTING iv_partner     TYPE string
                iv_role_en     TYPE string
                iv_role_ar     TYPE string
      RETURNING VALUE(rv_text) TYPE string.
    " convert an external date string to internal YYYYMMDD; returns empty when
    " the input is empty OR invalid. Origin: CONVERT_DATE_TO_INTERNAL usage in
    METHODS conv_date_internal
      IMPORTING iv_ext        TYPE string
      RETURNING VALUE(rv_int) TYPE d.
ENDCLASS.



CLASS ZCL_C022_KHULA_CERTI_LOGIC IMPLEMENTATION.


  METHOD BP_BUTTON_TEXT.
*&---------------------------------------------------------------------*
*& bp_button_text — "Add <role>" until a partner is picked, then
*& "Change <role>". Arabic when sy-langu = 'A' (the engine renders the
*& screen in the logon language; code-drawn captions must follow it).
*&---------------------------------------------------------------------*
    IF sy-langu = 'A'.
      rv_text = COND string( WHEN iv_partner IS NOT INITIAL
      THEN |تغيير { iv_role_ar }|
      ELSE |اضافة { iv_role_ar }| ).
    ELSE.
      rv_text = COND string( WHEN iv_partner IS NOT INITIAL
      THEN |CHANGE { iv_role_en }|
      ELSE |ADD { iv_role_en }| ).
    ENDIF.
  ENDMETHOD.


  METHOD BP_DOC_TYPES.
    " AS4LOCAL = 'A' is the active version; without it a domain being reworked in
    " a transport returns the inactive value set too and the list doubles.
    SELECT domvalue_l AS key, ddtext AS text
    FROM dd07t
    WHERE domname = 'Z_MOI_DOC_TYPE' AND ddlanguage = @sy-langu AND as4local = 'A'
    ORDER BY domvalue_l ASCENDING
    INTO CORRESPONDING FIELDS OF TABLE @rt.
    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT domvalue_l AS key, ddtext AS text
      FROM dd07t
      WHERE domname = 'Z_MOI_DOC_TYPE' AND ddlanguage = 'E' AND as4local = 'A'
      ORDER BY domvalue_l ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
  ENDMETHOD.


  METHOD BP_FLD.
    rv = |{ to_upper( iv_subject ) }_{ iv_suffix }|.
  ENDMETHOD.


  METHOD BP_HANDLE.
    CASE iv_event.
      WHEN c_ev_bp_go.
        " The same event backs the Search button AND the type dropdown's change,
        " so switching type just re-renders.
        IF io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'IDNUM' ) ) IS NOT INITIAL.
          bp_run_search( io_ctx = io_ctx iv_subject = iv_subject ).
        ENDIF.
        rv_ok = abap_true.
      WHEN c_ev_bp_new.
        " Resume Search clears the RESULT only; the search terms stay, because the
        " commonest reason to search again is a typo in one digit.
        io_ctx->set_val( iv_name = bp_fld( iv_subject = iv_subject iv_suffix = 'PARTNER' ) iv_value = '' ).
        io_ctx->set_val( iv_name = bp_fld( iv_subject = iv_subject iv_suffix = 'NAME' )    iv_value = '' ).
        io_ctx->set_val( iv_name = bp_fld( iv_subject = iv_subject iv_suffix = 'PHONE' )   iv_value = '' ).
        io_ctx->set_val( iv_name = bp_fld( iv_subject = iv_subject iv_suffix = 'EMAIL' )   iv_value = '' ).
        rv_ok = abap_true.
      WHEN c_ev_bp_cxl.
        io_ctx->close_popup( ).
        rv_ok = abap_true.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD BP_NATIONALITIES.
    SELECT land1 AS key, landx50 AS text
    FROM t005t
    WHERE spras = @sy-langu
    ORDER BY land1 ASCENDING
    INTO CORRESPONDING FIELDS OF TABLE @rt.
    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = 'E'
      ORDER BY land1 ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
  ENDMETHOD.


  METHOD BP_PICK.
    " Dynamic access for display text only. Every component that decides
    " something (PARTNER, CATEGORY, EID, DOB) is named statically elsewhere.
    SPLIT iv_names AT ',' INTO TABLE DATA(lt_try).
    LOOP AT lt_try INTO DATA(lv_try).
      ASSIGN COMPONENT to_upper( condense( lv_try ) ) OF STRUCTURE is_bp
      TO FIELD-SYMBOL(<c>).
      IF sy-subrc = 0 AND <c> IS NOT INITIAL.
        rv = |{ <c> }|.
        CONDENSE rv.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD BP_RENDER.
    DATA(lo_dlg) = io_popup->dialog( title = 'Partner Search' contentwidth = '46rem' ).

    " ---- already found: show it, do not ask again ----------------------
    DATA(lv_partner) = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'PARTNER' ) ).
    IF lv_partner IS NOT INITIAL.
      DATA(lo_res) = lo_dlg->content(
            )->simple_form( editable = abap_false layout = 'ResponsiveGridLayout'
            columnsxl = '2' columnsl = '2' columnsm = '1'
            )->content( ns = 'form' ).
      lo_res->title( zcl_rak_journey_util=>esc(
      io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'NAME' ) ) ) ).
      lo_res->label( 'Partner' ).
      lo_res->text( zcl_rak_journey_util=>esc( lv_partner ) ).
      lo_res->label( 'Nationality' ).
      lo_res->text( zcl_rak_journey_util=>esc(
      io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'NAT' ) ) ) ).
      lo_res->label( 'Phone Number' ).
      lo_res->text( zcl_rak_journey_util=>esc(
      io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'PHONE' ) ) ) ).
      lo_res->label( 'Email' ).
      lo_res->text( zcl_rak_journey_util=>esc(
      io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'EMAIL' ) ) ) ).

      DATA(lo_rb) = lo_dlg->buttons( ).
      lo_rb->button( text  = 'Resume Search'
      icon  = 'sap-icon://synchronize'
      press = io_ctx->event( c_ev_bp_new ) ).
      lo_rb->button( text  = 'Use this partner'
      type  = 'Emphasized'
      icon  = 'sap-icon://accept'
      press = io_ctx->event( c_ev_bp_cxl ) ).
      RETURN.
    ENDIF.

    " ---- the search form ----------------------------------------------
    DATA(lv_by) = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'SEARCHBY' ) ).
    DATA(lo_form) = lo_dlg->content(
          )->simple_form( editable = abap_true layout = 'ResponsiveGridLayout'
          columnsxl = '2' columnsl = '2' columnsm = '1'
          )->content( ns = 'form' ).

    lo_form->label( 'Search By' ).
    DATA(lo_by) = lo_form->combobox(
          selectedkey = io_ctx->bind( bp_fld( iv_subject = iv_subject iv_suffix = 'SEARCHBY' ) )
          change      = io_ctx->event( c_ev_bp_go ) ).
    lo_by->item( key = c_bp_eid  text = 'Emirates ID' ).
    lo_by->item( key = c_bp_pass text = 'Passport (Non EID Holder only)' ).
    lo_by->item( key = c_bp_unif text = 'Unified ID (Non EID Holder only)' ).
    lo_by->item( key = c_bp_tlic text = 'Trade License Number' ).

    " Nothing else until a type is chosen: the answer decides what the rest of the
    " form even is.
    IF lv_by IS INITIAL.
      lo_dlg->buttons( )->button( text = 'Close' press = io_ctx->event( c_ev_bp_cxl ) ).
      RETURN.
    ENDIF.

    lo_form->label( SWITCH string( lv_by
    WHEN c_bp_eid  THEN 'Emirates ID'
    WHEN c_bp_pass THEN 'Passport Number'
    WHEN c_bp_unif THEN 'Unified ID'
    ELSE                'Trade License Number' ) ).
    lo_form->input( value = io_ctx->bind( bp_fld( iv_subject = iv_subject iv_suffix = 'IDNUM' ) ) ).

    " A trade licence is a company: no date of birth, no nationality.
    IF lv_by <> c_bp_tlic.
      lo_form->label( 'Date of Birth' ).
      " DDMMYYYY on screen, YYYYMMDD in the value — the MOI cross-check compares
      " the dates as strings, so a display format would fail every comparison.
      lo_form->date_picker( value         = io_ctx->bind( bp_fld( iv_subject = iv_subject iv_suffix = 'DOB' ) )
      displayformat = 'dd/MM/yyyy'
      valueformat   = 'yyyyMMdd' ).
      lo_form->label( 'Nationality' ).
      DATA(lo_nat) = lo_form->combobox(
            selectedkey = io_ctx->bind( bp_fld( iv_subject = iv_subject iv_suffix = 'NAT' ) ) ).
      LOOP AT bp_nationalities( ) INTO DATA(ls_n).
        lo_nat->item( key = ls_n-key text = ls_n-text ).
      ENDLOOP.
    ENDIF.

    IF lv_by = c_bp_pass.
      lo_form->label( 'Passport Type' ).
      DATA(lo_pt) = lo_form->combobox(
            selectedkey = io_ctx->bind( bp_fld( iv_subject = iv_subject iv_suffix = 'PPTYPE' ) ) ).
      LOOP AT bp_doc_types( ) INTO DATA(ls_p).
        lo_pt->item( key = ls_p-key text = ls_p-text ).
      ENDLOOP.
    ENDIF.

    DATA(lo_btns) = lo_dlg->buttons( ).
    lo_btns->button( text  = 'Search'
    type  = 'Emphasized'
    icon  = 'sap-icon://search'
    press = io_ctx->event( c_ev_bp_go ) ).
    lo_btns->button( text = 'Close' press = io_ctx->event( c_ev_bp_cxl ) ).
  ENDMETHOD.


  METHOD BP_RUN_SEARCH.
    DATA(ls_req) = bp_search_opts( ).
    DATA(lv_by)  = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'SEARCHBY' ) ).
    DATA(lv_num) = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'IDNUM' ) ).

    ls_req-idtype      = lv_by.
    ls_req-dob         = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'DOB' ) ).
    ls_req-nationality = io_ctx->get_val( bp_fld( iv_subject = iv_subject iv_suffix = 'NAT' ) ).

    CASE lv_by.
      WHEN c_bp_eid.
        ls_req-eid      = lv_num.
        ls_req-call_moi = abap_true.
      WHEN c_bp_tlic.
        ls_req-trade_licence = lv_num.
      WHEN OTHERS.
        ls_req-eid = lv_num.
    ENDCASE.

    DATA(ls_res) = NEW zcl_rak_bp_search( )->search( is_req = ls_req ).

    DATA(lv_err) = abap_false.
    LOOP AT ls_res-msg INTO DATA(ls_m).
      io_ctx->add_msg( iv_type = COND #( WHEN ls_m-type = 'E' OR ls_m-type = 'A' THEN 'Error'
      WHEN ls_m-type = 'W' THEN 'Warning'
      ELSE 'Information' )
      iv_text = CONV string( ls_m-message ) ).
      IF ls_m-type = 'E' OR ls_m-type = 'A'.
        lv_err = abap_true.
      ENDIF.
    ENDLOOP.
    " An expired licence or ID is an error and must NOT become a found partner.
    IF lv_err = abap_true.
      RETURN.
    ENDIF.

    READ TABLE ls_res-rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Results land on the party being searched: <SUBJECT>_PARTNER / _NAME are the
    " read-only fields shown on the Parties step, _PHONE / _EMAIL feed the card.
    io_ctx->set_val( iv_name  = bp_fld( iv_subject = iv_subject iv_suffix = 'PARTNER' )
    iv_value = CONV string( ls_bp-partner ) ).

    " The BP row carries the whole name in both languages, so pick the one that
    " matches the logon language rather than assembling it from parts.
    io_ctx->set_val( iv_name  = bp_fld( iv_subject = iv_subject iv_suffix = 'NAME' )
    iv_value = COND string( WHEN sy-langu = 'A' THEN ls_bp-arabic_full_name
    ELSE ls_bp-english_full_name ) ).

    io_ctx->set_val( iv_name  = bp_fld( iv_subject = iv_subject iv_suffix = 'PHONE' )
    iv_value = CONV string( ls_bp-telephone_number ) ).
    io_ctx->set_val( iv_name  = bp_fld( iv_subject = iv_subject iv_suffix = 'EMAIL' )
    iv_value = bp_pick( is_bp    = ls_bp
    iv_names = 'SMTP_ADDR,EMAIL,E_MAIL,EMAILADDRESS,EMAIL_ADDRESS,EMAIL_ID' ) ).
  ENDMETHOD.


  METHOD BP_SEARCH_OPTS.
*&---------------------------------------------------------------------*
*& BP_SEARCH_OPTS — the request template handed to ZCL_RAK_BP_SEARCH.
*& Only the non-identity switches belong here; bp_run_search fills EID /
*& TRADE_LICENCE / IDTYPE / DOB / NATIONALITY from what the citizen typed.
*&---------------------------------------------------------------------*
    " E10 / E20 are the non-production systems. Their BP data is test data, so a
    " MOI date-of-birth or nationality mismatch and an expired trade licence or
    " Emirates ID are artefacts of that data rather than real findings — and
    " because those findings are errors, they would block every search there.
    " Skip only those three VERDICTS: MOI is still called and the BP still
    " updated from it (that is SKIP_MOI_MISMATCH, not NO_MOI_CALL). Production
    " keeps the full checks, because this must never soften a live decision.
    IF sy-sysid = 'E10' OR sy-sysid = 'E20'.
      rs-skip_moi_mismatch = abap_true.
      rs-skip_tl_expiry    = abap_true.
      rs-skip_eid_expiry   = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD CONV_DATE_INTERNAL.
*&---------------------------------------------------------------------*
*& conv_date_internal — date string -> SAP internal YYYYMMDD; empty on
*& blank or invalid input (so callers treat blank and invalid distinctly
*& by also testing the raw value).
*& io_ctx delivers DATE fields as ISO 'YYYY-MM-DD', which is what the UI5
*& date control posts — CONVERT_DATE_TO_INTERNAL only understands the user's
*& format, so ISO is handled explicitly first (and an already-internal
*& YYYYMMDD is passed through). Anything else falls back to the FM.
*&---------------------------------------------------------------------*
    DATA lv_raw TYPE string.
    lv_raw = condense( iv_ext ).
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

    " ISO 'YYYY-MM-DD' -> 'YYYYMMDD'
    IF strlen( lv_raw ) = 10 AND lv_raw+4(1) = '-' AND lv_raw+7(1) = '-'.
      rv_int = lv_raw(4) && lv_raw+5(2) && lv_raw+8(2).
      IF rv_int CO '0123456789'.
        RETURN.
      ENDIF.
      CLEAR rv_int.
      RETURN.
    ENDIF.

    IF strlen( lv_raw ) = 8 AND lv_raw CO '0123456789'.
      rv_int = lv_raw.
      RETURN.
    ENDIF.

    CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
      EXPORTING
        date_external            = lv_raw
        accept_initial_date      = 'X'
      IMPORTING
        date_internal            = rv_int
      EXCEPTIONS
        date_external_is_invalid = 1
        OTHERS                   = 2.
    IF sy-subrc <> 0.
      CLEAR rv_int.
    ENDIF.
  ENDMETHOD.


  METHOD GET_OTR_TEXT_BY_ALIAS.
*&---------------------------------------------------------------------*
*& get_otr_text_by_alias — same, honouring sy-langu (kept from source).
*&---------------------------------------------------------------------*
    DATA lv_text TYPE sotr_txt.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = iv_alias
        langu           = sy-langu
      IMPORTING
        e_text          = lv_text
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0.
      rv_text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD GET_OTR_TEXT_FOR_ALIAS.
*&---------------------------------------------------------------------*
*& get_otr_text_for_alias — resolve a message OTR alias (kept from source).
*&---------------------------------------------------------------------*
    DATA lv_text TYPE sotr_txt.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = iv_alias
      IMPORTING
        e_text          = lv_text
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0.
      rv_text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD T100_TEXT.
*&---------------------------------------------------------------------*
*& t100_text — a T100 message's text in the logon language.
*& The WD's mandatory messages are T100, not OTR: CHECK_INITIAL_FIELDS
*& renders whatever cl_wd_dynamic_tool returns through FORMAT_MESSAGE, and
*& substitutes its own id/number for one attribute. Reading them the same way
*& keeps the wording single-sourced with the legacy screen.
*& Returns BLANK when the message does not exist — FORMAT_MESSAGE swallows
*& everything via OTHERS = 0 — so every caller must have a fallback, exactly
*& as with get_otr_text_for_alias.
*&---------------------------------------------------------------------*
    DATA lv_text TYPE string.
    CALL FUNCTION 'FORMAT_MESSAGE'
      EXPORTING
        id     = iv_id
        lang   = sy-langu
        no     = iv_no
      IMPORTING
        msg    = lv_text
      EXCEPTIONS
        OTHERS = 0.
    rv_text = lv_text.
  ENDMETHOD.


  METHOD OPTIONS_FROM_DOMAIN.
*&=====================================================================*
*& PRIVATE HELPERS
*&=====================================================================*
*&---------------------------------------------------------------------*
*& options_from_domain — DDIC domain fixed values -> tt_option (key/text)
*& Replaces the per-dropdown DDUT_DOMVALUES_GET blocks (fill_dropdown_*).
*&---------------------------------------------------------------------*
    DATA lt_dd07v TYPE TABLE OF dd07v.
    CALL FUNCTION 'DDUT_DOMVALUES_GET'
      EXPORTING
        name          = iv_domain
        langu         = sy-langu
      TABLES
        dd07v_tab     = lt_dd07v
      EXCEPTIONS
        illegal_input = 1
        OTHERS        = 2.
    CHECK sy-subrc = 0.
    LOOP AT lt_dd07v INTO DATA(ls).
      APPEND VALUE #( key = ls-domvalue_l text = ls-ddtext ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD REACT_PERS_INFO.
*&---------------------------------------------------------------------*
*& REACT_PERS_INFO — per-row reactive behaviour of the personal-information
*& grid, as in the WebDynpro:
*&   Residence status = '01' (Citizen)  -> Village number editable
*&   Job status       = '01' (Employed) -> Main profession / Profession /
*&                                         Employer / Employer Emirate editable
*& A cell template is shared by every row, so the state cannot be rendered per
*& row — it lives in the hidden boolean <COL>_EN columns, which the renderer
*& binds to 'editable'.
*& The gates are recomputed for EVERY row from that row's own trigger values,
*& so the handler does not depend on the row index in the event name (the grid
*& has two fixed rows, so the cost is nil and the result is identical).
*& Closing a gate ALWAYS clears the target: a disabled cell keeps whatever was
*& typed before and would otherwise still post to the backend.
*&---------------------------------------------------------------------*
    DATA(ls_g) = io_ctx->get_grid_data( 'PERS_INFO' ).
    IF ls_g-rows IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_tt)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TT' ] ).
    DATA(lv_tw)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TW' ] ).
    DATA(lv_tu)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TU' ] ).
    DATA(lv_tu_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TU_EN' ] ).
    DATA(lv_tx)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TX' ] ).
    DATA(lv_tx_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TX_EN' ] ).
    DATA(lv_u2)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000U2' ] ).
    DATA(lv_u2_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000U2_EN' ] ).
    DATA(lv_ty)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TY' ] ).
    DATA(lv_ty_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TY_EN' ] ).
    DATA(lv_tz)    = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TZ' ] ).
    DATA(lv_tz_en) = line_index( ls_g-columns[ table_line = 'ZZAFLD0000TZ_EN' ] ).

    DATA lv_cells   TYPE i.
    DATA lv_open_tu TYPE abap_bool.
    DATA lv_open_em TYPE abap_bool.
    DATA lv_flag    TYPE string.
    FIELD-SYMBOLS <row> TYPE zif_rak_journey=>tt_string.

    LOOP AT ls_g-rows ASSIGNING <row>.
      lv_cells = lines( <row> ).

      " ---- Residence status = Citizen -> village number ----------------
      IF lv_tt > 0 AND lv_tt <= lv_cells AND lv_tu_en > 0 AND lv_tu_en <= lv_cells.
        lv_open_tu = xsdbool( <row>[ lv_tt ] = '01' ).
        <row>[ lv_tu_en ] = COND string( WHEN lv_open_tu = abap_true THEN 'X' ELSE '' ).
        IF lv_open_tu = abap_false AND lv_tu > 0 AND lv_tu <= lv_cells.
          CLEAR <row>[ lv_tu ].
        ENDIF.
      ENDIF.

      " ---- Job status = Employed -> the employment block ---------------
      IF lv_tw > 0 AND lv_tw <= lv_cells.
        lv_open_em = xsdbool( <row>[ lv_tw ] = '01' ).
        lv_flag    = COND string( WHEN lv_open_em = abap_true THEN 'X' ELSE '' ).
        IF lv_tx_en > 0 AND lv_tx_en <= lv_cells.
          <row>[ lv_tx_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_tx > 0 AND lv_tx <= lv_cells.
            CLEAR <row>[ lv_tx ].
          ENDIF.
        ENDIF.
        IF lv_u2_en > 0 AND lv_u2_en <= lv_cells.
          <row>[ lv_u2_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_u2 > 0 AND lv_u2 <= lv_cells.
            CLEAR <row>[ lv_u2 ].
          ENDIF.
        ENDIF.
        IF lv_ty_en > 0 AND lv_ty_en <= lv_cells.
          <row>[ lv_ty_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_ty > 0 AND lv_ty <= lv_cells.
            CLEAR <row>[ lv_ty ].
          ENDIF.
        ENDIF.
        IF lv_tz_en > 0 AND lv_tz_en <= lv_cells.
          <row>[ lv_tz_en ] = lv_flag.
          IF lv_open_em = abap_false AND lv_tz > 0 AND lv_tz <= lv_cells.
            CLEAR <row>[ lv_tz ].
          ENDIF.
        ENDIF.
      ENDIF.
    ENDLOOP.

    io_ctx->set_grid_data( iv_field = 'PERS_INFO' is_data = ls_g ).
  ENDMETHOD.


  METHOD REFRESH_HELP_URL.
*&---------------------------------------------------------------------*
*& refresh_help_url — Origin: VIEW_MAIN->SELECTED_SERVICE_PROCESS (help
*& branch) + E_GET_HELP_URL. Resolves the help URL via
*& ZFM_EGA_GET_ESERVICE_HELP_URL and stores it in HELP_URL.
*& Single-service class: AS3 always maps to help code 'YSR2'.
*&---------------------------------------------------------------------*
    DATA lv_url TYPE zde_ega_wdp_url_help.
    DATA lv_wdp_id TYPE zde_ega_wdp_id_url VALUE 'YSR2'.   " AS3 help code
    CALL FUNCTION 'ZFM_EGA_GET_ESERVICE_HELP_URL'
      EXPORTING
        iv_wdp_id   = lv_wdp_id
        iv_language = sy-langu       " language-aware (FM default is 'A')
      IMPORTING
        ev_help_url = lv_url.
    io_ctx->set_val( iv_name = 'HELP_URL' iv_value = |{ lv_url }| ).
  ENDMETHOD.


  METHOD SET_PARTNER_FUNCTIONS.
*&---------------------------------------------------------------------*
*& set_partner_functions — Origin: COMPONENTCONTROLLER->GET_PARTNER_FUNCTIONS.
*& For every party BP that is filled, stamp its partner-function code onto
*& the matching _FT component. Only the AS3-relevant roles are populated;
*& the others stay initial (harmless if the component is absent for a role).
*&---------------------------------------------------------------------*
    IF cs_partners-husband_bp      IS NOT INITIAL. cs_partners-husband_ft      = 'Y0000447'. ENDIF.
    IF cs_partners-wife_bp         IS NOT INITIAL. cs_partners-wife_ft         = 'Y0000407'. ENDIF.
    IF cs_partners-marriage_reg_bp IS NOT INITIAL. cs_partners-marriage_reg_ft = 'Y0000410'. ENDIF.
    IF cs_partners-witness1_bp     IS NOT INITIAL. cs_partners-witness1_ft     = 'Y0000110'. ENDIF.
    IF cs_partners-witness2_bp     IS NOT INITIAL. cs_partners-witness2_ft     = 'Y0000110'. ENDIF.
    IF cs_partners-divorcee_bp     IS NOT INITIAL. cs_partners-divorcee_ft     = 'Y0000420'. ENDIF.
    IF cs_partners-divorcer_bp     IS NOT INITIAL. cs_partners-divorcer_ft     = 'Y0000450'. ENDIF.
    IF cs_partners-attester_bp     IS NOT INITIAL. cs_partners-attester_ft     = 'Y0000446'. ENDIF.
    IF cs_partners-sponsor_bp      IS NOT INITIAL. cs_partners-sponsor_ft      = 'Y0000200'. ENDIF.
    IF cs_partners-guardian_bp     IS NOT INITIAL. cs_partners-guardian_ft     = 'Y0000442'. ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_ATTACH.
*&---------------------------------------------------------------------*
*& ON_ATTACH — fires after a file is staged for iv_field (the upload
*& FIELD NAME). The engine has already done the size check and stored the
*& file, so the only remaining check (Origin: CHECK_ENTRIES) is the
*& allowed-extension check against the system master list.
*& The staged file is read via io_ctx->get_attachment_files( ), whose
*& IDENTIFIER1 column carries the upload field name — so the file(s) for
*& this field are the rows where identifier1 = iv_field.
*&---------------------------------------------------------------------*
    CHECK iv_field IS NOT INITIAL.

    DATA lt_allowed TYPE ztt_ega_file_extensions.
    DATA lt_ext_ret TYPE bapiret2_t.
    CALL FUNCTION 'ZFM_EGA_GET_FILE_EXT_WD_UPLOAD'
      IMPORTING
        et_file_extensions = lt_allowed
        et_return          = lt_ext_ret.

    DATA ls_file    TYPE /qnv/sbuild_attachments_st.
    DATA lv_ext     TYPE c LENGTH 40.
    DATA lv_ext_msg TYPE string.
    LOOP AT io_ctx->get_attachment_files( ) INTO ls_file
    WHERE identifier1 = iv_field.
      CLEAR lv_ext.
      CALL FUNCTION 'TRINT_FILE_GET_EXTENSION'
        EXPORTING
          filename  = ls_file-file_name
          uppercase = 'X'
        IMPORTING
          extension = lv_ext.
      IF NOT line_exists( lt_allowed[ file_extension = lv_ext ] ).
        MESSAGE ID 'ZMSG_EGA_CM' TYPE 'E' NUMBER '111' WITH lv_ext INTO lv_ext_msg.
        io_ctx->add_msg( iv_type = 'Error' iv_text = lv_ext_msg ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE.
*&---------------------------------------------------------------------*
*& ON_CHANGE — folds the WD's field-change handlers. Two kinds:
*&  (a) clear-on-change: when a driver dropdown changes, blank the now-
*&      irrelevant dependent fields (Origin: SET_PREV_DIV / SET_MARR_CONS /
*&      SET_GRANT / CHECK_NO_PREV_DIV). EDITABLE/READONLY/REQUIRE toggles for
*&      the same drivers are declarative rules (ZRAK_T_JNY_RULE); only the
*&      value-clearing lives here, as the engine drives clearing via on_change.
*&  (b) value derivations: pin SERVICE_TYPE; resolve typed party BPs to names.
*&  (c) reactive PERS_INFO grid: a grid change arrives as
*&      'PERS_INFO.<COL>#<ROW>' and is routed to react_pers_info( ).
*&---------------------------------------------------------------------*

    DATA(lv_ev) = to_upper( iv_field ).
    IF lv_ev CS 'PERS_INFO.ZZAFLD0000TT'
    OR lv_ev CS 'PERS_INFO.ZZAFLD0000TW'.
      react_pers_info( io_ctx = io_ctx iv_field = iv_field ).
      RETURN.
    ENDIF.

    CASE iv_field.
      WHEN 'EARLIER_MARRIAGES'.        " Earlier marriages
        "   Origin: ONACTIONSET_PREV_DIV — clears both dependents on any change.
        io_ctx->set_val( iv_name = 'PREV_DIVORCES_COUNT' iv_value = space ). " no. previous divorces
        io_ctx->set_val( iv_name = 'FIRST_MARR_CTR_DT' iv_value = space ). " first marriage contract date

      WHEN 'CASE_UPON_DIVORCE'.        " Divorced case upon divorce
        "   Origin: ONACTIONSET_MARR_CONS — clears both dependents on any change.
        io_ctx->set_val( iv_name = 'MARR_CONSUMMATED' iv_value = space ). " marriage consummated
        io_ctx->set_val( iv_name = 'ISOLATION' iv_value = space ). " isolation

      WHEN 'MARR_GRANT_RECEIVED'.        " Was a marriage grant received
        "   Origin: ONACTIONSET_GRANT — clears grant side on any change.
        io_ctx->set_val( iv_name = 'GRANT_SIDE' iv_value = space ). " grant side

      WHEN 'PREV_DIVORCES_COUNT'.        " No. of previous divorces
        "   Origin: CHECK_NO_PREV_DIV — clear last divorce date only when there
        " is no prior divorce (UM <= 0). UM arrives as a STRING, so it must not
        DATA(lv_prev_div) = condense( io_ctx->get_val( 'PREV_DIVORCES_COUNT' ) ).
        IF lv_prev_div IS INITIAL
        OR ( lv_prev_div CO '0123456789' AND lv_prev_div = 0 ).
          io_ctx->set_val( iv_name = 'LAST_DIV_DATE' iv_value = space ). " last divorce date
        ENDIF.

      WHEN 'IF_SERVICE_TYPE'.
        "   Origin: ONACTIONSELECT_SERVICE -> SELECTED_SERVICE_PROCESS.
        io_ctx->set_val( iv_name = 'SERVICE_TYPE' iv_value = c_default_service ).
        refresh_help_url( io_ctx ).

      WHEN OTHERS.
        " onactiononselect_non_eid / onactionrb_payer1 / onactionrb_payer2
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE.
*&---------------------------------------------------------------------*
*& ON_CUSTOM_VALIDATE — runs per step (and for every step on submit).
*& CONTRACT: RETURN the messages in rt (tt_msg). The engine appends rt to
*& the step's message set and BLOCKS the step when any row is type 'Error'.
*& Do NOT use io_ctx->add_msg here — that shows a strip but does not block.
*& Folds 15 methods; is_valid_* / get_fld_list / modify_val_witness_list
*& were aggregation helpers whose checks are inlined under the step guard.
*&---------------------------------------------------------------------*
    rt = super->zif_rak_journey_logic~on_custom_validate(
    io_ctx = io_ctx iv_step = iv_step ).

    DATA(lv_today) = |{ sy-datum }|.
    CASE iv_step.
      WHEN c_step_marr.
        "   MARR — Marriage Contract. Origin: VALIDATE_DATES_FILE_SIZE — the
        "   marriage-contract date (8K) must not be in the future. (AS3 has no
        DATA(lv_contr_dat) = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ).
        IF lv_contr_dat IS NOT INITIAL AND lv_contr_dat > lv_today.
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_VALIDATE_FUTURE_DATE' ) ) TO rt.
        ENDIF.

      WHEN c_step_divo.
        "   DIVO — Divorce Details. The date-ordering rule lives here because
        "   this is the LAST step that owns any of its fields: marriage contract
        DATA(lv_div_dat)  = conv_date_internal( io_ctx->get_val( 'DIV_KHULA_DATE' ) ). " Date of divorce or khula
        DATA(lv_marr_dat) = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ). " Marriage contract date
        DATA(lv_fst_marr) = conv_date_internal( io_ctx->get_val( 'FIRST_MARR_CTR_DT' ) ). " First marriage contract date
        DATA(lv_lst_div)  = conv_date_internal( io_ctx->get_val( 'LAST_DIV_DATE' ) ). " Last divorce date
        IF lv_marr_dat IS NOT INITIAL AND lv_div_dat IS NOT INITIAL AND lv_marr_dat > lv_div_dat.
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_LAST_MARR_CONTR_DATE' ) ) TO rt.
        ENDIF.
        IF lv_fst_marr IS NOT INITIAL.
          IF ( lv_div_dat IS NOT INITIAL AND lv_fst_marr > lv_div_dat )
          OR ( lv_marr_dat  IS NOT INITIAL AND lv_fst_marr > lv_marr_dat )
          OR ( lv_lst_div  IS NOT INITIAL AND lv_fst_marr > lv_lst_div ).
            APPEND VALUE #( type = 'Error'
            text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_FST_MARR_CONTR_DATE' ) ) TO rt.
          ENDIF.
        ENDIF.
        IF lv_lst_div IS NOT INITIAL.
          IF ( lv_div_dat IS NOT INITIAL AND lv_lst_div > lv_div_dat )
          OR ( lv_marr_dat  IS NOT INITIAL AND lv_lst_div > lv_marr_dat )
          OR ( lv_fst_marr  IS NOT INITIAL AND lv_lst_div < lv_fst_marr ).
            APPEND VALUE #( type = 'Error'
            text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_LAST_DIV_DATE' ) ) TO rt.
          ENDIF.
        ENDIF.

      WHEN c_step_hist.
        "   THIS step: the number of wives (V3) must be numeric and the marriage
        DATA(lv_wives) = condense( io_ctx->get_val( 'WIVES_COUNT_HUSBAND' ) ).
        IF lv_wives IS NOT INITIAL AND lv_wives CN '0123456789'.
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_DIV_REQUE_ATT_MSG' ) ) TO rt.
        ENDIF.
        "   Children under 21 gets the same numeric test even though the WD has
        " none - VALIDATE_NUMERIC only ever read ZZAFLD0000V3, the wives count.
        " Its OTR message names that field ("...number of waives for husband")
        " so it cannot be reused here, and no OTR concept exists for this one;
        " GET_OTR_TEXT_FOR_ALIAS returns BLANK for an alias that is not there,
        " which would block the step behind an empty strip. Hence the literal,
        " worded like the OTR message and naming the field by its OTR label.
        DATA(lv_child_u21) = condense( io_ctx->get_val( 'CHILDREN_UNDER_21' ) ).
        IF lv_child_u21 IS NOT INITIAL AND lv_child_u21 CN '0123456789'.
          APPEND VALUE #( type = 'Error'
          text = COND string(
          WHEN sy-langu = 'A'
          THEN |الرجاء ادخال رقم لحقل عدد الأولاد أقل من 21 سنة|
          ELSE |Please add numeric value only for children-under-21| ) ) TO rt.
        ENDIF.
        "   Same test on the total number of children (8M). The WD imposes
        " nothing at all here - no method reads the attribute, its control sets
        " LENGTH = '0', and its STATE binds STC_DIV_MARR_TAKEOFF_1 which AS3 sets
        " to 0 - and ZZAFLD00008M is CHAR(60), so the legacy screen accepts 60
        " characters of anything. A count field should hold digits, so this goes
        " beyond the WD by choice. No OTR or T100 concept exists for the message.
        DATA(lv_children) = condense( io_ctx->get_val( 'CHILDREN_COUNT' ) ).
        IF lv_children IS NOT INITIAL AND lv_children CN '0123456789'.
          APPEND VALUE #( type = 'Error'
          text = COND string(
          WHEN sy-langu = 'A'
          THEN |الرجاء ادخال رقم لحقل عدد الابناء|
          ELSE |Please add numeric value only for no. of children| ) ) TO rt.
        ENDIF.
        "   Origin: CHECK_INITIAL_FIELDS — for ZZAFLD0000UM alone the WD swaps
        " the framework's mandatory text for ZMSG_ECOURT 000, "Number of
        " divorces can't be Zero". That wording is the giveaway: the framework
        " check tests whether the bound attribute is INITIAL, and on a numeric
        " attribute initial and zero are the same value, so the mandatory check
        " doubles as a zero check. MISSING_REQUIRED tests IS INITIAL on the
        " STRING form instead, where '0' is a non-empty string and passes - so
        " the blank case is covered by rule R04 plus the field's MSG, and only
        " zero needs catching here. Gated on EARLIER_MARRIAGES = 1 because that
        " is what makes the field mandatory at all (ONACTIONSET_PREV_DIV sets
        " STC_PREV_DIV = '01' only for UY = '1'), so a zero left behind on the
        " No branch must not block the step.
        " CO '0' matches '0', '00' and '000' without converting the string to a
        " number, which would raise CX_SY_CONVERSION_NO_NUMBER on any typo.
        DATA(lv_prev_div) = condense( io_ctx->get_val( 'PREV_DIVORCES_COUNT' ) ).
        IF io_ctx->get_val( 'EARLIER_MARRIAGES' ) = '1'
        AND lv_prev_div IS NOT INITIAL
        AND lv_prev_div CO '0'.
          DATA(lv_zero_msg) = t100_text( iv_id = 'ZMSG_ECOURT' iv_no = '000' ).
          IF lv_zero_msg IS INITIAL.
            lv_zero_msg = COND string(
            WHEN sy-langu = 'A'
            THEN |لا يمكن لعدد حالات الطلاق السابقة بين الطرفين أن يساوي صفر|
            ELSE |Number of divorces can't be Zero| ).
          ENDIF.
          APPEND VALUE #( type = 'Error' text = lv_zero_msg ) TO rt.
        ENDIF.
        DATA(lv_prov_dat) = conv_date_internal( io_ctx->get_val( 'MARR_PROVING_DATE' ) ).
        IF lv_prov_dat IS NOT INITIAL AND lv_prov_dat > lv_today.
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_VALIDATE_FUTURE_DATE' ) ) TO rt.
        ENDIF.

      WHEN c_step_prty.
        "   PRTY — Parties. Both witnesses filled or both empty, and no BP
        "   repeated across the four roles (Origin: VALIDATE_WITNESS /
        "   The divorcee is starred on the WD screen but its field is READONLY
        "   (the Add-BP popup writes it), and MISSING_REQUIRED loops
        "   WHERE readonly = abap_false and CONTINUEs on FTYPE 'READONLY', so
        "   the configured REQUIRED flag draws the asterisk and enforces
        "   nothing. Without this check ON_SUBMIT posts ls_partners-divorcee_bp
        "   empty. The divorcer needs no twin check: ON_INIT seeds it from the
        "   login BP, so it cannot be blank here.
        "   The text is a literal by sy-langu rather than an OTR alias: the WD
        "   had no message for this (its own star was decorative), and
        "   get_otr_text_for_alias returns BLANK on no_entry_found, which would
        "   block the step with an empty error strip.
        IF io_ctx->get_val( 'DIVORCEE_PARTNER' ) IS INITIAL.
          APPEND VALUE #( type = 'Error'
          text = COND string( WHEN sy-langu = 'A' THEN |يجب إضافة المطلقة|
          ELSE |The divorcee is required| ) ) TO rt.
        ENDIF.
        DATA(lv_wit1_bp) = io_ctx->get_val( 'WITNESS1_PARTNER' ).
        DATA(lv_wit2_bp) = io_ctx->get_val( 'WITNESS2_PARTNER' ).
        IF NOT ( ( lv_wit1_bp IS NOT INITIAL AND lv_wit2_bp IS NOT INITIAL )
        OR ( lv_wit1_bp IS INITIAL     AND lv_wit2_bp IS INITIAL ) ).
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/CIVIL_COURT_WITNESS_ERROR_MSG' ) ) TO rt.
        ENDIF.
        DATA(lt_bp) = VALUE zif_rak_journey=>tt_string(
              ( io_ctx->get_val( 'DIVORCEE_PARTNER' ) )
              ( io_ctx->get_val( 'DIVORCER_PARTNER' ) )
              ( io_ctx->get_val( 'WITNESS1_PARTNER' ) )
              ( io_ctx->get_val( 'WITNESS2_PARTNER' ) ) ).
        DELETE lt_bp WHERE table_line IS INITIAL.
        DATA(lt_bp_u) = lt_bp.
        SORT lt_bp_u. DELETE ADJACENT DUPLICATES FROM lt_bp_u.
        IF lines( lt_bp_u ) <> lines( lt_bp ).
          APPEND VALUE #( type = 'Error'
          text = get_otr_text_for_alias( 'Z_RAKEGA_MUNI/ZWDC_COURT_ATT_DUPLICATE_PARTIES_INV' ) ) TO rt.
        ENDIF.

      WHEN c_step_docs.
        " cross-attachment re-check here. The payer is fixed to the divorcer, so
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_INIT.
*&---------------------------------------------------------------------*
*& CLASS OVERVIEW (kept inside on_init so the class-builder can store it)
*&---------------------------------------------------------------------*
*& ZCL_C022_KHULA_CERTI_LOGIC  —  journey-engine handler
*&---------------------------------------------------------------------*
*& Generated from the WebDynpro migration of ZWDC_EGA_ECREATE_SR_COURT.
*& Source handler: ZCL_ECREATE_SR_COURT_HANDLER (186 methods).
*& Mapping:        ZCL_ECREATE_SR_COURT_method_mapping.xlsx
*& Template:       ZCL_RAK_<NAME>_LOGIC / productive sample ZCL_RAK_E020_LOGIC.
*&
*& LOCKED CONVENTIONS APPLIED
*&  - INHERITS FROM zcl_rak_journey_logic; redefines only the callbacks used.
*&  - No mutable class attributes. State lives in io_ctx (get_val/set_val).
*&  - Event/notification messages via io_ctx->add_msg( iv_type = <sev> iv_text = )
*&    where <sev> is the z2ui5 long form 'Error' / 'Warning' / 'Success'
*&    (NOT the short 'E' — the engine renders type verbatim and gates on 'Error').
*&    add_msg takes only iv_type / iv_text.
*&  - on_custom_validate does NOT use add_msg: it must RETURN its messages in
*&    rt (tt_msg, type = 'Error'); the engine appends rt to the step's error set
*&    and blocks the step when any row is type 'Error'. add_msg there would show
*&    a strip but would NOT block the step.
*&  - SERVICE_TYPE seeded in on_init and read with io_ctx->get_val everywhere.
*&  - Message-alias OTR texts kept as private runtime helpers
*&    (get_otr_text_for_alias / get_otr_text_by_alias -> SOTR_GET_TEXT_KEY).
*&  - Domain-backed dropdowns served by on_value_help via private helper
*&    options_from_domain( iv_domain ).
*&
*& OPEN ITEMS (current; see GENERATION_DECISIONS.md + the *_addenda xlsx):
*&  MANDATORY FIELDS — switched on. Verified against the live WD, which on a
*&   blank Submit names 11 fields plus the attachment; every one of those is
*&   REQUIRED in the config, with no gap in that direction. Three routes,
*&   because the engine enforces them differently:
*&    - 12 ordinary fields + ATTACHMENT: MISSING_REQUIRED reads the REQUIRED
*&      flag on ZRAK_T_JNY_FLD directly. ATTACHMENT rides its HAS_ATTACH
*&      branch, which also accepts a document already filed in the backend so
*&      resuming a draft is not a dead end.
*&    - 3 grid columns (PARTY_TYPE_TXT / TT / TW): REQUIRED on ZRAK_T_JNY_COL.
*&      PERS_INFO itself also carries REQUIRED = 'X' and that is a
*&      prerequisite, not decoration: MISSING_REQUIRED skips a field whose own
*&      IS_REQUIRED is false before it reaches the per-column loop.
*&    - CONTRACT_PLACE / DIVORCEE_PARTNER / DIVORCER_PARTNER are READONLY.
*&      REQ_LABEL still draws their asterisk, but MISSING_REQUIRED loops
*&      WHERE readonly = abap_false and CONTINUEs on FTYPE 'READONLY', so the
*&      flag cannot enforce them. Only DIVORCEE_PARTNER was a real gap (the
*&      other two are seeded in ON_INIT) and ON_CUSTOM_VALIDATE now blocks the
*&      PRTY step when it is empty.
*&   Deliberately NOT required: FIRST_MARR_CTR_DT and PREV_DIVORCES_COUNT
*&   are made mandatory by rules R02 / R04 when EARLIER_MARRIAGES = 1;
*&   CHILDREN_UNDER_21 stays optional: its control G_TAKEOFF_ZZAFLD0000UL
*&   carries STATE = '00', the screen prefills it with 0 and shows no asterisk.
*&   DOCUMENT_TYPE is required — DD_DOCUMENT_TYPE_CP carries STATE = '01' in
*&   VIEW_ADD_ATTACHMENT (the Open_Mandatory sheet had it as unstarred, read
*&   off the main screen, where that control does not appear).
*&   WIVES_COUNT_HUSBAND is required because its control
*&   G_TAKEOFF_ZZAFLD0000V3 carries STATE = '01', and it is the field the WD's
*&   VALIDATE_NUMERIC checks. The plain REQUIRED flag is right for "not blank,
*&   0 valid" — MISSING_REQUIRED tests IS INITIAL on the string form, so '0'
*&   passes; ON_CUSTOM_VALIDATE adds the numeric test.
*&   NOTE — these two fields map to the OPPOSITE backend columns from what an
*&   earlier reading assumed. LABEL_FOR is broken on both labels (each points at
*&   G_TAKEOFF_ZZAFLD0000UL), but label naming, layout order (V3 label+input at
*&   47/48, UL at 49/50) and the STATE flags all agree: V3 = number of wives,
*&   UL = children under 21. Confirmed against the screen.
*&  CONDITIONAL MANDATORY — the WD binds each control's STATE property to an
*&   attribute of its STATE context node and the ONACTIONSET_* handlers write
*&   '01' / '00' into it, so mandatory is data-driven there, not hard-coded.
*&   Those flags are ported as REQUIRE rules, not as code:
*&    R16  CASE_UPON_DIVORCE = 1 -> ISOLATION        (stc_isolation)
*&    R17  CASE_UPON_DIVORCE = 2 -> MARR_CONSUMMATED (stc_marr_cons)
*&    R11  PREV_DIVORCES_COUNT  > 0 -> LAST_DIV_DATE     (stc_last_div)
*&    R02 / R04 EARLIER_MARRIAGES = 1 -> FIRST_MARR_CTR_DT +
*&              PREV_DIVORCES_COUNT                      (stc_prev_div)
*&   GRANT_SIDE gets no REQUIRE: ONACTIONSET_GRANT touches ms_input_allowed
*&   only and never STATE. CHILDREN_COUNT / MARR_PROVING_DATE bind
*&   STC_DIV_MARR_TAKEOFF_1, which AS3 sets to 0.
*&   ON_CHANGE still clears the dependents on every trigger change; only the
*&   EDITABLE / READONLY / REQUIRE toggles are declarative.
*&  MESSAGE TEXTS — the required-field messages are the ENGINE's, not this
*&   class's and not the WD's: ZCL_RAK_TEXT msgno 013 ('&1 is required' /
*&   '&1 مطلوب') and 051 ('&1: attachment is required' / '&1: المرفق مطلوب'),
*&   with &1 replaced by the field's ZLABEL or ZLABEL_AR, overridable per
*&   journey through ZRAK_T_CJ_TXT. This class sets no MSG on any field.
*&   The date / witness / duplicate-party errors below ARE the WD's, resolved
*&   from its own OTR aliases. The divorcee message is the one text written
*&   here, as a literal by sy-langu: the WD had no message for it, and
*&   GET_OTR_TEXT_FOR_ALIAS returns BLANK on no_entry_found, which would block
*&   the step with an empty strip.
*&   KNOWN GAP: the grid-column message is built inline in MISSING_REQUIRED as
*&   |<column> is required on every row of <grid>| with no Arabic twin, so
*&   those three columns report in English even on an Arabic journey. Engine
*&   side, not fixable from here.
*&  CONFIRMATIONS (defaults in place):
*&   - step codes MARR/DIVO/HIST/PRTY/DOCS (ZRAK_T_JNY_STEP.STEP_ID); no PAY step.
*&   - DOCUMENT_TYPE filter iv_attach='AD01' — fixed value, no mapping.
*&   - PERS_INFO grid read/write via io_ctx get_grid_data/set_grid_data (wired).
*&   - on_submit header/header_ext mapping matches SUBMIT_DEV_MARRIAGE_TAKEOF
*&     (MOVE-CORRESPONDING set + the fixed values) — confirmed against the WD.
*&   - ATTACH_TYPES: AVI,BMP,DOC,DOCX,DWG,JPEG,JPG,MP4,PDF,PNG,PPT,RAR,TIF,TIFF,
*&     XLS,XLSX,ZIP (confirmed allowed set).
*&  ATTACHMENT VALIDATION (implemented in on_attach):
*&   - The engine does the size check + storage before firing on_attach, so the
*&     logic does the allowed-extension check only. The staged file is read via
*&     io_ctx->get_attachment_files( ) filtered on IDENTIFIER1 = iv_field (the
*&     upload field name); extension via TRINT_FILE_GET_EXTENSION checked against
*&     the master list ZFM_EGA_GET_FILE_EXT_WD_UPLOAD (error ZMSG_EGA_CM 111).
*&  GRID + ATTACHMENTS (implemented via the engine accessors):
*&   - PERS_INFO is a fixed 2-row EDITABLE_TABLE; seeded in on_init via
*&     set_grid_data (V2 = 1 Divorcer / 2 Divorcee), read in on_submit +
*&     on_custom_validate. The WD's own grid completeness checks are dead code
*&     (unconditional RETURN in CHECK_PERS_INFO, confirmed at runtime: a blank
*&     Submit reports no grid error), so they are not ported as code — the
*&     intent is carried by REQUIRED on the ZRAK_T_JNY_COL rows instead, which
*&     MISSING_REQUIRED does enforce against every existing row.
*&     The WD's UI-only row flags READ_ONLY / READ_ONLY1 are not columns here.
*&   - attachment submission posts each staged file (io_ctx->get_attachment_files)
*&     via ZFM_WDA_CREATE_AI_ATTACHMENT_U in on_submit.
*&   - on_submit fires on the SUBMIT action; on_save is draft-only (not used).
*&     No double-post risk: with no backend and no bridge the engine's own
*&     post path is not taken, so this class is the only writer.
*&  DEFERRED / ENHANCE (need input):
*&   - update_dummy_witnesses ported via customizing FM ZREAD_WITT( service ):
*&     dummies fire only when SKIP_WITNESS = 'X'. AS3 is WITH_WITNESS = 'X'
*&     (skip blank), so it does not fire.
*&
*& HONEST STATUS: fully ported and grounded in the WD source + engine
*& accessors, with the mandatory fields now on and cross-checked against the
*& live WD's blank-Submit error list. Nothing in this class has been compiled
*& or run by its author — activation and a live pass are the reader's.
*&---------------------------------------------------------------------*
*& ON_INIT — journey open: seed SERVICE_TYPE, header/help, texts, card
*& Folds: e_get_help_url, get_header_title, get_new_header_title,
*&        init_dropdowns, parse_portal_username, populate_card_data,
*&        populate_texts.  (dropdown POPULATION itself is dropped — the
*&        engine binds on_value_help options; init_dropdowns collapses to
*&        nothing here.)
*&---------------------------------------------------------------------*

    io_ctx->set_val( iv_name = 'SERVICE_TYPE' iv_value = c_default_service ).

    "   Origin: COMPONENTCONTROLLER->PARSE_PORTAL_USERNAME + HANDLEFROM_WINDOW_MAIN
    " it as the public attribute MV_LOGINBP, so the WD's internet-user chain
    DATA lv_loginbp TYPE bu_partner.
    lv_loginbp = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.

    "   Origin: HANDLEFROM_WINDOW_MAIN / POPULATE_CARD_DATA — seed the card.
    " The WD raised no error for a missing login BP, so none is raised here.
    IF lv_loginbp IS NOT INITIAL.
      DATA ls_bpdata TYPE zmoi_bp_str.
      CALL FUNCTION 'ZBP_GET_DATA'
        EXPORTING
          iv_partner = lv_loginbp
        IMPORTING
          ev_bp_data = ls_bpdata.

      DATA(lv_bpname) = COND string(
            WHEN ls_bpdata-zengname IS NOT INITIAL THEN |{ ls_bpdata-zengname }|
            ELSE condense( |{ ls_bpdata-zfname } { ls_bpdata-zfaname } { ls_bpdata-zgfname } { ls_bpdata-z4thname } { ls_bpdata-zlname }| ) ).

      io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'APP_NAME' iv_value = lv_bpname ).
      io_ctx->set_val( iv_name = 'APP_ID'   iv_value = |{ ls_bpdata-zeid }| ).

      " The applicant of this service IS the divorcer, so pre-fill that party
      " from the logged-in BP (the WD screen shows the divorcer already filled
      io_ctx->set_val( iv_name = 'DIVORCER_PARTNER' iv_value = |{ lv_loginbp }| ).
      io_ctx->set_val( iv_name = 'DIVORCER_NAME'    iv_value = lv_bpname ).
    ENDIF.

    "   Origin: VIEW_MAIN->SET_DEF_VALUES — service-INDEPENDENT constant
    " rather than re-deriving on each service selection as the WD did.
    io_ctx->set_val( iv_name = 'CONTRACT_PLACE'          " Contract Place
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_RAK' ) ).
    io_ctx->set_val( iv_name = 'COURT'         " Court
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_COURT_RAK' ) ).
    io_ctx->set_val( iv_name = 'EMIRATE'          " Emirate
    iv_value = get_otr_text_by_alias( 'Z_RAKEGA_MUNI/ZEGA_SRC_V_MAIN_EMIRATE_RAK' ) ).
    " NOTE: the WD set the Contract Place on four section structures
    " (marriage_certif / div_marr_takeoff / attestation_srv / marriage_cont);

    "   Origin: VIEW_MAIN->E_GET_HELP_URL — help link is service-type driven;
    " compute it for the seeded SERVICE_TYPE (and again in on_change).
    refresh_help_url( io_ctx ).

    "   Origin: VIEW_MAIN->GET_NEW_HEADER_TITLE — the WD read the page header
    " from the application's OTR alias. That text is now ZRAK_T_JNY.TITLE, so
    " there is nothing to set here: HEADER_TITLE was never a field on the
    " journey and SET_VAL against a name that is not in ZRAK_T_JNY_FLD is legal
    " and does nothing.

    "   Origin: (fill_dropdown_all row-build) — PERS_INFO is a fixed 2-row
    " EDITABLE_TABLE. The WD seeds the two rows with the partner-function CODE
    DATA(ls_seed) = io_ctx->get_grid_data( 'PERS_INFO' ).   " columns; rows empty at load
    IF ls_seed-rows IS INITIAL.
      DATA(lv_v2_i) = line_index( ls_seed-columns[ table_line = 'ZZAFLD0000V2' ] ).
      DATA(lv_txt_i) = line_index( ls_seed-columns[ table_line = 'PARTY_TYPE_TXT' ] ).
      DATA lt_r1 TYPE zif_rak_journey=>tt_string.
      DATA lt_r2 TYPE zif_rak_journey=>tt_string.
      DATA lv_ncols TYPE i.
      DATA lv_t_divorcer TYPE string.
      DATA lv_t_divorcee TYPE string.
      CLEAR: lt_r1, lt_r2.
      lv_ncols = lines( ls_seed-columns ).
      DO lv_ncols TIMES.
        APPEND `` TO lt_r1.
        APPEND `` TO lt_r2.
      ENDDO.
      " exactly two rows, fixed: row 1 = Divorcer, row 2 = Divorcee. V2 carries
      " the partner-function CODE, exactly as the WD sends it. The visible
      " "Partner type" column is PARTY_TYPE_TXT, which is NOT a component of
      " ZST_EGA_COURT_SERVICE_STR_TAB1, so the ON_SUBMIT column loop skips it
      " and it never reaches the backend - the same trick the <COL>_EN gates
      " use. It exists because the engine cannot render the WD's read-only
      " dropdown: a readonly SELECT cell shows the stored KEY, not the option
      " text (one cell template serves every row, so there is nowhere to
      " resolve a key per row), and the engine's own guidance is to store the
      " label beside the key. ZZAFLD0000V0 is left untouched and hidden, which
      " is what the WD does with it (set_visible( visibility_none ), never
      " written) - it used to carry this label and was posting a value the
      " legacy screen never sent.
      IF lv_v2_i > 0.
        lt_r1[ lv_v2_i ] = '1'.   " Divorcer
        lt_r2[ lv_v2_i ] = '2'.   " Divorcee
      ENDIF.
      IF sy-langu = 'A'.
        lv_t_divorcer = 'المطلق'.
        lv_t_divorcee = 'المطلقة'.
      ELSE.
        lv_t_divorcer = 'Divorcer'.
        lv_t_divorcee = 'Divorcee'.
      ENDIF.
      IF lv_txt_i > 0.
        lt_r1[ lv_txt_i ] = lv_t_divorcer.
        lt_r2[ lv_txt_i ] = lv_t_divorcee.
      ENDIF.
      APPEND lt_r1 TO ls_seed-rows.
      APPEND lt_r2 TO ls_seed-rows.
      io_ctx->set_grid_data( iv_field = 'PERS_INFO' is_data = ls_seed ).
    ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT.
*&---------------------------------------------------------------------*
*& ON_POPUP_EVENT — the Add-BP / partner search is owned by the reusable
*& ZCL_RAK_BP_POPUP (render + MOI lookup + write-back of <SUBJECT>_PARTNER /
*& <SUBJECT>_NAME). This handler only routes:
*&  (a) the popup's own events (BPP_*) to the popup instance for the active
*&      subject, and
*&  (b) the four Add-BP open events, each setting BP_ACTIVE_SUBJECT and opening
*&      the BP_<SUBJECT> popup.
*& Everything else (the payment PAYNOW/PAYPOLL/… flow) is delegated to the
*& superclass. Subjects: DIVORCEE, DIVORCER, WITNESS1, WITNESS2.
*&---------------------------------------------------------------------*

    IF iv_event CP 'BPP_*' AND io_ctx->get_val( 'BP_ACTIVE_SUBJECT' ) IS NOT INITIAL.
      bp_handle( io_ctx     = io_ctx
      iv_event   = iv_event
      iv_subject = io_ctx->get_val( 'BP_ACTIVE_SUBJECT' ) ).
      RETURN.
    ENDIF.

    CASE iv_event.
      WHEN c_evt_bp_divorcee.
        io_ctx->set_val( iv_name = 'BP_ACTIVE_SUBJECT' iv_value = 'DIVORCEE' ).
        io_ctx->open_popup( 'BP_DIVORCEE' ).
      WHEN c_evt_bp_witness1.
        io_ctx->set_val( iv_name = 'BP_ACTIVE_SUBJECT' iv_value = 'WITNESS1' ).
        io_ctx->open_popup( 'BP_WITNESS1' ).
      WHEN c_evt_bp_witness2.
        io_ctx->set_val( iv_name = 'BP_ACTIVE_SUBJECT' iv_value = 'WITNESS2' ).
        io_ctx->open_popup( 'BP_WITNESS2' ).
      WHEN OTHERS.
        super->zif_rak_journey_logic~on_popup_event(
        io_ctx = io_ctx iv_id = iv_id iv_event = iv_event ).
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_AFTER_FIELD.
*&---------------------------------------------------------------------*
*& ON_RENDER_AFTER_FIELD — the Add-BP button for each party, rendered
*& INLINE at the end of that party's row (same layout as the WD screen,
*& where "Add BP" sits directly beside the party field).
*& Buttons are NOT field configuration: they are drawn here and wired to an
*& event with io_ctx->event( ). io_view is this field's own cell, so the
*& button attaches to that row only. The caption flips Add -> Change by
*& reading the popup's write-back field <SUBJECT>_PARTNER.
*&---------------------------------------------------------------------*
    DATA lv_txt TYPE string.
    CASE to_upper( is_field-name ).
      WHEN 'PERS_INFO'.
        " Heading for the parties block that follows the grid. Drawn here, not as
        " ZSECTION: that column has no _AR twin (unlike ZLABEL_AR / MSG_AR), so a
        " configured section header is stuck in one language. The grid above needs
        " no heading of its own — its ZLABEL/ZLABEL_AR already prints one.
        IF sy-langu = 'A'.
          lv_txt = 'بيانات الاطراف'.
        ELSE.
          lv_txt = 'Parties involved'.
        ENDIF.
        io_view->title( text = lv_txt class = 'rakBlkTitle sapUiSmallMarginTop' ).

      WHEN 'DIVORCEE_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'DIVORCEE_PARTNER' )
        iv_role_en = 'divorcee' iv_role_ar = 'المطلقة' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_divorcee ) ).
      WHEN 'DIVORCER_NAME'.
        " No Add/Change button for the divorcer: that party IS the applicant and
        " nothing to search for. Only the fee-payer marker is drawn, exactly as
        IF sy-langu = 'A'.
          lv_txt = 'دافع الرسوم'.
        ELSE.
          lv_txt = 'Fee payer'.
        ENDIF.
        io_view->text( text = lv_txt class = 'sapUiSmallMarginBegin' ).
      WHEN 'WITNESS1_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'WITNESS1_PARTNER' )
        iv_role_en = 'witness 1' iv_role_ar = 'الشاهد الأول' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_witness1 ) ).
      WHEN 'WITNESS2_NAME'.
        io_view->button(
        text  = bp_button_text( iv_partner = io_ctx->get_val( 'WITNESS2_PARTNER' )
        iv_role_en = 'witness 2' iv_role_ar = 'الشاهد الثاني' )
        icon  = 'sap-icon://search'
        type  = 'Emphasized'
        press = io_ctx->event( c_evt_bp_witness2 ) ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_POPUP.
*&---------------------------------------------------------------------*
*& ON_RENDER_POPUP — draw the BP_<SUBJECT> partner-search dialog. The subject
*& is the id after 'BP_'. Non-BP popups fall through to the superclass.
*&---------------------------------------------------------------------*
    IF iv_id CP 'BP_*'.
      bp_render( io_ctx     = io_ctx
      io_popup   = io_popup
      iv_subject = substring_after( val = iv_id sub = 'BP_' ) ).
      RETURN.
    ENDIF.
    super->zif_rak_journey_logic~on_render_popup(
    io_ctx = io_ctx io_popup = io_popup iv_id = iv_id ).
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_SUBMIT.
*&---------------------------------------------------------------------*
*& ON_SUBMIT( io_ctx ) RETURNING rt — final backend creation for AS3.
*& The engine calls on_submit on the SUBMIT action (handle_submit); on_save
*& is the draft handler and is NOT where a case is created. Since this
*& journey creates its own case (no QNV bridge), on_submit is the engine's
*& designated moment to do it and to call io_ctx->set_reference( ) with the
*& real request number so the confirmation screen shows it. Returning an
*& 'Error' row in rt blocks the submit and keeps the citizen on the page.
*& Origin: VIEW_MAIN->ONACTIONSUBMIT_CASE (AS2/AS3 branch) ->
*&         SUBMIT_DEV_MARRIAGE_TAKEOF -> RFC_REQUEST_SUBMIT
*&         (ZFM_ECC_WDA_CREATE_REQUEST) + GET_PARTNER_FUNCTIONS.
*&---------------------------------------------------------------------*
    DATA ls_header      TYPE zst_ega_court_service_header.
    DATA ls_header_ext  TYPE zst_ega_court_service_head_div.
    DATA lt_item_ext1   TYPE zst_ega_court_service_tab1.
    DATA ls_partners    TYPE zst_ega_court_service_partners.
    DATA lt_bapireturn  TYPE bapiret2_t.
    DATA(lv_applicant)  = CAST zcl_rak_journey_engine( io_ctx )->mv_loginbp.

    "   Origin: VIEW_MAIN->UPDATE_DUMMY_WITNESSES (+ READ_WITNESS_HANDLE_DATA).
    " Whether witnesses are skipped for a service is customizing, read per
    DATA lv_skip_witness TYPE c LENGTH 1.   " CHAR1
    DATA lv_with_witness TYPE c LENGTH 1.   " CHAR1
    CALL FUNCTION 'ZREAD_WITT'
      EXPORTING
        iv_service   = CONV char40( c_default_service )   " AS3
      IMPORTING
        skip_witness = lv_skip_witness
        with_witness = lv_with_witness.
    IF lv_skip_witness = abap_true.
      io_ctx->set_val( iv_name = 'WITNESS1_PARTNER' iv_value = 'DUMMY_WIT1' ).
      io_ctx->set_val( iv_name = 'WITNESS2_PARTNER' iv_value = 'DUMMY_WIT2' ).
    ENDIF.

    ls_partners-divorcee_bp = io_ctx->get_val( 'DIVORCEE_PARTNER' ).
    ls_partners-divorcer_bp = io_ctx->get_val( 'DIVORCER_PARTNER' ).
    ls_partners-witness1_bp = io_ctx->get_val( 'WITNESS1_PARTNER' ).
    ls_partners-witness2_bp = io_ctx->get_val( 'WITNESS2_PARTNER' ).

    " payer: for AS3 the fee is always paid by the DIVORCER — the WD's payer
    " radio sits on the divorcer row and is not a choice for this service, so
    ls_partners-payer_ft = '00000004'.
    ls_partners-payer_bp = ls_partners-divorcer_bp.

    set_partner_functions( CHANGING cs_partners = ls_partners ).

    ls_header-process_type = 'YSR2'.
    ls_header-product      = c_default_service.
    ls_header-ordered_prod = c_default_service.
    ls_header-status       = 'E0003'.
    ls_header-quantity     = '1'.
    ls_header-zzafld0000ax = 'X'.
    ls_header-zzafld0000ay = lv_applicant.
    ls_header-zzafld0000dr = 'X'.

    " main-header divorce type (8O) are other-service fields — not populated for
    " AS3 (AS3's divorce type is UQ on header_ext).
    ls_header-text_z11     = io_ctx->get_val( 'REQUEST_TEXT' ).
    ls_header-zzafld00004d = io_ctx->get_val( 'CONTRACT_PLACE' ). " Contract Place
    ls_header-zzafld00008k = conv_date_internal( io_ctx->get_val( 'MARR_CONTRACT_DATE' ) ). " Marriage contract date (ISO -> YYYYMMDD)
    ls_header-zzafld00008l = io_ctx->get_val( 'MARR_CONTRACT_PLACE' ). " Marriage contract place
    ls_header-zzafld00008m = io_ctx->get_val( 'CHILDREN_COUNT' ). " No. of children
    ls_header-zzafld00008n = conv_date_internal( io_ctx->get_val( 'MARR_PROVING_DATE' ) ). " Marriage proving date (ISO -> YYYYMMDD)

    " ---- header extension: divorce takeoff-form fields --------------
    ls_header_ext-zzafld0000u4 = io_ctx->get_val( 'COURT' ).
    ls_header_ext-zzafld0000ug = io_ctx->get_val( 'EMIRATE' ).
    ls_header_ext-zzafld0000u3 = io_ctx->get_val( 'MARR_CONTRACT_NO' ).
    ls_header_ext-zzafld0000un = io_ctx->get_val( 'FAM_GUIDANCE_APPR' ).
    ls_header_ext-zzafld0000uo = io_ctx->get_val( 'MARR_GRANT_RECEIVED' ).
    ls_header_ext-zzafld0000uh = io_ctx->get_val( 'GRANT_SIDE' ).
    ls_header_ext-zzafld0000up = io_ctx->get_val( 'DIV_DECL_TYPE' ).
    ls_header_ext-zzafld0000uq = io_ctx->get_val( 'DIV_TYPE' ).
    " Origin: SUBMIT_DEV_MARRIAGE_TAKEOF — a divorce-type of '00' is the
    " "unset" placeholder; blank it before the backend call.
    IF ls_header_ext-zzafld0000uq = '00'.
      CLEAR ls_header_ext-zzafld0000uq.
    ENDIF.
    ls_header_ext-zzafld0000ur = io_ctx->get_val( 'DIV_APPLICANT' ).
    ls_header_ext-zzafld0000us = io_ctx->get_val( 'DIV_METHOD' ).
    ls_header_ext-zzafld0000ui = io_ctx->get_val( 'DIV_WORDS' ).
    ls_header_ext-zzafld0000uj = io_ctx->get_val( 'DIV_PLACE' ).
    ls_header_ext-zzafld0000ut = io_ctx->get_val( 'DIV_REASON' ).
    ls_header_ext-zzafld0000uk = io_ctx->get_val( 'DIV_REASON_DETAILS' ).
    ls_header_ext-zzafld0000u6 = io_ctx->get_val( 'RELATIVE_RELATION' ).
    ls_header_ext-zzafld0000uu = io_ctx->get_val( 'STATUS_UPON_MARR' ).
    ls_header_ext-zzafld0000uv = io_ctx->get_val( 'CASE_UPON_DIVORCE' ).
    ls_header_ext-zzafld0000uw = io_ctx->get_val( 'MARR_CONSUMMATED' ).
    ls_header_ext-zzafld0000ux = io_ctx->get_val( 'ISOLATION' ).
    ls_header_ext-zzafld0000v3 = io_ctx->get_val( 'WIVES_COUNT_HUSBAND' ). " NUMC
    ls_header_ext-zzafld0000um = io_ctx->get_val( 'PREV_DIVORCES_COUNT' ). " NUMC
    ls_header_ext-zzafld0000uy = io_ctx->get_val( 'EARLIER_MARRIAGES' ).
    ls_header_ext-zzafld0000ub = conv_date_internal( io_ctx->get_val( 'DIV_KHULA_DATE' ) ).
    ls_header_ext-zzafld0000uc = conv_date_internal( io_ctx->get_val( 'LAST_MARR_DATE' ) ).
    ls_header_ext-zzafld0000ud = conv_date_internal( io_ctx->get_val( 'LAST_MARR_CTR_DT' ) ).
    ls_header_ext-zzafld0000ue = conv_date_internal( io_ctx->get_val( 'FIRST_MARR_CTR_DT' ) ).
    ls_header_ext-zzafld0000uf = conv_date_internal( io_ctx->get_val( 'LAST_DIV_DATE' ) ).
    ls_header_ext-zzafld0000ul = io_ctx->get_val( 'CHILDREN_UNDER_21' ).

    " PERS_INFO is a fixed 2-row grid (row 1 Divorcer, row 2 Divorcee). Read
    DATA(ls_grid) = io_ctx->get_grid_data( 'PERS_INFO' ).
    DATA lt_cells   TYPE zif_rak_journey=>tt_string.
    DATA ls_item    TYPE zst_ega_court_service_str_tab1.
    DATA lv_colname TYPE string.
    DATA lv_ci      TYPE i.
    DATA lv_cellval TYPE string.
    DATA lv_row     TYPE i.
    FIELD-SYMBOLS <comp> TYPE any.
    LOOP AT ls_grid-rows INTO lt_cells.
      CLEAR ls_item.
      lv_row = sy-tabix.
      LOOP AT ls_grid-columns INTO lv_colname.
        lv_ci = sy-tabix.
        ASSIGN COMPONENT lv_colname OF STRUCTURE ls_item TO <comp>.
        IF sy-subrc = 0.
          READ TABLE lt_cells INDEX lv_ci INTO lv_cellval.
          IF sy-subrc = 0.
            <comp> = lv_cellval.   " string -> component type (NUMC TU converts)
          ENDIF.
        ENDIF.
      ENDLOOP.
      " Screen column 11 "Partner" (UZ) is the BP of this row's party. It is a
      " read-only display the citizen never fills, so stamp it here from the
      " fixed row order: row 1 = Divorcer, row 2 = Divorcee.
      ls_item-zzafld0000uz = COND #( WHEN lv_row = 1 THEN ls_partners-divorcer_bp
      ELSE ls_partners-divorcee_bp ).
      APPEND ls_item TO lt_item_ext1.
    ENDLOOP.

    CALL FUNCTION 'ZFM_ECC_WDA_CREATE_REQUEST'
      EXPORTING
        partners     = ls_partners
        header       = ls_header
        header_ext   = ls_header_ext
        item_ext1    = lt_item_ext1
      TABLES
        t_bapireturn = lt_bapireturn.

    " any 'Error' row and keeps the citizen on the page).
    LOOP AT lt_bapireturn INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      APPEND VALUE #( type = 'Error' text = |{ ls_ret-message }| ) TO rt.
    ENDLOOP.
    IF line_exists( rt[ type = 'Error' ] ).
      RETURN.
    ENDIF.

    " On success the new service id is returned in the 'S' row's MESSAGE_V1;
    " MESSAGE_V2 is the service GUID passed to ZFM_WDA_CREATE_AI_ATTACHMENT_U.
    READ TABLE lt_bapireturn INTO DATA(ls_ok) WITH KEY type = 'S'.
    IF sy-subrc = 0.
      DATA(lv_service_id) = ls_ok-message_v1.   " AS3 request number
      DATA(lv_guid)       = ls_ok-message_v2.    " GUID of the service — used for attachments
      " The engine owns the success screen and reads the number from here. There
      " is no confirmation STEP and no field for it, so set_reference( ) is the
      " only publication.
      io_ctx->set_reference( |{ lv_service_id }| ).

      " Origin: RFC_ATTACHEMNT_SUBMIT — attach the staged files to the new
      " Field map QNV (/QNV/SBUILD_ATTACHMENTS_ST) -> WD ls_attachments -> FM:
      DATA(lt_att) = io_ctx->get_attachment_files( ).
      DATA ls_att      TYPE /qnv/sbuild_attachments_st.
      DATA lv_mime     TYPE w3conttype.
      DATA lv_att_ext  TYPE c LENGTH 40.
      DATA lv_xcontent TYPE xstring.
      LOOP AT lt_att INTO ls_att.
        lv_mime = ls_att-file_mime.
        IF lv_mime IS INITIAL AND ls_att-file_name IS NOT INITIAL.
          CLEAR lv_att_ext.
          CALL FUNCTION 'TRINT_FILE_GET_EXTENSION'
            EXPORTING
              filename  = ls_att-file_name
              uppercase = 'X'
            IMPORTING
              extension = lv_att_ext.
          CALL FUNCTION 'SDOK_MIMETYPE_GET'
            EXPORTING
              extension = lv_att_ext
            IMPORTING
              mimetype  = lv_mime.
        ENDIF.

        " FILE_CONTENT arrives as a base64 data URL ('data:<mime>;base64,<payload>'),
        " and the FM wants raw XSTRING: drop the prefix before the comma, then
        " base64-decode the payload.
        CLEAR lv_xcontent.
        TRY.
            SPLIT ls_att-file_content AT ',' INTO DATA(lv_prefix) DATA(lv_payload).
            CALL FUNCTION 'SCMS_BASE64_DECODE_STR'
              EXPORTING
                input  = lv_payload
              IMPORTING
                output = lv_xcontent.
          CATCH cx_bcs INTO DATA(lx_bcs).
            APPEND VALUE #( type = 'Error'
            text = |{ ls_att-file_name }: { lx_bcs->get_text( ) }| ) TO rt.
            CONTINUE.
        ENDTRY.

        CALL FUNCTION 'ZFM_WDA_CREATE_AI_ATTACHMENT_U'
          EXPORTING
            guid         = CONV scmg_case_guid( lv_guid )
            filename     = CONV string( ls_att-identifier1 )
            file_descr   = CONV string( ls_att-file_name )
            filecontent  = lv_xcontent
            filemimetype = CONV string( lv_mime )
            langu        = sy-langu
            sap_object   = 'BUS2000116'.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP.
*&---------------------------------------------------------------------*
*& ON_VALUE_HELP — domain-backed dropdowns (open-q#5: options_from_domain)
*& Folds fill_dropdown_service / _wife_status / _divorce_type / _doc_type
*& and the bundled fill_dropdown_all. One WHEN per SELECT field; the DDIC
*& domain + meaning is kept as an inline comment.
*&---------------------------------------------------------------------*

    CASE iv_field.
      WHEN 'FAM_GUIDANCE_APPR'.
        rt = options_from_domain( 'ZADTEL0001TL' ).              " Family guidance approval
      WHEN 'MARR_GRANT_RECEIVED'.
        rt = options_from_domain( 'ZADTEL0001TM' ).              " Marriage grant
      WHEN 'DIV_DECL_TYPE'.
        rt = options_from_domain( 'ZADTEL0001TN' ).              " Type of divorce declaration
      WHEN 'DIV_TYPE'.
        rt = options_from_domain( 'ZADTEL0001TO' ).              " Type of divorce
      WHEN 'DIV_APPLICANT'.
        rt = options_from_domain( 'ZADTEL0001TP' ).              " Divorce applicant
      WHEN 'DIV_METHOD'.
        rt = options_from_domain( 'ZADTEL0001TQ' ).              " Method of divorce
      WHEN 'DIV_REASON'.
        rt = options_from_domain( 'ZADTEL0001TR' ).              " Divorce reason
      WHEN 'RELATIVE_RELATION'.
        rt = options_from_domain( 'ZADTEL0001T4' ).              " Relative relation
      WHEN 'STATUS_UPON_MARR'.
        rt = options_from_domain( 'ZADTEL0001TS' ).              " Status of divorced upon marriage
      WHEN 'CASE_UPON_DIVORCE'.
        rt = options_from_domain( 'ZADTEL0001TT' ).              " Divorced case upon divorce
      WHEN 'MARR_CONSUMMATED'.
        rt = options_from_domain( 'ZADTEL0001TU' ).              " Marriage consummated
      WHEN 'ISOLATION'.
        rt = options_from_domain( 'ZADTEL0001TV' ).              " Isolation
      WHEN 'EARLIER_MARRIAGES'.
        rt = options_from_domain( 'ZADTEL0001TW' ).              " Earlier marriages

      WHEN 'DOCUMENT_TYPE'.
        "   Origin: VIEW_ADD_ATTACHMENT->FILL_DROPDOWN_DOC_TYPE
        " through FM ZFM_ECC_WDA_ATT_DDLB_VALUE (open-q#3). The WD also hid
        DATA lt_attach TYPE zatt_docu_type_1.
        CALL FUNCTION 'ZFM_ECC_WDA_ATT_DDLB_VALUE'
          EXPORTING
            iv_attach        = c_att_key     " AD01 — fixed value, no per-service mapping
            iv_langu         = sy-langu
          TABLES
            et_document_type = lt_attach.
        LOOP AT lt_attach INTO DATA(ls_attach).
          APPEND VALUE #( key = ls_attach-id text = ls_attach-descrption ) TO rt.
        ENDLOOP.

        " the grid column spec carries the domain in its 'src' the engine
      WHEN 'PERS_INFO.ZZAFLD0000TT'.
        rt = options_from_domain( 'ZADTEL0001S2' ).              " Residence status
      WHEN 'PERS_INFO.ZZAFLD0000TV'.
        rt = options_from_domain( 'ZADTEL0001S4' ).              " Doctrine
      WHEN 'PERS_INFO.ZZAFLD0000TW'.
        rt = options_from_domain( 'ZADTEL0001S5' ).              " Job status
      WHEN 'PERS_INFO.ZZAFLD0000TX'.
        rt = options_from_domain( 'ZADTEL0001S6' ).              " Main profession
      WHEN 'PERS_INFO.ZZAFLD0000TZ'.
        rt = options_from_domain( 'ZADTEL0001S8' ).              " Employer Emirate

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
