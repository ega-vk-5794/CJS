REPORT zrak_cj_txt_qa.

TABLES sscrfields.

SELECT-OPTIONS s_jrn FOR sy-lisel NO INTERVALS.

PARAMETERS p_detl RADIOBUTTON GROUP g1 DEFAULT 'X'.
PARAMETERS p_summ RADIOBUTTON GROUP g1.
PARAMETERS p_expt RADIOBUTTON GROUP g1.
*   THE FOURTH MODE, AND THE ONE THAT WAS MISSING. ZCL_RAK_CJ_TXT_IO has
*   had IMPORT( ) for as long as it has had EXPORT( ) and nothing ever
*   called it, so the round trip stopped half way: a journey's texts could
*   be exported for a translator and there was no way to put the Arabic
*   back except field by field in the Studio.
PARAMETERS p_impt RADIOBUTTON GROUP g1.

PARAMETERS p_path TYPE string LOWER CASE DEFAULT 'C:\temp\cjs_texts.xls'.

*   TEST RUN IS THE DEFAULT, and it is the same discipline as
*   ZRAK_CJ_ATT_PURGE: an import rewrites the wording of every journey in
*   the file, and a mistyped path or a spreadsheet saved in the wrong
*   format should show a log rather than change anything. IMPORT( ) itself
*   already takes IV_COMMIT and defaults it false - it builds the full log
*   either way and only writes at the end - so the test run reports exactly
*   what the real one would do.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.


CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.

    CLASS-METHODS run.

  PRIVATE SECTION.

    CLASS-METHODS journeys
      RETURNING VALUE(rt_journey) TYPE zif_rak_cj_text_src=>ty_t_journey.

    CLASS-METHODS show_detail
      IMPORTING it_find TYPE zcl_rak_cj_txt_qa=>ty_t_find.

    CLASS-METHODS show_summary
      IMPORTING it_stat TYPE zcl_rak_cj_txt_qa=>ty_t_stat.

    CLASS-METHODS do_export
      IMPORTING it_journey TYPE zif_rak_cj_text_src=>ty_t_journey.

    CLASS-METHODS do_import.

    CLASS-METHODS show_import
      IMPORTING it_log TYPE zcl_rak_cj_txt_io=>ty_t_imp_log.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD journeys.
    LOOP AT s_jrn ASSIGNING FIELD-SYMBOL(<ls_r>) WHERE sign = 'I' AND option = 'EQ'.
      APPEND CONV zif_rak_cj_text_src=>ty_key( <ls_r>-low ) TO rt_journey.
    ENDLOOP.
  ENDMETHOD.


  METHOD show_detail.

    IF it_find IS INITIAL.
      MESSAGE 'Scan completed with no findings across the selected journeys.' TYPE 'S'.
      RETURN.
    ENDIF.

    DATA lt TYPE zcl_rak_cj_txt_qa=>ty_t_find.
    lt = it_find.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).
        lo_alv->get_display_settings( )->set_list_header( |CJS text findings: { lines( lt ) }| ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD show_summary.

    DATA lt TYPE zcl_rak_cj_txt_qa=>ty_t_stat.
    lt = it_stat.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).
        lo_alv->get_display_settings( )->set_list_header( |CJS translation coverage| ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx).
        MESSAGE lx->get_text( ) TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD do_export.

    DATA lt_bin  TYPE solix_tab.
    DATA lv_len  TYPE i.

    DATA(lo_io)   = NEW zcl_rak_cj_txt_io( ).
    DATA(lv_xstr) = lo_io->export( it_journey ).

    lv_len = xstrlen( lv_xstr ).
    lt_bin = cl_bcs_convert=>xstring_to_solix( lv_xstr ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING bin_filesize = lv_len
                filename     = p_path
                filetype     = 'BIN'
      CHANGING  data_tab     = lt_bin
      EXCEPTIONS OTHERS      = 1 ).

    IF sy-subrc = 0.
      MESSAGE |Exported to { p_path }| TYPE 'S'.
    ELSE.
      MESSAGE 'Download failed' TYPE 'E'.
    ENDIF.

  ENDMETHOD.


  METHOD do_import.

    DATA lt_bin TYPE solix_tab.
    DATA lv_len TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING filename   = p_path
                filetype   = 'BIN'
      IMPORTING filelength = lv_len
      CHANGING  data_tab   = lt_bin
      EXCEPTIONS OTHERS    = 1 ).

    IF sy-subrc <> 0.
      MESSAGE |Could not read { p_path }| TYPE 'E'.
    ENDIF.

    DATA(lv_xstr) = cl_bcs_convert=>solix_to_xstring( it_solix = lt_bin iv_size = lv_len ).

