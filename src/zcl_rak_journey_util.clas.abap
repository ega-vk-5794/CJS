CLASS zcl_rak_journey_util DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
*   Stateless helpers lifted out of ZCL_RAK_JOURNEY_ENGINE. Every method here
*   was verified to touch no engine attribute, which is why they are static and
*   why this class carries no reference back to the engine. Anything that needs
*   engine state does NOT belong here.

    CLASS-METHODS esc IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS esc_js IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS to_dats IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.

*   A DATE IN THE FORMAT SAP.M.DATEPICKER WAS TOLD TO EXPECT.
*
*   The picker is rendered with VALUEFORMAT = 'yyyy-MM-dd', which is a
*   statement about the MODEL value, not the display. A backend that
*   answers a DATS - 20260926, which is what the D0xx BAdI returns -
*   hands UI5 a string it cannot parse against that format, and the
*   citizen gets ".0..0.26.." in the field: the display format applied to
*   a value the parser gave up on. Nothing errors and the date looks
*   corrupted rather than unparsed.
*
*   TO_DATS( ) IS THE PARSER, this is only the formatter, so the two
*   directions cannot disagree about what a date looks like. Anything
*   TO_DATS( ) accepts - DATS, ISO, dd.mm.yyyy, dd/mm/yyyy, dd-mm-yyyy -
*   comes back as ISO.
*
*   AN UNPARSEABLE VALUE IS RETURNED UNCHANGED, never blanked. A date the
*   framework does not recognise is still the citizen's data and still
*   worth showing them; erasing it would lose a value on a resumed case
*   and look like the backend returned nothing.
    CLASS-METHODS ui_date IMPORTING iv TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS opt_text
      IMPORTING iv_key    TYPE string
                iv_text   TYPE string
      RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS is_block    IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS is_scratch  IMPORTING iv_name TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS known_type  IMPORTING iv_type TYPE string RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS open_url_html IMPORTING iv_url TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS att_url IMPORTING iv_guid TYPE string RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS row_key     IMPORTING is_field TYPE zif_rak_journey=>ty_field RETURNING VALUE(rv) TYPE string.
    CLASS-METHODS ctrl_width IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rv) TYPE string.

*   The AUTHORED width alone - blank when the field carries none, and blank
*   when what it carries is not a unit that survives a phone. Separate from
*   CTRL_WIDTH( ) because two callers need to tell an authored width from a
*   type default: CTRL_WIDTH( ) to return it instead of the CASE, and
*   ZCL_RAK_JOURNEY_RENDER to stop the laid-out cell's 100% overwriting it.
*   Reading ZRAK_T_JNY_FLD-CTRL_WIDTH directly in the renderer would get the
*   second one wrong, because a REJECTED value is not initial and would
*   suppress the 100% while contributing nothing in its place.
    CLASS-METHODS cfg_width  IMPORTING is_field  TYPE zif_rak_journey=>ty_field
                       RETURNING VALUE(rv) TYPE string.

*   The one width validator. A CSS length CJS is willing to put in the markup,
*   or blank - % and rem only, number required. A hard px width does not
*   collapse on a phone and is the single way a config value can break the
*   responsive layout, so it is refused wherever a width can be authored.
*   CFG_WIDTH( ) and COL_SPEC( ) both come through here so the two cannot
*   drift into accepting different things.
    CLASS-METHODS css_width IMPORTING iv_value  TYPE string
                       RETURNING VALUE(rv) TYPE string.

*   The one alignment validator, and the twin of CSS_WIDTH( ) above - same
*   rule, same reason. sap.m.Column's HALIGN takes Begin, End, Center, Left,
*   Right and Initial; anything else the browser drops without a word, and a
*   value that vanishes silently looks exactly like one that never arrived.
*   Blank out means no HALIGN, which is what every table renders today.
    CLASS-METHODS css_align IMPORTING iv_value  TYPE string
                       RETURNING VALUE(rv) TYPE string.

*   ============ NOT WIRED. READ THIS BEFORE CONNECTING IT. ==============
*   This was written for R13-6 and passed to DATE_PICKER( )'s MINDATE and
*   MAXDATE. It broke every journey that has a DATE field.
*
*   sap.m.DatePicker types MINDATE and MAXDATE as OBJECT - a JavaScript
*   Date - not as a string. An XML view parses an object-typed attribute as
*   JSON, and 2026-12-31 is not JSON:
*
*       SyntaxError: Unexpected non-whitespace character after JSON at
*       position 4
*
*   and it is fatal to the WHOLE VIEW. Not the field, not the step - the
*   journey does not render.
*
*   THE SECOND MISTAKE MATTERED MORE. The change was argued as "additive by
*   construction, because MIN_VAL and MAX_VAL are blank on every DATE
*   field" - and that was never checked. ZTEST_ALL carries both on
*   BIRTH_DATE, which is how it broke on the first journey anyone opened.
*   An additive-by-construction claim resting on an unverified SELECT is
*   not an argument.
*
*   Kept rather than deleted because the parsing is right and the next
*   attempt will want it: a real bound needs a BINDING or a
*   follow_up_action( ) setting the property from JavaScript after render,
*   which is a different mechanism. Do not pass it as an attribute again.
*   ======================================================================
*
*   A DATE BOUND FOR sap.m.DatePicker's MINDATE / MAXDATE, from what an
*   author wrote in MIN_VAL or MAX_VAL.
*
*   Those two columns are CHAR(20) on ZRAK_T_JNY_FLD and are read for NUMBER
*   ranges today. On a DATE field they are blank on every journey, so reading
*   them as a date bound is additive by construction - nothing that exists
*   moves.
*
*   WHAT IT ACCEPTS
*       20270101        a literal, yyyymmdd
*       2027-01-01      a literal, already in the picker's own format
*       TODAY           the relative case that actually recurs
*       TODAY-18Y       an age floor
*       TODAY+30D       a window that closes
*       TODAY-1Y
*
*   Only D and Y follow the sign. Months are deliberately NOT supported:
*   "one month before the 31st" has no single right answer and a bound that
*   is quietly wrong on five days of the month is worse than one an author
*   has to write as days. An unrecognised value is REFUSED - blank out, no
*   MINDATE, which is exactly how every date field renders today. Same
*   discipline as CSS_WIDTH( ) and CSS_ALIGN( ): a value the control would
*   drop silently must not be emitted, because a bound that vanishes looks
*   identical to one that never arrived.
*
*   RETURNS yyyy-MM-dd, matching the VALUEFORMAT the DATE branch already
*   passes. The two must agree or the picker parses the bound in one format
*   and the value in another.
*
*   IT IS A CONVENIENCE, NOT A CONTROL. A greyed-out calendar day stops the
*   click; it does not stop a value arriving by any other route, so the
*   handler's own check stays the thing that actually refuses. This exists so
*   the citizen is not offered a date that will be rejected after they have
*   filled in the rest of the step.
    CLASS-METHODS date_bound IMPORTING iv_value  TYPE string
                       RETURNING VALUE(rv) TYPE string.

*   THE ROW-PICK SPEC, and the ONE place DEFAULT_VAL is split for it.
*   'SEL_GUID', 'SEL_GUID|View' and 'SEL_GUID|View|<ar>' all answer target
*   SEL_GUID; the second and third also answer the button's own caption.
*
*   It exists because the split was written twice and only once: the renderer
*   captioned the button from the tail and the engine's ROWPICK_ branch went
*   on treating the WHOLE string as the target field name, so the pick wrote
*   the row key into a field called 'SEL_GUID|View|<ar>' - VAL_SET( ) to a name
*   the model does not have is silent, ON_CHANGE( ) matched nothing, and the
*   button rendered perfectly and did nothing. Both callers come here now. Any
*   third one must too.
    CLASS-METHODS pick_spec IMPORTING iv_default TYPE string
                       EXPORTING ev_target  TYPE string
                                 ev_text_en TYPE string
                                 ev_text_ar TYPE string.

*   A TABLE column header, and the optional width after it: 'Case No.|14rem'.
*   Same separator as PICK_SPEC( ) and the same rule - one place, both readers.
*
*   Only GET_TABLE( ) can reach it. A table whose columns come from the
*   KEY:Label:TYPE spec in DEFAULT_VAL cannot: '|' separates the COLUMNS there,
*   so a header in that spec can never contain one. That is deliberate -
*   DEFAULT_VAL already has four readings and this would have been a fifth.
    CLASS-METHODS col_spec IMPORTING iv_col   TYPE string
                       EXPORTING ev_text  TYPE string
                                 ev_width TYPE string
