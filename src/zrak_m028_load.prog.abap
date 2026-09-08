*&---------------------------------------------------------------------*
*& Report ZRAK_M028_LOAD
*&---------------------------------------------------------------------*
*& M028 Preliminary Design Approval Request - feeder, not the migrator.
*&
*& Re-runnable: deletes its own rows first, then inserts. Same deliberate
*& hand-authored path as ZRAK_M017_LOAD / ZRAK_M029_LOAD.
*&
*& ------------------------------------------------------------------
*& WHERE EVERY NAME BELOW COMES FROM
*&
*& /QNV/SB_UI_DEFIN, category DML, screens NCOD_1_1..1_3, read off the
*& full export. The walkthrough screenshots give the step count and the
*& layout; only the export gives FIELD_NAME, and the backend's field
*& control keys on the legacy name end to end.
*&
*&   NCOD_1_1  MY_COMPONENT   RAK_PROJECTLIST     -> ftype SELECT
*&             INTRENO_PROJECT  carrier, TOSAVE
*&   NCOD_1_2  NAME_DATA / LICENS_DATA / GRADE_DATA   LABEL
*&             EXPIRY_DATA                            DATE_FORMATTER
*&                 - together the read-only "Current Consultant" card
*&             ADDBUILDING    RAK_BUILDINGCONTROL
*&   NCOD_1_3  CB1..CB6       CHECKBOX   TOSAVE  LABEL_CON COD_1_4_CHB1..6
*&             SI1..SI6       STEPINPUT  TOSAVE
*&
*& ------------------------------------------------------------------
*& THREE STEPS, AND NO PAYMENT - THIS IS A DELIBERATE DIVERGENCE FROM
*& THE EXPORT, MADE ON INSTRUCTION. Read this before "fixing" it.
*&
*& The walkthrough says "No payment screen in sequence" and shows a
*& three-stop stepper ending in Submit: Project Selection, Building
*& Details, Required Discipline.
*&
*& THE EXPORT DISAGREES. NCOD_1_4 and NCOD_1_6 both exist and both carry
*& the full CPG envelope - RAKPAY, RAKREMAININGFEES, PW_RB1/PW_RB2,
*& MERCHANTID, SECRETKEY, REFERENCEID - and so does NCOD_3_1, the later
*& stage. ZRAK_M_MUNI_LOAD also carries M028 in its pay = abap_true
*& group.
*&
*& The screenshots were followed, as instructed. What that means in
*& practice, stated plainly so nobody has to rediscover it:
*&
*&   - no PAYFEE field is seeded, so the citizen has no way to pay
*&   - the journey submits at the end of step 3
*&   - if a fee DOES exist for this service, it is collected somewhere
*&     other than this journey, or not at all
*&
*& If a fee turns out to be due, the fix is a fourth step on NCOD_1_6
*& with a PAYFEE field, and a handler that chains the PAID gate - not a
*& change to the three steps below.
*&
*& ------------------------------------------------------------------
*& THE BUILDING LIST IS EDITABLE_TABLE, NOT ftype BUILDINGS.
*&
*& ZCL_RAK_MIGRATOR->CLASSIFY( ) maps RAK_BUILDINGCONTROL to ftype
*& BUILDINGS, which renders through the SELECT branch fed by
*& ZCL_RAK_CJ_OPTS off an API: directive - in other words a VALUE HELP,
*& a list of buildings that already exist to pick from.
*&
*& That is not this screen. The walkthrough shows an "Add Building"
*& button opening a popup of eleven TYPED fields - name, type, usage,
*& cost, height, and six floor counts - and the result landing in a list.
*& The citizen is creating buildings, not choosing them, so a dropdown
*& fed by a read would offer nothing on a new request.
*&
*& Hence EDITABLE_TABLE plus a handler-drawn popup. The migrator's
*& mapping is not wrong in general - it is wrong for THIS screen - which
*& is exactly why M028 is hand-authored rather than migrated.
*&
*& ------------------------------------------------------------------
*& NOT VERIFIED FROM HERE - all named in the run log too:
*&
*& 1. ZEGA_T_CJ_UI_MAP must carry NCOD_1_1..1_3. A screen correct in
*&    /QNV and missing from the map posts, returns success and creates
*&    nothing. Rule X16 in ZCL_RAK_CJS_XCHECK reports it CJS-side.
*& 2. MY_COMPONENT has no option list. RAK_PROJECTLIST fills itself from
*&    a read in the legacy control; the export names no search help. An
*&    empty dropdown is deliberate - see the note at the field.
*& 3. Building type and Building usage type have no option lists either,
*&    for the same reason and with the same consequence.
*& 4. The six discipline pairs are the export's. The walkthrough shows
*&    only FOUR (Structural, Architecture, Electrical, Mechanical), so
*&    two are presumably hidden by the live field control. They are all
*&    seeded, because a field the BAdI hides costs nothing and a field it
*&    expects and cannot find is a silent gap.
*&---------------------------------------------------------------------*
REPORT zrak_m028_load.

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M028'.

