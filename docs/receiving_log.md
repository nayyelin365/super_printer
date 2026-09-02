# Receiving Log — feature doc

Read this before touching `lib/features/receiving_log/`. The spec came as
a numbered written list plus reference screenshots; a few UI elements
visible in the screenshots (invoice file upload) were deliberately not
built because they weren't in the written spec — see "Known gaps" below.

## Mental model

An **invoice** (`ReceivingInvoice`) is the parent record — a supplier
delivery, identified by a user-typed `invoiceNo` (not auto-generated).
Each invoice holds one or more **items** (`ReceivingItem`), stored in that
invoice's own `items` Firestore subcollection. An invoice must exist
before an item can be added to it — there's no "add an item on its own."

Each item moves through a one-way status flow:

```
inStock ──▶ finished
   └──────▶ discarded
```

Once an item leaves `inStock`, it's read-only — no more action icons show
on its row.

## Where things live

| Concern | File |
|---|---|
| Domain models (`ReceivingInvoice`, `ReceivingItem`, `ReceivingItemStatus`) | `lib/features/receiving_log/domain/` |
| Firestore CRUD | `lib/features/receiving_log/data/receiving_invoice_repository.dart` |
| Excel export | `lib/features/receiving_log/data/receiving_log_excel.dart` |
| Providers + business logic | `lib/features/receiving_log/presentation/receiving_log_controller.dart` |
| Invoice list + nested item rows | `lib/features/receiving_log/presentation/receiving_log_list_screen.dart` |
| "Add Receiving Log" (create invoice) | `lib/features/receiving_log/presentation/add_receiving_invoice_screen.dart` |
| "Add Receiving Item" (create item + print) | `lib/features/receiving_log/presentation/add_receiving_item_screen.dart` |

Routes (under the app's `ShellRoute`, sidebar icon =
`Icons.local_shipping_outlined`, tooltip "Receiving Log & Instock"):

- `/receiving-log` — the list (entry point, also linked from the sidebar)
- `/receiving-log/new` — create an invoice
- `/receiving-log/invoice/:invoiceId/new-item` — add an item to that invoice

## Data shape: subcollection + collectionGroup, not a flat collection

Items live at `receiving_invoices/{invoiceId}/items/{itemId}`, **not** in
a flat top-level `receiving_items` collection. The list screen needs to
show every invoice's items at once, so rather than opening one Firestore
listener per invoice (which would mean N listeners for N invoices, and
listeners that come and go as invoices are added), it uses a single
`collectionGroup('items')` query
(`ReceivingInvoiceRepository.watchAllItems`) that watches every item
across every invoice in one stream, then groups them back by `invoiceId`
client-side in `receivingInvoicesWithItemsProvider`
(`receiving_log_controller.dart`). If you need to touch how items are
fetched, keep this shape — don't switch to per-invoice listeners, and
don't flatten items into a top-level collection (that would lose the
"invoice is the parent record" structure the spec asked for).

**Firestore rules gotcha, already hit once**: a nested `match` rule under
`receiving_invoices` is not enough to authorize the `collectionGroup`
query — Firestore requires a separate rule written with the recursive
`{path=**}` wildcard for collection-group access specifically. Both rules
need to be present; see `firestore_rules_reference/firestore.rules` and
the matching note in `CLAUDE.md`. If this ever regresses, the symptom is
`PERMISSION_DENIED` specifically on the `collectionGroup(items)` listen,
while direct invoice reads keep working — easy to misdiagnose as an
invoice-level rules problem when it's actually the items rule.

## Batch codes

Auto-generated per item, format `<initials>-#####` (e.g. `SF-00001` for
"Salmon Fillet") — same atomic-counter-per-prefix pattern as every other
auto-generated id in this app (`_nextBatchCode` in
`receiving_invoice_repository.dart`, counter collection
`receiving_item_counters`). The counter is keyed by the item's initials,
not global, so different item names get independent, tightly-packed
sequences rather than one shared counter with gaps.

## Reused, not rebuilt

Per the spec's explicit "reuse existing components/models/printing"
instruction:

- **Item Name** is picked from the existing Food catalog
  (`foodCatalogProvider`) — no separate item-management list.
- **Storage Location** is picked from the existing Log Sheet location list
  (`logLocationsProvider`, the same "Walk-in Cooler" etc. dropdown the Log
  Sheet and Sushi Rice features already use) — not a free-text field, and
  not a new location system.
- **Who created this** uses the same `StaffNamePicker`/`employees`
  roster the Sushi Rice SOP introduced (`lib/features/staff/`) — not a
  third "who did this" mechanism.
- **"Save & Print"** reuses the *existing* Food Rotation label template
  and the *existing* `LabelPrintController` (the same one the interactive
  print screen drives) — `startNewLabel(LabelTemplateCatalog.foodRotation,
  foodName: ...)` + field updates + `.print()`. This is deliberately
  different from the Sushi Rice SOP's labels, which render their own
  standalone bitmap: Receiving Log's fields (name, prep date, use-by,
  employee) already fit the existing Food Rotation template exactly, so
  there was no reason to duplicate it. A printer failure doesn't block
  saving the item — same "don't let a hardware problem lose data" pattern
  as everywhere else this app prints programmatically.
- **Export** mirrors the Log Sheet's `shareLogSheetExcel` — in-memory
  `.xlsx` via `share_plus`'s modern `ShareParams` API, no temp file.
- **Network-error handling** uses the shared
  `lib/shared/utils/network_error.dart` helper, same as every other
  Firestore-writing screen in the app.

## Known gaps / things intentionally not built

- **Invoice file upload** ("Upload Invoice" — PDF/JPG/PNG — shown in the
  reference screenshot) was **not** built. It's not in the written
  numbered spec (only in the screenshot), and this app has no file-storage
  capability anywhere to reuse (`firebase_storage` isn't a dependency).
  Building it would mean introducing real cloud file storage as new
  infrastructure — a real scope decision, not an oversight. Ask before
  adding it, and expect to add the `firebase_storage` dependency plus
  Storage security rules (a different rules file from Firestore's).
- **The 5-card "Kitchen Operation" hub** (Receiving Log / Preparation /
  Thawing / Cooking / Cooling Procedure as one dashboard) shown in a
  reference screenshot's surrounding context was **not** built — Receiving
  Log is reachable as its own sidebar item instead. Nothing in the written
  spec asked for that bigger hub; don't build it unless asked, even if
  another screenshot shows it again.
- No per-invoice or per-item edit screen for anything beyond status
  changes (Finish/Discard) — editing supplier/invoice fields after
  creation, or an item's quantity/temperature after saving, isn't wired up
  yet.
