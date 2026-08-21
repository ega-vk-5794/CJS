class Z2UI5_CL_EXT_RAKPAY definition
  public
  final
  create public .

public section.

  types:
    BEGIN OF ty_payment,
        quick                TYPE flag,
        mrak                 TYPE flag,
        kiosk                TYPE flag,
        walkin               TYPE flag,
        edirham              TYPE flag,
        creditcard           TYPE flag,
        nextvisible          TYPE flag,
        donate               TYPE flag,
        busyindicatorvisible TYPE flag,
        title                TYPE string,
        text                 TYPE string,
      END OF ty_payment .

  methods RAKPAY
    importing
      !IO_PARENT type ref to Z2UI5_CL_XML_FRAGMENT .
  methods CONSTRUCTOR
    importing
      !CLIENT type ref to Z2UI5_IF_CLIENT .
  methods RAKPAY_POPUP
    importing
      !IV_URL type STRING .
protected section.

  data CLIENT type ref to Z2UI5_IF_CLIENT .
private section.

  data MS_PAYMENT type TY_PAYMENT .
ENDCLASS.



CLASS Z2UI5_CL_EXT_RAKPAY IMPLEMENTATION.


  METHOD constructor.
    me->client = client.
  ENDMETHOD.


  METHOD rakpay.

    DATA(root) = io_parent.

    DATA(pay_btn) = root->button(
                       visible   = '{= !${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Pay'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'PAY' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).

    DATA(next_btn) = root->button(
                       visible   = '{= ${/XX/MS_PAYMENT/NEXTVISIBLE} }'
                       text      = 'Next'
                       icon      = 'sap-icon://icomoon/Right'
                       press     = client->_event( 'SAVE' )
                       class     = 'regularBTN'
                       iconfirst = 'false' ).
  ENDMETHOD.


  METHOD rakpay_popup.
    DATA: lv_script TYPE string.

    DATA(script) = z2ui5_cl_xml_view=>factory( ).
    lv_script = 'window.open("' && iv_url && '", "_blank");'.
    script->_generic( ns = 'html' name = 'script' )->_cc_plain_xml( lv_script ).

*    client->view_display( script->stringify( ) ).

    DATA(popup) = z2ui5_cl_xml_fragment=>factory( ).

    ms_payment-title = 'Payment Processing' .
    ms_payment-text  = 'Please don’t close the window until the processing is done'.
    ms_payment-busyindicatorvisible = abap_true.

    " TODO: ->dialog( ) - not yet confirmed against z2ui5_cl_xml_view's actual API surface,
    " same caveat as file_uploader/progress_indicator/custom_data earlier.
    DATA(pay_dialog) = popup->dialog(
                          id                   = 'payDialog'
                          showheader           = 'false'
                          horizontalscrolling  = 'false'
                          class                = 'confirmDialog payDialogBorderTopGray' ).

    pay_dialog->custom_data( )->core_custom_data( key = 'URL' value = iv_url ).

    DATA(outer_vbox) = pay_dialog->vbox( width = '100%' class = 'confirmDialog-vbox' ).
    DATA(inner_vbox) = outer_vbox->vbox( width = '100%' class = 'confirmDialog-inner-vbox' ).

    DATA(header_row) = inner_vbox->hbox( width = '100%' justifycontent = 'SpaceBetween' alignitems = 'Center' ).
    DATA(title_text) = header_row->text( text = '{/XX/MS_PAYMENT/TITLE}' class = 'color-black font1125 weight500' ).
    DATA(close_icon) = header_row->icon(
                           visible = '{= !${/XX/MS_PAYMENT/BUSYINDICATORVISIBLE} }'
                           src     = 'sap-icon://icomoon/close'
                           color   = '#10233E'
                           size    = '1.5rem'
                           press   = '.destroyPopup' ).

    DATA(body_text) = inner_vbox->text( text = '{/XX/MS_PAYMENT/TEXT}' class = 'color-black font1 weight400' ).

    DATA(busy_row) = inner_vbox->hbox( class = 'payDialog-busy-hbox' width = '100%' justifycontent = 'Center' alignitems = 'Center' ).
    DATA(busy_indicator) = busy_row->busy_indicator( visible = '{/XX/MS_PAYMENT/BUSYINDICATORVISIBLE}' ).

    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.
ENDCLASS.
