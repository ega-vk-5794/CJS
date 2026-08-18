*&---------------------------------------------------------------------*
*& ZCL_RAK_TEST_ALL_LOGIC
*&---------------------------------------------------------------------*
*& Handler for ZTEST_ALL and its layout clones. Exists to cover the part
*& of the engine that configuration alone cannot reach:
*&
*&   get_table( )         RECORDCARD, RO_PANEL, TABLE plain,
*&                        TABLE single-pick, TABLE multi-check
*&   on_value_help( )     a dropdown with no config source
*&   on_search( )         the SEARCH block's magnifier
*&   on_change( )         reacting to a field the citizen just edited
*&   on_init( )           seeding values before the first render
*&   on_after_read( )     the hook that runs after the backend read
*&   on_fee_calc( )       fee recalculation
*&   on_custom_validate( ) a check the config grammar cannot express
*&   on_before_post( )    scrubbing the KV payload
*&   on_before_fields( )  scrubbing the adapter payload
*&   on_attach( )         reacting to an upload
*&   on_render_start( )   step-level chrome, top of the step
*&   on_render_before_field( ) / on_render_after_field( )
*&                        a control immediately above or below ANY field or
*&                        block, without claiming it the way render_field does
*&   on_render_end( )     an action bar after every field, above Back / Next
*&   on_render_popup( )   a handler-owned dialog, via dialog_form( )
*&   on_popup_event( )    the dialog's buttons, and payment
*&   render_field( )      claiming PAYFEE and drawing the fee card
*&   wants_feedback( ) / on_feedback( )   the post-submit happiness step
*&
*& PAYMENT IS SIMULATED. render_field builds a fixed fee table instead of
*& calling ZCL_RAK_PAY_ENGINE, and on_popup_event intercepts PAYNOW and
*& PAYPOLL. Nothing here contacts the gateway, takes a lock, or needs a
*& case number - which is what makes it safe to run on any client.
*&
*& All data is hardcoded. There is no database dependency of any kind, so
*& this activates and runs in an empty system.
*&---------------------------------------------------------------------*
CLASS zcl_rak_test_all_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init            REDEFINITION.
    METHODS zif_rak_journey_logic~on_after_read      REDEFINITION.
    METHODS zif_rak_journey_logic~on_change          REDEFINITION.
    METHODS zif_rak_journey_logic~on_search          REDEFINITION.
    METHODS zif_rak_journey_logic~on_value_help      REDEFINITION.
    METHODS zif_rak_journey_logic~get_table          REDEFINITION.
    METHODS zif_rak_journey_logic~get_attachments    REDEFINITION.
    METHODS zif_rak_journey_logic~get_attach_url     REDEFINITION.
    METHODS zif_rak_journey_logic~on_attach          REDEFINITION.
    METHODS zif_rak_journey_logic~on_fee_calc        REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post     REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_fields   REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_tables   REDEFINITION.
    METHODS zif_rak_journey_logic~on_save            REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_start    REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_before_field REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_after_field  REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_end          REDEFINITION.
    METHODS zif_rak_journey_logic~on_render_popup    REDEFINITION.
    METHODS zif_rak_journey_logic~on_popup_event     REDEFINITION.
    METHODS zif_rak_journey_logic~render_field       REDEFINITION.
    METHODS zif_rak_journey_logic~wants_feedback     REDEFINITION.
    METHODS zif_rak_journey_logic~on_feedback        REDEFINITION.

  PRIVATE SECTION.
*   Handler-owned popup and event ids. The engine prefixes handler events
*   with HPOP_ on the way out and strips it on the way back, so these are
*   the bare ids seen in on_popup_event.
    CONSTANTS c_pop_help  TYPE string VALUE 'HELP'.
    CONSTANTS c_evt_help  TYPE string VALUE 'OPENHELP'.
    CONSTANTS c_evt_hsave TYPE string VALUE 'HELPSAVE'.
    CONSTANTS c_evt_hcxl  TYPE string VALUE 'HELPCANCEL'.
    CONSTANTS c_evt_lines TYPE string VALUE 'RECALCLINES'.
    CONSTANTS c_evt_tidy  TYPE string VALUE 'TIDYLINES'.
    CONSTANTS c_evt_relic TYPE string VALUE 'RELOADLIC'.
    CONSTANTS c_evt_clear TYPE string VALUE 'CLEARPICKS'.

*   The hand-built popup. c_pop_help above is drawn by the inherited
*   dialog_form( ), which is the easy path and covers most cases. This one is
*   built control by control instead, because that is what a popup with a search,
*   its own state and an attachment has to be - and it is the shape a journey
*   developer will actually need.
    CONSTANTS c_pop_doc   TYPE string VALUE 'DOCPICK'.
    CONSTANTS c_evt_docop TYPE string VALUE 'OPENDOC'.
    CONSTANTS c_evt_docgo TYPE string VALUE 'DOCSEARCH'.
    CONSTANTS c_evt_docok TYPE string VALUE 'DOCOK'.
    CONSTANTS c_evt_doccx TYPE string VALUE 'DOCCANCEL'.
*   Popup-local state. NOT configured fields, so bind( ) cannot reach them and
*   they live in the scratch store. Prefixed with the popup id on purpose:
*   scratch is one flat namespace for the whole journey and a bare TERM would
*   collide with the next popup somebody writes.
    CONSTANTS c_doc_term  TYPE string VALUE 'DOCPICK_TERM'.
    CONSTANTS c_doc_pick  TYPE string VALUE 'DOCPICK_CHOSEN'.

*   OWNERS - a repeating list, the shape the legacy Owner screen had.
*
*   The LIST lives on the step and the POPUP is one form that adds or edits a
*   single row. That is the whole design: a table you can see, and a dialog you
*   open to change one line of it. A search inside the popup that drills into a
*   detail view inside the popup is a level of nesting the framework can carry
*   and a citizen cannot.
*
*   The rows are held in an EDITABLE_TABLE field, OWNER_GRID, rather than in
*   scratch. A grid rides the model, survives the round trip and posts to the
*   backend on its own; scratch would do the first two and silently not the
*   third.
    CONSTANTS c_grid      TYPE string VALUE 'OWNER_GRID'.
    CONSTANTS c_pop_own   TYPE string VALUE 'OWNER'.
    CONSTANTS c_evt_ownew TYPE string VALUE 'OWN_NEW'.
    CONSTANTS c_evt_ownsr TYPE string VALUE 'OWN_SEARCH'.
    CONSTANTS c_evt_ownok TYPE string VALUE 'OWN_OK'.
    CONSTANTS c_evt_owncx TYPE string VALUE 'OWN_CANCEL'.

*   Opening the two partner searches. Named constants like every other event in
*   this class - the two literals these replaced were the only raw event strings
*   left, and a raw string is one typo away from a button that does nothing and
*   says nothing.
*
*   They are NOT prefixed BPP_. That prefix belongs to ZCL_RAK_BP_POPUP's own
*   events, and on_popup_event routes anything matching it straight to the popup -
*   so an open event called BPP_OPEN_LESSOR would be handed to a popup that has
*   never heard of it and silently dropped.
    CONSTANTS c_evt_bplsr TYPE string VALUE 'BP_OPEN_LESSOR'.
    CONSTANTS c_evt_bplse TYPE string VALUE 'BP_OPEN_LESSEE'.
*   The form behind the popup. Scratch, because none of these is a configured
*   field - they exist only while the dialog is open.
    CONSTANTS c_own_id    TYPE string VALUE 'OWN_ID'.
    CONSTANTS c_own_name  TYPE string VALUE 'OWN_NAME'.
    CONSTANTS c_own_eid   TYPE string VALUE 'OWN_EID'.
    CONSTANTS c_own_nat   TYPE string VALUE 'OWN_NAT'.
    CONSTANTS c_own_share TYPE string VALUE 'OWN_SHARE'.

*   Simulated payment state, carried on io_ctx because a handler has no
*   memory between requests.
    CONSTANTS c_pay_polls TYPE string VALUE 'PAY_POLLS'.

*   The popup itself. A private method rather than fifteen more lines inside
*   on_render_popup( ): two popups in a CASE is fine, fifteen is a 400-line
*   method three people edit at once. At that point give each popup a class.
    METHODS render_doc_popup IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                                       io_popup TYPE REF TO z2ui5_cl_xml_view.
    METHODS render_own_popup IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                                       io_popup TYPE REF TO z2ui5_cl_xml_view.
*   The owner table as the citizen sees it, drawn on the step. Hand-built rather
*   than configured because each row needs TWO actions - edit and delete - and a
*   configured TABLE offers one.
    METHODS render_own_list  IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                                       io_view TYPE REF TO z2ui5_cl_xml_view.
*   Load one owner into the popup form, or clear it for a new one.
    METHODS own_form_load    IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                       iv_id  TYPE string OPTIONAL.
*   Write the popup form back into the grid: replace the row with this id, or
*   append when it is new.
    METHODS own_form_save    IMPORTING io_ctx TYPE REF TO zif_rak_journey.
*   Look the owner up by the Emirates ID already typed, and fill the rest of the
*   form from the business partner record.
    METHODS own_search       IMPORTING io_ctx TYPE REF TO zif_rak_journey.
    METHODS own_delete       IMPORTING io_ctx TYPE REF TO zif_rak_journey
                                       iv_id  TYPE string.
    METHODS to_i      IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE i.

    METHODS gcell
      IMPORTING is_grid   TYPE zif_rak_journey=>ty_table
                iv_ix     TYPE i
                iv_col    TYPE string
      RETURNING VALUE(rv) TYPE string.
    METHODS sum_lines
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_msg.
    TYPES: BEGIN OF ty_line,
             sortk TYPE string,
             item  TYPE string,
             qty   TYPE string,
             due   TYPE string,
             orig  TYPE string,
           END OF ty_line,
           tt_line TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    METHODS seed_lines
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.
    METHODS seed_picklists
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.
    METHODS tidy_lines
      IMPORTING io_ctx          TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv_moved) TYPE i.
    METHODS default_origin
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.
    METHODS addrow
      IMPORTING iv1    TYPE string DEFAULT ``
                iv2    TYPE string DEFAULT ``
                iv3    TYPE string DEFAULT ``
                iv4    TYPE string DEFAULT ``
                iv5    TYPE string DEFAULT ``
                iv6    TYPE string DEFAULT ``
      CHANGING  cs_tab TYPE zif_rak_journey=>ty_table.
    METHODS licences  RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_table.
    METHODS lic_info  IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                      RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_table.
    METHODS owners    RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_table.
    METHODS vehicles  RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_table.
    METHODS doc_matrix RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_table.
    METHODS recalc    IMPORTING io_ctx TYPE REF TO zif_rak_journey.
    METHODS seed_fees IMPORTING io_ctx TYPE REF TO zif_rak_journey.

