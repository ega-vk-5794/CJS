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
