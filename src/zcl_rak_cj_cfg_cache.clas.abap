CLASS zcl_rak_cj_cfg_cache DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Returns the journey definition from the per-work-process cache.
    "! On a miss (or expired entry) it delegates to ZCL_RAK_JOURNEY_REPO,
    "! applies the theme defaults ONCE, and caches the result.
    "! The returned structure is a value copy — callers may mutate it
    "! (e.g. per-user backend context) without polluting the cache.
    CLASS-METHODS get
      IMPORTING iv_journey       TYPE string
                iv_lang          TYPE sy-langu
      RETURNING VALUE(rs_config) TYPE zif_rak_journey=>ty_config.

    "! Drops cached entries for one journey (all languages) or everything.
    "! Call this from the Studio (ZCL_RAK_CJS) save path so Preview picks
    "! up authoring changes immediately in the same work process.
    "! Other work processes converge on the NEXT request via the version
    "! counter, not after C_TTL_SEC.
    CLASS-METHODS invalidate
      IMPORTING iv_journey TYPE string OPTIONAL.

  PRIVATE SECTION.
    TYPES:
     BEGIN OF ty_entry,
        journey TYPE string,
        lang    TYPE sy-langu,
        loaded  TYPE timestamp,
        vers    TYPE int8,
        config  TYPE zif_rak_journey=>ty_config,
      END OF ty_entry.

    CLASS-DATA gt_cache TYPE HASHED TABLE OF ty_entry
                        WITH UNIQUE KEY journey lang.

    " 5 minutes: bounds authoring-change staleness across work processes.
    " If runtime definitions are effectively frozen between transports,
    " raise this to 1800. Upgrade path for zero-staleness across all
    " app servers: move gt_cache into a shared memory area (SHMA).
    CONSTANTS c_ttl_sec TYPE i VALUE 300.

*   The cache key. gt_cache was keyed on the caller's spelling of the
*   journey id, and the two callers do not agree on one: the engine takes
*   mv_journey straight off the URL query string, where ?journey=dok_d008
*   and ?journey=DOK_D008 are both accepted, while the Studio passes the
*   id as it sits in the table. That produced two entries for one journey,
*   and invalidate( ) deleted only the one whose spelling it happened to
*   hold — the other went on serving the previous version until the TTL
*   expired. Every key now goes through here, on the way in and out.
    CLASS-METHODS norm
      IMPORTING iv_journey TYPE string
      RETURNING VALUE(rv)  TYPE string.

    CLASS-METHODS apply_theme_defaults
      CHANGING cs_config TYPE zif_rak_journey=>ty_config.
ENDCLASS.



CLASS ZCL_RAK_CJ_CFG_CACHE IMPLEMENTATION.


  METHOD apply_theme_defaults.
    " moved here from ZCL_RAK_JOURNEY_ENGINE->INIT so defaults are
    " applied once per cache load instead of once per session

*   Two of these values are handed STRAIGHT to UI5 as enum members, and
*   UI5's enums are case-sensitive. The authoring tables hold everything
*   uppercase, so ACCENT_TYPE = 'EMPHASIZED' is not sap.m.ButtonType
*   Emphasized - it is an invalid value, the control silently falls back
*   to Default, and the primary action on every step renders as a plain
*   white button. DENSITY = 'COZY' fails the same way one level up:
*   density_class( ) matches 'Cozy' exactly and returns blank, so the
*   density class is never applied at all.
*
*   Both faults are invisible from the journey definition, which reads
*   exactly as the author intended. Canonicalised here rather than at
*   each use site because this method is the one place every config
*   passes through, and a fix in density_class( ) would leave the button
*   type broken and vice versa.
*
*   THEME_VARIANT and LAYOUT_MODE are NOT in this list: those are ours,
*   compared uppercase against uppercase literals in ZCL_RAK_JOURNEY_CSS,
*   and folding their case here would break the comparisons that work.
    cs_config-theme-accent_type = SWITCH string( to_upper( cs_config-theme-accent_type )
      WHEN 'EMPHASIZED'  THEN 'Emphasized'
      WHEN 'DEFAULT'     THEN 'Default'
      WHEN 'TRANSPARENT' THEN 'Transparent'
      WHEN 'GHOST'       THEN 'Ghost'
      WHEN 'ACCEPT'      THEN 'Accept'
      WHEN 'REJECT'      THEN 'Reject'
      WHEN 'ATTENTION'   THEN 'Attention'
      WHEN 'CRITICAL'    THEN 'Critical'
      WHEN 'NEGATIVE'    THEN 'Negative'
      WHEN 'NEUTRAL'     THEN 'Neutral'
      WHEN 'SUCCESS'     THEN 'Success'
*     Anything else, including blank, falls to the default below rather
*     than reaching a control as an invalid enum member.
      ELSE '' ).

    cs_config-theme-density = SWITCH string( to_upper( cs_config-theme-density )
      WHEN 'COMPACT' THEN 'Compact'
      WHEN 'COZY'    THEN 'Cozy'
      ELSE '' ).

    IF cs_config-theme-layout_mode IS INITIAL. cs_config-theme-layout_mode = 'WIZARD'.         ENDIF.
    IF cs_config-theme-variant     IS INITIAL. cs_config-theme-variant     = 'CLEAN'.          ENDIF.
    IF cs_config-theme-accent_type IS INITIAL. cs_config-theme-accent_type = 'Emphasized'.     ENDIF.
    IF cs_config-theme-brand_color IS INITIAL. cs_config-theme-brand_color = 'rgb(196,30,38)'. ENDIF.
    IF cs_config-theme-navy_color  IS INITIAL. cs_config-theme-navy_color  = 'rgb(16,35,62)'.  ENDIF.
  ENDMETHOD.


  METHOD get.
    DATA lv_now  TYPE timestamp.
    DATA lv_vers TYPE int8.

    DATA(lv_key) = norm( iv_journey ).
    IF lv_key IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD lv_now.

