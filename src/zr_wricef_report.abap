*&---------------------------------------------------------------------*
*& Report  ZR_WRICEF_REPORT
*& WRICEF Type: Report (R)
*& Description: Sample ABAP WRICEF Report object
*&---------------------------------------------------------------------*
REPORT zr_wricef_report.

*&---------------------------------------------------------------------*
*& Type Definitions
*&---------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_output,
    col1 TYPE string,
    col2 TYPE string,
    col3 TYPE string,
  END OF ty_output.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS: so_key FOR sy-uname NO-DISPLAY.
  PARAMETERS:     p_max   TYPE i DEFAULT 100.
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Class Definition
*&---------------------------------------------------------------------*
CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      run,
      display_results
        IMPORTING
          it_output TYPE STANDARD TABLE.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Class Implementation
*&---------------------------------------------------------------------*
CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    " Build output data, filtered by selection screen parameters
    DATA lt_output TYPE STANDARD TABLE OF ty_output.

    DATA(lt_all) = VALUE STANDARD TABLE OF ty_output(
      ( col1 = 'Key-1'  col2 = 'Value-1'  col3 = 'Description-1' )
      ( col1 = 'Key-2'  col2 = 'Value-2'  col3 = 'Description-2' )
      ( col1 = 'Key-3'  col2 = 'Value-3'  col3 = 'Description-3' )
    ).

    " Apply so_key filter and p_max limit from selection screen
    DATA(lv_count) = 0.
    LOOP AT lt_all INTO DATA(ls_row)
      WHERE col1 IN so_key.
      lv_count = lv_count + 1.
      IF lv_count > p_max.
        EXIT.
      ENDIF.
      APPEND ls_row TO lt_output.
    ENDLOOP.

    display_results( lt_output ).
  ENDMETHOD.

  METHOD display_results.
    " Build ALV field catalog
    DATA(lt_fieldcat) = VALUE slis_t_fieldcat_alv(
      ( fieldname = 'COL1' seltext_m = 'Key'         tabname = 'TY_OUTPUT' )
      ( fieldname = 'COL2' seltext_m = 'Value'       tabname = 'TY_OUTPUT' )
      ( fieldname = 'COL3' seltext_m = 'Description' tabname = 'TY_OUTPUT' )
    ).

    " Display ALV list
    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        it_fieldcat = lt_fieldcat
      TABLES
        t_outtab    = it_output
      EXCEPTIONS
        program_error = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
              WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  lcl_report=>run( ).
