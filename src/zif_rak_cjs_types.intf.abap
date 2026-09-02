INTERFACE zif_rak_cjs_types
  PUBLIC.

*   Types shared between the journey engine and its collaborator classes.
*   They were private to ZCL_RAK_JOURNEY_ENGINE until the engine was split; the
*   engine still declares an alias for each, so nothing that referenced the old
*   name had to change.

  TYPES: BEGIN OF ty_betab,
           field TYPE string,
           data  TYPE zif_rak_journey=>ty_table,
         END OF ty_betab,
         tt_betab TYPE STANDARD TABLE OF ty_betab WITH EMPTY KEY.

  TYPES: BEGIN OF ty_bp_hit,
           partner TYPE string,
           name    TYPE string,
           idnum   TYPE string,
         END OF ty_bp_hit,
         tt_bp_hit TYPE STANDARD TABLE OF ty_bp_hit WITH EMPTY KEY.

  TYPES: BEGIN OF ty_att,
           field TYPE string,
           tech  TYPE string,
           name  TYPE string,
           guid  TYPE string,
           filed TYPE abap_bool,   " already handed to the backend - never send twice
"          Which OCCURRENCE of the field this file belongs to - an owner, a
"          vehicle, a line. Blank means the field itself, which is every
"          attachment that existed before this column did.
"
"          A field alone cannot answer "whose document is this". Two owners
"          uploading an ID copy against one UPLOAD field produced two chips with
"          nothing to tell them apart, and a backend that could file neither.
"
"          The convention is the legacy one, not a new one: the D0xx BAdI
"          already reads an occurrence out of identifier1 - see OWNERS_SEARCH_<n>
"          in ZCL_EGA_CJ_DOK_ABS - so the key is appended there as FIELD_KEY.
           okey  TYPE string,
"          THE LEGACY DOCUMENT TYPE, and the reason a case cannot currently
"          tell a title deed from an Emirates ID.
"
"          Every legacy uploader carries DATA2 = 1/2/3 in
"          /QNV/SB_UI_DEFIN and the BAdI files it as ZDT_EGA_CJ_ATTR-DIFFCRT.
"          ATTACHMENTS_FOR_BACKEND( ) sent only identifier1/2, file_name and
"          file_content, so DIFFCRT arrived blank - and CREATE_ATTACHMENT
"          only checks OBJTRG and OBJSRC, so it passed silently.
"
"          It is worse than a missing label. GET_ATTACHMENT( ) de-duplicates
"          on (objsrc, diffcrt, objsrctype, objtrgtype), so with DIFFCRT
"          blank on every file, two documents on ONE field come back as one.
"          That is why ATTACH_MULTI is off on every migrated uploader.
"
"          Carried in the field's DEFAULT_VAL behind a DTYPE: prefix - the
"          same convention as TEXT: and API:, and for the same reason: an
"          uploader has no use for a default value, and a new DDIC column
"          would need an activation and a table adjust before anything
"          could use it.
           dtype TYPE string,
         END OF ty_att,
         tt_att TYPE STANDARD TABLE OF ty_att WITH EMPTY KEY.

  TYPES: BEGIN OF ty_gcol,
           name  TYPE string,   " column field (model component, upper)
           label TYPE string,   " column header
           ctype TYPE string,   " INPUT | NUMBER | DATE | SELECT
           src   TYPE string,   " data element for a SELECT column (optional)
"          Drawn or not drawn, and NOTHING else. A hidden column is still a
"          column: it keeps its model component, it round-trips through
"          grid_to_json / grid_from_json, and it goes to the BAdI with the rest of
"          the row. Only the renderer is allowed to care about this flag.
"
"          That distinction is the whole point. The columns worth hiding are the
"          ones the backend needs and the citizen must not see - the row key that
"          ROWPICK sends back, a document type code, an internal sequence - and
"          dropping them from the column list instead would take them out of the
"          payload as well, which is how a picklist stops being able to say which
"          row was picked.
           hide  TYPE abap_bool,
