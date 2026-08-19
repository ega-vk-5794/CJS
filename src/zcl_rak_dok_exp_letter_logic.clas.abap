CLASS zcl_rak_dok_exp_letter_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

* Handler for ZDOK_EXP_LETTER — the merged D014 licence page + D015 experience
* letter request.
*
* Enhanced from ZCL_D013_STAFF_APP_LET_LOGIC, which had the right shape and
* three problems this one fixes:
*
*   1. Its on_search called ZFE_CJ_SEARCH_BP_BY_ID and then ignored EV_MESSAGE,
*      so a failed lookup wrote six blank fields and said nothing. A candidate
*      who was not found looked identical to one who was found with no data.
*   2. Its get_table returned column headers and no rows — placeholder SQL,
*      commented out. Here both lists are served from the DOK handler API,
*      which is where they already come from in the legacy journey.
*   3. Its on_custom_validate was entirely commented out, so the Grades rule
*      it documents was never enforced.
*
* What this class does NOT do is draw anything. The licence list, the candidate
* list, the inline lookup panel and the fifteen grade boxes are all
* configuration; the code below serves them data and enforces what a rule
* cannot say.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_init           REDEFINITION.
    METHODS zif_rak_journey_logic~get_table         REDEFINITION.
    METHODS zif_rak_journey_logic~on_change         REDEFINITION.
    METHODS zif_rak_journey_logic~on_search         REDEFINITION.
    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post    REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_tables  REDEFINITION.

  PROTECTED SECTION.
    CONSTANTS c_min_len     TYPE i      VALUE 3.
    CONSTANTS c_idtype_def  TYPE string VALUE 'YFS002'.
    CONSTANTS c_teaching    TYPE string VALUE 'STAFF_1'.
    CONSTANTS c_other_staff TYPE string VALUE 'OTHER'.

*   The fifteen grade fields, in one place. Three methods need this list and
*   three copies of it is how one of them ends up missing Grade 7.
    METHODS grade_fields
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

*   Split a segmented answer into the two backend flags it stands for. Both
*   groups on this journey have the same shape: one choice, two flags, and the
*   flag that is not chosen must be posted BLANK rather than left absent.
    METHODS fan_out
      IMPORTING iv_key      TYPE string
                iv_on_value TYPE string
                iv_tech_on  TYPE string
                iv_tech_off TYPE string
      CHANGING  ct_kv       TYPE zif_rak_journey=>tt_kv.

  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RAK_DOK_EXP_LETTER_LOGIC IMPLEMENTATION.


  METHOD fan_out.
    READ TABLE ct_kv WITH KEY key = iv_key INTO DATA(ls_kv).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

*   BOTH flags are written, one of them blank. Writing only the chosen one
*   leaves whatever the backend held before - so a citizen who changes their
*   answer from Permanent to Temporary posts BOTH as set, and the case ends up
*   with two appointment types.
    ct_kv = VALUE #( BASE ct_kv
      ( key = iv_tech_on  value = COND #( WHEN ls_kv-value = iv_on_value THEN 'X' ELSE '' ) )
      ( key = iv_tech_off value = COND #( WHEN ls_kv-value = iv_on_value THEN '' ELSE 'X' ) ) ).

    DELETE ct_kv WHERE key = iv_key.
  ENDMETHOD.


  METHOD grade_fields.
    rt = VALUE #(
      ( `GRADE_PREKG` ) ( `GRADE_KG1` ) ( `GRADE_KG2` )
      ( `GRADE_1` ) ( `GRADE_2` )  ( `GRADE_3` )  ( `GRADE_4` )
      ( `GRADE_5` ) ( `GRADE_6` )  ( `GRADE_7` )  ( `GRADE_8` )
      ( `GRADE_9` ) ( `GRADE_10` ) ( `GRADE_11` ) ( `GRADE_12` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
    CASE to_upper( iv_name ).

*     ---- step 1, the licence list --------------------------------------
      WHEN 'LICENSES'.
*       Column 1 is the licence number and it MUST stay column 1: ROWPICK reads
*       row[ 1 ] as the key and writes it into LICENSE_SEL, and on_before_tables
*       marks the posted row by matching on it.
        rs_data-columns = VALUE #( ( `License` ) ( `School name` )
                                  ( `Issued at` ) ( `Expired at` ) ).

        DATA lt_lic TYPE zcl_dok_appln_handler_api=>tt_lic_no_list.
        NEW zcl_dok_appln_handler_api( )->get_all_school_licenses(
          EXPORTING iv_partner             = CONV #( io_ctx->get_val( 'OWNER_BP' ) )
          IMPORTING et_all_school_licenses = lt_lic ).

*       Falling back to license_search, exactly as the legacy D014 CREATE does:
*       get_all_school_licenses answers for an OWNER role and returns nothing
*       for the others, and an empty list on this step stops the journey dead.
        IF lt_lic IS INITIAL.
          NEW zcl_dok_appln_handler_api( )->license_search(
            EXPORTING iv_case_type    = ''
                      iv_bp_applicant = CONV #( io_ctx->get_val( 'OWNER_BP' ) )
            IMPORTING et_lic_no_list  = lt_lic ).
        ENDIF.

        LOOP AT lt_lic INTO DATA(ls_lic).
          APPEND VALUE #( ( |{ ls_lic-recnnr }| )
                          ( |{ ls_lic-recntxt }| )
                          ( |{ ls_lic-validfrom DATE = USER }| )
                          ( |{ ls_lic-validto DATE = USER }| ) ) TO rs_data-rows.
        ENDLOOP.

        IF rs_data-rows IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
            iv_text = 'No school licence is registered against your account.' ).
        ENDIF.

