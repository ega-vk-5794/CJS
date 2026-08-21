CLASS zcl_rak_qnv_bridge DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor IMPORTING is_config TYPE zif_rak_journey=>ty_config.
    METHODS post
      IMPORTING iv_screen      TYPE string
                iv_status      TYPE string OPTIONAL
                iv_guid        TYPE string
                it_items       TYPE zif_rak_journey=>tt_item
                it_tables      TYPE /qnv/sb_tabl_def_tt OPTIONAL
                it_attachments TYPE /qnv/sbuild_attachments_tt OPTIONAL
      EXPORTING ev_guid        TYPE string
"               The container case number, when THIS post created one. Blank on every
"               post that did not - which is every post on a journey with no case, and
"               every post after the first on one that has.
"
"               Separate from EV_GUID on purpose. The two used to be the same value,
"               because the BAdI writes the case id over the INTRENO_JOURNEY item it
"               was handed, and reading that back as the journey key is what made the
"               key move mid-journey.
                ev_case        TYPE string
                ev_next_screen TYPE string
                et_msg         TYPE zif_rak_journey=>tt_msg.
    " et_attachments: the files the backend already holds against this case.
    " The read FM fills them on the definition read - /QNV/CL_SBUILD_LOGIC's
    " GET_CONTROLDEFINITATION_DTLS returns CT_ATTACHMENTS, and the separate
    " GET_ATTACHMENT_DATA call has been commented out in the OData layer since
    " Sep 2022 with the note "populating the attachment before this function".
    " So this costs nothing extra: the rows were already coming back and being
    " thrown away here.
    METHODS read
      IMPORTING iv_screen      TYPE string
                iv_guid        TYPE string
                it_items       TYPE zif_rak_journey=>tt_item
*               The logged-on business partner, sent as PARAM3.
*
*               ZIF_EGA_FW_CJI~READ has no LOGINBP parameter - unlike CREATE and
*               UPDATE, which both take one - so PARAM3 is the ONLY channel a read
*               has for identity. Every ShapeIt launch carries it:
*
*                 ...&param2=D001&param1=202411280001&param3=1000116563
*
*               Without it a cold read has no partner. GS_DATA-PARTNER is filled
*               either from the shared buffer (which a fresh session has not
*               written yet) or from LS_DATA-APPLICANT_ID inside READ_CASE (which
*               only runs once a draft or case has been found), so on journey entry
*               it stays blank and the applicant name and Emirates ID render empty.
*
*               Optional, and blank sends exactly what was sent before.
                iv_loginbp     TYPE string OPTIONAL
      EXPORTING et_values      TYPE zif_rak_journey=>tt_kv
                et_attachments TYPE /qnv/sbuild_attachments_tt
*               The same two facts POST returns, for the same reason - a READ can
*               move the key just as a POST can, and until now nothing was
*               listening.
*
*               ZIF_EGA_FW_CJI~GET_SCREEN sets GV_GUID from the case id when the
*               journey is launched on a case, and CREATE_CASE re-points it at the
*               case id the moment one exists:
*
*                   IF gs_data-caseid IS NOT INITIAL.
*                     me->gv_guid = gs_data-caseid.
*
*               and the read BAdI hands that value straight back:
*
*                   WHEN 'INTRENO_JOURNEY'. <definition>-value = gv_guid.
*
*               So the backend has been announcing the key on every read and the
*               bridge was discarding it.
                ev_guid        TYPE string
                ev_case        TYPE string
                et_msg         TYPE zif_rak_journey=>tt_msg.

    " One grid's rows. The legacy read does NOT return table data: the OData layer
    " makes a second call per table, and so must we.
    "
    " The table is identified by /QNV/SB_UI_DEFIN-DATA2, not by the field name -
    " ZFM_EGA_CJ_FW_READ_TABLE_DATAN types IV_TABLE_NAME as /QNV/SBUILD_DATA2, and
    " the BAdI reads WITH KEY data2 = iv_table_name. The two are routinely
    " different: FIELD_NAME LICENSES against DATA2 LICENCES on the same row. So
    " iv_field is the field name and this resolves DATA2 itself, which is what
    " /QNV/CL_SBUILD_LOGIC=>GET_TABLEDATA does from the control definition.
