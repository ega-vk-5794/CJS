REPORT zrak_ba01_load.

*&---------------------------------------------------------------------*
*& BA01 / BA02 / BA03 - Online Appointment Booking (APPOINT, NBA01)
*&
*& Hand-authored, NOT driven through ZCL_RAK_MIGRATOR. The /QNV export for
*& NBA01 was supplied as EXPORT_DEFIN.XLSX (327 rows over six screens) and
*& every field name, technical name, search help and mandatory flag below
*& is read off it. The migrator is deliberately not used here.
*&
*& ============ THE SIX LEGACY SCREENS, AND WHAT THEY BECAME ===========
*&
*&   legacy            is                              here
*&   ------------------------------------------------------------------
*&   NBA01_1_1         appointment list, 3 tabs        BA01 / STP1
*&   NBA01_1_2         book, 2 tabs                    BA01 / STP2
*&   NBA01_1_3         booking confirmation            engine RENDER_RESULT
*&   NBA01_1_4         reschedule                      BA02 / STP1
*&   NBA01_1_5         cancel                          BA03 / STP1
*&   NBA01_1_6         cancel confirmation             engine RENDER_RESULT
*&
*& THREE JOURNEYS, NOT ONE, AND THE ENGINE IS WHY. The legacy list has two
*& links per row - Reschedule (NAVTO NBA01_1_4) and Cancel (NAVTO NBA01_1_5)
*& - so the list is a hub with three destinations. The CJS engine is a
*& linear wizard: ADVANCE_STEP( ) moves +1 and nothing jumps, so a hub
*& cannot fan out to three steps of one journey. The legacy screen does not
*& jump either - it NAVIGATES - and BA02 / BA03 reproduce that with
*& OPEN_URL( ) from the row buttons, which is the same mechanism under a
*& different name.
*&
*& All three carry BKND_JOURNEY = 'BA01' because JOURNEYTYPE is 'BA01' on
*& all six export screens, and PARAM2 is the BAdI filter. Splitting the
*& journey id would send BA02 to a filter with no implementation and the
*& read would come back with every value empty.
*&
*& Two confirmation screens are the engine's own result page. NBA01_1_3 and
*& NBA01_1_6 are a check-list of what was booked plus RAKHAPPY, and CJS
*& draws both already: RENDER_RESULT( ) shows the reference SET_REFERENCE( )
*& was given, and the happiness meter is the engine's, wired to
*& ZDT_HM_FEEDBACK - the same five ratings the legacy control offers.
*&
*& ============ THE APPOINTMENT CONTROL IS A JSON CARRIER ===============
*&
*& This is the thing to understand before changing any field below.
*&
*& On the legacy screen, Case ID / Sector / Discipline / Engineer / Date /
*& Time Slot are NOT six definition rows. They are drawn INSIDE one custom
*& control - CONTROL_TYPE 'APPOINTMENT', from shapeitext2 - which
*& round-trips a single JSON string in GS_DATA-APPOINT_JSON:
*&
*&   in   { "PARTNER": "..", "CASE_ID": "..", "CASE_UNCHANGABLE": true }
*&   out  { partner, case_id, role, engineer, date, appointment, sector }
*&
*& with date = yyyymmdd and appointment = HHMMHHMM (from, then to), which
*& ZCL_EGA_CJ_ENH_IMPL_OBA01~UPDATE splits as +0(4) && '00' and
*& +4(4) && '00' && '00'.
*&
*& AND THAT JSON WINS. In UPDATE's GV_SAVE_DRAFT branch every one of
*& AVAILABLE_CASE_ID, PICKED_DATE, PICKED_TIME_FROM/TO, ENGINEER_ID,
*& PICKED_ROLE and SECTOR_ID is assigned FROM the deserialized JSON,
*& overwriting whatever the item rows carried. So the six pickers below are
*& real CJS fields for the citizen, and the handler re-assembles them into
*& APPOINT_1 / APPOINT_JSON2_1 before the post. Send the items without the
*& JSON and the case is created with a blank date, a blank engineer and no
*& slot - and no message, because none of those are validated on the way in.
*&
*& APPOINT_1 and APPOINT_JSON2_1 are therefore seeded HIDDEN below. They are
*& the wire, not a control.
*&
*& ============ FIELD NAMES ARE THE LEGACY NAMES, WITH TWO EXCEPTIONS ===
*&
*& Backend field control is keyed on FIELD_NAME end to end - SEED_CTRL( )
*& looks the field up by it, CTRL_OF( ) reports on it, APPLY_CTRL( ) calls
*& SET_HIDDEN with it, and SET_HIDDEN on a name the journey does not have
*& is legal and does nothing. So the names below are the export's.
*&
*& The two exceptions are forced by the 23-character model ceiling:
*&
*&   REQ_CLARIFICATION_COMBOBOX    26 chars  ->  REQ_CLARIFICATION
*&   REQ_CLARIFICATION_COMBOBOX_2  28 chars  ->  REQ_CLARIFICATION_2
*&
*& BUILD_MODEL( ) builds _VS, _VST, _IDTYPE, _NAME, _IX and _EXP companions
*& on every field name, and _IDTYPE is 7, so a 26-character name raises an
*& UNCAUGHT CX_SY_STRUCT_COMP_NAME and the whole app dies - not one field.
*& Checked before shortening: ZCL_EGA_CJ_ENH_IMPL_OBA01~READ's LOOP AT
*& ct_definition names APP_NAME, APP_ID, DECLARATION_NAME, DECLARATION,
*& STAGES, NOTE, COMPLAINT_DESC, NEXT, REJECT, ATTACHMENTS_TEXT,
*& FINAL_REPORT_ATTACH_1, REQUEST_1_TXT and APPOINT_1_RE - and no
*& clarification field among them, so no field control is lost by the
*& rename. TECHNICAL_NAME is untouched either way and that is what posts.
*&
*& APPOINT_1_RE keeps its exact name because READ *does* branch on it
*& (WHEN 'APPOINT_1_RE' sets additionaldata1 = 'G' for a general-enquiry
*& reschedule), and a renamed field would never receive that.
*&
*& ============ WORDING IS READ, NOT TYPED =============================
*&
*& Every label on these screens already exists in English and Arabic in
*& /QNV/SB_LABELT, keyed by the export's LABEL_CON / VALUE code. LCL_TXT
*& below reads them and falls back to a literal only where no row answers.
*& The literals are transcriptions from the live screenshots, present so a
*& system without the legacy text rows still renders something readable -
*& they are NOT the authority and must not be "corrected" by hand.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside journey
*& ids BA01, BA02 and BA03.
*&
*& ============ WHAT IS NOT SETTLED - read before trusting this =========
*&
*& 1. PARAM3 COLLIDES. ZCL_RAK_QNV_BRIDGE sends the partner as PARAM3 on
*&    every read. ZCL_EGA_CJ_ENH_IMPL_OBA01~READ opens with
*&        gs_data-reschedule_col = cs_header-param3.
*&        gs_data-cancel_col     = cs_header-param4.
*&    and then READ TABLE upcoming_appointments INDEX reschedule_col. On the
*&    legacy path PARAM3 is a ROW INDEX, set by LINK_1's NAVTO
*&    (param3-UPCOMING_APPOINTMENTS). A CJS read therefore hands a partner
*&    number to a READ TABLE INDEX. It cannot be fixed on the legacy side -
*&    namespace boundary - and it is NOT worked around below, because the
*&    fix is a decision: either the bridge stops sending PARAM3 for this
*&    category, or CJS reads the list itself. See the handler header.
*& 2. FOUR OPTION LISTS HAVE NO SOURCE HERE. Case ID, Discipline, Engineer
*&    and Sector came from the OData service behind the APPOINTMENT control
*&    (CasesSet / RolesSet / EngineersSet / SectorsSet / SuggestEngineerSet)
*&    and that service is still unidentified - it is item 1 of
*&    doc/gaps/open-questions.md. The handler answers all four from named
*&    resolver methods that currently return nothing and say so on the
*&    trace. Request Clarification is NOT among them: it has a real search
*&    help, ZSH_CJ_APPOINT_SUBJECT, and is configured as SHLP below.
*& 3. NOTHING HERE HAS BEEN ACTIVATED OR RUN. There is no ADT connection
*&    from the environment this was written in.
*&---------------------------------------------------------------------*

