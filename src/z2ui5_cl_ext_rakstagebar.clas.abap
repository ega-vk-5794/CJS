class Z2UI5_CL_EXT_RAKSTAGEBAR definition
  public
  final
  create public .

public section.

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

  methods STEP_FORWARD
    importing
      !DIRECTION type CHAR1 optional
      !CONTROL type ref to OBJECT
    returning
      value(ET_STAGES) type TT_STAGES .
  methods GET_CURRENT_SCREEN
    returning
      value(SCREEN) type STRING .
  methods RAKSTAGEBAR
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT .
  methods CONSTRUCTOR
    importing
      !MT_STAGES type TT_STAGES optional .
  PROTECTED SECTION.
private section.

  data MT_STAGES type TT_STAGES .
ENDCLASS.



CLASS Z2UI5_CL_EXT_RAKSTAGEBAR IMPLEMENTATION.


  METHOD constructor.
    me->mt_stages[] = mt_stages[].

  ENDMETHOD.


  METHOD get_current_screen.
    READ TABLE mt_stages ASSIGNING FIELD-SYMBOL(<stage>) WITH KEY current = abap_true.
    IF sy-subrc EQ 0.
      screen = <stage>-screen.
    ENDIF.
  ENDMETHOD.


  METHOD rakstagebar.


    DATA(id_rak_stagebar) = io_parent->vbox( id = 'id-rak-stagebar' width = '100%' class = 'rak-stagebar-margin' rendertype = 'Bare' ).

    " ===================== DESKTOP =====================
    DATA(desktop) = id_rak_stagebar->hbox( width = '100%' visible = 'true' rendertype = 'Bare' ).

    " repeating aggregation - one HBox per stage, bound to oStageBarData>/stages
    DATA(stages) = desktop->hbox( items = '{/XX/MT_STAGES}' justifycontent = 'Start' alignitems = 'Start' rendertype = 'Bare' ).
*    LOOP AT mt_stages INTO DATA(ls_stage).
    DATA(stage_item) = stages->hbox( rendertype = 'Bare' ).

    " ---- STEP VBOX ----
    DATA(step_cont) = stage_item->vbox( width = '120px' justifycontent = 'Start' alignitems = 'Center' class = 'rak-stagebar-step-cont' rendertype = 'Bare' ).

    " -- lines & circle row --
    DATA(lines_circle) = step_cont->hbox( justifycontent = 'Start' alignitems = 'Start' rendertype = 'Bare' ).

    " left line
    DATA(left_line) = lines_circle->hbox( width = '2.8125rem' height = '0.9375rem' rendertype = 'Bare' ).
    DATA(left_line_gray) = left_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYLEFTLINE}' rendertype = 'Bare' ).
    DATA(left_line_green) = left_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENLEFTLINE}' rendertype = 'Bare' ).

    " circle
    DATA(circle) = lines_circle->hbox( width = '1.875rem' height = '1.875rem' rendertype = 'Bare' ).

    DATA(circle_red) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-red' visible = '{REDCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_red_text) = circle_red->text( text = '{STAGENUMBER}' class = 'Body_2_2 color-white' ).

    DATA(circle_green) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-green' visible = '{GREENCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_green_icon) = circle_green->icon( src = 'sap-icon://icomoon/fi_check' color = '#53A56E' class = 'rak-stagebar-step-done-icon' ).

    DATA(circle_gray) = circle->hbox( class = 'rak-stagebar-circle-cont rak-stagebar-circle-gray' visible = '{GRAYCIRCLE}' rendertype = 'Bare' ).
    DATA(circle_gray_text) = circle_gray->text( text = '{STAGENUMBER}' class = 'Body_2_3 color-gray4' ).

    " right line
    DATA(right_line) = lines_circle->hbox( width = '2.8125rem' height = '0.9375rem' rendertype = 'Bare' ).
    DATA(right_line_gray) = right_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYRIGHTLINE}' rendertype = 'Bare' ).
    DATA(right_line_green) = right_line->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENRIGHTLINE}' rendertype = 'Bare' ).

    " -- text row --
    DATA(text_row) = step_cont->hbox( width = '100%' justifycontent = 'Center' alignitems = 'Start' rendertype = 'Bare' ).
    DATA(text_red) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-red rak-stagebar-text-align-desktop' visible = '{REDSTAGELABEL}' ).
    DATA(text_gray) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-gray4 rak-stagebar-text-align-desktop' visible = '{GRAYSTAGELABEL}' ).
    DATA(text_green) = text_row->text( text = '{STAGELABEL}' class = 'Body_2_3 color-green rak-stagebar-text-align-desktop' visible = '{GREENSTAGELABEL}' ).

    " ---- GAP VBOX ----
    " NOTE: width is set programmatically client-side (StepBarInit()), same as source fragment's own comment.
    DATA(gap) = stage_item->vbox( width = '72px' height = '0.9375rem' justifycontent = 'Start'
                                   visible = '{ISLAST}' rendertype = 'Bare' ).
    DATA(gap_gray) = gap->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-gray3' visible = '{GRAYGAP}' rendertype = 'Bare' ).
    DATA(gap_green) = gap->hbox( width = '100%' height = '100%' class = 'rak-stagebar-line-green' visible = '{GREENGAP}' rendertype = 'Bare' ).