*     ---- step 2, the candidate list ------------------------------------
      WHEN 'STAFF_LIST'.
        rs_data-columns = VALUE #( ( `Name` ) ( `Emirates ID` )
                                  ( `Subject` ) ( `Staff type` ) ).

        DATA lt_staff TYPE zcl_dok_appln_handler_api=>tt_staff_exp.
        DATA(lv_company) = io_ctx->get_val( 'OWNER_BP' ).
        IF lv_company IS NOT INITIAL.
          NEW zcl_dok_appln_handler_api( )->get_staff_experience_lst(
            EXPORTING iv_bp_applicant = CONV #( lv_company )
                      iv_role         = 'Y00001'
            IMPORTING et_staff_list   = lt_staff ).
        ENDIF.

*       "Other" first, before the real staff. The legacy handler INSERTs it at
*       index 1 for a reason: a member of staff who has never been registered
*       has no row to pick, and without this the journey cannot be used for
*       them at all.
        APPEND VALUE #( ( c_other_staff )
                        ( |{ 'Select "Other" if staff not listed below'(001) }| )
                        ( `` ) ( `` ) ) TO rs_data-rows.

        LOOP AT lt_staff INTO DATA(ls_staff).
*         Arabic first when the journey is Arabic, and either name rather than a
*         blank cell: a staff list with empty names cannot be chosen from.
          DATA(lv_nm) = COND string(
            WHEN sy-langu = 'A' AND ls_staff-bp_name_ar IS NOT INITIAL THEN CONV string( ls_staff-bp_name_ar )
            WHEN ls_staff-bp_name_en IS NOT INITIAL                    THEN CONV string( ls_staff-bp_name_en )
            ELSE CONV string( ls_staff-bp_name_ar ) ).

          APPEND VALUE #( ( |{ ls_staff-partner }| )
                          ( lv_nm )
                          ( |{ ls_staff-emirates_id }| )
                          ( |{ ls_staff-subject_tx }| ) ) TO rs_data-rows.
        ENDLOOP.

    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

*   ---- the two segmented groups ---------------------------------------
*   One answer out, two flags in. The backend has no APPOINTMENTTYPE field - it
*   has APPOINTMENT_PERMANENT and APPOINTMENT_TEMPORARY - so posting the key
*   itself would post a name nothing reads.
    fan_out( EXPORTING iv_key      = 'APPOINTMENTTYPE'
                       iv_on_value = 'APP_1'
                       iv_tech_on  = 'GS_DATA-APPOINTMENT_PERMANENT'
                       iv_tech_off = 'GS_DATA-APPOINTMENT_TEMPORARY'
             CHANGING  ct_kv       = ct_kv ).

    fan_out( EXPORTING iv_key      = 'STAFFTYPE'
                       iv_on_value = c_teaching
                       iv_tech_on  = 'GS_DATA-STAFF_TEACHING'
                       iv_tech_off = 'GS_DATA-STAFF_NON'
             CHANGING  ct_kv       = ct_kv ).

