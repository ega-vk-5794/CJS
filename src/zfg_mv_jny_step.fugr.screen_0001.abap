PROCESS BEFORE OUTPUT.
  MODULE liste_initialisieren.
  MODULE sort_table.
  LOOP AT extract WITH CONTROL
   tctrl_zmv_jny_step CURSOR nextline.
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
      FIELD zmv_jny_step-step_id .
      FIELD zmv_jny_step-seqnr .
      FIELD zmv_jny_step-title .
      FIELD zmv_jny_step-icon .
      FIELD zmv_jny_step-columns .
      FIELD zmv_jny_step-title_ar .
      FIELD zmv_jny_step-bknd_screen .
      FIELD zmv_jny_step-active .
      FIELD zmv_jny_step-next_requires .
      FIELD zmv_jny_step-no_forward .
      MODULE set_update_flag ON CHAIN-REQUEST.
    ENDCHAIN.
    FIELD vim_marked MODULE liste_mark_checkbox.
    CHAIN.
      FIELD zmv_jny_step-step_id .
      MODULE liste_update_liste.
    ENDCHAIN.
  ENDLOOP.
  MODULE liste_after_loop.
