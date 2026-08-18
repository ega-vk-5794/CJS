CLASS zcl_e027_vice_captain_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

*   Handler for E027 - Sailing of a Vice Captain
*   (legacy NE027_1_*, seeded by ZRAK_E027_LOAD).
*
*   NO PAYMENT. There is no RAKPAY, no RAKREMAININGFEES and no fee CLIST
*   anywhere in the real export, and the last screen's NEXT button carries
*   D3 = SUBMIT rather than a pay event - confirmed, not assumed. So unlike
*   E014 / E015 / E146 this class redefines no on_init and wires no
*   PAY_SCREEN, PAY_METHOD or PAY_BUKRS. If a fee is introduced later, this
*   is where that goes, and STP4 needs NEXT_REQUIRES = 'PAYFEE' in the
*   feeder at the same time.
*
*   ---------------------------------------------------------------------
*   THIS CLASS USED TO SHOW THE OWNER LOOKUP BACKWARDS - the identical
*   inversion ZCL_E015_ENV_STUDY_LOGIC carried, from the identical shared
*   legacy block. Worth recording, because it fails silently.
*
*   It had its own show/hide code, in on_after_read and on_change, that
*   revealed the OWNER_1 lookup when the applicant type was
*   PARTNER_OWNER_1 and hid it otherwise. The legacy UI_FIELD_LOGICS on
*   NE027_1_2 says the opposite, unambiguously:
*       PARTNER_OWNER_1  ->  OWNER_FINDER-V-F   (Owner  -> HIDE)
*       PARTNER_REP_1    ->  OWNER_FINDER-V-T   (Rep    -> SHOW)
*   which is counter-intuitive but correct, and doubly so here: on this
*   journey OWNER_1 is bound to GS_DATA-REPRESENT_ID, so despite the
*   container being called OWNER_FINDER and the caption reading "Owner
*   details", the field identifies the REPRESENTATIVE - which is exactly
*   why it appears only when a representative applies. The old code asked
*   the owner to identify a representative, and hid the field in the one
*   case there was one.
*
*   The visibility now lives in ZRAK_T_JNY_RULE as rule R001 (SHOW OWNER_1
*   when PARTNER_OWNER_1 = PARTNER_REP_1), with the field authored HIDDEN
*   in the feeder - the same convention E014 and E015 use. The engine
*   evaluates rules on read AND on change, so the on_after_read
*   redefinition this class used to need is gone.
*
*   DO NOT reintroduce set_hidden( ) on OWNER_1 here. It OUTRANKS the
*   rules for the rest of the session, so it would not add to R001 - it
*   would silently take the decision away from it, which is how the
*   inversion survived in the first place.
*   ---------------------------------------------------------------------
*
*   THREE separate business-partner lookups on this journey, confirmed from
*   PARENT_CONTAINER and from three DIFFERENT backend bindings rather than
*   assumed to be one reused control:
*     STP1  OWNER_ID_1  GS_DATA-OWNER_ID          standalone in VBOX_5
*                       - the boat owner.
*     STP2  OWNER_1     GS_DATA-REPRESENT_ID      inside OWNER_FINDER
*                       - the representative applying on the owner's
*                         behalf; governed by R001, see above.
*     STP3  OWNER_ID_2  GS_DATA-CAPTAIN-OWNER_ID  inside CAPTAIN_FINDER
*                       - the vice-captain nominee. Its container has no
*                         other live child, so nothing shows or hides
*                         around it and no rule governs it.
*   REVIEW-BE: none of the three has on_search wired - each renders
*   correctly (SEARCH is a recognised ftype) but a press returns nothing
*   until a search API is confirmed and one on_search here branches on
*   iv_field. LICENCE_NO_1 on STP1 is a fourth inert lookup, legacy search
*   kind 'BOAT_LICENSE'. Same open item as E014's OWNER_FINDER_BP and
*   E015's three - one API, one place to fix it.
*
*   REVIEW-F4: TYPE_1 on STP1 is a COMBOBOX with NO search help, no CLIST
*   and no value list anywhere in the export - the legacy screen filled its
*   options from ZCL_EGA_CJ_ENH_IMPL_E027 at runtime. It renders EMPTY
*   today. The fix is either a SHLP in the feeder or an on_value_help
*   redefinition here; both need the real option keys first, which is also
*   what unblocks the LICENSE_TABLE / LICENSE_SEARCH visibility rule the
*   feeder could not author.
  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS c_applicant_type TYPE string VALUE 'PARTNER_OWNER_1' ##NO_TEXT.

*   One segmented field on screen, TWO booleans in the backend - the same
*   two-way group E015 has, not E014's three-way. The legacy screen had two
*   separate TBUTTONs, each bound to its own GS_DATA-PARTNER_* flag, and a
*   segmented field carries ONE value, so the chosen option has to be
*   fanned back out or the backend receives nothing for the applicant's
*   role.
    METHODS write_role_flags
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_pick TYPE string.
ENDCLASS.



CLASS ZCL_E027_VICE_CAPTAIN_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_change.
    IF to_upper( iv_field ) = c_applicant_type.
      write_role_flags( io_ctx = io_ctx iv_pick = io_ctx->get_val( c_applicant_type ) ).
    ENDIF.
  ENDMETHOD.


  METHOD write_role_flags.
*   Both flags written on every change, not just the chosen one - the
*   citizen who picks Representative after picking Owner must leave
*   GS_DATA-PARTNER_OWNER blank behind them, or the backend sees an
*   applicant who is both.
    DATA(lt_role) = VALUE zif_rak_journey=>tt_kv(
      ( key = `PARTNER_OWNER_1` value = `GS_DATA-PARTNER_OWNER` )
      ( key = `PARTNER_REP_1`   value = `GS_DATA-PARTNER_REP` ) ).

    LOOP AT lt_role INTO DATA(ls_role).
      io_ctx->set_val( iv_name  = ls_role-value
                       iv_value = COND string( WHEN ls_role-key = iv_pick THEN 'X' ELSE '' ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
