CLASS z2ui5_cl_core_action DEFINITION PUBLIC FINAL.

  PUBLIC SECTION.
    DATA mo_http_post TYPE REF TO z2ui5_cl_core_handler.
    DATA mo_app       TYPE REF TO z2ui5_cl_core_app.

    DATA ms_actual    TYPE z2ui5_if_core_types=>ty_s_actual.
    DATA ms_next      TYPE z2ui5_if_core_types=>ty_s_next.

    METHODS factory_system_startup
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

    METHODS factory_first_start
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

    METHODS factory_by_frontend
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

    METHODS factory_stack_leave
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

    METHODS factory_stack_call
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

    METHODS constructor
      IMPORTING
        val TYPE REF TO z2ui5_cl_core_handler.

  PROTECTED SECTION.
    METHODS prepare_app_stack
      IMPORTING
        val           TYPE z2ui5_if_core_types=>ty_s_next-o_app_leave
      RETURNING
        VALUE(result) TYPE REF TO z2ui5_cl_core_action.

  PRIVATE SECTION.
    METHODS reset_view_update_flags.
ENDCLASS.


CLASS z2ui5_cl_core_action IMPLEMENTATION.

  METHOD constructor.

    mo_http_post = val.
    mo_app = NEW #( ).

  ENDMETHOD.

  METHOD factory_by_frontend.

    result = NEW #( mo_http_post ).

    IF mo_http_post->mo_action->mo_app->mo_app IS BOUND.
      result->mo_app = mo_http_post->mo_action->mo_app.
    ELSE.
      result->mo_app = z2ui5_cl_core_app=>db_load( mo_http_post->ms_request-s_front-id ).
    ENDIF.

    result->mo_app->ms_draft-id      = z2ui5_cl_util=>uuid_get_c32( ).
    result->mo_app->ms_draft-id_prev = mo_http_post->ms_request-s_front-id.
    result->ms_actual-view           = mo_http_post->ms_request-s_front-view.

    IF mo_http_post->ms_request-o_model->is_empty( ) = abap_false.
      result->mo_app->model_json_parse( iv_view  = mo_http_post->ms_request-s_front-view
                                        io_model = mo_http_post->ms_request-o_model ).
    ENDIF.

    result->ms_actual-event       = mo_http_post->ms_request-s_front-event.
    result->ms_actual-t_event_arg = mo_http_post->ms_request-s_front-t_event_arg.

  ENDMETHOD.

  METHOD factory_first_start.

*---------------------------------------------------------------------------*
* WHAT MAY BE LAUNCHED FROM A URL. AN ALLOWLIST, NOT A DENYLIST.
*
* The CREATE OBJECT below takes its class name straight from the
* app_start URL parameter, so before this guard anyone who could reach
* /sap/bc/rest/egardcjs could instantiate ANY class implementing
* Z2UI5_IF_APP - on production, with no authority check in front of it.
* That is 35 classes in this package today, and the ones that matter are
* not the framework's:
*
*     ZCL_RAK_PAY_TEST, ZCL_RAK_PAY_ENGINE_TEST, ZCL_RAK_ATB_TEST,
*     ZCL_RAK_ATT_TEST, ZCL_RAK_BATTSCRAP_TEST, ZCL_RAK_DEMO_APP,
*     Z2UI5_CL_APP_HELLO_WORLD, ...
*
* A payment test harness reachable from a production URL is the whole
* finding. Closing the Quickstart landing page did not touch this - that
* was the ELSE branch of MAIN_BEGIN( ), this is the ELSEIF.
*
* ALLOWLIST, because a denylist is wrong by construction here: the risk
* is the app nobody remembered to list, and every new test class added
* next month is one of those. An allowlist fails closed.
*
* DEVELOPMENT IS EXEMPT, and only development. A developer launching
* their own test app is the normal way to work and breaking it would get
* this reverted rather than fixed. E10 is the one system where the
* landscape already accepts developer conveniences - the same line
* DEV_STUBS_OK( ) draws.
*
* SY-SYSID DIRECTLY, NOT ZCL_RAK_JOURNEY_UTIL=>IS_DEV( ). It says the
* same thing and the helper is better English, but this method is on the
* critical path of EVERY request: a static reference from the z2ui5 core
* to a CJS class means the core cannot load whenever that class is
* inactive, which would turn one failed activation into every journey
* down. The duplication is deliberate and cheap.
*
* THE LIST IS THE REAL APPS ONLY. ZCL_RAK_CJS and
* ZCL_RAK_JOURNEY_DESIGNER are authoring tools and stay on it because
* they are legitimately opened by URL - but they are NOT made safe by
* being here. The Studio carries its own gate (STUDIO_MODE( ) refuses
* and returns before it assembles anything); the designer's own gating
* is unread and is worth checking separately rather than assumed.
*---------------------------------------------------------------------------*
    DATA(lv_want) = to_upper( condense( CONV string(
      mo_http_post->ms_request-s_control-app_start ) ) ).

    IF sy-sysid <> 'E10'.
      IF lv_want <> `ZCL_RAK_JOURNEY_ENGINE`
        AND lv_want <> `ZCL_RAK_CJS`
        AND lv_want <> `ZCL_RAK_JOURNEY_DESIGNER`
        AND lv_want <> `ZCL_RAK_CJ_DASH`.
