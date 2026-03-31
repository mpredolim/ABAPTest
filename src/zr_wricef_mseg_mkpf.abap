*&---------------------------------------------------------------------*
*& Report  ZR_WRICEF_MSEG_MKPF
*& WRICEF Type: Report (R)
*& Description: Material Documents Report — MKPF + MSEG with ALV output
*&---------------------------------------------------------------------*
REPORT zr_wricef_mseg_mkpf.

*&---------------------------------------------------------------------*
*& Type Definitions
*&---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_output,
    " --- MKPF fields (header) ---
    mblnr TYPE mkpf-mblnr,   " Material Document Number
    mjahr TYPE mkpf-mjahr,   " Material Document Year
    bldat TYPE mkpf-bldat,   " Document Date
    budat TYPE mkpf-budat,   " Posting Date
    usnam TYPE mkpf-usnam,   " User Name
    xblnr TYPE mkpf-xblnr,   " Reference Document Number
    bktxt TYPE mkpf-bktxt,   " Document Header Text
    " --- MSEG fields (item) ---
    zeile TYPE mseg-zeile,   " Item in Material Document
    bwart TYPE mseg-bwart,   " Movement Type
    matnr TYPE mseg-matnr,   " Material Number
    werks TYPE mseg-werks,   " Plant
    lgort TYPE mseg-lgort,   " Storage Location
    charg TYPE mseg-charg,   " Batch Number
    menge TYPE mseg-menge,   " Quantity
    meins TYPE mseg-meins,   " Unit of Measure
    dmbtr TYPE mseg-dmbtr,   " Amount in Local Currency
    waers TYPE mseg-waers,   " Currency
  END OF ty_output.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b_mkpf WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: so_mblnr FOR mkpf-mblnr,          " Material Document Number
                  so_mjahr FOR mkpf-mjahr,           " Material Document Year
                  so_budat FOR mkpf-budat,           " Posting Date
                  so_bldat FOR mkpf-bldat,           " Document Date
                  so_usnam FOR mkpf-usnam NO-DISPLAY." User Name
SELECTION-SCREEN END OF BLOCK b_mkpf.

SELECTION-SCREEN BEGIN OF BLOCK b_mseg WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS: so_bwart FOR mseg-bwart,           " Movement Type
                  so_matnr FOR mseg-matnr,           " Material Number
                  so_werks FOR mseg-werks,           " Plant
                  so_lgort FOR mseg-lgort.           " Storage Location
SELECTION-SCREEN END OF BLOCK b_mseg.

*&---------------------------------------------------------------------*
*& Class Definition
*&---------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.
    CLASS-METHODS:
      run,
      fetch_data
        RETURNING VALUE(rt_output) TYPE tt_output,
      display_results
        IMPORTING it_output TYPE tt_output.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Class Implementation
*&---------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    DATA(lt_output) = fetch_data( ).

    IF lt_output IS INITIAL.
      MESSAGE 'No records found for the selection criteria.' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    display_results( lt_output ).
  ENDMETHOD.

  METHOD fetch_data.
    DATA lt_output TYPE tt_output.

    SELECT mkpf~mblnr,
           mkpf~mjahr,
           mkpf~bldat,
           mkpf~budat,
           mkpf~usnam,
           mkpf~xblnr,
           mkpf~bktxt,
           mseg~zeile,
           mseg~bwart,
           mseg~matnr,
           mseg~werks,
           mseg~lgort,
           mseg~charg,
           mseg~menge,
           mseg~meins,
           mseg~dmbtr,
           mseg~waers
      FROM mkpf
      INNER JOIN mseg
        ON  mseg~mandt = mkpf~mandt
        AND mseg~mblnr = mkpf~mblnr
        AND mseg~mjahr = mkpf~mjahr
      INTO CORRESPONDING FIELDS OF TABLE @lt_output
      WHERE mkpf~mblnr IN @so_mblnr
        AND mkpf~mjahr  IN @so_mjahr
        AND mkpf~budat  IN @so_budat
        AND mkpf~bldat  IN @so_bldat
        AND mkpf~usnam  IN @so_usnam
        AND mseg~bwart  IN @so_bwart
        AND mseg~matnr  IN @so_matnr
        AND mseg~werks  IN @so_werks
        AND mseg~lgort  IN @so_lgort.

    rt_output = lt_output.
  ENDMETHOD.

  METHOD display_results.
    " Build ALV field catalog
    DATA(lt_fieldcat) = VALUE slis_t_fieldcat_alv(
      " --- MKPF (Header) ---
      ( fieldname = 'MBLNR' tabname = 'TY_OUTPUT' seltext_m = 'Doc.Number'   key = 'X' )
      ( fieldname = 'MJAHR' tabname = 'TY_OUTPUT' seltext_m = 'Year'         key = 'X' )
      ( fieldname = 'BLDAT' tabname = 'TY_OUTPUT' seltext_m = 'Doc.Date'               )
      ( fieldname = 'BUDAT' tabname = 'TY_OUTPUT' seltext_m = 'Post.Date'              )
      ( fieldname = 'USNAM' tabname = 'TY_OUTPUT' seltext_m = 'User'                   )
      ( fieldname = 'XBLNR' tabname = 'TY_OUTPUT' seltext_m = 'Ref.Doc.'               )
      ( fieldname = 'BKTXT' tabname = 'TY_OUTPUT' seltext_m = 'Header Text'            )
      " --- MSEG (Item) ---
      ( fieldname = 'ZEILE' tabname = 'TY_OUTPUT' seltext_m = 'Item'         key = 'X' )
      ( fieldname = 'BWART' tabname = 'TY_OUTPUT' seltext_m = 'Mvmt Type'              )
      ( fieldname = 'MATNR' tabname = 'TY_OUTPUT' seltext_m = 'Material'               )
      ( fieldname = 'WERKS' tabname = 'TY_OUTPUT' seltext_m = 'Plant'                  )
      ( fieldname = 'LGORT' tabname = 'TY_OUTPUT' seltext_m = 'Stor.Loc.'              )
      ( fieldname = 'CHARG' tabname = 'TY_OUTPUT' seltext_m = 'Batch'                  )
      ( fieldname = 'MENGE' tabname = 'TY_OUTPUT' seltext_m = 'Quantity'               )
      ( fieldname = 'MEINS' tabname = 'TY_OUTPUT' seltext_m = 'UoM'                    )
      ( fieldname = 'DMBTR' tabname = 'TY_OUTPUT' seltext_m = 'Amount'                 )
      ( fieldname = 'WAERS' tabname = 'TY_OUTPUT' seltext_m = 'Currency'               )
    ).

    " ALV layout
    DATA ls_layout TYPE slis_layout_alv.
    ls_layout-zebra             = 'X'.
    ls_layout-colwidth_optimize = 'X'.

    " Display ALV grid
    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        i_callback_program = sy-repid
        is_layout          = ls_layout
        it_fieldcat        = lt_fieldcat
      TABLES
        t_outtab           = it_output
      EXCEPTIONS
        program_error      = 1
        OTHERS             = 2.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Text Symbols
*& TEXT-001: 'Document Header (MKPF)'
*& TEXT-002: 'Document Item (MSEG)'
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  lcl_report=>run( ).
