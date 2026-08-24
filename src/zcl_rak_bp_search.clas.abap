CLASS zcl_rak_bp_search DEFINITION
  PUBLIC
  CREATE PUBLIC.

* Business partner search with the protocol taken off it. Calls
* ZCL_EGA_BP_BO_API->BP_QUERY exactly as it stands - nothing in the BO API is
* touched, added to, or assumed about.
*
* BUSINESSPARTNERS_GET_ENTITYSET is three things and only the first is OData:
*
*   1. build filters, call BP_QUERY
*   2. decide whether the partner may be used - MOI cross-check, trade licence
*      expiry, Emirates ID expiry, and their skip conditions
*   3. turn any of that into /IWBEP/CX_MGW_BUSI_EXCEPTION
*
* Step 2 is what everybody needs and nobody else can reach, and it is the part
* that must not be copied: two divergent answers to "is this Emirates ID expired"
* is how one department starts accepting what another rejects, with nothing in
* either codebase to say so. It moves here, once. The DPC keeps step 3 and keeps
* CREATE_PARTNER, both of which are its own business.
*
*
* ============================ READ BEFORE CALLING ============================
*
* BP_QUERY IS NOT A READ WHEN AN EMIRATES ID IS SUPPLIED. Its own code:
*
*     IF lv_eid IS NOT INITIAL.
*       CALL FUNCTION 'ZCRM_MOI_CR_UPD_MASS' ...
*       WAIT UP TO 5 SECONDS.
*
* Three consequences, none of them visible from the outside:
*
*   - It WRITES. MOI create/update mass runs on every EId search.
*   - It costs AT LEAST five seconds, every time, by construction.
*   - WAIT UP TO ends the SAP LUW and triggers an implicit database COMMIT. Any
*     uncommitted work the caller had open is committed at that point, whether it
*     was ready or not.
*
* For CJS that last one is the dangerous one. Call this from on_search - a button
* the citizen presses - and never from on_change, where it would fire per
* keystroke, block a work process for five seconds a time, and commit a
* half-finished step behind the citizen's back.
*
* ET_RETURN from BP_QUERY carries the MOI function module's messages and nothing
* else. The BOPF no-data message is commented out in the BO API, which is why the
* "No data found" text below is raised here rather than expected from there.
*
* =============================================================================

  PUBLIC SECTION.

*   What a caller actually knows. All optional; supply what you have.
    TYPES: BEGIN OF ty_req,
             eid           TYPE string,   " EId, dashes or not
             trade_licence TYPE string,   " TradeLicense
             partner       TYPE string,
             idtype        TYPE string,
             search_term   TYPE string,
             dob           TYPE string,   " MOI cross-check only
             nationality   TYPE string,   " MOI cross-check only
             call_moi      TYPE abap_bool,
             "            Flag, and it is not a boolean. Three values are in live use and each
             "            switches off something different:
             "
             "              ''   everything runs
             "              'X'  MOI is called and the BP updated from it, but a DOB or
             "                   nationality mismatch does NOT reject. Both expiry checks
             "                   still run. This is CallMoi=X & Flag=X on the /rak/cj service.
             "              'T'  tenancy. BOTH expiry checks off. Not a general "skip
             "                   validation" switch and must not be used as one.
             flag          TYPE string,
             "            The Comoros / Rakhospitalid case. In the DPC this is the PRESENCE of
             "            the filter, not its value - a blank Rakhospitalid still skipped the
             "            check. Presence does not survive a flat structure, so the caller
             "            states the intent, which is clearer than it was.
             eid_check_off TYPE abap_bool,
             "            ZP28. BP_QUERY has an undiscoverable back door: paging SKIP and TOP
             "            both set to 999999999 make it inject TEMP_CASETYPE = 'ZP28', which is
             "            how that case type gets partners of type YP0001. Nothing names it and
             "            nothing else would ever set those numbers, so it is surfaced here
             "            rather than left as folklore. Leave it false unless you are ZP28.
             zp28          TYPE abap_bool,