ENDCLASS.



CLASS ZCL_RAK_TEST_ALL_LOGIC IMPLEMENTATION.


  METHOD addrow.
    DATA(lv_n) = lines( cs_tab-columns ).
    APPEND INITIAL LINE TO cs_tab-rows ASSIGNING FIELD-SYMBOL(<r>).
    IF lv_n >= 1.
      APPEND iv1 TO <r>.
    ENDIF.
    IF lv_n >= 2.
      APPEND iv2 TO <r>.
    ENDIF.
    IF lv_n >= 3.
      APPEND iv3 TO <r>.
    ENDIF.
    IF lv_n >= 4.
      APPEND iv4 TO <r>.
    ENDIF.
    IF lv_n >= 5.
      APPEND iv5 TO <r>.
    ENDIF.
    IF lv_n >= 6.
      APPEND iv6 TO <r>.
    ENDIF.
  ENDMETHOD.


  METHOD default_origin.
    DATA(ls_grid) = io_ctx->get_grid_data( 'LINE_ITEMS' ).
    IF ls_grid-rows IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_org) = COND string( WHEN io_ctx->get_val( 'SERVICE_CAT' ) = 'ADV'
                                THEN `AE` ELSE `` ).
    IF lv_org IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_out) = ls_grid.
    CLEAR ls_out-rows.
    DATA lv_hit TYPE i.
    DO lines( ls_grid-rows ) TIMES.
      DATA(lv_i) = sy-index.
      DATA(lv_it) = gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'ITEM' ).
      DATA(lv_q)  = gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'QTY' ).
      DATA(lv_d)  = gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'DUE' ).
      DATA(lv_o)  = gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'ORIG' ).
      IF lv_o IS INITIAL AND lv_it IS NOT INITIAL.
        lv_o   = lv_org.
        lv_hit = lv_hit + 1.
      ENDIF.
      addrow( EXPORTING iv1    = lv_it
                        iv2    = lv_q
                        iv3    = lv_d
                        iv4    = lv_o
              CHANGING  cs_tab = ls_out ).
    ENDDO.

    IF lv_hit = 0.
      RETURN.
    ENDIF.
    io_ctx->set_grid_data( iv_field = 'LINE_ITEMS' is_data = ls_out ).
    io_ctx->add_msg( iv_type = 'Information'
                     iv_text = |Origin defaulted on { lv_hit } line(s).| ).
  ENDMETHOD.


  METHOD doc_matrix.
*   Multi-check TABLE: DEFAULT_VAL is CHK:DOC_SEL, so column 1 is the key and
*   every ticked key is appended to DOC_SEL as a comma list.
    rs-columns = VALUE #( ( `Code` ) ( `Document` ) ( `Mandatory` ) ).
    addrow( EXPORTING iv1 = `D01` iv2 = `Trade licence copy`     iv3 = `Yes` CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `D02` iv2 = `Emirates ID copy`       iv3 = `Yes` CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `D03` iv2 = `Tenancy contract`       iv3 = `No`  CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `D04` iv2 = `Owner authorisation`    iv3 = `No`  CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `D05` iv2 = `Municipality clearance` iv3 = `No`  CHANGING cs_tab = rs ).
  ENDMETHOD.


  METHOD gcell.
*   Resolve the column name to its position, then read that cell of that row.
*   Column names are the ones from the DEFAULT_VAL spec (ITEM QTY DUE ORIG),
*   never the labels.
    DATA(lv_ci) = line_index( is_grid-columns[ table_line = to_upper( iv_col ) ] ).
    IF lv_ci = 0 OR iv_ix < 1 OR iv_ix > lines( is_grid-rows ).
      RETURN.
    ENDIF.
*   READ TABLE ... INTO DATA( ) takes its type straight from the table, so the
*   row variable is exactly the line type whatever that turns out to be.
    READ TABLE is_grid-rows INDEX iv_ix INTO DATA(lt_r).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rv = VALUE #( lt_r[ lv_ci ] OPTIONAL ).
  ENDMETHOD.


  METHOD licences.
*   RECORDCARD shape: column 1 is the key that gets stored, column 2 is the
*   card title, columns 3+ are joined into the meta line under it.
    rs-columns = VALUE #( ( `Licence` ) ( `Trade name` ) ( `Activity` ) ( `Valid to` ) ).
    addrow( EXPORTING iv1    = `LIC-1001`
                      iv2    = `Al Hamra Private School`
                      iv3    = `Education`
                      iv4    = `31.12.2026`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `LIC-1002`
                      iv2    = `Nakheel Trading LLC`
                      iv3    = `Trading`
                      iv4    = `30.06.2027`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `LIC-1003`
                      iv2    = `Rams Media Productions`
                      iv3    = `Advertising`
                      iv4    = `15.03.2027`
            CHANGING  cs_tab = rs ).
  ENDMETHOD.


  METHOD lic_info.
*   RO_PANEL shape: column 1 is the muted label, the rest are the bold values.
*   Reacts to the card picked above, so the panel is live.
    DATA(lv_sel) = io_ctx->get_val( 'LICENCE_CARDS' ).
    IF lv_sel IS INITIAL.
      RETURN.
    ENDIF.

    rs-columns = VALUE #( ( `Attribute` ) ( `Value` ) ).
    addrow( EXPORTING iv1 = `Licence number`    iv2 = lv_sel CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1    = `Issuing authority`
                      iv2    = `RAK Department of Economic Development`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1 = `Issued`            iv2 = `01.01.2024` CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `Expires`           iv2 = `31.12.2026` CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `Legal form`        iv2 = `Limited Liability Company` CHANGING cs_tab = rs ).
    addrow( EXPORTING iv1 = `Status`            iv2 = `Active` CHANGING cs_tab = rs ).
  ENDMETHOD.


  METHOD owners.
*   Plain TABLE: no DEFAULT_VAL on the field, so no selection column.
    rs-columns = VALUE #( ( `Name` ) ( `Nationality` ) ( `Share %` ) ( `Mobile` ) ).
    addrow( EXPORTING iv1    = `Ahmed Al Nuaimi`
                      iv2    = `United Arab Emirates`
                      iv3    = `51.00`
                      iv4    = `0501234567`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `Fatima Al Zaabi`
                      iv2    = `United Arab Emirates`
                      iv3    = `29.00`
                      iv4    = `0559876543`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `John Smith`
                      iv2    = `United Kingdom`
                      iv3    = `20.00`
                      iv4    = `0561122334`
            CHANGING  cs_tab = rs ).
  ENDMETHOD.


  METHOD own_delete.
    DATA(ls_g)   = io_ctx->get_grid_data( c_grid ).
    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) <> iv_id.
      APPEND lt_r TO ls_new-rows.
    ENDLOOP.
    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
*   The owner is gone from the list; their FILES are not. Deleting them here
*   would be the right thing and the framework has no call for it yet, so this
*   says so rather than pretending otherwise.
    io_ctx->add_msg( iv_type = 'Warning'
                     iv_text = |Owner { iv_id } removed. Any documents already | &&
                               |attached to them stay staged until the form is cleared.| ).
  ENDMETHOD.


  METHOD own_form_load.
*   Clear first, always. A form that keeps the last owner's values because one
*   field happened to be blank on the next one is the kind of bug nobody
*   reproduces on demand.
    io_ctx->set_val( iv_name = c_own_name  iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_eid   iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_nat   iv_value = '' ).
    io_ctx->set_val( iv_name = c_own_share iv_value = '' ).

    IF iv_id IS INITIAL.
