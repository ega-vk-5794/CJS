class ZCL_M012_MERGE_LOGIC definition
  public
  inheriting from ZCL_RAK_MUN_LOGIC
  final
  create public .

*&---------------------------------------------------------------------*
*& M012 - Request for Plots Merge (legacy NMERGE_1_1..1_4).
*&
*& TWO THINGS M012 NEEDS THAT THE FAMILY DOES NOT.
*&
*& 1. A MERGE NEEDS TWO PARCELS. Nothing in /QNV/SB_UI_DEFIN says so; it is
*&    in the nature of the service. Worth doing CJS-side, where the other
*&    nine validations are deliberately left to the BAdI, because it needs
*&    no table read - so it cannot fork domain logic and cannot go stale.
*&
*& 2. THE SELECTION AND THE GRID HAVE TO AGREE. PARCELSELECTOR is FTYPE
*&    'PARCELS' - the multi-select form, checkboxes on the cards - and it
*&    stores a '-' separated list. RAKPARCELS on step 2 is what the backend
*&    reads the parcels out of: ZIF_EGA_FW_CJI~UPDATE( ) walks
*&    CT_TABLE_DATA and builds the CJ02 note from UI_TABLE_COLUMN1. So the
*&    list has to reach the grid, and this class is what carries it.
*&
*& THE LIST IS THE SINGLE SOURCE OF TRUTH AND THE GRID IS DERIVED. That is
*& the second design here; the first one had the grid as the store and
*& ACCUMULATED into it on every pick, which was wrong in two ways that only
*& showed on screen:
*&
*&   - the card had no way to say "selected", because the value it compared
*&     against had already been moved into the grid and cleared. Every card
*&     looked unpicked however many were chosen.
*&   - and there was no way to UNPICK one. A merge assembled by mistake had
*&     to be abandoned.
*&
*& With checkboxes bound to the list, ticking and unticking both work and
*& the grid is rebuilt from whatever the list now says. SYNC_GRID( ) is
*& therefore idempotent and order-preserving, and it never has to know
*& whether this round trip added or removed anything.
*&
*& REVIEW-BE: whether the legacy service ALSO refuses a single-parcel merge,
*& and with which message, is not established - VALIDATE( ) has no such
*& check and the "at least one owned parcel" rule (ZMSG_EGA_CJ 011) is a
*& different condition. If it turns out the backend permits it, this class
*& is stricter than the service it replaces and that is a decision for the
*& owning team, not a defect to fix quietly.
*&---------------------------------------------------------------------*
public section.

*   A merge needs two. Named rather than inline so the number is findable.
  constants C_MIN_PARCELS type I value 2 ##NO_TEXT.
*   The add-a-parcel-you-do-not-own input. ADDPRCLCTL is the legacy
*   FIELD_NAME - the export's CONTROL_TYPE there is ADDPARCELS - and the
*   field control is keyed on the FIELD_NAME. See ZCL_RAK_MUN_LOGIC's
*   constants note.
  constants C_FLD_ADD type STRING value 'ADDPRCLCTL' ##NO_TEXT.
*   The separator the selector stores its list with, and the one the
*   backend already uses for the CJ02 note. Repeated here rather than
*   reached for on ZCL_RAK_CJ_PARCEL, because a static reference to that
*   class would put the whole wrapper-API chain in this handler's load
*   graph - the reason the engine creates it dynamically in the first
*   place.
  constants C_SEP type STRING value '-' ##NO_TEXT.

*   WHY ON_CHANGE. ZCL_RAK_CJ_PARCEL->TOGGLE( ) writes the list and then
*   calls ON_CHANGE for the field, exactly as PICK( ) always has - so this
*   fires on every tick and untick with the finished list already stored.
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
protected section.

*   The selected parcels, in the order the citizen picked them.
  methods PARCEL_KEYS
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
    returning
      value(RT) type STRING_TABLE .
*   Rebuild RAKPARCELS from the selection. Idempotent.
  methods SYNC_GRID
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY .
*   Append one key to the selection unless it is already there. Answers
*   whether it was added.
  methods ADD_KEY
    importing
      !IO_CTX type ref to ZIF_RAK_JOURNEY
      !IV_KEY type STRING
    returning
      value(RV) type ABAP_BOOL .
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_M012_MERGE_LOGIC IMPLEMENTATION.


  METHOD parcel_keys.
    DATA(lv_v) = io_ctx->get_val( c_fld_parcel ).
    IF lv_v IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT lv_v AT c_sep INTO TABLE rt.
