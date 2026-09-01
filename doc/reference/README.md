# Raw source, kept because it is not in any repository

These are **read-only copies** of material that had to be supplied by hand,
one file at a time. None of it lives in `rdcusjourney`, `shapeit1120` or
`shapeitext2`, so without this folder a later session has to ask for it again.

The distilled findings are in [`../services/odata-services.md`](../services/odata-services.md)
and [`../controls/shapeit-census.md`](../controls/shapeit-census.md). Read those
first; come here when you need a method body, an exact structure, or a filter
this repository does not already record.

## Rules for this folder

**Never edit anything in `legacy-src/`.** These are copies of legacy-namespace
objects. The namespace boundary in CLAUDE.md applies to the originals, and a
divergent copy here would be worse than no copy — it would look authoritative.
If SAP changes, replace the whole file.

**abapGit does not see this folder.** `.abapgit.xml` sets
`STARTING_FOLDER` to `/src/`, so nothing here is ever serialized, staged or
pulled as an object. That is what makes it safe to keep legacy source in a CJS
repository at all.

## legacy-src/

| File | Holds |
| --- | --- |
| `ZCL_ZEGA_FW_FND_DPC.txt` | `CHEMICALHISTORYS_GET_ENTITYSET` in full — the filter unpacking and the `ZFE_CJ_CHEMICALS_HIST` call |
| `ZCL_ZEGA_FW_FND_DPC_EXT.txt` | what the extension actually redefines (no chemicals) |
| `ZCL_ZEGA_FW_FND_MPC.txt` | `TS_CHEMICALHISTORY` and 11 other structures |
| `ZCL_ZEGA_EPDA_MAPLET_I_DPC.txt` | `WORKERSLISTSET_GET_ENTITYSET` and the `ZEGA_CJ_EPDA_LABORS_LIST` call |
| `ZCL_ZEGA_EPDA_MAPLET_I_DPC_EXT.txt` | `PORTACCOMMODATIO_GET_ENTITYSET`, and the empty room/bed bodies |
| `ZCL_ZEGA_EPDA_MAPLET_I_MPC.txt` | `TS_PORTACCOMMODATION`, `TS_WORKERSLIST`, 25 entity sets |
| `ZCL_ZEGA_EPDA_FSHRY_CR_DPC.txt` | the 112 not-implemented stubs |
| `ZCL_ZEGA_EPDA_FSHRY_CR_DPC_EXT.txt` | `CREATE_DEEP_ENTITY` → `CREATE_CASE( )`, the posting pattern to copy |
| `ZCL_ZEGA_EPDA_FSHRY_CR_MPC.txt` | fishery structures |
| `ZCL_ZEGA_EPDA_TD_DPC_EXT.txt` | permits, decisions, inspections; `GET_EXPANDED_NOC_CONSULTANT` |

## export/

`QNV_SB_UI_DEFIN.xlsx` — the `/QNV/SB_UI_DEFIN` export. 43,726 rows, one sheet.

Columns: `MANDT SCREEN_NAME CATEGORY FIELD_NAME LEVEL_CON ENABLED SEQUENCE
MANDATORY LABEL_CON CONTROL_TYPE DEFAULT_VALUE PARENT_CONTAINER PROPERTIES VALUE`

Every number in the control census is derived from this file, and it is the only
place the M-code → screen-family mapping can be recovered from (the code appears
as the `VALUE` of each screen's `JOURNEYTYPE` row).

```python
import openpyxl
wb = openpyxl.load_workbook('doc/reference/export/QNV_SB_UI_DEFIN.xlsx', read_only=True)
ws = wb['Sheet1']
it = ws.iter_rows(values_only=True)
hdr = list(next(it))
ix = {h: i for i, h in enumerate(hdr) if h}
```

## What is NOT here, and must not be added carelessly

`ZCL_ZUAEPASS_DPC_EXT` was supplied earlier in the same session and is
deliberately absent. It carries hardcoded UAE Pass credentials as class
constants — `M_PASS_DEV`, `M_PASS_QUA` and **`M_PASS_PRO`**. If that class is
ever needed here, strip those three constants first. Everything currently in
this folder was checked for credential-shaped constants and long key-like
literals before it was committed; both came back clean.
