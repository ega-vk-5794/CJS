*&---------------------------------------------------------------------*
*& ZCL_RAK_NOT_APPROVAL_LOGIC
*&
*& Handler for the Notary declaration journeys (NOT_* family).
*& Inherits ZCL_RAK_JOURNEY_LOGIC and redefines only what Notary needs:
*&   on_value_help      - resolves every list live from the Notary static
*&                        endpoints; nothing is held here
*&   on_search          - BP party lookup, pre-fills the party form
*&   get_table          - RO_PANEL body for the legal text, from the API
*&   on_custom_validate - Notary field checks; CALLS SUPER so the base
*&                        payment PAID-gate is preserved
*&
*& NOT redefined on purpose: on_before_post / on_before_fields (the base
*& strips PAY_* there), wants_feedback (feedback stays automatic).
*&---------------------------------------------------------------------*
CLASS zcl_rak_not_approval_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_value_help      REDEFINITION.
    METHODS zif_rak_journey_logic~on_search          REDEFINITION.
    METHODS zif_rak_journey_logic~get_table          REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

  PRIVATE SECTION.

    CONSTANTS mc_sub TYPE string VALUE '90'.

    METHODS blueprint_legal_text
      IMPORTING io_be          TYPE REF TO zcl_rak_be_not
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS ZCL_RAK_NOT_APPROVAL_LOGIC IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_RAK_NOT_APPROVAL_LOGIC->BLUEPRINT_LEGAL_TEXT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_BE                          TYPE REF TO ZCL_RAK_BE_NOT
* | [<-()] RV_TEXT                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD blueprint_legal_text.

    DATA(lv_json) = io_be->subservice_json( ).
    IF lv_json IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_res, legal_text TYPE string, END OF ty_res,
           BEGIN OF ty_root, result TYPE ty_res, END OF ty_root.

    DATA ls_r TYPE ty_root.

    TRY.
        /ui2/cl_json=>deserialize( EXPORTING json        = lv_json
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   CHANGING  data        = ls_r ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    rv_text = ls_r-result-legal_text.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_NOT_APPROVAL_LOGIC->ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_CTX                         TYPE REF TO ZIF_RAK_JOURNEY
* | [--->] IV_NAME                        TYPE        STRING
* | [<-()] RS_DATA                        TYPE        ZIF_RAK_JOURNEY=>TY_TABLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_logic~get_table.

    CASE to_upper( iv_name ).

      WHEN 'ARABICLEGALTEXT'.

        DATA(lo_be) = NEW zcl_rak_be_not( iv_subservice = mc_sub ).

        DATA(lv_req) = io_ctx->get_val( 'REQUEST_ID' ).
        IF lv_req IS INITIAL.
          lv_req = io_ctx->get_param( 'draftid' ).
        ENDIF.
        IF lv_req IS INITIAL.
          lv_req = io_ctx->get_param( 'caseid' ).
        ENDIF.

        DATA lv_txt TYPE string.

        IF lv_req IS NOT INITIAL.
          lv_txt = lo_be->legal_text( lv_req ).
        ENDIF.

        IF lv_txt IS INITIAL.
          lv_txt = blueprint_legal_text( lo_be ).
        ENDIF.

        IF lv_txt IS INITIAL.
          RETURN.
        ENDIF.

        rs_data-columns = VALUE #( ( `Legal Text` ) ).

        SPLIT lv_txt AT '</p>' INTO TABLE DATA(lt_para).

        LOOP AT lt_para INTO DATA(lv_p).
          REPLACE ALL OCCURRENCES OF '<p>'   IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '<br>'  IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '<br/>' IN lv_p WITH ``.
          REPLACE ALL OCCURRENCES OF '&nbsp;' IN lv_p WITH ` `.
          CONDENSE lv_p.
          IF lv_p IS NOT INITIAL.
            APPEND VALUE #( ( lv_p ) ) TO rs_data-rows.
          ENDIF.
        ENDLOOP.

    ENDCASE.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_NOT_APPROVAL_LOGIC->ZIF_RAK_JOURNEY_LOGIC~ON_CUSTOM_VALIDATE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_CTX                         TYPE REF TO ZIF_RAK_JOURNEY
* | [--->] IV_STEP                        TYPE        I
* | [<-()] RT                             TYPE        ZIF_RAK_JOURNEY=>TT_MSG
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_logic~on_custom_validate.

*   Preserve the base payment PAID-gate first.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx = io_ctx
                                                          iv_step = iv_step ).

*   Emirates ID shape.
    DATA(lv_eid) = io_ctx->get_val( 'PARTY_IDNUMBER' ).
    IF lv_eid IS NOT INITIAL AND strlen( lv_eid ) <> 15.
      APPEND VALUE #( type = 'Error' text = 'Emirates ID must be 15 digits.' ) TO rt.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_NOT_APPROVAL_LOGIC->ZIF_RAK_JOURNEY_LOGIC~ON_SEARCH
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_CTX                         TYPE REF TO ZIF_RAK_JOURNEY
* | [--->] IV_FIELD                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_logic~on_search.

*   BP party lookup. The id type chosen drives the Notary search type; a hit
*   pre-fills the party form so the citizen confirms rather than retypes.
    DATA(lv_id) = io_ctx->get_val( 'PARTY_IDNUMBER' ).
    IF lv_id IS INITIAL.
      lv_id = io_ctx->get_val( 'PARTY_PASSPORTNUMBER' ).
    ENDIF.
    IF lv_id IS INITIAL.
      lv_id = io_ctx->get_val( 'PARTY_UNIFIEDNUMBER' ).
    ENDIF.
    IF lv_id IS INITIAL.
      RETURN.
    ENDIF.