*   A leading, trailing or doubled separator leaves blank entries, which
*   would otherwise count as a selected parcel with no number.
    DELETE rt WHERE table_line IS INITIAL.
  ENDMETHOD.


  METHOD add_key.

    DATA(lv_k) = condense( iv_key ).
    IF lv_k IS INITIAL.
      RETURN.
    ENDIF.

*   COMPARED UNPADDED. The selector stores the service's own zero-padded
*   PARCELID and a typed number is not padded, so comparing as-is would let
*   the same parcel in twice under two spellings - and the backend would
*   then refuse the whole post on its duplicate rule (ZMSG_EGA_CJ 012)
*   after a round trip.
    DATA(lv_cmp) = lv_k.
    SHIFT lv_cmp LEFT DELETING LEADING '0'.

    LOOP AT parcel_keys( io_ctx ) INTO DATA(lv_h).
      DATA(lv_ht) = lv_h.
      SHIFT lv_ht LEFT DELETING LEADING '0'.
      IF lv_ht = lv_cmp.
        RETURN.
      ENDIF.
    ENDLOOP.

    DATA(lv_v) = io_ctx->get_val( c_fld_parcel ).
    IF lv_v IS INITIAL.
      lv_v = lv_k.
    ELSE.
      lv_v = |{ lv_v }{ c_sep }{ lv_k }|.
    ENDIF.
    io_ctx->set_val( iv_name = c_fld_parcel iv_value = lv_v ).
    rv = abap_true.

  ENDMETHOD.


  METHOD sync_grid.

*   READ, REBUILD, WRITE. GET_GRID_DATA( ) returns a COPY - editing what it
*   gave back changes nothing on screen - and there is no per-cell write,
*   so the whole table goes back.
*
*   THE GRID MUST BE AN EDITABLE_TABLE OR THIS DOES NOTHING, and it says so
*   rather than failing quietly: with FTYPE 'TABLE' the engine warns
*   "Only an editable grid has rows to read or write" and both calls are
*   no-ops. That cost a screen full of warnings and an "Added. 0 parcel(s)
*   selected." before the feeder was corrected.
    DATA(ls_grid) = io_ctx->get_grid_data( c_fld_parcels ).

*   COLUMNS GO BACK EXACTLY AS THEY CAME. SET_GRID_DATA( ) matches them BY
*   NAME, so handing back what was handed out is an identity map and cannot
*   put a value in the neighbouring column. Building a column list here is
*   how a cell ends up one place to the left.
    DATA lt_rows LIKE ls_grid-rows.

*   HOW MANY CELLS A ROW NEEDS. In a variable first: `DO ( lines( ... ) - 1 )
*   TIMES` is a SYNTAX ERROR - DO ... TIMES takes a data object, not a
*   functional expression - and it is the same trap as the TYPE HANDLE and
*   VALUE ones in CLAUDE.md. Written the wrong way twice in one session
*   already.
    DATA lv_pad TYPE i.
    lv_pad = lines( ls_grid-columns ) - 1.

    LOOP AT parcel_keys( io_ctx ) INTO DATA(lv_k).

*     ONE CELL FILLED, THE REST EMPTY, AND THAT IS CORRECT. Only the parcel
*     number is known here. Ownership state, location, address, ownership
*     method, grant type and the required action all come from
*     ZCL_EGA_CJ_FW_RO_ABS_V1->GET_PL_TABLE( ), which reads them per parcel
*     off the CJ02 note on the next backend read. Inventing them would put
*     values on screen that the round trip then contradicts.
*
*     The cells must still be PRESENT: a row shorter than the column list
*     is a row whose later cells are undefined rather than blank.
      DATA lt_cells TYPE zif_rak_journey=>tt_string.
      CLEAR lt_cells.
      APPEND lv_k TO lt_cells.
      IF lv_pad > 0.
        DO lv_pad TIMES.
          APPEND `` TO lt_cells.
        ENDDO.
      ENDIF.
      APPEND lt_cells TO lt_rows.

    ENDLOOP.

