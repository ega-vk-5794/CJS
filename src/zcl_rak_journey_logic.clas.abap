CLASS zcl_rak_journey_logic DEFINITION
  PUBLIC
  CREATE PUBLIC.

*   ---------------------------------------------------------------------------
*   RECONSTRUCTED HEAD - the lines from here down to c_pay_started were rebuilt,
*   not supplied. Compare against SE24 before activating and delete this note.
*
*   They are a rebuild rather than a guess: the implementation section below is
*   complete, and every symbol it uses had to be declared somewhere above it.
*   Enumerating those gave one interface, seven protected methods (all of which
*   were in the paste already) and five constants, of which four sat above the
*   paste's first surviving line. No instance attribute is referenced anywhere in
*   the body, which is why none is declared.
*
*   Anything the original head carried that the body never touches - a spare
*   constant, an unused type - cannot be recovered this way and is NOT here. That
*   loss is loud, not silent: an omitted declaration is a syntax error at
*   activation, never a runtime surprise. So activate, read the error list, and
*   put back whatever it names.
*
*   One value is unverifiable. c_pay_now MUST be 'PAYNOW' - ZCL_RAK_JOURNEY_RENDER
*   fires the literal HPOP_PAYNOW at the footer and this constant is what catches
*   it. c_pay_poll is referenced only by itself: pay_render raises it and
*   on_popup_event catches it, nothing outside the class names it, so whatever the
*   original said, 'PAYPOLL' behaves identically.
*   ---------------------------------------------------------------------------

  PUBLIC SECTION.
    INTERFACES zif_rak_journey_logic.

    CONSTANTS c_pay_field   TYPE string VALUE 'PAYFEE'.       " the fee control; holds 'PAID'
    CONSTANTS c_pay_now     TYPE string VALUE 'PAYNOW'.       " caught as HPOP_PAYNOW
    CONSTANTS c_pay_poll    TYPE string VALUE 'PAYPOLL'.      " raised by the poll timer
*   Re-open the gateway tab from the stored address. No backend call and no new
*   reference - the payment already exists, the citizen just lost the window to a
*   pop-up blocker or a stray close. Raising c_pay_now here would prepare a SECOND
*   payment for the same fee.
    CONSTANTS c_pay_open    TYPE string VALUE 'PAYOPEN'.
*   Stop waiting. Puts the Pay button back rather than leaving someone stuck on a
*   screen with no way out but the browser's back arrow.
    CONSTANTS c_pay_stop    TYPE string VALUE 'PAYSTOP'.
    CONSTANTS c_pay_started TYPE string VALUE 'PAY_STARTED'.  " 'X' once Pay pressed
    CONSTANTS c_pay_total   TYPE string VALUE 'PAY_TOTAL'.   " payable amount, from the backend

*   What the payment engine needs to find the fee and the merchant, and what only
*   the journey knows. PREPARE_GATEWAY tests the first two before it does anything
*   else, so a journey that does not supply them cannot pay - which is correct, and
*   now says so instead of failing later and less clearly.
*
*   Read from the model rather than hard-coded per subclass: DOK is RDOK /
*   DOK APPL_FEE / ZK, but the next department is not, and a value in the journey
*   definition is one a functional consultant can set without a transport. A
*   subclass may still redefine pay_engine( ) if it needs to derive them.
    CONSTANTS c_pay_bukrs    TYPE string VALUE 'PAY_BUKRS'.    " company code raising the fee
    CONSTANTS c_pay_material TYPE string VALUE 'PAY_MATERIAL'. " fee material in ZDT_EDIRHAM_SERV
    CONSTANTS c_pay_casesfor TYPE string VALUE 'PAY_CASESFOR'. " ZETISLAT_TRANSAC case family

*   Reserved carriers for the block the citizen reads BEFORE the gateway opens.
*   All three are optional; blank falls back to the RAK Government platform
*   defaults in pay_terms.
*
*   PAY_METHOD / PAY_CHANNEL - the named method and the named instrument, pipe
*                              separated when there is more than one to show.
*   PAY_CHARGES - the charges bullets, pipe separated. Supplied rather than
*                 computed, for the same reason the total is: a percentage this
*                 framework prints and the gateway then bills differently is a
*                 number the citizen was misled by.
    CONSTANTS c_pay_method  TYPE string VALUE 'PAY_METHOD'.
    CONSTANTS c_pay_channel TYPE string VALUE 'PAY_CHANNEL'.
    CONSTANTS c_pay_charges TYPE string VALUE 'PAY_CHARGES'.

*   The backend screen that resolves the gateway. This journey's OWN payment screen,
*   not the standalone pay app.
*
*   RAK Digital has two applications: the journey, and a common pay app (PG01). A
*   payment STARTED inside a journey is finished by that journey - its read BAdI
*   resolves the gateway from the case and returns APPLICATIONURL. PG01 is the other
*   door: the dashboard's Waiting for payment list, for someone who left without
*   paying. Routing an in-journey payment through PG01 finishes the payment but not
*   the journey, which is why it is the wrong call here.
*
*   PAY_JOURNEY and PAY_CATEGORY are blank on nearly every journey - blank means use
*   this journey's own backend configuration, which is almost always right. PAY_SCREEN
*   names the payment step's backend screen and does need authoring.
    CONSTANTS c_pay_journey  TYPE string VALUE 'PAY_JOURNEY'.
    CONSTANTS c_pay_category TYPE string VALUE 'PAY_CATEGORY'.
    CONSTANTS c_pay_screen   TYPE string VALUE 'PAY_SCREEN'.

*   The container case number, once the backend has given us one. Also read by
*   pay_engine( ). Filled the moment the first Pay press commits and never again,
*   which is what stops a second press creating a second case.
    CONSTANTS c_pay_case TYPE string VALUE 'CASE_NUMBER'.

*   How many polls have gone by waiting for the gateway address. The case is created
*   by the Pay press, and the open item it hangs off is raised from a LATER update
*   task with an SD sales order behind it - so the first read after the commit
*   routinely finds nothing. That is the normal case, not a failure.
    CONSTANTS c_pay_tries   TYPE string VALUE 'PAY_TRIES'.
*   Two minutes at the poll's 2.5s tick. It was fifty seconds, which was sized for a
*   world where each attempt blocked in the BAdI for up to two minutes of its own -
*   so twenty attempts was already far longer than it looked. With the DFKKOP gate
*   in PREPARE_PAYMENT a tick that finds nothing costs one indexed read, so the
*   journey can afford to be patient, and being patient is what a workflow-driven
*   open item actually needs.
*
*   Long enough for the open item on a working system, short enough that a citizen is
*   not left watching a spinner over a backend that is never going to answer.
    CONSTANTS c_pay_max_try TYPE i      VALUE 48.

  PROTECTED SECTION.
*   Seed an EDITABLE owner-style grid from the backend table that already holds
*   the same records, so the citizen amends what is there instead of retyping it.
*
*   Every amendment journey shows the same thing twice: a read-only list of the
*   owners the licence already has, and an empty editable list underneath with an
*   Add button. Nothing carried the first into the second, so amending one owner
*   meant re-entering all of them - and the backend then rejected the step,
*   because the shares of the rows actually submitted did not total 100.
*
*   Copied BY COLUMN NAME, never by position. The two grids usually share a
*   spec, but "usually" is what put the Emirates ID into D004's SHARE_PER.
*
*   RUNS ONCE, and that is the whole safety of it: it does nothing at all unless
*   the target grid is empty. A citizen who has deleted an owner on purpose does
*   not get it back on the next round trip, and nothing they typed is replaced.
    METHODS seed_grid_from_backend
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_grid   TYPE string
                iv_source TYPE string.

    TYPES: BEGIN OF ty_pop_field,
             name  TYPE string,
             label TYPE string,
             type  TYPE string,   " '' = input, TEXTAREA, DATE, SELECT, CHECKBOX, NUMBER
*            ---- value help ----------------------------------------------------
*            A popup could previously draw a plain input, a textarea or a date and
*            nothing else, so any dialog needing a dropdown or an F4 had to
*            hand-build its own - which is why most of them simply went without.
*
*            These are the SAME four sources the main form uses, resolved by the
*            SAME class, ZCL_RAK_F4_RESOLVER. A popup field and a configured field
*            carrying the same data element now offer the same list, which is the
*            point: two resolutions of one domain is how a dialog starts accepting
*            a value the form rejects.
*
*            Precedence: OPTIONS wins outright; otherwise the resolver's own
*            documented order applies - DOMNAME, then ROLLNAME (fixed values, then
*            the element's default search help), then SHLP.
             options  TYPE zif_rak_journey=>tt_option,
             rollname TYPE string,
             domname  TYPE string,
             shlp     TYPE string,
*            ---- presentation --------------------------------------------------
*            REQUIRED marks the label only. Nothing here enforces it: a popup is
*            the handler's, so the handler validates it in the OK event - the
*            engine's VALIDATE_STEP never sees these fields.
             required    TYPE abap_bool,
             readonly    TYPE abap_bool,
*            ---- reactivity ----------------------------------------------------
*            Raise this popup event when the field's value changes. Blank is the
*            old behaviour exactly: no event, no round trip.
*
*            It exists because a dialog could show a dropdown but never react to
*            one, so a popup that offers a choice which should FILL THE REST OF
*            THE FORM - pick a previous chemical declaration, pick a saved
*            address - had no way to. The alternative was a second button, and
*            DIALOG_FORM( ) has only OK and Cancel.
*
*            Same routing as F4_EVT above: it arrives at the handler's
*            ON_POPUP_EVENT( ), so the handler decides what filling in means.
*            Only a SELECT can raise it - an input has no settled moment to fire
*            on, and firing per keystroke would round-trip on every letter.
             change_evt  TYPE string,
             placeholder TYPE string,
             width       TYPE string,
             maxlen      TYPE i,
*            ---- an F4 button on the field -------------------------------------
*            Draws sap.m.Input's own value-help icon and fires this event, caught
*            in ON_POPUP_EVENT like any other. For a lookup the handler owns - a
*            BP browse, a licence picker - where no static list can answer.
             f4_evt      TYPE string,
           END OF ty_pop_field,
           tt_pop_field TYPE STANDARD TABLE OF ty_pop_field WITH EMPTY KEY.

    " Build a titled form dialog from a field list. Inputs are two-way bound
    " to the named model members; Save / Cancel fire handler events (default
    " 'OK' / 'CANCEL') caught in on_popup_event. Call this from on_render_popup.
    METHODS dialog_form
      IMPORTING io_ctx     TYPE REF TO zif_rak_journey
                io_popup   TYPE REF TO z2ui5_cl_xml_view
                iv_title   TYPE string
                it_fields  TYPE tt_pop_field
                iv_ok_text TYPE string DEFAULT 'Save'
                iv_ok_evt  TYPE string DEFAULT 'OK'
                iv_cxl_evt TYPE string DEFAULT 'CANCEL'
*               How many field columns the dialog lays out: 1 (the default and
*               what every existing caller gets), 2 or 3. Anything outside that
*               is clamped rather than refused - a popup is not the place to
*               fail because somebody typed 5.
*
*               Fields flow left to right in IT_FIELDS order. There is no way to
*               say "this one spans two columns": a form that needs that has
*               outgrown DIALOG_FORM( ) and should be built control by control,
*               the way RENDER_OWN_POPUP( ) in ZCL_RAK_TEST_ALL_LOGIC is.
*
*               A TEXTAREA in a 3-column dialog is a 3-line box a third of the
*               width, which is worse than the same box full width. Put long
*               free text on a 1-column dialog, or last where it hurts least.
                iv_columns TYPE i DEFAULT 1.


    " Draw the payment card: fee list + total, a Pay button, and - while a
    " payment is in progress and not yet PAID - a status indicator plus a
    " self-firing poll timer. Called from render_field when the engine
    " reaches the PAYFEE field; you rarely call it directly.
    METHODS pay_render
      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                io_view  TYPE REF TO z2ui5_cl_xml_view
                iv_field TYPE string
                it_fee   TYPE zcl_rak_pay_engine=>tt_fee
                iv_total TYPE kbetr
                iv_poll  TYPE abap_bool.

*   Everything between the fee total and the Pay button: which method, which
*   instrument, what it costs to use, and the pop-up notice. Called from
*   pay_render, so every journey with a fee card gets it and none has to build it.
    METHODS pay_terms
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                io_view TYPE REF TO z2ui5_cl_xml_view.

    METHODS pay_engine
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
      RETURNING VALUE(ro) TYPE REF TO zcl_rak_pay_engine.

*   THE JOURNEY KEY IS NOT ALWAYS THE CASE, AND THE PAYMENT STEP NEEDS THE
*   CASE. Blank means no case exists yet, which is a reason to WAIT rather
*   than a reason to complain.
*
*   On DOK and EPDA the backend re-points the journey key at the case id
*   the moment CREATE_CASE runs, so the key IS the case and this returns
*   it unchanged. On Municipality it does not: the create makes an RE
*   rental object and the key stays its INTRENO - IM00100123344 - while
*   the case is a separate number, 1959738. Handing that INTRENO to
*   DFKKOP as ZZEXT_KEY matches nothing, for ever, and the citizen watches
*   a timer under "Complete your payment in the new tab" with no open item
*   that could ever appear.
*
*   THE LOOKUP IS NOT NEW. It is the first two branches of
*   ZCL_RAK_PAY_ENGINE->RESOLVE_CASE( ), which has always known both
*   shapes - VIBDCHARACT-SUPPLEMENTINFO under FIXFITCHARACT 'CJ12' for an
*   INTRENO, SCMG_T_CASE_ATTR-EXT_KEY for a case. The pay engine resolved
*   correctly and the GATE in front of it did not, so the gate refused
*   before the engine was ever asked.
*
*   IDENTITY IS THE FALLBACK, and that is the whole safety property. When
*   neither lookup confirms a case, -KEY comes back UNCHANGED, so every
*   caller behaves exactly as it did before this method existed. It can
*   only ever replace an INTRENO with the case behind it; it can never
*   take a key away from a path that already works. DOK and EPDA run on
*   the raw key today and must go on doing so whether or not
*   SCMG_T_CASE_ATTR happens to answer at the moment Pay is pressed.
*
*   -IS_CASE says whether a case was positively CONFIRMED. It picks the
*   wording of a wait, never the control flow: a caller that used to
*   proceed on an unresolved key still proceeds on it.
    TYPES: BEGIN OF ty_case_key,
             key     TYPE string,
             is_case TYPE abap_bool,
           END OF ty_case_key.

    METHODS case_key_of
      IMPORTING io_ctx    TYPE REF TO zif_rak_journey
                iv_key    TYPE string
      RETURNING VALUE(rs) TYPE ty_case_key.

    METHODS trace_key
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_in   TYPE string
                iv_what TYPE string.

*   Every early exit in PREPARE_PAYMENT( ) used to be silent under
*   IV_QUIET, and the poll runs quiet for 48 ticks - two minutes in which
*   the citizen sees a spinner and the developer sees nothing at all.
*   TRACE( ) emits only under &trace=x, so this costs a production run
*   nothing and answers "why did the gateway not open" in one round trip.
    METHODS pay_trace
      IMPORTING io_ctx  TYPE REF TO zif_rak_journey
                iv_text TYPE string.

*   THE STANDARD CPG IS LAUNCHED THROUGH THE PAYMENTS WEB DYNPRO, not by
*   a URL the BAdI hands over ready-made. ZCL_CJ_DEMO_P001 builds exactly
*   this string as its EV_URL after filling the same MERCHANTID /
*   SERVICEID / SECRETKEY / REFERENCEID details, and the BAdI returns the
*   same string as REDIRECTURL. That app holds the CPG form and posts it,
*   which is also why the SECRET KEY never has to reach our page.
    METHODS wd_pay_url
      IMPORTING iv_ref    TYPE string
      RETURNING VALUE(rv) TYPE string.

    METHODS pay_field_step
      IMPORTING io_ctx         TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv_step) TYPE i.

