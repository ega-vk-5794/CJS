# `CX_SY_IMPORT_MISMATCH_ERROR` — `ZCL_EGA_CJ_DOK_ABS->ACCESS_STUDENT_EXIT_BUFFER`

Apply in ADT. This class is not in the CJS repository — it lives in the BAdI chain
(`ZCL_EGA_CJ_*_ABS`, in scope for change) and is maintained on the SAP side.

## What happens

```
IMPORT student_exit = cs_student_exit
  FROM SHARED BUFFER indx(cj) ID lv_id.
```

The row stored under `lv_id` was `EXPORT`ed from a **different shape** of the
`student_exit` structure than the one being imported into now. Almost always a
field was added to or retyped in that structure while rows written by the old
version were still sitting in the buffer.

It is a type mismatch **on a cache**. Not a missing key, not bad data on the form,
and nothing the citizen types will change it.

## Why "start the application again" does not help

The buffer id is built from the **student**, not the draft:

```
LV_ID = student_exit_2013196053     " C(30)
```

A new draft for the same student rebuilds the same id and hits the same poisoned
row. `SHARED BUFFER` is also cross-session, so this is not one citizen having a bad
day — **everyone who touches that student on that app server gets it**, until the
row is cleared.

## Immediate unblock

Clear the one row (or all of them) and the next read re-seeds it in the current shape:

```abap
REPORT zrak_clear_student_exit.

PARAMETERS p_sid TYPE char20 OBLIGATORY.

START-OF-SELECTION.
  DATA(lv_id) = CONV char30( |student_exit_{ p_sid }| ).
  DELETE FROM SHARED BUFFER indx(cj) ID lv_id.
  WRITE: / |Cleared { lv_id }, sy-subrc { sy-subrc }|.
```

Run it per app server — `SHARED BUFFER` is server-local, so a system with several
app servers needs it on each, or an `$SYNC` / restart.

That is a workaround, not the fix. Without the code change below it comes back the
next time that structure is touched.

## The fix

A cache must never be able to stop the application it exists to speed up. Catch the
mismatch, drop the poisoned row, report a miss — the caller then reads from the
source and the next `EXPORT` re-seeds the buffer in the current shape. It heals
itself, once, invisibly.

```abap
  METHOD access_student_exit_buffer.

    DATA(lv_id) = CONV char30( |student_exit_{ cs_student_exit-student_id }| ).
*                                              ^ unchanged - keep whatever
*                                                field this already builds from

    IF iv_operation = 'I'.
      CLEAR cs_student_exit.

      TRY.
          IMPORT student_exit = cs_student_exit
            FROM SHARED BUFFER indx(cj) ID lv_id.

        CATCH cx_sy_import_mismatch_error.
*         The buffered row was written from an older shape of STUDENT_EXIT.
*         Uncaught, this reaches the citizen as a dump on a screen that had
*         accepted their input without complaint - and because the id is keyed
*         by STUDENT and the buffer is shared, it repeats for every user and
*         every new draft touching that student until somebody clears it by hand.
*
*         Dropping the row and reporting a miss is what makes it self-healing:
*         the caller falls back to reading from the source exactly as it does on
*         a cold cache, and the next EXPORT re-seeds this id in the current shape.
*         The cost of being wrong here is one extra read. The cost of not doing
*         it is the service being down for that student.
          DELETE FROM SHARED BUFFER indx(cj) ID lv_id.
          CLEAR cs_student_exit.
          ev_sy_subrc = 4.
          RETURN.
      ENDTRY.

    ELSEIF iv_operation = 'E'.
      EXPORT student_exit = cs_student_exit
        TO SHARED BUFFER indx(cj) ID lv_id COMPRESSION ON.
    ENDIF.

    ev_sy_subrc = sy-subrc.

  ENDMETHOD.
```

### Check before you activate

`ev_sy_subrc = 4` must mean "not in the buffer, read it from the source" to every
caller of this method. That is what `IMPORT` itself returns on a miss, so a caller
that already handles a cold cache handles this too — but confirm it, because a
caller that treats non-zero as a hard error would turn a self-healing miss back
into a failure.

### What not to do instead

`ACCEPTING PADDING` and `IGNORING STRUCTURE BOUNDARIES` on the `IMPORT` will absorb
some shape changes and are tempting as a one-word fix. They also silently map data
into the wrong fields when the change is not a pure append. A wrong student record
that renders without complaint is worse than the dump. Catch and invalidate instead.
