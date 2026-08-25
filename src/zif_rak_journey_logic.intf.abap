INTERFACE zif_rak_journey_logic
  PUBLIC.

  " lifecycle -------------------------------------------------------------
  METHODS on_init
    IMPORTING io_ctx TYPE REF TO zif_rak_journey.
  METHODS on_after_read
    IMPORTING io_ctx TYPE REF TO zif_rak_journey.
  METHODS on_save
    IMPORTING io_ctx TYPE REF TO zif_rak_journey.
  METHODS on_before_post
    IMPORTING io_ctx TYPE REF TO zif_rak_journey
    CHANGING  ct_kv  TYPE zif_rak_journey=>tt_kv.
  " Adapter-path twin of on_before_post. Fired at the end of be_fields, on
  " every backend transmission (init / step_commit / submit), with the
  " flattened name/value payload CHANGING. Add, rewrite or remove items here
  " before the backend adapter (and any downstream BAdI) sees them.
  METHODS on_before_tables
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
    CHANGING  ct_tables TYPE /qnv/sb_tabl_def_tt.

  METHODS on_before_fields
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
    CHANGING  ct_fields TYPE zif_rak_journey_backend=>tt_field.

  " field reactions --------------------------------------------------------
  METHODS on_search
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              iv_field TYPE string.
  METHODS on_change
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              iv_field TYPE string.
  " Fired after a file has been stored in the CJS staging side-store and
  " added to the field's chip list. Use it to derive values from the file.
  METHODS on_attach
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              iv_field TYPE string.
  METHODS on_fee_calc
    IMPORTING io_ctx TYPE REF TO zif_rak_journey.

  " data providers ---------------------------------------------------------
  METHODS on_value_help
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
              iv_field  TYPE string
    RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.
  METHODS get_table
    IMPORTING io_ctx         TYPE REF TO zif_rak_journey
              iv_name        TYPE string
    RETURNING VALUE(rs_data) TYPE zif_rak_journey=>ty_table.

  " RESERVED - not yet called by the engine. These are the landing pads for
  " the backend attachment lifecycle (see CJS_Session_Handoff open item 7):
  " once the bridge posts attachments through the D0xx BAdI and reads them
  " back, the engine will source its chip list from get_attachments and its
  " links from get_attach_url instead of the CJS-side staging table.
  METHODS get_attach_url
    IMPORTING io_ctx        TYPE REF TO zif_rak_journey
              iv_field      TYPE string
    RETURNING VALUE(rv_url) TYPE string.
  METHODS get_attachments
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
              iv_field  TYPE string
    RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_attach.

  " validation -------------------------------------------------------------
  METHODS on_custom_validate
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
              iv_step   TYPE i
    RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_msg.

  " rendering --------------------------------------------------------------
  " Called once per step, before the step's fields. The base implementation
  " is empty; redefine to draw step-level chrome (buttons, banners).
  METHODS on_render_start
    IMPORTING io_ctx  TYPE REF TO zif_rak_journey
              io_view TYPE REF TO z2ui5_cl_xml_view.
  " Called for every field before the engine renders it. Return abap_true to
  " claim the field. The base claims PAYFEE and draws the payment card.
  METHODS render_field
    IMPORTING io_ctx         TYPE REF TO zif_rak_journey
              io_form        TYPE REF TO z2ui5_cl_xml_view
              is_field       TYPE zif_rak_journey=>ty_field
    RETURNING VALUE(rv_done) TYPE abap_bool.

  " custom popups (handler-owned) -----------------------------------------
  METHODS on_render_popup
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              io_popup TYPE REF TO z2ui5_cl_xml_view
              iv_id    TYPE string.
  " Also the sink for handler-drawn controls outside a popup (io_ctx->event).
  " The base handles the payment PAYNOW / PAYPOLL events here.
  METHODS on_popup_event
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              iv_id    TYPE string
              iv_event TYPE string.

  " global feedback (happiness meter) -------------------------------------
  " The engine appends a generic feedback step as the final step of every
  " journey. Return abap_false from wants_feedback to skip it for a journey
  " (default abap_true). When the citizen sends the rating, the engine calls
  " on_feedback with the chosen rating key ('EX'/'GD'/'AV'/'PR'/'VP') and the
  " optional comment; the base implementation is empty - redefine it to
  " persist the rating to your own table.
  METHODS wants_feedback
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
    RETURNING VALUE(rv) TYPE abap_bool.
  METHODS on_feedback
    IMPORTING io_ctx     TYPE REF TO zif_rak_journey
              iv_rating  TYPE string
              iv_comment TYPE string.
  METHODS on_render_before_field
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              io_view  TYPE REF TO z2ui5_cl_xml_view
              is_field TYPE zif_rak_journey=>ty_field.
  METHODS on_render_after_field
    IMPORTING io_ctx   TYPE REF TO zif_rak_journey
              io_view  TYPE REF TO z2ui5_cl_xml_view
              is_field TYPE zif_rak_journey=>ty_field.
  " After every field on the step. The mirror of on_render_start( ).
  METHODS on_render_end
    IMPORTING io_ctx  TYPE REF TO zif_rak_journey
              io_view TYPE REF TO z2ui5_cl_xml_view.
  " The handler's one moment at submit: everything has passed validation and
  " nothing has been sent to the backend yet. Return one or more messages of
  " type 'Error' to REFUSE the submit and keep the citizen on the page.
  " A journey that creates its own case does it here, and calls
  " io_ctx->set_reference( ) with the real case number so the confirmation
  " screen shows it instead of a timestamp.
  METHODS on_submit
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey
    RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_msg.

  " ==========================================================================
  " DRAFT FEATURES
  "
  " RESERVED - none of these is called by the engine yet, in the same sense
  " as GET_ATTACHMENTS( ) above. They are the seam, declared first so that
  " handlers and the engine can be moved onto it one journey at a time
  " instead of in one activation.
  "
  " The rule they encode: an unfinished application, and the files hanging
  " off it, are persisted by EITHER the backend OR CJS, per journey, and the
  " engine must be told which rather than inferring it from bknd_category.
  " See ZIF_RAK_JOURNEY=>C_MODE for the four answers.
  " ==========================================================================

  " Who owns the draft for this journey. Returning '' - the default - leaves
  " the decision to the journey configuration, which is where it belongs for
  " anything a functional consultant can set. Redefine only when the choice
  " is genuinely code: a journey that drafts through the BAdI on one path and
  " stages locally on another.
  METHODS draft_mode
    IMPORTING io_ctx       TYPE REF TO zif_rak_journey
    RETURNING VALUE(rv_mode) TYPE string.

  " The same question for attachments, answered separately on purpose.
  " DELEGATE means the backend stores the file and GET_ATTACHMENTS( ) /
  " GET_ATTACH_URL( ) supply the chips and links; NATIVE means the file sits
  " in ZRAK_CJ_ATTX under ZCL_RAK_CJ_ATT_STORE, which is what happens today.
  METHODS attach_mode
    IMPORTING io_ctx       TYPE REF TO zif_rak_journey
    RETURNING VALUE(rv_mode) TYPE string.

  " Every draft the current user may re-open. This is the API that does not
  " exist anywhere today: RESUME( ) can only re-open a draft whose id was
  " already handed to it as the draftid launch parameter, so nothing can
  " show a citizen the list in the first place.
  "
  " IV_PARTNER is the BP to list for; blank means the logged-in user's own.
  " IV_WITH_ROLES adds drafts a role-BP created on that partner's behalf -
  " an agent's view - and must stay OFF by default, because widening it is
  " a disclosure and narrowing it is only an inconvenience.
  "
  " Under DELEGATE this is the backend's list and the handler is the only
  " thing that knows how to ask for it. Under NATIVE the framework answers
  " it and a handler need not redefine this at all.
  METHODS get_drafts
    IMPORTING io_ctx        TYPE REF TO zif_rak_journey
              iv_partner    TYPE string OPTIONAL
              iv_with_roles TYPE abap_bool DEFAULT abap_false
    RETURNING VALUE(rt)     TYPE zif_rak_journey=>tt_draft.

  " Before the draft is written. Return one or more messages of type 'Error'
  " to REFUSE the save and keep the citizen on the page - the same contract
  " as ON_SUBMIT( ), and deliberately not the contract of ON_SAVE( ), whose
  " exceptions the engine swallows whole.
  METHODS on_draft_save
    IMPORTING io_ctx       TYPE REF TO zif_rak_journey
              iv_draft_id  TYPE string
    RETURNING VALUE(rt)    TYPE zif_rak_journey=>tt_msg.

  " After a draft has been restored into the model and before the step is
  " rendered. The place to re-derive anything that was never stored -
  " a live fee, a partner read that must not be served from a week-old copy.
  METHODS on_draft_load
    IMPORTING io_ctx      TYPE REF TO zif_rak_journey
              iv_draft_id TYPE string
    RETURNING VALUE(rt)   TYPE zif_rak_journey=>tt_msg.

  " The citizen threw the draft away, or retention did. Errors refuse the
  " discard; a handler that must clean up elsewhere does it here.
  METHODS on_draft_discard
    IMPORTING io_ctx      TYPE REF TO zif_rak_journey
              iv_draft_id TYPE string
    RETURNING VALUE(rt)   TYPE zif_rak_journey=>tt_msg.

  " ------------------------------------------------------------------------
  " RETENTION - how long an abandoned draft and its staged files survive.
  "
  " Both of these run from housekeeping, not from a session. IO_CTX is
  " therefore OPTIONAL and will arrive UNBOUND: there is no live journey, no
  " model and no user. Reading it without a check is a short dump in a batch
  " job, which is the least visible place in the system to put one.
  " ------------------------------------------------------------------------
  METHODS retention
    IMPORTING io_ctx    TYPE REF TO zif_rak_journey OPTIONAL
    RETURNING VALUE(rs) TYPE zif_rak_journey=>ty_retention.

  " Called once per expiring draft when RETENTION( ) asked for ARCHIVE.
  " Return abap_true to say the handler has archived it and the framework
  " may now remove its copy; abap_false leaves the draft where it is, which
  " is the safe answer and the default. A journey with a real archive - a
  " DMS drop, an outbound feed - is the only thing that knows where it goes.
  METHODS on_archive
    IMPORTING is_draft          TYPE zif_rak_journey=>ty_draft
    RETURNING VALUE(rv_handled) TYPE abap_bool.
ENDINTERFACE.