*   NO JOURNEY FILTER ON AN IMPORT, deliberately. The file names its own
*   journeys in column 1 and IMPORT( ) rejects any key the system does not
*   have, so the selection screen's journey list would be a second filter
*   that can only disagree with the file. Export a subset, translate it,
*   import it back - the subset is decided once, at export.
    DATA(lo_io)  = NEW zcl_rak_cj_txt_io( ).
    DATA(lt_log) = lo_io->import( iv_xstr   = lv_xstr
                                  iv_commit = xsdbool( p_test = abap_false ) ).

    IF lt_log IS INITIAL.
      MESSAGE 'Nothing to change - every text in the file already matches the system' TYPE 'S'.
      RETURN.
    ENDIF.

    show_import( lt_log ).

  ENDMETHOD.


  METHOD show_import.

    DATA(lt_log) = it_log.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt_log ).
        lo_alv->get_functions( )->set_all( ).
        lo_alv->get_columns( )->set_optimize( ).

*       THE TITLE CARRIES THE MODE, because the two runs otherwise produce
*       an identical-looking list and the only difference is whether the
*       database moved. Counting CHANGE rows rather than all rows: SKIP and
*       REJECT lines are reported and written nowhere.
        DATA(lv_chg) = REDUCE i( INIT n = 0 FOR ls IN it_log
                                 NEXT n = COND #( WHEN ls-action = 'CHANGE' THEN n + 1 ELSE n ) ).
        lo_alv->get_display_settings( )->set_list_header(
          COND #( WHEN p_test = abap_true
                  THEN |TEST RUN - { lv_chg } text(s) WOULD change. Nothing written.|
                  ELSE |{ lv_chg } text(s) written.| ) ).

        lo_alv->display( ).
      CATCH cx_salv_msg.
        MESSAGE 'ALV could not be displayed' TYPE 'E'.
    ENDTRY.

  ENDMETHOD.


  METHOD run.

*   IMPORT FIRST, BEFORE THE JOURNEY LIST IS RESOLVED. The file names its
*   own journeys, so an import needs neither the selection screen's list
*   nor the "text source returned no journeys" guard below - which would
*   otherwise refuse the one mode that can put translations INTO a system
*   that has none.
    IF p_impt = abap_true.
      do_import( ).
      RETURN.
    ENDIF.

    DATA(lt_journey) = journeys( ).
    DATA(lo_qa)      = NEW zcl_rak_cj_txt_qa( ).

    IF lt_journey IS INITIAL.
      lt_journey = lo_qa->available_journeys( ).
      IF lt_journey IS INITIAL.
        MESSAGE 'Text source returned no journeys. Check c_tab and the field constants in ZCL_RAK_CJ_TEXT_SRC_STD.' TYPE 'E'.
      ENDIF.
    ENDIF.

    CASE abap_true.
      WHEN p_expt.
        IF lt_journey IS INITIAL.
          MESSAGE 'Select at least one journey to export' TYPE 'E'.
        ENDIF.
        do_export( lt_journey ).
      WHEN p_summ.
        show_summary( lo_qa->summarise( lt_journey ) ).
      WHEN OTHERS.
        show_detail( lo_qa->scan( lt_journey ) ).
    ENDCASE.

  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  lcl_app=>run( ).
