CLASS zcl_rak_journey_engine DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_serializable_object .
    INTERFACES z2ui5_if_app .
    INTERFACES zif_rak_journey .

    TYPES ty_betab TYPE zif_rak_cjs_types=>ty_betab.
    TYPES tt_betab TYPE zif_rak_cjs_types=>tt_betab.

    DATA mr_model TYPE REF TO data .
    DATA mv_bp_term TYPE string .
    DATA mv_att_name TYPE string .
    DATA mv_att_b64 TYPE string .
    DATA mv_fb_comment TYPE string .
    DATA mt_scratch TYPE zif_rak_journey=>tt_kv .
    DATA mt_be_attach TYPE /qnv/sbuild_attachments_tt .
    DATA mt_be_table TYPE tt_betab .
    TYPES ty_ovr TYPE zif_rak_cjs_types=>ty_ovr.
    TYPES tt_ovr TYPE zif_rak_cjs_types=>tt_ovr.
    DATA mt_ovr TYPE tt_ovr .
    DATA mv_ref_ovr TYPE string .
    DATA mv_trace TYPE abap_bool .
    DATA mv_sess  TYPE string .
    DATA mt_evt_seen TYPE string_table .

    TYPES ty_bp_hit TYPE zif_rak_cjs_types=>ty_bp_hit.
    TYPES tt_bp_hit TYPE zif_rak_cjs_types=>tt_bp_hit.
    TYPES ty_att TYPE zif_rak_cjs_types=>ty_att.
    TYPES tt_att TYPE zif_rak_cjs_types=>tt_att.

    TYPES ty_gcol TYPE zif_rak_cjs_types=>ty_gcol.
    TYPES tt_gcol TYPE zif_rak_cjs_types=>tt_gcol.
    TYPES ty_f4c TYPE zif_rak_cjs_types=>ty_f4c.
    TYPES tt_f4c TYPE zif_rak_cjs_types=>tt_f4c.
    TYPES ty_miss TYPE zif_rak_cjs_types=>ty_miss.
    TYPES tt_miss TYPE zif_rak_cjs_types=>tt_miss.

    DATA mo_client    TYPE REF TO z2ui5_if_client.
    DATA mo_logic     TYPE REF TO zif_rak_journey_logic.
    DATA mo_bridge    TYPE REF TO zcl_rak_qnv_bridge.
    DATA mo_backend   TYPE REF TO zif_rak_journey_backend.
    DATA mo_f4        TYPE REF TO zcl_rak_f4_resolver.
    DATA ms_config    TYPE zif_rak_journey=>ty_config.
    DATA mt_param     TYPE zif_rak_journey=>tt_kv.
    DATA mv_journey   TYPE string.
    DATA mv_lang      TYPE sy-langu.
    DATA mv_userdata  TYPE string.
    DATA mv_loginbp   TYPE string.
    DATA mv_rolebp    TYPE string.
    DATA mv_role      TYPE string.
    DATA mv_step      TYPE i.
    DATA mv_submitted TYPE abap_bool.
    DATA mv_fb_done    TYPE abap_bool.
    DATA mv_fb_rating  TYPE string.
    DATA mv_case_guid TYPE string.
    DATA mv_case_number TYPE string.
    DATA ms_handle    TYPE zif_rak_journey_backend=>ty_handle.
    DATA mt_msg       TYPE zif_rak_journey=>tt_msg.
    DATA mt_rulehide  TYPE zif_rak_journey=>tt_string.
    DATA mt_ruleshow  TYPE zif_rak_journey=>tt_string.
    DATA mt_rulereq   TYPE zif_rak_journey=>tt_string.
    DATA mt_rulero    TYPE zif_rak_journey=>tt_string.
    DATA mt_ruleedit  TYPE zif_rak_journey=>tt_string.
