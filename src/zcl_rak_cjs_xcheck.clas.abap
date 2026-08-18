CLASS zcl_rak_cjs_xcheck DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
*   Cross-checks a CJS journey against the ShapeIt configuration it posts to.
*
*   Everything here compares ZRAK_T_JNY* against /QNV/SB_UI_DEFIN and
*   ZEGA_T_CJ_2_OBJ. It never opens a case, never calls a BAdI and writes
*   nothing, so it is safe to run on any system at any time.
*
*   It exists because the two sides fail SILENTLY when they disagree. A step
*   pointing at a screen that has no /QNV rows still renders, still validates and
*   still posts - the BAdI reads an empty LT_DEFIN and does nothing. There is no
*   error anywhere. The developer sees a working form and a missing case.

    TYPES: BEGIN OF ty_msg,
             sev  TYPE c LENGTH 1,        " E blocker · W risk · I note
             rule TYPE string,
             step TYPE string,
             text TYPE string,
           END OF ty_msg.
    TYPES tt_msg TYPE STANDARD TABLE OF ty_msg WITH EMPTY KEY.

    CLASS-METHODS check
      IMPORTING iv_journey    TYPE zrak_t_jny-journey_id
      RETURNING VALUE(rt_msg) TYPE tt_msg.

  PRIVATE SECTION.
    CLASS-DATA gs_jny  TYPE zrak_t_jny.
    CLASS-DATA gt_step TYPE STANDARD TABLE OF zrak_t_jny_step WITH EMPTY KEY.
    CLASS-DATA gt_fld  TYPE STANDARD TABLE OF zrak_t_jny_fld WITH EMPTY KEY.
    CLASS-DATA gt_defn TYPE STANDARD TABLE OF /qnv/sb_ui_defin WITH EMPTY KEY.
    CLASS-DATA gt_msg  TYPE tt_msg.

    CLASS-METHODS add IMPORTING iv_sev  TYPE c
                                iv_rule TYPE string
                                iv_step TYPE string OPTIONAL
                                iv_text TYPE string.
    CLASS-METHODS x01_backend_wiring.
    CLASS-METHODS x02_badi_registered.
    CLASS-METHODS x03_screens_exist.
    CLASS-METHODS x04_screen_shared.
    CLASS-METHODS x11_badi_screen_literals.
    CLASS-METHODS x12_screen_family.
    CLASS-METHODS x05_step_order.
    CLASS-METHODS x06_pay_screen.
    CLASS-METHODS x08_status_carrier.
    CLASS-METHODS x09_grid_contract.
    CLASS-METHODS x10_next_requires.
ENDCLASS.



CLASS ZCL_RAK_CJS_XCHECK IMPLEMENTATION.


  METHOD add.
    APPEND VALUE #( sev = iv_sev rule = iv_rule step = iv_step text = iv_text ) TO gt_msg.
  ENDMETHOD.


  METHOD check.
    CLEAR: gs_jny, gt_step, gt_fld, gt_defn, gt_msg.

    SELECT SINGLE * FROM zrak_t_jny INTO @gs_jny WHERE journey_id = @iv_journey.
    IF sy-subrc <> 0.
      rt_msg = VALUE #( ( sev = 'E' rule = 'X00'
                          text = |Journey { iv_journey } does not exist in ZRAK_T_JNY.| ) ).
      RETURN.
    ENDIF.

    SELECT * FROM zrak_t_jny_step INTO TABLE @gt_step
      WHERE journey_id = @iv_journey ORDER BY seqnr.
    SELECT * FROM zrak_t_jny_fld INTO TABLE @gt_fld
      WHERE journey_id = @iv_journey ORDER BY step_id, seqnr.

    IF gs_jny-bknd_active = abap_true AND gs_jny-bknd_category IS NOT INITIAL.
      SELECT * FROM /qnv/sb_ui_defin INTO TABLE @gt_defn
        WHERE category = @gs_jny-bknd_category.
    ENDIF.

    x01_backend_wiring( ).

*   Everything past here compares against ShapeIt. With no backend there is
*   nothing to compare to, and reporting ten missing screens for a journey that
*   deliberately has none is how a checker gets ignored.
    IF gs_jny-bknd_active = abap_true.
      x02_badi_registered( ).
      x03_screens_exist( ).
      x04_screen_shared( ).
      x11_badi_screen_literals( ).
      x12_screen_family( ).
      x05_step_order( ).
      x09_grid_contract( ).
    ENDIF.

    x06_pay_screen( ).
    x08_status_carrier( ).
    x10_next_requires( ).

    IF gt_msg IS INITIAL.
      add( iv_sev  = 'I'
           iv_rule = 'OK'
           iv_text = |{ iv_journey }: CJS and ShapeIt agree on every screen checked.| ).
    ENDIF.
    rt_msg = gt_msg.
  ENDMETHOD.


  METHOD x01_backend_wiring.
