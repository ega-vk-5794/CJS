*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_PORTAL_FIX
*&---------------------------------------------------------------------*
* Show, and undo, what a migrator run wrote into the LIVE portal tables
* ZEGA_T_CJ_GRP / _ID / _IDT.
*
* WHY THIS EXISTS
*   ZCL_RAK_MIGRATOR used to MODIFY the group named in IV_MAIN, whose old
*   default was '901' - a real production group carrying ~25 journeys. The
*   MODIFY relabelled it "AI Driven Journeys" in EN and AR and rewrote its
*   LEVELNO / ORDERNO. It also wrote every journey's leaf under the tile
*   <prefix><code> ('MIG_M011'), which is 8 characters into the CHAR(4)
*   ZDE_CJ_JOURNEYID: truncated to 'MIG_' on the INSERT, so all fifteen
*   journeys in a batch shared ONE leaf, each overwriting the last.
*   The migrator no longer does either (it refuses a group it did not
*   create, and builds a real four-character tile), but rows already
*   written stay written. This report removes them.
*
* WHAT IT WILL NOT DO
*   It never guesses what a live row used to say. A journey leaf is
*   removable only when ZRAK_T_JNY still records that tile as a CJS
*   journey - anything else is somebody's live service and is listed, not
*   touched. The group's own description, LEVELNO and ORDERNO are restored
*   ONLY from what you type in: read them out of a client where the group
*   is still correct (SE16 on ZEGA_T_CJ_GRP / ZEGA_T_CJ_IDT) and put them
*   in the Restore block below.
*
* Test run is the default. Nothing is written until you untick it.
*&---------------------------------------------------------------------*
REPORT zrak_cj_portal_fix.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_dept TYPE zega_t_cj_grp-department OBLIGATORY.
PARAMETERS p_grp  TYPE zega_t_cj_grp-journeyid  OBLIGATORY DEFAULT '901'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_del   TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_stale TYPE zega_t_cj_grp-journeyid.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
PARAMETERS p_rest TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_lvl  TYPE zega_t_cj_grp-levelno.
PARAMETERS p_ord  TYPE zega_t_cj_grp-orderno.
PARAMETERS p_dril TYPE zega_t_cj_grp-drilldown DEFAULT 'Y'.
PARAMETERS p_den  TYPE zega_t_cj_idt-description.
PARAMETERS p_dar  TYPE zega_t_cj_idt-description.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-b04.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b4.

START-OF-SELECTION.

* ---- which tiles belong to CJS. A leaf is ours ONLY if a CJS journey
* still claims it; everything else under the group is somebody's live
* service and is reported, never deleted.
  SELECT tile_code FROM zrak_t_jny WHERE tile_code <> @space
    INTO TABLE @DATA(lt_ours).

  WRITE: / 'PORTAL GROUP', 20 p_grp, 30 'department', 45 p_dept,
        60 COND string( WHEN p_test = abap_true THEN 'TEST RUN - nothing written'
                                                ELSE 'LIVE' ).
  ULINE.

* ---- the group row itself
  SELECT SINGLE * FROM zega_t_cj_grp
    WHERE department = @p_dept AND groupid = @space AND journeyid = @p_grp
    INTO @DATA(ls_grp).
  IF sy-subrc = 0.
    WRITE: / 'Group row  :', 16 'LEVELNO', 25 ls_grp-levelno,
             35 'ORDERNO', 45 ls_grp-orderno, 55 'DRILLDOWN', 66 ls_grp-drilldown.
  ELSE.
    WRITE: / 'Group row  : none in this department'.
  ENDIF.

  SELECT spras, description FROM zega_t_cj_idt WHERE journeyid = @p_grp
    INTO TABLE @DATA(lt_txt).
  LOOP AT lt_txt INTO DATA(ls_txt).
    WRITE: / 'Group text :', 16 ls_txt-spras, 20 ls_txt-description.
  ENDLOOP.

