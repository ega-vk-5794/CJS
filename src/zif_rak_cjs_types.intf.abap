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
         END OF ty_gcol,
         tt_gcol TYPE STANDARD TABLE OF ty_gcol WITH EMPTY KEY.

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
