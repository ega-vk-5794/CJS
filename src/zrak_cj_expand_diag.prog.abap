REPORT zrak_cj_expand_diag.

*&---------------------------------------------------------------------*
*& What can stand in for /IWBEP/IF_MGW_ODATA_EXPAND - printed, not guessed
*&
*& THE PROBLEM THIS EXISTS TO END. The parcel details dialog draws seven
*& tabs and only the Map tab has data. The other six - General, Business
*& Partners, Land, Development, Measurements, Documents - are ONE read,
*& and the live URL is now known:
*&
*&   PropertiesSet(Intreno='I800100108658',
*&                 Partnerguid=guid'6aa93cf9-0402-1ed6-b5ca-421c803dd3ad')
*&     ?$expand=ToProject,ToPartner,ToMeasurement,ToLandUse,
*&              ToDevelopment,ToAttachment
*&
*& IT IS GET_EXPANDED_ENTITY, SINGULAR - AND THIS REPORT SAID ENTITYSET.
*&
*& A KEY IN THE PATH decides which method Gateway routes to:
*&
*&   PropertiesSet?$expand=...        -> GET_EXPANDED_ENTITYSET
*&   PropertiesSet(key)?$expand=...   -> GET_EXPANDED_ENTITY
*&
*& and the dialog supplies a key. So the whole first version of this
*& report - and the note in ZCL_RAK_PROPERTY_API - pointed at a method the
*& details dialog never calls. Printing the implementers of an expand
*& interface was answering the right question about the wrong method.
*&
*& That also changes what is BLOCKED. The plural method dereferences
*& IO_EXPAND->GET_CHILDREN( ) unguarded; whether the singular one does has
*& not been read, so the expand object may not be needed here at all. And
*& CJS already holds both key parts - Intreno from the parcel row,
*& Partnerguid from MS_CTX - so nothing new has to be resolved either way.
*&
*& FloorSet is different and stays blocked: it exists ONLY inside
*& GET_EXPANDED_ENTITYSET (iv_entity_name = gc_floor), the plural one.
*&
*& WHY A DIAGNOSTIC AND NOT A CLASS. Because the repository has already
*& paid for the alternative. ZCL_RAK_CJ_REQ_CTX was written THREE TIMES
*& against a guessed shape of /IWBEP/CL_MGW_REQUEST, and each activation
*& revealed the next invisible fact - MT_HEADERS was already the parent's,
*& the constructor wanted a mandatory IR_REQUEST_DETAILS of an unreadable
*& type, the returning parameter was RT_HEADER and not
*& RT_REQUEST_HEADERS. doc/README.md's one standing rule came out of it:
*&
*&     Do not hand-write the shape of a standard SAP object you cannot open.
*&
*& There is no ADT connection from the environment these classes are
*& written in, so the only way to obey that rule is to have the SYSTEM say
*& what the object looks like. That is all this report does.
*&
*& WHAT TO DO WITH THE OUTPUT. Hand it back. With the candidate list and
*& their real constructors, the expand object can be built the way the
*& request context finally was: a factory that reads the chosen class's own
*& CONSTRUCTOR by RTTI, builds a PARAMETER-TABLE from whatever it declares
*& mandatory, and instantiates it dynamically - so a wrong guess becomes a
*& catchable runtime error instead of a class that will not load.
*&
*& Read-only. Instantiates nothing, calls nothing, changes nothing.
*&---------------------------------------------------------------------*

PARAMETERS p_intf TYPE seoclsname DEFAULT '/IWBEP/IF_MGW_ODATA_EXPAND'.

* THE DPC WHOSE OWN EXPANDED METHODS ARE PRINTED. This is the half that
* actually settles the question, and it was missing from the first version
* of this report because that version was written against the wrong method
* name entirely - see the correction block below.
PARAMETERS p_dpc  TYPE seoclsname DEFAULT 'ZCL_ZEGA_CJ_DPC_EXT'.

START-OF-SELECTION.

* Everything reaches WRITE through a variable. WRITE takes data objects,
* not expressions, and a method call in the operand fails at activation for
* a reason unrelated to what is being tested - the same care
* ZRAK_CJ_REQCTX_DIAG takes.
  DATA lv_txt   TYPE string.
  DATA lv_n     TYPE i.

