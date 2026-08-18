*----------------------------------------------------------------------*
* D011 School Advertisement NOC — demo-mode handler                    *
* Hardcoded table data mirrors the reference screenshots because the  *
* direct-launch session has no portal BP context; replace get_table   *
* with the ZFM_EGA_CJ_FW_READ_TABLE_DATAN call once the &userdata=    *
* portal hand-off is live.                                             *
*----------------------------------------------------------------------*
class ZCL_RAK_D011_DEMO_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

public section.

  data LISENCE_NUMBER type RECNNUMBER .

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
    redefinition .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RAK_D011_DEMO_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

      WHEN 'LICENSES'.

          NEW zcl_dok_appln_handler_api( )->license_search(
          EXPORTING
          iv_case_type    = ''
          iv_bp_applicant = '1000116563'
        IMPORTING
          et_lic_no_list = data(lt_licenses) ).
        " column 1 is the row key copied into the target field (default_val)
        rs_data-columns = VALUE #( ( `License No` ) ( `License Name` )
                                   ( `Valid From` ) ( `Valid To` ) ).
        rs_data-rows = VALUE #(
          ( VALUE zif_rak_journey=>tt_string( ( `0000002400003` ) ( `TEst` )                ( `12.08.2024` ) ( `11.08.2025` ) ) )
          ( VALUE zif_rak_journey=>tt_string( ( `0000002400008` ) ( `Manager school` )      ( `12.08.2024` ) ( `11.08.2025` ) ) )
          ( VALUE zif_rak_journey=>tt_string( ( `0000002400010` ) ( `EN School name 3` )    ( `12.08.2024` ) ( `11.08.2025` ) ) )
          ( VALUE zif_rak_journey=>tt_string( ( `0000002400011` ) ( `RAK Academy EN 2` )    ( `12.08.2024` ) ( `11.08.2025` ) ) )
          ( VALUE zif_rak_journey=>tt_string( ( `0000002400013` ) ( `test New school- EN2` ) ( `12.08.2024` ) ( `11.08.2025` ) ) ) ).

      WHEN 'OWNERS'.
        rs_data-columns = VALUE #( ( `Owner` ) ( `Emirates ID` ) ( `Share %` ) ).
        rs_data-rows = VALUE #(
          ( VALUE zif_rak_journey=>tt_string( ( `Fatima Al Mansoori` ) ( `784-19xx-xxxxxxx-1` ) ( `60` ) ) )
          ( VALUE zif_rak_journey=>tt_string( ( `Omar Al Shamsi` )     ( `784-19xx-xxxxxxx-2` ) ( `40` ) ) ) ).

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    " demo lookup: any search resolves to a fixed license reference
    io_ctx->set_val( iv_name = 'LICENSE_NO' iv_value = '0000002500005' ).
    io_ctx->add_msg( iv_type = 'Success' iv_text = 'License found' ).
  ENDMETHOD.
ENDCLASS.