*                                A THIRD PART ON THE SAME SEPARATOR:
*                                'Judgment Date|13%|End'. A sap.m.Column is
*                                flush left when nobody says otherwise, so a
*                                column of dates does not share an edge and a
*                                count of days reads as prose.
*
*                                Validated like the width and for the same
*                                reason - sap.m.Column takes Begin, End,
*                                Center, Left, Right and Initial, and anything
*                                else the browser drops without a word, which
*                                looks exactly like the alignment never
*                                arriving. See CSS_ALIGN( ).
                                 ev_align TYPE string
*                                R18-3. A FOURTH PART, and it is a comma
*                                separated list of KEYWORDS rather than one
*                                more positional value:
*                                'Filed|13%|End|SORT=ASC,RICH'.
*
*                                Positional ran out of room. The sap.m.Column
*                                properties the z2ui5 wrapper exposes and CJS
*                                was not passing are not one more thing, they
*                                are several, and a fifth and a sixth bar
*                                would make every spec count separators to
*                                read - which is how a width lands in the
*                                alignment.
*
*                                Returned RAW and upper-cased; COL_FLAG( )
*                                reads one keyword out of it. Blank for every
*                                column authored before this, which is all of
*                                them.
                                 ev_flags TYPE string.

*   One keyword out of the flags part of a column spec. 'X' for a keyword that
*   stands on its own ('RICH'), and the text after the '=' for one that carries
*   a value ('SORT=ASC' answers 'ASC'). Blank when absent, so every reader gets
*   "nothing was authored" for free and renders as it does today.
    CLASS-METHODS col_flag IMPORTING iv_flags  TYPE string
                                     iv_key    TYPE string
                           RETURNING VALUE(rv) TYPE string.

*   sap.ui.core.SortOrder, validated the way CSS_ALIGN( ) validates HALIGN and
*   for the same reason - an unknown value is dropped by the browser without a
*   word, which looks exactly like the property never arriving. ASC/ASCENDING
*   and DESC/DESCENDING are both taken, because a column spec is typed by hand.
    CLASS-METHODS css_sort IMPORTING iv_value  TYPE string
                           RETURNING VALUE(rv) TYPE string.

*   Language fallback (Arabic when IV_LANG = 'A' and the Arabic text is
*   filled, English otherwise) plus OTR:<alias> resolution, lifted out of
*   ZCL_RAK_JOURNEY_REPO~PICK( ) so a bilingual pair that never passes
*   through REPO - ZRAK_T_JNY_COL's ZLABEL/ZLABEL_AR, read directly by
*   ZCL_RAK_JOURNEY_GRID - can still resolve an OTR alias instead of being
*   frozen at whatever was last typed into the Studio. PICK( ) itself now
*   delegates here rather than duplicating the logic.
    CLASS-METHODS pick_text
      IMPORTING iv_en     TYPE clike
                iv_ar     TYPE clike
                iv_lang   TYPE sy-langu
      RETURNING VALUE(rv) TYPE string.

*   OTR:<alias> resolution on its own, lifted out of PICK_TEXT( ) so a text
*   that has already been picked EN/AR - one clause of a per-check MSG, below -
*   can still resolve an alias without going back through a bilingual pair it
*   no longer has. PICK_TEXT( ) calls this rather than keeping a second copy.
*   A missing concept returns the stored literal, prefix and all, so a wrong
*   alias is a visible "OTR:..." on screen rather than a blank nobody can
*   explain.
    CLASS-METHODS otr_text
      IMPORTING VALUE(iv_text) TYPE string
                VALUE(iv_lang) TYPE sy-langu
      RETURNING VALUE(rv)      TYPE string.

*   ONE MESSAGE COLUMN, SEVERAL CHECKS - and now a wording for each.
*
*   ZRAK_T_JNY_FLD-MSG / MSG_AR is read as the message for MISSING_REQUIRED,
*   for MIN_VAL / MAX_VAL, for the numeric CATCH and for REGEX. The checks
*   never fire together - required needs a BLANK value and the rest need a
*   filled one - so this was never a functional bug, only a wording one: a
*   field that is both REQUIRED and format-constrained had one column and two
*   sentences to write in it. Whichever wording went in, the other check
*   borrowed it and said the wrong thing.
*
*   MSG may therefore now carry per-check clauses:
*
*     REQUIRED:Please state the number of wives;FORMAT:@201
*
*   Recognised keys: REQUIRED, LEN, RANGE, NUMBER, FORMAT, and '*' as a
*   catch-all for any check with no clause of its own. Clauses are separated by
*   ';' and each is KEY:text, split on its FIRST colon - so a clause's text may
*   itself be 'OTR:<alias>' or '@nnn', the ZRAK_T_CJ_TXT reference a TABLE
*   column header already takes (COL_HEADER( )). Both resolve per round trip and
*   per language, which is what lets a migrated WD message keep its own OTR
*   concept on the FORMAT check while REQUIRED keeps its own words.
*
*   ADDITIVE, AND THE GUARD IS DELIBERATELY NARROW. The keyed form is only
*   recognised when the text BEGINS with one of those keys immediately followed
*   by ':'. Anything else - every MSG configured today, an OTR: alias on the
*   whole column, an ordinary sentence containing a colon or a semicolon - is
*   returned unchanged to every check that reads MSG today, so a journey that
*   sets nothing new sees no change at all.
*
*   IV_KEYED_ONLY is for the checks that do NOT read MSG today (MIN_LEN /
*   MAX_LEN). There, a plain MSG must keep being ignored - honouring it would
*   silently retitle every existing length message - but an explicit 'LEN:'
*   clause is a new instruction and is honoured. A blank return means "nothing
*   configured for this check": the caller falls back to the catalogue exactly
*   as it does today.
*   ONE DIRECTIVE OUT OF A DIRECTIVE-BEARING COLUMN.
*
*   DEFAULT_VAL on an UPLOAD already carried DTYPE:; it now also carries
*   FNAME:, and both are read through here rather than by two substring( )
*   calls written a year apart. That is the PICK_SPEC( ) lesson: a column
*   two things read is a column two things must read the SAME WAY, and the
*   method exists before the second reader rather than after it.
*
*   THE SHAPE IS MSG's, deliberately - semicolon-separated KEY:value
*   clauses, each split on its FIRST colon so the value may itself contain
*   one. A single unkeyed value is not a clause and returns blank, so a
*   DEFAULT_VAL holding an ordinary default is untouched.
*
*   Backward compatible by construction: DTYPE:1 on its own is one clause
*   with key DTYPE, which is exactly what the old parse returned.
    CLASS-METHODS directive
      IMPORTING VALUE(iv_spec) TYPE string
                VALUE(iv_key)  TYPE string
      RETURNING VALUE(rv)      TYPE string.

    CLASS-METHODS msg_for
      IMPORTING VALUE(iv_msg)        TYPE string
                VALUE(iv_check)      TYPE string
                VALUE(iv_journey)    TYPE string    OPTIONAL
                VALUE(iv_lang)       TYPE sy-langu  OPTIONAL
                VALUE(iv_keyed_only) TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv)            TYPE string.

*   A field name, made safe to be an ABAP structure component: upper case, only
*   letters digits and underscore, never longer than 23 (so BUILD_MODEL( )'s
*   companions - _VS, _VST, _IDTYPE, _NAME, _IX, _EXP - all still fit inside the
*   30-character cap). Same algorithm as ZCL_RAK_BE_NOT~MODEL_NAME( ), which
*   exists for the same reason on Notary's own dynamic business-object fields -
*   copied rather than shared, so a change here cannot regress that already-
*   proven path. BUILD_MODEL( ) builds one ABAP component per configured field
*   name; a field named with a character outside [A-Z0-9_], or one over 30
*   characters once its companions are appended, raises CX_SY_STRUCT_COMP_NAME
*   uncaught - the whole Studio preview or app dies with "UNCAUGHT EXCEPTION -
*   Please Restart App" for every journey, not only the one field at fault.
*   VALUE( ), not plain IMPORTING. A method's IMPORTING parameter is passed BY
*   REFERENCE by default, and by reference demands type COMPATIBILITY - so a
*   DDIC character field (ZRAK_T_JNY_COL-COL_NAME, ZRAK_T_JNY_FLD-NAME, and
*   every other config column this is called with) cannot be handed to a TYPE
*   string parameter at all: "is not type-compatible with formal parameter".
*   VALUE( ) passes by value, which converts.
    CLASS-METHODS comp_name IMPORTING VALUE(iv_key) TYPE string
                             RETURNING VALUE(rv)     TYPE string.