*   iv_quiet suppresses the messages. The gateway address is polled for, so the same
*   complaint would be printed on every tick unless the caller can ask for silence
*   until it decides to give up.
    METHODS prepare_payment
      IMPORTING io_ctx   TYPE REF TO zif_rak_journey
                iv_quiet TYPE abap_bool DEFAULT abap_false.

    METHODS build_pay_url
      IMPORTING io_ctx        TYPE REF TO zif_rak_journey
      RETURNING VALUE(rv_url) TYPE string.

*   The field names seeded into the payment journey's read. Redefine to carry more.
    METHODS pay_read_items
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_item.

  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_RAK_JOURNEY_LOGIC IMPLEMENTATION.


  METHOD build_pay_url.
    DATA(lv_app) = io_ctx->get_val( 'PAY_APPURL' ).
    IF lv_app IS NOT INITIAL.
      rv_url = lv_app.
      RETURN.
    ENDIF.

*   /sap/bc/zrak_cj_pay WAS NEVER BUILT. Nothing in this repository
*   implements that handler and nothing else references it, so this
*   branch produced a 404 on the rare occasion it was reached. The
*   payments Web Dynpro is the address that actually exists.
    DATA(lv_ref) = io_ctx->get_val( 'PAY_REFERENCE' ).
    IF lv_ref IS NOT INITIAL.
      rv_url = wd_pay_url( lv_ref ).
    ENDIF.
  ENDMETHOD.


  METHOD dialog_form.
*   COLUMNS. One is the default and draws exactly what this method always drew -
*   same width, same attributes, no new behaviour for any existing caller.
*
*   Clamped, not validated. 0 and 7 both mean somebody guessed, and a dialog that
*   refuses to open is a worse answer than a dialog with one column.
    DATA(lv_cols) = COND i( WHEN iv_columns < 1 THEN 1
                            WHEN iv_columns > 3 THEN 3
                            ELSE iv_columns ).

*   The dialog has to grow with the columns or the fields just get narrower and
*   nothing is gained. These are the widths at which a label and its control stop
*   colliding at each count.
    DATA(lv_width) = SWITCH string( lv_cols
                                    WHEN 2 THEN '54rem'
                                    WHEN 3 THEN '74rem'
                                    ELSE        '34rem' ).

    DATA(lo_dlg)  = io_popup->dialog( title = iv_title contentwidth = lv_width ).

*   THE THREE ATTRIBUTES THAT MAKE MULTI-COLUMN ACTUALLY WORK, and the reason
*   this is a method parameter and not a line each caller writes for itself.
*   Setting COLUMNSL alone looks like it should be enough and is not:
*
*     LABELSPAN* = 12 puts the label on its own row ABOVE its control. At one
*     column the default side-by-side label is right; at two or three the label
*     eats half of an already narrow cell and every control is squeezed to
*     nothing. 12 of 12 grid units is the whole width, which is what forces the
*     wrap.
*
*     ADJUSTLABELSPAN = false. Left true - the default - SAPUI5 recomputes the
*     label span itself from the number of containers and silently discards the
*     LABELSPAN* above. The symptom is a two-column dialog that lays out as if
*     none of this had been set, which reads as the columns not working at all.
*
*     SINGLECONTAINERFULLSIZE = false. A SimpleForm with ONE container - which is
*     every dialog built here, since none of them passes a title per group -
*     defaults to giving that container the full width and ignoring COLUMNSL /
*     COLUMNSXL entirely. This is the attribute that lets a single container be
*     divided into columns at all.
*
*   All three are passed ONLY when there is more than one column, so the
*   one-column dialog keeps the exact markup it had before this parameter existed.
    DATA lo_form TYPE REF TO z2ui5_cl_xml_view.
    IF lv_cols = 1.
      lo_form = lo_dlg->content(
        )->simple_form( editable  = abap_true
                        layout    = 'ResponsiveGridLayout'
                        columnsxl = '1' columnsl = '1' columnsm = '1'
        )->content( ns = 'form' ).
    ELSE.
      lo_form = lo_dlg->content(
        )->simple_form( editable                = abap_true
                        layout                  = 'ResponsiveGridLayout'
                        columnsxl               = |{ lv_cols }|
                        columnsl                = |{ lv_cols }|
                        columnsm                = |{ lv_cols }|
                        labelspanxl             = '12'
                        labelspanl              = '12'
                        labelspanm              = '12'
*                       A LITERAL 'false', not ABAP_FALSE. SIMPLE_FORM passes this one
*                       through RAW - only SINGLECONTAINERFULLSIZE goes through
*                       BOOLEAN_ABAP_2_JSON - so ABAP_FALSE would emit a blank
*                       attribute and the default true would stand.
                        adjustlabelspan         = 'false'
                        singlecontainerfullsize = abap_false
        )->content( ns = 'form' ).
    ENDIF.


*   Created on first use, not per field. The resolver caches per instance, so one
*   instance across the whole dialog means two fields on the same data element
*   cost one DDIC read - and a dialog with no value help at all costs none.
    DATA lo_f4 TYPE REF TO zcl_rak_f4_resolver.

    LOOP AT it_fields INTO DATA(ls).

*     REQUIRED is the sap.m.Label property, not a CSS class - see
*     ZCL_RAK_JOURNEY_RENDER->REQ_LABEL( ). Every hand-drawn popup that still
*     wants a marker should come through here rather than draw its own label.
      lo_form->label( text     = ls-label
                      required = ls-required ).

*     Explicit list wins outright; otherwise ask the resolver, which applies its
*     own documented precedence across the three names.
      DATA(lt_opt) = ls-options.
      IF lt_opt IS INITIAL
         AND ( ls-rollname IS NOT INITIAL
            OR ls-domname  IS NOT INITIAL
            OR ls-shlp     IS NOT INITIAL ).
        IF lo_f4 IS INITIAL.
          lo_f4 = NEW zcl_rak_f4_resolver( ).
        ENDIF.
        lt_opt = lo_f4->resolve( iv_rollname = ls-rollname
                                 iv_shlp     = ls-shlp
                                 iv_domname  = ls-domname ).
      ENDIF.

      DATA(lv_edit) = xsdbool( ls-readonly = abap_false ).
      DATA(lv_w)    = COND string( WHEN ls-width IS NOT INITIAL THEN ls-width ELSE '100%' ).
      DATA(lv_len)  = COND string( WHEN ls-maxlen > 0 THEN |{ ls-maxlen }| ).

*     A resolved list beats the declared type, deliberately. A field that names a
*     data element wants that element's values whether or not anybody remembered
*     to also write SELECT - and a SELECT whose sources resolve to nothing falls
*     through to an input below rather than rendering an empty dropdown.
      IF lt_opt IS NOT INITIAL.
        DATA(lo_cb) = lo_form->combobox( selectedkey = io_ctx->bind( ls-name )
                                         enabled     = lv_edit
                                         width       = lv_w
                                         placeholder = ls-placeholder
*                                        Blank leaves the dropdown exactly as it
*                                        rendered before CHANGE_EVT existed.
                                         change      = COND string(
                                           WHEN ls-change_evt IS NOT INITIAL
                                           THEN io_ctx->event( ls-change_evt ) ) ).
        LOOP AT lt_opt INTO DATA(ls_o).
          lo_cb->item( key = ls_o-key text = ls_o-text ).
        ENDLOOP.
        CONTINUE.
      ENDIF.

      CASE to_upper( ls-type ).
        WHEN 'TEXTAREA'.
          lo_form->text_area( value       = io_ctx->bind( ls-name )
                              rows        = '3'
                              editable    = lv_edit
                              width       = lv_w
                              placeholder = ls-placeholder ).

        WHEN 'DATE'.
          lo_form->date_picker( value   = io_ctx->bind( ls-name )
                                enabled = lv_edit
                                width   = lv_w ).

        WHEN 'CHECKBOX'.
          lo_form->checkbox( selected = io_ctx->bind( ls-name )
                             enabled  = lv_edit ).

        WHEN OTHERS.
*         F4_EVT draws sap.m.Input's own value-help icon. Blank leaves the input
*         exactly as it rendered before any of this existed.
          lo_form->input( value            = io_ctx->bind( ls-name )
                          type             = COND string( WHEN to_upper( ls-type ) = 'NUMBER' THEN 'Number' )
                          editable         = lv_edit
                          width            = lv_w
                          placeholder      = ls-placeholder
                          maxlength        = lv_len
                          showvaluehelp    = COND string( WHEN ls-f4_evt IS NOT INITIAL THEN abap_true )
                          valuehelprequest = COND string( WHEN ls-f4_evt IS NOT INITIAL
                                                          THEN io_ctx->event( ls-f4_evt ) ) ).
      ENDCASE.
    ENDLOOP.

    DATA(lo_btns) = lo_dlg->buttons( ).
    lo_btns->button( text  = iv_ok_text
                     type  = 'Emphasized'
                     icon  = 'sap-icon://accept'
                     press = io_ctx->event( iv_ok_evt ) ).
    lo_btns->button( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-cancel
                                        iv_default = `Cancel` )
                     press = io_ctx->event( iv_cxl_evt ) ).
  ENDMETHOD.


  METHOD case_key_of.

*   THE KEY COMES BACK UNCHANGED UNLESS A CASE IS POSITIVELY FOUND. Set
*   first and overwritten only on a confirmed hit, so every exit from
*   here - including both CATCH blocks - leaves the caller with exactly
*   the key it passed in. An earlier version of this returned BLANK when
*   it could not confirm a case, and the payment gate refused on blank:
*   that would have made a missing or not-yet-committed case-attribute
*   row break DOK and EPDA, two families that have never depended on one.
    rs-key = iv_key.

    DATA(lv_in) = condense( iv_key ).
    IF lv_in IS INITIAL.
      RETURN.
    ENDIF.

