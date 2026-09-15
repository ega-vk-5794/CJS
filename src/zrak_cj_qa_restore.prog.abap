*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_QA_RESTORE
*&---------------------------------------------------------------------*
* Puts back the three portal tables that were deleted in QA on
* 15.09.2026 at 16:20:30-16:24:04 by VIKRAM.K (SE24 /
* SETS_CLASS_TEST_ENTRY): ZEGA_T_CJ_GRP, ZEGA_T_CJ_IDT, ZEGA_T_CJ_ID.
*
* WHERE THE VALUES COME FROM
*   From QA's OWN change documents (SCU3 export of the delete), not
*   from DEV. That distinction is the whole point: DEV was supplied as
*   a reference and it does NOT match QA. QA held 35 journeys, DEV
*   holds 58; E142 and E146 exist in QA only; and five ZEGA_T_CJ_GRP
*   rows carry a different ORDERNO in QA than in DEV -
*
*     23/R160/D001  QA 3, DEV 1      23/R098/D014  QA 2, DEV 1
*     23/R160/D002  QA 4, DEV 2      23/R160/D016  QA 2, DEV 4
*     23/R160/D003  QA 1, DEV 3
*
*   so a copy of DEV would have restored the wrong tile order. Every
*   other field that appears in both agrees exactly, which is what
*   makes the change-log reading trustworthy.
*
* WHAT THE LOG DID NOT CARRY, AND WHAT WAS DONE ABOUT IT
*   MANDT      - written as SY-MANDT. Run this IN the QA client.
*   POPULAR    - logged and blank. Restored blank (blank in DEV too).
*   ANONYMOUS  - logged and blank. Restored blank (blank in DEV too).
*   ZEGA_T_CJ_ID-DESCRIPTION - the ONLY field not in the log at all.
*                It is filled from the journey's English ZEGA_T_CJ_IDT
*                text, because in DEV those two are identical for all
*                58 rows without exception. Untick P_DESC to leave the
*                column blank instead.
*
* Test run is the default. Nothing is written until you untick it.
* Re-runnable: a row that is already back and already correct is
* counted and skipped, never inserted twice.
*&---------------------------------------------------------------------*
REPORT zrak_cj_qa_restore.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_grp  TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_idt  TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_id   TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_desc TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_over TYPE abap_bool AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

TYPES: BEGIN OF ty_grp,
         department TYPE zega_t_cj_grp-department,
         groupid    TYPE zega_t_cj_grp-groupid,
         journeyid  TYPE zega_t_cj_grp-journeyid,
         levelno    TYPE zega_t_cj_grp-levelno,
         orderno    TYPE zega_t_cj_grp-orderno,
         drilldown  TYPE zega_t_cj_grp-drilldown,
       END OF ty_grp,
       tt_grp TYPE STANDARD TABLE OF ty_grp WITH EMPTY KEY.

TYPES: BEGIN OF ty_idt,
         spras       TYPE zega_t_cj_idt-spras,
         journeyid   TYPE zega_t_cj_idt-journeyid,
         description TYPE zega_t_cj_idt-description,
       END OF ty_idt,
       tt_idt TYPE STANDARD TABLE OF ty_idt WITH EMPTY KEY.

TYPES: BEGIN OF ty_id,
         journeyid TYPE zega_t_cj_id-journeyid,
         sip_code  TYPE zega_t_cj_id-sip_code,
       END OF ty_id,
       tt_id TYPE STANDARD TABLE OF ty_id WITH EMPTY KEY.

DATA gv_ins TYPE i.
DATA gv_ok  TYPE i.
DATA gv_dif TYPE i.
DATA gv_upd TYPE i.

