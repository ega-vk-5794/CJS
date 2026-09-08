CLASS zcl_m028_cod_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M028 - Preliminary Design Approval Request
*& (legacy NCOD_1_1..1_3, category DML).
*&
*& ------------------------------------------------------------------
*& IT INHERITS ZCL_RAK_JOURNEY_LOGIC DIRECTLY, AND NOT
*& ZCL_RAK_MUN_LOGIC. THIS IS THE ONE THING IN THIS CLASS THAT WILL LOOK
*& LIKE A MISTAKE, SO IT IS THE FIRST THING WRITTEN DOWN.
*&
*& Every other Municipality handler - M011, M012, M016, M017, M029 -
*& inherits ZCL_RAK_MUN_LOGIC, and the family convention says this one
*& should too. It must not, because that class's ON_CUSTOM_VALIDATE( )
*& ends with:
*&
*&     IF io_ctx->get_val( c_fld_parcel ) IS INITIAL
*&        AND parcel_rows( io_ctx ) = 0.
*&       IF iv_step = 0.  "Select a parcel before continuing."
*&
*& C_FLD_PARCEL is 'PARCELSELECTOR'. M028's first step is a PROJECT list
*& (MY_COMPONENT, legacy RAK_PROJECTLIST) and carries no parcel selector
*& at all - so GET_VAL( ) would return blank for a field that is not on
*& the journey, PARCEL_ROWS( ) would return 0 because there is no parcel
*& grid, and step 0 would be refused for ever with a message about a
*& control the citizen cannot see. A field name not on the journey is
*& legal, silent and always blank; that is what makes this fail quietly
*& rather than loudly.
*&
*& WHAT IS GIVEN UP BY NOT INHERITING IT, and why none of it is needed:
*&   - the fee-total gate on the Pay press: M028 seeds no PAYFEE field
*&     (see ZRAK_M028_LOAD's header - that follows the walkthrough on
*&     instruction, against the export)
*&   - the two empty ON_BEFORE_POST / ON_BEFORE_FIELDS redefinitions that
*&     keep PAY_* in the payload: with no payment on the journey there is
*&     nothing to keep, and the base's strip is the correct behaviour
*&   - HAS_PARCEL( ) / PARCEL_ROWS( ) / FEE_TOTAL( ): no parcel, no fee
*&
*& The PAID gate itself is NOT given up - it lives in
*& ZCL_RAK_JOURNEY_LOGIC, which this class does inherit, and
*& ON_CUSTOM_VALIDATE( ) below chains to it.
*&
*& IF A PAYMENT STEP IS EVER ADDED to this journey, the gate is already
*& in place through that chain; what would also be needed is the
*& TOTALFEESVALUE check, and at that point copying the twenty lines out
*& of ZCL_RAK_MUN_LOGIC->ON_POPUP_EVENT( ) is the right move - not
*& re-parenting this class and reintroducing the parcel deadlock.
*&
*& ------------------------------------------------------------------
*& THE BUILDING LIST IS A HANDLER-DRAWN POPUP OVER AN EDITABLE_TABLE.
*&
*& The walkthrough shows an "Add Building" button beside "Building List*"
*& opening a dialog of eleven typed fields, and the saved building
*& appearing as a row. ZCL_RAK_MIGRATOR would have made ADDBUILDING an
*& ftype BUILDINGS - a value help over buildings that already exist -
*& which is right for other screens and wrong for this one, where the
*& citizen is creating buildings rather than choosing them. See
*& ZRAK_M028_LOAD's header.
*&
*& DIALOG_FORM( ), NOT A HAND-BUILT POPUP. It sets REQUIRED from each
*& field's own flag, so the asterisk cannot be forgotten - which is what
*& went wrong on E016/E017/E018, where nine, four and ten enforced popup
*& fields carried no markers between them.
*&
*& A POPUP'S REQUIRED IS A MARKER; THE HANDLER IS THE ENFORCEMENT.
*& VALIDATE_STEP( ) never sees popup fields, so BUILDING_FIELDS( ) and
*& the OK branch of ON_POPUP_EVENT( ) must mirror each other exactly.
*& Both carry that warning at the code.
*&
*& DELETE WORKS, EDIT IS NOT WIRED. The engine owns row delete for an
*& EDITABLE_TABLE (GRIDDEL_ in ZCL_RAK_JOURNEY_ENGINE), which is the bin
*& icon the walkthrough shows. The pencil beside it needs a hand-drawn
*& per-row action, because ftype TABLE never reaches RENDER_FIELD( ) -
*& RENDER_BLOCK( ) answers TABLE itself. ZCL_RAK_TEST_ALL_LOGIC->
*& RENDER_OWN_LIST( ) is the pattern. Flagged in the loader's run log
*& rather than half-built here.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- M028's own field vocabulary -----------------------------------
*   EVERY NAME IS THE LEGACY /QNV/SB_UI_DEFIN FIELD_NAME for NCOD_1_*,
*   because that is what the backend's field control is keyed on end to
*   end. Renaming any of these silently switches off MANDATORY / ENABLED
*   / VISIBLE from the live field-control engine.
    CONSTANTS c_fld_project TYPE string VALUE 'MY_COMPONENT'.
    CONSTANTS c_fld_grid    TYPE string VALUE 'ADDBUILDING'.