* ---- children
  ULINE.
  WRITE: / 'Journey', 12 'Level', 20 'Order', 28 'Drill', 36 'Owner', 50 'Description (EN)'.
  ULINE.

  SELECT journeyid, levelno, orderno, drilldown FROM zega_t_cj_grp
    WHERE department = @p_dept AND groupid = @p_grp
    INTO TABLE @DATA(lt_kid).

  DATA lt_mine TYPE STANDARD TABLE OF zega_t_cj_grp-journeyid WITH EMPTY KEY.
  LOOP AT lt_kid INTO DATA(ls_kid).
    DATA(lv_mine) = xsdbool( line_exists( lt_ours[ table_line = ls_kid-journeyid ] )
                             OR ( p_stale IS NOT INITIAL AND ls_kid-journeyid = p_stale ) ).
    IF lv_mine = abap_true.
      APPEND ls_kid-journeyid TO lt_mine.
    ENDIF.
    SELECT SINGLE description FROM zega_t_cj_idt
      WHERE journeyid = @ls_kid-journeyid AND spras = 'E' INTO @DATA(lv_desc).
    WRITE: / ls_kid-journeyid, 12 ls_kid-levelno, 20 ls_kid-orderno,
             28 ls_kid-drilldown,
             36 COND string( WHEN lv_mine = abap_true THEN 'CJS' ELSE '** LIVE **' ),
             50 lv_desc.
    CLEAR lv_desc.
  ENDLOOP.
  ULINE.
  WRITE: / |{ lines( lt_kid ) } journey(s) under { p_grp }, { lines( lt_mine ) } created by CJS|.

* ---- remove the CJS leaves
  IF p_del = abap_true.
    IF lt_mine IS INITIAL.
      WRITE: / 'Nothing to remove - no CJS leaf under this group.'.
    ELSEIF p_test = abap_true.
      WRITE: / |TEST RUN - { lines( lt_mine ) } CJS leaf/leaves would be removed | &&
               |from ZEGA_T_CJ_GRP, _ID and _IDT.|.
    ELSE.
      LOOP AT lt_mine INTO DATA(lv_tile).
        DELETE FROM zega_t_cj_grp
          WHERE department = @p_dept AND groupid = @p_grp AND journeyid = @lv_tile.
        DELETE FROM zega_t_cj_id  WHERE journeyid = @lv_tile.
        DELETE FROM zega_t_cj_idt WHERE journeyid = @lv_tile.
        WRITE: / '[REMOVED]', 12 lv_tile.
      ENDLOOP.
      COMMIT WORK.
    ENDIF.
  ENDIF.

* ---- put the group back the way it was. Only the fields you filled in.
  IF p_rest = abap_true.
    IF p_test = abap_true.
      WRITE: / |TEST RUN - group { p_grp } would be set to LEVELNO { p_lvl }, | &&
               |ORDERNO { p_ord }, DRILLDOWN { p_dril }.|.
      IF p_den IS NOT INITIAL. WRITE: / |  EN description -> { p_den }|. ENDIF.
      IF p_dar IS NOT INITIAL. WRITE: / |  AR description -> { p_dar }|. ENDIF.
    ELSE.
      UPDATE zega_t_cj_grp SET levelno = @p_lvl, orderno = @p_ord, drilldown = @p_dril
        WHERE department = @p_dept AND groupid = @space AND journeyid = @p_grp.
      WRITE: / '[RESTORED] group row', 30 p_grp.
      IF p_den IS NOT INITIAL.
        UPDATE zega_t_cj_idt SET description = @p_den
          WHERE journeyid = @p_grp AND spras = 'E'.
        WRITE: / '[RESTORED] EN description'.
      ENDIF.
      IF p_dar IS NOT INITIAL.
        UPDATE zega_t_cj_idt SET description = @p_dar
          WHERE journeyid = @p_grp AND spras = 'A'.
        WRITE: / '[RESTORED] AR description'.
      ENDIF.
      COMMIT WORK.
    ENDIF.
  ENDIF.

  IF p_test = abap_true AND ( p_del = abap_true OR p_rest = abap_true ).
    ULINE.
    WRITE: / 'TEST RUN - untick Test run to apply.'.
  ENDIF.
