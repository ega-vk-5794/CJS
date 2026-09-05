# Ticket register

The living record of what the SIT testers raised against each journey, and who
closes each line.

| File | What it is |
| --- | --- |
| `register.py` | The data. One line per observation, in the tester's own words, with a state and the action that closes it. **This is the only file you edit.** |
| `build.py` | Regenerates the other three. Run `python3 doc/tickets/build.py`. |
| `SNAPSHOT.md` | The same register as markdown, journey by journey - readable in git and in a PR. |
| `register.json` | The same register as data, for anything that wants to consume it. |
| `snapshot.html` | The board the team reads, published as an artifact. |

## States

| State | Meaning | Who closes it |
| --- | --- | --- |
| `done_claude` | Fixed in CJS code, in git on `main` | nobody - but the object still needs an abapGit Pull **and** an activation |
| `done_dev` | The developer has closed it on the Jira thread | already done |
| `config` | CJS configuration - Studio tables, no ABAP | the journey's developer |
| `backend` | Backend, BAdI or record model | the backend team |
| `portal` | Portal, launchpad, Arabic service card | the portal team |
| `check` | Needs one run or one screenshot before it can be typed | reporter + developer together |

## Each round

1. Export the Jira issues (Issues + Comments sheets).
2. Add or re-state the observations in `register.py`; move a line to `done_*`
   when it is actually closed.
3. `python3 doc/tickets/build.py`
4. Commit, and republish `snapshot.html` to the same artifact URL so the link
   the team already has stays current.

## Who does what

The register splits the work by **who does it**, not only by what it is:

- **`fw` - framework.** A shared engine class (`ZCL_RAK_JOURNEY_*`). One change,
  every journey feels it, so the CJS team makes it and pushes it and the team
  pulls it. Listed on the *Framework changes* sheet.
- **`handler` - the journey's own class.** `ZCL_<journey>_..._LOGIC` belongs to
  the developer who owns that service. Where a fix is already written it sits in
  git for them to read and take - it is not pushed on their behalf and it does
  not count as closed until they take it.
- **`config`** never leaves the Studio.

`CJS_journey_ownership.xlsx` is the same split as a spreadsheet: one row per
journey with a FRAMEWORK column, a HANDLER CLASS column and a CONFIG column,
plus a sheet of all 172 observations and a sheet of the framework changes on
their own.
