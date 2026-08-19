CLASS zcl_rak_adv_demo_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~get_table         REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help     REDEFINITION.
    METHODS zif_rak_journey_logic~on_change         REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_feedback       REDEFINITION.
ENDCLASS.



CLASS ZCL_RAK_ADV_DEMO_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSE'.
        rs_data-columns = VALUE #( ( `License` ) ( `School` ) ( `Authority` ) ( `Curriculum` ) ).
        rs_data-rows = VALUE #(
          ( VALUE #( ( `0000002500010` ) ( `New School B1` )       ( `DED` ) ( `MOE Curriculum` ) ) )
          ( VALUE #( ( `0000002500027` ) ( `RAK Academy EN3` )     ( `DED` ) ( `British` ) ) )
          ( VALUE #( ( `0000002500034` ) ( `Little Flowers KG` )   ( `DED` ) ( `American` ) ) ) ).

      WHEN 'SCHOOL_INFO'.
        DATA(lv_lic) = io_ctx->get_val( 'LICENSE' ).
        rs_data-columns = VALUE #( ( `Field` ) ( `Value` ) ).
        rs_data-rows = VALUE #(
          ( VALUE #( ( `License Number` )         ( COND #( WHEN lv_lic IS NOT INITIAL THEN lv_lic ELSE `0000002500010` ) ) ) )
          ( VALUE #( ( `School Name (EN)` )        ( `New School B1` ) ) )
          ( VALUE #( ( `Trade License Authority` ) ( `DED` ) ) )
          ( VALUE #( ( `Trade License Number` )    ( `5506` ) ) )
          ( VALUE #( ( `Curriculum` )              ( `United Arab Emirates - MOE` ) ) )
          ( VALUE #( ( `Location` )                ( `108 Khor Khwair` ) ) ) ).

      WHEN 'OWNERS'.
        rs_data-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Shares` ) ( `Mobile` ) ).
        rs_data-rows = VALUE #(
          ( VALUE #( ( `Shrinu A. B. Javeed` ) ( `Indian` ) ( `100.00` ) ( `+971505919132` ) ) ) ).

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = 'CONSENT'.
      io_ctx->set_val( iv_name  = 'MEDIA_HINT'
                       iv_value = COND #( WHEN io_ctx->get_val( 'CONSENT' ) = 'Y'
                                          THEN 'Required because participants require consent'
                                          ELSE 'Optional unless participants require consent' ) ).
    ENDIF.
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

    DATA(lv_start) = io_ctx->get_val( 'START_DATE' ).
    DATA(lv_end)   = io_ctx->get_val( 'END_DATE' ).
    IF lv_start IS NOT INITIAL AND lv_end IS NOT INITIAL AND lv_end < lv_start.
      APPEND VALUE #( type = 'Error' text = 'End date cannot be before the request date.' ) TO rt.
    ENDIF.

    IF io_ctx->get_val( 'CONSENT' ) = 'Y' AND io_ctx->get_val( 'MEDIA_DOC' ) IS INITIAL.
      APPEND VALUE #( type = 'Error' text = 'Media Consent Letter is required when participants require consent.' ) TO rt.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_feedback.
    " placeholder: persist iv_rating (EX/GD/AV/PR/VP) + iv_comment to your table here
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
    CASE to_upper( iv_field ).
      WHEN 'PLATFORM'.
        rt = VALUE #(
          ( key = 'SM'  text = 'Social Media' )
          ( key = 'TV'  text = 'Television' )
          ( key = 'RAD' text = 'Radio' )
          ( key = 'PRT' text = 'Print' )
          ( key = 'OUT' text = 'Outdoor / Billboard' )
          ( key = 'WEB' text = 'School Website' ) ).
      WHEN 'ADV_TYPE'.
        rt = VALUE #(
          ( key = 'TXT' text = 'Text' )
          ( key = 'PHO' text = 'Photos' )
          ( key = 'VID' text = 'Videos' )
          ( key = 'AUD' text = 'Audio' ) ).
    ENDCASE.
  ENDMETHOD.
ENDCLASS.
