CLASS zcl_rak_ba01_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& BA01 / BA02 / BA03 - Online Appointment Booking (APPOINT, NBA01)
*&
*& One class for all three journeys, the way ZCL_RAK_MUN_LOGIC serves
*& M011/M012/M016: they are one service the engine has to see as three
*& because its wizard cannot fan out from a hub. Which one is running is
*& read from IO_CTX->GET_CONFIG( )-id, never passed around.
*&
*& INHERITING, never `INTERFACES zif_rak_journey_logic` - the interface
*& obliges ~25 methods and the class will not activate.
*&
*& ============ WHAT THIS CLASS EXISTS TO DO ===========================
*&
*& 1. REPLACE THE APPOINTMENT CONTROL WITH REAL FIELDS, AND REBUILD ITS
*&    JSON ON THE WAY OUT. The legacy screen draws Case ID / Sector /
*&    Discipline / Engineer / Date / Time Slot inside one shapeitext2
*&    control that round-trips GS_DATA-APPOINT_JSON. CJS draws six ordinary
*&    fields and ON_BEFORE_POST( ) packs them back into that JSON, because
*&    ZCL_EGA_CJ_ENH_IMPL_OBA01~UPDATE( ) reads the JSON and overwrites the
*&    item values with it. Send the items alone and the case is created
*&    with a blank date, a blank engineer and no slot, and nothing says so.
*&
*& 2. DRAW THE APPOINTMENT LIST BY HAND. Each upcoming row needs two
*&    actions - Reschedule and Cancel - and a configured TABLE offers one
*&    row press. RENDER_FIELD( ) is not the hook for it either:
*&    RENDER_BLOCK( ) answers ftype TABLE itself and never routes it
*&    through RENDER_ONE( ), the only caller of that hook, so a claim there
*&    is dead code that looks live.
*&
*& 3. OFFER ONLY SLOTS THAT ARE FREE. CREATE_CASE( ) refuses a clash with
*&    'Slot unavailable. Please select another time slot' AFTER the citizen
*&    has filled the whole form. SLOTS( ) removes them from the list first.
*&
*& 4. CARRY THE CROSS-FIELD RULES THE CONFIGURATION CANNOT EXPRESS - one
*&    of Case ID / Sector, and a date that is not in the past.
*&
*& 5. SEARCH AND SORT THE LIST. The live screen has a search box over all
*&    five columns and sort arrows on Appointment ID and Case ID. The
*&    engine offers both to a CONFIGURED table - SORT= column keywords,
*&    GROW_THRESH paging - and this list is hand-drawn for the sake of its
*&    row actions, so it gets neither for free. SHOWN_ROWS( ) does the
*&    filtering and the ordering; ROWS_OF( ) stays what the backend
*&    returned, so a search matching nothing never reads as a read that
*&    returned nothing.
*&
*& 6. SAY "NO SLOTS AVAILABLE" AT THE MOMENT THE SCREEN SAYS IT. An empty
*&    dropdown with no message is indistinguishable from a rule that hid
*&    the field, a search help with no entries, and a binding that fell
*&    through - so a date and engineer with nothing free is said out loud,
*&    on the round trip that caused it.
*&
*& 7. KNOW WHICH SHAPE A RESCHEDULE IS. A reschedule keeps the shape of
*&    the appointment it is rescheduling: a case appointment asks for the
*&    Discipline, a general enquiry for the Sector. READ( ) decides that
*&    server-side and CJS cannot see its flag, but the related case id
*&    comes back inside the payload, which is the same fact.
*&
*& ============ WHAT IT DELIBERATELY DOES NOT DO =======================
*&
*& IT DOES NOT RE-IMPLEMENT VALIDATE( ). ZCL_EGA_CJ_ENH_IMPL_OBA01
*& already enforces, on every post, the mandatory set per tab, the mobile
*& prefix, the email format and the slot clash. Copying those here would
*& fork rules nobody keeps in step, and the copy is always the one that
*& goes stale - the legacy path is still live for the ShapeIt screens.
*&
*& The split is the house one: THE BACKEND OWNS THE DOMAIN RULES, and this
*& class only adds what makes the citizen's round trip better - a clash
*& caught before a post rather than after one. Everything it does check is
*& something the engine cannot express in configuration.
*&
*& ============ THE ONE THING THAT IS NOT WIRED ========================
*&
*& *** THE ACTION DOES NOT REACH THE BAdI, AND NOTHING WILL SAY SO. ***
*&
*& ZCL_EGA_CJ_ENH_IMPL_OBA01~UPDATE( ) is a CASE over six flags -
*& GV_SAVE_DRAFT, GV_DELETE_DRAFT, GV_CANCEL, GV_CANCEL_SUBMIT,
*& GV_RESCHEDULE, GV_RESCHEDULE_SUBMIT - and CREATE_CASE( ) runs only
*& under GV_SAVE_DRAFT. On the legacy screen those come from the pressed
*& button's DATA3: 'SUBMIT' on NBA01_1_2, 'RESCHEDULE_SUBMIT' on _1_4,
*& 'CANCEL_SUBMIT' on _1_5, 'BOOK' / 'CANCEL' / 'RESCHEDULE' on _1_1.
*&
*& ZCL_RAK_QNV_BRIDGE->POST( ) sets CATEGORYNAME, FUNCTIONIN, PARAM1..5
*& and SCREENNAME on the header and nothing else. There is no action on
*& it, and no handler hook reaches CS_GENERAL_DATA - ON_BEFORE_POST( )
*& changes items, ON_BEFORE_TABLES( ) changes tables, neither touches the
*& header. So a CJS post arrives with every GV_ flag false, UPDATE( )
*& falls through its CASE with no branch taken, and the post returns
*& SUCCESS having created nothing.
*&
*& That is the exact shape CLAUDE.md warns about - posts, returns success,
*& does nothing - and it is fixed on the CJS side, not the legacy one:
*& ZCL_RAK_QNV_BRIDGE needs to set the header component that carries DATA3,
*& from a per-step configuration value. Two lines, once somebody supplies
*& the component name from /QNV/SBUILD_SAVEHEADER_ST, plus a column to
*& carry it.
*&
*& NOT GUESSED AT HERE. A wrong component name would be assigned by name
*& into the BAdI's own program through ZIF_EGA_FW_CJI~MAPPER's
*& ASSIGN (technicalname), which is how a bare identifier once dumped every
*& DOK journey with MOVE_TO_LIT_NOTALLOWED_NODATA. ACTION_FOR( ) below
*& returns the right word per journey and step and TRACE( )s it, so the
*& value is ready and visible the moment the channel exists.
*&
*& ============ AND ONE THAT COLLIDES ==================================
*&
*& PARAM3. The bridge sends the partner as PARAM3 on every read.
*& ZCL_EGA_CJ_ENH_IMPL_OBA01~READ( ) opens with
*&     gs_data-reschedule_col = cs_header-param3.
*&     gs_data-cancel_col     = cs_header-param4.
*& and then READ TABLE gs_data-upcoming_appointments INDEX reschedule_col.
*& On the legacy path PARAM3 IS a row index - LINK_1's NAVTO sends
*& param3-UPCOMING_APPOINTMENTS. A CJS read therefore hands a partner
*& number to a READ TABLE INDEX, takes the reschedule branch on a journey
*& that is not rescheduling, and comes back with AVAILABLE_CASE_ID blank
*& and CASE_UNCHANGABLE true.
*&
*& Not worked around here either, and for the same reason: the fix is a
*& decision between stopping PARAM3 for this category and having CJS read
*& the list itself, and both have consequences beyond this journey.
*& ON_AFTER_READ( ) traces what came back so the symptom is legible.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- journeys -------------------------------------------------------
    CONSTANTS c_jny_book  TYPE string VALUE 'BA01'.
    CONSTANTS c_jny_resch TYPE string VALUE 'BA02'.
    CONSTANTS c_jny_cancl TYPE string VALUE 'BA03'.

