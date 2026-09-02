CLASS zcl_m012_merge_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M012 - Request for Plots Merge (legacy NMERGE_1_1..1_4).
*&
*& THE ONE THING M012 NEEDS THAT THE FAMILY DOES NOT: a merge of one parcel
*& is not a merge. The legacy screen carries TWO controls on step 1 -
*& PARCELSELECTOR for the citizen's own parcels and ADDPRCLCTL (ADDPARCELS)
*& for one they do not own - and then RAK_PARCELS on step 2 listing what was
*& chosen. Nothing in /QNV/SB_UI_DEFIN says two is the minimum; it is in the
*& nature of the service.
*&
*& WHY THIS ONE IS WORTH DOING CJS-SIDE when the other nine validations are
*& deliberately left to the backend: it needs no table read. Every rule in
*& ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( ) needs VILMPL, VIBPOBJREL, JEST or a
*& function module, so a copy here would fork domain logic and go stale. A
*& row count does not. It saves the citizen a post that the backend would
*& reject anyway, and it cannot disagree with the backend because it is not
*& re-deciding anything the backend decides.
*&
*& REVIEW-BE: whether the legacy service ALSO refuses a single-parcel merge,
*& and with which message, is not established - VALIDATE( ) has no such
*& check and the "at least one owned parcel" rule (ZMSG_EGA_CJ 011) is a
*& different condition. If it turns out the backend permits it, this class is
*& stricter than the service it replaces and that is a decision for the
*& owning team, not a defect to fix quietly.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   A merge needs two. Named rather than inline so the number is findable.
    CONSTANTS c_min_parcels TYPE i VALUE 2.

*   The add-a-parcel-you-do-not-own input. ADDPRCLCTL is the legacy
*   FIELD_NAME - the export's CONTROL_TYPE there is ADDPARCELS - and the
*   field control is keyed on the FIELD_NAME. See ZCL_RAK_MUN_LOGIC's
*   constants note.
    CONSTANTS c_fld_add TYPE string VALUE 'ADDPRCLCTL'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

*   ---- HOW TWO PARCELS GET SELECTED ------------------------------------
*   THE PARCEL CONTROL IS SINGLE-SELECT AND A MERGE NEEDS TWO. That is the
*   whole reason this method exists.
*
*   ZCL_RAK_CJ_PARCEL stores ONE key in the field: a press calls PICK( ),
*   which writes the chosen parcel and nothing else. Its own header says
*   the real answer is one multi-select list and that it does not have one
*   yet - so on this journey a second press would simply replace the first,
*   and the citizen could never assemble a merge.
*
*   Rather than wait for multi-select in the control, the two step-1
*   controls ACCUMULATE into the grid, which is also what the legacy screen
*   does: PARCELSELECTOR and ADDPRCLCTL are pickers, and RAKPARCELS on
*   step 2 is the list of what was picked. Each pick or typed number is
*   appended here and the picker is then CLEARED, so it is ready for the
*   next one and the grid is the single source of what was chosen.
*
*   WHY ON_CHANGE AND NOT AN ADD BUTTON. A button beside the field would
*   need AFTER_FIELD( ) plus a FLOW layout row plus an event, and it would
*   be a second way to do the same thing. The picker raising CHANGE is
*   already the citizen's "I want this one" - ZCL_RAK_CJ_PARCEL's PICK( )
*   writes the value and the engine raises CHANGE on it, and a typed parcel
*   number raises CHANGE when the field is left.
    METHODS zif_rak_journey_logic~on_change REDEFINITION.

  PROTECTED SECTION.

*   Append one parcel number to the grid, unless it is already there.
*   Answers whether it was added, so the caller can decide what to say.
    METHODS add_parcel
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_parcel TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m012_merge_logic IMPLEMENTATION.


  METHOD add_parcel.

    DATA(lv_p) = condense( iv_parcel ).
    IF lv_p IS INITIAL.
      RETURN.
    ENDIF.

*   READ, REBUILD, WRITE. GET_GRID_DATA( ) returns a COPY - editing what it
*   gave back changes nothing on screen - and there is no per-cell write, so
*   the whole table goes back. The interface is explicit about both.
    DATA(ls_grid) = io_ctx->get_grid_data( c_fld_parcels ).

