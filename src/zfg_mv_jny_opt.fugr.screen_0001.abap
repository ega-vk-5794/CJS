PROCESS BEFORE OUTPUT.
  MODULE liste_initialisieren.
  module SORT_extract.
  LOOP AT extract WITH CONTROL
   tctrl_zmv_jny_opt CURSOR nextline.
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
      FIELD zmv_jny_opt-opt_key .
      FIELD zmv_jny_opt-seqnr .
      FIELD zmv_jny_opt-opt_text .
      FIELD zmv_jny_opt-opt_text_ar .
      MODULE set_update_flag ON CHAIN-REQUEST.
    ENDCHAIN.
    FIELD vim_marked MODULE liste_mark_checkbox.
    CHAIN.
      FIELD zmv_jny_opt-opt_key .
      MODULE liste_update_liste.
    ENDCHAIN.
  ENDLOOP.
  MODULE liste_after_loop.
