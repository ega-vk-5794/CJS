CLASS zcl_rak_accom_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& Port accommodation - buildings, rooms, beds and the workers in them.
*&
*& WHAT THIS REPLACES. ACCOMODATIONS is the EPDA control behind E030 and
*& E130. ZCL_RAK_MIGRATOR->CLASSIFY( ) had no branch for it, so it fell to
*& WHEN OTHERS and migrated as a text box - a labour-accommodation booking
*& rendered as somewhere to type. Its real source is two entity sets on
*& ZEGA_EPDA_MAPLET_I_SRV, which was in no repository until the DPC and MPC
*& were supplied.
*&
*& WHY THIS CALLS FUNCTION MODULES, NOT THE DPC. The same finding as
*& ZCL_RAK_CHEM_API, twice over:
*&
*&   PORTACCOMMODATIO_GET_ENTITYSET reads three filters and calls
*&   ZEGA_CJ_EPDA_PORT_OBJECTS. WORKERSLISTSET_GET_ENTITYSET reads one
*&   filter off IO_TECH_REQUEST_CONTEXT->GET_FILTER( ) - not off
*&   IT_FILTER_SELECT_OPTIONS - and calls ZEGA_CJ_EPDA_LABORS_LIST.
*&
*& Both function modules are RFC-enabled, so they are supported interfaces
*& rather than internals, and calling them needs no request context, no
*& expand object and no DPC superclass. Nothing legacy is modified.
*&
*& AND THE DPC IS WORSE THAN THE FUNCTION MODULE HERE, which is the part
*& worth knowing. ZEGA_CJ_EPDA_PORT_OBJECTS returns buildings, rooms AND
*& beds from ONE call. The DPC keeps rooms and beds in protected instance
*& attributes (GT_PORT_ROOMS, GT_PORT_BEDS) and its PORTROOMSET_ and
*& PORTBEDSET_GET_ENTITYSET are EMPTY METHOD BODIES - so over OData those
*& two entity sets answer nothing at all. Reading the function module
*& directly gives CJS all three levels, which the legacy UI cannot get.
*&
*& THE THREE LEVELS SHARE ONE ROW TYPE. Buildings, rooms and beds all come
*& back as ZEGA_CJ_EPDA_PORT_OBJECTS_TT - the same architectural-object
*& shape at three depths, related by PARENT_ARCH_OBJECT_ID. That is not a
*& simplification made here; it is how the backend models them.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   One row type for all three levels - see the note above.
    TYPES ty_objects TYPE zega_cj_epda_port_objects_tt.
    TYPES ty_workers TYPE zif_zega_cj_epda_labors_list1=>ztt_cj_fishery_workers.

    TYPES: BEGIN OF ty_req,
             port     TYPE string,
             case     TYPE string,
*            IV_RESERVED_ITEMS. 'X' asks for what is already reserved
*            against this case rather than what is free - the two are
*            different questions and the citizen asks both: "what can I
*            book" and "what have I booked".
             reserved TYPE abap_bool,
           END OF ty_req.

    TYPES: BEGIN OF ty_res,
             buildings TYPE ty_objects,
             rooms     TYPE ty_objects,
             beds      TYPE ty_objects,
             msg       TYPE bapiret2_t,
           END OF ty_res.

    TYPES: BEGIN OF ty_worker_res,
             rows TYPE ty_workers,
             msg  TYPE bapiret2_t,
           END OF ty_worker_res.

*   Everything the port holds, in one call. Buildings, rooms and beds come
*   back together because the function module returns them together; there
*   is no cheaper call that fetches only one level.
    METHODS objects
      IMPORTING is_req    TYPE ty_req
      RETURNING VALUE(rs) TYPE ty_res.

*   The workers on a licence. Keyed on the fishery licence number, which is
*   the only filter the service takes.
    METHODS workers
      IMPORTING iv_licence TYPE string
      RETURNING VALUE(rs)  TYPE ty_worker_res.

*   Any of the three levels as a pick list. KEY is ARCH_OBJECT_ID, which is
*   the id the booking is made against; TEXT is what a citizen reads.
    METHODS as_options
      IMPORTING it_rows   TYPE ty_objects
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   The rows of IT_ROWS whose parent is IV_PARENT. Rooms in a building,
*   beds in a room - the relationship the backend models with
*   PARENT_ARCH_OBJECT_ID and the one a cascading picker needs.
    METHODS children_of
      IMPORTING it_rows   TYPE ty_objects
                iv_parent TYPE string
      RETURNING VALUE(rt) TYPE ty_objects.

  PRIVATE SECTION.

*   Read off TS_PORTACCOMMODATION, which the DPC fills by
*   MOVE-CORRESPONDING from the function module's own rows - so these are
*   the function module's names too.
    CONSTANTS c_col_id     TYPE string VALUE 'ARCH_OBJECT_ID'.
    CONSTANTS c_col_text   TYPE string VALUE 'ARCH_OBJECT_TEXT'.
    CONSTANTS c_col_number TYPE string VALUE 'ARCH_OBJECT_NUMBER'.
    CONSTANTS c_col_parent TYPE string VALUE 'PARENT_ARCH_OBJECT_ID'.
    CONSTANTS c_col_avail  TYPE string VALUE 'AVAILABLE'.

    METHODS cell
      IMPORTING is_row    TYPE any
                iv_comp   TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS err
      IMPORTING iv_text TYPE string
      CHANGING  ct_msg  TYPE bapiret2_t.

ENDCLASS.



CLASS zcl_rak_accom_api IMPLEMENTATION.


  METHOD cell.
