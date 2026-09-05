# -*- coding: utf-8 -*-
"""Ticket register for the CJS SIT round.

Source: the five Jira exports of 05-Sep-2026 (Issues + Comments sheets).
Every observation below is one line a tester wrote, kept in their words and
classified. Edit this file and re-run build.py - nothing else is hand-written.

state values
  fw           framework change - engine class, made and pushed by us; the team pulls it
  handler      journey handler class - the developer's own ABAP; the change is written
               and sitting in git, but it is theirs to take
  done_dev     the developer has already closed it on the Jira thread
  config       CJS configuration - Studio tables, no ABAP
  backend      backend / BAdI / record model - not CJS
  portal       portal, launchpad, Arabic service card - not CJS
  check        needs a look at the system or the screenshot before it can be typed
"""

JOURNEYS = [
 # code, name, dept, ticket, jira status, assignee, note
 ("E021","Alternative Fuel","EPDA","CJSMIG-683","SIT","anand babu",
  "Handler ZCL_EPDA_E021_ALTER_FUEL_LOGIC has no ON_INIT, so the applicant's "
  "name, ID, mobile, email and role are never seeded - that is the same root "
  "cause behind 'applicant details missing' and most of the owner-step noise. "
  "Adding one needs the journey's own field names from the Studio."),
 ("E022","Development Project","EPDA","CJSMIG-684","SIT","anand babu",
  "The duplicate applicant write was fixed in the handler earlier; the "
  "applicant BP now also goes out as LOGIN_BP. Everything else on this ticket "
  "is step names, field order and two missing texts - all Studio work, and "
  "four of them are already coded into ZRAK_CJ_FIXPACK."),
 ("D012","School Trips & Activities","DOK","CJSMIG-685","SIT","Jyoti Meena",
  "Three of the nine are closed by the developer. What is left is the portal "
  "side - Arabic cases, Customer Action, the Back button - plus one backend "
  "mapping fault where the selected school is not the school that reaches the case."),
 ("E017","Export Chemical Products","EPDA","CJSMIG-687","SIT","Jyoti Meena",
  "The Add Chemical dialog was the bulk of this ticket and is fixed in code: "
  "all fourteen fields are now marked required AND enforced, the dialog shows "
  "its own messages instead of throwing them behind the modal, and it lays out "
  "in two columns. Search from History is a genuine gap - the legacy control "
  "reads ChemicalHistorySet and nothing in CJS calls it yet."),
 ("D002","Private School Licence - Apply","DOK","CJSMIG-688","SIT","Hasan Fraz",
  "Six of eleven closed by the developer. Arabic wording and the record-model "
  "access to Manager & School were handed to anand on the thread."),
 ("D013","Staff Appointment Letters","DOK","CJSMIG-689","SIT","Jyoti Meena",
  "The developer answered every line. Four are framework/portal, one is "
  "backend mapping, three are done. The beneficiary not reaching the record "
  "model is the one that still stops a case completing."),
 ("D014","Staff Experience Certificates","DOK","CJSMIG-690","SIT","Jyoti Meena",
  "Nothing on this ticket is CJS-side yet, and there is a repository hazard "
  "behind it: TWO handler classes claim D014 - ZCL_D014_STAFF_EXP_CERT_LOGIC "
  "and ZCL_D014_STAFF_GOLD_VISA_LOGIC. Confirm which one the journey row "
  "points at before chasing 'service not working' any further."),
 ("D003","Private School Licence - Renew","DOK","CJSMIG-692","Backlog","anand babu",
  "Five lines, all config or portal. The missing BP labels are a ZLABEL fill "
  "and are already listed in the fixpack worklist."),
 ("D021","School Fees (Amend or Increase)","DOK","CJSMIG-693","SIT","anand babu",
  "Small ticket, one hard blocker: transportation fees do not pick the distance "
  "up from the system, and the case cannot be submitted. That is a backend read "
  "plus a field rename, not an engine fault. The applicant BP now also goes out "
  "as LOGIN_BP on this journey."),
 ("D016","Private School Licence - Cancel","DOK","CJSMIG-694","Backlog","anand babu",
  "Three lines, none of them CJS code. Reassigned to anand for the Arabic side."),
 ("D006","Amend - Manage Change","DOK","CJSMIG-696","Backlog","Hasan Fraz",
  "Four lines. The new manager's details not appearing on the application form "
  "is a record-model question for the backend team."),
 ("E018","Transport of Chemical Products","EPDA","CJSMIG-697","SIT","Hasan Fraz",
  "This journey's class had NO ACTIVE VERSION - a CONSTANTS ... TYPE string "
  "VALUE '' would not compile, so SAP kept running an older build and every "
  "fix looked like it had not been applied. That is fixed in git. Re-test the "
  "CX_SY_CONVERSION_NO_NUMBER post failure only after the class is activated; "
  "it may well go with it."),
 ("D005","Amend - Name Change","DOK","CJSMIG-698","Backlog","Hasan Fraz",
  "Three lines, all of them shared with D003/D006/D016 - the Arabic start "
  "button, the attachment asterisk and the Customer Action redirect."),
 ("D022","Pursuing of Study Certificate","DOK","CJSMIG-699","SIT","Hasan Fraz",
  "Two closed by the developer. The payment step is the blocker and needs a "
  "trace run: PREPARE_PAYMENT( ) now names its own exit (NOCASE / NOSCREEN / "
  "NOURL) under &trace=x, which is what separates a missing case from a "
  "missing gateway address."),
 ("E019","Transport of Used Oil","EPDA","CJSMIG-700","SIT","anand babu",
  "The longest ticket in the round, and almost all of it is config. Same root "
  "cause as E021: ZCL_EPDA_E019_TRANS_USED_LOGIC has no ON_INIT, so no "
  "applicant details are seeded at all."),
 ("E020","Batteries / Scrap Handling","EPDA","CJSMIG-701","SIT","Hasan Fraz",
  "Config-heavy. 'Vehicle details not saving in backend' is worth reading as a "
  "column-order fault first: a backend table's cells are positional at both "
  "ends and the order comes from LIST_SEQUENCE in /QNV/SB_UI_DEFIN, not from "
  "the CJS spec."),
 ("E023","Dewatering Approval","EPDA","CJSMIG-702","SIT","anand babu",
  "One line: 'CJS service Not found'. The handler class exists and is complete, "
  "so this is the journey row or the launch link, not the code."),
 ("E025","Beekeeping Activity","EPDA","CJSMIG-703","SIT","anand babu",
  "The applicant BP fault is fixed. It was a one-word defect: the class called "
  "the applicant field 'OWNER_BP', which on this journey is the owner SEARCH "
  "BOX - so ON_INIT typed the applicant's partner number into the search field "
  "and blanked it again sixteen lines later."),
 ("E026","Tree Removal / Relocation / Pruning","EPDA","CJSMIG-704","SIT","anand babu",
  "Same applicant-BP family as E025 and fixed the same way, additively. The "
  "four remaining lines are config and are shared with E025."),
]