*   iv_type is the CONTROL TYPE, and it is not decoration. A PAYFEE control is
*   not a UI table and does not carry the UI table's naming: the fee list is
*   asked for under one fixed name by every department's read BAdI, so the type
*   is what decides the name sent, and the field name never reaches the FM.
*   Blank behaves exactly as before, which is what every non-fee grid passes.
    METHODS read_table
      IMPORTING iv_screen TYPE string
                iv_guid   TYPE string
                iv_field  TYPE string
                iv_type   TYPE string OPTIONAL
*               The backend table name the CJS author named explicitly, from the
*               field's TECH_NAME. Only consulted on a PAYFEE control, and only
*               when it is filled - see the fee branch in the implementation for
*               why this is TECH_NAME rather than DATA2.
                iv_table  TYPE string OPTIONAL
*               PARAM3, as on READ. The table read goes through the same BAdI and
*               has the same blind spot.
                iv_loginbp TYPE string OPTIONAL
      EXPORTING et_rows   TYPE /qnv/sbuild_ui_table_cust_tt
                et_msg    TYPE zif_rak_journey=>tt_msg.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_fm_read_table TYPE string VALUE 'ZFM_EGA_CJ_FW_READ_TABLE_DATAN'.
*   The name the fee list answers to. Part of the read FM's contract with every
*   department, not a per-journey configuration value - which is precisely why it
*   belongs here as a constant and not in ZRAK_T_JNY_FLD.
    CONSTANTS c_fee_table    TYPE /qnv/sbuild_data2 VALUE 'FEESLIST'.
    DATA ms_config TYPE zif_rak_journey=>ty_config.
ENDCLASS.



