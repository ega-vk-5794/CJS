INTERFACE zif_rak_journey
  PUBLIC.

  TYPES:
    BEGIN OF ty_validation,
      required TYPE abap_bool,
      regex    TYPE string,
      min_len  TYPE i,
      max_len  TYPE i,
      min_val  TYPE string,
      max_val  TYPE string,
      msg      TYPE string,
    END OF ty_validation.
  TYPES:
    BEGIN OF ty_option,
      key  TYPE string,
      text TYPE string,
    END OF ty_option,
    tt_option TYPE STANDARD TABLE OF ty_option WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_field,
      name         TYPE string,
      label        TYPE string,
      type         TYPE string,
      placeholder  TYPE string,
      default      TYPE string,
      group        TYPE string,
      section      TYPE string,
      state        TYPE string,
      width        TYPE string,
      has_attach   TYPE abap_bool,
      attach_label TYPE string,
      attach_types TYPE string,
      attach_maxmb TYPE i,
      attach_multi TYPE abap_bool,
      rollname     TYPE string,
      shlp         TYPE string,
      domname      TYPE string,
      tech_name    TYPE string,
      hidden       TYPE abap_bool,
      readonly     TYPE abap_bool,
      options      TYPE tt_option,
      validation   TYPE ty_validation,
    END OF ty_field,
    tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_step,
      id          TYPE string,
      title       TYPE string,
      icon        TYPE string,
      columns     TYPE i,
      bknd_screen TYPE string,
      " Names a field on this journey that must hold a value before the footer
      " button leaves this step. Blank means no gate, which is every step that
      " existed before this column did.
      "
      " It is here for the payment step. on_custom_validate( ) already refuses
      " to move on until the fee is PAID, but it refuses AFTER the citizen has
      " pressed - so the page showed an available button, took the press, and
      " then said no. This lets the page say what it wants beforehand.
      "
      " Value-based rather than a PAYFEE flag on purpose: any step with a
      " precondition the citizen must satisfy can use it, and the engine does
      " not have to learn a new special case each time.
      next_req    TYPE string,
      no_forward  TYPE abap_bool,
      fields      TYPE tt_field,
    END OF ty_step,
    tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_theme,
      variant      TYPE string,
      layout_mode  TYPE string,
      accent_type  TYPE string,
      brand_color  TYPE string,
      navy_color   TYPE string,
      density      TYPE string,
      subtitle     TYPE string,
      subtitle_ar  TYPE string,
      show_actions TYPE abap_bool,
    END OF ty_theme.
  TYPES:
    BEGIN OF ty_item,
      field TYPE string,
      tech  TYPE string,
      value TYPE string,
    END OF ty_item,
    tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_backend,
      active      TYPE abap_bool,
      category    TYPE string,
      journey     TYPE string,   " BE journey code = BAdI filter (e.g. D011)
      fm_post     TYPE string,
      fm_read     TYPE string,
      userdata    TYPE string,   " runtime: portal session hash from launch URL
      loginbp_dev TYPE string,   " runtime: dev-only BP override (&loginbp=)
      rolebp      TYPE string,
      role        TYPE string,
      context     TYPE tt_item,  " runtime: full launch param set, forwarded to the FMs as items
    END OF ty_backend.
  TYPES:
    BEGIN OF ty_rule,
      rule_id   TYPE string,
      src_field TYPE string,
      src_op    TYPE string,
      src_value TYPE string,
      action    TYPE string,
      tgt_field TYPE string,
      tgt_value TYPE string,
    END OF ty_rule,
    tt_rule TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_config,
      journey_id    TYPE string,
      title         TYPE string,
      cj_type       TYPE string,
      handler_class TYPE string,
      theme         TYPE ty_theme,
      backend       TYPE ty_backend,
      steps         TYPE tt_step,
      rules         TYPE tt_rule,
    END OF ty_config.
  TYPES:
    tt_string TYPE STANDARD TABLE OF string WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_table,
      columns TYPE tt_string,
      rows    TYPE STANDARD TABLE OF tt_string WITH EMPTY KEY,
    END OF ty_table.
  TYPES:
    BEGIN OF ty_attach,
      title TYPE string,
      url   TYPE string,
    END OF ty_attach,
    tt_attach TYPE STANDARD TABLE OF ty_attach WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_kv,
      key   TYPE string,
      value TYPE string,
    END OF ty_kv,
    tt_kv TYPE STANDARD TABLE OF ty_kv WITH EMPTY KEY.
  TYPES:
    BEGIN OF ty_msg,
      type TYPE string,
      text TYPE string,
    END OF ty_msg,
    tt_msg TYPE STANDARD TABLE OF ty_msg WITH EMPTY KEY.

  METHODS get_val
    IMPORTING iv_name         TYPE string
    RETURNING VALUE(rv_value) TYPE string.
  METHODS set_val
    IMPORTING iv_name  TYPE string
              iv_value TYPE string.
  METHODS get_param
    IMPORTING iv_name         TYPE string
    RETURNING VALUE(rv_value) TYPE string.
  METHODS add_msg
    IMPORTING iv_type TYPE string
              iv_text TYPE string.
  METHODS get_step
    RETURNING VALUE(rv_step) TYPE i.
  METHODS get_config
    RETURNING VALUE(rs_config) TYPE ty_config.

  " ---- EDITABLE_TABLE rows the citizen typed -----------------------------
  " get_val( ) deliberately returns blank for a grid: the model member is a
  " structured internal table, not a scalar, and the engine guards against
  " the GETWA_NOT_ASSIGNED that reading it as one would cause. These two are
  " the only way into those rows.
  "
  " Use get_grid_data for reading. rs-columns holds the column names from the
  " field's DEFAULT_VAL spec, in spec order; every rs-rows entry has one cell
  " per column in the same order, so a column name resolves to an index. It
  " is the same ty_table the handler passes back out of get_table( ), so a
  " journey deals with one table shape and not two. Every cell is a string.
  "
  " Use get_grid only to forward the payload verbatim - it returns the same
  " JSON array the backend items carry.
  "
  " Neither is the BAdI shape. The bridge flattens grids into
  " /QNV/SB_TABL_DEF_ST with positional UI_TABLE_COLUMN1..30, capped at 30
  " columns; that is a legacy contract and handlers should not inherit it.
  "
  " Both are empty when the field is unknown, is not an EDITABLE_TABLE, or
  " has no column spec. Columns are still published when there are no rows
  " yet, so an index can be resolved before the citizen types anything.
  METHODS get_grid_data
    IMPORTING iv_field  TYPE string
    RETURNING VALUE(rs) TYPE ty_table.
  METHODS get_grid
    IMPORTING iv_field  TYPE string
    RETURNING VALUE(rv) TYPE string.

  " Writing rows back. get_grid_data returns a COPY, so editing what it gave
  " you changes nothing on screen - the round trip is read, rebuild, write.
  "
  " set_grid_data takes the same ty_table shape. is_data-columns is matched to
  " the field's DEFAULT_VAL spec BY NAME, so column order does not have to
  " agree and a column the spec does not know is ignored. Leave is_data-columns
  " empty and the cells are taken positionally in spec order instead.
  "
  " set_grid replaces the table from raw JSON, same format get_grid returns.
  " Pass an empty string to clear the grid.
  "
  " Both replace the WHOLE table - there is no per-cell write, and set_val( )
  " cannot reach a grid cell either. Row _UID values are not carried in either
  " format, so the engine regenerates them on write: a row written back is a
  " new row as far as the delete buttons are concerned. Safe to call from
  " on_init (the model and its defaults already exist), on_after_read,
  " on_change, on_before_post and on_before_fields.
  METHODS set_grid_data
    IMPORTING iv_field TYPE string
              is_data  TYPE ty_table.
  METHODS set_grid
    IMPORTING iv_field TYPE string
              iv_json  TYPE string.

  " ---- custom popups + control wiring (handler-owned) --------------------
  " Open a handler-owned popup. On the next render the engine calls the
  " handler's on_render_popup( iv_id ) so it can draw its own dialog.
  METHODS open_popup
    IMPORTING iv_id TYPE string.
  " Close whatever popup is currently open.
  METHODS close_popup.
  " Two-way binding for a model member, so a handler-drawn control survives
  " round-trips. e.g. value = io_ctx->bind( 'ADDR_CITY' )
  METHODS bind
    IMPORTING iv_name   TYPE string
    RETURNING VALUE(rv) TYPE string.
  " An event string a handler-drawn control can fire; caught in
  " on_popup_event( iv_event ). e.g. press = io_ctx->event( 'OK' )
  METHODS event
    IMPORTING iv_id     TYPE string
    RETURNING VALUE(rv) TYPE string.
  " Open a URL in a new browser tab (e.g. a payment gateway page). The
  " journey page stays where it is; use a poll to learn the outcome.
  METHODS open_url
    IMPORTING iv_url TYPE string.
  " The current case / draft reference (the engine's live case guid). Needed
  " by payment (fees + poll key) and any backend-related handler logic, since
  " it is not a model field and may be created mid-journey by a draft save.
  METHODS get_case
    RETURNING VALUE(rv) TYPE string.

  " ---- driving the journey from a handler ---------------------------------
  " Everything Next does EXCEPT the move: validate this step, then post it to
  " the backend and take the case reference back. Returns abap_false when
  " validation or the post failed, with the messages already on the strip.
  "
  " It exists for payment. A gateway needs an open item, an open item needs a
  " case, and a case must NOT exist before the citizen has said they want to
  " pay - otherwise every abandoned form leaves one behind. So the payment
  " handler calls this from its PAYNOW event, and only then builds the URL.
  "
  " Safe to call more than once. The post carries the guid already held by the
  " engine, which the FM reads as an update rather than a create, so the
  " backend decides whether a container case is needed and creates exactly one.
  "
  " Do not call it from on_before_post or on_before_tables - those hooks run
  " INSIDE the post this triggers.
  METHODS commit_step
    RETURNING VALUE(rv_ok) TYPE abap_bool.

  " The move, and nothing else. No validation, no post - the caller has already
  " done both, which is what separates this from Next.
  "
  " Call it after a payment has been confirmed: the citizen has committed the
  " step and paid for it, and asking them to press Next as well only makes the
  " page look like it did not notice.
  "
  " Does nothing on the last step, deliberately. Advancing off the end is
  " submitting, and submitting is the citizen's application going in - not
  " something a poll fired by a timer gets to decide. Submit stays a press.
  METHODS advance_step.

  " ---- attachments already uploaded on this application -----------------
  " Every file the citizen has attached, with its content, in the shape the
  " D0xx BAdI expects. Use it when your handler creates the case itself - in
  " on_save( ) for instance - instead of letting the bridge post it.
  "
  " identifier1 is the field name the file was attached to, falling back to
  " TECH_NAME when the field is blank; identifier2 is always TECH_NAME. Getting
  " that fallback wrong is the reason to call this rather than read the
  " attachment store directly.
  "
  " It base64-loads every file into memory on each call, so hold the result in a
  " variable rather than calling it per attachment, and do not call it on every
  " render.
  " ---- an uploader inside a handler-drawn popup --------------------------
  " Draw the configured uploader for iv_field into any container - typically the
  " content of a dialog you are building in on_render_popup( ). It renders the
  " file picker, the allowed-types and size hint, and the chip list, all from
  " that field's own configuration, so a popup cannot drift out of step with the
  " page.
  "
  " The file stages the moment it is picked, exactly as it does on a step. That
  " is deliberate: closing the popup does not need to undo anything, because the
  " file really was attached and its chip is on the page to prove it. Give the
  " citizen the chip's delete button, not a Cancel that silently discards.
  "
  " iv_field must name a real UPLOAD field somewhere in the journey - any step,
  " not only the current one. It does NOT have to be visible: hide it with a rule
  " and the popup becomes the only way in. Rendering it in both places is also
  " safe; the popup's markup is scoped so the two cannot write over each other.
  "
  " Does nothing, and says so on the trace, if the field is unknown or is not an
  " upload.
  " iv_key names WHICH occurrence of the field this uploader belongs to - an
  " owner number, a row id, a line. Pass it whenever the same upload field is
  " drawn more than once for different subjects, which is the repeating-owner
  " case: without it two owners' documents land in one chip list with nothing
  " to tell them apart, and the backend can file neither correctly.
  "
  " With a key, the chips shown are only that subject's, and the file reaches
  " the backend as identifier1 = FIELD_KEY - the same shape the D0xx BAdI
  " already reads for OWNERS_SEARCH_<n>. Leave it blank and nothing changes.
  "
  " Use something stable: the partner number, not a row index that shifts when
  " a row above it is deleted.
  METHODS render_upload
    IMPORTING io_view  TYPE REF TO z2ui5_cl_xml_view
              iv_field TYPE string
              iv_key   TYPE string OPTIONAL.

  METHODS get_attachment_files
    RETURNING VALUE(rt) TYPE /qnv/sbuild_attachments_tt.

  " Files the BACKEND already holds against this case, as returned by the last
  " read. Different from get_attachment_files( ), which returns what the citizen
  " staged in THIS session and has not been posted yet.
  "
  " These have no staging guid and are not in the chip list, so they cannot be
  " deleted from the UI - they are there to be read. Use them to tell whether a
  " document has already been supplied on a resumed application, instead of
  " asking the citizen for it again.
  "
  " Empty until a read has happened, so on a new application it is always empty.
  METHODS get_backend_attachments
    RETURNING VALUE(rt) TYPE /qnv/sbuild_attachments_tt.

  " Rows the BACKEND returned for a table control on the last read, in the same
  " ty_table shape get_table( ) expects back. This is the missing half of the
  " table story: TABLE, RECORDCARD and RO_PANEL have NO model member, so rows
  " fetched for them have nowhere in io_ctx to land - which is why the backend
  " call could be filling its table correctly and io_ctx still showed nothing.
  "
  " For an EDITABLE_TABLE the rows are also written into the grid, so use
  " get_grid_data( ) there. For the other three, serve get_table( ) from here:
  "     rs_data = io_ctx->get_backend_table( 'LICENSES' ).
  "
  " rs-columns carries the DEFAULT_VAL spec names when the field has a spec, and
  " FIELD1..N otherwise - the backend sends cells by position, not by name.
  " Empty until a read has happened.
  " ---- the reference shown on the confirmation screen ---------------------
  " After a successful submit the engine shows one line - "Application submitted
  " successfully. Reference: X" - followed by the feedback faces. There is no
  " configuration behind that screen; it is drawn whenever the submit succeeded.
  "
  " X is worked out by the engine: the request id from an external backend, the
  " guid the BAdI returned, or a timestamp when there is no backend at all. Call
  " this when your OWN code created the case and knows the real number, and it
  " will be used instead - on every path.
  "
  " Call it from on_submit( ), which runs after validation and before the engine
  " decides the screen has been submitted.
  METHODS set_reference
    IMPORTING iv_ref TYPE string.

  " ---- field properties, set from code -----------------------------------
  " Rules already cover show, hide, require, optional, readonly and editable
  " declaratively, and a rule needs no handler at all - reach for one of these
  " only when the condition cannot be written as a rule.
  "
  " What you set here OUTRANKS both the rules and the configured flag, and it
  " lasts for the rest of the session. Call the opposite, or clear_props( ), to
  " hand the field back to its configuration.
  "
  " Safe to call from any hook. They are read at render time, so setting one in
  " on_init, on_change or on_custom_validate all work.
  METHODS set_hidden
    IMPORTING iv_field TYPE string
              iv_on    TYPE abap_bool DEFAULT abap_true.
  METHODS set_required
    IMPORTING iv_field TYPE string
              iv_on    TYPE abap_bool DEFAULT abap_true.
  METHODS set_readonly
    IMPORTING iv_field TYPE string
              iv_on    TYPE abap_bool DEFAULT abap_true.
  " Blank field clears every override on every field.
  METHODS clear_props
    IMPORTING iv_field TYPE string OPTIONAL.

  METHODS get_backend_table
    IMPORTING iv_field  TYPE string
    RETURNING VALUE(rs) TYPE ty_table.

  " ---- external-backend handle (Step 1) ---------------------------------
  " The live remote-resource handle for REST/immediate backends
  " (request_id, party_ids, bo_id, bdo, status, amount, token).
  " Identifiers ride the serialized engine instance across round-trips and
  " draft saves; the engine clears -token before each serialize, so the
  " backend re-acquires it on demand. Never persist the token.
  METHODS get_handle
    RETURNING VALUE(rs_handle) TYPE zif_rak_journey_backend=>ty_handle.
  METHODS set_handle
    IMPORTING is_handle TYPE zif_rak_journey_backend=>ty_handle.


ENDINTERFACE.