* ------------------------------------------------------- legacy wording
* LABELS ARE READ, NEVER TYPED - same helper, same rule and same
* reasoning as ZRAK_M017_LOAD and ZRAK_M029_LOAD. /QNV/SB_LABELT holds
* the department's own wording for every LABEL_CON code in the export,
* one row per SPRAS. The fallback is the literal, never blank.
CLASS lcl_txt DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS en
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ar
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
  PRIVATE SECTION.
    CLASS-METHODS pick
      IMPORTING iv_code   TYPE /qnv/sb_labelt-label_code
                iv_spras  TYPE sy-langu
                iv_fb     TYPE string
      RETURNING VALUE(rv) TYPE string.
ENDCLASS.

CLASS lcl_txt IMPLEMENTATION.
  METHOD en.
    rv = pick( iv_code = iv_code iv_spras = sy-langu iv_fb = iv_fb ).
  ENDMETHOD.

  METHOD ar.
    rv = pick( iv_code = iv_code iv_spras = 'A' iv_fb = iv_fb ).
  ENDMETHOD.

  METHOD pick.
    rv = iv_fb.
    IF iv_code IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE labeltext FROM /qnv/sb_labelt
      INTO @DATA(lv_txt)
      WHERE label_code = @iv_code AND spras = @iv_spras.
    IF sy-subrc = 0 AND lv_txt IS NOT INITIAL.
      rv = lv_txt.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

* ------------------------------------------------------------- runtime
* START-OF-SELECTION IS REQUIRED - a local CLASS ... IMPLEMENTATION is
* itself a processing block, so without the event everything after
* ENDCLASS belongs to no block and the first DELETE is unreachable.
START-OF-SELECTION.

* ------------------------------------------------------------- teardown
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ---------------------------------------------------------------- title
  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_en)
    WHERE journeyid = @c_jny AND spras = @sy-langu.
  IF lv_title_en IS INITIAL.
    lv_title_en = 'Preliminary Design Approval Request'.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    INTO @DATA(lv_title_ar)
    WHERE journeyid = @c_jny AND spras = 'A'.

* --------------------------------------------------------------- header
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt          = sy-mandt
    journey_id     = c_jny
    title          = lv_title_en
    title_ar       = lv_title_ar
    subtitle       = 'Submit the preliminary design of your project for approval.'
    subtitle_ar    = 'قدّم التصميم المبدئي لمشروعك للاعتماد.'
    active         = 'X'
    handler_class  = 'ZCL_M028_COD_LOGIC'
    bknd_active    = 'X'
    bknd_category  = 'DML'
    bknd_journey   = c_jny
    bknd_fm_post   = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read   = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Project Selection' title_ar = 'اختيار المشروع'
      icon = 'sap-icon://project-definition-triangle' bknd_screen = 'NCOD_1_1'
      active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Building Details' title_ar = 'تفاصيل المباني'
      icon = 'sap-icon://building' bknd_screen = 'NCOD_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Required Discipline' title_ar = 'التخصصات المطلوبة'
      icon = 'sap-icon://competitor' bknd_screen = 'NCOD_1_3'
      active = 'X' ) ) ).

