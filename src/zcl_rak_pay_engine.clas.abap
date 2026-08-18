CLASS zcl_rak_pay_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

*---------------------------------------------------------------------------------------*
* Program Title     : CJS Payment Engine (config-driven, framework-agnostic)
* Created By        : Vikram Kumar Pitchaimani
* Object Description: Reusable payment capability for ZCL_RAK_JOURNEY_ENGINE.
*                     Rendered by the engine as the RAKPAY / RAKREMAININGFEES /
*                     RAKSTAGEBAR control types. Carries no /QNV/ dependency.
*                     Logic ported verbatim from ZCL_EGA_CJ_FW_PG_ABS_V1 (fees,
*                     gateway routing, 15-min lock, method persistence) and from
*                     paymentset_get_entityset (status poll). Flags kept AS IS.
*---------------------------------------------------------------------------------------*

  PUBLIC SECTION.

    "! Terminal / non-terminal poll outcomes. The RAKPAY control revolves while
    "! the poll returns C_OPEN and stops on C_SUCCESS / C_FAILED.
    CONSTANTS:
      c_success TYPE string VALUE 'SUCCESS',
      c_open    TYPE string VALUE 'OPEN',
      c_failed  TYPE string VALUE 'FAILED'.

    "! A single fee row for the fee CLIST (description + amount).
    TYPES:
      BEGIN OF ty_fee,
        desc   TYPE text100,
        amount TYPE kbetr,
      END OF ty_fee,
      tt_fee TYPE STANDARD TABLE OF ty_fee WITH DEFAULT KEY.

    "! A field-level instruction the engine applies to its rendered config,
    "! so the routing decision stays declarative (flags as is).
    TYPES:
      BEGIN OF ty_field_op,
        fieldname TYPE char40,
        action    TYPE char10,   " HIDE_VIS / SET_VAL / CLR_VAL / SET_LABEL
        value     TYPE string,
      END OF ty_field_op,
      tt_field_op TYPE STANDARD TABLE OF ty_field_op WITH DEFAULT KEY.

    "! Selected method flags persisted to zega_t_cj_payupd.
    TYPES:
      BEGIN OF ty_method,
        creditcard TYPE char1,
        edirham    TYPE char1,
        kiosk      TYPE char1,
        mrak       TYPE char1,
        quick      TYPE char1,
        walkin     TYPE char1,
        donate     TYPE char1,
      END OF ty_method.

    "! Payment gateway payload (NOT_UI config fields assembled by the engine).
    TYPES:
      BEGIN OF ty_paydtl,
        email            TYPE string,
        userid           TYPE string,
        amount           TYPE string,
        serviceid        TYPE string,
        referenceid      TYPE string,
        merchantid       TYPE string,
        lang             TYPE string,
        eservicecode     TYPE string,
        terminalid       TYPE string,
        secretkey        TYPE string,
        redirecturl      TYPE string,
        applicationurl   TYPE string,
        paytype          TYPE string,
        servicesessionid TYPE string,
        paychannel       TYPE string,
        servicelist      TYPE string,
      END OF ty_paydtl.

    "! Generic name/value pairs the engine passes for the screen's NOT_UI fields.
    TYPES:
      BEGIN OF ty_nv,
        technicalname TYPE char40,
        value         TYPE string,
      END OF ty_nv,
      tt_nv TYPE STANDARD TABLE OF ty_nv WITH DEFAULT KEY.

    "! @parameter iv_caseid | External case key (SCMG ext_key). Optional at launch.
    "! @parameter iv_intreno | Journey intreno as used by the poll (may contain 'PP').
    "! @parameter iv_bp | Owner / login business partner.
    "! @parameter iv_bukrs | Company code of the department raising the fee (DOK = 'RDOK').
    "! @parameter iv_material | Fee material in ZDT_EDIRHAM_SERV (DOK = 'DOK APPL_FEE').
    "! @parameter iv_cases_for | ZETISLAT_TRANSAC case family (DOK = 'ZK').
    METHODS constructor
      IMPORTING
        !iv_caseid    TYPE scmg_ext_key OPTIONAL
        !iv_intreno   TYPE string       OPTIONAL
        !iv_bp        TYPE bu_partner   OPTIONAL
        !iv_bukrs     TYPE bukrs        OPTIONAL
        !iv_material  TYPE zdt_edirham_serv-material OPTIONAL
        !iv_cases_for TYPE zetislat_transac-cases_for OPTIONAL .

    "! Poll the gateway. Returns C_SUCCESS / C_OPEN / C_FAILED using the exact
    "! logic implemented in paymentset_get_entityset. Called on every timer tick;
    "! the control keeps revolving while C_OPEN is returned.
    METHODS poll_status
      IMPORTING
        !iv_intreno      TYPE string OPTIONAL
