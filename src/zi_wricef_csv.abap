*&---------------------------------------------------------------------*
*& Report  ZI_WRICEF_CSV
*& WRICEF Type: Interface – Inbound (I)
*& Description: Reads a local CSV file from the presentation server,
*&              parses its content, inserts the records into the custom
*&              transparent table ZTB_CSV, and displays the result in
*&              an ALV grid.
*&
*& Custom table used: ZTB_CSV
*&   Key  : MANDT + ROW_NUM
*&   Data : COL1…COL5, LOAD_TIMESTAMP, FILENAME
*&
*& Selection-Screen parameters:
*&   P_FILE  – Full path of the CSV file on the presentation server.
*&   P_DELIM – Column delimiter character (default: comma).
*&   P_HEAD  – Checkbox: check if the first row is a header (skip it).
*&   P_TEST  – Test mode: parse and display only, skip DB inserts.
*&---------------------------------------------------------------------*
REPORT zi_wricef_csv.

*&---------------------------------------------------------------------*
*& Type Definitions
*&---------------------------------------------------------------------*
TYPES:
  " Local mirror of ZTB_CSV (avoids dependency on activated table during
  " syntax check in systems where the table does not yet exist).
  BEGIN OF ty_ztb_csv,
    mandt          TYPE mandt,
    row_num        TYPE numc6,
    col1           TYPE char255,
    col2           TYPE char255,
    col3           TYPE char255,
    col4           TYPE char255,
    col5           TYPE char255,
    load_timestamp TYPE utclong,
    filename       TYPE char255,
  END OF ty_ztb_csv,

  BEGIN OF ty_alv_row,
    row_num   TYPE numc6,
    col1      TYPE char255,
    col2      TYPE char255,
    col3      TYPE char255,
    col4      TYPE char255,
    col5      TYPE char255,
    status    TYPE char20,
  END OF ty_alv_row.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS:
    p_file  TYPE string LOWER CASE OBLIGATORY,
    p_delim TYPE char1  DEFAULT ',',
    p_head  AS CHECKBOX DEFAULT abap_false,
    p_test  AS CHECKBOX DEFAULT abap_false,
    p_overw AS CHECKBOX DEFAULT abap_true.   " Overwrite existing records for this file
SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Class Definition
*&---------------------------------------------------------------------*
CLASS lcl_csv_interface DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      run,
      display_alv
        IMPORTING
          it_alv_rows TYPE STANDARD TABLE.

  PRIVATE SECTION.
    CLASS-METHODS:
      upload_file
        IMPORTING
          iv_filepath TYPE string
        RETURNING
          VALUE(rt_raw_lines) TYPE stringtab
        RAISING
          cx_sy_file_open,

      parse_csv
        IMPORTING
          it_raw_lines TYPE stringtab
          iv_delimiter TYPE char1
          iv_skip_head TYPE abap_bool
        RETURNING
          VALUE(rt_records) TYPE STANDARD TABLE OF ty_ztb_csv,

      split_csv_line
        IMPORTING
          iv_line      TYPE string
          iv_delimiter TYPE char1
        RETURNING
          VALUE(rt_fields) TYPE stringtab,

      insert_records
        IMPORTING
          it_records TYPE STANDARD TABLE OF ty_ztb_csv
        RETURNING
          VALUE(rv_inserted) TYPE i,

      build_alv_rows
        IMPORTING
          it_records TYPE STANDARD TABLE OF ty_ztb_csv
          iv_status  TYPE string
        RETURNING
          VALUE(rt_alv_rows) TYPE STANDARD TABLE OF ty_alv_row.
ENDCLASS.