*   IS IT ALREADY A CASE? The DOK and EPDA path, and it must stay first:
*   there the journey key IS the case id, so the answer is the key itself
*   and no INTRENO lookup is worth running.
*
*   WRAPPED, because this is the failure the comments around here have
*   been warning about for months. A journey key can be a GUID_22 with
*   punctuation in it, and an SCMG_EXT_KEY comparison against one raises
*   CX_SY_OPEN_SQL_DATA_ERROR rather than simply missing - mid-payment,
*   with the gateway open in another tab. Catching it leaves the key
*   untouched and unconfirmed, which is the honest answer and is also
*   what the caller did with it before.
    DATA lv_ek TYPE scmg_ext_key.
    TRY.
        lv_ek = |{ CONV scmg_ext_key( lv_in ) ALPHA = IN }|.
        SELECT SINGLE ext_key FROM scmg_t_case_attr
          WHERE ext_key = @lv_ek
          INTO @DATA(lv_hit).
        IF sy-subrc = 0 AND lv_hit IS NOT INITIAL.
          rs-is_case = abap_true.
          trace_key( io_ctx = io_ctx iv_in = lv_in iv_what = `already a case` ).
          RETURN.
        ENDIF.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

*   THEN AS AN INTRENO. VIBDCHARACT carries the case id against the RE
*   object under FIXFITCHARACT 'CJ12' - the same read RESOLVE_CASE( )
*   does first, and the one that turns IM00100123344 into 1959738. This
*   is the ONLY branch that changes what a caller sees, and it changes it
*   only when the database has positively said the two are the same
*   application.
*
*   Returned unpadded, the way the raw key always was. ALPHA = IN belongs
*   at the DFKKOP read, where it has always been, not here - padding it
*   early would change the value every other caller receives.
    DATA lv_int TYPE vibdcharact-intreno.
    TRY.
        lv_int = lv_in.
        SELECT SINGLE supplementinfo FROM vibdcharact
          WHERE intreno = @lv_int AND fixfitcharact = 'CJ12'
          INTO @DATA(lv_sup).
        IF sy-subrc = 0 AND lv_sup IS NOT INITIAL.
          rs-key     = condense( CONV string( lv_sup ) ).
          rs-is_case = abap_true.
          trace_key( io_ctx  = io_ctx
                     iv_in   = lv_in
                     iv_what = |case { rs-key } via VIBDCHARACT CJ12| ).
          RETURN.
        ENDIF.
      CATCH cx_root ##NO_HANDLER.
    ENDTRY.

    trace_key( io_ctx  = io_ctx
               iv_in   = lv_in
               iv_what = `no case confirmed - key used unchanged` ).

  ENDMETHOD.


  METHOD trace_key.
*   Two keys that look alike and mean different things is precisely what
*   cost this step a round: the trace showed the gate searching for
*   'IM00100123344' with case 1959738 sitting in SCASE, and nothing said
*   the two were related or that one of them was the wrong one.
    pay_trace( io_ctx = io_ctx iv_text = |PAY     case key { iv_in } -> { iv_what }| ).
  ENDMETHOD.


  METHOD wd_pay_url.
*   Hosts and the doubled '?' are copied from ZCL_CJ_DEMO_P001 as they
*   stand. The second '?' where a '&' belongs is the legacy's own
*   construction and is what the Web Dynpro app is known to accept -
*   correcting it here would be a guess against a working caller.
*
*   LAST RESORT ONLY. REDIRECTURL is preferred over this because the
*   BAdI already resolved the right host for the system it ran on,
*   whereas this has to pick one.
    IF iv_ref IS INITIAL.
      RETURN.
    ENDIF.
    rv = COND string(
           WHEN sy-sysid = 'E30'
           THEN `https://grpportal.rak.ae/sap/bc/webdynpro/sap/zwda_ega_euser_payments`
             && `?sap-language=EN?referenceId=`
           WHEN sy-sysid = 'E10'
           THEN `https://devgrpportal.rak.ae/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS`
             && `?sap-language=EN?referenceId=`
           ELSE `https://devgrpportal.rak.ae:444/sap/bc/webdynpro/sap/ZWDA_EGA_EUSER_PAYMENTS`
             && `?sap-language=EN?referenceId=` ) && iv_ref.
  ENDMETHOD.


  METHOD pay_trace.
    DATA lo_eng TYPE REF TO zcl_rak_journey_engine.
    TRY.
        lo_eng = CAST #( io_ctx ).
      CATCH cx_sy_move_cast_error.
        CLEAR lo_eng.
    ENDTRY.
    IF lo_eng IS BOUND.
      lo_eng->trace( iv_text ).
    ENDIF.
  ENDMETHOD.


  METHOD pay_engine.
* iv_caseid is the CONTAINER case number - the ext_key on SCMG_T_CASE_ATTR - and
* GET_CASE( ) supplies it, though only after the case exists.
*
* GET_CASE( ) returns MV_CASE_GUID, which the engine takes from the bridge's
* EV_GUID, which the bridge reads off the INTRENO_JOURNEY row of the POST reply:
*
*     ev_guid = VALUE #( lt_item[ technicalname = 'INTRENO_JOURNEY' ]-value OPTIONAL ).
*
* and the DOK BAdI overwrites exactly that row the moment the case is created:
*
*     IF gs_data-caseid IS NOT INITIAL.
*       READ TABLE ct_item_data ... technicalname = 'INTRENO_JOURNEY'.
*       <item>-value = gs_data-caseid.
*
* So the draft guid becomes the case id in the SAME round trip as the Pay press,
* before PREPARE_PAYMENT( ) runs. CASE_NUMBER cannot serve here: it is filled by a
* READ, and no read has happened yet at that moment - it is blank at precisely the
* point the engine needs it.
*
* CASE_NUMBER is still preferred when it IS filled, which is the resumed-journey
* case: the citizen returns to a saved application, the read fills CASE_NUMBER from
* GS_DATA-CASEID, and GET_CASE( ) may still be carrying the draft key.
*
* BUKRS, MATERIAL and CASES_FOR were not passed at all. PREPARE_GATEWAY tests the
* first two before it does anything else and returns 'company code / fee material
* were not supplied to the payment engine' - so with the constructor as it was,
* the gateway could never open on any journey, whatever else was fixed. They are
* read from the model so a journey supplies them in its own definition.
*   No fallback to GET_CASE( ). It was there because CASE_NUMBER used to be blank at
*   this point and GET_CASE( ) happened to hold the case id - the backend having
*   renamed the journey key underneath us. Both halves of that are gone: the engine
*   publishes CASE_NUMBER in TAKE_CASE( ) the moment the backend returns one, and
*   GET_CASE( ) is now the draft key and stays that way.
*
*   So a blank CASE_NUMBER means no case exists, and passing the draft key instead
*   would send the pay engine looking for an SCMG ext_key that never matches -
*   silently, because GET_FEES( ) and ROUTE_GATEWAY( ) both RETURN on no rows.
    DATA(lv_case) = io_ctx->get_val( c_pay_case ).

*   THE RESOLVED CASE for IV_CASEID, the journey key for IV_INTRENO. The
*   two parameters mean different things and were being handed the same
*   value - which is right only while the journey key happens to BE the
*   case, as it is on DOK and EPDA. On Municipality the key is the RE
*   object's INTRENO and IV_CASEID was therefore never a case at all.
*   RESOLVE_CASE( ) can turn an INTRENO into a case, which is why
*   IV_INTRENO keeps the raw key.
    ro = NEW zcl_rak_pay_engine(
           iv_caseid    = CONV #( case_key_of( io_ctx = io_ctx iv_key = lv_case )-key )
*          The CASE, not the journey key. RESOLVE_CASE( ) puts this straight into
*          VIBDCHARACT-INTRENO and SCMG_T_CASE_ATTR-EXT_KEY, and a CJS journey key is
*          a GUID_22 with punctuation in it - which raises CX_SY_OPEN_SQL_DATA_ERROR
*          rather than simply not matching. It used to work only because GET_CASE( )
*          was returning the case id, the backend having renamed the key underneath.
           iv_intreno   = lv_case
           iv_bp        = CONV #( io_ctx->get_param( 'loginbp' ) )
           iv_bukrs     = CONV #( io_ctx->get_val( c_pay_bukrs ) )
           iv_material  = CONV #( io_ctx->get_val( c_pay_material ) )
           iv_cases_for = CONV #( io_ctx->get_val( c_pay_casesfor ) ) ).
  ENDMETHOD.


  METHOD pay_field_step.
    rv_step = -1.
    DATA lv_ix TYPE i.
    DATA(ls_cfg) = io_ctx->get_config( ).
    LOOP AT ls_cfg-steps INTO DATA(ls_step).
      LOOP AT ls_step-fields INTO DATA(ls_f).
        IF to_upper( ls_f-name ) = c_pay_field.
          rv_step = lv_ix.
          RETURN.
        ENDIF.
      ENDLOOP.
      lv_ix = lv_ix + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD pay_read_items.
*   The bridge seeds CT_DEFINITION from this list before calling the read FM, and the
*   BAdI only fills rows that are already there - so a name missing here comes back
*   missing, silently. APPLICATIONURL is the one that matters; the rest are carried
*   because they are cheap and because seeing them is what makes a blank URL
*   diagnosable rather than mysterious.
    rt = VALUE #(
      ( field = 'APPLICATIONURL'   tech = 'APPLICATIONURL' )
      ( field = 'REDIRECTURL'      tech = 'REDIRECTURL' )
      ( field = 'MERCHANTID'       tech = 'MERCHANTID' )
      ( field = 'TERMINALID'       tech = 'TERMINALID' )
      ( field = 'SECRETKEY'        tech = 'SECRETKEY' )
      ( field = 'SERVICEID'        tech = 'SERVICEID' )
      ( field = 'REFERENCEID'      tech = 'REFERENCEID' )
      ( field = 'ESERVICECODE'     tech = 'ESERVICECODE' )
      ( field = 'SERVICESESSIONID' tech = 'SERVICESESSIONID' )
      ( field = 'PAYCHANNEL'       tech = 'PAYCHANNEL' )
      ( field = 'PAYTYPE'          tech = 'PAYTYPE' )
      ( field = 'SERVICELIST'      tech = 'SERVICELIST' )
      ( field = 'AMOUNT'           tech = 'AMOUNT' )
      ( field = 'EMAIL'            tech = 'EMAIL' )
      ( field = 'USERID'           tech = 'USERID' )
      ( field = 'LANG'             tech = 'LANG' )
      ( field = 'TOTALFEESVALUE'   tech = 'TOTALFEESVALUE' )
      ( field = 'OWNER_BP'         tech = 'OWNER_BP' )
      ( field = 'CASE'             tech = 'CASE' )
      ( field = 'INTRENO_JOURNEY'  tech = 'INTRENO_JOURNEY' )
      ( field = 'ATB_FLAG'         tech = 'ATB_FLAG' )
      ( field = 'PW_RB1'           tech = 'PW_RB1' )
      ( field = 'PW_RB2'           tech = 'PW_RB2' ) ).
  ENDMETHOD.


  METHOD pay_render.
    IF iv_poll = abap_true.
*     ---- the waiting screen ------------------------------------------------
*     A spinner under a fee table is the wrong shape for this moment. The citizen
*     is not looking at this tab - they are in the gateway - so what matters is
*     what they find when they come BACK, and the two things they need are a way
*     to reopen a window a pop-up blocker ate and the reassurance that we are
*     still listening.
*
*     Everything else goes. The fee table, the terms, the method block: all of it
*     is decided by now, none of it is actionable, and leaving a Pay button on
*     screen beside 'waiting for payment' invites a second attempt at a payment
*     that is already open.
      DATA(lv_secs) = 0.
      DATA(lv_tk) = io_ctx->get_val( c_pay_tries ).
      IF lv_tk IS NOT INITIAL AND lv_tk CO '0123456789'.
        lv_secs = lv_tk * 5 / 2.
      ENDIF.
      DATA(lv_el) = |{ lv_secs DIV 60 }:{ lv_secs MOD 60 WIDTH = 2 PAD = '0' }|.

      DATA(lo_wait) = io_view->vbox( class = 'rakCard' ).

      DATA lv_w TYPE string.
      lv_w =
        `<style>` &&
        `.rakPayRing{animation:rakSpin 1.9s linear infinite;transform-origin:50% 50%}` &&
        `@keyframes rakSpin{to{transform:rotate(360deg)}}` &&
        `@media (prefers-reduced-motion:reduce){.rakPayRing{animation:none}}` &&
        `</style>` &&
        `<div style="text-align:center;padding:2.4rem 1rem 1rem;">` &&
        `<svg width="96" height="96" viewBox="0 0 48 48" style="margin-bottom:1rem;">` &&
