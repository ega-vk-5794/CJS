*&---------------------------------------------------------------------*
*& ZCL_RAK_TEXT - the two languages the framework speaks
*&---------------------------------------------------------------------*
*& English and Arabic live in CATALOGUE below - no message class, no SE91,
*& no SE63. For two fixed languages a table in code is less to maintain
*& than a translation process, it transports with the class, and a diff
*& shows exactly what wording changed.
*&
*& CATALOGUE is the shipped baseline, not the last word. Table
*& ZRAK_T_CJ_TXT overrides any row, so a functional consultant can reword
*& anything in SM30 without a developer and without an activation:
*&
*&   MANDT    MANDT
*&   MSGNO    CHAR3    key   the number from C_NO below
*&   TEXT_EN  CHAR255
*&   TEXT_AR  CHAR255
*&
*& Both languages sit on one row on purpose: a reviewer comparing English
*& against Arabic reads them side by side instead of hunting for the twin
*& row. Delivery class C, then SE11 -> Utilities -> Table Maintenance
*& Generator for the SM30 dialog, then run ZRAK_CJ_TXT_SEED once so all
*& fifty rows are present to edit.
*&
*& A blank cell falls back to CATALOGUE, so clearing a value restores the
*& shipped wording rather than blanking the control.
*&
*& There are three kinds of text in CJS and only the first belongs here:
*&
*&   framework  what the engine says itself - Next, Pay, Delete, the
*&              validation and dialog wording. THIS CLASS.
*&   journey    labels, titles, messages authored per service. Already
*&              handled by the _AR twin columns. Nothing to do.
*&   config     option texts and value-help descriptions. Language comes
*&              from the DDIC search help or the _AR column on the option
*&              row - not from here.
*&
*& The language is the one the ENGINE resolved, not SY-LANGU. INIT reads
*& &lang= from the URL and falls back to SY-LANGU only when it is absent,
*& so a citizen asking for Arabic gets Arabic whatever language the ICF
*& service user happens to log on with. Reading SY-LANGU here instead put
*& the stylesheet in RTL while these texts stayed English on the same page.
*& SET_LANG is called once from INIT; nothing else should call it.
*&
*& OVERRIDES is the place to divert one text for one journey in code, for
*& when a department will not accept the shared wording. It wins over both
*& the table and the catalogue. The journey comes from SET_JOURNEY, called
*& once by the engine, so existing callers need no extra argument; pass
*& IV_JOURNEY only to force a specific one.
*&
*& Direction is derived here because it follows language and nothing else.
*&---------------------------------------------------------------------*
CLASS zcl_rak_text DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS c_langu_ar TYPE sy-langu VALUE 'A' ##NO_TEXT.

    CONSTANTS:
      BEGIN OF c_no,
        next          TYPE symsgno VALUE '001',
        back          TYPE symsgno VALUE '002',
        submit        TYPE symsgno VALUE '003',
        pay           TYPE symsgno VALUE '004',
        save_draft    TYPE symsgno VALUE '005',
        delete        TYPE symsgno VALUE '006',
        edit          TYPE symsgno VALUE '007',
        waiting       TYPE symsgno VALUE '008',
        done          TYPE symsgno VALUE '009',
        total         TYPE symsgno VALUE '010',
        description   TYPE symsgno VALUE '011',
        amount        TYPE symsgno VALUE '012',
        required      TYPE symsgno VALUE '013',
        too_short     TYPE symsgno VALUE '014',
        too_long      TYPE symsgno VALUE '015',
        bad_format    TYPE symsgno VALUE '016',
        choose_one    TYPE symsgno VALUE '017',
        upload        TYPE symsgno VALUE '018',
        attachments   TYPE symsgno VALUE '019',
        file_big      TYPE symsgno VALUE '020',
        file_type     TYPE symsgno VALUE '021',
        review        TYPE symsgno VALUE '022',
        no_entries    TYPE symsgno VALUE '023',
        add_row       TYPE symsgno VALUE '024',
        remove_row    TYPE symsgno VALUE '025',
        search        TYPE symsgno VALUE '026',
        confirm       TYPE symsgno VALUE '027',
        cancel        TYPE symsgno VALUE '028',
        complete      TYPE symsgno VALUE '029',
        select        TYPE symsgno VALUE '030',
        selected      TYPE symsgno VALUE '031',
        view          TYPE symsgno VALUE '032',
        filed         TYPE symsgno VALUE '033',
        browse        TYPE symsgno VALUE '034',
        close         TYPE symsgno VALUE '035',
        use           TYPE symsgno VALUE '036',
        nothing_req   TYPE symsgno VALUE '037',
        del_title     TYPE symsgno VALUE '038',
        del_warn      TYPE symsgno VALUE '039',
        bp_find       TYPE symsgno VALUE '040',
        bp_hint       TYPE symsgno VALUE '041',
        fb_title      TYPE symsgno VALUE '042',
        fb_thanks     TYPE symsgno VALUE '043',
        fb_send       TYPE symsgno VALUE '044',
        fb_hint       TYPE symsgno VALUE '045',
        fb_excellent  TYPE symsgno VALUE '046',
        fb_good       TYPE symsgno VALUE '047',
        fb_average    TYPE symsgno VALUE '048',
        fb_poor       TYPE symsgno VALUE '049',
        fb_verypoor   TYPE symsgno VALUE '050',
        fb_skip       TYPE symsgno VALUE '131',
        att_required  TYPE symsgno VALUE '051',
        choose_file   TYPE symsgno VALUE '074',
        num_min       TYPE symsgno VALUE '052',
        num_max       TYPE symsgno VALUE '053',
        not_number    TYPE symsgno VALUE '054',
        date_min      TYPE symsgno VALUE '055',
        date_max      TYPE symsgno VALUE '056',
        val_error     TYPE symsgno VALUE '057',
        amount_aed    TYPE symsgno VALUE '058',
        pay_method    TYPE symsgno VALUE '059',
        pay_with      TYPE symsgno VALUE '060',
        pay_now       TYPE symsgno VALUE '061',
        pay_received  TYPE symsgno VALUE '062',
        pay_popup     TYPE symsgno VALUE '063',
        pay_reopen    TYPE symsgno VALUE '064',
        pay_stop      TYPE symsgno VALUE '065',
        pay_stopped   TYPE symsgno VALUE '066',
        pay_prep      TYPE symsgno VALUE '067',
        pay_prep_wait TYPE symsgno VALUE '068',
        pay_prep_fail TYPE symsgno VALUE '069',
        pay_notdone   TYPE symsgno VALUE '070',
        pay_inprog    TYPE symsgno VALUE '071',
        pay_nofee     TYPE symsgno VALUE '072',
        pay_first     TYPE symsgno VALUE '073',
*       A PDF field with no document yet. Not an error - a certificate that
*       does not exist until the request is approved is the normal case, and
*       an empty viewer reads as one still loading.
        pdf_none      TYPE symsgno VALUE '075',
*       ZCL_RAK_BP_POPUP - the reusable Partner Search dialog. Framework text
*       because the popup itself is shared infrastructure, not one journey's
*       wording - every field label and section title in it used to be a bare
*       ABAP literal, so it rendered in English even on an Arabic run.
        bpp_title       TYPE symsgno VALUE '076',
        bpp_search_by   TYPE symsgno VALUE '077',
        bpp_eid         TYPE symsgno VALUE '078',
        bpp_passport_ne TYPE symsgno VALUE '079',
        bpp_unified_ne  TYPE symsgno VALUE '080',
        bpp_trade_lic   TYPE symsgno VALUE '081',
        bpp_passport_no TYPE symsgno VALUE '082',
        bpp_unified_id  TYPE symsgno VALUE '083',
        bpp_dob         TYPE symsgno VALUE '084',
        bpp_nat         TYPE symsgno VALUE '085',
        bpp_pass_type   TYPE symsgno VALUE '086',
        bpp_general     TYPE symsgno VALUE '087',
        bpp_contact     TYPE symsgno VALUE '088',
        bpp_address     TYPE symsgno VALUE '089',
        bpp_first_name  TYPE symsgno VALUE '090',
        bpp_father_name TYPE symsgno VALUE '091',
        bpp_grand_name  TYPE symsgno VALUE '092',
        bpp_fourth_name TYPE symsgno VALUE '093',
        bpp_last_name   TYPE symsgno VALUE '094',
        bpp_gender      TYPE symsgno VALUE '095',
        bpp_id_no       TYPE symsgno VALUE '096',
        bpp_id_exp      TYPE symsgno VALUE '097',
        bpp_unified_num TYPE symsgno VALUE '098',
        bpp_pp_issue    TYPE symsgno VALUE '099',
        bpp_pp_country  TYPE symsgno VALUE '100',
        bpp_pp_exp      TYPE symsgno VALUE '101',
        bpp_occupation  TYPE symsgno VALUE '102',
        bpp_mobile      TYPE symsgno VALUE '103',
        bpp_email       TYPE symsgno VALUE '104',
        bpp_telephone   TYPE symsgno VALUE '105',
        bpp_country     TYPE symsgno VALUE '106',
        bpp_region      TYPE symsgno VALUE '107',
        bpp_city        TYPE symsgno VALUE '108',
        bpp_street      TYPE symsgno VALUE '109',
        bpp_house_no    TYPE symsgno VALUE '110',
        bpp_pobox       TYPE symsgno VALUE '111',
        bpp_resume      TYPE symsgno VALUE '112',
        bpp_use_partner TYPE symsgno VALUE '113',
        bpp_partner_no  TYPE symsgno VALUE '114',
