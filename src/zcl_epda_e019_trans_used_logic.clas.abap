CLASS zcl_epda_e019_trans_used_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*---------------------------------------------------------------------------------------*
* E019 Transport Used Oil - handler.  Config is ZRAK_E019_LOAD.
*
* ---- WHAT WAS WRONG WITH THE GENERATED VERSION ------------------------
* Three things, and all three were silent.
*
* 1. THE THREE CONTAINER LISTS WERE EMPTY. OWNER_FINDER_FIELDS( ),
*    PERMIT_FINDER_FIELDS( ) and LICENSE_FINDER_FIELDS( ) each returned
*    nothing behind a REVIEW-CONTAINER comment, so SHOW_ONLY( ) looped
*    over nothing and the whole conditional block on step 1 did not
*    exist: both panels rendered, always, and both posted. Whoever wrote
*    it was right not to guess - the legacy UI_FIELD_LOGICS names the
*    CONTAINER (OWNER_FINDER-V-F) and never its children - but the
*    export answers it, one PARENT_CONTAINER hop at a time:
*
*      OWNER_FINDER    -> LABEL_14, OWNER_1
*      PERMIT_FINDER   -> LABEL_13, PERMIT_NUMBER_1, PERMIT_NUMBER_2
*      LICENSE_FINDER  -> HBOX_9 -> VBOX_13 -> LABEL_15,
*                                              REGISTERED_EMIRATES_1
*                                 -> VBOX_14 -> LABEL_16, TRADE_LICENSE_1
*
*    The labels are not CJS fields (a caption belongs to its control
*    here) and PERMIT_NUMBER_2 is PERMIT_NUMBER_1's search affordance
*    rather than a second field, so what is left is the three lists
*    below.
*
* 2. THE GRID CHECKS WERE COMMENTED OUT. Both of them, against
*    MATERIALS_DET and VEHICLES, with a correct comment above explaining
*    exactly why they were needed. Field REQUIRED does not reach grid
*    rows, so an application with no vehicle and no material passed
*    validation and the backend accepted it.
*
* 3. THE SHOW/HIDE COULD NOT HAVE WORKED EVEN ONCE THE LISTS WERE
*    FILLED, because REGISTERED_EMIRATES_1 and TRADE_LICENSE_1 are also
*    field names on steps 2 and 4 - see below.
*
* ---- WHY IV_STEP IS PASSED, AND WHY THIS IS NOT RULES -----------------
* E014/E015/E027 do this same applicant-type toggle in ZRAK_T_JNY_RULE,
* and their handlers carry a comment telling you not to use set_hidden( )
* because it OUTRANKS the rules. E019 cannot follow them, and the reason
* is not a preference:
*
* A HIDE IS KEYED ON A FIELD NAME, AND THIS JOURNEY REUSES ITS NAMES.
* REGISTERED_EMIRATES_1 and TRADE_LICENSE_1 sit on STP1 (the licence
* block), STP2 (Transporter) and STP4 (Receiving Company); ADDRESS_1 on
* STP2 and STP4. Rules are journey-wide - MT_RULEHIDE is a bare list of
* names - so a rule hiding step 1's pair hides its namesakes on the
* other two steps as well, and both are REQUIRED there. The citizen gets
* a form with invisible mandatory fields that will not submit and says
* nothing about why.
*
* Renaming is not the way out: backend field control is keyed on the
* legacy FIELD_NAME end to end, so a rename silently stops
* MANDATORY/ENABLED/VISIBLE applying.
*
* So the overrides go through the handler WITH IV_STEP, which lands them
* on step 0 alone. That parameter was added for this; -1 (its default)
* still means every step, so nothing else in the package changes.
*
* ---- WHAT IS DELIBERATELY NOT HERE ------------------------------------
* THE PERMIT LOOKUP. PERMIT_SELECTION( ) on ZCL_EGA_CJ_CONSULTANT_ABS
* already reads ZV_EPDAPMMAST on the permit number during the post and
* fills GS_DATA-COMPANY, and raises its own messages when the number is
* blank or unknown. Repeating it here would be a second implementation
* of a lookup that works, against a view CJS has no reason to read.
*
* THE COMPANY-BLOCK LOCK. The impl class disables every non-button
* control on NE019_1_2 once the permit has loaded. That arrives through
* field control - SEED_CTRL( ) sends the config out, CTRL_OF( ) reports
* only what the BAdI changed, APPLY_CTRL( ) applies it - so it needs no
* handler code and must not get any, or the two would fight.
*---------------------------------------------------------------------------------------*

  PUBLIC SECTION.
