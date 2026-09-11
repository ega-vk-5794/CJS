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
                io_ctx   TYPE REF TO zif_rak_journey OPTIONAL
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

*   The logged-on partner's projects, for M028's project step.
*
*   IT GOES THROUGH ZCL_RAK_FEES_API, NOT ZCL_RAK_PROPERTY_API, and that
*   is not an accident of where the method landed: ProjectSet is one of
*   the three entity sets that never dereference IO_TECH_REQUEST_CONTEXT
*   (with FeesSet and TrackerSet), which is why those three could be
*   wrapped before the request-context factory existed. PROJECTS( ) says
*   so at its own signature.
*
*   TAKES IS_CTX, like PROPERTY_OPTS( ). The filters are Dept, Partner
*   and CaseId - all three are journey identity, so the built context
*   answers them and nothing has to come off the screen.
    CLASS-METHODS project_opts
      IMPORTING is_dir   TYPE zcl_rak_cj_api=>ty_dir
                is_ctx   TYPE zcl_rak_cj_api=>ty_ctx
                io_ctx   TYPE REF TO zif_rak_journey OPTIONAL
      EXPORTING et_opt   TYPE zif_rak_journey=>tt_option
                ev_note  TYPE string.

*   First non-blank component of a row named in IV_NAMES, a comma list.
*
*   WHY A CANDIDATE LIST AND NOT A FIELD NAME. A project row is
*   LINE OF ZCL_ZEGA_CJ_MPC=>TT_PROJECT, and that MPC cannot be opened
*   from the CJS repository - so naming a component directly would be a
*   guess, and a wrong guess is a syntax error that takes this class down
*   at load. Every journey with an API: directive renders through
*   RESOLVE( ), so that would take the parcel selector down with it.
*
*   Same decision, and the same reason, as ATTACHMENTS_FOR_BACKEND( )'s
*   DIFFCRT list and ZCL_RAK_CJ_API->COLUMNS_OF( )'s runtime read of the
*   MPC row structure.
*
*   EV_HIT names the component that answered. Nothing reads it today -
*   PROJECT_OPTS( ) reports the MISS instead, which is the actionable
*   half - but it is on the signature because the first caller that has
*   somewhere to log to will want it, and adding it later would mean
*   touching every call site.
    CLASS-METHODS row_pick
      IMPORTING is_row    TYPE any
                iv_names  TYPE string
      EXPORTING ev_val    TYPE string
                ev_hit    TYPE string.

*   'Type=Parcel' -> 'Parcel'.
*
*   The slot now takes SEVERAL clauses separated by ';' and a value may
*   read another field on the same journey:
*
*       API:PROPERTY:PropertiesSet::Type=Parcel;Sector=@SECTOR_SEL
*
*   A fixed filter can only ever say "all parcels of type X". One that
*   reads a field narrows the list to what the citizen has already chosen,
*   which is the difference between a selector and a catalogue - and it is
*   configuration rather than a handler.
*
*   IO_CTX IS OPTIONAL because the @ form is the only thing that needs it,
*   and a caller with no context still parses literals correctly.
    CLASS-METHODS filter_val
      IMPORTING iv_filter TYPE string
                iv_name   TYPE string
                io_ctx    TYPE REF TO zif_rak_journey OPTIONAL
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

*   SEMICOLON-SEPARATED CLAUSES, the same shape MSG and an uploader's
*   DEFAULT_VAL already use, so an author meets one convention rather than
*   three. A directive carrying a single Name=Value - which is every one
*   configured today, 'Type=Parcel' - is one clause and parses to exactly
*   what the old single SPLIT returned.
    SPLIT iv_filter AT ';' INTO TABLE DATA(lt_cl).

    LOOP AT lt_cl INTO DATA(lv_cl).
      DATA(lv_eq) = find( val = lv_cl sub = '=' ).
      IF lv_eq <= 0.
        CONTINUE.
      ENDIF.
      lv_n = condense( substring( val = lv_cl len = lv_eq ) ).
      lv_v = condense( substring( val = lv_cl off = lv_eq + 1 ) ).
      CHECK to_upper( lv_n ) = to_upper( iv_name ).

