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

---

# Should the buffer move to the database instead?

Asked directly, so answered directly: **moving to `DATABASE` does not fix this bug**,
and on its own it makes the failure permanent rather than temporary.

```abap
IMPORT student_exit = cs_student_exit FROM DATABASE indx(cj) ID lv_id.
```

raises exactly the same `CX_SY_IMPORT_MISMATCH_ERROR` on exactly the same cause —
the stored cluster was written from a different shape of the structure. `IMPORT`
does not care which medium the row came from; it compares the stored type against
the target type and gives up when they differ.

The difference is what happens next. A `SHARED BUFFER` row dies when the app server
restarts, so today's poison clears itself at the next bounce whether or not anybody
understands it. A `DATABASE` row is persistent: it survives restarts, transports and
client copies, and sits there failing until somebody deletes it on purpose.

**So the catch-and-invalidate fix above is required either way.** Do that first. The
medium is a separate decision, and a smaller one.

## What each medium is actually good for

| | `SHARED BUFFER` (today) | `DATABASE` |
| --- | --- | --- |
| Scope | one app server | whole system |
| Survives restart | no | yes |
| Cost per access | memory read | DB read/write |
| Silent eviction | **yes**, under memory pressure | never |
| Housekeeping | automatic | **required — `INDX` grows forever** |
| Inside the caller's LUW | no | **yes — writes commit with it** |

Two rows in that table are the ones that decide it.

**Silent eviction.** A `SHARED BUFFER` row can be displaced when the buffer fills, and
the caller cannot tell an evicted row from one that was never written. That is fine
for a cache and fatal for anything treated as storage. If any caller of
`ACCESS_STUDENT_EXIT_BUFFER` depends on a row still being there — rather than
re-reading from the source on a miss — it already has a latent bug that has nothing
to do with the dump, and `DATABASE` is the correct answer for that caller.

**The LUW.** `EXPORT ... TO DATABASE` is a database change in the calling transaction.
It commits when the caller commits and rolls back when the caller rolls back — so a
failed post would silently discard the cache write, and a cache write would land in
the middle of a business LUW that did not ask for one. `SHARED BUFFER` has no such
coupling. Inside a BAdI called from an update task this is worth thinking about
before switching.

## The change worth making, whichever medium you keep

Put the **shape of the structure into the key**:

```abap
CONSTANTS c_shape TYPE string VALUE 'V2'.   " bump when STUDENT_EXIT changes

DATA(lv_id) = CONV char30( |stex_{ c_shape }_{ cs_student_exit-student_id }| ).
```

A structure change then **misses** the old rows instead of mismatching them. No
exception is raised at all: the read comes back empty, the caller reads from the
source exactly as on a cold cache, and the old rows age out on their own. The class
of bug disappears rather than being handled.

Keep the `TRY ... CATCH` as well, for the release where somebody changes the
structure and forgets to bump `c_shape`. Belt and braces: the token prevents it, the
catch survives it.

This is the pattern the CJS side already uses — `ZCL_RAK_CJ_CFG_CACHE` keys its
entries against a counter in `ZRAK_CJ_CFG_VER` and reloads when the two disagree,
for the same reason.

## Recommendation

1. **Apply the catch-and-invalidate fix.** Required regardless, and it is what
   unblocks today.
2. **Add the shape token to the key.** Small, and it removes the failure mode.
3. **Keep `SHARED BUFFER`** unless a caller genuinely needs cross-server or
   persistent data. It is a cache of something re-readable, memory is the right
   medium for that, and a DB round trip per student is a real cost on a wizard that
   reads this repeatedly.
4. **If you do move to `DATABASE`**, you own three new things: a deletion policy so
   `INDX` does not grow without limit, the LUW coupling above, and the fact that a
   poisoned row now needs deleting by hand instead of clearing at the next restart.

---

# Check this too: the key may be one character too long

Not verified — no ADT from the environment this was written in — but the arithmetic
is worth ten minutes on a system.

```
'student_exit_'          13 characters
'2013196053'             10 characters   (student SID)
                         --
                         23 characters
```

`INDX-SRTFD` is `CHAR(22)`.

`LV_ID` is declared `CONV char30( ... )`, so the *variable* holds all 23 — the
debugger screenshot confirms `C(30)` and shows the full `student_exit_2013196053`.
The question is what reaches the cluster key when the export is performed, because
the key field it lands in is shorter than the value being handed to it.

If it truncates at 22, the last character of the SID is lost, and **two students
whose ids differ only in the final digit share one buffer row**:

```
student_exit_2013196053  ->  student_exit_201319605
student_exit_2013196054  ->  student_exit_201319605
```

That would not dump. It would serve one student's exit data for another, silently,
and only for SIDs that happen to be adjacent — which is exactly the kind of defect
that survives testing and surfaces as an unreproducible complaint.

How to check, in order:

1. `SE11` on the cluster table actually used for area `CJ` — confirm the length of
   its `SRTFD` field. If it is a custom table with a longer key, there is nothing
   to fix.