*     New owner. The id is minted NOW and not on save, because the uploaders in
*     the dialog key their files on it - a file attached before the row exists
*     still has to belong to the right person.
      io_ctx->set_val( iv_name  = c_own_id
                       iv_value = |O{ sy-datum+2(6) }{ sy-uzeit }| ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_id iv_value = iv_id ).
    LOOP AT io_ctx->get_grid_data( c_grid )-rows INTO DATA(lt_r).
      CHECK VALUE string( lt_r[ 1 ] OPTIONAL ) = iv_id.
      io_ctx->set_val( iv_name = c_own_name  iv_value = VALUE #( lt_r[ 2 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_own_eid   iv_value = VALUE #( lt_r[ 3 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_own_nat   iv_value = VALUE #( lt_r[ 4 ] OPTIONAL ) ).
      io_ctx->set_val( iv_name = c_own_share iv_value = VALUE #( lt_r[ 5 ] OPTIONAL ) ).
      EXIT.
    ENDLOOP.
  ENDMETHOD.


  METHOD own_form_save.
*   get_grid_data( ) returns a COPY, so the round trip is read, rebuild, write.
*   Editing what it handed back changes nothing on screen.
    DATA(ls_g)  = io_ctx->get_grid_data( c_grid ).
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(ls_new) = VALUE zif_rak_journey=>ty_table( columns = ls_g-columns ).
    DATA lv_found TYPE abap_bool.
    DATA lt_row   TYPE zif_rak_journey=>tt_string.

    LOOP AT ls_g-rows INTO DATA(lt_r).
      IF VALUE string( lt_r[ 1 ] OPTIONAL ) = lv_id.
        lv_found = abap_true.
        CLEAR lt_row.
        APPEND lv_id                            TO lt_row.
        APPEND io_ctx->get_val( c_own_name )    TO lt_row.
        APPEND io_ctx->get_val( c_own_eid )     TO lt_row.
        APPEND io_ctx->get_val( c_own_nat )     TO lt_row.
        APPEND io_ctx->get_val( c_own_share )   TO lt_row.
        APPEND lt_row TO ls_new-rows.
      ELSE.
        APPEND lt_r TO ls_new-rows.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      CLEAR lt_row.
      APPEND lv_id                          TO lt_row.
      APPEND io_ctx->get_val( c_own_name )  TO lt_row.
      APPEND io_ctx->get_val( c_own_eid )   TO lt_row.
      APPEND io_ctx->get_val( c_own_nat )   TO lt_row.
      APPEND io_ctx->get_val( c_own_share ) TO lt_row.
      APPEND lt_row TO ls_new-rows.
    ENDIF.

    io_ctx->set_grid_data( iv_field = c_grid is_data = ls_new ).
  ENDMETHOD.


  METHOD own_search.
*   Search fills the form from the business partner record. It does NOT create
*   the row - that is still Add - so a citizen can search, look at what came
*   back, and close without having changed anything.
    DATA(lv_eid) = condense( io_ctx->get_val( c_own_eid ) ).
    IF strlen( lv_eid ) < 3.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Type at least 3 characters of the Emirates ID first.' ).
      RETURN.
    ENDIF.

*   Exactly the two columns the engine's own BP search reads, and no more.
*   BUT000 carries nationality under different names across landscapes, and a
*   demo is the wrong place to guess at one: an author who wants it can add the
*   column here once they have checked which it is in their system.
*
*   YFS002 is the Emirates ID type here - the same one the engine defaults to.
*   A journey looking up trade licences instead would read the id type from a
*   field rather than hard-coding it.
    SELECT SINGLE a~partner, a~zzfull_name_eng AS name
      FROM but000 AS a
      INNER JOIN but0id AS b
        ON  b~partner = a~partner
        AND b~type    = 'YFS002'
      WHERE b~idnumber = @lv_eid
      INTO @DATA(ls_bp).

    IF sy-subrc <> 0.
*     Say what was searched for. "Not found" on its own leaves the citizen
*     wondering whether the ID was wrong or the search was.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = |No business partner holds Emirates ID { lv_eid }. | &&
                                 |Type the details in by hand, or check the number.| ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = c_own_name iv_value = CONV string( ls_bp-name ) ).
    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = |Found { ls_bp-name } ({ ls_bp-partner }). | &&
                               |Add the nationality and shares, then press Add.| ).
  ENDMETHOD.


  METHOD recalc.
*   Everything on io_ctx is text, so convert in and out.
    DATA lv_qty TYPE i.
    DATA lv_cop TYPE i.
    DATA lv_ext TYPE i.
    DATA lv_dis TYPE i.

    lv_qty = to_i( io_ctx->get_val( 'QUANTITY' ) ).
    lv_cop = to_i( io_ctx->get_val( 'COPIES' ) ).
    lv_ext = to_i( io_ctx->get_val( 'EXTRA_COPIES' ) ).
    lv_dis = to_i( io_ctx->get_val( 'DISCOUNT_PCT' ) ).

    DATA(lv_fee) = lv_qty * 25 + ( lv_cop + lv_ext ) * 5.
    IF lv_dis > 0 AND lv_dis <= 50.
      lv_fee = lv_fee - lv_fee * lv_dis / 100.
    ENDIF.

    io_ctx->set_val( iv_name = 'FEE_AMOUNT' iv_value = |{ lv_fee }| ).
    io_ctx->set_val( iv_name = 'REF_TOTAL'  iv_value = |{ lv_fee }| ).

*   Drive the progress indicator off how much is filled in.
    DATA lv_done TYPE i.
    LOOP AT VALUE string_table(
        ( `FULL_NAME` ) ( `EMAIL_ADDR` ) ( `SERVICE_CAT` )
        ( `QUANTITY` )  ( `ACCEPT_TERMS` ) ) INTO DATA(lv_chk).
      IF io_ctx->get_val( lv_chk ) IS NOT INITIAL.
        lv_done = lv_done + 20.
      ENDIF.
    ENDLOOP.
    io_ctx->set_val( iv_name = 'PROGRESS_PCT' iv_value = |{ lv_done }| ).
  ENDMETHOD.


  METHOD render_doc_popup.
*   A popup built control by control: a search, a result list, an attachment and
*   two buttons. Everything here goes through io_ctx - bind( ), event( ),
*   get_val( ), render_upload( ). Reaching past it to z2ui5 directly is what
*   loses the popup's state on the next click.
    DATA(lo_dlg) = io_popup->dialog( title        = 'Supporting document'
                                     contentwidth = '34rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   ---- search: state that is NOT a configured field ------------------
*   bind( ) resolves a MODEL member, and DOCPICK_TERM has none - it is not in
*   any step. It works because set_val( ) falls through to the scratch store
*   when the name is not a model component, and bind( ) reads it back the same
*   way. Do not add a hidden field just to hold a search term: it would end up
*   in the backend payload.
    DATA(lo_top) = lo_c->hbox( alignitems = 'Center' class = 'sapUiTinyMarginBottom' ).
    lo_top->input( value       = io_ctx->bind( c_doc_term )
                   placeholder = 'Filter, e.g. pass'
                   width       = '18rem'
                   submit      = io_ctx->event( c_evt_docgo ) ).
    lo_top->button( text  = 'Filter'
                    icon  = 'sap-icon://search'
                    class = 'sapUiTinyMarginBegin'
                    press = io_ctx->event( c_evt_docgo ) ).

*   ---- the list -------------------------------------------------------
    DATA(lv_term) = to_upper( io_ctx->get_val( c_doc_term ) ).
    DATA(lv_sel)  = io_ctx->get_val( c_doc_pick ).
    DATA(lt_doc)  = VALUE zif_rak_journey=>tt_option(
      ( key = 'PASSPORT' text = 'Passport copy' )
      ( key = 'EID'      text = 'Emirates ID' )
      ( key = 'TRADELIC' text = 'Trade licence' )
      ( key = 'NOC'      text = 'No-objection certificate' ) ).

    DATA(lo_list) = lo_c->vbox( ).
    DATA lv_shown TYPE i.
    LOOP AT lt_doc INTO DATA(ls_doc).
      IF lv_term IS NOT INITIAL AND to_upper( ls_doc-text ) NS lv_term
         AND to_upper( ls_doc-key ) NS lv_term.
        CONTINUE.
      ENDIF.
      lv_shown = lv_shown + 1.
*     The key rides in the event id, which is how a list of unknown length wires
*     one button per row without needing a constant for each.
      lo_list->button( text  = ls_doc-text
                       type  = COND #( WHEN ls_doc-key = lv_sel THEN 'Emphasized' ELSE 'Transparent' )
                       icon  = COND #( WHEN ls_doc-key = lv_sel
                                       THEN 'sap-icon://accept' ELSE 'sap-icon://circle-task-2' )
                       press = io_ctx->event( |DOCSET_{ ls_doc-key }| ) ).
    ENDLOOP.
    IF lv_shown = 0.
      lo_list->message_strip( text = 'Nothing matches that filter.' type = 'Information' ).
    ENDIF.

*   ---- the attachment -------------------------------------------------
*   One line, and everything about it - the file picker, the allowed types, the
*   size ceiling and the chip list - comes from ATTACHMENTS_1's own
*   configuration. A popup that took its own limits would be a second place for
*   them to be wrong.
*
*   The file stages the moment it is picked, exactly as on a step, so Cancel
*   below undoes nothing. That is the honest behaviour: the file really was
*   attached, and its chip is on the step behind to prove it.
    lo_c->title( text = 'Attach it now, if you have it' class = 'sapUiSmallMarginTop' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'ATTACHMENTS_1' ).

    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Use this'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_docok ) ).
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_doccx ) ).
  ENDMETHOD.


  METHOD render_own_list.
*   The owner table, drawn on the step. Hand-built rather than a configured
*   TABLE because each row needs TWO actions - edit and delete - and a
*   configured table offers one row press.
    DATA(ls_g) = io_ctx->get_grid_data( c_grid ).

    DATA(lo_hd) = io_view->hbox( justifycontent = 'SpaceBetween'
                                 alignitems     = 'Center'
                                 class          = 'sapUiSmallMarginTop' ).
    lo_hd->title( text = 'Owner' class = 'rakBlkTitle' ).
    lo_hd->button( text  = 'Add Owner'
                   type  = 'Emphasized'
                   icon  = 'sap-icon://add'
                   press = io_ctx->event( c_evt_ownew ) ).

    DATA(lo_t)  = io_view->table( alternaterowcolors = abap_true ).
    DATA(lo_cl) = lo_t->columns( ).
    lo_cl->column( )->text( 'Owner Name' ).
    lo_cl->column( )->text( 'Nationality' ).
    lo_cl->column( )->text( 'Owner Shares' ).
    lo_cl->column( )->text( 'Documents' ).
    lo_cl->column( halign = 'End' )->text( '' ).

    DATA(lo_it) = lo_t->items( ).
    LOOP AT ls_g-rows INTO DATA(lt_r).
      DATA(lv_id)  = VALUE string( lt_r[ 1 ] OPTIONAL ).
      DATA(lv_nam) = VALUE string( lt_r[ 2 ] OPTIONAL ).
      DATA(lv_eid) = VALUE string( lt_r[ 3 ] OPTIONAL ).
      DATA(lv_nat) = VALUE string( lt_r[ 4 ] OPTIONAL ).
      DATA(lv_shr) = VALUE string( lt_r[ 5 ] OPTIONAL ).

*     How many files this owner has. Counting them here is the only way the
*     citizen can see, from the list, whose documents are still missing.
      DATA lv_docs TYPE i.
      CLEAR lv_docs.
      LOOP AT io_ctx->get_attachment_files( ) INTO DATA(ls_af).
        IF ls_af-identifier1 CS |_{ lv_id }|.
          lv_docs = lv_docs + 1.
        ENDIF.
      ENDLOOP.

      DATA(lo_cells) = lo_it->column_list_item( )->cells( ).
