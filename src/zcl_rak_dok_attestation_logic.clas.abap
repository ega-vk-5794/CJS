*&---------------------------------------------------------------------*
*& ZCL_RAK_DOK_ATTESTATION_LOGIC
*&---------------------------------------------------------------------*
*& Handler for CJS journey DOK_ATTESTATION (legacy QNV D028, cat DOKSL).
*&
*& WHY THIS CLASS EXISTS
*& ---------------------
*& The journey has no MTABLE, no PERSON_SEARCH and no PAYFEE. It needs a
*& handler for exactly one reason the declarative rules cannot cover:
*&
*&   The legacy screen ND028_1_1 renders a TBUTTON group
*&   (DATA1 = LEADERSHIP,TEACHER) whose two members carry two DIFFERENT
*&   backend fields:
*&       LEADERSHIP -> GS_DATA-PARTNER_PRINCIPAL
*&       TEACHER    -> GS_DATA-PARTNER_TEACHER
*&
*&   CJS models that group as ONE ftype='SEGMENTED' field (STAFF_ROLE)
*&   with two option keys. A single field cannot own two tech_names, so
*&   the fan-out happens here, into the two hidden carrier fields
*&   PRINCIPAL_FLAG and TEACHER_FLAG.
*&
*& Visibility of PRINCIPAL_TYPE is NOT done here — rules R1..R5 in
*& ZRAK_DOK_ATTESTATION_LOAD handle it, and change_evt wires STAFF_ROLE's
*& change event automatically.
*&
*& STATE RULE
*& ----------
*& The engine re-instantiates this class on every round-trip via
*& CREATE OBJECT, so a class attribute is empty on the next click. All
*& state is carried through io_ctx->set_val / get_val. Every name written
*& below has a field row in zrak_t_jny_fld — val_set drops writes to
*& undeclared names in silence. No mutable attributes exist in this class.
*&---------------------------------------------------------------------*
CLASS zcl_rak_dok_attestation_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_journey_logic
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_rak_journey_logic~on_change      REDEFINITION.
    METHODS zif_rak_journey_logic~on_before_post REDEFINITION.

  PRIVATE SECTION.
    " Constants only. No mutable attributes — see STATE RULE above.
    CONSTANTS c_role_field  TYPE string VALUE 'STAFF_ROLE'.
    CONSTANTS c_opt_leader  TYPE string VALUE 'LEADERSHIP'.
    CONSTANTS c_opt_teacher TYPE string VALUE 'TEACHER'.
    CONSTANTS c_fld_princ   TYPE string VALUE 'PRINCIPAL_FLAG'.
    CONSTANTS c_fld_teacher TYPE string VALUE 'TEACHER_FLAG'.

    " Derives the two backend flags from the one segmented value.
    " Idempotent and side-effect free apart from the two set_val calls.
    METHODS fan_out_role
      IMPORTING io_ctx TYPE REF TO zif_rak_journey.
ENDCLASS.



CLASS ZCL_RAK_DOK_ATTESTATION_LOGIC IMPLEMENTATION.


  METHOD fan_out_role.
    DATA(lv_role) = to_upper( condense( io_ctx->get_val( c_role_field ) ) ).

    io_ctx->set_val( iv_name  = c_fld_princ
                     iv_value = COND string( WHEN lv_role = c_opt_leader THEN `X` ELSE `` ) ).

    io_ctx->set_val( iv_name  = c_fld_teacher
                     iv_value = COND string( WHEN lv_role = c_opt_teacher THEN `X` ELSE `` ) ).
  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_before_post.

    " Once a handler is bound, the engine SKIPS its own PAY_* / PAYFEE
    " strip. This journey has no payment step, but the sweep stays as a
    " guard in case one is added later.
    DELETE ct_kv WHERE key CP 'PAY_*'.
    DELETE ct_kv WHERE key = 'PAYFEE'.

    " Re-derive from the payload rather than trust the last on_change: the
    " user can reach submit without ever firing a change event (draft
    " resume, back-navigation). flatten_kv has already swept STAFF_ROLE
    " into ct_kv, so read it from there — no io_ctx dependency.
    DATA lv_role TYPE string.
    READ TABLE ct_kv INTO DATA(ls_role) WITH KEY key = c_role_field.
    IF sy-subrc = 0.
      lv_role = to_upper( condense( CONV string( ls_role-value ) ) ).
    ENDIF.

    LOOP AT ct_kv ASSIGNING FIELD-SYMBOL(<ls_kv>)
         WHERE key = c_fld_princ OR key = c_fld_teacher.
      CASE <ls_kv>-key.
        WHEN c_fld_princ.
          <ls_kv>-value = COND string( WHEN lv_role = c_opt_leader  THEN `X` ELSE `` ).
        WHEN c_fld_teacher.
          <ls_kv>-value = COND string( WHEN lv_role = c_opt_teacher THEN `X` ELSE `` ).
      ENDCASE.
    ENDLOOP.

    " UI-only field. It has no tech_name; the backend has no home for it.
    DELETE ct_kv WHERE key = c_role_field.

    " PRINCIPAL_TYPE is meaningless for a teacher. Rule R5 already CLEARs
    " it, so this is belt-and-braces against a stale draft value.
    IF lv_role = c_opt_teacher.
      DELETE ct_kv WHERE key = 'PRINCIPAL_TYPE'.
    ENDIF.

  ENDMETHOD.


  METHOD zif_rak_journey_logic~on_change.
    " STAFF_ROLE has a change event because it is the src_field of R1..R5.
    CHECK to_upper( iv_field ) = c_role_field.

    fan_out_role( io_ctx ).
  ENDMETHOD.
ENDCLASS.
