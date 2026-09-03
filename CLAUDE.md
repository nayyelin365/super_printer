# super_printer

Flutter app for a kitchen/restaurant: Zebra thermal label printing, plus a
growing set of kitchen-operations features (Alarms, Log Sheet, Sushi Rice
Preparation SOP, Receiving Log). Riverpod throughout; `go_router` with one
persistent sidebar `ShellRoute`; Firebase project `smart-printer-aac97`
(Firestore + `firebase_core`, no auth system — see below).

## Before touching a specific feature, read its doc

- **Sushi Rice Preparation SOP** (multi-stage batch workflow, timers,
  labels, HACCP report): **read `docs/sushi_rice_sop.md` first.** It has
  business rules that came from many back-and-forth corrections — the
  pH threshold, the fixed-vs-chosen timer durations, which of two printed
  labels is which, etc. — that are easy to get wrong by guessing from the
  code alone.
- **Receiving Log** (invoices → items, status flow, printing/export):
  **read `docs/receiving_log.md` first.** Covers the subcollection +
  `collectionGroup` data shape, what's reused vs. new, and what was
  deliberately left out (invoice file upload, the bigger "Kitchen
  Operation" hub) so it isn't rebuilt from a screenshot alone.

## Firestore rules quirk: `collectionGroup` needs the `{path=**}` form

If a repository ever queries a subcollection across all its parents via
`.collectionGroup('name')` (as `ReceivingInvoiceRepository.watchAllItems`
does for `items`), a nested `match` rule under the parent
(`match /parent/{id} { match /name/{id} {...} }`) is **not** enough —
Firestore only authorizes a collection-group read against a rule written
with the recursive wildcard: `match /{path=**}/name/{id} { allow read,
write: if true; }`. Keep both: the nested one documents intent for direct
subcollection access, the wildcard one is what actually makes the
collection-group query work. Forgetting the wildcard form produces a
`PERMISSION_DENIED` on the group query specifically, while direct
subcollection reads/writes keep working fine — easy to miss until the
list/aggregate view is tested. See `firestore_rules_reference/firestore.rules`
for the deployed shape.

## Architecture conventions (apply across the whole app, not just one
feature)

- **Layering**: UI → Controller (Riverpod) → Repository → Firestore/
  SharedPreferences. Firestore calls never happen directly in widgets.
- **Firestore query design**: this environment has no console/CLI access
  to deploy indexes. Every repository avoids composite
  `where(equality) + orderBy(different field)` queries — filter by one
  field (auto-indexed) and sort client-side instead. Keep doing this for
  any new Firestore-backed feature.
- **Human-readable sequential IDs** (e.g. `Logs-MMDDYYYY0001`,
  `Batch-2026-0002`): generated via an atomic Firestore transaction
  against a small counter document, never a client-side guess — see
  `LogRepository._nextLogId` / `SushiRiceBatchRepository._nextBatchCode`
  for the pattern to copy.
- **No login/employee-auth system.** "Who did this" is captured via
  lightweight, purpose-built mechanisms: `LogPreferences` (remembers the
  last-typed initials locally) for the plain Log Sheet, and a real shared
  Firestore-backed roster (`lib/features/staff/`, collection `employees`)
  for the Sushi Rice SOP. Don't invent a third pattern — extend one of
  these two if a new feature needs "who did this."
- **Network-error handling**: use `lib/shared/utils/network_error.dart`
  (`hasNetworkConnection`, `networkAwareErrorMessage`) around any
  Firestore write reachable from a button — surfaces "Network error.
  Please check your internet connection." instead of a raw exception or
  a silent hang.
- **Printing**: the interactive print screen (`lib/features/label_printing/`)
  drives real Zebra printers over Bluetooth/USB via `LabelPrinter`/
  `LabelTemplateRenderer`. Any feature that needs to print
  *programmatically* (not through that interactive screen) should render
  its own bitmap standalone (see `sushi_rice_label_printer.dart`) rather
  than forcing a new `LabelData`/`LabelTemplate` into the existing
  template system — that system serves the manual print flow and
  shouldn't grow one-off cases.
- **Notifications/alarms**: the app's one real notification channel is
  `alarm_notifications.dart`, backing the Alarm feature
  (`lib/features/alarm/`). A feature that needs a kitchen-timer-style
  alert should create a real `Alarm` via `AlarmController.addAlarm` rather
  than standing up its own notification channel — the Sushi Rice SOP does
  exactly this (see `docs/sushi_rice_sop.md`'s "Alarm integration"
  section) after an earlier version tried a separate bespoke channel and
  was told to route through the Alarms tab instead. Per-alarm OS
  notification ids are derived from a stable FNV-1a hash of the alarm's
  own id (`stableAlarmBaseId`), not a counter — a feature scheduling
  alarms programmatically doesn't need to think about notification ids at
  all, just store the returned `Alarm.id` to cancel it later.

## Known incomplete/empty areas — don't assume from directory existence
alone

- Sitting in `assets/images/`: `thawing.svg`, `preparation.svg`,
  `cooking.svg`, `receiving_log.svg` — the last one is now used by the
  Receiving Log sidebar icon; `thawing`/`preparation`/`cooking` still hint
  at unbuilt features (a Thawing Log type, a general "Preparation" and/or
  "Cooking" hub — a "Kitchen Operation" dashboard with cards for each was
  shown in a screenshot once, but never explicitly requested as its own
  build task; don't build it unless asked). If asked to build one of
  these, check whether an icon's already waiting for it.
- Directory existence has been misleading before this session (see the
  "file-loss incident" in `docs/sushi_rice_sop.md`) — verify a feature's
  files actually have content, not just that the folder exists, before
  assuming it's built.

## Firebase

Real project (`smart-printer-aac97`), `firebase_options.dart` is
FlutterFire-CLI-generated and present. **No rules have been deployed from
this environment** (no console/CLI access) — every new Firestore
collection needs its rules added manually by the user. Check each
feature's doc/summary for the exact collections it introduced.