*    ENDLOOP.

    " ===================== MOBILE =====================
    DATA(mobile) = id_rak_stagebar->vbox( alignitems = 'Start' visible = 'false' width = '20.5rem' rendertype = 'Bare' ).

    DATA(mobile_label_row) = mobile->hbox( justifycontent = 'Start' rendertype = 'Bare' ).
    DATA(mobile_label) = mobile_label_row->text( text = '{oStageBarData>/settings/CurrentStageLabel}' class = 'Body_1_1 color-Gray7' ).

    DATA(mobile_progress_row) = mobile->hbox( justifycontent = 'SpaceBetween' alignitems = 'Center' width = '100%' rendertype = 'Bare' ).
    DATA(mobile_progress_bar) = mobile_progress_row->hbox( width = '70%' height = '0.375rem' rendertype = 'Bare' ).
    DATA(mobile_progress_indicator) = mobile_progress_bar->progress_indicator(
                                          displayonly  = 'true'
                                          percentvalue = '{oStageBarData>/settings/ProgressPercent}'
                                          height       = '100%'
                                          width        = '100%'
                                          class        = 'rak-stagebar-progress-indicator' ).

    " {i18n>step} X {i18n>of} Y - two i18n text-pool fragments interpolated around bound numbers.
    DATA(mobile_step_text) = mobile_progress_row->text(
                                text  = '{i18n>step} {oStageBarData>/settings/CurrentStage} {i18n>of} {oStageBarData>/settings/TotalStages}'
                                class = 'Body_2_3 color-gray7' ).
  ENDMETHOD.


  METHOD step_forward.
    READ TABLE mt_stages ASSIGNING FIELD-SYMBOL(<stage>) WITH KEY current = abap_true.
    IF sy-subrc EQ 0.
      DATA(lv_tabix) = sy-tabix.
      <stage>-current = abap_false.
      CASE direction.
        WHEN '-'.
          SUBTRACT 1 FROM lv_tabix.
        WHEN '+'.
          ADD 1 TO lv_tabix.
        WHEN '='.
        WHEN OTHERS.
      ENDCASE.
      IF lv_tabix GT 0.
        READ TABLE mt_stages ASSIGNING <stage> INDEX lv_tabix.
      ELSE.
        READ TABLE mt_stages ASSIGNING <stage> INDEX 1.
      ENDIF.
    ELSE.
      READ TABLE mt_stages ASSIGNING <stage> INDEX 1.
    ENDIF.
    IF sy-subrc EQ 0.
      lv_tabix = sy-tabix.

      LOOP AT mt_stages ASSIGNING FIELD-SYMBOL(<next_stage>).
        DATA(lv_line) = sy-tabix.
        <next_stage>-stagenumber = lv_line.
        SHIFT <next_stage>-stagenumber LEFT DELETING LEADING space.

        <next_stage>-grayleftline      = ''.
        <next_stage>-greenleftline     = ''.
        <next_stage>-redcircle         = ''.
        <next_stage>-greencircle       = ''.
        <next_stage>-graycircle        = ''.
        <next_stage>-grayrightline     = ''.
        <next_stage>-greenrightline    = ''.
        <next_stage>-redstagelabel     = ''.
        <next_stage>-graystagelabel    = ''.
        <next_stage>-greenstagelabel   = ''.
        <next_stage>-graygap           = ''.
        <next_stage>-greengap          = ''.
        <next_stage>-islast            = 'X'.
        IF lv_line EQ lines( mt_stages ).
          <next_stage>-islast          = ''.
        ENDIF.

        IF lv_line LT lv_tabix.
          <next_stage>-status          = 'Completed'.
          IF lv_line GT 1.
            <next_stage>-greenleftline   = 'X'.
          ENDIF.
          <next_stage>-greenrightline  = 'X'.
          <next_stage>-greengap        = 'X'.
          <next_stage>-greencircle     = 'X'.
          <next_stage>-greenstagelabel = 'X'.
        ENDIF.
        IF lv_line GT lv_tabix.
          <next_stage>-status          = 'Disabled'.
          <next_stage>-graycircle      = 'X'.
          <next_stage>-graystagelabel  = 'X'.
          <next_stage>-grayleftline   = 'X'.
          IF <next_stage>-islast EQ 'X'.
            <next_stage>-grayrightline = 'X'.
            <next_stage>-graygap       = 'X'.
          ENDIF.
        ENDIF.
      ENDLOOP.

      <stage>-current                  = abap_true.
      <stage>-status                   = 'Current'.
      <stage>-redcircle                = 'X'.
      <stage>-redstagelabel            = 'X'.
      <stage>-grayrightline            = 'X'.
      <stage>-graygap                  = 'X'.
      IF lv_tabix GT 1.
        <stage>-greenleftline          = 'X'.
      ENDIF.
      CALL METHOD control->(<stage>-screen).

      et_stages[] = me->mt_stages[].


    ENDIF.
  ENDMETHOD.
ENDCLASS.