CONSTANTS c_book  TYPE zrak_t_jny-journey_id VALUE 'BA01'.
CONSTANTS c_resch TYPE zrak_t_jny-journey_id VALUE 'BA02'.
CONSTANTS c_cancl TYPE zrak_t_jny-journey_id VALUE 'BA03'.

TYPES tt_jny  TYPE STANDARD TABLE OF zrak_t_jny      WITH EMPTY KEY.
TYPES tt_step TYPE STANDARD TABLE OF zrak_t_jny_step WITH EMPTY KEY.
TYPES tt_fld  TYPE STANDARD TABLE OF zrak_t_jny_fld  WITH EMPTY KEY.
TYPES tt_opt  TYPE STANDARD TABLE OF zrak_t_jny_opt  WITH EMPTY KEY.
TYPES tt_rule TYPE STANDARD TABLE OF zrak_t_jny_rule WITH EMPTY KEY.

*&---------------------------------------------------------------------*
*& Legacy wording, read by LABEL_CON code.
*&
*& One SELECT for the whole run rather than one per label: the export
*& carries 30-odd distinct codes and a SELECT SINGLE per field would be
*& thirty round trips to save writing a cache.
*&
*& EN( ) takes spras 'E', AR( ) takes 'A'. Both fall back to the literal
*& passed in, so a system with no /QNV text rows still renders the screen
*& instead of a page of blank captions.
*&---------------------------------------------------------------------*
CLASS lcl_txt DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS load.
    CLASS-METHODS en IMPORTING iv_code TYPE string
                               iv_else TYPE string
                     RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ar IMPORTING iv_code TYPE string
                               iv_else TYPE string
                     RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS missing RETURNING VALUE(rv) TYPE i.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_l,
             code  TYPE string,
             spras TYPE sy-langu,
             text  TYPE string,
           END OF ty_l.
    CLASS-DATA mt_l   TYPE SORTED TABLE OF ty_l WITH UNIQUE KEY code spras.
    CLASS-DATA mv_mis TYPE i.
    CLASS-METHODS pick IMPORTING iv_code TYPE string
                                 iv_sp   TYPE sy-langu
                                 iv_else TYPE string
                       RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS lcl_txt IMPLEMENTATION.

  METHOD load.
*   Wrapped: /QNV/SB_LABELT is a legacy table and a system without the
*   ShapeIt layer installed has no such table. A missing text table must
*   degrade to literals, not stop the seed.
    TRY.
        SELECT label_code, spras, labeltext
          FROM /qnv/sb_labelt
          WHERE spras = 'E' OR spras = 'A'
          INTO TABLE @DATA(lt_raw).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    LOOP AT lt_raw INTO DATA(ls_raw).
      INSERT VALUE #( code  = to_upper( ls_raw-label_code )
                      spras = ls_raw-spras
                      text  = ls_raw-labeltext ) INTO TABLE mt_l.
    ENDLOOP.
  ENDMETHOD.

  METHOD pick.
    READ TABLE mt_l INTO DATA(ls) WITH KEY code  = to_upper( iv_code )
                                           spras = iv_sp.
    IF sy-subrc = 0 AND ls-text IS NOT INITIAL.
      rv = ls-text.
      RETURN.
    ENDIF.
    mv_mis = mv_mis + 1.
    rv     = iv_else.
  ENDMETHOD.

  METHOD en.
    rv = pick( iv_code = iv_code iv_sp = 'E' iv_else = iv_else ).
  ENDMETHOD.

  METHOD ar.
    rv = pick( iv_code = iv_code iv_sp = 'A' iv_else = iv_else ).
  ENDMETHOD.

  METHOD missing.
    rv = mv_mis.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.

  lcl_txt=>load( ).

  DELETE FROM zrak_t_jny_rule WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  DELETE FROM zrak_t_jny_col  WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  DELETE FROM zrak_t_jny_opt  WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  DELETE FROM zrak_t_jny_fld  WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  DELETE FROM zrak_t_jny_step WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  DELETE FROM zrak_t_jny      WHERE journey_id IN (@c_book,@c_resch,@c_cancl).
  COMMIT WORK AND WAIT.

* -------------------------------------------------------------- headers
* LAYOUT_MODE 'SINGLE' on all three. Two steps do not need a wizard strip,
* and the legacy RAKSTAGEBAR on these screens is a 3-stage progress bar the
* portal draws round the whole service, not a step navigator.
*
* BKND_CATEGORY 'APPOINT' and BKND_JOURNEY 'BA01' are the export's CATEGORY
* and JOURNEYTYPE. Together they are how ZFM_EGA_CJ_FW_READ_N reaches
* ZCL_EGA_CJ_ENH_IMPL_OBA01: PARAM2 is the BAdI filter.
*
* No PAYFEE field and no payment carriers on any of the three. There is no
* PAYMENT control anywhere in the 327 export rows and no fee screen among
* the six - this service is free, and a PAID gate with nothing to pay would
* refuse every submit.
  INSERT zrak_t_jny FROM TABLE @( VALUE tt_jny(
    ( mandt         = sy-mandt
      journey_id    = c_book
      tile_code     = 'BA01'
      title         = lcl_txt=>en( iv_code = 'NEC_ND01_1_1_TITLE_TEXT'
                                   iv_else = 'Appointment Booking' )
      title_ar      = lcl_txt=>ar( iv_code = 'NEC_ND01_1_1_TITLE_TEXT'
                                   iv_else = 'حجز موعد' )
      subtitle      = 'Schedule a virtual meeting with an engineer'
      subtitle_ar   = 'حجز اجتماع افتراضي مع المهندسين'
      layout_mode   = 'SINGLE'
      theme_variant = 'PORTAL'
      accent_type   = 'Emphasized'
      density       = 'Cozy'
      show_actions  = ''
      active        = 'X'
      handler_class = 'ZCL_RAK_BA01_LOGIC'
      bknd_active   = 'X'
      bknd_category = 'APPOINT'
      bknd_journey  = 'BA01' )
*   BA02 and BA03 carry no TILE_CODE. They are not portal tiles - the
*   citizen reaches them from a row of the BA01 list, exactly as LINK_1 and
*   LINK_2 navigate on the legacy screen. A tile code here would put
*   "Reschedule Appointment" on the services page with nothing selected.
    ( mandt         = sy-mandt
      journey_id    = c_resch
      title         = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                                   iv_else = 'Reschedule an Appointment' )
      title_ar      = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                                   iv_else = 'إعادة جدولة الموعد' )
      layout_mode   = 'SINGLE'
      theme_variant = 'PORTAL'
      accent_type   = 'Emphasized'
      density       = 'Cozy'
      active        = 'X'
      handler_class = 'ZCL_RAK_BA01_LOGIC'
      bknd_active   = 'X'
      bknd_category = 'APPOINT'
      bknd_journey  = 'BA01' )
    ( mandt         = sy-mandt
      journey_id    = c_cancl
      title         = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                                   iv_else = 'Cancel an Appointment' )
      title_ar      = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                                   iv_else = 'إلغاء الموعد' )
      layout_mode   = 'SINGLE'
      theme_variant = 'PORTAL'
      accent_type   = 'Emphasized'
      density       = 'Cozy'
      active        = 'X'
      handler_class = 'ZCL_RAK_BA01_LOGIC'
      bknd_active   = 'X'
      bknd_category = 'APPOINT'
      bknd_journey  = 'BA01' ) ) ).

