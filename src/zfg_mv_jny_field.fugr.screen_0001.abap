PROCESS BEFORE OUTPUT.
  MODULE liste_initialisieren.
  MODULE sort_table.
  LOOP AT extract WITH CONTROL
   tctrl_zmv_jny_field CURSOR nextline.
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
      FIELD zmv_jny_field-field_name .
      FIELD zmv_jny_field-seqnr .
      FIELD zmv_jny_field-zlabel .
      FIELD zmv_jny_field-ftype .
      FIELD zmv_jny_field-placeholder .
      FIELD zmv_jny_field-default_val .
      FIELD zmv_jny_field-fgroup .
      FIELD zmv_jny_field-zsection .
      FIELD zmv_jny_field-fstate .
      FIELD zmv_jny_field-width .
      FIELD zmv_jny_field-hidden .
      FIELD zmv_jny_field-readonly .
      FIELD zmv_jny_field-required .
      FIELD zmv_jny_field-regex .
      FIELD zmv_jny_field-min_len .
      FIELD zmv_jny_field-max_len .
      FIELD zmv_jny_field-min_val .
      FIELD zmv_jny_field-max_val .
      FIELD zmv_jny_field-msg .
      FIELD zmv_jny_field-has_attach .
      FIELD zmv_jny_field-attach_label .
      FIELD zmv_jny_field-rollname .
      FIELD zmv_jny_field-shlp .
      FIELD zmv_jny_field-attach_types .
      FIELD zmv_jny_field-attach_maxmb .
      FIELD zmv_jny_field-attach_multi .
      FIELD zmv_jny_field-zlabel_ar .
      FIELD zmv_jny_field-placeholder_ar .
      FIELD zmv_jny_field-msg_ar .
      FIELD zmv_jny_field-tech_name .
      FIELD zmv_jny_field-domname .
      MODULE set_update_flag ON CHAIN-REQUEST.
    ENDCHAIN.
    FIELD vim_marked MODULE liste_mark_checkbox.
    CHAIN.
      FIELD zmv_jny_field-field_name .
      MODULE liste_update_liste.
    ENDCHAIN.
  ENDLOOP.
  MODULE liste_after_loop.