*   ZRAK_T_JNY_RULE rows with TOTABLE filled - grid-scoped, evaluated by
*   ZCL_RAK_JOURNEY_GRID rather than here. See ZIF_RAK_CJS_TYPES=>TY_GRIDRULE.
    DATA mt_rulegrid  TYPE zif_rak_cjs_types=>tt_gridrule.

    DATA mv_popup       TYPE string.
    DATA mv_popup_shown TYPE abap_bool.
    DATA mv_popup_id    TYPE string.
    DATA mv_pop_field   TYPE string.
    DATA mv_open_url    TYPE string.
    DATA mv_close_page  TYPE abap_bool.
    DATA mv_closed      TYPE abap_bool.
    DATA mt_bp_hits     TYPE tt_bp_hit.
    DATA mt_attach      TYPE tt_att.
    DATA mo_css    TYPE REF TO zcl_rak_journey_css.
    DATA mo_grid   TYPE REF TO zcl_rak_journey_grid.
    DATA mo_render TYPE REF TO zcl_rak_journey_render.
    DATA mo_be     TYPE REF TO zcl_rak_journey_be.
    DATA mo_rules  TYPE REF TO zcl_rak_journey_rules.

    DATA mt_gate TYPE zif_rak_journey=>tt_msg.
    DATA mv_req_t0 TYPE i.
    CONSTANTS c_slow_call_ms  TYPE i VALUE 1500.
    CONSTANTS c_slow_total_ms TYPE i VALUE 4000.

    METHODS trace_gate IMPORTING iv_text TYPE string.
    METHODS trace_perf IMPORTING iv_label TYPE string iv_ms TYPE i.
    METHODS tick RETURNING VALUE(rv) TYPE i.
    METHODS tock IMPORTING iv_t0 TYPE i RETURNING VALUE(rv_ms) TYPE i.
    METHODS gate_report.
    METHODS bp_of IMPORTING iv_in TYPE string RETURNING VALUE(rv) TYPE string.

    METHODS ensure_parts.
    METHODS init.
    METHODS ensure_config.
    METHODS check_types.
    METHODS change_evt  IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS opt_evt     IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS btn_evt     IMPORTING iv_id   TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS att_max_mb IMPORTING iv_field_mb TYPE i RETURNING VALUE(rv) TYPE i.
    CONSTANTS c_att_fallback_mb TYPE i VALUE 2.
    CONSTANTS c_att_hard_mb TYPE i VALUE 10.
    CONSTANTS c_att_tvarv       TYPE string VALUE 'ZRAK_CJ_ATT_MAXMB'.
    DATA mv_att_sys_mb TYPE i.
    METHODS radio_key_back IMPORTING iv_field TYPE string.
    METHODS trace IMPORTING iv_text TYPE string.
    METHODS read_params.
    METHODS build_model.
    METHODS merge_dynamic_steps.
    DATA mt_dyn_required TYPE string_table.
    DATA mv_dyn_note TYPE string.
    METHODS val_get IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE string.
    METHODS val_set IMPORTING iv_name TYPE string iv_value TYPE string.

    METHODS take_case IMPORTING iv_case TYPE string.

    METHODS resolve_identity.

    METHODS case_reference RETURNING VALUE(rv) TYPE string.
    METHODS set_field_state IMPORTING iv_name  TYPE string
                                      iv_state TYPE string
                                      iv_text  TYPE string.
    METHODS clear_field_states.

    METHODS handle_next.
    METHODS handle_submit.
    METHODS handle_save.
    METHODS handle_delete.
    METHODS bp_search.
    METHODS drop_attachments.
    METHODS safe_field
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rs_field) TYPE zif_rak_journey=>ty_field.
    METHODS field_exists
      IMPORTING iv_name   TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_ENGINE IMPLEMENTATION.


  METHOD z2ui5_if_app~main.
    mv_req_t0 = tick( ).
    ensure_parts( ).
    mo_client = client.

    CLEAR mt_msg.
    CLEAR mt_gate.

    TRY.
        CALL METHOD ('ZCL_RAK_NOT_TRACE')=>('RESET').
      CATCH cx_root.
    ENDTRY.

    IF mv_journey IS INITIAL.
      read_params( ).
      mv_journey = zif_rak_journey~get_param( 'journey' ).
      init( ).
    ELSE.
      ensure_config( ).
      IF mo_backend IS INITIAL.
        mo_backend = zcl_rak_be_factory=>get( ms_config ).
      ENDIF.
      IF mo_backend IS INITIAL AND ms_config-backend-active = abap_true.
        CREATE OBJECT mo_bridge EXPORTING is_config = ms_config.
      ENDIF.
      IF mo_logic IS INITIAL AND ms_config-handler_class IS NOT INITIAL.
        TRY.
            CREATE OBJECT mo_logic TYPE (ms_config-handler_class).
          CATCH cx_root INTO DATA(lx_hnd).
            CLEAR mo_logic.
            trace_gate( |Handler class { ms_config-handler_class } could not be | &&
                        |instantiated: { lx_hnd->get_text( ) }. Every hook on this | &&
                        |journey is silently doing nothing.| ).
            mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
              text = |Handler class { ms_config-handler_class } could not be instantiated.| ) ).
        ENDTRY.
      ENDIF.

      merge_dynamic_steps( ).

      LOOP AT mt_dyn_required INTO DATA(lv_dreq2).
        zif_rak_journey~set_required( iv_field = lv_dreq2 iv_on = abap_true ).
      ENDLOOP.
    ENDIF.

    IF mv_sess IS INITIAL.
      mv_sess = zcl_rak_cj_evt=>new_sess( ).
      DATA(lv_first) = abap_true.
    ENDIF.

    zcl_rak_cj_evt=>begin( iv_sess    = mv_sess
                           iv_journey = mv_journey
                           iv_langu   = mv_lang
                           ir_seen    = REF #( mt_evt_seen )
                           iv_bp      = mv_loginbp
                           iv_rolebp  = mv_rolebp
                           iv_role    = mv_role
                           iv_channel = zif_rak_journey~get_param( 'channel' )
                           iv_device  = zif_rak_journey~get_param( 'device' ) ).

    IF lv_first = abap_true.
      DATA(lv_resumed) = xsdbool(
        zif_rak_journey~get_param( 'caseid' )  IS NOT INITIAL OR
        zif_rak_journey~get_param( 'draftid' ) IS NOT INITIAL ).

      zcl_rak_cj_evt=>add(
        iv_type   = COND #( WHEN lv_resumed = abap_true
                            THEN zcl_rak_cj_evt=>c_type-resume
                            ELSE zcl_rak_cj_evt=>c_type-launch )
        iv_case   = mv_case_guid
        iv_bp     = mv_loginbp
        iv_detail = |{ ms_config-backend-category }| ).
    ENDIF.

    DATA(ls_get)   = mo_client->get( ).
    DATA(lv_event) = ls_get-event.

    IF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'SEARCH_'.
      IF mo_logic IS BOUND.
        mo_logic->on_search( io_ctx = me iv_field = substring( val = lv_event off = 7 ) ).
      ENDIF.

    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'CHANGE_'.
      DATA(lv_chg_fld) = substring( val = lv_event off = 7 ).
      radio_key_back( lv_chg_fld ).
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_change( io_ctx = me iv_field = lv_chg_fld ).
          CATCH cx_root INTO DATA(lx_chg).
            mt_msg = VALUE #( ( type = 'Warning'
              text = |Could not react to { lv_chg_fld }: { lx_chg->get_text( ) }| ) ).
        ENDTRY.
      ENDIF.
      set_field_state( iv_name = lv_chg_fld iv_state = 'None' iv_text = '' ).

    ELSEIF strlen( lv_event ) > 5 AND substring( val = lv_event len = 5 ) = 'HPOP_'.
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_popup_event( io_ctx   = me
                                      iv_id    = mv_popup_id
                                      iv_event = substring( val = lv_event off = 5 ) ).
          CATCH cx_root INTO DATA(lx_hpop).
            mt_msg = VALUE #( BASE mt_msg
              ( type = 'Warning' text = lx_hpop->get_text( ) ) ).
        ENDTRY.
      ENDIF.
      IF substring( val = lv_event off = 5 ) = 'CLOSE' AND mv_open_url IS INITIAL.
        CLEAR mt_msg.
        mv_closed    = abap_true.
        mv_submitted = abap_true.
        DATA(lv_fbw) = abap_false.
        IF mo_logic IS BOUND.
          lv_fbw = abap_true.
          TRY.
              lv_fbw = mo_logic->wants_feedback( me ).
            CATCH cx_root.
          ENDTRY.
        ENDIF.
        IF mv_fb_done = abap_true OR lv_fbw = abap_false.
          mv_close_page = abap_true.
        ENDIF.
      ENDIF.

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'ROWPICK_'.
      SPLIT substring( val = lv_event off = 8 ) AT '~' INTO DATA(lv_rpf) DATA(lv_rpk).
      LOOP AT ms_config-steps INTO DATA(ls_rps).
        READ TABLE ls_rps-fields INTO DATA(ls_rpf) WITH KEY name = lv_rpf.
        IF sy-subrc = 0.
          DATA lv_rptgt TYPE string.
          lv_rptgt = COND #( WHEN ls_rpf-default IS NOT INITIAL THEN ls_rpf-default
                             WHEN to_upper( ls_rpf-type ) = 'RECORDCARD' THEN ls_rpf-name
                             ELSE '' ).
          IF lv_rptgt IS NOT INITIAL.
            val_set( iv_name = lv_rptgt iv_value = lv_rpk ).
            IF mo_logic IS BOUND.
              mo_logic->on_change( io_ctx = me iv_field = lv_rptgt ).
            ENDIF.
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.
    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'ROWCHK_'.
      SPLIT substring( val = lv_event off = 7 ) AT '~' INTO DATA(lv_ckf) DATA(lv_cck).
      LOOP AT ms_config-steps INTO DATA(ls_cks).
        READ TABLE ls_cks-fields INTO DATA(ls_ckf) WITH KEY name = lv_ckf.
        IF sy-subrc = 0.
          DATA lv_cset TYPE string.
          CLEAR lv_cset.
          IF ls_ckf-default CP 'CHK:*'.
            lv_cset = to_upper( substring( val = ls_ckf-default off = 4 ) ).
          ELSEIF to_upper( ls_ckf-type ) = 'CHECKGROUP'.
            lv_cset = to_upper( ls_ckf-name ).
          ENDIF.
          IF lv_cset IS NOT INITIAL.
            SPLIT val_get( lv_cset ) AT ',' INTO TABLE DATA(lt_cset).
            DELETE lt_cset WHERE table_line IS INITIAL.
            READ TABLE lt_cset WITH KEY table_line = lv_cck TRANSPORTING NO FIELDS.
            IF sy-subrc = 0.
              DELETE lt_cset WHERE table_line = lv_cck.
            ELSE.
              APPEND lv_cck TO lt_cset.
            ENDIF.
            val_set( iv_name = lv_cset iv_value = concat_lines_of( table = lt_cset sep = ',' ) ).
            IF mo_logic IS BOUND.
              TRY.
                  mo_logic->on_change( io_ctx = me iv_field = lv_cset ).
                CATCH cx_root.
              ENDTRY.
            ENDIF.
          ENDIF.
          EXIT.
        ENDIF.
      ENDLOOP.
    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'FBRATE_'.
      mv_fb_rating = substring( val = lv_event off = 7 ).

    ELSEIF strlen( lv_event ) > 5 AND substring( val = lv_event len = 5 ) = 'GOTO_'.
      DATA(lv_goto) = substring( val = lv_event off = 5 ).
      IF lv_goto IS NOT INITIAL AND lv_goto CO '0123456789'.
        DATA(lv_gt) = CONV i( lv_goto ).
        IF lv_gt >= 0 AND lv_gt < lines( ms_config-steps ).
          mv_step = lv_gt.
        ENDIF.
      ENDIF.

    ELSEIF lv_event = 'FBSEND'.
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_feedback( io_ctx = me iv_rating = mv_fb_rating iv_comment = mv_fb_comment ).
          CATCH cx_root.
        ENDTRY.
      ENDIF.
      mv_fb_done = abap_true.
      IF mv_closed = abap_true.
        mv_close_page = abap_true.
      ENDIF.

    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'BPOPEN_'.
      mv_pop_field = substring( val = lv_event off = 7 ).
      mv_popup = 'BP'.
      CLEAR: mv_bp_term, mt_bp_hits.

    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'BPPICK_'.
      DATA(lv_bp) = substring( val = lv_event off = 7 ).
      val_set( iv_name = mv_pop_field iv_value = lv_bp ).
      READ TABLE mt_bp_hits INTO DATA(ls_hit) WITH KEY partner = lv_bp.
      IF sy-subrc = 0.
        val_set( iv_name = |{ mv_pop_field }_NAME| iv_value = ls_hit-name ).
      ENDIF.
      IF mo_logic IS BOUND.
        mo_logic->on_change( io_ctx = me iv_field = mv_pop_field ).
      ENDIF.
      set_field_state( iv_name = mv_pop_field iv_state = 'None' iv_text = '' ).
      CLEAR: mv_popup, mt_bp_hits.

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'ATTSAVE_'.
      DATA(lv_att_raw) = substring( val = lv_event off = 8 ).
      DATA lv_att_field TYPE string.
      DATA lv_att_key   TYPE string.
      SPLIT lv_att_raw AT '~' INTO lv_att_field lv_att_key.
      DATA(ls_att_lim) = safe_field( lv_att_field ).
      DATA(lv_att_mb)  = att_max_mb( ls_att_lim-attach_maxmb ).
      DATA lv_att_size TYPE p LENGTH 8 DECIMALS 1.
      lv_att_size = CONV decfloat34( strlen( mv_att_b64 ) ) * 3 / 4 / 1048576.

      IF mv_att_b64 IS NOT INITIAL AND strlen( mv_att_b64 ) > lv_att_mb * 1400000.
        mt_msg = VALUE #( ( type = 'Error'
          text = |{ mv_att_name } is { lv_att_size } MB. The most this form accepts is | &&
                 |{ lv_att_mb } MB, so it has not been attached.| ) ).
      ELSEIF mv_att_b64 IS NOT INITIAL.
        DATA lv_att_msg TYPE string.
        DATA(lv_att_guid) = zcl_rak_cj_att_store=>put( EXPORTING iv_name = mv_att_name
                                                                 iv_b64  = mv_att_b64
                                                       IMPORTING ev_msg  = lv_att_msg ).
        IF lv_att_guid IS NOT INITIAL.
          DATA lv_att_tech TYPE string.
          CLEAR lv_att_tech.
          LOOP AT ms_config-steps INTO DATA(ls_att_s).
            LOOP AT ls_att_s-fields INTO DATA(ls_att_f) WHERE name IS NOT INITIAL.
              IF to_upper( ls_att_f-name ) = lv_att_field.
                lv_att_tech = ls_att_f-tech_name.
                EXIT.
              ENDIF.
            ENDLOOP.
            IF lv_att_tech IS NOT INITIAL.
              EXIT.
            ENDIF.
          ENDLOOP.
          APPEND VALUE #( field = lv_att_field
                          tech  = lv_att_tech
                          name  = mv_att_name
                          guid  = lv_att_guid
                          okey  = lv_att_key ) TO mt_attach.
          set_field_state( iv_name = lv_att_field iv_state = 'None' iv_text = '' ).
          mt_msg = VALUE #( ( type = 'Success' text = |{ mv_att_name } attached| ) ).
          IF mo_logic IS BOUND.
            TRY.
                mo_logic->on_attach( io_ctx = me iv_field = lv_att_field ).
              CATCH cx_root INTO DATA(lx_att).
                mt_msg = VALUE #( BASE mt_msg
                  ( type = 'Warning' text = lx_att->get_text( ) ) ).
            ENDTRY.
          ENDIF.
        ELSE.
          mt_msg = VALUE #( ( type = 'Error'
            text = |{ mv_att_name }: { lv_att_msg }| ) ).
        ENDIF.
      ELSE.
        mt_msg = VALUE #( ( type = 'Warning'
          text = 'No file received. If this repeats, the file may be too large or inline scripts are blocked.' ) ).
      ENDIF.
      CLEAR: mv_att_name, mv_att_b64.

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'ATTVIEW_'.
      DATA(lv_vw) = substring( val = lv_event off = 8 ).
      IF lv_vw CO '0123456789'.
        READ TABLE mt_attach INTO DATA(ls_vw) INDEX CONV i( lv_vw ).
        IF sy-subrc = 0.
          mo_client->follow_up_action(
            mo_client->_event_client(
              val  = z2ui5_if_client=>cs_event-open_new_tab
              t_arg = VALUE #( ( zcl_rak_journey_util=>att_url( ls_vw-guid ) ) ) ) ).
        ENDIF.
      ENDIF.

    ELSEIF strlen( lv_event ) > 7 AND substring( val = lv_event len = 7 ) = 'ATTDEL_'.
      DATA(lv_del) = substring( val = lv_event off = 7 ).
      IF lv_del CO '0123456789'.
        DATA(lv_del_ix) = CONV i( lv_del ).
        READ TABLE mt_attach INTO DATA(ls_del) INDEX lv_del_ix.
        IF sy-subrc = 0.
          zcl_rak_cj_att_store=>delete( ls_del-guid ).
          DELETE mt_attach INDEX lv_del_ix.
        ENDIF.
      ENDIF.
    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'GRIDADD_'.
      mo_grid->grid_add( substring( val = lv_event off = 8 ) ).

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'GRIDDEL_'.
      mo_grid->grid_del( iv_field = substring( val = lv_event off = 8 )
                         iv_uid   = mo_client->get_event_arg( 1 ) ).

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'GRIDCHG_'.
      SPLIT substring( val = lv_event off = 8 ) AT '~' INTO DATA(lv_gcf) DATA(lv_gcc).
      DATA(lv_gcx) = mo_grid->grid_index( iv_field = lv_gcf
                                          iv_uid   = mo_client->get_event_arg( 1 ) ).
      IF mo_logic IS BOUND AND lv_gcx > 0.
        TRY.
            mo_logic->on_change( io_ctx   = me
                                 iv_field = |{ to_upper( lv_gcf ) }.{ to_upper( lv_gcc ) }#{ lv_gcx }| ).
          CATCH cx_root INTO DATA(lx_gcg).
            mt_msg = VALUE #( BASE mt_msg ( type = 'Warning' text = lx_gcg->get_text( ) ) ).
        ENDTRY.
      ENDIF.

    ELSEIF strlen( lv_event ) > 8 AND substring( val = lv_event len = 8 ) = 'GRIDSEL_'.
      mo_grid->grid_sel_pick( iv_field = substring( val = lv_event off = 8 )
                              iv_uid   = mo_client->get_event_arg( 1 ) ).

    ELSEIF strlen( lv_event ) > 3 AND substring( val = lv_event len = 3 ) = 'TAB'.
      DATA(lv_rest) = substring( val = lv_event off = 3 ).
      IF lv_rest IS NOT INITIAL AND lv_rest CO '0123456789'.
        DATA(lv_tb) = CONV i( lv_rest ).
        IF lv_tb >= 0 AND lv_tb < lines( ms_config-steps ).
          mv_step = lv_tb.
        ENDIF.
      ENDIF.

    ELSE.
      CASE lv_event.
        WHEN 'NEXT'.
          DATA(lv_from) = mv_step.
          handle_next( ).
          zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-next
                               iv_step_no = mv_step
                               iv_case    = mv_case_guid
                               iv_result  = COND string( WHEN mv_step > lv_from THEN 'OK' ELSE 'BLOCK' )
                               iv_detail  = |{ lv_from }>{ mv_step }| ).
        WHEN 'BACK'.
          IF mv_step > 0.
            mv_step = mv_step - 1.
            zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-back
                                 iv_step_no = mv_step
                                 iv_case    = mv_case_guid ).
          ENDIF.
        WHEN 'SUBMIT'.
          handle_submit( ).
          zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-submit
                               iv_step_no = mv_step
                               iv_case    = mv_case_guid
                               iv_bp      = mv_loginbp ).
        WHEN 'SAVE'.
          handle_save( ).
          zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-save
                               iv_step_no = mv_step
                               iv_case    = mv_case_guid ).
        WHEN 'ASKDEL'. mv_popup = 'DELCONF'.
        WHEN 'DELETE'.
          handle_delete( ).
          zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-delete
                               iv_step_no = mv_step
                               iv_case    = mv_case_guid ).
        WHEN 'POPCLOSE'. CLEAR: mv_popup, mt_bp_hits.
        WHEN 'BPGO'.     bp_search( ).
      ENDCASE.
    ENDIF.

    IF mo_logic IS BOUND.
      TRY.
          mo_logic->on_fee_calc( me ).
        CATCH cx_root INTO DATA(lx_fee).
          mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
            text = |Fee calculation skipped: { lx_fee->get_text( ) }| ) ).
      ENDTRY.
    ENDIF.

    mo_rules->eval_rules( ).

    gate_report( ).

    mo_render->render( ).

    zcl_rak_cj_evt=>add_view( iv_step_id = ``
                              iv_step_no = mv_step ).

    IF mv_case_guid IS NOT INITIAL.
      zcl_rak_cj_evt=>add_once( iv_type    = zcl_rak_cj_evt=>c_type-case_new
                                iv_key     = mv_case_guid
                                iv_case    = mv_case_guid
                                iv_step_no = mv_step ).
    ENDIF.

    zcl_rak_cj_evt=>flush( ).

    CLEAR ms_config.
    CLEAR: mo_css, mo_grid, mo_render, mo_be, mo_rules.
    CLEAR ms_handle-token.
  ENDMETHOD.


  METHOD read_params.
    CLEAR mt_param.
    DATA(lv_q) = mo_client->get( )-s_config-search.
    IF lv_q IS INITIAL.
      RETURN.
    ENDIF.
    IF substring( val = lv_q len = 1 ) = '?'.
      lv_q = substring( val = lv_q off = 1 ).
    ENDIF.
    SPLIT lv_q AT '&' INTO TABLE DATA(lt_pairs).
    LOOP AT lt_pairs INTO DATA(lv_pair).
      SPLIT lv_pair AT '=' INTO DATA(lv_n) DATA(lv_v).
      APPEND VALUE #( key = to_upper( lv_n ) value = lv_v ) TO mt_param.
    ENDLOOP.
  ENDMETHOD.


  METHOD init.
    DATA(lv_p) = to_upper( zif_rak_journey~get_param( 'lang' ) ).
    mv_lang = COND #( WHEN lv_p = 'AR' OR lv_p = 'A' THEN 'A'
                      WHEN lv_p = 'EN' OR lv_p = 'E' THEN 'E'
                      ELSE sy-langu ).
    zcl_rak_text=>set_lang( mv_lang ).

    mv_userdata = zif_rak_journey~get_param( 'userdata' ).

    resolve_identity( ).

    ensure_config( ).

    IF ms_config-journey_id IS INITIAL.
      mt_msg = VALUE #( ( type = 'Error'
        text = |Journey '{ mv_journey }' not found or inactive. Launch with ?journey=<ID>| ) ).
      RETURN.
    ENDIF.

    DATA lv_launch_case TYPE string.

    IF mv_case_guid IS INITIAL.
      mv_case_guid = zif_rak_journey~get_param( 'caseid' ).
      IF mv_case_guid IS NOT INITIAL.
        lv_launch_case = mv_case_guid.
      ELSE.
        mv_case_guid = zif_rak_journey~get_param( 'draftid' ).
      ENDIF.
    ENDIF.
    DATA(lv_tp) = to_upper( zif_rak_journey~get_param( 'trace' ) ).
    mv_trace = xsdbool( lv_tp = 'X' OR lv_tp = '1' OR lv_tp = 'TRUE' ).

    mo_backend = zcl_rak_be_factory=>get( ms_config ).
    IF mo_backend IS INITIAL AND ms_config-backend-active = abap_true.
      mo_bridge = NEW zcl_rak_qnv_bridge( ms_config ).
    ENDIF.

    IF mv_trace = abap_true.
      trace( |journey { ms_config-journey_id } · BKND_ACTIVE { COND string( WHEN ms_config-backend-active = abap_true THEN 'X' ELSE 'blank' ) }| &&
             | · category { COND string( WHEN ms_config-backend-category IS NOT INITIAL THEN ms_config-backend-category ELSE '(empty)' ) }| &&
             | · BE journey { COND string( WHEN ms_config-backend-journey IS NOT INITIAL THEN ms_config-backend-journey ELSE '(empty)' ) }| ).
      IF mo_backend IS BOUND.
        trace( 'path = EXTERNAL backend from ZCL_RAK_BE_FACTORY. The QNV bridge and the D0xx BAdI are NOT used.' ).
      ELSEIF mo_bridge IS BOUND.
        trace( 'path = QNV bridge. Posts and reads go to the D0xx BAdI.' ).
      ELSE.
        trace( 'path = NONE. No backend call will be made on any event. BKND_ACTIVE is blank.' ).
      ENDIF.
      trace( |case/draft on entry = { COND string( WHEN mv_case_guid IS NOT INITIAL THEN mv_case_guid ELSE '(new application)' ) }| ).
    ENDIF.


    merge_dynamic_steps( ).

    build_model( ).

    IF lv_launch_case IS NOT INITIAL.
      take_case( lv_launch_case ).
    ENDIF.

    clear_field_states( ).

    LOOP AT mt_dyn_required INTO DATA(lv_dreq).
      zif_rak_journey~set_required( iv_field = lv_dreq iv_on = abap_true ).
    ENDLOOP.

    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_field).
        IF ls_field-default IS NOT INITIAL
           AND ls_field-type <> 'LINK'
           AND ls_field-type <> 'EDITABLE_TABLE'
           AND ls_field-type <> 'RO_PANEL'
           AND ls_field-type <> 'TABLE'.
          val_set( iv_name = ls_field-name iv_value = ls_field-default ).
        ENDIF.
        IF ls_field-type = 'RO_PANEL'.
          val_set( iv_name  = |{ ls_field-name }_EXP|
                   iv_value = COND string( WHEN to_upper( ls_field-default ) = 'CLOSED'
                                           THEN '' ELSE 'X' ) ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    IF ms_config-handler_class IS NOT INITIAL.
      TRY.
          CREATE OBJECT mo_logic TYPE (ms_config-handler_class).
        CATCH cx_root.
          CLEAR mo_logic.
          trace_gate( |Handler class { ms_config-handler_class } could not be | &&
                      |instantiated. Every hook on this journey is doing nothing.| ).
          mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
            text = |Handler class { ms_config-handler_class } could not be instantiated.| ) ).
      ENDTRY.
    ENDIF.

    check_types( ).

