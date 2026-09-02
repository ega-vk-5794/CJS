REPORT zrak_cj_expand_diag.

*&---------------------------------------------------------------------*
*& What can stand in for /IWBEP/IF_MGW_ODATA_EXPAND - printed, not guessed
*&
*& THE PROBLEM THIS EXISTS TO END. The parcel details dialog draws seven
*& tabs and only the Map tab has data. The other six - General, Business
*& Partners, Land, Development, Measurements, Documents - are one read:
*&
*&     PropertiesSet( … )?$expand=ToProject,ToPartner,ToMeasurement,
*&                                 ToLandUse,ToDevelopment,ToAttachment
*&
*& which routes to PROPERTIESSET_GET_EXPANDED_ENTITYSET, and that method
*& calls IO_EXPAND->GET_CHILDREN( ) unguarded. So the tabs are not empty
*& because the data is missing or the filters are wrong - they are empty
*& because there is no expand object to pass, exactly as the entity-set
*& reads had no request context until ZCL_RAK_CJ_REQ_CTX was built. Same
*& class of problem, and it should have the same answer.
*&
*& The same gate holds FloorSet (RAK_FLOORUNIT), Project and License, so
*& this is not only about six tabs.
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

START-OF-SELECTION.

* Everything reaches WRITE through a variable. WRITE takes data objects,
* not expressions, and a method call in the operand fails at activation for
* a reason unrelated to what is being tested - the same care
* ZRAK_CJ_REQCTX_DIAG takes.
  DATA lv_txt   TYPE string.
  DATA lv_n     TYPE i.

  WRITE: / 'Implementers of', p_intf.
  ULINE.

* ---------------------------------------------------------------- who
* SEOMETAREL is the class/interface relation table. RELTYPE 1 is an
* interface IMPLEMENTATION (2 is inheritance), and VERSION 1 is the active
* version.
*
* UNVERIFIED FROM THE ENVIRONMENT THIS WAS WRITTEN IN: the RELTYPE and
* VERSION codes above are the documented ones but could not be confirmed
* against a live system. If this prints nothing, drop the RELTYPE filter
* first - a wrong constant here answers "no implementers" for an interface
* that has plenty, which is the misleading direction.
  SELECT clsname FROM seometarel
    WHERE refclsname = @p_intf
      AND reltype    = 1
      AND version    = 1
    ORDER BY clsname
    INTO TABLE @DATA(lt_impl).

  IF lt_impl IS INITIAL.
    WRITE: / 'No implementers found with RELTYPE = 1 AND VERSION = 1.'.
    WRITE: / 'Retrying without either filter - see the note in the source.'.
    SKIP.
    SELECT clsname, reltype, version FROM seometarel
      WHERE refclsname = @p_intf
      ORDER BY clsname
      INTO TABLE @DATA(lt_any).
    LOOP AT lt_any INTO DATA(ls_any).
      lv_txt = |{ ls_any-clsname } (reltype { ls_any-reltype }, version { ls_any-version })|.
      WRITE: / lv_txt.
    ENDLOOP.
    IF lt_any IS INITIAL.
      WRITE: / 'Nothing at all. Check the interface name.'.
    ENDIF.
    RETURN.
  ENDIF.

  DESCRIBE TABLE lt_impl LINES lv_n.
  lv_txt = |{ lv_n } implementer(s)|.
  WRITE: / lv_txt.
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
    WRITE: / ls_impl-clsname.

    DATA lo_cls TYPE REF TO cl_abap_classdescr.
    DATA lo_any TYPE REF TO cl_abap_typedescr.
    CLEAR lo_cls.

*   DESCRIBE_BY_NAME as a CALL METHOD with an exception block, not as a
*   functional call: a class in the list whose own load fails must not take
*   this report down with it.
    TRY.
        CALL METHOD cl_abap_typedescr=>describe_by_name
          EXPORTING  p_name         = ls_impl-clsname
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

*   ABSTRACT and the creation visibility decide whether it can be made at
*   all, before any parameter matters.
    lv_txt = |   abstract: { lo_cls->is_abstract } · create visibility: { lo_cls->create_visibility }|.
    WRITE: / lv_txt.

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
      lv_txt = |     { ls_par-name } · kind { ls_par-parm_kind }| &&
               | · optional { ls_par-is_optional }| &&
               | · type { ls_par-type_kind } { ls_par-type }|.
      WRITE: / lv_txt.
    ENDLOOP.

  ENDLOOP.

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
