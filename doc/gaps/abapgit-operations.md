# abapGit pull and stage — what has actually gone wrong here

Not theory. Every item below happened in this repository, with the evidence.

## 1. Stage-without-pull reverts committed work

**Staging an object that has not been pulled pushes SAP's older copy over newer
work in git.** The pull dialog's `Overwrite local object` rows arrive
**unticked**, and the ticks reset every time the dialog opens — so an existing
object is skipped unless ticked by hand, on every pull. abapGit still reports
success.

Confirmed occurrences:

| What was lost | How |
| --- | --- |
| The E128 PAID gate | Pushed to git, E128 showed `M_`, row not ticked, next Stage pushed SAP's older copy back. The gate was gone a second time |
| `ZCL_RAK_JOURNEY_RENDER`, `ZCL_RAK_JOURNEY_UTIL`, `ZCL_RAK_MIGRATOR` | One stage reverted all three; the new classes survived only because SAP did not have them |
| `ZCL_RAK_CJ_REQ_CTX`, `ZCL_RAK_CJ_API` | A stage put back the subclass version that had **failed activation three times** |
| **`ZCL_D003_SCHOOL_LIC_RNEW_LOGIC`, twice** | 51 lines — the whole `OWNERS_SEARCH` outbound remap — deleted by a stage, restored, then deleted by the next stage |

**If a fix you know you made is missing, check the stage history before
re-diagnosing the code.**

### The D003 case, because it is the clearest
Without the remap, `TABLES_FOR_BACKEND( )` puts the share into
`UI_TABLE_COLUMN5` while `/QNV/SB_UI_DEFIN` gives `GS_DATA-OWNERS[]-SHARE_PER` a
`LIST_SEQUENCE` of 3, and the backend refuses the step with **"The Total of the
Share (0.00%) is not equal to 100%"**. D001 and D004 carry the same fix.

It has now been reverted twice. It will keep reverting until
`ZCL_D003_SCHOOL_LIC_RNEW_LOGIC` is **pulled into SAP before the next stage**.

## 2. Reading the State column

`local` + `remote`:

| State | Meaning | Action |
| --- | --- | --- |
| `_M` `_A` | git is ahead | tick — safe |
| `M_` | **SAP has changes git does not** | ticking discards them — diff first |
| `MM` | both changed | conflict — diff before choosing |

## 3. Objects that reappear in every pull

Two distinct causes, and they need opposite fixes.

**a) The object was pulled but never activated.** abapGit compares git against
SAP's **active** version. Until activation, SAP still holds the old code and the
row is listed again. Activate after every pull.

> *Active does not mean current.* A pull writes the source and leaves the object
> inactive; the runtime keeps running the OLD active version and the Class
> Builder still displays it. A syntax error therefore looks exactly like a pull
> that never happened. Verify by **content** — open SE24 and look for a method or
> a string you just added — never by the `Implemented / Active` label.

**b) The object cannot be created at all.** Nine rows reappeared indefinitely
because git held a `.clas.xml` / `.prog.xml` with **no `.abap` beside it**. Git
history showed an `.abap` had never existed — zero commits, ever. abapGit listed
an object it had no source to create, the pull could not complete it, and it came
back next time.

They were residue of a rename that completed only for E028: each berth / store /
housing journey exists under two names, `<ACTION>_<THING>` and `<THING>_<ACTION>`,
and only E028 moved its source across. The shells were deleted.

**A metadata file with no source is not an object. Delete it.**

That shell had also concealed a live defect: `ZRAK_E029_LOAD` set
`handler_class = 'ZCL_E029_STORE_NEW_LOGIC'`, one of the shells — so running it
would have created a journey pointing at a handler that does not exist.

## 4. Two sessions editing the same class

`ZCL_RAK_JOURNEY_RENDER` was edited by two sessions at once and cost a merge
each time. Decide who owns a class before the next pull; a file showing `MM` is
the warning.

## 5. Practical order

1. **Pull first, tick every `Overwrite local object` row you mean to keep.**
2. Diff anything showing `M_` or `MM`.
3. **Activate.** `ZCL_RAK_CJS` and `ZCL_RAK_JOURNEY_LOGIC` break widest — activate those first.
4. Verify by content, not by status.
5. Only then Stage.