*   COLUMNS COME BACK FROM THE READ AND GO STRAIGHT BACK IN. They are the
*   seven from the field's DEFAULT_VAL spec, and SET_GRID_DATA( ) matches
*   them BY NAME - so handing back what was handed out is an identity map
*   and cannot put a value in the neighbouring column. Building a column
*   list here instead is how a cell ends up one place to the left.
*
*   Columns are published even when there are no rows yet, so this works on
*   the first pick.

*   ALREADY THERE? The duplicate-parcel rule is the backend's
*   (ZMSG_EGA_CJ 012) and it will refuse the post - but letting the citizen
*   add the same parcel twice and only finding out after a round trip is a
*   worse experience than not adding it. Compared UNPADDED, because the
*   selector stores what the service returned - which is zero-padded - and
*   a typed number is not.
    DATA(lv_cmp) = lv_p.
    SHIFT lv_cmp LEFT DELETING LEADING '0'.

    LOOP AT ls_grid-rows INTO DATA(lt_row).
      DATA(lv_have) = VALUE #( lt_row[ 1 ] OPTIONAL ).
      SHIFT lv_have LEFT DELETING LEADING '0'.
      IF lv_have = lv_cmp AND lv_have IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDLOOP.

*   ONE CELL FILLED, SIX EMPTY, AND THAT IS CORRECT. Only column 1 - the
*   parcel number - is known here. Ownership state, location, address,
*   ownership method, grant type and the required action all come from
*   ZCL_EGA_CJ_FW_RO_ABS_V1->GET_PL_TABLE( ), which reads them per parcel
*   off the CJ02 note on the next backend read. Inventing them here would
*   put values on screen that the next round trip contradicts.
*
*   The cells must still be PRESENT though: a row shorter than the column
*   list is a row whose later cells are undefined rather than blank.
*   THE COUNT GOES IN A VARIABLE FIRST. `DO ( lines( … ) - 1 ) TIMES` is a
*   SYNTAX ERROR: DO ... TIMES takes a data object, not a functional
*   expression, and it is not a general expression position. Same family as
*   the TYPE HANDLE and VALUE traps in CLAUDE.md, and the same mistake that
*   stopped ZRAK_CJ_EXPAND_DIAG activating an hour ago - where the cost is
*   the one that file warns about: the class does not activate, the runtime
*   keeps the previous version, and nothing on screen changes.
    DATA lv_pad TYPE i.
    lv_pad = lines( ls_grid-columns ) - 1.

    DATA lt_new TYPE zif_rak_journey=>tt_string.
    lt_new = VALUE #( ( lv_p ) ).
    IF lv_pad > 0.
      DO lv_pad TIMES.
        APPEND `` TO lt_new.
      ENDDO.
    ENDIF.

    APPEND lt_new TO ls_grid-rows.
    io_ctx->set_grid_data( iv_field = c_fld_parcels is_data = ls_grid ).
    rv = abap_true.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

*   SUPER FIRST. ON_CHANGE's base body is empty today, but chaining costs
*   nothing and an empty redefinition is a deletion the moment the base
*   grows a body - which is exactly how E128 lost its PAID gate.
    super->zif_rak_journey_logic~on_change( io_ctx = io_ctx iv_field = iv_field ).

*   THE PARCEL PICKER. ZCL_RAK_CJ_PARCEL->PICK( ) has just written the
*   chosen parcel into the field; move it into the grid and clear the
*   picker so the next press is a second parcel rather than a replacement.
    IF iv_field = c_fld_parcel.
      DATA(lv_sel) = io_ctx->get_val( c_fld_parcel ).
      IF lv_sel IS NOT INITIAL.
        IF add_parcel( io_ctx = io_ctx iv_parcel = lv_sel ) = abap_false.
          io_ctx->add_msg(
            iv_type = 'Information'
            iv_text = COND string(
              WHEN sy-langu = 'A' THEN `هذه القطعة مضافة بالفعل.`
              ELSE `That parcel is already in the list.` ) ).
        ELSE.