2. If it is 22: export for two SIDs differing only in the last digit, then import
   both and compare.

If it is truncating, the shape token above makes it worse, not better — `stex_V2_`
is 8 characters, which leaves 14 for the id and truncates a 10-digit SID far
earlier. In that case shorten the prefix and hash rather than concatenate, or move
to a cluster table with a longer `SRTFD`. Establish the length first; it changes
what the right key looks like.

---

# The clear report "did not work" — why, and what to do instead

Worth saying first: **this is an argument for fixing the code rather than clearing
the buffer.** Clearing an export/import buffer from outside is fragile for reasons
that have nothing to do with the statement being wrong, and all four traps below
disappear if `ACCESS_STUDENT_EXIT_BUFFER` deletes the row itself when it catches the
mismatch. That code runs in the right client, on the right app server, in the right
session, with the key it built itself — none of which an external report can
guarantee.

If the report is still wanted, work through these in order. "Did not work" means
different things and they have different causes.

## 1. Wrong app server — the most likely one

`SHARED BUFFER` is **per application server**. The report ran wherever the batch or
dialog work process ran; the failing journey runs wherever ICF routed the HTTP
request. On a multi-server system those are usually not the same, and the delete
happily reports success against a buffer that never held the row.

The debugger screenshot names the server the journey was on:

```
ABAP Debugger(1) (Exclusive) -HTTP- (vhrkhe10ci_E10_00)
```

`SM51` lists the servers. The delete has to run on **that** one — or on all of them.
There is no way to reach another server's export/import buffer from ABAP without
executing there.

## 2. Wrong client

`INDX` is client-dependent and the buffer key includes the client. The journey runs
in **client 200** (`sap-client=200` in the URL). A report run in any other client
builds a different key and deletes nothing.

Either log into 200, or state it:

```abap
DELETE FROM SHARED BUFFER indx(cj) CLIENT '200' ID lv_id.
```

## 3. Wrong key

The report guesses the id. The method builds it from a field the debugger only
showed truncated (`cs_student_exit-s…`), so the prefix or the field may not be what
the report assumes. Take `LV_ID` **verbatim** from the debugger rather than
rebuilding it — that value is known to be right.

Note also the length question raised above: if `SRTFD` is `CHAR(22)` the 23-character
id truncates. The report truncates identically, so this does not by itself stop the
delete matching — but confirm the length anyway, because it is a real defect on its
own.

## 4. It reported `sy-subrc = 4`

That is not a failure of the statement, it is the answer: **no row under that key on
this server, in this client**. Causes 1 to 3 all produce it. So does a buffer that
has already been displaced under memory pressure, in which case there is nothing
left to delete and the dump you are still seeing is coming from somewhere else.

## Probe before deleting

Do not delete blind. This reports what is actually there, distinguishing "no row",
"a good row" and "the poisoned row" — which is the thing worth knowing:

```abap
REPORT zrak_probe_student_exit.

PARAMETERS p_id TYPE char30 OBLIGATORY.   " paste LV_ID from the debugger
PARAMETERS p_del AS CHECKBOX.             " tick only after the probe says POISONED

START-OF-SELECTION.

* Any structure will do for the probe - a mismatch is raised by the IMPORT before
* the target is ever filled, which is exactly the condition being tested for.
  DATA: BEGIN OF ls_probe,
          dummy TYPE string,
        END OF ls_probe.

  WRITE: / |server { sy-host } · client { sy-mandt } · id "{ p_id }"|.

  TRY.
      IMPORT student_exit = ls_probe FROM SHARED BUFFER indx(cj) ID p_id.

      IF sy-subrc = 0.
        WRITE: / 'Row present and it imported cleanly into a DIFFERENT structure.'.
        WRITE: / 'That means the stored shape is not what is dumping - look elsewhere.'.
      ELSE.
        WRITE: / |No row under this key here. sy-subrc { sy-subrc }.|.
        WRITE: / 'Wrong app server, wrong client, or wrong key - see the notes.'.
      ENDIF.

    CATCH cx_sy_import_mismatch_error.
*     THIS is the row that is dumping the journey. The probe reproduces the
*     failure on demand, which also means it confirms server, client and key are
*     all correct - the three things a bare DELETE cannot tell you.
      WRITE: / 'POISONED. The stored row mismatches on import - this is the one.'.
      IF p_del = abap_true.
        DELETE FROM SHARED BUFFER indx(cj) ID p_id.
        WRITE: / |Deleted. sy-subrc { sy-subrc }.|.
      ELSE.
        WRITE: / 'Re-run with the delete box ticked to clear it.'.
      ENDIF.
  ENDTRY.
```

Run it on the app server named in the debugger, in client 200. The probe telling you
`POISONED` is the confirmation that everything else lines up; anything else means one
of causes 1 to 3 is still in play and deleting would have achieved nothing.

## If it still cannot be cleared