* ---------------------------------------------------------------------
* ZEGA_T_CJ_GRP - 128 rows, exactly as the change log recorded them.
* DRILLDOWN is 'N' on every one; ICON was logged blank on every one and
* is therefore not carried here at all.
* ---------------------------------------------------------------------
FORM f_grp_data CHANGING ct TYPE tt_grp.
  ct = VALUE #(
    ( department = '6' groupid = '109' journeyid = 'E027' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '6' groupid = 'R099' journeyid = 'E014' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '6' groupid = 'R099' journeyid = 'E015' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '6' groupid = 'R099' journeyid = 'E142' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '6' groupid = 'R099' journeyid = 'E146' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '6' groupid = 'R101' journeyid = 'E016' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '6' groupid = 'R101' journeyid = 'E017' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '6' groupid = 'R101' journeyid = 'E018' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '6' groupid = 'R101' journeyid = 'E019' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '6' groupid = 'R101' journeyid = 'E020' levelno = 2 orderno = 5 drilldown = 'N' )
    ( department = '6' groupid = 'R102' journeyid = 'E021' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '6' groupid = 'R102' journeyid = 'E022' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '6' groupid = 'R103' journeyid = 'E026' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = '280' journeyid = 'D004' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = '281' journeyid = 'D010' levelno = 1 orderno = 4 drilldown = 'N' )
    ( department = '23' groupid = '281' journeyid = 'D012' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = '281' journeyid = 'D021' levelno = 1 orderno = 7 drilldown = 'N' )
    ( department = '23' groupid = '283' journeyid = 'D007' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = '283' journeyid = 'D008' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = '284' journeyid = 'D027' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = 'R097' journeyid = 'D013' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = 'R098' journeyid = 'D014' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = 'R160' journeyid = 'D001' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '23' groupid = 'R160' journeyid = 'D002' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '23' groupid = 'R160' journeyid = 'D003' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = 'R160' journeyid = 'D016' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = 'R161' journeyid = 'D005' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = 'R161' journeyid = 'D006' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = 'R161' journeyid = 'D009' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '23' groupid = 'R170' journeyid = 'D020' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = 'R801' journeyid = 'D022' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '23' groupid = 'R801' journeyid = 'D024' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '23' groupid = 'R801' journeyid = 'D025' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '23' groupid = 'R801' journeyid = 'D026' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '23' groupid = 'RD01' journeyid = 'D028' levelno = 1 orderno = 3 drilldown = 'N' )
    ( department = '29' groupid = '280' journeyid = 'D004' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = '281' journeyid = 'D010' levelno = 1 orderno = 4 drilldown = 'N' )
    ( department = '29' groupid = '281' journeyid = 'D012' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = '281' journeyid = 'D021' levelno = 1 orderno = 7 drilldown = 'N' )
    ( department = '29' groupid = '283' journeyid = 'D007' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = '283' journeyid = 'D008' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = '284' journeyid = 'D027' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = 'R097' journeyid = 'D013' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = 'R160' journeyid = 'D003' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = 'R160' journeyid = 'D016' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = 'R161' journeyid = 'D005' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = 'R161' journeyid = 'D006' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = 'R161' journeyid = 'D009' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '29' groupid = 'R170' journeyid = 'D020' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = 'R801' journeyid = 'D022' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '29' groupid = 'R801' journeyid = 'D024' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '29' groupid = 'R801' journeyid = 'D025' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '29' groupid = 'R801' journeyid = 'D026' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '30' groupid = '284' journeyid = 'D027' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '30' groupid = 'R801' journeyid = 'D022' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '30' groupid = 'R801' journeyid = 'D024' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '30' groupid = 'R801' journeyid = 'D025' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '30' groupid = 'R801' journeyid = 'D026' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '31' groupid = 'R099' journeyid = 'E014' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '31' groupid = 'R099' journeyid = 'E015' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '31' groupid = 'R099' journeyid = 'E142' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '31' groupid = 'R099' journeyid = 'E146' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '31' groupid = 'R101' journeyid = 'E016' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '31' groupid = 'R101' journeyid = 'E017' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '31' groupid = 'R101' journeyid = 'E018' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '31' groupid = 'R101' journeyid = 'E019' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '31' groupid = 'R101' journeyid = 'E020' levelno = 2 orderno = 5 drilldown = 'N' )
    ( department = '31' groupid = 'R102' journeyid = 'E021' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '31' groupid = 'R102' journeyid = 'E022' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '31' groupid = 'R103' journeyid = 'E026' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '32' groupid = 'R099' journeyid = 'E014' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '32' groupid = 'R099' journeyid = 'E015' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '32' groupid = 'R099' journeyid = 'E142' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '32' groupid = 'R099' journeyid = 'E146' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '32' groupid = 'R101' journeyid = 'E016' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '32' groupid = 'R101' journeyid = 'E017' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '32' groupid = 'R101' journeyid = 'E018' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '32' groupid = 'R101' journeyid = 'E019' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '32' groupid = 'R101' journeyid = 'E020' levelno = 2 orderno = 5 drilldown = 'N' )
    ( department = '32' groupid = 'R102' journeyid = 'E021' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '32' groupid = 'R102' journeyid = 'E022' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '32' groupid = 'R103' journeyid = 'E026' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '33' groupid = 'R099' journeyid = 'E014' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '33' groupid = 'R099' journeyid = 'E015' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '33' groupid = 'R099' journeyid = 'E142' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '33' groupid = 'R099' journeyid = 'E146' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '33' groupid = 'R101' journeyid = 'E016' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '33' groupid = 'R101' journeyid = 'E017' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '33' groupid = 'R101' journeyid = 'E018' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '33' groupid = 'R101' journeyid = 'E019' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '33' groupid = 'R101' journeyid = 'E020' levelno = 2 orderno = 5 drilldown = 'N' )
    ( department = '33' groupid = 'R102' journeyid = 'E021' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '33' groupid = 'R102' journeyid = 'E022' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '33' groupid = 'R103' journeyid = 'E026' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '34' groupid = '109' journeyid = 'E027' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '34' groupid = 'R103' journeyid = 'E026' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = '280' journeyid = 'D004' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = '281' journeyid = 'D010' levelno = 1 orderno = 4 drilldown = 'N' )
    ( department = '35' groupid = '281' journeyid = 'D012' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = '281' journeyid = 'D021' levelno = 1 orderno = 7 drilldown = 'N' )
    ( department = '35' groupid = '283' journeyid = 'D007' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = '283' journeyid = 'D008' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = '284' journeyid = 'D027' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = 'R097' journeyid = 'D013' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = 'R160' journeyid = 'D003' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = 'R161' journeyid = 'D005' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = 'R161' journeyid = 'D006' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = 'R161' journeyid = 'D009' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '35' groupid = 'R170' journeyid = 'D020' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = 'R801' journeyid = 'D022' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '35' groupid = 'R801' journeyid = 'D024' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '35' groupid = 'R801' journeyid = 'D025' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '35' groupid = 'R801' journeyid = 'D026' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '36' groupid = '280' journeyid = 'D004' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = '281' journeyid = 'D010' levelno = 1 orderno = 4 drilldown = 'N' )
    ( department = '36' groupid = '281' journeyid = 'D012' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = '283' journeyid = 'D007' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '36' groupid = '283' journeyid = 'D008' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = '284' journeyid = 'D027' levelno = 1 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = 'R097' journeyid = 'D013' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '36' groupid = 'R160' journeyid = 'D003' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '36' groupid = 'R161' journeyid = 'D005' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '36' groupid = 'R161' journeyid = 'D006' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = 'R161' journeyid = 'D009' levelno = 2 orderno = 3 drilldown = 'N' )
    ( department = '36' groupid = 'R801' journeyid = 'D022' levelno = 2 orderno = 4 drilldown = 'N' )
    ( department = '36' groupid = 'R801' journeyid = 'D024' levelno = 2 orderno = 1 drilldown = 'N' )
    ( department = '36' groupid = 'R801' journeyid = 'D025' levelno = 2 orderno = 2 drilldown = 'N' )
    ( department = '36' groupid = 'R801' journeyid = 'D026' levelno = 2 orderno = 3 drilldown = 'N' )
  ).
