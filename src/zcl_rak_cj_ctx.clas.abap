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
*& THE SESSION KEY TRAVELS TOO, AND IT IS NOT &userdata= VERBATIM.
*&
*& The launch URL's &userdata= is a JSON envelope. ZCL_EGA_CJ_UTILITY=>
*& GET_BP( ) - the one the engine already uses - deserializes it into
*& { ebp, rolebp, rolename } and then matches ZEGA_T_CJ_US_LOG on EBP.
*&
*& The DPC's OWN GET_BP( ), on ZCL_ZEGA_CJ_UTILITY_DPC_EXT, does no such
*& thing: it takes the 'x-custom1' header value AS the key -
*& WHERE user_key EQ @l_key - with no unwrapping at all.
*&
*& Two classes, the same method name, different input formats. Passing the
*& envelope where the raw key belongs matches no row and resolves nobody,
*& and nothing anywhere says so. SESSION_KEY_OF( ) unwraps it, and falls
*& back to the value as given when it is not JSON - so a launch that ever
*& carries the bare key still works.
*&
*& AND ON E10 CLIENT 200 ONLY, THERE IS A SIMULATED IDENTITY.
*&
*& A journey launched from the CJS Studio or straight from SE38 carries no
*& &userdata= at all, so every property, fee and tenancy read answers an
*& empty table - not because the layer is wrong but because nobody is
*& logged in. Testing that through the portal means a portal launch for
*& every round trip, which is not how this is being developed.
*&
*& SIMULATE( ) therefore fills a MISSING session key from
*& ZEGA_T_CJ_US_LOG, exactly as a portal login would have left it: the
*& active row for C_SIM_USER, or for whatever &simuser= names. It reads
*& that table and never writes it - the rule is to mimic the portal, not
*& to create rows it would have created.
*&
*& IT IS FENCED, TIGHTLY. SY-SYSID must be E10 and SY-MANDT 200; anywhere
*& else the method returns having done nothing, so a transport into QA or
*& production cannot resolve an identity nobody authenticated. It also
*& only ever fills what is BLANK - a real launch always wins.
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

*   The launch URL's &userdata= JSON -> the ZEGA_T_CJ_US_LOG-USER_KEY inside
*   it. Returns the input unchanged when it is not JSON, and blank for
*   blank. See the class header for why the two GET_BP( )s disagree.
    CLASS-METHODS session_key_of
      IMPORTING iv_userdata TYPE string
      RETURNING VALUE(rv)   TYPE string.

  PRIVATE SECTION.

*   The one system and client the simulation is allowed in. Both are
*   checked; E10 alone is not enough, because 200 is the CJS development
*   client and the others are not.
    CONSTANTS c_sim_sysid TYPE sy-sysid VALUE 'E10'.
    CONSTANTS c_sim_mandt TYPE sy-mandt VALUE '200'.

*   The internet user whose portal session is borrowed. HISHAM.M resolves
*   to partner 3000401630 on E10 and owns the parcels every property read
*   is tested against. Override per launch with &simuser=.
    CONSTANTS c_sim_user  TYPE zega_t_cj_us_log-id VALUE 'HISHAM.M'.

*   Fill a missing identity from ZEGA_T_CJ_US_LOG. E10/200 only, read
*   only, and only what the launch left blank.
    CLASS-METHODS simulate
      IMPORTING io_ctx TYPE REF TO zif_rak_journey
      CHANGING  cs     TYPE zcl_rak_cj_api=>ty_ctx.

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


  METHOD session_key_of.
*   The same three members ZCL_EGA_CJ_UTILITY=>GET_BP( ) deserializes into.
*   Named exactly as it names them, because /UI2/CL_JSON matches on the
*   component name.
    TYPES: BEGIN OF ty_env,
             ebp      TYPE string,
             rolebp   TYPE string,
             rolename TYPE string,
           END OF ty_env.

    IF iv_userdata IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_env TYPE ty_env.

    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json = iv_userdata
                                   CHANGING  data = ls_env ).
      CATCH cx_root.
        CLEAR ls_env.
    ENDTRY.