*       The caller's evidence that a gateway was genuinely launched for THIS
*       attempt - PAY_APPURL filled and OPEN_URL fired. Read ONLY by the dev
*       short circuit below. On any system other than the dev box it is
*       ignored entirely, so a caller that always passes abap_true changes
*       nothing in E20 / E30.
        !iv_launched     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_status) TYPE string .

    "! Dev-only auto-success switch. TRUE only on the dev box, and the system
    "! check is ABAP, evaluated FIRST - no TVARVC row, no transport and no
    "! configuration change can turn this on anywhere else. The TVARVC entry
    "! exists only so a developer can turn it OFF on dev to exercise the real
    "! gateway path.
    CLASS-METHODS dev_autopay
      RETURNING VALUE(rv) TYPE abap_bool .

    "! Build the fee list + total for the current case (dfkkop / vbap / makt).
    METHODS get_fees
      EXPORTING
        !et_fee   TYPE tt_fee
        !ev_total TYPE kbetr .

    "! Decide gateway (ATB vs standard) from zdt_pg_dep_map and department gating.
    "! Returns declarative field ops for the engine to apply. Flags kept AS IS.
    METHODS route_gateway
      RETURNING
        VALUE(rt_ops) TYPE tt_field_op .

    "! Wait for the open item and billing document the case-create BAdI raises,
    "! draw the payment reference, write the ZETISLAT_TRANSAC row POLL_STATUS later
    "! reads, and return the gateway payload as declarative field ops.
    "! EV_READY is the only thing the caller tests before launching the gateway.
    METHODS prepare_gateway
      IMPORTING
        !iv_etisalat  TYPE abap_bool DEFAULT abap_false
        !iv_userid    TYPE string OPTIONAL
        !iv_email     TYPE string OPTIONAL
      EXPORTING
        !es_paydtl    TYPE ty_paydtl
        !et_messages  TYPE bapiret2_t
        !ev_ready     TYPE abap_bool
      RETURNING
        VALUE(rt_ops) TYPE tt_field_op .

    "! 15-minute lock check. Populates messages 023/024/025 and raises rv_stop.
    METHODS check_lock
      EXPORTING
        !et_messages   TYPE bapiret2_t
      RETURNING
        VALUE(rv_stop) TYPE abap_bool .

    "! Initialise the payment logger row (mirrors read() PAY_1_0 behaviour).
    METHODS init_logger .

    "! Persist the selected method + donate flag to zega_t_cj_payupd.
    METHODS persist_method
      IMPORTING
        !is_method TYPE ty_method .

    "! Assemble the gateway payload from the screen's NOT_UI name/value config.
    METHODS build_payload
      IMPORTING
        !it_nv           TYPE tt_nv
      RETURNING
        VALUE(rs_paydtl) TYPE ty_paydtl .

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS c_autopay_tvarv TYPE string  VALUE 'ZRAK_CJ_PAY_AUTOSUCCESS'.
    CONSTANTS c_dev_sysid     TYPE sy-sysid VALUE 'E10'.

    CONSTANTS c_wait_ticks   TYPE i      VALUE 300.
    CONSTANTS c_wait_max_sec TYPE i      VALUE 60.
    CONSTANTS c_gw_etisalat  TYPE string VALUE 'ETISALAT'.
    CONSTANTS c_gw_edirham   TYPE string VALUE 'EDIRHAM'.
    CONSTANTS c_user_erp     TYPE string VALUE 'PORTAL1'.
    CONSTANTS c_source_sys   TYPE string VALUE '01'.

*   The one DFKKOP open item the gateway bills against.
    TYPES: BEGIN OF ty_open,
             invoice_number TYPE dfkkop-opbel,
             xblnr          TYPE dfkkop-xblnr,
             due_amount     TYPE dfkkop-betrh,
             waers          TYPE dfkkop-waers,
           END OF ty_open.

    DATA mv_caseid    TYPE scmg_ext_key .
    DATA mv_intreno   TYPE string .
    DATA mv_bp        TYPE bu_partner .
    DATA mv_bukrs     TYPE bukrs .
    DATA mv_material  TYPE zdt_edirham_serv-material .
    DATA mv_cases_for TYPE zetislat_transac-cases_for .

    "! Poll DFKKOP until the BAdI's open item is readable. abap_false on timeout.
    METHODS wait_for_open_item
      EXPORTING
        !es_open     TYPE ty_open
      RETURNING
        VALUE(rv_ok) TYPE abap_bool .

    "! Poll VBFA until the billing document exists. Initial on timeout.
    METHODS wait_for_invoice
      IMPORTING
        !iv_xblnr       TYPE dfkkop-xblnr
      RETURNING
        VALUE(rv_vbeln) TYPE vbeln .

    "! Resolve the case_key / payment_id used by the poll. Returns abap_false
    "! when the case cannot be resolved (caller returns C_FAILED). Faithful port
    "! of the resolution block in paymentset_get_entityset.
    METHODS resolve_case
      IMPORTING
        !iv_intreno       TYPE string
      EXPORTING
        !ev_case_key      TYPE scmg_ext_key
        !ev_payment_id    TYPE vbeln
        !ev_by_payment_id TYPE abap_bool
      RETURNING
        VALUE(rv_ok)      TYPE abap_bool .

ENDCLASS.



CLASS ZCL_RAK_PAY_ENGINE IMPLEMENTATION.


  METHOD build_payload.
*---------------------------------------------------------------------------------------*
* Assemble the gateway payload from the screen's NOT_UI name/value config.
* Enrichment (get_cpg_details) remains an engine handler hook.
*---------------------------------------------------------------------------------------*
    rs_paydtl-email            = VALUE #( it_nv[ technicalname = 'EMAIL' ]-value OPTIONAL ).
    rs_paydtl-userid           = VALUE #( it_nv[ technicalname = 'USERID' ]-value OPTIONAL ).
    rs_paydtl-amount           = VALUE #( it_nv[ technicalname = 'AMOUNT' ]-value OPTIONAL ).
    rs_paydtl-serviceid        = VALUE #( it_nv[ technicalname = 'SERVICEID' ]-value OPTIONAL ).
    rs_paydtl-referenceid      = VALUE #( it_nv[ technicalname = 'REFERENCEID' ]-value OPTIONAL ).
    rs_paydtl-merchantid       = VALUE #( it_nv[ technicalname = 'MERCHANTID' ]-value OPTIONAL ).
    rs_paydtl-lang             = VALUE #( it_nv[ technicalname = 'LANG' ]-value OPTIONAL ).
    rs_paydtl-eservicecode     = VALUE #( it_nv[ technicalname = 'ESERVICECODE' ]-value OPTIONAL ).
    rs_paydtl-terminalid       = VALUE #( it_nv[ technicalname = 'TERMINALID' ]-value OPTIONAL ).
    rs_paydtl-secretkey        = VALUE #( it_nv[ technicalname = 'SECRETKEY' ]-value OPTIONAL ).
    rs_paydtl-redirecturl      = VALUE #( it_nv[ technicalname = 'REDIRECTURL' ]-value OPTIONAL ).
    rs_paydtl-applicationurl   = VALUE #( it_nv[ technicalname = 'APPLICATIONURL' ]-value OPTIONAL ).
    rs_paydtl-paytype          = VALUE #( it_nv[ technicalname = 'PAYTYPE' ]-value OPTIONAL ).
    rs_paydtl-servicesessionid = VALUE #( it_nv[ technicalname = 'SERVICESESSIONID' ]-value OPTIONAL ).
    rs_paydtl-paychannel       = VALUE #( it_nv[ technicalname = 'PAYCHANNEL' ]-value OPTIONAL ).
    rs_paydtl-servicelist      = VALUE #( it_nv[ technicalname = 'SERVICELIST' ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD check_lock.