*       ZCL_C022_KHULA_CERTI_LOGIC's own Partner Search popup - a separate,
*       hand-drawn copy of ZCL_RAK_BP_POPUP's, not a call into it, so it
*       needed its own pass through this catalogue. Two labels here are
*       worded differently than their ZCL_RAK_BP_POPUP twin (Partner vs
*       Partner &1, Phone Number vs Mobile Number) so they get their own
*       entries rather than reusing bpp_partner_no / bpp_mobile.
        bpp_partner     TYPE symsgno VALUE '115',
        bpp_phone       TYPE symsgno VALUE '116',
*       TABLE COLUMN HEADERS. A TABLE field's headers live in the
*       KEY:Label:TYPE spec in DEFAULT_VAL, and DEFAULT_VAL has no _AR twin -
*       so a literal header shows its English to an Arabic reader, which is
*       what every Track Complaint / Track Suggestion details table did. A
*       spec column written as KEY:@nnn resolves through here instead; see
*       ZCL_RAK_JOURNEY_RENDER->COL_HEADER( ).
        col_suggestion_id   TYPE symsgno VALUE '117',
        col_suggestion_date TYPE symsgno VALUE '118',
        col_mobile_number   TYPE symsgno VALUE '119',
        col_name            TYPE symsgno VALUE '120',
        col_department      TYPE symsgno VALUE '121',
        col_status          TYPE symsgno VALUE '122',
*       THE RESULT CARD. Its headline and subtitle were English literals with no
*       language test at all, while the closed-card and the Reference label a few
*       lines away in the same method were already bilingual - so an Arabic run
*       ended on an English success message.
        res_paid            TYPE symsgno VALUE '123',
        res_submitted       TYPE symsgno VALUE '124',
        res_done_sub        TYPE symsgno VALUE '125',
        res_not_submitted   TYPE symsgno VALUE '126',
        res_not_sub_sub     TYPE symsgno VALUE '127',
*       EC02's headers. MOBILE NUMBER, DEPARTMENT and STATUS are shared with
*       EC06 above rather than duplicated - the same column, the same wording.
        col_complaint_id    TYPE symsgno VALUE '128',
        col_complaint_date  TYPE symsgno VALUE '129',
        col_description     TYPE symsgno VALUE '130',
*       Navigation is locked once the fee is PAID - see ZCL_RAK_JOURNEY_ENGINE->NAV_LOCKED( ).
        nav_locked          TYPE symsgno VALUE '132',
*       CAPTCHA - the verification control. Framework wording, not a
*       journey's: the same challenge appears on every service that turns
*       it on, and a per-journey label would drift into five spellings of
*       the same instruction.
        cap_title           TYPE symsgno VALUE '133',
        cap_hint            TYPE symsgno VALUE '134',
        cap_ph              TYPE symsgno VALUE '135',
        cap_refresh         TYPE symsgno VALUE '136',
        cap_wrong           TYPE symsgno VALUE '137',
*       The leading blank item on an OPTIONAL closed-list dropdown - the way
*       back to "not answered" after a mis-click. Shown only where the field
*       has no PLACEHOLDER of its own to use instead. See R13-8 in
*       ZCL_RAK_JOURNEY_RENDER's SELECT branch.
        opt_none            TYPE symsgno VALUE '138',
*       THE WHOLE REFUSAL, and deliberately the whole of it. Used by the
*       Studio's closed-system page and by its write guard. Any extra
*       word here reaches a caller who has not been identified, so the
*       wording is the one thing about it that must not grow.
        not_authorized      TYPE symsgno VALUE '139',
*       THE SECOND LINE OF THE REFUSAL, AND IT EXISTS TO SUPPRESS A
*       DEFAULT RATHER THAN TO SAY ANYTHING.
*
*       sap.m.MessagePage's DESCRIPTION defaults to "Check the filter
*       settings", and an unsupplied z2ui5 OPTIONAL is not blank - it is
*       whatever UI5 defaults to, because XML_GET_PARTS( ) drops every
*       blank property from the markup and the control's own default
*       then applies. So the refusal page read "Not authorized. / Check
*       the filter settings", which is nonsense on a page with no
*       filters. Passing a space does not help either: a space IS blank
*       to that filter and gets dropped the same way.
*
*       Something real therefore has to be passed. This is the most
*       neutral line available - it names no system, no landscape and no
*       Studio, and it tells the one reader who might legitimately be
*       stuck what to do next.
        not_auth_hint       TYPE symsgno VALUE '140',
*       A date the framework cannot read. Named DATE_BAD rather than
*       DATE_FORMAT because the commonest case is not a format at all -
*       32.13.2026 is written exactly the way the picker asks for and is
*       still not a date.
        date_bad            TYPE symsgno VALUE '141',
*       The Studio on a client that may look and not write. It names no
*       system and no client - the same rule the refusal page follows,
*       and for the same reason: whoever is reading it has not been
*       identified, and the landscape's shape is not theirs to learn.
*       144 BECAUSE 142 AND 143 ARE TAKEN, and this constant was briefly
*       142 - which collided with SORT_ASC and raised
*       CX_SY_ITAB_DUPLICATE_KEY the moment the catalogue was built, so
*       the Studio AND every journey died on start with an uncaught
*       exception. The number is a UNIQUE KEY and nothing checks it at
*       compile time; read the highest in use numerically before adding
*       one, not off the tail of a filtered list.
        cjs_read_only       TYPE symsgno VALUE '144',
*       R18-3. The two entries of a sortable column's header menu. Two rather
*       than one toggle, because a menu entry that reads "Sort" has to say
*       what it would sort to, and a toggle would have to know what it is
*       toggling from.
        sort_asc            TYPE symsgno VALUE '142',
        sort_desc           TYPE symsgno VALUE '143',
*       ================================================================
*       THE DOK SCHOOL FAMILY - D001, D002, D011, D012.
*       ================================================================
*       These four journeys draw wording NO CONFIG COLUMN CAN REACH:
*       D001 hand-draws its whole Owner list and Owner dialog in ABAP, and
*       all four raise validation messages from ON_CUSTOM_VALIDATE( ) and
*       ON_CHANGE( ), which have no _AR twin anywhere. Every one of them
*       was a bare literal, so an Arabic run showed English.
*
*       JOURNEY WORDING IN THE FRAMEWORK CATALOGUE, DELIBERATELY. The class
*       header says journey text is handled by the _AR twin columns - true
*       of everything that lives in ZRAK_T_JNY*, and these do not. A
*       hand-drawn control has no row to carry its twin, so the only two
*       places its Arabic can live are a literal in the class (which is the
*       defect) or here. Here also means SM30-maintainable through
*       ZRAK_T_CJ_TXT with no developer and no activation, and countable by
*       the missing-Arabic report, neither of which a literal can offer.
*
*       NUMBERS START AT 145 BECAUSE 144 IS THE HIGHEST IN USE. Read the
*       highest NUMERICALLY before adding - MSGNO is a UNIQUE KEY that
*       nothing checks at compile time, and a collision raises
*       CX_SY_ITAB_DUPLICATE_KEY the moment the catalogue is built, which
*       kills the Studio and every journey at once. See the note on 144.
*
*       WHAT IS NOT HERE IS AS DELIBERATE AS WHAT IS. Six of D001's strings
*       are the same words an existing entry already carries in verified
*       Arabic, so they REUSE it rather than getting a twin: Emirates ID
*       (BPP_EID), Nationality (BPP_NAT), Mobile Number (COL_MOBILE_NUMBER),
*       Search (SEARCH), Close (CLOSE) and Delete (DELETE). A second row
*       saying the same thing is a second row to keep in step.
        own_owner           TYPE symsgno VALUE '145',
        own_details         TYPE symsgno VALUE '146',
        own_add_owner       TYPE symsgno VALUE '147',
        own_col_name        TYPE symsgno VALUE '148',
        own_col_email       TYPE symsgno VALUE '149',
        own_col_shares      TYPE symsgno VALUE '150',
        own_edit_tip        TYPE symsgno VALUE '151',
        own_none_yet        TYPE symsgno VALUE '152',
        own_identification  TYPE symsgno VALUE '153',
*       BIRTH DATE RATHER THAN BPP_DOB. The Arabic is the same string as
*       BPP_DOB's and is copied from it verbatim; the entry exists only
*       because the English differs ("Birth Date" against "Date of Birth")
*       and this pass is not allowed to change what an English reader sees.
*       Collapse the two if the department ever agrees one spelling.
        own_dob             TYPE symsgno VALUE '154',
        own_shares_pct      TYPE symsgno VALUE '155',
        own_documents       TYPE symsgno VALUE '156',