*            ---- per-check switches -------------------------------------------
*            FLAG above is one field carrying three unrelated decisions, and that
*            is why it keeps being used as a general "skip validation" switch when
*            it is not one. 'X' only stops a MOI mismatch rejecting; 'T' only
*            turns off the two expiry checks. Nothing could ask for one without
*            the other, and no popup could state its intent in its own terms.
*
*            These say it directly, one switch per check. FLAG still works exactly
*            as it did - VALIDATE( ) ORs the two together - so every existing
*            caller is unaffected and a new caller never has to learn the codes.
*
*            MOI is still CALLED and the BP still updated from it; this only stops
*            a date-of-birth or nationality mismatch being an error. Equivalent to
*            FLAG = 'X'.
*            Sends CallMoi as null rather than X, and skips the DOB/nationality
*            mismatch check ZCL_RAK_BP_SEARCH~VALIDATE( ) would otherwise run for
*            CALL_MOI = X. It does NOT stop the underlying MOI call itself -
*            confirmed against BUSINESSPARTNERS_GET_ENTITYSET (the DPC this class
*            replaces): CallMoi is read there only AFTER ZCL_EGA_BP_BO_API->BP_QUERY( )
*            has already run, purely to decide whether a mismatch is an error, never
*            to decide whether BP_QUERY calls MOI. BP_QUERY's own trigger is
*            "IF lv_eid IS NOT INITIAL" - see the note at the top of this class -
*            so any Emirates ID search calls MOI regardless of CallMoi, and that is
*            ZCL_EGA_BP_BO_API's behaviour to change, not something reachable from
*            here.
*
*            Worth setting anyway: CJS should not ASK for a verification it does
*            not want, whatever BP_QUERY goes on to do with the EId on its own
*            account. ZCRM_MOI_CR_UPD_MASS writes, costs at least five seconds by
*            construction, and its WAIT UP TO ends the LUW and forces an implicit
*            COMMIT of whatever the caller had open - none of that is something
*            this flag can prevent, but the mismatch rejection is, and that is
*            what NO_MOI_CALL actually buys.
             no_moi_call       TYPE abap_bool,
             skip_moi_mismatch TYPE abap_bool,
*            Trade licence expiry, category 2. Half of FLAG = 'T'.
             skip_tl_expiry    TYPE abap_bool,
*            Emirates ID expiry, category 1. The other half of FLAG = 'T', and the
*            same thing EID_CHECK_OFF already said - both are honoured.
             skip_eid_expiry   TYPE abap_bool,
*            Severity for the validation findings. Blank or 'E' rejects, which is
*            what every caller gets today. 'W' reports the same texts as warnings
*            and lets the partner through - for a popup that wants to show an
*            expired licence rather than refuse to find it. Anything that lets a
*            partner through on a warning owns that decision.
             msg_type          TYPE string,
*            Cap the hit list. Zero means "as BP_QUERY returns it", which is the
*            behaviour every caller has today. Independent of ZP28, which sets
*            paging to a sentinel for a different reason entirely.
             max_rows          TYPE i,
           END OF ty_req.

