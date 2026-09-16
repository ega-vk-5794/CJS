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
*                THE THREE THAT WERE MISSING, and the standard is "every
*                character the citizen can see", not "every column somebody
*                remembered".
*
*                COLUMN - ZRAK_T_JNY_COL's ZLABEL / ZLABEL_AR. Every grid
*                header on every journey was invisible to this: not counted as
*                missing, not exported, not backfilled, not imported. The
*                Studio maintains that pair as Label and Label (AR), so it is
*                an ordinary translatable pair and round-trips like any other.
                 column    TYPE c LENGTH 10 VALUE 'COLUMN',
*                SECTION - ZSECTION / ZSECTION_AR. ZSECTION was read already
*                but only as the BLOCK KEY for grouping, never emitted as a
*                text of its own, so section headings never reached a
*                translator and ZSECTION_AR was never written. It is a heading
*                the citizen reads, and REPO->PICK( ) resolves the pair at
*                runtime like every other.
                 section   TYPE c LENGTH 10 VALUE 'SECTION',
*                NOAR - a visible text with NO ARABIC COLUMN TO PUT ONE IN.
*                ATTACH_LABEL and DESCR are both rendered and neither has an
*                _AR twin in the DDIC, so they cannot be translated in config
*                at all. Emitting them as ordinary pairs would be a lie: the
*                export would collect an Arabic the import has nowhere to
*                write. They are emitted with the Arabic side permanently
*                blank so they appear in the DETAIL and GAP runs as work that
*                needs a DDIC column or a TEXT:@nnn indirection - a real
*                finding rather than a silent omission.
                 noar      TYPE c LENGTH 10 VALUE 'NOAR',
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

    SELECT step_id, field_name, zsection, zsection_ar, zlabel, zlabel_ar,
           placeholder, placeholder_ar, msg, msg_ar,
           attach_label, descr
      FROM zrak_t_jny_fld
      WHERE journey_id = @lv_id
      ORDER BY step_id, seqnr
      INTO TABLE @DATA(lt_fld).

*   SECTION HEADINGS, ONCE EACH. A section is a property of the step, not of
*   the field - ten fields carrying ZSECTION 'School Details' are one heading
*   on screen, and emitting it ten times would hand a translator the same
*   sentence ten times and let them answer it ten different ways.
*
*   KEYED ON STEP + SECTION, because the same wording can legitimately head a
*   section on two different steps and those are two rows to translate: the
*   Arabic is stored per field, so writing one back has to know which step's
*   fields to write to.
    TYPES: BEGIN OF ty_sec,
             step TYPE zif_rak_cj_text_src=>ty_key,
             sec  TYPE zif_rak_cj_text_src=>ty_key,
           END OF ty_sec.
    DATA lt_seen TYPE STANDARD TABLE OF ty_sec WITH EMPTY KEY.

    LOOP AT lt_fld ASSIGNING FIELD-SYMBOL(<ls_s>) WHERE zsection IS NOT INITIAL.
      DATA(ls_key) = VALUE ty_sec( step = CONV #( <ls_s>-step_id )
                                   sec  = CONV #( <ls_s>-zsection ) ).
      IF line_exists( lt_seen[ table_line = ls_key ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_key TO lt_seen.

      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_s>-step_id )
                     iv_block   = CONV #( <ls_s>-zsection )
*                    THE SECTION IS ITS OWN ELEMENT. Keyed on the field it was
*                    first seen on and the import would write one field's
*                    ZSECTION_AR and leave the other nine disagreeing.
                     iv_elem    = space
                     iv_kind    = c_kind-section
                     iv_en      = <ls_s>-zsection
                     iv_ar      = <ls_s>-zsection_ar
           CHANGING  ct_txt     = rt_txt ).
    ENDLOOP.

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

*     ---- VISIBLE, AND WITH NOWHERE TO PUT AN ARABIC -------------------
*     ATTACH_LABEL is the caption RENDER_ATTACH( ) draws over an uploader and
*     DESCR is the helper line under a field. Both reach the screen and
*     NEITHER HAS AN _AR COLUMN in ZRAK_T_JNY_FLD - checked against the DDIC,
*     not assumed.
*
*     Emitted with the Arabic side permanently blank, on purpose. They then
*     show up in DETAIL and in GAP as work, which is the truth: an Arabic
*     reader sees English here today and no amount of translating fixes it
*     without either a DDIC column or a TEXT:@nnn / OTR: indirection. Leaving
*     them out would have made the report say a journey was fully translated
*     while two kinds of visible text were still English.
      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_f>-step_id )
                     iv_block   = CONV #( <ls_f>-zsection )
                     iv_elem    = CONV #( <ls_f>-field_name )
                     iv_kind    = c_kind-noar
                     iv_en      = <ls_f>-attach_label
                     iv_ar      = space
           CHANGING  ct_txt     = rt_txt ).

      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_f>-step_id )
                     iv_block   = CONV #( <ls_f>-zsection )
                     iv_elem    = CONV #( <ls_f>-field_name )
                     iv_kind    = c_kind-noar
                     iv_en      = <ls_f>-descr
                     iv_ar      = space
           CHANGING  ct_txt     = rt_txt ).

    ENDLOOP.