*       A ring that is plainly turning, with a card at the centre. Not a busy
*       indicator - that reads as 'the page is loading' and this page is not.
        `<circle cx="24" cy="24" r="21" fill="none" stroke="rgba(0,0,0,.09)" stroke-width="2.5"/>` &&
        `<circle class="rakPayRing" cx="24" cy="24" r="21" fill="none" stroke="#A80F2D"` &&
        ` stroke-width="2.5" stroke-linecap="round" stroke-dasharray="26 106"/>` &&
        `<rect x="14" y="19" width="20" height="13" rx="2" fill="none"` &&
        ` stroke="#A80F2D" stroke-width="1.8"/>` &&
        `<path d="M14 24 H34" stroke="#A80F2D" stroke-width="1.8"/>` &&
        `</svg>` &&
        `<div style="font-size:1.3rem;font-weight:700;">` &&
*       English only for now. MV_LANG lives on the engine and is not on
*       ZIF_RAK_JOURNEY, so this method cannot see it - add an Arabic branch here
*       once it is, rather than leaving a COND that can never take its first arm.
        zcl_rak_journey_util=>esc( `Complete your payment in the new tab` ) &&
        `</div>` &&
        `<div style="font-size:.92rem;opacity:.72;margin-top:.4rem;max-width:34rem;` &&
        `margin-left:auto;margin-right:auto;">` &&
        `We are waiting for the payment to be confirmed. Keep this page open - it ` &&
        `updates by itself.</div>` &&
        `<div style="margin-top:1.1rem;display:inline-flex;gap:1.6rem;align-items:baseline;` &&
        `font-family:monospace;font-size:.85rem;opacity:.6;">` &&
        `<span>AED ` && zcl_rak_journey_util=>esc( |{ iv_total NUMBER = USER }| ) && `</span>` &&
        `<span>` && lv_el && `</span></div></div>`.
      REPLACE ALL OCCURRENCES OF `{` IN lv_w WITH `\{`.
      REPLACE ALL OCCURRENCES OF `}` IN lv_w WITH `\}`.
      lo_wait->html( content = lv_w sanitizecontent = abap_false ).

      DATA(lo_act) = lo_wait->hbox( justifycontent = 'Center'
                                    class          = 'sapUiSmallMarginTop sapUiSmallMarginBottom' ).
*     The one control that earns its place. A blocked pop-up is the commonest way
*     this goes wrong and the citizen has no other route back to the gateway.
      lo_act->button( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_reopen
                                         iv_default = `Reopen payment page` )
                      icon  = 'sap-icon://action'
                      type  = 'Emphasized'
                      press = io_ctx->event( c_pay_open ) ).

*     After a minute, an exit. Waiting with no way to stop is how somebody ends up
*     using the browser's back arrow, and the back arrow leaves the payment open
*     with nothing watching it.
      IF lv_secs >= 60.
        lo_act->button( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_stop
                                           iv_default = `Stop waiting` )
                        press = io_ctx->event( c_pay_stop )
                        class = 'sapUiTinyMarginBegin' ).
      ENDIF.

      lo_wait->button( text  = 'poll'
                       class = 'rakHide rakPayPoll'
                       press = io_ctx->event( c_pay_poll ) ).
      DATA(lv_js) =
        `setTimeout(function(){var el=document.querySelector('.rakPayPoll');` &&
        `if(el){sap.ui.getCore().byId(el.id).firePress();}},2500);this.remove();`.
      DATA(lv_html) =
        `<div><img src="data:," style="display:none" onerror="` && lv_js && `"/></div>`.
      REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
      REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
      lo_wait->html( content = lv_html sanitizecontent = abap_false ).
      RETURN.
    ENDIF.

    DATA(lo_card) = io_view->vbox( class = 'rakSearch' ).

    DATA(lo_tab)  = lo_card->table( ).
    DATA(lo_cols) = lo_tab->columns( ).
    lo_cols->column( )->text( zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-description
                                                 iv_default = `Description` ) ).
    lo_cols->column( halign = 'End' )->text( zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-amount_aed
                                                                iv_default = `Amount (AED)` ) ).
    DATA(lo_items) = lo_tab->items( ).
    LOOP AT it_fee INTO DATA(ls_fee).
      lo_items->column_list_item( )->cells(
        )->text( ls_fee-desc
        )->text( |{ ls_fee-amount NUMBER = USER }| ).
    ENDLOOP.

    DATA(lo_tot) = lo_card->hbox( justifycontent = 'End'
                                  alignitems     = 'Center'
                                  class          = 'sapUiSmallMarginTop' ).
    lo_tot->label( zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-total
                                      iv_default = `Total` ) ).
    lo_tot->object_number( number     = |{ iv_total NUMBER = USER }|
                           numberunit = 'AED'
                           emphasized = abap_true
                           class      = 'sapUiSmallMarginBegin' ).

    IF io_ctx->get_val( iv_field ) = 'PAID'.
      lo_card->object_status( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_received
                                                 iv_default = `Payment received` )
                              state = 'Success'
                              icon  = 'sap-icon://accept'
                              class = 'sapUiSmallMarginTop' ).
      RETURN.
    ENDIF.

*   Between the total and the button, and only while something is still owed. The
*   early return above keeps it off the page after payment - which is right, since
*   by then none of it is true: the method was chosen, the charges were applied,
*   and the pop-up either opened or the citizen would not be standing here.
    pay_terms( io_ctx = io_ctx io_view = lo_card ).

    IF iv_poll = abap_false.
*     PAY_FOOTER = 'X' suppresses this button and leaves the footer's Pay as the
*     only way in. Two live Pay buttons on one card is two entry points into one
*     payment with nothing stopping both being pressed, and prepare_payment( )
*     blocks for up to two minutes - long enough for a citizen to press the other
*     one while the first is still waiting on the open item.
      IF io_ctx->get_val( 'PAY_FOOTER' ) <> 'X'.
        lo_card->button( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_now
                                            iv_default = `Pay now` )
                         type  = 'Emphasized'
                         icon  = 'sap-icon://credit-card'
                         class = 'sapUiSmallMarginTop'
                         press = io_ctx->event( c_pay_now ) ).
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD pay_terms.
*   The order is the legacy order and it is the right one: what is being used to
*   pay, then what using it costs, then the one thing the citizen has to do to
*   their own browser before any of it can work.

*   ---- Payment Method -------------------------------------------------
    DATA(lv_method) = io_ctx->get_val( c_pay_method ).
    IF lv_method IS INITIAL.
      lv_method = 'RAK.ae / quick payment'.
    ENDIF.

    io_view->label( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_method
                                       iv_default = `Payment Method` )
                    class = 'sapUiSmallMarginTop' ).
    DATA(lo_m) = io_view->radio_button_group( selectedindex = '0' ).
    SPLIT lv_method AT '|' INTO TABLE DATA(lt_method).
    LOOP AT lt_method INTO DATA(lv_m).
      CONDENSE lv_m.
      IF lv_m IS NOT INITIAL.
        lo_m->radio_button( text = zcl_rak_journey_util=>esc( lv_m ) ).
      ENDIF.
    ENDLOOP.

*   ---- the pop-up notice ----------------------------------------------
*   Not decoration. The gateway is a different domain, so it can only be reached
*   with window.open, and a blocked pop-up produces exactly nothing: no page, no
*   error, a button that appears not to work. The citizen is the only person who
*   can fix it and they cannot fix what nobody told them - which is why this sits
*   ABOVE the button rather than in the failure message afterwards.
    io_view->message_strip( text     = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_popup
                                                    iv_default = `Please allow browser pop-ups to enable payment` )
                            type     = 'Information'
                            showicon = abap_true
                            class    = 'sapUiTinyMarginTop' ).

*   ---- Pay with -------------------------------------------------------
    DATA(lv_chan) = io_ctx->get_val( c_pay_channel ).
    IF lv_chan IS INITIAL.
      lv_chan = 'RAK Pay'.
    ENDIF.

    io_view->label( text  = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_with
                                       iv_default = `Pay with` )
                    class = 'sapUiSmallMarginTop' ).
    DATA(lo_c) = io_view->radio_button_group( selectedindex = '0' ).
    SPLIT lv_chan AT '|' INTO TABLE DATA(lt_chan).
    LOOP AT lt_chan INTO DATA(lv_c).
      CONDENSE lv_c.
      IF lv_c IS NOT INITIAL.
        lo_c->radio_button( text = zcl_rak_journey_util=>esc( lv_c ) ).
      ENDIF.
    ENDLOOP.

*   ---- what it costs to use it ----------------------------------------
*   READ THIS BEFORE THE NEXT RELEASE. The defaults below are the RAK Government
*   payment-platform charges as published on the legacy portal. They are two
*   percentages, a cap and a VAT rate: every one of them is somebody else's
*   number, and every one of them will change without this class being touched.
*
*   That is what PAY_CHARGES is for. Point it at the BAdI or at a TVARV entry and
*   these lines stop being ABAP the moment anybody has somewhere better to keep
*   them. They are here so the page is not blank in the meantime and they should
*   not survive the first rate change.
    DATA lt_ch TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA(lv_charges) = io_ctx->get_val( c_pay_charges ).
    IF lv_charges IS NOT INITIAL.
      SPLIT lv_charges AT '|' INTO TABLE lt_ch.
    ELSE.
      lt_ch = VALUE #(
        ( `RAK Government has enabled a new payment platform for online services, ` &&
          `offering payment channels including E-Wallet, Apple Pay and Google Pay.` )
        ( `Cards Visa / MasterCard on RAK Government portal: 1.00%` )
        ( `RAK Wallet: 0.80% with CAP 1000 AED` )
        ( `The above bank charges are subject to VAT 5%` ) ).
    ENDIF.

    DATA(lo_p) = io_view->vbox( class = 'rakSearch sapUiSmallMarginTop' ).
    LOOP AT lt_ch INTO DATA(lv_line).
      CONDENSE lv_line.
      IF lv_line IS NOT INITIAL.
        lo_p->text( text = zcl_rak_journey_util=>esc( lv_line ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD prepare_payment.
*---------------------------------------------------------------------------------------*
* Ask this journey's own payment screen for a gateway URL. That is the whole method.
*
* The read BAdI behind that screen already does everything a gateway launch needs:
* it resolves the open item from the case, picks the gateway, draws the payment
* reference, writes the transaction row and returns a ready checkout URL in
* APPLICATIONURL. For D026 that is GET_RB_CPG_DETAILS, reached from its READ under
* IF gs_data-fees[] IS NOT INITIAL AND technicalname EQ 'PAYTYPE' - which is why
* PAY_READ_ITEMS( ) seeds PAYTYPE whether or not the journey configures it.
*
* NOT the standalone pay app. PG01 is the dashboard's Waiting for payment door, for
* a citizen who left the journey without paying. A payment started inside a journey
* has to be finished by that journey, or the payment completes and the journey does
* not.
*
* So CJS supplies a case number and opens what comes back. It does NOT choose between
* ATB, EDIRHAM and ETISALAT, does not read ZDT_MERCH_RAKPAY or ZDT_EDIRHAM_SERV, does
* not touch the number range and does not write ZETISLAT_TRANSAC. Every one of those
* was a reimplementation of this call, and the cost was visible: two references drawn
* for one payment, and a POST to the CPG connector on a landscape that uses ATB.
*
* ZCL_RAK_PAY_ENGINE->PREPARE_GATEWAY is what did all that and is no longer called
* from here. It is left in place rather than deleted - POLL_STATUS and CHECK_LOCK on
* the same class are still used - but nothing should call it again without first
* establishing that the payment journey cannot answer.
*---------------------------------------------------------------------------------------*
*   CASE_NUMBER only. GET_CASE( ) is the draft key - see the note in pay_engine( ) -
*   and the payment screen's read BAdI resolves the gateway from a CASE.
    DATA(lv_case) = io_ctx->get_val( c_pay_case ).
    IF lv_case IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
*                      NOT "the commit did not reach the backend" any more. That
*                      wording asserted the one thing that is usually false: the
*                      commit reaches the backend, the case gets created, and the
*                      number comes back as the journey KEY rather than as EV_CASE
*                      because we went in holding nothing. PAYNOW adopts it now.
*                      Reaching here means neither channel produced a case, so say
*                      that and nothing more.
*                      BACKTICKS, not quotes. ABAP TRUNCATES TRAILING BLANKS in a
*                      '...' character literal, so 'from the ' && 'commit' renders
*                      as "from thecommit" - which is exactly how this shipped and
*                      what the citizen was shown. A `...` string literal keeps
*                      them. Any concatenation split across lines needs backticks
*                      or a |...| template; this is not a style preference.
                       iv_text = `Payment cannot start: no case number came back from the ` &&
                                 `commit, on either the case or the journey key. Nothing ` &&
                                 `can be billed until the backend has created the case.` ).
      pay_trace( io_ctx  = io_ctx
                 iv_text = `PAY     prepare STOP NOCASE - no case number on either ` &&
                           `CASE_NUMBER or the journey key` ).
      zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_block
                           iv_case   = lv_case
                           iv_result = 'BLOCK'
                           iv_detail = `NOCASE` ).
      RETURN.
    ENDIF.

    DATA(lv_screen) = io_ctx->get_val( c_pay_screen ).
    IF lv_screen IS INITIAL.
      io_ctx->add_msg( iv_type = 'Error'
                       iv_text = 'Payment cannot start: PAY_SCREEN is not set. It names the backend screen whose read BAdI resolves the gateway - the payment step''s own BKND_SCREEN.' ).
      pay_trace( io_ctx  = io_ctx
                 iv_text = `PAY     prepare STOP NOSCREEN - PAY_SCREEN is blank and the ` &&
                           `payment step has no BKND_SCREEN to derive it from, so no read ` &&
                           `BAdI can be called and no gateway can ever resolve` ).
      zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_block
                           iv_case   = lv_case
                           iv_result = 'BLOCK'
                           iv_detail = `NOSCREEN` ).
      RETURN.
    ENDIF.

