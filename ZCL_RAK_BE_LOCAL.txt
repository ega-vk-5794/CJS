*&---------------------------------------------------------------------*
*& ZCL_RAK_BE_LOCAL  —  "backend not built yet" implementation
*&
*& Persists a journey to a local staging table instead of calling any
*& external system. Selected by backend_type = 'LOCAL' via the factory.
*& Proves the pluggable-backend design and lets a journey run end-to-end
*& (draft -> party -> BO -> submit) with no auth, SSL, or external system.
*&
*& Switch a journey's config from LOCAL to REST/QNV with no field-config
*& change: that swap is the acceptance test for the whole abstraction.
*&---------------------------------------------------------------------*
*
*  DDIC — create these two transparent tables in SE11 before activating.
*
*  ------------------------------------------------------------------
*  ZRAK_T_BE_LOC   (header — one row per journey instance)
*  ------------------------------------------------------------------
*    MANDT       MANDT          CLNT 3     key
*    REQUEST_ID  ZRAK_JOURNEY_ID? use CHAR 32  key   (locally minted GUID32)
*    JOURNEY_ID  ZRAK_JOURNEY_ID  CHAR 30
*    STATUS      CHAR 10                       (DRAFT / SUBMITTED)
*    BO_ID       CHAR 32
*    AMOUNT      CHAR 20
*    PAYLOAD     STRING                        (flattened fields as JSON)
*    CREATED_BY  SYUNAME
*    CREATED_AT  TIMESTAMPL
*    CHANGED_AT  TIMESTAMPL
*
*  ------------------------------------------------------------------
*  ZRAK_T_BE_LOC_P (party child — one row per added party)
*  ------------------------------------------------------------------
*    MANDT       MANDT          CLNT 3     key
*    REQUEST_ID  CHAR 32                    key
*    PARTY_ID    CHAR 32                    key   (locally minted)
*    IS_FIRST    CHAR 1
*    PAYLOAD     STRING                           (party fields as JSON)
*
*  If your naming standard differs, adjust the table names in this class
*  (mc_thdr / mc_tpty) and the field list to match.
*&---------------------------------------------------------------------*

CLASS zcl_rak_be_local DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_rak_journey_backend.

    METHODS constructor
      IMPORTING iv_journey TYPE string OPTIONAL.

  PRIVATE SECTION.

    DATA mv_journey TYPE string.

    METHODS new_guid
      RETURNING VALUE(rv) TYPE string.

    METHODS kv_json
      IMPORTING it_fields      TYPE zif_rak_journey_backend=>tt_field
      RETURNING VALUE(rv_json) TYPE string.

    METHODS field
      IMPORTING it_fields       TYPE zif_rak_journey_backend=>tt_field
                iv_name         TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    METHODS msg
      IMPORTING iv_type   TYPE bapiret2-type
                iv_text   TYPE string
      CHANGING  ct_return TYPE bapiret2_t.

ENDCLASS.



CLASS ZCL_RAK_BE_LOCAL IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_JOURNEY                     TYPE        STRING(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD constructor.
    mv_journey = iv_journey.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_RAK_BE_LOCAL->FIELD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_FIELDS                      TYPE        ZIF_RAK_JOURNEY_BACKEND=>TT_FIELD
* | [--->] IV_NAME                        TYPE        STRING
* | [<-()] RV_VALUE                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD field.
    rv_value = VALUE #( it_fields[ name = to_upper( iv_name ) ]-value OPTIONAL ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_RAK_BE_LOCAL->KV_JSON
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_FIELDS                      TYPE        ZIF_RAK_JOURNEY_BACKEND=>TT_FIELD
* | [<-()] RV_JSON                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD kv_json.
    IF it_fields IS INITIAL.
      rv_json = '{}'.
      RETURN.
    ENDIF.
    DATA lv_body TYPE string.
    LOOP AT it_fields INTO DATA(ls_f).
      DATA(lv_val) = ls_f-value.
      REPLACE ALL OCCURRENCES OF '\' IN lv_val WITH '\\'.
      REPLACE ALL OCCURRENCES OF '"' IN lv_val WITH '\"'.
      lv_body = COND #( WHEN lv_body IS INITIAL
                        THEN |"{ ls_f-name }":"{ lv_val }"|
                        ELSE |{ lv_body },"{ ls_f-name }":"{ lv_val }"| ).
    ENDLOOP.
    rv_json = |\{{ lv_body }\}|.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_RAK_BE_LOCAL->MSG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_TYPE                        TYPE        BAPIRET2-TYPE