*   AFTER the CREATE OBJECT above, which is the whole point. Reported from the
*   journey banner higher up in this method it read NOT BOUND on every first
*   load - the banner is written before the handler is built - and that false
*   negative is worse than no line at all: it sends you looking for a broken
*   class when the class is fine.
    IF mv_trace = abap_true.
      trace( |handler { COND string( WHEN ms_config-handler_class IS NOT INITIAL
                                     THEN ms_config-handler_class
                                     ELSE '(none configured)' ) }| &&
             | · { COND string( WHEN mo_logic IS BOUND THEN 'bound' ELSE 'NOT BOUND' ) }| ).
    ENDIF.

    IF mo_logic IS BOUND.
      TRY.
          mo_logic->on_init( me ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF mv_case_guid IS NOT INITIAL AND mo_bridge IS BOUND.
      mo_be->backend_read( 0 ).
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_after_read( me ).
          CATCH cx_root.
        ENDTRY.
      ENDIF.

    ELSEIF mv_case_guid IS INITIAL AND mo_bridge IS BOUND.
      mo_be->backend_create( ).
      IF mv_case_guid IS NOT INITIAL.
        mo_be->backend_read( 0 ).
        IF mo_logic IS BOUND.
          TRY.
              mo_logic->on_after_read( me ).
            CATCH cx_root.
          ENDTRY.
        ENDIF.
      ENDIF.

    ELSEIF mv_case_guid IS NOT INITIAL AND mo_backend IS BOUND.
      DATA(ls_rh) = ms_handle.
      DATA lt_rr TYPE bapiret2_t.
      mo_backend->resume(
        EXPORTING
          iv_request_id = mv_case_guid
        IMPORTING
          et_return     = lt_rr
        CHANGING
          cs_handle     = ls_rh ).
      ms_handle = ls_rh.
      LOOP AT lt_rr INTO DATA(ls_rrm) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_rrm-message ) TO mt_msg.
      ENDLOOP.
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_after_read( me ).
          CATCH cx_root.
        ENDTRY.
      ENDIF.
    ENDIF.
    DATA(lv_sp) = zif_rak_journey~get_param( 'step' ).
    IF lv_sp IS NOT INITIAL AND lv_sp CO '0123456789'.
      DATA(lv_si) = CONV i( lv_sp ).
      IF lv_si > 0 AND lv_si < lines( ms_config-steps ).
        mv_step = lv_si.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD build_model.
    DATA lt_comp TYPE cl_abap_structdescr=>component_table.

    DATA(lo_bool)   = CAST cl_abap_elemdescr( cl_abap_typedescr=>describe_by_name( 'ABAP_BOOL' ) ).
    DATA(lo_num)    = cl_abap_elemdescr=>get_p( p_length = 13 p_decimals = 2 ).
    DATA(lo_int)    = cl_abap_elemdescr=>get_i( ).
    DATA(lo_str)    = cl_abap_elemdescr=>get_string( ).
    DATA(lo_strtab) = cl_abap_tabledescr=>create( p_line_type = lo_str ).
    DATA lo_type TYPE REF TO cl_abap_datadescr.

    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_field).
        IF ls_field-type = 'UPLOAD'.
          CONTINUE.
        ENDIF.

        DATA(lv_name) = to_upper( ls_field-name ).

        IF ls_field-type = 'EDITABLE_TABLE'.
          READ TABLE lt_comp WITH KEY name = lv_name TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            DATA lt_rowcomp TYPE cl_abap_structdescr=>component_table.
            CLEAR lt_rowcomp.
            APPEND VALUE #( name = '_UID' type = lo_str ) TO lt_rowcomp.
            mo_grid->grid_sel( EXPORTING is_field = ls_field IMPORTING ev_mode = DATA(lv_smode) ).
            IF lv_smode IS NOT INITIAL.
              APPEND VALUE #( name = '_SEL' type = lo_bool ) TO lt_rowcomp.
            ENDIF.
            LOOP AT mo_grid->grid_cols( ls_field ) INTO DATA(gc).
              READ TABLE lt_rowcomp WITH KEY name = gc-name TRANSPORTING NO FIELDS.
              IF sy-subrc <> 0.