ENDFORM.

* ---------------------------------------------------------------------
* ZEGA_T_CJ_IDT - 70 rows, 35 journeys x EN + AR.
* ---------------------------------------------------------------------
FORM f_idt_data CHANGING ct TYPE tt_idt.
  ct = VALUE #(
    ( spras = 'A' journeyid = 'D001' description = |طلب موافقة مبدئية| )
    ( spras = 'E' journeyid = 'D001' description = |Request Initial Approval| )
    ( spras = 'A' journeyid = 'D002' description = |تقديم طلب| )
    ( spras = 'E' journeyid = 'D002' description = |Apply| )
    ( spras = 'A' journeyid = 'D003' description = |تجديد| )
    ( spras = 'E' journeyid = 'D003' description = |Renew| )
    ( spras = 'A' journeyid = 'D004' description = |تغييرات الملكية| )
    ( spras = 'E' journeyid = 'D004' description = |Ownership Changes| )
    ( spras = 'A' journeyid = 'D005' description = |تغيير اسم المدرسة| )
    ( spras = 'E' journeyid = 'D005' description = |Change School Name| )
    ( spras = 'A' journeyid = 'D006' description = |تغيير المدير أو الناظر| )
    ( spras = 'E' journeyid = 'D006' description = |Change Manager or Principal| )
    ( spras = 'A' journeyid = 'D007' description = |تغيير المنهج الدراسي| )
    ( spras = 'E' journeyid = 'D007' description = |Change Curriculum| )
    ( spras = 'A' journeyid = 'D008' description = |إضافة أو تقليص المراحل الدراسية| )
    ( spras = 'E' journeyid = 'D008' description = |Add or Reduce Educational Cycles| )
    ( spras = 'A' journeyid = 'D009' description = |تغيير الموقع| )
    ( spras = 'E' journeyid = 'D009' description = |Change Location| )
    ( spras = 'A' journeyid = 'D010' description = |مبنى المدرسة (تعديل)| )
    ( spras = 'E' journeyid = 'D010' description = |School Building (Modify)| )
    ( spras = 'A' journeyid = 'D012' description = |الرحلات والأنشطة المدرسية (الموافقة)| )
    ( spras = 'E' journeyid = 'D012' description = |School Trips & Activities (Approval)| )
    ( spras = 'A' journeyid = 'D013' description = |إصدار| )
    ( spras = 'E' journeyid = 'D013' description = |Issue| )
    ( spras = 'A' journeyid = 'D014' description = |إصدار| )
    ( spras = 'E' journeyid = 'D014' description = |Issue| )
    ( spras = 'A' journeyid = 'D016' description = |إلغاء| )
    ( spras = 'E' journeyid = 'D016' description = |Cancel| )
    ( spras = 'A' journeyid = 'D020' description = |تعديل أو زيادة اليوم الدراسي| )
    ( spras = 'E' journeyid = 'D020' description = |Modify or Increase School Day| )
    ( spras = 'A' journeyid = 'D021' description = |الرسوم المدرسية (تعديل أو زيادة)| )
    ( spras = 'E' journeyid = 'D021' description = |School Fees (Amend or Increase)| )
    ( spras = 'A' journeyid = 'D022' description = |شهادة متابعة الدراسة| )
    ( spras = 'E' journeyid = 'D022' description = |Pursuing Study Certificate| )
    ( spras = 'A' journeyid = 'D024' description = |شهادة إجازة دراسية| )
    ( spras = 'E' journeyid = 'D024' description = |Study Leave Certificate| )
    ( spras = 'A' journeyid = 'D025' description = |شهادة تحويل| )
    ( spras = 'E' journeyid = 'D025' description = |Transfer Certificate| )
    ( spras = 'A' journeyid = 'D026' description = |طلب كشف الدرجات / بطاقة التقرير| )
    ( spras = 'E' journeyid = 'D026' description = |Request Transcript / Report Card| )
    ( spras = 'A' journeyid = 'D027' description = |تصديق الشهادة الأكاديمية| )
    ( spras = 'E' journeyid = 'D027' description = |Academic Certificate (Attest)| )
    ( spras = 'A' journeyid = 'D028' description = |التأشيرة الذهبية للمعلمين| )
    ( spras = 'E' journeyid = 'D028' description = |Golden Visa for Educators| )
    ( spras = 'A' journeyid = 'E014' description = |تسجيل| )
    ( spras = 'E' journeyid = 'E014' description = |Register| )
    ( spras = 'A' journeyid = 'E015' description = |تقديم دراسة| )
    ( spras = 'E' journeyid = 'E015' description = |Submit Study| )
    ( spras = 'A' journeyid = 'E016' description = |استيراد المنتجات الكيميائية| )
    ( spras = 'E' journeyid = 'E016' description = |Import Chemical Products| )
    ( spras = 'A' journeyid = 'E017' description = |تصدير المنتجات الكيميائية| )
    ( spras = 'E' journeyid = 'E017' description = |Export Chemical Products| )
    ( spras = 'A' journeyid = 'E018' description = |نقل المنتجات الكيميائية| )
    ( spras = 'E' journeyid = 'E018' description = |Transport Chemical Products| )
    ( spras = 'A' journeyid = 'E019' description = |نقل الزيوت المستعملة| )
    ( spras = 'E' journeyid = 'E019' description = |Transport Used Oil| )
    ( spras = 'A' journeyid = 'E020' description = |التعامل مع البطاريات / الخردة| )
    ( spras = 'E' journeyid = 'E020' description = |Batteries / Scrap Handling| )
    ( spras = 'A' journeyid = 'E021' description = |الموافقة على الوقود البديل / المواد الخام| )
    ( spras = 'E' journeyid = 'E021' description = |Alternative Fuel / Raw Material Approval| )
    ( spras = 'A' journeyid = 'E022' description = |الموافقة على مشروع تطويري| )
    ( spras = 'E' journeyid = 'E022' description = |Development Project Approval| )
    ( spras = 'A' journeyid = 'E026' description = |الموافقة على إزالة / نقل / تقليم الأشجار| )
    ( spras = 'E' journeyid = 'E026' description = |Tree Removal / Relocation / Pruning Approval| )
    ( spras = 'A' journeyid = 'E027' description = |بطاقة نائب القبطان| )
    ( spras = 'E' journeyid = 'E027' description = |Vice Captain Card| )
    ( spras = 'A' journeyid = 'E142' description = |تجديد| )
    ( spras = 'E' journeyid = 'E142' description = |Renew| )
    ( spras = 'A' journeyid = 'E146' description = |استئناف| )
    ( spras = 'E' journeyid = 'E146' description = |Appeal| )
  ).
