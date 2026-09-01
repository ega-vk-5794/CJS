CLASS zcl_rak_chem_api DEFINITION
  PUBLIC
  INHERITING FROM zcl_zega_fw_fnd_dpc_ext
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The citizen's previous chemical declarations.
*&
*& WHAT WAS MISSING. The legacy CHEMICALS_DETAILS control does two things:
*& it collects a chemical, and - before that - it OFFERS the ones this
*& applicant has declared before, read from ChemicalHistorySet and filtered
*& by their permit and trade licence. E016, E017 and E018 rebuilt the first
*& half by hand, about 2,700 lines of dialog carrying that entity set's own
*& fields, and rebuilt none of the second. No CJS class referenced
*& ChemicalHistorySet at all until this one.
*&
*& That is not a cosmetic gap. A chemical declaration is thirteen fields
*& including HS code, CAS number and chemical formula, and an importer
*& declaring the same twenty substances every month was retyping all of it,
*& correctly, every time. The history lookup is the whole reason the legacy
*& dialog was tolerable.
*&
*& WHY IT INHERITS A DIFFERENT DPC. ChemicalHistorySet is on
*& zega_fw_fnd_srv, NOT on CUSTOMERJOURNEY - its row type is
*& ZCL_ZEGA_FW_FND_MPC=>TS_CHEMICALHISTORY. So this cannot inherit
*& ZCL_RAK_CJ_API, which inherits ZCL_ZEGA_CJ_DPC_EXT: a class has one
*& superclass, and the <Set>_GET_ENTITYSET methods are PROTECTED, so only a
*& subclass of the RIGHT DPC may call them.
*&
*& That is also why FILTER( ) and TO_MSG( ) are duplicated here rather than
*& reused from ZCL_RAK_CJ_API. Fifteen lines of duplication is the cheaper
*& side of the trade: referencing that class statically would make this one
*& fail to load whenever anything in the CUSTOMERJOURNEY DPC chain is
*& inactive, and it has no business depending on a service it never calls.
*&
*& THE FILTERS ARE THE LEGACY CONTROL'S OWN. IvPermit, IvTradeLicense,
*& IvRegisteredEmirates and IvImpExpType - the four the ShapeIt control
*& sends. IMPEXPTYPE is what separates the three journeys from each other:
*& import history must not be offered on an export form.
*&
*& THE FIELD NAMES OF TS_CHEMICALHISTORY ARE NOT HARD-CODED ANYWHERE HERE,
*& deliberately. The structure could not be read from the environment this
*& was written in, and inventing component names is how three activation
*& rounds were lost on a different class in this same layer. So the rows
*& come back in the MPC's own type, and AS_OPTIONS( ) / ROW_VALUES( ) walk
*& whatever components the structure actually has, by RTTI. COMPONENTS( )
*& prints them: run it once and the caller's mapping can stop guessing.
*&
*& NO CONSTRUCTOR IS DECLARED, on purpose - there is nothing to initialise,
*& so the superclass's own is inherited unchanged. That makes
*& NEW zcl_rak_chem_api( ) depend on ZCL_ZEGA_FW_FND_DPC_EXT's constructor
*& being parameterless, which is the same assumption ZCL_RAK_CJ_API already
*& makes about the CUSTOMERJOURNEY DPC. If activation says otherwise it
*& says so here, by parameter name, and a constructor is added that passes
*& them on - it is a one-line fix, not a redesign.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_req,
             permit      TYPE string,
             licence     TYPE string,
             emirate     TYPE string,
             impexp      TYPE string,
           END OF ty_req.

    TYPES: BEGIN OF ty_res,
             rows TYPE zcl_zega_fw_fnd_mpc=>tt_chemicalhistory,
             msg  TYPE bapiret2_t,
           END OF ty_res.

*   One component of one history row, as name and value. Deliberately
*   untyped: the caller matches on NAME, so it never has to name a
*   component this class could not verify.
    TYPES: BEGIN OF ty_cell,
             name  TYPE string,
             value TYPE string,
           END OF ty_cell,
           tt_cell TYPE STANDARD TABLE OF ty_cell WITH EMPTY KEY.

*   The previous declarations for this applicant. IS_REQ carries the four
*   filters the legacy control sends; a blank one is omitted, not sent
*   empty, because the DPC tests IS INITIAL on what it reads out.
    METHODS history
      IMPORTING is_req    TYPE ty_req
      RETURNING VALUE(rs) TYPE ty_res.

*   The same rows as a pick list. KEY is the row's index as a string, so
*   the caller can hand it straight back to ROW_VALUES( ) - the entity set
*   has no key this layer can rely on, and an index is honest about that.
*   TEXT is built from whichever of the recognised columns the structure
*   actually has, so a row reads as something a citizen recognises rather
*   than a number.
    METHODS as_options
      IMPORTING it_rows   TYPE zcl_zega_fw_fnd_mpc=>tt_chemicalhistory
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   Every component of one row, by name. The caller maps these onto its own
*   popup fields; nothing here knows what those are called.
    METHODS row_values
      IMPORTING it_rows   TYPE zcl_zega_fw_fnd_mpc=>tt_chemicalhistory
                iv_key    TYPE string
      RETURNING VALUE(rt) TYPE tt_cell.