* ---------------------------------------------------------------- steps
* STP1 of BA01 carries NO_ACTION. The list is answered by pressing a row
* action or Book an Appointment, and the engine's three-way footer has no
* value for that: without NO_ACTION the step draws a Close button, which
* abandons a journey the citizen has not started. NO_ACTION is not
* NO_FORWARD - NO_FORWARD removes Next and lets Close through.
*
* BKND_SCREEN on STP1 is NBA01_1_1 so the read reaches the BAdI and
* GS_DATA-UPCOMING_APPOINTMENTS / PAST / CANCELLED come back. The screen
* posts nothing: the engine never commits a step whose footer has no
* forward action.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE tt_step(
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 10
      title    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_LABEL_17'
                              iv_else = 'Appointments' )
      title_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_LABEL_17'
                              iv_else = 'المواعيد' )
      icon = 'sap-icon://appointment-2' bknd_screen = 'NBA01_1_1'
      no_action = 'X' active = 'X' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 20
      title    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_LABEL_31'
                              iv_else = 'Book an Appointment' )
      title_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_LABEL_31'
                              iv_else = 'حجز موعد' )
      icon = 'sap-icon://add-appointment' bknd_screen = 'NBA01_1_2'
      columns = 2 active = 'X' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 10
      title    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                              iv_else = 'Reschedule Appointment' )
      title_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                              iv_else = 'إعادة جدولة الموعد' )
      icon = 'sap-icon://date-time' bknd_screen = 'NBA01_1_4'
      columns = 2 active = 'X' )
    ( mandt = sy-mandt journey_id = c_cancl step_id = 'STP1' seqnr = 10
      title    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                              iv_else = 'Cancel Appointment' )
      title_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                              iv_else = 'إلغاء الموعد' )
      icon = 'sap-icon://sys-cancel' bknd_screen = 'NBA01_1_5'
      active = 'X' ) ) ).

* -------------------------------------------------- BA01 / STP1 - the list
* Three TABLE fields, all HIDDEN, and the hiding is the point.
*
* They exist so ZCL_RAK_JOURNEY_BE->BACKEND_READ( ) reads them: its loop is
*   LOOP AT ls_step-fields WHERE type = 'EDITABLE_TABLE' OR type = 'TABLE' ...
* with no visibility test, so a hidden TABLE is still fetched through
* READ_TABLE( ) and parked in MT_BE_TABLE under its own field name. The
* handler then draws all three itself from GET_BACKEND_TABLE( ).
*
* Hand-drawn rather than configured because each Upcoming row needs TWO
* actions - Reschedule and Cancel - and a configured TABLE offers one row
* press. Claiming the field in RENDER_FIELD( ) would not work either:
* RENDER_BLOCK( ) answers ftype TABLE itself and never routes it through
* RENDER_ONE( ), the only caller of that hook, so the claim is dead code
* that looks live.
*
* FIELD_NAME is the MTABLE's name from the export, not the MTABLE_EXT's.
* UPCOMING_APPOINTMENTS_2 / PAST_APPOINTMENTS / CANCELLED_APPOINTMENTS are
* the rows; UPCOMING_APPOINTMENTS, MTABLE_EXT_2 and MTABLE_EXT_3 are
* presentation wrappers pointing back at them through DATA4.
*
* UPCOMING_APPOINTMENTS_2 is 23 characters - exactly on the model ceiling,
* not over it. Do not lengthen it.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE tt_fld(
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 10
      field_name = 'UPCOMING_APPOINTMENTS_2' ftype = 'TABLE' hidden = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_UPCOMING_APPOINTMENTS'
                               iv_else = 'Upcoming' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_UPCOMING_APPOINTMENTS'
                               iv_else = 'القادمة' )
      tech_name = 'GS_DATA-UPCOMING_APPOINTMENTS[]' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 20
      field_name = 'PAST_APPOINTMENTS' ftype = 'TABLE' hidden = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_PAST_APPOINTMENTS'
                               iv_else = 'Past' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_PAST_APPOINTMENTS'
                               iv_else = 'السابقة' )
      tech_name = 'GS_DATA-PAST_APPOINTMENTS[]' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 30
      field_name = 'CANCELLED_APPOINTMENTS' ftype = 'TABLE' hidden = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_CANCELLED_APPOINTMENTS'
                               iv_else = 'Canceled' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_CANCELLED_APPOINTMENTS'
                               iv_else = 'الملغية' )
      tech_name = 'GS_DATA-CANCELLED_APPOINTMENTS[]' )
*   Which of the three lists is on screen. Not posted anywhere - it is a
*   view switch, and the legacy screen does it with three TBUTTONs whose
*   UI_FIELD_LOGICS show one VBOX and hide the other two.
*   HIDDEN because the handler draws the switch itself, beside the list, and
*   a configured SEGMENTED as well would put two switches on one page.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 40
      field_name = 'APPT_VIEW' ftype = 'SEGMENTED' hidden = 'X'
      zlabel = 'View' zlabel_ar = 'العرض'
      default_val = 'U' )