* ---------------------------------------------- STP1 Project Selection
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(

*   THE PROJECT LIST, BOUND TO THE PROJECT API.
*
*   NOT a hand-typed ZRAK_T_JNY_OPT list, and no longer an empty dropdown
*   either. 'API:PROJECT:ProjectSet' is the fourth option source:
*   ZCL_RAK_JOURNEY_RENDER consults ZCL_RAK_CJ_OPTS->RESOLVE( ) AHEAD of
*   the DDIC resolver, RESOLVE( ) dispatches PROJECT to PROJECT_OPTS( ),
*   and that calls ZCL_RAK_FEES_API->PROJECTS( ) - whose own signature
*   says, in as many words, "Projects for the logged-on partner. M028
*   picks one here." The reader was written for this journey.
*
*   WHY THE FEES API AND NOT THE PROPERTY ONE. ProjectSet is one of the
*   three entity sets that never dereference IO_TECH_REQUEST_CONTEXT,
*   with FeesSet and TrackerSet, so it was wrappable before the
*   request-context factory existed. ZRAK_CJ_API_DIAG proved it answers
*   on E10 - 0 rows there, correctly, because no case or partner was
*   supplied.
*
*   THE FILTERS COME FROM JOURNEY IDENTITY, not from this screen: Dept,
*   Partner and CaseId, all off ZCL_RAK_CJ_CTX. CaseId is blank on a new
*   request - io_ctx->get_case( ) does not exist yet at step 1 - and
*   PROJECTS( ) simply omits that filter, which is what makes the list
*   "every project this partner owns". That is exactly what step 1 needs.
*
*   CLOSED_LIST because the citizen must pick one of their existing
*   projects; a typable ComboBox lets them submit a reference that does
*   not exist.
*
*   AN UNSERVED OR EMPTY BINDING SAYS SO ON SCREEN rather than drawing a
*   blank box - PROJECT_OPTS( ) separates "this partner owns no project"
*   from "rows came back but no key component matched", which are
*   different problems that look identical.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'MY_COMPONENT' ftype = 'SELECT' required = 'X'
      closed_list = 'X'
      default_val = 'API:PROJECT:ProjectSet'
      zsection = 'Select the project' zsection_ar = 'اختر المشروع'
      zlabel = 'Project' zlabel_ar = 'المشروع'
      msg = 'REQUIRED:Choose a project before continuing'
      msg_ar = 'REQUIRED:يرجى اختيار مشروع قبل المتابعة' )

*   Carrier - TOSAVE in the export, no control on the screen. Written by
*   the handler when a project is chosen.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'INTRENO_PROJECT' ftype = 'DISPLAY'
      hidden = 'X' readonly = 'X'
      zlabel = 'Project key' zlabel_ar = 'مفتاح المشروع' ) ) ).

* ----------------------------------------------- STP2 Building Details
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(

*   ---- the Current Consultant card -----------------------------------
*   Four read-only values under one heading, exactly as the walkthrough
*   shows them. All four are LABEL / DATE_FORMATTER rows in the export -
*   the citizen never types them; the handler fills them from the
*   project's assigned consultant.
*
*   DISPLAY AND READONLY BOTH, because DISPLAY alone still reaches the
*   validation loop for some checks and READONLY is what takes a field
*   out of it.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
      field_name = 'NAME_DATA' ftype = 'DISPLAY' readonly = 'X'
      zsection = 'Current Consultant' zsection_ar = 'الاستشاري الحالي'
      zlabel = 'Consultant' zlabel_ar = 'الاستشاري' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'LICENS_DATA' ftype = 'DISPLAY' readonly = 'X'
      zlabel = 'Trade License No' zlabel_ar = 'رقم الرخصة التجارية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'EXPIRY_DATA' ftype = 'DISPLAY' readonly = 'X'
      zlabel = 'Trade License Expiry Date'
      zlabel_ar = 'تاريخ انتهاء الرخصة التجارية' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 40
      field_name = 'GRADE_DATA' ftype = 'DISPLAY' readonly = 'X'
      zlabel = 'Grade' zlabel_ar = 'التصنيف' )