ENDFORM.

* ---------------------------------------------------------------------
* ZEGA_T_CJ_ID - 35 rows. SIP_CODE is the second value column of the
* change log (its header reads 'Journey ID' a second time, which is the
* export's own mislabelling - every one of the 33 codes QA and DEV share
* matches DEV's SIP_CODE exactly, which settles what the column is).
* ---------------------------------------------------------------------
FORM f_id_data CHANGING ct TYPE tt_id.
  ct = VALUE #(
    ( journeyid = 'D001' sip_code = '1609' )
    ( journeyid = 'D002' sip_code = '1658' )
    ( journeyid = 'D003' sip_code = '1612' )
    ( journeyid = 'D004' sip_code = '1611' )
    ( journeyid = 'D005' sip_code = '1659' )
    ( journeyid = 'D006' sip_code = '1663' )
    ( journeyid = 'D007' sip_code = '1660' )
    ( journeyid = 'D008' sip_code = '1661' )
    ( journeyid = 'D009' sip_code = '1662' )
    ( journeyid = 'D010' sip_code = '1664' )
    ( journeyid = 'D012' sip_code = '1644' )
    ( journeyid = 'D013' sip_code = '1642' )
    ( journeyid = 'D014' sip_code = '1646' )
    ( journeyid = 'D016' sip_code = '1665' )
    ( journeyid = 'D020' sip_code = '1702' )
    ( journeyid = 'D021' sip_code = '1640' )
    ( journeyid = 'D022' sip_code = '1711' )
    ( journeyid = 'D024' sip_code = '1713' )
    ( journeyid = 'D025' sip_code = '1714' )
    ( journeyid = 'D026' sip_code = '1715' )
    ( journeyid = 'D027' sip_code = '1716' )
    ( journeyid = 'D028' sip_code = '1716' )
    ( journeyid = 'E014' sip_code = '1671' )
    ( journeyid = 'E015' sip_code = '1683' )
    ( journeyid = 'E016' sip_code = '1674' )
    ( journeyid = 'E017' sip_code = '1675' )
    ( journeyid = 'E018' sip_code = '1676' )
    ( journeyid = 'E019' sip_code = '1677' )
    ( journeyid = 'E020' sip_code = '1678' )
    ( journeyid = 'E021' sip_code = '1679' )
    ( journeyid = 'E022' sip_code = '1680' )
    ( journeyid = 'E026' sip_code = '1669' )
    ( journeyid = 'E027' sip_code = '1668' )
    ( journeyid = 'E142' sip_code = '1673' )
    ( journeyid = 'E146' sip_code = '1672' )
  ).