*   The search box and the chosen sort, both HIDDEN for the same reason as
*   APPT_VIEW: the handler draws them itself, in the toolbar above the
*   list, and a configured control as well would put two of each on the
*   page. They are fields rather than instance attributes because a
*   handler's own attributes do not survive a round trip - only the model
*   does - so a search typed on one request has to be a model value to
*   still be filtering on the next.
*
*   Neither posts. There is no TECH_NAME on either, so ITEMS_FROM_KV( )
*   emits nothing for them and the BAdI never sees a UI filter.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 50
      field_name = 'APPT_SEARCH' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Search' zlabel_ar = 'بحث' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1' seqnr = 60
      field_name = 'APPT_SORT' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Sort' zlabel_ar = 'الترتيب' ) ) ).

  INSERT zrak_t_jny_opt FROM TABLE @( VALUE tt_opt(
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
      field_name = 'APPT_VIEW' opt_key = 'U' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_ITF_1' iv_else = 'Upcoming' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_ITF_1' iv_else = 'القادمة' ) )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
      field_name = 'APPT_VIEW' opt_key = 'P' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_ITF_2' iv_else = 'Past' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_ITF_2' iv_else = 'السابقة' ) )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
      field_name = 'APPT_VIEW' opt_key = 'C' seqnr = 30
      opt_text    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_ITF_3' iv_else = 'Canceled' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_ITF_3' iv_else = 'الملغية' ) ) ) ).

* Column headings for the three lists, in ZRAK_T_JNY_COL rather than packed
* into DEFAULT_VAL. That path has a real ZLABEL_AR column, is maintained on
* the Studio's column editor, and COL_ROWS_OF( ) reads it - the DEFAULT_VAL
* spec's fifth slot is the second-best way to say the same thing.
*
* The handler reads these for its hand-drawn headings, so a heading changed
* here reaches the screen with no code change.
*
* COL_NAME order is the LIST_SEQUENCE order in the export - 1 APPOINT_ID,
* 2 CASE_ID, 3 DATE, 4 TIME, 5 ASSIGNED_TO - and it has to stay that way.
* ZCL_EGA_CJ_ECOMP_ABS->READ( ) fills FIELDn as 'FIELD' && LIST_SEQUENCE,
* so the slot a value lands in comes from the legacy sequence, not from the
* order written here; the two disagreeing renders a neighbouring value with
* nothing reported.
  DATA lt_col  TYPE STANDARD TABLE OF zrak_t_jny_col WITH EMPTY KEY.
  DATA lt_tabs TYPE string_table.
  lt_tabs = VALUE string_table( ( `UPCOMING_APPOINTMENTS_2` )
                                ( `PAST_APPOINTMENTS` )
                                ( `CANCELLED_APPOINTMENTS` ) ).
  LOOP AT lt_tabs INTO DATA(lv_tab).
    DATA(lv_fld) = CONV zrak_t_jny_col-field_name( lv_tab ).
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
                    field_name = lv_fld col_name = 'APPOINT_ID' seqnr = 10
                    zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_APPOINT_ID_1'
                                             iv_else = 'Appointment ID' )
                    zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_APPOINT_ID_1'
                                             iv_else = 'رقم الموعد' )
                    readonly = 'X' width = '18%' ) TO lt_col.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
                    field_name = lv_fld col_name = 'CASE_ID' seqnr = 20
                    zlabel    = lcl_txt=>en( iv_code = 'NNTC_1_11_CASE_ID' iv_else = 'Case ID' )
                    zlabel_ar = lcl_txt=>ar( iv_code = 'NNTC_1_11_CASE_ID' iv_else = 'رقم الطلب' )
                    readonly = 'X' width = '18%' ) TO lt_col.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
                    field_name = lv_fld col_name = 'ZDATE' seqnr = 30
                    zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_DATE' iv_else = 'Date' )
                    zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_DATE' iv_else = 'التاريخ' )
                    readonly = 'X' width = '16%' ) TO lt_col.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
                    field_name = lv_fld col_name = 'ZTIME' seqnr = 40
                    zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_TIME' iv_else = 'Time' )
                    zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_TIME' iv_else = 'الوقت' )
                    readonly = 'X' width = '16%' ) TO lt_col.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book step_id = 'STP1'
                    field_name = lv_fld col_name = 'ASSIGNED_TO' seqnr = 50
                    zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_ASSIGNED_TO'
                                             iv_else = 'Assigned to' )
                    zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_ASSIGNED_TO'
                                             iv_else = 'مُعين إلى' )
                    readonly = 'X' width = '22%' ) TO lt_col.
  ENDLOOP.
* ZDATE / ZTIME, not DATE / TIME. COL_NAME reaches
* CL_ABAP_STRUCTDESCR=>CREATE( ) through BUILD_MODEL( )'s inner row
* structure, and a column called DATE or TIME is a reserved-word collision
* waiting to happen in generated code. The legacy LIST_SEQUENCE is what
* positions the cell, so the CJS-side name is free.
  INSERT zrak_t_jny_col FROM TABLE @lt_col.

* ------------------------------------------------ BA01 / STP2 - the form
* ONE step, both tabs, and BOOK_TYPE is the tab.
*
* The legacy screen is an ITB with two ITFs - My Case and General Enquiries
* - holding two parallel sets of controls that differ in three places: the
* case tab has Case ID and Discipline where the general tab has Sector, and
* its comments box is a mandatory Meeting reason where the general tab's is
* an optional Comments. Everything else is the same question asked twice
* into a different GS_DATA component.
*
* A SEGMENTED plus rules reproduces that in configuration, which is where
* show/hide belongs. The two sets stay two sets of fields rather than one
* shared set because the BACKEND keeps them apart: GS_DATA-EMAIL and
* GS_DATA-EMAIL_2 are different components and UPDATE( ) reads whichever
* matches the branch it took.
*
* REQUIRED is set on both sets, and that is safe: VALIDATE_STEP( ) skips
* hidden fields outright, so the half that is not on screen is not checked.
*
* FGROUP 'ROW:n' pairs the fields the way the live screen does - Case ID
* beside Discipline beside Engineer, Date beside Time Slot, Email beside
* Mobile.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE tt_fld(
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 10
      field_name = 'BOOK_TYPE' ftype = 'SEGMENTED' required = 'X'
      zsection    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_LABEL_31'
                                 iv_else = 'Book an Appointment' )
      zsection_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_LABEL_31'
                                 iv_else = 'حجز موعد' )
      default_val = 'C' )

*   ---- My Case ------------------------------------------------------
*   No legacy label code: on NBA01_1_2 the Case ID caption is drawn INSIDE
*   the APPOINTMENT control, so /QNV has no row for it. NNTC_1_11_CASE_ID
*   is the code the export uses for the same words on the list's Case ID
*   column, which is the nearest thing the department actually owns.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 20
      field_name = 'AVAILABLE_CASE_ID' ftype = 'SELECT' fgroup = 'ROW:1'
      zlabel    = lcl_txt=>en( iv_code = 'NNTC_1_11_CASE_ID' iv_else = 'Case ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NNTC_1_11_CASE_ID' iv_else = 'رقم الطلب' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-AVAILABLE_CASE_ID' )
*   REQUIRED although the live screen draws no asterisk on it. VALIDATE( )'s
*   CREATE branch refuses a case-tab booking with a blank PICKED_ROLE -
*   message 114, 'Role is mandatory' - so a citizen who leaves it alone
*   cannot submit. A field the backend enforces and the form does not mark
*   is the looks-optional-and-will-not-submit bug; the marker is the honest
*   half to change.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 30
      field_name = 'PICKED_ROLE' ftype = 'SELECT' required = 'X' fgroup = 'ROW:1'
      zlabel = 'Discipline' zlabel_ar = 'تخصص'
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-PICKED_ROLE' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 40
      field_name = 'ENGINEER_ID' ftype = 'SELECT' required = 'X' fgroup = 'ROW:1'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'المهندس' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      msg = 'REQUIRED:Please select the designated engineer handling your application'
      tech_name = 'GS_DATA-ENGINEER_ID' )
