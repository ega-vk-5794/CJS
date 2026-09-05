# CJS journey snapshot - 5 September 2026

Built from the five Jira exports (Issues + Comments sheets). Regenerate with `python3 doc/tickets/build.py` after editing `register.py`.

**19 journeys - 19 tickets - 172 observations - 30 closed - 142 open**

| Bucket | Count | Who closes it |
| --- | ---: | --- |
| Fixed in CJS code | 15 | in git - abapGit Pull + activate |
| Closed by developer | 15 | already done |
| CJS configuration | 72 | journey developer, in the Studio |
| Backend / record model | 20 | backend team |
| Portal / framework | 28 | portal team |
| Needs a look | 22 | one run or one screenshot |

## Waiting on an abapGit Pull

A code fix is not live until the object is pulled AND activated. In the pull dialog every *Overwrite local object* row arrives **unticked**.

| Object | What changed | Ticket |
| --- | --- | --- |
| `ZCL_E025_BEEKEEPING_LOGIC` | Applicant BP goes to LOGIN_BP, not to the owner search box | CJSMIG-703 |
| `ZCL_E026_TREE_REMOVAL_LOGIC` | Applicant BP also goes out as LOGIN_BP | CJSMIG-704 |
| `ZCL_E027_VICE_CAPTAIN_LOGIC` | Same applicant-BP fix, applied before it was reported | - |
| `ZCL_EPDA_E022_DEV_PROJ_LOGIC` | Same applicant-BP fix; duplicate applicant write removed | CJSMIG-684 |
| `ZCL_D021_MOD_SCHOOL_FEE_LOGIC` | Same applicant-BP fix | CJSMIG-693 |
| `ZCL_D014_STAFF_GOLD_VISA_LOGIC` | Same applicant-BP fix | - |
| `ZCL_E018_NOC_TRANS_CHEM_LOGIC` | Activation breaker removed - the class had no active version | CJSMIG-697 |
| `ZCL_E017_NOC_EXP_CHEM_LOGIC` | All fourteen Add Chemical fields marked and enforced | CJSMIG-687 |
| `ZCL_RAK_JOURNEY_LOGIC` | Dialogs draw their own messages and lay out in two columns | CJSMIG-687 / 697 |
| `ZCL_RAK_JOURNEY_RENDER` | 'Not now' beside Send feedback; attachment labels carry the native required marker | several |
| `ZCL_RAK_JOURNEY_ENGINE` | FBSKIP handling for the skipped feedback | several |
| `ZCL_RAK_JOURNEY_BE` | Counts and names the attachments it could not read | several |
| `ZRAK_CJ_FIXPACK` | Report: applies 19 of the config points mechanically, per journey | 682-697 |
| `ZRAK_CJ_BACKUP` | Report: full export / import of a journey's configuration | - |

## E021 - Alternative Fuel

EPDA · CJSMIG-683 · SIT · anand babu · blocks CJSMIG-468 · 8 screenshots on the ticket · **15 observations, 1 closed, 14 open**

