REPORT zrak_cj_txt_qa.

TABLES sscrfields.

SELECT-OPTIONS s_jrn FOR sy-lisel NO INTERVALS.

PARAMETERS p_detl RADIOBUTTON GROUP g1 DEFAULT 'X'.
PARAMETERS p_summ RADIOBUTTON GROUP g1.
PARAMETERS p_expt RADIOBUTTON GROUP g1.

PARAMETERS p_path TYPE string LOWER CASE DEFAULT 'C:\temp\cjs_texts.xls'.


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


  METHOD run.

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