CLASS ZCL_RAK_QNV_BRIDGE IMPLEMENTATION.


  METHOD constructor.
    ms_config = is_config.
    IF ms_config-backend-fm_post IS INITIAL.
      ms_config-backend-fm_post = 'ZFM_EGA_CJ_FW_POST_N'.
    ENDIF.
    IF ms_config-backend-fm_read IS INITIAL.
      ms_config-backend-fm_read = 'ZFM_EGA_CJ_FW_READ_N'.
    ENDIF.
    " UI journey ID and backend journey code are DIFFERENT values;
    " fall back to cj_type only when no explicit backend code is configured
    IF ms_config-backend-journey IS INITIAL.
      ms_config-backend-journey = ms_config-cj_type.
    ENDIF.
  ENDMETHOD.


  METHOD post.
    DATA ls_hdr  TYPE /qnv/sbuild_saveheader_st.
    DATA lt_item TYPE /qnv/sbuild_saveitem_tt.
    DATA lt_att  TYPE /qnv/sbuild_attachments_tt.
    DATA lt_tab  TYPE /qnv/sb_tabl_def_tt.

    ls_hdr-categoryname = ms_config-backend-category.
    ls_hdr-screenname   = iv_screen.
    ls_hdr-functionin   = ms_config-backend-fm_post.

    CONSTANTS c_caller_fld TYPE string VALUE 'ZCJS_CALLER'.
    CONSTANTS c_caller_id  TYPE string VALUE 'CJS'.

    APPEND VALUE #( fieldname = 'USERDATA'        technicalname = 'USERDATA'
                    value = ms_config-backend-userdata ) TO lt_item.

    APPEND VALUE #( fieldname = c_caller_fld technicalname = c_caller_fld
                        value = c_caller_id ) TO lt_item.

    IF ms_config-backend-userdata IS INITIAL
       AND ms_config-backend-loginbp_dev IS NOT INITIAL.
      APPEND VALUE #( fieldname = 'LOGINBP_DEV' technicalname = 'LOGINBP_DEV'
                      value = ms_config-backend-loginbp_dev ) TO lt_item.
    ENDIF.

    APPEND VALUE #( fieldname = 'CJS_LOGINBP' technicalname = 'CJS_LOGINBP'
                    value = ms_config-backend-loginbp_dev ) TO lt_item.
    APPEND VALUE #( fieldname = 'CJS_ROLEBP'  technicalname = 'CJS_ROLEBP'
                    value = ms_config-backend-rolebp ) TO lt_item.
    APPEND VALUE #( fieldname = 'CJS_ROLE'    technicalname = 'CJS_ROLE'
                    value = ms_config-backend-role ) TO lt_item.

    APPEND VALUE #( fieldname = 'JOURNEYTYPE'     technicalname = 'JOURNEYTYPE'
                    value = ms_config-backend-journey ) TO lt_item.
    APPEND VALUE #( fieldname = 'INTRENO_JOURNEY' technicalname = 'INTRENO_JOURNEY'
                    value = iv_guid ) TO lt_item.
    IF iv_status IS NOT INITIAL.
      APPEND VALUE #( fieldname = 'STATUS' technicalname = 'STATUS' value = iv_status ) TO lt_item.
    ENDIF.
    APPEND VALUE #( fieldname = 'ERROR' technicalname = 'ERROR' ) TO lt_item.

    LOOP AT ms_config-backend-context INTO DATA(ls_ctx).
      DATA(lv_tech) = to_upper( ls_ctx-tech ).

      CHECK lv_tech <> 'USERDATA'    AND lv_tech <> 'LOGINBP_DEV'
        AND lv_tech <> 'JOURNEYTYPE' AND lv_tech <> 'INTRENO_JOURNEY'
        AND lv_tech <> 'LOGINBP'     AND lv_tech <> 'ROLEBP'
        AND lv_tech <> 'ROLE'
        AND lv_tech <> 'CJS_LOGINBP' AND lv_tech <> 'CJS_ROLEBP'
        AND lv_tech <> 'CJS_ROLE'.

      CHECK lv_tech <> 'STATUS' AND lv_tech <> 'ERROR' AND lv_tech <> c_caller_fld.

      CHECK lv_tech <> 'SAP-CLIENT' AND lv_tech <> 'APP_START'
        AND lv_tech <> 'JOURNEY'    AND lv_tech <> 'TRACE'.

      IF lv_tech CS '-' OR lv_tech CS '[]'.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( fieldname     = ls_ctx-field
                      technicalname = ls_ctx-tech
                      value         = ls_ctx-value ) TO lt_item.
    ENDLOOP.

    LOOP AT it_items INTO DATA(ls_i).
      APPEND VALUE #( fieldname     = ls_i-field
                      technicalname = COND #( WHEN ls_i-tech IS NOT INITIAL THEN ls_i-tech ELSE ls_i-field )
                      value         = ls_i-value
                      category      = ms_config-backend-category
                      screenname    = iv_screen ) TO lt_item.
    ENDLOOP.

    lt_tab = it_tables.
    lt_att = it_attachments.

    TRY.
        CALL FUNCTION ms_config-backend-fm_post
          CHANGING
            cs_general_data = ls_hdr
            ct_item_data    = lt_item
            ct_attacments   = lt_att
            ct_tabledata    = lt_tab.
      CATCH cx_root INTO DATA(lx).