*     @FIELD READS THE JOURNEY'S OWN VALUE, which is the whole point of
*     this change: a filter that is fixed at design time can only ever say
*     "all parcels of type X". A filter that reads another field on the
*     same journey narrows the list to what the citizen has already
*     chosen - pick a sector, see that sector's parcels - and it is
*     configuration, not a handler.
*
*     A LITERAL IS ANYTHING WITHOUT THE @, so every directive in the
*     system today is untouched. The @ is not a character a legacy filter
*     value carries.
      IF strlen( lv_v ) > 1 AND lv_v(1) = '@'.
        IF io_ctx IS BOUND.
          rv = condense( io_ctx->get_val( substring( val = lv_v off = 1 ) ) ).
        ENDIF.
*       BLANK IS BLANK, NOT THE LITERAL. A field the citizen has not filled
*       in yet resolves to nothing, and nothing is the right filter - the
*       list is unnarrowed until they choose. Falling back to '@SECTOR' as
*       a literal would filter on a value no row can have and produce an
*       empty list that looks like "you own no parcels".
      ELSE.
        rv = lv_v.
      ENDIF.
      RETURN.
    ENDLOOP.
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
                                 io_ctx  = io_ctx
                       IMPORTING et_opt  = et_opt
                                 ev_note = ev_note ).

      WHEN 'MAPLET'.
        accom_opts( EXPORTING is_dir  = ls_dir
                              io_ctx  = io_ctx
                    IMPORTING et_opt  = et_opt
                              ev_note = ev_note ).

*     ADDITIVE, AND THAT IS THE WHOLE SAFETY ARGUMENT. This CASE is on the
*     directive's own API word, so a field carrying API:PROPERTY: or
*     API:MAPLET: cannot reach this branch and behaves exactly as it did.
*     Nothing configured today says PROJECT - M028 is the first, and it is
*     seeded by ZRAK_M028_LOAD in the same change.
      WHEN 'PROJECT'.
        project_opts( EXPORTING is_dir  = ls_dir
                                is_ctx  = ls_ctx
                                io_ctx  = io_ctx
                      IMPORTING et_opt  = et_opt
                                ev_note = ev_note ).

      WHEN OTHERS.
*       Named, not silent. The list is empty because nothing serves this
*       binding yet, and that is a different thing from a citizen who owns
*       no parcels.
        ev_note = |{ is_field-name }: { ls_dir-api }/{ ls_dir-eset } has no wrapper API yet|.
    ENDCASE.

*   ---- SEARCH IS FRAMEWORK, ABOVE EVERY BRANCH -------------------------
*   Here rather than inside PROPERTY_OPTS( ), because a search box is not
*   a property of parcels. Every API-bound list is a list of key/text
*   options by the time it reaches this line, so one filter serves them
*   all - projects, accommodations, and whatever the next wrapper answers.
*
*   The branch-specific filters stay in their branch, and that split is
*   the rule rather than an accident: SECTOR and LANDUSE name components
*   of a property row and only PROPERTY_OPTS( ) knows they exist, while
*   SEARCH names nothing and works on what the citizen reads.
*
*   MATCHED ON KEY AND TEXT TOGETHER. A citizen typing a parcel number
*   expects it found whether the number is in the key, the text, or both -
*   and CS, not equality, because a search box means "contains" everywhere
*   else they have used one.
*
*   BLANK SEARCHES NOTHING. An unfilled @FIELD is "not narrowed yet", and
*   the alternative is an empty list on first render.
    DATA(lv_q) = to_upper( filter_val( iv_filter = ls_dir-dfilter
                                       iv_name   = `Search`
                                       io_ctx    = io_ctx ) ).
    IF lv_q IS NOT INITIAL AND et_opt IS NOT INITIAL.
      DATA(lv_before) = lines( et_opt ).
*     Built into a keep list rather than deleted in place: deleting from
*     the table being looped over skips the row after each hit, which is
*     the oldest bug in this file's family and silently leaves half the
*     non-matches in.
      DATA lt_keep TYPE zif_rak_journey=>tt_option.
      LOOP AT et_opt INTO DATA(ls_chk).
        CHECK to_upper( |{ ls_chk-key } { ls_chk-text }| ) CS lv_q.
        APPEND ls_chk TO lt_keep.
      ENDLOOP.
      et_opt = lt_keep.
      IF et_opt IS INITIAL.