*&---------------------------------------------------------------------*
*& Class Implementation
*&---------------------------------------------------------------------*
CLASS lcl_csv_interface IMPLEMENTATION.

  METHOD run.
    " ----------------------------------------------------------------
    " 1. Upload the raw CSV lines from the local file system
    " ----------------------------------------------------------------
    DATA lt_raw TYPE stringtab.

    TRY.
        lt_raw = upload_file( p_file ).
      CATCH cx_sy_file_open INTO DATA(lx_file).
        MESSAGE lx_file->get_text( ) TYPE 'E'.
        RETURN.
    ENDTRY.

    IF lt_raw IS INITIAL.
      MESSAGE 'The selected file is empty or could not be read.' TYPE 'W'.
      RETURN.
    ENDIF.

    " ----------------------------------------------------------------
    " 2. Parse raw lines into typed records
    " ----------------------------------------------------------------
    DATA(lt_records) = parse_csv(
      it_raw_lines = lt_raw
      iv_delimiter = p_delim
      iv_skip_head = p_head ).

    IF lt_records IS INITIAL.
      MESSAGE 'No data rows found in the CSV file.' TYPE 'W'.
      RETURN.
    ENDIF.

    " ----------------------------------------------------------------
    " 3. Insert into ZTB_CSV (skipped in test mode)
    " ----------------------------------------------------------------
    DATA lv_inserted TYPE i.
    DATA lv_status   TYPE string.

    IF p_test = abap_true.
      lv_status = 'TEST – not saved'.
      lv_inserted = 0.
      MESSAGE |Test mode active – { lines( lt_records ) } rows parsed, DB not updated.| TYPE 'S'.
    ELSE.
      lv_inserted = insert_records( lt_records ).
      lv_status   = 'Inserted'.
      MESSAGE |{ lv_inserted } record(s) successfully inserted into ZTB_CSV.| TYPE 'S'.
    ENDIF.

    " ----------------------------------------------------------------
    " 4. Build ALV rows and display
    " ----------------------------------------------------------------
    DATA(lt_alv_rows) = build_alv_rows(
      it_records = lt_records
      iv_status  = lv_status ).

    display_alv( lt_alv_rows ).
  ENDMETHOD.


  METHOD upload_file.
    " Use GUI_UPLOAD to read the file from the presentation server.
    DATA lt_data TYPE filetable.
    DATA lt_file_content TYPE STANDARD TABLE OF string.

    CALL FUNCTION 'GUI_UPLOAD'
      EXPORTING
        filename                = iv_filepath
        filetype                = 'ASC'
        has_field_separator     = abap_false
        read_by_line            = abap_true
      TABLES
        data_tab                = lt_file_content
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        OTHERS                  = 17.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_sy_file_open
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    rt_raw_lines = lt_file_content.
  ENDMETHOD.


  METHOD parse_csv.
    DATA lv_row_num  TYPE numc6.
    DATA lv_line_idx TYPE i VALUE 1.
    DATA lv_ts       TYPE utclong.

    GET TIME STAMP FIELD lv_ts.

    LOOP AT it_raw_lines INTO DATA(lv_line).
      " Skip header row if requested
      IF lv_line_idx = 1 AND iv_skip_head = abap_true.
        lv_line_idx = lv_line_idx + 1.
        CONTINUE.
      ENDIF.

      " Skip completely empty lines
      IF lv_line IS INITIAL.
        lv_line_idx = lv_line_idx + 1.
        CONTINUE.
      ENDIF.

      lv_row_num = lv_row_num + 1.

      " Split the line into individual fields
      DATA(lt_fields) = split_csv_line(
        iv_line      = lv_line
        iv_delimiter = iv_delimiter ).

      " Map fields to record structure (up to 5 columns)
      DATA ls_record TYPE ty_ztb_csv.
      CLEAR ls_record.
      ls_record-mandt          = sy-mandt.
      ls_record-row_num        = lv_row_num.
      ls_record-load_timestamp = lv_ts.
      ls_record-filename       = p_file.

      DATA(lv_num_fields) = lines( lt_fields ).

      " Map up to 5 fields from the split result into the record structure
      FIELD-SYMBOLS <lv_col> TYPE char255.
      DO 5 TIMES.
        DATA(lv_col_idx) = sy-index.
        IF lv_col_idx > lv_num_fields. EXIT. ENDIF.
        READ TABLE lt_fields INTO DATA(lv_f) INDEX lv_col_idx.
        ASSIGN COMPONENT |COL{ lv_col_idx }| OF STRUCTURE ls_record TO <lv_col>.
        IF sy-subrc = 0. <lv_col> = lv_f. ENDIF.
      ENDDO.

      APPEND ls_record TO rt_records.
      lv_line_idx = lv_line_idx + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD split_csv_line.
    " Basic CSV split on the given delimiter.
    " Handles quoted fields: a field enclosed in double quotes may
    " contain the delimiter character itself.
    DATA lv_in_quotes TYPE abap_bool VALUE abap_false.
    DATA lv_current   TYPE string.
    DATA lv_char      TYPE char1.
    DATA lv_len       TYPE i.
    DATA lv_pos       TYPE i.

    lv_len = strlen( iv_line ).

    DO lv_len TIMES.
      lv_pos  = sy-index - 1.
      lv_char = iv_line+lv_pos(1).

      IF lv_char = '"'.
        lv_in_quotes = SWITCH #( lv_in_quotes
          WHEN abap_true  THEN abap_false
          ELSE                 abap_true ).
        CONTINUE.
      ENDIF.

      IF lv_char = iv_delimiter AND lv_in_quotes = abap_false.
        APPEND lv_current TO rt_fields.
        CLEAR lv_current.
        CONTINUE.
      ENDIF.

      CONCATENATE lv_current lv_char INTO lv_current.
    ENDDO.

    " Append the last field
    APPEND lv_current TO rt_fields.
  ENDMETHOD.


  METHOD insert_records.
    " If overwrite mode is active, remove any previous rows for this
    " file before inserting so re-runs produce consistent results.
    IF p_overw = abap_true.
      DELETE FROM ztb_csv WHERE filename = p_file.
    ENDIF.

    " Bulk insert all parsed records
    INSERT ztb_csv FROM TABLE it_records.

    IF sy-subrc = 0 OR sy-subrc = 4.
      " sy-subrc = 0: all rows inserted; 4: no rows (empty table) – both fine
      rv_inserted = lines( it_records ).
    ELSE.
      " Unexpected error: roll back and report zero inserted
      ROLLBACK WORK.
      rv_inserted = 0.
      MESSAGE |Database insert failed (sy-subrc = { sy-subrc }).| TYPE 'E'.
      RETURN.
    ENDIF.

    COMMIT WORK AND WAIT.
  ENDMETHOD.


  METHOD build_alv_rows.
    LOOP AT it_records INTO DATA(ls_rec).
      DATA(ls_alv) = VALUE ty_alv_row(
        row_num = ls_rec-row_num
        col1    = ls_rec-col1
        col2    = ls_rec-col2
        col3    = ls_rec-col3
        col4    = ls_rec-col4
        col5    = ls_rec-col5
        status  = iv_status ).
      APPEND ls_alv TO rt_alv_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD display_alv.
    " Build field catalog
    DATA(lt_fieldcat) = VALUE slis_t_fieldcat_alv(
      ( fieldname = 'ROW_NUM' seltext_m = 'Row #'    col_pos = 1 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'COL1'    seltext_m = 'Column 1' col_pos = 2 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'COL2'    seltext_m = 'Column 2' col_pos = 3 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'COL3'    seltext_m = 'Column 3' col_pos = 4 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'COL4'    seltext_m = 'Column 4' col_pos = 5 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'COL5'    seltext_m = 'Column 5' col_pos = 6 tabname = 'TY_ALV_ROW' )
      ( fieldname = 'STATUS'  seltext_m = 'Status'   col_pos = 7 tabname = 'TY_ALV_ROW' )
    ).

    DATA ls_layout TYPE slis_layout_alv.
    ls_layout-zebra            = abap_true.
    ls_layout-colwidth_optimize = abap_true.

    DATA ls_header TYPE slis_listheader.
    DATA lt_header TYPE slis_t_listheader.

    ls_header-typ  = 'H'.
    ls_header-info = 'WRICEF Interface – CSV Import Results'.
    APPEND ls_header TO lt_header.

    ls_header-typ  = 'S'.
    ls_header-key  = 'File:'.
    ls_header-info = p_file.
    APPEND ls_header TO lt_header.

    ls_header-typ  = 'S'.
    ls_header-key  = 'Rows:'.
    ls_header-info = lines( it_alv_rows ).
    APPEND ls_header TO lt_header.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY'
      EXPORTING
        it_fieldcat   = lt_fieldcat
        is_layout     = ls_layout
        it_list_commentary = lt_header
      TABLES
        t_outtab      = it_alv_rows
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
*& Texts (maintained via transaction SE38 / Goto → Text Elements)
*&   TEXT-001 = 'CSV File Import Parameters'
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  lcl_csv_interface=>run( ).