*   The id-type combobox holds SAP identification types (YFS002 and the
*   like) because the engine's own BP browse searches BUT0ID with them.
*   Notary does not know those codes - its searchType values are
*   IndividualbyEID / IndividualbyPassport / IndividualbyUID / CompanybyTL.
*   Translate here, at the boundary, and leave the SAP codes alone.
    DATA(lv_idtype) = to_upper( io_ctx->get_val( 'PARTY_SEARCH_IDTYPE' ) ).

    DATA(lv_stype) = COND string(
      WHEN lv_idtype = 'YFS002' OR lv_idtype = 'EID' OR lv_idtype = 'EMIRATESID'
        THEN 'IndividualbyEID'
      WHEN lv_idtype = 'PASSPORT' OR lv_idtype = 'YFS003'
        THEN 'IndividualbyPassport'
      WHEN lv_idtype = 'UID' OR lv_idtype = 'UNIFIED' OR lv_idtype = 'YFS004'
        THEN 'IndividualbyUID'
      WHEN lv_idtype = 'TL' OR lv_idtype = 'TRADELICENSE' OR lv_idtype = 'COMPANYBYTL'
        THEN 'CompanybyTL'
*     No id type chosen: fall back to whichever number the citizen filled.
      WHEN io_ctx->get_val( 'PARTY_PASSPORTNUMBER' ) IS NOT INITIAL
        THEN 'IndividualbyPassport'
      WHEN io_ctx->get_val( 'PARTY_UNIFIEDNUMBER' ) IS NOT INITIAL
        THEN 'IndividualbyUID'
      ELSE 'IndividualbyEID' ).

    DATA(lo_be) = NEW zcl_rak_be_not( ).
    DATA(lv_resp) = lo_be->search_party(
      iv_search_type = lv_stype
      it_fields      = VALUE #(
        ( name = 'PARTY_IDNUMBER'       value = io_ctx->get_val( 'PARTY_IDNUMBER' ) )
        ( name = 'PARTY_PASSPORTNUMBER' value = io_ctx->get_val( 'PARTY_PASSPORTNUMBER' ) )
        ( name = 'PARTY_UNIFIEDNUMBER'  value = io_ctx->get_val( 'PARTY_UNIFIEDNUMBER' ) )
        ( name = 'PARTY_DOB'            value = io_ctx->get_val( 'PARTY_DOB' ) )
        ( name = 'PARTY_NATIONALITY'    value = io_ctx->get_val( 'PARTY_NATIONALITY' ) ) ) ).

    IF lv_resp IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_pr,
             first_name    TYPE string,
             last_name     TYPE string,
             father_name   TYPE string,
             nation        TYPE string,
             mobile_number TYPE string,
             email         TYPE string,
           END OF ty_pr,
           BEGIN OF ty_pw, result TYPE ty_pr, END OF ty_pw.

    DATA ls_p TYPE ty_pw.
    /ui2/cl_json=>deserialize( EXPORTING json        = lv_resp
                                         pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                               CHANGING  data        = ls_p ).

    IF ls_p-result-first_name IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_FIRSTNAME' iv_value = ls_p-result-first_name ).
    ENDIF.
    IF ls_p-result-last_name IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_LASTNAME' iv_value = ls_p-result-last_name ).
    ENDIF.
    IF ls_p-result-father_name IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_FATHERNAME' iv_value = ls_p-result-father_name ).
    ENDIF.
    IF ls_p-result-mobile_number IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_MOBILENUMBER' iv_value = ls_p-result-mobile_number ).
    ENDIF.
    IF ls_p-result-email IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PARTY_EMAIL' iv_value = ls_p-result-email ).
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_NOT_APPROVAL_LOGIC->ZIF_RAK_JOURNEY_LOGIC~ON_VALUE_HELP
* +-------------------------------------------------------------------------------------------------+
* | [--->] IO_CTX                         TYPE REF TO ZIF_RAK_JOURNEY
* | [--->] IV_FIELD                       TYPE        STRING
* | [<-()] RT                             TYPE        ZIF_RAK_JOURNEY=>TT_OPTION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_logic~on_value_help.

*   Every list here is resolved live. dyn_list_for( ) maps a field name to
*   a list NAME only; lookup( ) fetches the content from the Notary static
*   endpoints on each call. No list values are held in this class.
    DATA(lo_be) = NEW zcl_rak_be_not( iv_subservice = mc_sub ).

    DATA(lv_list) = lo_be->dyn_list_for( iv_name = iv_field ).
    IF lv_list IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_a1 TYPE string.
    DATA lv_a2 TYPE string.

*   Region and city are dependent lists: the endpoint needs the parent that
*   was chosen. This is the one place those values are visible.
    CASE lv_list.

      WHEN 'REGION'.
        lv_a1 = io_ctx->get_val( 'PARTY_LIVINGCOUNTRY' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = 'AE'.
        ENDIF.

      WHEN 'CITY'.
        lv_a1 = io_ctx->get_val( 'PARTY_LIVINGCOUNTRY' ).
        IF lv_a1 IS INITIAL.
          lv_a1 = 'AE'.
        ENDIF.
        lv_a2 = io_ctx->get_val( 'PARTY_REGION' ).
        IF lv_a2 IS INITIAL.
          RETURN.
        ENDIF.

    ENDCASE.

    DATA(lt_opt) = lo_be->lookup( iv_list = lv_list
                                  iv_arg1 = lv_a1
                                  iv_arg2 = lv_a2 ).

    rt = VALUE #( FOR o IN lt_opt ( key = o-key text = o-text ) ).

  ENDMETHOD.
ENDCLASS.