*&---------------------------------------------------------------------*
*& ZIF_RAK_JOURNEY_BACKEND
*&
*& The pluggable-backend seam. One CJS engine, many backends: the engine
*& never knows whether a journey is served by a REST service, the legacy
*& QNV bridge, or local staging.
*&
*& Backends are selected by the journey's bknd_category through
*& ZCL_RAK_BE_FACTORY. A category the factory does not recognise yields an
*& unbound reference, which is what keeps the QNV / BAdI route untouched.
*&---------------------------------------------------------------------*
INTERFACE zif_rak_journey_backend
  PUBLIC.

* ---------------------------------------------------------------------
* Capabilities - what this backend supports. The engine reads these
* rather than assuming; a backend that cannot pay says so.
* ---------------------------------------------------------------------
  TYPES: BEGIN OF ty_cap,
           immediate   TYPE abap_bool,   " commits per step (REST) vs deferred (QNV)
           resumable   TYPE abap_bool,   " can re-open an existing request
           attachments TYPE abap_bool,
           payment     TYPE abap_bool,
         END OF ty_cap.

* ---------------------------------------------------------------------
* The handle. Rides the serialized engine instance between round-trips
* and carries everything the backend needs to continue a request.
* Object references are NOT used here on purpose: they do not survive
* z2ui5 serialization.
* ---------------------------------------------------------------------
  TYPES: BEGIN OF ty_handle,
           request_id TYPE string,          " the backend's request identifier
           applicant  TYPE string,
           party_ids  TYPE string_table,
           bo_id      TYPE string,
           bdo        TYPE string,
           token      TYPE string,          " cleared before each serialize
           status     TYPE string,
           amount     TYPE string,
         END OF ty_handle.

* ---------------------------------------------------------------------
* Flat name/value pairs. The engine flattens its model into this for
* every backend call; the backend decides what to do with them.
* ---------------------------------------------------------------------
  TYPES: BEGIN OF ty_field,
           name  TYPE string,
           value TYPE string,
         END OF ty_field,
         tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

* ---------------------------------------------------------------------
* One uploaded document.
* ---------------------------------------------------------------------
  TYPES: BEGIN OF ty_file,
           name      TYPE string,
           name_ar   TYPE string,
           mime      TYPE string,
           extension TYPE string,
           doc_type  TYPE string,           " the backend's document code
           xdata     TYPE xstring,
         END OF ty_file.

* ---------------------------------------------------------------------
* DYNAMIC FIELD DESCRIPTORS
*
* Some steps are not configured at all - their fields are defined by the
* backend at runtime. The Notary business object is the case this exists
* for: its fields come from GET /subservice/{id} and are never seeded.
*
* The engine merges these into ms_config BEFORE build_model( ), which is
* why this must be answered by the backend and not by a handler: the UI
* model is built from configured fields, and build_model( ) runs before
* the handler's on_init( ).
*
* The merge is not a one-shot at launch. MAIN( ) merges and rebuilds on
* every round trip, because a step can only be described once the citizen
* has made the choice that decides it - the Notary declaration is picked
* on step 1 and the business object step follows from it. Returning a
* different set of fields on a later call is therefore expected, and
* build_model( ) carries existing values across so the rebuild is cheap
* and non-destructive. Return the same names for the same state and the
* values stay put.
*
* A backend with no dynamic steps returns an empty table.
* ---------------------------------------------------------------------
  TYPES: BEGIN OF ty_dyn_opt,
           key  TYPE string,
           text TYPE string,
         END OF ty_dyn_opt,
         tt_dyn_opt TYPE STANDARD TABLE OF ty_dyn_opt WITH EMPTY KEY.

  TYPES: BEGIN OF ty_dyn_field,
           name     TYPE string,
           label    TYPE string,
           label_ar TYPE string,
           type     TYPE string,       " INPUT / SELECT / DATE / NUMBER / TEXTAREA
           required TYPE abap_bool,
           max_len  TYPE i,
*          Pattern the backend wants the value to match. The Notary blueprint ships
*          one per business field alongside the label and the choices, and
*          ZCL_RAK_JOURNEY_RULES already enforces VALIDATION-REGEX - there was just
*          nothing carrying it from one to the other.
           regex    TYPE string,
           options  TYPE tt_dyn_opt,
         END OF ty_dyn_field,
         tt_dyn_field TYPE STANDARD TABLE OF ty_dyn_field WITH EMPTY KEY.


  METHODS capabilities
    RETURNING VALUE(rs_cap) TYPE ty_cap.

* Describe a step whose fields are not configured. iv_step is the step's
* bknd_screen. Returning an empty table means "this step is not dynamic".
*
* it_fields is the engine's flattened model, the same shape every other
* backend call gets. It is here because DESCRIBE_STEP( ) runs before every
* handler hook - deliberately, see above - and the Notary declaration is
* chosen by the citizen at runtime. Without it the backend has a step name
* and nothing else, cannot know which blueprint to fetch, and every dynamic
* step comes back empty. Optional: a backend that does not need it ignores it.
  METHODS describe_step
    IMPORTING iv_step          TYPE string
              it_fields        TYPE tt_field OPTIONAL
    RETURNING VALUE(rt_fields) TYPE tt_dyn_field.

* Create the request. Called once, on the first committing step.
  METHODS init
    IMPORTING it_fields TYPE tt_field
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

* Re-open an existing request (caseid / draftid launch parameter).
  METHODS resume
    IMPORTING iv_request_id TYPE string
    EXPORTING et_return     TYPE bapiret2_t
    CHANGING  cs_handle     TYPE ty_handle.

* Commit one wizard step. iv_step is the step's bknd_screen.
  METHODS step_commit
    IMPORTING iv_step   TYPE string
              it_fields TYPE tt_field
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

  METHODS submit
    IMPORTING it_fields TYPE tt_field
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

  METHODS attach
    IMPORTING is_file   TYPE ty_file
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

* Payment lifecycle. iv_event is CALC / CREATE / LOCK / PAID.
* Backends whose capabilities report payment = abap_false implement this
* as a no-op.
  METHODS pay
    IMPORTING iv_event  TYPE string
              it_fields TYPE tt_field
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

  METHODS discard
    EXPORTING et_return TYPE bapiret2_t
    CHANGING  cs_handle TYPE ty_handle.

ENDINTERFACE.