*     Name over Emirates ID, as the legacy screen had it.
      DATA(lo_nm) = lo_cells->vbox( ).
      lo_nm->text( text = lv_nam ).
      lo_nm->text( text = lv_eid class = 'rakRecMeta' ).
      lo_cells->text( lv_nat ).
      lo_cells->text( lv_shr ).
      lo_cells->object_status(
        text  = |{ lv_docs } file(s)|
        state = COND #( WHEN lv_docs > 0 THEN 'Success' ELSE 'Warning' )
        icon  = COND #( WHEN lv_docs > 0 THEN 'sap-icon://attachment' ELSE 'sap-icon://alert' ) ).
*     Two buttons rather than the legacy overflow menu: one press instead of
*     two, and nothing hidden behind an icon a citizen has to discover.
      DATA(lo_act) = lo_cells->hbox( ).
      lo_act->button( icon    = 'sap-icon://edit'
                      type    = 'Transparent'
                      tooltip = 'Edit owner details'
                      press   = io_ctx->event( |OWN_EDIT_{ lv_id }| ) ).
      lo_act->button( icon    = 'sap-icon://delete'
                      type    = 'Transparent'
                      tooltip = 'Delete'
                      press   = io_ctx->event( |OWN_DEL_{ lv_id }| ) ).
    ENDLOOP.

    IF ls_g-rows IS INITIAL.
      io_view->message_strip( text     = 'No owners yet. Press Add Owner to enter the first one.'
                              type     = 'Information'
                              showicon = abap_true
                              class    = 'sapUiSmallMarginTop' ).
    ENDIF.
  ENDMETHOD.


  METHOD render_own_popup.
*   ONE dialog: the owner's details and their documents. No search, no drill-
*   down, no second popup - the list is on the step behind and this is the form
*   that adds one line to it.
    DATA(lv_id) = io_ctx->get_val( c_own_id ).

    DATA(lo_dlg) = io_popup->dialog( title = 'Owner' contentwidth = '40rem' ).
    DATA(lo_c)   = lo_dlg->content( )->vbox( class = 'sapUiSmallMargin' ).

*   Search sits ON the section title, not under the Emirates ID field, because
*   it acts on the whole form: type the ID, press Search, and the rest fills in.
    DATA(lo_hdr) = lo_c->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    lo_hdr->title( text = 'Owner Details' class = 'rakBlkTitle' ).
    lo_hdr->button( text  = 'Search'
                    type  = 'Emphasized'
                    icon  = 'sap-icon://search'
                    press = io_ctx->event( c_evt_ownsr ) ).

*   Two per row, the way the legacy dialog laid it out.
    DATA(lo_r1) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c1) = lo_r1->vbox( class = 'rakCell' ).
    lo_c1->label( text = 'Owner name' class = 'rakReq' ).
    lo_c1->input( value = io_ctx->bind( c_own_name ) width = '17rem' ).
    DATA(lo_c2) = lo_r1->vbox( class = 'rakCell' ).
    lo_c2->label( text = 'Emirates ID' class = 'rakReq' ).
*   Enter in the ID box does the same as pressing Search. Somebody who has just
*   typed fifteen digits should not have to reach for the mouse.
    lo_c2->input( value       = io_ctx->bind( c_own_eid )
                  width       = '17rem'
                  placeholder = '784-xxxx-xxxxxxx-x'
                  submit      = io_ctx->event( c_evt_ownsr ) ).

    DATA(lo_r2) = lo_c->hbox( class = 'rakRow' alignitems = 'End' ).
    DATA(lo_c3) = lo_r2->vbox( class = 'rakCell' ).
    lo_c3->label( text = 'Nationality' ).
    lo_c3->input( value = io_ctx->bind( c_own_nat ) width = '17rem' ).
    DATA(lo_c4) = lo_r2->vbox( class = 'rakCell' ).
    lo_c4->label( text = 'Shares %' class = 'rakReq' ).
    lo_c4->input( value = io_ctx->bind( c_own_share ) type = 'Number' width = '17rem' ).

*   ---- their documents ------------------------------------------------
*   iv_key is what makes a repeating list work. Every uploader here is keyed on
*   THIS owner's id, so the chips shown are only theirs and the file reaches the
*   backend as identifier1 = MAIN_DOC_<owner id> - the shape the D0xx BAdI
*   already reads for OWNERS_SEARCH_<n>.
*
*   Without the key every owner's files would land in one chip list with nothing
*   to tell them apart, and the delete button beside a chip would remove
*   somebody else's document.
    lo_c->title( text = 'Documents' class = 'rakBlkTitle sapUiSmallMarginTop' ).
    lo_c->label( text = 'Emirates ID copy' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'MAIN_DOC' iv_key = lv_id ).
    lo_c->label( text = 'Passport copy and other documents' ).
    io_ctx->render_upload( io_view = lo_c iv_field = 'EXTRA_DOCS' iv_key = lv_id ).

    DATA(lo_b) = lo_dlg->buttons( ).
    lo_b->button( text  = 'Add'
                  type  = 'Emphasized'
                  icon  = 'sap-icon://accept'
                  press = io_ctx->event( c_evt_ownok ) ).
    lo_b->button( text = 'Close' press = io_ctx->event( c_evt_owncx ) ).
  ENDMETHOD.


  METHOD seed_fees.
*   One table, written whole, five times. There is no per-cell write in
*   ZIF_RAK_JOURNEY and no way for set_val( ) to reach a grid cell, so the shape
*   of this is fixed by the interface: build the rows, hand them over, done.
    DATA ls_data TYPE zif_rak_journey=>ty_table.
    DATA lt_grid TYPE zif_rak_journey=>tt_string.

*   COLUMNS ARE NAMED, and that is what makes this short. set_grid_data matches
*   them to the DEFAULT_VAL spec BY NAME, so:
*
*     - the order here does not have to match the spec's
*     - the amount columns can simply be LEFT OUT rather than sent empty
*
*   Leaving them out is the point. 0.00 on the form is a NUMBER cell rendering an
*   empty value; sending actual zeros would make "not answered" and "no charge"
*   the same answer, and on a fee schedule that distinction is the document.
*
*   K and L are upper case because grid_cols( ) upper-cases every column name it
*   parses. A lower-case name here matches nothing and is silently ignored - the
*   spec says unknown columns are dropped, so the failure would be three blank
*   rows rather than an error.
    ls_data-columns = VALUE #( ( `K` ) ( `L` ) ).
    ls_data-rows    = VALUE #(
      ( VALUE #( ( `SCHOOL` )  ( `School Fee` ) ) )
      ( VALUE #( ( `BOOKS` )   ( `Books Fee` ) ) )
      ( VALUE #( ( `UNIFORM` ) ( `Uniform Fee` ) ) ) ).

*   One list, five grids. A sixth cycle is one line here and one field in the
*   seed - not a sixth copy of this method.
    lt_grid = VALUE #( ( `FEES_PREKG` ) ( `FEES_KG` )
                       ( `FEES_C1` ) ( `FEES_C2` ) ( `FEES_C3` ) ).

    LOOP AT lt_grid INTO DATA(lv_grid).

*     NEVER OVERWRITE. On a resumed draft the rows are already in the model with
*     the citizen's amounts in them, and re-seeding would replace a completed fee
*     schedule with three empty ones without saying a word.
*
*     Test -ROWS and not the structure. get_grid_data publishes the COLUMNS even
*     when there are no rows yet - the interface is explicit that it does, so an
*     index can be resolved before anything is typed - which means the structure
*     is never initial and a plain IS INITIAL check here would seed exactly never.
      IF io_ctx->get_grid_data( lv_grid )-rows IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      io_ctx->set_grid_data( iv_field = lv_grid
                             is_data  = ls_data ).
    ENDLOOP.
  ENDMETHOD.


  METHOD seed_lines.
    DATA(ls_grid) = io_ctx->get_grid_data( 'LINE_ITEMS' ).
    IF ls_grid-rows IS NOT INITIAL.
      RETURN.
    ENDIF.
    IF ls_grid-columns IS INITIAL.
      RETURN.
    ENDIF.

    CLEAR ls_grid-rows.
    addrow( EXPORTING iv1    = `Standard processing`
                      iv2    = `1`
                      iv3    = ``
                      iv4    = ``
            CHANGING  cs_tab = ls_grid ).
    addrow( EXPORTING iv1    = `Certified copy`
                      iv2    = `2`
                      iv3    = ``
                      iv4    = ``
            CHANGING  cs_tab = ls_grid ).

    io_ctx->set_grid_data( iv_field = 'LINE_ITEMS' is_data = ls_grid ).
  ENDMETHOD.


  METHOD seed_picklists.
    DATA(ls_p) = io_ctx->get_grid_data( 'LINE_PICK' ).
    IF ls_p-columns IS NOT INITIAL AND ls_p-rows IS INITIAL.
      addrow( EXPORTING iv1 = `Standard processing` iv2 = `1` CHANGING cs_tab = ls_p ).
      addrow( EXPORTING iv1 = `Certified copy`      iv2 = `2` CHANGING cs_tab = ls_p ).
      addrow( EXPORTING iv1 = `Courier delivery`    iv2 = `1` CHANGING cs_tab = ls_p ).
      io_ctx->set_grid_data( iv_field = 'LINE_PICK' is_data = ls_p ).
    ENDIF.

    DATA(ls_l) = io_ctx->get_grid_data( 'LIC_LIST' ).
    IF ls_l-columns IS NOT INITIAL AND ls_l-rows IS INITIAL.
      addrow( EXPORTING iv1    = `E2400038`
                        iv2    = `RAK Private School Lic Test`
                        iv3    = `25.06.2024`
              CHANGING  cs_tab = ls_l ).
      addrow( EXPORTING iv1    = `E2400041`
                        iv2    = `GEMS International EN`
                        iv3    = `27.06.2024`
              CHANGING  cs_tab = ls_l ).
      addrow( EXPORTING iv1    = `E2400132`
                        iv2    = `The WellSpring Private School`
                        iv3    = `01.12.2024`
              CHANGING  cs_tab = ls_l ).
      io_ctx->set_grid_data( iv_field = 'LIC_LIST' is_data = ls_l ).
    ENDIF.

    DATA(ls_d) = io_ctx->get_grid_data( 'DOC_PICK' ).
    IF ls_d-columns IS NOT INITIAL AND ls_d-rows IS INITIAL.
      addrow( EXPORTING iv1 = `D01` iv2 = `Trade licence copy`     CHANGING cs_tab = ls_d ).
      addrow( EXPORTING iv1 = `D02` iv2 = `Emirates ID copy`       CHANGING cs_tab = ls_d ).
      addrow( EXPORTING iv1 = `D03` iv2 = `Tenancy contract`       CHANGING cs_tab = ls_d ).
      addrow( EXPORTING iv1 = `D04` iv2 = `Owner authorisation`    CHANGING cs_tab = ls_d ).
      io_ctx->set_grid_data( iv_field = 'DOC_PICK' is_data = ls_d ).
    ENDIF.
  ENDMETHOD.


  METHOD sum_lines.
*   Reads the grid, publishes three totals into read-only fields, and returns
*   one message per unusable row. Called from the Recalculate button and again
*   from on_custom_validate, so Next cannot slip past it.
*
*   ls_grid-columns carries the column names from the DEFAULT_VAL spec; each
*   ls_grid-rows entry has one cell per column in the same order. gcell( )
*   turns a name into an index so nothing here depends on column position.
    DATA(ls_grid) = io_ctx->get_grid_data( 'LINE_ITEMS' ).

    DATA lv_qty TYPE i.
    DATA lv_due TYPE d.
    DATA lv_cnt TYPE i.
    DATA lv_ix  TYPE i.

    DO lines( ls_grid-rows ) TIMES.
      lv_ix = sy-index.
      DATA(lv_item) = gcell( is_grid = ls_grid iv_ix = lv_ix iv_col = 'ITEM' ).
      DATA(lv_q)    = gcell( is_grid = ls_grid iv_ix = lv_ix iv_col = 'QTY' ).
      DATA(lv_d)    = gcell( is_grid = ls_grid iv_ix = lv_ix iv_col = 'DUE' ).
      DATA(lv_org)  = gcell( is_grid = ls_grid iv_ix = lv_ix iv_col = 'ORIG' ).

*     A row the citizen added and then left alone is entirely blank. Skip it
*     silently - complaining about it would be wrong.
      IF lv_item IS INITIAL AND lv_q IS INITIAL
         AND lv_d IS INITIAL AND lv_org IS INITIAL.
        CONTINUE.
      ENDIF.

      lv_cnt = lv_cnt + 1.

      IF lv_item IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = |Line { lv_ix }: description is missing.| ) TO rt.
      ENDIF.
      IF to_i( lv_q ) <= 0.
        APPEND VALUE #( type = 'Error'
          text = |Line { lv_ix }: quantity must be 1 or more.| ) TO rt.
      ENDIF.
      lv_qty = lv_qty + to_i( lv_q ).