*   ---- fields ---------------------------------------------------------
*   EVERY NAME HERE IS THE LEGACY /QNV FIELD_NAME, and that is a hard
*   requirement rather than a convention: backend field control is keyed on
*   it end to end. SEED_CTRL( ) looks the field up by it, CTRL_OF( )
*   reports back on it, and APPLY_CTRL( ) calls SET_HIDDEN / SET_READONLY /
*   SET_REQUIRED with it - and SET_HIDDEN( ) on a name the journey does not
*   have is legal and does nothing. A renamed field does not merely lose a
*   nicety; MANDATORY, ENABLED and VISIBLE all silently stop applying and
*   it looks like a backend that never sent them.
*
*   The two clarification fields are the documented exception - see the
*   feeder header. They are over the 23-character model ceiling under their
*   legacy names and no field control names them.
    CONSTANTS c_book_type TYPE string VALUE 'BOOK_TYPE'.
    CONSTANTS c_case_id   TYPE string VALUE 'AVAILABLE_CASE_ID'.
    CONSTANTS c_role      TYPE string VALUE 'PICKED_ROLE'.
    CONSTANTS c_engineer  TYPE string VALUE 'ENGINEER_ID'.
    CONSTANTS c_date      TYPE string VALUE 'APPOINT_DATE'.
    CONSTANTS c_time      TYPE string VALUE 'APPOINT_TIME'.
    CONSTANTS c_sector    TYPE string VALUE 'SECTOR_ID'.
    CONSTANTS c_engineer2 TYPE string VALUE 'ENGINEER_2'.
    CONSTANTS c_date2     TYPE string VALUE 'APPOINT_DATE_2'.
    CONSTANTS c_time2     TYPE string VALUE 'APPOINT_TIME_2'.
    CONSTANTS c_json      TYPE string VALUE 'APPOINT_1'.
    CONSTANTS c_json2     TYPE string VALUE 'APPOINT_JSON2_1'.
    CONSTANTS c_json_re   TYPE string VALUE 'APPOINT_1_RE'.
    CONSTANTS c_view      TYPE string VALUE 'APPT_VIEW'.
    CONSTANTS c_search    TYPE string VALUE 'APPT_SEARCH'.
    CONSTANTS c_sort      TYPE string VALUE 'APPT_SORT'.

*   ---- backend tables -------------------------------------------------
    CONSTANTS c_tab_up  TYPE string VALUE 'UPCOMING_APPOINTMENTS_2'.
    CONSTANTS c_tab_pst TYPE string VALUE 'PAST_APPOINTMENTS'.
    CONSTANTS c_tab_cnc TYPE string VALUE 'CANCELLED_APPOINTMENTS'.

*   ---- handler-drawn events -------------------------------------------
*   Matched with CP, never with an offset. IV_EVENT is TYPE string and an
*   offset on a short one raises CX_SY_RANGE_OUT_OF_BOUNDS - which the
*   engine turns into a Warning rather than a dump, so the citizen gets an
*   unexplained offset error on a press that otherwise worked.
    CONSTANTS c_evt_view  TYPE string VALUE 'BA_VIEW_*'.
    CONSTANTS c_evt_book  TYPE string VALUE 'BA_BOOK'.
    CONSTANTS c_evt_resch TYPE string VALUE 'BA_RESCH~*'.
    CONSTANTS c_evt_cancl TYPE string VALUE 'BA_CANCL~*'.
    CONSTANTS c_evt_sort  TYPE string VALUE 'BA_SORT~*'.
    CONSTANTS c_evt_find  TYPE string VALUE 'BA_FIND'.

*   ---- the slot grid --------------------------------------------------
*   The working window and the slot length. THESE TWO ARE AN ASSUMPTION
*   and the only one in this class that a screenshot cannot settle: the
*   /QNV export has no slot list, ZCL_EGA_CJ_ENH_IMPL_OBA01 never builds
*   one - it only refuses a clash - and the live list came from a DatesSet
*   on the OData service behind the control, which is unidentified. The
*   screenshots show 30-minute slots running at least 12:00 to 17:30 with
*   the list scrolled, so the window below is the narrowest one consistent
*   with them. Widen it here, in one place, once somebody confirms it.
    CONSTANTS c_slot_from TYPE i VALUE 8.
    CONSTANTS c_slot_to   TYPE i VALUE 18.
    CONSTANTS c_slot_mins TYPE i VALUE 30.

    METHODS zif_rak_journey_logic~on_init          REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read    REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help    REDEFINITION.
    METHODS zif_rak_journey_logic~on_change        REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start  REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event   REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post   REDEFINITION.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_row,
             appoint_id  TYPE string,
             case_id     TYPE string,
             zdate       TYPE string,
             ztime       TYPE string,
             assigned_to TYPE string,
           END OF ty_row.
    TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    TYPES tt_slot TYPE STANDARD TABLE OF string WITH EMPTY KEY.

*   Trace, the way ZCL_RAK_MUN_LOGIC does it: a cast inside TRY/CATCH
*   rather than a new interface method, because a test double passed as
*   IO_CTX is not the engine and must not be broken by instrumentation.
*   TRACE( ) itself emits only under &trace=x.
    METHODS trc        IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                 iv_text TYPE string.
    METHODS jny        IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rv) TYPE string.
    METHODS is_general IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rv) TYPE abap_bool.
    METHODS action_for IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rv) TYPE string.
    METHODS rows_of    IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                 iv_tab TYPE string
                       RETURNING VALUE(rt) TYPE tt_row.
*   ROWS_OF( ) is what the backend returned; SHOWN_ROWS( ) is what the
*   citizen is looking at. Kept apart on purpose - ON_AFTER_READ( ) traces
*   the first to answer "did the read work", and a search that matches
*   nothing must not read as a read that returned nothing.
    METHODS shown_rows IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                 iv_tab TYPE string
                       RETURNING VALUE(rt) TYPE tt_row.
*   The related CASE id that came back inside the reschedule payload. Blank
*   means the appointment is a general enquiry - the same fact READ( )
*   turns into additionaldata1 = 'G'.
    METHODS json_case  IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rv) TYPE string.
    METHODS col_labels IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                 iv_tab TYPE string
                       RETURNING VALUE(rt) TYPE string_table.
*   The three tab captions, from APPT_VIEW's own option rows rather than
*   from literals here - the feeder already resolved them out of
*   /QNV/SB_LABELT in both languages, and ZCL_RAK_JOURNEY_REPO->PICK( ) has
*   already chosen the language by the time a handler sees them.
    METHODS view_opts  IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS slots      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                                 iv_date  TYPE string
                                 iv_engnr TYPE string
                       RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS taken      IMPORTING iv_date  TYPE string
                                 iv_engnr TYPE string
                       RETURNING VALUE(rt) TYPE tt_slot.
    METHODS appt_json  IMPORTING io_ctx TYPE REF TO zif_rak_journey
                       RETURNING VALUE(rv) TYPE string.
    METHODS launch_url IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                                 iv_jny  TYPE string
                                 iv_appt TYPE string
                       RETURNING VALUE(rv) TYPE string.

*   ---- the four lists with no source in this system -------------------
*   Each is one method, returns nothing today, and traces the fact. They
*   are the CasesSet / RolesSet / EngineersSet / SectorsSet reads the
*   APPOINTMENT control made against an OData service that is item 1 of
*   doc/gaps/open-questions.md - name, DPC and MPC all unknown.
*
*   SEPARATE METHODS RATHER THAN ONE STUB so that wiring each is a method
*   body and nothing else, and so the trace names WHICH list is empty. An
*   empty dropdown with no message is the hardest failure in this codebase
*   to tell from a rule that hid the field.
    METHODS cases     IMPORTING io_ctx TYPE REF TO zif_rak_journey
                      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS roles     IMPORTING io_ctx TYPE REF TO zif_rak_journey
                      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS engineers IMPORTING io_ctx TYPE REF TO zif_rak_journey
                      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
    METHODS sectors   IMPORTING io_ctx TYPE REF TO zif_rak_journey
                      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

ENDCLASS.



CLASS zcl_rak_ba01_logic IMPLEMENTATION.


  METHOD trc.
    DATA lo_eng TYPE REF TO zcl_rak_journey_engine.
    TRY.
        lo_eng = CAST #( io_ctx ).
      CATCH cx_sy_move_cast_error.
        CLEAR lo_eng.
    ENDTRY.
    IF lo_eng IS BOUND.
      lo_eng->trace( iv_text ).
    ENDIF.
  ENDMETHOD.


  METHOD jny.
*   JOURNEY_ID, not ID. TY_CONFIG names it in full and a chained
*   component that does not exist is a syntax error in this method, which
*   takes the WHOLE class down at load - every caller then reports
*   'Method X is unknown or PROTECTED or PRIVATE' and points nowhere near
*   here.
    rv = to_upper( io_ctx->get_config( )-journey_id ).
  ENDMETHOD.


  METHOD is_general.
*   Which tab, and the answer has to survive a reschedule.
*
*   On BA01 it is simply BOOK_TYPE. On BA02 it is not asked at all: a
*   reschedule keeps the shape of the appointment it is rescheduling, and
*   ZCL_EGA_CJ_ENH_IMPL_OBA01~READ( ) decides that server-side - its
*   WHEN 'APPOINT_1_RE' branch sets additionaldata1 = 'G' when the
*   appointment has no related ZG19 case. So the only honest local test is
*   whether a case id came back with it.
    IF jny( io_ctx ) = c_jny_book.
      rv = xsdbool( io_ctx->get_val( c_book_type ) = 'G' ).
      RETURN.
    ENDIF.

