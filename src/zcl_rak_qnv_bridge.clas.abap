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
"               The partner this session resolved, for the same reason READ
"               needed it - and on POST the consequence is larger.
"
"               ZCL_EGA_CJ_FW_RO_ABS_V1->MAPPER( ) derives BOTH Municipality
"               partners from an item called BP and nothing else, and
"               CREATE( ) validates the TR0800 one BEFORE creating the RE
"               rental object. A blank partner therefore stops the create
"               (ZMSG_EGA_CJ 009 and 010), no INTRENO comes back, and the
"               engine reports "The backend did not return a draft
"               reference. The application cannot be started." - which names
"               none of the cause.
"
"               Optional, and blank falls back to LOGINBP_DEV, so a journey
"               that never passes it sends exactly what it sent before.
                iv_loginbp     TYPE string OPTIONAL
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
*               Field control as the BAdI left it, one row per attribute:
*               KEY is |<FIELDNAME>/<ATTRIBUTE>| and VALUE is the flag it
*               carried. A KV table rather than a typed structure so a
*               newly interesting column - an ADDITIONALDATA slot, say -
*               costs a line here and nothing anywhere else.
                et_ctrl        TYPE zif_rak_journey=>tt_kv
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

*   One definition row's field control, flattened into KV rows. The shape
*   is READ( )'s business and nobody else's.
*   TYPED, not generic. IS_DEF was TYPE ANY and the static read of
*   IS_DEF-FIELDNAME is then illegal - "does not have a structure and
*   therefore does not have a component called FIELDNAME".
*
*   LINE OF the TABLE type, never a guessed row-type name. The table type
*   is already named in READ( )'s own LT_DEF, so it is proven to exist;
*   /QNV/SBUILD_DEFINITION_ST would only be the conventional spelling of
*   its row, and this environment cannot open a /QNV/ object to check. The
*   rule that keeps being re-learned here: do not hand-write the shape of
*   a standard object you cannot open - derive it.
*
*   The columns this method is UNCERTAIN of stay dynamic. That was always
*   the point of ASSIGN COMPONENT here, not the parameter's type.
    METHODS ctrl_of
      IMPORTING is_def  TYPE LINE OF /qnv/sbuild_definition_tt
                is_seed TYPE LINE OF /qnv/sbuild_definition_tt
      CHANGING  ct_ctrl TYPE zif_rak_journey=>tt_kv.

*   SEED THE FIELD CONTROL WITH WHAT CJS ALREADY BELIEVES, so what comes
*   back is the BAdI's FINAL WORD rather than a half-answer.
*
*   The rows sent into ZIF_EGA_FW_CJI~READ used to carry nothing but a
*   field name, so every flag came back blank unless the implementation
*   wrote one - and blank is ambiguous in the worst direction: it reads
*   identically as "the BAdI cleared this" and "the BAdI never looked at
*   it". BACKEND_READ( ) consequently called SET_REQUIRED( abap_false ) on
*   every field the implementation did not name, which silently removed the
*   required marker from every migrated mandatory field on any screen the
*   BAdI answered at all.
*
*   Seeded with the journey's own configuration instead, an untouched row
*   comes back saying exactly what CJS already thought and applying it is a
*   no-op; a row the implementation changed says so unambiguously, in both
*   directions. That is what makes ENABLED and VISIBLE safe to apply and
*   not only to trace.
*
*   Written through ASSIGN COMPONENT because the definition structure is a
*   legacy DDIC type: a column this release does not have is skipped rather
*   than failing activation.
    METHODS seed_ctrl
      IMPORTING iv_screen TYPE string
                iv_field  TYPE string
      CHANGING  cs_def    TYPE LINE OF /qnv/sbuild_definition_tt.

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

*   ---- PARAM3 IS THE PARTNER, AND THE POST WAS NOT SENDING IT --------
*   READ( ) HAS ALWAYS SET IT AND POST( ) NEVER DID. That asymmetry is
*   the whole defect: reads resolved the citizen, posts arrived with
*   LOGINBP blank, and ZFM_EGA_CJ_FW_POST_N returns before it ever gets
*   to the BAdI:
*
*       IF loginbp IS INITIAL AND anonymous <> 'X'.
*         RETURN.                       "Authentication not valid
*       ENDIF.
*       GET BADI cj_badi FILTERS journey_type = journeytype.
*
*   WHICH IS WHY THIS LOOKED LIKE A MISSING BAdI IMPLEMENTATION. The FM
*   returns with no messages and no draft reference in about a
*   millisecond - exactly what a filter matching nothing looks like from
*   outside - and CJS's own blocker text said so, sending three people to
*   SE18 to check a registration that was never the problem. Confirmed in
*   the debugger instead: stack frame 18, the arrow on the RETURN at line
*   67, LOGINBP holding spaces.
*
*   IT WORKED THIS MORNING because the FM filled the gap itself:
*
*       * IF loginbp IS INITIAL AND sy-sysid <> 'E30'.
*       *   loginbp = lc_test_bp.
*       * ENDIF.
*
*   That block is commented out now, and CJS was relying on it without
*   anything saying so. A dev-only hardcode in a legacy FM is not a
*   channel to depend on - the FM is not in this repository and cannot be
*   changed from here - so the partner travels in the payload where the
*   read already put it.
*
*   SAME PRECEDENCE AS READ( ): the session's resolved partner first, the
*   dev `&loginbp=` override second. PARAM4 carries ROLEBP because the FM
*   defaults ROLEBP from LOGINBP when it is blank, and letting it do that
*   silently would post one partner as though it were the other.
    ls_hdr-param3 = COND #( WHEN iv_loginbp IS NOT INITIAL
                            THEN iv_loginbp
                            ELSE ms_config-backend-loginbp_dev ).
    ls_hdr-param4 = ms_config-backend-rolebp.

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

