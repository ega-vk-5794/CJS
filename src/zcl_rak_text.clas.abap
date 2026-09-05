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
        ar = `رمز التحقق غير مطابق. تم عرض رمز جديد - يرجى المحاولة مرة أخرى.` ) ).
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
      READ TABLE overrides( ) INTO DATA(ls_ov)
           WITH KEY journey_id = lv_jny msgno = iv_no.
      IF sy-subrc = 0.
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
                     `وبالتالي أتحمل المسؤولية عن أي معلومات غير صحيحة أو مضللة.` ) ).
  ENDMETHOD.


  METHOD long.
    rv_text = iv_default.
    IF iv_journey IS INITIAL OR iv_field IS INITIAL.
      RETURN.
    ENDIF.

    READ TABLE long_texts( ) INTO DATA(ls_long)
         WITH KEY journey_id = to_upper( iv_journey )
                  field_name = to_upper( iv_field ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF is_arabic( ) = abap_true AND ls_long-ar IS NOT INITIAL.
      rv_text = ls_long-ar.
    ELSEIF ls_long-en IS NOT INITIAL.
      rv_text = ls_long-en.
    ENDIF.
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
