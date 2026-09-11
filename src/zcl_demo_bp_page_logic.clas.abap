class ZCL_DEMO_BP_PAGE_LOGIC definition
  public
  inheriting from ZCL_RAK_JOURNEY_LOGIC
  final
  create public .

*&---------------------------------------------------------------------*
*& DEMO HANDLER for the paging / search / filter contract (R18-2).
*&
*& It exists to be driven, not shipped. BUT000 is the only table in the
*& system with enough rows to tell a working window from a broken one -
*& a demo over ten rows proves nothing, which is exactly how R17-2's
*& threshold test passed against 55 rows while the mechanism was inert.
*&
*& WHAT IT DEMONSTRATES, and each is a different half of the contract:
*&
*&   BP_LIST   pages. GET_TABLE( ) honours IV_OFFSET / IV_PAGE_SIZE and
*&             fills RS_DATA-TOTAL, so the engine's pager can say
*&             "51-75 / 4,812" and disable Next on the last page.
*&
*&   BP_FIND   searches. A plain INPUT the citizen types into; the query
*&             below narrows on it, IN THE DATABASE, so the window is a
*&             window onto the filtered set and the count moves with it.
*&
*&   BP_GROUP  filters. Same mechanism as the search, separate field, to
*&             show that two narrowing inputs compose rather than fight.
*&
*&   BP_ADDR   is the linked table. It is filtered by BP_SEL, which the
*&             row-pick on BP_LIST writes - so picking a partner on a
*&             paged, searched list drives a second table. That is the
*&             dependent-list case the parcel selector's Sector=@FIELD
*&             directive does for options, in its table form.
*&
*& THE SEARCH RESETS THE PAGE, and it has to. A citizen on page 7 of all
*& partners who types a name is asking a new question; leaving the offset
*& at 150 answers it with an empty page and looks broken. ON_CHANGE( )
*& below is the whole of that.
*&
*& RE-READING PER PAGE IS REAL AND IS NOT HIDDEN. Every Next runs the
*& SELECT again. For a demo that is the point - it makes the cost visible
*& - but a production handler over an expensive read should cache, and
*& the interface comment says so.
*&
*& Dev/test only. Seeded by ZRAK_DEMO_BPPAGE, which deletes its own rows
*& first and touches nothing outside journey ZDEMOBPPAGE.
*&---------------------------------------------------------------------*

public section.

  methods ZIF_RAK_JOURNEY_LOGIC~GET_TABLE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_CHANGE
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_RENDER_AFTER_FIELD
    redefinition .
  methods ZIF_RAK_JOURNEY_LOGIC~ON_POPUP_EVENT
    redefinition .
protected section.

  constants C_LIST  type STRING value 'BP_LIST' ##NO_TEXT.
  constants C_ADDR  type STRING value 'BP_ADDR' ##NO_TEXT.
  constants C_FIND  type STRING value 'BP_FIND' ##NO_TEXT.
  constants C_GROUP type STRING value 'BP_GROUP' ##NO_TEXT.
  constants C_SEL   type STRING value 'BP_SEL' ##NO_TEXT.

private section.

*   One display name from a BUT000 row. An organisation carries NAME_ORG1
*   and a person carries NAME_FIRST / NAME_LAST, and a demo that shows
*   only one of them looks empty for half the table.
*   Three strings rather than a BUT000 structure: the SELECT reads six
*   named columns, so the row it produces is not a BUT000 and passing one
*   would mean a CORRESPONDING just to satisfy the signature.
  methods NAME_OF
    importing IV_ORG   type STRING
              IV_FIRST type STRING
              IV_LAST  type STRING
    returning value(RV) type STRING .

*   Back to page one. Two callers - the Search press and the Clear press -
*   so it is a method before it has two, not after.
  methods RESET_PAGE
    importing IO_CTX type ref to ZIF_RAK_JOURNEY .
ENDCLASS.