*       THE SIX UPLOADER LABELS. Each names a document the department
*       already has a legal name for - see the warning at the catalogue
*       rows themselves.
        own_doc_eid         TYPE symsgno VALUE '157',
        own_doc_passport    TYPE symsgno VALUE '158',
        own_doc_intro       TYPE symsgno VALUE '159',
        own_doc_criminal    TYPE symsgno VALUE '160',
        own_doc_cv          TYPE symsgno VALUE '161',
        own_doc_family      TYPE symsgno VALUE '162',
        own_btn_add         TYPE symsgno VALUE '163',
*       D001's validation and popup messages.
        d001_need_owner     TYPE symsgno VALUE '164',
        d001_owner_incompl  TYPE symsgno VALUE '165',
        d001_need_stage     TYPE symsgno VALUE '166',
        d001_fill_required  TYPE symsgno VALUE '167',
        d001_shares_100     TYPE symsgno VALUE '168',
        d001_eid_format     TYPE symsgno VALUE '169',
        d001_upload_doc     TYPE symsgno VALUE '170',
        d001_owner_added    TYPE symsgno VALUE '171',
*       D002 - the manager and trade-licence searches.
        d002_search_min     TYPE symsgno VALUE '172',
        d002_trade_enter    TYPE symsgno VALUE '173',
        d002_trade_nobp     TYPE symsgno VALUE '174',
*       D011 - advertisement.
        d011_need_type      TYPE symsgno VALUE '175',
        d011_end_before     TYPE symsgno VALUE '176',
        d011_reselect_cons  TYPE symsgno VALUE '177',
*       D012 - school trip / activity.
        d012_need_grade     TYPE symsgno VALUE '178',
        d012_end_after      TYPE symsgno VALUE '179',
        d012_end_before     TYPE symsgno VALUE '180',
*       ---- FRAMEWORK, NOT D-FAMILY, AND FOUND FROM A D001 SCREENSHOT ----
*       Two literals sat in the engine itself, so they showed English on
*       EVERY journey in Arabic, not only these four. Both are caught here
*       rather than worked around per journey.
*
*       ATT_HINT is RENDER_UPLOADER( )'s size line. &1 is the extension
*       list (PDF, JPG, PNG - not translated, they are file formats) and
*       &2 the megabyte figure; only the words around them were English.
        att_hint            TYPE symsgno VALUE '181',
*       GRID_ADD is the Add button over a grid. &1 is the grid's own LABEL,
*       which is ALREADY bilingual from ZLABEL_AR - so the button read
*       "<Arabic label> Add", half translated, which is the tell that the
*       verb and not the noun was the literal.
        grid_add            TYPE symsgno VALUE '182',
*       ---- D001's BUILDINGS grid headers ----
*       Hard-coded in GET_TABLE( ) as RS_DATA-COLUMNS, which is a plain
*       string table with no _AR twin - the shape ~28 handlers share.
        col_block_name      TYPE symsgno VALUE '183',
        col_floors          TYPE symsgno VALUE '184',
        col_rooms           TYPE symsgno VALUE '185',
*       ---- SAVE AS DRAFT ----
*       Two sheet findings in one line of engine code: the confirmation was
*       an English literal on an Arabic page, AND it printed MV_INTRENO -
*       which before a case exists is a GUID_22, so the citizen was shown
*       twenty-two characters of technical key as their "draft number".
*
*       TWO ENTRIES, NOT ONE WITH AN OPTIONAL &1. A reference is only worth
*       printing when it is one the citizen could use, and a template with
*       an empty substitution leaves a dangling dash.
        draft_saved         TYPE symsgno VALUE '188',
        draft_saved_ref     TYPE symsgno VALUE '189',
*       ---- THE ATTACHMENT LABEL FALLBACKS ----
*       ATTACH_LABEL has NO _AR TWIN IN THE DDIC, which is why the text
*       report emits it as kind NOAR with the Arabic side permanently
*       blank - an export can collect an Arabic the import has nowhere to
*       write. Both places that fall back when it is empty appended an
*       English literal, so blanking the column - the obvious way to let
*       the field's own bilingual LABEL through - produced
*       "<Arabic label> - attachment". These make that fallback safe.
        att_suffix          TYPE symsgno VALUE '186',
        att_support         TYPE symsgno VALUE '187',
      END OF c_no.
    TYPES:
      BEGIN OF ty_txt,
        msgno TYPE symsgno,
        en    TYPE string,
        ar    TYPE string,
      END OF ty_txt,
      tt_txt TYPE SORTED TABLE OF ty_txt WITH UNIQUE KEY msgno.

    TYPES:
      BEGIN OF ty_over,
        journey_id TYPE string,
        msgno      TYPE symsgno,
        en         TYPE string,
        ar         TYPE string,
      END OF ty_over,
      tt_over TYPE STANDARD TABLE OF ty_over WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_miss,
        msgno   TYPE symsgno,
        english TYPE string,
      END OF ty_miss,
      tt_miss TYPE STANDARD TABLE OF ty_miss WITH EMPTY KEY.

*   FIELD LONG TEXT - a paragraph that will not fit in ZLABEL.
*
*   ZLABEL is CHAR(150) and cuts on INSERT, so a consent declaration in
*   ZRAK_T_JNY_FLD is not merely displayed short, it IS short: the rest of
*   the sentence is gone from the database and cannot be recovered from it.
*   It has to come from somewhere that has no such ceiling, and this is that
*   somewhere - keyed by journey and field, bilingual, and in git rather
*   than in a table nobody can review.
*
*   Preferred over TEXT: on DEFAULT_VAL when the text is legal wording, for
*   two reasons: string literals here have no length limit and no _AR
*   problem, and a declaration that someone must be able to audit belongs
*   where a diff will show it changing.
    TYPES:
      BEGIN OF ty_long,
        journey_id TYPE string,
        field_name TYPE string,
        en         TYPE string,
        ar         TYPE string,
      END OF ty_long,
      tt_long TYPE STANDARD TABLE OF ty_long WITH EMPTY KEY.

    CLASS-METHODS long_texts
      RETURNING VALUE(rt_long) TYPE tt_long.

*   The paragraph for one field, or IV_DEFAULT when nothing is registered -
*   which means an unregistered field keeps whatever ZLABEL holds, and every
*   journey that predates this renders exactly as it did.
    CLASS-METHODS long
      IMPORTING iv_journey     TYPE string
                iv_field       TYPE string
                iv_default     TYPE string
      RETURNING VALUE(rv_text) TYPE string.

*   Does a journey key written here name the journey now running?
*
*   THE KEYS IN THIS CLASS ARE SERVICE CODES AND MS_CONFIG-JOURNEY_ID IS NOT.
*   A ZRAK_T_JNY key is the full spelling - DOK_D002_SCHOOL_LIC_NEW - while
*   everyone writing an entry here, in this repo and in every discussion of
*   these journeys, calls it D002. An exact READ TABLE therefore matched
*   nothing for the whole DOK family, silently: LONG( ) returns IV_DEFAULT
*   when it misses, so a declaration keyed 'D002' rendered as the field's
*   own one-word ZLABEL and looked like a field that had never been
*   configured. That is what it did.
*
*   A SEGMENT MATCH, not a substring one. The id is split on '_' and the
*   key has to equal a whole segment, so 'D001' does not also answer for
*   DOK_D0012_* - which a CS or CP test would have done. An exact match is
*   tried first and still wins, so 'EC01' against journey EC01 behaves
*   precisely as it did and so does every other family.
    CLASS-METHODS jny_match
      IMPORTING iv_key    TYPE string
                iv_journey TYPE string
      RETURNING VALUE(rv) TYPE abap_bool.

*   The catalogue number an @<ref> names, or BLANK when it does not name one.
*
*   THE CATCH THREE CALLERS RELIED ON NEVER FIRES, and that is the whole
*   reason this exists. Every one of them wrote CONV symsgno( lv_no ) inside
*   a TRY and documented the CATCH as the branch a non-numeric reference
*   takes. It does not: a character source assigned to a type N target has
*   its non-digits DISCARDED and the digits right-aligned, silently and with
*   no exception - so '@D001NOTE' does not fail, it becomes 001, and 001 is
*   C_NO-NEXT. D001's payment note rendered as the word "Next", which is a
*   real catalogue entry correctly served for a number nobody asked for.
*   There is nothing to notice: no dump, no blank, no token on screen, just
*   an unrelated sentence where a paragraph belongs.
*
*   A reference is a number only if it is one to three digits and nothing
*   else. Blank comes back otherwise, and the caller takes its own fallback
*   - which is the branch each of them already wrote and none of them
*   reached. '000' is never a catalogue entry (they start at C_NO-NEXT 001),
*   so an initial RV is unambiguous.
    CLASS-METHODS msgno_of
      IMPORTING iv_ref    TYPE string
      RETURNING VALUE(rv) TYPE symsgno.

    CLASS-METHODS catalogue
      RETURNING VALUE(rt_txt) TYPE tt_txt.

    CLASS-METHODS overrides
      RETURNING VALUE(rt_over) TYPE tt_over.

    CLASS-METHODS set_journey
      IMPORTING iv_journey TYPE string.

    CLASS-METHODS journey
      RETURNING VALUE(rv_journey) TYPE string.

    CLASS-METHODS get
      IMPORTING iv_no          TYPE symsgno
                iv_default     TYPE string
                iv_journey     TYPE string OPTIONAL
                iv_v1          TYPE string OPTIONAL
                iv_v2          TYPE string OPTIONAL
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS pick
      IMPORTING iv_base        TYPE string
                iv_ar          TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    CLASS-METHODS set_lang
      IMPORTING iv_lang TYPE sy-langu.

    CLASS-METHODS lang
      RETURNING VALUE(rv_lang) TYPE sy-langu.

    CLASS-METHODS is_arabic
      RETURNING VALUE(rv_ar) TYPE abap_bool.

    CLASS-METHODS rtl
      RETURNING VALUE(rv_rtl) TYPE abap_bool.

    CLASS-METHODS misses
      RETURNING VALUE(rt_miss) TYPE tt_miss.

    CLASS-METHODS reset.

  PRIVATE SECTION.

    CLASS-DATA gt_txt    TYPE tt_txt.
    CLASS-DATA gv_loaded TYPE abap_bool.
    CLASS-DATA gt_miss   TYPE tt_miss.
    CLASS-DATA gv_lang   TYPE sy-langu.
    CLASS-DATA gv_journey TYPE string.