*   The Current Consultant card - all four read-only.
    CONSTANTS c_fld_cons_name   TYPE string VALUE 'NAME_DATA'.
    CONSTANTS c_fld_cons_lic    TYPE string VALUE 'LICENS_DATA'.
    CONSTANTS c_fld_cons_expiry TYPE string VALUE 'EXPIRY_DATA'.
    CONSTANTS c_fld_cons_grade  TYPE string VALUE 'GRADE_DATA'.

*   ---- the popup's own model members ---------------------------------
*   NOT legacy names: the legacy control kept these inside itself and the
*   export has no row for any of them. They are CJS model members that
*   exist only while the dialog is open, and they are prefixed so they
*   cannot collide with a journey field.
*
*   EVERY ONE IS UNDER 23 CHARACTERS. BUILD_MODEL( ) calls
*   CL_ABAP_STRUCTDESCR=>CREATE( ) per field and also builds _VS, _VST,
*   _IDTYPE, _NAME, _IX and _EXP companions on the same name, so 23 is
*   the real cap and CX_SY_STRUCT_COMP_NAME is uncaught - the whole app
*   dies with UNCAUGHT EXCEPTION, not a message.
    CONSTANTS c_pop_name  TYPE string VALUE 'BLD_NAME'.
    CONSTANTS c_pop_type  TYPE string VALUE 'BLD_TYPE'.
    CONSTANTS c_pop_usage TYPE string VALUE 'BLD_USAGE'.
    CONSTANTS c_pop_cost  TYPE string VALUE 'BLD_COST'.
    CONSTANTS c_pop_hgt   TYPE string VALUE 'BLD_HEIGHT'.
    CONSTANTS c_pop_typ   TYPE string VALUE 'BLD_TYPICAL'.
    CONSTANTS c_pop_flr   TYPE string VALUE 'BLD_FLOORS'.
    CONSTANTS c_pop_mezz  TYPE string VALUE 'BLD_MEZZ'.
    CONSTANTS c_pop_roof  TYPE string VALUE 'BLD_ROOF'.
    CONSTANTS c_pop_heli  TYPE string VALUE 'BLD_HELI'.
    CONSTANTS c_pop_base  TYPE string VALUE 'BLD_BASEMENT'.

*   ---- events --------------------------------------------------------
*   MATCHED WITH CP, NEVER AN OFFSET. IV_EVENT is TYPE string and event
*   names are short, so iv_event(8) on a six-character name raises
*   CX_SY_RANGE_OUT_OF_BOUNDS - which the engine turns into a Warning
*   rather than a dump, so it survives as an unexplained error on a
*   SUCCESSFUL action. That is exactly what happened to E016's Add.
    CONSTANTS c_evt_add    TYPE string VALUE 'BLDADD'.
    CONSTANTS c_evt_ok     TYPE string VALUE 'BLDOK'.
    CONSTANTS c_evt_cancel TYPE string VALUE 'BLDCXL'.
    CONSTANTS c_pop_id     TYPE string VALUE 'BLDPOP'.

*   Step indexes. STP1 is 0, STP2 is 1, STP3 is 2.
    CONSTANTS c_step_building   TYPE i VALUE 1.
    CONSTANTS c_step_discipline TYPE i VALUE 2.

    METHODS zif_rak_journey_logic~on_render_after_field REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup       REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event        REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate    REDEFINITION.

  PROTECTED SECTION.

*   The dialog's field list. THE SINGLE SOURCE for what the popup shows
*   AND what it marks required - read the warning at the implementation
*   before changing either.
*   TT_POP_FIELD WITHOUT A CLASS PREFIX, DELIBERATELY. The type is
*   declared in ZCL_RAK_JOURNEY_LOGIC's PROTECTED section, and an
*   inherited protected type is known in a subclass by its plain name.
*   Writing ZCL_RAK_JOURNEY_LOGIC=>TT_POP_FIELD here reads as safer and
*   is the form most likely to be refused.
    METHODS building_fields
      RETURNING VALUE(rt) TYPE tt_pop_field.