*---------------------------------------------------------------------------------------*
* Port of the 15-min payment-waiting check in update(). Resolves opbel, reads
* zetislat_transac, calls ZFM_PAY_CHECK_LOCK, raises messages 023/024/025.
*---------------------------------------------------------------------------------------*
    DATA: caseid   TYPE scmg_ext_key,
          opbel    TYPE opbel_kk,
          lt_open  TYPE zdt_ega_bp_open_tt,
          lt_trans TYPE ztt_pay_req,
          lt_lock  TYPE ztt_pay_req,
          ls_trans LIKE LINE OF lt_trans.

    CLEAR: et_messages, rv_stop.

    caseid = |{ mv_caseid ALPHA = IN }|.

    CALL FUNCTION 'ZFM_BP_WSRV_MBME_MUN'
      EXPORTING
        iv_zzext_key                 = caseid
      IMPORTING
        gt_dfkkop                    = lt_open
      EXCEPTIONS
        data_not_found               = 1
        error_passed_to_mess_handler = 2
        OTHERS                       = 3.

    opbel = VALUE #( lt_open[ case_id = caseid ]-invoice_number OPTIONAL ).
    opbel = |{ opbel ALPHA = IN }|.

    IF opbel IS INITIAL.
      IF zcl_ega_epda_appln_handler_api=>cj_epda_valid_casetype( iv_case_id = caseid ) = abap_true.
        zcl_ega_epda_appln_handler_api=>cj_epda_payment_list(
          EXPORTING
            iv_case_id   = caseid
          IMPORTING
            et_open_item = lt_open ).
      ELSE.
        DATA(lo_dok_handler) = NEW zcl_dok_appln_handler_api( ).
        IF lo_dok_handler->cj_dok_valid_casetype( iv_case_id = caseid ) = abap_true.
          lo_dok_handler->cj_dok_payment_list(
            EXPORTING
              iv_case_id   = caseid
            IMPORTING
              et_open_item = lt_open ).
        ENDIF.
      ENDIF.

      IF lt_open IS NOT INITIAL.
        opbel = VALUE #( lt_open[ case_id = caseid ]-invoice_number OPTIONAL ).
        IF opbel IS NOT INITIAL.
          opbel = |{ opbel ALPHA = IN }|.
        ENDIF.
      ENDIF.
    ENDIF.

    SELECT payment_id, opbel, date_init, time_init FROM zetislat_transac
      INTO TABLE @DATA(val_trans)
      WHERE opbel EQ @opbel AND ext_key EQ @caseid.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SORT val_trans BY date_init DESCENDING time_init DESCENDING.
    DELETE ADJACENT DUPLICATES FROM val_trans COMPARING payment_id opbel.

    LOOP AT val_trans ASSIGNING FIELD-SYMBOL(<val_trans>).
      CLEAR: lt_trans, ls_trans.
      ls_trans-payment_id = <val_trans>-payment_id.
      ls_trans-opbel      = <val_trans>-opbel.
      APPEND ls_trans TO lt_trans.
    ENDLOOP.

    CALL FUNCTION 'ZFM_PAY_CHECK_LOCK'
      EXPORTING
        it_pay_req  = lt_trans
        iv_gateway  = 'SAP'
      IMPORTING
        et_pay_lock = lt_lock.

    LOOP AT lt_lock INTO ls_trans.
      DATA(lv_num) = COND msgno(
        WHEN ls_trans-status EQ 'P' THEN '024'
        WHEN ls_trans-status EQ 'F' THEN '025'
        ELSE '023' ).

*     MESSAGE has to be filled here, not left to the caller.
*
*     BAPIRET2 carries the message TWICE - once resolvable as ID / NUMBER /
*     MESSAGE_V1..4, and once rendered as MESSAGE - and only the second is any
*     use to a UI. This filled the first three and left MESSAGE blank, so a
*     caller that renders ls-message, which is the obvious thing to do, drew an
*     empty red strip: the payment was blocked, the citizen was told nothing,
*     and the trace showed a clean gate because nothing had actually gone wrong.
*
*     It is the same trap RAISE_MESSAGE works around in ZCL_EGA_CJ_DOK_ABS, where
*     BALW_BAPIRETURN_GET2 is called over every row for exactly this reason.
*     Cheaper to not create the problem: MESSAGE ... INTO resolves the class,
*     the language and the &1 &2 substitution in one statement.
      DATA lv_lock_text TYPE string.
      CLEAR lv_lock_text.
      MESSAGE ID 'ZMSG_PAYMENTS' TYPE 'E' NUMBER lv_num
        WITH ls_trans-payment_id ls_trans-user_portal INTO lv_lock_text.

      et_messages = VALUE #( BASE et_messages
        ( type = 'E' id = 'ZMSG_PAYMENTS' number = lv_num
          message_v1 = ls_trans-payment_id message_v2 = ls_trans-user_portal
          message    = lv_lock_text ) ).
    ENDLOOP.

    IF line_exists( et_messages[ type = 'E' ] ).
      rv_stop = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD constructor.
    mv_caseid    = iv_caseid.
    mv_intreno   = iv_intreno.
    mv_bp        = iv_bp.
    mv_bukrs     = iv_bukrs.
    mv_material  = iv_material.
    mv_cases_for = iv_cases_for.
  ENDMETHOD.


  METHOD dev_autopay.
*---------------------------------------------------------------------------------------*
* The only gate that matters is the first one, and it is ABAP rather than
* configuration on purpose. A green tick over a payment that did not happen is the
* single most expensive thing this class can do, so the ability to produce one must
* not be reachable from a table anybody can maintain.
*---------------------------------------------------------------------------------------*
    IF sy-sysid <> c_dev_sysid.
      RETURN.
    ENDIF.

*   Default ON. An explicit OFF switches it off; anything else, including no row at
*   all, leaves it on - so a fresh dev client walks the journey end to end without a
*   Basis request, and a developer who needs the real gateway path can take it back
*   without a transport.
    SELECT SINGLE low FROM tvarvc INTO @DATA(lv_low)
      WHERE name = @c_autopay_tvarv AND type = 'P'.
    IF sy-subrc = 0 AND to_upper( condense( lv_low ) ) = 'OFF'.
      RETURN.
    ENDIF.

    rv = abap_true.
  ENDMETHOD.


  METHOD get_fees.
