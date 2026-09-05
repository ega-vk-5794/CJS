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
    METHODS unclip IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                   CHANGING  cs_data TYPE zif_rak_journey=>ty_table.

*   Walks GS_DATA to any depth looking for the value the clipped cell
*   is the beginning of. Recursive - see the method for why a flat
*   scan was not enough.
    METHODS deep_scan
      IMPORTING iv_cell  TYPE string
                iv_path  TYPE string
                iv_data  TYPE any
                iv_depth TYPE i
      CHANGING  cv_found TYPE string
                cv_path  TYPE string
                cv_best  TYPE i
                cv_bpath TYPE string.
ENDCLASS.



CLASS ZCL_RAK_EC06_LOGIC IMPLEMENTATION.


METHOD zif_rak_journey_logic~get_table.
  rs_data = io_ctx->get_backend_table( iv_name ).
  unclip( EXPORTING io_ctx = io_ctx CHANGING cs_data = rs_data ).
ENDMETHOD.


METHOD deep_scan.
*  Recursive because the flat scan already answered, and the answer was
*  no: GS_DATA has 41 text components and the longest holds 15
*  characters. Whatever else that record carries, the description is not
*  a field of it - so either it sits inside an inner structure or table,
*  or it is not in GS_DATA at all. A scan that goes down finds the first
*  case and PROVES the second; a flat one could do neither.
*
*  Depth is capped and tables are cut at 50 lines. This runs while a
*  citizen waits, and an unbounded walk of an unknown record is not
*  something to set going on a live screen.
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
      DATA(lv_l) = strlen( lv_v ).
      IF lv_l > cv_best.
        cv_best  = lv_l.
        cv_bpath = iv_path.
      ENDIF.
*     The cell is a PREFIX of what it was cut from - the one property of
*     a truncated value that no column reordering can change. Both sides
*     are condensed, because the bridge condensed the cell on the way in.
      IF lv_l > strlen( iv_cell )
         AND substring( val = lv_v off = 0 len = strlen( iv_cell ) ) = iv_cell.
        cv_found = lv_v.
        cv_path  = iv_path.
      ENDIF.

    WHEN cl_abap_typedescr=>kind_struct.
      DATA(lo_s) = CAST cl_abap_structdescr( lo_t ).
      LOOP AT lo_s->components INTO DATA(ls_c).
        ASSIGN COMPONENT ls_c-name OF STRUCTURE iv_data TO FIELD-SYMBOL(<x>).
        IF sy-subrc = 0.
          deep_scan( EXPORTING iv_cell  = iv_cell
                               iv_path  = |{ iv_path }-{ ls_c-name }|
                               iv_data  = <x>
                               iv_depth = iv_depth + 1
                     CHANGING  cv_found = cv_found
                               cv_path  = cv_path
                               cv_best  = cv_best
                               cv_bpath = cv_bpath ).
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
                             iv_path  = |{ iv_path }[{ lv_n }]|
                             iv_data  = <line>
                             iv_depth = iv_depth + 1
                   CHANGING  cv_found = cv_found
                             cv_path  = cv_path
                             cv_best  = cv_best
                             cv_bpath = cv_bpath ).
      ENDLOOP.

    WHEN OTHERS.
      RETURN.

  ENDCASE.
ENDMETHOD.


METHOD unclip.
*&---------------------------------------------------------------------*
*& THE DESCRIPTION IS CUT AT 250 CHARACTERS, AND NOT BY CJS.
*&
*& The BAdI assigns a STRING into a FIELDn of
*& /QNV/SBUILD_UI_TABLE_CUST_TT, whose components are fixed-width DDIC
*& characters, and ABAP truncates silently at that assignment. By the
*& time the bridge reads the row the tail is gone - every CJS cell is
*& already a STRING, so no column width, MAXLEN or renderer change makes
*& any difference. That structure is legacy and is not widened here.
*&
*& On WebDynpro this never showed, because the old screen bound the
*& detail record's own string field instead of reading the description
*& out of the flattened table. This looks for that field.
*&
*& NO COLUMN NAME, NO COLUMN INDEX, AND NOW NO FIELD NAME EITHER. Cell
*& order comes from LIST_SEQUENCE in /QNV/SB_UI_DEFIN rather than from
*& the CJS spec, so an index drifts the moment a column is added on the
*& legacy side, and a table with no DEFAULT_VAL spec has no column names
*& at all. The first version searched GS_DATA's own fields with the same
*& prefix test and found nothing - 41 text components, longest 15
*& characters - so the search now goes down through inner structures and
*& tables too, identifying the value by what happened to it rather than
*& by where anybody expects it to live.
*&
*& ---- TEMPORARY PROBE - REMOVE BEFORE THIS GOES ANYWHERE NEAR LIVE ----
*& The probe reports the PATH now. A hit names the component to read
*& directly next time; a miss is evidence the text is not in GS_DATA at
*& any depth, which means asking ZCL_EGA_CJ_ECOMP_ABS for it rather than
*& hoping it was left lying about. It renders at the BOTTOM of the page,
*& after the footer.
*&---------------------------------------------------------------------*
  DATA lv_cells TYPE i.
  DATA lv_max   TYPE i.
  DATA lv_hit   TYPE i.
  DATA lv_found TYPE string.
  DATA lv_path  TYPE string.
  DATA lv_best  TYPE i.
  DATA lv_bpath TYPE string.

  CLEAR: lv_cells, lv_max, lv_hit, lv_best.

  LOOP AT cs_data-rows ASSIGNING FIELD-SYMBOL(<row>).
    LOOP AT <row> ASSIGNING FIELD-SYMBOL(<cell>).

      lv_cells = lv_cells + 1.
      DATA(lv_len) = strlen( <cell> ).
      IF lv_len > lv_max.
        lv_max = lv_len.
      ENDIF.

*     Only a cell sitting near the cap can be a truncated one. The cap is
*     250 and the bridge condenses on the way in, so a clipped value
*     arrives a few characters short of it.
      IF lv_len < 240.
        CONTINUE.
      ENDIF.

      CLEAR: lv_found, lv_path.
      deep_scan( EXPORTING iv_cell  = <cell>
                           iv_path  = `GS_DATA`
                           iv_data  = zcl_ega_cj_ecomp_abs=>gs_data
                           iv_depth = 0
                 CHANGING  cv_found = lv_found
                           cv_path  = lv_path
                           cv_best  = lv_best
                           cv_bpath = lv_bpath ).

      IF lv_found IS NOT INITIAL.
        <cell> = lv_found.
        lv_hit = lv_hit + 1.
      ENDIF.

    ENDLOOP.
  ENDLOOP.

* ---- TEMPORARY PROBE - REMOVE WITH THE NOTE ABOVE ----
  DATA(lv_tail) = COND string( WHEN lv_path IS NOT INITIAL
                               THEN | · FOUND at { lv_path }| ELSE `` ).
  io_ctx->add_msg(
    iv_type = COND string( WHEN lv_hit > 0 THEN `Success` ELSE `Information` )
    iv_text = |UNCLIP deep · rows { lines( cs_data-rows ) } · cells { lv_cells }| &&
              | · longest cell { lv_max } · deepest text { lv_best } at { lv_bpath }| &&
              | · replaced { lv_hit }{ lv_tail }| ).
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
