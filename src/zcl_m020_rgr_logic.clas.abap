CLASS zcl_m020_rgr_logic DEFINITION
  PUBLIC
  INHERITING FROM zcl_rak_grant_logic
  FINAL
  CREATE PUBLIC.

*&---------------------------------------------------------------------*
*& M020 Renewal Grant Request.
*&
*&   STP1  NRGR_1_1   Parcel Selection   the grant card list
*&   STP2  NRGR_1_2   Documents          three uploads + details + one more
*&   STP3  NRGR_1_3   Fees & Payment
*&   ---   NRGR_1_4   the CPG screen - PAY_SCREEN, never a CJS step
*&
*& THE SELECTOR READS GRANTS, exactly as M019's does - Partnerrole
*& YTR080, one source, Favourites only. The stepper calls it "Parcel
*& Selection" where M019 says "Grant Selection"; the control is the same
*& and the role is the same. Reading it with TR0800 would answer the
*& citizen's owned parcels, which renders perfectly and is wrong.
*&
*& THE DOCUMENT SET IS MOSTLY OPTIONAL AND ONE IS NOT. From the
*& screenshot: Sheikh Zayed Program Letter and Justification carry no
*& asterisk, "N.O.C From the Mortgaged Holder" does, and so does the
*& free-text "Renewal Grant Request Details". The last upload - "Upload a
*& File to describe your text above" - is optional and pairs with that
*& text.
*&
*& WHICH MAKES THE NOC THE ONLY HARD DOCUMENT RULE, and it is worth
*& stating why it is not left to configured REQUIRED alone: an uploader's
*& REQUIRED is checked by VALIDATE_STEP( ) against the FIELD, and an
*& upload field holds no scalar. See the note at ON_CUSTOM_VALIDATE.
*&---------------------------------------------------------------------*

  PUBLIC SECTION.

*   NAMES CONFIRMED FROM EXPORT_DEFIN.XLSX for NRGR_1_1 / NRGR_1_2.
*   NRGR_1_2 carries TWO uploader sets - UPLOADER1_1 / UPLOADER2_1 /
*   UPLOADER3_1 with screen sequences 280/330/380, and an UPLOADER1 /
*   UPLOADER2 / UPLOADER3 set at 490/510 with no sequence on the
*   third. The sequenced _1 set plus UPLOADER4 (460) is the one the
*   citizen sees, and it is the one used here.
    CONSTANTS c_fld_grant    TYPE string VALUE 'PARCELSELECTOR'.

*   ---- step 2 -----------------------------------------------------------
*   The three named uploads, in the export's own screen order.
    CONSTANTS c_fld_sz_letter TYPE string VALUE 'UPLOADER1_1'.
    CONSTANTS c_fld_just_doc  TYPE string VALUE 'UPLOADER2_1'.
*    CONSTANTS c_fld_noc       TYPE string VALUE 'UPLOADER3_1'.

*   The free text and the file that describes it.
*   ENTERTEXT is the CJS name; the export spells it EnterText, mixed case,
*   and the feeder carries that exact spelling in TECH_NAME because the
*   bridge upper-cases FIELDNAME but not TECHNICALNAME.
    CONSTANTS c_fld_details   TYPE string VALUE 'ENTERTEXT'.
    CONSTANTS c_fld_extra     TYPE string VALUE 'UPLOADER4'.

    METHODS zif_rak_journey_logic~on_custom_validate REDEFINITION.

protected section.
private section.
ENDCLASS.



CLASS ZCL_M020_RGR_LOGIC IMPLEMENTATION.


  METHOD zif_rak_journey_logic~on_custom_validate.

*   SUPER FIRST, AND BEFORE ANY `CHECK` - the engine's PAID gate, then
*   the MML parcel rule, then the grants base.
    rt = super->zif_rak_journey_logic~on_custom_validate( io_ctx  = io_ctx
                                                          iv_step = iv_step ).

*   ---- NOTHING IS ADDED HERE, AND THAT IS THE CORRECT ANSWER ----------
*   THE MORTGAGE NOC IS ENFORCED BY CONFIGURED `REQUIRED` ON THE
*   UPLOADER, and I wrote a code check for it before reading how the
*   engine handles one. Both halves of that were wrong:
*
*   An UPLOAD field has NO MODEL COMPONENT - BUILD_MODEL( ) does
*   `IF ls_field-type = 'UPLOAD'. CONTINUE.` - so GET_VAL( ) on an
*   uploader returns blank whether a file is attached or not. A check
*   written on it refuses EVERY submit, which is the worst failure shape
*   available: a form that cannot be sent and gives a reason that is not
*   true.
*
*   And it was unnecessary, because ZCL_RAK_JOURNEY_RULES already does
*   this properly. For a REQUIRED field of type UPLOAD it checks
*
*       line_exists( mo_e->mt_attach[ field = to_upper( ls_mf-name ) ] )
*
*   - the staged list, keyed by FIELD NAME, which is exactly the question
*   - and falls back to the GET_ATTACHMENTS( ) hook so a document the
*   backend already holds satisfies the requirement on a resumed draft.
*   Uploads are then excluded from the scalar required check by FTYPE.
*
*   SO: mark the NOC `REQUIRED` in ZRAK_T_JNY_FLD and leave it alone. The
*   same goes for the details text, which is an ordinary TEXTAREA with a
*   real value - VALIDATE_STEP( ) refuses Next on step 2 without it and
*   the citizen is stopped one step earlier, with the field's own
*   message, rather than at submit.
*
*   The method is redefined only to keep the SUPER-> chain explicit: an
*   empty redefinition of this hook is a deletion of the PAID gate.
    RETURN.

  ENDMETHOD.
ENDCLASS.