* | [--->] IV_TEXT                        TYPE        STRING
* | [<-->] CT_RETURN                      TYPE        BAPIRET2_T
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD msg.
    APPEND VALUE bapiret2( type = iv_type id = 'ZCJS' number = '000' message = iv_text )
           TO ct_return.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_RAK_BE_LOCAL->NEW_GUID
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RV                             TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD new_guid.
    TRY.
        rv = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        rv = |{ sy-datum }{ sy-uzeit }{ sy-timlo }|.
    ENDTRY.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~ATTACH
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_FILE                        TYPE        TY_FILE
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~attach.
    " Local backend does not persist file bytes; acknowledge so the flow proceeds.
    msg( EXPORTING iv_type = 'S'
                   iv_text = |Attachment '{ is_file-name }' accepted (local staging)|
         CHANGING  ct_return = et_return ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~CAPABILITIES
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RS_CAP                         TYPE        TY_CAP
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~capabilities.
    rs_cap = VALUE #( immediate   = abap_true
                      resumable   = abap_true
                      attachments = abap_true
                      payment     = abap_true ).
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~DESCRIBE_STEP
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STEP                        TYPE        STRING
* | [<-()] RT_FIELDS                      TYPE        TT_DYN_FIELD
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~describe_step.
*   Local staging has no dynamic steps.
    RETURN.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~DISCARD
* +-------------------------------------------------------------------------------------------------+
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~discard.
    IF cs_handle-request_id IS INITIAL.
      RETURN.
    ENDIF.
    DELETE FROM zrak_t_be_loc_p WHERE request_id = @cs_handle-request_id.
    DELETE FROM zrak_t_be_loc   WHERE request_id = @cs_handle-request_id.
    CLEAR cs_handle.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~INIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_FIELDS                      TYPE        TT_FIELD
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~init.
    DATA(lv_id) = new_guid( ).
    GET TIME STAMP FIELD DATA(lv_ts).

    DATA(lv_jny) = COND string( WHEN mv_journey IS NOT INITIAL THEN mv_journey
                                ELSE field( it_fields = it_fields iv_name = 'subServiceId' ) ).

    INSERT zrak_t_be_loc FROM @( VALUE #(
      request_id = lv_id
      journey_id = lv_jny
      status     = 'DRAFT'
      payload    = kv_json( it_fields )
      created_by = sy-uname
      created_at = lv_ts
      changed_at = lv_ts ) ).

    IF sy-subrc <> 0.
      msg( EXPORTING iv_type = 'E' iv_text = 'Local staging insert failed' CHANGING ct_return = et_return ).
      RETURN.
    ENDIF.

    cs_handle-request_id = lv_id.
    cs_handle-status     = 'DRAFT'.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~PAY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EVENT                       TYPE        STRING