*   NOT AVAILABLE_CASE_ID. On a reschedule that field holds the
*   APPOINTMENT id - READ( ) assigns gs_data-available_case_id =
*   lv_appoint_id - and it is never blank, so testing it would call every
*   reschedule a case reschedule and draw Discipline where the live screen
*   draws Sector. The related case id travels inside the payload instead.
*
*   ON_AFTER_READ( ) has already turned that into BOOK_TYPE, so this reads
*   the answer rather than re-deriving it; the fallback re-reads the
*   payload for a round trip that reached here before the read did.
    IF io_ctx->get_val( c_book_type ) IS NOT INITIAL.
      rv = xsdbool( io_ctx->get_val( c_book_type ) = 'G' ).
      RETURN.
    ENDIF.
    rv = xsdbool( json_case( io_ctx ) IS INITIAL ).
  ENDMETHOD.


  METHOD json_case.
*   One key out of the reschedule payload.
*
*   /UI2/CL_JSON, not a hand-rolled scan: it is what the BAdI itself uses
*   to read this same string, so the two agree on casing and on what counts
*   as absent. A local type rather than a class-level one because these
*   three components are this method's business and nothing else reads them.
    TYPES: BEGIN OF ty_pay,
             partner TYPE string,
             case_id TYPE string,
             sector  TYPE string,
           END OF ty_pay.
    DATA ls_pay TYPE ty_pay.

    DATA(lv_raw) = io_ctx->get_val( c_json_re ).
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

*   Wrapped. The payload is whatever the backend put in GS_DATA-APPOINT_JSON
*   and a malformed one must not take the step down - a blank answer here
*   means "general enquiry", which is the safer of the two shapes to draw:
*   it asks for a Sector, which every appointment has, rather than for a
*   Discipline, which only a case appointment does.
    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = lv_raw
                                   CHANGING  data = ls_pay ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    rv = ls_pay-case_id.
  ENDMETHOD.


  METHOD action_for.
*   The word the BAdI needs and cannot currently be sent. See the class
*   header: UPDATE( ) is a CASE over six GV_ flags set from the pressed
*   button's DATA3, and ZCL_RAK_QNV_BRIDGE->POST( ) puts no action on the
*   header at all.
*
*   Resolved and traced anyway, deliberately. When the channel is added the
*   value is already correct and already visible, and until then the trace
*   is what separates "the post did nothing because the action was absent"
*   from "the BAdI is not registered" - two causes with one symptom, which
*   is the shape that sends an investigation to SE18 for a registration
*   that was never wrong.
    CASE jny( io_ctx ).
      WHEN c_jny_book.  rv = 'SUBMIT'.
      WHEN c_jny_resch. rv = 'RESCHEDULE_SUBMIT'.
      WHEN c_jny_cancl. rv = 'CANCEL_SUBMIT'.
      WHEN OTHERS.      CLEAR rv.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
*   The base is empty, so there is nothing to chain here - checked against
*   ZCL_RAK_JOURNEY_LOGIC rather than assumed. An empty redefinition of a
*   hook whose base does real work is a DELETION, not a no-op.
    super->zif_rak_journey_logic~on_init( io_ctx ).

*   Which list the hub opens on. Upcoming, as the legacy TBUTTON_1 does -
*   its UI_FIELD_LOGICS show UPCOMING_VBOX and hide the other two.
    IF jny( io_ctx ) = c_jny_book AND io_ctx->get_val( c_view ) IS INITIAL.
      io_ctx->set_val( iv_name = c_view iv_value = 'U' ).
    ENDIF.

*   BA02 / BA03 are launched from a row of the BA01 list with the
*   appointment id in the launch parameter, which is also what the engine
*   takes as its key. Publishing it into AVAILABLE_CASE_ID is what puts it
*   on the screen, where the legacy _1_4 and _1_5 both show it as a
*   read-only caption and value.
    IF jny( io_ctx ) <> c_jny_book AND io_ctx->get_val( c_case_id ) IS INITIAL.
      DATA(lv_appt) = io_ctx->get_param( 'caseid' ).
      IF lv_appt IS INITIAL.
        lv_appt = io_ctx->get_case( ).
      ENDIF.
      io_ctx->set_val( iv_name = c_case_id iv_value = lv_appt ).
      trc( io_ctx = io_ctx
           iv_text = |BA01    { jny( io_ctx ) } opened on appointment { lv_appt }| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
    super->zif_rak_journey_logic~on_after_read( io_ctx ).

*   WHAT CAME BACK, COUNTED. This is the PARAM3 collision's only visible
*   symptom: the bridge sends the partner as PARAM3, READ( ) reads PARAM3
*   as a row index into UPCOMING_APPOINTMENTS and takes its reschedule
*   branch, and the lists then come back empty or the case id comes back
*   blank on a journey that is not rescheduling. Three numbers separate
*   that from "this partner has no appointments", which looks identical.
    IF jny( io_ctx ) = c_jny_resch.
*     WHICH SHAPE THIS RESCHEDULE IS, decided the moment the payload
*     arrives and published as BOOK_TYPE so the rules can act on it.
*
*     Done here rather than in ON_INIT( ) because the payload is what the
*     READ returns: ON_INIT( ) runs before it and would see an empty
*     string, set 'C', and draw Discipline on every reschedule including
*     the general-enquiry ones the live screen draws Sector on.
      DATA(lv_rel) = json_case( io_ctx ).
      DATA(lv_bt)  = COND string( WHEN lv_rel IS INITIAL THEN 'G' ELSE 'C' ).
      io_ctx->set_val( iv_name = c_book_type iv_value = lv_bt ).
      DATA(lv_sel) = COND string( WHEN lv_bt = 'G' THEN 'Sector' ELSE 'Discipline' ).
      trc( io_ctx  = io_ctx
           iv_text = |BA01    reschedule payload · related case '{ lv_rel }'| &&
                     | · BOOK_TYPE { lv_bt } · { lv_sel } is the selector shown| ).
      RETURN.
    ENDIF.

    IF jny( io_ctx ) <> c_jny_book.
      RETURN.
    ENDIF.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    read · upcoming { lines( rows_of( io_ctx = io_ctx iv_tab = c_tab_up ) ) }| &&
                   | · past { lines( rows_of( io_ctx = io_ctx iv_tab = c_tab_pst ) ) }| &&
                   | · cancelled { lines( rows_of( io_ctx = io_ctx iv_tab = c_tab_cnc ) ) }| &&
                   | · all three zero on a partner who has appointments means PARAM3| &&
                   | reached READ( ) as a row index - see the class header| ).
  ENDMETHOD.


  METHOD rows_of.
*   GET_BACKEND_TABLE( ) matches on the FIELD NAME exactly as BACKEND_READ( )
*   parked it. Asking for the DATA2 spelling instead returns nothing and
*   cannot say why, which is why these are constants and not literals.
    DATA(ls_t) = io_ctx->get_backend_table( iv_tab ).
    LOOP AT ls_t-rows INTO DATA(lt_cells).
*     Positional, and the order is the legacy LIST_SEQUENCE - 1 APPOINT_ID,
*     2 CASE_ID, 3 DATE, 4 TIME, 5 ASSIGNED_TO. ZCL_EGA_CJ_ECOMP_ABS->READ( )
*     fills FIELDn as 'FIELD' && LIST_SEQUENCE, so the slot a value lands in
*     is set in /QNV/SB_UI_DEFIN and not here. A column whose sequence is
*     missing renders blank and one whose sequence differs renders its
*     neighbour's value - neither raises anything.
      APPEND VALUE #( appoint_id  = VALUE #( lt_cells[ 1 ] OPTIONAL )
                      case_id     = VALUE #( lt_cells[ 2 ] OPTIONAL )
                      zdate       = VALUE #( lt_cells[ 3 ] OPTIONAL )
                      ztime       = VALUE #( lt_cells[ 4 ] OPTIONAL )
                      assigned_to = VALUE #( lt_cells[ 5 ] OPTIONAL ) ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD shown_rows.
*   What the citizen is looking at: the backend rows, filtered by the
*   search box and ordered by the chosen column.
*
*   BOTH DONE HERE, IN ABAP, and that is forced rather than chosen. The
*   engine gives a CONFIGURED table sorting through the SORT= column
*   keyword and paging through GROW_THRESH - but this list is hand-drawn,
*   because each upcoming row needs two actions, and a hand-drawn table
*   gets none of that. Search the engine has no answer for on any path.
    rt = rows_of( io_ctx = io_ctx iv_tab = iv_tab ).