Handler ZCL_EPDA_E021_ALTER_FUEL_LOGIC has no ON_INIT, so the applicant's name, ID, mobile, email and role are never seeded - that is the same root cause behind 'applicant details missing' and most of the owner-step noise. Adding one needs the journey's own field names from the Studio.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Initial page loads with error messages | Needs a look | The screenshot is already on the ticket, but Jira is not reachable from where this register is built - paste the error text here. Most likely the required-field messages firing before the citizen has typed anything, which is a rule/required config question, not the engine. |
| 2 | Applicant details not aligned - should be row wise | CJS configuration | Studio > Design tab. Place the applicant fields on one row of the 12-column grid (ZRAK_CJ_LAY). |
| 3 | EPDA permit no & applicant type data missing | Needs a look | The handler has no ON_INIT, so nothing seeds these. Confirm the field names in ZRAK_T_JNY_FLD and an ON_INIT can be written in an hour. |
| 4 | Permit / EID / trade licence order wrong, no search button | CJS configuration | Field order in the Design tab; the search button appears when the field's FTYPE is SEARCH. |
| 5 | Company details field order not correct | CJS configuration | Design tab. |
| 6 | Company name EN/AR not filled from the permit number | Backend / record model | The permit read has to return the company name. Backend/BAdI. |
| 7 | Grid: all row fields mandatory, drop the delete1 column | CJS configuration | REQUIRED per field, and remove the column from the grid spec in ZRAK_T_JNY_FLD-DEFAULT_VAL. |
| 8 | Units and No. of Months should be dropdowns | CJS configuration | Add the values to ZRAK_T_JNY_OPT and set CLOSED_LIST = X. |
| 9 | Supplier company: order and mandatory indicators | CJS configuration | Design tab + REQUIRED. |
| 10 | Step name 'Letter from the Supplier Company' -> 'Documents' | CJS configuration | Already coded in ZRAK_CJ_FIXPACK, English and Arabic. Run the report for this journey. |
| 11 | Mandatory attachment labels need the * indicator | CJS configuration | The engine draws the asterisk now - RENDER_ATTACH( ) passes the native required property. What is left is ticking REQUIRED on each upload field. |
| 12 | Declaration & Notes missing | CJS configuration | Add a DISPLAY field whose DEFAULT_VAL is TEXT:@nnn pointing at a ZRAK_T_CJ_TXT row, so it reads in both languages. |
| 13 | Feedback is mandatory | Fixed in CJS code | A 'Not now' button now sits beside Send feedback and the journey finishes without it. ZCL_RAK_JOURNEY_RENDER + ZCL_RAK_JOURNEY_ENGINE (FBSKIP). |
| 14 | Case created (1959717) but attachments not saved | Needs a look | Instrumented: ZCL_RAK_JOURNEY_BE now counts the files it could not read, says so on screen and names them on the trace. Re-run with &trace=x and send the ATTACH line. |
| 15 | Arabic - service start button not showing | Portal / framework | Service card / launchpad, not CJS. |

## E022 - Development Project

EPDA · CJSMIG-684 · SIT · anand babu · blocks CJSMIG-477 · 8 screenshots on the ticket · **15 observations, 2 closed, 13 open**

The duplicate applicant write was fixed in the handler earlier; the applicant BP now also goes out as LOGIN_BP. Everything else on this ticket is step names, field order and two missing texts - all Studio work, and four of them are already coded into ZRAK_CJ_FIXPACK.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Initial page loads with error messages | Needs a look | The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built. |
| 2 | Applicant details not aligned - should be row wise | CJS configuration | Design tab. |
| 3 | Applicant details are duplicated | Fixed in CJS code | The handler was writing the applicant fields twice. Fixed in ZCL_EPDA_E022_DEV_PROJ_LOGIC. |
| 4 | Emirates ID search should follow the format; Browse not required | CJS configuration | PLACEHOLDER for the mask, REGEX for the format, FTYPE SEARCH instead of the browse control. |
| 5 | Permit / EID / trade licence order; permit number not a dropdown | CJS configuration | Design tab + FTYPE. |
| 6 | Company details field order not correct | CJS configuration | Design tab. |
| 7 | Company name English & Arabic duplicated | CJS configuration | Two fields are bound to the same value. Hide one in ZRAK_T_JNY_FLD. |
| 8 | Rename step 'Development Project' -> 'Project Details' | CJS configuration | Coded in ZRAK_CJ_FIXPACK, EN + AR. |
| 9 | Rename step 'Trade license' -> 'Documents' | CJS configuration | Coded in ZRAK_CJ_FIXPACK, EN + AR. |
| 10 | Trade licence attachment is missing | CJS configuration | Add the upload field to the Documents step. |
| 11 | Declaration & Note missing | CJS configuration | DISPLAY field with a TEXT: default. |
| 12 | Step 5 request confirmation not required | CJS configuration | Coded in ZRAK_CJ_FIXPACK as STEP_OFF - reversible, sets ACTIVE blank. |
| 13 | Feedback is mandatory | Fixed in CJS code | 'Not now' button - same engine fix as E021. |
| 14 | Attachments are not saving | Needs a look | Re-run with &trace=x and send the ATTACH line. |
| 15 | Customer action not working | Portal / framework | Landing page redirect - portal team. |