*---------------------------------------------------------------------------------------*
* Port of get_fees + the read() fee block. dfkkop open items joined to vbap/makt.
*---------------------------------------------------------------------------------------*
    TYPES: BEGIN OF ty_fees_int,
             casedesc TYPE text100,
             kbetr    TYPE kbetr,
           END OF ty_fees_int.

    DATA: fees     TYPE STANDARD TABLE OF ty_fees_int,
          ext_key  TYPE scmg_ext_key,
          lt_vbeln TYPE RANGE OF vbeln_va.

    CLEAR: et_fee, ev_total.

    ext_key = |{ mv_caseid ALPHA = IN }|.
    IF ext_key IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE case_guid INTO @DATA(guid) FROM scmg_t_case_attr WHERE ext_key EQ @ext_key.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT betrh, xblnr, zzext_key INTO TABLE @DATA(lt_fees)
      FROM dfkkop WHERE augst NE '9' AND zzext_key EQ @ext_key AND betrh > 0.

    lt_vbeln = VALUE #( FOR wa IN lt_fees ( sign = 'I' option = 'EQ' low = wa-xblnr+6(10) ) ).

    SELECT a~arktx, a~netwr, a~ext_key, a~vbeln, a~matnr, b~maktx
      FROM vbap AS a INNER JOIN makt AS b ON a~matnr EQ b~matnr
      INTO TABLE @DATA(lt_desc)
      WHERE a~vbeln IN @lt_vbeln AND b~spras EQ @sy-langu.

    LOOP AT lt_fees ASSIGNING FIELD-SYMBOL(<fs_fees>).
      fees = VALUE #( BASE fees
        ( casedesc = VALUE #( lt_desc[ ext_key = <fs_fees>-zzext_key
                                       vbeln   = <fs_fees>-xblnr+6(10)
                                       netwr   = <fs_fees>-betrh ]-maktx OPTIONAL )
          kbetr    = <fs_fees>-betrh ) ).
    ENDLOOP.

    LOOP AT fees ASSIGNING FIELD-SYMBOL(<ls_fee>).
      DATA(desc) = COND text100(
        WHEN <ls_fee>-casedesc IS INITIAL AND sy-langu EQ 'E' THEN 'B&E Deposit Fees'
        WHEN <ls_fee>-casedesc IS INITIAL AND sy-langu NE 'E' THEN 'التأمينات'
        ELSE <ls_fee>-casedesc ).
      et_fee = VALUE #( BASE et_fee ( desc = desc amount = <ls_fee>-kbetr ) ).
      ev_total = ev_total + <ls_fee>-kbetr.
    ENDLOOP.
  ENDMETHOD.


  METHOD init_logger.
*---------------------------------------------------------------------------------------*
* Mirrors the payment-logger MODIFY in read() for PAY_1_0 / MPAY_1_0 / NPAY_1_0.
*---------------------------------------------------------------------------------------*
    DATA: paylog TYPE zega_t_cj_payupd.

    paylog-caseid = |{ mv_caseid ALPHA = IN }|.
    paylog-bp     = |{ mv_bp ALPHA = IN }|.

    IF paylog-caseid IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY zega_t_cj_payupd FROM paylog.
  ENDMETHOD.


  METHOD persist_method.
*---------------------------------------------------------------------------------------*
* Port of the method-persistence block in update(). Writes selected channel + donate.
*---------------------------------------------------------------------------------------*
    DATA: caseid TYPE scmg_ext_key.

    caseid = |{ mv_caseid ALPHA = IN }|.
    IF caseid IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zega_t_cj_payupd INTO @DATA(paydtl) WHERE caseid EQ @caseid.
    IF sy-subrc <> 0.
      paydtl-caseid = caseid.
      paydtl-bp     = |{ mv_bp ALPHA = IN }|.
    ENDIF.

    paydtl-creditcard = is_method-creditcard.
    paydtl-edirham    = is_method-edirham.
    paydtl-kiosk      = is_method-kiosk.
    paydtl-mrak       = is_method-mrak.
    paydtl-quick      = is_method-quick.
    paydtl-walkin     = is_method-walkin.
    paydtl-donate     = is_method-donate.

    MODIFY zega_t_cj_payupd FROM paydtl.
  ENDMETHOD.


  METHOD poll_status.
*---------------------------------------------------------------------------------------*
* Exact port of paymentset_get_entityset. SUCCESS / OPEN / FAILED only.
* No timeout: the control revolves on OPEN until a terminal status is returned.
*---------------------------------------------------------------------------------------*
    DATA: lv_intreno    TYPE string,
          lv_case_key   TYPE scmg_ext_key,
          lv_payment_id TYPE vbeln,
          lv_by_pp      TYPE abap_bool,
          lt_trans      TYPE STANDARD TABLE OF zetislat_transac.

    lv_intreno = COND #( WHEN iv_intreno IS NOT INITIAL THEN iv_intreno ELSE mv_intreno ).

*   DEV SHORT CIRCUIT. A dev box has no reachable gateway, so the journey cannot be
*   walked end to end without one, and the previous version of this was dangerous in
*   the other direction: it returned SUCCESS on E10 before anything else ran, so the
*   screen said 'Payment received' for a payment that had never been attempted.
*
*   The rule is unchanged - it may speak only when a payment was genuinely started -
*   but the EVIDENCE has moved, for two reasons.
*
*   It is now IV_LAUNCHED, supplied by the caller, and that is strictly stronger than
*   what was tested before. PAY_APPURL is only ever filled by PREPARE_PAYMENT( ) from
*   a real APPLICATIONURL returned by the payment screen's read BAdI, which means the
*   case existed, the open item existed, the department was routed to a gateway and
*   OPEN_URL( ) fired. The one thing that did not happen is the citizen paying -
*   which is exactly what a dev box cannot do and precisely what is being stood in
*   for. With PAY_APPURL blank, IV_LAUNCHED is false and this does not fire.
*
*   And it now sits ABOVE the RESOLVE_CASE( ) guard rather than below it. The old
*   placement could not be reached at all: RESOLVE_CASE( ) is handed the CASE id,
*   which matches neither VIBDCHARACT-INTRENO nor GET_CASES( ), so the only branch
*   that can resolve is the SCMG_T_CASE_ATTR fallback - and that branch was throwing
*   its own result away (fixed below). The dev path was dead for the same reason the
*   real poll was.
    IF iv_launched = abap_true AND dev_autopay( ) = abap_true.
      rv_status = c_success.
      RETURN.
    ENDIF.

    IF resolve_case(
         EXPORTING iv_intreno       = lv_intreno
         IMPORTING ev_case_key      = lv_case_key
                   ev_payment_id    = lv_payment_id
                   ev_by_payment_id = lv_by_pp ) = abap_false.
