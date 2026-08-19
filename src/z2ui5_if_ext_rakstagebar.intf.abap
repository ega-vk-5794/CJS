interface Z2UI5_IF_EXT_RAKSTAGEBAR
  public .


  types:
    BEGIN OF ty_stages,
      status          TYPE string,
      stagenumber     TYPE string,
      stagelabel      TYPE string,
      grayleftline    TYPE flag,
      greenleftline   TYPE flag,
      redcircle       TYPE flag,
      greencircle     TYPE flag,
      graycircle      TYPE flag,
      grayrightline   TYPE flag,
      greenrightline  TYPE flag,
      redstagelabel   TYPE flag,
      graystagelabel  TYPE flag,
      greenstagelabel TYPE flag,
      graygap         TYPE flag,
      greengap        TYPE flag,
      islast          TYPE flag,
      screen          TYPE string,
      current         TYPE flag,
    END OF ty_stages .
  types:
    tt_stages TYPE STANDARD TABLE OF ty_stages WITH DEFAULT KEY .

  data MT_STAGES type TT_STAGES .
  data CLIENT type ref to Z2UI5_IF_CLIENT .
endinterface.