*   ROWS is the ENTITY type, and that is a correction rather than a preference.
*
*   The BO API's own ZST_CT_EGA_BO_BP_ROOT looked like the tidier choice - a
*   business class with no OData type in it - and it is wrong. Every rule this
*   class carries was written in the DPC against the structure AFTER the
*   conversion "et_entityset = bp_query( )", and the two structures are not the
*   same shape: the BOPF root has TELEPHONE_NUMBER where the entity has a phone
*   field, has no NAME or SMTPADDR at all, and types EID as something a string
*   parameter will not take.
*
*   So validating against the root meant validating against components that are
*   only coincidentally the ones the rules were written for. The entity type keeps
*   DOB, NATIONALITY, CATEGORY, VALID_DATE_TO, EID, PARTNER and IDTYPE all proven
*   by the DPC source, which is the entire set the checks below touch.
*
*   The conversion happens once, in QUERY( ), exactly where the DPC did it.
*   A BOUND table type over the entity line type. The MPC's own TT_BUSINESSPARTNER
*   declares no key, which makes it GENERIC - usable for a formal parameter or a
*   field symbol and not for a structure component or a DATA. That is why the DPC
*   can take it as ET_ENTITYSET and this cannot hold it in TY_RES.
*
*   TS_BUSINESSPARTNER, the line type, is an ordinary bound structure, so declaring
*   the table here costs one line and keeps the proven component set.
    TYPES tt_bp TYPE STANDARD TABLE OF zcl_zega_bp_mpc_ext=>ts_businesspartner
                WITH EMPTY KEY.

    TYPES: BEGIN OF ty_res,
             rows TYPE tt_bp,
             msg  TYPE bapiret2_t,
           END OF ty_res.

*   it_extra_msg is the DPC's MT_RETURN, injected where it used to be appended so
*   message order does not change.
    METHODS search
      IMPORTING is_req        TYPE ty_req
                it_extra_msg  TYPE bapiret2_t OPTIONAL
      RETURNING VALUE(rs_res) TYPE ty_res.


*   784-1988-2718131-8 and 784198827181318 are the same Emirates ID. Anything
*   comparing two of them has to say so.
*
*   PUBLIC and a CLASS-METHOD because callers outside this class need it. The
*   popup and the engine both take an Emirates ID straight from a citizen, who
*   types it the way it is printed on the card - with hyphens - and every layer
*   below expects the digits. A caller should not have to instantiate a search to
*   tidy a string before making one.
    CLASS-METHODS norm_eid
      IMPORTING VALUE(iv_eid) TYPE string
      RETURNING VALUE(rv_id)  TYPE string.

*   Is this search an Emirates ID search? Only an Emirates ID may be stripped of
*   its hyphens.
*
*   TY_REQ-EID also carries passport and unified numbers - ZCL_RAK_BP_POPUP and
*   ZCL_RAK_NOT_APPROVAL_LOGIC both put them there, and both say in their own
*   comments that they are not certain it is right. A passport number may contain
*   a hyphen that BELONGS to it, so stripping one would search for a document
*   nobody holds. This is the guard that keeps the fix off those two.
*
*   A BLANK id type counts as Emirates ID. The field is called EID, a caller that
*   names no type has said nothing to the contrary, and the alternative - leaving
*   the hyphens on and dumping - is the bug being fixed.
    CLASS-METHODS is_eid_type
      IMPORTING VALUE(iv_idtype) TYPE string
      RETURNING VALUE(rv)        TYPE abap_bool.


  PROTECTED SECTION.

    METHODS query
      IMPORTING is_req  TYPE ty_req
      EXPORTING et_rows TYPE tt_bp
                et_msg  TYPE bapiret2_t.

    METHODS validate
      IMPORTING is_req  TYPE ty_req
                it_rows TYPE tt_bp
      CHANGING  ct_msg  TYPE bapiret2_t.

*   VALUE( ), not plain IMPORTING. A method's IMPORTING parameter is passed BY
*   REFERENCE by default, and by reference demands type COMPATIBILITY - so a DDIC
*   character field cannot be handed to a TYPE string parameter at all. VALUE( )
*   passes by value, which converts. Every one of these takes DDIC fields off the
*   BP row, so every one of them needs it.
    METHODS add
      IMPORTING VALUE(iv_text) TYPE string
                VALUE(iv_type) TYPE string DEFAULT 'E'
      CHANGING  ct_msg         TYPE bapiret2_t.