*   The component names of TS_CHEMICALHISTORY as the system declares them.
*   Not called by the journeys - it exists so one run replaces a guess.
    CLASS-METHODS components
      RETURNING VALUE(rv) TYPE string.

  PRIVATE SECTION.

    METHODS filter
      IMPORTING iv_property TYPE string
                iv_value    TYPE string
      CHANGING  ct_filter   TYPE /iwbep/t_mgw_select_option.

    METHODS to_msg
      IMPORTING io_exc TYPE REF TO cx_root
      CHANGING  ct_msg TYPE bapiret2_t.

ENDCLASS.



CLASS zcl_rak_chem_api IMPLEMENTATION.


  METHOD filter.
*   A blank value adds NOTHING. The DPC tests IS INITIAL on what it reads
*   out, and an I/EQ/'' row is not initial - it is an equality test against
*   the empty string, which matches no row.
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    APPEND VALUE #( property = iv_property
                    select_options = VALUE #( ( sign = 'I' option = 'EQ' low = iv_value ) ) )
      TO ct_filter.
  ENDMETHOD.


  METHOD to_msg.
    APPEND VALUE bapiret2( type    = 'E'
                           id      = 'ZMSG_EGA_CJ'
                           number  = '000'
                           message = io_exc->get_text( ) ) TO ct_msg.
  ENDMETHOD.


  METHOD history.
    DATA lt_flt TYPE /iwbep/t_mgw_select_option.

    filter( EXPORTING iv_property = `IvPermit`
                      iv_value    = is_req-permit  CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `IvTradeLicense`
                      iv_value    = is_req-licence CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `IvRegisteredEmirates`
                      iv_value    = is_req-emirate CHANGING ct_filter = lt_flt ).
    filter( EXPORTING iv_property = `IvImpExpType`
                      iv_value    = is_req-impexp  CHANGING ct_filter = lt_flt ).

    TRY.
        chemicalhistoryset_get_entityset(
          EXPORTING
            iv_entity_name           = `ChemicalHistory`
            iv_entity_set_name       = `ChemicalHistorySet`
            iv_source_name           = ``
            it_filter_select_options = lt_flt
            is_paging                = VALUE #( )
            it_key_tab               = VALUE #( )
            it_navigation_path       = VALUE #( )
            it_order                 = VALUE #( )
            iv_filter_string         = ``
            iv_search_string         = ``
*           The request context this layer can build. Whether the FND DPC
*           reads it could not be checked from here; passing it costs
*           nothing and an unbound one is what dumps.
            io_tech_request_context  = zcl_rak_cj_req_ctx=>get( )
          IMPORTING
            et_entityset             = rs-rows ).
      CATCH cx_root INTO DATA(lx).
        to_msg( EXPORTING io_exc = lx CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD as_options.
    DATA lv_ix TYPE i.

*   The columns worth showing in a one-line label, in the order a citizen
*   reads them. Matched against the structure's REAL components below, so a
*   name that does not exist simply contributes nothing - it never raises
*   and never invents a column.
    DATA(lt_want) = VALUE string_table(
      ( `CHEMICALNAME` ) ( `CHEMICAL_NAME` ) ( `MATERIALNAME` ) ( `MATERIAL_NAME` )
      ( `HSCODE` )       ( `HS_CODE` )       ( `CAS` )          ( `CASNUMBER` ) ).

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<row>).
      lv_ix = sy-tabix.
      DATA lv_txt TYPE string.
      CLEAR lv_txt.

      LOOP AT lt_want INTO DATA(lv_want).
        ASSIGN COMPONENT lv_want OF STRUCTURE <row> TO FIELD-SYMBOL(<cell>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
*       CONV string( ), not a bare move - <CELL> is TYPE any from a dynamic
*       ASSIGN COMPONENT and has no static type for the target to derive.
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

    lv_ix = COND i( WHEN iv_key CO '0123456789' AND iv_key IS NOT INITIAL
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


  METHOD components.
    DATA lo_type TYPE REF TO cl_abap_typedescr.

    CALL METHOD cl_abap_typedescr=>describe_by_name
      EXPORTING  p_name         = 'ZCL_ZEGA_FW_FND_MPC=>TS_CHEMICALHISTORY'
      RECEIVING  p_descr_ref    = lo_type
      EXCEPTIONS type_not_found = 1
                 OTHERS         = 2.
    IF sy-subrc <> 0.
      rv = 'TS_CHEMICALHISTORY is not in this system'.
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_sd) = CAST cl_abap_structdescr( lo_type ).
      CATCH cx_sy_move_cast_error.
        rv = 'TS_CHEMICALHISTORY is not a structure'.
        RETURN.
    ENDTRY.

    LOOP AT lo_sd->components INTO DATA(ls_comp).
      rv = COND string( WHEN rv IS INITIAL THEN CONV string( ls_comp-name )
                        ELSE |{ rv }, { ls_comp-name }| ).
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