*   ---- is there anything to pay yet? --------------------------------------
*   One SELECT SINGLE before spending a round trip on the BAdI.
*
*   The case is created by the Pay press, but its open item is not: the case starts
*   a workflow, the workflow raises a sales order, billing follows, and FI-CA posts
*   the item at the end of that chain. None of it is an update task, so COMMIT WORK
*   AND WAIT would not help - there is nothing to wait for yet. The only honest
*   answer is to ask again later, which is exactly what the poll does.
*
*   The BAdI cannot ask again later. Being a synchronous OData call it has nowhere
*   to put 'not yet', so GET_CPG_DETAILS_OLD approximates a poll inside one request:
*
*       DO 300 TIMES.
*         SELECT SINGLE ... FROM dfkkop WHERE zzext_key = ... AND augst = space.
*         IF sy-subrc EQ 0. EXIT. ELSE. WAIT UP TO '0.2' SECONDS. ENDIF.
*       ENDDO.
*
*   That was the right answer when the caller only got one attempt. CJS gets one
*   every 2.5 seconds, so the inner loop is now redundant - and it runs on EVERY
*   tick, in a dialog, until the address comes back.
*
*   THIS IS NOT A NEW QUERY. It is the same SELECT the BAdI has run for ten years,
*   asked once per tick instead of up to three hundred times per tick. Whatever
*   index it uses, it uses less of it than before.
*
*   BUKRS is deliberately not filtered. The BAdI pins 'RDOK' because it belongs to
*   one department; this is framework code and ZZEXT_KEY is a case id, which is
*   unique on its own. The BAdI still applies its own filter when it runs - this
*   gate only decides whether it is worth calling.
*   Typed FIRST, converted second - the order matters, and getting it wrong is what
*   broke this on the first run. ALPHA = IN pads to the length of the field it is
*   handed, and LV_CASE is a string, which has no length to pad to: the key came out
*   unpadded, matched nothing, and every tick returned early with the gateway never
*   opening. The BAdI gets this right because EXT_KEY is declared SCMG_EXT_KEY
*   before the conversion ever touches it.
*   RESOLVED FIRST, AND THIS IS THE FIX. ZZEXT_KEY is a CASE id. The
*   journey key is one on DOK and EPDA and is NOT one on Municipality,
*   where it is the RE object's INTRENO - so this gate searched DFKKOP
*   for 'IM00100123344' while the case sat in SCASE as 1959738, and no
*   open item could ever match. The citizen watched the payment timer
*   under a gateway that was never going to open.
*
*   THE SELECT BELOW IS UNTOUCHED, and that is deliberate. CASE_KEY_OF( )
*   hands the key back unchanged unless it positively finds a case, so on
*   DOK and EPDA this reads exactly the value it read before - including
*   when SCMG_T_CASE_ATTR does not answer, which today does not stop
*   those two families paying and must not start.
    DATA(ls_ck) = case_key_of( io_ctx = io_ctx iv_key = lv_case ).

    DATA lv_ek TYPE scmg_ext_key.
    lv_ek = ls_ck-key.
    DATA lv_extkey TYPE scmg_ext_key.
    lv_extkey = |{ lv_ek ALPHA = IN }|.

    SELECT SINGLE opbel FROM dfkkop INTO @DATA(lv_opbel)
      WHERE zzext_key = @lv_extkey
        AND augst     = @space
        AND betrh     > 0.
    IF sy-subrc <> 0.
*     Visible only under trace, and only until the workflow timing is known. The
*     first run of this gate failed silently and looked identical to a backend that
*     had not answered - the key it actually searched for is the one fact that
*     separates those two.
      io_ctx->add_msg( iv_type = 'Information'
                       iv_text = |TRACE dfkkop: no open item yet for ext_key '{ lv_extkey }'| ).

*     NO CASE YET IS NOT THE SAME AS NO FEE YET, and saying the wrong one
*     sends the reader to the wrong place. Both are legitimate "not yet"
*     states - the case is created by the post, the open item follows a
*     workflow - but only one of them is fixed by waiting for billing.
*     WORDING ONLY: the wait, the event and the RETURN below are the same
*     ones this branch has always taken, so a journey that used to sit
*     here and poll still sits here and polls.
      IF iv_quiet = abap_false.
        IF ls_ck-is_case = abap_false.
          io_ctx->add_msg( iv_type = 'Error'
            iv_text = `The application's case has not been created yet, so the payment `
                   && `page cannot open. The application is saved - reopen it in a few `
                   && `minutes to pay.` ).
        ELSE.
          io_ctx->add_msg( iv_type = 'Error'
            iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_nofee
                          iv_default = `The fee for this application has not been raised yet, so `
                                    && `the payment page cannot open. The application is saved - `
                                    && `reopen it in a few minutes to pay.` ) ).
        ENDIF.
      ENDIF.

*     Outside the IV_QUIET guard on purpose. Quiet suppresses the message to the
*     citizen, not the fact that a Pay press went nowhere.
      zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_block
                           iv_case   = lv_case
                           iv_result = 'BLOCK'
                           iv_detail = COND #( WHEN ls_ck-is_case = abap_false
                                               THEN `NOCASEYET` ELSE `NOFEE` ) ).
      RETURN.
    ENDIF.

*   THIS journey's backend configuration, reused as it stands. Same category, same
*   read FM, same backend journey - the only thing that changes is that the read is
*   asked for now, with the case number, rather than waiting for the next render.
*
*   PAY_JOURNEY and PAY_CATEGORY override it and are blank almost everywhere. They
*   exist for a department whose payment screen sits under a different category from
*   the rest of its journey, not as a route to the standalone pay app.
    DATA(ls_cfg) = io_ctx->get_config( ).

    DATA(lv_journey) = io_ctx->get_val( c_pay_journey ).
    IF lv_journey IS NOT INITIAL.
      ls_cfg-backend-journey = lv_journey.
    ENDIF.

    DATA(lv_category) = io_ctx->get_val( c_pay_category ).
    IF lv_category IS NOT INITIAL.
      ls_cfg-backend-category = lv_category.
    ENDIF.

*   ---- PARAM1 IS THE DRAFT KEY, NOT THE CASE NUMBER ------------------
*   THE READ RESOLVES A RENTAL OBJECT, AND ONLY THE DRAFT KEY FINDS ONE.
*   This sent the case number and the whole chain died two calls later:
*
*     MAPPER      ms_rero-intreno = ms_header_param-param1
*                 SELECT swenr, smenr FROM vibdro WHERE intreno = ms_rero-intreno
*     READ( )     BAPI_RE_RO_GET_DETAIL with that RO -> mt_char
*     the CPG blk caseid = mt_char[ fix_fit_charact = 'CJ12' ]-supplementinfo
*     GET_RB_CPG_DETAILS
*                 IF case_key IS INITIAL AND invoice_number IS INITIAL.
*                   RETURN.
*
*   VIBDRO is keyed on the INTRENO. Hand it 000001959749 and it finds no
*   row, so MS_RERO stays blank, the BAPI returns nothing, MT_CHAR is
*   empty, CASEID is blank, and GET_RB_CPG_DETAILS returns on its first
*   line - confirmed in the debugger with CASE_KEY holding spaces.
*
*   THE CASE IS INSIDE THE RENTAL OBJECT, WHICH IS THE POINT. The draft IS
*   the RE object; CREATE_DUMMY_CASE( ) writes the case id onto it as
*   characteristic CJ12 and leaves the key alone. So the draft key is what
*   finds the object and the object is what carries the case - passing the
*   case number instead skips the only thing that can resolve it.
*
*   GET_CASE( ) FIRST, CASE_NUMBER SECOND, and that one rule serves both
*   families. On DOK and EPDA the backend re-points the journey key at the
*   case the moment CREATE_CASE runs, so GET_CASE( ) already IS the case
*   number and this sends exactly what it sent before. On Municipality the
*   key stays the INTRENO (IM00100123352) while the case is a separate
*   number (000001959749), and only then do the two differ. Same
*   identity-fallback shape as CASE_KEY_OF( ), and for the same reason:
*   a family branch has to be kept right as families are added, whereas a
*   fallback is right by construction.
*
*   LV_CASE IS UNCHANGED and still the case number. It is what the DFKKOP
*   gate searched, what the messages name and what the event log records -
*   only the guid the read is asked with moves.
    DATA(lv_rguid) = io_ctx->get_case( ).
    IF lv_rguid IS INITIAL.
      lv_rguid = lv_case.
    ENDIF.

*   WHAT WENT OUT. Which screen, under which category and backend journey,
*   with which case AND with which guid - five values that between them
*   decide whether the read BAdI is even the right one, and none of which
*   were visible. The guid is listed separately from the case precisely
*   because the two being the same value on DOK and different on
*   Municipality is what hid this.
    pay_trace( io_ctx  = io_ctx
               iv_text = |PAY     prepare read screen={ lv_screen } case={ lv_case } | &&
                         |guid={ lv_rguid } cat={ ls_cfg-backend-category } | &&
                         |jny={ ls_cfg-backend-journey }| ).

    NEW zcl_rak_qnv_bridge( ls_cfg )->read(
      EXPORTING
        iv_screen  = lv_screen
        iv_guid    = lv_rguid
        it_items   = pay_read_items( )
*       PARAM3. ZIF_EGA_FW_CJI~READ takes no LOGINBP, so this is the only channel
*       the payment read has for the partner - and GET_CPG_DETAILS / the RAK Pay
*       variant build the gateway payload from GS_DATA-PARTNER. On a cold read
*       there is no shared-buffer entry to supply it.
        iv_loginbp = io_ctx->get_param( 'loginbp' )
      IMPORTING
        et_values  = DATA(lt_vals)
        et_msg     = DATA(lt_msg) ).

    IF iv_quiet = abap_false.
      LOOP AT lt_msg INTO DATA(ls_msg).
        io_ctx->add_msg( iv_type = ls_msg-type iv_text = ls_msg-text ).
      ENDLOOP.
    ENDIF.

*   THE BACKEND'S OWN WORDS, ON THE TRACE, WHATEVER IV_QUIET SAYS. Quiet
*   suppresses what the CITIZEN sees; it was also suppressing the one
*   thing that explains a failure, for all 48 poll ticks. If the BAdI
*   refused, it said why here and nobody could read it.
    LOOP AT lt_msg INTO DATA(ls_bmsg).
      pay_trace( io_ctx  = io_ctx
                 iv_text = |PAY     prepare backend { ls_bmsg-type }: { ls_bmsg-text }| ).
    ENDLOOP.

*   WHAT CAME BACK. A missing APPLICATIONURL has two completely different
*   causes that look identical from here - the BAdI was never really
*   called or answered nothing, versus it answered fine and the address
*   is under a key of another name. Listing the keys separates them in
*   one run, instead of a round per guess.
*   HOW MANY ARE ACTUALLY FILLED, counted separately from how many came
*   back. A screen whose definition lists every payment field and whose
*   map has no CPG row returns all the names and none of the values, and
*   a key list alone reads as a healthy payment read - which is exactly
*   how 23 keys with 23 blanks looked.
    DATA lv_keys TYPE string.
    DATA lv_filled TYPE i.
    LOOP AT lt_vals INTO DATA(ls_kv).
      IF ls_kv-value IS NOT INITIAL.
        lv_filled = lv_filled + 1.
      ENDIF.
      IF strlen( lv_keys ) > 300.
        CONTINUE.
      ENDIF.
      lv_keys = COND string( WHEN lv_keys IS INITIAL
                             THEN CONV string( ls_kv-key )
                             ELSE |{ lv_keys },{ ls_kv-key }| ).
    ENDLOOP.
    pay_trace( io_ctx  = io_ctx
               iv_text = |PAY     prepare read returned { lines( lt_vals ) } value(s) of which | &&
                         |{ lv_filled } filled, { lines( lt_msg ) } message(s) - keys: { lv_keys }| ).

*   REFERENCE AND AMOUNT ARE STORED BEFORE ANY EXIT. They used to be
*   written at the very bottom, after the URL check had already returned -
*   so on the one path that needed them, everything the read did answer
*   was thrown away, and PAY_REFERENCE stayed blank for ever.
    DATA(lv_ref) = VALUE string( lt_vals[ key = 'REFERENCEID' ]-value OPTIONAL ).
    IF lv_ref IS NOT INITIAL.
      io_ctx->set_val( iv_name = 'PAY_REFERENCE' iv_value = lv_ref ).
    ENDIF.

    DATA(lv_amt) = VALUE string( lt_vals[ key = 'AMOUNT' ]-value OPTIONAL ).
    IF lv_amt IS NOT INITIAL.
      io_ctx->set_val( iv_name = c_pay_total iv_value = lv_amt ).
    ENDIF.