*   All five move together. BKND_ACTIVE on its own is the worst of the partial
*   states: Next validates, renders, advances and reaches no backend, and there
*   is no error - because a journey with no backend is a legitimate thing to be.
    IF gs_jny-bknd_active = abap_false.
      IF gs_jny-bknd_category IS NOT INITIAL OR gs_jny-bknd_journey IS NOT INITIAL.
        add( iv_sev  = 'W'
             iv_rule = 'X01'
             iv_text = 'BKND_ACTIVE is blank but the backend columns are filled. ' &&
                       'Nothing this journey collects will reach ShapeIt.' ).
      ENDIF.
      RETURN.
    ENDIF.

    IF gs_jny-bknd_category IS INITIAL.
      add( iv_sev  = 'E'
           iv_rule = 'X01'
           iv_text = 'BKND_CATEGORY is empty. Every /QNV lookup keys on it, so no ' &&
                     'screen can resolve and every post reaches an empty definition.' ).
    ENDIF.
    IF gs_jny-bknd_journey IS INITIAL.
      add( iv_sev  = 'E'
           iv_rule = 'X01'
           iv_text = 'BKND_JOURNEY is empty. It is sent as PARAM2 and is what the read FM ' &&
                     'falls back to when the VIBDRO lookup on PARAM1 misses - which is ' &&
                     'every non-object journey. With it blank no BAdI is selected.' ).
    ENDIF.
