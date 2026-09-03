CLASS zcl_m011_divide_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_mun_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M011 - Request for Plots Division (legacy NSUBDIVISION_1_1..1_4).
*&
*& DELIBERATELY EMPTY, AND THAT IS THE POINT. Everything M011 needs is in
*& ZCL_RAK_MUN_LOGIC: the PAID gate chained to super, the payment card left
*& untouched, the two fee-bearing strip exceptions, and the "pick a parcel"
*& check. The domain rules - one location hierarchy, no open container, an
*& owner role on every parcel, no grant role, nothing under construction -
*& all run in ZCL_EGA_CJ_FW_RO_ABS_V1->VALIDATE( ) on the post, and are not
*& duplicated here on purpose. See that class's header for why.
*&
*& It exists as a NAMED handler rather than pointing HANDLER_CLASS straight
*& at the base for two reasons. It is the family convention - E028, E029,
*& D001 and the rest each have their own - and it is where a journey-specific
*& rule goes when one appears, without touching a class the other two
*& Municipality journeys also run.
*&
*& NO EMPTY REDEFINITIONS. An empty subclass is harmless; an empty
*& REDEFINITION is a deletion, and four of the base's hooks do real work.
*& Nothing is redefined here, so nothing is removed. If a redefinition is
*& ever added, ON_CUSTOM_VALIDATE must chain
*&
*&     rt = super->zif_rak_journey_logic~on_custom_validate( ... )
*&
*& before any CHECK, or the PAID gate goes and M011 becomes submittable
*& unpaid - which is exactly what happened to E128, twice.
*&
*& WHAT M011 IS: one parcel in, a division request out. Single selector, no
*& added-parcel grid, no usage-type change. That is the whole difference from
*& M012 and M016, and all three of those differences are configuration.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   ---- M011's own field vocabulary -----------------------------------
*   EVERY NAME IS THE LEGACY /QNV/SB_UI_DEFIN FIELD_NAME, because that is
*   what the backend's field control is keyed on end to end - see the long
*   note on the constants in ZCL_RAK_MUN_LOGIC. Renaming any of these
*   silently switches off MANDATORY / ENABLED / VISIBLE from the live
*   field-control engine.
*
*   Here rather than in the base because they are M011's screen, and an
*   enhancement to this journey should not have to re-read the export to
*   find out what a field is called.
*   ONLY WHAT THE BASE DOES NOT ALREADY HAVE. C_FLD_TERMS and
*   C_FLD_DONATE were declared here too and are inherited from
*   ZCL_RAK_MUN_LOGIC - an inherited attribute cannot be redeclared, and
*   the Class Builder says so plainly: "There is already an attribute
*   called C_FLD_DONATE". They moved to the base when the Pay press
*   started checking the terms, and this copy should have gone with them.
*
*   The same applies to C_FLD_PARCEL, C_FLD_PARCELS, C_FLD_NOTE,
*   C_FLD_NOC, C_FLD_LETTER and now C_FLD_TOTAL - all inherited, none
*   redeclared here. C_FLD_TOTAL moved up when the Pay press started
*   writing TOTALFEESVALUE into the post; all three journeys name that
*   field identically, so one declaration serves them.
    CONSTANTS c_fld_upload3 TYPE string VALUE 'UPLOADER3'.   " optional, DATA2=3

*   ---- what the backend decides, and where -----------------------------
*   Written down so an enhancement does not re-implement it by accident.
*   ZCL_EGA_CJ_FW_RO_ABS_V1 does all of this on the legacy side:
*
*     FIELD_CONTROL( )     hides C_FLD_NOC unless the parcel is mortgaged,
*                          and C_FLD_LETTER unless it has 2+ TR0800 owners.
*                          Arrives through the bridge as VISIBLE and is
*                          applied by APPLY_CTRL( ) - nothing to do here.
*     VALIDATE( )          the nine domain rules. Messages come back on the
*                          post through ET_MSG and surface as engine
*                          messages. Do not duplicate them.
*     UPDATE( )            creates the ZGCX container case when the fees
*                          step posts with TOTALFEESVALUE present, and
*                          writes the case id to characteristic CJ12.
*     GET_FEES( )          calls ZCL_EGA_MUN_CJ_FEES_M011->GET_INITIAL_FEE.
*
*   So the room for a journey-specific rule here is: anything that needs no
*   table read and improves the round trip before a post. M012's parcel
*   count is the family's one example. M011 has none today.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m011_divide_logic IMPLEMENTATION.
ENDCLASS.