*   Not JSON, or JSON without an EBP: treat what we were given as the key
*   itself. Better a value that might work than a blank that cannot.
    rv = COND string( WHEN ls_env-ebp IS NOT INITIAL THEN ls_env-ebp
                      ELSE iv_userdata ).
  ENDMETHOD.


  METHOD build.
    DATA(ls_cfg) = io_ctx->get_config( ).

    rs-partner = io_ctx->get_param( 'LOGINBP' ).
    rs-role    = io_ctx->get_param( 'ROLE' ).

*   THE PORTAL SESSION KEY - unwrapped, not passed on whole.
    rs-session_key = session_key_of( io_ctx->get_param( 'USERDATA' ) ).

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

*   LAST, so a real launch is never overwritten - see the header. Outside
*   E10/200 this is a no-op and the blanks stay blank, which is the honest
*   answer for a journey nobody logged into.
    simulate( EXPORTING io_ctx = io_ctx CHANGING cs = rs ).
  ENDMETHOD.


  METHOD simulate.
    IF sy-sysid <> c_sim_sysid OR sy-mandt <> c_sim_mandt.
      RETURN.
    ENDIF.

*   NO EARLY RETURN ON A PRESENT KEY. This method used to bail the moment
*   CS-SESSION_KEY was filled - which was fine while it was the ONLY
*   simulation. Then the engine started injecting USERDATA itself, so the
*   key arrived filled, this returned immediately, and CS-PARTNER was
*   never set: the parcel list went from three rows to
*
*       No partner is known for this journey, so no property can be listed
*
*   with nothing changed on the property side at all. Each field is now
*   filled on its own merits - a blank one is filled, a filled one is left
*   alone - so neither simulation can switch the other off.
    DATA lv_user TYPE zega_t_cj_us_log-id.
    lv_user = to_upper( io_ctx->get_param( 'SIMUSER' ) ).
    IF lv_user IS INITIAL.
      lv_user = c_sim_user.
    ENDIF.

*   The ACTIVE row, which is the one the DPC's GET_BP( ) matches. An
*   inactive row is a previous session and resolves nobody.
    IF cs-session_key IS INITIAL.
      SELECT SINGLE user_key FROM zega_t_cj_us_log
        WHERE id = @lv_user AND active = @abap_true
        INTO @cs-session_key.
    ENDIF.

*   And the partner behind that user, so the FILTERS agree with the header.
*   The two are read the same way the portal reads them and could disagree
*   only if the log row were stale.
    IF cs-partner IS INITIAL.
*     IV_INTERNET_USER refuses a variable typed ZEGA_T_CJ_US_LOG-ID - the
*     parameter is TYPE STRING and the binding is by reference, so the
*     types must match. A ZRAK_CJ_TESTKEY run once read that refusal as
*     "E10 resolves nobody". It resolves everybody; the call was wrong.
      DATA lv_fm_user TYPE string.
      DATA lv_bp      TYPE bu_partner.
      lv_fm_user = lv_user.
      TRY.
          CALL FUNCTION 'ZFM_EGA_GET_BP_FROM_INTERNET_U'
            EXPORTING  iv_internet_user    = lv_fm_user
            IMPORTING  ev_business_partner = lv_bp.
        CATCH cx_root.
          CLEAR lv_bp.
      ENDTRY.
      IF lv_bp IS NOT INITIAL.
        cs-partner = |{ lv_bp ALPHA = OUT }|.
        CONDENSE cs-partner.
      ENDIF.
    ENDIF.

    IF cs-partnerguid IS INITIAL.
      cs-partnerguid = guid_of( cs-partner ).
    ENDIF.
  ENDMETHOD.


ENDCLASS.