*       NAME THE ONE THAT LOOKS LIKE NOTHING. Every other exception here reads as
*       what it is; CX_SY_IMPORT_MISMATCH_ERROR arrives as the runtime's generic
*       "an exception was raised but was not handled locally" text, which says
*       neither what failed nor whether anything can be done about it.
*
*       WHAT IT IS. Confirmed in the debugger, not guessed:
*
*         ZCL_EGA_CJ_DOK_ABS->ACCESS_STUDENT_EXIT_BUFFER
*           IMPORT student_exit = cs_student_exit
*             FROM SHARED BUFFER indx(cj) ID lv_id.
*
*       The row under that id was EXPORTed from a DIFFERENT shape of the
*       structure than it is now imported into. A type mismatch on a CACHE - not
*       a missing key, and nothing to do with what the citizen typed.
*
*       AND THE KEY IS THE STUDENT, NOT THE DRAFT:
*
*         LV_ID = student_exit_2013196053
*
*       That is the part worth writing down, because the obvious advice is wrong.
*       Deleting the application and starting again does NOT help - the new draft
*       builds the same id from the same student and hits the same poisoned row.
*       SHARED BUFFER is cross-session too, so it is not one citizen: everyone
*       who touches that student on this app server gets it, until the row is
*       cleared or the buffer is flushed.
*
*       So this message must NOT send anybody round the retry loop. It says the
*       truth - the same student will keep failing, and somebody has to clear the
*       cache - because a citizen told to try again will try again, twice, and
*       then telephone.
*
*       The real fix is four lines in ACCESS_STUDENT_EXIT_BUFFER: catch
*       CX_SY_IMPORT_MISMATCH_ERROR, DELETE the row, report a miss. A cache must
*       never be able to stop the application it is only there to speed up. That
*       class is not in this repository - it lives in the BAdI chain and is
*       maintained in ADT - so this bridge reports it as clearly as it can and
*       does not pretend to have fixed it.
        DATA(lv_cls) = cl_abap_classdescr=>get_class_name( lx ).
        IF lv_cls CS 'CX_SY_IMPORT_MISMATCH_ERROR'.
          APPEND VALUE #( type = 'Error'
            text = |This service cannot continue for this student right now. The | &&
                   |backend is holding cached data for them in an older format. | &&
                   |Nothing you entered caused it, and starting the application | &&
                   |again will not clear it - please report it to support.| ) TO et_msg.

*         The technical half, separately, so the citizen-facing line above does not
*         have to carry any of it.
          APPEND VALUE #( type = 'Information'
            text = |INDX(CJ) SHARED BUFFER type mismatch · screen { iv_screen } · | &&
                   |guid { iv_guid } · { lv_cls }. Raised by | &&
                   |ZCL_EGA_CJ_DOK_ABS->ACCESS_STUDENT_EXIT_BUFFER, whose buffer id is | &&
                   |student_exit_<SID> - keyed by STUDENT, so a new draft hits the same | &&
                   |row. Clear that id from the buffer, and catch the exception there.| ) TO et_msg.
          RETURN.
        ENDIF.

        APPEND VALUE #( type = 'Error' text = |Backend POST failed: { lx->get_text( ) }| ) TO et_msg.
        RETURN.
    ENDTRY.

    ev_next_screen = ls_hdr-screenname.  " FM advances via get_screenname

    DATA(lv_back) = VALUE string( lt_item[ technicalname = 'INTRENO_JOURNEY' ]-value OPTIONAL ).

    IF iv_guid IS INITIAL.
      ev_guid = lv_back.
    ELSE.
      ev_guid = iv_guid.
      IF lv_back IS NOT INITIAL AND lv_back <> iv_guid.
        ev_case = lv_back.
      ENDIF.
    ENDIF.

    READ TABLE lt_item INTO DATA(ls_err) WITH KEY fieldname = 'ERROR'.
    IF sy-subrc = 0 AND ls_err-messagedesc IS NOT INITIAL.
      APPEND VALUE #( type = COND #( WHEN ls_err-messagetype = 'E' THEN 'Error'
                                     WHEN ls_err-messagetype = 'W' THEN 'Warning'
                                     ELSE 'Information' )
                      text = ls_err-messagedesc ) TO et_msg.
    ENDIF.
  ENDMETHOD.


  METHOD read.
    DATA ls_hdr TYPE /qnv/sbuild_getheader_st.
    DATA lt_def TYPE /qnv/sbuild_definition_tt.
    DATA lt_att TYPE /qnv/sbuild_attachments_tt.

