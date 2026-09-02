CLASS zcl_rak_cj_ctx DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& Who the citizen is, in the shape the wrapper APIs filter on.
*&
*& ZCL_RAK_CJ_API's rule is that identity travels in MS_CTX and goes out
*& as FILTERS, never inferred by the DPC from a portal session CJS does
*& not have. This class is the one place that rule is satisfied: it reads
*& what the engine already knows about the launch and hands back a
*& TY_CTX. Nothing else should assemble one field by field.
*&
*& THE PARTNER GUID IS DERIVED, NOT CARRIED. The engine has never needed
*& one - it works in partner NUMBERS (MV_LOGINBP, and BP_OF( ) converts a
*& guid down to a number when a launch URL supplies one). Every property
*& and tenancy read on CUSTOMERJOURNEY filters on Partnerguid and returns
*& an empty table without one, silently. So GUID_OF( ) does the inverse
*& lookup on BUT000, once, and a journey launched with &partnerguid= is
*& believed ahead of it.
*&
*& THE SESSION KEY TRAVELS TOO. MS_CTX-USERDATA carries the launch URL's
*& &userdata=, which is the value the portal puts in the 'x-custom1' header.
*& ZCL_RAK_CJ_REQ_CTX puts it back there, so GET_BP( ) inside the DPC
*& resolves the real caller. Filters remain the primary identity - this
*& reaches the paths a filter cannot, the ones that consume the partner
*& GET_BP( ) resolves rather than one the caller supplied.
*&
*& DEPARTMENT IS NOT ON THE JOURNEY. ZRAK_T_JNY carries a backend CATEGORY
*& (MML, TEN, GRANTS...) which is not the portal department FeesSet filters
*& on - that is a ZEGA_T_CJ_GRP-DEPARTMENT, supplied at launch. It is read
*& from the launch parameters and left blank when absent rather than
*& guessed from the category, because a wrong department filters fees to
*& nothing and looks exactly like a case with no fees.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    CLASS-METHODS build
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rs) TYPE zcl_rak_cj_api=>ty_ctx.

*   Partner number -> partner guid, uppercase and undashed, as the DPC
*   compares it. Blank when the partner is unknown or has no BUT000 row -
*   the caller's own guard reports that, this does not.
    CLASS-METHODS guid_of
      IMPORTING iv_partner TYPE string
      RETURNING VALUE(rv)  TYPE string.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_rak_cj_ctx IMPLEMENTATION.


  METHOD guid_of.
    DATA lv_bp TYPE bu_partner.

    IF iv_partner IS INITIAL.
      RETURN.
    ENDIF.

*   ALPHA = IN: the launch parameter carries the number as a citizen sees
*   it, BUT000 holds it zero-padded, and comparing the two unpadded finds
*   nothing while looking like "this partner has no properties".
    lv_bp = |{ condense( iv_partner ) ALPHA = IN }|.

    SELECT SINGLE partner_guid FROM but000
      WHERE partner = @lv_bp
      INTO @DATA(lv_guid).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv = lv_guid.
    TRANSLATE rv TO UPPER CASE.
  ENDMETHOD.


  METHOD build.
    DATA(ls_cfg) = io_ctx->get_config( ).

    rs-partner = io_ctx->get_param( 'LOGINBP' ).
    rs-role    = io_ctx->get_param( 'ROLE' ).

*   THE PORTAL SESSION KEY, and the reason this class exists at all now.
*   It arrives on the launch URL as &userdata= and the engine already keeps
*   it in MV_USERDATA - ZCL_RAK_JOURNEY_ENGINE resolves the login BP with
*   exactly this value, ZCL_EGA_CJ_UTILITY=>GET_BP( qv_key = mv_userdata ).
*   The same value is what the portal sends the DPC as the 'x-custom1'
*   header, so handing it to ZCL_RAK_CJ_REQ_CTX is not impersonation: it is
*   the citizen's own session, in the form the DPC already expects.
    rs-userdata = io_ctx->get_param( 'USERDATA' ).

*   A guid supplied at launch wins - it is what the portal actually
*   authenticated, and re-deriving it would only be able to agree.
    rs-partnerguid = io_ctx->get_param( 'PARTNERGUID' ).
    IF rs-partnerguid IS INITIAL.
      rs-partnerguid = guid_of( rs-partner ).
    ELSE.
      TRANSLATE rs-partnerguid TO UPPER CASE.
      REPLACE ALL OCCURRENCES OF '-' IN rs-partnerguid WITH ''.
    ENDIF.

*   INTRENO is the property this journey is about, once one has been
*   chosen. Early in a journey there is none, and that is not an error -
*   it is exactly the state a parcel selector exists to end.
    rs-intreno = io_ctx->get_param( 'INTRENO' ).

*   The BACKEND journey code (M011, D001...), not ZRAK_T_JNY-JOURNEY_ID.
*   The DPC's JourneyId/JourneyCode filters are the legacy codes, and a
*   CJS journey id prefixed MIG_ would match nothing.
    rs-journey = ls_cfg-backend-journey.

    rs-screen     = VALUE #( ls_cfg-steps[ io_ctx->get_step( ) + 1 ]-bknd_screen OPTIONAL ).
    rs-department = io_ctx->get_param( 'DEPARTMENT' ).
    rs-langu      = sy-langu.
  ENDMETHOD.


ENDCLASS.