## D012 - School Trips & Activities

DOK · CJSMIG-685 · SIT · Jyoti Meena · blocks CJSMIG-351 · 8 screenshots on the ticket · **9 observations, 4 closed, 5 open**

Three of the nine are closed by the developer. What is left is the portal side - Arabic cases, Customer Action, the Back button - plus one backend mapping fault where the selected school is not the school that reaches the case.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Attachment types should allow JPG, PNG etc | Closed by developer | Closed by Jyoti. |
| 2 | Selected Indian school, a different school reached the case | Backend / record model | Backend data mapping - Jyoti's own answer. |
| 3 | Attachments not reflected into the case | Closed by developer | Closed by Jyoti. |
| 4 | Customer Action from landing page, Upload does nothing | Portal / framework | Framework side - Jyoti's answer. |
| 5 | Cases not translated into Arabic | Portal / framework | Framework side. |
| 6 | No case exists to submit in Arabic | Portal / framework | Framework side. |
| 7 | Back button does not work to submit a new case | Portal / framework | Framework side. |
| 8 | Applicant type field alignment | Closed by developer | Closed by Jyoti. |
| 9 | Curriculum type field alignment | Closed by developer | Closed by Jyoti. |

## E017 - Export Chemical Products

EPDA · CJSMIG-687 · SIT · Jyoti Meena · blocks CJSMIG-522 · 7 screenshots on the ticket · **18 observations, 4 closed, 14 open**

The Add Chemical dialog was the bulk of this ticket and is fixed in code: all fourteen fields are now marked required AND enforced, the dialog shows its own messages instead of throwing them behind the modal, and it lays out in two columns. Search from History is a genuine gap - the legacy control reads ChemicalHistorySet and nothing in CJS calls it yet.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Owner search should be in EID format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. Listed in the fixpack worklist. |
| 2 | Representative + owner EID search errors and will not move to the next step | Needs a look | Needs one run with the exact search value. The popup validation now blocks correctly, so an error here is the search itself. |
| 3 | Permit number / trade licence etc. not required on the chemical tab | CJS configuration | Coded in ZRAK_CJ_FIXPACK as three HIDE rules anchored on the CHEMICALS_DETAILS grid. |
| 4 | Add Chemical - all fields should be mandatory | Fixed in CJS code | All fourteen are now marked with an asterisk and enforced. Ten of the fourteen checks had been commented out. ZCL_E017_NOC_EXP_CHEM_LOGIC->VALIDATE_INPUT( ). |
| 5 | Mandatory-field message shows on the main screen, not in the dialog | Fixed in CJS code | DIALOG_FORM( ) now draws pending messages inside the dialog. ZCL_RAK_JOURNEY_LOGIC. |
| 6 | One field per row - should be two or more | Fixed in CJS code | Popup dialogs lay out in two columns now. The fix was FormContainers, not the columnsL property. ZCL_RAK_JOURNEY_LOGIC->DIALOG_FORM( ). |
| 7 | Bill of Lading input clears its own value | Needs a look | Check BOL_POP actually exists in ZRAK_T_JNY_FLD - a field name that is not on the journey accepts set_val and get_val and does nothing. |
| 8 | 'Use a previous declaration' field not required | CJS configuration | Hide the field. |
| 9 | HS code should be a guided formatted number with a watermark | CJS configuration | REGEX for the format, PLACEHOLDER for the watermark. |
| 10 | Modify - existing values are not showing | Needs a look | The edit path does not load the row back into the dialog. Needs a run. |
| 11 | Search from History is missing | Needs a look | A real gap, not a bug: the legacy control reads ChemicalHistorySet on zega_fw_fnd_srv and no CJS class calls it. Needs a decision before it can be built. |
| 12 | 'up to 2 MB' repeats on every attachment; mandatory indicator missing | CJS configuration | The asterisk is engine-side and done; the repeated size hint is per-field wording. |
| 13 | Preview page should be removed | CJS configuration | Coded in ZRAK_CJ_FIXPACK as STEP_OFF. |
| 14 | Step 5 request confirmation not required | CJS configuration | Coded in ZRAK_CJ_FIXPACK as STEP_OFF. |
| 15 | Feedback is mandatory | Fixed in CJS code | 'Not now' button. |
| 16 | Attachments are not saving | Needs a look | Re-run with &trace=x. |
| 17 | Customer action not working | Portal / framework | Portal team. |
| 18 | Chemical details missing in the backend | Backend / record model | Read the grid spec against the LIST_SEQUENCE rows for that screen in /QNV/SB_UI_DEFIN - a backend table's cells are positional at both ends. |