*   The red note under Case ID on the live screen. DISPLAY, and the text
*   rides DEFAULT_VAL behind TEXT: rather than sitting in ZLABEL, which is
*   CHAR(150) and cuts on INSERT with nothing reported.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 50
      field_name = 'CASE_INFO' ftype = 'DISPLAY' readonly = 'X'
      default_val = 'TEXT:Only rejected/pending Customer action cases will be displayed' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 60
      field_name = 'APPOINT_DATE' ftype = 'DATE' required = 'X' fgroup = 'ROW:2'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'Pick a Date' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'تاريخ الموعد' )
      placeholder = 'e.g. Dec 31, 2026' placeholder_ar = 'على سبيل المثال 2026/12/31'
      tech_name = 'GS_DATA-PICKED_DATE' )
*   CLOSED_LIST: a slot is picked from what is free, never typed. Without it
*   the engine draws a typable ComboBox and a citizen can enter a slot that
*   was filtered out as taken.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 70
      field_name = 'APPOINT_TIME' ftype = 'SELECT' required = 'X' fgroup = 'ROW:2'
      closed_list = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'Time Slot' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'وقت الموعد' )
      tech_name = 'GS_DATA-PICKED_TIME' )

*   ---- General Enquiries --------------------------------------------
*   Not REQUIRED, matching the live screen, which draws no asterisk on
*   Sector ID. VALIDATE( ) only insists that ONE of AVAILABLE_CASE_ID and
*   SECTOR_ID is filled, which is a cross-field rule no single field's
*   REQUIRED flag can express - ON_CUSTOM_VALIDATE( ) carries it.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 80
      field_name = 'SECTOR_ID' ftype = 'SELECT' fgroup = 'ROW:3'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_SECTOR_ID' iv_else = 'Sector ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_SECTOR_ID' iv_else = 'القسم' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-SECTOR_ID' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 90
      field_name = 'ENGINEER_2' ftype = 'SELECT' required = 'X' fgroup = 'ROW:3'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'المهندس' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-ENGINEER_ID_2' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 100
      field_name = 'APPOINT_DATE_2' ftype = 'DATE' required = 'X' fgroup = 'ROW:4'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'Pick a Date' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'تاريخ الموعد' )
      placeholder = 'e.g. Dec 31, 2026' placeholder_ar = 'على سبيل المثال 2026/12/31'
      tech_name = 'GS_DATA-PICKED_DATE_2' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 110
      field_name = 'APPOINT_TIME_2' ftype = 'SELECT' required = 'X' fgroup = 'ROW:4'
      closed_list = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'Time Slot' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'وقت الموعد' )
      tech_name = 'GS_DATA-PICKED_TIME_2' )

*   ---- Case Details -------------------------------------------------
*   SHLP, not hand-seeded options. The export gives both clarification
*   comboboxes SH_NAME = ZSH_CJ_APPOINT_SUBJECT with SH_EL_KEY 'KEY' and
*   SH_EL_VALUE 'VALUE', so the four choices on the live screen come from a
*   real search help. Seeding them as OPT rows would fork a list the
*   department maintains elsewhere.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 120
      field_name = 'REQ_CLARIFICATION' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_APPOINT_SUBJECT'
      zsection    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_CASE_DETAILS' iv_else = 'Case Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_CASE_DETAILS' iv_else = 'تفاصيل الطلب' )
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'Request Clarification' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'طلب ايضاح' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-REQUEST_CLARIFICATION' )
*   Meeting reason - MANDATORY on the case tab only, and it is the newest
*   rule on this service: VALIDATE( ) message 116, added 08.04.2026, refuses
*   a case-tab booking with an empty GS_DATA-COMMENTS.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 130
      field_name = 'COMMENTS_TEXTAREA' ftype = 'TEXTAREA' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_LABEL_13' iv_else = 'Meeting reason' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_LABEL_13' iv_else = 'سبب الاجتماع' )
      msg = 'REQUIRED:Meeting reason is required. Please enter a meeting reason to proceed'
      tech_name = 'GS_DATA-COMMENTS' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 140
      field_name = 'REQ_CLARIFICATION_2' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_APPOINT_SUBJECT'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'Request Clarification' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'طلب ايضاح' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-REQUEST_CLARIFICATION_2' )
*   Optional, deliberately. The general tab's box is Comments on the live
*   screen and VALIDATE( )'s SECTOR_ID branch never looks at COMMENTS_2.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 150
      field_name = 'COMMENTS_TEXTAREA_2' ftype = 'TEXTAREA'
      zlabel    = lcl_txt=>en( iv_code = 'TITLE_COMMENTS' iv_else = 'Comments' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'TITLE_COMMENTS' iv_else = 'الملاحظات' )
      tech_name = 'GS_DATA-COMMENTS_2' )

*   ---- Contact Details ----------------------------------------------
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 160
      field_name = 'CONTACT_NOTE' ftype = 'DISPLAY' readonly = 'X'
      zsection    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_LABEL_14'
                                 iv_else = 'Contact Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_LABEL_14'
                                 iv_else = 'بيانات الاتصال' )
      default_val = 'TEXT:You will receive the meeting link and updates on the following contact details:' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 170
      field_name = 'EMAIL_INPUT' ftype = 'EMAIL' required = 'X' fgroup = 'ROW:5'
      zlabel    = lcl_txt=>en( iv_code = 'EMAIL' iv_else = 'Email' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'EMAIL' iv_else = 'البريد الإلكتروني' )
      tech_name = 'GS_DATA-EMAIL' )