ENDFORM.

START-OF-SELECTION.

  WRITE: / 'Restore of the QA portal tables into client', sy-mandt.
  IF p_test = abap_true.
    WRITE: / 'TEST RUN - nothing is written. Untick Test run to commit.'.
  ENDIF.
  ULINE.

  IF p_grp = abap_true.
    PERFORM f_do_grp.
  ENDIF.
  IF p_idt = abap_true.
    PERFORM f_do_idt.
  ENDIF.
  IF p_id = abap_true.
    PERFORM f_do_id.
  ENDIF.

  IF p_test = abap_false.
    COMMIT WORK AND WAIT.
    WRITE: / 'Committed.'.
  ENDIF.

*&--------------------------------------------------------------------*
*& Each table follows the same shape: the row is looked up on its own
*& key, inserted when it is gone, counted when it is back and correct,
*& and only listed - not written - when it is back with DIFFERENT
*& values, unless P_OVER says otherwise. A restore must never quietly
*& overwrite something somebody has re-created by hand since the delete.
*&--------------------------------------------------------------------*
FORM f_head USING iv_tab TYPE string.
  CLEAR: gv_ins, gv_ok, gv_dif, gv_upd.
  SKIP.
  WRITE: / iv_tab COLOR COL_HEADING.
ENDFORM.