*               A CHECKBOX column binds its cell's SELECTED to this component
*               directly (same as _SEL below) - sap.m.CheckBox rejects a
*               string there ("" is of type string, expected boolean"), so it
*               needs the same ABAP_BOOL type _SEL already gets, not the
*               STRING every other column gets.
                APPEND VALUE #( name = gc-name
                                type = COND #( WHEN gc-name CP '*_EN' OR gc-ctype = 'CHECKBOX'
                                              THEN lo_bool ELSE lo_str ) ) TO lt_rowcomp.
              ENDIF.
            ENDLOOP.
            DATA(lo_row)  = cl_abap_structdescr=>create( lt_rowcomp ).
            DATA(lo_rtab) = cl_abap_tabledescr=>create( p_line_type = lo_row ).
            APPEND VALUE #( name = lv_name type = lo_rtab ) TO lt_comp.
          ENDIF.
          CONTINUE.
        ENDIF.

        IF ls_field-type = 'TABLE' OR ls_field-type = 'REQPANEL'.
          CONTINUE.
        ENDIF.

        READ TABLE lt_comp WITH KEY name = lv_name TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          CASE ls_field-type.
            WHEN 'CHECKBOX' OR 'SWITCH'.
              lo_type = lo_bool.
            WHEN 'RADIO'.
              lo_type = lo_str.
            WHEN 'SLIDER' OR 'STEPPER' OR 'RATING' OR 'PROGRESS'.
              lo_type = lo_num.
            WHEN 'MULTISELECT'.
              lo_type = lo_strtab.
            WHEN OTHERS.
              lo_type = lo_str.
          ENDCASE.
          APPEND VALUE #( name = lv_name type = lo_type ) TO lt_comp.
          APPEND VALUE #( name = |{ lv_name }_VS|  type = lo_str ) TO lt_comp.
          APPEND VALUE #( name = |{ lv_name }_VST| type = lo_str ) TO lt_comp.
        ENDIF.
        IF ls_field-type = 'SEARCH'.
          DATA(lv_idt) = |{ lv_name }_IDTYPE|.
          READ TABLE lt_comp WITH KEY name = lv_idt TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND VALUE #( name = lv_idt type = lo_str ) TO lt_comp.
          ENDIF.
          DATA(lv_nm) = |{ lv_name }_NAME|.
          READ TABLE lt_comp WITH KEY name = lv_nm TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND VALUE #( name = lv_nm type = lo_str ) TO lt_comp.
          ENDIF.
        ENDIF.
        IF ls_field-type = 'RADIO'.
          DATA(lv_rix) = |{ lv_name }_IX|.
          READ TABLE lt_comp WITH KEY name = lv_rix TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND VALUE #( name = lv_rix type = lo_int ) TO lt_comp.
          ENDIF.
        ENDIF.
        IF ls_field-type = 'RO_PANEL'.
          DATA(lv_exp) = |{ lv_name }_EXP|.
          READ TABLE lt_comp WITH KEY name = lv_exp TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            APPEND VALUE #( name = lv_exp type = lo_bool ) TO lt_comp.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    DATA(lv_has_fee) = abap_false.
    LOOP AT ms_config-steps INTO DATA(ls_fstep).
      LOOP AT ls_fstep-fields INTO DATA(ls_ffld).
        IF to_upper( ls_ffld-type ) = 'PAYFEE'.
          lv_has_fee = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF lv_has_fee = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_has_fee = abap_true.
      LOOP AT VALUE string_table( ( `PAY_STARTED` ) ( `PAY_REFERENCE` ) ( `PAY_APPURL` ) )
           INTO DATA(lv_paym).
        READ TABLE lt_comp WITH KEY name = lv_paym TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          APPEND VALUE #( name = lv_paym type = lo_str ) TO lt_comp.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lt_comp IS INITIAL.
      APPEND VALUE #( name = 'DUMMY' type = lo_str ) TO lt_comp.
    ENDIF.

    DATA(lo_struct) = cl_abap_structdescr=>create( lt_comp ).
    CREATE DATA mr_model TYPE HANDLE lo_struct.
  ENDMETHOD.


  METHOD val_get.
    DATA(lv_key) = to_upper( condense( iv_name ) ).
    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mr_model->* TO <model>.
    ASSIGN COMPONENT lv_key OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
    IF sy-subrc <> 0.
      rv = VALUE #( mt_scratch[ key = lv_key ]-value OPTIONAL ).
      RETURN.
    ENDIF.

    DESCRIBE FIELD <f> TYPE DATA(lv_kind).

    CASE lv_kind.

      WHEN cl_abap_typedescr=>typekind_table.
        DATA(lo_row) = CAST cl_abap_tabledescr(
                         cl_abap_typedescr=>describe_by_data( <f> ) )->get_table_line_type( ).

        IF lo_row->kind <> cl_abap_typedescr=>kind_elem.
          RETURN.
        ENDIF.

        FIELD-SYMBOLS <tab>  TYPE ANY TABLE.
        FIELD-SYMBOLS <line> TYPE any.
        DATA lv_cell TYPE string.

        ASSIGN <f> TO <tab>.
        LOOP AT <tab> ASSIGNING <line>.
          lv_cell = <line>.
          rv = COND #( WHEN rv IS INITIAL THEN lv_cell ELSE |{ rv },{ lv_cell }| ).
        ENDLOOP.

      WHEN cl_abap_typedescr=>typekind_struct1
        OR cl_abap_typedescr=>typekind_struct2.
        RETURN.

      WHEN OTHERS.
        rv = <f>.

    ENDCASE.
  ENDMETHOD.


  METHOD val_set.
    DATA(lv_key) = to_upper( condense( iv_name ) ).
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_val) = iv_value.
    IF lv_val IS NOT INITIAL.
      DATA(lv_zdt) = lv_val.
      REPLACE ALL OCCURRENCES OF REGEX '[.\-/0]' IN lv_zdt WITH ''.
      IF lv_zdt IS INITIAL AND strlen( lv_val ) >= 8.
        CLEAR lv_val.
      ENDIF.
    ENDIF.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mr_model->* TO <model>.
    ASSIGN COMPONENT lv_key OF STRUCTURE <model> TO FIELD-SYMBOL(<f>).
    IF sy-subrc <> 0.
      READ TABLE mt_scratch ASSIGNING FIELD-SYMBOL(<s>) WITH KEY key = lv_key.
      IF sy-subrc = 0.
        <s>-value = lv_val.
      ELSE.
        APPEND VALUE #( key = lv_key value = lv_val ) TO mt_scratch.
      ENDIF.
      RETURN.
    ENDIF.

    DESCRIBE FIELD <f> TYPE DATA(lv_kind).

    CASE lv_kind.

      WHEN cl_abap_typedescr=>typekind_table.
        DATA(lo_row) = CAST cl_abap_tabledescr(
                         cl_abap_typedescr=>describe_by_data( <f> ) )->get_table_line_type( ).

        IF lo_row->kind <> cl_abap_typedescr=>kind_elem.
          RETURN.
        ENDIF.

        FIELD-SYMBOLS <tab> TYPE ANY TABLE.
        ASSIGN <f> TO <tab>.

        DATA lt_new TYPE string_table.
        IF lv_val IS NOT INITIAL.
          SPLIT lv_val AT ',' INTO TABLE lt_new.
        ENDIF.

        FIELD-SYMBOLS <ins> TYPE any.
        CLEAR <tab>.
        LOOP AT lt_new INTO DATA(lv_part).
          INSERT INITIAL LINE INTO TABLE <tab> ASSIGNING <ins>.
          IF sy-subrc = 0.
            <ins> = lv_part.
          ENDIF.
        ENDLOOP.

      WHEN cl_abap_typedescr=>typekind_struct1
        OR cl_abap_typedescr=>typekind_struct2.
        RETURN.

      WHEN OTHERS.
        TRY.
            <f> = lv_val.
          CATCH cx_root.
        ENDTRY.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey~get_val.
    rv_value = val_get( iv_name ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_val.
    val_set( iv_name = iv_name iv_value = iv_value ).
  ENDMETHOD.


  METHOD zif_rak_journey~get_param.
    DATA(lv_k) = to_upper( iv_name ).

    CASE lv_k.
      WHEN 'LOGINBP'.
        IF mv_loginbp IS NOT INITIAL.
          rv_value = mv_loginbp.
          RETURN.
        ENDIF.
      WHEN 'ROLEBP'.
        IF mv_rolebp IS NOT INITIAL.
          rv_value = mv_rolebp.
          RETURN.
        ENDIF.
      WHEN 'ROLE'.
        IF mv_role IS NOT INITIAL.
          rv_value = mv_role.
          RETURN.
        ENDIF.
      WHEN OTHERS.
    ENDCASE.

    rv_value = VALUE #( mt_param[ key = lv_k ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD zif_rak_journey~add_msg.
    APPEND VALUE #( type = iv_type text = iv_text ) TO mt_msg.
  ENDMETHOD.


  METHOD zif_rak_journey~get_step.
    rv_step = mv_step.
  ENDMETHOD.


  METHOD zif_rak_journey~get_config.
    rs_config = ms_config.
  ENDMETHOD.


  METHOD change_evt.
    rv = mo_client->_event( |CHANGE_{ iv_name }| ).
  ENDMETHOD.


  METHOD handle_next.
    IF zif_rak_journey~commit_step( ) = abap_false.
      RETURN.
    ENDIF.
    zif_rak_journey~advance_step( ).
  ENDMETHOD.


  METHOD handle_submit.
    IF mv_submitted = abap_true.
      RETURN.
    ENDIF.
    clear_field_states( ).
    mt_msg = mo_rules->validate_all( ).
    IF mt_msg IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF mo_logic IS BOUND.
      TRY.
          DATA(lt_sb) = mo_logic->on_submit( me ).
          APPEND LINES OF lt_sb TO mt_msg.
        CATCH cx_root INTO DATA(lx_sb).
          mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
            text = |Submit stopped: { lx_sb->get_text( ) }| ) ).
      ENDTRY.
      READ TABLE mt_msg WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        RETURN.
      ENDIF.
    ENDIF.

    IF mo_backend IS BOUND.
      IF mo_be->be_attach( ) = abap_false.
        RETURN.
      ENDIF.

      DATA(ls_h) = ms_handle.
      DATA lt_sub TYPE bapiret2_t.
      mo_backend->submit(
        EXPORTING
          it_fields = mo_be->be_fields( )
        IMPORTING
          et_return = lt_sub
        CHANGING
          cs_handle = ls_h ).
      ms_handle = ls_h.
      LOOP AT lt_sub INTO DATA(ls_sm) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_sm-message ) TO mt_msg.
      ENDLOOP.
      IF line_exists( lt_sub[ type = 'E' ] ).
        RETURN.
      ENDIF.
      mv_case_guid = ms_handle-request_id.
      mv_submitted = abap_true.
      drop_attachments( ).
    ELSEIF mo_bridge IS BOUND.
      READ TABLE ms_config-steps INTO DATA(ls_step) INDEX lines( ms_config-steps ).
      mo_bridge->post(
        EXPORTING
          iv_screen      = ls_step-bknd_screen
          iv_status      = 'SUBMIT'
          iv_guid        = mv_case_guid
          it_items       = mo_be->post_items( )
          it_tables      = mo_be->tables_for_backend( )
          it_attachments = mo_be->attachments_for_backend( )
        IMPORTING
          ev_guid        = mv_case_guid
          ev_case        = DATA(lv_case_sub)
          et_msg         = DATA(lt_ret) ).
      take_case( lv_case_sub ).
      READ TABLE lt_ret WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        mt_msg = lt_ret.
        RETURN.
      ENDIF.
      APPEND LINES OF lt_ret TO mt_msg.
      mv_submitted = abap_true.
      IF mo_logic IS BOUND.
        TRY.
            mo_logic->on_after_read( me ).
          CATCH cx_root.
        ENDTRY.
      ENDIF.
      drop_attachments( ).
    ELSE.
      IF mv_case_guid IS INITIAL.
        mv_case_guid = COND #( WHEN ms_config-cj_type IS NOT INITIAL
                               THEN |{ ms_config-cj_type }-{ sy-datum }{ sy-uzeit }|
                               ELSE |{ sy-datum }{ sy-uzeit }| ).
      ENDIF.
      mv_submitted = abap_true.
      drop_attachments( ).
    ENDIF.

    IF mv_ref_ovr IS NOT INITIAL.
      mv_case_guid = mv_ref_ovr.
    ENDIF.
  ENDMETHOD.


  METHOD handle_save.
    IF mo_logic IS BOUND.
      TRY.
          mo_logic->on_save( me ).
        CATCH cx_root.
      ENDTRY.
    ENDIF.

    IF mo_backend IS BOUND.
      IF mo_be->be_commit( mv_step ) = abap_false.
        RETURN.
      ENDIF.
      IF ms_handle-request_id IS NOT INITIAL.
        mv_case_guid = ms_handle-request_id.
      ENDIF.
      APPEND VALUE #( type = 'Success'
        text = |Saved as draft — { mv_case_guid }| ) TO mt_msg.
      RETURN.
    ENDIF.

    IF mo_bridge IS BOUND.
      READ TABLE ms_config-steps INTO DATA(ls_step) INDEX mv_step + 1.
      mo_bridge->post(
        EXPORTING
          iv_screen = ls_step-bknd_screen
          iv_status = 'SAVE_DRAFT'
          iv_guid   = mv_case_guid
          it_items  = mo_be->post_items( )
          it_tables = mo_be->tables_for_backend( )
        IMPORTING
          ev_guid   = mv_case_guid
          ev_case   = DATA(lv_case_drf)
          et_msg    = DATA(lt_ret) ).
      take_case( lv_case_drf ).
      READ TABLE lt_ret WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        mt_msg = lt_ret.
        RETURN.
      ENDIF.
      mt_msg = VALUE #( ( type = 'Success' text = |Saved as draft - { mv_case_guid }| ) ).
    ELSE.
      mt_msg = VALUE #( ( type = 'Warning'
        text = 'No backend is configured for this journey — nothing was saved.' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD handle_delete.
    CLEAR mv_popup.

    IF mo_bridge IS BOUND AND mv_case_guid IS NOT INITIAL.
      READ TABLE ms_config-steps INTO DATA(ls_dstep) INDEX mv_step + 1.
      mo_bridge->post(
        EXPORTING
          iv_screen = ls_dstep-bknd_screen
          iv_status = 'DELETE'
          iv_guid   = mv_case_guid
          it_items  = mo_be->post_items( )
        IMPORTING
          ev_guid   = mv_case_guid
          ev_case   = DATA(lv_case_del)
          et_msg    = DATA(lt_dm) ).
      take_case( lv_case_del ).
      READ TABLE lt_dm WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        mt_msg = lt_dm.
        RETURN.
      ENDIF.
    ENDIF.
    DATA lv_cancelled TYPE abap_bool.
    IF mo_backend IS BOUND AND ms_handle-request_id IS NOT INITIAL AND mv_submitted = abap_false.
      DATA(ls_dh)  = ms_handle.
      DATA lt_disc TYPE bapiret2_t.
      mo_backend->discard( IMPORTING et_return = lt_disc CHANGING cs_handle = ls_dh ).
      ms_handle = ls_dh.
      LOOP AT lt_disc INTO DATA(ls_dmsg) WHERE type = 'E'.
        APPEND VALUE #( type = 'Error' text = ls_dmsg-message ) TO mt_msg.
      ENDLOOP.
      IF line_exists( lt_disc[ type = 'E' ] ).
        RETURN.
      ENDIF.
      lv_cancelled = abap_true.
    ENDIF.

    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF ls_f-type = 'EDITABLE_TABLE'.
          mo_grid->grid_from_json( iv_field = ls_f-name iv_json = `` ).
          CONTINUE.
        ENDIF.
        IF ls_f-type = 'UPLOAD' OR ls_f-type = 'TABLE' OR ls_f-type = 'REQPANEL'.
          CONTINUE.
        ENDIF.
        val_set( iv_name = ls_f-name iv_value = '' ).
      ENDLOOP.
    ENDLOOP.
    clear_field_states( ).
    drop_attachments( ).
    CLEAR mt_scratch.
    CLEAR mt_be_attach.
    CLEAR mt_be_table.
    CLEAR mt_ovr.

    DATA(lv_orphan) = COND string(
      WHEN mo_backend IS BOUND AND ms_handle-request_id IS NOT INITIAL
           AND lv_cancelled = abap_false
      THEN ms_handle-request_id ELSE `` ).

    CLEAR mv_case_guid.
    CLEAR ms_handle.
    mv_step = 0.
    IF lv_orphan IS NOT INITIAL.
      mt_msg = VALUE #( ( type = 'Warning'
        text = |Form cleared. Case { lv_orphan } still exists in the backend and has to be cancelled there.| ) ).
    ELSE.
      mt_msg = VALUE #( ( type = 'Success' text = 'Application deleted' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD bp_search.
    CLEAR mt_bp_hits.
    DATA(lv_term) = condense( mv_bp_term ).
    IF strlen( lv_term ) < 3.
      RETURN.
    ENDIF.

    DATA(lv_idtype) = val_get( |{ mv_pop_field }_IDTYPE| ).
    IF lv_idtype IS INITIAL.
      lv_idtype = 'YFS002'.
    ENDIF.

    TYPES:
      BEGIN OF ty_sel,
        partner  TYPE but000-partner,
        name     TYPE but000-zzfull_name_eng,
        idnumber TYPE but0id-idnumber,
      END OF ty_sel.
    DATA lt TYPE STANDARD TABLE OF ty_sel WITH EMPTY KEY.