ENDCLASS.



CLASS ZCL_RAK_TEXT IMPLEMENTATION.


  METHOD catalogue.
    rt_txt = VALUE tt_txt(
( msgno = c_no-next         en = `Next`                          ar = `التالي` )
      ( msgno = c_no-back         en = `Back`                          ar = `رجوع` )
      ( msgno = c_no-submit en = `Submit` ar = `تقديم` )
      ( msgno = c_no-pay          en = `Pay`                           ar = `دفع` )
      ( msgno = c_no-save_draft   en = `Save as Draft`                 ar = `حفظ كمسودة` )
      ( msgno = c_no-delete       en = `Delete`                        ar = `حذف` )
      ( msgno = c_no-edit         en = `Edit`                          ar = `تعديل` )
      ( msgno = c_no-waiting      en = `Waiting for payment`           ar = `في انتظار الدفع` )
      ( msgno = c_no-done         en = `Done`                          ar = `تم` )
      ( msgno = c_no-total        en = `Total`                         ar = `الإجمالي` )
      ( msgno = c_no-description  en = `Description`                   ar = `البيان` )
      ( msgno = c_no-amount       en = `Amount`                        ar = `المبلغ` )
      ( msgno = c_no-required     en = `&1 is required`                ar = `&1 مطلوب` )
      ( msgno = c_no-too_short
        en = `&1 must be at least &2 characters`
        ar = `يجب أن يحتوي &1 على &2 أحرف على الأقل` )
      ( msgno = c_no-too_long
        en = `&1 must be at most &2 characters`
        ar = `يجب ألا يتجاوز &1 &2 أحرف` )
*     &1, not a placeholder-free line - ZCL_RAK_JOURNEY_RULES's regex check
*     (its only caller) already passes IV_V1 = the field's label expecting
*     one, and already uses this exact English wording as ITS OWN IV_DEFAULT
*     fallback; the catalogue's own copy was the one place still missing it,
*     so the field name never actually appeared unless the DB table override
*     supplied its own &1.
      ( msgno = c_no-bad_format   en = `&1 has an invalid format`      ar = `صيغة &1 غير صحيحة` )
      ( msgno = c_no-choose_one   en = `Please make a selection`       ar = `يرجى تحديد أحد الخيارات` )
      ( msgno = c_no-upload en = `Upload` ar = `إرفاق` )
      ( msgno = c_no-attachments  en = `Attachments`                   ar = `المرفقات` )
      ( msgno = c_no-file_big     en = `The file is too large`         ar = `حجم الملف كبير جداً` )
      ( msgno = c_no-file_type en = `This file type is not allowed` ar = `نوع الملف غير مسموح به` )
      ( msgno = c_no-review       en = `Review`                        ar = `مراجعة` )
      ( msgno = c_no-no_entries en = `No records available.` ar = `لا توجد سجلات.` )
      ( msgno = c_no-add_row en = `Add row` ar = `إضافة صف` )
      ( msgno = c_no-remove_row   en = `Remove`                        ar = `إزالة` )
      ( msgno = c_no-search       en = `Search`                        ar = `بحث` )
      ( msgno = c_no-confirm      en = `Confirm`                       ar = `تأكيد` )
      ( msgno = c_no-cancel       en = `Cancel`                        ar = `إلغاء` )
      ( msgno = c_no-complete en = `Complete` ar = `إتمام` )
      ( msgno = c_no-select       en = `Select`                        ar = `تحديد` )
      ( msgno = c_no-selected en = `Selected` ar = `محدد` )
      ( msgno = c_no-view         en = `View`                          ar = `عرض` )
      ( msgno = c_no-filed en = `Filed` ar = `تم الإرفاق` )
      ( msgno = c_no-browse       en = `Browse`                        ar = `استعراض` )
      ( msgno = c_no-close        en = `Close`                         ar = `إغلاق` )
      ( msgno = c_no-use          en = `Use`                           ar = `استخدام` )
      ( msgno = c_no-nothing_req en = `Nothing required on this step.` ar = `لا يوجد شيء مطلوب في هذه الخطوة.` )
      ( msgno = c_no-del_title    en = `Delete application`            ar = `حذف الطلب` )
      ( msgno = c_no-del_warn
        en = `This permanently removes the application and any saved draft. This cannot be undone.`
        ar = `سيتم حذف الطلب وأي مسودة محفوظة نهائياً. لا يمكن التراجع عن هذا الإجراء.` )
      ( msgno = c_no-bp_find      en = `Find Business Partner`         ar = `البحث عن شريك تجاري` )
      ( msgno = c_no-bp_hint
        en = `Partner no. / name / Emirates ID (min. 3 characters)`
        ar = `رقم الشريك / الاسم / رقم الهوية (3 أحرف على الأقل)` )
      ( msgno = c_no-fb_title     en = `How was your experience?`      ar = `كيف كانت تجربتك؟` )
      ( msgno = c_no-fb_thanks    en = `Thanks for your feedback`      ar = `شكراً لملاحظاتك` )
      ( msgno = c_no-fb_send      en = `Send feedback`                 ar = `إرسال الملاحظات` )
      ( msgno = c_no-fb_skip      en = `Not now`                       ar = `ليس الآن` )
      ( msgno = c_no-fb_hint
        en = `Anything you would like us to know? (optional)`
        ar = `هل هناك ما تود إخبارنا به؟ (اختياري)` )
      ( msgno = c_no-fb_excellent en = `Excellent`                     ar = `ممتاز` )
      ( msgno = c_no-fb_good      en = `Good`                          ar = `جيد` )
      ( msgno = c_no-fb_average   en = `Average`                       ar = `متوسط` )
      ( msgno = c_no-fb_poor      en = `Poor`                          ar = `ضعيف` )
      ( msgno = c_no-fb_verypoor  en = `Very Poor`                     ar = `ضعيف جداً` )
      ( msgno = c_no-att_required en = `&1: attachment is required`    ar = `&1: المرفق مطلوب` )
      ( msgno = c_no-choose_file  en = `Choose file`                  ar = `اختر ملفاً` )
      ( msgno = c_no-num_min      en = `&1 must be at least &2`        ar = `يجب أن يكون &1 &2 على الأقل` )
      ( msgno = c_no-num_max      en = `&1 must be at most &2`         ar = `يجب ألا يتجاوز &1 &2` )
      ( msgno = c_no-not_number   en = `&1 must be a valid number`     ar = `يجب أن يكون &1 رقماً صحيحاً` )
      ( msgno = c_no-date_min     en = `&1 must be on or after &2`     ar = `يجب أن يكون &1 في &2 أو بعده` )
      ( msgno = c_no-date_max     en = `&1 must be on or before &2`    ar = `يجب أن يكون &1 في &2 أو قبله` )
      ( msgno = c_no-val_error    en = `Validation error: &1`          ar = `خطأ في التحقق: &1` )
      ( msgno = c_no-amount_aed   en = `Amount (AED)`                  ar = `المبلغ (درهم)` )
      ( msgno = c_no-pay_method   en = `Payment Method`                ar = `طريقة الدفع` )
      ( msgno = c_no-pay_with     en = `Pay with`                      ar = `الدفع عن طريق` )
      ( msgno = c_no-pay_now      en = `Pay now`                       ar = `ادفع الآن` )
      ( msgno = c_no-pay_received en = `Payment received`              ar = `تم استلام الدفعة` )
      ( msgno = c_no-pay_popup
        en = `Please allow browser pop-ups to enable payment`
        ar = `يرجى السماح بالنوافذ المنبثقة في المتصفح لإتمام الدفع` )
      ( msgno = c_no-pay_reopen   en = `Reopen payment page`           ar = `إعادة فتح صفحة الدفع` )
      ( msgno = c_no-pay_stop     en = `Stop waiting`                  ar = `إيقاف الانتظار` )
      ( msgno = c_no-pay_stopped
        en = `Stopped waiting. If you completed the payment it will still be recorded - reopen this application to check.`
        ar = `تم إيقاف الانتظار. إذا أتممت الدفع فسيتم تسجيله - أعد فتح الطلب للتحقق.` )
      ( msgno = c_no-pay_prep
        en = `Preparing your payment. This takes a few seconds.`
        ar = `جارٍ تحضير عملية الدفع. سيستغرق ذلك بضع ثوانٍ.` )
      ( msgno = c_no-pay_prep_wait
        en = `The payment page is still being prepared. One moment.`
        ar = `لا تزال صفحة الدفع قيد التحضير. لحظة من فضلك.` )
      ( msgno = c_no-pay_prep_fail
        en = `The payment could not be prepared. Press Pay to try again.`
        ar = `لم يتمكن النظام من تحضير عملية الدفع. اضغط دفع للمحاولة مرة أخرى.` )
      ( msgno = c_no-pay_notdone
        en = `Payment was not completed. You can try again.`
        ar = `لم يتم إتمام عملية الدفع. يمكنك المحاولة مرة أخرى.` )
      ( msgno = c_no-pay_inprog
        en = `A payment is already in progress for this application. Please wait a few minutes and try again.`
        ar = `هناك عملية دفع جارية لهذا الطلب بالفعل. يرجى الانتظار بضع دقائق والمحاولة مرة أخرى.` )
      ( msgno = c_no-pay_nofee
        en = `The fee for this application has not been raised yet, so the payment page cannot open. The application is saved - reopen it in a few minutes to pay.`
        ar = `لم يتم إصدار الرسوم لهذا الطلب بعد، لذلك لا يمكن فتح صفحة الدفع. تم حفظ الطلب - أعد فتحه بعد بضع دقائق للدفع.` )
      ( msgno = c_no-pay_first
        en = `Payment must be completed before submitting.`
        ar = `يجب إتمام عملية الدفع قبل الإرسال.` )
      ( msgno = c_no-pdf_none
        en = `No document to display yet.`
        ar = `لا يوجد مستند للعرض حتى الآن.` )
      ( msgno = c_no-bpp_title       en = `Partner Search`              ar = `البحث عن الشريك` )
      ( msgno = c_no-bpp_search_by   en = `Search By`                   ar = `البحث بواسطة` )
      ( msgno = c_no-bpp_eid         en = `Emirates ID`                 ar = `الهوية الإماراتية` )
      ( msgno = c_no-bpp_passport_ne
        en = `Passport (Non EID Holder only)`
        ar = `جواز السفر (لغير حاملي الهوية الإماراتية فقط)` )
      ( msgno = c_no-bpp_unified_ne
        en = `Unified ID (Non EID Holder only)`
        ar = `الرقم الموحد (لغير حاملي الهوية الإماراتية فقط)` )
      ( msgno = c_no-bpp_trade_lic   en = `Trade License Number`        ar = `رقم الرخصة التجارية` )
      ( msgno = c_no-bpp_passport_no en = `Passport Number`             ar = `رقم جواز السفر` )
      ( msgno = c_no-bpp_unified_id  en = `Unified ID`                  ar = `الرقم الموحد` )
      ( msgno = c_no-bpp_dob         en = `Date of Birth`               ar = `تاريخ الميلاد` )
      ( msgno = c_no-bpp_nat         en = `Nationality`                 ar = `الجنسية` )
      ( msgno = c_no-bpp_pass_type   en = `Passport Type`               ar = `نوع جواز السفر` )
      ( msgno = c_no-bpp_general     en = `General Info`                ar = `معلومات عامة` )
      ( msgno = c_no-bpp_contact     en = `Contact Info`                ar = `معلومات الاتصال` )
      ( msgno = c_no-bpp_address     en = `Address Info`                ar = `معلومات العنوان` )
      ( msgno = c_no-bpp_first_name  en = `First Name`                  ar = `الاسم الأول` )
      ( msgno = c_no-bpp_father_name en = `Father Name`                 ar = `اسم الأب` )
      ( msgno = c_no-bpp_grand_name  en = `Grandfather Name`            ar = `اسم الجد` )
      ( msgno = c_no-bpp_fourth_name en = `Fourth Name`                 ar = `الاسم الرابع` )
      ( msgno = c_no-bpp_last_name   en = `Last Name`                   ar = `اسم العائلة` )
      ( msgno = c_no-bpp_gender      en = `Gender`                      ar = `الجنس` )
      ( msgno = c_no-bpp_id_no       en = `ID Number`                   ar = `رقم الهوية` )
      ( msgno = c_no-bpp_id_exp      en = `ID Expiry date`              ar = `تاريخ انتهاء الهوية` )
      ( msgno = c_no-bpp_unified_num en = `Unified Number`              ar = `الرقم الموحد` )
      ( msgno = c_no-bpp_pp_issue    en = `Date of passport Issue`      ar = `تاريخ إصدار جواز السفر` )
      ( msgno = c_no-bpp_pp_country
        en = `Country of passport Issue`
        ar = `بلد إصدار جواز السفر` )
      ( msgno = c_no-bpp_pp_exp      en = `Passport Expiry Date`        ar = `تاريخ انتهاء جواز السفر` )
      ( msgno = c_no-bpp_occupation  en = `Occupation`                  ar = `المهنة` )
      ( msgno = c_no-bpp_mobile      en = `Mobile Number`               ar = `رقم الهاتف المتحرك` )
      ( msgno = c_no-bpp_email       en = `Email`                       ar = `البريد الإلكتروني` )
      ( msgno = c_no-bpp_telephone   en = `Telephone`                   ar = `الهاتف` )
      ( msgno = c_no-bpp_country     en = `Country Of Living`           ar = `بلد الإقامة` )
      ( msgno = c_no-bpp_region      en = `Region`                      ar = `المنطقة` )
      ( msgno = c_no-bpp_city        en = `City`                        ar = `المدينة` )
      ( msgno = c_no-bpp_street      en = `Street Name`                 ar = `اسم الشارع` )
      ( msgno = c_no-bpp_house_no    en = `Home Number`                 ar = `رقم المنزل` )
      ( msgno = c_no-bpp_pobox       en = `PO Box`                      ar = `صندوق البريد` )
      ( msgno = c_no-bpp_resume      en = `Resume Search`               ar = `استئناف البحث` )
      ( msgno = c_no-bpp_use_partner en = `Use this partner`            ar = `استخدام هذا الشريك` )
      ( msgno = c_no-bpp_partner_no  en = `Partner &1`                  ar = `الشريك &1` )
      ( msgno = c_no-bpp_partner     en = `Partner`                     ar = `الشريك` )
      ( msgno = c_no-bpp_phone       en = `Phone Number`                ar = `رقم الهاتف` )
*     TABLE COLUMN HEADERS - see the block comment on C_NO above.
*     SUGGESTION ID and MOBILE NUMBER carry the Arabic taken verbatim from
*     EC06's own LABEL_AR for the matching input fields, so the header and the
*     field it reports on read identically. The other four are standard terms;
*     DEPARTMENT in particular has more than one accepted rendering in RAK
*     government usage, so CONFIRM `الدائرة` with whoever owns the wording
*     before this goes to citizens.
      ( msgno = c_no-col_suggestion_id   en = `Suggestion ID`   ar = `رقم الاقتراح` )
      ( msgno = c_no-col_suggestion_date en = `Suggestion Date` ar = `تاريخ الاقتراح` )
      ( msgno = c_no-col_mobile_number   en = `Mobile Number`   ar = `رقم الهاتف` )
      ( msgno = c_no-col_name            en = `Name`            ar = `الاسم` )
      ( msgno = c_no-col_department      en = `Department`      ar = `الدائرة` )
      ( msgno = c_no-col_status          en = `Status`          ar = `الحالة` )
*     RESULT CARD - see the block comment on C_NO above. Standard renderings;
*     worth a wording pass by whoever owns the Arabic before they go live, the
*     same way the EC01 declaration is flagged.
      ( msgno = c_no-res_paid          en = `Payment received`     ar = `تم استلام الدفع` )
      ( msgno = c_no-res_submitted     en = `Application submitted` ar = `تم تقديم الطلب` )
      ( msgno = c_no-res_done_sub
        en = `We have everything we need. Keep the reference below for any follow-up.`
        ar = `لدينا كل ما نحتاجه. يرجى الاحتفاظ بالرقم المرجعي أدناه لأي متابعة.` )
      ( msgno = c_no-res_not_submitted en = `Not submitted yet`    ar = `لم يتم التقديم بعد` )
      ( msgno = c_no-res_not_sub_sub
        en = `This application has not been submitted. Go back and complete the remaining steps.`
        ar = `لم يتم تقديم هذا الطلب. يرجى الرجوع وإكمال الخطوات المتبقية.` )
*     EC02's headers. COMPLAINT ID and DESCRIPTION carry Arabic taken verbatim
*     from the journeys' own LABEL_AR (EC02's COMPLAINT_ID, EC05's
*     DESCRIPTION_1), so a header and the field it reports on read identically.
      ( msgno = c_no-col_complaint_id   en = `Complaint ID`   ar = `رقم الشكوى` )
      ( msgno = c_no-col_complaint_date en = `Complaint Date` ar = `تاريخ الشكوى` )
      ( msgno = c_no-col_description    en = `Description`    ar = `الوصف` )
      ( msgno = c_no-nav_locked
        en = `The fee has been paid, so the earlier steps are closed. Press Done to finish.`
        ar = `تم دفع الرسوم، لذلك أُغلقت الخطوات السابقة. اضغط "تم" لإكمال الطلب.` )
      ( msgno = c_no-cap_title
        en = `Verification`
        ar = `التحقق` )