*     NOT a failure. The poll starts firing about two seconds after the gateway
*     opens, while the citizen is still on the checkout page, so everything below
*     that means "no answer yet" has to read as OPEN. Reporting FAILED here told a
*     citizen mid-payment that their payment had not completed - the worst possible
*     moment to say it, and untrue.
      rv_status = c_open.
      RETURN.
    ENDIF.

    IF lv_by_pp = abap_true.
      SELECT * FROM zetislat_transac INTO TABLE @lt_trans
        WHERE payment_id EQ @lv_payment_id AND status <> 'C'.
    ELSE.
      SELECT * FROM zetislat_transac INTO TABLE @lt_trans
        WHERE ext_key EQ @lv_case_key AND status <> 'C'.
    ENDIF.

*   No transaction row yet. Written by the read BAdI when it prepared the gateway,
*   and the poll can outrun it. OPEN, not failed.
    IF sy-subrc <> 0.
      rv_status = c_open.
      RETURN.
    ENDIF.

    SORT lt_trans BY date_init DESCENDING time_init DESCENDING.
    READ TABLE lt_trans INTO DATA(transaction) INDEX 1.
    IF sy-subrc <> 0.
      rv_status = c_open.
      RETURN.
    ENDIF.

*   The ONLY thing that now reports failure: a transaction the gateway itself marked
*   cancelled. Everything else is either success or still in flight, so 'Payment was
*   not completed' means exactly that and nothing else.
    IF transaction-status EQ 'C'.
      rv_status = c_failed.
      RETURN.
    ENDIF.

    IF transaction-gateway = 'ATB'.
      DATA(lv_checkout_id) = transaction-checkoutid.
      CALL METHOD zcl_ega_payment_utility=>call_atb_details
        EXPORTING
          iv_ref_id          = CONV zde_ega_pay_transaction_id( transaction-transaction_id )
          iv_checkoutid      = CONV #( lv_checkout_id )
        IMPORTING
          ev_urn             = DATA(urn)
          ev_pay_succ        = DATA(lv_paysucc)
          ev_order_status    = DATA(orderstatus)
          ev_amount          = DATA(lv_amount)
          ev_checkoutstatus  = DATA(lv_checkoutstatus)
          ev_disp_status_msg = DATA(lv_dispstatusmsg)
          ev_settlementdate  = DATA(settlementdate).

      rv_status = COND #( WHEN lv_dispstatusmsg EQ 'Success' THEN c_success ELSE c_open ).
      RETURN.
    ENDIF.

    DATA: i_serviceid       TYPE string,
          i_referencenumber TYPE string,
          bankapprovalcode  TYPE string,
          transactionid     TYPE string,
          amount            TYPE string,
          finalizedamount   TYPE string,
          paymentsuccess    TYPE string,
          result            TYPE zdt_ega_gw_payment_response.

    i_serviceid       = transaction-service_id.
    i_referencenumber = transaction-transaction_id.

    CALL FUNCTION 'ZREAD_PAY_STATUS_DEST'
      EXPORTING
        i_serviceid       = i_serviceid
        i_referencenumber = i_referencenumber
      IMPORTING
        bankapprovalcode  = bankapprovalcode
        transactionid     = transactionid
        amount            = amount
        finalizedamount   = finalizedamount
        paymentsuccess    = paymentsuccess
        result            = result.

    rv_status = COND #( WHEN result-status EQ '0000' THEN c_success ELSE c_open ).
  ENDMETHOD.


  METHOD prepare_gateway.
*---------------------------------------------------------------------------------------*
* Port of GET_CPG_DETAILS_OLD in ZCL_EGA_CJ_DOK_ABS.
*
* Order is load-bearing and matches legacy exactly: wait for the FI-CA open item,
* wait for the billing document, read merchant config, draw the reference from the
* number range, write ZETISLAT_TRANSAC, then assemble the payload. The gateway bills
* from DFKKOP-BETRH, not from the fee list the card displays.
*
* The ZETISLAT_TRANSAC row is what POLL_STATUS later reads. Without it the poll
* resolves no transaction and returns C_FAILED, so this method and the poll are one
* mechanism, not two.
*
* Every failure path returns a message. Legacy failed silently on CHECK, which is why
* a dead Pay button and a missing open item looked identical from the screen.
*---------------------------------------------------------------------------------------*
    DATA lv_case      TYPE scmg_ext_key.
    DATA lv_gateway   TYPE zetislat_transac-gateway.
    DATA ls_trans     TYPE zetislat_transac.
    DATA lv_sessionid TYPE thfb_session_id.
    DATA lv_object    TYPE nrobj.
    DATA lv_nr_range  TYPE nrnr.
    DATA lv_refid     TYPE nrlevel.
    DATA lv_partner   TYPE char10.
    DATA lv_puser     TYPE char50.
    DATA lv_email     TYPE string.
    DATA lv_vbelv     TYPE vbeln_von.
    DATA ls_open      TYPE ty_open.

    CLEAR: es_paydtl, et_messages, ev_ready, rt_ops.

    lv_case = |{ mv_caseid ALPHA = IN }|.

    IF lv_case IS INITIAL.
      APPEND VALUE #( type = 'E'
        message = 'Payment cannot start: no case id on this journey.' ) TO et_messages.
      RETURN.
    ENDIF.

    IF mv_bukrs IS INITIAL OR mv_material IS INITIAL.
      APPEND VALUE #( type = 'E'
        message = 'Payment cannot start: company code / fee material were not supplied to the payment engine.' ) TO et_messages.
      RETURN.
    ENDIF.

    lv_gateway = COND #( WHEN iv_etisalat = abap_true THEN c_gw_etisalat ELSE c_gw_edirham ).

    IF wait_for_open_item( IMPORTING es_open = ls_open ) = abap_false.
      APPEND VALUE #( type = 'E'
        message = |No open item was raised for case { lv_case } within { c_wait_max_sec } seconds. | &&
                  |The gateway was not opened.| ) TO et_messages.
      RETURN.
    ENDIF.

