class ZCL_RAK_EC02_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
    redefinition .
protected section.
  PRIVATE SECTION.
*   The details step, zero-based, as the hooks count them.
    CONSTANTS c_last_step TYPE i VALUE 1.
ENDCLASS.



CLASS ZCL_RAK_EC02_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~get_table.
  rs_data = io_ctx->get_backend_table( iv_name ).
ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   Returning a message here stops the step - which is how Submit is
*   blocked without an engine change. It fires on the details step only,
*   so Next from the search step still works normally.
*
*   The wording matters. "Validation failed" would read as the citizen
*   having done something wrong; they have not, and there is nothing for
*   them to correct. This says the journey is finished and they may leave.
    CHECK iv_step = c_last_step.

    rt = VALUE #( ( type = 'Information'
                    text = 'This is a tracking service - there is nothing to submit. ' &&
                           'The status above is current. You can close this page, or ' &&
                           'press Back to look up another complaint.' ) ).
  ENDMETHOD.
ENDCLASS.
