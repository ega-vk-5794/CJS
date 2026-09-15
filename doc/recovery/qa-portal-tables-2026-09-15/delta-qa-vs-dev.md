# QA vs DEV — the delta

Both sides as exported: QA from its 15.09.2026 delete log, DEV from the
live tables. Sorted so the two QA-only journeys and the five genuine
conflicts are findable; everything not listed here is identical.

## Summary

| | QA | DEV | shared | DEV only | QA only | same key, different value |
| --- | --- | --- | --- | --- | --- | --- |
| journeys | 35 | 58 | 33 | 25 | 2 | — |
| `ZEGA_T_CJ_GRP` rows | 128 | 168 | 120 | 48 | 8 | **5** |
| `ZEGA_T_CJ_IDT` rows | 70 | 107 | 66 | 41 | 4 | 0 |
| `ZEGA_T_CJ_ID` rows | 35 | 58 | 33 | 25 | 2 | 0 |

**The only real conflict in the whole comparison is five `ORDERNO` values.**
Everything else is presence: journeys DEV has and QA never did, and two
journeys QA has and DEV never did.

## The five rows where QA and DEV disagree on the same key

`ZEGA_T_CJ_GRP`, all department 23 (Education), `LEVELNO` and `DRILLDOWN` agree:

| DEPARTMENT / GROUPID / JOURNEYID | journey | QA ORDERNO | DEV ORDERNO |
| --- | --- | --- | --- |
| 23 / R098 / D014 | Issue | **2** | 1 |
| 23 / R160 / D001 | Request Initial Approval | **3** | 1 |
| 23 / R160 / D002 | Apply | **4** | 2 |
| 23 / R160 / D003 | Renew | **1** | 3 |
| 23 / R160 / D016 | Cancel | **2** | 4 |

Under R160 that is a straight reordering — QA runs D003, D016, D001, D002
where DEV runs D001, D002, D003, D016.

## Journeys in QA only (2) — DEV has never had them

| JOURNEYID | SIP_CODE | EN | AR | GRP rows |
| --- | --- | --- | --- | --- |
| E142 | 1673 | Renew | تجديد | 31/R099, 32/R099, 33/R099, 6/R099 |
| E146 | 1672 | Appeal | استئناف | 31/R099, 32/R099, 33/R099, 6/R099 |

Both sit under group `R099` in departments 6, 31, 32 and 33 — four GRP rows each.

## Journeys in DEV only (25) — never in QA, so not part of the restore

| JOURNEYID | SIP_CODE | EN | AR present? | GRP rows in DEV |
| --- | --- | --- | --- | --- |
| D011 | D011 | School Marketing Materials (Approval) | yes | 23/281, 29/281, 35/281, 36/281 |
| D015 | 1646 | Issue | yes | 29/R098, 35/R098, 36/R098 |
| D017 | 0000 | Inquiries | yes | 23/282, 29/282, 35/282, 36/282 |
| D018 | 0000 | Complaints | yes | 23/282, 29/282, 35/282, 36/282 |
| D019 | 1643 | School Calendar (Approval) | yes | 23/281, 29/281, 35/281 |
| D023 | *(blank)* | Student's Affairs Services | yes | 29/R801, 30/R801, 36/R801 |
| D098 | 1665 | Cancelation of School License Ala test | yes | *none* |
| D099 | 1665 | QV Tables Test | **no** | *none* |
| E001 | 1183 | Renewal of a Recreational Fishing Licence (Without Boat) | yes | *none* |
| E002 | *(blank)* | Renew Professional License | **no** | *none* |
| E003 | *(blank)* | Recreational Fishing License without a boat | **no** | *none* |
| E004 | *(blank)* | Recreational Fishing License without a boat - Renewal | **no** | *none* |
| E005 | *(blank)* | Recreational Fishing License without a boat - For 1 Day | **no** | *none* |
| E006 | *(blank)* | New | **no** | *none* |
| E008 | *(blank)* | Fishermen Worker Sailing | **no** | *none* |
| E009 | *(blank)* | Boat License Transfer / Clearance | **no** | *none* |
| E010 | *(blank)* | Installation of Coral Reef | **no** | *none* |
| E023 | E023 | Dewatering | yes | 31/R103, 32/R103, 33/R103, 6/R103 |
| E024 | 1682 | Temporary Company Approval | yes | 31/R102, 32/R102, 33/R102, 6/R102 |
| E025 | E025 | Honey Beekeeping | yes | 31/R103, 32/R103, 33/R103, 34/R103, 6/R103 |
| E028 | 1697 | Apply | yes | 34/1128, 6/1128 |
| E029 | 1700 | Apply | yes | 34/1129, 6/1129 |
| E030 | 1695 | Apply | yes | 34/112, 6/112 |
| E031 | E031 | Outdoor Material Storage Approval | yes | 31/R102, 32/R102, 33/R102, 6/R102 |
| E032 | E032 | Groundwater Well Drilling Approval | yes | 31/R102, 32/R102, 33/R102, 6/R102 |