*   The billing document is WANTED, not REQUIRED, and this is faithful to
*   GET_CPG_DETAILS_OLD: its invoice loop has no CHECK after it and falls straight
*   through when nothing is found. INVOICE feeds one field, ZETISLAT_TRANSAC-
*   PAYMENT_ID, and appears nowhere in the CPG payload - so a missing billing
*   document costs a blank reference on the transaction row and nothing else.
*
*   Blocking on it was wrong and it showed: on a dev box where the billing job does
*   not run, a case with a perfectly good open item could never reach the gateway.
*   Reported as a Warning so it is visible rather than silent, and so the blank
*   PAYMENT_ID is explained if anyone goes looking for it later.
    DATA(lv_invoice) = wait_for_invoice( ls_open-xblnr ).
    IF lv_invoice IS INITIAL.
      APPEND VALUE #( type = 'W'
        message = |No billing document was found for the open item on case { lv_case } | &&
                  |within { c_wait_max_sec } seconds. Payment continues; the transaction | &&
                  |row carries no payment id.| ) TO et_messages.
    ENDIF.

    SELECT SINGLE * FROM zdt_edirham_serv INTO @DATA(ls_serv)
      WHERE bukrs    EQ @mv_bukrs
        AND material EQ @mv_material.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E'
        message = |No ZDT_EDIRHAM_SERV entry for company code { mv_bukrs } and material { mv_material }.| ) TO et_messages.
      RETURN.
    ENDIF.

    SELECT SINGLE * FROM zdt_merch_rakpay INTO @DATA(ls_merch)
      WHERE bukrs   EQ @mv_bukrs
        AND gateway EQ @lv_gateway.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E'
        message = |No ZDT_MERCH_RAKPAY entry for company code { mv_bukrs } and gateway { lv_gateway }.| ) TO et_messages.
      RETURN.
    ENDIF.

    lv_partner = |{ mv_bp ALPHA = IN }|.
    IF lv_partner IS NOT INITIAL.
      CALL FUNCTION 'ZGET_INT_USER_FROM_BP'
        EXPORTING
          iv_partner = lv_partner
        IMPORTING
          ev_user    = lv_puser.
    ENDIF.

    IF iv_email IS NOT INITIAL.
      lv_email = iv_email.
    ELSEIF lv_puser IS NOT INITIAL.
      CALL FUNCTION 'ZFM_WS_PORTAL_USER_FIND_UNAME'
        EXPORTING
          iv_username   = CONV string( lv_puser )
        IMPORTING
          ev_user_email = lv_email.
    ENDIF.

    CALL METHOD zcl_ega_payment_utility=>get_nr_object_init_payment
      IMPORTING
        ev_object   = lv_object
        ev_nr_range = lv_nr_range.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = lv_nr_range
        object                  = lv_object
      IMPORTING
        number                  = lv_refid
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        quantity_is_not_1       = 5
        interval_overflow       = 6
        buffer_overflow         = 7
        OTHERS                  = 8.
    IF sy-subrc <> 0 OR lv_refid IS INITIAL.
      APPEND VALUE #( type = 'E'
        message = |Could not draw a payment reference from number range { lv_object } / { lv_nr_range }.| ) TO et_messages.
      RETURN.
    ENDIF.
    CONDENSE lv_refid NO-GAPS.

    CALL FUNCTION 'TH_GET_SESSION_ID'
      IMPORTING
        session_id = lv_sessionid.

    es_paydtl-referenceid      = lv_refid.
    es_paydtl-userid           = COND #( WHEN iv_userid IS NOT INITIAL THEN iv_userid ELSE lv_puser ).
    es_paydtl-email            = lv_email.
    es_paydtl-amount           = ls_open-due_amount.
    CONDENSE es_paydtl-amount NO-GAPS.
    es_paydtl-serviceid        = ls_serv-service_id.
    es_paydtl-merchantid       = ls_merch-merchant_id.
    es_paydtl-terminalid       = ls_merch-terminal_id.
    es_paydtl-secretkey        = ls_merch-secret_key.
    es_paydtl-eservicecode     = |{ ls_serv-serv_code_main }-{ ls_serv-serv_code_sub }|.
    es_paydtl-lang             = COND #( WHEN sy-langu EQ 'E' THEN 'en' ELSE 'ar' ).
    es_paydtl-paytype          = '2'.
    es_paydtl-servicesessionid = lv_sessionid.

    es_paydtl-paychannel = COND #(
      WHEN sy-sysid EQ 'E30' AND iv_etisalat EQ abap_true THEN 'https://www.rak.ae/etcpg/cpg/reg/'
      WHEN sy-sysid EQ 'E30'                              THEN 'https://www.rak.ae/cpgconnector/cpg/1'
      WHEN iv_etisalat EQ abap_true                       THEN 'https://stg.rak.ae/etcpg/cpg/reg/'
      ELSE 'https://stg.rak.ae/cpgconnector/cpg/1' ).

    es_paydtl-redirecturl = COND #(
      WHEN sy-sysid EQ 'E30' THEN
        'https://grpportal.rak.ae/sap/bc/webdynpro/sap/zwda_ega_euser_payments?sap-language=EN?referenceId=' && lv_refid
      WHEN sy-sysid EQ 'E10' THEN
        'https://devgrpportal.rak.ae/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS?sap-language=EN?referenceId=' && lv_refid
      ELSE
        'https://devgrpportal.rak.ae:444/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS?sap-language=EN?referenceId=' && lv_refid ).

    es_paydtl-servicelist = |eserviceid={ ls_serv-serv_code_main }-{ ls_serv-serv_code_sub },| &&
                            |quantity=1,price={ es_paydtl-amount };|.
    CONDENSE es_paydtl-servicelist NO-GAPS.

    CALL FUNCTION 'IB_CONVERT_INTO_TIMESTAMP'
      EXPORTING
        i_datlo     = sy-datum
        i_timlo     = sy-uzeit
        i_tzone     = 'UTC'
      IMPORTING
        e_timestamp = ls_trans-date_initialized.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
      EXPORTING
        input  = ls_open-xblnr
      IMPORTING
        output = lv_vbelv.

    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_vbelv
      IMPORTING
        output = lv_vbelv.

    SELECT SINGLE case_type FROM scmg_t_case_attr INTO @ls_trans-case_type
      WHERE ext_key EQ @lv_case.

    ls_trans-transaction_id         = lv_refid.
    ls_trans-amount                 = ls_open-due_amount.
    ls_trans-currency               = ls_open-waers.
    ls_trans-payment_id             = lv_invoice.
    ls_trans-opbel                  = ls_open-invoice_number.
    ls_trans-transaction_desc_short = lv_vbelv.
    ls_trans-transaction_desc_long  = ls_open-invoice_number.
    ls_trans-status                 = 'I'.
    ls_trans-user_erp               = c_user_erp.
    ls_trans-user_portal            = lv_puser.
    ls_trans-ext_key                = lv_case.
    ls_trans-gateway                = lv_gateway.
    ls_trans-date_init              = sy-datum.
    ls_trans-time_init              = sy-uzeit.
    ls_trans-service_id             = es_paydtl-serviceid.
    ls_trans-source_system          = c_source_sys.
    ls_trans-cases_for              = mv_cases_for.

    INSERT zetislat_transac FROM ls_trans.
    IF sy-subrc <> 0.
      APPEND VALUE #( type = 'E'
        message = |Could not write the payment transaction row for reference { lv_refid }. | &&
                  |The gateway was not opened.| ) TO et_messages.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.

    rt_ops = VALUE #(
      ( fieldname = 'AMOUNT'           action = 'SET_VAL' value = es_paydtl-amount )
      ( fieldname = 'USERID'           action = 'SET_VAL' value = es_paydtl-userid )
      ( fieldname = 'EMAIL'            action = 'SET_VAL' value = es_paydtl-email )
      ( fieldname = 'SERVICEID'        action = 'SET_VAL' value = es_paydtl-serviceid )
      ( fieldname = 'REFERENCEID'      action = 'SET_VAL' value = es_paydtl-referenceid )
      ( fieldname = 'MERCHANTID'       action = 'SET_VAL' value = es_paydtl-merchantid )
      ( fieldname = 'LANG'             action = 'SET_VAL' value = es_paydtl-lang )
      ( fieldname = 'ESERVICECODE'     action = 'SET_VAL' value = es_paydtl-eservicecode )
      ( fieldname = 'TERMINALID'       action = 'SET_VAL' value = es_paydtl-terminalid )
      ( fieldname = 'SECRETKEY'        action = 'SET_VAL' value = es_paydtl-secretkey )
      ( fieldname = 'REDIRECTURL'      action = 'SET_VAL' value = es_paydtl-redirecturl )
      ( fieldname = 'PAYTYPE'          action = 'SET_VAL' value = es_paydtl-paytype )
      ( fieldname = 'SERVICESESSIONID' action = 'SET_VAL' value = es_paydtl-servicesessionid )
      ( fieldname = 'PAYCHANNEL'       action = 'SET_VAL' value = es_paydtl-paychannel )
      ( fieldname = 'SERVICELIST'      action = 'SET_VAL' value = es_paydtl-servicelist )
      ( fieldname = 'INTRENO_JOURNEY'  action = 'SET_VAL' value = CONV string( lv_case ) ) ).

    ev_ready = abap_true.
  ENDMETHOD.


  METHOD resolve_case.