## D002 - Private School Licence - Apply

DOK · CJSMIG-688 · SIT · Hasan Fraz · blocks CJSMIG-252 · 8 screenshots on the ticket · **11 observations, 6 closed, 5 open**

Six of eleven closed by the developer. Arabic wording and the record-model access to Manager & School were handed to anand on the thread.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Add Manager - wrong text, should be Birthday | Closed by developer | Closed by Hasan. Also coded in ZRAK_CJ_FIXPACK as a LABEL change on MANAGER_DOB. |
| 2 | Fees Details comes back empty | Closed by developer | Closed by Hasan. |
| 3 | Building Information should be demit | Closed by developer | Closed by Hasan. |
| 4 | Attachment type shows DOC, should be PDF / JPG | Closed by developer | Closed by Hasan. Also coded in ZRAK_CJ_FIXPACK as an ATTACH_TYPE change. |
| 5 | Cannot upload a PDF or a photo | Closed by developer | Closed by Hasan - same accept list. |
| 6 | Arabic translation not complete | CJS configuration | Handed to anand on the thread. ZLABEL_AR across the journey. |
| 7 | Attachments not reflected to the record model | Closed by developer | Closed by Hasan. |
| 8 | Manager empty in the application form | Backend / record model | Not answered on the thread. Record model. |
| 9 | Cannot access Manager & School in the record model | Backend / record model | Handed to anand on the thread. |
| 10 | Customer Action should redirect to the new CJS | Portal / framework | Portal team. |
| 11 | Mandatory attachments need the * | CJS configuration | Engine draws it; tick REQUIRED on each upload field. |

## D013 - Staff Appointment Letters

DOK · CJSMIG-689 · SIT · Jyoti Meena · blocks CJSMIG-360 · 8 screenshots on the ticket · **10 observations, 3 closed, 7 open**

The developer answered every line. Four are framework/portal, one is backend mapping, three are done. The beneficiary not reaching the record model is the one that still stops a case completing.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Application form - data missing | Backend / record model | Record model. |
| 2 | Only one attachment reflected, the others not | Closed by developer | Closed by Jyoti. Worth knowing why: GET_ATTACHMENT( ) de-duplicates on (objsrc, diffcrt, objsrctype, objtrgtype), so two files sharing a document type collapse into one. |
| 3 | Selected school is not the school on the case | Backend / record model | Backend data mapping - Jyoti's answer. |
| 4 | Customer Action upload not working | Portal / framework | Framework side - Jyoti's answer. |
| 5 | Cases not translated into Arabic | Portal / framework | Framework side. |
| 6 | No case exists to submit in Arabic | Portal / framework | Framework side. |
| 7 | Back button does not work to submit a new case | Portal / framework | Framework side. |
| 8 | Applicant type field alignment | Closed by developer | Closed by Jyoti. |
| 9 | Remove the spaces on grades | Closed by developer | Closed by Jyoti. |
| 10 | Beneficiary not reflected in the record model - case stuck | Backend / record model | anand to advise on the mapping - Jyoti's answer. |

