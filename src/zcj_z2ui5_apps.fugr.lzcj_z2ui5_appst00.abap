*---------------------------------------------------------------------*
*    view related data declarations
*---------------------------------------------------------------------*
*...processing: ZCJ_Z2UI5_APPS..................................*
DATA:  BEGIN OF STATUS_ZCJ_Z2UI5_APPS                .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZCJ_Z2UI5_APPS                .
CONTROLS: TCTRL_ZCJ_Z2UI5_APPS
            TYPE TABLEVIEW USING SCREEN '0100'.
*...processing: ZCJ_Z2UI5_SCREEN................................*
DATA:  BEGIN OF STATUS_ZCJ_Z2UI5_SCREEN              .   "state vector
         INCLUDE STRUCTURE VIMSTATUS.
DATA:  END OF STATUS_ZCJ_Z2UI5_SCREEN              .
CONTROLS: TCTRL_ZCJ_Z2UI5_SCREEN
            TYPE TABLEVIEW USING SCREEN '0200'.
*.........table declarations:.................................*
TABLES: *ZCJ_Z2UI5_APPS                .
TABLES: *ZCJ_Z2UI5_APPS_T              .
TABLES: *ZCJ_Z2UI5_SCREEN              .
TABLES: *ZCJ_Z2UI5_SCREET              .
TABLES: ZCJ_Z2UI5_APPS                 .
TABLES: ZCJ_Z2UI5_APPS_T               .
TABLES: ZCJ_Z2UI5_SCREEN               .
TABLES: ZCJ_Z2UI5_SCREET               .

* general table data declarations..............
  INCLUDE LSVIMTDT                                .