*   ---- the building list ---------------------------------------------
*   EDITABLE_TABLE, filled from the handler's Add Building popup. See the
*   header for why this is not ftype BUILDINGS.
*
*   REQUIRED HERE IS THE ASTERISK, NOT THE ENFORCEMENT. The walkthrough
*   shows "Building List*", and ZCL_RAK_JOURNEY_RULES->MISSING_REQUIRED( )
*   says in its own words that for an EDITABLE_TABLE an empty grid still
*   passes - it checks required COLUMNS against existing rows and is
*   "deliberately NOT a row-count check". ZCL_M028_COD_LOGIC enforces the
*   row count. If this flag is ever removed, remove that check too.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 50
      field_name = 'ADDBUILDING' ftype = 'EDITABLE_TABLE' required = 'X'
      zsection = 'Building List' zsection_ar = 'قائمة المباني'
      zlabel = 'Building List' zlabel_ar = 'قائمة المباني'
      msg = 'REQUIRED:Add at least one building'
      msg_ar = 'REQUIRED:يرجى إضافة مبنى واحد على الأقل' ) ) ).

* ------------------------------------------- STP2 the grid columns
* THE ORDER HERE IS THE CONTRACT the handler builds its rows against -
* see ZCL_M028_COD_LOGIC->ROW_FROM_POPUP( ), which carries the same list
* in the same order and says so. SET_GRID_DATA( ) maps by position: a
* cell out of order lands in the neighbouring column and one past the
* last column is dropped, neither of which raises anything.
*
* THREE VISIBLE, EIGHT HIDDEN. The walkthrough's grid shows Building
* Name, Building type and Building usage type only - but the popup
* collects eleven values and all eleven have to reach the backend, so the
* rest ride along as hidden columns rather than as eleven more model
* fields that could only hold one building.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BNAME' seqnr = 10
      zlabel = 'Building Name' zlabel_ar = 'اسم المبنى'
      ctrl = 'TEXT' readonly = 'X' required = 'X' width = '34%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BTYPE' seqnr = 20
      zlabel = 'Building type' zlabel_ar = 'نوع المبنى'
      ctrl = 'TEXT' readonly = 'X' required = 'X' width = '33%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BUSAGE' seqnr = 30
      zlabel = 'Building usage type' zlabel_ar = 'نوع استخدام المبنى'
      ctrl = 'TEXT' readonly = 'X' required = 'X' width = '33%' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BCOST' seqnr = 40
      zlabel = 'Building costs' zlabel_ar = 'تكلفة المبنى'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BHEIGHT' seqnr = 50
      zlabel = 'Building Height in meters' zlabel_ar = 'ارتفاع المبنى بالأمتار'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BTYPICAL' seqnr = 60
      zlabel = 'No of typical building' zlabel_ar = 'عدد المباني المتكررة'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BFLOORS' seqnr = 70
      zlabel = 'No of Typical Floors' zlabel_ar = 'عدد الطوابق المتكررة'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BMEZZ' seqnr = 80
      zlabel = 'No of Mezzanine Floors' zlabel_ar = 'عدد طوابق الميزانين'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BROOF' seqnr = 90
      zlabel = 'No of Roof Floors' zlabel_ar = 'عدد طوابق السطح'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BHELI' seqnr = 100
      zlabel = 'No of Helioports' zlabel_ar = 'عدد مهابط الطائرات'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2'
      field_name = 'ADDBUILDING' col_name = 'BBASEMENT' seqnr = 110
      zlabel = 'No of Basement Floors' zlabel_ar = 'عدد طوابق القبو'
      ctrl = 'TEXT' readonly = 'X' hidden = 'X' ) ) ).

