CLASS zcl_m016_cbr_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M016 - Change Building Regulations (legacy NCBR_1_1..1_4).
*&
*& THIN, LIKE M011, AND FOR THE SAME REASON: everything it needs is in
*& ZCL_RAK_MUN_LOGIC. The two things that make M016 look different from its
*& siblings are both configuration, not code:
*&
*&   RAKSELECTUSAGETYPE on NCBR_1_2 - the new usage type the citizen is
*&       asking for. A closed list, so it is a SELECT field with its options
*&       in ZRAK_T_JNY_OPT. See the REVIEW-F4 note in ZRAK_M016_LOAD: the
*&       legacy control carries no SH_NAME and its domain is not in the
*&       export, so the options are seeded from the requirement document and
*&       need confirming against the live service.
*&
*&   The PROPERTY AGENT path - the four "Property Agent" screenshots in the
*&       requirement document. That is not an M016 feature: it is the
*&       family's tasheel flow, and it is already handled upstream. When the
*&       launch supplies a BP value longer than ten characters,
*&       ZCL_EGA_CJ_FW_RO_ABS_V1->MAPPER( ) reads it as a tasheel
*&       transaction id, resolves ZEGA_T_CJ_BP_REL to the pair
*&       (main_partner = TR0800 owner, login_partner = TR0640 applicant) and
*&       writes the id to characteristic CJ10. Nothing in CJS decides any of
*&       that, and re-deciding it here would be a second opinion on which
*&       partner owns the case.
*&
*& NO EMPTY REDEFINITIONS - see ZCL_M011_DIVIDE_LOGIC. If one is ever added,
*& ON_CUSTOM_VALIDATE must chain super before any CHECK or the PAID gate is
*& gone.
*&
*& REVIEW-BE: the requirement document's title is "Building Regulations /
*& Change of Land Use", and those are two services. The M-code on the NCBR
*& screens resolves to CBR alone; change of land use is M015, which is not
*& in this scope and has no feeder. Flagged rather than merged - one CJS
*& journey has one BKND_JOURNEY, so merging them is a decision for the
*& owning team.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- M016's own field vocabulary -----------------------------------
*   EVERY NAME IS THE LEGACY /QNV/SB_UI_DEFIN FIELD_NAME - the backend's
*   field control is keyed on it end to end, so renaming one silently
*   switches off MANDATORY / ENABLED / VISIBLE from the live field-control
*   engine. See the constants note in ZCL_RAK_MUN_LOGIC.
*
*   RAKSELECTUSAGETYPE, not USAGETYPE: on NCBR_1_2 the FIELD_NAME and the
*   CONTROL_TYPE happen to be the same string, and the FIELD_NAME is what is
*   keyed on. An earlier version of this constant said USAGETYPE and would
*   have received no field control at all.
    CONSTANTS c_fld_usage   TYPE string VALUE 'RAKSELECTUSAGETYPE'.

*   M016 has FOUR uploaders where M011 has three. C_FLD_UPLOAD carries no
*   DATA2 at all, where the numbered three carry 1, 2 and 3 - so it is not
*   one of the numbered document types.
*   ONLY WHAT THE BASE DOES NOT ALREADY HAVE. C_FLD_TERMS and
*   C_FLD_DONATE were declared here too and are inherited from
*   ZCL_RAK_MUN_LOGIC - an inherited attribute cannot be redeclared, and
*   the Class Builder says so plainly: "There is already an attribute
*   called C_FLD_DONATE". They moved to the base when the Pay press
*   started checking the terms, and this copy should have gone with them.
*
*   The same applies to C_FLD_PARCEL, C_FLD_PARCELS, C_FLD_NOTE,
*   C_FLD_NOC and C_FLD_LETTER - all inherited, none redeclared here.
    CONSTANTS c_fld_upload  TYPE string VALUE 'UPLOADER'.     " optional, no DATA2
    CONSTANTS c_fld_upload3 TYPE string VALUE 'UPLOADER3'.    " optional, DATA2=3
    CONSTANTS c_fld_total   TYPE string VALUE 'TOTALVALUE'.   " tech TOTALFEESVALUE

*   ---- what the backend decides, and where -----------------------------
*   Same contract as M011's - FIELD_CONTROL( ) owns the NOC and LETTER
*   visibility, VALIDATE( ) owns the nine domain rules and returns their
*   messages on the post, UPDATE( ) creates the ZGCX case when the fees step
*   posts with TOTALFEESVALUE, and GET_FEES( ) calls
*   ZCL_EGA_MUN_CJ_FEES_M016->GET_INITIAL_FEE. None of it is duplicated
*   here.
*
*   THE ONE PLACE AN M016 ENHANCEMENT IS LIKELY TO BE NEEDED is the usage
*   type. It is REQUIRED and its option list is deliberately empty, because
*   nothing in the export names the list - see the REVIEW-F4 block in
*   ZRAK_M016_LOAD. If the list turns out to be dynamic (dependent on the
*   parcel's current usage type, which would be the natural design), that is
*   an ON_CHANGE redefinition here reading the parcel and calling
*   SET_OPTIONS( ) - and it must not become a hardcoded list, which is the
*   failure mode the empty list exists to prevent.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m016_cbr_logic IMPLEMENTATION.
ENDCLASS.