* ------------------------------------------------- what the interface IS
* ADDED AFTER READING THE DPC SOURCE, which settled the two questions this
* report was written for and left exactly one open.
*
* Settled: GET_EXPANDED_ENTITY is an INTERFACE method
* (/IWBEP/IF_MGW_APPL_SRV_RUNTIME~), so it is public and there is no
* generated-name truncation to discover; and IO_EXPAND, though declared
* OPTIONAL, is dereferenced UNCONDITIONALLY - `io_expand->get_children( )`
* runs before any child is fetched, and each of the six tabs is then gated
* on line_exists( children[ tech_nav_prop_name = 'TOPARTNER' ] ).
*
* So an expand object is required AND has to report the six nav names. An
* empty one returns an entity with every tab blank, which looks exactly
* like a backend with no data.
*
* Open: how to build one. Either implement the interface - for which the
* method list has to be known, and guessing it is what cost
* ZCL_RAK_CJ_REQ_CTX three activation rounds - or instantiate a standard
* class that already does, which the implementer list below names.
*
* This block answers the first half. It is read-only RTTI and prints the
* interface's own methods with their parameters, so a small
* ZCL_RAK_CJ_EXPAND can be written against what the system declares
* rather than against what seems likely.
  DATA lo_it   TYPE REF TO cl_abap_intfdescr.
  DATA lo_itd  TYPE REF TO cl_abap_typedescr.

  WRITE: / 'Methods ON', p_intf.
  ULINE.

  TRY.
      CALL METHOD cl_abap_typedescr=>describe_by_name
        EXPORTING  p_name         = p_intf
        RECEIVING  p_descr_ref    = lo_itd
        EXCEPTIONS type_not_found = 1
                   OTHERS         = 2.
      IF sy-subrc = 0.
        lo_it ?= lo_itd.
      ENDIF.
    CATCH cx_root.
      CLEAR lo_it.
  ENDTRY.

  IF lo_it IS NOT BOUND.
    WRITE: / 'Could not describe it. Either the name is wrong or it is not'.
    WRITE: / 'an interface - check the spelling on the selection screen.'.
  ELSE.
    DESCRIBE TABLE lo_it->methods LINES lv_n.
    lv_txt = |{ lv_n } method(s) - every one of them has to be implemented|.
    WRITE: / lv_txt.
    SKIP.
    LOOP AT lo_it->methods INTO DATA(ls_im).
      SKIP.
      lv_txt = |  { ls_im-name }|.
      WRITE: / lv_txt.

      IF ls_im-parameters IS INITIAL.
        WRITE: / '     (no parameters declared)'.
        CONTINUE.
      ENDIF.

*     EXACTLY the shape the DPC section below already proves: NAME,
*     PARM_KIND and IS_OPTIONAL on the row, and the type from
*     GET_METHOD_PARAMETER_TYPE( ). Not a component called TYPE - this
*     report activation-failed on that once already.
      LOOP AT ls_im-parameters INTO DATA(ls_ip).
        DATA lo_ipt  TYPE REF TO cl_abap_typedescr.
        DATA lv_ityp TYPE string.
        CLEAR: lo_ipt, lv_ityp.

        CALL METHOD lo_it->get_method_parameter_type
          EXPORTING  p_method_name       = ls_im-name
                     p_parameter_name    = ls_ip-name
          RECEIVING  p_descr_ref         = lo_ipt
          EXCEPTIONS parameter_not_found = 1
                     method_not_found    = 2
                     OTHERS              = 3.
        IF sy-subrc = 0 AND lo_ipt IS BOUND.
          lv_ityp = lo_ipt->absolute_name.
        ELSE.
          lv_ityp = '(type not readable)'.
        ENDIF.

        lv_txt = |     { ls_ip-name } · kind { ls_ip-parm_kind }| &&
                 | · optional { ls_ip-is_optional }| &&
                 | · { lv_ityp }|.
        WRITE: / lv_txt.
      ENDLOOP.
    ENDLOOP.
  ENDIF.
  SKIP.

  WRITE: / 'Implementers of', p_intf.
  ULINE.

* ---------------------------------------------------------------- who
* SEOMETAREL is the class/interface relation table.
*
* SELECT * AND ASSIGN COMPONENT, NOT NAMED COLUMNS - and after two shape
* errors in this one file that is proportionate rather than fussy.
*
* Naming RELTYPE or VERSION in the SELECT list or the WHERE would put this
* report's ability to COMPILE on my memory of a DDIC table I cannot open
* from here. A column that turns out not to exist is not a wrong answer, it
* is a syntax error - the same outcome IS_ABSTRACT and LS_PAR-TYPE just
* produced. ASSIGN COMPONENT moves that to runtime, where a missing column
* is reported and the report still runs.
*
* REFCLSNAME is the one column named, because it is what the table exists
* for: SEOMETAREL relates a class to an interface or superclass. If even
* that is wrong nothing here can work and the SELECT says so plainly.
  SELECT * FROM seometarel
    WHERE refclsname = @p_intf
    ORDER BY PRIMARY KEY
    INTO TABLE @DATA(lt_rel).