*   Blank every popup member, so the next Add opens empty instead of
*   holding the last building.
    METHODS clear_popup
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

*   Is the dialog complete? Returns the messages, empty when it is.
*   A POPUP CHECK HAS TO RETURN A VERDICT and the caller has to gate the
*   save AND the close on it - E017's returned nothing, the caller saved
*   and closed regardless, and a blank chemical row went to the case with
*   a warning toast as the only sign.
    METHODS validate_popup
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_msg.

  PRIVATE SECTION.

*   Number of disciplines the citizen has ticked.
    METHODS disciplines_chosen
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv) TYPE i.

ENDCLASS.



CLASS zcl_m028_cod_logic IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_render_after_field.

*   The Add Building button sits beside the list, which is what the
*   walkthrough shows. ON_RENDER_AFTER_FIELD is the hook for exactly
*   this - drawing next to a named field - and it keeps the button out of
*   the grid, which the engine owns.
    CHECK to_upper( is_field-name ) = c_fld_grid.

    io_view->button(
      text  = COND string( WHEN sy-langu = 'A' THEN `إضافة مبنى` ELSE `Add Building` )
      icon  = 'sap-icon://add'
      type  = 'Emphasized'
      press = io_ctx->event( c_evt_add ) ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.

*   CASE on the popup id, the way D001/D004 and E016/E017/E018 do. The
*   base's own popups reach here too, so anything not ours must fall
*   through to super rather than be swallowed.
    IF iv_id <> c_pop_id.
      super->zif_rak_journey_logic~on_render_popup( io_ctx   = io_ctx
                                                    io_popup = io_popup
                                                    iv_id    = iv_id ).
      RETURN.
    ENDIF.

*   TWO COLUMNS. The walkthrough's dialog puts Building type and Building
*   usage type side by side, and eleven fields one per row is a dialog
*   nobody can see the bottom of. Three would make the numeric fields a
*   third of the width for no gain.
    dialog_form( io_ctx     = io_ctx
                 io_popup   = io_popup
                 iv_title   = COND string( WHEN sy-langu = 'A'
                                           THEN `إضافة مبنى`
                                           ELSE `Add A Building` )
                 it_fields  = building_fields( )
                 iv_ok_text = COND string( WHEN sy-langu = 'A'
                                           THEN `إضافة المبنى`
                                           ELSE `Add Building` )
                 iv_ok_evt  = c_evt_ok
                 iv_cxl_evt = c_evt_cancel
                 iv_columns = 2 ).

  ENDMETHOD.


  METHOD building_fields.

*   ---- THIS LIST AND THE OK BRANCH MUST MIRROR EACH OTHER -------------
*   DIALOG_FORM( ) sets REQUIRED on the label and enforces NOTHING -
*   VALIDATE_STEP( ) never sees popup fields. So a field marked here and
*   not checked in VALIDATE_POPUP( ) promises an asterisk it never keeps,
*   and a field checked there and not marked here is the
*   looks-optional-and-will-not-save bug. Move one end, move the other.
*
*   The required set is the walkthrough's: every field carries a red
*   asterisk except Building costs.
*
*   BUILDING TYPE AND USAGE ARE PLAIN INPUTS FOR NOW. They are dropdowns
*   on the live screen, but nothing in this repository says what the
*   values are - the legacy control fills them from a read and the export
*   names no search help. An empty CLOSED_LIST would be unusable and a
*   hand-typed list lets a citizen pick a code the case cannot accept, so
*   they stay inputs until the source is known. Add OPTIONS, ROLLNAME,
*   DOMNAME or SHLP here and they become dropdowns with no other change.
*
*   TYPE 'NUMBER' ONLY WHERE THE VALUE REALLY IS NUMERIC. A non-numeric
*   value under type NUMBER renders an EMPTY input - the field looks
*   broken rather than wrong - so the floor counts and the height take it
*   and nothing else does.
    rt = VALUE #(
      ( name = c_pop_name  label = 'Building Name'          required = abap_true )
      ( name = c_pop_type  label = 'Building type'          required = abap_true )
      ( name = c_pop_usage label = 'Building usage type'    required = abap_true )
      ( name = c_pop_cost  label = 'Building costs'         type = 'NUMBER' )
      ( name = c_pop_hgt   label = 'Building Height in meters' type = 'NUMBER' required = abap_true )
      ( name = c_pop_typ   label = 'No of typical building' type = 'NUMBER' required = abap_true )
      ( name = c_pop_flr   label = 'No of Typical Floors'   type = 'NUMBER' required = abap_true )
      ( name = c_pop_mezz  label = 'No of Mezzanine Floors' type = 'NUMBER' required = abap_true )
      ( name = c_pop_roof  label = 'No of Roof Floors'      type = 'NUMBER' required = abap_true )
      ( name = c_pop_heli  label = 'No of Helioports'       type = 'NUMBER' required = abap_true )
      ( name = c_pop_base  label = 'No of Basement Floors'  type = 'NUMBER' required = abap_true ) ).

  ENDMETHOD.


  METHOD validate_popup.

