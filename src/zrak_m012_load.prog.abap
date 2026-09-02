REPORT zrak_m012_load.

*&---------------------------------------------------------------------*
*& M012 - Request for Plots Merge
*&
*& ZRAK_M011_LOAD IS THE REFERENCE FEEDER FOR THIS FAMILY and carries the
*& full reasoning - the four things a hand feeder must not forget, why the
*& payment card is one field, why the domain validations stay in the BAdI,
*& why stage 2 is a separate service. Read it first. Only the differences
*& are explained here.
*&
*& Hand-authored from the /QNV/SB_UI_DEFIN export, screens NMERGE_1_1..1_4,
*& category MML.
*&
*& STRUCTURE - same four steps as M011:
*&   STP1  NMERGE_1_1  Parcel Selection   (selector PLUS add-a-parcel)
*&   STP2  NMERGE_1_2  Parcels & Documents (the chosen-parcels grid)
*&   STP3  NMERGE_1_3  Fees & Payment
*&
*& WHAT DIFFERS FROM M011, confirmed by field-set diff against the export
*& rather than assumed from the family:
*&
*&   - NMERGE_1_1 carries TWO controls: PARCELSELECTOR and ADDPRCLCTL
*&     (CONTROL_TYPE ADDPARCELS). M011 has only the selector.
*&   - NMERGE_1_2 carries RAKPARCELS (CONTROL_TYPE RAK_PARCELS), the list
*&     of what was chosen. M011 has no such grid.
*&   - only ONE uploader on NMERGE_1_2 (UPLOADER, not mandatory), against
*&     M011's three.
*&   - the handler is ZCL_M012_MERGE_LOGIC, which adds the one check the
*&     family does not have: a merge needs at least two parcels.
*&
*& Re-runnable: deletes its own rows first. Touches nothing outside 'M012'.
*&---------------------------------------------------------------------*

CONSTANTS c_jny TYPE zrak_t_jny-journey_id VALUE 'M012'.

START-OF-SELECTION.

  DELETE FROM zrak_t_jny_rule WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_col  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_opt  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_fld  WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny_step WHERE journey_id = @c_jny.
  DELETE FROM zrak_t_jny      WHERE journey_id = @c_jny.
  COMMIT WORK AND WAIT.

* ------------------------------------------------- the Arabic title
* See ZRAK_M011_LOAD: read from the legacy table, SPRAS 'A', never invented
* and never left blank.
  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'A'
    INTO @DATA(lv_title_ar).
  IF sy-subrc <> 0.
    CLEAR lv_title_ar.
  ENDIF.

  SELECT SINGLE description FROM zega_t_cj_idt
    WHERE journeyid = @c_jny AND spras = 'E'
    INTO @DATA(lv_title_en).
  IF sy-subrc <> 0 OR lv_title_en IS INITIAL.
    lv_title_en = 'Request for Plots Merge'.
  ENDIF.

* ---------------------------------------------------------------- header
  INSERT zrak_t_jny FROM @( VALUE #(
    mandt         = sy-mandt
    journey_id    = c_jny
    title         = lv_title_en
    title_ar      = lv_title_ar
    subtitle      = 'Apply to merge two or more adjoining plots, and track the request.'
    subtitle_ar   = 'تقديم طلب لدمج قطعتين أو أكثر متجاورتين ومتابعة الطلب.'
    layout_mode   = 'WIZARD'
    theme_variant = 'PORTAL'
    accent_type   = 'Emphasized'
    brand_color   = 'rgb(196,30,38)'
    navy_color    = 'rgb(16,35,62)'
    density       = 'Cozy'
    show_actions  = 'X'
    active        = 'X'
    handler_class = 'ZCL_M012_MERGE_LOGIC'
    bknd_active   = 'X'
    bknd_category = 'MML'
    bknd_journey  = 'M012'
    bknd_fm_post  = 'ZFM_EGA_CJ_FW_POST_N'
    bknd_fm_read  = 'ZFM_EGA_CJ_FW_READ_N' ) ).