*   One filter row. A method and not a DEFINE: a macro splits its arguments on
*   whitespace, so the moment one of them was an expression - COND string( WHEN
*   ... ) - the macro tore it into pieces and the compiler reported a mangled
*   fragment on a line that looked correct. Macros cannot take expressions and
*   this class needs to pass one.
    METHODS add_flt
      IMPORTING VALUE(iv_prop) TYPE string
                VALUE(iv_val)  TYPE string
      CHANGING  ct_filter      TYPE /iwbep/t_mgw_select_option.

  PRIVATE SECTION.
    CONSTANTS c_moi_msg TYPE string VALUE 'Z_RAKEGA_MUNI/ZEGA_BP_V_MAIN_MOI_VAL_MSG'.
    CONSTANTS c_tenancy TYPE string VALUE 'T'.
    CONSTANTS c_zp28    TYPE i      VALUE 999999999.
ENDCLASS.



CLASS ZCL_RAK_BP_SEARCH IMPLEMENTATION.


  METHOD add.
*   Severity is the caller's now, defaulting to the 'E' every finding used to be.
    APPEND VALUE #( type    = COND #( WHEN iv_type IS INITIAL THEN 'E' ELSE iv_type )
                    message = iv_text ) TO ct_msg.
  ENDMETHOD.


  METHOD add_flt.
    IF iv_val IS INITIAL.
      RETURN.
    ENDIF.
    APPEND VALUE #( property       = iv_prop
                    select_options = VALUE #( ( sign = 'I' option = 'EQ' low = iv_val ) ) )
           TO ct_filter.
  ENDMETHOD.


  METHOD norm_eid.
*   KEEP THE DIGITS, DROP EVERYTHING ELSE.
*
*   Not REPLACE of the hyphen. An Emirates ID is fifteen digits and nothing else,
*   so the rule can be stated positively - and stated that way it also survives
*   the separators a citizen actually arrives with: spaces from a careful typist,
*   a slash, and the en-dash or em-dash that Word and most chat clients silently
*   auto-correct a typed hyphen into. Those last two look identical to a hyphen on
*   screen and would have walked straight past a REPLACE that named only ASCII 45.
*
*   Anything non-numeric is therefore discarded rather than rejected. This method
*   normalises; it does not validate. A caller that needs to know whether what is
*   left is a plausible Emirates ID can test STRLEN( ) on the result.
    CLEAR rv_id.
    DATA(lv_in) = iv_eid.

*   OFF is computed into a variable rather than written as SY-INDEX - 1 inline.
*   An arithmetic expression in an actual parameter is legal from 7.40, but this
*   class is called from the legacy path as well and a plain variable costs
*   nothing and cannot be the reason an activation fails on an older stack.
    DATA lv_off TYPE i.
    DATA lv_ch  TYPE string.

    DO strlen( lv_in ) TIMES.
      lv_off = sy-index - 1.
      lv_ch  = substring( val = lv_in off = lv_off len = 1 ).
      IF lv_ch CO '0123456789'.
        rv_id = rv_id && lv_ch.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD is_eid_type.
    DATA(lv) = to_upper( condense( iv_idtype ) ).
    rv = xsdbool(    lv IS INITIAL
                  OR lv = 'YFS002'
                  OR lv = 'EID'
                  OR lv = 'EMIRATESID'
                  OR lv = 'EMIRATES_ID' ).
  ENDMETHOD.



  METHOD query.
*   Every BP_QUERY parameter is MANDATORY - there is no OPTIONAL on any of the
*   eight - so all eight are passed. The empty locals are the pattern the BO API
*   uses on itself: CHECK_ID_VALIDITY declares exactly these and passes them to
*   GET_BP_ID the same way.
    DATA lt_filter TYPE /iwbep/t_mgw_select_option.
    DATA lt_order  TYPE /iwbep/t_mgw_sorting_order.
    DATA ls_paging TYPE /iwbep/s_mgw_paging.
    DATA lt_nav    TYPE /iwbep/t_mgw_navigation_path.
    DATA lt_key    TYPE /iwbep/t_mgw_name_value_pair.
    DATA lv_fstr   TYPE string.
    DATA lt_ret    TYPE bapiret2_t.