*   AN ID SEARCH IS DECIDED ON THE DIGITS, NOT ON THE PUNCTUATION.
*
*   The test used to be LV_TERM CO '0123456789' against the raw term, so an
*   Emirates ID entered the way it is printed on the card - 784-1987-8624392-7 -
*   failed it on the hyphens and fell through to the ELSE branch, which searches
*   ZZFULL_NAME_ENG. The citizen got no results for a partner that exists, and
*   nothing on the screen suggested their ID had been searched for as a name.
*
*   Digits, hyphens and spaces now all count as an ID. NORM_EID( ) then strips the
*   separators for the LIKE, because BUT0ID-IDNUMBER stores the digits - so
*   784-1987-8624392-7 and 784198786243927 find the same row.
*
*   The NAME branch keeps the term exactly as typed. A name is not digits and
*   must not have its punctuation removed.
    DATA(lv_digits) = zcl_rak_bp_search=>norm_eid( lv_term ).
    DATA(lv_isid)   = xsdbool( lv_digits IS NOT INITIAL AND lv_term CO '0123456789- ' ).

    DATA(lv_like) = COND string( WHEN lv_isid = abap_true
                                 THEN '%' && lv_digits && '%'
                                 ELSE '%' && to_upper( lv_term ) && '%' ).

    IF lv_isid = abap_true.

      SELECT a~partner, a~zzfull_name_eng AS name, b~idnumber
        FROM but000 AS a
        LEFT JOIN but0id AS b
          ON  b~partner = a~partner
          AND b~type    = @lv_idtype
        WHERE a~partner LIKE @lv_like
           OR b~idnumber LIKE @lv_like
        ORDER BY a~partner
        INTO TABLE @lt UP TO 20 ROWS.
    ELSE.
      SELECT a~partner, a~zzfull_name_eng AS name, b~idnumber
        FROM but000 AS a
        LEFT JOIN but0id AS b
          ON  b~partner = a~partner
          AND b~type    = @lv_idtype
        WHERE upper( a~zzfull_name_eng ) LIKE @lv_like
        ORDER BY a~partner
        INTO TABLE @lt UP TO 20 ROWS.
    ENDIF.

    LOOP AT lt INTO DATA(ls).
      APPEND VALUE #( partner = ls-partner name = ls-name idnum = ls-idnumber ) TO mt_bp_hits.
    ENDLOOP.
  ENDMETHOD.


  METHOD clear_field_states.
    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        set_field_state( iv_name = ls_f-name iv_state = 'None' iv_text = '' ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD drop_attachments.
    LOOP AT mt_attach INTO DATA(ls_att).
      zcl_rak_cj_att_store=>delete( ls_att-guid ).
    ENDLOOP.
    CLEAR mt_attach.
  ENDMETHOD.


  METHOD ensure_config.
    IF ms_config-journey_id IS NOT INITIAL.
      RETURN.
    ENDIF.

    ms_config = zcl_rak_cj_cfg_cache=>get( iv_journey = mv_journey
                                           iv_lang    = mv_lang ).
    IF ms_config-journey_id IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE theme_own FROM zrak_t_jny
      WHERE journey_id = @ms_config-journey_id
      INTO @DATA(lv_own).

    DATA(ls_theme) = zcl_rak_cj_theme=>effective(
      iv_own     = xsdbool( lv_own = 'X' )
      iv_brand   = ms_config-theme-brand_color
      iv_navy    = ms_config-theme-navy_color
      iv_accent  = ms_config-theme-accent_type
      iv_density = ms_config-theme-density
      iv_layout  = ms_config-theme-layout_mode
      iv_variant = ms_config-theme-variant ).

    ms_config-theme-brand_color = ls_theme-brand.
    ms_config-theme-navy_color  = ls_theme-navy.
    ms_config-theme-accent_type = ls_theme-accent.
    ms_config-theme-density     = ls_theme-density.
    IF ls_theme-layout IS NOT INITIAL.
      ms_config-theme-layout_mode = ls_theme-layout.
    ENDIF.
    IF ls_theme-variant IS NOT INITIAL.
      ms_config-theme-variant     = ls_theme-variant.
    ENDIF.

    zcl_rak_text=>set_journey( ms_config-journey_id ).

    ms_config-backend-userdata    = mv_userdata.
    ms_config-backend-loginbp_dev = mv_loginbp.
    ms_config-backend-rolebp      = mv_rolebp.
    ms_config-backend-role        = mv_role.
    ms_config-backend-context     = VALUE #( FOR p IN mt_param
                                             WHERE ( key <> 'LOGINBP' AND
                                                     key <> 'ROLEBP'  AND
                                                     key <> 'ROLE' )
                                             ( field = p-key tech = p-key value = p-value ) ).
  ENDMETHOD.


  METHOD set_field_state.
    val_set( iv_name = |{ iv_name }_VS|  iv_value = iv_state ).
    val_set( iv_name = |{ iv_name }_VST| iv_value = iv_text ).
  ENDMETHOD.


  METHOD btn_evt.
    rv = mo_client->_event( iv_id ).
  ENDMETHOD.


  METHOD check_types.
    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF zcl_rak_journey_util=>known_type( ls_f-type ) = abap_false.
          mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
            text = |Field { ls_f-name }: unsupported type '{ ls_f-type }' - rendered as a plain input.| ) ).
        ENDIF.
        IF to_upper( ls_f-type ) = 'PAYFEE' AND mo_logic IS NOT BOUND.
          mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
            text = 'PAYFEE requires handler_class (a subclass of ZCL_RAK_JOURNEY_LOGIC). Payment is disabled.' ) ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD field_exists.
    LOOP AT ms_config-steps INTO DATA(ls_step).
      READ TABLE ls_step-fields TRANSPORTING NO FIELDS WITH KEY name = iv_name.
      IF sy-subrc = 0.
        rv = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD opt_evt.
