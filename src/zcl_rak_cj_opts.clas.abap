CLASS zcl_rak_cj_opts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& The fourth source of a field's option list: a wrapper API.
*&
*& A field's options have had three sources - ZRAK_T_JNY_OPT, the
*& handler's ON_VALUE_HELP( ), and the DDIC F4 resolver. None of them can
*& answer "which parcels does this citizen own", because that answer lives
*& behind a Gateway DPC. This class is the fourth: a field whose
*& DEFAULT_VAL carries an API: directive gets its list from the matching
*& ZCL_RAK_*_API.
*&
*& THAT IS WHY THE DIRECTIVE EXISTS. ZCL_RAK_MIGRATOR writes
*& 'API:PROPERTY:PropertiesSet::Type=Parcel' onto every field it
*& classified as PARCEL, straight from BIND_TABLE( ), so the binding is
*& config the migrator produced rather than a branch someone has to
*& remember to add per journey. RESOLVE( ) is the other end of it.
*&
*& AN UNSERVED BINDING SAYS SO. A directive naming an API that is not
*& written yet - FloorSet, the tenancy and signing sets, the ValueHelp
*& domains - comes back with NO options and a NOTE, and the renderer puts
*& the note on the screen. That is the whole point: the alternative is a
*& dropdown that is empty for four different reasons which look identical,
*& which is the failure mode CLAUDE.md's silent-failure section is mostly
*& about.
*&
*& THE KEY IS WHAT THE LEGACY CONTROL STORED. RAKPARCELSELECTOR writes the
*& PARCEL ID into the journey's field, not the internal INTRENO -
*& 'setProperty("/INTRENO_PARCEL/value", a)' where a is ParcelId - so a
*& journey resumed from a draft written by ShapeIt and one written by CJS
*& hold the same value. Do not "improve" this to INTRENO.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

    CLASS-METHODS resolve
      IMPORTING is_field TYPE zif_rak_journey=>ty_field
                io_ctx   TYPE REF TO zif_rak_journey
      EXPORTING et_opt   TYPE zif_rak_journey=>tt_option
                ev_note  TYPE string.

*   Does this field carry a directive at all? Cheap enough to call before
*   building a context.
    CLASS-METHODS is_bound
      IMPORTING is_field  TYPE zif_rak_journey=>ty_field
      RETURNING VALUE(rv) TYPE abap_bool.

  PRIVATE SECTION.

    CLASS-METHODS property_opts
      IMPORTING is_dir   TYPE zcl_rak_cj_api=>ty_dir
                is_ctx   TYPE zcl_rak_cj_api=>ty_ctx
      EXPORTING et_opt   TYPE zif_rak_journey=>tt_option
                ev_note  TYPE string.

*   Port accommodation. Takes IO_CTX rather than the built context because
*   its filters are a PORT and a CASE, neither of which is journey identity -
*   the port is a field the citizen fills on the step itself.
    CLASS-METHODS accom_opts
      IMPORTING is_dir   TYPE zcl_rak_cj_api=>ty_dir
                io_ctx   TYPE REF TO zif_rak_journey
      EXPORTING et_opt   TYPE zif_rak_journey=>tt_option
                ev_note  TYPE string.

*   'Type=Parcel' -> 'Parcel'. The directive's filter slot is one
*   name=value pair today; anything richer belongs in the API, not in a
*   string this class has to parse.
    CLASS-METHODS filter_val
      IMPORTING iv_filter TYPE string
                iv_name   TYPE string
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS first_msg
      IMPORTING it_msg    TYPE bapiret2_t
      RETURNING VALUE(rv) TYPE string.
ENDCLASS.



CLASS zcl_rak_cj_opts IMPLEMENTATION.


  METHOD is_bound.
    rv = xsdbool( strlen( is_field-default ) > 4 AND is_field-default(4) = 'API:' ).
  ENDMETHOD.


  METHOD filter_val.
    DATA lv_n TYPE string.
    DATA lv_v TYPE string.

    IF iv_filter IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT iv_filter AT '=' INTO lv_n lv_v.
    IF to_upper( condense( lv_n ) ) = to_upper( iv_name ).
      rv = condense( lv_v ).
    ENDIF.
  ENDMETHOD.


  METHOD first_msg.
    READ TABLE it_msg INTO DATA(ls) INDEX 1.
    IF sy-subrc = 0.
      rv = ls-message.
    ENDIF.
  ENDMETHOD.


  METHOD resolve.
    CLEAR: et_opt, ev_note.

    IF is_bound( is_field ) = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_dir) = zcl_rak_cj_api=>parse_dir( is_field-default ).
    IF ls_dir-ok = abap_false.
      ev_note = |{ is_field-name }: the API binding '{ is_field-default }' is not readable|.
      RETURN.
    ENDIF.

    DATA(ls_ctx) = zcl_rak_cj_ctx=>build( io_ctx ).

    CASE to_upper( ls_dir-api ).
      WHEN 'PROPERTY'.
        property_opts( EXPORTING is_dir  = ls_dir
                                 is_ctx  = ls_ctx
                       IMPORTING et_opt  = et_opt
                                 ev_note = ev_note ).

      WHEN 'MAPLET'.
        accom_opts( EXPORTING is_dir  = ls_dir
                              io_ctx  = io_ctx
                    IMPORTING et_opt  = et_opt
                              ev_note = ev_note ).

      WHEN OTHERS.
