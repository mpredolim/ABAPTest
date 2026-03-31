*&---------------------------------------------------------------------*
*& Report  ZF_WRICEF_PO_FORM
*& WRICEF Type: Form (F)
*& Technology:  Adobe Forms (SFP)
*& Description: Purchase Order Form – prints one Adobe PDF per PO.
*&
*& Selection-Screen parameters:
*&   SO_EBELN – Purchase Order number range (OBLIGATORY).
*&   P_BSART  – Purchase Order type (optional filter).
*&   SO_BEDAT – Date of creation range (optional filter).
*&
*& Adobe Form used: ZFM_PO_ADOBE
*&   (created/maintained via transaction SFP)
*&
*& SAP tables read:
*&   EKKO – Purchasing Document Header
*&   EKPO – Purchasing Document Item
*&   LFA1 – Vendor Master (General Section)
*&   ADR6 / ADRC – Address data (street, city, postal code)
*&---------------------------------------------------------------------*
REPORT zf_wricef_po_form.

*&---------------------------------------------------------------------*
*& Type Definitions
*&---------------------------------------------------------------------*
TYPES:
  " Header data passed to the Adobe Form
  BEGIN OF ty_po_header,
    print_date   TYPE sy-datum,      " Current date
    ebeln        TYPE ebeln,         " PO number
    bsart        TYPE bsart,         " PO type
    bedat        TYPE bedat,         " PO creation date
    lifnr        TYPE lifnr,         " Vendor ID
    vendor_name  TYPE name1_gp,      " Vendor / customer name
    street       TYPE str_street,    " Street
    city         TYPE ort01,         " City
    country      TYPE land1,         " Country
    postal_code  TYPE pstlz,         " Postal code
  END OF ty_po_header,

  " Line-item data passed to the Adobe Form
  BEGIN OF ty_po_item,
    ebelp        TYPE ebelp,         " PO item number
    txz01        TYPE txz01,         " Short text / description
    menge        TYPE bstmg,         " Ordered quantity
    meins        TYPE bstme,         " Unit of measure
    netpr        TYPE netpr,         " Net price per order unit
    peinh        TYPE peinh,         " Price unit
    line_total   TYPE wrbtr,         " Line total (menge * netpr / peinh)
    waers        TYPE waers,         " Currency
  END OF ty_po_item,

  ty_po_items TYPE STANDARD TABLE OF ty_po_item WITH DEFAULT KEY,

  " Totals block passed to the Adobe Form
  BEGIN OF ty_po_totals,
    total_qty    TYPE bstmg,         " Sum of quantities
    subtotal     TYPE wrbtr,         " Sum of all line totals (= subtotal)
    total        TYPE wrbtr,         " Total (same as subtotal for PO)
    waers        TYPE waers,         " Currency
  END OF ty_po_totals.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: so_ebeln FOR ekko-ebeln OBLIGATORY,   " Purchase Order – required
                  so_bedat FOR ekko-bedat.              " Date of Creation – optional
  PARAMETERS:     p_bsart  TYPE bsart.                  " PO Type – optional
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Class Definition
*&---------------------------------------------------------------------*
CLASS lcl_po_form DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      run.

  PRIVATE SECTION.
    CLASS-METHODS:
      fetch_po_headers
        RETURNING
          VALUE(rt_ekko) TYPE STANDARD TABLE OF ekko,

      fetch_po_items
        IMPORTING
          iv_ebeln       TYPE ebeln
        RETURNING
          VALUE(rt_ekpo) TYPE STANDARD TABLE OF ekpo,

      fetch_vendor_data
        IMPORTING
          iv_lifnr          TYPE lifnr
        RETURNING
          VALUE(rs_header)  TYPE ty_po_header,

      build_item_list
        IMPORTING
          it_ekpo           TYPE STANDARD TABLE OF ekpo
        RETURNING
          VALUE(rt_items)   TYPE ty_po_items,

      compute_totals
        IMPORTING
          it_items          TYPE ty_po_items
        RETURNING
          VALUE(rs_totals)  TYPE ty_po_totals,

      print_adobe_form
        IMPORTING
          is_header         TYPE ty_po_header
          it_items          TYPE ty_po_items
          is_totals         TYPE ty_po_totals.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Class Implementation