*   APPLICATIONURL IS THE ATB PATH'S FIELD, AND ONLY ATB FILLS IT. This
*   is why M011 polled 48 times and gave up: the read answered richly -
*   AMOUNT, MERCHANTID, SERVICEID, SECRETKEY, REFERENCEID, PAYCHANNEL -
*   and every one of those was discarded because a single field it never
*   sets was blank.
*
*   ROUTE_GATEWAY( ) decides which it is from ZDT_PG_DEP_MAP: an ATB
*   department gets a ready-made APPLICATIONURL, and everything else -
*   PW_RB1 set, ATB_FLAG DISABLED, which is what M011 comes back as -
*   goes to the standard CPG through the payments Web Dynpro. There is no
*   pre-built URL on that route and there never was one to wait for.
*
*   REDIRECTURL IS THAT LAUNCH ADDRESS, not a return address as its name
*   suggests. ZCL_CJ_DEMO_P001 settles it: after filling the same details
*   it returns EV_URL built as ZWDA_EGA_EUSER_PAYMENTS with the
*   referenceId, character for character what the BAdI puts in
*   REDIRECTURL. That app holds the CPG form and posts it, which is also
*   why the SECRET KEY the read returns never has to reach our page.
*
*   ORDER MATTERS AND ATB STAYS FIRST. Where APPLICATIONURL is filled it
*   still wins, so nothing changes for a department already routed to
*   ATB - this only supplies an address on the route that never had one.
    DATA(lv_url) = VALUE string( lt_vals[ key = 'APPLICATIONURL' ]-value OPTIONAL ).
    DATA(lv_src) = `APPLICATIONURL`.

    IF lv_url IS INITIAL.
      lv_url = VALUE string( lt_vals[ key = 'REDIRECTURL' ]-value OPTIONAL ).
      lv_src = `REDIRECTURL (standard CPG via payments Web Dynpro)`.
    ENDIF.

    IF lv_url IS INITIAL.
      lv_url = wd_pay_url( lv_ref ).
      lv_src = `built from REFERENCEID`.
    ENDIF.

*   DID A PAYMENT SCREEN ANSWER AT ALL? The two ways of getting no address
*   look identical from here and lead to completely different places, and
*   the old message named neither of them.
*
*   ZCL_EGA_CJ_FW_RO_ABS_V1 builds the CPG payload only inside
*   IF line_exists( mt_ui_map[ objectkey = 'CPG_1' ] ) OR ... 'CPG_2',
*   and MT_UI_MAP is selected on (JOURNEYID, SCREEN, RWMODE). So a screen
*   with no CPG row in ZEGA_T_CJ_UI_MAP returns its own fields perfectly
*   and not one payment field - no MERCHANTID, no PAYCHANNEL, no
*   REFERENCEID, and no address of any kind. Nothing errors.
*
*   That is what M011 was doing. PAY_SCREEN was derived from the payment
*   step's own BKND_SCREEN, NSUBDIVISION_1_3, whose map holds a single
*   row - objectkey INITIAL, rwmode 1 - so the CPG branch was skipped on
*   every one of the 48 poll ticks. The same case read under NPAY_1_1 /
*   PG01 / PAY returns the whole payload.
*
*   PAY_SCREEN, PAY_JOURNEY and PAY_CATEGORY exist precisely for a
*   department whose payment screen sits under a different category from
*   the rest of its journey, which is what Municipality is. Deriving
*   PAY_SCREEN from the step is right where payment IS a step of the
*   journey - DOK and EPDA - and silently wrong otherwise, so the message
*   below names the three fields instead of sending the reader to the
*   backend.
*   THE TEST IS ON VALUES, NEVER ON KEYS - the trace settled this and the
*   first version of it was wrong. NSUBDIVISION_1_3 returns all 23
*   payment field NAMES, APPLICATIONURL and MERCHANTID and SECRETKEY
*   among them, because the screen's definition in /QNV/SB_UI_DEFIN
*   carries those fields. What it does not return is a single VALUE for
*   any of them, because the block that fills them is the one MT_UI_MAP
*   skipped. Testing LINE_EXISTS( ) therefore says "payment screen" about
*   the exact screen that is not one.
    DATA(lv_mid)  = VALUE string( lt_vals[ key = 'MERCHANTID' ]-value OPTIONAL ).
    DATA(lv_chan) = VALUE string( lt_vals[ key = 'PAYCHANNEL' ]-value OPTIONAL ).

    DATA(lv_has_cpg) = xsdbool( lv_mid  IS NOT INITIAL
                             OR lv_chan IS NOT INITIAL
                             OR lv_ref  IS NOT INITIAL ).

    IF lv_url IS INITIAL.
      pay_trace( io_ctx  = io_ctx
                 iv_text = COND string(
                   WHEN lv_has_cpg = abap_false
                   THEN |PAY     prepare STOP NOTAPAYSCREEN - { lv_screen } answered with no | &&
                        |CPG payload at all, so it has no CPG_1/CPG_2 row in ZEGA_T_CJ_UI_MAP|
                   ELSE `PAY     prepare STOP NOURL - CPG payload came back but carried no ` &&
                        `APPLICATIONURL, no REDIRECTURL and no REFERENCEID` ) ).
      IF iv_quiet = abap_false.
        IF lv_has_cpg = abap_false.
          io_ctx->add_msg( iv_type = 'Error'
            iv_text = |Screen { lv_screen } is not a payment screen - it answered with no | &&
                      |gateway fields at all. Set PAY_SCREEN, PAY_JOURNEY and PAY_CATEGORY | &&
                      |on this journey to the payment service, or the payment step will go | &&
                      |on reading its own screen.| ).
        ELSE.
          io_ctx->add_msg( iv_type = 'Error'
            iv_text = |The payment journey returned no gateway address for case { lv_case }. | &&
                      |Either the case still carries no open item, or the department is not | &&
                      |routed to a gateway - both are backend configuration, not this journey.| ).
        ENDIF.
      ENDIF.
      RETURN.
    ENDIF.

    pay_trace( io_ctx  = io_ctx
               iv_text = |PAY     prepare OK - gateway address from { lv_src }| ).

*   BUILD_PAY_URL prefers PAY_APPURL over everything else, so writing it here is
*   the whole handover. The reference is carried too, for the poll and for anyone
*   reconciling against the transaction table.
    io_ctx->set_val( iv_name = 'PAY_APPURL' iv_value = lv_url ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~attach_mode.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~draft_mode.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_attachments.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_attach_url.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_drafts.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~get_table.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_after_read.
  ENDMETHOD.


  METHOD seed_grid_from_backend.
*   Already populated - by the citizen, or by an earlier pass. Leave it alone.
    DATA(ls_tgt) = io_ctx->get_grid_data( iv_grid ).
    CHECK ls_tgt-rows IS INITIAL.
    CHECK ls_tgt-columns IS NOT INITIAL.

    DATA(ls_src) = io_ctx->get_backend_table( iv_source ).
    CHECK ls_src-rows IS NOT INITIAL.

    DATA lt_rows LIKE ls_tgt-rows.
    DATA lv_any  TYPE abap_bool.

    LOOP AT ls_src-rows INTO DATA(lt_srow).
      DATA(lt_trow) = zcl_rak_journey_util=>blank_row( ls_tgt-columns ).

*     Name to name. Where the backend gives no column of that name the target
*     cell simply stays blank, rather than taking a neighbour's value.
      LOOP AT ls_tgt-columns INTO DATA(lv_col).
        DATA(lv_val) = zcl_rak_journey_util=>cell_of( it_cols = ls_src-columns
                                                      it_row  = lt_srow
                                                      iv_name = lv_col ).
        CHECK lv_val IS NOT INITIAL.
        zcl_rak_journey_util=>put_cell( EXPORTING it_cols = ls_tgt-columns
                                                  iv_name = lv_col
                                                  iv_val  = lv_val
                                        CHANGING  ct_row  = lt_trow ).
        lv_any = abap_true.
      ENDLOOP.

      APPEND lt_trow TO lt_rows.
    ENDLOOP.

*   Nothing matched by name at all - the two grids do not share a vocabulary.
*   Say so rather than seeding a table of blank rows, which would read as data
*   loss and would also submit as one.
    IF lv_any = abap_false.
      io_ctx->add_msg(
        iv_type = 'Warning'
        iv_text = |{ iv_grid } could not be pre-filled from { iv_source }: no column | &&
                  |names in common. Check the two specs against each other.| ).
      RETURN.
    ENDIF.

    io_ctx->set_grid_data( iv_field = iv_grid
                           is_data  = VALUE #( columns = ls_tgt-columns rows = lt_rows ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_archive.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_attach.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_fields.
    DELETE ct_fields WHERE name CP 'PAY_*'.
    DELETE ct_fields WHERE name = c_pay_field.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = c_pay_field.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_tables.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_custom_validate.
*   The PAID gate, minus the deadlock it used to cause.
*
*   COMMIT_STEP( ) runs this for the current step, and ON_POPUP_EVENT( PAYNOW )
*   calls COMMIT_STEP( ) as the FIRST thing it does - the backend has to create the
*   case before there is an open item to bill against. So on the fee step this
*   method was refusing the one commit that makes payment possible: the citizen
*   could not pay until they had paid, the post never went, and the whole press
*   cost 6 ms and left no trace anywhere.
*
*   PAY_STARTED is the discriminator, and it costs nothing new: the payment path
*   already writes it and the footer already reads it. Set means THIS commit is the
*   payment. Blank means the citizen pressed Submit with the fee unpaid, which is
*   the case the gate exists for.
    DATA(lv_ps) = pay_field_step( io_ctx ).
    CHECK lv_ps >= 0 AND iv_step = lv_ps.

    IF io_ctx->get_val( c_pay_started ) = 'X'.
      RETURN.
    ENDIF.

    IF io_ctx->get_val( c_pay_field ) <> 'PAID'.
      rt = VALUE #( ( type = 'Error'
                      text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_first
                                 iv_default = `Payment must be completed before submitting.` ) ) ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_draft_discard.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_draft_load.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_draft_save.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_feedback.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_fee_calc.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_init.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_popup_event.

*   ---- PAY_SCREEN, DERIVED WHEN NOTHING SUPPLIED IT ------------------
*   PREPARE_PAYMENT( ) refuses without it, and its own message says what
*   the value is: "the payment step's own BKND_SCREEN". The engine is
*   holding that string the whole time - so refusing to start a payment
*   over a value it could work out itself was the wrong trade.
*
*   IT IS NOT A MODEL COMPONENT. BUILD_MODEL( ) reserves exactly three
*   PAY_ names - PAY_STARTED, PAY_REFERENCE, PAY_APPURL - so PAY_SCREEN
*   lives in MT_SCRATCH, which is why SET_VAL( ) works for it at all and
*   why nothing in ZRAK_T_JNY_FLD is needed. Two mechanisms already
*   supply it: a configured PAY_SCREEN field carrying the screen in
*   DEFAULT_VAL (what ZCL_RAK_CJS_XCHECK looks for, and calls the
*   "carrier"), or a handler ON_INIT doing it by hand, as D001, E014,
*   E015 and E146 do.
*
*   THE THREE MUNICIPALITY JOURNEYS HAD NEITHER, and that is what this
*   is for: M011 created its ZGCX case, linked the parcel, both partners
*   and all three attachments, raised the sales order - and then could
*   not open the gateway, because one string naming a screen the engine
*   already knew was blank.
*
*   ONLY WHEN BLANK, so a journey that configures it or sets it in
*   ON_INIT is untouched. A fee-less journey never reaches here at all -
*   the pay events are raised by the PAYFEE card, which it does not draw.
*
*   THE CURRENT STEP IS THE RIGHT STEP for every path that needs it: the
*   press, the poll and the reopen all happen on the payment step, and
*   PREPARE_PAYMENT( ) is only reached from those three.
    IF iv_event = c_pay_now OR iv_event = c_pay_poll OR iv_event = c_pay_open.

*     Cast rather than a new interface method, and the CATCH matters -
*     a test double passed as IO_CTX is not the engine and must not be
*     broken by this. Same pattern as the trace below.
      DATA lo_pe TYPE REF TO zcl_rak_journey_engine.
      TRY.
          lo_pe = CAST #( io_ctx ).
        CATCH cx_sy_move_cast_error.
          CLEAR lo_pe.
      ENDTRY.

      IF lo_pe IS BOUND.

