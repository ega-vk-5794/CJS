class Z2UI5_CL_EXT_RAKSTAGEBAR definition
  public
  final
  create public .

public section.

  interfaces Z2UI5_IF_EXT_RAKSTAGEBAR .

  methods CONSTRUCTOR
    importing
      !CLIENT type ref to Z2UI5_IF_CLIENT optional .
protected section.
private section.
ENDCLASS.



CLASS Z2UI5_CL_EXT_RAKSTAGEBAR IMPLEMENTATION.


  METHOD constructor.
    me->z2ui5_if_ext_rakstagebar~client = client.

    client->_bind_edit( me->z2ui5_if_ext_rakstagebar~mt_stages ).

    CLEAR: me->z2ui5_if_ext_rakstagebar~mt_stages[].
    APPEND INITIAL LINE TO me->z2ui5_if_ext_rakstagebar~mt_stages ASSIGNING FIELD-SYMBOL(<stage>).
    <stage>-stagelabel      = 'Case details'.
    <stage>-screen          = 'SCREEN_NP001_1_1'.
    APPEND INITIAL LINE TO me->z2ui5_if_ext_rakstagebar~mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Case details'.
    <stage>-screen          = 'SCREEN_NP001_1_2'.
    APPEND INITIAL LINE TO me->z2ui5_if_ext_rakstagebar~mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Documents'.
    <stage>-screen          = 'SCREEN_NP001_1_3'.
    APPEND INITIAL LINE TO me->z2ui5_if_ext_rakstagebar~mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Payment'.
    <stage>-screen          = 'SCREEN_NP001_1_4'.
    APPEND INITIAL LINE TO me->z2ui5_if_ext_rakstagebar~mt_stages ASSIGNING <stage>.
    <stage>-stagelabel      = 'Confirmation'.
    <stage>-screen          = 'SCREEN_NP001_1_5'.

  ENDMETHOD.


  METHOD z2ui5_if_ext_rakstagebar~rakstagebar.
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
ENDCLASS.