*   REGEX, and both message keys. VALIDATE( ) accepts a mobile that is all
*   digits AND starts 05 or 9715, so the pattern says both things at once.
*   FORMAT: alone would be enough here because the field carries no MIN_VAL
*   or MAX_VAL - the numeric gate that would otherwise run first and stop
*   FORMAT being reached - but a range added later would silently swap the
*   wording, so NUMBER: is written now.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 180
      field_name = 'MOBILE_INPUT' ftype = 'PHONE' required = 'X' fgroup = 'ROW:5'
      zlabel    = lcl_txt=>en( iv_code = 'ECOMP_NEC01_1_1_LABEL_11' iv_else = 'Mobile' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'ECOMP_NEC01_1_1_LABEL_11' iv_else = 'رقم الهاتف' )
      regex = '^(05[0-9]{8}|9715[0-9]{8})$'
      msg = 'REQUIRED:Please enter your mobile number;FORMAT:Please enter a valid mobile number;NUMBER:Please enter a valid mobile number'
      tech_name = 'GS_DATA-MOBILE' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 190
      field_name = 'EMAIL_INPUT_2' ftype = 'EMAIL' required = 'X' fgroup = 'ROW:6'
      zlabel    = lcl_txt=>en( iv_code = 'NEC_ND01_1_1_EMAIL' iv_else = 'Email' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NEC_ND01_1_1_EMAIL' iv_else = 'البريد الإلكتروني' )
      tech_name = 'GS_DATA-EMAIL_2' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 200
      field_name = 'MOBILE_INPUT_2' ftype = 'PHONE' required = 'X' fgroup = 'ROW:6'
      zlabel    = lcl_txt=>en( iv_code = 'ECOMP_NEC01_1_1_LABEL_11' iv_else = 'Mobile' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'ECOMP_NEC01_1_1_LABEL_11' iv_else = 'رقم الهاتف' )
      regex = '^(05[0-9]{8}|9715[0-9]{8})$'
      msg = 'REQUIRED:Please enter your mobile number;FORMAT:Please enter a valid mobile number;NUMBER:Please enter a valid mobile number'
      tech_name = 'GS_DATA-MOBILE_2' )

*   ---- the wire ------------------------------------------------------
*   The two JSON carriers. HIDDEN, never drawn, and the whole reason the
*   pickers above reach the backend at all: UPDATE( )'s GV_SAVE_DRAFT
*   branch assigns AVAILABLE_CASE_ID, PICKED_DATE, PICKED_TIME_FROM/TO,
*   ENGINEER_ID, PICKED_ROLE and SECTOR_ID from the deserialized JSON,
*   overwriting whatever the item rows carried. ON_BEFORE_POST( ) fills
*   these two.
*
*   ftype INPUT rather than a type of their own: they need a model
*   component and a TECH_NAME and nothing else. ITEMS_FROM_KV( ) only
*   emits a key that matches a configured field, so deleting either of
*   these silently stops the JSON being posted.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 210
      field_name = 'APPOINT_1' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Appointment payload' zlabel_ar = 'بيانات الموعد'
      tech_name = 'GS_DATA-APPOINT_JSON' )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2' seqnr = 220
      field_name = 'APPOINT_JSON2_1' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Appointment payload (enquiry)' zlabel_ar = 'بيانات الموعد (استفسار)'
      tech_name = 'GS_DATA-APPOINT_JSON2' ) ) ).

  INSERT zrak_t_jny_opt FROM TABLE @( VALUE tt_opt(
*   'C' and 'G' are the control's own two modes - DATA1 on APPOINT_1 is 'C'
*   and on APPOINT_JSON2_1 is 'G' - and READ( ) flips a reschedule to 'G'
*   when the appointment has no related ZG19 case. Using the same two
*   letters means the handler never translates.
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2'
      field_name = 'BOOK_TYPE' opt_key = 'C' seqnr = 10
      opt_text    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_ITF_1' iv_else = 'My Case' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_ITF_1' iv_else = 'طلباتي' ) )
    ( mandt = sy-mandt journey_id = c_book step_id = 'STP2'
      field_name = 'BOOK_TYPE' opt_key = 'G' seqnr = 20
      opt_text    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_2_ITF_2' iv_else = 'General Enquiries' )
      opt_text_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_2_ITF_2' iv_else = 'استفسارات عامة' ) ) ) ).

* ---------------------------------------------------------------- rules
* BOOK_TYPE drives the tab, in configuration rather than in ON_CHANGE( ).
*
* BOTH DIRECTIONS FOR EVERY FIELD. A SHOW on its own leaves the other tab's
* panel on screen after the segment is switched back - still holding values,
* still posting them - and on this journey that would post EMAIL and
* EMAIL_2 together, which is the shape UPDATE( ) uses to decide which
* branch it is in.
*
* Generated rather than typed: 36 near-identical rows, and exactly one of
* them gets a copy-paste slip if they are written out by hand.
*
* RULE_ID IS CHAR(3). Four prefixes of one letter plus a NUMC(2) - C/D for
* the case set, G/H for the general set. Writing C01..C10 with a string
* template's WIDTH instead would be fine here but NUMC is leading-zero by
* definition and needs no alignment argument; and a two-character prefix
* would truncate to a duplicate key and short-dump on the INSERT, pointing
* at the statement rather than at the naming.
  DATA lt_rule TYPE tt_rule.
  DATA lv_n    TYPE n LENGTH 2.

  DATA(lt_case) = VALUE string_table(
    ( `AVAILABLE_CASE_ID` ) ( `PICKED_ROLE` )       ( `ENGINEER_ID` )
    ( `CASE_INFO` )         ( `APPOINT_DATE` )      ( `APPOINT_TIME` )
    ( `REQ_CLARIFICATION` ) ( `COMMENTS_TEXTAREA` ) ( `EMAIL_INPUT` )
    ( `MOBILE_INPUT` ) ).

  DATA(lt_gen) = VALUE string_table(
    ( `SECTOR_ID` )           ( `ENGINEER_2` )            ( `APPOINT_DATE_2` )
    ( `APPOINT_TIME_2` )      ( `REQ_CLARIFICATION_2` )   ( `COMMENTS_TEXTAREA_2` )
    ( `EMAIL_INPUT_2` )       ( `MOBILE_INPUT_2` ) ).

  LOOP AT lt_case INTO DATA(lv_cf).
    lv_n = sy-tabix.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book rule_id = |C{ lv_n }|
                    src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'C'
                    action = 'SHOW' tgt_field = lv_cf ) TO lt_rule.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book rule_id = |D{ lv_n }|
                    src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'G'
                    action = 'HIDE' tgt_field = lv_cf ) TO lt_rule.
  ENDLOOP.

  LOOP AT lt_gen INTO DATA(lv_gf).
    lv_n = sy-tabix.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book rule_id = |G{ lv_n }|
                    src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'G'
                    action = 'SHOW' tgt_field = lv_gf ) TO lt_rule.
    APPEND VALUE #( mandt = sy-mandt journey_id = c_book rule_id = |H{ lv_n }|
                    src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'C'
                    action = 'HIDE' tgt_field = lv_gf ) TO lt_rule.
  ENDLOOP.

* BA02 shows Discipline on a case reschedule and Sector on a general one,
* off the same BOOK_TYPE the booking form uses. Four rows, both directions
* for each field, because a SHOW on its own leaves the other selector on
* screen still holding a value and still posting it - and on this journey
* the two go to different GS_DATA components.
  APPEND VALUE #( mandt = sy-mandt journey_id = c_resch rule_id = 'R01'
                  src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'C'
                  action = 'SHOW' tgt_field = 'PICKED_ROLE' ) TO lt_rule.
  APPEND VALUE #( mandt = sy-mandt journey_id = c_resch rule_id = 'R02'
                  src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'G'
                  action = 'HIDE' tgt_field = 'PICKED_ROLE' ) TO lt_rule.
  APPEND VALUE #( mandt = sy-mandt journey_id = c_resch rule_id = 'R03'
                  src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'G'
                  action = 'SHOW' tgt_field = 'SECTOR_ID' ) TO lt_rule.
  APPEND VALUE #( mandt = sy-mandt journey_id = c_resch rule_id = 'R04'
                  src_field = 'BOOK_TYPE' src_op = 'EQ' src_value = 'C'
                  action = 'HIDE' tgt_field = 'SECTOR_ID' ) TO lt_rule.

  INSERT zrak_t_jny_rule FROM TABLE @lt_rule.