Two blunt instruments, in order of preference:

1. **Apply the code fix and let it clear itself.** The next journey that touches that
   student catches the mismatch, deletes the row on the correct server in the correct
   client, and re-seeds it. No report, no server hunting.
2. **Restart the app server.** `SHARED BUFFER` does not survive it. Heavy-handed, but
   it is the one method that needs no key and no guessing.

`$SYNC` is worth mentioning only to say it is not the answer here — it resets table
buffers, not the export/import buffer.

---

# Confirmed cause: `CONNE_IMPORT_WRONG_COMP_TYPE`

The exception object, read in the debugger:

```
CX_SY_IMPORT_MISMATCH_ERROR
  KERNEL_ERRID = CONNE_IMPORT_WRONG_COMP_TYPE
```

That is not a generic mismatch. It names the specific condition: a **component of the
structure has a different TYPE** than it had when the row was exported. Not a field
added, not a field removed, not a reordering — a field whose type was changed.

So somebody altered a field's type in `STUDENT_EXIT` (or in a structure it includes):
a length change such as `CHAR10` to `CHAR20`, or a domain/data-element swap such as
`NUMC` to `CHAR`. Everything buffered before that activation is now unreadable.

Two things follow from it.

**It confirms the fix.** Nothing in the form, the journey or the case is involved.
The stored bytes cannot be mapped onto the current structure and never will be. The
row is dead weight and deleting it is the only correct action.

**It rules out the tempting shortcut for good.** `ACCEPTING PADDING` tolerates a
CHARACTER field that grew, and nothing else. It does not tolerate a type change, and
where it does absorb one it maps the old bytes into the new field and hands back a
value that was never stored. `CONNE_IMPORT_WRONG_COMP_TYPE` is precisely the case
where that produces a plausible-looking wrong answer. Catch and invalidate.

Worth finding out which field changed and when — the transport that carried it is
also the moment the service started failing, and any other cluster keyed on the same
structure has the same problem waiting.

---

# Next finding: the key is built from an EMPTY student id

The catch works — no dump, `sy-subrc = 4`, execution continues past `ENDTRY`. But the
debugger shows what the key actually was on this call:

```
LV_ID = student_exit_          " nothing after the underscore
```

`cs_student_exit-studentid` was **initial** when line 3 built the key:

```abap
DATA(lv_id) = CONV char30( |student_exit_{ cs_student_exit-studentid }| ).
```

An earlier call in the same session had `student_exit_2013196053`, so this is not
always true — the caller fills the id sometimes and not others.

## Why this matters more than the miss

The template collapses a blank id silently. `|student_exit_{ }|` is `student_exit_`,
a perfectly valid 13-character key — so **every caller that arrives without a student
id shares one row**.

That is not a cache miss. It is a bucket:

* the first `EXPORT` with a blank id files one student's exit data under
  `student_exit_`
* the next `IMPORT` with a blank id hands that data to a **different** student

No dump, no error, no `sy-subrc`. A wrong student's record, rendered as if it were
right. Same class of defect as the key-length truncation flagged earlier, and worth
more attention than the mismatch that started all this — the mismatch was loud, this
one is silent.

## The guard

A blank id must never reach the buffer, in either direction. A miss is the only safe
answer:

```abap
  METHOD access_student_exit_buffer.

*   A BLANK STUDENT ID MUST NOT REACH THE BUFFER, and the string template will not
*   stop it: |student_exit_{ }| is "student_exit_", a valid key that every caller
*   without an id shares. The first EXPORT files one student under it and the next
*   IMPORT hands that data to another - silently, with sy-subrc 0 and a record that
*   looks entirely normal.
*
*   Reported as a miss because that is what it is: there is no student, so there is
*   nothing legitimately buffered. CLEAR only on the read - CS_STUDENT_EXIT is
*   CHANGING, and clearing it on an export would destroy the caller's own data on
*   the way out.
    IF cs_student_exit-studentid IS INITIAL.
      IF iv_operation = 'I'.
        CLEAR cs_student_exit.
      ENDIF.
      ev_sy_subrc = 4.
      RETURN.
    ENDIF.

    DATA(lv_id) = CONV char30( |student_exit_{ cs_student_exit-studentid }| ).
    ...
```

## And then find out why it is blank

The guard stops the damage; it does not answer the question. The stack is the same
one as the working call:

```
ZIF_EGA_FW_CJI~UPDATE   (ZCL_EGA_CJ_ENH_IMPL_D…)
  ACCESS_STUDENT_EXIT_BUFFER
```

So the same caller reaches here both with and without an id. Worth a breakpoint on
line 3 to see which path arrives empty — most likely a read attempted before the
student has been resolved, in which case the buffer call is simply premature and the
right fix is upstream, not here.

Note this also means the buffer has been doing nothing useful on those calls: every
blank-id read is a miss, so the data is being re-read from source every time. Fixing
the caller may turn out to restore a cache that has quietly not been working.