* NO RETURN HERE, and that is the fix to a flow bug rather than a style
* choice. This used to RETURN when the interface had no implementers -
* which skipped the DPC section below entirely, and that section is now
* the MORE valuable half: if GET_EXPANDED_ENTITY does not declare
* IO_EXPAND at all then the implementer list does not matter and the
* report would have stopped just before saying so.
  IF lt_rel IS INITIAL.
    WRITE: / 'No rows in SEOMETAREL for that name. Check the spelling -'.
    WRITE: / 'and read the DPC section below anyway, which is the part'.
    WRITE: / 'that says whether an expand object is even wanted.'.
    SKIP.
  ELSE.
    DESCRIBE TABLE lt_rel LINES lv_n.
    lv_txt = |{ lv_n } SEOMETAREL row(s) referencing it|.
    WRITE: / lv_txt.
    SKIP.
  ENDIF.

* RELTYPE 1 is an interface IMPLEMENTATION and 2 is inheritance; VERSION 1
* is active. Both are read through ASSIGN COMPONENT and both are REPORTED
* rather than filtered on - so a row that is not what those codes are
* believed to mean is still listed, with its codes visible, instead of
* being silently dropped. A filter here answering "no implementers" for an
* interface that has plenty is the misleading direction, and the one this
* report exists to avoid.
  DATA lt_impl TYPE TABLE OF seoclsname.

  LOOP AT lt_rel ASSIGNING FIELD-SYMBOL(<rel>).
    ASSIGN COMPONENT 'CLSNAME' OF STRUCTURE <rel> TO FIELD-SYMBOL(<cls>).
    IF sy-subrc <> 0.
*     EXIT the loop, not RETURN from the report - same reason as above:
*     the DPC section is what has to be reached.
      WRITE: / 'SEOMETAREL has no CLSNAME component - skipping the list.'.
      EXIT.
    ENDIF.

    DATA(lv_rt) = `?`.
    DATA(lv_vr) = `?`.
    ASSIGN COMPONENT 'RELTYPE' OF STRUCTURE <rel> TO FIELD-SYMBOL(<rt>).
    IF sy-subrc = 0.
      lv_rt = condense( CONV string( <rt> ) ).
    ENDIF.
    ASSIGN COMPONENT 'VERSION' OF STRUCTURE <rel> TO FIELD-SYMBOL(<vr>).
    IF sy-subrc = 0.
      lv_vr = condense( CONV string( <vr> ) ).
    ENDIF.

    lv_txt = |{ <cls> } · reltype { lv_rt } (1=implements, 2=inherits)| &&
             | · version { lv_vr } (1=active)|.
    WRITE: / lv_txt.

    APPEND CONV seoclsname( <cls> ) TO lt_impl.
  ENDLOOP.

  SKIP.

* ------------------------------------------------- and what each one wants
* THE CONSTRUCTOR IS THE WHOLE QUESTION. An expand object that cannot be
* instantiated is no better than none, and the request-context work showed
* that the difference between a usable standard class and an unusable one is
* entirely in what its constructor demands: /IWBEP/CL_MGW_REQUEST_UNITTST
* constructs happily and is still useless, because it never sets MR_REQUEST.
*
* So: every parameter, its kind, whether it is optional, and its type. A
* class whose mandatory parameters are all types that can be named and built
* is a candidate; one that wants an object of an unreadable type is not.
  LOOP AT lt_impl INTO DATA(ls_impl).

    ULINE.
    WRITE: / ls_impl.

    DATA lo_cls TYPE REF TO cl_abap_classdescr.
    DATA lo_any TYPE REF TO cl_abap_typedescr.
    CLEAR lo_cls.

*   DESCRIBE_BY_NAME as a CALL METHOD with an exception block, not as a
*   functional call: a class in the list whose own load fails must not take
*   this report down with it.
    TRY.
        CALL METHOD cl_abap_typedescr=>describe_by_name
          EXPORTING  p_name         = ls_impl
          RECEIVING  p_descr_ref    = lo_any
          EXCEPTIONS type_not_found = 1
                     OTHERS         = 2.
        IF sy-subrc <> 0.
          WRITE: / '   cannot be described - type not found'.
          CONTINUE.
        ENDIF.
        lo_cls ?= lo_any.
      CATCH cx_root.
        WRITE: / '   cannot be described'.
        CONTINUE.
    ENDTRY.