*   Redefinitions, NOT "INTERFACES zif_rak_journey_logic". Declaring the interface
*   directly obliges this class to implement all ~25 of its methods; it implements
*   four, so it would never activate. Inheriting the base supplies the empty
*   defaults for the rest AND the payment card - the shape every other handler in
*   this package uses.
    METHODS zif_rak_journey_logic~on_after_read      REDEFINITION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_partner_owner_1 TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.
    CONSTANTS c_permit_yes      TYPE string VALUE 'PERMIT_YES' ##NO_TEXT.

*   The option keys, which are the legacy field names of the group members.
    CONSTANTS c_opt_rep         TYPE string VALUE 'PARTNER_REP_1' ##NO_TEXT.
    CONSTANTS c_opt_permit_yes  TYPE string VALUE 'PERMIT_YES' ##NO_TEXT.

*   STP1 is step 0. Every override in this class is scoped to it, so the
*   number is named once rather than repeated as a literal at six call sites.
    CONSTANTS c_step_applicant  TYPE i VALUE 0.
*   STP3, the materials step, whose two grids are checked on submit.
    CONSTANTS c_step_materials  TYPE i VALUE 2.

*   The children of each legacy container, resolved from PARENT_CONTAINER in
*   the /QNV/SB_UI_DEFIN export. See the class header for the derivation -
*   these are the lists that were empty.
    METHODS owner_finder_fields   RETURNING VALUE(rt) TYPE string_table.
    METHODS permit_finder_fields  RETURNING VALUE(rt) TYPE string_table.
    METHODS license_finder_fields RETURNING VALUE(rt) TYPE string_table.

    METHODS set_group
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string
                it_all  TYPE string_table
                it_tech TYPE string_table.

    METHODS show_only
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
                it_on  TYPE string_table
                it_off TYPE string_table.

    METHODS apply_permit_choice
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS apply_type_choice
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

*   THE OTHER HALF OF THE CARRIER MECHANISM, and not optional. Taking the
*   TECH_NAME off the two toggles also stops them being FILLED on the way
*   back, because BACKEND_READ( ) matches a definition to a field by
*   TECH_NAME - so a resumed draft would redraw both toggles blank while
*   the backend still held the answer. This reads the carriers and puts
*   each control back on the option they imply.
    METHODS uncarry
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

    METHODS fill_declaration
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.

ENDCLASS.



CLASS ZCL_EPDA_E019_TRANS_USED_LOGIC IMPLEMENTATION.


  METHOD owner_finder_fields.
*   Container OWNER_FINDER holds LABEL_14 and OWNER_1. The label is
*   OWNER_1's own caption in CJS, so the field is all that is left.
    rt = VALUE string_table( ( `OWNER_1` ) ).
  ENDMETHOD.


  METHOD permit_finder_fields.
*   Container PERMIT_FINDER holds LABEL_13, PERMIT_NUMBER_1 and
*   PERMIT_NUMBER_2. PERMIT_NUMBER_2 is the SEARCH_FIELD affordance on
*   the SAME backend component as PERMIT_NUMBER_1 (both bind
*   GS_DATA-PERMIT_NUMBER), not a second field, and the label is the
*   field's caption - so one name.
    rt = VALUE string_table( ( `PERMIT_NUMBER_1` ) ).
  ENDMETHOD.


  METHOD license_finder_fields.