* --------------------------------------------- STP3 Required Discipline
* SIX PAIRS, FROM THE EXPORT. The walkthrough shows four; the other two
* are presumably hidden by the live field control, and a field the BAdI
* hides costs nothing while a field it expects and cannot find is a
* silent gap.
*
* The checkbox labels are read from the export's own LABEL_CON codes,
* COD_1_4_CHB1..CHB6. The fallbacks are the four disciplines the
* walkthrough names; CHB5 and CHB6 have no fallback wording because
* nothing in this repository says what they are - the label table is the
* only honest source, and a blank there is visible rather than wrong.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'CB1' ftype = 'CHECKBOX'
      zsection = 'Please select the required discipline(s)'
      zsection_ar = 'يرجى اختيار التخصصات المطلوبة'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB1' iv_fb = 'Structural Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB1' iv_fb = 'مهندس إنشائي' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'SI1' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'CB2' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB2' iv_fb = 'Architecture Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB2' iv_fb = 'مهندس معماري' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'SI2' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 50
      field_name = 'CB3' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB3' iv_fb = 'Electrical Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB3' iv_fb = 'مهندس كهربائي' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 60
      field_name = 'SI3' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 70
      field_name = 'CB4' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB4' iv_fb = 'Mechanical Engineer' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB4' iv_fb = 'مهندس ميكانيكي' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 80
      field_name = 'SI4' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 90
      field_name = 'CB5' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB5' iv_fb = 'COD_1_4_CHB5' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB5' iv_fb = 'COD_1_4_CHB5' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 100
      field_name = 'SI5' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 110
      field_name = 'CB6' ftype = 'CHECKBOX'
      zlabel    = lcl_txt=>en( iv_code = 'COD_1_4_CHB6' iv_fb = 'COD_1_4_CHB6' )
      zlabel_ar = lcl_txt=>ar( iv_code = 'COD_1_4_CHB6' iv_fb = 'COD_1_4_CHB6' ) )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 120
      field_name = 'SI6' ftype = 'STEPPER' hidden = 'X'
      min_val = '0' max_val = '99'
      zlabel = 'Minimum drawings to be uploaded'
      zlabel_ar = 'الحد الأدنى للمخططات المطلوب رفعها' ) ) ).

* ------------------------------------------------------------- rules
* EACH COUNTER APPEARS ONLY WITH ITS OWN DISCIPLINE, which is what the
* walkthrough shows: the three ticked disciplines carry a stepper and the
* unticked one does not.
*
* SI1..SI6 are authored HIDDEN above and a SHOW rule releases each one.
* ZCL_RAK_JOURNEY_RULES->IS_HIDDEN( ) reads it in exactly that order - a
* configured HIDDEN loses to a matching SHOW - so this is the supported
* way round and not a trick.
*
* CONFIG, NOT CODE. This is show/hide keyed on one field's value, which
* is what ZRAK_T_JNY_RULE is for; a handler ON_CHANGE doing the same
* thing would be a rule written in ABAP.
  INSERT zrak_t_jny_rule FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R01'
      src_field = 'CB1' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI1' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R02'
      src_field = 'CB2' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI2' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R03'
      src_field = 'CB3' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI3' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R04'
      src_field = 'CB4' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI4' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R05'
      src_field = 'CB5' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI5' )
    ( mandt = sy-mandt journey_id = c_jny rule_id = 'R06'
      src_field = 'CB6' src_op = 'EQ' src_value = 'X'
      action = 'SHOW' tgt_field = 'SI6' ) ) ).

  COMMIT WORK AND WAIT.