*       ---- THE CONFIGURED DEFAULT WINS, EVERY TIME -------------------
*       "BLANK ONLY" WAS NOT ENOUGH, AND A DEBUGGER SESSION PROVED IT.
*       PAY_SCREEN is a MODEL value: it lives in the draft and survives
*       every round trip. So once a journey has run with one value, a
*       corrected DEFAULT_VAL in ZRAK_T_JNY_FLD never reaches it - the
*       old value is not blank, so nothing overwrote it, and
*       CS_HEADER-SCREENNAME went on arriving as NPAY_1_1 after the
*       configuration had already been changed to NSUBDIVISION_1_4 and
*       the load report re-run.
*
*       That is the wrong precedence for this field. PAY_SCREEN is not
*       something a citizen types or a backend returns - it is static
*       configuration, and the model copy is only a carrier so
*       PREPARE_PAYMENT( ) can read it through GET_VAL( ). When config
*       states a value, config is right and the carried copy is stale by
*       definition.
*
*       So the configured DEFAULT is re-seeded on every pay event. There
*       is nothing to lose: a value nobody configured is untouched, and a
*       value somebody configured cannot be pinned to whatever a draft
*       happened to capture first.
        DATA(lv_cfgscr) = ``.
        LOOP AT lo_pe->ms_config-steps INTO DATA(ls_cstp).
          LOOP AT ls_cstp-fields INTO DATA(ls_cfld)
               WHERE name = c_pay_screen.
            IF ls_cfld-default IS NOT INITIAL.
              lv_cfgscr = ls_cfld-default.
            ENDIF.
          ENDLOOP.
        ENDLOOP.

        IF lv_cfgscr IS NOT INITIAL.
          IF io_ctx->get_val( c_pay_screen ) <> lv_cfgscr.
            lo_pe->trace( |PAY     PAY_SCREEN { io_ctx->get_val( c_pay_screen ) } -> | &&
                          |{ lv_cfgscr } · the configured DEFAULT_VAL wins over the | &&
                          |value carried in the draft| ).
          ENDIF.
          io_ctx->set_val( iv_name = c_pay_screen iv_value = lv_cfgscr ).

        ELSEIF io_ctx->get_val( c_pay_screen ) IS INITIAL.
*         NOTHING CONFIGURED AND NOTHING CARRIED. Falls back to the
*         payment step's own screen, which is right wherever payment IS a
*         step of the journey - DOK and EPDA - and is what this did
*         before. On Municipality it is the screen that answers INITIAL
*         but has no CPG_1 row, so those journeys must configure the row.
          READ TABLE lo_pe->ms_config-steps INTO DATA(ls_pstp)
               INDEX lo_pe->mv_step + 1.
          IF sy-subrc = 0 AND ls_pstp-bknd_screen IS NOT INITIAL.
            io_ctx->set_val( iv_name  = c_pay_screen
                             iv_value = CONV string( ls_pstp-bknd_screen ) ).
            lo_pe->trace( |PAY     PAY_SCREEN was blank and unconfigured · derived | &&
                          |{ ls_pstp-bknd_screen } from the payment step's own BKND_SCREEN| ).
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

    CASE iv_event.
      WHEN c_pay_now.
*       PAY_STARTED first, BEFORE the commit. It used to be written after
*       OPEN_URL, which is too late for three separate reasons:
*         - ON_CUSTOM_VALIDATE cannot tell a payment commit from a submit, so it
*           refused the commit and payment could never start at all
*         - the footer's Pay button stayed live through a gateway preparation that
*           can take two minutes
*         - a citizen who pressed it twice got two case numbers
*
*       Cleared on every path below that does not reach the gateway, so a failed
*       attempt leaves the button live and the citizen able to try again.
        io_ctx->set_val( iv_name = c_pay_started iv_value = 'X' ).
        zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_start
                             iv_case   = io_ctx->get_val( c_pay_case )
                             iv_detail = |tries { io_ctx->get_val( c_pay_tries ) }| ).

*       START CLEAN. PAY_APPURL and PAY_REFERENCE are model members, so they live in
*       the draft and survive everything - a Back, a reload, a session picked up
*       tomorrow. A value left over from an earlier attempt is worse than useless
*       here: the poll's first test is whether PAY_APPURL is blank, so a stale one
*       sends it straight past the gateway wait and into POLL_STATUS, which finds no
*       transaction for this attempt and answers OPEN for ever. The symptom is a
*       spinner that never resolves and a read that is never made.
*
*       Cleared HERE rather than after a failure, because the failures that matter
*       are the ones nobody handled - a dump, a closed tab, a session that timed out
*       mid-gateway. Only the start of the next attempt is guaranteed to run.
        io_ctx->set_val( iv_name = 'PAY_APPURL'    iv_value = '' ).
        io_ctx->set_val( iv_name = 'PAY_REFERENCE' iv_value = '' ).
        io_ctx->set_val( iv_name = c_pay_tries     iv_value = '0' ).

*       COMMIT ON EVERY PRESS. Pressing Pay IS pressing Next internally: the
*       commit is what has the backend create the case, and the gateway has
*       nothing to bill against until it exists.
*
*       It used to run only while CASE_NUMBER was blank, which meant a press that
*       failed anywhere after the commit - no open item yet, a lock, a gateway that
*       never answered - could never re-post. The retry went straight to
*       PREPARE_PAYMENT( ) against a case the backend may not have finished, and
*       the citizen had no way to make the create happen again.
*
*       Re-posting is safe because the BAdI is the thing that decides: CREATE_CASE( )
*       is skipped when the case already exists, so a second commit updates rather
*       than duplicates. The duplicate-case loop this guard was written for was not
*       the BAdI creating a second case on purpose - it was the key changing
*       underneath it:
*
*         1  the BAdI overwrites the INTRENO_JOURNEY item with the new case id
*         2  the bridge returns that as EV_GUID, so GET_CASE( ) becomes the case id
*         3  the next post therefore sends INTRENO_JOURNEY = case id
*         4  MAPPER sets GV_GUID from it and RETRIVE_DATA reads the shared buffer
*            under that key - which is EMPTY, because GS_DATA was stored under the
*            old draft guid
*         5  IS_NEW and IS_UPDATE are both blank, so the abstract UPDATE calls
*            CREATE( ), GUID_CREATE makes a fresh draft, IS_NEW goes true,
*            GS_DATA-CASEID is blank - and CREATE_CASE makes another case
*
*       That is a backend key problem and it belongs on the backend side. Skipping
*       the commit hid it at the cost of a payment that could not be retried.
*
*       STATUS is what tells the BAdI what this post IS. MAPPER switches on it to
*       set GV_SAVE_DRAFT / GV_SUBMIT / GV_PAYMENT, and the D0xx UPDATE only
*       reaches CREATE_CASE( ) under WHEN GV_SAVE_DRAFT. COMMIT_STEP( ) posts no
*       status of its own - its own trace line says 'no STATUS' - so without this
*       the pay commit arrives with a full payload and no instruction: no case is
*       created, CASE_NUMBER stays blank, and PREPARE_PAYMENT( ) reports "no case
*       number, the commit did not reach the backend". It did reach it. It just
*       never said what it was for.
*
*       Written HERE rather than in each subclass. The seed comments on the
*       payment step's STATUS carrier already assume the base class does it, and a
*       payment journey that forgets fails in a way that looks like a backend
*       problem for as long as it takes somebody to think of the status item.
        io_ctx->set_val( iv_name = 'STATUS' iv_value = 'PAYMENT' ).

        DATA(lv_committed) = io_ctx->commit_step( ).

*       Cleared on BOTH paths. STATUS is an ordinary model member and rides the
*       draft, so left set it would travel on the next ordinary Next and have the
*       BAdI run the whole submit-and-pay branch for a plain step change.
        io_ctx->set_val( iv_name = 'STATUS' iv_value = '' ).

        IF lv_committed = abap_false.
          io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).
          RETURN.
        ENDIF.

*       INTRENO_JOURNEY IS THE CASE, IN EVERY SCENARIO.
*
*       That is the backend contract, stated by the people who own it, and the
*       engine already holds the value: the bridge reads INTRENO_JOURNEY off the
*       returned items and hands it back, and GET_CASE( ) is where it lands.
*
*       ZCL_RAK_QNV_BRIDGE->POST( ) only reports EV_CASE when the returned
*       INTRENO_JOURNEY DIFFERS from the one it was sent. On the press that creates
*       the case there is nothing to differ from, and on a backend that answers with
*       the key it was given there is no difference either - so EV_CASE stays blank,
*       TAKE_CASE( ) is never called, and CASE_NUMBER is empty on a journey that
*       demonstrably has a case. PREPARE_PAYMENT( ) then refuses on every poll while
*       the citizen watches a timer.
*
*       An earlier version of this adopted the key ONLY when it was all digits and
*       under 22 characters, on the theory that a GUID_22 draft key must never reach
*       RESOLVE_CASE( ). That test rejected the very value it was meant to pass and
*       the payment step stayed dead. The shape of the key is the backend's business,
*       not something to be second-guessed from here.
*
*       So: if CASE_NUMBER is blank, the journey key IS the case number. Guarded on
*       blank only, so every journey that already has one is untouched.
*
*       WATCH THIS ONE. If a draft GUID_22 ever does reach RESOLVE_CASE( ) it goes
*       into an SCMG_EXT_KEY comparison and raises CX_SY_OPEN_SQL_DATA_ERROR rather
*       than simply missing - mid-payment, with the gateway open in another tab. If
*       that appears, the answer is for the BACKEND to return the case in
*       INTRENO_JOURNEY on this post, not to put the guess back here.
*       RESOLVED, NOT ASSUMED. This wrote the journey key straight into
*       CASE_NUMBER, which is correct only while that key IS the case -
*       true on DOK and EPDA, false on Municipality, where it is the RE
*       object's INTRENO. CASE_NUMBER then held a value that no DFKKOP
*       row and no SCMG case would ever match, and every consumer
*       downstream inherited it.
*
*       Now the key goes through CASE_KEY_OF( ): converted when
*       VIBDCHARACT knows the case behind the INTRENO, and handed back
*       UNCHANGED otherwise - so on DOK and EPDA this still writes
*       exactly what GET_CASE( ) returned, and a Municipality journey
*       whose case is not linked yet still writes the key it used to.
*       The value is resolved again at every read, so a key written
*       before the link existed is not stuck with it.
        IF io_ctx->get_val( c_pay_case ) IS INITIAL.
          DATA(lv_key) = case_key_of( io_ctx = io_ctx
                                      iv_key = io_ctx->get_case( ) )-key.
          IF lv_key IS NOT INITIAL.
            io_ctx->set_val( iv_name = c_pay_case iv_value = lv_key ).
          ENDIF.
        ENDIF.

*       CASE_NUMBER is written by the ENGINE, in TAKE_CASE( ), from the bridge's
*       EV_CASE - not here. It used to be captured from GET_CASE( ) at this point,
*       which worked only while the backend was renaming the journey key. Now that
*       the key holds still, GET_CASE( ) is the DRAFT guid, and writing it here
*       overwrote the real case number the engine had just published.

        DATA(lo_pay) = pay_engine( io_ctx ).

*       Say which branch this request took. PAYNOW has four exits and three of
*       them look identical from the outside - a fast request and a message strip
*       - so a screenshot cannot tell them apart. That is how an empty red band
*       came to be diagnosed as a lock it was not.
*
*       Cast rather than an interface method: TRACE( ) is on the engine, not on
*       ZIF_RAK_JOURNEY, and widening the interface for a diagnostic is the wrong
*       trade. The catch matters - a test double passed as IO_CTX is not the
*       engine and must not be broken by instrumentation.
        DATA lo_eng TYPE REF TO zcl_rak_journey_engine.
        TRY.
            lo_eng = CAST #( io_ctx ).
          CATCH cx_sy_move_cast_error.
            CLEAR lo_eng.
        ENDTRY.
        IF lo_eng IS BOUND.
          lo_eng->trace( |PAY     press · case { io_ctx->get_val( c_pay_case ) }| ).
        ENDIF.

        DATA lt_lock TYPE bapiret2_t.
        DATA(lv_stop) = lo_pay->check_lock( IMPORTING et_messages = lt_lock ).
        IF lo_eng IS BOUND.
          lo_eng->trace( |PAY     check_lock stop={ lv_stop } · { lines( lt_lock ) } message(s)| ).
        ENDIF.
        IF lv_stop = abap_true.
          io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).

          DATA(lv_said) = abap_false.
          LOOP AT lt_lock INTO DATA(ls_lock).