*     Grid DATE cells arrive as the citizen sees them, dd.MM.yyyy, so they
*     need parsing before they can be compared.
      IF lv_d IS NOT INITIAL.
        DATA lv_dt TYPE d.
        CLEAR lv_dt.
        TRY.
            IF strlen( lv_d ) = 10 AND lv_d+2(1) = '.' AND lv_d+5(1) = '.'.
              lv_dt = lv_d+6(4) && lv_d+3(2) && lv_d+0(2).
            ELSEIF strlen( lv_d ) = 8 AND lv_d CO '0123456789'.
              lv_dt = lv_d.
            ENDIF.
          CATCH cx_root.
            CLEAR lv_dt.
        ENDTRY.
        IF lv_dt IS INITIAL.
          APPEND VALUE #( type = 'Error'
            text = |Line { lv_ix }: needed-by date is not a valid date.| ) TO rt.
        ELSEIF lv_due IS INITIAL OR lv_dt < lv_due.
          lv_due = lv_dt.
        ENDIF.
      ENDIF.
    ENDDO.

    io_ctx->set_val( iv_name = 'LINE_COUNT' iv_value = |{ lv_cnt }| ).
    io_ctx->set_val( iv_name = 'LINE_QTY'   iv_value = |{ lv_qty }| ).
    io_ctx->set_val( iv_name  = 'LINE_DUE'
                     iv_value = COND string( WHEN lv_due IS INITIAL THEN ''
                                             ELSE |{ lv_due DATE = USER }| ) ).
  ENDMETHOD.


  METHOD tidy_lines.
    DATA(ls_grid) = io_ctx->get_grid_data( 'LINE_ITEMS' ).
    IF ls_grid-columns IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_keep TYPE tt_line.

    DO lines( ls_grid-rows ) TIMES.
      DATA(lv_i) = sy-index.
      DATA(ls_l) = VALUE ty_line(
        item = condense( gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'ITEM' ) )
        qty  = condense( gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'QTY' ) )
        due  = condense( gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'DUE' ) )
        orig = condense( gcell( is_grid = ls_grid iv_ix = lv_i iv_col = 'ORIG' ) ) ).

      IF ls_l-item IS INITIAL AND ls_l-qty IS INITIAL
         AND ls_l-due IS INITIAL AND ls_l-orig IS INITIAL.
        rv_moved = rv_moved + 1.
        CONTINUE.
      ENDIF.

      IF to_i( ls_l-qty ) <= 0.
        ls_l-qty = '1'.
      ENDIF.

      ls_l-sortk = COND string( WHEN strlen( ls_l-due ) = 10
                                THEN ls_l-due+6(4) && ls_l-due+3(2) && ls_l-due+0(2)
                                ELSE '99991231' ).
      APPEND ls_l TO lt_keep.
    ENDDO.

    SORT lt_keep BY sortk ASCENDING item ASCENDING.

    DATA(ls_out) = ls_grid.
    CLEAR ls_out-rows.
    LOOP AT lt_keep INTO DATA(ls_k).
      addrow( EXPORTING iv1    = ls_k-item
                        iv2    = ls_k-qty
                        iv3    = ls_k-due
                        iv4    = ls_k-orig
              CHANGING  cs_tab = ls_out ).
    ENDLOOP.

    io_ctx->set_grid_data( iv_field = 'LINE_ITEMS' is_data = ls_out ).
  ENDMETHOD.


  METHOD to_i.
    DATA lv_int TYPE string.
    DATA lv_dec TYPE string.
    DATA(lv) = condense( iv ).
    REPLACE ALL OCCURRENCES OF ',' IN lv WITH ``.
    SPLIT lv AT '.' INTO lv_int lv_dec.
    IF lv_int IS NOT INITIAL AND lv_int CO '0123456789'.
      rv = lv_int.
    ENDIF.
  ENDMETHOD.


  METHOD vehicles.