*   ---- BP: the item the Municipality BAdI derives its partners FROM ----
*
*   WITHOUT THIS A MUNICIPALITY JOURNEY CANNOT START AT ALL, and the error
*   names none of it: "The backend did not return a draft reference. The
*   application cannot be started."
*
*   The chain, end to end, in ZCL_EGA_CJ_FW_RO_ABS_V1:
*
*     MAPPER( )   derives BOTH partners from ONE item and nothing else -
*                   mt_partner = VALUE #(
*                     ( role_type = 'TR0800'
*                       partner = VALUE #( mt_item_data[
*                                   technicalname = 'BP' ]-value OPTIONAL ) )
*                     ( role_type = 'TR0640' partner = ...same... ) ).
*     CREATE( )   calls validate( mode = 'C' ) FIRST
*     VALIDATE( ) with a blank TR0800 partner appends ZMSG_EGA_CJ 009, and
*                   ZCL_EGA_MUN_CJ_ODATA_API( partner = blank )->properties
*                   is then empty too, which appends 010
*     CREATE( )   raise_message( ) -> stop -> RETURN, BEFORE create( )
*
*   so no RE rental object is created, no INTRENO comes back, the
*   INTRENO_JOURNEY item below stays blank, and the engine correctly
*   reports that it has no draft reference. Every symptom is one missing
*   item.
*
*   THE PAYLOAD CARRIED CJS_LOGINBP AND NOT BP. Those are not the same
*   name and the BAdI reads only the second. LOGINBP_DEV, CJS_ROLEBP and
*   CJS_ROLE were all here; the one the Municipality abstract actually
*   keys on was not.
*
*   IV_LOGINBP FIRST, LOGINBP_DEV SECOND. IV_LOGINBP is the partner the
*   engine resolved for this session; LOGINBP_DEV is the dev-only
*   `&loginbp=` override and is what CJS_LOGINBP above sends. Preferring
*   the resolved one means a real session posts the real partner and a dev
*   override still works.
*
*   GUARDED, so a journey that configures its own BP field wins. A second
*   item with the same technical name would make
*   `mt_item_data[ technicalname = 'BP' ]` ambiguous - it reads the FIRST -
*   and which one that is would depend on insertion order.
*
*   SAFE FOR THE OTHER FAMILIES. The DOK and EPDA abstracts map items to
*   characteristics through their own config table by TECHNICALNAME, so an
*   item no row names is ignored rather than written anywhere.
    IF NOT line_exists( lt_item[ technicalname = 'BP' ] ).
      DATA(lv_bp) = COND string( WHEN iv_loginbp IS NOT INITIAL
                                 THEN iv_loginbp
                                 ELSE ms_config-backend-loginbp_dev ).
      IF lv_bp IS NOT INITIAL.
        APPEND VALUE #( fieldname = 'BP' technicalname = 'BP'
                        value = lv_bp ) TO lt_item.
      ENDIF.
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


  METHOD seed_ctrl.
    DATA(lv_f) = to_upper( condense( iv_field ) ).
    IF lv_f IS INITIAL.
      RETURN.
    ENDIF.

*   The field as this journey configures it. A field the config does not
*   know (INTRENO_JOURNEY, seeded unconditionally below) gets the neutral
*   defaults: visible, enabled, not mandatory.
    DATA lv_req TYPE abap_bool.
    DATA lv_ena TYPE abap_bool VALUE abap_true.
    DATA lv_vis TYPE abap_bool VALUE abap_true.

    LOOP AT ms_config-steps INTO DATA(ls_s) WHERE bknd_screen = iv_screen.
      READ TABLE ls_s-fields INTO DATA(ls_f) WITH KEY name = lv_f.
      IF sy-subrc = 0.
        lv_req = xsdbool( ls_f-validation-required = abap_true ).
        lv_ena = xsdbool( ls_f-readonly = abap_false ).
        lv_vis = xsdbool( ls_f-hidden   = abap_false ).
        EXIT.
      ENDIF.
    ENDLOOP.

    DATA(lt_set) = VALUE zif_rak_journey=>tt_kv(
      ( key = `MANDATORY` value = COND string( WHEN lv_req = abap_true THEN 'X' ) )
      ( key = `ENABLED`   value = COND string( WHEN lv_ena = abap_true THEN 'X' ) )
      ( key = `VISIBLE`   value = COND string( WHEN lv_vis = abap_true THEN 'X' ) ) ).

    LOOP AT lt_set INTO DATA(ls_set).
      ASSIGN COMPONENT ls_set-key OF STRUCTURE cs_def TO FIELD-SYMBOL(<v>).
      IF sy-subrc = 0.
        <v> = ls_set-value.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ctrl_of.
    DATA(lv_fld) = to_upper( CONV string( is_def-fieldname ) ).
    IF lv_fld IS INITIAL.
      RETURN.
    ENDIF.