*     "Five digits" and not "the code": the citizen is looking at a
*     deliberately distorted picture, and the one thing that makes it
*     quick to read is knowing how many characters to expect.
      ( msgno = c_no-cap_hint
        en = `Type the five digits shown below.`
        ar = `أدخل الأرقام الخمسة الظاهرة أدناه.` )
      ( msgno = c_no-cap_ph
        en = `5 digits`
        ar = `٥ أرقام` )
      ( msgno = c_no-cap_refresh
        en = `Show a different code`
        ar = `عرض رمز آخر` )
      ( msgno = c_no-cap_wrong
        en = `The verification code does not match. A new code is shown - please try again.`
        ar = `رمز التحقق غير مطابق. تم عرض رمز جديد - يرجى المحاولة مرة أخرى.` )
      ( msgno = c_no-opt_none
        en = `(none)`
        ar = `(بدون)` )
      ( msgno = c_no-not_authorized
        en = `Not authorized.`
        ar = `غير مصرح.` )
      ( msgno = c_no-not_auth_hint
        en = `Contact your administrator if you need access.`
        ar = `يرجى التواصل مع المسؤول إذا كنت بحاجة إلى الوصول.` )
      ( msgno = c_no-date_bad
        en = `&1 is not a valid date`
        ar = `&1 ليس تاريخاً صحيحاً` )
      ( msgno = c_no-sort_asc  en = `Sort Ascending`  ar = `ترتيب تصاعدي` )
      ( msgno = c_no-sort_desc en = `Sort Descending` ar = `ترتيب تنازلي` )
      ( msgno = c_no-cjs_read_only
        en = `Read-only on this client`
        ar = `للعرض فقط في هذا العميل` )