*   Single-pick TABLE: column 1 is the key written into the field named in
*   DEFAULT_VAL (VEHICLE_SEL).
    rs-columns = VALUE #( ( `Plate` ) ( `Type` ) ( `Model` ) ( `Year` ) ).
    addrow( EXPORTING iv1    = `RAK-A-12345`
                      iv2    = `Pickup`
                      iv3    = `Toyota Hilux`
                      iv4    = `2022`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `RAK-B-67890`
                      iv2    = `Van`
                      iv3    = `Nissan Urvan`
                      iv4    = `2021`
            CHANGING  cs_tab = rs ).
    addrow( EXPORTING iv1    = `RAK-C-11223`
                      iv2    = `Truck`
                      iv3    = `Isuzu NPR`
                      iv4    = `2019`
            CHANGING  cs_tab = rs ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_attachments.
*   RESERVED - the engine does not call this yet. It will source the chip
*   list from here once attachments round-trip through the BAdI.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_attach_url.
*   RESERVED - as above, for the download link.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
*   TABLE, RECORDCARD and RO_PANEL have no model member, so rows the backend
*   returned for them are parked on the context instead. Serving get_table( ) from
*   there is the whole point of get_backend_table( ) - and it wins over the
*   hardcoded rows below, so a live journey shows real data and this test bed
*   still shows something with no backend at all.
    DATA(ls_be) = io_ctx->get_backend_table( iv_name ).
    IF ls_be-rows IS NOT INITIAL.
      rs_data = ls_be.
      RETURN.
    ENDIF.

    CASE iv_name.
      WHEN 'LICENCE_CARDS'. rs_data = licences( ).
      WHEN 'LICENCE_INFO'.  rs_data = lic_info( io_ctx ).
      WHEN 'OWNERS'.        rs_data = owners( ).
      WHEN 'VEHICLES'.      rs_data = vehicles( ).
      WHEN 'DOC_MATRIX'.    rs_data = doc_matrix( ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
*   Fires after the backend read. BKND_ACTIVE is blank on the test
*   journeys, so on a normal run this is a no-op - which is itself the
*   thing to observe: values that depend on backend data must be set
*   here, never in on_init.
    IF io_ctx->get_val( 'FULL_NAME' ) IS NOT INITIAL.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = 'Existing application data was read from the backend.' ).
    ENDIF.
    seed_lines( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_attach.
*   Fires AFTER the file is stored and already on screen, so this is an
*   advisory hook - it cannot reject the upload.
    CASE iv_field.
      WHEN 'ID_COPY_REF'.
        IF io_ctx->get_val( 'ID_COPY_REF' ) IS INITIAL.
          io_ctx->set_val( iv_name = 'ID_COPY_REF' iv_value = 'REF-FROM-DOCUMENT' ).
          io_ctx->add_msg( iv_type = 'Information'
                           iv_text = 'Reference number read from the attached copy.' ).
        ENDIF.
      WHEN 'MAIN_DOC'.
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = 'Main document received.' ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.
*   Adapter-path twin of on_before_post. Fires on every transmission -
*   init, step commit and submit - so anything rewritten here is
*   rewritten every time, not once.
    super->zif_rak_journey_logic~on_before_fields(
      EXPORTING
        io_ctx    = io_ctx
      CHANGING
        ct_fields = ct_fields ).

    DELETE ct_fields WHERE name = 'REF_CODE'.
    DELETE ct_fields WHERE name = 'REF_TOTAL'.
    DELETE ct_fields WHERE name = 'REF_DATE'.
    DELETE ct_fields WHERE name = 'PROGRESS_PCT'.
    DELETE ct_fields WHERE name = 'INFO_TEXT'.

*   Rewriting a value, not just filtering. Read through ASSIGN COMPONENT
*   rather than <f>-value: TT_FIELD belongs to ZIF_RAK_JOURNEY_BACKEND and
*   only NAME is used anywhere in the framework, so the payload component
*   name is not something this class should hard-code.
    tidy_lines( io_ctx ).

    DATA lv_tmp TYPE string.
    LOOP AT ct_fields ASSIGNING FIELD-SYMBOL(<f>) WHERE name = 'EMAIL_ADDR'.
      ASSIGN COMPONENT 'VALUE' OF STRUCTURE <f> TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0.
        lv_tmp = <v>.
        <v>    = to_lower( lv_tmp ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
*   The base drops PAYFEE and every PAY_* carrier. Keep that, then strip
*   the scratch fields this journey invented.
    super->zif_rak_journey_logic~on_before_post(
      EXPORTING
        io_ctx = io_ctx
      CHANGING
        ct_kv  = ct_kv ).

    DELETE ct_kv WHERE key = 'REF_CODE'.
    DELETE ct_kv WHERE key = 'REF_TOTAL'.
    DELETE ct_kv WHERE key = 'REF_DATE'.
    DELETE ct_kv WHERE key = 'PROGRESS_PCT'.
    DELETE ct_kv WHERE key = 'INFO_TEXT'.
    DELETE ct_kv WHERE key CP 'PARTNER_IDTYPE*'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
    super->zif_rak_journey_logic~on_before_tables(
      EXPORTING
        io_ctx    = io_ctx
      CHANGING
        ct_tables = ct_tables ).

    DATA(lv_pick) = io_ctx->get_val( 'LINE_SEL' ).
    IF lv_pick IS NOT INITIAL.
      LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>) WHERE ui_table_name = 'LINE_PICK'.
        IF <t>-ui_table_column1 = lv_pick.
          <t>-ui_table_column29 = 'S'.
        ENDIF.
      ENDLOOP.
    ENDIF.

    DATA(lv_ticked) = io_ctx->get_val( 'DOC_MSEL' ).
    IF lv_ticked IS NOT INITIAL.
      SPLIT lv_ticked AT ',' INTO TABLE DATA(lt_codes).
      LOOP AT ct_tables ASSIGNING <t> WHERE ui_table_name = 'DOC_PICK'.
        DATA lv_code TYPE string.
        lv_code = <t>-ui_table_column1.
        CONDENSE lv_code.
        IF line_exists( lt_codes[ table_line = lv_code ] ).
          <t>-ui_table_column29 = 'S'.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE iv_field.

*     Derived value: a select drives a read-only text.
      WHEN 'SERVICE_CAT'.
        CASE io_ctx->get_val( 'SERVICE_CAT' ).
          WHEN 'ADV'. io_ctx->set_val( iv_name = 'INFO_TEXT' iv_value = 'Advertisement requests are reviewed within 3 working days.' ).
          WHEN 'EVT'. io_ctx->set_val( iv_name = 'INFO_TEXT' iv_value = 'Event permits need the venue owner letter attached.' ).
          WHEN OTHERS. io_ctx->set_val( iv_name = 'INFO_TEXT' iv_value = 'Describe your request in the Notes field.' ).
        ENDCASE.
        default_origin( io_ctx ).
        recalc( io_ctx ).

*     Arithmetic across three fields, recomputed on every edit.
      WHEN 'QUANTITY' OR 'COPIES' OR 'EXTRA_COPIES' OR 'DISCOUNT_PCT'.
        recalc( io_ctx ).

*     Cheap format normalisation.
      WHEN 'EMIRATES_ID'.
        DATA(lv_id) = io_ctx->get_val( 'EMIRATES_ID' ).
        REPLACE ALL OCCURRENCES OF '-' IN lv_id WITH ''.
        CONDENSE lv_id NO-GAPS.
        io_ctx->set_val( iv_name = 'EMIRATES_ID' iv_value = lv_id ).

*     A picked RECORDCARD key arrives here as a normal field change.
      WHEN 'LICENCE_CARDS'.
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |Licence { io_ctx->get_val( 'LICENCE_CARDS' ) } selected.| ).

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   Keep the base behaviour first: it blocks submit while PAYFEE is not
*   PAID. Dropping the super call is the classic way to lose that.
    rt = super->zif_rak_journey_logic~on_custom_validate(
      io_ctx  = io_ctx
      iv_step = iv_step ).

*   Step numbers are zero-based. S2 is index 1.
    IF iv_step = 1.
      DATA lv_q TYPE i.
      DATA lv_c TYPE i.
      lv_q = to_i( io_ctx->get_val( 'QUANTITY' ) ).
      lv_c = to_i( io_ctx->get_val( 'COPIES' ) ).
*     A cross-field rule the config grammar cannot express.
      IF lv_c > lv_q.
        APPEND VALUE #( type = 'Error'
          text = 'Printed copies cannot exceed the quantity.' ) TO rt.
      ENDIF.
      IF io_ctx->get_val( 'IS_URGENT' ) = 'X'
         AND strlen( io_ctx->get_val( 'NOTES' ) ) < 20.
        APPEND VALUE #( type = 'Error'
          text = 'An urgent request needs at least 20 characters of justification in Notes.' ) TO rt.
      ENDIF.
    ENDIF.

*   S3 is index 2 - a licence must be chosen before moving on.
    IF iv_step = 2 AND io_ctx->get_val( 'LICENCE_CARDS' ) IS INITIAL.
      APPEND VALUE #( type = 'Error'
        text = 'Choose a licence card before continuing.' ) TO rt.
    ENDIF.

*   S4 is index 3. sum_lines( ) both publishes the totals and reports every
*   unusable row, so Next recalculates and validates in one pass - there is
*   no second code path that could disagree with the button.
    IF iv_step = 3.
*     Read a SEL: target exactly like any other field - that is the contract, and
*     it is why a handler needs to know nothing about _SEL.
      IF io_ctx->get_val( 'LINE_SEL' ) IS INITIAL.
        APPEND VALUE #( type = 'Error'
          text = 'Tick one line in the editable pick list.' ) TO rt.
      ENDIF.
      IF io_ctx->get_val( 'DOC_MSEL' ) NS 'D01'.
        APPEND VALUE #( type = 'Error'
          text = 'The trade licence copy (D01) has to be ticked.' ) TO rt.
      ENDIF.

      APPEND LINES OF sum_lines( io_ctx ) TO rt.
      IF to_i( io_ctx->get_val( 'LINE_COUNT' ) ) = 0.
        APPEND VALUE #( type = 'Error'
          text = 'Add at least one line item before continuing.' ) TO rt.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_feedback.
*   iv_rating is one of EX GD AV PR VP. A real handler persists it; this
*   one only acknowledges, so the journey stays database-free.
    DATA lv_word TYPE string.
    CASE iv_rating.
      WHEN 'EX'. lv_word = 'excellent'.
      WHEN 'GD'. lv_word = 'good'.
      WHEN 'AV'. lv_word = 'average'.
      WHEN 'PR'. lv_word = 'poor'.
      WHEN 'VP'. lv_word = 'very poor'.
      WHEN OTHERS. lv_word = iv_rating.
    ENDCASE.

    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = |Rating recorded: { lv_word }.| ).

    IF iv_comment IS NOT INITIAL.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = |Comment noted ({ strlen( iv_comment ) } characters).| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_fee_calc.
    recalc( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
*   Runs once when the journey opens, before the first render. Anything
*   set here is what the citizen sees on step 1.
    IF io_ctx->get_val( 'REF_CODE' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'REF_CODE' iv_value = 'ZTEST-ALL-001' ).
    ENDIF.
    IF io_ctx->get_val( 'PROGRESS_PCT' ) IS INITIAL.
      io_ctx->set_val( iv_name = 'PROGRESS_PCT' iv_value = '10' ).
    ENDIF.
    io_ctx->set_val( iv_name = 'STATUS_TXT' iv_value = 'In preparation' ).

*   Launch parameters arrive here. ?journey=ZTEST_ALL&loginbp=1000123
*   would land in get_param( 'loginbp' ).
    seed_lines( io_ctx ).
    seed_picklists( io_ctx ).

    DATA(lv_bp) = io_ctx->get_param( 'loginbp' ).
    IF lv_bp IS NOT INITIAL.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = |Launched for business partner { lv_bp }.| ).
    ENDIF.

    seed_fees( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.

*   ---- the partner popup's OWN events, before anything else ----------
*   THIS WAS MISSING. Opening the dialog was wired and answering it was not, so it
*   drew correctly and then Search, Resume Search and Close all did nothing - which
*   looks like a broken dialog and is a dispatch gap.
*
*   Matched on the BPP_ prefix so the popup is only constructed for its own events.
*   It is stateless - every value it touches is a model field - so a fresh instance
*   each round trip is the same instance.
    IF iv_event CP 'BPP_*' AND io_ctx->get_val( 'BP_ACTIVE_SUBJECT' ) IS NOT INITIAL.
      NEW zcl_rak_bp_popup(
            io_ctx     = io_ctx
            iv_subject = io_ctx->get_val( 'BP_ACTIVE_SUBJECT' ) )->handle( iv_event ).
      RETURN.
    ENDIF.

    CASE iv_event.

*     --- opening one of the two partner searches ---------------------
*     The subject is remembered in a field because on_popup_event is given the
*     event and not the popup id. Encoding it into every event name instead would
*     make the popup class parse its own events to find out who it is.
      WHEN c_evt_bplsr.
        io_ctx->set_val( iv_name = 'BP_ACTIVE_SUBJECT' iv_value = 'LESSOR' ).
        io_ctx->open_popup( 'BP_LESSOR' ).
        RETURN.
      WHEN c_evt_bplse.
        io_ctx->set_val( iv_name = 'BP_ACTIVE_SUBJECT' iv_value = 'LESSEE' ).
        io_ctx->open_popup( 'BP_LESSEE' ).
        RETURN.

*     --- handler-owned dialog ---------------------------------------
      WHEN c_evt_help.
        io_ctx->open_popup( c_pop_help ).

      WHEN c_evt_hsave.
        io_ctx->close_popup( ).
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = 'Thanks, we have noted that.' ).
        recalc( io_ctx ).

      WHEN c_evt_hcxl.
        io_ctx->close_popup( ).