* ---------------------------------------------------------------- steps
* NEXT_REQUIRES is NOT set on STP1 here, where M011 sets it to the parcel
* field. On a merge the citizen may legitimately pick nothing from their own
* list and add two parcels they do not own, so a single field cannot express
* "enough chosen" - the handler's row count does. Setting it would block a
* valid path.
  INSERT zrak_t_jny_step FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      title = 'Parcel Selection' title_ar = 'اختيار القطع'
      icon = 'sap-icon://map' bknd_screen = 'NMERGE_1_1' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      title = 'Parcels & Documents' title_ar = 'القطع والمستندات'
      icon = 'sap-icon://attachment' bknd_screen = 'NMERGE_1_2' active = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      title = 'Fees & Payment' title_ar = 'الرسوم والدفع'
      icon = 'sap-icon://payment-approval' bknd_screen = 'NMERGE_1_3'
      active = 'X' ) ) ).

* --------------------------------------------------- STP1 Parcel Selection
* PARCELSEL is the same live control as M011's - see that feeder for why the
* API: directive is bound to PropertiesSet and emphatically not to
* FindParcelSet.
*
* ADDPARCEL IS THE ONE THAT NEEDS A DECISION, and it is seeded as a plain
* INPUT rather than as a composite. ADDPARCELS is EXTENDED in the export - a
* control drawn by JavaScript, whose inner fields the export does not
* describe at all - and its whole purpose is a parcel the citizen does NOT
* own, so it cannot read from PropertiesSet, which answers only their own.
* An API: binding here would produce a list that can never contain what the
* citizen is looking for.
*
* REVIEW-BE: the legacy control validates the typed number against the
* cadastre and warns that it is not owned - the requirement document's own
* screenshots show both "Add parcel that I don't own" and "Unexpected error
* while adding non owned parcel", so that path is not clean on the live
* service either. CJS has no wrapper for that read: ZCL_RAK_PROPERTY_API
* filters on the citizen's Partnerguid by construction. Until one exists the
* typed number reaches the backend unvalidated and the BAdI's own
* VALIDATE( ) is what refuses it - a worse round trip than the legacy
* control, and the reason this is flagged rather than quietly shipped.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
*   FTYPE 'PARCELS' - PLURAL - IS THE MULTI-SELECT ONE. It draws a
*   CHECKBOX on every card instead of a Select button and stores a '-'
*   separated list, which is the same form the backend already keeps the
*   parcel list in: ZIF_EGA_FW_CJI~UPDATE( ) builds the CJ02 note as
*   parcel && '-' && ui_table_column1 and splits it back the same way.
*
*   M011 and M016 stay on 'PARCEL' - one parcel, one Select button.
*   Nothing about them changes.
*
*   THIS REPLACED AN ACCUMULATE-IN-THE-HANDLER APPROACH THAT WAS WRONG.
*   The first version kept the single-select control and had
*   ZCL_M012_MERGE_LOGIC move each pick into the grid from ON_CHANGE. It
*   worked in principle and was wrong on screen: the card showed nothing
*   selected afterwards, and there was no way to UNPICK a parcel. A
*   checkbox is the only affordance that says "several, and you can
*   change your mind" - which is what the legacy control does with its
*   own bMulti flag.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 10
      field_name = 'PARCELSELECTOR' ftype = 'PARCELS'
      zlabel = 'Your parcels' zlabel_ar = 'قطعك'
      default_val = 'API:PROPERTY:PropertiesSet::Type=Parcel'
      tech_name = 'INTRENO_PARCEL' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 20
      field_name = 'ADDPRCLCTL' ftype = 'INPUT'
      zsection = 'Add a parcel you do not own'
      zlabel = 'Parcel number' zlabel_ar = 'رقم القطعة'
      placeholder = 'Enter the parcel number'
      placeholder_ar = 'أدخل رقم القطعة'
*     Digits only. The cadastre numbers are numeric and the legacy control
*     zero-pads on the way in, so a letter here is a typo rather than a
*     format this service supports.
      regex = '^[0-9]{1,20}$' max_len = 20
      msg = 'Enter a parcel number using digits only'
      msg_ar = 'أدخل رقم القطعة بالأرقام فقط' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP1' seqnr = 30
      field_name = 'MERGEHINT' ftype = 'DISPLAY'
      default_val = 'A merge needs at least two parcels. Pick from your own ' &&
                    'list, or add a parcel you do not own - the owner''s ' &&
                    'letter of consent will then be required.' ) ) ).

