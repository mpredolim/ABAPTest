*&---------------------------------------------------------------------*
*& Adobe Form Object: ZFM_PO_ADOBE
*& Object Type:       Adobe Form (SFP – Form Builder)
*& Description:       Purchase Order print form used by the WRICEF
*&                    Type F program ZF_WRICEF_PO_FORM.
*&
*& This file documents the Adobe Form interface and layout design.
*& In a real SAP system the form must be created and activated through
*& transaction SFP (Form Builder).
*&
*&---------------------------------------------------------------------*
*
*  ====================================================================
*  1.  FORM PROPERTIES  (SFP → Form → Properties)
*  ====================================================================
*   Form name        : ZFM_PO_ADOBE
*   Description      : Purchase Order – Adobe Form
*   Form type        : Printed form
*   Language         : System language (SY-LANGU)
*   Activation date  : (set on first activation)
*
*  ====================================================================
*  2.  INTERFACE  (SFP → Interface)
*  ====================================================================
*   The form interface defines the ABAP-side parameters that are
*   passed to the generated function module ZFM_PO_ADOBE.
*
*   IMPORT parameters
*   -----------------
*   IS_HEADER   TYPE  ZF_WRICEF_PO_FORM=>TY_PO_HEADER
*               ( or a global DDIC structure ZST_PO_HEADER containing
*                 the same fields – recommended for production use )
*     Fields surfaced in the form:
*       PRINT_DATE    – Current date          (DATS)
*       EBELN         – Purchase Order number  (CHAR 10)
*       BSART         – PO type               (CHAR 4)
*       BEDAT         – PO creation date      (DATS)
*       LIFNR         – Vendor ID             (CHAR 10)
*       VENDOR_NAME   – Vendor name           (CHAR 35)
*       STREET        – Street                (CHAR 60)
*       CITY          – City                  (CHAR 35)
*       COUNTRY       – Country key           (CHAR 3)
*       POSTAL_CODE   – Postal code           (CHAR 10)
*
*   IT_ITEMS    TYPE  STANDARD TABLE OF ZF_WRICEF_PO_FORM=>TY_PO_ITEM
*               ( or a global DDIC table type ZTT_PO_ITEMS )
*     Fields surfaced in the form:
*       EBELP         – Item number           (NUMC 5)
*       TXZ01         – Short description     (CHAR 40)
*       MENGE         – Quantity              (QUAN)
*       MEINS         – Unit of measure       (UNIT)
*       NETPR         – Net unit price        (CURR)
*       PEINH         – Price unit            (DEC)
*       LINE_TOTAL    – Line total (qty×price)(CURR)
*       WAERS         – Currency              (CUKY)
*
*   IS_TOTALS   TYPE  ZF_WRICEF_PO_FORM=>TY_PO_TOTALS
*               ( or a global DDIC structure ZST_PO_TOTALS )
*     Fields surfaced in the form:
*       TOTAL_QTY     – Total quantity        (QUAN)
*       SUBTOTAL      – Subtotal amount       (CURR)
*       TOTAL         – Total amount          (CURR)
*       WAERS         – Currency              (CUKY)
*
*  ====================================================================
*  3.  FORM LAYOUT  (SFP → Layout – Adobe LiveCycle Designer)
*  ====================================================================
*
*   Page 1 (master page: A4 portrait, margins 15 mm)
*   ─────────────────────────────────────────────────────────────────
*   ┌─────────────────────────────────────────────────────────────────┐
*   │  COMPANY LOGO (optional image placeholder, top-right)          │
*   │  ─────────────────────────────────────────────────────────────  │
*   │  PURCHASE ORDER                        Date: <PRINT_DATE>      │
*   │  PO Number : <EBELN>                                           │
*   │  PO Type   : <BSART>                                           │
*   │  Created   : <BEDAT>                                           │
*   │  ─────────────────────────────────────────────────────────────  │
*   │  VENDOR / CUSTOMER                                             │
*   │  ID      : <LIFNR>                                             │
*   │  Name    : <VENDOR_NAME>                                       │
*   │  Address : <STREET>, <POSTAL_CODE> <CITY>, <COUNTRY>          │
*   │  ─────────────────────────────────────────────────────────────  │
*   │  PO ITEMS                                                      │
*   │  ┌───────┬────────────────────────┬──────┬──────┬────────────┐ │
*   │  │ Item# │ Description            │  Qty │ Unit │ Unit Price │ │
*   │  ├───────┼────────────────────────┼──────┼──────┼────────────┤ │
*   │  │<EBELP>│<TXZ01>                 │<MENGE>│<MEINS>│<NETPR>    │ │
*   │  │  ...  │  ...                   │ ...  │ ...  │ ...        │ │
*   │  └───────┴────────────────────────┴──────┴──────┴────────────┘ │
*   │  ─────────────────────────────────────────────────────────────  │
*   │  (shown only when IT_ITEMS has more than 1 row)                │
*   │  Total Quantity : <TOTAL_QTY>                                  │
*   │  Subtotal       : <SUBTOTAL>   <WAERS>                        │
*   │  Total          : <TOTAL>      <WAERS>                        │
*   └─────────────────────────────────────────────────────────────────┘
*
*   Subform structure inside LiveCycle Designer
*   ─────────────────────────────────────────────────────────────────
*   ROOT (flowed)
*   ├── sfHeader        (positioned, static texts + field bindings)
*   │     PrintDate     → $.IS_HEADER.PRINT_DATE
*   │     PONumber      → $.IS_HEADER.EBELN
*   │     POType        → $.IS_HEADER.BSART
*   │     POCreated     → $.IS_HEADER.BEDAT
*   ├── sfVendor        (positioned)
*   │     VendorID      → $.IS_HEADER.LIFNR
*   │     VendorName    → $.IS_HEADER.VENDOR_NAME
*   │     VendorStreet  → $.IS_HEADER.STREET
*   │     VendorCity    → $.IS_HEADER.CITY
*   │     VendorCountry → $.IS_HEADER.COUNTRY
*   │     VendorZIP     → $.IS_HEADER.POSTAL_CODE
*   ├── sfItemsTable    (flowed, repeating – bound to IT_ITEMS)
*   │   └── sfItemRow   (repeating subform, one row per IT_ITEMS entry)
*   │         ItemNum   → $.IT_ITEMS[*].EBELP
*   │         Descr     → $.IT_ITEMS[*].TXZ01
*   │         Qty       → $.IT_ITEMS[*].MENGE
*   │         UoM       → $.IT_ITEMS[*].MEINS
*   │         UnitPrice → $.IT_ITEMS[*].NETPR
*   │         LineTotal → $.IT_ITEMS[*].LINE_TOTAL
*   └── sfTotals        (flowed, conditional visibility)
*         Visibility script (JavaScript):
*           this.presence = (xfa.resolveNode("IT_ITEMS").count > 1)
*                           ? "visible" : "hidden";
*         TotalQty    → $.IS_TOTALS.TOTAL_QTY
*         Subtotal    → $.IS_TOTALS.SUBTOTAL
*         TotalAmt    → $.IS_TOTALS.TOTAL
*         Currency    → $.IS_TOTALS.WAERS
*
*  ====================================================================
*  4.  FORM CONTEXT  (SFP → Context)
*  ====================================================================
*   Import parameters are dragged from the interface node into the
*   context tree:
*     Context
*     ├── IS_HEADER   (Structure)
*     ├── IT_ITEMS    (Internal Table – sets up automatic pagination)
*     └── IS_TOTALS   (Structure)
*
*  ====================================================================
*  5.  ACTIVATION & TESTING
*  ====================================================================
*   a) Create the interface ZFM_PO_ADOBE in SFP, activate it.
*   b) Create the form ZFM_PO_ADOBE in SFP referencing the interface,
*      design the layout in LiveCycle Designer, activate.
*   c) Execute ZF_WRICEF_PO_FORM via SE38 with a valid PO number to
*      trigger print preview of the generated Adobe PDF.
*
*  ====================================================================
*  6.  GENERATED FUNCTION MODULE SIGNATURE  (for reference)
*  ====================================================================
*   FUNCTION ZFM_PO_ADOBE
*     IMPORTING
*       /1BCDWB/DOCPARAMS  TYPE SFPDOCPARAMS
*       IS_HEADER          TYPE TY_PO_HEADER   " or ZST_PO_HEADER
*       IT_ITEMS           TYPE TT_PO_ITEMS    " or ZTT_PO_ITEMS
*       IS_TOTALS          TYPE TY_PO_TOTALS   " or ZST_PO_TOTALS
*     EXCEPTIONS
*       USAGE_ERROR        = 1
*       SYS_ERROR          = 2
*       INTERNAL_ERROR     = 3.
*