* --------------------------------------------- BA02 - reschedule (NBA01_1_4)
* The appointment being rescheduled is DISPLAY, not an input. The legacy
* screen shows it as a caption and a value beside it and offers no way to
* change it: READ( ) has already pinned it, and the control it hands the
* JSON to is given CASE_UNCHANGABLE true.
*
* APPOINT_1_RE KEEPS ITS EXACT NAME. It is one of the field names
* ZCL_EGA_CJ_ENH_IMPL_OBA01~READ( ) branches on - WHEN 'APPOINT_1_RE' sets
* additionaldata1 = 'G' when the appointment has no related ZG19 case, which
* is how a rescheduled general enquiry keeps its general-enquiry shape.
* Renamed, the field would never receive that and every reschedule would be
* treated as a case booking.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE tt_fld(
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 10
      field_name = 'AVAILABLE_CASE_ID' ftype = 'DISPLAY' readonly = 'X'
      zsection    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                                 iv_else = 'Reschedule Appointment' )
      zsection_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_4_LABEL_5'
                                 iv_else = 'إعادة جدولة الموعد' )
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_MTABLE_COL_9'
                               iv_else = 'Appointment ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_MTABLE_COL_9'
                               iv_else = 'رقم الموعد' )
      tech_name = 'GS_DATA-AVAILABLE_CASE_ID' )
*   BOTH SELECTORS, AND A HIDDEN BOOK_TYPE TO CHOOSE BETWEEN THEM.
*
*   A reschedule keeps the shape of the appointment it is rescheduling, and
*   the two shapes ask different questions: a case appointment asks for the
*   Discipline, a general enquiry asks for the Sector. The live screen
*   proves it - rescheduling appointment 1986479, which has no related
*   case, draws "Sector ID / Inspection" where a case reschedule draws
*   Discipline, and no Discipline field at all.
*
*   ZCL_EGA_CJ_ENH_IMPL_OBA01~READ( ) is what decides, server-side: its
*   WHEN 'APPOINT_1_RE' branch looks the appointment up in ZDT_EGA_CAAT_GEN
*   and sets additionaldata1 = 'G' when ZG19_CASE_ID is blank. CJS cannot
*   see that flag, but it CAN see the same fact - the related case id
*   travels back inside GS_DATA-APPOINT_JSON, which APPOINT_1_RE carries -
*   so ON_AFTER_READ( ) reads it there and sets BOOK_TYPE, and the rules
*   below do the rest in configuration.
*
*   NOT the same test as AVAILABLE_CASE_ID being blank. On this journey
*   that field holds the APPOINTMENT id, never the case id: READ( ) assigns
*   gs_data-available_case_id = lv_appoint_id and puts lv_related_case_id
*   in the JSON instead. Testing the wrong one would call every reschedule
*   a case reschedule.
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 15
      field_name = 'BOOK_TYPE' ftype = 'SEGMENTED' hidden = 'X'
      zlabel = 'Booking type' zlabel_ar = 'نوع الحجز'
      default_val = 'C' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 20
      field_name = 'PICKED_ROLE' ftype = 'SELECT' required = 'X' fgroup = 'ROW:1'
      zlabel = 'Discipline' zlabel_ar = 'تخصص'
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-PICKED_ROLE' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 25
      field_name = 'SECTOR_ID' ftype = 'SELECT' fgroup = 'ROW:1'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_SECTOR_ID' iv_else = 'Sector ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_SECTOR_ID' iv_else = 'القسم' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-SECTOR_ID' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 30
      field_name = 'ENGINEER_ID' ftype = 'SELECT' required = 'X' fgroup = 'ROW:1'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_ENGINEER' iv_else = 'المهندس' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-ENGINEER_ID' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 40
      field_name = 'APPOINT_DATE' ftype = 'DATE' required = 'X' fgroup = 'ROW:2'
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'Pick a Date' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_DATE' iv_else = 'تاريخ الموعد' )
      placeholder = 'e.g. Dec 31, 2026' placeholder_ar = 'على سبيل المثال 2026/12/31'
      tech_name = 'GS_DATA-PICKED_DATE' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 50
      field_name = 'APPOINT_TIME' ftype = 'SELECT' required = 'X' fgroup = 'ROW:2'
      closed_list = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'Time Slot' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NEC_ND01_1_1_TIME_SLOT' iv_else = 'وقت الموعد' )
      tech_name = 'GS_DATA-PICKED_TIME' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 60
      field_name = 'REQ_CLARIFICATION' ftype = 'SELECT' required = 'X'
      shlp = 'ZSH_CJ_APPOINT_SUBJECT'
      zsection    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_CASE_DETAILS' iv_else = 'Case Details' )
      zsection_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_CASE_DETAILS' iv_else = 'تفاصيل الطلب' )
      zlabel    = lcl_txt=>en( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'Request Clarification' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'NBA_ND01_1_2_REQUEST' iv_else = 'طلب ايضاح' )
      placeholder = 'select' placeholder_ar = 'تحديد'
      tech_name = 'GS_DATA-REQUEST_CLARIFICATION' )
*   MANDATORY on the export row, unlike the booking screen's twin, which
*   only became mandatory through VALIDATE( ) in April.
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 70
      field_name = 'COMMENTS_TEXTAREA' ftype = 'TEXTAREA' required = 'X'
      zlabel    = lcl_txt=>en( iv_code = 'TITLE_COMMENTS' iv_else = 'Comments' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'TITLE_COMMENTS' iv_else = 'الملاحظات' )
      tech_name = 'GS_DATA-COMMENTS' )
    ( mandt = sy-mandt journey_id = c_resch step_id = 'STP1' seqnr = 80
      field_name = 'APPOINT_1_RE' ftype = 'INPUT' hidden = 'X'
      zlabel = 'Appointment payload' zlabel_ar = 'بيانات الموعد'
      tech_name = 'GS_DATA-APPOINT_JSON' ) ) ).

