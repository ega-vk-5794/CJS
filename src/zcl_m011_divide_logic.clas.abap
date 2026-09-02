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
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_m011_divide_logic IMPLEMENTATION.
ENDCLASS.