*   The country list, keyed by T005T-LAND1 and texted in the logon language.
*
*   ONE source, because a nationality has to survive three hops that were each
*   using a different vocabulary: the dropdown the citizen picks from, the value
*   ZFE_CJ_SEARCH_BP_BY_ID fills in after a BP search, and whatever is written to
*   the owner row and posted. D001 hand-maintained 106 items keyed '1' to '106'
*   while the BP search wrote the nationality TEXT into the same field - so the
*   key never matched, the combobox rendered unselected, and the column saved
*   blank. United Arab Emirates was not in the hand-written list at all.
*
*   LAND1 is the key that makes the three agree: it is what T005T is keyed on and
*   what ZFE_CJ_SEARCH_BP_BY_ID returns as EV_NATIONALITY_KEY (BU_NATIO).
*
*   Lifted from ZCL_RAK_BP_POPUP->NATIONALITIES( ), which now delegates here
*   rather than holding a second copy - the same move PICK_TEXT( ) made.
    CLASS-METHODS nationalities
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_option.

*   Addressing a grid row by COLUMN NAME instead of by position.
*
*   Every handler that maintains a grid from a popup has written its row as a run
*   of APPENDs in a fixed order, and every one of them has been wrong, because the
*   row's real width is ZRAK_T_JNY_COL - or, with no rows there, the DEFAULT_VAL
*   spec - and not the length of that run. SET_GRID_DATA( ) walks the CONFIGURED
*   columns and takes cell N from the row, so a run longer or shorter than the
*   spec puts every value in a neighbour's column and drops the tail.
*
*   It is close to invisible, which is why it survived: the hand-drawn list reads
*   the same positions back, so the screen looks right, and only the POST - which
*   reads the columns by NAME - sees the shift. D004 stored the owner's Emirates
*   ID in SHARE_PER that way, and the backend refused the step with "The Total of
*   the Share (0.00%) is not equal to 100%" while the list showed 100.
*
*   Here rather than in ZCL_RAK_JOURNEY_LOGIC so a handler can use it without a
*   redefinition, and so the grid renderer can use it too.
    CLASS-METHODS col_ix
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
                iv_name   TYPE string
      RETURNING VALUE(rv) TYPE i.

    CLASS-METHODS cell_of
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
                it_row    TYPE zif_rak_journey=>tt_string
                iv_name   TYPE string
      RETURNING VALUE(rv) TYPE string.

    CLASS-METHODS put_cell
      IMPORTING it_cols TYPE zif_rak_journey=>tt_string
                iv_name TYPE string
                iv_val  TYPE string
      CHANGING  ct_row  TYPE zif_rak_journey=>tt_string.

*   A row sized to the spec, every cell blank. Start here, then PUT_CELL( ) by
*   name - never APPEND, which is what shifts the neighbours.
    CLASS-METHODS blank_row
      IMPORTING it_cols   TYPE zif_rak_journey=>tt_string
      RETURNING VALUE(rt) TYPE zif_rak_journey=>tt_string.

*   ==== WHICH SYSTEM IS THIS, AND WHAT MAY IT DO =========================
*   ONE PLACE TO ASK, because four places asking it four ways is how the
*   answers drifted. Before this, the same question was written as
*   `= 'E10'`, `<> 'E30'`, `<> c_dev_sysid` and `= 'E10' AND mandt = '200'`
*   in five different classes - and two of those spellings quietly let a
*   development stub run in staging.
*
*   The system ids are RAK's: E10 development, E20 quality, E30
*   production. A system this does not recognise is treated as
*   PRODUCTION, which is the safe direction to be wrong in: a new or
*   renamed system gets the strictest behaviour until somebody adds it
*   here deliberately, rather than inheriting a developer's conveniences
*   by accident.
    CLASS-METHODS is_dev  RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS is_qa   RETURNING VALUE(rv) TYPE abap_bool.
    CLASS-METHODS is_prod RETURNING VALUE(rv) TYPE abap_bool.

*   ---- THE NAMED-USER OVERRIDE: CONFIGURATION ONLY ---------------------
*   The framework owner may manage CONFIGURATION on every system while
*   the framework is being finished - the Studio opens in EDIT mode and
*   &trace=x prints. Requested, removed at go-live readiness, and
*   requested again for a further period; C_ON below is the switch.
*
*   IT IS THE ONE THING IN THIS MATRIX NOT DERIVED FROM SY-SYSID, so
*   what it does and does not reach is worth stating exactly:
*
*     LIFTS  STUDIO_MODE( )  -> EDIT, so this user can save and delete
*                               the live configuration of citizen-facing
*                               services, E30 included.
*            TRACE_OK( )     -> &trace=x prints, which carries partner
*                               numbers, case ids and backend payloads.
*            AUTH_OK( )      -> satisfied without S_DEVELOP, or the
*                               Studio would open in EDIT mode and then
*                               refuse every save - buttons that work
*                               and an action that does not.
*
*     DOES NOT LIFT  DEV_STUBS_OK( ). Identity stays derived from
*            SY-SYSID for everyone, with no exception. Configuration
*            work does not need to impersonate a citizen, and the stubs
*            are what would let a request be posted on production under
*            a partner the session never authenticated. See that method.
*
*   THE OTHER BYPASS IS NOT COMING BACK WITH IT. AUTH_OK( ) used to
*   carry LV_BYPASS as well, which once returned true to everybody. That
*   was removed in the same commit as this and stays removed: this
*   grants ONE named person configuration access, which is a different
*   thing from leaving the authority check switchable.
*
*   A HARDCODED NAME IS THE WEAKEST FORM OF THIS and this is now the
*   second time it has gone in. It is readable by anyone with the
*   repository, it travels through the transport to every system, and
*   withdrawing it needs a code change and an activation - so Basis
*   cannot revoke it the way they revoke a role. The churn is itself the
*   argument: the Z_RAK_CJS SU21 object AUTH_OK( ) already describes
*   would have made both removals and both restorations an SU01 change
*   with no transport and no commit.
    CLASS-METHODS power_user RETURNING VALUE(rv) TYPE abap_bool.

*   MAY A DEVELOPMENT STUB STAND IN FOR A REAL VALUE. Development only,
*   and this is the one that matters most.
*
*   A stub is anything that invents an identity the citizen did not supply:
*   the simulated HISHAM.M session, the &loginbp= URL override, the dev BP
*   the bridge puts in PARAM3, ZCL_RAK_BE_NOT's MC_DEV_BP. Every one of
*   them exists so a developer can walk a journey without a portal login,
*   and every one of them files a real request under a partner nobody
*   chose if it runs anywhere else.
*
*   It is NOT about ZRAK_T_JNY_FLD-DEFAULT_VAL. A business default - the
*   Entity a form opens on, a consent paragraph, the three payment
*   carriers - is configuration the department authored and must apply on
*   every system. Suppressing those in production would break payment
*   routing on the system where it matters most. The distinction is
*   "invented identity" versus "authored value", and only the first is
*   gated here.
*
*   WHEN THIS RETURNS FALSE, THE CALLER MUST FAIL LOUDLY. Refusing a stub
*   and then carrying on with a blank partner is worse than the stub was:
*   it posts an anonymous request instead of a mislabelled one. Say the
*   citizen could not be identified and stop.
    CLASS-METHODS dev_stubs_ok RETURNING VALUE(rv) TYPE abap_bool.

*   MAY &trace=x PRINT. Development and quality only. The trace carries
*   partner numbers, case ids, backend payloads and the BAdI's own
*   messages, and on production that is a citizen's screen.
*
*   The refusal is SILENT by design - no "trace is not available here",
*   which would confirm the parameter exists to anyone who guessed it.
    CLASS-METHODS trace_ok RETURNING VALUE(rv) TYPE abap_bool.

*   WHAT THE JOURNEY STUDIO MAY DO HERE. 'EDIT' on development, 'READ' on
*   quality, 'NONE' anywhere else.
*
*   Configuration reaches other systems by transport, never by editing
*   against their data - so authoring is development-only. Quality gets
*   read access because being able to SEE what a journey is configured to
*   do, on the system where it is being tested, answers most of the
*   questions that would otherwise become a call to a developer.
*
*   'NONE' means the Studio does not open at all. The caller must enforce
*   'READ' server-side on every write path - Save, Delete, Activate, the
*   feeders, PERSIST( ) - and not merely hide the buttons, because a
*   hidden button is not an unreachable event.
    CLASS-METHODS studio_mode RETURNING VALUE(rv) TYPE string.

    CONSTANTS c_studio_edit TYPE string VALUE 'EDIT'.
    CONSTANTS c_studio_read TYPE string VALUE 'READ'.
    CONSTANTS c_studio_none TYPE string VALUE 'NONE'.

  PRIVATE SECTION.