*   A change event is raised when a RULE depends on this field - or when the
*   journey has a handler at all.
*
*   The rule test on its own was a trap. ON_CHANGE( ) is the documented way for a
*   handler to react to a field, and it simply never fired unless some rule
*   happened to name that field as its source. A handler could redefine
*   ON_CHANGE, the method could be correct, and nothing would call it - no error,
*   no trace, no clue. That is what kept the Notary declaration dropdown from
*   loading its blueprint: SET_SUBSERVICE( ) sits in ON_CHANGE and the field was
*   nobody's rule source.
*
*   The cost is one round trip when a citizen changes a select on a journey that
*   has a handler. That is the point of having one, and it is the same round trip
*   Next already makes. Journeys with no handler class are unaffected.
    IF line_exists( ms_config-rules[ src_field = to_upper( iv_name ) ] )
       OR mo_logic IS BOUND.
      rv = mo_client->_event( |CHANGE_{ iv_name }| ).
    ENDIF.
  ENDMETHOD.


  METHOD safe_field.
    DATA(lv_want) = to_upper( condense( iv_name ) ).
    LOOP AT ms_config-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO rs_field.
        IF to_upper( rs_field-name ) = lv_want.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    CLEAR rs_field.
  ENDMETHOD.


  METHOD zif_rak_journey~bind.
    rv = mo_render->bind_of( iv_name ).
  ENDMETHOD.


  METHOD zif_rak_journey~close_popup.
    CLEAR: mv_popup, mv_popup_id.
  ENDMETHOD.


  METHOD zif_rak_journey~event.
    rv = mo_client->_event( |HPOP_{ iv_id }| ).
  ENDMETHOD.


  METHOD zif_rak_journey~get_case.
    rv = mv_case_guid.
  ENDMETHOD.


  METHOD zif_rak_journey~get_handle.
    rs_handle = ms_handle.
  ENDMETHOD.


  METHOD zif_rak_journey~open_popup.
    mv_popup    = 'CUST'.
    mv_popup_id = iv_id.
  ENDMETHOD.


  METHOD zif_rak_journey~open_url.
    CHECK iv_url IS NOT INITIAL.
    mv_open_url = iv_url.
  ENDMETHOD.


  METHOD zif_rak_journey~set_handle.
    ms_handle = is_handle.
  ENDMETHOD.


  METHOD att_max_mb.
    IF iv_field_mb > 0.
      rv = iv_field_mb.
      IF rv > c_att_hard_mb.
        rv = c_att_hard_mb.
      ENDIF.
      RETURN.
    ENDIF.

    IF mv_att_sys_mb = 0.
      SELECT SINGLE low FROM tvarvc INTO @DATA(lv_lo)
        WHERE name = @c_att_tvarv AND type = 'P'.
      IF sy-subrc = 0 AND condense( lv_lo ) CO '0123456789' AND lv_lo IS NOT INITIAL.
        mv_att_sys_mb = condense( lv_lo ).
      ENDIF.
      IF mv_att_sys_mb <= 0.
        mv_att_sys_mb = c_att_fallback_mb.
      ENDIF.
      IF mv_att_sys_mb > c_att_hard_mb.
        mv_att_sys_mb = c_att_hard_mb.
      ENDIF.
    ENDIF.
    rv = mv_att_sys_mb.
  ENDMETHOD.


  METHOD bp_of.
    DATA(lv_in) = to_upper( condense( iv_in ) ).

    IF lv_in IS INITIAL.
      RETURN.
    ENDIF.

    REPLACE ALL OCCURRENCES OF '-' IN lv_in WITH ''.

    IF strlen( lv_in ) = 32.
      SELECT SINGLE partner FROM but000
        WHERE partner_guid = @lv_in
        INTO @DATA(lv_p).
      IF sy-subrc = 0.
        rv = |{ lv_p ALPHA = OUT }|.
        CONDENSE rv.
      ELSE.
        trace( |IDENT   no partner for guid { lv_in }| ).
      ENDIF.
      RETURN.
    ENDIF.

    rv = |{ CONV bu_partner( iv_in ) ALPHA = OUT }|.
    CONDENSE rv.
  ENDMETHOD.


  METHOD case_reference.
    rv = COND #( WHEN mv_case_number IS NOT INITIAL THEN mv_case_number
                 ELSE mv_case_guid ).

    IF rv CO '0123456789' AND rv IS NOT INITIAL.
      SHIFT rv LEFT DELETING LEADING '0'.
      IF rv IS INITIAL.
        rv = '0'.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD ensure_parts.
    CREATE OBJECT mo_css EXPORTING io_engine = me.
    CREATE OBJECT mo_grid EXPORTING io_engine = me.
    CREATE OBJECT mo_render EXPORTING io_engine = me.
    CREATE OBJECT mo_be EXPORTING io_engine = me.
    CREATE OBJECT mo_rules EXPORTING io_engine = me.
  ENDMETHOD.


  METHOD gate_report.
    IF mv_trace = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_dynnote) = COND string( WHEN mv_dyn_note IS NOT INITIAL
                                    THEN mv_dyn_note
                                    ELSE 'merge_dynamic_steps never ran' ).

    mt_msg = VALUE #( BASE mt_msg ( type = 'Information'
      text = |TRACE  DYNAMIC  { lv_dynnote }| ) ).

    DATA lt_belog TYPE stringtab.
    TRY.
        CALL METHOD ('ZCL_RAK_NOT_TRACE')=>('DUMP')
          RECEIVING rt_log = lt_belog.
      CATCH cx_root.
    ENDTRY.

    DATA(lv_calls) = 0.
    LOOP AT lt_belog INTO DATA(lv_bl).
      IF lv_bl CS '-->'.
        lv_calls = lv_calls + 1.
      ENDIF.
    ENDLOOP.

    IF lv_calls = 0.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
        text = 'TRACE  BACKEND  NO Notary API call was made on this interaction.' ) ).
    ELSE.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Information'
        text = |TRACE  BACKEND  { lv_calls } Notary API call(s) on this interaction| ) ).
    ENDIF.

*   EVERY line, not only the ones carrying --> or <--.
*
*   The filter that used to sit here showed HTTP arrows and discarded the rest,
*   which quietly threw away the only lines that explain a call that did NOT
*   happen: AUTH not attempted, LOOKUP skipped, LOOKUP no endpoint, BLUEPRINT
*   skipped - and the request payloads, which HTTP( ) has always logged and
*   nobody has ever been able to see.
*
*   That is backwards. "No Notary API call was made" is the symptom; those
*   notes are the reason, and they were being collected and dropped one line
*   before the screen.
*
*   Also moved OUT of the ELSE. The zero-call case is exactly when the notes
*   matter most, and it was the one case that displayed none of them.
    LOOP AT lt_belog INTO DATA(lv_bl2).
      mt_msg = VALUE #( BASE mt_msg ( type = 'Information'
        text = |TRACE  BACKEND  { lv_bl2 }| ) ).
    ENDLOOP.

    DATA(lv_ms) = tock( mv_req_t0 ).

    IF mt_gate IS INITIAL.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Success'
        text = |TRACE  GATE  clean - no blockers found on this request | &&
               |· whole request { lv_ms } ms| ) ).
    ELSE.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
        text = |TRACE  GATE  { lines( mt_gate ) } BLOCKER(S). | &&
               |This journey must not go to QA until every one is cleared. | &&
               |· whole request { lv_ms } ms| ) ).
      LOOP AT mt_gate INTO DATA(ls_g).
        mt_msg = VALUE #( BASE mt_msg ( type = 'Error'
          text = |TRACE  BLOCKER  { ls_g-text }| ) ).
      ENDLOOP.
    ENDIF.

    IF lv_ms >= c_slow_total_ms.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
        text = |TRACE  SLOW  the whole request took { lv_ms } ms. | &&
               |Check the per-call lines above for where it went.| ) ).
    ENDIF.
  ENDMETHOD.


  METHOD merge_dynamic_steps.

    CLEAR: mt_dyn_required, mv_dyn_note.

    IF mo_backend IS NOT BOUND.
      mv_dyn_note = 'no backend bound - merge skipped'.
      RETURN.
    ENDIF.

    DATA lt_dyn TYPE zif_rak_journey_backend=>tt_dyn_field.
