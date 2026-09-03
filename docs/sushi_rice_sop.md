# Sushi Rice Preparation — SOP feature

Read this before touching anything under `lib/features/log_sheet/*sushi_rice*`
or `lib/features/staff/`. It explains the business rules (which came from the
user across many messages, not from one spec) and where each piece lives.

## Mental model

A **batch** (`SushiRiceBatch`) is one preparation run, identified by a
human-readable code like `Batch-2026-0002`. Many batches run **concurrently**
— the dashboard shows all of them, each independently timed. A batch moves
through 5 stages in order:

```
soaking → cookingRest → mixingCooling → phCheck → readyToUse
```

All 5 stages are fully built. Each of the first three is a **fixed
countdown**, not a staff-chosen duration — see "Timer stages" below. pH
Check is a pass/fail gate. Ready to Use is the 24-hour TPHC compliance
window.

## Where things live

| Concern | File |
|---|---|
| Domain model, all constants/thresholds | `lib/features/log_sheet/domain/sushi_rice_batch.dart` |
| Firestore CRUD (`sushi_rice_batches` collection) | `lib/features/log_sheet/data/sushi_rice_batch_repository.dart` |
| Label printing (2 distinct labels — see below) | `lib/features/log_sheet/data/sushi_rice_label_printer.dart` |
| Business logic / state transitions / **Alarm integration** | `lib/features/log_sheet/presentation/sushi_rice_batch_controller.dart` |
| Dashboard (5 stage cards + batch list) | `lib/features/log_sheet/presentation/sushi_rice_dashboard_screen.dart` |
| "New Preparation Rice Batch" wizard | `lib/features/log_sheet/presentation/sushi_rice_new_batch_screen.dart` |
| Per-batch detail screen (all 5 stage UIs) | `lib/features/log_sheet/presentation/sushi_rice_batch_detail_screen.dart` |
| **"Sushi Rice pH Log Sheet" HACCP report** | `lib/features/log_sheet/presentation/sushi_rice_ph_log_sheet_screen.dart` |
| Staff/employee roster (shared, not Sushi-Rice-specific) | `lib/features/staff/` |