*     --- hand-built popup: search, own state, attachment --------------
*     --- owners: list on the step, one popup to add or edit a row ----
      WHEN c_evt_ownew.
        own_form_load( io_ctx ).          " no id = a new owner
        io_ctx->open_popup( c_pop_own ).

      WHEN c_evt_ownsr.
        own_search( io_ctx ).

      WHEN c_evt_ownok.
*       Validate before writing. Closing on an incomplete row and complaining
*       behind the dialog makes the citizen reopen it and guess what was wrong.
        IF io_ctx->get_val( c_own_name ) IS INITIAL
           OR io_ctx->get_val( c_own_eid ) IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
                           iv_text = 'Owner name and Emirates ID are both needed.' ).
          RETURN.
        ENDIF.
        own_form_save( io_ctx ).
        io_ctx->close_popup( ).
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |{ io_ctx->get_val( c_own_name ) } added to the owner list.| ).

      WHEN c_evt_owncx.
*       Close discards the FORM, not the files. Anything already attached is
*       staged against this owner id and stays there - the same rule as
*       everywhere else here: a chip on screen means a real file.
        io_ctx->close_popup( ).

      WHEN c_evt_docop.
*       Start clean. A popup that reopens showing the last search is a small
*       thing that reads as a bug.
        io_ctx->set_val( iv_name = c_doc_term iv_value = '' ).
        io_ctx->set_val( iv_name = c_doc_pick iv_value = '' ).
        io_ctx->open_popup( c_pop_doc ).

      WHEN c_evt_docgo.
*       Nothing to do but re-render: the term is already in scratch, because the
*       input is bound to it, and render_doc_popup( ) filters on it. This branch
*       exists so Enter in the search box is a real event rather than a control
*       that looks live and is not.
        io_ctx->add_msg( iv_type = 'Information'
                         iv_text = |Filtered on "{ io_ctx->get_val( c_doc_term ) }".| ).

      WHEN c_evt_docok.
        DATA(lv_chosen) = io_ctx->get_val( c_doc_pick ).
        IF lv_chosen IS INITIAL.
*         Do not close on an incomplete choice. Closing and reporting the problem
*         behind the dialog makes the citizen reopen it and guess what went wrong.
          io_ctx->add_msg( iv_type = 'Warning' iv_text = 'Choose a document type first.' ).
          RETURN.
        ENDIF.
        io_ctx->close_popup( ).
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |Document type { lv_chosen } selected. | &&
                                   |Anything you attached is on the step behind, as a chip.| ).

      WHEN c_evt_doccx.
*       Cancel closes and undoes nothing. Any file picked is already staged and
*       its chip is on the step - which is deliberate. The citizen removes it
*       with the chip's delete button, not with a Cancel that discards silently.
        io_ctx->close_popup( ).

*     --- grid read-back ---------------------------------------------
*     --- the two buttons the new placement hooks drew ----------------
      WHEN c_evt_relic.
*       A real handler would re-read the licences here. This one re-seeds them, so
*       the button does something observable with no backend behind it.
        DATA(ls_lic) = io_ctx->get_grid_data( 'LIC_LIST' ).
        CLEAR ls_lic-rows.
        io_ctx->set_grid_data( iv_field = 'LIC_LIST' is_data = ls_lic ).
        seed_picklists( io_ctx ).
        io_ctx->add_msg( iv_type = 'Success' iv_text = 'Licence list reloaded.' ).

      WHEN c_evt_clear.
*       Clearing the TARGET clears the ticks: grid_sel_sync( ) reflects the target
*       into the row flags on every render, so the handler never touches _SEL.
        io_ctx->set_val( iv_name = 'LINE_SEL' iv_value = '' ).
        io_ctx->set_val( iv_name = 'DOC_MSEL' iv_value = '' ).
        io_ctx->add_msg( iv_type = 'Success' iv_text = 'All picks cleared.' ).

      WHEN c_evt_tidy.
        DATA(lv_dropped) = tidy_lines( io_ctx ).
        LOOP AT sum_lines( io_ctx ) INTO DATA(ls_tm).
          io_ctx->add_msg( iv_type = ls_tm-type iv_text = ls_tm-text ).
        ENDLOOP.
        io_ctx->add_msg( iv_type = 'Success'
                         iv_text = |Lines tidied. { lv_dropped } empty row(s) removed, sorted by needed-by date.| ).

      WHEN c_evt_lines.
        DATA(lt_bad) = sum_lines( io_ctx ).
        IF lt_bad IS INITIAL.
          io_ctx->add_msg( iv_type = 'Success'
                           iv_text = |Totals updated from { io_ctx->get_val( 'LINE_COUNT' ) } line(s).| ).
        ELSE.
          LOOP AT lt_bad INTO DATA(ls_bad).
            io_ctx->add_msg( iv_type = ls_bad-type iv_text = ls_bad-text ).
          ENDLOOP.
        ENDIF.

*     --- simulated payment ------------------------------------------
*     The base implementation of these two events talks to
*     ZCL_RAK_PAY_ENGINE. Intercepting them here is what keeps the test
*     journey away from the live gateway. Do NOT call super.
      WHEN zcl_rak_journey_logic=>c_pay_now.
        io_ctx->set_val( iv_name = zcl_rak_journey_logic=>c_pay_started iv_value = 'X' ).
        io_ctx->set_val( iv_name  = 'PAY_REFERENCE'
                         iv_value = |SIM{ sy-datum }{ sy-uzeit }| ).
        io_ctx->set_val( iv_name = c_pay_polls iv_value = '0' ).
        io_ctx->add_msg( iv_type = 'Information'
                         iv_text = 'Simulated payment started. The poll will confirm it shortly.' ).

      WHEN zcl_rak_journey_logic=>c_pay_poll.
*       The card polls itself every 2.5 seconds. Confirm on the second
*       poll so the busy state is actually visible.
        DATA lv_n TYPE i.
        lv_n = to_i( io_ctx->get_val( c_pay_polls ) ).
        lv_n = lv_n + 1.
        io_ctx->set_val( iv_name = c_pay_polls iv_value = |{ lv_n }| ).
        IF lv_n >= 2.
          io_ctx->set_val( iv_name = zcl_rak_journey_logic=>c_pay_field   iv_value = 'PAID' ).
          io_ctx->set_val( iv_name = zcl_rak_journey_logic=>c_pay_started iv_value = '' ).
          io_ctx->add_msg( iv_type = 'Success'
                           iv_text = 'Payment received (simulated).' ).
*         The citizen committed the step when they pressed Pay and has now paid
*         for it. Making them press Next as well only makes the page look like it
*         did not notice. advance_step( ) moves one step and does nothing on the
*         last one - advancing off the end is submitting, and submitting is not
*         something a poll fired by a timer gets to decide.
          io_ctx->advance_step( ).
        ENDIF.

      WHEN OTHERS.
*       Row actions carry their subject in the event id, which is how a list of
*       any length wires its buttons without a constant for each row.
        IF iv_event CP 'OWN_EDIT_*'.
          own_form_load( io_ctx = io_ctx iv_id = substring( val = iv_event off = 9 ) ).
          io_ctx->open_popup( c_pop_own ).
          RETURN.
        ENDIF.
        IF iv_event CP 'OWN_DEL_*'.
          own_delete( io_ctx = io_ctx iv_id = substring( val = iv_event off = 8 ) ).
          RETURN.
        ENDIF.
        IF iv_event CP 'DOCSET_*'.
          io_ctx->set_val( iv_name  = c_doc_pick
                           iv_value = substring( val = iv_event off = 7 ) ).
        ENDIF.
*       Select on a row: remember which, then switch the popup to its detail
*       view. Two set_val( ) calls and the next render is a different dialog.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_after_field.
*   A hint under ONE half of a side-by-side row. io_view is the row CELL here, not
*   the card, so this sits under School name en2 and leaves School Name Arabic 2
*   alone - which is the whole reason the hook passes the container it does.
    IF is_field-name = 'FEE_AMOUNT'.
      io_ctx->set_val( iv_name = 'FEE_HINT_SHOWN' iv_value = 'X' ).
      io_view->text( text  = 'Recalculated from quantity and copies.'
                     class = 'rakAttHint' ).
      RETURN.
    ENDIF.