*       The same wording the Studio's own refusal uses, and for the same
*       reason: the caller has not been identified, so a refusal must not
*       confirm whether the class exists, whether the name was close, or
*       what would have been accepted instead.
*
*       RAISED ABOVE THE TRY, WHICH IS WHY THE GUARD SITS HERE RATHER
*       THAN NEXT TO THE CREATE OBJECT IT PROTECTS. That TRY ends in
*       CATCH cx_root and rewrites everything it catches into "App with
*       name X not found...", so a refusal raised inside it would have
*       been relabelled into a different message with the class name
*       echoed back. Z2UI5_CX_UTIL_ERROR is a CX_NO_CHECK subclass, so
*       no RAISING clause is needed on the method - which is also how
*       the existing raise in the CATCH below gets away with it.
        RAISE EXCEPTION TYPE z2ui5_cx_util_error
          EXPORTING
            val = `Not authorized.`.
      ENDIF.
    ENDIF.

    TRY.
        result = NEW #( mo_http_post ).

        IF mo_http_post->ms_request-s_control-app_start_draft IS NOT INITIAL.
          TRY.

              DATA(lo_app) = z2ui5_cl_core_app=>db_load( mo_http_post->ms_request-s_control-app_start_draft ).
              result->mo_app = lo_app.
              result->ms_actual-check_on_navigated = abap_true.
              result->ms_next-s_set-set_app_state_active = abap_true.
              result->mo_app->ms_draft-id_prev_app_stack = ``.
              result->mo_app->ms_draft-id = z2ui5_cl_util=>uuid_get_c32( ).
              RETURN.
            CATCH cx_root.
              " expired or invalid bookmark draft - fall through to a fresh
              " app start, but tell the user why the saved state is gone
              result->ms_next-s_set-s_msg_toast-text =
                `Bookmarked app state expired or could not be restored - starting with a fresh app`.
          ENDTRY.
        ENDIF.

        result->mo_app->ms_draft-id = z2ui5_cl_util=>uuid_get_c32( ).

        DATA li_app TYPE REF TO z2ui5_if_app.
        CREATE OBJECT li_app TYPE (mo_http_post->ms_request-s_control-app_start).
        result->mo_app->mo_app = li_app.
        li_app->id_draft = result->mo_app->ms_draft-id.

        result->ms_actual-check_on_navigated = abap_true.

      CATCH cx_root INTO DATA(x).
        RAISE EXCEPTION TYPE z2ui5_cx_util_error
          EXPORTING
            val      = |App with name { mo_http_post->ms_request-s_control-app_start } not found...|
            previous = x.
    ENDTRY.

  ENDMETHOD.

  METHOD factory_stack_call.

    result = prepare_app_stack( ms_next-o_app_call ).
    result->mo_app->ms_draft-id_prev_app_stack = mo_app->ms_draft-id.

  ENDMETHOD.

  METHOD factory_stack_leave.

    result = prepare_app_stack( ms_next-o_app_leave ).

    DATA(lo_draft) = NEW z2ui5_cl_core_srv_draft( ).

    " check for new app?
    IF lo_draft->check_exists( ms_next-o_app_leave->id_draft ) = abap_false.
      result->mo_app->ms_draft-id_prev_app_stack = mo_app->ms_draft-id_prev_app_stack.
      RETURN.
    ENDIF.

    " check for already existing app?
    IF mo_app->ms_draft-id_prev_app_stack IS NOT INITIAL.
      DATA(ls_draft) = lo_draft->read_info( mo_app->ms_draft-id_prev_app_stack ).
      result->mo_app->ms_draft-id_prev_app_stack = ls_draft-id_prev_app_stack.
    ENDIF.

  ENDMETHOD.

  METHOD factory_system_startup.

    result = NEW #( mo_http_post ).

    result->mo_app->ms_draft-id          = z2ui5_cl_util=>uuid_get_c32( ).
    result->ms_actual-check_on_navigated = abap_true.
    result->mo_app->mo_app               = z2ui5_cl_app_startup=>factory( ).

    CAST z2ui5_if_app( result->mo_app->mo_app )->id_draft = result->mo_app->ms_draft-id.

  ENDMETHOD.

  METHOD reset_view_update_flags.

    SPLIT z2ui5_if_core_types=>cs_view_slot_list AT `,` INTO TABLE DATA(lt_slot).
    LOOP AT lt_slot INTO DATA(lv_slot).
      ASSIGN COMPONENT lv_slot OF STRUCTURE ms_next-s_set TO FIELD-SYMBOL(<slot>).
      ASSERT sy-subrc = 0.
      ASSIGN COMPONENT `CHECK_UPDATE_MODEL` OF STRUCTURE <slot> TO FIELD-SYMBOL(<check_update_model>).
      ASSERT sy-subrc = 0.
      <check_update_model> = abap_false.
    ENDLOOP.

  ENDMETHOD.

  METHOD prepare_app_stack.

    mo_app->db_save( ).

    " val is always the ms_next-o_app_leave / ms_next-o_app_call reference
    " itself (see factory_stack_leave / factory_stack_call), so an already
    " assigned draft id is kept as is
    IF val->id_draft IS INITIAL.
      val->id_draft = z2ui5_cl_util=>uuid_get_c32( ).
    ENDIF.

    result = NEW #( mo_http_post ).
    TRY.
        result->mo_app = z2ui5_cl_core_app=>db_load_by_app( val ).
      CATCH cx_root.
        result->mo_app->mo_app = val.
    ENDTRY.

    result->mo_app->ms_draft-id          = val->id_draft.

    result->mo_app->ms_draft-id_prev     = mo_app->ms_draft-id.
    result->mo_app->ms_draft-id_prev_app = mo_app->ms_draft-id.
    result->ms_actual-check_on_navigated = abap_true.
    result->ms_next-s_set                = ms_next-s_set.

    result->reset_view_update_flags( ).

    IF ms_next-next_event IS NOT INITIAL.
      result->ms_actual-event = ms_next-next_event.
    ELSEIF lines( ms_next-s_set-s_follow_up_action-custom_js ) > 0.
      " backward compatibility: derive the next event from a legacy
      " follow_up_action( _event( ) ) snippet ( deprecated mechanism )
      DATA(lv_action) = ms_next-s_set-s_follow_up_action-custom_js[ 1 ].
      SPLIT lv_action AT `.eB(['` INTO DATA(lv_dummy)
            result->ms_actual-event.
      SPLIT result->ms_actual-event AT `']` INTO result->ms_actual-event lv_dummy.
    ENDIF.
    result->ms_actual-r_data = ms_next-r_data.

    CLEAR result->ms_next-s_set-s_msg_box.
    CLEAR result->ms_next-s_set-s_msg_toast.

  ENDMETHOD.

ENDCLASS.
