CLASS zcl_rak_cj_text_src_cfg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_rak_cj_text_src.

    CONSTANTS: BEGIN OF c_kind,
                 title     TYPE c LENGTH 10 VALUE 'TITLE',
                 subtitle  TYPE c LENGTH 10 VALUE 'SUBTITLE',
                 step      TYPE c LENGTH 10 VALUE 'STEP',
                 label     TYPE c LENGTH 10 VALUE 'LABEL',
                 placehold TYPE c LENGTH 10 VALUE 'PLACEHOLD',
                 msg       TYPE c LENGTH 10 VALUE 'MSG',
                 option    TYPE c LENGTH 10 VALUE 'OPTION',
               END OF c_kind.

  PRIVATE SECTION.

    METHODS add
      IMPORTING iv_journey TYPE zif_rak_cj_text_src=>ty_key
                iv_step    TYPE zif_rak_cj_text_src=>ty_key
                iv_block   TYPE zif_rak_cj_text_src=>ty_key
                iv_elem    TYPE zif_rak_cj_text_src=>ty_key
                iv_kind    TYPE c
                iv_en      TYPE clike
                iv_ar      TYPE clike
      CHANGING  ct_txt     TYPE zif_rak_cj_text_src=>ty_t_txt.

ENDCLASS.



CLASS ZCL_RAK_CJ_TEXT_SRC_CFG IMPLEMENTATION.


  METHOD add.

    IF iv_en IS INITIAL AND iv_ar IS INITIAL.
      RETURN.
    ENDIF.

    APPEND VALUE #( journey  = iv_journey
                    step_id  = iv_step
                    block_id = iv_block
                    elem_id  = iv_elem
                    txt_kind = iv_kind
                    text_en  = iv_en
                    text_ar  = iv_ar ) TO ct_txt.

  ENDMETHOD.


  METHOD zif_rak_cj_text_src~list_journeys.

    SELECT DISTINCT journey_id FROM zrak_t_jny
      ORDER BY journey_id
      INTO TABLE @DATA(lt_jny).

    LOOP AT lt_jny ASSIGNING FIELD-SYMBOL(<ls_j>).
      APPEND CONV zif_rak_cj_text_src=>ty_key( <ls_j>-journey_id ) TO rt_journey.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_cj_text_src~read_journey.

    DATA(lv_id) = to_upper( CONV string( iv_journey ) ).

    SELECT SINGLE journey_id, title, title_ar, subtitle, subtitle_ar
      FROM zrak_t_jny
      WHERE journey_id = @lv_id
      INTO @DATA(ls_h).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    add( EXPORTING iv_journey = CONV #( ls_h-journey_id )
                   iv_step    = space
                   iv_block   = space
                   iv_elem    = space
                   iv_kind    = c_kind-title
                   iv_en      = ls_h-title
                   iv_ar      = ls_h-title_ar
         CHANGING  ct_txt     = rt_txt ).

    add( EXPORTING iv_journey = CONV #( ls_h-journey_id )
                   iv_step    = space
                   iv_block   = space
                   iv_elem    = space
                   iv_kind    = c_kind-subtitle
                   iv_en      = ls_h-subtitle
                   iv_ar      = ls_h-subtitle_ar
         CHANGING  ct_txt     = rt_txt ).

    SELECT step_id, title, title_ar FROM zrak_t_jny_step
      WHERE journey_id = @lv_id
      ORDER BY seqnr
      INTO TABLE @DATA(lt_step).

    LOOP AT lt_step ASSIGNING FIELD-SYMBOL(<ls_s>).
      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_s>-step_id )
                     iv_block   = space
                     iv_elem    = space
                     iv_kind    = c_kind-step
                     iv_en      = <ls_s>-title
                     iv_ar      = <ls_s>-title_ar
           CHANGING  ct_txt     = rt_txt ).
    ENDLOOP.

    SELECT step_id, field_name, zsection, zlabel, zlabel_ar,
           placeholder, placeholder_ar, msg, msg_ar
      FROM zrak_t_jny_fld
      WHERE journey_id = @lv_id
      ORDER BY step_id, seqnr
      INTO TABLE @DATA(lt_fld).

    LOOP AT lt_fld ASSIGNING FIELD-SYMBOL(<ls_f>).

      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_f>-step_id )
                     iv_block   = CONV #( <ls_f>-zsection )
                     iv_elem    = CONV #( <ls_f>-field_name )
                     iv_kind    = c_kind-label
                     iv_en      = <ls_f>-zlabel
                     iv_ar      = <ls_f>-zlabel_ar
           CHANGING  ct_txt     = rt_txt ).

      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_f>-step_id )
                     iv_block   = CONV #( <ls_f>-zsection )
                     iv_elem    = CONV #( <ls_f>-field_name )
                     iv_kind    = c_kind-placehold
                     iv_en      = <ls_f>-placeholder
                     iv_ar      = <ls_f>-placeholder_ar
           CHANGING  ct_txt     = rt_txt ).

      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_f>-step_id )
                     iv_block   = CONV #( <ls_f>-zsection )
                     iv_elem    = CONV #( <ls_f>-field_name )
                     iv_kind    = c_kind-msg
                     iv_en      = <ls_f>-msg
                     iv_ar      = <ls_f>-msg_ar
           CHANGING  ct_txt     = rt_txt ).

    ENDLOOP.

    SELECT step_id, field_name, opt_key, opt_text, opt_text_ar
      FROM zrak_t_jny_opt
      WHERE journey_id = @lv_id
      ORDER BY step_id, field_name, seqnr
      INTO TABLE @DATA(lt_opt).

    LOOP AT lt_opt ASSIGNING FIELD-SYMBOL(<ls_o>).
      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_o>-step_id )
                     iv_block   = CONV #( <ls_o>-field_name )
                     iv_elem    = CONV #( <ls_o>-opt_key )
                     iv_kind    = c_kind-option
                     iv_en      = <ls_o>-opt_text
                     iv_ar      = <ls_o>-opt_text_ar
           CHANGING  ct_txt     = rt_txt ).
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_cj_text_src~write.

    DATA lt_touched TYPE STANDARD TABLE OF zif_rak_cj_text_src=>ty_key WITH EMPTY KEY.

    LOOP AT it_txt ASSIGNING FIELD-SYMBOL(<ls_t>).

      DATA(lv_id) = to_upper( CONV string( <ls_t>-journey ) ).
      DATA(lv_en) = <ls_t>-text_en.
      DATA(lv_ar) = <ls_t>-text_ar.

      CASE <ls_t>-txt_kind.

        WHEN c_kind-title.
          UPDATE zrak_t_jny SET title = @lv_en, title_ar = @lv_ar
            WHERE journey_id = @lv_id.

        WHEN c_kind-subtitle.
          UPDATE zrak_t_jny SET subtitle = @lv_en, subtitle_ar = @lv_ar
            WHERE journey_id = @lv_id.

        WHEN c_kind-step.
          UPDATE zrak_t_jny_step SET title = @lv_en, title_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id.

        WHEN c_kind-label.
          UPDATE zrak_t_jny_fld SET zlabel = @lv_en, zlabel_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND field_name = @<ls_t>-elem_id.

        WHEN c_kind-placehold.
          UPDATE zrak_t_jny_fld SET placeholder = @lv_en, placeholder_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND field_name = @<ls_t>-elem_id.

        WHEN c_kind-msg.
          UPDATE zrak_t_jny_fld SET msg = @lv_en, msg_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND field_name = @<ls_t>-elem_id.

        WHEN c_kind-option.
          UPDATE zrak_t_jny_opt SET opt_text = @lv_en, opt_text_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND field_name = @<ls_t>-block_id
              AND opt_key    = @<ls_t>-elem_id.

        WHEN OTHERS.
          CONTINUE.

      ENDCASE.

      IF NOT line_exists( lt_touched[ table_line = <ls_t>-journey ] ).
        APPEND <ls_t>-journey TO lt_touched.
      ENDIF.

    ENDLOOP.

    COMMIT WORK AND WAIT.

    LOOP AT lt_touched ASSIGNING FIELD-SYMBOL(<lv_j>).
      zcl_rak_cj_cfg_cache=>invalidate( CONV string( <lv_j> ) ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
