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

*   Puts back the text the bridge could not carry - see the method. The
*   grid arrives with its long cells cut at the width of a legacy DDIC
*   component, and the whole of each one is still sitting in the BAdI's
*   own detail record.
    METHODS unclip IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                   CHANGING  cs_data TYPE zif_rak_journey=>ty_table.
ENDCLASS.



CLASS ZCL_RAK_EC02_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~get_table.
  rs_data = io_ctx->get_backend_table( iv_name ).
  unclip( EXPORTING io_ctx = io_ctx CHANGING cs_data = rs_data ).
ENDMETHOD.


METHOD unclip.
*&---------------------------------------------------------------------*
*& THE DESCRIPTION WAS BEING CUT AT 250 CHARACTERS, AND NOT BY CJS.
*&
*& The BAdI assigns a STRING into a FIELDn of
*& /QNV/SBUILD_UI_TABLE_CUST_TT, whose components are fixed-width DDIC
*& characters, and ABAP truncates silently at that assignment. By the time
*& the bridge reads the row the tail is gone, so nothing downstream can
*& recover it - every CJS cell is already a STRING, and no column width,
*& MAXLEN or renderer change makes any difference. That structure is
*& legacy and is not widened here.
*&
*& On WebDynpro this never showed, because the old screen bound the detail
*& record's own string field rather than reading the description out of
*& the flattened table. This does the same: ZCL_EGA_CJ_ECOMP_ABS parks the
*& whole record in GS_DATA - the public static EC01 and EC05 already read
*& CASEID from - and the untruncated text should still be in it.
*&
*& NO COLUMN NAME AND NO COLUMN INDEX. Cell order comes from LIST_SEQUENCE
*& in /QNV/SB_UI_DEFIN, not from the CJS spec, so an index drifts when a
*& column is added on the legacy side; and a table with no DEFAULT_VAL
*& spec has no column names at all. A truncated cell is a PREFIX of what
*& it was cut from, which is the one property that cannot drift.
*&
*& ---- TEMPORARY PROBE - REMOVE BEFORE THIS GOES ANYWHERE NEAR LIVE ----
*&
*& The first attempt at this fix produced no visible change, and there are
*& four candidates that look identical on screen: the class is not active,
*& GS_DATA is empty when GET_TABLE( ) runs, GS_DATA holds the text but the
*& prefix test misses, or GS_DATA is itself already truncated. Inference
*& cannot separate those and has already cost a round, so the numbers that
*& do are printed instead.
*&
*& It renders at the BOTTOM of the page, after the footer - strips are
*& drawn from MT_MSG before the fields are, so anything added while a
*& field renders missed that loop and the engine draws it separately at
*& the end. Scroll down.
*&
*& How to read it:
*&   no probe line at all  -> the class is not active. Verify by content,
*&                            not by the Class Builder status.
*&   comps=0               -> GS_DATA is empty at this point. The read
*&                            populates it later, or not on this path.
*&   best=249 (or 250)     -> GS_DATA is truncated too. The premise is
*&                            wrong and the text must come from elsewhere.
*&   best=<big> matched=0  -> the text is there and the prefix test missed.
*&---------------------------------------------------------------------*
  FIELD-SYMBOLS <comp> TYPE any.
  DATA lv_full  TYPE string.
  DATA lv_ix    TYPE i.
  DATA lv_kind  TYPE c LENGTH 1.
  DATA lv_comps TYPE i.
  DATA lv_best  TYPE i.
  DATA lv_cells TYPE i.
  DATA lv_max   TYPE i.
  DATA lv_hit   TYPE i.

  CLEAR: lv_comps, lv_best, lv_cells, lv_max, lv_hit.

  LOOP AT cs_data-rows ASSIGNING FIELD-SYMBOL(<row>).
    LOOP AT <row> ASSIGNING FIELD-SYMBOL(<cell>).

      lv_cells = lv_cells + 1.
      DATA(lv_len) = strlen( <cell> ).
      IF lv_len > lv_max.
        lv_max = lv_len.
      ENDIF.

*     Only a cell sitting near the cap can be a truncated one. The cap is
*     250 and the bridge CONDENSEs on the way in, so a clipped value
*     arrives a few characters short of it.
      IF lv_len < 240.
        CONTINUE.
      ENDIF.

      lv_ix = 1.
      DO.
        ASSIGN COMPONENT lv_ix OF STRUCTURE zcl_ega_cj_ecomp_abs=>gs_data TO <comp>.
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        lv_ix = lv_ix + 1.

*       Text only. GS_DATA carries dates, numbers and possibly inner
*       tables, and CONV string( ) on a deep component is a dump.
        DESCRIBE FIELD <comp> TYPE lv_kind.
        IF lv_kind <> 'C' AND lv_kind <> 'g'.
          CONTINUE.
        ENDIF.

        lv_comps = lv_comps + 1.
*       CONDENSE on this side too, because the bridge condensed the cell.
        lv_full = condense( CONV string( <comp> ) ).
        IF strlen( lv_full ) > lv_best.
          lv_best = strlen( lv_full ).
        ENDIF.

        IF strlen( lv_full ) > lv_len
           AND substring( val = lv_full off = 0 len = lv_len ) = <cell>.
          <cell> = lv_full.
          lv_hit = lv_hit + 1.
          EXIT.
        ENDIF.
      ENDDO.

    ENDLOOP.
  ENDLOOP.

* ---- TEMPORARY PROBE - REMOVE WITH THE COMMENT BLOCK ABOVE ----
  io_ctx->add_msg(
    iv_type = 'Information'
    iv_text = |UNCLIP probe · rows { lines( cs_data-rows ) } · cells { lv_cells }| &&
              | · longest cell { lv_max } · GS_DATA text comps { lv_comps }| &&
              | · longest GS_DATA text { lv_best } · replaced { lv_hit }| ).
ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The base method IS the PAID gate - it refuses a submit while PAYFEE is not
*   'PAID'. A redefinition REPLACES it, so without this call the gate is simply
*   not there for this journey. It must come before any CHECK below: a CHECK that
*   fails exits the method, and anything after it would never run.
*
*   Self-guarding - PAY_FIELD_STEP returns -1 when the journey has no PAYFEE
*   field, so this is a no-op on a journey with no payment step.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                         iv_step = iv_step ).

*   Returning a message here stops the step - which is how Submit is
*   blocked without an engine change. It fires on the details step only,
*   so Next from the search step still works normally.
*
*   The wording matters. "Validation failed" would read as the citizen
*   having done something wrong; they have not, and there is nothing for
*   them to correct. This says the journey is finished and they may leave.
    CHECK iv_step = c_last_step.

    rt = VALUE #( BASE rt ( type = 'Information'
                    text = 'This is a tracking service - there is nothing to submit. ' &&
                           'The status above is current. You can close this page, or ' &&
                           'press Back to look up another complaint.' ) ).
  ENDMETHOD.
ENDCLASS.