* --------------------------------------------------- STP2 Parcels & Documents
* THE GRID'S COLUMNS COME FROM THE BAdI, NOT FROM THE EXPORT. RAK_PARCELS is
* EXTENDED, so /QNV/SB_UI_DEFIN describes none of its inner fields and there
* is not one LEVEL_CON = 'T' row for it anywhere in NMERGE. The authoritative
* order is ZCL_EGA_CJ_FW_RO_ABS_V1->GET_PL_TABLE( ), which fills
* FIELD1..FIELD7 in exactly this sequence:
*
*   field1  parcel id          <fs_parcel>-objid
*   field2  ownership state    'Mortgaged' / 'Self-Owned' / 'Not Owned Parcel'
*   field3  location           VIBDLOCHIER -> TIVBDLOCHIER-XLOCHIER
*   field4  address            PARCEL_ADDRESS( ), BAPI_RE_PL_GET_DETAIL
*   field5  ownership method   <fs_parcel>-ownershpmthd
*   field6  grant type         <fs_parcel>-granttype
*   field7  required action    'Letter of consent' / 'Attach NOC from bank'
*
* AND THE ORDER IS LOAD-BEARING AT BOTH ENDS. ZCL_RAK_JOURNEY_BE hands cell
* N to configured column N of this spec, and the BAdI fills FIELDn from
* LIST_SEQUENCE in /QNV/SB_UI_DEFIN. Nothing checks that the two agree: a
* column out of order renders the NEIGHBOURING value, silently. So this spec
* must not be reordered without re-reading GET_PL_TABLE( ).
*
* REVIEW-GRID: the columns above are read from the BAdI source, which is the
* right source, but the /QNV/ LIST_SEQUENCE rows that decide which FIELDn
* each value lands in could not be checked for RAK_PARCELS because it has
* none. If a column comes back showing its neighbour's value, this spec
* against GET_PL_TABLE( ) is the first place to look.
*
* READONLY, and that is deliberate. The citizen does not type parcel
* details - the two controls on step 1 choose parcels and the backend
* answers with everything else. Making the grid editable would invite edits
* the post discards.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 10
*   EDITABLE_TABLE, NOT TABLE - AND THE ENGINE SAID SO OUT LOUD:
*
*     Grid RAKPARCELS: FTYPE is TABLE, not EDITABLE_TABLE.
*     Only an editable grid has rows to read or write.
*
*   three times on one screen, followed by "Added. 0 parcel(s) selected."
*   GET_GRID_DATA( ) and SET_GRID_DATA( ) work only on an EDITABLE_TABLE,
*   so with TABLE the handler's read answered nothing and its write went
*   nowhere - and the count it printed was honest.
*
*   FIELD-LEVEL READONLY IS OFF, AND PER-COLUMN READONLY IS ON INSTEAD.
*   The intent was never that the citizen types parcel details - those come
*   from GET_PL_TABLE( ) on the backend read - it was that the grid should
*   not be typable. ZRAK_T_JNY_COL-READONLY does exactly that, per column,
*   and leaves the grid itself editable so the handler can write rows and
*   the citizen gets a delete button per row. READONLY on the FIELD takes
*   the rows away from both of them.
      field_name = 'RAKPARCELS' ftype = 'EDITABLE_TABLE'
      zsection = 'Parcels to merge'
      zlabel = 'Parcels to merge' zlabel_ar = 'القطع المطلوب دمجها'
      default_val = 'PARCELID:Parcel:TEXT'          &&
                    '|OWNSTATE:Ownership:TEXT'      &&
                    '|LOCATION:Location:TEXT'       &&
                    '|ADDRESS:Address:TEXT'         &&
                    '|OWNMETHOD:Ownership method:TEXT' &&
                    '|GRANTTYPE:Grant type:TEXT'    &&
                    '|ACTIONREQ:Action required:TEXT'
*     THE `[]` SUFFIX IS THE GRID CONVENTION. Without a TECH_NAME the rows
*     post nothing; the bridge flattens a grid into the table payload the
*     BAdI reads as CT_TABLE_DATA, whose UI_TABLE_COLUMN1 is where
*     ZIF_EGA_FW_CJI~UPDATE( ) reads each parcel from to build the CJ02
*     note.
      tech_name = 'GS_DATA-PARCELS[]' )