*     ==================================================================
*     THE DOK SCHOOL FAMILY - D001, D002, D011, D012
*     ==================================================================
*     EVERY ENGLISH STRING BELOW IS BYTE-IDENTICAL TO THE LITERAL IT
*     REPLACED, including the wording nobody would choose twice ("Kindly
*     enter shares as 100", the double space in D002's trade message).
*     This pass moves text, it does not edit it - an English reader must
*     see exactly the screen they saw yesterday, so that anything that
*     does change is known to be the Arabic.
*
*     THE ARABIC IS NEW AND NEEDS THE DEPARTMENT'S EYES, and the six
*     document names below need them most. CLAUDE.md's rule is that
*     migrated wording is read from the legacy text tables and never
*     hand-translated, because the department owns words the citizen
*     already knows from the live screen. These literals are in a
*     HAND-WRITTEN handler class, so they have no /QNV/SB_LABELT row to
*     read - but the six uploader labels almost certainly DO have one
*     under the legacy D001 screen, and a document's name on a government
*     form is a legal term, not a description. Check these against
*     /QNV/SB_LABELT before they go live; ZRAK_T_CJ_TXT rewords any of
*     them in SM30 with no developer and no activation.
      ( msgno = c_no-own_owner          en = `Owner`          ar = `المالك` )
      ( msgno = c_no-own_details        en = `Owner Details`  ar = `بيانات المالك` )
      ( msgno = c_no-own_add_owner      en = `Add Owner`      ar = `إضافة مالك` )
      ( msgno = c_no-own_col_name       en = `Owner Name`     ar = `اسم المالك` )
      ( msgno = c_no-own_col_email      en = `Email Address`  ar = `البريد الإلكتروني` )
      ( msgno = c_no-own_col_shares     en = `Owner Shares`   ar = `حصص المالك` )
      ( msgno = c_no-own_edit_tip
        en = `Edit owner details`
        ar = `تعديل بيانات المالك` )
      ( msgno = c_no-own_none_yet
        en = `No owners yet. Press Add Owner to enter the first one.`
        ar = `لا يوجد ملاك حتى الآن. اضغط "إضافة مالك" لإدخال الأول.` )
      ( msgno = c_no-own_identification en = `Identification` ar = `الهوية` )
*     Arabic copied verbatim from BPP_DOB - see the note at the constant.
      ( msgno = c_no-own_dob            en = `Birth Date`     ar = `تاريخ الميلاد` )
      ( msgno = c_no-own_shares_pct     en = `Shares %`       ar = `نسبة الحصص %` )
      ( msgno = c_no-own_documents      en = `Documents`      ar = `المستندات` )
      ( msgno = c_no-own_doc_eid
        en = `Emirates ID Copy`
        ar = `صورة الهوية الإماراتية` )
      ( msgno = c_no-own_doc_passport
        en = `Passport Copy`
        ar = `صورة جواز السفر` )
      ( msgno = c_no-own_doc_intro
        en = `Introductory Statement`
        ar = `بيان تعريفي` )
*     The lower-case "certificate" is the literal's own, kept deliberately.
      ( msgno = c_no-own_doc_criminal
        en = `Criminal Clearance certificate`
        ar = `شهادة حسن سيرة وسلوك` )
      ( msgno = c_no-own_doc_cv
        en = `Curriculum Vitae`
        ar = `السيرة الذاتية` )
      ( msgno = c_no-own_doc_family
        en = `Family Book`
        ar = `خلاصة القيد` )
      ( msgno = c_no-own_btn_add        en = `Add`            ar = `إضافة` )
      ( msgno = c_no-d001_need_owner
        en = `Add at least one owner before continuing.`
        ar = `يرجى إضافة مالك واحد على الأقل قبل المتابعة.` )
      ( msgno = c_no-d001_owner_incompl
        en = `Every owner needs a name, an e-mail address and a share percentage.`
        ar = `يجب إدخال الاسم والبريد الإلكتروني ونسبة الحصص لكل مالك.` )
      ( msgno = c_no-d001_need_stage
        en = `Select at least one education stage.`
        ar = `يرجى اختيار مرحلة تعليمية واحدة على الأقل.` )
      ( msgno = c_no-d001_fill_required
        en = `Kindly fill required details.`
        ar = `يرجى تعبئة البيانات المطلوبة.` )
*     REWORDED ON REQUEST. Was "Kindly enter shares as 100", which told the
*     citizen the total rather than naming the field they had left empty -
*     and it fires when SHARE_PER is BLANK, not when the shares fail to sum.
      ( msgno = c_no-d001_shares_100
        en = `Kindly enter Share %`
        ar = `يرجى إدخال نسبة الحصص %` )
      ( msgno = c_no-d001_eid_format
        en = `Emirates ID must be in the format 784-XXXX-XXXXXXX-X.`
        ar = `يجب أن تكون الهوية الإماراتية بالصيغة 784-XXXX-XXXXXXX-X.` )
*     &1 IS THE DOCUMENT'S NAME AND IT COMES FROM CONFIG, so it arrives in
*     whatever language the option row holds - the placeholder is not
*     translated here and must stay a placeholder.
      ( msgno = c_no-d001_upload_doc
        en = `Please upload &1.`
        ar = `يرجى إرفاق &1.` )
*     &1 is the Emirates ID just entered - a number, the same in both.
      ( msgno = c_no-d001_owner_added
        en = `&1 added to the owner list.`
        ar = `تمت إضافة &1 إلى قائمة الملاك.` )
*     &1 is the minimum character count.
      ( msgno = c_no-d002_search_min
        en = `Enter at least &1 characters to search`
        ar = `أدخل &1 أحرف على الأقل للبحث` )
*     REWORDED ON REQUEST, and it now matches the field's own label, which
*     is "Trade License Number" - the message used to call the same thing a
*     Trade ID.
      ( msgno = c_no-d002_trade_enter
        en = `Enter Trade License Number`
        ar = `أدخل رقم الرخصة التجارية` )
*     The double space after "No" is the literal's own and is kept so the
*     English is unchanged. Worth correcting in SM30, not in this pass.
      ( msgno = c_no-d002_trade_nobp
        en = `No  valid Business Partner Found for Entered Trade ID`
        ar = `لم يتم العثور على شريك تجاري صحيح لرقم الرخصة المدخل` )
      ( msgno = c_no-d011_need_type
        en = `Select at least one advertisement type.`
        ar = `يرجى اختيار نوع إعلان واحد على الأقل.` )
      ( msgno = c_no-d011_end_before
        en = `The advertisement end date cannot be before the start date.`
        ar = `لا يمكن أن يكون تاريخ انتهاء الإعلان قبل تاريخ بدايته.` )
      ( msgno = c_no-d011_reselect_cons
        en = `Re-select the consent answer before continuing.`
        ar = `يرجى إعادة اختيار إجابة الموافقة قبل المتابعة.` )
      ( msgno = c_no-d012_need_grade
        en = `Select at least one targeted grade.`
        ar = `يرجى اختيار صف مستهدف واحد على الأقل.` )
      ( msgno = c_no-d012_end_after
        en = `The activity must end after it starts.`
        ar = `يجب أن ينتهي النشاط بعد وقت بدايته.` )
      ( msgno = c_no-d012_end_before
        en = `The activity end date cannot be before the start date.`
        ar = `لا يمكن أن يكون تاريخ انتهاء النشاط قبل تاريخ بدايته.` )
*     FRAMEWORK. &1 is the extension list and stays untranslated - PDF and
*     JPG are file formats, not words.
      ( msgno = c_no-att_hint
        en = `&1 · up to &2 MB`
        ar = `&1 · حتى &2 ميجابايت` )
*     &1 is the grid's own label, already bilingual from ZLABEL_AR.
      ( msgno = c_no-grid_add
        en = `Add &1`
        ar = `إضافة &1` )
*     D001's BUILDINGS grid. "Block" is the campus building block - worth
*     confirming against the department's own word, which may be كتلة.
      ( msgno = c_no-col_block_name en = `Block Name`    ar = `اسم المبنى` )
      ( msgno = c_no-col_floors     en = `No. of floors` ar = `عدد الطوابق` )
      ( msgno = c_no-col_rooms      en = `No. of rooms`  ar = `عدد الغرف` )
      ( msgno = c_no-draft_saved
        en = `Saved as draft`
        ar = `تم الحفظ كمسودة` )
*     &1 is the case number, never the journey key - see the engine.
      ( msgno = c_no-draft_saved_ref
        en = `Saved as draft - &1`
        ar = `تم الحفظ كمسودة - &1` )
*     &1 is the field's own LABEL, which is already bilingual.
      ( msgno = c_no-att_suffix  en = `&1 - attachment`     ar = `&1 - مرفق` )
      ( msgno = c_no-att_support en = `Supporting document` ar = `مستند داعم` ) ).
  ENDMETHOD.


  METHOD get.
    IF gv_loaded = abap_false.
      gt_txt = catalogue( ).

      SELECT msgno, text_en, text_ar FROM zrak_t_cj_txt
        INTO TABLE @DATA(lt_db).

      LOOP AT lt_db INTO DATA(ls_db).
        READ TABLE gt_txt ASSIGNING FIELD-SYMBOL(<ls_t>)
             WITH TABLE KEY msgno = ls_db-msgno.
        IF sy-subrc <> 0.
          INSERT VALUE ty_txt( msgno = ls_db-msgno
                               en    = ls_db-text_en
                               ar    = ls_db-text_ar ) INTO TABLE gt_txt.
          CONTINUE.
        ENDIF.
        IF ls_db-text_en IS NOT INITIAL.
          <ls_t>-en = ls_db-text_en.
        ENDIF.
        IF ls_db-text_ar IS NOT INITIAL.
          <ls_t>-ar = ls_db-text_ar.
        ENDIF.
      ENDLOOP.

      gv_loaded = abap_true.
    ENDIF.

    DATA(lv_jny) = COND string( WHEN iv_journey IS NOT INITIAL
                                THEN to_upper( iv_journey )
                                ELSE gv_journey ).

    IF lv_jny IS NOT INITIAL.