Routes (all under the app's `ShellRoute`, sidebar icon = `Icons.soup_kitchen_outlined`):

- `/logs/sushiRice/dashboard` — entry point, also linked from the sidebar
- `/logs/sushiRice/new` — start a batch
- `/logs/sushiRice/batch/:batchId` — whatever that batch's current stage needs
- `/logs/sushiRice/report` — the HACCP log sheet (all batches, historical)

## Timer stages: fixed countdown + locked action button

This is **not** "staff picks a duration in a range." Each stage is a fixed
total countdown; its "start next step" button is disabled for the first N
minutes (the SOP's minimum), then enabled for the rest of the window. If the
button still isn't tapped when the countdown hits zero, a **real Alarm**
fires (see "Alarm integration" below) — with sound, even if the app is
backgrounded/killed, and visible in the app's own Alarms tab while pending.

| Stage | Unlock at | Total (buzzer fires) |
|---|---|---|
| Soaking | 20 min | 30 min |
| Cooking & Rest | 45 min | 50 min |
| Mixing & Cooling | 25 min | 35 min |

Constants: `sushiRiceSoakUnlockMinutes`/`sushiRiceSoakTotalMinutes`, and the
`CookRest`/`MixCool` equivalents, all in `sushi_rice_batch.dart`.

The shared countdown-card UI is `_StageCard` in
`sushi_rice_batch_detail_screen.dart` — one widget, parameterized per stage
(ring color, labels, timings), not three copies.

## Staff pickers — different modals at different transitions

Each stage transition opens a dialog to record who's doing it. **Don't
assume they're all the same** — three distinct shapes exist:

1. **Soaking → Cooking & Rest** ("Start Cooking"): title = batch code, name
   picker only, green confirm button.
2. **Cooking & Rest → Mixing & Cooling** ("Start Mixing"): title = batch
   code, **+ vinegar amount radio** (`sushiRiceVinegarAmountsOz` = 4/8/12 oz)
   above the name picker, green confirm button.
3. **Mixing & Cooling → pH Check** ("Measure pH Level"): title = **"Choose
   Your Name"** (no batch code), name picker only, plain (not green) confirm
   button labeled "CONTINUE →".

`_openNameOnlyDialog` in the detail screen covers cases 1 and 3 (same shape,
different title/button color); case 2 has its own `_openVinegarDialog`.

The name picker itself is `StaffNamePicker`
(`lib/features/staff/presentation/widgets/staff_picker.dart`) — single-select
chips + a free-text "Enter Name" field. Typing a new name adds it to the
**`employees`** Firestore collection immediately (not `staff_members` — that
name was tried and explicitly renamed). No seeded/fake names — starts empty.

## pH Check

**Critical limit: ≤ 4.2** (`sushiRicePhPassThreshold`). This number moved
twice during development (4.1 → "over 4.6" → 4.2) — 4.2 is correct because
it matches the literal "Critical Limit: ≤ 4.2" text baked into the reference
HACCP log sheet mockup, which is the authoritative source now that the
dedicated report exists. If anyone asks to change it again, get the exact
number from them, don't infer it.

- Reading ≤ 4.2 → pass → prints the **TPHC label** (see below) → stage
  becomes `readyToUse`.
- Reading > 4.2 → fail → red "outside the critical limit" message +
  **CORRECTION ACTION** button → clears the input for a retest. The retest
  reading is saved as both `phReading` (current) and `correctivePhValue`
  (audit trail), with `correctiveActionTaken = true`.
- No "discard batch" option exists at this stage in the UI — the flow always
  assumes retesting until it passes. (`finalBatchStatus` on Ready to Use is
  the only place a batch is marked Discarded/Expired.)

## Two distinct printed labels — don't merge them

Both go through `sushi_rice_label_printer.dart`, both print at "Save &
Print" moments, but they're **different labels for different purposes**:

1. `printSushiRiceBatchLabel` — prints at **batch creation** (Soaking
   start). Shows "Soak Until: <time>". This is an identification/tracking
   label, still valid even if the label prints in step 1 of the earlier
   conversation while step 4 defines the second one.
2. `printSushiRiceTphcLabel` — prints once **pH passes**. Shows the pH
   value and "Use by: <time>" + "24 hr TPHC Window". This is the compliance
   label that starts the Ready-to-Use countdown.

Both are QR-coded (batch code), both standalone renderers deliberately
*not* wired into the existing `LabelData`/`LabelTemplate` system (that
system serves the interactive print screen; these print programmatically
from app logic and would ripple into an unrelated, working feature if
merged in).

## Ready to Use / TPHC window

24-hour window (`sushiRiceReadyToUseWindowHours`) starting when the TPHC
label prints. Compliance alerts fire at hours 20/21/22/23/24
(`sushiRiceTphcAlertHours`), one real Alarm each — see "Alarm integration"
below for why these are Alarms, not a bespoke notification.

**Finish Batch** opens a dialog to record `finalBatchStatus`
(`sushiRiceFinalStatuses` = Used/Discarded/Expired) + staff, before
actually closing the batch out (and cancelling any alarms still pending).

## Alarm integration — every buzzer is a real Alarm, not a separate channel

**This reverses an earlier design decision** (a bespoke
`sushi_rice_notifications.dart` notification channel, since deleted) — the
user explicitly asked for every automatic SOP alert to show up in, and
fire through, the app's existing Alarm feature (`lib/features/alarm/`,
the Alarms tab). If you're reading old context that mentions a separate
Sushi Rice notification channel, that's stale; it no longer exists.

How it works — all in `SushiRiceBatchController`:

- `_scheduleAlarm({at, title})` calls the real
  `AlarmController.addAlarm(hour:, minute:, title:, repeatSound: true)` —
  the exact same method the Alarm editor screen uses — and returns the
  created alarm's id.
- `_cancelAlarm(alarmId)` calls `AlarmController.deleteAlarm`.
- `SushiRiceBatch.currentStageAlarmId` holds the one pending "... Time's
  Up!" alarm for whichever of Soaking/Cooking & Rest/Mixing & Cooling is
  active — cancelled and replaced on every stage transition
  (`startCooking`, `startMixing`, `startPhCheck`).
- `SushiRiceBatch.tphcAlarmIds` holds all five TPHC hour-mark alarm ids,
  created together in `_printTphcLabelAndStartReadyToUse` right after the
  compliance label prints. `acknowledgeHour` cancels that specific hour's
  alarm (in addition to recording `lastAcknowledgedHour`); `setFinalBatchStatus`
  cancels whatever's left (current-stage alarm plus any un-acknowledged
  TPHC alarms) so Finish Batch never leaves an orphaned alarm ringing.