Three things worth noting in that list, all DEV-side and none of them QA's problem:

- **Eleven have no `ZEGA_T_CJ_GRP` row at all** — `D098`, `D099`, `E001`–`E006`,
  `E008`–`E010`. They are in `_ID` and `_IDT` but appear on no portal group.
- **Nine have no Arabic `_IDT` row** — `D099`, `E002`–`E006`, `E008`–`E010`.
- **Sixteen carry no real `SIP_CODE`** — nine blank (`D023`, `E002`–`E006`,
  `E008`–`E010`), two `0000` (`D017`, `D018`), and five repeating the journey
  id as its own code (`D011`, `E023`, `E025`, `E031`, `E032`). `D098` and
  `D099` additionally share `1665`. QA's 35 are all real four-digit codes and
  all distinct.

## The 48 DEV-only GRP rows

All 48 belong to the 25 DEV-only journeys above — there is no case of a shared
journey having an extra group row in DEV. Grouped by journey:

| JOURNEYID | DEPARTMENT/GROUPID | LEVELNO | ORDERNO |
| --- | --- | --- | --- |
| D011 | 23/281, 29/281, 35/281, 36/281 | 1 | 1 |
| D015 | 29/R098, 35/R098, 36/R098 | 2 | 1 |
| D017 | 23/282, 29/282, 35/282, 36/282 | 1 | 1 |
| D018 | 23/282, 29/282, 35/282, 36/282 | 1 | 2 |
| D019 | 23/281, 29/281, 35/281 | 1 | 5 |
| D023 | 29/R801, 30/R801, 36/R801 | 2 | 5 |
| E023 | 31/R103, 32/R103, 33/R103, 6/R103 | 2 | 3 |
| E024 | 31/R102, 32/R102, 33/R102, 6/R102 | 2 | 4 |
| E025 | 31/R103, 32/R103, 33/R103, 34/R103, 6/R103 | 2 | 1 |
| E028 | 34/1128, 6/1128 | 2 | 1 |
| E029 | 34/1129, 6/1129 | 2 | 1 |
| E030 | 34/112, 6/112 | 2 | 1 |
| E031 | 31/R102, 32/R102, 33/R102, 6/R102 | 2 | 5 |
| E032 | 31/R102, 32/R102, 33/R102, 6/R102 | 2 | 6 |

## The 41 DEV-only IDT rows

All 41 belong to the 25 DEV-only journeys (25 English + 16 Arabic — the nine
missing-Arabic journeys above are why it is not 50). Texts are in the table
of DEV-only journeys further up; nothing else is added here.

## What is identical

- All **33** shared SIP codes.
- All **66** shared `_IDT` texts, EN and AR, character for character.
- **115 of 120** shared GRP rows in full; the other five differ only in `ORDERNO`.
- `DRILLDOWN` is `N` on every row of both sides; `ICON` is blank on every row of both.
- `POPULAR` and `ANONYMOUS` are blank on every `_ID` row of both.