*   ---- Non Teaching posts no grades and no subject ---------------------
*   The rules HIDE them, and a hidden field keeps its value. Somebody who ticks
*   six grades, then switches to Non Teaching, would otherwise post six grades
*   against a non-teaching appointment - and the screen showed none of them.
    IF io_ctx->get_val( 'STAFFTYPE' ) <> c_teaching.
      LOOP AT grade_fields( ) INTO DATA(lv_g).
        DELETE ct_kv WHERE key = lv_g.
      ENDLOOP.
      DELETE ct_kv WHERE key = 'SUBJECT'.
    ENDIF.

*   ---- UI-only keys ---------------------------------------------------
*   Pick targets and lookup inputs. They have no tech_name so they would not
*   reach a backend field anyway; deleting them keeps the posted item list to
*   what the application actually consists of.
    DELETE ct_kv WHERE key = 'LICENSE_SEL'
                    OR key = 'STAFF_SEL'
                    OR key = 'SEARCH_DOB'
                    OR key = 'SEARCH_NAT'
                    OR key = 'CAND_MOBILE'
                    OR key = 'CAND_EMAIL'
                    OR key = 'OWNER_BP'
                    OR key = 'LOGIN_BP'.

*   No fee on this journey, and the strip costs nothing. If a fee step is ever
*   added, the base class writes PAY_* carriers into the model and they are not
*   the backend's business.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.
*   How the backend learns which row was picked: column 29 = 'S' on the chosen
*   licence. The legacy D014 UPDATE reads exactly that - ui_table_name =
*   LICENSES with ui_table_column29 = 'S' - and it is the only way the selection
*   travels, because the grid posts every row.
    DATA(lv_lic) = io_ctx->get_val( 'LICENSE_SEL' ).
    IF lv_lic IS NOT INITIAL.
      LOOP AT ct_tables ASSIGNING FIELD-SYMBOL(<t>)
           WHERE ui_table_name = 'LICENSES' AND ui_table_column1 = lv_lic.
        <t>-ui_table_column29 = 'S'.
      ENDLOOP.
    ENDIF.

*   The same convention on the candidate list, which the legacy D015 UPDATE
*   reads the same way - it takes sy-tabix off the marked STAFF_LIST row to
*   index gs_data-staff_list.
    DATA(lv_stf) = io_ctx->get_val( 'STAFF_SEL' ).
    IF lv_stf IS NOT INITIAL AND lv_stf <> c_other_staff.
      LOOP AT ct_tables ASSIGNING <t>
           WHERE ui_table_name = 'STAFF_LIST' AND ui_table_column1 = lv_stf.
        <t>-ui_table_column29 = 'S'.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    CASE to_upper( iv_field ).

*     ---- a licence was picked ------------------------------------------
      WHEN 'LICENSE_SEL'.
        DATA(lv_lic) = io_ctx->get_val( 'LICENSE_SEL' ).
        CHECK lv_lic IS NOT INITIAL.

*       read_case fills the shared GS_DATA from the licence, which is what puts
*       the school block on step 2. It is the legacy call and it is the reason
*       every school field on that step is READONLY: none of it is typed.
        DATA(lv_recnr) = CONV recnnumber( lv_lic ).
        NEW zcl_dok_appln_handler_api( )->school_details(
          EXPORTING iv_recnnr    = lv_recnr
          IMPORTING et_school_dt = DATA(ls_school) ).

        IF ls_school IS INITIAL.
          io_ctx->add_msg( iv_type = 'Error'
            iv_text = |Licence { lv_lic } could not be read. Choose another, or contact DOK.| ).
          RETURN.
        ENDIF.