*   PARAM1 is the KEY, and the read FM treats it as one of three things:
*
*       IF cs_header-param1 IS NOT INITIAL.
*         SELECT SINGLE sgrnr INTO @journeytype FROM vibdro WHERE intreno EQ @cs_header-param1.
*       ENDIF.
*       IF journeytype IS INITIAL.
*         journeytype = cs_header-param2.
*       ENDIF.
*
*   a real estate INTRENO for an object-anchored journey, or - when that misses,
*   which is the normal case here - a draft id or a case id, with PARAM2 naming the
*   journey instead. Both ShapeIt samples are the second shape:
*
*       param2=D001   param1=202411280001   (draft)
*       param2=PG01   param1=1959219        (the common pay app)
*
*   A GUID_22 is NONE of those three. It exists only between journey entry and the
*   first key, as the INDX(CJ) buffer id, and CREATE_CASE abandons it the moment a
*   case id appears. Sending one here is harmless - the VIBDRO select misses and
*   PARAM2 answers - but sending one AFTER a real key exists is not: READ_CASE
*   ALPHA-converts it into an SCMG_EXT_KEY, finds neither case nor draft, and
*   returns EV_FOUND blank with the CX_SY_OPEN_SQL_DATA_ERROR swallowed. The
*   journey comes back empty and nothing is reported. Hence EV_GUID / EV_CASE below.
    ls_hdr-param1       = iv_guid.
    ls_hdr-param2       = ms_config-backend-journey.
*   PARAM3 is the partner. Falls back to the dev BP override so a direct launch
*   without a portal session still resolves an applicant on E10 / E20.
    ls_hdr-param3       = COND #( WHEN iv_loginbp IS NOT INITIAL THEN iv_loginbp
                                  ELSE ms_config-backend-loginbp_dev ).
    ls_hdr-param4       = ms_config-backend-rolebp.
    ls_hdr-screenname   = iv_screen.
    ls_hdr-categoryname = ms_config-backend-category.

    " pre-seed definition rows so the BAdI read fills our fields
    LOOP AT it_items INTO DATA(ls_i).
      APPEND VALUE #( fieldname     = ls_i-field
                      technicalname = COND #( WHEN ls_i-tech IS NOT INITIAL THEN ls_i-tech ELSE ls_i-field )
                      screenname    = iv_screen
                      categoryname  = ms_config-backend-category ) TO lt_def.
    ENDLOOP.

*   Seed INTRENO_JOURNEY unconditionally. The BAdI answers it by field name:
*
*       CASE <definition>-fieldname.
*         WHEN 'INTRENO_JOURNEY'. <definition>-value = gv_guid.
*
*   so with no row for it the branch never fires and the backend's key never comes
*   back. Seeding from IT_ITEMS alone is not enough: the engine posts and reads only
*   the CURRENT step's fields, and a journey typically carries INTRENO_JOURNEY as a
*   hidden field on step 1 only - so from step 2 onwards the key went silent exactly
*   when the case that replaces it was being created.
*
*   Appended after the loop and only when absent, so an author who did declare the
*   field keeps their own row and its TECH_NAME.
    IF NOT line_exists( lt_def[ fieldname = 'INTRENO_JOURNEY' ] ).
      APPEND VALUE #( fieldname     = 'INTRENO_JOURNEY'
                      technicalname = 'INTRENO_JOURNEY'
                      screenname    = iv_screen
                      categoryname  = ms_config-backend-category ) TO lt_def.
    ENDIF.

    ls_hdr-param5 = 'CJS'.

    TRY.
        CALL FUNCTION ms_config-backend-fm_read
          CHANGING
            cs_header     = ls_hdr
            ct_definition = lt_def
            ct_attacments = lt_att.
      CATCH cx_root INTO DATA(lx).
        APPEND VALUE #( type = 'Error' text = |Backend READ failed: { lx->get_text( ) }| ) TO et_msg.
        RETURN.
    ENDTRY.

    LOOP AT lt_def INTO DATA(ls_d).
      APPEND VALUE #( key = ls_d-fieldname value = ls_d-value ) TO et_values.
    ENDLOOP.