*   The three RAK systems. Private: everything outside this class asks a
*   question about capability, never about which system it is on.
    CONSTANTS c_sys_dev  TYPE sy-sysid VALUE 'E10'.
    CONSTANTS c_sys_qa   TYPE sy-sysid VALUE 'E20'.
    CONSTANTS c_sys_prod TYPE sy-sysid VALUE 'E30'.

*   The recognised per-check keys of a keyed MSG. See MSG_FOR( ).
    CLASS-METHODS msg_key
      IMPORTING VALUE(iv_key) TYPE string
      RETURNING VALUE(rv)     TYPE abap_bool.

*   One clause's text, with 'OTR:<alias>' and '@nnn' resolved. Anything else
*   comes back exactly as configured.
    CLASS-METHODS msg_token
      IMPORTING VALUE(iv_raw)     TYPE string
                VALUE(iv_lang)    TYPE sy-langu
                VALUE(iv_journey) TYPE string OPTIONAL
      RETURNING VALUE(rv)         TYPE string.

ENDCLASS.



CLASS ZCL_RAK_JOURNEY_UTIL IMPLEMENTATION.


  METHOD is_dev.
    rv = xsdbool( sy-sysid = c_sys_dev ).
  ENDMETHOD.


  METHOD is_qa.
    rv = xsdbool( sy-sysid = c_sys_qa ).
  ENDMETHOD.


  METHOD is_prod.
*   NOT xsdbool( sy-sysid = c_sys_prod ). An unrecognised system - a
*   sandbox, a copy, a system renamed after this was written - counts as
*   production here. Anything else means a new system inherits a
*   developer's stubs on its first day.
    rv = xsdbool( sy-sysid <> c_sys_dev AND sy-sysid <> c_sys_qa ).
  ENDMETHOD.


  METHOD power_user.
*   ---- TO TURN THIS OFF ------------------------------------------------
*   Set C_ON to ABAP_FALSE and activate this class. That is the whole
*   change: every gate reads this one method, which is why the name sits
*   here once rather than at three call sites - and why switching it off
*   cannot leave one of them still open.
*
*   A named constant rather than a line to delete, because this is now
*   the second time it has been switched. The off state is a one-word
*   edit that is obvious in a diff, and nobody has to reconstruct the
*   method from a reverted commit the next time it is wanted back.
    CONSTANTS c_on TYPE abap_bool VALUE abap_true.

    IF c_on = abap_false.
      rv = abap_false.
      RETURN.
    ENDIF.

*   SY-UNAME is already upper case in every dialog and RFC context, but
*   TO_UPPER costs nothing and removes the one way this could fail
*   silently - a comparison that never matches reads exactly like a user
*   who was never on the list.
    rv = xsdbool( to_upper( sy-uname ) = 'VIKRAM.K' ).
  ENDMETHOD.


  METHOD dev_stubs_ok.
*   POWER_USER( ) IS DELIBERATELY NOT CONSULTED HERE, and this is the one
*   gate it does not lift.
*
*   The override exists so the framework owner can manage CONFIGURATION -
*   open the Studio, read a trace. It is not for submitting. The stubs
*   are the other thing entirely: they decide WHO THE CITIZEN IS, and
*   lifting them here would honour &loginbp=, send ZCL_RAK_BE_NOT's
*   MC_DEV_BP and let the bridge fill PARAM3 and LOGINBP_DEV - so a
*   request could be posted on production under a partner the session
*   never authenticated. No amount of configuration work needs that.
*
*   The first version of the override did lift it. The owner then said
*   they would use this for configuration only and never for submission,
*   which is exactly the boundary that makes the stubs unnecessary.
    rv = is_dev( ).
  ENDMETHOD.


  METHOD trace_ok.
    rv = xsdbool( is_dev( ) = abap_true
               OR is_qa( )  = abap_true
               OR power_user( ) = abap_true ).
  ENDMETHOD.


  METHOD studio_mode.
*   POWER_USER( ) IS TESTED FIRST, so it outranks the system rather than
*   being narrowed by it - on E20 the answer would otherwise be READ and
*   on E30 NONE, which is the whole thing being overridden.
*
*   IS_PROD( ) is not consulted and does not need to be: anything that is
*   not development, not quality and not the named user falls to
*   C_STUDIO_NONE, so a sandbox, a system copy or a system renamed after
*   this was written is closed by default rather than open by omission.
    rv = COND string( WHEN power_user( ) = abap_true THEN c_studio_edit
                      WHEN is_dev( ) = abap_true THEN c_studio_edit
                      WHEN is_qa( )  = abap_true THEN c_studio_read
                      ELSE c_studio_none ).
  ENDMETHOD.


  METHOD att_url.
*   The single place the streaming ICF node is named. Kept RELATIVE: an absolute
*   host breaks on E30 and open_new_tab rejects cross-domain absolute URLs.
    rv = |/sap/bc/rest/cjattviewer?guid={ iv_guid }|.
  ENDMETHOD.


  METHOD col_spec.
    DATA lv_w TYPE string.
    DATA lv_a TYPE string.
    DATA lv_f TYPE string.
    CLEAR: ev_text, ev_width, ev_align, ev_flags.
*   FOUR PARTS NOW, and SPLIT into four targets rather than three. A spec with
*   fewer parts leaves the trailing targets blank - which CSS_ALIGN( ) refuses
*   and COL_FLAG( ) reads as nothing - so every column authored before this
*   renders exactly as it did.
    SPLIT iv_col AT '|' INTO ev_text lv_w lv_a lv_f.
*   The width is validated, never passed through. A refused value leaves the
*   column exactly as it renders today rather than emitting a length the
*   browser discards silently - which would look like the width never arrived.
    ev_width = css_width( lv_w ).
    ev_align = css_align( lv_a ).
    ev_flags = to_upper( condense( lv_f ) ).
  ENDMETHOD.


  METHOD col_flag.
    DATA lt_f TYPE string_table.
    IF iv_flags IS INITIAL.
      RETURN.
    ENDIF.
    SPLIT iv_flags AT ',' INTO TABLE lt_f.
    DATA(lv_key) = to_upper( condense( iv_key ) ).
    LOOP AT lt_f INTO DATA(lv_one).
      lv_one = condense( lv_one ).
      IF lv_one = lv_key.
*       PRESENT ON ITS OWN ANSWERS 'X', NOT BLANK, so a caller tests the answer
*       rather than testing whether the answer is blank. A keyword written as
*       'SORT=' with nothing behind it would otherwise read as absent, which is
*       the FORCESELECTION shape again - configured, and behaving unconfigured.
        rv = 'X'.
        RETURN.
      ENDIF.
      IF lv_one CP |{ lv_key }=*|.
        rv = condense( substring( val = lv_one off = strlen( lv_key ) + 1 ) ).
        IF rv IS INITIAL.
          rv = 'X'.
        ENDIF.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD css_sort.
    DATA(lv_s) = to_upper( condense( iv_value ) ).
    rv = SWITCH string( lv_s
           WHEN 'ASC'        THEN 'Ascending'
           WHEN 'ASCENDING'  THEN 'Ascending'
           WHEN 'DESC'       THEN 'Descending'
           WHEN 'DESCENDING' THEN 'Descending'
           WHEN 'NONE'       THEN 'None'
           ELSE space ).
  ENDMETHOD.


  METHOD date_bound.
    DATA lv_d TYPE d.
    DATA lv_n TYPE i.

    DATA(lv_v) = to_upper( condense( iv_value ) ).
    IF lv_v IS INITIAL.
      RETURN.
    ENDIF.

*   STRLEN BEFORE THE OFFSET. An offset on a STRING is an offset, and
*   lv_v(5) on '2027' raises CX_SY_RANGE_OUT_OF_BOUNDS rather than simply
*   not matching - the same trap that dumped an E016 popup on iv_event(8).
*   A literal shorter than five characters is not a TODAY token and must
*   reach the literal branch below, not throw on the way there.
    IF strlen( lv_v ) >= 5 AND lv_v(5) = 'TODAY'.
      lv_d = sy-datum.
      DATA(lv_rest) = substring( val = lv_v off = 5 ).
      IF lv_rest IS NOT INITIAL.