*---------------------------------------------------------------------------------------*
* Faithful port of the case-resolution block in paymentset_get_entityset,
* including the 'PP' split path and the vibdcharact CJ12 -> get_cases -> attr chain.
*---------------------------------------------------------------------------------------*
    DATA: lv_pp_position TYPE i,
          lv_before      TYPE string.

    CLEAR: ev_case_key, ev_payment_id, ev_by_payment_id.
    rv_ok = abap_true.

    lv_pp_position = find( val = iv_intreno sub = 'PP' ).

    IF lv_pp_position < 1.
      SELECT SINGLE supplementinfo INTO @DATA(caseid)
        FROM vibdcharact WHERE intreno EQ @iv_intreno AND fixfitcharact EQ 'CJ12'.

      IF sy-subrc <> 0 OR caseid IS INITIAL.
        DATA(cases) = zcl_cj_gen_utils=>get_cases( intreno = CONV #( iv_intreno ) ).
        IF cases[] IS NOT INITIAL.
          caseid = VALUE #( cases[ 1 ]-fieldname OPTIONAL ).
        ELSE.
*         The one branch a CJS journey can actually reach, and it used to throw its
*         own result away. KEY was selected and never assigned to CASEID, and the
*         guard below it - sy-subrc <> 0 AND key IS NOT INITIAL - can never be true,
*         because a failed SELECT SINGLE leaves KEY initial.
*
*         IV_INTRENO here is the CASE id; PAY_ENGINE( ) passes it deliberately. A
*         case id matches neither VIBDCHARACT-INTRENO nor GET_CASES( ), so both
*         branches above miss and this is the only one left. EV_CASE_KEY therefore
*         came back blank on every CJS payment, RV_OK came back false, and
*         POLL_STATUS answered C_OPEN for the life of the session - the payment could
*         never confirm on any system.
          DATA(case_key) = CONV scmg_ext_key( |{ iv_intreno ALPHA = IN }| ).
          SELECT SINGLE ext_key INTO @DATA(key) FROM scmg_t_case_attr WHERE ext_key EQ @case_key.
*         EV_CASE_KEY directly rather than via CASEID: CASEID is typed from
*         VIBDCHARACT-SUPPLEMENTINFO and KEY is an SCMG_EXT_KEY, and routing one
*         through the other is a truncation waiting to happen. The block below
*         only fills EV_CASE_KEY from CASEID when CASEID is filled, so setting the
*         target itself is both shorter and safer.
          IF sy-subrc = 0 AND key IS NOT INITIAL.
            ev_case_key = key.
          ELSE.
            rv_ok = abap_false.
            RETURN.
          ENDIF.
        ENDIF.
      ENDIF.

      IF caseid IS NOT INITIAL.
        ev_case_key = CONV #( caseid ).
      ENDIF.

      IF ev_case_key IS INITIAL.
        rv_ok = abap_false.
        RETURN.
      ENDIF.
    ELSE.
      SPLIT iv_intreno AT 'PP' INTO lv_before ev_payment_id.
      ev_by_payment_id = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD route_gateway.
*---------------------------------------------------------------------------------------*
* Port of the department radio-button + gateway routing in read(). Flags AS IS.
* Emits declarative ops so the engine mutates its own rendered config.
*---------------------------------------------------------------------------------------*
    DATA: lv_fieldname     TYPE char40,
          lv_fieldname2    TYPE char40,
          lv_selected_rb   TYPE char40,
          lv_unselected_rb TYPE char40,
          lv_atb_enabled   TYPE abap_bool,
          lv_caseid        TYPE scmg_ext_key.

    lv_caseid = |{ mv_caseid ALPHA = IN }|.

    " EPDA / DOK: hide the offline channels (MRAK / KIOSK / WALKIN).
    DATA(epdaflag) = zcl_ega_epda_appln_handler_api=>cj_epda_valid_casetype( iv_case_id = lv_caseid ).
    DATA(dokflag)  = NEW zcl_dok_appln_handler_api( )->cj_dok_valid_casetype( iv_case_id = lv_caseid ).

    IF epdaflag EQ 'X' OR dokflag EQ 'X'.
      rt_ops = VALUE #( BASE rt_ops
        ( fieldname = 'MRAK'   action = 'HIDE_VIS' )
        ( fieldname = 'KIOSK'  action = 'HIDE_VIS' )
        ( fieldname = 'WALKIN' action = 'HIDE_VIS' ) ).
    ENDIF.

    SELECT SINGLE bukrs INTO @DATA(lv_comp)
      FROM dfkkop WHERE augst <> '9' AND zzext_key = @lv_caseid.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    SELECT SINGLE gateway INTO @DATA(lv_gateway)
      FROM zdt_pg_dep_map WHERE bukrs = @lv_comp.

    IF sy-subrc = 0 AND lv_gateway = 'ATB'.
      lv_fieldname     = 'PW_HBOX1'.
      lv_selected_rb   = 'PW_RB2'.
      lv_unselected_rb = 'PW_RB1'.
      lv_atb_enabled   = abap_true.
    ELSE.
      lv_fieldname     = 'PW_HBOX2'.
      lv_fieldname2    = 'FEE_STRUCT_VBOX'.
      lv_selected_rb   = 'PW_RB1'.
      lv_unselected_rb = 'PW_RB2'.
      lv_atb_enabled   = abap_false.
    ENDIF.

    rt_ops = VALUE #( BASE rt_ops
      ( fieldname = lv_fieldname     action = 'HIDE_VIS' )
      ( fieldname = lv_fieldname     action = 'CLR_VAL'  )
      ( fieldname = lv_selected_rb   action = 'SET_VAL'   value = 'X' )
      ( fieldname = lv_unselected_rb action = 'CLR_VAL'  ) ).

    IF lv_fieldname2 IS NOT INITIAL.
      rt_ops = VALUE #( BASE rt_ops ( fieldname = lv_fieldname2 action = 'HIDE_VIS' ) ).
    ENDIF.

    rt_ops = VALUE #( BASE rt_ops
      ( fieldname = 'ATB_FLAG' action = 'CLR_VAL' )
      ( fieldname = 'ATB_FLAG' action = 'SET_LABEL'
        value = COND #( WHEN lv_atb_enabled = abap_true THEN 'ENABLED' ELSE 'DISABLED' ) ) ).
  ENDMETHOD.


  METHOD wait_for_invoice.
*---------------------------------------------------------------------------------------*
* The billing document follows the sales order asynchronously, so it needs its own
* wait. Timing verbatim from GET_CPG_DETAILS_OLD. VBTYP_N 'M' is the invoice.
*---------------------------------------------------------------------------------------*
    DATA lv_vbeln_va TYPE vbeln_va.

    CLEAR rv_vbeln.
    lv_vbeln_va = |{ iv_xblnr ALPHA = IN }|.

    DO c_wait_ticks TIMES.
      SELECT SINGLE vbeln FROM vbfa
        INTO @rv_vbeln
        WHERE vbelv   EQ @lv_vbeln_va
          AND vbtyp_n EQ 'M'.
      IF sy-subrc EQ 0 AND rv_vbeln IS NOT INITIAL.
        RETURN.
      ENDIF.
      WAIT UP TO '0.2' SECONDS.
    ENDDO.

    CLEAR rv_vbeln.
  ENDMETHOD.


  METHOD wait_for_open_item.
*---------------------------------------------------------------------------------------*
* The case-create BAdI raises the FI-CA open item from a later update task, so it is
* not readable in the LUW that created the case. WAIT closes the current database LUW
* on every tick, which is what makes the row appear. A WAIT-free retry inside one
* round trip will never see it, however long it spins.
*
* Timing verbatim from GET_CPG_DETAILS_OLD: 300 ticks of 0.2 seconds. AUGST EQ SPACE
* is also verbatim, and is NOT the same row set as GET_FEES, which uses AUGST NE '9'.
*---------------------------------------------------------------------------------------*
    DATA lv_case TYPE scmg_ext_key.

    CLEAR es_open.
    lv_case = |{ mv_caseid ALPHA = IN }|.

    DO c_wait_ticks TIMES.
      SELECT SINGLE opbel AS invoice_number, xblnr, betrh AS due_amount, waers
        FROM dfkkop
        INTO @es_open
        WHERE zzext_key EQ @lv_case
          AND augst     EQ @space
          AND betrh     GT 0
          AND bukrs     EQ @mv_bukrs.
      IF sy-subrc EQ 0.
        rv_ok = abap_true.
        RETURN.
      ENDIF.
      WAIT UP TO '0.2' SECONDS.
    ENDDO.

    CLEAR es_open.
  ENDMETHOD.
ENDCLASS.