## D014 - Staff Experience Certificates

DOK · CJSMIG-690 · SIT · Jyoti Meena · blocks CJSMIG-369 · 6 screenshots on the ticket · **11 observations, 0 closed, 11 open**

Nothing on this ticket is CJS-side yet, and there is a repository hazard behind it: TWO handler classes claim D014 - ZCL_D014_STAFF_EXP_CERT_LOGIC and ZCL_D014_STAFF_GOLD_VISA_LOGIC. Confirm which one the journey row points at before chasing 'service not working' any further.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | The service does not work on the portal screen | Needs a look | Check which handler class the journey row points at first - two classes claim D014. |
| 2 | Application form - data missing | Backend / record model | Record model. |
| 3 | Beneficiary not reflected in the record model - case stuck | Backend / record model | Same fault as D013. |
| 4 | Cannot complete the case - problem with the case output | Backend / record model | Follows from the beneficiary fault. |
| 5 | Selected school is not the school on the case | Backend / record model | Backend data mapping. |
| 6 | Customer Action upload not working | Portal / framework | Framework side. |
| 7 | Old case journey portal not working, cannot compare | Portal / framework | Portal team. |
| 8 | Cases not translated into Arabic | Portal / framework | Framework side. |
| 9 | No case exists to submit in Arabic | Portal / framework | Framework side. |
| 10 | Back button does not work to submit a new case | Portal / framework | Framework side. |
| 11 | Cannot post payment through the landing page | Needs a look | Run with &trace=x: PREPARE_PAYMENT( ) names its exit - NOCASE, NOSCREEN or NOURL - which says whether the case, the screen mapping or the gateway address is missing. |

## D003 - Private School Licence - Renew

DOK · CJSMIG-692 · Backlog · anand babu · blocks CJSMIG-261 · 3 screenshots on the ticket · **5 observations, 0 closed, 5 open**

Five lines, all config or portal. The missing BP labels are a ZLABEL fill and are already listed in the fixpack worklist.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Owner - BP labels missing | CJS configuration | Fill ZLABEL / ZLABEL_AR. In the fixpack worklist. |
| 2 | Owner details missing from the application form | Backend / record model | Record model. |
| 3 | Arabic version has no Start button | Portal / framework | Service card. |
| 4 | Customer Action should redirect to CJS | Portal / framework | Portal team. |
| 5 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |

## D021 - School Fees (Amend or Increase)

DOK · CJSMIG-693 · SIT · anand babu · blocks CJSMIG-396 · 4 screenshots on the ticket · **4 observations, 0 closed, 4 open**

Small ticket, one hard blocker: transportation fees do not pick the distance up from the system, and the case cannot be submitted. That is a backend read plus a field rename, not an engine fault. The applicant BP now also goes out as LOGIN_BP on this journey.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Field should read Distance, not Educational stage | CJS configuration | ZLABEL / ZLABEL_AR. In the fixpack worklist - the field name is not known from here. |
| 2 | Table should show every educational stage and fetch the current fee | Backend / record model | The read has to return all stages with their current fee. |
| 3 | Transportation fees do not reflect the distance - error, cannot submit | Backend / record model | Blocker. The distance is not coming back from the system; the submit fails on it. |
| 4 | Cannot complete the case on the submission screen | Backend / record model | Follows from the fee fault above. |

## D016 - Private School Licence - Cancel

DOK · CJSMIG-694 · Backlog · anand babu · blocks CJSMIG-270 · 2 screenshots on the ticket · **3 observations, 0 closed, 3 open**

Three lines, none of them CJS code. Reassigned to anand for the Arabic side.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Arabic version has no Start button | Portal / framework | Service card. Reassigned to anand. |
| 2 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 3 | Customer Action should redirect to CJS | Portal / framework | Portal team. |