*   ABSTRACT AND THE CREATION VISIBILITY ARE NOT PRINTED, and the reason is
*   the point of this whole report.
*
*   The first version read LO_CLS->IS_ABSTRACT and
*   LO_CLS->CREATE_VISIBILITY. Neither is a component of
*   CL_ABAP_CLASSDESCR - "Field IS_ABSTRACT is unknown" - so this report,
*   written to stop a standard object's shape being guessed at, would not
*   activate because its own author guessed at one. Only the components
*   ZCL_RAK_CJ_REQ_CTX already proves in working code are used now:
*   METHODS, and NAME / PARM_KIND / IS_OPTIONAL on a parameter row.
*
*   Nothing is lost that matters. A class that cannot be instantiated fails
*   at the CREATE OBJECT the real factory will do, inside a TRY, and says
*   so - which is the same answer one step later and does not depend on
*   reading an attribute correctly.

    READ TABLE lo_cls->methods INTO DATA(ls_m) WITH KEY name = 'CONSTRUCTOR'.
    IF sy-subrc <> 0.
*     NO CONSTRUCTOR ROW MEANS A PARAMETERLESS ONE - which is the best
*     possible answer here, and the one to try first.
      WRITE: / '   CONSTRUCTOR: none declared - parameterless. TRY THIS ONE FIRST.'.
      CONTINUE.
    ENDIF.

    IF ls_m-parameters IS INITIAL.
      WRITE: / '   CONSTRUCTOR: declared with no parameters. TRY THIS ONE FIRST.'.
      CONTINUE.
    ENDIF.

    WRITE: / '   CONSTRUCTOR:'.
    LOOP AT ls_m-parameters INTO DATA(ls_par).

*     THE TYPE COMES FROM GET_METHOD_PARAMETER_TYPE( ), not from a
*     component of the parameter row. LS_PAR has NAME, PARM_KIND and
*     IS_OPTIONAL - the three ZCL_RAK_CJ_REQ_CTX reads - and no TYPE:
*     "The data object LS_PAR does not have a component called TYPE."
*     Same mistake as IS_ABSTRACT above, in the same report, on the same
*     object. Once is carelessness; twice in one file is a habit, and the
*     habit is writing against a remembered shape instead of the one the
*     working code next door demonstrates.
      DATA lo_par TYPE REF TO cl_abap_typedescr.
      DATA lv_type TYPE string.
      CLEAR: lo_par, lv_type.

      CALL METHOD lo_cls->get_method_parameter_type
        EXPORTING  p_method_name       = ls_m-name
                   p_parameter_name    = ls_par-name
        RECEIVING  p_descr_ref         = lo_par
        EXCEPTIONS parameter_not_found = 1
                   method_not_found    = 2
                   OTHERS              = 3.
      IF sy-subrc = 0 AND lo_par IS BOUND.
*       ABSOLUTE_NAME rather than a formatted type: it is the one string
*       that names any type unambiguously, including a local or generated
*       one, and it is what a factory would have to be able to CREATE DATA
*       against. If it reads \CLASS=... or \TYPE=%_T00... that parameter is
*       the reason this candidate is unusable.
        lv_type = lo_par->absolute_name.
      ELSE.
        lv_type = '(type not readable)'.
      ENDIF.

      lv_txt = |     { ls_par-name } · kind { ls_par-parm_kind }| &&
               | · optional { ls_par-is_optional }| &&
               | · { lv_type }|.
      WRITE: / lv_txt.
    ENDLOOP.

  ENDLOOP.