*   Container LICENSE_FINDER nests two levels deeper than the others -
*   LICENSE_FINDER -> HBOX_9 -> VBOX_13 / VBOX_14 - which is why reading
*   only the direct children of the named container answers nothing and
*   the list looked unresolvable.
*
*   BOTH OF THESE NAMES ALSO EXIST ON STP2 AND STP4. Every hide and
*   require against them in this class carries IV_STEP for that reason.
    rt = VALUE string_table( ( `REGISTERED_EMIRATES_1` )
                             ( `TRADE_LICENSE_1` ) ).
  ENDMETHOD.


  METHOD set_group.
*   Every flag in the group, every time.
*
*   IT_TECH HOLDS CARRIER FIELD NAMES, NOT TECHNICAL NAMES, and that is
*   the correction. The generated version passed 'GS_DATA-PARTNER_OWNER'
*   here - a TECH_NAME - straight into SET_VAL( ), which takes a FIELD
*   name. There is no field called GS_DATA-PARTNER_OWNER, and SET_VAL( )
*   against a name the journey does not have is legal and does nothing:
*   the whole group write was silent, on every round trip, and the
*   backend flags were never set by this class at all.
*
*   IT_ALL and IT_TECH are positional - the nth option writes the nth
*   carrier - so a short IT_TECH would silently stop writing the tail of
*   the group. Checked rather than trusted.
    IF lines( it_all ) <> lines( it_tech ).
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = |Handler misconfigured: { lines( it_all ) } options |
                                 && |against { lines( it_tech ) } backend fields| ).
      RETURN.
    ENDIF.

    LOOP AT it_all INTO DATA(lv_opt).
      DATA(lv_i) = sy-tabix.
      io_ctx->set_val( iv_name  = it_tech[ lv_i ]
                       iv_value = COND string( WHEN lv_opt = iv_pick
                                               THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD show_only.
*   Both directions. SHOW alone leaves the other panel on screen after its
*   trigger is cleared, still holding values and still posting them.
*
*   IV_STEP = C_STEP_APPLICANT on every call. Without it the hide reaches
*   the namesakes on the Transporter and Receiving Company steps, where
*   they are required - see the class header.
    LOOP AT it_on INTO DATA(lv_on).
      io_ctx->set_hidden( iv_field = lv_on
                          iv_on    = abap_false
                          iv_step  = c_step_applicant ).
    ENDLOOP.
    LOOP AT it_off INTO DATA(lv_off).
      io_ctx->set_hidden( iv_field = lv_off
                          iv_on    = abap_true
                          iv_step  = c_step_applicant ).
*     Clearing the value matters as much as hiding the control: a hidden
*     field that still holds what the citizen typed still posts it, so
*     answering Yes after answering No would send both a permit number
*     and a trade licence.
      io_ctx->set_val( iv_name = lv_off iv_value = '' ).
    ENDLOOP.
  ENDMETHOD.


  METHOD apply_type_choice.
*   Applicant type. The legacy logic is explicit and reads backwards:
*   OWNER_FINDER-V-F on the Owner button, OWNER_FINDER-V-T on
*   Representative - so the owner lookup appears only when somebody
*   applies ON BEHALF of the owner, never when the owner applies
*   personally.
    DATA(lv_rep) = xsdbool( io_ctx->get_val( c_partner_owner_1 ) = c_opt_rep ).

    show_only( io_ctx = io_ctx
               it_on  = COND #( WHEN lv_rep = abap_true THEN owner_finder_fields( ) )
               it_off = COND #( WHEN lv_rep = abap_false THEN owner_finder_fields( ) ) ).

*   REQUIRED FOLLOWS VISIBILITY, and it has to be set both ways round.
*   set_required( iv_on = abap_false ) is not "leave it alone" - it
*   forces the field optional - which is exactly what is wanted while
*   the lookup is hidden, and exactly what must be undone when it is
*   shown again.
    io_ctx->set_required( iv_field = `OWNER_1`
                          iv_on    = lv_rep
                          iv_step  = c_step_applicant ).
  ENDMETHOD.


  METHOD apply_permit_choice.
*   PERMIT_FINDER when the answer is Yes, LICENSE_FINDER otherwise. The
*   legacy UI_FIELD_LOGICS pairs them - PERMIT_FINDER-V-T with
*   LICENSE_FINDER-V-F on the Yes button and the reverse on No - so
*   exactly one is ever on screen.
    DATA(lv_yes) = xsdbool( io_ctx->get_val( c_permit_yes ) = c_opt_permit_yes ).

    IF lv_yes = abap_true.
      show_only( io_ctx = io_ctx
                 it_on  = permit_finder_fields( )
                 it_off = license_finder_fields( ) ).
    ELSE.
      show_only( io_ctx = io_ctx
                 it_on  = license_finder_fields( )
                 it_off = permit_finder_fields( ) ).
    ENDIF.

*   The backend refuses each of these itself - PERMIT_SELECTION( ) raises
*   e575 for a missing permit number and e886/e887 for a missing licence
*   or emirate - but only AFTER the post. Marking them here means the
*   citizen sees the asterisk and the message on the step they are
*   standing on, instead of a round trip later.
    io_ctx->set_required( iv_field = `PERMIT_NUMBER_1`
                          iv_on    = lv_yes
                          iv_step  = c_step_applicant ).
    io_ctx->set_required( iv_field = `REGISTERED_EMIRATES_1`
                          iv_on    = xsdbool( lv_yes = abap_false )
                          iv_step  = c_step_applicant ).
    io_ctx->set_required( iv_field = `TRADE_LICENSE_1`
                          iv_on    = xsdbool( lv_yes = abap_false )
                          iv_step  = c_step_applicant ).
  ENDMETHOD.


  METHOD fill_declaration.
*   "I, <name>, as the company owner, hereby declare ..." - the legacy
*   READ builds DECLARATION_NAME by concatenating the applicant's name
*   with E003_DECLARATION_TEXT1, and this is the same sentence.
*
*   THE PARAGRAPH ITSELF IS NOT REPEATED HERE. It is ZRAK_T_CJ_TXT 900,
*   which the field's DEFAULT_VAL already points at as 'TEXT:@900' -
*   read per language on every round trip, so a wording change needs no
*   reseed and no transport. Only the name is prepended.
    DATA(lv_name) = io_ctx->get_val( `APP_NAME` ).
    IF lv_name IS INITIAL.
*     No name resolved yet - the portal session fills it. Leave the
*     field on its TEXT:@900 default rather than writing "I, ,".
      RETURN.
    ENDIF.

*   IV_DEFAULT IS A STRING LITERAL, NOT SPACE. The formal parameter is
*   TYPE string and these methods take their parameters by reference, so
*   binding SPACE - a data object of type C - is a syntax error, and a
*   syntax error in one method takes the whole class down at load. A
*   literal is accepted, which is what makes the wrong form look fine.
    DATA(lv_body) = zcl_rak_text=>get( iv_no      = '900'
                                       iv_default = `` ).
    IF lv_body IS INITIAL.
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name  = `DECLARATION_NAME`
                     iv_value = |I, { lv_name }, { lv_body }| ).
  ENDMETHOD.


  METHOD uncarry.
*   Carrier -> control, the reverse of SET_GROUP( ). Only ever writes when
*   a carrier actually holds 'X', so an unanswered toggle stays on its
*   configured default instead of being forced onto an option nobody
*   picked.
    IF io_ctx->get_val( `CY_PARTNER_REP` ) = 'X'.
      io_ctx->set_val( iv_name = c_partner_owner_1 iv_value = c_opt_rep ).
    ELSEIF io_ctx->get_val( `CY_PARTNER_OWNER` ) = 'X'.
      io_ctx->set_val( iv_name = c_partner_owner_1 iv_value = `PARTNER_OWNER_1` ).
    ENDIF.

    IF io_ctx->get_val( `CY_PERMIT_NO` ) = 'X'.
      io_ctx->set_val( iv_name = c_permit_yes iv_value = `PERMIT_NO` ).
    ELSEIF io_ctx->get_val( `CY_PERMIT_YES` ) = 'X'.
      io_ctx->set_val( iv_name = c_permit_yes iv_value = c_opt_permit_yes ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   ORDER MATTERS HERE. UNCARRY( ) first, because everything below reads
*   the control's value and on a resumed draft that value only exists
*   once the carriers have been read back.
    uncarry( io_ctx ).

*   Then the same show/hide the change handler does, applied on arrival.
*   Without this the first render shows both panels until the citizen
*   touches the control - and a resumed draft shows both for good.
    apply_type_choice( io_ctx ).
    apply_permit_choice( io_ctx ).

*   AND WRITE THE CARRIERS BACK OUT. A citizen who never touches either
*   toggle accepts both defaults, ON_CHANGE( ) never fires, and without
*   this the flags the backend tests would reach it blank - so
*   CASE_MAPPING( )'s CASE abap_true would match nothing and the
*   application would post with no applicant type at all.
    set_group( io_ctx  = io_ctx
               iv_pick = io_ctx->get_val( c_partner_owner_1 )
               it_all  = VALUE string_table( ( `PARTNER_OWNER_1` )
                                             ( `PARTNER_REP_1` ) )
               it_tech = VALUE string_table( ( `CY_PARTNER_OWNER` )
                                             ( `CY_PARTNER_REP` ) ) ).
    set_group( io_ctx  = io_ctx
               iv_pick = io_ctx->get_val( c_permit_yes )
               it_all  = VALUE string_table( ( `PERMIT_YES` )
                                             ( `PERMIT_NO` ) )
               it_tech = VALUE string_table( ( `CY_PERMIT_YES` )
                                             ( `CY_PERMIT_NO` ) ) ).

    fill_declaration( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

      WHEN c_partner_owner_1.
*       A LEGACY TOGGLE GROUP IS N BOOLEAN ITEMS, not one value. DATA1 on
*       each TBUTTON lists the whole group, and each member reaches the
*       backend as its own flag - so picking one has to write 'X' to it
*       AND blank to every sibling, or the previous answer travels too.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_partner_owner_1 )
                   it_all  = VALUE string_table( ( `PARTNER_OWNER_1` )
                                                 ( `PARTNER_REP_1` ) )
                   it_tech = VALUE string_table( ( `CY_PARTNER_OWNER` )
                                                 ( `CY_PARTNER_REP` ) ) ).
        apply_type_choice( io_ctx ).

      WHEN c_permit_yes.
        set_group( io_ctx  = io_ctx
                   iv_pick = io_ctx->get_val( c_permit_yes )
                   it_all  = VALUE string_table( ( `PERMIT_YES` )
                                                 ( `PERMIT_NO` ) )
                   it_tech = VALUE string_table( ( `CY_PERMIT_YES` )
                                                 ( `CY_PERMIT_NO` ) ) ).
        apply_permit_choice( io_ctx ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate: it refuses a submit while the fee is still
*   unpaid. Redefining without calling it would silently take that gate off this
*   journey. It self-guards - PAY_FIELD_STEP returns -1 when the journey has no
*   PAYFEE field - so it costs nothing on E019, which carries no fee at all.
*
*   It must also come BEFORE any CHECK, since a failing CHECK exits the method.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   REQUIRED DOES NOT REACH GRID ROWS. The grid field holds no scalar, so an
*   empty grid satisfies field validation and the application submits with no
*   vehicle and no material in it - which the backend accepts, because
*   CASE_MAPPING( ) only deletes incomplete vehicle rows and never objects to
*   there being none.
*
*   Per-COLUMN required is enforced and is seeded, but it judges rows that
*   already exist. Whether at least one exists can only be checked here.
*
*   These two were written and then commented out in the generated version,
*   with the comment above them left in place - so the code read as though
*   the check was there.
*
*   Steps count from ZERO in hooks, so the materials step is 2.
    IF iv_step <> c_step_materials.
      RETURN.
    ENDIF.

    IF lines( io_ctx->get_grid_data( `VEHICLES` )-rows ) = 0.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = |Add at least one vehicle before continuing.| ) ).
    ENDIF.

    IF lines( io_ctx->get_grid_data( `MATERIALS_DET` )-rows ) = 0.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = |Add at least one material before continuing.| ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