*       SAYING SO, because an empty list has four causes that look
*       identical on screen and this is the one the citizen can fix.
        ev_note = |No match for '{ lv_q }' in { lv_before } entr(ies) - clear the search to see them all|.
      ENDIF.
    ENDIF.
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

    DATA(lv_type) = filter_val( iv_filter = is_dir-dfilter iv_name = `Type` io_ctx = io_ctx ).

*   THE OTHER CLAUSES NARROW WHAT THE CITIZEN SEES, not what the API
*   returns, and the difference is worth being exact about. TYPE is the
*   only filter PROPERTIES( ) takes, so SECTOR, LANDUSE and SEARCH are
*   applied to the rows after they arrive. That is not paging and does not
*   pretend to be: the read is the same size, but the option list the
*   browser carries is not, and a citizen choosing from four parcels
*   instead of two hundred is the half that was actually asked for.
*
*   SEARCH IS A FILTER WHOSE VALUE COMES FROM A FIELD, which is why no new
*   mechanism is needed for it. Configure Search=@PARCEL_FIND, put a plain
*   input on the step called PARCEL_FIND, and the list narrows as the
*   citizen types - ON_CHANGE( ) already forces the round trip and
*   RENDER_ONE( ) already re-resolves the options on every render.
    DATA(lv_sector) = filter_val( iv_filter = is_dir-dfilter iv_name = `Sector`  io_ctx = io_ctx ).
    DATA(lv_luse)   = filter_val( iv_filter = is_dir-dfilter iv_name = `LandUse` io_ctx = io_ctx ).

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

*     THE NARROWING, after the text is composed so SEARCH can match what
*     the citizen actually reads rather than one column of it.
*
*     A BLANK CLAUSE FILTERS NOTHING. An unfilled @FIELD resolves to
*     blank, and blank has to mean "not narrowed yet" - the alternative is
*     an empty list on first render that reads as "you own no parcels".
*     SECTORTEXT ONLY, not a SECTOR code as well. The row type is
*     LINE OF a legacy MPC table that cannot be opened from here, and
*     SECTORTEXT and LANDUSE are the two components this method already
*     reads and therefore the two that are proven to exist. Naming a third
*     on the strength of the OData property list would be a guess, and a
*     wrong component name is a syntax error that takes this class down -
*     which takes the parcel selector and every other API-bound dropdown
*     with it, because RENDER_ONE( ) routes them all through RESOLVE( ).
      IF lv_sector IS NOT INITIAL AND to_upper( ls_row-sectortext ) <> to_upper( lv_sector ).
        CONTINUE.
      ENDIF.
      IF lv_luse IS NOT INITIAL AND to_upper( ls_row-landuse ) <> to_upper( lv_luse ).
        CONTINUE.
      ENDIF.
*     SEARCH IS NOT HANDLED HERE. It moved up to RESOLVE( ), which applies
*     it to every API-bound list rather than only to parcels - a search
*     box is not a property of properties. SECTOR and LANDUSE stay,
*     because they name components of a property row that only this method
*     knows exist.

      APPEND VALUE #( key = lv_key text = lv_text ) TO et_opt.
    ENDLOOP.

    IF et_opt IS INITIAL AND ev_note IS INITIAL.
      ev_note = COND string( WHEN sy-langu = 'E'
                             THEN 'No property is registered against this partner'
                             ELSE 'لا يوجد عقار مسجل لهذا الشريك' ).
    ENDIF.
  ENDMETHOD.


  METHOD project_opts.
    CLEAR: et_opt, ev_note.

*   ProjectSet is the only set this branch serves. Anything else under
*   API:PROJECT: is named rather than silently answered with an empty
*   list - an empty dropdown and an unserved binding look identical on
*   screen and are completely different problems.
    IF to_upper( is_dir-eset ) <> 'PROJECTSET'.
      ev_note = |{ is_dir-eset } is not served by the project API|.
      RETURN.
    ENDIF.

    DATA(lo_api) = NEW zcl_rak_fees_api( is_ctx = is_ctx ).