*       +nD / -nY. The sign, the digits and the unit, and every part has to
*       be there - a half-written token is refused rather than guessed at.
*
*       Three characters minimum: sign, at least one digit, unit. Below that
*       the LEN below computes negative and SUBSTRING raises, so the length
*       is checked before any offset arithmetic rather than after.
        IF strlen( lv_rest ) < 3.
          RETURN.
        ENDIF.
        DATA(lv_sign) = lv_rest(1).
        DATA(lv_unit) = substring( val = lv_rest off = strlen( lv_rest ) - 1 ).
        DATA(lv_num)  = substring( val = lv_rest off = 1 len = strlen( lv_rest ) - 2 ).
        IF ( lv_sign <> '+' AND lv_sign <> '-' )
           OR lv_num IS INITIAL OR lv_num CN '0123456789'.
          RETURN.
        ENDIF.
        lv_n = CONV i( lv_num ).
        IF lv_sign = '-'.
          lv_n = lv_n * -1.
        ENDIF.
        CASE lv_unit.
          WHEN 'D'.
            lv_d = lv_d + lv_n.
          WHEN 'Y'.
*           Year arithmetic on the DATS text. 29 February minus a whole
*           number of years lands on a date that does not exist in the
*           target year; ABAP normalises it to 1 March, which is the
*           conventional answer for an age floor and the one every other
*           system in this landscape gives.
*           WIDTH/PAD only. ALPHA = OUT is for a character field with
*           leading zeros and does not combine with an integer.
            DATA(lv_yr) = CONV i( lv_d(4) ) + lv_n.
            IF lv_yr < 1000 OR lv_yr > 9999.
              RETURN.
            ENDIF.
            lv_d = |{ lv_yr WIDTH = 4 PAD = '0' }{ lv_d+4(4) }|.
          WHEN OTHERS.
            RETURN.
        ENDCASE.
      ENDIF.
      rv = |{ lv_d(4) }-{ lv_d+4(2) }-{ lv_d+6(2) }|.
      RETURN.
    ENDIF.

*   Not a token, so a literal. TO_DATS( ) is the parser the DATE range check
*   already uses, so a bound and a typed value are read by one thing - and a
*   value it refuses comes back blank, which is the refusal this method wants
*   anyway.
    DATA(lv_dats) = to_dats( lv_v ).
    IF strlen( lv_dats ) <> 8 OR lv_dats CN '0123456789'.
      RETURN.
    ENDIF.
    rv = |{ lv_dats(4) }-{ lv_dats+4(2) }-{ lv_dats+6(2) }|.
  ENDMETHOD.


  METHOD css_align.
*   THE ONE ALIGNMENT VALIDATOR, the same discipline CSS_WIDTH( ) is under
*   and written as a method before it has a second caller rather than after
*   - which is the lesson R12-2 cost, when a split written at one call site
*   left the other reading the whole string.
*
*   sap.m.Column's HALIGN takes exactly these six. Anything else is dropped
*   by the browser silently, and a value that vanishes without a word looks
*   identical to one that never arrived - so a refused value falls through
*   to no HALIGN at all, which is today's rendering.
*
*   Case-folded because an author typing 'end' has said what they meant.
    DATA(lv_a) = to_upper( condense( iv_value ) ).
    rv = SWITCH string( lv_a
           WHEN 'BEGIN'   THEN 'Begin'
           WHEN 'END'     THEN 'End'
           WHEN 'CENTER'  THEN 'Center'
           WHEN 'LEFT'    THEN 'Left'
           WHEN 'RIGHT'   THEN 'Right'
           WHEN 'INITIAL' THEN 'Initial'
           ELSE space ).
  ENDMETHOD.


  METHOD pick_spec.
    CLEAR: ev_target, ev_text_en, ev_text_ar.
    SPLIT iv_default AT '|' INTO ev_target ev_text_en ev_text_ar.
  ENDMETHOD.


  METHOD css_width.
*   Only % and rem are accepted. Anything else - px, em, vw, a bare number, a
*   typo - answers blank, and every caller reads blank as "nothing was
*   authored" and renders as it did before. The number is checked as well as
*   the unit: '%' or 'rem' on its own is not a width, and z2ui5 would put it in
*   the markup unchanged for the browser to drop without a word.
    DATA(lv) = to_lower( condense( iv_value ) ).
    IF lv IS INITIAL.
      RETURN.
    ENDIF.
    FIND REGEX '^[0-9]+(\.[0-9]+)?(%|rem)$' IN lv.
    IF sy-subrc = 0.
      rv = lv.
    ENDIF.
  ENDMETHOD.


  METHOD cfg_width.
*   The authored per-field width, or blank - both when the field carries none
*   and when what it carries is refused. A config value that breaks a layout
*   is worse than no config value at all, because nothing on the screen says
*   where the width came from, so a rejected one renders exactly as the field
*   did before the column was read. CSS_WIDTH( ) is the rule, shared with the
*   table column width.
    rv = css_width( is_field-ctrl_width ).
  ENDMETHOD.


  METHOD ctrl_width.
*   Per-field width from config first, the type defaults below when there is
*   none. CFG_WIDTH( ) answers blank both for a field that authored nothing
*   and for a value it refuses, so both fall through to the CASE and every
*   journey authored before the column existed renders identically.
    rv = cfg_width( is_field ).
    IF rv IS NOT INITIAL.
      RETURN.
    ENDIF.

    CASE is_field-type.
*     Controls with no usable width property, or already at 100%. RATING was
*     here returning 10rem, which was dead: sap.m.RatingIndicator has no width
*     (it scales via iconSize), so the value could never be applied.
      WHEN 'TEXTAREA' OR 'SLIDER' OR 'PROGRESS' OR 'RATING'.
        rv = ''.
      WHEN 'DATE' OR 'TIME' OR 'DATETIME'.
        rv = '11rem'.
      WHEN 'NUMBER' OR 'STEPPER' OR 'CURRENCY'.
        rv = '10rem'.
      WHEN 'PHONE'.
        rv = '13rem'.
      WHEN 'SELECT' OR 'MULTISELECT'.
        rv = '18rem'.
*     RADIO inherited SELECT's 18rem, which was harmless while the value was
*     never passed. It is passed now, and 18rem is narrower than four inline
*     options need - the group wrapped. Full width, let the options flow.
      WHEN 'RADIO'.
        rv = '100%'.
      WHEN 'EMAIL'.
        rv = '22rem'.
      WHEN OTHERS.
        rv = '24rem'.
    ENDCASE.
  ENDMETHOD.


  METHOD esc.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `{` IN rv WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN rv WITH `\}`.
  ENDMETHOD.


  METHOD esc_js.
    rv = iv.
    REPLACE ALL OCCURRENCES OF `\` IN rv WITH `\\`.
    REPLACE ALL OCCURRENCES OF `'` IN rv WITH `\'`.
    REPLACE ALL OCCURRENCES OF `"` IN rv WITH `\"`.
  ENDMETHOD.


  METHOD is_block.
    rv = xsdbool( iv_type = 'SEARCH' OR iv_type = 'TABLE'
               OR iv_type = 'UPLOAD' OR iv_type = 'PAYFEE'
               OR iv_type = 'EDITABLE_TABLE' OR iv_type = 'RECORDCARD'
*              CAPTCHA is a block: it draws a picture, an input and a
*              refresh button as one panel, so it must reach RENDER_BLOCK( )
*              rather than RENDER_ONE( ), which draws a single control.
               OR iv_type = 'REQPANEL' OR iv_type = 'PDF'
               OR iv_type = 'CAPTCHA' ).
  ENDMETHOD.


  METHOD is_scratch.
    DATA(lv_n) = to_upper( iv_name ).