*   Same field as M011's, same characteristic CJ11, same RE note.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 20
      field_name = 'ENTERTEXT' ftype = 'TEXTAREA' required = 'X'
      zsection = 'Request Details'
      zlabel = 'Describe the merge you are requesting'
      zlabel_ar = 'اذكر تفاصيل الدمج المطلوب'
      placeholder = 'Describe why the plots should be merged'
      placeholder_ar = 'اذكر سبب دمج القطع'
      msg = 'Describe the merge you are requesting'
      msg_ar = 'يرجى ذكر تفاصيل الدمج المطلوب'
      min_len = 10 max_len = 1000
      tech_name = 'PLOTLONGTEXT' )
*   ONE uploader on this screen, and MANDATORY is blank in the export - so
*   optional here. M011 has three, two of them mandatory; the difference is
*   real and was diffed rather than assumed.
*   ATTACH_MULTI IS OFF, and it is worth saying why because this is the one
*   field on the three journeys where multiple files would be natural.
*
*   The legacy uploaders carry DATA2 = 1/2/3 as a document type, which the
*   BAdI files as ZDT_EGA_CJ_ATTR-DIFFCRT. CJS does not send it:
*   ZCL_RAK_JOURNEY_BE->ATTACHMENTS_FOR_BACKEND( ) sets only identifier1/2,
*   file_name and file_content. So DIFFCRT arrives blank, and
*   GET_ATTACHMENT( ) de-duplicates on
*   ( objsrc, diffcrt, objsrctype, objtrgtype ) - all four of which are
*   identical for two files uploaded to the SAME field. The second file is
*   then dropped on re-read and the citizen sees one document where they
*   attached two, with nothing anywhere reporting it.
*
*   ATTACH_MULTI STAYS OFF, and carrying the document type does not change
*   that. ZCL_RAK_JOURNEY_BE now sends DIFFCRT where the field declares one
*   - which is what lets a case tell a title deed from an Emirates ID - but
*   two files on the SAME field share a field and therefore share a type,
*   so they still de-duplicate to one on re-read. Multi-file needs the
*   OCCURRENCE key in identifier1, which is a different mechanism.
*
*   NMERGE_1_2's single UPLOADER carries no DATA2 at all, so this field
*   declares no DTYPE: rather than inventing one.
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' seqnr = 30
      field_name = 'UPLOADER' ftype = 'UPLOAD'
      zsection = 'Attachments'
      zlabel = 'Supporting document' zlabel_ar = 'مستند مؤيد'
      attach_label = 'Add document' has_attach = 'X'
      attach_types = 'pdf,jpg,jpeg,png' attach_maxmb = 5 ) ) ).

* --------------------------------------------------- STP3 Fees & Payment
* Identical to M011's - see that feeder for why the legacy screen's radio
* groups, fee CLIST and remaining-fees controls are NOT re-created as
* fields, and for the TOTALFEESVALUE caveat.
  INSERT zrak_t_jny_fld FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 10
      field_name = 'PAYFEE' ftype = 'PAYFEE'
      zlabel = 'Payment' zlabel_ar = 'الدفع' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 20
      field_name = 'TOTALVALUE' ftype = 'DISPLAY' readonly = 'X'
      hidden = 'X'
      zlabel = 'Total fees' zlabel_ar = 'إجمالي الرسوم'
      tech_name = 'TOTALFEESVALUE' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 30
      field_name = 'CHECKBOX_3' ftype = 'CHECKBOX' required = 'X'
      zlabel = 'I / We acknowledge and accept the Terms & Conditions applicable and available on the site'
      zlabel_ar = 'أنا / نحن نعترف ونقبل الشروط والأحكام المعمول بها والمتاحة على الموقع'
      msg = 'The Terms & Conditions must be accepted before payment'
      msg_ar = 'يجب قبول الشروط والأحكام قبل الدفع'
      tech_name = 'ACCEPT_TERMS' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP3' seqnr = 40
      field_name = 'CHECKBOX_4' ftype = 'CHECKBOX'
      zlabel = 'I would like to donate five dirhams to Ajer Charity Foundation.'
      zlabel_ar = 'أود التبرع لمؤسسة آجر الخيرية بمبلغ خمسة دراهم.'
      tech_name = 'DONATE' ) ) ).