*   IV_CASE IS THE CONTEXT'S INTRENO, and it is OPTIONAL on purpose.
*   IS_CTX-INTRENO is io_ctx->get_case( ) - the live case guid, which on
*   a brand new request does not exist yet. Blank is the normal state at
*   the project step, and PROJECTS( ) simply omits the CaseId filter, so
*   the read comes back as "every project this partner owns". That is
*   exactly what step 1 has to offer.
    DATA(ls_res) = lo_api->projects( iv_case = is_ctx-intreno ).

    IF ls_res-msg IS NOT INITIAL.
      ev_note = first_msg( ls_res-msg ).
    ENDIF.

    DATA lv_key  TYPE string.
    DATA lv_desc TYPE string.

    LOOP AT ls_res-rows ASSIGNING FIELD-SYMBOL(<ls_row>).

*     THE KEY IS THE PROJECT'S INTERNAL NUMBER, because that is what
*     NCOD_1_1 stores: the screen carries INTRENO_PROJECT as a TOSAVE
*     carrier beside the control, exactly as NACO_1_1 carries
*     INTRENO_PARCEL beside the parcel selector.
      row_pick( EXPORTING is_row   = <ls_row>
                          iv_names = 'INTRENO,PROJECTID,PROJECT,PROJECTNO,PROJECTNUMBER,ID'
                IMPORTING ev_val   = lv_key ).
      IF lv_key IS INITIAL.
        CONTINUE.
      ENDIF.

*     Enough to tell two projects apart without turning the dropdown into
*     a table. Falls back to the key alone, which is always readable.
      row_pick( EXPORTING is_row   = <ls_row>
                          iv_names = 'PROJECTNAME,DESCRIPTION,PROJECTDESC,NAME,TEXT,DESC'
                IMPORTING ev_val   = lv_desc ).

      APPEND VALUE #( key  = lv_key
                      text = COND string( WHEN lv_desc IS NOT INITIAL
                                          THEN |{ lv_key } - { lv_desc }|
                                          ELSE lv_key ) ) TO et_opt.
    ENDLOOP.

*   ---- SAYING WHICH OF THE TWO EMPTINESSES THIS IS -------------------
*   NO TRACE( ) CALL HERE, DELIBERATELY. TRACE( ) is an INSTANCE method on
*   ZCL_RAK_JOURNEY_ENGINE and this is a CLASS-METHOD holding a context
*   struct, not an engine - so there is nothing to call it on. Reaching
*   for ZCL_RAK_JOURNEY_UTIL=>TRACE( ) instead does not work either: no
*   such method exists, and an unknown method here is a syntax error that
*   leaves this class with no active version, which would take the parcel
*   selector and every other API-bound field down with it.
*
*   EV_NOTE carries it instead, and it separates the two cases that look
*   identical on screen:
*
*     rows came back but no key could be read -> the candidate list in
*         ROW_PICK( ) above does not name the real component. Actionable,
*         and one run names it.
*     no rows at all -> this partner genuinely owns no project.
    IF et_opt IS INITIAL AND ev_note IS INITIAL.
      IF ls_res-rows IS NOT INITIAL.
        ev_note = |ProjectSet returned { lines( ls_res-rows ) } row(s) but no key | &&
                  |component matched. Extend the candidate list in | &&
                  |ZCL_RAK_CJ_OPTS->PROJECT_OPTS( ).|.
      ELSE.
        ev_note = COND string( WHEN sy-langu = 'E'
                               THEN 'No project is registered against this partner'
                               ELSE 'لا يوجد مشروع مسجل لهذا الشريك' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD row_pick.
    CLEAR: ev_val, ev_hit.

*   ASSIGN COMPONENT, NEVER ASSIGN (name). Assign-by-name resolves a
*   string as a data object visible in the CALLING program and writes
*   into whatever it finds - which is how ZIF_EGA_FW_CJI~MAPPER dumped
*   every DOK journey with MOVE_TO_LIT_NOTALLOWED_NODATA. Component
*   assignment cannot reach outside the structure.
    SPLIT iv_names AT ',' INTO TABLE DATA(lt_name).
    LOOP AT lt_name INTO DATA(lv_name).
      ASSIGN COMPONENT condense( to_upper( lv_name ) )
             OF STRUCTURE is_row TO FIELD-SYMBOL(<val>).
      IF sy-subrc = 0 AND <val> IS NOT INITIAL.
        ev_val = condense( CONV string( <val> ) ).
        ev_hit = condense( to_upper( lv_name ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
