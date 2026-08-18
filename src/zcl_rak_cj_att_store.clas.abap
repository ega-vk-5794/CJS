CLASS zcl_rak_cj_att_store DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Side-store for in-session attachment blobs.
    "!
    "! WHY: attachment base64 content must NOT live in the engine instance
    "! (it would serialize into the z2ui5 draft blob on every round-trip)
    "! nor in the rendered view XML (megabytes over the wire per render).
    "! Blobs live in transparent table ZRAK_CJ_ATTX keyed by GUID; the
    "! engine keeps only (field, name, guid). Content is materialized at
    "! POST time (ATTACHMENTS_FOR_BACKEND) and streamed for inline preview
    "! by the ICF handler ZCL_RAK_CJ_ATT_HTTP.
    "!
    "! REQUIRED DDIC OBJECT — transparent table ZRAK_CJ_ATTX (SE11),
    "! delivery class A, data class APPL1, size cat. by volume:
    "!   MANDT     key  MANDT       (CLNT 3)
    "!   GUID      key  SYSUUID_C32 (CHAR 32)
    "!   UNAME          XUBNAME     (CHAR 12)   owner — cross-user guard
    "!   FILE_NAME      built-in    CHAR 255
    "!   MIMETYPE       built-in    CHAR 128
    "!   ERDAT          ERDAT       (DATS 8)    housekeeping
    "!   CONTENT        built-in    STRING      full data:<mime>;base64,... URL
    "! A plain INSERT/SELECT table — no EXPORT/IMPORT cluster contract.
    "!
    "! HOUSEKEEPING: schedule ZRAK_CJ_ATT_PURGE daily.

    "! Stores one blob, returns its GUID ('' on failure).
    "! EV_MSG carries the concrete reason on failure (for on-screen diag).
    CLASS-METHODS put
      IMPORTING iv_name        TYPE string
                iv_b64         TYPE string
      EXPORTING ev_msg         TYPE string
      RETURNING VALUE(rv_guid) TYPE string.

    "! Loads one blob by GUID. All EV_* initial when not found.
    "! When IV_UNAME is supplied it must match the stored owner, else
    "! nothing is returned (cross-user access guard for the ICF handler).
    CLASS-METHODS get
      IMPORTING iv_guid  TYPE string
                iv_uname TYPE xubname OPTIONAL
      EXPORTING ev_name  TYPE string
                ev_mime  TYPE string
                ev_b64   TYPE string.

    CLASS-METHODS delete
      IMPORTING iv_guid TYPE string.

    "! Removes blobs older than IV_DAYS. Run via ZRAK_CJ_ATT_PURGE.
    CLASS-METHODS purge
      IMPORTING iv_days TYPE i DEFAULT 7.

  PRIVATE SECTION.
    "! Extracts the MIME type from a data URL header ('' if not a data URL).
    CLASS-METHODS mime_of
      IMPORTING iv_b64        TYPE string
      RETURNING VALUE(rv_mime) TYPE string.
ENDCLASS.



CLASS ZCL_RAK_CJ_ATT_STORE IMPLEMENTATION.


  METHOD delete.
    IF iv_guid IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_guid) = CONV sysuuid_c32( iv_guid ).
    DELETE FROM zrak_cj_attx WHERE guid = @lv_guid.
    " commit handled by the z2ui5 end-of-request draft persistence
  ENDMETHOD.


  METHOD get.
    CLEAR: ev_name, ev_mime, ev_b64.
    IF iv_guid IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_guid) = CONV sysuuid_c32( iv_guid ).

    SELECT SINGLE uname, file_name, mimetype, content
      FROM zrak_cj_attx
      WHERE guid = @lv_guid
      INTO @DATA(ls_row).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " owner guard — only enforced when a user is supplied (ICF preview)
    IF iv_uname IS SUPPLIED AND iv_uname IS NOT INITIAL
       AND ls_row-uname <> iv_uname.
      RETURN.
    ENDIF.

    ev_name = ls_row-file_name.
    ev_mime = ls_row-mimetype.
    ev_b64  = ls_row-content.
  ENDMETHOD.


  METHOD mime_of.
    " data:application/pdf;base64,JVBERi0...  ->  application/pdf
    IF strlen( iv_b64 ) < 5 OR substring( val = iv_b64 len = 5 ) <> 'data:'.
      RETURN.
    ENDIF.
    DATA(lv_head) = substring_before( val = iv_b64 sub = ';base64,' ).
    IF lv_head IS INITIAL.
      RETURN.
    ENDIF.
    rv_mime = substring( val = lv_head off = 5 ).   " strip 'data:'
  ENDMETHOD.


  METHOD purge.
    DATA(lv_cutoff) = CONV d( sy-datum - iv_days ).
    DELETE FROM zrak_cj_attx WHERE erdat < @lv_cutoff.
    " commit owned by the calling report
  ENDMETHOD.


  METHOD put.
    CLEAR ev_msg.
    DATA lv_uuid TYPE sysuuid_c32.
    TRY.
        lv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        ev_msg = 'UUID generation failed on this kernel'.
        RETURN.
    ENDTRY.

    DATA ls_row TYPE zrak_cj_attx.
    ls_row-guid      = lv_uuid.
    ls_row-uname     = sy-uname.
    ls_row-file_name = iv_name.
    ls_row-mimetype  = mime_of( iv_b64 ).
    ls_row-erdat     = sy-datum.
    ls_row-content   = iv_b64.

    INSERT zrak_cj_attx FROM ls_row.
    IF sy-subrc <> 0.
      " sy-subrc = 4 on a unique-key violation. Since every row carries a
      " fresh UUID, a duplicate here means the table's PRIMARY KEY does not
      " include GUID (only MANDT is key) — so it can hold just one row and
      " every insert after the first collides. Fix is in SE11, not here.
      ev_msg = COND #(
        WHEN sy-subrc = 4
        THEN 'INSERT rejected as duplicate key — mark GUID as a Key field in ZRAK_CJ_ATTX (SE11)'
        ELSE |INSERT failed (sy-subrc={ sy-subrc }) on ZRAK_CJ_ATTX| ).
      RETURN.
    ENDIF.
    COMMIT WORK.
    " z2ui5 commits the round-trip draft at end of request, which persists
    " this INSERT too; an explicit commit here is not required and avoids
    " interfering with the framework LUW.

    rv_guid = lv_uuid.
  ENDMETHOD.
ENDCLASS.
