CLASS zcl_rd_status_scenarios DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
  TYPES: tt_string TYPE STANDARD TABLE OF char5.
  TYPES: BEGIN OF ty_req,
           requestnumber           TYPE string,
           requeststatus           TYPE string,
           estimatedannualamount   TYPE string,
           dir_first_uploaded      TYPE abap_bool,
           dir_first_downloaded    TYPE abap_bool,
           all_docs_fully_approved TYPE abap_bool,
           any_issue_during_process TYPE abap_bool,
           is_submit               TYPE abap_bool,
           is_draft_update         TYPE abap_bool,
           manager_action          TYPE string,
           authorized_close        TYPE abap_bool,
           needs_vat_notification  TYPE abap_bool,
         END OF ty_req.

  METHODS process_scenario
    IMPORTING iv_entityset TYPE string
              is_payload   TYPE ty_req.

  PRIVATE SECTION.

  CONSTANTS:
    c_es_supp    TYPE string VALUE 'SupplierRuquestsIntSet',
    c_es_gen     TYPE string VALUE 'GeneralDetailsExtSet',
    c_es_attach  TYPE string VALUE 'AttachmentsIntSet'.

  CONSTANTS:
    c_sys_nopr TYPE char5 VALUE 'NOPR',
    c_sys_osno TYPE char5 VALUE 'OSNO',
    c_sys_noco TYPE char5 VALUE 'NOCO',
    c_sys_nopo TYPE char5 VALUE 'NOPO'.

  CONSTANTS:
    c_u_drft TYPE char5 VALUE 'DRFT',
    c_u_vlog TYPE char5 VALUE 'VLOG',
    c_u_lkp1 TYPE char5 VALUE 'LKP1',
    c_u_vbad TYPE char5 VALUE 'VBAD',
    c_u_vdnd TYPE char5 VALUE 'VDND',
    c_u_sdip TYPE char5 VALUE 'SDIP',
    c_u_ads  TYPE char5 VALUE 'ADSG',
    c_u_kopr TYPE char5 VALUE 'KOPR',
    c_u_firs TYPE char5 VALUE 'FIRS',
    c_u_issu TYPE char5 VALUE 'ISSU',
    c_u_pmng TYPE char5 VALUE 'PMNG',
    c_u_done TYPE char5 VALUE 'DONE',
    c_u_decl TYPE char5 VALUE 'DECL',
    c_u_comp TYPE char5 VALUE 'COMP',
    c_u_lock TYPE char5 VALUE 'LOCK'.

  METHODS set_statuses
    IMPORTING iv_reqno      TYPE string
              iv_reqstat    TYPE char5
              it_userstats  TYPE tt_string
              it_sysstats   TYPE tt_string.

  METHODS write_vendor_log
    IMPORTING iv_reqno   TYPE string
              iv_action  TYPE string
              iv_refcode TYPE string.

  METHODS ensure_vendor_dir_clone
    IMPORTING iv_reqno TYPE string.

  METHODS ensure_notification_for_vat
    IMPORTING iv_reqno TYPE string.

  METHODS detect_scenario
    IMPORTING iv_entityset TYPE string
              is_req       TYPE ty_req
    RETURNING VALUE(rv_code) TYPE i.

  METHODS scenario_0  IMPORTING is_req TYPE ty_req.
  METHODS scenario_1  IMPORTING is_req TYPE ty_req.
  METHODS scenario_2  IMPORTING is_req TYPE ty_req.
  METHODS scenario_3  IMPORTING is_req TYPE ty_req.
  METHODS scenario_4  IMPORTING is_req TYPE ty_req.
  METHODS scenario_5  IMPORTING is_req TYPE ty_req.
  METHODS scenario_6  IMPORTING is_req TYPE ty_req.
  METHODS scenario_7  IMPORTING is_req TYPE ty_req.
  METHODS scenario_8  IMPORTING is_req TYPE ty_req.
  METHODS scenario_9  IMPORTING is_req TYPE ty_req.
  METHODS scenario_10 IMPORTING is_req TYPE ty_req.
  METHODS scenario_11 IMPORTING is_req TYPE ty_req.
  METHODS scenario_12 IMPORTING is_req TYPE ty_req.
  METHODS scenario_13 IMPORTING is_req TYPE ty_req.
  METHODS scenario_14 IMPORTING is_req TYPE ty_req.
  METHODS scenario_15 IMPORTING is_req TYPE ty_req.
  METHODS scenario_16 IMPORTING is_req TYPE ty_req.

ENDCLASS.