*   BP_QUERY returns the BOPF root; ROWS is the entity table. The assignment
*   between them is the same one the DPC has always made, and it stays in one place
*   so nothing downstream has to know two shapes.
    DATA lt_root   TYPE zst_ct_ega_bo_bp_root.

*   VERIFIED, not assumed: BP_QUERY never dereferences IO_TECH_REQUEST_CONTEXT.
*   It loops the filters, tests IS_PAGING, reads the EId, calls the MOI function
*   module and runs the BOPF query. The reference is declared and never touched,
*   so an initial one is safe and this is callable from outside Gateway at all.
    DATA lo_ctx TYPE REF TO /iwbep/if_mgw_req_entityset.

*   The property names have to be the OData ones EXACTLY - 'EId' and not 'EID'.
*   BP_QUERY MOVE-CORRESPONDINGs each SELECT_OPTIONS row onto a BOPF selection
*   parameter and takes ATTRIBUTE_NAME straight from PROPERTY, then looks its own
*   EId back up under that spelling.
*   HYPHENS COME OFF HERE, and this is the fix for the dump.
*
*   A citizen types the Emirates ID the way it is printed on the card,
*   784-1987-8624392-7, because the form asked for an Emirates ID and that is what
*   one looks like. Everything below this line wants the fifteen digits: the value
*   goes into the BOPF selection parameter as typed, and the MOI call behind
*   BP_QUERY takes it into a numeric field. A hyphen there is not a search that
*   finds nothing - it is a short dump, in front of the citizen, on a screen that
*   had accepted the input without complaint.
*
*   Normalising here rather than in the popup covers every caller at once,
*   including the two that build a TY_REQ by hand. Both formats now work and
*   neither is preferred, which is the whole request: nobody should have to know
*   which one this expects.
*
*   Guarded by IS_EID_TYPE. TY_REQ-EID also carries passport and unified numbers,
*   whose hyphens may be part of the number - see the note on that method.
    DATA(lv_eid_flt) = COND string( WHEN is_eid_type( is_req-idtype ) = abap_true
                                    THEN norm_eid( is_req-eid )
                                    ELSE is_req-eid ).
    add_flt( EXPORTING iv_prop   = 'EId'
                       iv_val    = lv_eid_flt
             CHANGING  ct_filter = lt_filter ).

    add_flt( EXPORTING iv_prop   = 'TradeLicense'
                       iv_val    = is_req-trade_licence
             CHANGING  ct_filter = lt_filter ).
    add_flt( EXPORTING iv_prop   = 'Partner'
                       iv_val    = is_req-partner
             CHANGING  ct_filter = lt_filter ).
    add_flt( EXPORTING iv_prop   = 'Idtype'
                       iv_val    = is_req-idtype
             CHANGING  ct_filter = lt_filter ).
    add_flt( EXPORTING iv_prop   = 'DateOfBirth'
                       iv_val    = is_req-dob
             CHANGING  ct_filter = lt_filter ).
    add_flt( EXPORTING iv_prop   = 'Documentnationality'
                       iv_val    = is_req-nationality
             CHANGING  ct_filter = lt_filter ).
    add_flt( EXPORTING iv_prop   = 'Flag'
                       iv_val    = is_req-flag
             CHANGING  ct_filter = lt_filter ).

*   NO_MOI_CALL wins over CALL_MOI. One says "call it", the other "never call it",
*   and a caller that sets both meant the second - suppressing a write is not a
*   thing to get wrong by precedence.
    DATA(lv_moi) = COND string( WHEN is_req-call_moi = abap_true
                                 AND is_req-no_moi_call = abap_false THEN 'X' ELSE '' ).
    add_flt( EXPORTING iv_prop   = 'CallMoi'
                       iv_val    = lv_moi
             CHANGING  ct_filter = lt_filter ).