*           Never render a blank. A BAPIRET2 row may carry its text as MESSAGE or
*           only as ID / NUMBER / MESSAGE_V1..4, and passing the first straight to
*           the strip draws an empty red band - refused, with the reason nowhere,
*           on a request the gate calls clean because nothing failed.
            DATA(lv_text) = CONV string( ls_lock-message ).
            IF lv_text IS INITIAL AND ls_lock-id IS NOT INITIAL.
              MESSAGE ID ls_lock-id TYPE 'E' NUMBER ls_lock-number
                WITH ls_lock-message_v1 ls_lock-message_v2
                     ls_lock-message_v3 ls_lock-message_v4
                INTO lv_text.
            ENDIF.
            IF lv_text IS NOT INITIAL.
              io_ctx->add_msg( iv_type = 'Error' iv_text = lv_text ).
              lv_said = abap_true.
            ENDIF.
          ENDLOOP.

          IF lv_said = abap_false.
            io_ctx->add_msg( iv_type = 'Error'
              iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_inprog
                            iv_default = `A payment is already in progress for this `
                                      && `application. Please wait a few minutes and try again.` ) ).
          ENDIF.
          zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_block
                               iv_result = 'BLOCK'
                               iv_detail = `INPROG` ).
          RETURN.
        ENDIF.

        prepare_payment( io_ctx = io_ctx iv_quiet = abap_true ).
        DATA(lv_url) = build_pay_url( io_ctx ).
        IF lo_eng IS BOUND.
          lo_eng->trace( COND string( WHEN lv_url IS NOT INITIAL
                                      THEN |PAY     gateway url resolved|
                                      ELSE |PAY     no gateway url yet - poll will ask again| ) ).
        ENDIF.
        IF lv_url IS INITIAL.
*         NOT a failure, and this is the change that matters. The case was created a
*         moment ago by COMMIT_STEP( ) above, and the open item the gateway bills
*         against is raised from a LATER update task with an SD sales order behind
*         it. Asking for a gateway address in the same breath as creating the case is
*         simply too early - the first attempt finding nothing is normal.
*
*         This was hidden until now by a different bug: every press created a NEW
*         case, so by the time the citizen pressed again the open item from the
*         PREVIOUS one had appeared and the read succeeded. One case per journey
*         removed the accidental delay along with the duplicate.
*
*         So leave PAY_STARTED set - the poll timer draws while it is - and let the
*         poll ask again. Nothing blocks a work process, which is the whole reason
*         this is not the legacy WAIT loop.
          io_ctx->set_val( iv_name = c_pay_tries iv_value = '0' ).
          io_ctx->add_msg( iv_type = 'Information'
                           iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_prep
                                         iv_default = `Preparing your payment. This takes a few seconds.` ) ).
          RETURN.
        ENDIF.

        io_ctx->open_url( lv_url ).
      WHEN c_pay_open.
*       Reopen only. The payment exists, its reference exists, and the gateway is
*       holding it - the citizen simply lost the window. Going back through
*       c_pay_now would call the payment screen's BAdI again, which writes a fresh
*       ZETISLAT_TRANSAC row and draws a new reference number: two payments open
*       for one fee, and the lock refusing whichever arrives second.
        DATA(lv_open) = io_ctx->get_val( 'PAY_APPURL' ).
        IF lv_open IS INITIAL.
          io_ctx->add_msg( iv_type = 'Warning'
            iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_prep_wait
                          iv_default = `The payment page is still being prepared. One moment.` ) ).
          RETURN.
        ENDIF.
        io_ctx->open_url( lv_open ).

      WHEN c_pay_stop.
*       Clears the waiting state only. The payment itself is untouched - it may
*       still complete at the gateway, and the poll will pick it up when the
*       citizen presses Pay again or reopens the case from the dashboard.
        io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).
        io_ctx->set_val( iv_name = c_pay_tries   iv_value = '0' ).
        io_ctx->add_msg( iv_type = 'Information'
          iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_stopped
                        iv_default = `Stopped waiting. If you completed the payment it will `
                                  && `still be recorded - reopen this application to check.` ) ).
        zcl_rak_cj_evt=>add(
          iv_type     = zcl_rak_cj_evt=>c_type-pay_stop
          iv_case     = io_ctx->get_val( c_pay_case )
          iv_result   = 'TIMEOUT'
          iv_duration = CONV i( io_ctx->get_val( c_pay_tries ) ) * 2500 ).

      WHEN c_pay_poll.
*       The poll has TWO jobs, in order.
*
*       Before the gateway address exists it is what waits for the open item - a new
*       round trip per tick, so the LUW closes between attempts and the update task's
*       row becomes visible. That is the same reason the legacy code used WAIT; the
*       difference is that this holds no work process while it waits.
        IF io_ctx->get_val( 'PAY_APPURL' ) IS INITIAL.
          DATA lv_try TYPE i.
          DATA(lv_seen) = io_ctx->get_val( c_pay_tries ).
          IF lv_seen IS NOT INITIAL AND lv_seen CO '0123456789'.
            lv_try = lv_seen.
          ENDIF.
          lv_try = lv_try + 1.
          io_ctx->set_val( iv_name = c_pay_tries iv_value = |{ lv_try }| ).

          DATA(lv_last) = xsdbool( lv_try >= c_pay_max_try ).

*         WHICH TICK THIS IS. The waiting card looks identical on tick 1
*         and tick 47, and until now so did the trace - so there was no
*         way to tell a poll that is still early from one about to give
*         up, or to tell that the poll was running at all.
          pay_trace( io_ctx  = io_ctx
                     iv_text = |PAY     poll tick { lv_try } of { c_pay_max_try }| ).

          prepare_payment( io_ctx   = io_ctx
                           iv_quiet = xsdbool( lv_last = abap_false ) ).

          DATA(lv_now) = build_pay_url( io_ctx ).
          IF lv_now IS NOT INITIAL.
            pay_trace( io_ctx  = io_ctx
                       iv_text = |PAY     poll opening gateway on tick { lv_try }| ).
            io_ctx->open_url( lv_now ).
            RETURN.
          ENDIF.

*         Given up. PAY_STARTED is cleared so the button comes back live - by the
*         time a citizen reads the message and presses again, the open item has
*         usually arrived.
          IF lv_last = abap_true.
            io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).
            io_ctx->set_val( iv_name = c_pay_tries   iv_value = '0' ).
            io_ctx->add_msg( iv_type = 'Error'
                             iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_prep_fail
                                           iv_default = `The payment could not be prepared. Press Pay to try again.` ) ).
          ENDIF.
          zcl_rak_cj_evt=>add( iv_type   = zcl_rak_cj_evt=>c_type-pay_block
                               iv_result = 'BLOCK'
                               iv_detail = `PREPFAIL` ).
          RETURN.
        ENDIF.

*       And once it exists, it is the payment status poll it always was.
*       Keep counting once the gateway address exists. PAY_TRIES was only ever
*       incremented while waiting for the address, so after that the elapsed clock
*       on the waiting screen sat at 0:00 for the whole payment. C_PAY_MAX_TRY
*       gates the branch above only, so nothing else reads this.
        DATA lv_tick TYPE i.
        DATA(lv_seen2) = io_ctx->get_val( c_pay_tries ).
        IF lv_seen2 IS NOT INITIAL AND lv_seen2 CO '0123456789'.
          lv_tick = lv_seen2.
        ENDIF.
        io_ctx->set_val( iv_name = c_pay_tries iv_value = |{ lv_tick + 1 }| ).

        DATA(lo_poll) = pay_engine( io_ctx ).
*       Same reason as pay_engine( ): the poll resolves by CASE. Passing the journey
*       key sent a GUID_22 into key comparisons and dumped the app mid-payment, with
*       the gateway already open in another tab.
*       IV_LAUNCHED is abap_true because this branch is only reached once
*       PAY_APPURL is filled, which means a gateway really was resolved and opened
*       for this attempt. It is read ONLY by the dev short circuit in POLL_STATUS;
*       on E20 / E30 it is ignored and the ATB / ZREAD_PAY_STATUS_DEST path runs
*       exactly as before.
        CASE lo_poll->poll_status( iv_intreno  = io_ctx->get_val( c_pay_case )
                                   iv_launched = abap_true ).
          WHEN zcl_rak_pay_engine=>c_success.
            IF io_ctx->get_val( c_pay_field ) = 'PAID'.
              RETURN.
            ENDIF.
            io_ctx->set_val( iv_name = c_pay_field   iv_value = 'PAID' ).
            io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).
            io_ctx->add_msg( iv_type = 'Success'
                             iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_received
                                           iv_default = `Payment received` ) ).
            zcl_rak_cj_evt=>add(
              iv_type     = zcl_rak_cj_evt=>c_type-pay_done
              iv_case     = io_ctx->get_val( c_pay_case )
              iv_result   = 'OK'
              iv_duration = CONV i( io_ctx->get_val( c_pay_tries ) ) * 2500 ).

*           Move on. Payment is the only event in a journey that completes without
*           the citizen pressing anything, so leaving them on a paid fee card with a
*           Next button asks them to acknowledge something that has already
*           happened - and on the tick that flips to PAID the poll timer stops
*           drawing, so nothing else would move the page either.
*
*           ADVANCE_STEP( ) rather than setting the step: it issues the next step's
*           BACKEND_READ( ) and ON_AFTER_READ( ), which is what fills the
*           confirmation fields. Setting MV_STEP alone would draw a confirmation
*           screen with blank lines on it. It also stops of its own accord on the
*           last step, so a journey whose fee card IS the last step is unaffected.
            io_ctx->advance_step( ).
          WHEN zcl_rak_pay_engine=>c_failed.
            io_ctx->set_val( iv_name = c_pay_started iv_value = '' ).
            io_ctx->add_msg( iv_type = 'Error'
                             iv_text = zcl_rak_text=>get( iv_no      = zcl_rak_text=>c_no-pay_notdone
                                           iv_default = `Payment was not completed. You can try again.` ) ).
            zcl_rak_cj_evt=>add(
              iv_type     = zcl_rak_cj_evt=>c_type-pay_fail
              iv_case     = io_ctx->get_val( c_pay_case )
              iv_result   = 'FAIL'
              iv_duration = CONV i( io_ctx->get_val( c_pay_tries ) ) * 2500 ).
          WHEN OTHERS.
        ENDCASE.
    ENDCASE.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_after_field.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_before_field.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_end.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_popup.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_render_start.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_save.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_search.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_submit.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_value_help.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~render_field.
    rv_done = abap_false.
    CHECK to_upper( is_field-name ) = c_pay_field.

    DATA lt_fee   TYPE zcl_rak_pay_engine=>tt_fee.
    DATA lv_total TYPE kbetr.
    DATA(ls_be) = io_ctx->get_backend_table( c_pay_field ).
    LOOP AT ls_be-rows INTO DATA(lt_row).
      DATA(lv_desc) = VALUE string( lt_row[ 1 ] OPTIONAL ).
      DATA(lv_amt)  = VALUE string( lt_row[ 2 ] OPTIONAL ).
      CONDENSE lv_desc.
      CONDENSE lv_amt.
      IF lv_desc IS INITIAL AND lv_amt IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA lv_k TYPE kbetr.
      CLEAR lv_k.
      TRY.
          DATA(lv_num) = lv_amt.
          REPLACE ALL OCCURRENCES OF ',' IN lv_num WITH ``.
          lv_k = CONV kbetr( lv_num ).
        CATCH cx_root.
          CLEAR lv_k.
      ENDTRY.
      APPEND VALUE #( desc = lv_desc amount = lv_k ) TO lt_fee.
    ENDLOOP.

    DATA(lv_tot_raw) = io_ctx->get_val( c_pay_total ).
    CONDENSE lv_tot_raw.
    IF lv_tot_raw IS NOT INITIAL.
      TRY.
          REPLACE ALL OCCURRENCES OF ',' IN lv_tot_raw WITH ``.
          lv_total = CONV kbetr( lv_tot_raw ).
        CATCH cx_root.
          CLEAR lv_total.
      ENDTRY.
    ELSEIF lt_fee IS NOT INITIAL.
*     Before the citizen presses Pay, PAY_TOTAL is legitimately empty: it is
*     written by prepare_payment( ) from DFKKOP-BETRH, which is what the gateway
*     bills, and that row does not exist until the case does. Summing the
*     displayed rows is the honest stand-in - same amount, different source - and
*     it is far better than showing 0.00 beside a fee list that plainly is not
*     zero, which is what the card did before.
      LOOP AT lt_fee INTO DATA(ls_sum).
        lv_total = lv_total + ls_sum-amount.
      ENDLOOP.
    ENDIF.

    IF lt_fee IS INITIAL.
      pay_engine( io_ctx )->get_fees(
        IMPORTING et_fee = lt_fee ev_total = lv_total ).
      IF lt_fee IS NOT INITIAL.
        io_ctx->add_msg( iv_type = 'Information'
                         iv_text = 'Fees were read directly rather than supplied by the backend. ' &&
                                   'Configure a /QNV/SB_UI_DEFIN row for PAYFEE.' ).
      ENDIF.
    ENDIF.

    pay_render(
      io_ctx   = io_ctx
      io_view  = io_form
      iv_field = c_pay_field
      it_fee   = lt_fee
      iv_total = lv_total
      iv_poll  = xsdbool( io_ctx->get_val( c_pay_started ) = 'X'
                          AND io_ctx->get_val( c_pay_field ) <> 'PAID' ) ).

    rv_done = abap_true.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~retention.
  ENDMETHOD.


  METHOD zif_rak_journey_logic~wants_feedback.
    rv = abap_true.
  ENDMETHOD.
ENDCLASS.