## D006 - Amend - Manage Change

DOK · CJSMIG-696 · Backlog · Hasan Fraz · blocks CJSMIG-297 · 3 screenshots on the ticket · **4 observations, 0 closed, 4 open**

Four lines. The new manager's details not appearing on the application form is a record-model question for the backend team.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | New manager details not shown on the application form | Backend / record model | Record model. |
| 2 | Arabic version has no Start button | Portal / framework | Service card. |
| 3 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 4 | Customer Action should redirect to CJS | Portal / framework | Portal team. |

## E018 - Transport of Chemical Products

EPDA · CJSMIG-697 · SIT · Hasan Fraz · blocks CJSMIG-531 · 5 screenshots on the ticket · **10 observations, 4 closed, 6 open**

This journey's class had NO ACTIVE VERSION - a CONSTANTS ... TYPE string VALUE '' would not compile, so SAP kept running an older build and every fix looked like it had not been applied. That is fixed in git. Re-test the CX_SY_CONVERSION_NO_NUMBER post failure only after the class is activated; it may well go with it.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Owner search should be in EID format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. In the fixpack worklist. |
| 2 | Representative + owner EID search errors and will not move on | Needs a look | Re-test after the class is activated. |
| 3 | Permit number / trade licence etc. not required on the chemical tab | CJS configuration | Coded in ZRAK_CJ_FIXPACK as three HIDE rules. |
| 4 | Add Chemical - all fields should be mandatory | Fixed in CJS code | All fourteen marked and enforced. ZCL_E018_NOC_TRANS_CHEM_LOGIC. |
| 5 | Mandatory-field message shows on the main screen, not in the dialog | Fixed in CJS code | Engine fix - messages now draw inside the dialog. |
| 6 | One field per row - should be two or more | Fixed in CJS code | Two-column dialogs - engine fix. |
| 7 | Bill of Lading input clears its own value | Needs a look | Check BOL_POP exists in ZRAK_T_JNY_FLD. |
| 8 | 'Use a previous declaration' field not required | CJS configuration | Hide the field. |
| 9 | HS code should be a guided formatted number with a watermark | CJS configuration | REGEX + PLACEHOLDER. |
| 10 | Backend POST failed - CX_SY_CONVERSION_NO_NUMBER, cannot go to the next step | Fixed in CJS code | The class had no active version at all - a CONSTANTS ... TYPE string VALUE '' will not compile - so SAP was running an older build of every method on this journey. Fixed in git. Pull, activate, and re-test this line first. |

## D005 - Amend - Name Change

DOK · CJSMIG-698 · Backlog · Hasan Fraz · blocks CJSMIG-288 · 2 screenshots on the ticket · **3 observations, 0 closed, 3 open**

Three lines, all of them shared with D003/D006/D016 - the Arabic start button, the attachment asterisk and the Customer Action redirect.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Arabic version has no Start button | Portal / framework | Service card. |
| 2 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 3 | Customer Action should redirect to the new CJS | Portal / framework | Portal team. |

## D022 - Pursuing of Study Certificate

DOK · CJSMIG-699 · SIT · Hasan Fraz · blocks CJSMIG-405 · 6 screenshots on the ticket · **5 observations, 2 closed, 3 open**

Two closed by the developer. The payment step is the blocker and needs a trace run: PREPARE_PAYMENT( ) now names its own exit (NOCASE / NOSCREEN / NOURL) under &trace=x, which is what separates a missing case from a missing gateway address.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Service card is missing the 'who can apply' information | Portal / framework | Service catalogue - taken by Vikram on the thread. |
| 2 | Cannot search by Emirates ID; the field stays on SIS ID | Closed by developer | Closed by Hasan - the Emirates ID option was removed, SIS ID only. |
| 3 | Academic Year / School and Terms do not match the old version | Closed by developer | Closed by Hasan - both removed. |
| 4 | The payment step errors when paying | Needs a look | Run with &trace=x. PREPARE_PAYMENT( ) reports its exit and the keys the backend answered with, which separates 'no case' from 'no gateway address'. |
| 5 | Cannot complete the case at the payment step | Needs a look | Blocker - same run as above. |