* INVALIDATE, ALWAYS - a versioned per-work-process cache means another
* work process keeps serving the old configuration, and the change then
* looks exactly like a report that did not run.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* --------------------------------------------------------------- report
  WRITE: / 'M028 Preliminary Design Approval Request - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT for SPRAS A - the'.
    WRITE: / '           Arabic header will fall back to English.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'Steps    : STP1 Project Selection     NCOD_1_1   2 fields'.
  WRITE: / '           STP2 Building Details      NCOD_1_2   5 fields'.
  WRITE: / '                                      + 11 grid columns'.
  WRITE: / '           STP3 Required Discipline   NCOD_1_3  12 fields'.
  WRITE: / '                                      + 6 SHOW rules'.
  WRITE: / ''.
  WRITE: / 'Handler  : ZCL_M028_COD_LOGIC (inherits ZCL_RAK_JOURNEY_LOGIC'.
  WRITE: / '           directly - NOT ZCL_RAK_MUN_LOGIC, whose step-0'.
  WRITE: / '           parcel check would refuse this journey for ever'.
  WRITE: / '           against a PARCELSELECTOR this screen does not have)'.
  WRITE: / 'Backend  : DML / ZFM_EGA_CJ_FW_POST_N / _READ_N'.
  WRITE: / ''.
  WRITE: / 'PAYMENT  : NOT SEEDED - this follows the walkthrough, which'.
  WRITE: / '           says "No payment screen in sequence", ON INSTRUCTION.'.
  WRITE: / '           THE EXPORT DISAGREES: NCOD_1_4, NCOD_1_6 and'.
  WRITE: / '           NCOD_3_1 all carry RAKPAY and the full CPG envelope,'.
  WRITE: / '           and ZRAK_M_MUNI_LOAD has M028 in its pay group.'.
  WRITE: / '           If a fee is due for this service, the citizen has no'.
  WRITE: / '           way to pay it in this journey. Resolve before go-live.'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO - none of these are code:'.
  WRITE: / '  1. ZEGA_T_CJ_UI_MAP must carry NCOD_1_1, NCOD_1_2 and'.
  WRITE: / '     NCOD_1_3. A screen correct in /QNV and missing from the'.
  WRITE: / '     map posts, returns success and creates nothing. Run'.
  WRITE: / '     ZCL_RAK_CJS_XCHECK rule X16.'.
  WRITE: / '  2. MY_COMPONENT (project) is bound to the project API -'.
  WRITE: / '     DEFAULT_VAL = API:PROJECT:ProjectSet, served by'.
  WRITE: / '     ZCL_RAK_CJ_OPTS->PROJECT_OPTS( ) over'.
  WRITE: / '     ZCL_RAK_FEES_API->PROJECTS( ). NOTHING TO CONFIGURE, but'.
  WRITE: / '     the ROW SHAPE is unconfirmed: ZCL_ZEGA_CJ_MPC=>TT_PROJECT'.
  WRITE: / '     cannot be opened from the CJS repository, so the key and'.
  WRITE: / '     description are read through a candidate list. If the'.
  WRITE: / '     dropdown says "returned N row(s) but no key component'.
  WRITE: / '     matched", add the real component name to ROW_PICK( )''s'.
  WRITE: / '     list in ZCL_RAK_CJ_OPTS - one run names it.'.
  WRITE: / '  3. Building type and Building usage type in the Add Building'.
  WRITE: / '     popup have no option lists either - same reason, and the'.
  WRITE: / '     popup will draw them as plain inputs until they do. The'.
  WRITE: / '     lists go in ZCL_M028_COD_LOGIC->BUILDING_FIELDS( ).'.
  WRITE: / '  4. CB5 and CB6 have no wording anywhere in this repository,'.
  WRITE: / '     so their labels fall back to the label CODE and will read'.
  WRITE: / '     COD_1_4_CHB5 / CHB6 on screen until /QNV/SB_LABELT'.
  WRITE: / '     answers. That is deliberate - visible beats invented.'.
  WRITE: / '  5. Row EDIT (the pencil in the walkthrough) is NOT wired.'.
  WRITE: / '     Delete works - the engine owns GRIDDEL_ - but a per-row'.
  WRITE: / '     edit action has to be hand-drawn, because ftype TABLE'.
  WRITE: / '     never reaches RENDER_FIELD( ). See'.
  WRITE: / '     ZCL_RAK_TEST_ALL_LOGIC->RENDER_OWN_LIST( ) for the'.
  WRITE: / '     pattern. Add a building and delete it works today.'.