*       Publishing into the model rather than relying on the backend read: the
*       citizen picks the licence and moves on in one round trip, and waiting
*       for the next backend read would show them an empty school panel first.
        LOOP AT ls_school-school INTO DATA(ls_sch).
          io_ctx->set_val( iv_name = 'NAME_EN'         iv_value = CONV string( ls_sch-school_name_en ) ).
          io_ctx->set_val( iv_name = 'NAME_AR'         iv_value = CONV string( ls_sch-school_name_ab ) ).
          io_ctx->set_val( iv_name = 'REG_AUTHORITY'   iv_value = CONV string( ls_sch-reg_authority_tx ) ).
          io_ctx->set_val( iv_name = 'TRADE_LIC'       iv_value = CONV string( ls_sch-trade_lic ) ).
          io_ctx->set_val( iv_name = 'TELEPHONE'       iv_value = CONV string( ls_sch-telephone ) ).
          io_ctx->set_val( iv_name = 'CURRICULUM'      iv_value = CONV string( ls_sch-curriculum_tx ) ).
          io_ctx->set_val( iv_name = 'CURRICULUM_TYPE' iv_value = CONV string( ls_sch-curriculum_type ) ).
          io_ctx->set_val( iv_name = 'POBOX'           iv_value = CONV string( ls_sch-pobox ) ).
          io_ctx->set_val( iv_name = 'LOCATION'        iv_value = CONV string( ls_sch-location_tx ) ).
          io_ctx->set_val( iv_name = 'SCHOOL_ADRESS'   iv_value = CONV string( ls_sch-adress ) ).
          io_ctx->set_val( iv_name = 'PARCEL_ID'       iv_value = CONV string( ls_sch-parcel_id ) ).
          EXIT.
        ENDLOOP.

*     ---- a candidate was picked ----------------------------------------
      WHEN 'STAFF_SEL'.
        DATA(lv_sel) = io_ctx->get_val( 'STAFF_SEL' ).
        CHECK lv_sel IS NOT INITIAL.

*       OTHER means the citizen is about to search for somebody the school has
*       not registered. Clear the found-candidate fields so the lookup on the
*       next step starts empty rather than showing whoever was picked before.
        IF lv_sel = c_other_staff.
          io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = '' ).
          io_ctx->set_val( iv_name = 'CAND_NAME'       iv_value = '' ).
          io_ctx->set_val( iv_name = 'CAND_MOBILE'     iv_value = '' ).
          io_ctx->set_val( iv_name = 'CAND_EMAIL'      iv_value = '' ).
          RETURN.
        ENDIF.

*       A registered candidate needs no lookup: the partner is the picked key.
        io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = lv_sel ).

    ENDCASE.
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

    CASE iv_step.

*     ---- step 1: a licence must be picked ------------------------------
*     REQUIRED on the LICENSES field does not reach a grid, and the pick target
*     is a hidden READONLY that required does not cover either. So this is the
*     only thing stopping an application with no licence on it.
      WHEN 0.
        IF io_ctx->get_val( 'LICENSE_SEL' ) IS INITIAL.
          APPEND VALUE #( type = 'Error'
                          text = 'Select the licence this request is for.' ) TO rt.
        ENDIF.

*     ---- step 2: a candidate must be picked ----------------------------
      WHEN 1.
        IF io_ctx->get_val( 'STAFF_SEL' ) IS INITIAL.
          APPEND VALUE #( type = 'Error'
                          text = 'Select a candidate, or Other if they are not listed.' ) TO rt.
        ENDIF.

*     ---- step 3: the appointment ---------------------------------------
      WHEN 2.
*       The lookup must have SUCCEEDED, not merely been typed into. on_search
*       replaces the typed ID with the partner number, so anything that is not a
*       partner means Search was never pressed or it failed.
        IF io_ctx->get_val( 'CANDIDATESEARCH' ) IS INITIAL.
          APPEND VALUE #( type = 'Error'
                          text = 'Find the candidate with Search before continuing.' ) TO rt.
        ENDIF.

*       Relieving after appointment. Nothing in the config can express a
*       relationship between two dates, and a letter covering negative service
*       is not something to discover downstream.
        DATA(lv_from) = io_ctx->get_val( 'EFFECT_START' ).
        DATA(lv_to)   = io_ctx->get_val( 'EFFECT_END' ).
        IF lv_from IS NOT INITIAL AND lv_to IS NOT INITIAL AND lv_to < lv_from.
          APPEND VALUE #( type = 'Error'
                          text = 'The reliving date cannot be before the appointment date.' ) TO rt.
        ENDIF.