*   _IX joins the framework-owned suffixes: it carries a RADIO's selected index
*   and an authored field of that name would collide with it.
    rv = xsdbool( lv_n = 'PAYFEE' OR lv_n CP 'PAY_*' OR lv_n CP '*_IX' OR lv_n CP '*_SEL' ).
  ENDMETHOD.


  METHOD known_type.
    rv = xsdbool( iv_type = '' OR iv_type = 'INPUT' OR iv_type = 'EMAIL' OR iv_type = 'PHONE'
      OR iv_type = 'NUMBER' OR iv_type = 'COUNT' OR iv_type = 'CURRENCY' OR iv_type = 'TEXTAREA' OR iv_type = 'DATE'
      OR iv_type = 'TIME' OR iv_type = 'DATETIME' OR iv_type = 'SELECT' OR iv_type = 'MULTISELECT'
      OR iv_type = 'RADIO' OR iv_type = 'CHECKBOX' OR iv_type = 'SWITCH' OR iv_type = 'SEGMENTED'
      OR iv_type = 'SLIDER' OR iv_type = 'STEPPER' OR iv_type = 'RATING' OR iv_type = 'DISPLAY'
      OR iv_type = 'READONLY' OR iv_type = 'STATUS' OR iv_type = 'OBJNUM' OR iv_type = 'PROGRESS'
      OR iv_type = 'LINK' OR iv_type = 'SEARCH' OR iv_type = 'TABLE' OR iv_type = 'UPLOAD'
      OR iv_type = 'PAYFEE' OR iv_type = 'EDITABLE_TABLE' OR iv_type = 'CHECKGROUP'
      OR iv_type = 'REVIEW' OR iv_type = 'RO_PANEL' OR iv_type = 'RECORDCARD'
      OR iv_type = 'REQPANEL'
*     The composite ftypes ZCL_RAK_MIGRATOR->CLASSIFY( ) assigns to the
*     ShapeIt controls that are not plain fields. They render through the
*     SELECT branch, off an API: binding in DEFAULT_VAL - see
*     ZCL_RAK_CJ_OPTS. Listed here so the engine's own unknown-type warning
*     stops firing on every migrated Municipality journey; a genuinely
*     unserved one still reports itself, on the field, through the note
*     ZCL_RAK_CJ_OPTS returns.
*     PARCELS IS THE MULTI-SELECT ONE AND IT WAS MISSING HERE. There are
*     THREE places an ftype has to be named and this is the third: the
*     renderer's SELECT branch (ZCL_RAK_JOURNEY_RENDER, so the field draws
*     at all), the parcel control's own condition (so the card list is
*     drawn instead of a dropdown) - both of which had it - and this list,
*     which only drives CHECK_TYPES( )'s warning.
*
*     So the symptom was cosmetic and misleading in equal measure: M012
*     drew its checkbox cards correctly AND reported "Field PARCELSELECTOR:
*     unsupported type 'PARCELS' - rendered as a plain input" above them.
*     The warning was wrong, the render was right, and the two together
*     read as the control having failed.
*
*     RE-APPLIED ONCE ALREADY. This line was added in 7f37019 and removed
*     again by a Stage from SAP, because the object was staged before it
*     was pulled - the exact hazard CLAUDE.md's abapGit section describes,
*     and the second time it has happened on this project. If the warning
*     comes back, check the stage history before re-diagnosing the code.
      OR iv_type = 'PARCELS'
      OR iv_type = 'PARCEL' OR iv_type = 'PROPERTY' OR iv_type = 'TITLEDEED'
      OR iv_type = 'FLOORUNIT' OR iv_type = 'CONTRACT' OR iv_type = 'BUILDINGS'
      OR iv_type = 'SIGN' OR iv_type = 'CHEMICALS'
      OR iv_type = 'ACCOM' OR iv_type = 'BOATS'
*     PDF BELONGS HERE AND HAS BEEN MISSING TWICE. Commit bc1a7ee is
*     titled "PDF was missing from KNOWN_TYPE" and its one added line
*     landed in IS_BLOCK( ) instead - which PDF also needs, and already
*     had - so the warning it was meant to silence never stopped. A PDF
*     field therefore renders correctly AND reports itself as an
*     unsupported type rendered as a plain input, which reads as the
*     control having failed.
      OR iv_type = 'PDF'
      OR iv_type = 'CAPTCHA' ).
  ENDMETHOD.


  METHOD open_url_html.

*   WINDOW.OPEN IS POPUP-BLOCKED OUTSIDE A USER GESTURE, and that is the
*   whole difference between this working on DOK and EPDA and not working
*   on Municipality. There the open item already exists when Pay is
*   pressed, so the gateway address resolves on the PRESS round trip -
*   inside the browser's transient user activation, where a popup is
*   allowed. On Municipality the open item is raised by a later workflow,
*   so the address only arrives on a POLL TICK: a timer-driven round trip
*   with no activation behind it, which Chrome blocks SILENTLY. No error,
*   no tab, and a card that goes on saying "Complete your payment in the
*   new tab" for two minutes while nothing happens.
*
*   So the open is now attempted AND CHECKED. A blocked call returns null
*   rather than throwing, and the fallback puts a real link in the page -
*   clicking that IS a gesture, so it cannot be blocked in turn. Where the
*   popup succeeds nothing changes at all: the image removes itself
*   exactly as before, which is why this is safe for the two families
*   that work today.
*
*   AN ATTRIBUTE, NOT A <script>. A script inserted through html( )
*   reaches the DOM as innerHTML and is inert by specification, so it
*   would never run; an inline event attribute does. Same channel
*   RENDER_UPLOADER( ) has always used.
*
*   BACKTICKS, NOT A |...| TEMPLATE. The snippet needs braces for its if
*   and try blocks, and a brace inside an ABAP string template opens an
*   embedded expression. Escaping them for UI5 is a different problem
*   with the same character and is still done at the end.
    DATA(lv_js) =
      `var u='` && esc_js( iv_url ) && `';var w=null;` &&
      `try{w=window.open(u,'_blank');}catch(e){}` &&
      `var p=this.parentNode;this.remove();` &&
      `if(!w){` &&
        `var a=document.createElement('a');` &&
        `a.href=u;a.target='_blank';a.rel='noopener';` &&
        `a.textContent='Open the payment page';` &&
        `a.setAttribute('style','display:inline-block;margin:8px 0 4px 0;` &&
        `padding:10px 18px;background:#b30000;color:#fff;border-radius:6px;` &&
        `text-decoration:none;font-weight:600');` &&
        `var n=document.createElement('div');` &&
        `n.textContent='Your browser blocked the payment window. ` &&
        `Use the button above to open it.';` &&
        `n.setAttribute('style','margin-bottom:8px;font-size:0.875rem;color:#666');` &&
        `p.appendChild(a);p.appendChild(n);` &&
      `}`.

*   THE ATTRIBUTE IS DOUBLE-QUOTED AND THE SNIPPET IS SINGLE-QUOTED, so
*   the only double quote that can appear here came from the URL through
*   ESC_JS( ), which escapes it for JAVASCRIPT and not for HTML - leaving
*   a bare quote that would end the attribute early. Encoding it lets the
*   parser hand JS back exactly what ESC_JS( ) intended.
    REPLACE ALL OCCURRENCES OF `"` IN lv_js WITH `&quot;`.

    DATA(lv_html) = `<div><img src="data:," style="display:none" onerror="` && lv_js && `"/></div>`.
    REPLACE ALL OCCURRENCES OF `{` IN lv_html WITH `\{`.
    REPLACE ALL OCCURRENCES OF `}` IN lv_html WITH `\}`.
    rv = lv_html.
  ENDMETHOD.


  METHOD opt_text.
    rv = COND #( WHEN iv_text IS INITIAL THEN iv_key ELSE iv_text ).
  ENDMETHOD.


  METHOD row_key.
*   Returns the field's side-by-side row token, read from two sources in this
*   order. Blank means the field starts a row of its own, which is the pre-change
*   behaviour, so every journey authored before this renders identically.
*
*   1. '+' when SAME_ROW is set on the field - join the previous field's row
*      unconditionally. The component does NOT exist on TY_FIELD yet, which is
*      why it is read through ASSIGN COMPONENT instead of is_field-same_row:
*      that compiles today and starts working the moment the component and its
*      DDIC column are added, with no further change in this class. Do not
*      convert it to a direct component read until ZIF_RAK_JOURNEY carries it.
*      Values 0 and N count as not set so a CHAR1 flag column can be filled
*      either way round.
*
*   2. The GROUP value itself when it is prefixed ROW: - the no-DDIC path, so a
*      two-up row can be authored from the config tables as they stand today.
*      Consecutive fields carrying the same ROW: value share one row and the
*      group emits no core:Title. The trade-off: such a field cannot also sit
*      under a titled group, because GROUP is doing both jobs. Treat this as the
*      interim path and SAME_ROW as the target.
*
*   Never mix the two sources inside one row - source 1 joins whatever came
*   before it, source 2 joins only a matching token, and a '+' field following a
*   ROW: field will join it, which is probably not what was meant.
    DATA lv_raw TYPE string.
    FIELD-SYMBOLS <lv_sr> TYPE any.
    ASSIGN COMPONENT 'SAME_ROW' OF STRUCTURE is_field TO <lv_sr>.
    IF sy-subrc = 0.