*   THE MIRROR OF BUILDING_FIELDS( ) - see the warning there. Ten
*   required fields, ten checks, Building costs deliberately absent from
*   both.
    DATA lt_req TYPE zif_rak_journey=>tt_string.
    lt_req = VALUE #( ( c_pop_name ) ( c_pop_type ) ( c_pop_usage )
                      ( c_pop_hgt )  ( c_pop_typ )  ( c_pop_flr )
                      ( c_pop_mezz ) ( c_pop_roof ) ( c_pop_heli )
                      ( c_pop_base ) ).

*   THE FIELD LIST GOES INTO A VARIABLE FIRST. A functional method call
*   is not reliably accepted as the source of a LOOP AT on this release,
*   and a syntax error in one method takes the WHOLE class down at load -
*   which surfaces at every caller as "Method X is unknown or PROTECTED
*   or PRIVATE" and points nowhere near the cause.
    DATA(lt_fld) = building_fields( ).

    LOOP AT lt_fld INTO DATA(ls_f) WHERE required = abap_true.
      IF NOT line_exists( lt_req[ table_line = ls_f-name ] ).
        CONTINUE.
      ENDIF.
*     THE VALUE GOES INTO A VARIABLE FIRST. "IS INITIAL" is a predicate
*     over a DATA OBJECT, not over an expression, so a functional call as
*     its operand is rejected with "Unexpected operator IS" - a message
*     that names the operator rather than the call, which is what makes it
*     read like a typo in the IF.
      DATA(lv_val) = condense( io_ctx->get_val( ls_f-name ) ).
      IF lv_val IS INITIAL.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN |{ ls_f-label } مطلوب.|
              ELSE |{ ls_f-label } is required.| ) ) ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.

*   ---- CHAIN FIRST FOR EVERYTHING THAT IS NOT OURS -------------------
*   ON_POPUP_EVENT is the BP and attachment machinery for the whole
*   framework, and it is one of the four hooks whose base body does real
*   work. A redefinition that does not chain deletes all of it - so
*   anything this class does not recognise goes straight to super, and
*   the three branches below all RETURN so nothing can fall through into
*   the next one.
*
*   CP, NOT AN OFFSET, on every comparison - see the constants.
    IF iv_event CP |*{ c_evt_add }*|.
      clear_popup( io_ctx ).
      io_ctx->open_popup( c_pop_id ).
      RETURN.
    ENDIF.

    IF iv_event CP |*{ c_evt_cancel }*|.
      clear_popup( io_ctx ).
      io_ctx->close_popup( ).
      RETURN.
    ENDIF.

    IF iv_event CP |*{ c_evt_ok }*|.

*     THE SAVE AND THE CLOSE ARE BOTH GATED ON THE VERDICT, and leaving
*     the dialog open is the point - the citizen keeps what they typed.
      DATA(lt_msg) = validate_popup( io_ctx ).
      IF lt_msg IS NOT INITIAL.
        LOOP AT lt_msg INTO DATA(ls_m).
          io_ctx->add_msg( iv_type = ls_m-type iv_text = ls_m-text ).
        ENDLOOP.
        RETURN.
      ENDIF.