*   BLANK IS CORRECT and this used to say otherwise. ZCL_RAK_QNV_BRIDGE->CONSTRUCTOR
*   fills both when they are empty:
*
*       IF ms_config-backend-fm_post IS INITIAL.
*         ms_config-backend-fm_post = 'ZFM_EGA_CJ_FW_POST_N'.
*
*   There is one post FM and one read FM for every journey, so leaving them blank
*   is the normal case and the Studio label says so. Reporting it as a blocker was
*   noise on top of a rule that had nothing to add.
*
*   What IS worth checking is a name that was typed. An FM that does not exist
*   fails at CALL FUNCTION, inside the bridge's TRY, and comes back as a message
*   rather than a dump - so a typo here looks like a backend that answered badly.
    IF gs_jny-bknd_fm_post IS NOT INITIAL.
      SELECT SINGLE funcname FROM tfdir INTO @DATA(lv_fp)
        WHERE funcname = @gs_jny-bknd_fm_post.
      IF sy-subrc <> 0.
        add( iv_sev  = 'E'
             iv_rule = 'X01'
             iv_text = |BKND_FM_POST names { gs_jny-bknd_fm_post }, which does not exist. | &&
                       |CALL FUNCTION fails inside the bridge's TRY, so every post comes back | &&
                       |as a message and looks like a backend that answered badly. Leave it | &&
                       |blank to get the framework default.| ).
      ENDIF.
    ENDIF.

    IF gs_jny-bknd_fm_read IS NOT INITIAL.
      SELECT SINGLE funcname FROM tfdir INTO @DATA(lv_fr)
        WHERE funcname = @gs_jny-bknd_fm_read.
      IF sy-subrc <> 0.
        add( iv_sev  = 'E'
             iv_rule = 'X01'
             iv_text = |BKND_FM_READ names { gs_jny-bknd_fm_read }, which does not exist. | &&
                       |Leave it blank to get the framework default.| ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD x02_badi_registered.
*   NOT a registration check, and it was written as one - wrongly. The BAdI is
*   selected by GET BADI cj_badi FILTERS journey_type = journeytype, which is
*   enhancement-implementation configuration and lives nowhere this class can
*   read. D026 has no row here and works end to end, which is what showed it up.
*
*   What this table actually feeds is MT_CONFIG in ZCL_EGA_CJ_DOK_ABS->CONSTRUCTOR.
*   Empty is harmless unless the handler reads it, so this is a note and not a
*   finding - a checker whose blockers are wrong teaches everybody to skip the
*   ones that are right.
    SELECT SINGLE journeyid FROM zega_t_cj_2_obj INTO @DATA(lv_j)
      WHERE journeyid = @gs_jny-bknd_journey.
    IF sy-subrc <> 0.
      add( iv_sev  = 'I'
           iv_rule = 'X02'
           iv_text = |No ZEGA_T_CJ_2_OBJ row for { gs_jny-bknd_journey }, so MT_CONFIG is | &&
                     |empty in the BAdI constructor. Harmless unless the handler reads it. | &&
                     |BAdI selection itself is by filter and is not checked here.| ).
    ENDIF.
  ENDMETHOD.


  METHOD x03_screens_exist.
    LOOP AT gt_step INTO DATA(ls_step).
      IF ls_step-bknd_screen IS INITIAL.
        add( iv_sev  = 'W'
             iv_rule = 'X03'
             iv_step = |{ ls_step-step_id }|
             iv_text = 'No BKND_SCREEN. This step posts nowhere - every field on it ' &&
                       'renders, survives the round trip and reaches the BAdI as nothing.' ).
        CONTINUE.
      ENDIF.
      READ TABLE gt_defn TRANSPORTING NO FIELDS
        WITH KEY screen_name = ls_step-bknd_screen.
      IF sy-subrc <> 0.
        add( iv_sev  = 'E'
             iv_rule = 'X03'
             iv_step = |{ ls_step-step_id }|
             iv_text = |BKND_SCREEN { ls_step-bknd_screen } has no rows in /QNV/SB_UI_DEFIN | &&
                       |for category { gs_jny-bknd_category }. The BAdI's LT_DEFIN comes back | &&
                       |empty, so the post is accepted and silently does nothing.| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD x04_screen_shared.
*   A screen shared ACROSS journeys is normal and deliberate - a licence list, a
*   applicant panel, an attachment page. Nothing about it breaks CJS: the BAdI is
*   selected from PARAM2 = BKND_JOURNEY, and ZEGA_T_CJ_UI_MAP is keyed by journey,
*   so the right implementation and the right mapping still run.
*
*   It is reported because of what it means for CHANGE. A /QNV field added,
*   renamed or resequenced on a shared screen changes every journey that posts to
*   it, at once, and nothing in either configuration says so. A developer editing
*   the licence list to add a column for their own journey has no way of knowing
*   how many others they just touched.
*
*   Information, not a finding. Nothing here is wrong.
    LOOP AT gt_step INTO DATA(ls_step) WHERE bknd_screen IS NOT INITIAL.

      SELECT journey_id FROM zrak_t_jny_step INTO TABLE @DATA(lt_other)
        WHERE bknd_screen = @ls_step-bknd_screen
          AND journey_id <> @gs_jny-journey_id
        ORDER BY journey_id.
      DELETE ADJACENT DUPLICATES FROM lt_other COMPARING journey_id.

      IF lt_other IS NOT INITIAL.
        DATA lt_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.
        CLEAR lt_names.
        LOOP AT lt_other INTO DATA(ls_o).
          APPEND |{ ls_o-journey_id }| TO lt_names.
          IF lines( lt_names ) >= 8.
            EXIT.
          ENDIF.
        ENDLOOP.
        add( iv_sev  = 'I'
             iv_rule = 'X04'
             iv_step = |{ ls_step-step_id }|
             iv_text = |Screen { ls_step-bknd_screen } is shared with { lines( lt_other ) } | &&
                       |other journey(s): { concat_lines_of( table = lt_names sep = `, ` ) }| &&
                       |{ COND string( WHEN lines( lt_other ) > 8 THEN ` ...` ELSE `` ) }. | &&
                       |Correct, and worth knowing before anyone edits its /QNV rows - a | &&
                       |column added here lands in all of them.| ).
      ENDIF.

*     Within ONE journey it is a different matter. Two steps posting to the same
*     screen means the backend receives two commits it cannot tell apart, and any
*     BAdI branching on SCREENNAME will take the same branch for both.
      LOOP AT gt_step INTO DATA(ls_twin)
           WHERE bknd_screen = ls_step-bknd_screen AND step_id <> ls_step-step_id.
        IF ls_twin-seqnr > ls_step-seqnr.
          add( iv_sev  = 'W'
               iv_rule = 'X04'
               iv_step = |{ ls_step-step_id }|
               iv_text = |Steps { ls_step-step_id } and { ls_twin-step_id } both post to | &&
                         |{ ls_step-bknd_screen }. The backend cannot distinguish them, and | &&
                         |a BAdI branching on SCREENNAME takes the same branch for both.| ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD x05_step_order.
*   THE ONE THAT IS EASIEST TO MISS.
*
*   ZCL_EGA_CJ_DOK_ABS->GET_SCREENNAME( ) advances the backend like this:
*
*       SELECT DISTINCT screen_name FROM /qnv/sb_ui_defin
*         WHERE category = ... ORDER BY screen_name ASCENDING.
*       READ TABLE lt_screen WITH KEY screen_name = <current>.
*       READ TABLE lt_screen INTO screen INDEX sy-tabix + 1.
*
*   The next screen is the ALPHABETICALLY next one in the whole category, and the
*   backend has never heard of SEQNR.
*
*   INFORMATION, NOT A BLOCKER - and it was written as a blocker first, which was
*   wrong. CJS never consumes that answer. It sends BKND_SCREEN by name and picks
*   the next step from its own list, so CS_GENERAL_DATA-SCREENNAME coming back
*   wrong costs it nothing.
*
*   It is still worth saying, for two reasons. A journey run from BOTH front ends
*   - ShapeIt for staff, CJS for citizens - does depend on it, and reusable
*   screens make disagreement the norm rather than the exception: a shared licence
*   list sorts wherever its name sorts, not where the journey puts it. And any
*   D0xx BAdI that branches on SCREENNAME is reading a value CJS supplies, which
*   is checked separately in X11.
    DATA lt_mine TYPE STANDARD TABLE OF /qnv/sbuild_screen_name WITH EMPTY KEY.
    LOOP AT gt_step INTO DATA(ls_step) WHERE bknd_screen IS NOT INITIAL.
      APPEND ls_step-bknd_screen TO lt_mine.
    ENDLOOP.
    IF lines( lt_mine ) < 2.
      RETURN.
    ENDIF.

    DATA(lt_sorted) = lt_mine.
    SORT lt_sorted AS TEXT BY table_line.
    IF lt_sorted <> lt_mine.
      add( iv_sev  = 'I'
           iv_rule = 'X05'
           iv_text = |CJS step order is { concat_lines_of( table = lt_mine sep = ` > ` ) } | &&
                     |but the backend advances alphabetically, which gives | &&
                     |{ concat_lines_of( table = lt_sorted sep = ` > ` ) }. Harmless while CJS | &&
                     |drives, since it never reads the backend's cursor - relevant only if this | &&
                     |journey is also run from ShapeIt.| ).
    ENDIF.

*   And the sort is over the CATEGORY, not over this journey. A screen belonging
*   to another journey that sorts between two of ours is enough to break the
*   chain on its own.
    DATA lt_cat TYPE STANDARD TABLE OF /qnv/sbuild_screen_name WITH EMPTY KEY.
    LOOP AT gt_defn INTO DATA(ls_d).
      READ TABLE lt_cat TRANSPORTING NO FIELDS WITH KEY table_line = ls_d-screen_name.
      IF sy-subrc <> 0.
        APPEND ls_d-screen_name TO lt_cat.
      ENDIF.
    ENDLOOP.
    SORT lt_cat AS TEXT BY table_line.

    DATA lv_prev TYPE i.
    lv_prev = 0.
    LOOP AT lt_mine INTO DATA(lv_scr).
      READ TABLE lt_cat TRANSPORTING NO FIELDS WITH KEY table_line = lv_scr.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_ix) = sy-tabix.
      IF lv_prev > 0 AND lv_ix > lv_prev + 1.
        add( iv_sev  = 'I'
             iv_rule = 'X05'
             iv_text = |Between { lt_cat[ lv_prev ] } and { lv_scr } the category holds | &&
                       |{ lv_ix - lv_prev - 1 } other screen(s), so GET_SCREENNAME( ) would hand | &&
                       |the backend one of those. Expected wherever screens are reused; only | &&
                       |matters on the ShapeIt front end.| ).
      ENDIF.
      lv_prev = lv_ix.
    ENDLOOP.
  ENDMETHOD.


  METHOD x06_pay_screen.
    LOOP AT gt_fld INTO DATA(ls_f) WHERE ftype = 'PAYFEE'.
      DATA(lv_pay_step) = ls_f-step_id.

      READ TABLE gt_step INTO DATA(ls_step) WITH KEY step_id = lv_pay_step.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE gt_fld INTO DATA(ls_ps)
        WITH KEY step_id = lv_pay_step field_name = 'PAY_SCREEN'.
      IF sy-subrc <> 0.
        add( iv_sev  = 'W'
             iv_rule = 'X06'
             iv_step = |{ lv_pay_step }|
             iv_text = 'No PAY_SCREEN carrier on the payment step. PREPARE_PAYMENT( ) will ' &&
                       'fall back to this step''s own screen, which is usually right - but ' &&
                       'say it, so the next reader does not have to know the default.' ).
      ELSEIF ls_ps-default_val IS NOT INITIAL
         AND to_upper( ls_ps-default_val ) <> to_upper( ls_step-bknd_screen ).
        add( iv_sev  = 'E'
             iv_rule = 'X06'
             iv_step = |{ lv_pay_step }|
             iv_text = |PAY_SCREEN says { ls_ps-default_val } but the step posts to | &&
                       |{ ls_step-bknd_screen }. PREPARE_PAYMENT( ) reads the first and the | &&
                       |commit writes the second, so the gateway is resolved from a screen | &&
                       |the case was never filed against and APPLICATIONURL comes back empty.| ).
      ENDIF.

*     PAY_JOURNEY / PAY_CATEGORY pointing at the common pay app is the specific
*     mistake worth naming: the payment completes and the journey does not.
      READ TABLE gt_fld INTO DATA(ls_pj)
        WITH KEY step_id = lv_pay_step field_name = 'PAY_JOURNEY'.
      IF sy-subrc = 0 AND ls_pj-default_val IS NOT INITIAL
         AND to_upper( ls_pj-default_val ) <> to_upper( gs_jny-bknd_journey ).
        add( iv_sev  = 'W'
             iv_rule = 'X06'
             iv_step = |{ lv_pay_step }|
             iv_text = |PAY_JOURNEY is { ls_pj-default_val } while this journey is | &&
                       |{ gs_jny-bknd_journey }. A payment started inside a journey has to be | &&
                       |finished by that journey - route it elsewhere and the money is taken | &&
                       |while the application stays unsubmitted.| ).
      ENDIF.
      EXIT.
    ENDLOOP.
  ENDMETHOD.


  METHOD x08_status_carrier.
*   The engine posts only the CURRENT step's fields, and the BAdI decides what a
*   post IS entirely from the STATUS item. A STATUS carrier on step 1 does not
*   travel on the step 2 post.
    LOOP AT gt_step INTO DATA(ls_step).
      READ TABLE gt_fld TRANSPORTING NO FIELDS
        WITH KEY step_id = ls_step-step_id field_name = 'STATUS'.
      DATA(lv_has) = xsdbool( sy-subrc = 0 ).

      READ TABLE gt_fld TRANSPORTING NO FIELDS
        WITH KEY step_id = ls_step-step_id ftype = 'PAYFEE'.
      DATA(lv_pay) = xsdbool( sy-subrc = 0 ).

      IF lv_pay = abap_true AND lv_has = abap_false.
        add( iv_sev  = 'E'
             iv_rule = 'X08'
             iv_step = |{ ls_step-step_id }|
             iv_text = 'Payment step with no STATUS carrier. The Pay commit arrives with a ' &&
                       'full payload and no instruction: GV_SAVE_DRAFT stays blank, ' &&
                       'CREATE_CASE is never reached, and no case is created.' ).
      ENDIF.
    ENDLOOP.

*   NO journey-wide check. It was here and it was wrong: Save, Submit and Delete
*   pass IV_STATUS to the bridge, which injects the item itself -
*
*       IF iv_status IS NOT INITIAL.
*         APPEND VALUE #( fieldname = 'STATUS' ... value = iv_status ) TO lt_item.
*
*   - so those three never need a configured carrier. Only the PAYMENT step does,
*   because COMMIT_STEP( ) passes no status and reads the model field instead.
*   That is the check above, and it is the only one worth making.
  ENDMETHOD.


  METHOD x09_grid_contract.
*   A grid is the one control that genuinely REQUIRES /QNV rows. The BAdI mapper
*   only touches table data when it finds the field with DATA8 set:
*
*       READ TABLE lt_defin ... WITH KEY field_name = <item>-fieldname.
*       IF sy-subrc EQ 0 AND ls_defin-data8 EQ abap_true.
*
*   and it builds cell names as 'FIELD' && LIST_SEQUENCE, so a blank sequence on
*   the column rows produces FIELD0, every ASSIGN misses, and the rows arrive
*   with the right count and no content.
    LOOP AT gt_fld INTO DATA(ls_f)
         WHERE ftype = 'EDITABLE_TABLE' OR ftype = 'TABLE' OR ftype = 'RECORDCARD'.
      READ TABLE gt_step INTO DATA(ls_step) WITH KEY step_id = ls_f-step_id.
      IF sy-subrc <> 0 OR ls_step-bknd_screen IS INITIAL.
        CONTINUE.
      ENDIF.

*     By FIELD_NAME or by DATA2. The two paths resolve a table differently - the
*     mapper joins the POST on UI_TABLE_NAME = the field name, while READ_TABLE
*     looks the table up by DATA2 - so a grid authored under one spelling is
*     perfectly reachable by the other. Checking only the first reported grids
*     that work.
      READ TABLE gt_defn INTO DATA(ls_d)
        WITH KEY screen_name = ls_step-bknd_screen field_name = ls_f-field_name.
      IF sy-subrc <> 0.
        READ TABLE gt_defn INTO ls_d
          WITH KEY screen_name = ls_step-bknd_screen data2 = ls_f-field_name.
      ENDIF.
      IF sy-subrc <> 0.
        add( iv_sev  = 'E'
             iv_rule = 'X09'
             iv_step = |{ ls_f-step_id }|
             iv_text = |Grid { ls_f-field_name } has no row on screen { ls_step-bknd_screen }, | &&
                       |under either FIELD_NAME or DATA2. Its rows post and are skipped, | &&
                       |because the mapper joins on UI_TABLE_NAME = the field name and finds | &&
                       |nothing to join to.| ).
        CONTINUE.
      ENDIF.

*     DATA8 gates the POST branch only. A display grid - TABLE, RECORDCARD -
*     never posts, so demanding it there reported a blocker on configuration that
*     is doing exactly what it should.
      IF ls_d-data8 <> abap_true AND ls_f-ftype = 'EDITABLE_TABLE'.
        add( iv_sev  = 'E'
             iv_rule = 'X09'
             iv_step = |{ ls_f-step_id }|
             iv_text = |Editable grid { ls_f-field_name } has DATA8 blank on | &&
                       |{ ls_step-bknd_screen }. The mapper tests it before touching table | &&
                       |data, so every row the citizen enters is discarded without a message.| ).
      ENDIF.

      SELECT COUNT(*) FROM /qnv/sb_ui_defin INTO @DATA(lv_bad)
        WHERE category         = @gs_jny-bknd_category
          AND screen_name      = @ls_step-bknd_screen
          AND parent_container = @ls_f-field_name
          AND list_sequence    = @space.
      IF lv_bad > 0.
        add( iv_sev  = 'W'
             iv_rule = 'X09'
             iv_step = |{ ls_f-step_id }|
             iv_text = |Grid { ls_f-field_name } has { lv_bad } column row(s) with no | &&
                       |LIST_SEQUENCE. Cell names are built as 'FIELD' && LIST_SEQUENCE, so | &&
                       |those columns resolve to FIELD0 and come back empty while the row | &&
                       |count still looks right.| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD x10_next_requires.
    LOOP AT gt_step INTO DATA(ls_step) WHERE next_requires IS NOT INITIAL.
      READ TABLE gt_fld TRANSPORTING NO FIELDS
        WITH KEY step_id = ls_step-step_id field_name = ls_step-next_requires.
      IF sy-subrc <> 0.
        add( iv_sev  = 'W'
             iv_rule = 'X10'
             iv_step = |{ ls_step-step_id }|
             iv_text = |NEXT_REQUIRES names { ls_step-next_requires }, which is not a field on | &&
                       |this step. The gate fails open - the button behaves as if it were | &&
                       |blank - so the step has no gate at all.| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD x11_badi_screen_literals.
*   The one place a shared screen CAN bite CJS.
*
*   D0xx handlers branch on the screen name CJS sent - ZCL_EGA_CJ_ENH_IMPL_D026
*   has IF cs_general_data-screenname EQ 'ND026_1_2' guarding the MOE score call
*   and the fee check. The literal is journey-specific; the step it guards may not
*   be. Point a step at a shared screen and that branch silently stops firing:
*   no error, no message, the validation just never happens.
*
*   Read from source rather than guessed. The literals exist nowhere else - not in
*   /QNV, not in ZRAK_T_JNY*, only in the handler's own code.
    IF gs_jny-bknd_journey IS INITIAL.
      RETURN.
    ENDIF.

*   The column holding the implementing class is read by NAME rather than named
*   in the SELECT. ZEGA_T_CJ_2_OBJ belongs to the department, not to CJS, and a
*   checker that fails to activate because it guessed a column wrong is worse
*   than one that quietly skips a single rule. ZCL_EGA_CJ_DOK_ABS itself only
*   ever does SELECT * on this table, so there was nothing to copy from.
    SELECT SINGLE * FROM zega_t_cj_2_obj INTO @DATA(ls_obj)
      WHERE journeyid = @gs_jny-bknd_journey.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lv_cls TYPE string.
    DATA(lt_try) = VALUE string_table(
      ( `OBJECTNAME` ) ( `OBJECT` ) ( `CLASSNAME` ) ( `CLASS_NAME` )
      ( `CLASS` ) ( `IMPL_CLASS` ) ( `BADI_IMPL` ) ( `OBJ_NAME` ) ).
    LOOP AT lt_try INTO DATA(lv_try).
      ASSIGN COMPONENT lv_try OF STRUCTURE ls_obj TO FIELD-SYMBOL(<cls>).
      IF sy-subrc = 0 AND <cls> IS NOT INITIAL.
        lv_cls = <cls>.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF lv_cls IS INITIAL.
      add( iv_sev  = 'I'
           iv_rule = 'X11'
           iv_text = 'Could not find the implementing-class column on ZEGA_T_CJ_2_OBJ, so ' &&
                     'hard-coded screen names in the BAdI were not checked. Add the real ' &&
                     'column name to LT_TRY in X11 and the rule starts working.' ).
      RETURN.
    ENDIF.

*   Method includes via CL_OO_CLASSNAME_SERVICE, then READ REPORT on each.
*   REPOSRC holds no source lines - the text is compressed - and REPOSRC_LINE_VIEW
*   does not exist on every release. This is the portable route: the service
*   resolves the =====CM### include names, which are not derivable by hand, and
*   READ REPORT is as old as ABAP.
    DATA lt_inc TYPE seop_methods_w_include.
    TRY.
        lt_inc = cl_oo_classname_service=>get_all_method_includes(
          clsname = CONV seoclsname( lv_cls ) ).
      CATCH cx_root.
        CLEAR lt_inc.
    ENDTRY.

    IF lt_inc IS INITIAL.
      add( iv_sev  = 'I'
           iv_rule = 'X11'
           iv_text = |Could not read the source of { lv_cls }. Grep it by hand for | &&
                     |SCREENNAME EQ and compare each literal against the BKND_SCREEN | &&
                     |values above.| ).
      RETURN.
    ENDIF.

    DATA lt_line TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    LOOP AT lt_inc INTO DATA(ls_inc).
      CLEAR lt_line.
      READ REPORT ls_inc-incname INTO lt_line.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      LOOP AT lt_line INTO DATA(lv_line).
        DATA(lv_up) = to_upper( lv_line ).
*       A comment cannot branch on anything.
        IF lv_up CS 'SCREENNAME' AND substring( val = condense( lv_up ) len = 1 ) <> '*'.
        ELSE.
          CONTINUE.
        ENDIF.
        FIND FIRST OCCURRENCE OF REGEX `'(N[A-Z0-9_]+)'` IN lv_up SUBMATCHES DATA(lv_lit).
        IF sy-subrc <> 0 OR lv_lit IS INITIAL.
          CONTINUE.
        ENDIF.
        READ TABLE gt_step TRANSPORTING NO FIELDS WITH KEY bknd_screen = lv_lit.
        IF sy-subrc <> 0.
          add( iv_sev  = 'W'
               iv_rule = 'X11'
               iv_text = |{ lv_cls } branches on screen '{ lv_lit }', which no step of this | &&
                         |journey posts to. That branch can never fire - whatever it guards | &&
                         |(a validation, a fee check, an API call) silently does not run.| ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD x12_screen_family.
*   THE OFF-BY-ONE.
*
*   A journey's own screens are named as a family - ND009_1_1, ND009_1_2,
*   ND009_1_3 - and a step that opens on a REUSABLE screen (a licence list, a
*   location picker shared across departments) sits outside it. ShapeIt numbers
*   only its own family, so its screen _1_1 is the step AFTER the reusable one.
*
*   Seed the CJS steps against the family one-for-one by position and every
*   screen shifts by one: the second step posts to the first screen, the third
*   to the second, and the last step is left with a screen that belongs to
*   another step or with none at all. Nothing errors. The citizen types into the
*   right form and it is filed against the wrong screen, and the case appears
*   only at Submit because the step that should have created it never posted
*   where it thought it did.
*
*   Two halves, and the second is the one that catches it:
*     - a step on a screen outside the family is NORMAL, and reported only so
*       the family below is read with it in mind
*     - a family screen that no step claims is the tell. The journey owns it,
*       ShapeIt renders it, and CJS posts to it from nowhere.
    DATA lt_fam TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lv_pref TYPE string.

*   The family prefix is whatever the steps agree on up to the last underscore.
*   Taken from the majority rather than from step 1, precisely because step 1 is
*   the one most likely to be the reusable outlier.
    DATA lt_pref TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    LOOP AT gt_step INTO DATA(ls_step) WHERE bknd_screen IS NOT INITIAL.
      DATA(lv_s) = CONV string( ls_step-bknd_screen ).
      DATA(lv_off) = 0.
      FIND ALL OCCURRENCES OF '_' IN lv_s RESULTS DATA(lt_hit).
      IF lt_hit IS INITIAL.
        CONTINUE.
      ENDIF.
      lv_off = lt_hit[ lines( lt_hit ) ]-offset.
      APPEND substring( val = lv_s len = lv_off + 1 ) TO lt_pref.
    ENDLOOP.
    IF lt_pref IS INITIAL.
      RETURN.
    ENDIF.

    SORT lt_pref BY table_line.
    DATA lv_best TYPE i.
    DATA lv_run  TYPE i.
    DATA lv_cur  TYPE string.
    LOOP AT lt_pref INTO DATA(lv_p).
      IF lv_p = lv_cur.
        lv_run = lv_run + 1.
      ELSE.
        lv_cur = lv_p.
        lv_run = 1.
      ENDIF.
      IF lv_run > lv_best.
        lv_best = lv_run.
        lv_pref = lv_p.
      ENDIF.
    ENDLOOP.
    IF lv_pref IS INITIAL OR lv_best < 2.
      RETURN.
    ENDIF.

*   Every screen of the family that exists in ShapeIt.
    DATA(lv_like) = |{ lv_pref }%|.
    SELECT DISTINCT screen_name FROM /qnv/sb_ui_defin INTO TABLE @DATA(lt_scr)
      WHERE category = @gs_jny-bknd_category
        AND screen_name LIKE @lv_like
      ORDER BY screen_name.
    IF lt_scr IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT gt_step INTO ls_step WHERE bknd_screen IS NOT INITIAL.
      IF NOT ls_step-bknd_screen CP |{ lv_pref }*|.
        add( iv_sev  = 'I'
             iv_rule = 'X12'
             iv_step = |{ ls_step-step_id }|
             iv_text = |Step opens on { ls_step-bknd_screen }, outside this journey's | &&
                       |{ lv_pref }* family - a reusable screen. Expected, and the reason | &&
                       |ShapeIt's own numbering starts one step later than CJS's.| ).
      ENDIF.
    ENDLOOP.

    LOOP AT lt_scr INTO DATA(ls_scr).
      READ TABLE gt_step TRANSPORTING NO FIELDS WITH KEY bknd_screen = ls_scr-screen_name.
      IF sy-subrc <> 0.
        add( iv_sev  = 'E'
             iv_rule = 'X12'
             iv_text = |Screen { ls_scr-screen_name } belongs to this journey's family but no | &&
                       |step posts to it. Either a step is missing, or the steps are seeded | &&
                       |one position out - which is what happens when a reusable first screen | &&
                       |is counted by CJS and not by ShapeIt. Read BKND_SCREEN down SEQNR and | &&
                       |compare it against the ShapeIt URLs before anything else.| ).
      ENDIF.
    ENDLOOP.

*   And the shape of the mistake, said plainly when it is visible: the family has
*   as many screens as the journey has steps after the reusable one.
    DATA(lv_own) = 0.
    LOOP AT gt_step INTO ls_step WHERE bknd_screen IS NOT INITIAL.
      IF ls_step-bknd_screen CP |{ lv_pref }*|.
        lv_own = lv_own + 1.
      ENDIF.
    ENDLOOP.
    IF lines( lt_scr ) > lv_own.
      add( iv_sev  = 'W'
           iv_rule = 'X12'
           iv_text = |The { lv_pref }* family has { lines( lt_scr ) } screen(s) but only | &&
                     |{ lv_own } step(s) post into it. { lines( lt_scr ) - lv_own } screen(s) | &&
                     |are unreachable from CJS.| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