*     Plain assignment, not a string template: <lv_sr> is generically typed and a
*     template needs the type at compile time. Wrapped because a render dump
*     takes the whole journey down, and nothing here can prove the component is
*     elementary until it exists.
      TRY.
          lv_raw = <lv_sr>.
        CATCH cx_root.
          CLEAR lv_raw.
      ENDTRY.
      DATA(lv_sr) = to_upper( condense( lv_raw ) ).
      IF lv_sr IS NOT INITIAL AND lv_sr <> '0' AND lv_sr <> 'N'.
        rv = '+'.
        RETURN.
      ENDIF.
    ENDIF.
    DATA(lv_grp) = to_upper( condense( is_field-group ) ).
    IF strlen( lv_grp ) > 4 AND lv_grp(4) = 'ROW:'.
      rv = lv_grp.
    ENDIF.
  ENDMETHOD.


  METHOD ui_date.
    rv = iv.

    DATA(lv_dats) = to_dats( iv ).
    IF strlen( lv_dats ) <> 8.
      RETURN.
    ENDIF.

*   00000000 IS "NO DATE", NOT THE YEAR ZERO. A DATS component the backend
*   never filled comes back as eight zeroes; formatted it would put
*   "0000-00-00" in the picker, which the citizen then has to clear before
*   they can enter anything.
    IF lv_dats = '00000000'.
      CLEAR rv.
      RETURN.
    ENDIF.

    rv = |{ lv_dats(4) }-{ lv_dats+4(2) }-{ lv_dats+6(2) }|.
  ENDMETHOD.


  METHOD to_dats.
*   Normalize a picker date string to internal yyyymmdd. Accepts ISO (yyyy-mm-dd),
*   ABAP DATS (yyyymmdd) and day-first locale forms (dd.mm.yyyy / dd/mm/yyyy /
*   dd-mm-yyyy). ISO and day-first with '-' are told apart by separator position.
*   Returns empty when the value cannot be parsed unambiguously (incl. month-first
*   or partial dates), so callers skip - never falsely reject - such a value.
    DATA(lv) = condense( iv ).
    IF lv IS INITIAL.
      RETURN.
    ENDIF.
    DATA lv_y TYPE string.
    DATA lv_m TYPE string.
    DATA lv_d TYPE string.
    IF strlen( lv ) = 8 AND lv CO '0123456789'.
      lv_y = lv(4). lv_m = lv+4(2). lv_d = lv+6(2).
    ELSEIF strlen( lv ) = 10 AND lv+4(1) = '-' AND lv+7(1) = '-'.
      lv_y = lv(4). lv_m = lv+5(2). lv_d = lv+8(2).
    ELSEIF strlen( lv ) = 10
       AND ( lv+2(1) = '.' OR lv+2(1) = '/' OR lv+2(1) = '-' )
       AND lv+2(1) = lv+5(1).
      lv_d = lv(2). lv_m = lv+3(2). lv_y = lv+6(4).
    ELSE.
      RETURN.
    ENDIF.
    IF lv_y CO '0123456789' AND lv_m CO '0123456789' AND lv_d CO '0123456789'.
      DATA(lv_mm) = CONV i( lv_m ).
      DATA(lv_dd) = CONV i( lv_d ).
      DATA(lv_yy) = CONV i( lv_y ).

*     DAYS IN THAT MONTH, NOT 31 IN EVERY MONTH.
*
*     "lv_dd BETWEEN 1 AND 31" let 31.02.2026 through as 20260231, which
*     is not a date. Assigned to a D field it becomes 00000000, so the
*     value reached the backend BLANK - the citizen typed something, the
*     form accepted it, and the case was created without it. Same ending
*     as 32.13.2026 and one step harder to spot, because 31 February
*     passes every test that only looks at the number.
*
*     ARITHMETIC RATHER THAN DATE_CHECK_PLAUSIBILITY( ). Twelve lengths
*     and one leap rule are deterministic and need nothing outside this
*     class; the FM would be a dependency in a method the DOB parser, the
*     range check and the read path all sit on.
      DATA(lv_max) = SWITCH i( lv_mm
                               WHEN 1 OR 3 OR 5 OR 7 OR 8 OR 10 OR 12 THEN 31
                               WHEN 4 OR 6 OR 9 OR 11                 THEN 30
                               WHEN 2 THEN COND i(
*                                THE FULL GREGORIAN RULE, not "divisible by
*                                four". 2100 is not a leap year and a birth
*                                or expiry date can legitimately reach it.
                                 WHEN ( lv_yy MOD 4 = 0 AND lv_yy MOD 100 <> 0 )
                                   OR lv_yy MOD 400 = 0
                                 THEN 29 ELSE 28 )
                               ELSE 0 ).

      IF lv_mm BETWEEN 1 AND 12 AND lv_dd BETWEEN 1 AND lv_max.
        rv = |{ lv_y }{ lv_m }{ lv_d }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD comp_name.
    DATA(lv) = to_upper( condense( iv_key ) ).

*   Anything that is not a letter, a digit or an underscore cannot be in a
*   component name either - a hyphen, a dot, a space, all raise the same
*   exception with a different offending character.
    DATA lv_out TYPE string.
    DATA lv_i   TYPE i.
    CONSTANTS lc_ok TYPE string
      VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'.

    WHILE lv_i < strlen( lv ).
      DATA(lv_c) = lv+lv_i(1).
      IF lc_ok CS lv_c.
        lv_out = lv_out && lv_c.
      ELSE.
        lv_out = lv_out && '_'.
      ENDIF.
      lv_i = lv_i + 1.
    ENDWHILE.

*   A component name cannot start with a digit.
    IF lv_out IS NOT INITIAL AND lv_out(1) CO '0123456789'.
      lv_out = |F{ lv_out }|.
    ENDIF.

*   23, not 30: BUILD_MODEL( ) does not create one component per field, it
*   creates the field and then its companions on the same base name - _VS,
*   _VST, _IDTYPE, _NAME, _IX, _EXP. _IDTYPE is the longest at seven
*   characters, so the base has to stop at 23 for every companion to still
*   fit inside the 30-character cap.
    IF strlen( lv_out ) <= 23.
      rv = lv_out.
      RETURN.
    ENDIF.

*   Too long: 18 characters of the name and a four-digit fingerprint of the
*   WHOLE key - 23 in total, leaving room for _IDTYPE. The fingerprint stops
*   two keys that share their first 18 characters from collapsing onto one
*   component, which would be worse than the dump this fixes - two fields
*   would then silently share a value. Computed from the key alone, never
*   from its position in the field list, so two independent callers walking
*   the same fields arrive at the same name.
    DATA lv_h TYPE i.
    CLEAR lv_i.
    WHILE lv_i < strlen( lv_out ).
      DATA(lv_p) = find( val = lc_ok sub = lv_out+lv_i(1) ).
      IF lv_p < 0.
        lv_p = 0.
      ENDIF.
      lv_h = ( lv_h * 31 + lv_p + 1 ) MOD 100000.
      lv_i = lv_i + 1.
    ENDWHILE.

    rv = |{ lv_out(18) }_{ lv_h MOD 10000 WIDTH = 4 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.


  METHOD pick_text.
*   Arabic preferred when lang = 'A' and the Arabic text is filled, English
*   otherwise - same fallback PICK( ) always used.
    rv = COND #( WHEN iv_lang = 'A' AND iv_ar IS NOT INITIAL THEN iv_ar
                 ELSE iv_en ).

*   OTR:<alias> lets a config text stay single-sourced with an SAP OTR
*   concept instead of being frozen at whatever it was when someone last
*   typed it into the Studio. A missing or deleted OTR concept falls back
*   to the stored literal (prefix and all) rather than an empty text, so
*   the failure is a visible "OTR:..." on screen, not a blank one nobody
*   can explain.
*   The resolution itself is OTR_TEXT( ) - one copy, so a per-check MSG clause
*   that has already been picked EN/AR can resolve an alias through the same
*   code rather than a second one that drifts from it.
    rv = otr_text( iv_text = rv iv_lang = iv_lang ).
  ENDMETHOD.


  METHOD otr_text.
    rv = iv_text.
    IF strlen( rv ) <= 4 OR substring( val = rv len = 4 ) <> 'OTR:'.
      RETURN.
    ENDIF.

