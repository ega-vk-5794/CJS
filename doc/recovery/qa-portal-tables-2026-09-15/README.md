# QA portal tables deleted 15.09.2026 — what was recovered and how

`ZEGA_T_CJ_GRP`, `ZEGA_T_CJ_IDT` and `ZEGA_T_CJ_ID` were emptied in QA on
**15.09.2026, 16:20:30 – 16:24:04**, by `VIKRAM.K`, transaction `SE24`,
program `SETS_CLASS_TEST_ENTRY`. Every logged row carries change type
`Deleted`; there is no Insert or Update in the window, so the log is the
whole event and nothing was changed before it.

**Restore with [`ZRAK_CJ_QA_RESTORE`](../../../src/zrak_cj_qa_restore.prog.abap),
run in the QA client.** Test run is its default. The CSVs beside this note
are the same 233 rows, for SE16 / LSMW or just for reading.

| Table | Rows | Source of each field |
| --- | --- | --- |
| `ZEGA_T_CJ_GRP` | 128 | DEPARTMENT, GROUPID, JOURNEYID, LEVELNO, ORDERNO, DRILLDOWN all logged. ICON logged blank on all 128. |
| `ZEGA_T_CJ_IDT` | 70 | SPRAS, JOURNEYID, DESCRIPTION all logged. 35 journeys × EN + AR, no journey missing a language. |
| `ZEGA_T_CJ_ID` | 35 | JOURNEYID and SIP_CODE logged. POPULAR and ANONYMOUS logged blank. DESCRIPTION **not logged** — see below. |

## Why the values come from QA's change log and not from the DEV export

The DEV export was supplied as the reference, and **DEV is not a copy of QA**:

- QA held **35** journeys, DEV holds **58**. The 23 extra DEV journeys
  (`D011`, `D015`, `D017`–`D019`, `D023`, `D098`, `D099`, `E001`–`E010`,
  `E023`–`E025`, `E028`–`E032`) were **never in QA** and must not be created there.
- `E142` and `E146` exist in **QA only**, so DEV could not have supplied them at all.
- Five `ZEGA_T_CJ_GRP` rows carry a different `ORDERNO` in QA than in DEV:

  | DEPARTMENT / GROUPID / JOURNEYID | QA (restored) | DEV |
  | --- | --- | --- |
  | 23 / R160 / D001 | 3 | 1 |
  | 23 / R160 / D002 | 4 | 2 |
  | 23 / R160 / D003 | 1 | 3 |
  | 23 / R160 / D016 | 2 | 4 |
  | 23 / R098 / D014 | 2 | 1 |

  Copying DEV would have put the tiles back in the wrong order on four
  Education groups.

Everything else that appears in both agrees **exactly** — all 33 shared
SIP codes, all 66 shared EN/AR descriptions, and the LEVELNO / DRILLDOWN
of every shared group row. That agreement is what makes reading the
change log trustworthy, and the five disagreements above are what make
reading it necessary.

## The three fields the log could not answer, and what was done

- **`MANDT`** — change documents do not record the client. The report
  writes `sy-mandt`, so it must be **run in the QA client**, not
  transported into one.
- **`POPULAR` / `ANONYMOUS`** (`ZEGA_T_CJ_ID`) — present in the log and
  blank on all 35 rows; blank in DEV on all 58 as well. Restored blank.
- **`ZEGA_T_CJ_ID-DESCRIPTION`** — the only field absent from the log
  entirely (the export carries seven header columns and three value
  columns: SIP_CODE plus the two blanks above). It is restored from the
  journey's **English `ZEGA_T_CJ_IDT` text**, because in DEV those two
  columns are identical for all 58 rows with no exception. This is the
  one inferred value in the whole restore — `P_DESC` on the selection
  screen turns it off and leaves the column blank instead.

One label in the `ZEGA_T_CJ_ID` export is misleading: the value column is
headed `Journey ID` a second time, but it is **`SIP_CODE`** — every one of
the 33 codes QA and DEV share matches DEV's `SIP_CODE` exactly.

## What the report will not do

A row that is already back and already correct is counted and skipped. A
row that is back with **different** values is listed and left alone unless
`P_OVER` is ticked — a restore must not quietly overwrite something
somebody re-created by hand since the delete.

## Not verified here

Nothing in this repository can be compiled, activated or run. The report's
structure, its row counts and the reconstruction above were checked against
the exports; **activation and the run itself are outstanding.**