*   Same rule as POST, and stated the same way so the two cannot drift.
*
*   BLANK WENT OUT - we had no key, so whatever came back IS the key.
*   A KEY WENT OUT - the key is ours; a DIFFERENT value coming back is the case id,
*   because GET_SCREEN and CREATE_CASE both re-point GV_GUID at GS_DATA-CASEID once
*   a case exists. Reporting that as EV_GUID would move the journey's identity
*   mid-flight - the failure this separation was introduced to stop on POST.
    DATA(lv_back) = VALUE string( lt_def[ fieldname = 'INTRENO_JOURNEY' ]-value OPTIONAL ).

    IF iv_guid IS INITIAL.
      ev_guid = lv_back.
    ELSE.
      ev_guid = iv_guid.
      IF lv_back IS NOT INITIAL AND lv_back <> iv_guid.
        ev_case = lv_back.
      ENDIF.
    ENDIF.

    " Was the whole point of the bug: lt_att was a CHANGING parameter on the FM
    " call, the backend filled it, and this method returned without ever looking
    " at it. Every file already on the case was fetched and discarded on every
    " step read.
    et_attachments = lt_att.
  ENDMETHOD.


  METHOD read_table.
    DATA(lv_field) = CONV /qnv/sbuild_data(  to_upper( iv_field ) ).
    DATA(lv_screen) = CONV /qnv/sbuild_screen_name( iv_screen ).
    DATA(lv_cat)    = CONV /qnv/sbuild_data( ms_config-backend-category ).

    SELECT SINGLE data2 FROM /qnv/sb_ui_defin
      WHERE screen_name = @lv_screen
        AND category    = @lv_cat
        AND field_name  = @lv_field
      INTO @DATA(lv_data2).
    DATA(lv_norow) = xsdbool( sy-subrc <> 0 ).

*   ASK ANYWAY. This used to give up here whenever DATA2 was blank or the row was
*   missing, so the FM was never called and the only evidence was a warning on the
*   citizen's form. Trying costs one round trip and can only help:
*
*   - The DOK BAdI matches on DATA2, so on that department a guess will not match
*     and comes back empty - no worse than not asking, but now we can SAY that the
*     attempt was made and failed, which is a far better diagnosis than silence.
*   - Other departments do not all key on DATA2. The RO abstract decides what to
*     return from its own UI map rather than from the passed name, so there a
*     journey with no DATA2 may work perfectly well.
*
*   What is never done is send a BLANK name. The BAdI does
*       READ TABLE lt_defin WITH KEY data2 = iv_table_name
*   and blank matches the FIRST row on the screen with an empty DATA2 - typically
*   some container - which would return either nothing or, worse, another
*   control's rows. The field name cannot do that: it either matches the right
*   table or matches nothing.
    DATA lv_table TYPE /qnv/sbuild_data2.
    DATA lv_src   TYPE string.
    DATA lv_fee   TYPE abap_bool.
    IF lv_data2 IS NOT INITIAL.
      lv_table = lv_data2.
      lv_src   = 'DATA2'.
    ELSE.
      lv_table = lv_field.
      lv_src   = COND string( WHEN lv_norow = abap_true
                              THEN 'the field name - there is no /QNV/SB_UI_DEFIN row at all'
                              ELSE 'the field name - DATA2 is blank on the /QNV/SB_UI_DEFIN row' ).
    ENDIF.

*   ---- fees are not a configured grid --------------------------------
*   The fee list has one name on the backend and it is never the field's. Every
*   department's read BAdI answers the fee request under FEESLIST: the name is
*   part of the FM contract, not part of this journey's UI. So a PAYFEE control
*   is asked for by type, and whatever the author called the field - PAYFEE, FEE,
*   LICENSE_FEE - stops mattering here, which is the point.
*
*   This OVERRIDES DATA2 rather than falling back to it. A DATA2 on a PAYFEE row
*   is a UI-table name that has been carried onto a control which is not a UI
*   table, and honouring it asks the BAdI for a table it has never heard of. The
*   failure is silent and expensive: no rows, no error, an empty fee card, and
*   the handler quietly falling through to GET_FEES( ) and a direct dfkkop read -
*   so a journey whose fees are not open items yet shows the citizen nothing to
*   pay. The override is said out loud when the two disagree, so the stray row
*   gets cleaned up instead of being worked around.
    IF to_upper( iv_type ) = 'PAYFEE'.
      lv_fee = abap_true.

