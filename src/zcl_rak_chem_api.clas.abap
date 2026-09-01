CLASS zcl_rak_chem_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The citizen's previous chemical declarations.
*&
*& WHAT WAS MISSING. The legacy CHEMICALS_DETAILS control does two things:
*& it collects a chemical, and - before that - it offers the ones this
*& applicant has declared before. E016, E017 and E018 rebuilt the first
*& half by hand, about 2,700 lines of dialog carrying that source's own
*& field names, and rebuilt none of the second. No CJS class reached the
*& history at all until this one.
*&
*& That is not cosmetic. A declaration is thirteen fields including HS code,
*& CAS number and chemical formula, and an importer declaring the same
*& twenty substances every month was retyping all of it, correctly, every
*& time. The history lookup is what made the legacy dialog tolerable.
*&
*& WHY THIS CALLS A FUNCTION MODULE AND NOT THE DPC. The first version of
*& this class inherited ZCL_ZEGA_FW_FND_DPC_EXT and called what it assumed
*& was CHEMICALHISTORYSET_GET_ENTITYSET. Reading the generated base class
*& settled three things at once, and all three killed that approach:
*&
*&   1. The method is CHEMICALHISTORYS_GET_ENTITYSET - the generator
*&      truncates at 30 characters, so the 'et' of 'Set' is gone.
*&   2. It IGNORES IT_FILTER_SELECT_OPTIONS entirely. It takes its filters
*&      from IO_TECH_REQUEST_CONTEXT->GET_FILTER( ), then GET_CONVERTED_
*&      SOURCE_KEYS( ), GET_TOP( ) and GET_SKIP( ) - so passing filters as a
*&      parameter, which is how every CUSTOMERJOURNEY read works, would have
*&      sent nothing and returned everything.
*&   3. Its filter properties are the INTERNAL names - 'IV_PERMIT', not
*&      'IvPermit' - and an unrecognised property RAISES rather than being
*&      ignored.
*&
*& And underneath all of that, the method's entire body is: unpack four
*& filters, CALL FUNCTION 'ZFE_CJ_CHEMICALS_HIST', copy fifteen fields into
*& the response. Everything above the function call is Gateway plumbing that
*& exists to turn an HTTP request into four variables - which CJS already
*& has, as four variables.
*&
*& So this calls the function module. It is RFC-enabled, so it is a
*& supported interface rather than an internal; it needs no request context,
*& no expand object and no DPC superclass; and it cannot be affected by the
*& CUSTOMERJOURNEY DPC chain being inactive. Nothing in the legacy namespace
*& is touched - this only calls it.
*&
*& THE IMPORT/EXPORT CODE. Domain ZDO_EPDA_CHEM_IMP_EXP has exactly two
*& fixed values: 1 Import, 2 Export. There is NO transit value, which is why
*& E018 sends none and gets unfiltered history - that is the domain's answer,
*& not a gap in this class.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   The history row, in the type the function module actually returns.
*   ZV_EPDA_CHEVHELP carries the same fifteen fields the OData entity
*   exposes, under the same names.
    TYPES ty_rows TYPE zif_zfe_cj_chemicals_hist=>zv_epda_chevhelp_tb.

    TYPES: BEGIN OF ty_req,
             permit  TYPE string,
             licence TYPE string,
             emirate TYPE string,
             impexp  TYPE string,
           END OF ty_req.

    TYPES: BEGIN OF ty_res,
             rows TYPE ty_rows,
             msg  TYPE bapiret2_t,
           END OF ty_res.

    TYPES: BEGIN OF ty_cell,
             name  TYPE string,
             value TYPE string,
           END OF ty_cell,
           tt_cell TYPE STANDARD TABLE OF ty_cell WITH EMPTY KEY.

*   Domain ZDO_EPDA_CHEM_IMP_EXP, both of its values. Transit has none.
    CONSTANTS c_import TYPE string VALUE '1'.
    CONSTANTS c_export TYPE string VALUE '2'.

*   The previous declarations for this applicant. A blank filter is passed
*   as blank, which the function module reads as "no restriction" - the same
*   thing the DPC did when a filter was absent from the URL.
    METHODS history
      IMPORTING is_req    TYPE ty_req
      RETURNING VALUE(rs) TYPE ty_res.

*   The same rows as a pick list. KEY is the row's index as a string: the
*   history has no key of its own that survives a round trip, and an index
*   is honest about that. TEXT is what a citizen recognises - the chemical,
*   then the material, then the HS code.
    METHODS as_options
      IMPORTING it_rows   TYPE ty_rows
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   Every component of one row, by name, so a caller maps onto its own popup
*   fields without this class knowing what those are called. Still RTTI
*   rather than a hand-written list: the row type is generated, and a
*   regenerated one that gains a column should widen this automatically.
    METHODS row_values
      IMPORTING it_rows   TYPE ty_rows
                iv_key    TYPE string
      RETURNING VALUE(rt) TYPE tt_cell.

  PRIVATE SECTION.

