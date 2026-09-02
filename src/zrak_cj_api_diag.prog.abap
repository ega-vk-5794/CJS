*&---------------------------------------------------------------------*
*& Report ZRAK_CJ_API_DIAG
*&---------------------------------------------------------------------*
* One place to prove that the wrapper layer READS - not that it builds.
*
* ZRAK_CJ_REQCTX_DIAG settled construction: /IWBEP/CL_MGW_REQUEST can be
* created outside Gateway, x-custom1 reaches it, and GET_BP( ) resolves the
* caller from it. That proves the plumbing and nothing about the data. This
* report is the next question: given a real session key and a real partner,
* does each wrapped entity set come back with the rows a citizen would see?
*
* It calls the APIs exactly the way a journey does - identity in MS_CTX,
* out as filters, never inferred by the DPC - and prints what came back:
* the row count, the messages, and the first few rows COMPONENT BY
* COMPONENT via RTTI, so a wrong filter shows up as the wrong rows rather
* than as an empty list nobody can explain.
*
* READ-ONLY. Every method here is a GET_ENTITYSET or an RFC-enabled read;
* nothing posts, nothing commits. FeesSet, TrackerSet and ProjectSet never
* touch the request context; the PropertiesSet family does, so an unbound
* context shows up there first - which is why WHY( ) is printed at the top
* whatever you tick.
*
* If a read answers nothing, work down in this order:
*   1. the context line below - unbound means ZCL_RAK_CJ_REQ_CTX failed
*   2. the session key - it is ZEGA_T_CJ_US_LOG-USER_KEY, NOT the launch
*      URL's &userdata= envelope (ZCL_RAK_CJ_CTX unwraps that; here you
*      type the key itself)
*   3. the partner guid - PROPERTIESSET filters on Partnerguid, and blank
*      matches nothing rather than everything
*&---------------------------------------------------------------------*
REPORT zrak_cj_api_diag.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS p_key  TYPE c LENGTH 132.
PARAMETERS p_bp   TYPE bu_partner.
PARAMETERS p_guid TYPE c LENGTH 32.
PARAMETERS p_role TYPE c LENGTH 10.
PARAMETERS p_dept TYPE c LENGTH 4.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_jny  TYPE c LENGTH 10.
PARAMETERS p_scrn TYPE c LENGTH 30.
PARAMETERS p_case TYPE c LENGTH 32.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
PARAMETERS p_fees TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_trk  TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_proj TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-b04.
PARAMETERS p_parc TYPE abap_bool AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_unit TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_own  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_map  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_pid  TYPE c LENGTH 20.
SELECTION-SCREEN END OF BLOCK b4.

SELECTION-SCREEN BEGIN OF BLOCK b5 WITH FRAME TITLE TEXT-b05.
PARAMETERS p_chem  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_permt TYPE c LENGTH 20.
PARAMETERS p_lic   TYPE c LENGTH 20.
PARAMETERS p_emir  TYPE c LENGTH 10.
PARAMETERS p_ie    TYPE c LENGTH 1.
SELECTION-SCREEN END OF BLOCK b5.

SELECTION-SCREEN BEGIN OF BLOCK b6 WITH FRAME TITLE TEXT-b06.
PARAMETERS p_accom TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_port  TYPE c LENGTH 20.
PARAMETERS p_resv  TYPE abap_bool AS CHECKBOX DEFAULT ' '.
PARAMETERS p_wlic  TYPE c LENGTH 20.
SELECTION-SCREEN END OF BLOCK b6.

SELECTION-SCREEN BEGIN OF BLOCK b7 WITH FRAME TITLE TEXT-b07.
PARAMETERS p_rows TYPE i DEFAULT 3.
SELECTION-SCREEN END OF BLOCK b7.


*&---------------------------------------------------------------------*
CLASS lcl_out DEFINITION.
  PUBLIC SECTION.
*   IT_ANY is generic on purpose: every result table here is a generated
*   MPC or function-module type, and naming them would tie this report to
*   structures that are regenerated elsewhere. The dump below is RTTI, so
*   a column added to a service appears here with no edit.
    CLASS-METHODS dump
      IMPORTING iv_name TYPE string
                it_any  TYPE ANY TABLE
                it_msg  TYPE bapiret2_t OPTIONAL
                iv_max  TYPE i DEFAULT 3.
    CLASS-METHODS msgs
      IMPORTING it_msg TYPE bapiret2_t.
ENDCLASS.