* ============ THE DPC'S OWN EXPANDED METHODS, AS DECLARED ============
*
* THIS IS THE HALF THAT ANSWERS THE QUESTION. Everything above is about
* what could be PASSED for IO_EXPAND; this is about whether it is even
* wanted, and what else the method needs.
*
* Printed by RTTI from the class itself, because the DPC is not in any
* repository readable from where this was written and its methods are
* PROTECTED - so only a subclass may call them, which is exactly why
* ZCL_RAK_CJ_API inherits it. A signature guessed from a name is what
* cost three activation rounds on ZCL_RAK_CJ_REQ_CTX.
*
* WHAT TO LOOK FOR, in order:
*   1. Is there a *_GET_EXPANDED_ENTITY at all, singular? The live URL
*      carries a key, so that is the one the dialog calls.
*   2. Does it declare IO_EXPAND? If not, there is nothing to solve and
*      the tabs are one method call away.
*   3. If it does - is it OPTIONAL? Optional and unread is the same as
*      absent. The plural method declares it optional and dereferences it
*      anyway, which is the trap this whole line of work started from.
*   4. What types the other parameters want. IT_KEY_TAB or an
*      IS_KEY_TAB-shaped structure will need Intreno and Partnerguid -
*      both of which CJS already has.
  ULINE.
  WRITE: / 'EXPANDED methods on', p_dpc.
  ULINE.

  DATA lo_dpc  TYPE REF TO cl_abap_classdescr.
  DATA lo_dany TYPE REF TO cl_abap_typedescr.

  TRY.
      CALL METHOD cl_abap_typedescr=>describe_by_name
        EXPORTING  p_name         = p_dpc
        RECEIVING  p_descr_ref    = lo_dany
        EXCEPTIONS type_not_found = 1
                   OTHERS         = 2.
      IF sy-subrc <> 0.
        WRITE: / 'Not found. Check the class name - it is a PARAMETER.'.
        RETURN.
      ENDIF.
      lo_dpc ?= lo_dany.
    CATCH cx_root.
      WRITE: / 'Could not be described.'.
      RETURN.
  ENDTRY.

  DATA lv_hits TYPE i.

  LOOP AT lo_dpc->methods INTO DATA(ls_dm).

*   EVERY method whose name mentions EXPAND, not only the two expected
*   ones. A DPC generated for this service may name them differently per
*   entity set, and a filter on the two guessed names would answer
*   "nothing here" for a class full of them.
    IF ls_dm-name NS 'EXPAND'.
      CONTINUE.
    ENDIF.
    lv_hits = lv_hits + 1.

    SKIP.
    WRITE: / ls_dm-name.

    IF ls_dm-parameters IS INITIAL.
      WRITE: / '   (no parameters declared)'.
      CONTINUE.
    ENDIF.

    LOOP AT ls_dm-parameters INTO DATA(ls_dp).

      DATA lo_dt   TYPE REF TO cl_abap_typedescr.
      DATA lv_dtyp TYPE string.
      CLEAR: lo_dt, lv_dtyp.

*     The type comes from GET_METHOD_PARAMETER_TYPE( ), never from a
*     component of the parameter row - LS_DP has NAME, PARM_KIND and
*     IS_OPTIONAL and no TYPE, which this report already got wrong once.
      CALL METHOD lo_dpc->get_method_parameter_type
        EXPORTING  p_method_name       = ls_dm-name
                   p_parameter_name    = ls_dp-name
        RECEIVING  p_descr_ref         = lo_dt
        EXCEPTIONS parameter_not_found = 1
                   method_not_found    = 2
                   OTHERS              = 3.
      IF sy-subrc = 0 AND lo_dt IS BOUND.
        lv_dtyp = lo_dt->absolute_name.
      ELSE.
        lv_dtyp = '(type not readable)'.
      ENDIF.

      lv_txt = |     { ls_dp-name } · kind { ls_dp-parm_kind }| &&
               | · optional { ls_dp-is_optional }| &&
               | · { lv_dtyp }|.
      WRITE: / lv_txt.

    ENDLOOP.

  ENDLOOP.

  IF lv_hits = 0.
    SKIP.
    WRITE: / 'No method on this class mentions EXPAND.'.
    WRITE: / 'Either the name is wrong, or the expanded reads live on the'.
    WRITE: / 'generated DPC rather than its _EXT subclass - try'.
    WRITE: / 'ZCL_ZEGA_CJ_DPC in the parameter.'.
  ENDIF.

  SKIP.

  SKIP.
  ULINE.
  WRITE: / 'NEXT STEP'.
  WRITE: / '  Hand this list back. A class with a parameterless'.
  WRITE: / '  constructor, not abstract and publicly creatable, is the'.
  WRITE: / '  candidate to build ZCL_RAK_CJ_EXPAND around - the same'.
  WRITE: / '  RTTI-factory shape as ZCL_RAK_CJ_REQ_CTX, so a wrong guess'.
  WRITE: / '  is a catchable runtime error rather than a class that will'.
  WRITE: / '  not load.'.
  SKIP.
  WRITE: / '  Then GET_CHILDREN( ) has to answer something the DPC accepts.'.
  WRITE: / '  Constructing the object is NOT the same as satisfying it -'.
  WRITE: / '  that is exactly the trap /IWBEP/CL_MGW_REQUEST_UNITTST set on'.
  WRITE: / '  the request context, where it constructed fine and then'.
  WRITE: / '  raised DATREF_NOT_ASSIGNED on the first header read. Only a'.
  WRITE: / '  real expanded read proves this, and the six parcel tabs are'.
  WRITE: / '  the test.'.
