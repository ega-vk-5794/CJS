class ZCL_RAK_EC05_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

*   EC05 - Give Suggestions.
*
*   This class exists for ONE reason, and it is worth saying plainly: the
*   engine refuses to draw the happiness meter when no handler is bound.
*
*     METHOD render_feedback.
*       IF mo_e->mo_logic IS NOT BOUND.
*         RETURN.
*
*   So a journey with no handler gets the confirmation line and nothing
*   else - no faces, no rating, no comment box. The seed report originally
*   shipped these four journeys handler-free on the grounds that nothing
*   needed one. That was wrong, and this is the correction.
*
*   Everything else here is inherited. wants_feedback( ) already returns
*   true on the base class, so the faces appear without a line of code;
*   the two methods below only exist to record what the citizen said and
*   to fill in the confirmation text.
  methods ZIF_RAK_JOURNEY_LOGIC~ON_FEEDBACK
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_AFTER_READ
    redefinition .
protected section.
ENDCLASS.



CLASS ZCL_RAK_EC05_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~on_after_read.
    IF io_ctx->get_case( ) IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_no) = condense( CONV string( zcl_ega_cj_ecomp_abs=>gs_data-caseid ) ).
    IF lv_no IS NOT INITIAL.
      io_ctx->set_reference( lv_no ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_feedback.
*   The rating the citizen gave, and their comment if they left one. The
*   engine has already thanked them and will not ask twice.
*
*   Nothing is stored yet, deliberately: there is no table for it, and a
*   silent INSERT into something invented here would be a second place for
*   satisfaction data to live. When the happiness table exists, write it
*   here - rating is one of EXCELLENT / GOOD / AVERAGE / POOR / VERYPOOR.
*
*   Until then this is a hook that runs and does nothing, which is honest,
*   as long as nobody assumes otherwise. Hence this comment.
    RETURN.
  ENDMETHOD.
ENDCLASS.