CLASS ZCL_RD_STATUS_SCENARIOS IMPLEMENTATION.


  METHOD detect_scenario.
    IF ( iv_entityset = c_es_supp OR iv_entityset = c_es_gen ) AND
       is_req-requestnumber IS INITIAL AND is_req-requeststatus IS INITIAL.
      rv_code = 0.
      RETURN.
    ENDIF.

    IF iv_entityset = c_es_gen AND is_req-requeststatus IS INITIAL.
      rv_code = 1.
      RETURN.
    ENDIF.

    IF is_req-is_draft_update IS INITIAL AND iv_entityset = c_es_supp AND is_req-requeststatus = c_u_lkp1.
      rv_code = 2. RETURN.
    ENDIF.

    IF iv_entityset = c_es_attach AND is_req-dir_first_uploaded = abap_true.
      rv_code = 3. RETURN.
    ENDIF.

    IF iv_entityset = c_es_attach AND is_req-dir_first_downloaded = abap_true.
      rv_code = 4. RETURN.
    ENDIF.

    IF iv_entityset = c_es_attach AND is_req-requeststatus = c_u_sdip.
      rv_code = 5. RETURN.
    ENDIF.

    IF iv_entityset = c_es_attach AND is_req-all_docs_fully_approved = abap_true.
      rv_code = 6. RETURN.
    ENDIF.

    IF is_req-is_draft_update = abap_true AND is_req-requeststatus = c_u_drft.
      rv_code = 7. RETURN.
    ENDIF.

    IF is_req-is_submit = abap_true
       AND is_req-requeststatus IS INITIAL
       AND is_req-estimatedannualamount >= '5500'
       AND is_req-estimatedannualamount <  '10000'.
      rv_code = 8. RETURN.
    ENDIF.

    IF is_req-is_submit = abap_true
       AND is_req-requeststatus IS INITIAL
       AND is_req-estimatedannualamount > '10000'.
      rv_code = 9. RETURN.
    ENDIF.

    IF is_req-manager_action = 'COMP' OR is_req-requeststatus = c_u_done.
      rv_code = 10. RETURN.
    ENDIF.

    IF is_req-manager_action = 'DECL' OR is_req-requeststatus = c_u_decl.
      rv_code = 11. RETURN.
    ENDIF.

    IF is_req-needs_vat_notification = abap_true.
      rv_code = 12. RETURN.
    ENDIF.

    IF is_req-requeststatus = c_u_kopr.
      rv_code = 13. RETURN.
    ENDIF.

    IF is_req-requeststatus = c_u_vbad.
      rv_code = 14. RETURN.
    ENDIF.

    IF is_req-requeststatus = c_u_sdip AND is_req-any_issue_during_process IS INITIAL.
      rv_code = 15. RETURN.
    ENDIF.

    IF is_req-any_issue_during_process = abap_true OR is_req-requeststatus = c_u_issu.
      rv_code = 16. RETURN.
    ENDIF.

    IF is_req-authorized_close = abap_true OR is_req-requeststatus = c_u_comp.
      rv_code = 6. RETURN.
    ENDIF.

    rv_code = -1.
  ENDMETHOD.


  METHOD ensure_notification_for_vat.
  ENDMETHOD.


METHOD ensure_vendor_dir_clone.

