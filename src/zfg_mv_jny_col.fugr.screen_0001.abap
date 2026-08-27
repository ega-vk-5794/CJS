PROCESS BEFORE OUTPUT.
  MODULE liste_initialisieren.
  MODULE sort_extract.
  LOOP AT extract WITH CONTROL
   tctrl_zmv_jny_col CURSOR nextline.
    MODULE liste_show_liste.
  ENDLOOP.
  MODULE fill_substflds.
*
PROCESS AFTER INPUT.
  MODULE liste_exit_command AT EXIT-COMMAND.
  MODULE liste_before_loop.
  LOOP AT extract.
    MODULE liste_init_workarea.
    CHAIN.
      FIELD zmv_jny_col-col_name .
      FIELD zmv_jny_col-seqnr .
      FIELD zmv_jny_col-zlabel .
      FIELD zmv_jny_col-zlabel_ar .
      FIELD zmv_jny_col-ctrl .
      FIELD zmv_jny_col-shlp .
      FIELD zmv_jny_col-rollname .
      FIELD zmv_jny_col-width .
      FIELD zmv_jny_col-align .
      FIELD zmv_jny_col-hidden .
      FIELD zmv_jny_col-pinned .
      FIELD zmv_jny_col-readonly .
      FIELD zmv_jny_col-required .
      FIELD zmv_jny_col-decimals .
      FIELD zmv_jny_col-maxlen .
      FIELD zmv_jny_col-total .
      MODULE set_update_flag ON CHAIN-REQUEST.
    ENDCHAIN.
    FIELD vim_marked MODULE liste_mark_checkbox.
    CHAIN.
      FIELD zmv_jny_col-col_name .
      MODULE liste_update_liste.
    ENDCHAIN.
  ENDLOOP.
  MODULE liste_after_loop.