* | [--->] IT_FIELDS                      TYPE        TT_FIELD
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~pay.
    " Local backend simulates payment so the journey can complete without a gateway.
    CASE iv_event.
      WHEN 'CALC'.
        IF cs_handle-amount IS INITIAL.
          cs_handle-amount = '50.00'.
        ENDIF.
      WHEN 'CREATE'.
        IF cs_handle-bdo IS INITIAL.
          cs_handle-bdo = new_guid( ).
        ENDIF.
      WHEN 'LOCK'.
        " no-op locally
      WHEN 'PAID'.
        cs_handle-status = 'PAID'.
        GET TIME STAMP FIELD DATA(lv_ts).
        UPDATE zrak_t_be_loc
          SET status     = 'PAID',
              amount     = @cs_handle-amount,
              changed_at = @lv_ts
          WHERE request_id = @cs_handle-request_id.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~RESUME
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_REQUEST_ID                  TYPE        STRING
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~resume.
    SELECT SINGLE journey_id, status, bo_id, amount
      FROM zrak_t_be_loc
      WHERE request_id = @iv_request_id
      INTO @DATA(ls_hdr).
    IF sy-subrc <> 0.
      msg( EXPORTING iv_type = 'E' iv_text = |Local request { iv_request_id } not found| CHANGING ct_return = et_return ).
      RETURN.
    ENDIF.
    cs_handle-request_id = iv_request_id.
    cs_handle-status     = ls_hdr-status.
    cs_handle-bo_id      = ls_hdr-bo_id.
    cs_handle-amount     = ls_hdr-amount.

    SELECT party_id FROM zrak_t_be_loc_p
      WHERE request_id = @iv_request_id
      INTO TABLE @DATA(lt_p).
    LOOP AT lt_p INTO DATA(ls_p).
      APPEND ls_p-party_id TO cs_handle-party_ids.
    ENDLOOP.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~STEP_COMMIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_STEP                        TYPE        STRING
* | [--->] IT_FIELDS                      TYPE        TT_FIELD
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~step_commit.
    GET TIME STAMP FIELD DATA(lv_ts).

    CASE iv_step.

      WHEN 'PARTY1' OR 'PARTY2'.
        DATA(lv_pid) = new_guid( ).
        INSERT zrak_t_be_loc_p FROM @( VALUE #(
          request_id = cs_handle-request_id
          party_id   = lv_pid
          is_first   = COND #( WHEN iv_step = 'PARTY1' THEN 'X' ELSE '' )
          payload    = kv_json( it_fields ) ) ).
        IF sy-subrc = 0.
          APPEND lv_pid TO cs_handle-party_ids.
        ELSE.
          msg( EXPORTING iv_type = 'E' iv_text = 'Local party insert failed' CHANGING ct_return = et_return ).
        ENDIF.

      WHEN 'BO'.
        IF cs_handle-bo_id IS INITIAL.
          cs_handle-bo_id = new_guid( ).
        ENDIF.
        UPDATE zrak_t_be_loc
          SET bo_id      = @cs_handle-bo_id,
              payload    = @( kv_json( it_fields ) ),
              changed_at = @lv_ts
          WHERE request_id = @cs_handle-request_id.
        IF sy-subrc <> 0.
          msg( EXPORTING iv_type = 'E' iv_text = 'Local BO update failed' CHANGING ct_return = et_return ).
        ENDIF.

      WHEN 'LEGAL' OR 'BILLING'.
        UPDATE zrak_t_be_loc
          SET changed_at = @lv_ts
          WHERE request_id = @cs_handle-request_id.

      WHEN OTHERS.
        RETURN.

    ENDCASE.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_RAK_BE_LOCAL->ZIF_RAK_JOURNEY_BACKEND~SUBMIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_FIELDS                      TYPE        TT_FIELD
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* | [<-->] CS_HANDLE                      TYPE        TY_HANDLE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD zif_rak_journey_backend~submit.
    GET TIME STAMP FIELD DATA(lv_ts).
    UPDATE zrak_t_be_loc
      SET status     = 'SUBMITTED',
          changed_at = @lv_ts
      WHERE request_id = @cs_handle-request_id.
    IF sy-subrc <> 0.
      msg( EXPORTING iv_type = 'E' iv_text = 'Local submit failed' CHANGING ct_return = et_return ).
      RETURN.
    ENDIF.
    cs_handle-status = 'SUBMITTED'.
  ENDMETHOD.
ENDCLASS.