*   CHEMINAL_NAME is not a typo here. It is the source's own spelling, in
*   ZV_EPDA_CHEVHELP and in ZCL_ZEGA_FW_FND_MPC=>TS_CHEMICALHISTORY alike -
*   and E017's C_CHEM_POP carries the same misspelling, which is how we know
*   that handler's field names were copied from this service. Correcting it
*   here would simply stop matching.
    CONSTANTS c_col_chem  TYPE string VALUE 'CHEMINAL_NAME'.
    CONSTANTS c_col_mat   TYPE string VALUE 'MATERIAL_NAME'.
    CONSTANTS c_col_hs    TYPE string VALUE 'HS_CODE'.

ENDCLASS.



CLASS zcl_rak_chem_api IMPLEMENTATION.


  METHOD history.
*   DDIC-typed locals, not the context's strings passed straight in. The
*   function module's parameters are typed (RECNNR, ZDE_UAE_REGION and so
*   on) and moving through a declared local is what makes the conversion
*   explicit rather than incidental.
    DATA lv_impexp  TYPE zif_zfe_cj_chemicals_hist=>zde_epda_chem_imp_exp.
    DATA lv_permit  TYPE zif_zfe_cj_chemicals_hist=>recnnr.
    DATA lv_emirate TYPE zif_zfe_cj_chemicals_hist=>zde_uae_region.
    DATA lv_licence TYPE zif_zfe_cj_chemicals_hist=>zde_ega_epda_trade_license_no.

    lv_impexp  = is_req-impexp.
    lv_permit  = is_req-permit.
    lv_emirate = is_req-emirate.
    lv_licence = is_req-licence.

    TRY.
        CALL FUNCTION 'ZFE_CJ_CHEMICALS_HIST'
          EXPORTING
            iv_imp_exp_type        = lv_impexp
            iv_permit              = lv_permit
            iv_registered_emirates = lv_emirate
            iv_trade_license       = lv_licence
          IMPORTING
            et_hist                = rs-rows
          EXCEPTIONS
            OTHERS                 = 1.

        IF sy-subrc <> 0.
          CLEAR rs-rows.
          APPEND VALUE bapiret2(
              type    = 'E'
              id      = 'ZMSG_EGA_CJ'
              number  = '000'
              message = |The chemical history service returned { sy-subrc }| ) TO rs-msg.
        ENDIF.

      CATCH cx_root INTO DATA(lx).
*       Co-deployed, the function module raises rather than setting SY-SUBRC -
*       which is exactly what the generated DPC guards against too.
        CLEAR rs-rows.
        APPEND VALUE bapiret2( type    = 'E'
                               id      = 'ZMSG_EGA_CJ'
                               number  = '000'
                               message = lx->get_text( ) ) TO rs-msg.
    ENDTRY.
  ENDMETHOD.


  METHOD as_options.
    DATA lv_ix TYPE i.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<row>).
      lv_ix = sy-tabix.

      DATA lv_txt TYPE string.
      CLEAR lv_txt.

      LOOP AT VALUE string_table( ( c_col_chem ) ( c_col_mat ) ( c_col_hs ) )
           INTO DATA(lv_col).
        ASSIGN COMPONENT lv_col OF STRUCTURE <row> TO FIELD-SYMBOL(<cell>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
*       CONV string( ), not a bare move - <CELL> is TYPE any from a dynamic
*       ASSIGN COMPONENT and gives the target no type to derive from.
        DATA(lv_one) = condense( CONV string( <cell> ) ).
        IF lv_one IS INITIAL.
          CONTINUE.
        ENDIF.
        lv_txt = COND string( WHEN lv_txt IS INITIAL THEN lv_one
                              ELSE |{ lv_txt } - { lv_one }| ).
      ENDLOOP.

      IF lv_txt IS INITIAL.
        lv_txt = |Declaration { lv_ix }|.
      ENDIF.

      APPEND VALUE #( key = |{ lv_ix }| text = lv_txt ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD row_values.
    DATA lv_ix TYPE i.

    lv_ix = COND i( WHEN iv_key IS NOT INITIAL AND iv_key CO '0123456789'
                    THEN CONV i( iv_key ) ELSE 0 ).
    IF lv_ix <= 0.
      RETURN.
    ENDIF.

    READ TABLE it_rows ASSIGNING FIELD-SYMBOL(<row>) INDEX lv_ix.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lo_sd) = CAST cl_abap_structdescr(
                    cl_abap_typedescr=>describe_by_data( <row> ) ).

    LOOP AT lo_sd->components INTO DATA(ls_comp).
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE <row> TO FIELD-SYMBOL(<cell>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( name  = to_upper( CONV string( ls_comp-name ) )
                      value = condense( CONV string( <cell> ) ) ) TO rt.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