*     An author who typed a table name into the PAYFEE field's TECH_NAME meant
*     it, and gets it. That is the whole difference between this and DATA2:
*     TECH_NAME is entered in the Studio, on this control, on purpose, while a
*     DATA2 on a PAYFEE row is far more often a leftover from whatever the row
*     was copied from - which is why the override below exists at all.
*
*     The case it serves is real. FEESLIST is the fee contract for a case whose
*     open items the backend has already raised. A journey that prices itself
*     from its own table - a grade-by-grade fee matrix, a per-document tariff,
*     anything an EDITABLE_TABLE already holds - has no open items to read and
*     no way, until now, to say where its fees actually live.
      IF iv_table IS NOT INITIAL.
        lv_table = CONV /qnv/sbuild_data2( to_upper( condense( iv_table ) ) ).
        lv_src   = 'TECH_NAME on the PAYFEE control'.
      ELSE.
        IF lv_data2 IS NOT INITIAL AND lv_data2 <> c_fee_table.
          APPEND VALUE #( type = 'Warning'
            text = |Fees ({ iv_field }): DATA2 is { lv_data2 } on a PAYFEE control. The fee | &&
                   |list is read as { c_fee_table } unless the control's TECH_NAME names | &&
                   |another table, so DATA2 was ignored. Either clear it on the | &&
                   |/QNV/SB_UI_DEFIN row, or - if { lv_data2 } really is where this | &&
                   |journey's fees live - put that name in TECH_NAME where it will be | &&
                   |honoured.| ) TO et_msg.
        ENDIF.
        lv_table = c_fee_table.
        lv_src   = 'the fee contract'.
      ENDIF.
    ENDIF.

    IF lv_table IS INITIAL.
      RETURN.
    ENDIF.

    DATA ls_hdr TYPE /qnv/sbuild_getheader_st.
    ls_hdr-param1       = iv_guid.
    ls_hdr-param2       = ms_config-backend-journey.
*   PARAM3, as on READ - the grid read reaches the same BAdI through the same
*   header and had the same blind spot.
    ls_hdr-param3       = COND #( WHEN iv_loginbp IS NOT INITIAL THEN iv_loginbp
                                  ELSE ms_config-backend-loginbp_dev ).
    ls_hdr-param4       = ms_config-backend-rolebp.
    ls_hdr-screenname   = iv_screen.
    ls_hdr-categoryname = ms_config-backend-category.
    ls_hdr-param5 = 'CJS'.
    TRY.
        CALL FUNCTION c_fm_read_table
          EXPORTING
            is_header     = ls_hdr
            iv_table_name = lv_table
          IMPORTING
            et_data_table = et_rows.
      CATCH cx_root INTO DATA(lx).
        APPEND VALUE #( type = 'Error'
          text = |Backend table READ failed for { iv_field }: { lx->get_text( ) }| ) TO et_msg.
        RETURN.
    ENDTRY.

*   Only complain when the guess was actually needed AND it produced nothing.
*   A correct DATA2 that legitimately returns no rows is not a fault, and a guess
*   that happened to work needs no comment either.
    IF et_rows IS INITIAL AND lv_src <> 'DATA2'.
      IF lv_fee = abap_true.
*       Nothing to fix in configuration when the name sent was the contract one -
*       so the advice has to point at the BAdI instead. Worth saying because the
*       symptom the citizen sees is a fee card with no lines, and the handler will
*       go on to read open items and very likely find none either.
        IF lv_src = 'the fee contract'.
          APPEND VALUE #( type = 'Warning'
            text = |Fees: the backend was asked for { c_fee_table } on screen { iv_screen } | &&
                   |and returned no lines. If this service charges a fee, the read BAdI is | &&
                   |not filling the fee table for this case.| ) TO et_msg.
        ELSE.
*         The author named the table themselves, so this one IS fixable in
*         configuration and the advice should say where.
          APPEND VALUE #( type = 'Warning'
            text = |Fees ({ iv_field }): TECH_NAME names { lv_table } and the backend | &&
                   |returned no lines for it on screen { iv_screen }. Check the name | &&
                   |against what the read BAdI answers to, or clear TECH_NAME to fall | &&
                   |back to { c_fee_table }.| ) TO et_msg.
        ENDIF.
      ELSE.
        APPEND VALUE #( type = 'Warning'
          text = |Grid { iv_field }: asked the backend using { lv_src }, and it returned nothing. | &&
                 |Set DATA2 on that row to the name the BAdI expects - it is often, | &&
                 |but not always, the field name.| ) TO et_msg.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