CLASS lcl_out IMPLEMENTATION.

  METHOD msgs.
    LOOP AT it_msg INTO DATA(ls_m).
      WRITE: / '     msg', 12 ls_m-type, 16 ls_m-message.
    ENDLOOP.
  ENDMETHOD.

  METHOD dump.
    ULINE.
    WRITE: / iv_name, 40 |{ lines( it_any ) } row(s)|.
    msgs( it_msg ).

    DATA lv_i TYPE i.
    LOOP AT it_any ASSIGNING FIELD-SYMBOL(<row>).
      lv_i = lv_i + 1.
      IF lv_i > iv_max.
        DATA(lv_more) = lines( it_any ) - iv_max.
        WRITE: / |     ... { lv_more } more|.
        EXIT.
      ENDIF.
      DATA(lv_line) = ``.
      TRY.
          DATA(lo_s) = CAST cl_abap_structdescr(
                         cl_abap_typedescr=>describe_by_data( <row> ) ).
          LOOP AT lo_s->components INTO DATA(ls_c).
            ASSIGN COMPONENT ls_c-name OF STRUCTURE <row> TO FIELD-SYMBOL(<v>).
            IF sy-subrc <> 0 OR <v> IS INITIAL.
              CONTINUE.
            ENDIF.
*           Only what is filled. A generated row type carries forty
*           components and three of them answer the question.
            lv_line = lv_line && |{ ls_c-name }={ <v> }  |.
          ENDLOOP.
        CATCH cx_root INTO DATA(lx).
          lv_line = |cannot read row: { lx->get_text( ) }|.
      ENDTRY.
      WRITE: / |  [{ lv_i }]|, 8 lv_line.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.

  DATA ls_ctx TYPE zcl_rak_cj_api=>ty_ctx.
  ls_ctx-session_key = condense( CONV string( p_key ) ).
  ls_ctx-partner     = |{ p_bp ALPHA = OUT }|.
  ls_ctx-partnerguid = CONV string( p_guid ).
  ls_ctx-role        = CONV string( p_role ).
  ls_ctx-department  = CONV string( p_dept ).
  ls_ctx-journey     = CONV string( p_jny ).
  ls_ctx-screen      = CONV string( p_scrn ).
  ls_ctx-intreno     = CONV string( p_case ).
  ls_ctx-langu       = sy-langu.

  CONDENSE ls_ctx-partner.

  DATA(lv_klen) = strlen( ls_ctx-session_key ).
  WRITE: / 'CJS WRAPPER API - READ TEST'.
  ULINE.
  WRITE: / 'partner', 16 ls_ctx-partner, 40 'guid', 48 ls_ctx-partnerguid.
  WRITE: / 'journey', 16 ls_ctx-journey, 40 'screen', 48 ls_ctx-screen.
  WRITE: / 'case', 16 ls_ctx-intreno, 40 'dept', 48 ls_ctx-department.
  WRITE: / 'key length', 16 |{ lv_klen }|.

* ---- the request context, before anything is read through it ----------
* WHY( ) is printed whatever GET( ) answered: a context that BOUND on the
* fallback class still cannot answer a header, and only WHY( ) says so.
  DATA(lo_req) = zcl_rak_cj_req_ctx=>get( ls_ctx-session_key ).
  DATA(lv_why) = zcl_rak_cj_req_ctx=>why( ).
  DATA(lv_bnd) = COND string( WHEN lo_req IS BOUND THEN 'BOUND'
                                                   ELSE '** UNBOUND **' ).
  WRITE: / 'request ctx', 16 lv_bnd, 40 lv_why.

* ---- CUSTOMERJOURNEY: the three sets that never read the context ------
  IF p_fees = abap_true OR p_trk = abap_true OR p_proj = abap_true.
    TRY.
        DATA(lo_fee) = NEW zcl_rak_fees_api( is_ctx = ls_ctx ).
        IF p_fees = abap_true.
          DATA(ls_f) = lo_fee->fees( ).
          lcl_out=>dump( iv_name = 'FeesSet    (ZCL_RAK_FEES_API->FEES)'
                         it_any = ls_f-rows it_msg = ls_f-msg iv_max = p_rows ).
        ENDIF.
        IF p_trk = abap_true.
          DATA(ls_t) = lo_fee->tracker( ).
          lcl_out=>dump( iv_name = 'TrackerSet (ZCL_RAK_FEES_API->TRACKER)'
                         it_any = ls_t-rows it_msg = ls_t-msg iv_max = p_rows ).
        ENDIF.
        IF p_proj = abap_true.
          DATA(ls_p) = lo_fee->projects( iv_case = ls_ctx-intreno ).
          lcl_out=>dump( iv_name = 'ProjectSet (ZCL_RAK_FEES_API->PROJECTS)'
                         it_any = ls_p-rows it_msg = ls_p-msg iv_max = p_rows ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_f).
        ULINE.
        WRITE: / '** ZCL_RAK_FEES_API raised:', 32 lx_f->get_text( ).
    ENDTRY.
  ENDIF.