*   Every attribute the legacy field control is known to travel in. A name
*   that is not a component of this release's structure is skipped, so the
*   list can name more than any one system has.
    DATA(lt_want) = VALUE string_table(
      ( `MANDATORY` ) ( `ENABLED` ) ( `VISIBLE` ) ( `READONLY` )
      ( `ADDITIONALDATA1` ) ( `ADDITIONALDATA2` )
      ( `ADDITIONALDATA3` ) ( `ADDITIONALDATA4` ) ).

    LOOP AT lt_want INTO DATA(lv_want).
      ASSIGN COMPONENT lv_want OF STRUCTURE is_def TO FIELD-SYMBOL(<v>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(lv_val) = condense( CONV string( <v> ) ).
*     A blank ADDITIONALDATA is noise - there are four of them on every row.
      IF lv_val IS INITIAL AND lv_want CP 'ADDITIONALDATA*'.
        CONTINUE.
      ENDIF.

*     A SEEDED FLAG IS REPORTED ONLY WHEN THE BADI CHANGED IT.
*
*     SEED_CTRL( ) sent MANDATORY, ENABLED and VISIBLE out carrying the
*     journey's own configuration, so a row that comes back agreeing with
*     what went out says nothing - the implementation did not touch it.
*     Reporting it anyway would be actively harmful, because
*     ZCL_RAK_JOURNEY_BE->APPLY_CTRL( ) applies these through SET_HIDDEN /
*     SET_READONLY / SET_REQUIRED, and an override written there OUTRANKS
*     ZRAK_T_JNY_RULE - ZCL_RAK_JOURNEY_RULES->IS_HIDDEN( ) checks the
*     override before MT_RULEHIDE. An echo of the seed would therefore
*     un-hide every field a rule hides, on every screen the BAdI answers:
*     one silent failure traded for a worse one.
*
*     What survives this gate is a genuine difference between what CJS
*     believes and what the legacy field-control engine says, which is
*     exactly what the BAdI is the authority on.
      IF lv_want = `MANDATORY` OR lv_want = `ENABLED` OR lv_want = `VISIBLE`.
        ASSIGN COMPONENT lv_want OF STRUCTURE is_seed TO FIELD-SYMBOL(<s>).
        IF sy-subrc = 0 AND condense( CONV string( <s> ) ) = lv_val.
          CONTINUE.
        ENDIF.
      ENDIF.

      APPEND VALUE #( key = |{ lv_fld }/{ lv_want }| value = lv_val ) TO ct_ctrl.
    ENDLOOP.
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
                      categoryname  = ms_config-backend-category ) TO lt_def
             ASSIGNING FIELD-SYMBOL(<ls_def>).
      seed_ctrl( EXPORTING iv_screen = iv_screen
                           iv_field  = CONV string( ls_i-field )
                 CHANGING  cs_def    = <ls_def> ).
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

*   WHAT WENT OUT, kept so what comes back can be told apart from it.
*   CT_DEFINITION is a CHANGING parameter - the implementation mutates the
*   very rows seeded above - so without this copy there is no way to
*   distinguish the BAdI's answer from an echo of the seed. See CTRL_OF( ).
    DATA(lt_seed) = lt_def.

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

*   THE BADI ANSWERS MORE THAN A VALUE, and for as long as this has
*   existed only the value was kept.
*
*   ZIF_EGA_FW_CJI~READ hands the implementation the whole definition
*   table and the implementation mutates it: values, yes, but also the
*   FIELD CONTROL - which fields are mandatory, enabled, visible on this
*   screen in this state - and the ADDITIONALDATA slots that carry the
*   stage list and BAdI-filled option lists. That is the legacy service's
*   field-control engine, and CJS was throwing all of it away on every
*   round trip. It is why a migrated journey's required markers, read-only
*   states and step titles do not match the live one.
*
*   Read BY NAME through ASSIGN COMPONENT rather than named in a MOVE: the
*   definition structure is a legacy DDIC type that cannot be opened from
*   the environment this was written in, and a column that turns out not
*   to exist yields nothing instead of failing activation. The engine
*   decides what to DO with each - see BACKEND_READ( ).
    LOOP AT lt_def INTO DATA(ls_d).
      APPEND VALUE #( key = ls_d-fieldname value = ls_d-value ) TO et_values.
      DATA ls_seed TYPE LINE OF /qnv/sbuild_definition_tt.
      CLEAR ls_seed.
      READ TABLE lt_seed INTO ls_seed WITH KEY fieldname = ls_d-fieldname.
      ctrl_of( EXPORTING is_def  = ls_d
                         is_seed = ls_seed
               CHANGING  ct_ctrl = et_ctrl ).
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