FORM f_foot USING iv_tab TYPE string.
  WRITE: / iv_tab, 'restored:', gv_ins,
           '| already correct:', gv_ok,
           '| differs:', gv_dif,
           '| overwritten:', gv_upd.
ENDFORM.

FORM f_do_grp.
  DATA lt TYPE tt_grp.
  DATA ls_db TYPE zega_t_cj_grp.
  PERFORM f_head USING `ZEGA_T_CJ_GRP`.
  PERFORM f_grp_data CHANGING lt.
  LOOP AT lt INTO DATA(ls).
    SELECT SINGLE * FROM zega_t_cj_grp
      WHERE department = @ls-department
        AND groupid    = @ls-groupid
        AND journeyid  = @ls-journeyid
      INTO @ls_db.
    IF sy-subrc <> 0.
      gv_ins = gv_ins + 1.
      IF p_test = abap_false.
        INSERT zega_t_cj_grp FROM @( VALUE #( mandt = sy-mandt
          department = ls-department groupid = ls-groupid
          journeyid  = ls-journeyid  levelno = ls-levelno
          orderno    = ls-orderno    drilldown = ls-drilldown ) ).
      ENDIF.
      CONTINUE.
    ENDIF.
    IF ls_db-levelno = ls-levelno AND ls_db-orderno = ls-orderno
       AND ls_db-drilldown = ls-drilldown.
      gv_ok = gv_ok + 1.
      CONTINUE.
    ENDIF.
    gv_dif = gv_dif + 1.
    WRITE: / '  differs:', ls-department, ls-groupid, ls-journeyid,
             '| in QA now', ls_db-levelno, ls_db-orderno, ls_db-drilldown,
             '| logged', ls-levelno, ls-orderno, ls-drilldown.
    CHECK p_over = abap_true.
    gv_upd = gv_upd + 1.
    CHECK p_test = abap_false.
    UPDATE zega_t_cj_grp SET levelno   = @ls-levelno
                             orderno   = @ls-orderno
                             drilldown = @ls-drilldown
      WHERE department = @ls-department
        AND groupid    = @ls-groupid
        AND journeyid  = @ls-journeyid.
  ENDLOOP.
  PERFORM f_foot USING `ZEGA_T_CJ_GRP`.
