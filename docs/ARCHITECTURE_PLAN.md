# UcapHutang Architecture Plan

## Product scope

UcapHutang has three top-level features:

1. **Draft** — transactions produced by speech/AI that still need review.
2. **Catat** — speech capture using an explicitly selected Personal or Split Bill flow.
3. **Riwayat** — per-person net balances and immutable transaction/payment logs.

The review screen is one reusable feature. It is opened either immediately after Catat finishes processing or by selecting a Draft.

## Architectural boundaries

Use feature-first MVVM with a small domain and service layer:

```text
UcapHutang/
├── App/
│   ├── AppContainer.swift
│   └── RootTabView.swift
├── Core/
│   ├── DesignSystem/
│   ├── Extensions/
│   └── Utilities/
├── Domain/
│   ├── Models/
│   └── Repositories/
├── Services/
│   ├── AI/
│   ├── Speech/
│   └── Persistence/
└── Features/
    ├── Draft/
    ├── Capture/
    ├── Review/
    └── Ledger/
```

Rules:

- Views render state and forward user intent; they do not parse speech, run inference, calculate balances, or save records.
- ViewModels are `@MainActor`, depend on protocols, and own screen state/navigation intent.
- Domain models contain app terminology and invariants, independent of MLX, Speech, Contacts, and SwiftUI.
- Services adapt Apple/MLX APIs. Protocols allow deterministic mocks in previews and tests.
- Repository writes are the only persistence boundary. Replace the initial in-memory repository with SwiftData without changing feature ViewModels.
- Store monetary values as integer Rupiah (`Int64`), never `Double`.
- Persist one canonical `Date` for transaction time. Default to the current local date/time; deterministic transcript parsing may override explicitly mentioned components.

## Domain model

### TransactionDraft

A mutable review candidate with:

- UUID and lifecycle status (`needsReview`, `confirmed`, `discarded`)
- authoritative capture flow (`personal`, `splitBill`)
- date/time, title, total amount, optional notes
- raw transcript, optional raw model response, warnings
- participants represented as relational tuples: person, role/direction, share, optional item
- split method (`equal`, `custom`) where applicable

### LedgerEntry

An immutable confirmed event:

- `charge`: personal debt/piutang or a split-bill receivable
- `payment`: money settled outside the app
- counterparty ID/name, signed balance delta, date, title, notes, and source draft ID

Signed delta convention:

- Positive: the person owes the user (piutang).
- Negative: the user owes the person (utang).
- Payment always moves the current balance toward zero and may not cross zero in the first release.

The ledger balance is derived by summing entries; do not persist a second mutable balance total.

## Feature plans

### Draft

Files:

- `DraftListView.swift`
- `DraftListViewModel.swift`
- reusable `DraftRow.swift`

States: loading, empty, content, error. Filters: all, utang, piutang, split bill. Selecting a row routes the draft UUID to the shared Review feature. Confirmed/discarded drafts disappear from this list because the query is status-based.

### Catat

Files:

- `CaptureFlowChooserView.swift`
- `CaptureView.swift`
- `CaptureViewModel.swift`
- speech and extraction service protocols/adapters

State machine:

```text
idle -> listening -> finalizing -> processing -> review
  └────────────── failure/retry ──────────────┘
```

Requirements:

- User explicitly chooses Personal or Split Bill before recording; Qwen must never reroute the chosen mode.
- Do not auto-start recording after choosing a mode.
- Finalize Speech results (`isFinal`, with bounded timeout) before inference so trailing names are not truncated.
- Prevent re-entrant inference and duplicate drafts.
- Save a `needsReview` draft atomically before navigating to Review.
- On model/decoder failure, retain flow and raw transcript as a partial draft; do not invent missing financial data.

### Review

Files:

- `ReviewView.swift`
- `ReviewViewModel.swift`
- `ParticipantEditor.swift`
- contact picker/resolution service in a later slice

One screen handles both entry paths. Editable fields:

- transaction date and time
- title
- amount
- Personal direction: “Saya berutang” / “Dia berutang kepada saya”
- Split method: equal/custom
- one or many participants and custom shares
- optional notes

Validation:

- amount > 0; title and required people are present
- Personal supports exactly one counterparty
- Split Bill is user-paid, includes the user implicitly, and stores each `(person, item, amount)` tuple
- equal/custom allocations conserve total Rupiah exactly
- unresolved contacts are warnings, not silently fuzzy-linked

“Save Data” atomically updates the draft, marks it confirmed, and creates ledger charge entries. Delete requires confirmation. Initial AI output remains immutable diagnostic evidence even after user edits.

### Riwayat

Files:

- `LedgerListView.swift`
- `LedgerListViewModel.swift`
- `PersonLedgerDetailView.swift`
- `PaymentView.swift`

List is grouped by stable person identity, preferring a contact identifier over display name. Detail shows derived net balance and chronological charge/payment logs.

Payment flow:

1. User opens a person ledger and taps “Catat Pembayaran”.
2. UI states clearly: **Pembayaran dilakukan di luar aplikasi. UcapHutang hanya mencatat pelunasan.**
3. Enter amount, date/time, and optional notes.
4. Validate amount > 0 and amount <= absolute outstanding balance.
5. Append a `payment` ledger entry whose sign moves balance toward zero.

Do not mutate or delete the original debt entry when paid.

## Design system

Temporary tokens live under `Core/DesignSystem`:

- `AppColors`: background, surface, text, accent, debt, receivable, split, warning, destructive
- `AppSpacing`: 4/8/12/16/24/32 scale
- `AppRadius`: 10/16/24/capsule
- reusable components: primary button, filter chip, section card, amount text, empty state, status badge

Use semantic colors instead of feature-local RGB literals. Support Dynamic Type, minimum 44-point targets, Reduce Motion, VoiceOver labels, and sufficient contrast. Mid-fidelity guidance: open white layouts, large whitespace, rounded cards, filter pills, a centered microphone action, and a persistent three-tab shell.

## Delivery sequence

1. Domain models, repository protocol, in-memory adapter, design tokens, and tab shell.
2. Draft list plus shared Review vertical slice using seeded/mock data.
3. Ledger projection and external-payment logging, with balance tests.
4. Speech state machine and permissions.
5. Qwen/MLX migration following `QWEN_MIGRATION_PLAN.md`.
6. Contacts resolution with conservative matched/ambiguous/unmatched states.
7. Replace in-memory persistence with SwiftData and migration tests.
8. Accessibility, UI tests, performance measurements, and device testing.

Each production behavior follows RED–GREEN–REFACTOR. High-priority tests cover signed balances, partial/full payments, split remainder distribution, custom sum validation, strict decoder boundaries, date resolution, failure draft creation, and duplicate-processing prevention.