CLASS ZCL_DEMO_BP_PAGE_LOGIC IMPLEMENTATION.


  METHOD name_of.
    rv = condense( iv_org ).
    IF rv IS INITIAL.
      rv = condense( |{ iv_first } { iv_last }| ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_after_field.
*   A SEARCH BUTTON, BECAUSE TYPING DOES NOT ROUND-TRIP.
*
*   This is not a preference. OPT_EVT( ) raises CHANGE on a TYPED control
*   only when a ZRAK_T_JNY_RULE names that field as SRC_FIELD, and the
*   reason is documented at that method: a round trip on every blur
*   re-renders the view and drops focus, so the first Tab out of a text
*   field appears to do nothing. Without a rule or a button, a citizen
*   types "test", nothing happens, and the list they are looking at is
*   still the one from the last event - which is exactly what it looked
*   like.
*
*   THE BUTTON IS THE BETTER OF THE TWO OPT-INS. A rule row would make
*   every blur a round trip and bring the focus problem with it; a button
*   makes the search deliberate, which is what a citizen expects from a
*   search box and what JP1 already does on screen.
    CHECK to_upper( is_field-name ) = to_upper( c_group ).

    DATA(lo_row) = io_view->hbox( class = 'sapUiSmallMarginBegin sapUiSmallMarginBottom' ).

    lo_row->button( text  = 'Search'
                    type  = 'Emphasized'
                    icon  = 'sap-icon://search'
                    class = 'sapUiTinyMarginEnd'
                    press = io_ctx->event( 'BPSEARCH' ) ).

    lo_row->button( text  = 'Clear'
                    icon  = 'sap-icon://clear-filter'
                    press = io_ctx->event( 'BPCLEAR' ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.
*   IO_CTX->EVENT( ) EMITS HPOP_, WHICH LANDS HERE EVEN FROM THE MAIN
*   VIEW - the engine has one dispatch for a handler-drawn button and it
*   is this one, popup or not. D001's partner search uses the same route.
*
*   CP, NOT AN OFFSET. IV_EVENT is a STRING and these names are short;
*   iv_event(8) on a six-character name raises CX_SY_RANGE_OUT_OF_BOUNDS,
*   which the engine turns into an unexplained warning on a successful
*   press. A pattern match cannot run off the end.
*   IF / ELSEIF, NOT A CASE ON ABAP_TRUE. WHEN takes a constant, so
*   WHEN xsdbool( iv_event CP '...' ) is refused with "string calculation
*   not permitted here" - a message that names neither CASE nor the
*   pattern match. A CASE over iv_event itself would work but only with
*   equality, and equality is what the CP is here to avoid.
    IF iv_event CP 'BPSEARCH'.
      reset_page( io_ctx ).

    ELSEIF iv_event CP 'BPCLEAR'.
      io_ctx->set_val( iv_name = c_find  iv_value = `` ).
      io_ctx->set_val( iv_name = c_group iv_value = `` ).
*     AND THE PICK WITH THEM. Leaving BP_SEL set would keep the address
*     table showing a partner that is no longer in the list.
      io_ctx->set_val( iv_name = c_sel   iv_value = `` ).
      reset_page( io_ctx ).

    ELSE.
      super->zif_rak_journey_logic~on_popup_event( io_ctx   = io_ctx
                                                   iv_id    = iv_id
                                                   iv_event = iv_event ).
    ENDIF.
  ENDMETHOD.


  METHOD reset_page.
*   BACK TO PAGE ONE, on a large negative step rather than a reset method:
*   PAGE_MOVE( ) clamps at zero, so this is the same floor a citizen
*   pressing Back repeatedly would reach and there is no second entry
*   point to keep in step with the first.
    CAST zcl_rak_journey_engine( io_ctx )->page_move( iv_field = c_list
                                                      iv_dir   = -999999 ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
*   TYPING A NEW SEARCH PUTS YOU BACK ON PAGE ONE.
*
*   Without this a citizen on page 7 who types a name is answered with an
*   empty page: the offset is still 150 and the filtered set has eleven
*   rows. Nothing errors, the pager just says 151-150 and the table is
*   blank - the failure looks like "search is broken" rather than "you are
*   past the end".
*
*   PAGE_MOVE( ) with a large negative step rather than a reset method,
*   because the engine clamps at zero and there is no state here worth a
*   second entry point. It is the same clamp a citizen pressing Back
*   repeatedly would hit.
*   KEPT, THOUGH THE BUTTON IS THE PATH THAT RUNS TODAY. ON_CHANGE( )
*   fires for a typed field only where a ZRAK_T_JNY_RULE names it as
*   SRC_FIELD - see ON_RENDER_AFTER_FIELD( ) - so this is dead on this
*   journey as configured. It stays because adding such a rule is a
*   supported way to make the search live, and a live search that then
*   answered from page 7 would be the bug this method exists to prevent.
    CHECK to_upper( iv_field ) = to_upper( c_find )
       OR to_upper( iv_field ) = to_upper( c_group ).

    reset_page( io_ctx ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.

    CASE to_upper( iv_name ).

      WHEN 'BP_LIST'.
*       ---- the paged, searched, filtered list ------------------------
*
*       CHAR HOST VARIABLES, NOT STRING. ABAP SQL treats a STRING host
*       variable as a LOB and refuses it in a WHERE expression - "only
*       elementary types for host variables are permitted". The values
*       come off the model as strings and are moved into fixed-length
*       fields for the query.
        DATA lv_like  TYPE c LENGTH 82.
        DATA lv_glike TYPE c LENGTH 12.
        DATA lv_total TYPE i.
        DATA lv_rows  TYPE i.
        DATA lv_off   TYPE i.

        DATA(lv_find)  = to_upper( condense( io_ctx->get_val( c_find ) ) ).
        DATA(lv_group) = to_upper( condense( io_ctx->get_val( c_group ) ) ).

*       A BLANK SEARCH IS '%', NOT A BRANCH. Comparing a host variable to
*       a literal inside the WHERE - ( @lv_find = '' OR ... ) - is the
*       obvious way to make a filter optional and ABAP SQL will not have
*       it. A wildcard that matches everything says the same thing in one
*       clause and needs no expression at all.
        lv_like  = COND #( WHEN lv_find  IS INITIAL THEN '%' ELSE |%{ lv_find }%| ).
        lv_glike = COND #( WHEN lv_group IS INITIAL THEN '%' ELSE lv_group ).

*       NARROWED IN THE DATABASE, NOT AFTER. Windowing a set you have
*       already read whole saves the payload and nothing else; the point
*       of the contract is that the rows beyond the window are never
*       assembled.
        SELECT COUNT(*) FROM but000
         WHERE ( upper( name_org1 ) LIKE @lv_like
              OR upper( name_last ) LIKE @lv_like
              OR partner            LIKE @lv_like )
           AND bu_group LIKE @lv_glike
          INTO @lv_total.

        rs_data-total = lv_total.

        rs_data-columns = VALUE #( ( `Partner` ) ( `Name` ) ( `Type` ) ( `Group` ) ).

        lv_rows = COND #( WHEN iv_page_size > 0 THEN iv_page_size ELSE 200 ).
        lv_off  = iv_offset.

*       THE CLAUSE ORDER IS THE POINT HERE. ABAP SQL wants
*       ... ORDER BY ... INTO TABLE @lt UP TO @n ROWS OFFSET @o - the INTO
*       after the ORDER BY, and OFFSET after UP TO. Written the other way
*       round it reports "OFFSET is not allowed here", which names the
*       keyword rather than the ordering.
*
*       AND THE ORDER MUST BE STABLE, or page 2 repeats a row page 1
*       already showed. PARTNER is the key, so it is both stable and the
*       order a citizen expects.
        SELECT partner, type, bu_group, name_org1, name_first, name_last
          FROM but000
         WHERE ( upper( name_org1 ) LIKE @lv_like
              OR upper( name_last ) LIKE @lv_like
              OR partner            LIKE @lv_like )
           AND bu_group LIKE @lv_glike
         ORDER BY partner
          INTO TABLE @DATA(lt_bp)
            UP TO @lv_rows ROWS
            OFFSET @lv_off.

        LOOP AT lt_bp INTO DATA(ls_bp).
          APPEND VALUE #( ( CONV string( ls_bp-partner ) )
                          ( name_of( iv_org   = CONV #( ls_bp-name_org1 )
                                     iv_first = CONV #( ls_bp-name_first )
                                     iv_last  = CONV #( ls_bp-name_last ) ) )
                          ( CONV string( ls_bp-type ) )
                          ( CONV string( ls_bp-bu_group ) ) ) TO rs_data-rows.
        ENDLOOP.

      WHEN 'BP_ADDR'.
*       ---- the linked table ------------------------------------------
*       Driven by the row picked on BP_LIST. Empty until something is
*       picked, which is correct rather than a gap: an address list with
*       no partner chosen would be every address in the system.
        DATA(lv_sel) = condense( io_ctx->get_val( c_sel ) ).
        IF lv_sel IS INITIAL.
          RETURN.
        ENDIF.

        rs_data-columns = VALUE #( ( `Address` ) ( `Street` ) ( `City` ) ( `Country` ) ( `Post code` ) ).

        DATA(lv_bp) = CONV bu_partner( |{ lv_sel ALPHA = IN }| ).

*       BUT020 IS THE PARTNER-TO-ADDRESS LINK and ADRC holds the address
*       itself. Both are read with the five most standard components each
*       carries; this is a demo, and a demo that will not activate teaches
*       nothing.
*       POST_CODE1, NOT POST_CODE. ADRC carries POST_CODE1 (city),
*       POST_CODE2 (PO box) and POST_CODE3 (company) - there is no bare
*       POST_CODE, which is the kind of fact that only a syntax error
*       teaches when the table cannot be opened from the repository.
        SELECT a~addrnumber, c~street, c~city1, c~country, c~post_code1
          FROM but020 AS a
          INNER JOIN adrc AS c ON c~addrnumber = a~addrnumber
         WHERE a~partner = @lv_bp
         ORDER BY a~addrnumber
          INTO TABLE @DATA(lt_ad).

        LOOP AT lt_ad INTO DATA(ls_ad).
          APPEND VALUE #( ( CONV string( ls_ad-addrnumber ) )
                          ( CONV string( ls_ad-street ) )
                          ( CONV string( ls_ad-city1 ) )
                          ( CONV string( ls_ad-country ) )
                          ( CONV string( ls_ad-post_code1 ) ) ) TO rs_data-rows.
        ENDLOOP.

*       THE TOTAL IS THE ROW COUNT HERE, and saying so is not the same as
*       leaving it blank. This table is never paged - a partner has a
*       handful of addresses - so the count it reports is complete.
        rs_data-total = lines( rs_data-rows ).

      WHEN OTHERS.
        rs_data = super->zif_rak_journey_logic~get_table( io_ctx       = io_ctx
                                                          iv_name      = iv_name
                                                          iv_offset    = iv_offset
                                                          iv_page_size = iv_page_size ).
    ENDCASE.

  ENDMETHOD.
ENDCLASS.