*   ---- search ---------------------------------------------------------
*   Across every column the citizen can see, which is what a single search
*   box over a table means to the person using it. Upper-cased both sides
*   so a search for "abd" finds "Abd Alrahman".
    DATA(lv_q) = to_upper( condense( io_ctx->get_val( c_search ) ) ).
    IF lv_q IS NOT INITIAL.
*     Built as a new table rather than DELETEd in place. Deleting from the
*     table a LOOP is walking shifts every index behind the cursor, so the
*     row after each removal is skipped - a filter that drops roughly half
*     of what it should and looks like it worked.
      DATA lt_keep TYPE tt_row.
      CLEAR lt_keep.
      LOOP AT rt INTO DATA(ls_chk).
        DATA(lv_hay) = to_upper( |{ ls_chk-appoint_id } { ls_chk-case_id } | &&
                                 |{ ls_chk-zdate } { ls_chk-ztime } { ls_chk-assigned_to }| ).
        IF lv_hay CS lv_q.
          APPEND ls_chk TO lt_keep.
        ENDIF.
      ENDLOOP.
      rt = lt_keep.
    ENDIF.

*   ---- sort -----------------------------------------------------------
*   Only the two columns the live screen offers arrows on - Appointment ID
*   and Case ID. Date, Time and Assigned to are NOT sortable there, and
*   offering an arrow the live screen does not have would be a difference
*   nobody asked for; Date in particular would sort on the rendered
*   dd.MM.yyyy string rather than on the date, which is a plausible wrong
*   answer and worse than no arrow at all.
*
*   The backend has already ordered the rows - APPOINTMENTS_SEARCH( ) does
*   SORT DESCENDING BY booked_date booked_time_slot_from - so an unset
*   sort leaves that ordering alone rather than imposing one of its own.
    DATA(lv_spec) = io_ctx->get_val( c_sort ).
    IF lv_spec IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT lv_spec AT ':' INTO DATA(lv_col) DATA(lv_dir).

    CASE lv_col.
      WHEN 'APPOINT_ID'.
        IF lv_dir = 'D'.
          SORT rt BY appoint_id DESCENDING.
        ELSE.
          SORT rt BY appoint_id ASCENDING.
        ENDIF.
      WHEN 'CASE_ID'.
        IF lv_dir = 'D'.
          SORT rt BY case_id DESCENDING.
        ELSE.
          SORT rt BY case_id ASCENDING.
        ENDIF.
      WHEN OTHERS.
*       A sort column that is not one of the two is not silently ignored.
*       The only way to get one is a stale APPT_SORT left by an older
*       build, and an ordering that quietly stops applying is the shape
*       this codebase keeps meeting.
        trc( io_ctx  = io_ctx
             iv_text = |BA01    sort column '{ lv_col }' is not sortable · ignored| ).
    ENDCASE.
  ENDMETHOD.


  METHOD view_opts.
*   Into a variable first. LOOP AT wants an internal table DATA OBJECT, and
*   a component of a functional call's result is not one.
    DATA(lt_steps) = io_ctx->get_config( )-steps.
    LOOP AT lt_steps INTO DATA(ls_step).
      READ TABLE ls_step-fields INTO DATA(ls_fld) WITH KEY name = c_view.
      IF sy-subrc = 0 AND ls_fld-options IS NOT INITIAL.
        rt = ls_fld-options.
        RETURN.
      ENDIF.
    ENDLOOP.

*   Fallback only. A journey seeded by ZRAK_BA01_LOAD always has these
*   three rows; reaching here means the option rows were not loaded, and
*   three untranslated captions are a better answer than three empty
*   buttons - the switch is how the citizen reaches the other two lists.
    rt = VALUE #( ( key = 'U' text = 'Upcoming' )
                  ( key = 'P' text = 'Past' )
                  ( key = 'C' text = 'Canceled' ) ).
  ENDMETHOD.


  METHOD col_labels.
*   Headings from ZRAK_T_JNY_COL, not from literals in this class. The
*   column rows are configuration with a real ZLABEL_AR and a Studio
*   editor behind them, so a heading changed there reaches the screen with
*   no code change - which is the whole reason the feeder puts them in that
*   table rather than packing them into DEFAULT_VAL.
    DATA(lv_jny)  = CONV zrak_t_jny_col-journey_id( jny( io_ctx ) ).
    DATA(lv_fld)  = CONV zrak_t_jny_col-field_name( iv_tab ).
    DATA(lv_lang) = sy-langu.