*   The ZP28 back door, said out loud. See the note on ty_req-zp28.
    IF is_req-zp28 = abap_true.
      ls_paging-skip = c_zp28.
      ls_paging-top  = c_zp28.
    ENDIF.

*   A STATEMENT, not an expression. A functional call used on the right of an
*   assignment takes input parameters only - it cannot carry IMPORTING, which is
*   why "et_rows = ...->bp_query( ... IMPORTING ... )" would not parse. With a
*   returning value AND an exporting one, the standalone form with RECEIVING is
*   the only shape that says both.
    DATA(lo_api) = NEW zcl_ega_bp_bo_api( ).
    lo_api->bp_query(
      EXPORTING
        it_filter_select_options = lt_filter
        it_order                 = lt_order
        is_paging                = ls_paging
        it_navigation_path       = lt_nav
        it_key_tab               = lt_key
        iv_filter_string         = lv_fstr
        iv_search_string         = is_req-search_term
        io_tech_request_context  = lo_ctx
      IMPORTING
        et_return                = lt_ret
      RECEIVING
        rt_data                  = lt_root ).

    et_rows = lt_root.

*   MAX_ROWS is applied AFTER the call and not as paging. BP_QUERY's IS_PAGING is
*   already spoken for by the ZP28 sentinel, and a TOP that clashed with it would
*   silently switch that back door off. Trimming the answer cannot interfere with
*   either, and zero leaves the set exactly as BP_QUERY returned it.
    IF is_req-max_rows > 0 AND lines( et_rows ) > is_req-max_rows.
      DELETE et_rows FROM is_req-max_rows + 1.
    ENDIF.

    et_msg  = lt_ret.
  ENDMETHOD.


  METHOD search.
    query( EXPORTING is_req  = is_req
           IMPORTING et_rows = rs_res-rows
                     et_msg  = rs_res-msg ).

    IF rs_res-rows IS INITIAL.
      add( EXPORTING iv_text = COND #( WHEN sy-langu = 'E' THEN 'No data found'
                                       ELSE 'لم يتم العثور على بيانات' )
           CHANGING  ct_msg  = rs_res-msg ).
    ENDIF.

    IF it_extra_msg IS NOT INITIAL.
      APPEND LINES OF it_extra_msg TO rs_res-msg.
    ENDIF.

    validate( EXPORTING is_req  = is_req
                        it_rows = rs_res-rows
              CHANGING  ct_msg  = rs_res-msg ).

*   No CREATE_PARTNER here. It is a method of the DPC, it stays a method of the
*   DPC, and the DPC still runs it on the same condition it always did - when
*   there are no messages. A search class that writes a business partner would be
*   a worse thing than the duplication this class exists to remove.
  ENDMETHOD.


  METHOD validate.
*   Same three checks, same order, same skip conditions, same texts as the DPC
*   had. This is the only copy now - read it against the original once before
*   trusting it, and after that trust it.
    READ TABLE it_rows INTO DATA(ls_bp) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
 .
*   ---- effective switches ---------------------------------------------
*   FLAG and the explicit booleans are ORed, never one instead of the other. An
*   existing caller passes FLAG and gets exactly what it always got; a new one
*   names the check it means and never has to learn 'X' from 'T'.
    DATA(lv_skip_moi) = xsdbool( is_req-skip_moi_mismatch = abap_true
                              OR is_req-flag IS NOT INITIAL ).
    DATA(lv_skip_tl)  = xsdbool( is_req-skip_tl_expiry = abap_true
                              OR is_req-flag = c_tenancy ).
    DATA(lv_skip_eid) = xsdbool( is_req-skip_eid_expiry = abap_true
                              OR is_req-eid_check_off = abap_true
                              OR is_req-flag = c_tenancy ).