# ticket, seq, journey, observation, state, action
OBS = [
# ---------------- CJSMIG-683  E021 --------------------------------------
("CJSMIG-683",1,"E021","Initial page loads with error messages","check",
 "The screenshot is already on the ticket, but Jira is not reachable from where this register is built - paste the error text here. Most likely the required-field messages firing before the citizen has typed anything, which is a rule/required config question, not the engine."),
("CJSMIG-683",2,"E021","Applicant details not aligned - should be row wise","config",
 "Studio > Design tab. Place the applicant fields on one row of the 12-column grid (ZRAK_CJ_LAY)."),
("CJSMIG-683",3,"E021","EPDA permit no & applicant type data missing","check",
 "The handler has no ON_INIT, so nothing seeds these. Confirm the field names in ZRAK_T_JNY_FLD and an ON_INIT can be written in an hour."),
("CJSMIG-683",4,"E021","Permit / EID / trade licence order wrong, no search button","config",
 "Field order in the Design tab; the search button appears when the field's FTYPE is SEARCH."),
("CJSMIG-683",5,"E021","Company details field order not correct","config","Design tab."),
("CJSMIG-683",6,"E021","Company name EN/AR not filled from the permit number","backend",
 "The permit read has to return the company name. Backend/BAdI."),
("CJSMIG-683",7,"E021","Grid: all row fields mandatory, drop the delete1 column","config",
 "REQUIRED per field, and remove the column from the grid spec in ZRAK_T_JNY_FLD-DEFAULT_VAL."),
("CJSMIG-683",8,"E021","Units and No. of Months should be dropdowns","config",
 "Add the values to ZRAK_T_JNY_OPT and set CLOSED_LIST = X."),
("CJSMIG-683",9,"E021","Supplier company: order and mandatory indicators","config","Design tab + REQUIRED."),
("CJSMIG-683",10,"E021","Step name 'Letter from the Supplier Company' -> 'Documents'","config",
 "Already coded in ZRAK_CJ_FIXPACK, English and Arabic. Run the report for this journey."),
("CJSMIG-683",11,"E021","Mandatory attachment labels need the * indicator","config",
 "The engine draws the asterisk now - RENDER_ATTACH( ) passes the native required property. What is left is ticking REQUIRED on each upload field."),
("CJSMIG-683",12,"E021","Declaration & Notes missing","config",
 "Add a DISPLAY field whose DEFAULT_VAL is TEXT:@nnn pointing at a ZRAK_T_CJ_TXT row, so it reads in both languages."),
("CJSMIG-683",13,"E021","Feedback is mandatory","fw",
 "A 'Not now' button now sits beside Send feedback and the journey finishes without it. ZCL_RAK_JOURNEY_RENDER + ZCL_RAK_JOURNEY_ENGINE (FBSKIP)."),
("CJSMIG-683",14,"E021","Case created (1959717) but attachments not saved","check",
 "Instrumented: ZCL_RAK_JOURNEY_BE now counts the files it could not read, says so on screen and names them on the trace. Re-run with &trace=x and send the ATTACH line."),
("CJSMIG-683",15,"E021","Arabic - service start button not showing","portal",
 "Service card / launchpad, not CJS."),
# ---------------- CJSMIG-684  E022 --------------------------------------
("CJSMIG-684",1,"E022","Initial page loads with error messages","check",
 "The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built."),
("CJSMIG-684",2,"E022","Applicant details not aligned - should be row wise","config","Design tab."),
("CJSMIG-684",3,"E022","Applicant details are duplicated","handler",
 "The handler was writing the applicant fields twice. Fixed in ZCL_EPDA_E022_DEV_PROJ_LOGIC."),
("CJSMIG-684",4,"E022","Emirates ID search should follow the format; Browse not required","config",
 "PLACEHOLDER for the mask, REGEX for the format, FTYPE SEARCH instead of the browse control."),
("CJSMIG-684",5,"E022","Permit / EID / trade licence order; permit number not a dropdown","config","Design tab + FTYPE."),
("CJSMIG-684",6,"E022","Company details field order not correct","config","Design tab."),
("CJSMIG-684",7,"E022","Company name English & Arabic duplicated","config",
 "Two fields are bound to the same value. Hide one in ZRAK_T_JNY_FLD."),
("CJSMIG-684",8,"E022","Rename step 'Development Project' -> 'Project Details'","config","Coded in ZRAK_CJ_FIXPACK, EN + AR."),
("CJSMIG-684",9,"E022","Rename step 'Trade license' -> 'Documents'","config","Coded in ZRAK_CJ_FIXPACK, EN + AR."),
("CJSMIG-684",10,"E022","Trade licence attachment is missing","config","Add the upload field to the Documents step."),
("CJSMIG-684",11,"E022","Declaration & Note missing","config","DISPLAY field with a TEXT: default."),
("CJSMIG-684",12,"E022","Step 5 request confirmation not required","config","Coded in ZRAK_CJ_FIXPACK as STEP_OFF - reversible, sets ACTIVE blank."),
("CJSMIG-684",13,"E022","Feedback is mandatory","fw","'Not now' button - same engine fix as E021."),
("CJSMIG-684",14,"E022","Attachments are not saving","check","Re-run with &trace=x and send the ATTACH line."),
("CJSMIG-684",15,"E022","Customer action not working","portal","Landing page redirect - portal team."),
# ---------------- CJSMIG-685  D012 --------------------------------------
("CJSMIG-685",1,"D012","Attachment types should allow JPG, PNG etc","done_dev","Closed by Jyoti."),
("CJSMIG-685",2,"D012","Selected Indian school, a different school reached the case","backend","Backend data mapping - Jyoti's own answer."),
("CJSMIG-685",3,"D012","Attachments not reflected into the case","done_dev","Closed by Jyoti."),
("CJSMIG-685",4,"D012","Customer Action from landing page, Upload does nothing","portal","Framework side - Jyoti's answer."),
("CJSMIG-685",5,"D012","Cases not translated into Arabic","portal","Framework side."),
("CJSMIG-685",6,"D012","No case exists to submit in Arabic","portal","Framework side."),
("CJSMIG-685",7,"D012","Back button does not work to submit a new case","portal","Framework side."),
("CJSMIG-685",8,"D012","Applicant type field alignment","done_dev","Closed by Jyoti."),
("CJSMIG-685",9,"D012","Curriculum type field alignment","done_dev","Closed by Jyoti."),
# ---------------- CJSMIG-687  E017 --------------------------------------
("CJSMIG-687",1,"E017","Owner search should be in EID format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH. Listed in the fixpack worklist."),
("CJSMIG-687",2,"E017","Representative + owner EID search errors and will not move to the next step","check",
 "Needs one run with the exact search value. The popup validation now blocks correctly, so an error here is the search itself."),
("CJSMIG-687",3,"E017","Permit number / trade licence etc. not required on the chemical tab","config","Coded in ZRAK_CJ_FIXPACK as three HIDE rules anchored on the CHEMICALS_DETAILS grid."),
("CJSMIG-687",4,"E017","Add Chemical - all fields should be mandatory","handler",
 "All fourteen are now marked with an asterisk and enforced. Ten of the fourteen checks had been commented out. ZCL_E017_NOC_EXP_CHEM_LOGIC->VALIDATE_INPUT( )."),
("CJSMIG-687",5,"E017","Mandatory-field message shows on the main screen, not in the dialog","fw",
 "DIALOG_FORM( ) now draws pending messages inside the dialog. ZCL_RAK_JOURNEY_LOGIC."),
("CJSMIG-687",6,"E017","One field per row - should be two or more","fw",
 "Popup dialogs lay out in two columns now. The fix was FormContainers, not the columnsL property. ZCL_RAK_JOURNEY_LOGIC->DIALOG_FORM( )."),
("CJSMIG-687",7,"E017","Bill of Lading input clears its own value","check",
 "Check BOL_POP actually exists in ZRAK_T_JNY_FLD - a field name that is not on the journey accepts set_val and get_val and does nothing."),
("CJSMIG-687",8,"E017","'Use a previous declaration' field not required","config","Hide the field."),
("CJSMIG-687",9,"E017","HS code should be a guided formatted number with a watermark","config","REGEX for the format, PLACEHOLDER for the watermark."),
("CJSMIG-687",10,"E017","Modify - existing values are not showing","check","The edit path does not load the row back into the dialog. Needs a run."),
("CJSMIG-687",11,"E017","Search from History is missing","check",
 "A real gap, not a bug: the legacy control reads ChemicalHistorySet on zega_fw_fnd_srv and no CJS class calls it. Needs a decision before it can be built."),
("CJSMIG-687",12,"E017","'up to 2 MB' repeats on every attachment; mandatory indicator missing","config",
 "The asterisk is engine-side and done; the repeated size hint is per-field wording."),
("CJSMIG-687",13,"E017","Preview page should be removed","config","Coded in ZRAK_CJ_FIXPACK as STEP_OFF."),
("CJSMIG-687",14,"E017","Step 5 request confirmation not required","config","Coded in ZRAK_CJ_FIXPACK as STEP_OFF."),
("CJSMIG-687",15,"E017","Feedback is mandatory","fw","'Not now' button."),
("CJSMIG-687",16,"E017","Attachments are not saving","check","Re-run with &trace=x."),
("CJSMIG-687",17,"E017","Customer action not working","portal","Portal team."),
("CJSMIG-687",18,"E017","Chemical details missing in the backend","backend",
 "Read the grid spec against the LIST_SEQUENCE rows for that screen in /QNV/SB_UI_DEFIN - a backend table's cells are positional at both ends."),
# ---------------- CJSMIG-688  D002 --------------------------------------
("CJSMIG-688",1,"D002","Add Manager - wrong text, should be Birthday","done_dev","Closed by Hasan. Also coded in ZRAK_CJ_FIXPACK as a LABEL change on MANAGER_DOB."),
("CJSMIG-688",2,"D002","Fees Details comes back empty","done_dev","Closed by Hasan."),
("CJSMIG-688",3,"D002","Building Information should be demit","done_dev","Closed by Hasan."),
("CJSMIG-688",4,"D002","Attachment type shows DOC, should be PDF / JPG","done_dev","Closed by Hasan. Also coded in ZRAK_CJ_FIXPACK as an ATTACH_TYPE change."),
("CJSMIG-688",5,"D002","Cannot upload a PDF or a photo","done_dev","Closed by Hasan - same accept list."),
("CJSMIG-688",6,"D002","Arabic translation not complete","config","Handed to anand on the thread. ZLABEL_AR across the journey."),
("CJSMIG-688",7,"D002","Attachments not reflected to the record model","done_dev","Closed by Hasan."),
("CJSMIG-688",8,"D002","Manager empty in the application form","backend","Not answered on the thread. Record model."),
("CJSMIG-688",9,"D002","Cannot access Manager & School in the record model","backend","Handed to anand on the thread."),
("CJSMIG-688",10,"D002","Customer Action should redirect to the new CJS","portal","Portal team."),
("CJSMIG-688",11,"D002","Mandatory attachments need the *","config","Engine draws it; tick REQUIRED on each upload field."),
# ---------------- CJSMIG-689  D013 --------------------------------------
("CJSMIG-689",1,"D013","Application form - data missing","backend","Record model."),
("CJSMIG-689",2,"D013","Only one attachment reflected, the others not","done_dev",
 "Closed by Jyoti. Worth knowing why: GET_ATTACHMENT( ) de-duplicates on (objsrc, diffcrt, objsrctype, objtrgtype), so two files sharing a document type collapse into one."),
("CJSMIG-689",3,"D013","Selected school is not the school on the case","backend","Backend data mapping - Jyoti's answer."),
("CJSMIG-689",4,"D013","Customer Action upload not working","portal","Framework side - Jyoti's answer."),
("CJSMIG-689",5,"D013","Cases not translated into Arabic","portal","Framework side."),
("CJSMIG-689",6,"D013","No case exists to submit in Arabic","portal","Framework side."),
("CJSMIG-689",7,"D013","Back button does not work to submit a new case","portal","Framework side."),
("CJSMIG-689",8,"D013","Applicant type field alignment","done_dev","Closed by Jyoti."),
("CJSMIG-689",9,"D013","Remove the spaces on grades","done_dev","Closed by Jyoti."),
("CJSMIG-689",10,"D013","Beneficiary not reflected in the record model - case stuck","backend","anand to advise on the mapping - Jyoti's answer."),
# ---------------- CJSMIG-690  D014 --------------------------------------
("CJSMIG-690",1,"D014","The service does not work on the portal screen","check",
 "Check which handler class the journey row points at first - two classes claim D014."),
("CJSMIG-690",2,"D014","Application form - data missing","backend","Record model."),
("CJSMIG-690",3,"D014","Beneficiary not reflected in the record model - case stuck","backend","Same fault as D013."),
("CJSMIG-690",4,"D014","Cannot complete the case - problem with the case output","backend","Follows from the beneficiary fault."),
("CJSMIG-690",5,"D014","Selected school is not the school on the case","backend","Backend data mapping."),
("CJSMIG-690",6,"D014","Customer Action upload not working","portal","Framework side."),
("CJSMIG-690",7,"D014","Old case journey portal not working, cannot compare","portal","Portal team."),
("CJSMIG-690",8,"D014","Cases not translated into Arabic","portal","Framework side."),
("CJSMIG-690",9,"D014","No case exists to submit in Arabic","portal","Framework side."),
("CJSMIG-690",10,"D014","Back button does not work to submit a new case","portal","Framework side."),
("CJSMIG-690",11,"D014","Cannot post payment through the landing page","check",
 "Run with &trace=x: PREPARE_PAYMENT( ) names its exit - NOCASE, NOSCREEN or NOURL - which says whether the case, the screen mapping or the gateway address is missing."),
# ---------------- CJSMIG-692  D003 --------------------------------------
("CJSMIG-692",1,"D003","Owner - BP labels missing","config","Fill ZLABEL / ZLABEL_AR. In the fixpack worklist."),
("CJSMIG-692",2,"D003","Owner details missing from the application form","backend","Record model."),
("CJSMIG-692",3,"D003","Arabic version has no Start button","portal","Service card."),
("CJSMIG-692",4,"D003","Customer Action should redirect to CJS","portal","Portal team."),
("CJSMIG-692",5,"D003","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
# ---------------- CJSMIG-693  D021 --------------------------------------
("CJSMIG-693",1,"D021","Field should read Distance, not Educational stage","config","ZLABEL / ZLABEL_AR. In the fixpack worklist - the field name is not known from here."),
("CJSMIG-693",2,"D021","Table should show every educational stage and fetch the current fee","backend","The read has to return all stages with their current fee."),
("CJSMIG-693",3,"D021","Transportation fees do not reflect the distance - error, cannot submit","backend",
 "Blocker. The distance is not coming back from the system; the submit fails on it."),
("CJSMIG-693",4,"D021","Cannot complete the case on the submission screen","backend","Follows from the fee fault above."),
# ---------------- CJSMIG-694  D016 --------------------------------------
("CJSMIG-694",1,"D016","Arabic version has no Start button","portal","Service card. Reassigned to anand."),
("CJSMIG-694",2,"D016","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-694",3,"D016","Customer Action should redirect to CJS","portal","Portal team."),
# ---------------- CJSMIG-696  D006 --------------------------------------
("CJSMIG-696",1,"D006","New manager details not shown on the application form","backend","Record model."),
("CJSMIG-696",2,"D006","Arabic version has no Start button","portal","Service card."),
("CJSMIG-696",3,"D006","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-696",4,"D006","Customer Action should redirect to CJS","portal","Portal team."),
# ---------------- CJSMIG-697  E018 --------------------------------------
("CJSMIG-697",1,"E018","Owner search should be in EID format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH. In the fixpack worklist."),
("CJSMIG-697",2,"E018","Representative + owner EID search errors and will not move on","check","Re-test after the class is activated."),
("CJSMIG-697",3,"E018","Permit number / trade licence etc. not required on the chemical tab","config","Coded in ZRAK_CJ_FIXPACK as three HIDE rules."),
("CJSMIG-697",4,"E018","Add Chemical - all fields should be mandatory","handler","All fourteen marked and enforced. ZCL_E018_NOC_TRANS_CHEM_LOGIC."),
("CJSMIG-697",5,"E018","Mandatory-field message shows on the main screen, not in the dialog","fw","Engine fix - messages now draw inside the dialog."),
("CJSMIG-697",6,"E018","One field per row - should be two or more","fw","Two-column dialogs - engine fix."),
("CJSMIG-697",7,"E018","Bill of Lading input clears its own value","check","Check BOL_POP exists in ZRAK_T_JNY_FLD."),
("CJSMIG-697",8,"E018","'Use a previous declaration' field not required","config","Hide the field."),
("CJSMIG-697",9,"E018","HS code should be a guided formatted number with a watermark","config","REGEX + PLACEHOLDER."),
("CJSMIG-697",10,"E018","Backend POST failed - CX_SY_CONVERSION_NO_NUMBER, cannot go to the next step","handler",
 "The class had no active version at all - a CONSTANTS ... TYPE string VALUE '' will not compile - so SAP was running an older build of every method on this journey. Fixed in git. Pull, activate, and re-test this line first."),
# ---------------- CJSMIG-698  D005 --------------------------------------
("CJSMIG-698",1,"D005","Arabic version has no Start button","portal","Service card."),
("CJSMIG-698",2,"D005","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-698",3,"D005","Customer Action should redirect to the new CJS","portal","Portal team."),
# ---------------- CJSMIG-699  D022 --------------------------------------
("CJSMIG-699",1,"D022","Service card is missing the 'who can apply' information","portal","Service catalogue - taken by Vikram on the thread."),
("CJSMIG-699",2,"D022","Cannot search by Emirates ID; the field stays on SIS ID","done_dev","Closed by Hasan - the Emirates ID option was removed, SIS ID only."),
("CJSMIG-699",3,"D022","Academic Year / School and Terms do not match the old version","done_dev","Closed by Hasan - both removed."),
("CJSMIG-699",4,"D022","The payment step errors when paying","check",
 "Run with &trace=x. PREPARE_PAYMENT( ) reports its exit and the keys the backend answered with, which separates 'no case' from 'no gateway address'."),
("CJSMIG-699",5,"D022","Cannot complete the case at the payment step","check","Blocker - same run as above."),
# ---------------- CJSMIG-700  E019 --------------------------------------
("CJSMIG-700",1,"E019","Initial page loads with error messages","check",
 "The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built."),
("CJSMIG-700",2,"E019","Applicant details not aligned - should be row wise","config","Design tab."),
("CJSMIG-700",3,"E019","Applicant details are duplicated","config",
 "Not the same cause as E022 - this handler writes nothing. Two fields are bound to the same value; hide one."),
("CJSMIG-700",4,"E019","Emirates ID search should follow the format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH."),
("CJSMIG-700",5,"E019","Permit / EID / trade licence order; permit number not a dropdown","config","Design tab + FTYPE."),
("CJSMIG-700",6,"E019","Company details field order not correct","config","Design tab."),
("CJSMIG-700",7,"E019","Company name English & Arabic duplicated","config","Hide one of the two fields."),
("CJSMIG-700",8,"E019","'Material Text 1' should read 'Name'","config","ZLABEL / ZLABEL_AR."),
("CJSMIG-700",9,"E019","Issuing emirates should be a dropdown","config","ZRAK_T_JNY_OPT + CLOSED_LIST."),
("CJSMIG-700",10,"E019","Vehicle Code must not allow more than 2 digits","config","MAX_LEN on the field."),
("CJSMIG-700",11,"E019","Vehicle Plate must not allow more than 4 digits","config","MAX_LEN on the field."),
("CJSMIG-700",12,"E019","Remove the 'Mtable Delete 2' column","config","Drop it from the grid spec in DEFAULT_VAL."),
("CJSMIG-700",13,"E019","Units should be a dropdown","config","ZRAK_T_JNY_OPT + CLOSED_LIST."),
("CJSMIG-700",14,"E019","Address, Registered Emirate, Trade Licence should be inputs, not display","config","Change FTYPE from DISPLAY to INPUT and tick REQUIRED."),
("CJSMIG-700",15,"E019","Step name should change to Documents","config","Step title, EN + AR."),
("CJSMIG-700",16,"E019","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-700",17,"E019","Declaration & Notes missing","config","DISPLAY field with a TEXT: default."),
("CJSMIG-700",18,"E019","Feedback is mandatory","fw","'Not now' button."),
("CJSMIG-700",19,"E019","Attachments are not saving","check","Re-run with &trace=x."),
("CJSMIG-700",20,"E019","Company name not updated in the backend","backend","Backend write."),
("CJSMIG-700",21,"E019","UOM not updated in the backend","backend","Backend write."),
("CJSMIG-700",22,"E019","Customer action","portal","Portal team."),
("CJSMIG-700",23,"E019","Arabic services cannot be submitted","portal","Framework side."),
# ---------------- CJSMIG-701  E020 --------------------------------------
("CJSMIG-701",1,"E020","Initial page loads with error messages","check",
 "The screenshot is on the ticket; paste it here - Jira is not reachable from where this register is built."),
("CJSMIG-701",2,"E020","Applicant details not aligned - should be row wise","config","Design tab."),
("CJSMIG-701",3,"E020","Applicant details are duplicated","config","Two fields bound to the same value; hide one."),
("CJSMIG-701",4,"E020","Emirates ID search should follow the format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH."),
("CJSMIG-701",5,"E020","Permit / EID / trade licence order; permit number not a dropdown","config","Design tab + FTYPE."),
("CJSMIG-701",6,"E020","Rename the step 'Material Origin source' to 'Batteries/Scrap Details'","config","Step title, EN + AR."),
("CJSMIG-701",7,"E020","Fields under Material origin source must be dynamic and mandatory by dropdown value","config",
 "Show/hide belongs in ZRAK_T_JNY_RULE keyed on the dropdown, with REQUIRED on the fields it reveals."),
("CJSMIG-701",8,"E020","Vehicle code 1 digit, vehicle plate 4 digits","config","MAX_LEN on both fields."),
("CJSMIG-701",9,"E020","'Materials Det' is duplicated and should be renamed","config","Hide one, rename the other."),
("CJSMIG-701",10,"E020","Declaration & Note missing","config","DISPLAY field with a TEXT: default."),
("CJSMIG-701",11,"E020","Step 5 request confirmation not required","config","STEP_OFF - the fixpack does this for other journeys and takes one more line."),
("CJSMIG-701",12,"E020","Feedback is mandatory","fw","'Not now' button."),
("CJSMIG-701",13,"E020","Attachments are not saving","check","Re-run with &trace=x."),
("CJSMIG-701",14,"E020","Vehicle details not saving in the backend","backend",
 "Line the grid spec up against the LIST_SEQUENCE rows for that screen before treating it as a rendering fault."),
# ---------------- CJSMIG-702  E023 --------------------------------------
("CJSMIG-702",1,"E023","CJS service Not found","config",
 "The handler class exists and is complete. Check the ZRAK_T_JNY row and the launch URL's journey id - a code that does not resolve gives exactly this."),
# ---------------- CJSMIG-703  E025 --------------------------------------
("CJSMIG-703",1,"E025","Emirates ID search should follow the format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH."),
("CJSMIG-703",2,"E025","Number of Apiaries max 2 digits; Expected Production max 6","config","MAX_LEN on both fields."),
("CJSMIG-703",3,"E025","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-703",4,"E025","Declaration & Note missing","config","DISPLAY field with a TEXT: default."),
("CJSMIG-703",5,"E025","Case id is not correct - shows the wrong number","check",
 "Send the number that was shown next to the case it belongs to. On some families the journey key is not the case id, and the engine has one resolver for that - but it needs the pair to confirm."),
("CJSMIG-703",6,"E025","Applicant BP not saved in the record model, not in the backend application","handler",
 "Fixed. The class called the applicant field OWNER_BP, which is this journey's owner SEARCH BOX; ON_INIT wrote the partner there and blanked it sixteen lines later. Now goes to LOGIN_BP. ZCL_E025_BEEKEEPING_LOGIC."),
# ---------------- CJSMIG-704  E026 --------------------------------------
("CJSMIG-704",1,"E026","Emirates ID search should follow the format; Browse not required","config","PLACEHOLDER + REGEX; FTYPE SEARCH."),
("CJSMIG-704",2,"E026","Mandatory attachments need the *","config","Tick REQUIRED on each upload field."),
("CJSMIG-704",3,"E026","Declaration & Note missing","config","DISPLAY field with a TEXT: default."),
("CJSMIG-704",4,"E026","Case id is not correct - shows the wrong number","check","Same as E025 - send the pair of numbers."),
("CJSMIG-704",5,"E026","Applicant BP not saved in the record model, not in the backend application","handler",
 "The applicant partner now also goes out as LOGIN_BP, the field every other journey uses. ZCL_E026_TREE_REMOVAL_LOGIC."),
]

# Code that is in git and waiting on an abapGit Pull + activate.
PENDING_ACTIVATION = [
 ("ZCL_E025_BEEKEEPING_LOGIC","Applicant BP goes to LOGIN_BP, not to the owner search box","CJSMIG-703"),
 ("ZCL_E026_TREE_REMOVAL_LOGIC","Applicant BP also goes out as LOGIN_BP","CJSMIG-704"),
 ("ZCL_E027_VICE_CAPTAIN_LOGIC","Same applicant-BP fix, applied before it was reported","-"),
 ("ZCL_EPDA_E022_DEV_PROJ_LOGIC","Same applicant-BP fix; duplicate applicant write removed","CJSMIG-684"),
 ("ZCL_D021_MOD_SCHOOL_FEE_LOGIC","Same applicant-BP fix","CJSMIG-693"),
 ("ZCL_D014_STAFF_GOLD_VISA_LOGIC","Same applicant-BP fix","-"),
 ("ZCL_E018_NOC_TRANS_CHEM_LOGIC","Activation breaker removed - the class had no active version","CJSMIG-697"),
 ("ZCL_E017_NOC_EXP_CHEM_LOGIC","All fourteen Add Chemical fields marked and enforced","CJSMIG-687"),
 ("ZCL_RAK_JOURNEY_LOGIC","Dialogs draw their own messages and lay out in two columns","CJSMIG-687 / 697"),
 ("ZCL_RAK_JOURNEY_RENDER","'Not now' beside Send feedback; attachment labels carry the native required marker","several"),
 ("ZCL_RAK_JOURNEY_ENGINE","FBSKIP handling for the skipped feedback","several"),
 ("ZCL_RAK_JOURNEY_BE","Counts and names the attachments it could not read","several"),
 ("ZRAK_CJ_FIXPACK","Report: applies 19 of the config points mechanically, per journey","682-697"),
 ("ZRAK_CJ_BACKUP","Report: full export / import of a journey's configuration","-"),
]

# From the RAK_EGA Jira CSV export (all 19 tickets, 04-Sep-2026).
# Each SIT ticket blocks that journey's delivery ticket.
BLOCKS = {
  "CJSMIG-683": "CJSMIG-468",
  "CJSMIG-684": "CJSMIG-477",
  "CJSMIG-685": "CJSMIG-351",
  "CJSMIG-687": "CJSMIG-522",
  "CJSMIG-688": "CJSMIG-252",
  "CJSMIG-689": "CJSMIG-360",
  "CJSMIG-690": "CJSMIG-369",
  "CJSMIG-692": "CJSMIG-261",
  "CJSMIG-693": "CJSMIG-396",
  "CJSMIG-694": "CJSMIG-270",
  "CJSMIG-696": "CJSMIG-297",
  "CJSMIG-697": "CJSMIG-531",
  "CJSMIG-698": "CJSMIG-288",
  "CJSMIG-699": "CJSMIG-405",
  "CJSMIG-700": "CJSMIG-540",
  "CJSMIG-701": "CJSMIG-549",
  "CJSMIG-702": "CJSMIG-558",
  "CJSMIG-703": "CJSMIG-567",
  "CJSMIG-704": "CJSMIG-576",
}

# Screenshot filenames the tester attached. Jira is not reachable from the
# environment this register is built in, so these are named, not read.
ATTACHMENTS = {
  "CJSMIG-683": ['image-20260902-113807.png', 'image-20260902-114953.png', 'image-20260902-120122.png', 'image-20260902-122028.png', 'image-20260902-122606.png', 'image-20260902-122723.png', 'image-20260902-124215.png', 'image-20260902-124850.png'],
  "CJSMIG-684": ['image-20260903-064001.png', 'image-20260903-064227.png', 'image-20260903-064350.png', 'image-20260903-064549.png', 'image-20260903-064940.png', 'image-20260903-065249.png', 'image-20260903-065637.png', 'image-20260903-065812.png'],
  "CJSMIG-685": ['image-20260903-064402.png', 'image-20260903-064441.png', 'image-20260903-064506.png', 'image-20260903-064539.png', 'image-20260903-064621.png', 'image-20260903-064649.png', 'image-20260903-070527.png', 'image-20260903-070958.png'],
  "CJSMIG-687": ['0df49494-9dd8-44c5-bbd4-199a05be8211.png', 'image-20260903-073034.png', 'image-20260903-074113.png', 'image-20260903-084439.png', 'image-20260903-084817.png', 'image-20260903-085047.png', 'image-20260903-090205.png'],
  "CJSMIG-688": ['Issue 1 -20260903-065219.png', 'Issue 2-20260903-065513.png', 'Issue 3 -20260903-070016.png', 'Issue 6-20260903-071134.png', 'Issue 8 -20260903-073609.png', 'Issue 9-20260903-074144.png', 'issue 4-20260903-070148.png', 'issue 7 -20260903-073323.png'],
  "CJSMIG-689": ['image-20260903-084323.png', 'image-20260903-084348.png', 'image-20260903-084418.png', 'image-20260903-084444.png', 'image-20260903-084513.png', 'image-20260903-084618.png', 'image-20260903-084643.png', 'image-20260903-084703.png'],
  "CJSMIG-690": ['image-20260903-102424.png', 'image-20260903-102446.png', 'image-20260903-102507.png', 'image-20260903-102551.png', 'image-20260903-102646.png', 'image-20260903-102732.png'],
  "CJSMIG-692": ['Issue 1 -20260903-103115.png', 'Issue 2-20260903-105745.png', 'Issue 3-20260903-103708.png'],
  "CJSMIG-693": ['image-20260903-111346.png', 'image-20260903-111422.png', 'image-20260903-111506.png', 'image-20260903-111514.png'],
  "CJSMIG-694": ['Issue 1-20260903-103708.png', 'image-20260904-080309.png'],
  "CJSMIG-696": ['Issue 1-20260903-103708.png', 'image-20260904-075823.png', 'issue1-20260903-121242.png'],
  "CJSMIG-697": ['0df49494-9dd8-44c5-bbd4-199a05be8211.png', 'image-20260903-073034.png', 'image-20260903-130651.png', 'image-20260903-131011.png', 'image-20260903-131532.png'],
  "CJSMIG-698": ['Issue 1-20260903-103708.png', 'image-20260904-074828.png'],
  "CJSMIG-699": ['image-20260904-054737.png', 'image-20260904-054749.png', 'image-20260904-054818.png', 'image-20260904-054855.png', 'image-20260904-054923.png', 'image-20260904-055001.png'],
  "CJSMIG-700": ['image-20260903-064940.png', 'image-20260904-055423.png', 'image-20260904-071342.png', 'image-20260904-071842.png', 'image-20260904-072118.png', 'image-20260904-072355.png', 'image-20260904-072630.png'],
  "CJSMIG-701": ['image-20260903-065249.png', 'image-20260904-074855.png', 'image-20260904-075149.png', 'image-20260904-075208.png', 'image-20260904-075228.png', 'image-20260904-075427.png', 'image-20260904-075845.png', 'image-20260904-080013.png'],
  "CJSMIG-702": [],
  "CJSMIG-703": ['image-20260904-104239.png', 'image-20260904-104517.png', 'image-20260904-104935.png', 'image-20260904-113134.png'],
  "CJSMIG-704": ['image-20260904-104239.png', 'image-20260904-104935.png', 'image-20260904-113134.png'],
}

# The journey's own handler class - the one a developer edits for that service.
HANDLER = {
 "E021": "ZCL_EPDA_E021_ALTER_FUEL_LOGIC",
 "E022": "ZCL_EPDA_E022_DEV_PROJ_LOGIC",
 "D012": "ZCL_D012_SCHOOL_TRIP_ACT_LOGIC",
 "E017": "ZCL_E017_NOC_EXP_CHEM_LOGIC",
 "D002": "ZCL_D002_SCHOOL_LIC_NEW_LOGIC",
 "D013": "ZCL_D013_STAFF_APP_LET_LOGIC",
 "D014": "ZCL_D014_STAFF_EXP_CERT_LOGIC (and ZCL_D014_STAFF_GOLD_VISA_LOGIC - two classes claim D014)",
 "D003": "ZCL_D003_SCHOOL_LIC_RNEW_LOGIC",
 "D021": "ZCL_D021_MOD_SCHOOL_FEE_LOGIC",
 "D016": "ZCL_D016_SCHOOL_LIC_CANC_LOGIC",
 "D006": "ZCL_D006_SCHOOL_MNG_CHG_LOGIC",
 "E018": "ZCL_E018_NOC_TRANS_CHEM_LOGIC",
 "D005": "ZCL_D005_SCHOOL_NAME_CHG_LOGIC",
 "D022": "ZCL_D022_STUD_STUDY_CERT_LOGIC",
 "E019": "ZCL_EPDA_E019_TRANS_USED_LOGIC",
 "E020": "ZCL_EPDA_E020_BATT_SCRAP_LOGIC",
 "E023": "ZCL_E023_DEWATERING_LOGIC",
 "E025": "ZCL_E025_BEEKEEPING_LOGIC",
 "E026": "ZCL_E026_TREE_REMOVAL_LOGIC",
}

# Framework objects we changed and pushed. These are engine classes, shared by
# every journey - not any one developer's to own.
FRAMEWORK = [
 ("ZCL_RAK_JOURNEY_LOGIC",
  "Popup dialogs draw their own messages instead of putting them behind the modal, "
  "and lay out in two columns (FormContainers, not the columnsL property)."),
 ("ZCL_RAK_JOURNEY_RENDER",
  "A 'Not now' button beside Send feedback, so feedback is no longer compulsory; "
  "attachment labels carry the native required property, so the * actually draws."),
 ("ZCL_RAK_JOURNEY_ENGINE",
  "FBSKIP handling behind the 'Not now' button."),
 ("ZCL_RAK_JOURNEY_BE",
  "Counts the attachments it could not read, says so on screen and names them on "
  "the trace - so 'attachments not saving' can be diagnosed in one run."),
 ("ZIF_RAK_JOURNEY",
  "MSGS( ) so a dialog can read the pending messages."),
 ("ZRAK_CJ_FIXPACK",
  "Report. Applies 19 of the config points mechanically, per journey, idempotent."),
 ("ZRAK_CJ_BACKUP",
  "Report. Full export and import of one journey's configuration - the fallback "
  "before anyone edits config in anger."),
]