*&---------------------------------------------------------------------*
CLASS lcl_po_form IMPLEMENTATION.

  METHOD run.
    " ----------------------------------------------------------------
    " 1. Fetch PO headers matching the selection-screen criteria
    " ----------------------------------------------------------------
    DATA(lt_ekko) = fetch_po_headers( ).

    IF lt_ekko IS INITIAL.
      MESSAGE 'No Purchase Orders found for the given selection.' TYPE 'S'
              DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " ----------------------------------------------------------------
    " 2. Loop over each PO and generate one Adobe Form per PO
    " ----------------------------------------------------------------
    LOOP AT lt_ekko INTO DATA(ls_ekko).

      " 2a. Fetch items for this PO
      DATA(lt_ekpo) = fetch_po_items( ls_ekko-ebeln ).

      IF lt_ekpo IS INITIAL.
        CONTINUE.  " Skip POs with no printable items
      ENDIF.

      " 2b. Build vendor / header block
      DATA(ls_header) = fetch_vendor_data( ls_ekko-lifnr ).
      ls_header-print_date := sy-datum.
      ls_header-ebeln       = ls_ekko-ebeln.
      ls_header-bsart       = ls_ekko-bsart.
      ls_header-bedat       = ls_ekko-bedat.

      " 2c. Build item list with line totals
      DATA(lt_items) = build_item_list( lt_ekpo ).

      " 2d. Compute totals
      DATA(ls_totals) = compute_totals( lt_items ).
      ls_totals-waers = ls_ekko-waers.

      " 2e. Print the Adobe Form for this PO
      print_adobe_form(
        is_header = ls_header
        it_items  = lt_items
        is_totals = ls_totals ).

    ENDLOOP.
  ENDMETHOD.


  METHOD fetch_po_headers.
    " Read EKKO filtered by selection-screen options.
    " When p_bsart is empty the condition is skipped (all PO types).
    SELECT * FROM ekko
      INTO TABLE rt_ekko
      WHERE ebeln IN so_ebeln
        AND bedat IN so_bedat
        AND ( bsart = p_bsart OR p_bsart = space ).
  ENDMETHOD.


  METHOD fetch_po_items.
    " Read EKPO for the given PO number (exclude deleted / cancelled items)
    SELECT * FROM ekpo
      INTO TABLE rt_ekpo
      WHERE ebeln = iv_ebeln
        AND loekz = space.  " loekz = space means item not deleted
  ENDMETHOD.


  METHOD fetch_vendor_data.
    " Ensure LIFNR is zero-padded (ALPHA conversion) before the DB read
    DATA lv_lifnr TYPE lifnr.
    lv_lifnr = iv_lifnr.
    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
      EXPORTING
        input  = lv_lifnr
      IMPORTING
        output = lv_lifnr.

    " Read vendor master and address for the given vendor
    SELECT SINGLE name1, stras, ort01, land1, pstlz
      FROM lfa1
      INTO @DATA(ls_lfa1)
      WHERE lifnr = @lv_lifnr.

    IF sy-subrc = 0.
      rs_header-lifnr       = iv_lifnr.
      rs_header-vendor_name = ls_lfa1-name1.
      rs_header-street      = ls_lfa1-stras.
      rs_header-city        = ls_lfa1-ort01.
      rs_header-country     = ls_lfa1-land1.
      rs_header-postal_code = ls_lfa1-pstlz.
    ELSE.
      rs_header-lifnr       = iv_lifnr.
      rs_header-vendor_name = iv_lifnr.  " Fallback: show ID if name not found
    ENDIF.
  ENDMETHOD.


  METHOD build_item_list.
    LOOP AT it_ekpo INTO DATA(ls_ekpo).
      DATA(ls_item) = VALUE ty_po_item(
        ebelp      = ls_ekpo-ebelp
        txz01      = ls_ekpo-txz01
        menge      = ls_ekpo-menge
        meins      = ls_ekpo-meins
        netpr      = ls_ekpo-netpr
        peinh      = ls_ekpo-peinh
        waers      = ls_ekpo-waers ).

      " Calculate line total: quantity × net price / price unit
      IF ls_ekpo-peinh > 0.
        ls_item-line_total = ( ls_ekpo-menge * ls_ekpo-netpr ) / ls_ekpo-peinh.
      ELSE.
        ls_item-line_total = ls_ekpo-menge * ls_ekpo-netpr.
      ENDIF.

      APPEND ls_item TO rt_items.
    ENDLOOP.
  ENDMETHOD.


  METHOD compute_totals.
    LOOP AT it_items INTO DATA(ls_item).
      rs_totals-total_qty = rs_totals-total_qty + ls_item-menge.
      rs_totals-subtotal  = rs_totals-subtotal  + ls_item-line_total.
    ENDLOOP.

    " For a standard PO form, total = subtotal (no tax / discount applied here)
    rs_totals-total = rs_totals-subtotal.
  ENDMETHOD.


  METHOD print_adobe_form.
    " ----------------------------------------------------------------
    " Call the Adobe Form function module generated by SFP transaction.
    " The function module ZFM_PO_ADOBE is created via SFP and its
    " interface matches the parameters below.
    "
    " Output control: open/close spool automatically.
    " ----------------------------------------------------------------
    DATA ls_output_options TYPE sfpoutputparams.
    DATA ls_doc_params     TYPE sfpdocparams.

    " Use print preview (dialog) – change to P for spool / S for PDF
    ls_output_options-nodialog = abap_false.
    ls_output_options-preview  = abap_true.

    " Set document language
    ls_doc_params-langu = sy-langu.

    " Open form processing
    CALL FUNCTION 'FP_JOB_OPEN'
      CHANGING
        ie_outputparams = ls_output_options
      EXCEPTIONS
        cancel          = 1
        usage_error     = 2
        sys_error       = 3
        internal_error  = 4
        OTHERS          = 5.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      RETURN.
    ENDIF.

    " Get the function module name for the form ZFM_PO_ADOBE
    DATA lv_fm_name TYPE funcname.
    CALL FUNCTION 'FP_FUNCTION_MODULE_NAME'
      EXPORTING
        i_name     = 'ZFM_PO_ADOBE'
      IMPORTING
        e_funcname = lv_fm_name
      EXCEPTIONS
        not_found  = 1
        OTHERS     = 2.

    IF sy-subrc <> 0.
      MESSAGE 'Adobe Form ZFM_PO_ADOBE not found. Please create it via transaction SFP.'
              TYPE 'E'.
      RETURN.
    ENDIF.

    " Call the generated function module dynamically
    CALL FUNCTION lv_fm_name
      EXPORTING
        /1bcdwb/docparams = ls_doc_params
        is_header         = is_header
        it_items          = it_items
        is_totals         = is_totals
      EXCEPTIONS
        usage_error       = 1
        sys_error         = 2
        internal_error    = 3
        OTHERS            = 4.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    " Close form processing
    DATA ls_result TYPE sfpjoboutput.
    CALL FUNCTION 'FP_JOB_CLOSE'
      IMPORTING
        ie_result  = ls_result
      EXCEPTIONS
        usage_error    = 1
        sys_error      = 2
        internal_error = 3
        OTHERS         = 4.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Texts (maintained via SE38 / Goto → Text Elements)
*&   TEXT-001 = 'Purchase Order Selection'
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  lcl_po_form=>run( ).