*   Indices of steps with nothing to draw, deleted after the loop rather than
*   inside it - deleting from the table being looped over skips rows.
    DATA lt_drop TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    LOOP AT ms_config-steps ASSIGNING FIELD-SYMBOL(<dstep>).

*     Captured HERE, not read later. DESCRIBE_STEP( ) reads and loops over tables
*     of its own, and any of those resets SY-TABIX - so by the time the drop
*     decision is made below, SY-TABIX no longer names this step.
      DATA(lv_ix) = sy-tabix.

      IF <dstep>-bknd_screen IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR lt_dyn.

      TRY.
          lt_dyn = mo_backend->describe_step( <dstep>-bknd_screen ).
        CATCH cx_root INTO DATA(lx_dyn).
          mv_dyn_note = |{ mv_dyn_note }{ <dstep>-bknd_screen }=EXCEPTION | .
          CONTINUE.
      ENDTRY.

      mv_dyn_note = |{ mv_dyn_note }{ <dstep>-bknd_screen }={ lines( lt_dyn ) }fld |.

*     A step that has no static fields of its own AND whose backend describes no
*     fields either has nothing to draw. Note it and drop it below.
*
*     This is the Notary business-object case. The blueprint returns businessFields
*     as an EMPTY ARRAY for the declaration types that have no business object -
*     Approval & Signature, No Objection, Pledge, Clearance - and the legacy portal
*     does not show the section at all for those. CJS was rendering an empty step
*     with a heading, a Next button and nothing to fill in, and then POSTing to
*     BKND_SCREEN for a business object that does not exist.
*
*     Deliberately narrow. DESCRIBE_STEP is implemented for the BO screen only and
*     returns nothing for every other screen, so keying this on "backend described
*     no fields" alone would drop every step on the journey. A step that carries
*     configured fields always survives.
      IF <dstep>-fields IS INITIAL AND lt_dyn IS INITIAL.
        APPEND lv_ix TO lt_drop.
        mv_dyn_note = |{ mv_dyn_note }{ <dstep>-id } DROPPED (no configured fields, | &&
                      |backend described none) |.
        CONTINUE.
      ENDIF.

      LOOP AT lt_dyn INTO DATA(ls_dyn).

        DATA(lv_dnm) = to_upper( ls_dyn-name ).
        IF lv_dnm IS INITIAL.
          CONTINUE.
        ENDIF.

        READ TABLE <dstep>-fields TRANSPORTING NO FIELDS WITH KEY name = lv_dnm.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        APPEND VALUE #(
          name    = lv_dnm
*         Arabic when the journey is Arabic. The backend already resolves
*         LABEL_AR off the blueprint and it was being thrown away here, so every
*         blueprint-driven field carried an English label on the Arabic journey -
*         on a screen where every configured field beside it was translated.
*         Same precedence ZCL_RAK_JOURNEY_REPO->PICK( ) uses: Arabic if asked for
*         and present, English otherwise.
          label   = COND string( WHEN mv_lang = 'A' AND ls_dyn-label_ar IS NOT INITIAL
                                 THEN ls_dyn-label_ar
                                 WHEN ls_dyn-label IS NOT INITIAL
                                 THEN ls_dyn-label
                                 ELSE ls_dyn-name )
          type    = COND string( WHEN ls_dyn-type IS NOT INITIAL
                                 THEN to_upper( ls_dyn-type )
                                 ELSE 'INPUT' )
*         MAX_LEN was computed by DESCRIBE_STEP and dropped here, so a blueprint
*         field with a length limit accepted anything and failed at the Notary API
*         instead of at the field - the citizen learns about it on submit, with no
*         indication of which answer was too long.
          validation = VALUE #( max_len = ls_dyn-max_len
                                regex   = ls_dyn-regex )
          options = VALUE #( FOR o IN ls_dyn-options ( key = o-key text = o-text ) )
        ) TO <dstep>-fields.

        IF ls_dyn-required = abap_true.
          APPEND lv_dnm TO mt_dyn_required.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

