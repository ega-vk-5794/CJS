# M016 — Change Building Regulations, as the legacy service actually runs

Walked end to end on the live portal as `HISHAM.M` / partner `3000401630`,
September 2026. Screens captured, not inferred. Where this contradicts what the
migrator produces, the live service is right and the note says what to change.

The legacy screen family is `NCBR_1_*`; `JOURNEYTYPE` resolves it to **M016**.
(`ZRAK_M_MUNI_LOAD`'s header already flags that M016's title says "Building
Regulations/Change of Land Use" while the code resolves to CBR alone — CLU is
M015, a service not on the list. The walkthrough below is CBR.)

## Three steps, and the last one is Pay

```
1  Parcel Selection      2  Documents      3  Fees & Payment
```

That is the whole wizard. There is **no Confirmation step and no Review step**:
the footer on step 3 reads `Back` / **`Pay`**, and the confirmation page appears
after the payment returns, outside the wizard.

Two consequences for the migrator, both already acted on:

- the legacy confirmation screen must not become a step — `IS_CONFIRMATION( )`
  drops it now
- CJS appends its own **Review and submit** step, so a migrated M016 has four
  steps where the citizen has three. That is a deliberate CJS difference, not a
  defect, but it is a difference — and on a fee-bearing journey the citizen
  reaches Review *after* paying, which reads oddly. Worth deciding per journey
  whether the Review step is appended at all when the last step is a payment.

Step titles come from the legacy **STAGES** list (`Parcel Selection`,
`Documents`, `Fees & Payment`), which lives in the BAdI's `READ` as
`additionaldata3` and is **not** in `/QNV/SB_UI_DEFIN`. The migrator derives
titles from screen content instead and cannot reach these.

## Step 1 — Parcel Selection

Heading `Parcel Selection`, sub-line `Please select a property from the list`.

Toolbar, left to right: a two-segment button `Owned` / `Property Agent`, a
separate pill `★ Favorites`, then (only on Property Agent) a `- Select Owner -`
dropdown, then `Search` on the right. **No Grants segment** — grants is a
category the journey is launched in, not a tab the citizen picks.

Then `3 Properties found`, the cards, and a footer line:
`Can't Find a Parcel? You can review the list of your properties on your Home Page`.

### The card

```
┌─────────────────────────────────────────────────────────┐
│ 507060119                                     [ Legacy ] │
│ SUHAILAH/سهيلة │ Residential - Private │ Parcel          │
│                                            ⊞ Full Details │
└─────────────────────────────────────────────────────────┘
```

- red left border, one card per property
- **the parcel number is shown WITHOUT its leading zeros** — `507060119`, where
  `PropertiesSet` returns `00000000000507060119`. Display only; what the control
  *stores* could not be read off the screen, and it matters: a draft written by
  ShapeIt and one written by CJS have to hold the same value. **Open.**
- a badge top right per parcel — `Legacy`, `Waiver`, `Purchase` seen on the
  three test parcels. An acquisition/ownership type; the component name is not
  yet confirmed against `TS_PROPERTIES`.
- one meta line, pipe-separated: area name (EN/AR together) │ land use │ type
- `Full Details` bottom right, opening the seven-tab dialog documented in
  [`../controls/shapeit-reads.md`](../controls/shapeit-reads.md)

### Property Agent

Switching to `Property Agent` shows `0 Properties found` and `No data` until an
owner is chosen from `- Select Owner -`. The dropdown lists the companies this
citizen acts for, by Arabic name. So the empty state is the *correct* state, not
a failed read — which is why `ZCL_RAK_CJ_PARCEL` answers nothing rather than
falling back to the citizen's own property when no owner is picked.

## Step 2 — Documents

| Field | Control | Required |
| --- | --- | --- |
| `Change Building Regulations Details` | textarea, placeholder "Please enter more details about the Parcel Building Regulation request" | yes |
| `Upload a File to describe your text above` | file, "Select a file" + paperclip | no |
| `Letter of consent` | file | yes |
| `Usage type` | select, "Select" | yes |

Required is marked with a red asterisk on the label — the native `required`
property, which is what CJS uses too.

## Step 3 — Fees & Payment

```
Initial Fee
Change land use & building regulations for Grant plot        ৳ 500.00
To see the estimated remaining fees  [Click here]     Total: ৳ 500.00
```

- **Payment Method**, four radio options: `RAK.ae / quick payment`, `mRak`,
  `KISOK machine` (the portal's own spelling), `Walk-in`
- a red hint under them: `Please allow browser pop-ups to enable payment`
- **Pay with**, a card-brand strip: Visa / Mastercard / Amex / Discover
- a charges block:
  - Cards Visa/MasterCard on RAK Government portal: 1.00%
  - RAK Wallet: 0.80% with CAP 1000 AED
  - The above bank charges are subject to VAT 5%
- two checkboxes: `I / We acknowledge and accept the Terms & Conditions
  applicable and available on the site` (required) and `I would like to donate
  five dirhams to Ajer Charity Foundation` (optional)
- footer: `Back` / **`Pay`**

Choosing `mRak` replaces the card strip with an **Account Details** panel
carrying `Number` and `Case Number` (e.g. `3000332011`), the line
`Please Make the Payment via mRak App`, and an `Email me the details`
checkbox — and the footer button becomes `Next` rather than `Pay`.

### A live defect, captured

Re-entering the payment step after a payment was started raises
`Error — Payment is in progress against Payment ID`, modal, with only `OK`.
The step is then stuck: the citizen can neither pay again nor move on. Recorded
because a CJS rebuild must decide what to do in that state rather than inherit
it — the PAID gate in `ZCL_RAK_JOURNEY_LOGIC` refuses submit while
`PAYFEE <> 'PAID'`, which is the same corner from the other side.

## What M016 needs that CJS does not yet have

1. `PAYFEE` on the payment step — the migrator drops `RAKPAY`, so twelve of the
   fifteen Municipality journeys currently have no pay control at all.
2. The fee lines themselves: `Initial Fee` is one `FeesSet` read, and the
   "estimated remaining fees" link is a second one. `ZCL_RAK_FEES_API->FEES( )`
   serves the first; the second is not identified yet.
3. The payment-method radio group, the charges text and the two checkboxes are
   plain config — options and a `TEXT:` default — not code.