*     ---- THE CELL ORDER IS THE CONTRACT ----------------------------
*     SET_GRID_DATA( ) maps by name, but the COLUMNS came straight back
*     from GET_GRID_DATA( ), so the map is an identity map and cell N
*     lands in configured column N. A cell out of order is written to
*     the neighbouring column; one past the last column is dropped.
*     Neither raises anything.
*
*     The order lives in ZRAK_T_JNY_COL for ADDBUILDING, seeded by
*     ZRAK_M028_LOAD, and it is:
*
*       10 BNAME  20 BTYPE  30 BUSAGE  40 BCOST  50 BHEIGHT
*       60 BTYPICAL  70 BFLOORS  80 BMEZZ  90 BROOF
*       100 BHELI  110 BBASEMENT
*
*     Read that report before adding or reordering a column here.
      DATA(ls_grid) = io_ctx->get_grid_data( c_fld_grid ).
      DATA lt_cell TYPE zif_rak_journey=>tt_string.
      lt_cell = VALUE #(
        ( io_ctx->get_val( c_pop_name ) )
        ( io_ctx->get_val( c_pop_type ) )
        ( io_ctx->get_val( c_pop_usage ) )
        ( io_ctx->get_val( c_pop_cost ) )
        ( io_ctx->get_val( c_pop_hgt ) )
        ( io_ctx->get_val( c_pop_typ ) )
        ( io_ctx->get_val( c_pop_flr ) )
        ( io_ctx->get_val( c_pop_mezz ) )
        ( io_ctx->get_val( c_pop_roof ) )
        ( io_ctx->get_val( c_pop_heli ) )
        ( io_ctx->get_val( c_pop_base ) ) ).
      APPEND lt_cell TO ls_grid-rows.
      io_ctx->set_grid_data( iv_field = c_fld_grid is_data = ls_grid ).

      clear_popup( io_ctx ).
      io_ctx->close_popup( ).
      RETURN.
    ENDIF.

    super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                  iv_id    = iv_id
                                                  iv_event = iv_event ).

  ENDMETHOD.


  METHOD clear_popup.

*   Driven off BUILDING_FIELDS( ) rather than a second list, so a field
*   added to the dialog cannot be left behind here holding the previous
*   building's value.
    DATA(lt_fld) = building_fields( ).
    LOOP AT lt_fld INTO DATA(ls_f).
      io_ctx->set_val( iv_name = ls_f-name iv_value = `` ).
    ENDLOOP.

  ENDMETHOD.


  METHOD disciplines_chosen.

*   CB1..CB6. Six, from the export - the walkthrough shows four and the
*   other two are presumably hidden by the live field control, which
*   costs nothing here: a hidden checkbox is simply never ticked.
    DATA lv_cb TYPE string.
    DO 6 TIMES.
*     Same rule as VALIDATE_POPUP( ): IS NOT INITIAL needs a data object,
*     never a functional call.
      lv_cb = io_ctx->get_val( |CB{ sy-index }| ).
      IF lv_cb IS NOT INITIAL.
        rv = rv + 1.
      ENDIF.
    ENDDO.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. The base implementation is the
*   PAID gate; a redefinition REPLACES it, so omitting this call silently
*   removes payment protection - which is precisely how E128 became
*   submittable unpaid, twice. It has to come before a CHECK because a
*   failing CHECK exits the method, taking the gate with it.
*
*   This journey seeds no PAYFEE field today, so the gate has nothing to
*   refuse - but the call stays, because the day a payment step is added
*   nobody will remember to put it back.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   VALUE #( BASE rt ... ) below rather than `rt = VALUE #( ... )`, so
*   what the gate returned is extended rather than discarded.

*   ---- step 2: at least one building --------------------------------
*   The grid's own REQUIRED flag cannot do this.
*   ZCL_RAK_JOURNEY_RULES->MISSING_REQUIRED( ) checks required COLUMNS
*   against the rows that already exist and lets an empty grid pass -
*   "deliberately NOT a row-count check", in its own words. So REQUIRED
*   on ADDBUILDING draws the asterisk the live screen shows, and this is
*   the enforcement.
    IF iv_step = c_step_building.
*     Into a variable first - see the note in VALIDATE_POPUP( ) on why a
*     functional call is not left in an operand position here.
      DATA(ls_bld) = io_ctx->get_grid_data( c_fld_grid ).
      IF lines( ls_bld-rows ) = 0.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يرجى إضافة مبنى واحد على الأقل قبل المتابعة.`
              ELSE `Add at least one building before continuing.` ) ) ).
      ENDIF.
    ENDIF.

*   ---- step 3: at least one discipline ------------------------------
*   Six independent checkboxes cannot be a required CHECKGROUP, and this
*   is the reason a group would be wrong anywhere: a group is satisfied
*   by ticking ANY option, which is the right rule HERE but the wrong one
*   for terms and declarations. Written out rather than configured so the
*   distinction stays visible.
*
*   NO CHECK ON THE DRAWING COUNTS. The walkthrough shows 0 in every
*   stepper on a screen the citizen is about to submit, so zero is a
*   value the live service accepts and refusing it here would block a
*   submit the legacy screen allows.
    IF iv_step = c_step_discipline.
      IF disciplines_chosen( io_ctx ) = 0.
        rt = VALUE #( BASE rt
          ( type = 'Error'
            text = COND string(
              WHEN sy-langu = 'A'
              THEN `يرجى اختيار تخصص واحد على الأقل.`
              ELSE `Select at least one discipline.` ) ) ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


ENDCLASS.