*     THROUGH JNY_MATCH( ) FOR THE SAME REASON LONG( ) IS - see the note at
*     its declaration. An override keyed 'D002' against a running journey
*     called DOK_D002_SCHOOL_LIC_NEW missed, silently, and the catalogue's
*     generic wording was served instead of the journey's own.
      DATA ls_ov TYPE ty_over.
      DATA(lt_ov) = overrides( ).
      LOOP AT lt_ov INTO DATA(ls_ovt).
        IF ls_ovt-msgno = iv_no AND jny_match( iv_key = ls_ovt-journey_id iv_journey = lv_jny ) = abap_true.
          ls_ov = ls_ovt.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF ls_ov IS NOT INITIAL.
        IF is_arabic( ) = abap_true AND ls_ov-ar IS NOT INITIAL.
          rv_text = ls_ov-ar.
        ELSE.
          rv_text = ls_ov-en.
        ENDIF.
        IF iv_v1 IS SUPPLIED.
          REPLACE FIRST OCCURRENCE OF '&1' IN rv_text WITH iv_v1.
        ENDIF.
        IF iv_v2 IS SUPPLIED.
          REPLACE FIRST OCCURRENCE OF '&2' IN rv_text WITH iv_v2.
        ENDIF.
        RETURN.
      ENDIF.
    ENDIF.

    READ TABLE gt_txt INTO DATA(ls_txt) WITH TABLE KEY msgno = iv_no.
    DATA(lv_found) = xsdbool( sy-subrc = 0 ).

    IF lv_found = abap_false.
      rv_text = iv_default.
    ELSEIF is_arabic( ) = abap_true AND ls_txt-ar IS NOT INITIAL.
      rv_text = ls_txt-ar.
    ELSEIF ls_txt-en IS NOT INITIAL.
      rv_text = ls_txt-en.
    ELSE.
      rv_text = iv_default.
    ENDIF.

    IF lv_found = abap_false
       OR ( is_arabic( ) = abap_true AND ls_txt-ar IS INITIAL ).
      IF NOT line_exists( gt_miss[ msgno = iv_no ] ).
        APPEND VALUE ty_miss( msgno = iv_no english = rv_text ) TO gt_miss.
      ENDIF.
    ENDIF.

    IF iv_v1 IS SUPPLIED.
      REPLACE FIRST OCCURRENCE OF '&1' IN rv_text WITH iv_v1.
    ENDIF.
    IF iv_v2 IS SUPPLIED.
      REPLACE FIRST OCCURRENCE OF '&2' IN rv_text WITH iv_v2.
    ENDIF.
  ENDMETHOD.


  METHOD is_arabic.
    rv_ar = xsdbool( lang( ) = c_langu_ar ).
  ENDMETHOD.


  METHOD journey.
    rv_journey = gv_journey.
  ENDMETHOD.


  METHOD lang.
    rv_lang = COND #( WHEN gv_lang IS NOT INITIAL THEN gv_lang ELSE sy-langu ).
  ENDMETHOD.


  METHOD long_texts.
*   EC01 - the File Complaint certification.
*
*   ZLABEL held this at exactly 150 characters, cut by the INSERT that
*   wrote it: "...I understand that I will be held responsible for". The
*   rest of the sentence is not hidden by the renderer, it is absent from
*   ZRAK_T_JNY_FLD, so it had to be re-supplied rather than recovered.
*   XCHECK rule X13 named the field: DECLARATION, on step S1.
*
*   >> THE CLOSING CLAUSE IS A RECONSTRUCTION. CONFIRM IT. <<
*
*   Everything up to "held responsible for" is verbatim from the database.
*   What follows it - "any incorrect or false information provided" - was
*   written here to close the sentence, because the original wording no
*   longer exists anywhere to copy from. It is deliberately the most
*   conservative ending available: it completes the grammar and adds no
*   obligation, consequence or penalty that the visible half did not
*   already imply. If the approved text says more than that - rejection of
*   the application, legal liability, anything - this is understating it
*   and must be replaced with the real wording. A citizen is agreeing to
*   this sentence.
*
*   The Arabic is a translation of the same reconstruction and carries the
*   same caveat.
*   THE SCHOOL DECLARATION, ONCE, FOR FOUR JOURNEYS.
*   D002, D011 and D012 build the identical sentence in their own BAdIs
*   under WHEN 'DECLARATION_NAME' - the same words, both languages - and
*   D001's is the same text again. Four copies of four hundred characters
*   in one table is four chances for them to drift, so it is written here
*   once and referenced below.
*
*   STILL FOUR ROWS, NOT ONE SHARED KEY. LONG( ) reads journey plus field,
*   and a department that wants to reword its own declaration should be
*   able to without touching the other three. The text is shared; the
*   entries are not.
    DATA(lv_decl_en) =
      `I, {APPLICANTNAME} as the company owner, hereby declare that all ` &&
      `information provided in this application and in attached documents ` &&
      `are true and accurate, that I will be responsible for any consequences ` &&
      `of them, and I will be abide by all relevant regular conditions, ` &&
      `instructions and guidelines to avoid legal action in case of violations ` &&
      `and that I authorize our representative to follow up all the related ` &&
      `to the activity.`.
    DATA(lv_decl_ar) =
      `أنا، {APPLICANTNAME} بصفتي مالك الشركة، أقر بموجب هذا أن جميع ` &&
      `المعلومات المقدمة في هذا الطلب والمستندات المرفقة صحيحة ودقيقة، ` &&
      `وأنني سأكون مسؤولاً عن أي عواقب تترتب عليها، وسوف ألتزم بجميع ` &&
      `الشروط والتعليمات والمبادئ التوجيهية النظامية ذات الصلة لتجنب ` &&
      `اتخاذ الإجراءات القانونية في حالة وجود مخالفات وأنني أفوض مندوبنا ` &&
      `بمتابعة كل ما يتعلق بالنشاط.`.