*       Grades, for Teaching only. The rules show and hide the boxes; only code
*       can say "at least one of these fifteen". This is the check the sample
*       handler documented and left commented out.
        IF io_ctx->get_val( 'STAFFTYPE' ) = c_teaching.
          DATA(lv_any) = abap_false.
          LOOP AT grade_fields( ) INTO DATA(lv_g).
            IF io_ctx->get_val( lv_g ) = 'X'.
              lv_any = abap_true.
              EXIT.
            ENDIF.
          ENDLOOP.
          IF lv_any = abap_false.
            APPEND VALUE #( type = 'Error'
                            text = 'Select at least one grade for a Teaching appointment.' ) TO rt.
          ENDIF.
        ENDIF.

      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
    super->zif_rak_journey_logic~on_init( io_ctx = io_ctx ).

*   The portal session hash is the only identity the journey is launched with.
*   Everything else - which BP, which role, which company - comes out of it.
    zcl_ega_cj_utility=>get_bp(
      EXPORTING
        qv_key  = io_ctx->get_param( iv_name = 'USERDATA' )
      IMPORTING
        loginbp = DATA(lv_loginbp)
        rolebp  = DATA(lv_rolebp)
        role    = DATA(lv_role) ).

    IF lv_loginbp IS INITIAL.
      lv_loginbp = '1000116563'.
*     No session. Say so rather than rendering an empty licence list, which
*     reads as "you have no licences" and is a different problem entirely.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = 'Your portal session could not be read. Please launch this service from the portal.' ).
      RETURN.
    ENDIF.

    io_ctx->set_val( iv_name = 'LOGIN_BP' iv_value = |{ lv_loginbp }| ).

*   The applicant is the logged-in BP, and the company is the role BP when the
*   citizen is acting for an organisation. The licence list belongs to whichever
*   of the two owns the school.
    DATA(lv_owner) = COND #( WHEN lv_rolebp IS NOT INITIAL THEN lv_rolebp ELSE lv_loginbp ).
    io_ctx->set_val( iv_name = 'OWNER_BP' iv_value = |{ lv_owner }| ).

    SELECT SINGLE zzfull_name_eng AS name_en, zzreferencea AS name_ar
      FROM but000 WHERE partner = @lv_loginbp INTO @DATA(ls_name).
    IF sy-subrc = 0.
      io_ctx->set_val( iv_name  = 'APP_NAME'
                       iv_value = COND #( WHEN sy-langu = 'A' AND ls_name-name_ar IS NOT INITIAL
                                          THEN CONV string( ls_name-name_ar )
                                          ELSE CONV string( ls_name-name_en ) ) ).
    ENDIF.

    SELECT SINGLE idnumber FROM but0id
      WHERE partner = @lv_loginbp AND type = @c_idtype_def
      INTO @DATA(lv_eid).
    io_ctx->set_val( iv_name = 'APP_ID' iv_value = CONV string( lv_eid ) ).

