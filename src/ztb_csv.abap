*&---------------------------------------------------------------------*
*& Dictionary Object: ZTB_CSV
*& Object Type:       Transparent Table
*& Description:       Custom table to store CSV file records processed
*&                    by the WRICEF Type I interface ZI_WRICEF_CSV.
*&
*& Key Fields:
*&   MANDT   – Client (auto-filled by SAP)
*&   ROW_NUM – Sequential row number from the CSV file
*&
*& Data Fields:
*&   COL1 through COL5 – Up to five delimited column values from each
*&                        CSV row (CHAR 255 each).
*&   LOAD_TIMESTAMP    – UTC timestamp recorded at the moment the row
*&                        was inserted.
*&   FILENAME          – Original file name / path supplied on the
*&                        selection screen (CHAR 255).
*&---------------------------------------------------------------------*
*
* DDL-equivalent definition (informational – activate via SE11/SE14):
*
* @EndUserText.label : 'CSV Interface Records'
* @AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
* @AbapCatalog.tableCategory         : #TRANSPARENT
* @AbapCatalog.deliveryClass         : #APPLICATION_SYSTEM_DATA
* @AbapCatalog.dataMaintenance       : #ALLOWED
* define table ztb_csv {
*   key mandt          : abap.clnt not null;
*   key row_num        : abap.numc(6) not null;
*   col1               : abap.char(255);
*   col2               : abap.char(255);
*   col3               : abap.char(255);
*   col4               : abap.char(255);
*   col5               : abap.char(255);
*   load_timestamp     : abap.utclong;
*   filename           : abap.char(255);
* }
*
* This file documents the table structure.  In a real SAP system the
* table must be created and activated through transaction SE11.
