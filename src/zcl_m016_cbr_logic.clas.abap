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

*   The requested usage type. Here rather than in the base because M016 is
*   the only journey in the family that asks for one.
    CONSTANTS c_fld_usage TYPE string VALUE 'USAGETYPE'.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m016_cbr_logic IMPLEMENTATION.
ENDCLASS.