* ------------------------------------------------- BA03 - cancel (NBA01_1_5)
* One question. DATA1 on the export's textarea is 250, which is the reason
* for MAX_LEN - the legacy control caps the box and the citizen is told
* rather than truncated on the way in.
*
* MAX_LEN never reads a plain MSG, only an explicit LEN: clause, which is
* why the message below is keyed rather than written as a bare sentence.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE tt_fld(
    ( mandt = sy-mandt journey_id = c_cancl step_id = 'STP1' seqnr = 10
      field_name = 'AVAILABLE_CASE_ID' ftype = 'DISPLAY' readonly = 'X'
      zsection    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                                 iv_else = 'Cancel Appointment' )
      zsection_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_5_LABEL_3'
                                 iv_else = 'إلغاء الموعد' )
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_1_MTABLE_COL_15'
                               iv_else = 'Appointment ID' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_1_MTABLE_COL_15'
                               iv_else = 'رقم الموعد' )
      tech_name = 'GS_DATA-AVAILABLE_CASE_ID' )
    ( mandt = sy-mandt journey_id = c_cancl step_id = 'STP1' seqnr = 20
      field_name = 'COMMENTS_TEXTAREA' ftype = 'TEXTAREA' required = 'X'
      max_len = 250
      zlabel    = lcl_txt=>en( iv_code = 'APPOINT_NBA01_1_5_LABEL_13'
                               iv_else = 'Could you share the reason for canceling this appointment?' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'APPOINT_NBA01_1_5_LABEL_13'
                               iv_else = 'هل يمكن أن توضح سبب إلغاء هذا الموعد؟' )
      msg = 'REQUIRED:Cancellation reason is mandatory;LEN:Please keep the reason under 250 characters'
      tech_name = 'GS_DATA-CANCELATION_REASON' ) ) ).

  COMMIT WORK AND WAIT.

* A versioned per-work-process cache means another work process keeps
* serving the old config, and the change then looks like it did not take.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_book ) ).
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_resch ) ).
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_cancl ) ).

* ----------------------------------------------------------- walkthrough
  WRITE: / 'BA01 / BA02 / BA03 - Online Appointment Booking seeded.'.
  SKIP.
  WRITE: / 'WHAT WENT IN'.
  WRITE: / '  BA01  Appointment Booking   STP1 list (NBA01_1_1) + STP2 book (NBA01_1_2)'.
  WRITE: / '  BA02  Reschedule            STP1 (NBA01_1_4)'.
  WRITE: / '  BA03  Cancel                STP1 (NBA01_1_5)'.
  WRITE: / '  All three: category APPOINT, BAdI filter BA01, handler ZCL_RAK_BA01_LOGIC.'.
  SKIP.

  DATA(lv_miss) = lcl_txt=>missing( ).
  IF lv_miss > 0.
    WRITE: / 'WORDING', lv_miss, 'label(s) had no /QNV/SB_LABELT row and fell back'.
    WRITE: / '  to the literal transcribed from the live screenshots. That is a'.
    WRITE: / '  fallback, not the authority - if this count is high, the legacy text'.
    WRITE: / '  table is not in this client and the Arabic on screen is a'.
    WRITE: / '  transcription rather than the department own wording.'.
  ELSE.
    WRITE: / 'WORDING  every label resolved from /QNV/SB_LABELT. No literals used.'.
  ENDIF.
  SKIP.

  WRITE: / 'TO TRY IT'.
  WRITE: / '  1  Launch BA01 with &trace=x. STP1 should list the partner appointments'.
  WRITE: / '     under Upcoming / Past / Canceled, with Reschedule and Cancel on each'.
  WRITE: / '     upcoming row and Book an Appointment above the list.'.
  WRITE: / '  2  Press Book. STP2 opens on My Case. Switching to General Enquiries'.
  WRITE: / '     must REPLACE the fields, not add to them - if both Email boxes are'.
  WRITE: / '     on screen at once a HIDE rule did not fire and the post will carry'.
  WRITE: / '     both branches.'.
  WRITE: / '  3  Pick a date. The time slots are built by the handler and slots'.
  WRITE: / '     already taken for that engineer are not offered. When NOTHING is'.
  WRITE: / '     free the strip says "No slots available" - the same words the live'.
  WRITE: / '     screen puts under the Time Slot box.'.
  WRITE: / '  3a Back on STP1, the Search box filters all five columns and the'.
  WRITE: / '     Appointment ID and Case ID headings sort three ways - ascending,'.
  WRITE: / '     descending, then back to the backend own newest-first order.'.
  WRITE: / '     Past and Canceled draw no Reschedule or Cancel, by design.'.
  WRITE: / '  3b Reschedule a GENERAL enquiry (one whose Case ID shows -) and the'.
  WRITE: / '     screen must ask for a SECTOR, not a Discipline. If it asks for a'.
  WRITE: / '     Discipline, BOOK_TYPE was derived from the wrong field - see'.
  WRITE: / '     ON_AFTER_READ in the handler.'.
  WRITE: / '  4  Submit. The trace prints the APPOINT_JSON that went out - check'.
  WRITE: / '     date is yyyymmdd and appointment is HHMMHHMM before believing a'.
  WRITE: / '     case with a blank slot is a backend problem.'.
  SKIP.

  WRITE: / 'KNOWN, AND NOT WORKED AROUND HERE'.
  WRITE: / '  PARAM3  ZCL_RAK_QNV_BRIDGE sends the partner as PARAM3 on every read.'.
  WRITE: / '          ZCL_EGA_CJ_ENH_IMPL_OBA01~READ reads PARAM3 as a row index'.
  WRITE: / '          (gs_data-reschedule_col) and then READ TABLE ... INDEX on it.'.
  WRITE: / '          On the legacy path PARAM3 IS a row index - LINK_1 NAVTO sets'.
  WRITE: / '          param3-UPCOMING_APPOINTMENTS. Needs a decision, not a patch.'.
  WRITE: / '  LISTS   Case ID, Discipline, Engineer and Sector have no source in'.
  WRITE: / '          this system. They came from the OData service behind the'.
  WRITE: / '          APPOINTMENT control and that service is still unidentified.'.
  WRITE: / '          The handler answers all four from named resolver methods that'.
  WRITE: / '          return nothing today and say so on the trace.'.
  WRITE: / '  Request Clarification is NOT one of those - it has a real search help,'.
  WRITE: / '  ZSH_CJ_APPOINT_SUBJECT, and is configured as SHLP.'.
  WRITE: / '  CONFIRM The two confirmation screens are the engine own result page, so'.
  WRITE: / '          a cancellation ends on "Application submitted" rather than the'.
  WRITE: / '          live screen "Your Appointment is Cancelled! / The assigned'.
  WRITE: / '          engineer has been notified." That wording is global to every'.
  WRITE: / '          journey (ZCL_RAK_TEXT c_no-res_submitted), so making it'.
  WRITE: / '          per-journey is an engine change and is not made here.'.
  SKIP.
  WRITE: / 'THREE COLUMNS THIS SEED WRITES ARE IN GIT BUT MAY NOT BE IN SAP'.
  WRITE: / '  ZRAK_T_JNY_FLD-ZSECTION_AR   Arabic section headings'.
  WRITE: / '  ZRAK_T_JNY_FLD-CLOSED_LIST   the two Time Slot dropdowns'.
  WRITE: / '  ZRAK_T_JNY_STEP-NO_ACTION    the footer on the list step'.
  WRITE: / '  All three need activation AND a table adjust before a seeded value'.
  WRITE: / '  is true. Until then the section headings render English to an Arabic'.
  WRITE: / '  reader, the slot dropdowns stay typable, and the list step draws a'.
  WRITE: / '  Close button that abandons a journey the citizen has not started.'.