ENDFORM.

FORM f_do_idt.
  DATA lt TYPE tt_idt.
  DATA ls_db TYPE zega_t_cj_idt.
  PERFORM f_head USING `ZEGA_T_CJ_IDT`.
  PERFORM f_idt_data CHANGING lt.
  LOOP AT lt INTO DATA(ls).
    SELECT SINGLE * FROM zega_t_cj_idt
      WHERE spras = @ls-spras AND journeyid = @ls-journeyid
      INTO @ls_db.
    IF sy-subrc <> 0.
      gv_ins = gv_ins + 1.
      IF p_test = abap_false.
        INSERT zega_t_cj_idt FROM @( VALUE #( mandt = sy-mandt
          spras = ls-spras journeyid = ls-journeyid
          description = ls-description ) ).
      ENDIF.
      CONTINUE.
    ENDIF.
    IF ls_db-description = ls-description.
      gv_ok = gv_ok + 1.
      CONTINUE.
    ENDIF.
    gv_dif = gv_dif + 1.
    WRITE: / '  differs:', ls-spras, ls-journeyid,
             '| in QA now', ls_db-description, '| logged', ls-description.
    CHECK p_over = abap_true.
    gv_upd = gv_upd + 1.
    CHECK p_test = abap_false.
    UPDATE zega_t_cj_idt SET description = @ls-description
      WHERE spras = @ls-spras AND journeyid = @ls-journeyid.
  ENDLOOP.
  PERFORM f_foot USING `ZEGA_T_CJ_IDT`.
ENDFORM.

FORM f_do_id.
  DATA lt     TYPE tt_id.
  DATA lt_idt TYPE tt_idt.
  DATA ls_db  TYPE zega_t_cj_id.
  DATA lv_des TYPE zega_t_cj_id-description.
  PERFORM f_head USING `ZEGA_T_CJ_ID`.
  PERFORM f_id_data  CHANGING lt.
  PERFORM f_idt_data CHANGING lt_idt.
  LOOP AT lt INTO DATA(ls).
*   DESCRIPTION is the one field the change log never held. In DEV it
*   equals the English ZEGA_T_CJ_IDT text on all 58 rows, so that is
*   what is put back - unless P_DESC is unticked, which leaves it blank.
    CLEAR lv_des.
    IF p_desc = abap_true.
      READ TABLE lt_idt INTO DATA(ls_t)
        WITH KEY spras = 'E' journeyid = ls-journeyid.
      IF sy-subrc = 0.
        lv_des = ls_t-description.
      ENDIF.
    ENDIF.
    SELECT SINGLE * FROM zega_t_cj_id
      WHERE journeyid = @ls-journeyid
      INTO @ls_db.
    IF sy-subrc <> 0.
      gv_ins = gv_ins + 1.
      IF p_test = abap_false.
*       POPULAR and ANONYMOUS were logged blank and go back blank.
        INSERT zega_t_cj_id FROM @( VALUE #( mandt = sy-mandt
          journeyid = ls-journeyid sip_code = ls-sip_code
          description = lv_des ) ).
      ENDIF.
      CONTINUE.
    ENDIF.
    IF ls_db-sip_code = ls-sip_code.
      gv_ok = gv_ok + 1.
      CONTINUE.
    ENDIF.
    gv_dif = gv_dif + 1.
    WRITE: / '  differs:', ls-journeyid,
             '| in QA now', ls_db-sip_code, '| logged', ls-sip_code.
    CHECK p_over = abap_true.
    gv_upd = gv_upd + 1.
    CHECK p_test = abap_false.
    UPDATE zega_t_cj_id SET sip_code = @ls-sip_code
      WHERE journeyid = @ls-journeyid.
  ENDLOOP.
  PERFORM f_foot USING `ZEGA_T_CJ_ID`.
ENDFORM.