*   The same sentence with the token the OTHER three journeys can answer.
*   REPLACE and not a second copy, so a reword lands in both.
    DATA(lv_decl_o_en) = replace( val  = lv_decl_en
                                  sub  = `{APPLICANTNAME}`
                                  with = `{APP_NAME}` ).
    DATA(lv_decl_o_ar) = replace( val  = lv_decl_ar
                                  sub  = `{APPLICANTNAME}`
                                  with = `{APP_NAME}` ).

    rt_long = VALUE tt_long(
      ( journey_id = 'EC01'
        field_name = 'DECLARATION'
        en         = `I hereby certify that the information provided in this form is accurate, ` &&
                     `complete, correct, and true. I understand that I will be held responsible ` &&
                     `for any incorrect or false information provided.`
        ar         = `أقر بأن المعلومات المقدمة في هذا النموذج دقيقة وكاملة وصحيحة وحقيقية. ` &&
                     `وأتفهم أنني سأكون مسؤولاً عن أي معلومات غير صحيحة أو كاذبة يتم تقديمها.` )

*     EC05 - the Give Suggestions certification. ECOMP-41.
*
*     THE SAME TRUNCATION, ON BOTH COLUMNS THIS TIME, and the config proves it
*     rather than suggesting it: EC05's ZLABEL is exactly 150 characters and
*     ends "...I would be held responsible for", while ZLABEL_AR is exactly 80
*     and stops mid-word at "وبالتا" - the opening of "وبالتالي". 150 and 80 are
*     the two DDIC widths, so both were cut by the INSERT that wrote them. The
*     Arabic reader saw it worse because the Arabic column was the shorter one.
*
*     >> BOTH CLOSING CLAUSES ARE RECONSTRUCTIONS. CONFIRM THEM. <<
*
*     Everything up to "responsible for" / "وبالتا" is verbatim from the
*     database. What follows was written here to close the sentence, in EC05's
*     own phrasing rather than EC01's - the two declarations are worded
*     differently and should not be silently merged. As with EC01 it is the
*     most conservative ending available: it completes the grammar and adds no
*     obligation, consequence or penalty the visible half did not already
*     imply. A citizen is agreeing to this sentence. If the approved wording
*     says more, this understates it and must be replaced.
      ( journey_id = 'EC05'
        field_name = 'DECLARATION'
        en         = `I hereby certify that the information provided on this form is accurately ` &&
                     `described, complete, correct and true. Thus, I would be held responsible ` &&
                     `for any incorrect or false information provided.`
        ar         = `أقر بموجب هذا أن جميع المعلومات المقدمة في هذا الطلب صحيحة ودقيقة وكاملة، ` &&
                     `وبالتالي أتحمل المسؤولية عن أي معلومات غير صحيحة أو مضللة.` )

*     D001 - THE SCHOOL LICENCE DECLARATION, AND UNLIKE EC01 ABOVE THIS ONE
*     IS NOT RECONSTRUCTED. It is copied verbatim from the department's own
*     BAdI implementations - ZCL_EGA_CJ_ENH_IMPL_D002, _D011 and _D012 all
*     build the identical sentence under WHEN 'DECLARATION_NAME', in both
*     languages. That is the wording the citizen already sees on the live
*     screen, which is exactly what "as per current application" asked for.
*
*     WHY D001'S FIELD SHOWED SOMETHING ELSE ENTIRELY. Its DEFAULT_VAL reads
*     TEXT:@D001DECL, and the @ branch of LONG_TEXT( ) used to do
*     CONV symsgno( 'D001DECL' ) inside a TRY. This comment used to say the
*     conversion fails and the TRY swallows it; it does not fail. A character
*     source assigned to a type N target has its non-digits DISCARDED, so
*     'D001DECL' becomes 001 - C_NO-NEXT - and the catalogue correctly served
*     the word "Next" for a number nobody asked for. Same for D001's PAYNOTE,
*     TEXT:@D001NOTE, which also reduces to 001. MSGNO_OF( ) is the guard now
*     and the declaration was never rendering at all before it.
*
*     SO IT LIVES HERE RATHER THAN IN A @nnn ROW, and that is the better
*     home regardless: ZRAK_T_CJ_TXT is CHAR255 and this sentence is over
*     four hundred characters, so a text row could not have held it whole.
*     Clearing DEFAULT_VAL is the config half - see the note handed over
*     with this change.
*
*     {APPLICANTNAME} IS SUBSTITUTED BY SUBST_FIELDS( ), which the LONG( )
*     branch of LONG_TEXT( ) already calls. The legacy builds the same
*     thing by CONCATENATEing GS_DATA-PARTNER_NAME.
*
*     ONE DEPARTURE FROM THE LEGACY, AND IT IS A DEFECT THERE. All three
*     BAdIs prefix the ARABIC sentence with the English literal 'I,' -
*     CONCATENATE 'I,' gs_data-partner_name '<arabic>' - so an Arabic
*     reader gets "I, <name> بصفتي مالك الشركة...". The Arabic below opens
*     with أنا، instead. Everything after the name is verbatim.
      ( journey_id = 'D001' field_name = 'DECLARE'
        en = lv_decl_en ar = lv_decl_ar )
*     D002, D011 AND D012 HAD NO DECLARATION ON SCREEN AT ALL. Their BAdIs
*     build one - the sentence above - and CJS never drew it, because none
*     of the three carries a DECLARE field in ZRAK_T_JNY_FLD the way D001
*     does. So the legacy screens ask the citizen to declare and the CJS
*     versions did not, which is a compliance gap rather than a cosmetic
*     one.
*
*     THE ENTRY ALONE IS NOT ENOUGH. Each journey still needs a CHECKBOX
*     field named DECLARE on its last input step, REQUIRED, with
*     DEFAULT_VAL left EMPTY - a TEXT: default is never seeded as a value,
*     and anything else there would render the box pre-ticked and pass its
*     own required check.
*     AND THE PLACEHOLDER IS NOT THE SAME FIELD ON ALL FOUR. D001 calls the
*     applicant's name APPLICANTNAME; D002, D011 and D012 all call it
*     APP_NAME. SUBST_FIELDS( ) resolves {NAME} by asking GET_VAL( NAME ),
*     and a field the journey does not have answers BLANK AND SILENT - so
*     sharing D001's token verbatim would have given the other three a
*     declaration that names nobody, with nothing anywhere to say why.
*
*     Swapped rather than duplicated: one sentence, one place to reword it,
*     and the token corrected per journey.
      ( journey_id = 'D002' field_name = 'DECLARE'
        en = lv_decl_o_en ar = lv_decl_o_ar )
      ( journey_id = 'D011' field_name = 'DECLARE'
        en = lv_decl_o_en ar = lv_decl_o_ar )
      ( journey_id = 'D012' field_name = 'DECLARE'
        en = lv_decl_o_en ar = lv_decl_o_ar ) ).
  ENDMETHOD.


  METHOD long.
    rv_text = iv_default.
    IF iv_journey IS INITIAL OR iv_field IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_fld)  = to_upper( iv_field ).
    DATA(lt_long) = long_texts( ).
    DATA ls_long TYPE ty_long.
    LOOP AT lt_long INTO DATA(ls_try).
      IF ls_try-field_name <> lv_fld.
        CONTINUE.
      ENDIF.
      IF jny_match( iv_key = ls_try-journey_id iv_journey = iv_journey ) = abap_true.
        ls_long = ls_try.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF ls_long IS INITIAL.
      RETURN.
    ENDIF.

    IF is_arabic( ) = abap_true AND ls_long-ar IS NOT INITIAL.
      rv_text = ls_long-ar.
    ELSEIF ls_long-en IS NOT INITIAL.
      rv_text = ls_long-en.
    ENDIF.
  ENDMETHOD.


  METHOD msgno_of.
*   See the note at the declaration.
    DATA(lv) = condense( iv_ref ).
    IF lv IS INITIAL OR strlen( lv ) > 3 OR lv CN '0123456789'.
      RETURN.
    ENDIF.
    rv = lv.
  ENDMETHOD.


  METHOD jny_match.
*   See the note at the declaration. Exact first, then whole-segment.
    DATA(lv_key) = to_upper( condense( iv_key ) ).
    DATA(lv_jny) = to_upper( condense( iv_journey ) ).
    IF lv_key IS INITIAL OR lv_jny IS INITIAL.
      RETURN.
    ENDIF.
    IF lv_key = lv_jny.
      rv = abap_true.
      RETURN.
    ENDIF.
    SPLIT lv_jny AT '_' INTO TABLE DATA(lt_seg).
    LOOP AT lt_seg INTO DATA(lv_seg).
      IF lv_seg = lv_key.
        rv = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD misses.
    rt_miss = gt_miss.
  ENDMETHOD.


  METHOD overrides.
    rt_over = VALUE tt_over(
      ( journey_id = 'EC01'
        msgno      = c_no-del_warn
        en         = `This permanently removes the complaint and any saved draft. This cannot be undone.`
        ar         = `سيتم حذف الشكوى وأي مسودة محفوظة نهائياً. لا يمكن التراجع عن هذا الإجراء.` ) ).
  ENDMETHOD.


  METHOD pick.
    IF is_arabic( ) = abap_true AND iv_ar IS NOT INITIAL.
      rv_text = iv_ar.
    ELSE.
      rv_text = iv_base.
    ENDIF.
  ENDMETHOD.


  METHOD reset.
    CLEAR gt_txt.
    CLEAR gt_miss.
    gv_loaded = abap_false.
  ENDMETHOD.


  METHOD rtl.
    rv_rtl = is_arabic( ).
  ENDMETHOD.


  METHOD set_journey.
    gv_journey = to_upper( iv_journey ).
  ENDMETHOD.


  METHOD set_lang.
    gv_lang = iv_lang.
  ENDMETHOD.
ENDCLASS.