* ---- PropertiesSet: this is the family that needs the context ---------
  IF p_parc = abap_true OR p_unit = abap_true OR p_own = abap_true
     OR p_map = abap_true OR p_pid IS NOT INITIAL.
    TRY.
        DATA(lo_pr) = NEW zcl_rak_property_api( is_ctx = ls_ctx ).
        IF p_parc = abap_true.
          DATA(ls_pc) = lo_pr->parcels( ).
          lcl_out=>dump( iv_name = 'PropertiesSet Type=Parcel (->PARCELS)'
                         it_any = ls_pc-rows it_msg = ls_pc-msg iv_max = p_rows ).
        ENDIF.
        IF p_unit = abap_true.
          DATA(ls_un) = lo_pr->units( ).
          lcl_out=>dump( iv_name = 'PropertiesSet Type=Unit   (->UNITS)'
                         it_any = ls_un-rows it_msg = ls_un-msg iv_max = p_rows ).
        ENDIF.
        IF p_own = abap_true.
          DATA(ls_ow) = lo_pr->managed_owners( ).
          lcl_out=>dump( iv_name = 'PartnerSet Role=Z00008    (->MANAGED_OWNERS)'
                         it_any = ls_ow-rows it_msg = ls_ow-msg iv_max = p_rows ).
        ENDIF.
        IF p_pid IS NOT INITIAL.
          DATA(lv_ex) = lo_pr->parcel_exists( iv_parcel_id = CONV string( p_pid ) ).
          ULINE.
          DATA(lv_yn) = COND string( WHEN lv_ex = abap_true THEN 'yes' ELSE 'no' ).
          WRITE: / |PARCEL_EXISTS( { p_pid } )|, 40 lv_yn.
        ENDIF.
        IF p_map = abap_true.
          DATA(ls_mp) = lo_pr->map_url( iv_parcel = CONV string( p_pid ) ).
          ULINE.
          WRITE: / 'MAP_URL'.
          WRITE: / '  url', 12 ls_mp-url.
          WRITE: / '  gis', 12 ls_mp-gisurl.
          DATA(lv_tok) = COND string( WHEN ls_mp-token IS INITIAL
                                      THEN '(none)' ELSE 'present' ).
          WRITE: / '  token', 12 lv_tok.
          lcl_out=>msgs( ls_mp-msg ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_p).
        ULINE.
        WRITE: / '** ZCL_RAK_PROPERTY_API raised:', 32 lx_p->get_text( ).
    ENDTRY.
  ENDIF.

* ---- ChemicalHistorySet, which is an RFC read and needs no context ----
  IF p_chem = abap_true.
    TRY.
        DATA(lo_ch) = NEW zcl_rak_chem_api( ).
        DATA(ls_ch) = lo_ch->history( is_req = VALUE #(
          permit  = CONV string( p_permt )
          licence = CONV string( p_lic )
          emirate = CONV string( p_emir )
          impexp  = CONV string( p_ie ) ) ).
        lcl_out=>dump( iv_name = 'ChemicalHistorySet (ZCL_RAK_CHEM_API->HISTORY)'
                       it_any = ls_ch-rows it_msg = ls_ch-msg iv_max = p_rows ).
      CATCH cx_root INTO DATA(lx_c).
        ULINE.
        WRITE: / '** ZCL_RAK_CHEM_API raised:', 32 lx_c->get_text( ).
    ENDTRY.
  ENDIF.

* ---- port accommodation + workers, also RFC reads ---------------------
  IF p_accom = abap_true.
    TRY.
        DATA(lo_ac) = NEW zcl_rak_accom_api( ).
        DATA(ls_ac) = lo_ac->objects( is_req = VALUE #(
          port     = CONV string( p_port )
          case     = ls_ctx-intreno
          reserved = p_resv ) ).
        lcl_out=>dump( iv_name = 'PortObjects - buildings'
                       it_any = ls_ac-buildings it_msg = ls_ac-msg iv_max = p_rows ).
        lcl_out=>dump( iv_name = 'PortObjects - rooms'
                       it_any = ls_ac-rooms iv_max = p_rows ).
        lcl_out=>dump( iv_name = 'PortObjects - beds'
                       it_any = ls_ac-beds iv_max = p_rows ).
        IF p_wlic IS NOT INITIAL.
          DATA(ls_wk) = lo_ac->workers( iv_licence = CONV string( p_wlic ) ).
          lcl_out=>dump( iv_name = 'WorkersList'
                         it_any = ls_wk-rows it_msg = ls_wk-msg iv_max = p_rows ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_a).
        ULINE.
        WRITE: / '** ZCL_RAK_ACCOM_API raised:', 32 lx_a->get_text( ).
    ENDTRY.
  ENDIF.

  ULINE.
  WRITE: / 'Done. A read that answered 0 rows with no message is a FILTER',
         / 'question, not an error - check partner guid and role first.'.