- `AlarmController.ensurePermissions()` is called once, at `startBatch` —
  same permission check the Alarm editor does before its first
  `addAlarm`. If denied, `SushiRiceStartResult.alarmPermissionGranted`
  carries that back so the new-batch screen can warn ("...may not go
  off...", same wording as the Alarm editor), rather than silently
  scheduling something that won't fire. Not re-checked on later stage
  transitions — permission granted once stays granted for the session.

**Known simplification for TPHC**: the spec says the compliance buzzer
should re-alert every 5 minutes until acknowledged. Real per-5-minute
re-triggering isn't something this app's notification layer can do
without native platform code (same documented limitation as the plain
Alarm feature's own "repeat sound" — see `alarm.dart`'s doc comment on
`repeatSound`); each TPHC hour mark is one Alarm with `repeatSound: true`,
which keeps it pinned/re-alerting until Dismissed rather than literally
re-firing on a 5-minute cadence. This is the same honest trade-off the
Alarm feature itself already made and documented — don't try to build a
truer 5-minute loop without checking with the user first, since it would
mean native code beyond what's been scoped so far.

## The HACCP report ("Sushi Rice pH Log Sheet")

This is the real compliance record — **not** the generic Log Sheet table.
It replaced an earlier "just reuse the generic LogEntry table" approach once
the user showed the actual required format: a transposed table (one column
per batch, field labels down the left) with blue section banners (Stage
1–4 + Corrective Action), sourced directly from `SushiRiceBatch` fields.

Since this report exists, **Sushi Rice pH results are no longer written to
the generic `LogEntry`/`logs` Firestore collection at all** — that would
have meant force-fitting a pH value into a `targetTemp`/`actualTemp` pair
formatted as °F, which is exactly the kind of awkward duplication the
dedicated report was built to avoid. If you're asked to "also show it in
the regular Log Sheet," that's a real, deliberate scope question to ask
about, not an oversight to silently fix.

One known gap: **"pH Meter Name & Calibrated Date"** is a column in the
report but has no UI to enter it anywhere in the flow — the reference
mockup itself shows it blank. Left blank until asked for.

## Firestore collections (need security rules — none deployed, no console
access from this environment)

```
sushi_rice_batches/{batchId}           — one batch, see toMap()/fromMap()
sushi_rice_batch_counters/{year}       — atomic per-year batch-code counter
employees/{employeeId}                 — staff roster (name only)
```

Suggested open rules for local testing (tighten once there's real auth):

```
match /sushi_rice_batches/{batchId} { allow read, write: if true; }
match /sushi_rice_batch_counters/{year} { allow read, write: if true; }
match /employees/{employeeId} { allow read, write: if true; }
```

## Known gaps / things intentionally not built

- **QR scanning**: labels are QR-coded (`printSushiRiceQrLabel`'s QR
  drawing via the `barcode` package's `Barcode.qrCode()`), but there's no
  in-app camera scanner — "Scan QR on Label" on the dashboard shows a
  "not available yet" message. Explicit user decision, not an oversight.
- **pH meter name/calibration tracking** — see above.
- **Receiving Log** (`lib/features/receiving_log/`) is a separate feature,
  not part of this SOP — it was lost in the file-loss incident below and
  has since been rebuilt (see `CLAUDE.md` for its own notes). Don't
  confuse the two when reading old context that predates the rebuild.
- Unused SVG assets still sitting in `assets/images/` as of this writing
  that hint at *planned but unbuilt* work: `thawing.svg`, `preparation.svg`,
  `cooking.svg`. If asked to build a Thawing Log or a Cooking/Preparation
  hub, these are probably meant for those.

## The file-loss incident (context, not a mystery to re-solve)

Mid-project, a large amount of already-built code (a full multi-batch
Sushi Rice implementation, the Receiving Log feature, staff roster,
several shared-widget edits) disappeared from disk between one turn and
the next — files reverted to an earlier git state or wiped to empty
directories, cause unknown (not a git operation performed by the assistant;
possibly an editor/IDE action on the user's end). It was rebuilt from
scratch afterward, twice, incorporating corrections the user gave along
the way (which is *why* some of the current design choices — fixed-window
timers instead of chosen durations, the 4.2 pH threshold, the dedicated
HACCP report — look like second/third drafts: they are). If large chunks
of expected code are missing again, check `git status`/`git log` and flag
it to the user rather than silently assuming it was never built.

## General conventions this feature follows (already established
elsewhere in the app — don't reinvent)

- Riverpod layering: UI → Controller → Repository → Firestore. Firestore
  operations never happen directly in widgets.
- Firestore queries avoid composite indexes: filter by one field, sort
  client-side (see `watchActive`/`watchAll` in the repository).
- IDs that need to be human-readable use an atomic per-period Firestore
  counter (`_nextBatchCode`), same pattern as the Log Sheet's own
  `Logs-MMDDYYYY####` scheme.
- No bespoke notification ids of its own anymore — every alert is a real
  `Alarm` (see "Alarm integration" above), so alarm-id generation/storage
  is entirely the Alarm feature's own concern (`stableAlarmBaseId`); this
  feature just stores the resulting alarm ids on the batch to cancel them
  later.
- Network errors surface as "Network error. Please check your internet
  connection." via `lib/shared/utils/network_error.dart`
  (`hasNetworkConnection`, `networkAwareErrorMessage`) — used everywhere
  this feature touches Firestore. Reuse it rather than writing new
  ad-hoc error text.