"          Everything below comes from ZRAK_T_JNY_COL, when a grid has rows
"          there. A grid still on a packed DEFAULT_VAL spec never populates
"          these - grid_cols( ) leaves them at their type-initial value, and
"          every check below is written to treat that as "not set".
           label_ar TYPE string,   " ZLABEL_AR - bilingual header
           shlp     TYPE string,   " search help name (not yet wired to a real
"                                    F4 popup - captured for authoring intent;
"                                    SELECT still resolves via ROLLNAME/SRC or
"                                    the handler's on_value_help, same as today)
           width    TYPE string,   " column( ) width, e.g. '8rem' or '20%'
           align    TYPE string,   " Begin | Center | End -> column( )-halign
           pinned   TYPE abap_bool," captured from ZRAK_T_JNY_COL-PINNED; NOT
"                                    rendered - sap.m.Table has no frozen/
"                                    sticky-column feature to bind it to
           readonly TYPE abap_bool," per-column read-only, ORed with the
"                                    grid's own whole-grid readonly
           required TYPE abap_bool," captured, not yet enforced - per-row
"                                    required validation is not wired into
"                                    VALIDATE_STEP/MISSING_REQUIRED yet
           decimals TYPE i,        " captured, not yet enforced - no decimal
"                                    formatting is applied to the cell
           maxlen   TYPE i,        " -> input( )-maxlength
           total    TYPE abap_bool," included in the grid's footer sum
"          Per-row visibility/edit expressions, computed at render time by
"          ZCL_RAK_JOURNEY_GRID from a ZRAK_T_JNY_RULE row whose TOTABLE names
"          this grid and whose SRC_FIELD is itself one of this grid's own
"          columns. Native UI5 expression-binding strings, e.g.
"          '{= ${STATUS} <> ''X'' }' - never persisted, never touched by
"          grid_cols( ).
           row_vis  TYPE string,
           row_edit TYPE string,
         END OF ty_gcol,
         tt_gcol TYPE STANDARD TABLE OF ty_gcol WITH EMPTY KEY.

*   A ZRAK_T_JNY_RULE row whose TOTABLE is filled: routed here by
*   ZCL_RAK_JOURNEY_RULES->EVAL_RULES instead of being evaluated as a scalar
*   field rule, because there is no single value to read at that point - the
*   grid decides, per column and (when SRC_FIELD is itself one of its own
*   columns) per row, at render time.
  TYPES: BEGIN OF ty_gridrule,
           totable   TYPE string,   " the EDITABLE_TABLE/TABLE field this rule targets
           src_field TYPE string,   " a column of TOTABLE (per row) or any other field (whole column)
           src_op    TYPE string,   " EQ | NE | INITIAL | NOTINITIAL
           src_value TYPE string,
           action    TYPE string,   " HIDE | SHOW | READONLY | EDITABLE
           tgt_field TYPE string,   " the column within TOTABLE the action applies to
         END OF ty_gridrule,
         tt_gridrule TYPE STANDARD TABLE OF ty_gridrule WITH EMPTY KEY.

  TYPES: BEGIN OF ty_f4c,
           key  TYPE string,
           opts TYPE zif_rak_journey=>tt_option,
         END OF ty_f4c,
         tt_f4c TYPE HASHED TABLE OF ty_f4c WITH UNIQUE KEY key.

  TYPES: BEGIN OF ty_miss,
           name  TYPE string,
           label TYPE string,
           kind  TYPE string,   " ATT | VAL
           msg   TYPE string,
         END OF ty_miss,
         tt_miss TYPE STANDARD TABLE OF ty_miss WITH EMPTY KEY.

*   Field properties a HANDLER set, as opposed to ones a rule set.
  TYPES: BEGIN OF ty_ovr,
           field TYPE string,
           prop  TYPE string,
           on    TYPE abap_bool,
         END OF ty_ovr,
         tt_ovr TYPE STANDARD TABLE OF ty_ovr WITH EMPTY KEY.

ENDINTERFACE.