*       Named, not silent. The list is empty because nothing serves this
*       binding yet, and that is a different thing from a citizen who owns
*       no parcels.
        ev_note = |{ is_field-name }: { ls_dir-api }/{ ls_dir-eset } has no wrapper API yet|.
    ENDCASE.
  ENDMETHOD.


  METHOD accom_opts.
    CLEAR: et_opt, ev_note.

*   Only the accommodation list is offered as options. Rooms and beds come
*   back from the SAME call and are reachable through
*   ZCL_RAK_ACCOM_API->CHILDREN_OF( ), but a cascading three-level picker is
*   a control, not an option list, and belongs in a handler.
    IF to_upper( is_dir-eset ) <> 'PORTACCOMMODATIONSET'.
      ev_note = |{ is_dir-eset } is not served by the accommodation API|.
      RETURN.
    ENDIF.

*   THE PORT IS A FIELD, NOT IDENTITY. E030 collects it on the step, so the
*   journey's own value is read first; a launch parameter is the fallback
*   for a journey started from a port context. The case is the engine's,
*   because a reservation belongs to the application being filled in.
    DATA(lv_port) = io_ctx->get_val( `PORT` ).
    IF lv_port IS INITIAL.
      lv_port = io_ctx->get_param( 'PORT' ).
    ENDIF.

*   CASE_NUMBER, NOT GET_CASE( ). The function module's IV_CASE is an
*   SCMG_EXT_KEY - the case's external number - while GET_CASE( ) returns
*   the engine's live case/draft GUID, which is a different identifier for
*   the same application. Passing the guid would not error: it would filter
*   to nothing and render an empty accommodation list on a port that is
*   full. Blank is the safer miss, because the port alone still lists what
*   the port holds. The engine writes CASE_NUMBER into the model itself
*   when the backend returns one, so this is its own value, not a guess.
    DATA(lo_api) = NEW zcl_rak_accom_api( ).
    DATA(ls_res) = lo_api->objects( VALUE #( port = lv_port
                                             case = io_ctx->get_val( `CASE_NUMBER` ) ) ).

    IF ls_res-msg IS NOT INITIAL.
      ev_note = first_msg( ls_res-msg ).
      RETURN.
    ENDIF.

    et_opt = lo_api->as_options( ls_res-buildings ).

    IF et_opt IS INITIAL.
      ev_note = COND string( WHEN sy-langu = 'E'
                             THEN 'This port has no accommodation registered'
                             ELSE 'لا يوجد سكن مسجل في هذا الميناء' ).
    ENDIF.
  ENDMETHOD.


  METHOD property_opts.
    CLEAR: et_opt, ev_note.

    DATA(lo_api) = NEW zcl_rak_property_api( is_ctx ).

*   PropertiesSet is the only property read with a flat _GET_ENTITYSET.
*   FloorSet and the $expand detail view are not served yet - see the
*   class header of ZCL_RAK_PROPERTY_API for why - so they are reported
*   rather than silently answered with an empty list.
    IF to_upper( is_dir-eset ) <> 'PROPERTIESSET'.
      ev_note = |{ is_dir-eset } is not served yet - it exists only inside GET_EXPANDED_ENTITYSET|.
      RETURN.
    ENDIF.

    DATA(lv_type) = filter_val( iv_filter = is_dir-dfilter iv_name = 'Type' ).

    DATA(ls_res) = lo_api->properties( iv_type = lv_type ).

    IF ls_res-msg IS NOT INITIAL.
      ev_note = first_msg( ls_res-msg ).
    ENDIF.

    LOOP AT ls_res-rows INTO DATA(ls_row).
*     PARCELID for a parcel, BUILDING for a row that has none - a unit on
*     a building the citizen owns carries the building number and an empty
*     parcel id, and the control reads exactly this pair.
      DATA(lv_key) = COND string( WHEN ls_row-parcelid IS NOT INITIAL
                                  THEN ls_row-parcelid ELSE ls_row-building ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.

*     Enough to tell two parcels apart without turning the dropdown into a
*     table: the number, then where it is and what it may be used for.
      DATA(lv_text) = lv_key.
      IF ls_row-sectortext IS NOT INITIAL.
        lv_text = |{ lv_text } - { ls_row-sectortext }|.
      ENDIF.
      IF ls_row-landuse IS NOT INITIAL.
        lv_text = |{ lv_text } - { ls_row-landuse }|.
      ENDIF.

      APPEND VALUE #( key = lv_key text = lv_text ) TO et_opt.
    ENDLOOP.

    IF et_opt IS INITIAL AND ev_note IS INITIAL.
      ev_note = COND string( WHEN sy-langu = 'E'
                             THEN 'No property is registered against this partner'
                             ELSE 'لا يوجد عقار مسجل لهذا الشريك' ).
    ENDIF.
  ENDMETHOD.


ENDCLASS.