## E019 - Transport of Used Oil

EPDA · CJSMIG-700 · SIT · anand babu · blocks CJSMIG-540 · 7 screenshots on the ticket · **23 observations, 1 closed, 22 open**

The longest ticket in the round, and almost all of it is config. Same root cause as E021: ZCL_EPDA_E019_TRANS_USED_LOGIC has no ON_INIT, so no applicant details are seeded at all.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Initial page loads with error messages | Needs a look | The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built. |
| 2 | Applicant details not aligned - should be row wise | CJS configuration | Design tab. |
| 3 | Applicant details are duplicated | CJS configuration | Not the same cause as E022 - this handler writes nothing. Two fields are bound to the same value; hide one. |
| 4 | Emirates ID search should follow the format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. |
| 5 | Permit / EID / trade licence order; permit number not a dropdown | CJS configuration | Design tab + FTYPE. |
| 6 | Company details field order not correct | CJS configuration | Design tab. |
| 7 | Company name English & Arabic duplicated | CJS configuration | Hide one of the two fields. |
| 8 | 'Material Text 1' should read 'Name' | CJS configuration | ZLABEL / ZLABEL_AR. |
| 9 | Issuing emirates should be a dropdown | CJS configuration | ZRAK_T_JNY_OPT + CLOSED_LIST. |
| 10 | Vehicle Code must not allow more than 2 digits | CJS configuration | MAX_LEN on the field. |
| 11 | Vehicle Plate must not allow more than 4 digits | CJS configuration | MAX_LEN on the field. |
| 12 | Remove the 'Mtable Delete 2' column | CJS configuration | Drop it from the grid spec in DEFAULT_VAL. |
| 13 | Units should be a dropdown | CJS configuration | ZRAK_T_JNY_OPT + CLOSED_LIST. |
| 14 | Address, Registered Emirate, Trade Licence should be inputs, not display | CJS configuration | Change FTYPE from DISPLAY to INPUT and tick REQUIRED. |
| 15 | Step name should change to Documents | CJS configuration | Step title, EN + AR. |
| 16 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 17 | Declaration & Notes missing | CJS configuration | DISPLAY field with a TEXT: default. |
| 18 | Feedback is mandatory | Fixed in CJS code | 'Not now' button. |
| 19 | Attachments are not saving | Needs a look | Re-run with &trace=x. |
| 20 | Company name not updated in the backend | Backend / record model | Backend write. |
| 21 | UOM not updated in the backend | Backend / record model | Backend write. |
| 22 | Customer action | Portal / framework | Portal team. |
| 23 | Arabic services cannot be submitted | Portal / framework | Framework side. |

## E020 - Batteries / Scrap Handling

EPDA · CJSMIG-701 · SIT · Hasan Fraz · blocks CJSMIG-549 · 8 screenshots on the ticket · **14 observations, 1 closed, 13 open**