*   Read BEFORE the repo load, deliberately. If somebody invalidates while
*   load_config( ) is running, the entry is stamped with the older counter,
*   the next get( ) sees the mismatch and reloads. Stamping with a value
*   read afterwards would bake the race in.
*
*   sy-subrc is checked because an empty version table is a legitimate
*   state — it stays empty until the first invalidate( ) — and an
*   unchecked SELECT SINGLE leaves lv_vers holding whatever it held
*   before, which on a loop would be the previous journey's counter.
    SELECT SINGLE vers FROM zrak_cj_cfg_ver INTO lv_vers.
    IF sy-subrc <> 0.
      CLEAR lv_vers.
    ENDIF.

    READ TABLE gt_cache ASSIGNING FIELD-SYMBOL(<ls_hit>)
         WITH TABLE KEY journey = lv_key lang = iv_lang.
    IF sy-subrc = 0.
      TRY.
          IF <ls_hit>-vers = lv_vers
             AND cl_abap_tstmp=>subtract( tstmp1 = lv_now
                                          tstmp2 = <ls_hit>-loaded ) < c_ttl_sec.
            rs_config = <ls_hit>-config.
            RETURN.
          ENDIF.
        CATCH cx_parameter_invalid.
*         A timestamp that will not subtract is a corrupt entry, not a
*         fresh one. Falling through to the DELETE below is right; the
*         empty CATCH previously left the entry in place to fail again
*         on every subsequent request.
      ENDTRY.
      DELETE gt_cache WHERE journey = lv_key AND lang = iv_lang.
    ENDIF.

    rs_config = NEW zcl_rak_journey_repo( )->load_config(
                  iv_journey_id = lv_key
                  iv_lang       = iv_lang ).
    IF rs_config-journey_id IS INITIAL.
*     Nothing cached on a miss, so a journey that is created after the
*     first failed lookup is picked up on the next request rather than
*     after the TTL.
      RETURN.
    ENDIF.
    apply_theme_defaults( CHANGING cs_config = rs_config ).

    INSERT VALUE #( journey = lv_key
                    lang    = iv_lang
                    loaded  = lv_now
                    vers    = lv_vers
                    config  = rs_config ) INTO TABLE gt_cache.
  ENDMETHOD.


  METHOD invalidate.
*   The counter bump is what every OTHER work process and app server sees;
*   the local DELETE below only serves this one. Both are needed: without
*   the bump the neighbours keep their copies until the TTL, and without
*   the DELETE this process re-reads a row it has just written.
    UPDATE zrak_cj_cfg_ver SET vers = vers + 1.
    IF sy-subrc <> 0.
      INSERT zrak_cj_cfg_ver FROM @( VALUE #( vers = 1 ) ).
      IF sy-subrc <> 0.
*       Somebody else inserted the first row between our UPDATE and our
*       INSERT. Their bump counts, so this is not an error — but the
*       local cache must still go, or this process serves what it has.
        CLEAR gt_cache.
      ENDIF.
    ENDIF.
    COMMIT WORK.

    IF iv_journey IS INITIAL.
      CLEAR gt_cache.
    ELSE.
      DELETE gt_cache WHERE journey = norm( iv_journey ).
    ENDIF.
  ENDMETHOD.


  METHOD norm.
    rv = to_upper( condense( val = iv_journey ) ).
  ENDMETHOD.
ENDCLASS.