*   The declaration names the applicant, so it can only be built once the name
*   is known. Same two sentences as the legacy READ, same order, both languages.
    DATA(lv_who) = io_ctx->get_val( 'APP_NAME' ).
    io_ctx->set_val( iv_name  = 'DECLARATION_NAME'
                     iv_value = COND #(
                       WHEN sy-langu = 'A'
                       THEN |أنا، { lv_who }، بصفتي مالك الشركة، أقر بموجب هذا أن جميع المعلومات | &&
                            |المقدمة في هذا الطلب والمستندات المرفقة صحيحة ودقيقة.|
                       ELSE |I, { lv_who }, as the company owner, hereby declare that all information | &&
                            |provided in this application and in attached documents are true and | &&
                            |accurate, that I will be responsible for any consequences of them.| ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
    CHECK to_upper( iv_field ) = 'CANDIDATESEARCH'.

    DATA(lv_term) = condense( io_ctx->get_val( 'CANDIDATESEARCH' ) ).
    IF strlen( lv_term ) < c_min_len.
      io_ctx->add_msg( iv_type = 'Warning'
        iv_text = |Enter at least { c_min_len } characters to search| ).
      RETURN.
    ENDIF.

    DATA(lv_idtype) = io_ctx->get_val( 'CANDIDATESEARCH_IDTYPE' ).
    IF lv_idtype IS INITIAL.
      lv_idtype = c_idtype_def.
    ENDIF.

*   Dashes off before the FM sees it. 784-1988-2718131-8 and 784198827181318 are
*   the same Emirates ID and BUT0ID holds one of the two - which one depends on
*   who created the partner, so normalising is the only way this finds anybody.
    DATA(lv_num) = lv_term.
    REPLACE ALL OCCURRENCES OF '-' IN lv_num WITH ''.
    CONDENSE lv_num NO-GAPS.

    DATA lv_partner     TYPE partner.
    DATA lv_idnumber    TYPE bu_id_number.
    DATA lv_passport    TYPE bu_id_number.
    DATA lv_name        TYPE bu_name1tx.
    DATA lv_phone       TYPE farp_mobile.
    DATA lv_email       TYPE ad_smtpadr.
    DATA lv_natio       TYPE natio50.
    DATA lv_natio_key   TYPE bu_natio.
    DATA lv_dob         TYPE bu_birthdt.
    DATA lv_message     TYPE bapiret2-message.

    CALL FUNCTION 'ZFE_CJ_SEARCH_BP_BY_ID'
      EXPORTING
        iv_type            = CONV bu_id_type( lv_idtype )
        iv_idnumber        = CONV bu_id_number( lv_num )
      IMPORTING
        ev_partner         = lv_partner
        ev_id_number       = lv_idnumber
        ev_passport        = lv_passport
        ev_name            = lv_name
        ev_phone           = lv_phone
        ev_email           = lv_email
        ev_nationality     = lv_natio
        ev_nationality_key = lv_natio_key
        ev_date_of_birth   = lv_dob
        ev_message         = lv_message.

*   EV_MESSAGE IS READ, and this is the fix. The sample handler called the same
*   FM and ignored it, so a candidate who was not found produced six blank
*   fields and no explanation - indistinguishable from one who was found with
*   nothing on file.
    IF lv_partner IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
        iv_text = COND #( WHEN lv_message IS NOT INITIAL THEN CONV string( lv_message )
                          ELSE |No person found for { lv_term }.| ) ).
      io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = '' ).
      RETURN.
    ENDIF.

*   ---- the two search inputs are CHECKS, not decoration ---------------
*   Date of birth and nationality are on that panel to confirm the person, the
*   same way the MOI cross-check does on a partner search. Finding somebody
*   whose date of birth disagrees with what was typed is a WRONG MATCH, and
*   accepting it would put an experience letter against the wrong staff member.
    DATA(lv_ask_dob) = io_ctx->get_val( 'SEARCH_DOB' ).
    IF lv_ask_dob IS NOT INITIAL AND lv_dob IS NOT INITIAL
       AND lv_ask_dob <> |{ lv_dob }|.
      io_ctx->add_msg( iv_type = 'Error'
        iv_text = 'The date of birth does not match the person found for that ID.' ).
      io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = '' ).
      RETURN.
    ENDIF.

    DATA(lv_ask_nat) = io_ctx->get_val( 'SEARCH_NAT' ).
    IF lv_ask_nat IS NOT INITIAL AND lv_natio_key IS NOT INITIAL
       AND lv_ask_nat <> |{ lv_natio_key }|.
      io_ctx->add_msg( iv_type = 'Error'
        iv_text = 'The nationality does not match the person found for that ID.' ).
      io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = '' ).
      RETURN.
    ENDIF.

*   The partner number, not the typed ID, into the field the backend reads.
*   CANDIDATESEARCH carries GS_DATA-STAFF-PARTNER, so this is the answer.
    io_ctx->set_val( iv_name = 'CANDIDATESEARCH' iv_value = |{ lv_partner }| ).
    io_ctx->set_val( iv_name = 'CAND_NAME'       iv_value = |{ lv_name }| ).
    io_ctx->set_val( iv_name = 'CAND_MOBILE'     iv_value = |{ lv_phone }| ).
    io_ctx->set_val( iv_name = 'CAND_EMAIL'      iv_value = |{ lv_email }| ).

*   Filling the two inputs back in from what was found, when they were left
*   empty. The citizen sees which person was matched, and a second Search then
*   has the cross-check to work with.
    IF lv_ask_dob IS INITIAL AND lv_dob IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'SEARCH_DOB' iv_value = |{ lv_dob }| ).
    ENDIF.
    IF lv_ask_nat IS INITIAL AND lv_natio_key IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'SEARCH_NAT' iv_value = |{ lv_natio_key }| ).
    ENDIF.

    io_ctx->add_msg( iv_type = 'Success' iv_text = |{ lv_name } found.| ).
  ENDMETHOD.
ENDCLASS.