*   And a running total under the grid it belongs to.
    IF is_field-name = 'LINE_ITEMS'.
      DATA(lv_n) = io_ctx->get_val( 'LINE_COUNT' ).
      IF lv_n IS NOT INITIAL AND lv_n <> '0'.
        io_view->object_status(
          text  = |{ lv_n } line(s), total quantity { io_ctx->get_val( 'LINE_QTY' ) }|
          state = 'Information'
          icon  = 'sap-icon://sum' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_before_field.
*   A button ABOVE a block. This is the case that had no answer before: a block
*   renders through the engine's private render_block( ), so claiming it with
*   render_field( ) would mean drawing the whole grid by hand. io_view here is the
*   card the block is about to render into, so the button lands just above it.
    IF is_field-name = 'LIC_LIST'.
      DATA(lo_bar) = io_view->hbox( justifycontent = 'End' alignitems = 'Center' ).
      lo_bar->button( text  = 'Refresh licences'
                      icon  = 'sap-icon://refresh'
                      type  = 'Transparent'
                      press = io_ctx->event( c_evt_relic ) ).
      RETURN.
    ENDIF.

*   A legend above the tick-box list, so the citizen knows what the column does.
    IF is_field-name = 'DOC_PICK'.
      io_view->text( text  = 'Tick every document you already hold. D01 is mandatory.'
                     class = 'rakAttHint' ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.
*   Step 1 carries the partner searches and the owner list. Steps count from ZERO
*   in the hooks, so 0 is the first step and 3 is the fourth.
    IF io_ctx->get_step( ) = 0.

*     Partner search first: it belongs with the applicant fields above it, and the
*     owner list is a separate block below.
*
*     THIS USED TO SIT AT THE BOTTOM OF THIS METHOD and never ran. The step 0
*     branch returns here, and the branch below it is CHECKed to step 3, so code
*     after both was reachable on no step at all. Nothing complained: an unreachable
*     render block is just a screen that quietly lacks two buttons.
      DATA(lo_bp) = io_view->hbox( class = 'rakRow sapUiSmallMarginTop' ).
      lo_bp->button( text  = COND #( WHEN io_ctx->get_val( 'LESSOR_PARTNER' ) IS INITIAL
                                     THEN 'Search lessor' ELSE 'Change lessor' )
                     icon  = 'sap-icon://search'
                     type  = 'Emphasized'
                     press = io_ctx->event( c_evt_bplsr ) ).
      lo_bp->button( text  = COND #( WHEN io_ctx->get_val( 'LESSEE_PARTNER' ) IS INITIAL
                                     THEN 'Search lessee' ELSE 'Change lessee' )
                     icon  = 'sap-icon://search'
                     type  = 'Emphasized'
                     class = 'sapUiSmallMarginBegin'
                     press = io_ctx->event( c_evt_bplse ) ).

      render_own_list( io_ctx = io_ctx io_view = io_view ).
      RETURN.
    ENDIF.

*   An action bar BELOW the step content and above Back / Next - the mirror of
*   on_render_start( ). Only on Documents, which is where the pick lists are.
    CHECK io_ctx->get_step( ) = 3.

    DATA(lo_end) = io_view->hbox( justifycontent = 'End'
                                  alignitems     = 'Center'
                                  class          = 'sapUiSmallMarginTop' ).
    lo_end->text( text  = |Picked line: { io_ctx->get_val( 'LINE_SEL' ) }  ·  |
                          && |ticked docs: { io_ctx->get_val( 'DOC_MSEL' ) }|
                  class = 'sapUiTinyMarginEnd' ).
    lo_end->button( text  = 'Clear all picks'
                    icon  = 'sap-icon://clear-all'
                    type  = 'Transparent'
                    press = io_ctx->event( c_evt_clear ) ).
    lo_end->button( text  = 'Pick a document type'
                    icon  = 'sap-icon://attachment'
                    press = io_ctx->event( c_evt_docop ) ).

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
*   dialog_form( ) is inherited. It builds a titled dialog from a field
*   list, two-way bound to model members, with Save and Cancel wired to
*   the event ids given.
*   Two popups, so iv_id has to be checked. Every popup event and every popup
*   render arrives at the same method: without the check, one popup draws over
*   the other and its OK button fires the wrong branch.

    IF iv_id CP 'BP_*'.
      NEW zcl_rak_bp_popup(
        io_ctx = io_ctx
        iv_subject = substring_after(
        val = iv_id
        sub = 'BP_' ) )->render( io_popup ).
      RETURN.
    ENDIF.

    IF iv_id = c_pop_doc.
      render_doc_popup( io_ctx = io_ctx io_popup = io_popup ).
      RETURN.
    ENDIF.
    IF iv_id = c_pop_own.
      render_own_popup( io_ctx = io_ctx io_popup = io_popup ).
      RETURN.
    ENDIF.

    CHECK iv_id = c_pop_help.

    dialog_form(
      io_ctx     = io_ctx
      io_popup   = io_popup
      iv_title   = 'Tell us what you need'
      iv_ok_text = 'Apply'
      iv_ok_evt  = c_evt_hsave
      iv_cxl_evt = c_evt_hcxl
      it_fields  = VALUE #(
        ( name = 'NOTES'        label = 'What are you applying for?' type = 'TEXTAREA' )
        ( name = 'BIRTH_DATE'   label = 'Date of birth'              type = 'DATE' )
        ( name = 'ID_COPY_REF'  label = 'Reference, if you have one' type = '' ) ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
*   Called once per step, before its fields. Step-level chrome goes here.
    DATA(lv_step) = io_ctx->get_step( ).

    DATA(lo_bar) = io_view->hbox( alignitems = 'Center'
                                  class      = 'sapUiSmallMarginBegin sapUiTinyMarginBottom' ).
    lo_bar->object_status(
      text  = |Step { lv_step + 1 } of 6|
      state = 'Information'
      icon  = 'sap-icon://hint'
      class = 'sapUiTinyMarginEnd' ).
*   io_ctx->event( ) wraps the id so the engine routes the press back
*   into on_popup_event. It works outside a popup too, which is what
*   makes this button possible.
    lo_bar->button( text  = 'What do I need?'
                    icon  = 'sap-icon://sys-help'
                    type  = 'Transparent'
                    press = io_ctx->event( c_evt_help ) ).

*   Documents is step index 3. The grid has no change event of its own -
*   render_grid binds cells straight to the model and only Add and Delete
*   raise anything - so an explicit button is the honest way to give the
*   citizen an immediate recalculation. Without it the totals would only
*   refresh on Next.
    IF lv_step = 3.
      lo_bar->button( text  = 'Recalculate totals'
                      icon  = 'sap-icon://sum'
                      type  = 'Transparent'
                      press = io_ctx->event( c_evt_lines ) ).
      lo_bar->button( text  = 'Tidy lines'
                      icon  = 'sap-icon://sort'
                      type  = 'Transparent'
                      press = io_ctx->event( c_evt_tidy ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_save.
*   What a handler that creates its own case would do here: take the staged files
*   with their identifiers already resolved and hand them to its own FM, rather
*   than letting the bridge post them.
    DATA(lt_files) = io_ctx->get_attachment_files( ).
    IF lt_files IS NOT INITIAL.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = |{ lines( lt_files ) } staged file(s) ready to attach to a case.| ).
    ENDIF.

*   And the other half: what the backend ALREADY holds, so a resumed application
*   does not ask for a document that was supplied months ago.
    DATA(lt_have) = io_ctx->get_backend_attachments( ).
    IF lt_have IS NOT INITIAL.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = |{ lines( lt_have ) } file(s) already on the case in the backend.| ).
    ENDIF.

*   Save as Draft. Nothing to persist beyond what the engine already
*   stores, so this just acknowledges.
    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = 'Draft saved by the test handler.' ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
*   The SEARCH block's magnifier and Enter key both land here. The term
*   is in the field's own value; the chosen ID type is in <FIELD>_IDTYPE.
    CHECK iv_field = 'PARTNER'.

    DATA(lv_term) = io_ctx->get_val( 'PARTNER' ).
    DATA(lv_type) = io_ctx->get_val( 'PARTNER_IDTYPE' ).

    IF lv_term IS INITIAL.
      io_ctx->add_msg( iv_type = 'Warning'
                       iv_text = 'Enter a partner number, name or Emirates ID first.' ).
      RETURN.
    ENDIF.

*   Simulated hit. A real handler would call the BP search here and, on
*   exactly one hit, fill the identity fields the way this does.
    io_ctx->set_val( iv_name = 'FULL_NAME'   iv_value = 'Ahmed Al Nuaimi' ).
    io_ctx->set_val( iv_name = 'EMAIL_ADDR'  iv_value = 'ahmed.alnuaimi@example.ae' ).
    io_ctx->set_val( iv_name = 'MOBILE_NO'   iv_value = '0501234567' ).
    io_ctx->set_val( iv_name = 'EMIRATES_ID' iv_value = '784199012345671' ).
    io_ctx->add_msg( iv_type = 'Success'
                     iv_text = |Partner found for { lv_term } (ID type { lv_type }). Details filled in.| ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
*   Called for a dropdown that has no OPTIONS, no ROLLNAME, no DOMNAME
*   and no SHLP. Return an empty table to leave the control empty.
    CASE iv_field.
      WHEN 'BRANCH_CD'.
        rt = VALUE #(
          ( key = 'RAK01' text = 'Ras Al Khaimah - Main' )
          ( key = 'RAK02' text = 'Al Nakheel' )
          ( key = 'RAK03' text = 'Al Jazeera Al Hamra' )
          ( key = 'RAK04' text = 'Rams' ) ).
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
    rv_done = abap_false.

*   Claim PAYFEE and draw the standard fee card with a fixed fee list.
*   The base class would call ZCL_RAK_PAY_ENGINE here; this does not, so
*   there is no lock check, no gateway and no case number needed.
    CHECK to_upper( is_field-name ) = zcl_rak_journey_logic=>c_pay_field.

    DATA lv_fee TYPE i.
    lv_fee = to_i( io_ctx->get_val( 'FEE_AMOUNT' ) ).
    IF lv_fee <= 0.
      lv_fee = 150.
    ENDIF.

    DATA(lt_fee) = VALUE zcl_rak_pay_engine=>tt_fee(
      ( desc = 'Service fee'      amount = lv_fee )
      ( desc = 'Knowledge dirham' amount = 10 )
      ( desc = 'Innovation fee'   amount = 10 ) ).

    pay_render(
      io_ctx   = io_ctx
      io_view  = io_form
      iv_field = zcl_rak_journey_logic=>c_pay_field
      it_fee   = lt_fee
      iv_total = CONV kbetr( lv_fee + 20 )
      iv_poll  = xsdbool( io_ctx->get_val( zcl_rak_journey_logic=>c_pay_started ) = 'X'
                          AND io_ctx->get_val( zcl_rak_journey_logic=>c_pay_field ) <> 'PAID' ) ).

    rv_done = abap_true.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~wants_feedback.
    rv = abap_true.
  ENDMETHOD.
ENDCLASS.