ENDMETHOD.


  METHOD process_scenario.
    DATA lv_code TYPE i.
    lv_code = detect_scenario( iv_entityset = iv_entityset is_req = is_payload ).
    CASE lv_code.
      WHEN 0.   scenario_0( is_payload ).
      WHEN 1.   scenario_1( is_payload ).
      WHEN 2.   scenario_2( is_payload ).
      WHEN 3.   scenario_3( is_payload ).
      WHEN 4.   scenario_4( is_payload ).
      WHEN 5.   scenario_5( is_payload ).
      WHEN 6.   scenario_6( is_payload ).
      WHEN 7.   scenario_7( is_payload ).
      WHEN 8.   scenario_8( is_payload ).
      WHEN 9.   scenario_9( is_payload ).
      WHEN 10.  scenario_10( is_payload ).
      WHEN 11.  scenario_11( is_payload ).
      WHEN 12.  scenario_12( is_payload ).
      WHEN 13.  scenario_13( is_payload ).
      WHEN 14.  scenario_14( is_payload ).
      WHEN 15.  scenario_15( is_payload ).
      WHEN 16.  scenario_16( is_payload ).
      WHEN OTHERS.
        write_vendor_log( iv_reqno = is_payload-requestnumber iv_action = 'UNKNOWN' iv_refcode = '00' ).
    ENDCASE.
  ENDMETHOD.


  METHOD scenario_0.

    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = conv #( c_u_drft )
      it_userstats = VALUE #( ( CONV #( c_u_vlog ) ) )
      it_sysstats  = VALUE #( ( CONV #( c_sys_nopr ) ) ) ).

    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'INIT' iv_refcode = '10' ).

  ENDMETHOD.


  METHOD scenario_1.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = CONV #( c_u_drft )
      it_userstats = VALUE #( ( CONV #( c_u_vlog ) ) )
      it_sysstats  = VALUE #( ( CONV #( c_sys_nopr ) ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'INIT_GEN' iv_refcode = '10' ).
  ENDMETHOD.


  METHOD scenario_10.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_done
      it_userstats = VALUE #( ( c_u_pmng ) ( c_u_done ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'MGR_DONE' iv_refcode = '15' ).
  ENDMETHOD.


  METHOD scenario_11.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_decl
      it_userstats = VALUE #( ( c_u_decl ) )
      it_sysstats  = VALUE #( ( c_sys_noco ) ( c_sys_nopo ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'MGR_DECL' iv_refcode = '16' ).
  ENDMETHOD.


  METHOD scenario_12.
    ensure_notification_for_vat( iv_reqno = is_req-requestnumber ).
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = COND #( WHEN is_req-requeststatus IS INITIAL THEN c_u_drft ELSE is_req-requeststatus )
      it_userstats = VALUE #( )
      it_sysstats  = VALUE #( ( c_sys_osno ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'VAT_NOTIFY' iv_refcode = '10' ).
  ENDMETHOD.


  METHOD scenario_13.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_kopr
      it_userstats = VALUE #( ( c_u_kopr ) )
      it_sysstats  = VALUE #( ( ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'COORD_LOCK' iv_refcode = '12' ).
  ENDMETHOD.


  METHOD scenario_14.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_vbad
      it_userstats = VALUE #( ( c_u_vbad ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'BASIC_DATA' iv_refcode = '12' ).
  ENDMETHOD.


  METHOD scenario_15.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_sdip
      it_userstats = VALUE #( ( c_u_sdip ) ( c_u_lock ) )
      it_sysstats  = VALUE #( ( c_sys_osno ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'IN_PROCESS' iv_refcode = '15' ).
  ENDMETHOD.


  METHOD scenario_16.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_issu
      it_userstats = VALUE #( ( c_u_issu ) )
      it_sysstats  = VALUE #( ( c_sys_osno ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'ISSUE' iv_refcode = '16' ).
  ENDMETHOD.


  METHOD scenario_2.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = CONV #( c_u_lkp1 )
      it_userstats = VALUE #( ( CONV #(  c_u_lkp1 ) ) ( CONV #( c_u_lock ) ) )
      it_sysstats  = VALUE #( ( CONV #( c_sys_nopr ) ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'PAGE1_DONE' iv_refcode = '11' ).
  ENDMETHOD.


  METHOD scenario_3.
    ensure_vendor_dir_clone( iv_reqno = is_req-requestnumber ).
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_vbad
      it_userstats = VALUE #( ( c_u_lkp1 ) ( c_u_vbad ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'DIR1_UP' iv_refcode = '12' ).
  ENDMETHOD.


  METHOD scenario_4.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_vdnd
      it_userstats = VALUE #( ( c_u_vbad ) ( c_u_vdnd ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'DIR1_DN' iv_refcode = '13' ).
  ENDMETHOD.


  METHOD scenario_5.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_sdip
      it_userstats = VALUE #( ( c_u_sdip ) )
      it_sysstats  = VALUE #( ( ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'DOC_INPROC' iv_refcode = '14' ).
  ENDMETHOD.


  METHOD scenario_6.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_ads
      it_userstats = VALUE #( ( c_u_firs ) ( c_u_ads ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'DOCS_OK' iv_refcode = '15' ).
  ENDMETHOD.


  METHOD scenario_7.
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_drft
      it_userstats = VALUE #( ( c_u_drft ) )
      it_sysstats  = VALUE #( ( c_sys_osno ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'DRFT_UPD' iv_refcode = '11' ).
  ENDMETHOD.


  METHOD scenario_8.
    ensure_vendor_dir_clone( iv_reqno = is_req-requestnumber ).
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_done
      it_userstats = VALUE #( ( c_u_done ) ( c_u_lock ) )
      it_sysstats  = VALUE #( ( c_sys_nopr ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'SUBMIT_LT10K' iv_refcode = '12' ).
  ENDMETHOD.


  METHOD scenario_9.
    ensure_vendor_dir_clone( iv_reqno = is_req-requestnumber ).
    set_statuses(
      iv_reqno     = is_req-requestnumber
      iv_reqstat   = c_u_pmng
      it_userstats = VALUE #( ( c_u_pmng ) )
      it_sysstats  = VALUE #( ( c_sys_osno ) ) ).
    write_vendor_log( iv_reqno = is_req-requestnumber iv_action = 'SUBMIT_GT10K' iv_refcode = '13' ).
  ENDMETHOD.


METHOD set_statuses.


ENDMETHOD.


METHOD write_vendor_log.

ENDMETHOD.
ENDCLASS.