Config-heavy. 'Vehicle details not saving in backend' is worth reading as a column-order fault first: a backend table's cells are positional at both ends and the order comes from LIST_SEQUENCE in /QNV/SB_UI_DEFIN, not from the CJS spec.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Initial page loads with error messages | Needs a look | The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built. |
| 2 | Applicant details not aligned - should be row wise | CJS configuration | Design tab. |
| 3 | Applicant details are duplicated | CJS configuration | Two fields bound to the same value; hide one. |
| 4 | Emirates ID search should follow the format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. |
| 5 | Permit / EID / trade licence order; permit number not a dropdown | CJS configuration | Design tab + FTYPE. |
| 6 | Rename the step 'Material Origin source' to 'Batteries/Scrap Details' | CJS configuration | Step title, EN + AR. |
| 7 | Fields under Material origin source must be dynamic and mandatory by dropdown value | CJS configuration | Show/hide belongs in ZRAK_T_JNY_RULE keyed on the dropdown, with REQUIRED on the fields it reveals. |
| 8 | Vehicle code 1 digit, vehicle plate 4 digits | CJS configuration | MAX_LEN on both fields. |
| 9 | 'Materials Det' is duplicated and should be renamed | CJS configuration | Hide one, rename the other. |
| 10 | Declaration & Note missing | CJS configuration | DISPLAY field with a TEXT: default. |
| 11 | Step 5 request confirmation not required | CJS configuration | STEP_OFF - the fixpack does this for other journeys and takes one more line. |
| 12 | Feedback is mandatory | Fixed in CJS code | 'Not now' button. |
| 13 | Attachments are not saving | Needs a look | Re-run with &trace=x. |
| 14 | Vehicle details not saving in the backend | Backend / record model | Line the grid spec up against the LIST_SEQUENCE rows for that screen before treating it as a rendering fault. |

## E023 - Dewatering Approval

EPDA · CJSMIG-702 · SIT · anand babu · blocks CJSMIG-558 · 0 screenshots on the ticket · **1 observations, 0 closed, 1 open**

One line: 'CJS service Not found'. The handler class exists and is complete, so this is the journey row or the launch link, not the code.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | CJS service Not found | CJS configuration | The handler class exists and is complete. Check the ZRAK_T_JNY row and the launch URL's journey id - a code that does not resolve gives exactly this. |

## E025 - Beekeeping Activity

EPDA · CJSMIG-703 · SIT · anand babu · blocks CJSMIG-567 · 4 screenshots on the ticket · **6 observations, 1 closed, 5 open**

The applicant BP fault is fixed. It was a one-word defect: the class called the applicant field 'OWNER_BP', which on this journey is the owner SEARCH BOX - so ON_INIT typed the applicant's partner number into the search field and blanked it again sixteen lines later.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Emirates ID search should follow the format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. |
| 2 | Number of Apiaries max 2 digits; Expected Production max 6 | CJS configuration | MAX_LEN on both fields. |
| 3 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 4 | Declaration & Note missing | CJS configuration | DISPLAY field with a TEXT: default. |
| 5 | Case id is not correct - shows the wrong number | Needs a look | Send the number that was shown next to the case it belongs to. On some families the journey key is not the case id, and the engine has one resolver for that - but it needs the pair to confirm. |
| 6 | Applicant BP not saved in the record model, not in the backend application | Fixed in CJS code | Fixed. The class called the applicant field OWNER_BP, which is this journey's owner SEARCH BOX; ON_INIT wrote the partner there and blanked it sixteen lines later. Now goes to LOGIN_BP. ZCL_E025_BEEKEEPING_LOGIC. |

## E026 - Tree Removal / Relocation / Pruning

EPDA · CJSMIG-704 · SIT · anand babu · blocks CJSMIG-576 · 3 screenshots on the ticket · **5 observations, 1 closed, 4 open**

Same applicant-BP family as E025 and fixed the same way, additively. The four remaining lines are config and are shared with E025.

| # | Observation | Status | What closes it |
| ---: | --- | --- | --- |
| 1 | Emirates ID search should follow the format; Browse not required | CJS configuration | PLACEHOLDER + REGEX; FTYPE SEARCH. |
| 2 | Mandatory attachments need the * | CJS configuration | Tick REQUIRED on each upload field. |
| 3 | Declaration & Note missing | CJS configuration | DISPLAY field with a TEXT: default. |
| 4 | Case id is not correct - shows the wrong number | Needs a look | Same as E025 - send the pair of numbers. |
| 5 | Applicant BP not saved in the record model, not in the backend application | Fixed in CJS code | The applicant partner now also goes out as LOGIN_BP, the field every other journey uses. ZCL_E026_TREE_REMOVAL_LOGIC. |