*   Applies to the findings below and NOT to the "No data found" in SEARCH( ) -
*   that one is not a validation verdict, it is the absence of a row.
    DATA(lv_sev)      = COND string( WHEN is_req-msg_type IS INITIAL THEN 'E'
                                     ELSE to_upper( is_req-msg_type ) ).

*   ---- MOI cross-check ------------------------------------------------
*   MOI call with no flag set. Two separate appends on purpose: a row wrong on
*   both date of birth and nationality says so twice, as it always did.
    IF is_req-call_moi = abap_true AND is_req-no_moi_call = abap_false
       AND lv_skip_moi = abap_false.
      DATA(lv_moi) = CONV string( cl_hrtmc_dr_utilities=>get_otr_text_by_alias( iv_alias = c_moi_msg ) ).
      IF ls_bp-dob <> is_req-dob.
        add( EXPORTING iv_text = lv_moi iv_type = lv_sev CHANGING ct_msg = ct_msg ).
      ENDIF.
      IF ls_bp-nationality <> is_req-nationality.
        add( EXPORTING iv_text = lv_moi iv_type = lv_sev CHANGING ct_msg = ct_msg ).
      ENDIF.
    ENDIF.

*   ---- trade licence expiry, category 2 -------------------------------
*   Tenancy skips it. The original read row 1 a second time here WITHOUT testing
*   sy-subrc, so on an empty set it used whatever the previous READ had left in
*   the work area. Harmless - an initial category matches neither '1' nor '2' -
*   but guarded above now rather than relied upon.
    IF ls_bp-category = '2' AND ls_bp-valid_date_to < sy-datum
       AND lv_skip_tl = abap_false.
      add( EXPORTING iv_text = COND #( WHEN sy-langu = 'E' THEN 'Trade License is expired'
                                       ELSE 'الرخصة التجارية منتهية الصلاحية' )
           iv_type = lv_sev
           CHANGING  ct_msg  = ct_msg ).
    ENDIF.

*   ---- Emirates ID expiry, category 1 ---------------------------------
*   Guarded on "the row that came back is the row that was asked for". That guard
*   replaced an IDTYPE = 'YFS002' test which could never be true again once
*   BP_QUERY began updating the BP from MOI data and returning YFS001 on every
*   row - comparing the EID asked for against the EID returned depends on no type
*   code at all.
*
*   BOTH SIDES ARE NORMALISED, AND THAT IS A FIX. The original stripped dashes
*   from the returned value only and compared it against the filter as typed.
*   Live callers send both formats:
*
*     ?$filter=(EId eq '784-1988-2718131-8')     dashed
*     ?$filter=EId eq '784197928658638'          plain
*
*   On the dashed one the guard could never be true - '784-1988-2718131-8' against
*   '784198827181318' - so the expired-Emirates-ID check silently did not run.
*   Whether an expired ID was rejected depended on whether the caller happened to
*   type dashes, which is not a rule anybody wrote down.
*
*   Expect this to reject cases that were being let through. That is the point,
*   and it will be reported as a regression by whoever meets it first.
*   CONV on the way in. The parameter is already by value, so a character field
*   converts - but stating it here means a change to the entity's EID type shows up
*   as a conversion that fails at this line rather than as a signature mismatch
*   somewhere else.
    DATA(lv_eid) = norm_eid( CONV string( ls_bp-eid ) ).
    DATA(lv_ask) = norm_eid( is_req-eid ).

    IF lv_ask = lv_eid
       AND ls_bp-category = '1' AND ls_bp-valid_date_to < sy-datum
       AND lv_skip_eid = abap_false.
      add( EXPORTING iv_text = COND #( WHEN sy-langu = 'E' THEN 'Emirates ID is expired'
                                       ELSE 'هوية الإمارات منتهية الصلاحية' )
           iv_type = lv_sev
           CHANGING  ct_msg  = ct_msg ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
