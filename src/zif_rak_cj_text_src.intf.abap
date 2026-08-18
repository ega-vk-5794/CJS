INTERFACE zif_rak_cj_text_src
  PUBLIC.

  TYPES ty_key TYPE c LENGTH 30.

  TYPES: BEGIN OF ty_txt,
           journey  TYPE ty_key,
           step_id  TYPE ty_key,
           block_id TYPE ty_key,
           elem_id  TYPE ty_key,
           txt_kind TYPE c LENGTH 10,
           text_en  TYPE string,
           text_ar  TYPE string,
         END OF ty_txt.

  TYPES ty_t_txt TYPE STANDARD TABLE OF ty_txt WITH EMPTY KEY.

  TYPES ty_t_journey TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

  METHODS list_journeys
    RETURNING VALUE(rt_journey) TYPE ty_t_journey.

  METHODS read_journey
    IMPORTING iv_journey    TYPE ty_key
    RETURNING VALUE(rt_txt) TYPE ty_t_txt.

  METHODS write
    IMPORTING it_txt TYPE ty_t_txt.

ENDINTERFACE.
