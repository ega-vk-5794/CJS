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
    METHODS unclip CHANGING cs_data TYPE zif_rak_journey=>ty_table.
ENDCLASS.



CLASS ZCL_RAK_EC02_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~get_table.
  rs_data = io_ctx->get_backend_table( iv_name ).
  unclip( CHANGING cs_data = rs_data ).
ENDMETHOD.


METHOD unclip.
*&---------------------------------------------------------------------*
*& THE DESCRIPTION WAS BEING CUT AT 250 CHARACTERS, AND NOT BY CJS.
*&
*& The BAdI answers a table read into /QNV/SBUILD_UI_TABLE_CUST_TT, whose
*& FIELDn components are fixed-width DDIC characters. It assigns a STRING
*& into one of them - the whole complaint description - and ABAP truncates
*& silently at the assignment. By the time the bridge reads the row the
*& tail is gone, so nothing downstream can recover it: every CJS cell is
*& already a STRING, and no column width, MAXLEN or renderer change makes
*& any difference.
*&
*& That structure is legacy and must not be widened. On the WebDynpro
*& screen this never showed, because the old screen bound the detail
*& record's own string field rather than reading the description out of
*& the flattened table - the cap simply never applied to it.
*&
*& So the fix is to do what the old screen did. ZCL_EGA_CJ_ECOMP_ABS
*& parks the full detail record in GS_DATA, the same public static EC01
*& and EC05 already read CASEID from, and the untruncated description is
*& still in there. This puts it back into the cell the bridge clipped.
*&
*& NO COLUMN NAME AND NO COLUMN INDEX. The obvious version of this reads
*& cell 4, or the column called DESCRIPTION. Both are wrong here: the
*& order of a backend table's cells comes from LIST_SEQUENCE in
*& /QNV/SB_UI_DEFIN and not from the CJS spec, so a column added on the
*& legacy side shifts every index after it, and a table with no
*& DEFAULT_VAL spec has no column names at all - its columns are FIELD1..N.
*&
*& The test used instead needs neither: a cell that was truncated is a
*& PREFIX of the value it was truncated from. So for each long cell, look
*& for a field of GS_DATA whose text starts with that cell and is longer.
*& That identifies the clipped column by what happened to it, which is
*& the one property that cannot drift.
*&
*& It also fixes any other clipped column for free, which is the point -
*& DESCRIPTION is simply the first one long enough to notice.
*&---------------------------------------------------------------------*
  FIELD-SYMBOLS <comp> TYPE any.
  DATA lv_full TYPE string.
  DATA lv_ix   TYPE i.
  DATA lv_kind TYPE c LENGTH 1.

  LOOP AT cs_data-rows ASSIGNING FIELD-SYMBOL(<row>).
    LOOP AT <row> ASSIGNING FIELD-SYMBOL(<cell>).

      DATA(lv_len) = strlen( <cell> ).
*     Only a cell sitting near the cap can be a truncated one. The cap is
*     250; the bridge CONDENSEs the cell on the way in, so a clipped value
*     arrives a few characters short of it - the 250-character original in
*     the reported case measured 249 on screen. 240 is comfortably below
*     any of that and comfortably above every other column on these two
*     journeys, so a complaint id or a mobile number is never scanned.
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

*       Text only. GS_DATA carries dates, numbers and - depending on the
*       release - inner tables, and CONV string( ) on a deep component is
*       a dump, not a conversion.
        DESCRIBE FIELD <comp> TYPE lv_kind.
        IF lv_kind <> 'C' AND lv_kind <> 'g'.
          CONTINUE.
        ENDIF.

*       CONDENSE on this side too, because the bridge condensed the cell.
*       Without it a description with two spaces anywhere in its first 240
*       characters fails the prefix test and silently keeps its short form.
        lv_full = condense( CONV string( <comp> ) ).

        IF strlen( lv_full ) > lv_len
           AND substring( val = lv_full off = 0 len = lv_len ) = <cell>.
          <cell> = lv_full.
          EXIT.
        ENDIF.
      ENDDO.

    ENDLOOP.
  ENDLOOP.
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