*         THE RUNNING COUNT, SAID OUT LOUD, because the citizen cannot see
*         it otherwise. RAKPARCELS lives on STEP 2 - that is where the
*         legacy screen puts it and, more to the point, a field's step is
*         which BKND_SCREEN it posts to, so moving the grid to step 1 would
*         post the parcels to NMERGE_1_1 instead of NMERGE_1_2. So on step
*         1 a pick would otherwise clear the picker and show nothing at
*         all, which reads as the press having failed.
          io_ctx->add_msg(
            iv_type = 'Success'
            iv_text = COND string(
              WHEN sy-langu = 'A'
              THEN |تمت الإضافة. عدد القطع المختارة: { parcel_rows( io_ctx ) }|
              ELSE |Added. { parcel_rows( io_ctx ) } parcel(s) selected.| ) ).
        ENDIF.
*       CLEARED WHETHER OR NOT IT WAS ADDED. A picker still holding the
*       last pick reads as "this is your selection", which on a
*       multi-parcel journey is the wrong story - the grid is the
*       selection.
        io_ctx->set_val( iv_name = c_fld_parcel iv_value = `` ).
      ENDIF.
      RETURN.
    ENDIF.

*   THE TYPED PARCEL - one the citizen does NOT own.
*
*   REVIEW-BE: unvalidated here, deliberately. The legacy ADDPARCELS
*   control checks the number against the cadastre and warns that it is not
*   owned; ZCL_RAK_PROPERTY_API filters on the citizen's own Partnerguid by
*   construction and so cannot answer for a parcel they do not own. The
*   backend's VALIDATE( ) refuses a number that does not exist
*   (ZMSG_EGA_CJ 006 has no owner role, 011 none owned), so the citizen
*   finds out on the post rather than on the keystroke. Flagged in the
*   feeder too.
    IF iv_field = c_fld_add.
      DATA(lv_typed) = io_ctx->get_val( c_fld_add ).
      IF lv_typed IS NOT INITIAL.
        IF add_parcel( io_ctx = io_ctx iv_parcel = lv_typed ) = abap_false.
          io_ctx->add_msg(
            iv_type = 'Information'
            iv_text = COND string(
              WHEN sy-langu = 'A' THEN `هذه القطعة مضافة بالفعل.`
              ELSE `That parcel is already in the list.` ) ).
        ELSE.
*         THE RUNNING COUNT, SAID OUT LOUD, because the citizen cannot see
*         it otherwise. RAKPARCELS lives on STEP 2 - that is where the
*         legacy screen puts it and, more to the point, a field's step is
*         which BKND_SCREEN it posts to, so moving the grid to step 1 would
*         post the parcels to NMERGE_1_1 instead of NMERGE_1_2. So on step
*         1 a pick would otherwise clear the picker and show nothing at
*         all, which reads as the press having failed.
          io_ctx->add_msg(
            iv_type = 'Success'
            iv_text = COND string(
              WHEN sy-langu = 'A'
              THEN |تمت الإضافة. عدد القطع المختارة: { parcel_rows( io_ctx ) }|
              ELSE |Added. { parcel_rows( io_ctx ) } parcel(s) selected.| ) ).
        ENDIF.
        io_ctx->set_val( iv_name = c_fld_add iv_value = `` ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. This chains TWO levels - the
*   family's "pick a parcel" check in ZCL_RAK_MUN_LOGIC, which itself chains
*   ZCL_RAK_JOURNEY_LOGIC's PAID gate. Skipping it here would remove both,
*   and the payment one silently.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   Step 1 only - steps count from ZERO in hooks, so the parcel step is 0.
    CHECK iv_step = 0.

*   AND ONLY WHEN SOMETHING WAS CHOSEN. With nothing chosen at all the base
*   has already said "select a parcel", and two messages for one empty
*   screen reads as two problems.
*
*   THE GRID IS THE ONLY COUNT NOW. An earlier version added one for a
*   selector still holding a value - which was right while a pick STAYED in
*   the field, and became double-counting the moment ON_CHANGE started
*   moving each pick into the grid and clearing the picker. The selector is
*   empty between picks by design, so reading it here would count the last
*   parcel twice and let a single-parcel merge through.
    DATA(lv_rows) = parcel_rows( io_ctx ).
    CHECK lv_rows > 0.

    IF lv_rows < c_min_parcels.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = COND string(
            WHEN sy-langu = 'A'
            THEN `يجب اختيار قطعتي أرض على الأقل للدمج.`
            ELSE `Select at least two parcels to merge.` ) ) ).
    ENDIF.

  ENDMETHOD.


ENDCLASS.