*   SEQNR is in the field list as well as the ORDER BY. ABAP SQL wants an
*   ordering column to be selected, and leaving it out is the kind of
*   syntax error that takes the whole class down rather than this method.
    SELECT seqnr, zlabel, zlabel_ar FROM zrak_t_jny_col
      INTO TABLE @DATA(lt_c)
      WHERE journey_id = @lv_jny
        AND field_name = @lv_fld
      ORDER BY seqnr.

    LOOP AT lt_c INTO DATA(ls_c).
      APPEND COND string( WHEN lv_lang = 'A' AND ls_c-zlabel_ar IS NOT INITIAL
                          THEN ls_c-zlabel_ar
                          ELSE ls_c-zlabel ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
    super->zif_rak_journey_logic~on_render_start( io_ctx = io_ctx io_view = io_view ).

*   The hub, and only the hub. STP2 is an ordinary configured form.
    IF jny( io_ctx ) <> c_jny_book OR io_ctx->get_step( ) <> 0.
      RETURN.
    ENDIF.

    DATA(lv_view) = io_ctx->get_val( c_view ).
    IF lv_view IS INITIAL.
      lv_view = 'U'.
    ENDIF.

*   Header: the title, and Book an Appointment on the right, exactly where
*   the legacy CARD_HEADER puts it.
    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
*   READ TABLE, not VALUE ... OPTIONAL. `steps[ 1 ]` on a config with no
*   steps raises CX_SY_ITAB_LINE_NOT_FOUND and an uncaught one kills the
*   render of a page whose only problem was an empty heading - but the
*   guard cannot be written as
*       VALUE string( io_ctx->get_config( )-steps[ 1 ]-title OPTIONAL )
*   because OPTIONAL attaches to a TABLE EXPRESSION and nothing else. Read
*   a component off one and the compiler stops seeing a table expression,
*   reads `string` as a structure to be built from components, and reports
*   **The type "STRING" is not a structure** - which names neither OPTIONAL
*   nor the component access. Same family as the VALUE and TYPE HANDLE
*   traps: the message describes where the parser gave up, not what is
*   wrong. `VALUE #( lt_cells[ 1 ] OPTIONAL )` in ROWS_OF( ) is the form
*   that DOES work, because there the line itself is the value.
    DATA lv_head TYPE string.
    DATA(lt_steps) = io_ctx->get_config( )-steps.
    READ TABLE lt_steps INTO DATA(ls_first) INDEX 1.
    IF sy-subrc = 0.
      lv_head = ls_first-title.
    ENDIF.
    lo_hd->title( text = lv_head class = 'rakBlkTitle' ).
    lo_hd->button( text  = 'Book an Appointment'
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add-appointment'
                   press = io_ctx->event( c_evt_book ) ).

*   The three-way switch. Drawn here rather than as a configured SEGMENTED
*   because it has to sit between the header and the list, and a configured
*   field lands wherever its SEQNR puts it among the fields - which on this
*   step are all hidden.
    DATA(lo_sw) = io_view->hbox( class = 'sapUiSmallMarginTop' ).
    DATA(lt_seg) = view_opts( io_ctx ).
    LOOP AT lt_seg INTO DATA(ls_seg).
      lo_sw->button( text  = ls_seg-text
                     type  = COND string( WHEN ls_seg-key = lv_view
                                          THEN 'Emphasized' ELSE 'Transparent' )
                     press = io_ctx->event( |BA_VIEW_{ ls_seg-key }| ) ).
    ENDLOOP.

    DATA(lv_tab) = SWITCH string( lv_view
                                  WHEN 'P' THEN c_tab_pst
                                  WHEN 'C' THEN c_tab_cnc
                                  ELSE          c_tab_up ).
    DATA(lt_all)  = rows_of( io_ctx = io_ctx iv_tab = lv_tab ).
    DATA(lt_rows) = shown_rows( io_ctx = io_ctx iv_tab = lv_tab ).
    DATA(lt_lbl)  = col_labels( io_ctx = io_ctx iv_tab = lv_tab ).

*   The search box, on its own line above the table, where the live screen
*   puts it. BIND( ) rather than a value: two-way, so what is typed is on
*   the model by the time any round trip reaches the server, and the
*   button is only there to force one.
    DATA(lo_tb) = io_view->hbox( justifycontent = 'End'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_tb->input( value       = io_ctx->bind( c_search )
                  placeholder = zcl_rak_text=>pick( iv_base = 'Search' iv_ar = 'بحث' )
                  submit      = io_ctx->event( c_evt_find )
                  width       = '16rem' ).
    lo_tb->button( icon  = 'sap-icon://search'
                   type  = 'Transparent'
                   press = io_ctx->event( c_evt_find ) ).

    IF lt_rows IS INITIAL.
*     A message, not an empty grid. An empty table with five headings and
*     no rows reads as a list that failed to load; this says which list is
*     empty and that it is the answer rather than the absence of one.
*
*     AND IT SAYS WHICH KIND OF EMPTY. A search that matched nothing and a
*     list with nothing in it look identical on screen, and only one of
*     them is fixed by clearing the search box.
      io_view->message_strip(
        text     = COND string(
                     WHEN lt_all IS NOT INITIAL
                     THEN zcl_rak_text=>pick(
                            iv_base = 'No appointments match your search.'
                            iv_ar   = 'لا توجد مواعيد مطابقة لبحثك.' )
                     ELSE zcl_rak_text=>pick(
                            iv_base = 'No appointments in this list.'
                            iv_ar   = 'لا توجد مواعيد في هذه القائمة.' ) )
        type     = 'Information'
        showicon = abap_true
        class    = 'sapUiSmallMarginTop' ).
      RETURN.
    ENDIF.

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).

*   The first two columns carry a sort arrow and the other three do not,
*   matching the live screen exactly. COL_LABELS( ) returns them in
*   ZRAK_T_JNY_COL SEQNR order, which is the legacy LIST_SEQUENCE order, so
*   index 1 is Appointment ID and index 2 is Case ID.
*
*   A BUTTON in the header rather than sap.m.Column's own sort menu:
*   headerMenu is an ASSOCIATION, not an aggregation, so a menu written as
*   a child of the column lands in its header aggregation and draws where
*   the heading goes - and this table is hand-built, so the engine's
*   MT_SORT machinery is not in play either way.
    DATA(lv_spec) = io_ctx->get_val( c_sort ).
    LOOP AT lt_lbl INTO DATA(lv_lbl).
      DATA(lv_ix)  = sy-tabix.
      DATA(lv_key) = COND string( WHEN lv_ix = 1 THEN 'APPOINT_ID'
                                  WHEN lv_ix = 2 THEN 'CASE_ID' ).
      IF lv_key IS INITIAL.
        lo_cl->column( )->text( lv_lbl ).
        CONTINUE.
      ENDIF.
*     SORTINDICATOR is sap.m.Column's own, so the arrow is drawn by UI5
*     where it draws every other one, rather than as an icon inside the
*     header that happens to look like it. Blank spec means unsorted -
*     which is the backend's own newest-first ordering, not the absence of
*     an ordering.
      DATA(lv_ind) = COND string(
        WHEN lv_spec = |{ lv_key }:A| THEN 'Ascending'
        WHEN lv_spec = |{ lv_key }:D| THEN 'Descending'
        ELSE                               'None' ).
*     The affordance, and only while there is no arrow to be the
*     affordance itself. A sort icon beside a UI5 sort arrow is two
*     indicators for one state.
      DATA(lv_icon) = COND string( WHEN lv_ind = 'None' THEN 'sap-icon://sort' ).
      lo_cl->column( sortindicator = lv_ind
        )->button( text  = lv_lbl
                   icon  = lv_icon
                   type  = 'Transparent'
                   press = io_ctx->event( |BA_SORT~{ lv_key }| ) ).
    ENDLOOP.
*   The actions column has no ZRAK_T_JNY_COL row and should not have one:
*   it holds no cell value, so a configured column would be a heading over
*   an empty grid slot and would shift every value one place left.
    IF lv_view = 'U'.
      lo_cl->column( halign = 'End' )->text( 'Actions' ).
    ENDIF.

    DATA(lo_it) = lo_t->items( ).
    LOOP AT lt_rows INTO DATA(ls_r).
      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
      lo_cells->text( ls_r-appoint_id ).
      lo_cells->text( ls_r-case_id ).
      lo_cells->text( ls_r-zdate ).
      lo_cells->text( ls_r-ztime ).
      lo_cells->text( ls_r-assigned_to ).

*     Reschedule and Cancel on upcoming rows only, which is what the legacy
*     screen does: LINK_1 and LINK_2 sit inside HBOX_6 under
*     UPCOMING_APPOINTMENTS and the past and cancelled tables have no
*     action column at all.
      IF lv_view = 'U'.
        DATA(lo_act) = lo_cells->hbox( ).
*       A TILDE separates the payload, and the event names above are matched
*       with CP for it. An offset would be an offset on a STRING and a short
*       event throws CX_SY_RANGE_OUT_OF_BOUNDS, which the engine turns into
*       a Warning on a press that otherwise succeeded.
        lo_act->button( text    = 'Reschedule'
                        type    = 'Transparent'
                        tooltip = 'Move this appointment to another slot'
                        press   = io_ctx->event( |BA_RESCH~{ ls_r-appoint_id }| ) ).
        lo_act->button( text    = 'Cancel'
                        type    = 'Transparent'
                        tooltip = 'Cancel this appointment'
                        press   = io_ctx->event( |BA_CANCL~{ ls_r-appoint_id }| ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD launch_url.
*   RELATIVE, and that is deliberate. The SICF node this journey is served
*   from is not knowable from inside the app - egardcjs and cjattviewer are
*   both registered in this repository - and a relative URL resolves
*   against the document the citizen is already on, so it carries the host,
*   the path and the client without any of them being written down here.
*
*   THIS IS THE ONE LINE TO CHANGE if journeys are ever served from
*   somewhere other than the page the list is drawn on.
*
*   USERDATA and LANG ride along because the target journey resolves its
*   own partner and language from them; TRACE rides along so a diagnosis
*   does not stop at the navigation.
    rv = |?journey={ iv_jny }&caseid={ iv_appt }|.

    DATA(lv_ud) = io_ctx->get_param( 'userdata' ).
    IF lv_ud IS NOT INITIAL.
      rv = |{ rv }&userdata={ lv_ud }|.
    ENDIF.
    DATA(lv_lang) = io_ctx->get_param( 'lang' ).
    IF lv_lang IS NOT INITIAL.
      rv = |{ rv }&lang={ lv_lang }|.
    ENDIF.
    DATA(lv_tr) = io_ctx->get_param( 'trace' ).
    IF lv_tr IS NOT INITIAL.
      rv = |{ rv }&trace={ lv_tr }|.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
*   SUPER FIRST. ON_POPUP_EVENT is one of the four base hooks that do real
*   work - it carries the BP and attachment machinery and the payment
*   PAYNOW / PAYPOLL events - so a redefinition that does not chain removes
*   all of it silently.
    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                 iv_id    = iv_id
                                                 iv_event = iv_event ).

*   CP throughout, never an offset - see the constants.
    IF iv_event CP c_evt_view.
*     'BA_VIEW_U' -> 'U'. The last character, taken with a substring whose
*     length comes from STRLEN( ), so nothing here can run off the end of a
*     string that arrived shorter than expected.
      DATA(lv_off) = strlen( iv_event ) - 1.
      io_ctx->set_val( iv_name = c_view iv_value = substring( val = iv_event
                                                              off = lv_off
                                                              len = 1 ) ).
      RETURN.
    ENDIF.

    IF iv_event = c_evt_find.
*     Nothing to do but come back. The search box is two-way bound, so by
*     the time this event arrives APPT_SEARCH already holds what was typed
*     and the next render filters on it. The event exists only to BE a
*     round trip - pressing Enter or the magnifier has to reach the server
*     for the list to be redrawn.
      RETURN.
    ENDIF.

    IF iv_event CP c_evt_sort.
      SPLIT iv_event AT '~' INTO DATA(lv_x) DATA(lv_col).
      IF lv_col IS INITIAL.
        RETURN.
      ENDIF.
*     THREE STATES, NOT TWO: ascending, descending, and back to the
*     backend's own ordering. A two-state toggle would make the newest-first
*     order APPOINTMENTS_SEARCH( ) returns unreachable once anything had
*     been sorted, and that ordering is the one the list opens on.
      DATA(lv_now) = io_ctx->get_val( c_sort ).
      DATA(lv_new) = COND string(
        WHEN lv_now = |{ lv_col }:A| THEN |{ lv_col }:D|
        WHEN lv_now = |{ lv_col }:D| THEN space
        ELSE                              |{ lv_col }:A| ).
      io_ctx->set_val( iv_name = c_sort iv_value = lv_new ).
      RETURN.
    ENDIF.

    IF iv_event = c_evt_book.
*     ADVANCE_STEP( ), not COMMIT_STEP( ). The hub validates nothing and
*     posts nothing - it is a list - and COMMIT_STEP( ) would run the post
*     for NBA01_1_1, which exists to be read.
      io_ctx->advance_step( ).
      RETURN.
    ENDIF.

    IF iv_event CP c_evt_resch OR iv_event CP c_evt_cancl.
      SPLIT iv_event AT '~' INTO DATA(lv_evt) DATA(lv_appt).
      IF lv_appt IS INITIAL.
*       The payload is the appointment id and without it the target journey
*       opens on nothing. Said out loud rather than navigating anyway: a
*       reschedule screen with a blank appointment id looks like a backend
*       that returned no case.
        io_ctx->add_msg( iv_type = 'Error'
                         iv_text = |Could not read the appointment from that row.| ).
        RETURN.
      ENDIF.
      DATA(lv_target) = COND string( WHEN iv_event CP c_evt_resch
                                     THEN c_jny_resch ELSE c_jny_cancl ).
      trc( io_ctx  = io_ctx
           iv_text = |BA01    row action { lv_evt } · appointment { lv_appt } · opening { lv_target }| ).
      io_ctx->open_url( launch_url( io_ctx  = io_ctx
                                    iv_jny  = lv_target
                                    iv_appt = lv_appt ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
    rt = super->zif_rak_journey_logic~on_value_help( io_ctx = io_ctx iv_field = iv_field ).

    DATA(lv_f) = to_upper( iv_field ).
    CASE lv_f.
      WHEN c_case_id.   rt = cases( io_ctx ).
      WHEN c_role.      rt = roles( io_ctx ).
      WHEN c_engineer.  rt = engineers( io_ctx ).
      WHEN c_engineer2. rt = engineers( io_ctx ).
      WHEN c_sector.    rt = sectors( io_ctx ).
*     The two slot lists differ only in which date and which engineer they
*     are asked about - the case tab keeps its answers in PICKED_DATE /
*     ENGINEER_ID and the general tab in PICKED_DATE_2 / ENGINEER_ID_2.
      WHEN c_time.
        rt = slots( io_ctx   = io_ctx
                    iv_date  = io_ctx->get_val( c_date )
                    iv_engnr = io_ctx->get_val( c_engineer ) ).
      WHEN c_time2.
        rt = slots( io_ctx   = io_ctx
                    iv_date  = io_ctx->get_val( c_date2 )
                    iv_engnr = io_ctx->get_val( c_engineer2 ) ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD slots.
*   The grid, minus what is already taken.
*
*   A slot's KEY is the eight characters the backend wants - HHMM then HHMM
*   - because that is exactly what UPDATE( ) splits back out:
*       picked_time_from = appointment+0(4) && '00'
*       picked_time_to   = appointment+4(4) && '00' && '00'
*   so the key can be dropped into the JSON untouched. Its TEXT is the
*   readable form the live dropdown shows.
*
*   Both are built here rather than stored anywhere: a slot list is derived
*   from a window and a date, and a table of them would be a second place
*   for the working hours to be wrong.
    DATA lv_h    TYPE i.
    DATA lv_m    TYPE i.
    DATA lv_eh   TYPE i.
    DATA lv_em   TYPE i.
    DATA lv_from TYPE c LENGTH 4.
    DATA lv_to   TYPE c LENGTH 4.
*   NUMC, not a template's WIDTH / PAD / ALIGN. A numeric template's
*   alignment default is not worth an afternoon and NUMC is leading-zero by
*   definition - the same reason the seed reports build their ids this way.
    DATA lv_nh   TYPE n LENGTH 2.
    DATA lv_nm   TYPE n LENGTH 2.

    DATA(lt_taken) = taken( iv_date = iv_date iv_engnr = iv_engnr ).

    lv_h = c_slot_from.
    lv_m = 0.
    WHILE lv_h < c_slot_to.
      lv_eh = lv_h.
      lv_em = lv_m + c_slot_mins.
      IF lv_em >= 60.
        lv_em = lv_em - 60.
        lv_eh = lv_eh + 1.
      ENDIF.

      lv_nh = lv_h.
      lv_nm = lv_m.
      lv_from = |{ lv_nh }{ lv_nm }|.
      lv_nh = lv_eh.
      lv_nm = lv_em.
      lv_to = |{ lv_nh }{ lv_nm }|.

*     A taken slot is DROPPED, not greyed. CREATE_CASE( ) refuses a clash
*     outright - 'Slot unavailable. Please select another time slot' - and
*     it refuses it after the citizen has filled in the whole form, so
*     offering one at all is offering a dead end.
      READ TABLE lt_taken TRANSPORTING NO FIELDS
           WITH KEY table_line = CONV string( lv_from ).
      IF sy-subrc <> 0.
        APPEND VALUE #( key  = |{ lv_from }{ lv_to }|
                        text = |{ lv_from(2) }:{ lv_from+2(2) }-{ lv_to(2) }:{ lv_to+2(2) }| ) TO rt.
      ENDIF.

      lv_h = lv_eh.
      lv_m = lv_em.
    ENDWHILE.

    IF iv_date IS INITIAL OR iv_engnr IS INITIAL.
*     Every slot, and a trace saying why. Without a date and an engineer
*     there is nothing to be taken against, so the full grid is the honest
*     answer - but a full grid is also what a failed availability read
*     looks like, and the two need telling apart.
      trc( io_ctx  = io_ctx
           iv_text = |BA01    slots · no date or engineer yet · whole window offered| ).
      RETURN.
    ENDIF.

    trc( io_ctx  = io_ctx
         iv_text = |BA01    slots for { iv_engnr } on { iv_date } · { lines( rt ) } free| &&
                   | · { lines( lt_taken ) } taken| ).
  ENDMETHOD.


  METHOD taken.
*   The slots this engineer already has on this date.
*
*   READ DYNAMICALLY, AND THAT IS NOT TIDINESS. A static SELECT names
*   ZDT_EGA_CAAT_GEN at compile time, so a system without the legacy layer
*   would not ACTIVATE this class - and a class with no active version
*   surfaces at every caller as "Method X is unknown or PROTECTED or
*   PRIVATE", pointing nowhere near the cause. A CATCH cannot save a static
*   SELECT from a missing table: that is a syntax error, not an exception.
*   Resolved at runtime instead, the same reason XCHECK rule X16 resolves
*   its table and columns dynamically, and a missing table degrades to
*   "every slot is free" - which is only ever the behaviour this method
*   exists to improve on, never a wrong booking, because the BAdI still
*   refuses a real clash.
*
*   MIRRORS THE LEGACY TEST EXACTLY. CREATE_CASE( )'s clash check is
*       SELECT SINGLE case_guid FROM zdt_ega_caat_gen
*         WHERE booked_date = .. AND booked_time_slot_from = .. AND engineer_id = ..
*   with NO filter on APPOINTMENT_TYPE - so an appointment that has been
*   cancelled still blocks its slot there. That is almost certainly not
*   intended, and it is deliberately reproduced rather than corrected:
*   filtering '03' out here would offer a slot the BAdI then refuses, which
*   is a worse failure than a slot missing from the list. It is a
*   legacy-side defect, and the namespace boundary says it is not ours.
*
*   Reading only. CJS keeps no copy of the booking state - the table stays
*   the backend's.
    CONSTANTS lc_tab TYPE string VALUE 'ZDT_EGA_CAAT_GEN'.

*   A NAMED TYPE, not `TABLE OF c LENGTH 6`. The LENGTH addition belongs to
*   a direct DATA declaration and not after TABLE OF, and there is no
*   precedent for the short form anywhere in this repository - which is
*   reason enough not to be the first, given nothing here compiles before
*   it reaches SAP. Six because BOOKED_TIME_SLOT_FROM is HHMMSS.
    TYPES ty_hhmmss TYPE c LENGTH 6.
    DATA lt_dyn   TYPE STANDARD TABLE OF ty_hhmmss WITH EMPTY KEY.
    DATA lv_where TYPE string.

    IF iv_date IS INITIAL OR iv_engnr IS INITIAL.
      RETURN.
    ENDIF.

*   BOTH VALUES CHECKED BEFORE THEY REACH A DYNAMIC WHERE. They come from
*   the model, which means they come from the browser, and a dynamic WHERE
*   built from browser input is an injection. A date is eight digits and a
*   user name is the SAP character set - anything else is not a value this
*   method can be asked about, so it answers "nothing is taken" and says so
*   rather than building the clause.
    IF strlen( iv_date ) <> 8 OR iv_date CN '0123456789'.
      RETURN.
    ENDIF.
    IF iv_engnr CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-.'.
      RETURN.
    ENDIF.

    lv_where = |BOOKED_DATE = '{ iv_date }' AND ENGINEER_ID = '{ iv_engnr }'|.

    TRY.
        SELECT booked_time_slot_from FROM (lc_tab)
          WHERE (lv_where)
          INTO TABLE @lt_dyn.
      CATCH cx_root.
        RETURN.
    ENDTRY.

    LOOP AT lt_dyn INTO DATA(lv_raw).
*     BOOKED_TIME_SLOT_FROM is HHMMSS; a slot key is HHMM. Compared on the
*     first four characters so a stored '123000' matches a '1230' slot.
      APPEND lv_raw(4) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    super->zif_rak_journey_logic~on_change( io_ctx = io_ctx iv_field = iv_field ).

    DATA(lv_f) = to_upper( iv_field ).

*   A SLOT THAT IS NO LONGER OFFERED MUST NOT SURVIVE THE CHANGE THAT
*   WITHDREW IT. Picking a date, then an engineer who is busy at that hour,
*   leaves the chosen slot sitting in the field: the dropdown no longer
*   lists it, the model still holds it, and the post carries it into a
*   clash the citizen was never shown. Clearing it puts the question back.
    IF lv_f = c_date OR lv_f = c_engineer OR lv_f = c_role.
      IF io_ctx->get_val( c_time ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_time iv_value = space ).
        trc( io_ctx  = io_ctx
             iv_text = |BA01    { lv_f } changed · cleared { c_time }, the slot list has moved| ).
      ENDIF.
    ENDIF.

    IF lv_f = c_date2 OR lv_f = c_engineer2 OR lv_f = c_sector.
      IF io_ctx->get_val( c_time2 ) IS NOT INITIAL.
        io_ctx->set_val( iv_name = c_time2 iv_value = space ).
        trc( io_ctx  = io_ctx
             iv_text = |BA01    { lv_f } changed · cleared { c_time2 }, the slot list has moved| ).
      ENDIF.
    ENDIF.

*   The engineer depends on the discipline on the case tab and on the
*   sector on the general tab, so a change upstream invalidates the choice
*   below it for the same reason.
    IF lv_f = c_role AND io_ctx->get_val( c_engineer ) IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_engineer iv_value = space ).
    ENDIF.
    IF lv_f = c_sector AND io_ctx->get_val( c_engineer2 ) IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_engineer2 iv_value = space ).
    ENDIF.

*   ---- "No slots available" ------------------------------------------
*   The live screen says it in red under the Time Slot box the moment a
*   date and an engineer are both chosen and nothing is free, and this is
*   the same moment: a date or an engineer has just changed.
*
*   SAID HERE AND NOT IN ON_VALUE_HELP( ). The resolver runs on every
*   render of that dropdown, so raising it there would repeat the warning
*   on every round trip until the citizen moved - including the one where
*   they are reading it.
*
*   AND NOT IN ON_CUSTOM_VALIDATE( ) EITHER. A blank Time Slot already
*   fails the required check with its own message; adding a second one at
*   submit would put two messages on screen for one problem, and the
*   useful moment is the press that caused it, not the press four fields
*   later.
    DATA(lv_gen)  = is_general( io_ctx ).
    DATA(lv_dfld) = COND string( WHEN lv_gen = abap_true THEN c_date2 ELSE c_date ).
    DATA(lv_efld) = COND string( WHEN lv_gen = abap_true THEN c_engineer2 ELSE c_engineer ).

    IF lv_f <> lv_dfld AND lv_f <> lv_efld.
      RETURN.
    ENDIF.

    DATA(lv_d) = io_ctx->get_val( lv_dfld ).
    DATA(lv_e) = io_ctx->get_val( lv_efld ).
    IF lv_d IS INITIAL OR lv_e IS INITIAL.
      RETURN.
    ENDIF.

*   Into a variable first, because what SLOTS( ) returns is an internal
*   TABLE. A scalar-returning call in this position is proven - every
*   handler here writes `io_ctx->get_val( .. ) IS INITIAL` and they all
*   activate - but a table-valued one has no precedent in this repository,
*   and CONCAT_LINES_OF( ) failed in exactly that position in
*   ZCL_RAK_JOURNEY_BE with `Unexpected operator "IS"` naming the method
*   rather than the expression. One variable costs nothing and settles it.
    DATA(lt_free) = slots( io_ctx = io_ctx iv_date = lv_d iv_engnr = lv_e ).
    IF lt_free IS INITIAL.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = zcl_rak_text=>pick(
                                   iv_base = 'No slots available'
                                   iv_ar   = 'لا يوجد موعد متاح' ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY CHECK. The base implementation is the PAID
*   gate; a redefinition REPLACES it, so omitting this call silently
*   removes payment protection - which is how E128 became submittable
*   unpaid, twice. It has to come before a CHECK because a failing CHECK
*   exits the method, taking the gate with it.
*
*   This service has no fee and no PAYFEE field, so the gate has nothing to
*   refuse - which is a reason to chain it, not a reason to skip it. A fee
*   added later must not depend on somebody remembering this line.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   ONLY WHAT CONFIGURATION CANNOT SAY. Everything with a single-field
*   answer - required, the mobile pattern, the email format, the 250
*   characters on a cancellation reason - is on the field rows where a
*   reviewer can see it. What is left is cross-field, and there are two.

*   ---- one of Case ID / Sector ---------------------------------------
*   VALIDATE( )'s CREATE branch refuses a booking with both blank, and
*   which one is filled is also what UPDATE( ) and CREATE_CASE( ) branch
*   on: available_case_id first, sector_id second. No REQUIRED flag can
*   express "one of these two", and marking either would mark it on the
*   tab where it does not belong.
    IF jny( io_ctx ) = c_jny_book AND iv_step = 1.
      DATA(lv_case) = io_ctx->get_val( c_case_id ).
      DATA(lv_sect) = io_ctx->get_val( c_sector ).
      IF lv_case IS INITIAL AND lv_sect IS INITIAL.
*       VALUE #( BASE rt ... ), so the gate's own messages are extended
*       rather than discarded.
*
*       FIELD named on the message: VALIDATE_STEP( ) gives it the same
*       red-border-and-tooltip treatment every built-in check gets, instead
*       of leaving the citizen to find the field by reading the strip.
        rt = VALUE #( BASE rt
          ( type  = 'Error'
            field = COND string( WHEN is_general( io_ctx ) THEN c_sector ELSE c_case_id )
            text  = COND string( WHEN is_general( io_ctx )
                                 THEN |Please choose a sector.|
                                 ELSE |Please choose the case this appointment is about.| ) ) ).
      ENDIF.
    ENDIF.

*   ---- a date that has already passed ---------------------------------
*   MIN_VAL cannot say "today". ZCL_RAK_JOURNEY_RULES puts a DATE field's
*   MIN_VAL through TO_DATS( ), which wants a literal date, so a config
*   value would have to be re-seeded every morning.
*
*   Nothing on the backend refuses it either: CREATE_CASE( ) writes
*   BOOKED_DATE as given, and APPOINTMENTS_SEARCH( ) then files the result
*   under Past - so a citizen who mistypes a year books an appointment that
*   is over before it is made, with a confirmation email to say so.
    DATA(lv_dfld) = COND string( WHEN is_general( io_ctx ) THEN c_date2 ELSE c_date ).
    DATA(lv_dval) = io_ctx->get_val( lv_dfld ).
    IF lv_dval IS NOT INITIAL.
      DATA(lv_dats) = zcl_rak_journey_util=>to_dats( lv_dval ).
*     Blank means TO_DATS( ) could not read it, which is the format check's
*     business and not this one's - two messages on one field for one
*     mistake is worse than the later of the two arriving alone.
      IF lv_dats IS NOT INITIAL AND lv_dats < CONV string( sy-datum ).
        rt = VALUE #( BASE rt
          ( type  = 'Error'
            field = lv_dfld
            text  = |Please pick a date from today onwards.| ) ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD appt_json.
*   The control's payload, rebuilt from ordinary fields.
*
*   THE KEYS ARE LOWER CASE AND THE SHAPE IS THE CONTROL'S, not a tidier
*   one. /UI2/CL_JSON=>DESERIALIZE( ) maps case-insensitively into
*   UPDATE( )'s local APPOINT_JSON_TYPE - partner, case_id, role, engineer,
*   date, appointment, sector - and a key that structure does not have is
*   dropped in silence. Renaming one here loses that value with no message
*   and no trace: the case is created, and the field it fed is blank.
*
*   Built by hand rather than through a serializer for the same reason the
*   BAdI builds its own by hand: the contract is six known keys, and a
*   serialized ABAP structure would carry component names and a casing
*   decided by the serializer rather than by the reader.
    DATA(lv_gen) = is_general( io_ctx ).

    DATA(lv_case) = io_ctx->get_val( c_case_id ).
    DATA(lv_sect) = COND string( WHEN lv_gen = abap_true THEN io_ctx->get_val( c_sector ) ).
    DATA(lv_role) = io_ctx->get_val( c_role ).
    DATA(lv_eng)  = COND string( WHEN lv_gen = abap_true
                                 THEN io_ctx->get_val( c_engineer2 )
                                 ELSE io_ctx->get_val( c_engineer ) ).
    DATA(lv_date) = COND string( WHEN lv_gen = abap_true
                                 THEN io_ctx->get_val( c_date2 )
                                 ELSE io_ctx->get_val( c_date ) ).
    DATA(lv_slot) = COND string( WHEN lv_gen = abap_true
                                 THEN io_ctx->get_val( c_time2 )
                                 ELSE io_ctx->get_val( c_time ) ).

*   yyyymmdd, whatever the citizen's DatePicker handed over. A
*   sap.m.DatePicker does NOT discard input it fails to parse - it flags
*   its own valueState and writes the typed characters through the two-way
*   binding anyway - so '19.08.1987' reaches here as those characters, and
*   the BAdI's date+0(4) / +4(2) / +6(2) slicing would read '19.0' as a
*   year without raising anything.
    DATA(lv_dats) = zcl_rak_journey_util=>to_dats( lv_date ).
    IF lv_dats IS NOT INITIAL.
      lv_date = |{ lv_dats }|.
    ENDIF.

    rv = |\{ "partner": "{ io_ctx->get_param( 'loginbp' ) }"| &&
         |, "case_id": "{ lv_case }"| &&
         |, "role": "{ lv_role }"| &&
         |, "engineer": "{ lv_eng }"| &&
         |, "date": "{ lv_date }"| &&
         |, "appointment": "{ lv_slot }"| &&
         |, "sector": "{ lv_sect }" \}|.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

*   SUPER FIRST. The base strips PAY_* and PAYFEE, and this journey has no
*   fee - so the strip removes nothing and chaining costs nothing, which is
*   exactly when it should be chained rather than skipped. D001, D025 and
*   E027 skip it deliberately because they ARE fee-bearing; that reasoning
*   does not apply here and copying their shape would.
    super->zif_rak_journey_logic~on_before_post( EXPORTING io_ctx = io_ctx
                                                 CHANGING  ct_kv  = ct_kv ).

    DATA(lv_json) = appt_json( io_ctx ).
    DATA(lv_gen)  = is_general( io_ctx ).

*   WHICH CARRIER, and it is not a free choice. UPDATE( ) deserializes
*   GS_DATA-APPOINT_JSON into the case-tab structure and
*   GS_DATA-APPOINT_JSON2 into the general-tab one, then branches on which
*   came back filled - so writing both would put a case booking and an
*   enquiry booking in front of it at once.
*
*   A reschedule always uses APPOINT_1_RE, which carries the same
*   GS_DATA-APPOINT_JSON. The general/case distinction on that screen is
*   READ( )'s to make, not ours.
    DATA(lv_carrier) = SWITCH string( jny( io_ctx )
                                      WHEN c_jny_resch THEN c_json_re
                                      ELSE COND string( WHEN lv_gen = abap_true
                                                        THEN c_json2 ELSE c_json ) ).

*   The key is the FIELD NAME, upper case. ITEMS_FROM_KV( ) then resolves
*   the TECH_NAME from the journey's own configuration - which is why a
*   carrier that is not a configured field is dropped here in silence, and
*   why both are seeded in the feeder even though only one is ever filled.
*   Hoisted into a variable rather than called inside the READ and the
*   DELETE. A functional call as a comparison value in a WHERE is accepted
*   in some releases and not others, and this class has no compiler in
*   front of it - a syntax error in one method takes the whole class down
*   at load and reports itself at every caller instead of here.
    DATA(lv_key) = to_upper( lv_carrier ).

    READ TABLE ct_kv ASSIGNING FIELD-SYMBOL(<kv>) WITH KEY key = lv_key.
    IF sy-subrc = 0.
      <kv>-value = lv_json.
    ELSE.
      APPEND VALUE #( key = lv_key value = lv_json ) TO ct_kv.
    ENDIF.

*   Cancellation posts no JSON at all - NBA01_1_5 has one textarea and the
*   appointment id is already the journey key - so the carrier written
*   above is dropped again rather than sent empty. An APPOINT_JSON with
*   blank values would be deserialized and would overwrite the appointment
*   being cancelled with nothing.
    IF jny( io_ctx ) = c_jny_cancl.
      DELETE ct_kv WHERE key = lv_key.
    ENDIF.

*   SAY WHAT WENT OUT. This one line answers, in a single round trip, the
*   question the next three rounds would otherwise be spent on: whether a
*   case created with a blank slot is the backend's doing or ours.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    post { jny( io_ctx ) } · action { action_for( io_ctx ) }| &&
                   | (NOT SENT - no header channel, see the class header)| &&
                   | · carrier { lv_carrier } = { lv_json }| ).
  ENDMETHOD.


* =====================================================================
* THE FOUR LISTS WITH NO SOURCE IN THIS SYSTEM
*
* On the live screen these come from the OData service behind the
* APPOINTMENT control - CasesSet, RolesSet, EngineersSet, SectorsSet and
* SuggestEngineerSet - and that service is not identified anywhere
* available: it is item 1 of doc/gaps/open-questions.md, and none of the
* seven entity sets appears on any DPC in this repository.
* ZCL_EGA_CJ_ENH_IMPL_OBA01 does not supply them either; it consumes the
* values the control produced.
*
* SO THEY RETURN NOTHING, AND EACH SAYS SO. An empty dropdown with no
* message is the hardest failure in this codebase to read - it looks
* identical to a rule that hid the field, to a search help with no
* entries, and to an API binding that fell through to a domain. One trace
* line per list names which one is empty and why.
*
* WHAT IS KNOWN ABOUT EACH, so that wiring one is a method body and not a
* fresh investigation:
*
*   ENGINEERS  ENGINEER_ID is a SAP user name. APPOINTMENTS_SEARCH( )
*              resolves the display name with
*                LEFT OUTER JOIN usr21 ON usr21~bname = b~engineer_id
*                LEFT OUTER JOIN adrp  ON adrp~persnumber = usr21~persnumber
*              taking concat_with_space( name_first, name_last ). So the
*              text half is settled; what is missing is WHICH users, given
*              a discipline or a sector.
*   CASES      the live hint says "Only rejected/pending Customer action
*              cases will be displayed", so it is the citizen's own cases
*              filtered by status. The partner is io_ctx->get_param(
*              'loginbp' ). The status set is the unknown.
*   ROLES      PICKED_ROLE. The screenshots show Architecture, Head of
*              Section, Electromechanics, Structural and Engineer - AD
*              reviewer, with the list scrolled, so it is longer than five.
*   SECTORS    SECTOR_ID. The screenshots show Buildings permitting,
*              Qualification, Advertisement, Inspection, Planning,
*              Infrastructure Permitting and Survey, also scrolled.
*
* NOT SEEDED FROM THE SCREENSHOTS. A hand-typed list would be a fork of
* something the department maintains, in two languages, with no key - and
* the keys are what post. A wrong list is harder to notice than no list,
* which is the same reason an API-bound field must never fall through to a
* domain that happens to share its name.
* =====================================================================


  METHOD cases.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    { c_case_id } has no option source · CasesSet is on the| &&
                   | appointment OData service, which is unidentified| &&
                   | (doc/gaps/open-questions.md item 1)| ).
  ENDMETHOD.


  METHOD roles.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    { c_role } has no option source · RolesSet is on the| &&
                   | appointment OData service, which is unidentified| ).
  ENDMETHOD.


  METHOD engineers.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    engineer list has no option source · EngineersSet /| &&
                   | SuggestEngineerSet are on the appointment OData service,| &&
                   | which is unidentified. The NAME half is known - usr21/adrp| &&
                   | on ENGINEER_ID - only the selection is missing| ).
  ENDMETHOD.


  METHOD sectors.
    trc( io_ctx  = io_ctx
         iv_text = |BA01    { c_sector } has no option source · SectorsSet is on the| &&
                   | appointment OData service, which is unidentified| ).
  ENDMETHOD.


ENDCLASS.