*   REPLACED WHOLE, NOT APPENDED TO. That is what makes an untick work: the
*   grid is whatever the list now says, so a removed parcel disappears
*   without this method needing to know it was removed.
*
*   IT ALSO DISCARDS THE BACKEND'S OWN COLUMNS on every sync, which is
*   accepted rather than overlooked: the next read fills them again from
*   the CJ02 note. The alternative - matching old rows to new keys and
*   preserving their cells - keeps a stale ownership state on a parcel the
*   citizen just re-added, which is the worse of the two.
    ls_grid-rows = lt_rows.
    io_ctx->set_grid_data( iv_field = c_fld_parcels is_data = ls_grid ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.

*   SUPER FIRST. ON_CHANGE's base body is empty today, but chaining costs
*   nothing and an empty redefinition becomes a deletion the moment the
*   base grows one - which is how E128 lost its PAID gate.
    super->zif_rak_journey_logic~on_change( io_ctx = io_ctx iv_field = iv_field ).

*   THE SELECTOR. TOGGLE( ) has already written the finished list, so there
*   is nothing to add here - only the grid to bring into line with it.
    IF iv_field = c_fld_parcel.
      sync_grid( io_ctx ).
      RETURN.
    ENDIF.

*   THE TYPED PARCEL - one the citizen does NOT own. It goes into the same
*   list the checkboxes drive, so it appears as a ticked card if the
*   citizen happens to own it after all, and in the grid either way.
*
*   REVIEW-BE: unvalidated here, deliberately. The legacy ADDPARCELS
*   control checks the number against the cadastre and warns that it is not
*   owned; ZCL_RAK_PROPERTY_API filters on the citizen's own Partnerguid by
*   construction and so cannot answer for a parcel they do not own. The
*   backend's VALIDATE( ) refuses one that does not exist (ZMSG_EGA_CJ 006
*   no owner role, 011 none owned), so the citizen finds out on the post
*   rather than on the keystroke.
    IF iv_field = c_fld_add.
      DATA(lv_typed) = io_ctx->get_val( c_fld_add ).
      IF lv_typed IS NOT INITIAL.
        IF add_key( io_ctx = io_ctx iv_key = lv_typed ) = abap_true.
          sync_grid( io_ctx ).
          io_ctx->add_msg(
            iv_type = 'Success'
            iv_text = COND string(
              WHEN sy-langu = 'A'
              THEN |تمت الإضافة. عدد القطع المختارة: { lines( parcel_keys( io_ctx ) ) }|
              ELSE |Added. { lines( parcel_keys( io_ctx ) ) } parcel(s) selected.| ) ).
        ELSE.
          io_ctx->add_msg(
            iv_type = 'Information'
            iv_text = COND string(
              WHEN sy-langu = 'A' THEN `هذه القطعة مضافة بالفعل.`
              ELSE `That parcel is already in the list.` ) ).
        ENDIF.
*       CLEARED EITHER WAY, so the box is ready for the next number and
*       does not read as "this is your selection" - the cards and the grid
*       are the selection.
        io_ctx->set_val( iv_name = c_fld_add iv_value = `` ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK`. This chains TWO levels - the
*   family's "pick a parcel" check in ZCL_RAK_MUN_LOGIC, which itself
*   chains ZCL_RAK_JOURNEY_LOGIC's PAID gate. Skipping it removes both, and
*   the payment one silently.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   Step 1 only - steps count from ZERO in hooks.
    CHECK iv_step = 0.

*   THE SELECTION IS COUNTED, NOT THE GRID. Both should agree - SYNC_GRID( )
*   is called on every change - but the list is the source and the grid is
*   derived, so counting the derived copy would report a stale number for
*   one round trip if a sync were ever missed.
    DATA(lv_n) = lines( parcel_keys( io_ctx ) ).

*   NOTHING CHOSEN AT ALL is the base's message, not this one. Two messages
*   for one empty screen reads as two problems.
    CHECK lv_n > 0.

    IF lv_n < c_min_parcels.
      rt = VALUE #( BASE rt
        ( type = 'Error'
          text = COND string(
            WHEN sy-langu = 'A'
            THEN `يجب اختيار قطعتي أرض على الأقل للدمج.`
            ELSE `Select at least two parcels to merge.` ) ) ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