*   Descending, so an earlier delete cannot shift a later index.
*
*   MS_CONFIG-STEPS is rebuilt from the same blueprint on every round trip, so the
*   drop is the same every time and MV_STEP keeps addressing the step the citizen
*   is actually on. The clamp is for the one case that is not stable: a resumed
*   draft whose stored step index was recorded before a step disappeared.
    IF lines( lt_drop ) > 0 AND lines( lt_drop ) < lines( ms_config-steps ).
      SORT lt_drop DESCENDING.
      LOOP AT lt_drop INTO DATA(lv_drop).
        DELETE ms_config-steps INDEX lv_drop.
      ENDLOOP.
      IF mv_step >= lines( ms_config-steps ).
        mv_step = lines( ms_config-steps ) - 1.
      ENDIF.
      IF mv_step < 0.
        mv_step = 0.
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD radio_key_back.
    DATA(ls_f) = safe_field( iv_field ).
    IF to_upper( ls_f-type ) <> 'RADIO'.
      RETURN.
    ENDIF.

    DATA lv_ix TYPE i.
    lv_ix = val_get( |{ ls_f-name }_IX| ).
    IF lv_ix < 0.
      RETURN.
    ENDIF.

    DATA(lt_o) = ls_f-options.
    IF lt_o IS INITIAL AND mo_logic IS BOUND.
      TRY.
          lt_o = mo_logic->on_value_help( io_ctx = me iv_field = ls_f-name ).
        CATCH cx_root.
          CLEAR lt_o.
      ENDTRY.
    ENDIF.
    IF lt_o IS INITIAL
       AND ( ls_f-rollname IS NOT INITIAL OR ls_f-shlp IS NOT INITIAL OR ls_f-domname IS NOT INITIAL ).
      lt_o = mo_render->f4_opts( ls_f ).
    ENDIF.

    READ TABLE lt_o INTO DATA(ls_o) INDEX lv_ix + 1.
    IF sy-subrc = 0.
      val_set( iv_name = ls_f-name iv_value = ls_o-key ).
    ENDIF.
  ENDMETHOD.


  METHOD resolve_identity.

    mv_loginbp = bp_of( VALUE #( mt_param[ key = 'LOGINBP' ]-value OPTIONAL ) ).
    mv_rolebp  = bp_of( VALUE #( mt_param[ key = 'ROLEBP' ]-value OPTIONAL ) ).
    mv_role    = to_upper( VALUE #( mt_param[ key = 'ROLE' ]-value OPTIONAL ) ).

    IF mv_userdata IS NOT INITIAL.
      DATA lv_l TYPE bu_partner.
      DATA lv_r TYPE bu_partner.
      DATA lv_o TYPE string.
      TRY.
          zcl_ega_cj_utility=>get_bp( EXPORTING qv_key  = mv_userdata
                                      IMPORTING loginbp = lv_l
                                                rolebp  = lv_r
                                                role    = lv_o ).
        CATCH cx_root INTO DATA(lx_bp).
          trace( |IDENT   get_bp failed: { lx_bp->get_text( ) }| ).
      ENDTRY.

      IF lv_l IS NOT INITIAL.
        mv_loginbp = |{ lv_l ALPHA = OUT }|.
        CONDENSE mv_loginbp.
        mv_rolebp  = |{ lv_r ALPHA = OUT }|.
        CONDENSE mv_rolebp.
        mv_role    = to_upper( lv_o ).
      ENDIF.
    ENDIF.

    IF mv_loginbp IS INITIAL AND sy-sysid <> 'E30'.
      mv_loginbp = bp_of( VALUE #( mt_param[ key = 'LOGINBP' ]-value OPTIONAL ) ).
    ENDIF.

    IF mv_rolebp IS INITIAL.
      mv_rolebp = mv_loginbp.
    ENDIF.

    trace( |IDENT   login { COND string( WHEN mv_loginbp IS NOT INITIAL THEN mv_loginbp ELSE '(none)' ) }| &&
           | · role bp { COND string( WHEN mv_rolebp IS NOT INITIAL THEN mv_rolebp ELSE '(none)' ) }| &&
           | · role { COND string( WHEN mv_role IS NOT INITIAL THEN mv_role ELSE '(none)' ) }| &&
           | · via { COND string( WHEN mv_userdata IS NOT INITIAL THEN 'userdata' ELSE 'url' ) }| ).

    IF mv_rolebp IS NOT INITIAL AND mv_rolebp <> mv_loginbp.
      DATA(lv_as) = COND string( WHEN mv_role IS NOT INITIAL THEN | as { mv_role }| ELSE `` ).
      trace( |IDENT   acting on behalf of { mv_rolebp }{ lv_as }| ).
    ENDIF.

  ENDMETHOD.


  METHOD take_case.
    IF iv_case IS INITIAL OR iv_case = mv_case_number.
      RETURN.
    ENDIF.

    mv_case_number = iv_case.

    val_set( iv_name = 'CASE_NUMBER' iv_value = mv_case_number ).

    trace( |CASE    backend returned case { mv_case_number } - journey key stays { mv_case_guid }| ).
  ENDMETHOD.


  METHOD tick.
    GET RUN TIME FIELD rv.
  ENDMETHOD.


  METHOD tock.
    DATA lv_now TYPE i.
    GET RUN TIME FIELD lv_now.
    rv_ms = ( lv_now - iv_t0 ) / 1000.
    IF rv_ms < 0.
      CLEAR rv_ms.
    ENDIF.
  ENDMETHOD.


  METHOD trace.
    IF mv_trace = abap_false.
      RETURN.
    ENDIF.
    mt_msg = VALUE #( BASE mt_msg ( type = 'Information' text = |TRACE  { iv_text }| ) ).
  ENDMETHOD.


  METHOD trace_gate.
    mt_gate = VALUE #( BASE mt_gate ( type = 'Error' text = iv_text ) ).
    zcl_rak_cj_evt=>add( iv_type    = zcl_rak_cj_evt=>c_type-gate
                         iv_step_no = mv_step
                         iv_result  = 'BLOCK'
                         iv_detail  = iv_text ).
  ENDMETHOD.


  METHOD trace_perf.
    IF iv_ms >= zcl_rak_cj_evt=>c_slow_ms.
      zcl_rak_cj_evt=>add( iv_type     = zcl_rak_cj_evt=>c_type-perf
                           iv_step_no  = mv_step
                           iv_duration = iv_ms
                           iv_detail   = iv_label ).
    ENDIF.

    IF mv_trace = abap_false.
      RETURN.
    ENDIF.
    IF iv_ms >= c_slow_call_ms.
      mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
        text = |TRACE  SLOW  { iv_label } took { iv_ms } ms (over { c_slow_call_ms } ms). | &&
               |The engine is waiting on the backend here, not rendering.| ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey~advance_step.
    IF mv_step < lines( ms_config-steps ) - 1.
      mv_step = mv_step + 1.
      IF mo_bridge IS BOUND.
        mo_be->backend_read( mv_step ).
        IF mo_logic IS BOUND.
          TRY.
              mo_logic->on_after_read( me ).
            CATCH cx_root.
          ENDTRY.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey~clear_props.
    IF iv_field IS INITIAL.
      CLEAR mt_ovr.
      RETURN.
    ENDIF.
    DELETE mt_ovr WHERE field = to_upper( condense( iv_field ) ).
  ENDMETHOD.


  METHOD zif_rak_journey~commit_step.
    clear_field_states( ).
    mt_msg = mo_rules->validate_step( mv_step ).
    IF mt_msg IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF mo_backend IS BOUND.
      IF mo_be->be_commit( mv_step ) = abap_false.
        RETURN.
      ENDIF.
    ELSEIF mo_bridge IS BOUND.
      READ TABLE ms_config-steps INTO DATA(ls_step) INDEX mv_step + 1.
      DATA(lt_pi) = mo_be->post_items( mv_step ).
      DATA(lt_pt) = mo_be->tables_for_backend( mv_step ).

      DATA(lv_status) = to_upper( zif_rak_journey~get_val( 'STATUS' ) ).
      DATA(lv_final)  = xsdbool( lv_status = 'PAYMENT' OR lv_status = 'SUBMIT' ).

      DATA lt_pa TYPE /qnv/sbuild_attachments_tt.
      IF lv_final = abap_true.
        lt_pa = mo_be->attachments_for_backend( ).
      ENDIF.
      trace( |POST    screen { ls_step-bknd_screen } · guid { mv_case_guid } · { lines( lt_pi ) } items| &&
             | · { lines( lt_pt ) } table row(s) · { lines( lt_pa ) } attachment(s)| &&
             | · { COND string( WHEN lv_status IS NOT INITIAL THEN lv_status ELSE 'no STATUS' ) }| &&
             COND string( WHEN lv_final = abap_false AND mt_attach IS NOT INITIAL
                          THEN | · { lines( mt_attach ) } file(s) held in staging until the case is created|
                          ELSE `` ) ).
      LOOP AT lt_pt INTO DATA(ls_tr).
        AT NEW ui_table_name.
          trace( |POST    table { ls_tr-ui_table_name } - must equal the grid field name for the BAdI to join it| ).
        ENDAT.
      ENDLOOP.

      mo_bridge->post(
        EXPORTING
          iv_screen      = ls_step-bknd_screen
          iv_guid        = mv_case_guid
          it_items       = lt_pi
          it_tables      = lt_pt
          it_attachments = lt_pa
        IMPORTING
          ev_guid        = mv_case_guid
          ev_case        = DATA(lv_case_new)
          et_msg         = DATA(lt_m) ).
      take_case( lv_case_new ).
      trace( |POST    { lines( lt_m ) } message(s) back| ).

      READ TABLE lt_m WITH KEY type = 'Error' TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        APPEND LINES OF lt_m TO mt_msg.
        RETURN.
      ENDIF.
      APPEND LINES OF lt_m TO mt_msg.

      IF lv_final = abap_true.
        drop_attachments( ).
      ENDIF.
    ENDIF.

    rv_ok = abap_true.
  ENDMETHOD.


  METHOD zif_rak_journey~get_attachment_files.
    rt = mo_be->attachments_for_backend( ).
  ENDMETHOD.


  METHOD zif_rak_journey~get_backend_attachments.
    rt = mt_be_attach.
  ENDMETHOD.


  METHOD zif_rak_journey~get_backend_table.
    rs = VALUE #( mt_be_table[ field = to_upper( condense( iv_field ) ) ]-data OPTIONAL ).
  ENDMETHOD.


  METHOD zif_rak_journey~get_grid.
    DATA lt_ig TYPE tt_gcol.
    IF mo_grid->grid_check( EXPORTING iv_field = iv_field IMPORTING et_cols = lt_ig ) = abap_false.
      RETURN.
    ENDIF.
    rv = mo_grid->grid_to_json( safe_field( iv_field )-name ).
  ENDMETHOD.


  METHOD zif_rak_journey~get_grid_data.
    DATA lt_gc TYPE tt_gcol.
    IF mo_grid->grid_check( EXPORTING iv_field = iv_field IMPORTING et_cols = lt_gc ) = abap_false.
      RETURN.
    ENDIF.
    DATA(ls_fld) = safe_field( iv_field ).

    LOOP AT lt_gc INTO DATA(ls_c).
      APPEND ls_c-name TO rs-columns.
    ENDLOOP.

    FIELD-SYMBOLS <model> TYPE any.
    ASSIGN mr_model->* TO <model>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT to_upper( ls_fld-name ) OF STRUCTURE <model> TO FIELD-SYMBOL(<tab>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    FIELD-SYMBOLS <t> TYPE STANDARD TABLE.
    ASSIGN <tab> TO <t>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_cells TYPE zif_rak_journey=>tt_string.
    DATA lv_cell  TYPE string.
    LOOP AT <t> ASSIGNING FIELD-SYMBOL(<row>).
      CLEAR lt_cells.
      LOOP AT lt_gc INTO DATA(ls_c2).
        CLEAR lv_cell.
        ASSIGN COMPONENT ls_c2-name OF STRUCTURE <row> TO FIELD-SYMBOL(<c>).
        IF sy-subrc = 0.
          lv_cell = <c>.
        ENDIF.
        APPEND lv_cell TO lt_cells.
      ENDLOOP.
      APPEND lt_cells TO rs-rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey~render_upload.

    DATA(ls_f) = safe_field( iv_field ).

    IF ls_f-name IS INITIAL.
      trace_gate( |render_upload( '{ to_upper( iv_field ) }' ): no such field in this | &&
                  |journey. The popup will have no uploader.| ).
      io_view->message_strip( text = |Attachment field { to_upper( iv_field ) } is not configured|
                              type = 'Error' ).
      RETURN.
    ENDIF.
    IF to_upper( ls_f-type ) <> 'UPLOAD' AND ls_f-has_attach = abap_false.
      trace_gate( |render_upload( '{ to_upper( iv_field ) }' ): the field exists but is | &&
                  |type { ls_f-type } with no attachment flag, so there is nowhere to | &&
                  |stage a file.| ).
      io_view->message_strip( text = |Field { to_upper( iv_field ) } does not take attachments|
                              type = 'Error' ).
      RETURN.
    ENDIF.

    ensure_parts( ).
    mo_render->render_uploader( io_box   = io_view
                                iv_field = ls_f-name
                                iv_types = ls_f-attach_types
                                iv_maxmb = ls_f-attach_maxmb
                                iv_scope = '_POP'
                                iv_key   = iv_key ).
    mo_render->render_chips( io_box = io_view iv_field = ls_f-name iv_key = iv_key ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_grid.
    DATA lt_ig TYPE tt_gcol.
    IF mo_grid->grid_check( EXPORTING iv_field = iv_field IMPORTING et_cols = lt_ig ) = abap_false.
      RETURN.
    ENDIF.
    mo_grid->grid_from_json( iv_field = safe_field( iv_field )-name iv_json = iv_json ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_grid_data.
    DATA lt_gc TYPE tt_gcol.
    IF mo_grid->grid_check( EXPORTING iv_field = iv_field IMPORTING et_cols = lt_gc ) = abap_false.
      RETURN.
    ENDIF.
    DATA(ls_fld) = safe_field( iv_field ).

    DATA lt_src TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA(lv_byname) = xsdbool( is_data-columns IS NOT INITIAL ).
    LOOP AT lt_gc INTO DATA(ls_gc).
      DATA(lv_pos) = sy-tabix.
      DATA(lv_ci)  = 0.
      IF lv_byname = abap_false.
        lv_ci = lv_pos.
      ELSE.
        LOOP AT is_data-columns INTO DATA(lv_cn).
          IF to_upper( condense( lv_cn ) ) = ls_gc-name.
            lv_ci = sy-tabix.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
      APPEND lv_ci TO lt_src.
    ENDLOOP.

    IF lv_byname = abap_true AND is_data-rows IS NOT INITIAL.
      LOOP AT lt_src TRANSPORTING NO FIELDS WHERE table_line > 0.
        EXIT.
      ENDLOOP.
      IF sy-subrc <> 0.
        DATA lv_want TYPE string.
        LOOP AT lt_gc INTO DATA(ls_gcw).
          lv_want = COND #( WHEN lv_want IS INITIAL THEN ls_gcw-name
                            ELSE |{ lv_want }, { ls_gcw-name }| ).
        ENDLOOP.
        mt_msg = VALUE #( BASE mt_msg ( type = 'Warning'
          text = |Grid { iv_field }: none of the supplied column names match the spec. Expected { lv_want }. Nothing was written.| ) ).
        RETURN.
      ENDIF.
    ENDIF.

    DATA lt_obj   TYPE string_table.
    DATA lv_pairs TYPE string.
    DATA lv_cell  TYPE string.
    LOOP AT is_data-rows INTO DATA(lt_row).
      CLEAR lv_pairs.
      LOOP AT lt_gc INTO DATA(ls_gc2).
        DATA(lv_p) = sy-tabix.
        CLEAR lv_cell.
        DATA(lv_s) = VALUE #( lt_src[ lv_p ] OPTIONAL ).
        IF lv_s > 0.
          lv_cell = VALUE #( lt_row[ lv_s ] OPTIONAL ).
        ENDIF.
        DATA(lv_v)  = escape( val = lv_cell format = cl_abap_format=>e_json_string ).
        DATA(lv_kv) = |"{ ls_gc2-name }":"{ lv_v }"|.
        lv_pairs = COND #( WHEN lv_pairs IS INITIAL THEN lv_kv ELSE |{ lv_pairs },{ lv_kv }| ).
      ENDLOOP.
      APPEND |\{{ lv_pairs }\}| TO lt_obj.
    ENDLOOP.

    mo_grid->grid_from_json( iv_field = ls_fld-name
                             iv_json  = COND string( WHEN lt_obj IS INITIAL THEN ``
                                                     ELSE |[{ concat_lines_of( table = lt_obj sep = `,` ) }]| ) ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_hidden.
    mo_rules->set_prop( iv_field = iv_field iv_prop = 'HIDDEN' iv_on = iv_on ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_readonly.
    mo_rules->set_prop( iv_field = iv_field iv_prop = 'READONLY' iv_on = iv_on ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_reference.
    mv_ref_ovr = condense( iv_ref ).
  ENDMETHOD.


  METHOD zif_rak_journey~set_required.
    mo_rules->set_prop( iv_field = iv_field iv_prop = 'REQUIRED' iv_on = iv_on ).
  ENDMETHOD.
ENDCLASS.
