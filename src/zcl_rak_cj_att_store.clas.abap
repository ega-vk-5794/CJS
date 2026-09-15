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
    "! IV_JOURNEY is what makes a purge precise instead of a date sweep.
    "! OPTIONAL so the two existing callers outside the engine keep compiling;
    "! a row stored without it is exactly as untraceable as every row was
    "! before, which is the state this is digging out of.
    CLASS-METHODS put
      IMPORTING iv_name        TYPE string
                iv_b64         TYPE string
                iv_journey     TYPE string OPTIONAL
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

    "! Marks every staged file of one journey as filed against the case.
    "! A filed row has a second copy on the case, so purging it loses nothing -
    "! which is the difference between a retention sweep and data loss.
    CLASS-METHODS mark_filed
      IMPORTING it_guid TYPE string_table.

    "! Removes blobs older than IV_DAYS. Run via ZRAK_CJ_ATT_PURGE.
    "! IV_JOURNEY restricts the sweep to one journey, so a handler's own
    "! RETENTION( ) policy can be honoured per journey rather than one age
    "! being applied to all of them.
    "! IV_FILED_ONLY removes only files that have a copy on the case. That is
    "! the safe sweep: what it leaves behind is precisely the staged-but-never-
    "! posted files, which are the ones a resumed draft still needs and the ones
    "! a short retention would otherwise destroy.
    CLASS-METHODS purge
      IMPORTING iv_days       TYPE i DEFAULT 7
                iv_journey    TYPE string OPTIONAL
                iv_filed_only TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_del) TYPE i.

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


  METHOD mark_filed.
*   Called once the post has put these files on the case. It does not delete:
*   the citizen may still press Back, and RENDER_CHIPS( ) draws the staged copy
*   as well as the case copy. All it records is that a purge may now take them.
    CHECK it_guid IS NOT INITIAL.

*   A DECLARED RANGE, NOT AN INLINE @( VALUE #( ) ). The inline host expression
*   is refused in an UPDATE ... WHERE - "@( is invalid here (due to grammar)" -
*   so the range is built first and passed as a plain host variable. Same
*   shape PURGE( ) below already uses.
    DATA lt_r TYPE RANGE OF zrak_cj_attx-guid.
    LOOP AT it_guid INTO DATA(lv_g).
      CHECK lv_g IS NOT INITIAL.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_g ) TO lt_r.
    ENDLOOP.
    CHECK lt_r IS NOT INITIAL.

    UPDATE zrak_cj_attx SET filed = 'X' WHERE guid IN @lt_r.
    " commit owned by the caller, as PURGE( ) is
  ENDMETHOD.

  METHOD purge.
    DATA(lv_cutoff) = CONV d( sy-datum - iv_days ).

*   RANGES RATHER THAN A DYNAMIC WHERE. Both restrictions are optional and an
*   empty range matches everything, so one statement covers all four
*   combinations without assembling SQL from strings.
    DATA lt_j TYPE RANGE OF zrak_cj_attx-journey_id.
    IF iv_journey IS NOT INITIAL.
      lt_j = VALUE #( ( sign = 'I' option = 'EQ' low = to_upper( iv_journey ) ) ).
    ENDIF.
    DATA lt_f TYPE RANGE OF zrak_cj_attx-filed.
    IF iv_filed_only = abap_true.
      lt_f = VALUE #( ( sign = 'I' option = 'EQ' low = 'X' ) ).
    ENDIF.

    DELETE FROM zrak_cj_attx
      WHERE erdat      <  @lv_cutoff
        AND journey_id IN @lt_j
        AND filed      IN @lt_f.
    rv_del = sy-dbcnt.
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
    ls_row-journey_id = iv_journey.
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