*   TYPE sotr_alias, not the STRING SUBSTRING( ) returns by default - a
*   function module's import parameters are typed strictly, unlike a
*   method's by-reference binding. Passing a STRING here dumps
*   CX_SY_DYN_CALL_ILLEGAL_TYPE at runtime.
    DATA lv_alias TYPE sotr_alias.
    lv_alias = substring( val = rv off = 4 ).
    DATA lv_otr TYPE sotr_txt.
    CLEAR lv_otr.
    CALL FUNCTION 'SOTR_GET_TEXT_KEY'
      EXPORTING
        alias           = lv_alias
        langu           = iv_lang
      IMPORTING
        e_text          = lv_otr
      EXCEPTIONS
        no_entry_found  = 1
        parameter_error = 2
        OTHERS          = 3.
    IF sy-subrc = 0 AND lv_otr IS NOT INITIAL.
      rv = lv_otr.
    ENDIF.
  ENDMETHOD.


  METHOD msg_key.
    DATA(lv) = to_upper( condense( iv_key ) ).
    rv = xsdbool(    lv = 'REQUIRED'
                  OR lv = 'LEN'
                  OR lv = 'RANGE'
                  OR lv = 'NUMBER'
                  OR lv = 'FORMAT'
                  OR lv = '*' ).
  ENDMETHOD.


  METHOD msg_token.
    rv = iv_raw.
    IF rv IS INITIAL.
      RETURN.
    ENDIF.

    IF strlen( rv ) > 4 AND substring( val = rv len = 4 ) = 'OTR:'.
      rv = otr_text( iv_text = rv iv_lang = iv_lang ).
      RETURN.
    ENDIF.

*   @nnn - a ZRAK_T_CJ_TXT row, the same reference COL_HEADER( ) takes for a
*   TABLE column header and LONG_TEXT( ) for a paragraph. Guarded on STRLEN( )
*   before the offset: RV is a STRING, and an offset past the end of one raises
*   CX_SY_RANGE_OUT_OF_BOUNDS rather than returning blank.
    IF strlen( rv ) > 1 AND rv(1) = '@'.
      DATA lv_no TYPE string.
      lv_no = substring( val = rv off = 1 ).
      CONDENSE lv_no.
      TRY.
          rv = zcl_rak_text=>get( iv_no      = CONV symsgno( lv_no )
                                  iv_default = iv_raw
                                  iv_journey = iv_journey ).
        CATCH cx_root.
*         An unusable number is not a reason to show the citizen nothing. The
*         raw token goes on screen so it is obvious in testing which check on
*         which field is misconfigured.
          rv = iv_raw.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD directive.
    CLEAR rv.

    DATA(lv_want) = to_upper( condense( iv_key ) ).
    IF lv_want IS INITIAL OR iv_spec IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_cl TYPE string_table.
    SPLIT iv_spec AT ';' INTO TABLE lt_cl.

    LOOP AT lt_cl INTO DATA(lv_cl).
      DATA(lv_off) = find( val = lv_cl sub = ':' ).
      IF lv_off <= 0.
        CONTINUE.
      ENDIF.
*     FIRST colon only, so a value may contain one of its own - a file
*     name is free text and nothing stops an author writing one.
      IF to_upper( condense( substring( val = lv_cl len = lv_off ) ) ) = lv_want.
        rv = condense( substring( val = lv_cl off = lv_off + 1 ) ).
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD msg_for.
    CLEAR rv.

    DATA lv_raw TYPE string.
    lv_raw = iv_msg.
    SHIFT lv_raw LEFT DELETING LEADING space.
    IF lv_raw IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_cl TYPE string_table.
    SPLIT lv_raw AT ';' INTO TABLE lt_cl.

*   KEYED OR NOT, DECIDED ON THE FIRST CLAUSE ONLY. The text has to BEGIN with
*   a recognised key immediately followed by ':' - so an ordinary sentence that
*   happens to contain a colon or a semicolon, and an 'OTR:' alias covering the
*   whole column, are both plain wording and take the untouched path below.
    DATA lv_first TYPE string.
    DATA lv_keyed TYPE abap_bool.
    READ TABLE lt_cl INTO lv_first INDEX 1.
    IF sy-subrc = 0.
      DATA(lv_p) = find( val = lv_first sub = ':' ).
      IF lv_p > 0.
        lv_keyed = msg_key( substring( val = lv_first len = lv_p ) ).
      ENDIF.
    ENDIF.

    IF lv_keyed = abap_false.
*     Every check that reads MSG today gets it, exactly as before.
*     IV_KEYED_ONLY marks the checks that did NOT, and they keep not.
      IF iv_keyed_only = abap_false.
        rv = iv_msg.
      ENDIF.
      RETURN.
    ENDIF.

    DATA(lv_want) = to_upper( condense( iv_check ) ).
    DATA lv_star TYPE string.
    DATA lv_txt  TYPE string.
    DATA lv_k    TYPE string.
    DATA lv_off  TYPE i.
    DATA lv_aft  TYPE i.

    LOOP AT lt_cl INTO DATA(lv_cl).
      lv_off = find( val = lv_cl sub = ':' ).
      IF lv_off <= 0.
        CONTINUE.
      ENDIF.
      lv_k = to_upper( condense( substring( val = lv_cl len = lv_off ) ) ).
*     The FIRST colon only, so a clause's own text may be 'OTR:<alias>'.
*     LV_AFT is computed into a variable rather than written as LV_OFF + 1
*     inline: an arithmetic expression in an actual parameter is legal from
*     7.40, and a plain variable costs nothing and cannot be the reason an
*     activation fails.
      lv_aft = lv_off + 1.
      lv_txt = substring( val = lv_cl off = lv_aft ).
      SHIFT lv_txt LEFT DELETING LEADING space.
      IF lv_k = lv_want.
        rv = lv_txt.
        EXIT.
      ELSEIF lv_k = '*'.
        lv_star = lv_txt.
      ENDIF.
    ENDLOOP.

    IF rv IS INITIAL.
      rv = lv_star.
    ENDIF.
    IF rv IS INITIAL.
*     Keyed, but nothing for THIS check. Blank on purpose: the caller falls
*     back to the catalogue, which is bilingual and already says the right
*     thing for the check that fired.
      RETURN.
    ENDIF.

    DATA lv_lang TYPE sy-langu.
    lv_lang = COND #( WHEN iv_lang IS NOT INITIAL THEN iv_lang
                      ELSE zcl_rak_text=>lang( ) ).
    rv = msg_token( iv_raw     = rv
                    iv_lang    = lv_lang
                    iv_journey = iv_journey ).
  ENDMETHOD.


  METHOD col_ix.
    LOOP AT it_cols INTO DATA(lv_c).
      IF to_upper( condense( lv_c ) ) = to_upper( iv_name ).
        rv = sy-tabix.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD cell_of.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    rv = VALUE #( it_row[ lv_ix ] OPTIONAL ).
  ENDMETHOD.


  METHOD put_cell.
*   A column the spec does not define is SKIPPED, never appended. Appending is
*   what pushed every later cell one place along in the first place.
    DATA(lv_ix) = col_ix( it_cols = it_cols iv_name = iv_name ).
    CHECK lv_ix > 0.
    CHECK lines( ct_row ) >= lv_ix.
    READ TABLE ct_row INDEX lv_ix ASSIGNING FIELD-SYMBOL(<cell>).
    CHECK sy-subrc = 0.
    <cell> = iv_val.
  ENDMETHOD.


  METHOD blank_row.
    DO lines( it_cols ) TIMES.
      APPEND `` TO rt.
    ENDDO.
  ENDMETHOD.


  METHOD nationalities.
*   SELECT ... INTO TABLE rather than SELECT ... ENDSELECT: the loop form holds a
*   database cursor open for the whole of the loop body, and this is a single
*   round trip for about 240 rows.
    SELECT land1 AS key, landx50 AS text
      FROM t005t
      WHERE spras = @sy-langu
      ORDER BY land1 ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt.

*   Falling back to English rather than to nothing. A journey launched in a
*   language T005T has no rows for would otherwise show an empty nationality
*   list, which looks like a broken control rather than a missing translation.
    IF rt IS INITIAL AND sy-langu <> 'E'.
      SELECT land1 AS key, landx50 AS text
        FROM t005t
        WHERE spras = 'E'
        ORDER BY land1 ASCENDING
        INTO CORRESPONDING FIELDS OF TABLE @rt.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