*   ---- GRID COLUMN HEADERS -------------------------------------------
*   ZRAK_T_JNY_COL was not read here at all, so every grid header on every
*   journey was invisible to this report - D003's Owners grid, D021's four fee
*   grids, M029's five consultant columns. ZLABEL and ZLABEL_AR are real
*   columns the Studio maintains as Label and Label (AR), so this is an
*   ordinary pair and needs no new mechanism: it exports, backfills, gaps and
*   imports exactly like a field label.
*
*   BLOCK IS THE GRID, ELEM IS THE COLUMN, which mirrors how options are keyed
*   (block = field, elem = opt_key) - so two grids on one step with a column
*   of the same name stay two rows.
    SELECT step_id, field_name, col_name, zlabel, zlabel_ar
      FROM zrak_t_jny_col
      WHERE journey_id = @lv_id
      ORDER BY step_id, field_name, seqnr
      INTO TABLE @DATA(lt_col).

    LOOP AT lt_col ASSIGNING FIELD-SYMBOL(<ls_c>).
      add( EXPORTING iv_journey = CONV #( lv_id )
                     iv_step    = CONV #( <ls_c>-step_id )
                     iv_block   = CONV #( <ls_c>-field_name )
                     iv_elem    = CONV #( <ls_c>-col_name )
                     iv_kind    = c_kind-column
                     iv_en      = <ls_c>-zlabel
                     iv_ar      = <ls_c>-zlabel_ar
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

        WHEN c_kind-column.
          UPDATE zrak_t_jny_col SET zlabel = @lv_en, zlabel_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND field_name = @<ls_t>-block_id
              AND col_name   = @<ls_t>-elem_id.

*       EVERY FIELD OF THE SECTION, NOT ONE OF THEM. A section heading is
*       stored per FIELD - ten fields in 'School Details' each carry their own
*       copy of ZSECTION and ZSECTION_AR - so writing the row the export was
*       keyed on would leave nine fields disagreeing with the tenth, and
*       REPO->PICK( ) reads whichever it meets first. Keyed on the OLD English
*       because that is what the file was exported against and what every one
*       of those fields still holds.
        WHEN c_kind-section.
          UPDATE zrak_t_jny_fld SET zsection = @lv_en, zsection_ar = @lv_ar
            WHERE journey_id = @lv_id
              AND step_id    = @<ls_t>-step_id
              AND zsection   = @<ls_t>-block_id.

*       NOAR IS READ-ONLY BY CONSTRUCTION. ATTACH_LABEL and DESCR have no
*       Arabic column, so there is nothing to write an Arabic into - and
*       writing the ENGLISH back from a translation file would let a
*       translator silently reword a caption while believing they were
*       translating it. Reported, never written.
        WHEN c_kind-noar.
          CONTINUE.

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
