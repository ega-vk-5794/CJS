class ZCL_RAK_EC06_LOGIC definition
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

*   Walks GS_DATA to any depth looking for the value the clipped cell
*   is the beginning of. Recursive - see the method for why a flat
*   scan was not enough.
    METHODS deep_scan
      IMPORTING iv_cell  TYPE string
                iv_data  TYPE any
                iv_depth TYPE i
      CHANGING  cv_found TYPE string.
ENDCLASS.



CLASS ZCL_RAK_EC06_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~get_table.
  rs_data = io_ctx->get_backend_table( iv_name ).
  unclip( CHANGING cs_data = rs_data ).
ENDMETHOD.


METHOD deep_scan.
*  Structures by component, tables by row. Recursive because the value is
*  NOT a field of GS_DATA: on the reported complaint it was found at
*  GS_DATA-COMPLAINT_DETAILS[1]-COMPLAINERNAME, two levels down and
*  inside an inner table. A flat scan of GS_DATA's own 41 components
*  found nothing and reported its longest text as fifteen characters,
*  which is how close this came to being written off as unrecoverable.
*
*  Depth is capped at five and each table is cut at fifty rows. This runs
*  while a citizen waits, and an unbounded walk of a record whose shape
*  we do not control is not something to set going on a live screen.
  IF cv_found IS NOT INITIAL OR iv_depth > 5.
    RETURN.
  ENDIF.

  DATA(lo_t) = cl_abap_typedescr=>describe_by_data( iv_data ).

  CASE lo_t->kind.

    WHEN cl_abap_typedescr=>kind_elem.
*     Text only. A date or a packed number cannot be the description, and
*     CONV string( ) on some of them is a dump rather than a conversion.
      IF lo_t->type_kind <> cl_abap_typedescr=>typekind_char
         AND lo_t->type_kind <> cl_abap_typedescr=>typekind_string.
        RETURN.
      ENDIF.
      DATA(lv_v) = condense( CONV string( iv_data ) ).
*     THE MATCH IS ON CONTENT, NOT ON A NAME, and on this journey that is
*     not a stylistic preference. The value was found in a component
*     called COMPLAINERNAME - whatever that field was meant to hold, it
*     is carrying the complaint description here. Code that went looking
*     for something called DESCRIPTION would have walked straight past
*     it, and code that hard-codes COMPLAINERNAME breaks the day that
*     mapping is corrected. A truncated cell is a PREFIX of what it was
*     cut from; that stays true under either.
*
*     Both sides are condensed, because the bridge condensed the cell on
*     the way in - without that a description with a double space inside
*     its first 240 characters fails the test and silently keeps its
*     short form.
      IF strlen( lv_v ) > strlen( iv_cell )
         AND substring( val = lv_v off = 0 len = strlen( iv_cell ) ) = iv_cell.
        cv_found = lv_v.
      ENDIF.

    WHEN cl_abap_typedescr=>kind_struct.
      DATA(lo_s) = CAST cl_abap_structdescr( lo_t ).
      LOOP AT lo_s->components INTO DATA(ls_c).
        ASSIGN COMPONENT ls_c-name OF STRUCTURE iv_data TO FIELD-SYMBOL(<x>).
        IF sy-subrc = 0.
          deep_scan( EXPORTING iv_cell  = iv_cell
                               iv_data  = <x>
                               iv_depth = iv_depth + 1
                     CHANGING  cv_found = cv_found ).
        ENDIF.
      ENDLOOP.

    WHEN cl_abap_typedescr=>kind_table.
      FIELD-SYMBOLS <tab> TYPE ANY TABLE.
      ASSIGN iv_data TO <tab>.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      DATA lv_n TYPE i.
      lv_n = 0.
      LOOP AT <tab> ASSIGNING FIELD-SYMBOL(<line>).
        lv_n = lv_n + 1.
        IF lv_n > 50.
          EXIT.
        ENDIF.
        deep_scan( EXPORTING iv_cell  = iv_cell
                             iv_data  = <line>
                             iv_depth = iv_depth + 1
                   CHANGING  cv_found = cv_found ).
      ENDLOOP.

    WHEN OTHERS.
      RETURN.

  ENDCASE.
ENDMETHOD.


METHOD unclip.
*&---------------------------------------------------------------------*
*& THE DESCRIPTION IS CUT AT 250 CHARACTERS, AND NOT BY CJS.
*&
*& Confirmed in the debugger: ET_DATA_TABLE[1]-FIELD4 in
*& ZFM_EGA_CJ_FW_READ_TABLE_DATAN is C(250), absolute type
*& /QNV/SBUILD_TABLE_COLUMN, and it already holds the cut text there. The
*& BAdI assigns a STRING into that fixed-width component and ABAP
*& truncates silently at the assignment, so the tail is gone before CJS
*& is called at all. Every CJS cell is already a STRING - no column
*& width, MAXLEN or renderer change makes the slightest difference, and
*& that structure is legacy and is not widened.
*&
*& On WebDynpro this never showed, because the old screen bound the
*& detail record rather than reading the description out of the
*& flattened table.
*&
*& So this reads the detail record too. ZCL_EGA_CJ_ECOMP_ABS parks it in
*& GS_DATA - the public static EC01 and EC05 already read CASEID from -
*& and the untruncated text is still in there, two levels down, at
*& GS_DATA-COMPLAINT_DETAILS[1]-COMPLAINERNAME on the reported case.
*&
*& NO COLUMN INDEX, NO COLUMN NAME, NO FIELD NAME. Cell order comes from
*& LIST_SEQUENCE in /QNV/SB_UI_DEFIN rather than from the CJS spec, so an
*& index drifts the moment a column is added on the legacy side, and a
*& table with no DEFAULT_VAL spec has no column names at all. On the
*& source side the field is called COMPLAINERNAME, which is not what it
*& is holding - so a name-driven search would have missed it, and
*& hard-coding that name would break when the mapping is fixed.
*&
*& What is used instead survives both: a truncated cell is a PREFIX of
*& the value it was cut from. The cell is identified by what happened to
*& it, which is the one property that cannot drift - and any other
*& clipped column on these journeys is repaired for free.
*&---------------------------------------------------------------------*
  DATA lv_found TYPE string.

  LOOP AT cs_data-rows ASSIGNING FIELD-SYMBOL(<row>).
    LOOP AT <row> ASSIGNING FIELD-SYMBOL(<cell>).

*     Only a cell sitting near the cap can be a truncated one. The cap is
*     250 and the bridge condenses on the way in, so a clipped value
*     arrives a few characters short of it - the reported one measured
*     249. Below 240 nothing is scanned, which keeps a complaint id and a
*     mobile number out of the walk entirely.
      IF strlen( <cell> ) < 240.
        CONTINUE.
      ENDIF.

      CLEAR lv_found.
      deep_scan( EXPORTING iv_cell  = <cell>
                           iv_data  = zcl_ega_cj_ecomp_abs=>gs_data
                           iv_depth = 0
                 CHANGING  cv_found = lv_found ).

      IF lv_found IS NOT INITIAL.
        <cell> = lv_found.
      ENDIF.

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
                           'press Back to look up another suggestion.' ) ).
  ENDMETHOD.
ENDCLASS.