* ------------------------------------------- STP2 grid columns
* READONLY ON EVERY COLUMN, which is how the grid stays editable as a
* TABLE while none of its CELLS is typable.
*
* ZRAK_T_JNY_COL-READONLY is one of the four column properties that is
* actually enforced (WIDTH is applied too; PINNED and DECIMALS are inert
* and the Studio labels them so). The FIELD is EDITABLE_TABLE because
* only an editable grid has rows the handler can read or write - see the
* note on the field above - and per-column READONLY is what stops that
* editability reaching the citizen's keyboard.
*
* THE ORDER IS GET_PL_TABLE( )'s FIELD1..FIELD7 and must stay that way.
* These rows are read in preference to the pipe spec on the field itself
* (ZCL_RAK_JOURNEY_GRID->GRID_COLS( )), so the two must agree - and cell
* N still lands in configured column N at both ends.
*
* NO REQUIRED ANYWHERE. It IS enforced, against every row that already
* exists - and every one of these cells is filled by the backend read,
* not by the citizen, so a required column would refuse a row the moment
* it was added and before the read could fill it.
  INSERT zrak_t_jny_col FROM TABLE @( VALUE #(
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'PARCELID'  seqnr = 1 zlabel = 'Parcel' zlabel_ar = 'القطعة'
      ctrl = 'INPUT' readonly = 'X' width = '9rem' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'OWNSTATE'  seqnr = 2 zlabel = 'Ownership' zlabel_ar = 'الملكية'
      ctrl = 'INPUT' readonly = 'X' width = '9rem' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'LOCATION'  seqnr = 3 zlabel = 'Location' zlabel_ar = 'الموقع'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'ADDRESS'   seqnr = 4 zlabel = 'Address' zlabel_ar = 'العنوان'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'OWNMETHOD' seqnr = 5 zlabel = 'Ownership method' zlabel_ar = 'طريقة الملكية'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'GRANTTYPE' seqnr = 6 zlabel = 'Grant type' zlabel_ar = 'نوع المنحة'
      ctrl = 'INPUT' readonly = 'X' )
    ( mandt = sy-mandt journey_id = c_jny step_id = 'STP2' field_name = 'RAKPARCELS'
      col_name = 'ACTIONREQ' seqnr = 7 zlabel = 'Action required' zlabel_ar = 'الإجراء المطلوب'
      ctrl = 'INPUT' readonly = 'X' ) ) ).

  COMMIT WORK AND WAIT.
  zcl_rak_cj_cfg_cache=>invalidate( iv_journey = CONV #( c_jny ) ).

* ---------------------------------------------------------------- report
  WRITE: / 'M012 Request for Plots Merge - seeded.'.
  WRITE: / ''.
  WRITE: / 'Title    :', lv_title_en.
  IF lv_title_ar IS INITIAL.
    WRITE: / 'Title AR : NOT FOUND in ZEGA_T_CJ_IDT - add the SPRAS A row'.
    WRITE: / '           and re-run, or Arabic readers see English.'.
  ELSE.
    WRITE: / 'Title AR :', lv_title_ar.
  ENDIF.
  WRITE: / ''.
  WRITE: / 'STEPS'.
  WRITE: / '  STP1 Parcel Selection      NMERGE_1_1   3 fields'.
  WRITE: / '  STP2 Parcels & Documents   NMERGE_1_2   3 fields'.
  WRITE: / '  STP3 Fees & Payment        NMERGE_1_3   4 fields'.
  WRITE: / ''.
  WRITE: / 'WALKTHROUGH'.
  WRITE: / '  1. Launch &journey=M012 with a real session.'.
  WRITE: / '  2. Step 1: press Select on one of your own parcels. The'.
  WRITE: / '     pick is MOVED INTO THE LIST and the picker clears, so the'.
  WRITE: / '     next press is a second parcel rather than a replacement -'.
  WRITE: / '     the control is single-select and a merge needs two.'.
  WRITE: / '     A message confirms the running count each time.'.
  WRITE: / '  3. Or type a parcel number you do not own; same accumulate.'.
  WRITE: / '  4. Pressing Next with fewer than two is refused by'.
  WRITE: / '     ZCL_M012_MERGE_LOGIC - it counts the GRID, not the picker.'.
  WRITE: / '  5. Step 2 lists them with ownership, location, address and the'.
  WRITE: / '     action each one requires - filled by the backend read.'.
  WRITE: / '  6. Step 3 is the payment card.'.
  WRITE: / '  Pay is refused without the Terms checkbox and without a fee'.
  WRITE: / '  total - the legacy PAY-E semantic, enforced at the press in'.
  WRITE: / '  ZCL_RAK_MUN_LOGIC, because the PAYFEE card draws its own Pay'.
  WRITE: / '  button and no configuration can grey it out.'.
  WRITE: / '  Pay then creates the ZGCX case, the gateway opens, and the'.
  WRITE: / '  engine draws its own success page and happiness meter from'.
  WRITE: / '  MV_SUBMITTED and WANTS_FEEDBACK - neither is seeded here.'.
  WRITE: / '  There is NO Review step: the legacy service has none.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-BE'.
  WRITE: / '  - ADDPARCEL is an unvalidated INPUT. The legacy ADDPARCELS'.
  WRITE: / '    control checks the number against the cadastre and warns'.
  WRITE: / '    when it is not owned; CJS has no wrapper for that read,'.
  WRITE: / '    because ZCL_RAK_PROPERTY_API filters on the citizen''s own'.
  WRITE: / '    Partnerguid by construction. Until one exists the number'.
  WRITE: / '    reaches the backend unchecked and VALIDATE( ) refuses it.'.
  WRITE: / '  - Whether the legacy service also refuses a one-parcel merge'.
  WRITE: / '    is NOT established - VALIDATE( ) has no such rule. If it'.
  WRITE: / '    permits one, this journey is stricter than the service it'.
  WRITE: / '    replaces, and that is the owning team''s call.'.
  WRITE: / '  - ATTACHMENT DOCUMENT TYPE IS NOT SENT. The legacy uploaders'.
  WRITE: / '    carry DATA2 = 1/2/3 as the document type and the BAdI files'.
  WRITE: / '    it as ZDT_EGA_CJ_ATTR-DIFFCRT, but'.
  WRITE: / '    ATTACHMENTS_FOR_BACKEND( ) sets only identifier1/2,'.
  WRITE: / '    file_name and file_content - so DIFFCRT arrives blank and'.
  WRITE: / '    passes the mandatory check. GET_ATTACHMENT( ) then'.
  WRITE: / '    de-duplicates on (objsrc, diffcrt, objsrctype, objtrgtype),'.
  WRITE: / '    so two files on ONE field come back as one. ATTACH_MULTI is'.
  WRITE: / '    off on UPLOADER for that reason. Affects M011 and M016.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-GRID'.
  WRITE: / '  PARCELS columns are read from GET_PL_TABLE( ) FIELD1..FIELD7'.
  WRITE: / '  and are POSITIONAL at both ends. RAK_PARCELS is EXTENDED, so'.
  WRITE: / '  the export carries no LIST_SEQUENCE rows to check them'.
  WRITE: / '  against. A column showing its neighbour''s value means this'.
  WRITE: / '  spec and GET_PL_TABLE( ) have drifted - do not reorder it'.
  WRITE: / '  without re-reading that method.'.
  WRITE: / ''.
  WRITE: / 'REVIEW-TECH  (fields with no TECH_NAME, each deliberate)'.
  WRITE: / '  ADDPARCEL   feeds the grid; the grid is what posts'.
  WRITE: / '  MERGEHINT   guidance paragraph'.
  WRITE: / '  REVIEW      the engine''s review renderer'.
  WRITE: / '  PAYFEE      the payment card'.
  WRITE: / '  UPLOADER    posts through the attachment channel'.
  WRITE: / ''.
  WRITE: / 'NOT MIGRATED'.
  WRITE: / '  As M011 - stage bar, header labels, 111 buttons, the payment'.
  WRITE: / '  card''s own radios and fee list, the confirmation page. Plus'.
  WRITE: / '  M012-specific: the ADDPARCELS composite is replaced by a'.
  WRITE: / '  plain INPUT, see REVIEW-BE.'.
  WRITE: / ''.
  WRITE: / 'STILL TO DO'.
  WRITE: / '  - Run ZCL_RAK_CJS_XCHECK for M012.'.
  WRITE: / '  - Wire the add-a-parcel lookup, or accept the round trip.'.
  WRITE: / '  - Stage 2 (NMERGE_2_1..2_3) is a separate service.'.
  WRITE: / '  - Nothing here has been activated or run.'.