*   One dynamic read, in one place. CONV string( ) rather than a bare move -
*   <VAL> is TYPE any from ASSIGN COMPONENT and gives the target no type to
*   derive from. A component that is not there yields blank, never a dump:
*   the row type is a DDIC table type that may gain or lose a field without
*   this class being touched.
    ASSIGN COMPONENT iv_comp OF STRUCTURE is_row TO FIELD-SYMBOL(<val>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv = condense( CONV string( <val> ) ).
  ENDMETHOD.


  METHOD err.
    APPEND VALUE bapiret2( type    = 'E'
                           id      = 'ZMSG_EGA_CJ'
                           number  = '000'
                           message = iv_text ) TO ct_msg.
  ENDMETHOD.


  METHOD objects.
*   DDIC-typed locals rather than the context's strings passed straight in.
*   The function module's parameters are typed, and moving through a
*   declared local makes the conversion explicit rather than incidental.
    DATA lv_port     TYPE zif_zega_cj_epda_port_objects=>zde_ega_fshry_port.
    DATA lv_case     TYPE zif_zega_cj_epda_port_objects=>scmg_ext_key.
    DATA lv_reserved TYPE zif_zega_cj_epda_port_objects=>flag.

    IF is_req-port IS INITIAL AND is_req-case IS INITIAL.
*     Neither filter set would ask the port for everything it has. Say so
*     rather than returning a list nobody meant to request.
      err( EXPORTING iv_text = COND #( WHEN sy-langu = 'E'
                                       THEN 'No port or case is known, so no accommodation can be listed'
                                       ELSE 'لا يوجد ميناء أو معاملة معروفة، لذلك لا يمكن عرض السكن' )
           CHANGING  ct_msg  = rs-msg ).
      RETURN.
    ENDIF.

    lv_port     = is_req-port.
    lv_case     = is_req-case.
    lv_reserved = COND #( WHEN is_req-reserved = abap_true THEN 'X' ELSE space ).

    TRY.
        CALL FUNCTION 'ZEGA_CJ_EPDA_PORT_OBJECTS'
          EXPORTING
            iv_port           = lv_port
            iv_case           = lv_case
            iv_reserved_items = lv_reserved
          IMPORTING
            et_building       = rs-buildings
            et_rooms          = rs-rooms
            et_beds           = rs-beds
          EXCEPTIONS
            OTHERS            = 1.

        IF sy-subrc <> 0.
          CLEAR: rs-buildings, rs-rooms, rs-beds.
          err( EXPORTING iv_text = |The port accommodation service returned { sy-subrc }|
               CHANGING  ct_msg  = rs-msg ).
        ENDIF.

      CATCH cx_root INTO DATA(lx).
*       Co-deployed, the function module raises rather than setting
*       SY-SUBRC - which is what the generated DPC guards against too.
        CLEAR: rs-buildings, rs-rooms, rs-beds.
        err( EXPORTING iv_text = lx->get_text( ) CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD workers.
    DATA lv_licence TYPE zif_zega_cj_epda_labors_list1=>recnnumber.

    IF iv_licence IS INITIAL.
      err( EXPORTING iv_text = COND #( WHEN sy-langu = 'E'
                                       THEN 'No licence number is known, so no workers can be listed'
                                       ELSE 'لا يوجد رقم رخصة معروف، لذلك لا يمكن عرض العمال' )
           CHANGING  ct_msg  = rs-msg ).
      RETURN.
    ENDIF.

    lv_licence = iv_licence.

    TRY.
        CALL FUNCTION 'ZEGA_CJ_EPDA_LABORS_LIST'
          EXPORTING
            iv_license = lv_licence
          IMPORTING
            et_workers = rs-rows
          EXCEPTIONS
            OTHERS     = 1.

        IF sy-subrc <> 0.
          CLEAR rs-rows.
          err( EXPORTING iv_text = |The workers list service returned { sy-subrc }|
               CHANGING  ct_msg  = rs-msg ).
        ENDIF.

      CATCH cx_root INTO DATA(lx).
        CLEAR rs-rows.
        err( EXPORTING iv_text = lx->get_text( ) CHANGING ct_msg = rs-msg ).
    ENDTRY.
  ENDMETHOD.


  METHOD as_options.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(lv_key) = cell( is_row = <row> iv_comp = c_col_id ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.

*     The name first, then the number, because a citizen looking for
*     "Block C" is not looking for an architectural object id.
      DATA(lv_txt) = cell( is_row = <row> iv_comp = c_col_text ).
      DATA(lv_num) = cell( is_row = <row> iv_comp = c_col_number ).
      IF lv_num IS NOT INITIAL.
        lv_txt = COND string( WHEN lv_txt IS INITIAL THEN lv_num
                              ELSE |{ lv_txt } - { lv_num }| ).
      ENDIF.
      IF lv_txt IS INITIAL.
        lv_txt = lv_key.
      ENDIF.

*     AVAILABLE is shown, not filtered on. A citizen who cannot see the
*     full occupied and free reads an empty list as a broken screen; a
*     list that says which is which reads as an answer.
      IF cell( is_row = <row> iv_comp = c_col_avail ) IS INITIAL.
        lv_txt = |{ lv_txt } ({ COND string( WHEN sy-langu = 'E'
                                             THEN 'not available' ELSE 'غير متاح' ) })|.
      ENDIF.

      APPEND VALUE #( key = lv_key text = lv_txt ) TO rt.
    ENDLOOP.
  ENDMETHOD.


  METHOD children_of.
    IF iv_parent IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<row>).
      IF cell( is_row = <row> iv_comp = c_col_parent ) = iv_parent.
        APPEND <row> TO rt.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
