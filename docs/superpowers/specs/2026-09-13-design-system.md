# UcapHutang Design System

> Reference document for any agentic AI (e.g. Gemini) implementing or changing UI in this app. It records the visual language already agreed on with the product owner across earlier planning sessions (spec `2026-09-12-voice-draft-remediation-design.md`, plans P0–P7, and the merge-with-main plan). Treat every rule here as approved — do not reinterpret or "improve" it without asking the owner first.

**Platform:** iOS 26.5+, SwiftUI, Xcode 26.6, Swift 5 mode.
**Design philosophy:** Apple Human Interface Guidelines. Native components over custom reimplementations. No Android idioms (no hamburger menus, no FABs, no top tabs).
**Language:** Indonesian for all user-facing copy. "Utang" is the approved spelling — never "Hutang" — in UI text; the Catat flow title is "Utang / Piutang". Code identifiers (`TransactionType.hutang`, the app name `UcapHutang`) are unchanged since they are not user-facing wording.

---

## 1. Color tokens

All colors are defined once in `UcapHutang/Core/DesignSystem/AppDesignSystem.swift` as `enum AppColors`. Never hardcode a `Color(...)` or hex value directly in a view — add or reuse a token here.

| Token | Value | Used for |
|---|---|---|
| `AppColors.background` | `Color(.systemBackground)` | Screen backgrounds |
| `AppColors.surface` | `Color(.secondarySystemBackground)` | Cards, rows, grouped sections |
| `AppColors.textPrimary` | `Color.primary` | Primary text, primary icons |
| `AppColors.textSecondary` | `Color.secondary` | Secondary text, captions, disabled hints |
| `AppColors.accent` | `Color.blue` | Interactive tint (links, selected state, progress) |
| `AppColors.debt` | `Color.red` | "Utang" amounts, debt direction |
| `AppColors.receivable` | `Color.green` | "Piutang" amounts, receivable direction |
| `AppColors.split` | `Color.orange` | Split Bill flow accent |
| `AppColors.warning` | `Color.orange` | Non-blocking warnings, invalid-field highlight |
| `AppColors.destructive` | `Color.red` | Destructive actions, blocking errors, unlinked-contact state |
| `AppColors.border` | `Color.secondary.opacity(0.22)` | Hairline strokes on cards, chips, fields |
| `AppColors.reminderButtonBackground` | Asset `ReminderButtonBackground`: **Light `#FFF5E0`, Dark `#3A3222`** | "Ingatkan lewat Pesan" button background |

**Accepted contrast exception:** small colored labels — the "Utang"/"Piutang" direction label, balance pills, and "Wajib dihubungkan" — are allowed to fall short of the full 4.5:1 text contrast ratio because color here is reinforced by an icon or an accessibility label, not the only signal. Do not "fix" this by flattening these labels to `textPrimary`; the owner explicitly accepted the exception.

**Never convey meaning by color alone.** Every debt/receivable indicator that uses `AppColors.debt`/`.receivable` must also carry a directional SF Symbol (`arrow.up.right` / `arrow.down.left`) and a VoiceOver label ("Utang" / "Piutang"), because color-only encoding fails accessibility.

**Primary action buttons** are adaptive black/white (`.tint(.primary)` on `.borderedProminent`), not a fixed brand color — this reads correctly in both Light and Dark Mode without a custom asset. Do not reintroduce a custom `AppPrimaryButtonStyle`; it was removed in favor of native `.borderedProminent` + `.tint(.primary)`.

**Dark Mode:** every screen must be previewed in both `.light` and `.dark` `preferredColorScheme`. Never assume a white or black background — always go through `AppColors`, never `Color.white`/`Color.black`.

---

## 2. Spacing, radius, layout

`enum AppSpacing` (all `CGFloat`):

| Token | Value |
|---|---|
| `xSmall` | 4 |
| `small` | 8 |
| `medium` | 12 |
| `large` | 16 |
| `xLarge` | 24 |
| `xxLarge` | 32 |

`enum AppRadius`:

| Token | Value |
|---|---|
| `small` | 10 |
| `medium` | 16 |
| `large` | 24 |

Rules:
- Screen edge padding: `AppSpacing.xLarge` (24pt) horizontal, matching the HIG 16–24pt content margin range.
- Card/section corner radius: `AppRadius.medium` for standard cards, `AppRadius.large` for hero elements (Catat flow-chooser cards, sheets with `.presentationDetents`).
- **Every tappable control is at least 44×44pt** (`frame(minHeight: 44)` or larger) — buttons, list rows, chips, chevron-only rows, contact-card action buttons.
- Wide or many-item content (filter bars, summary card rows) must use `ViewThatFits` to lay out horizontally when there's room and stack vertically at large Dynamic Type sizes instead of clipping or forcing horizontal scrolling of primary content.
- `NavigationStack` only — never the deprecated `NavigationView`.

---

## 3. Typography

- Use semantic text styles only: `.largeTitle`, `.title`, `.title2`, `.title3`, `.headline`, `.body`, `.subheadline`, `.footnote`, `.caption`. **Never** `.font(.system(size:))` with a hardcoded number in production view code.
- Weight and color carry hierarchy more than size differences — e.g. `.body.weight(.semibold))` for emphasized inline values instead of bumping the font size.
- For a control whose diameter should scale with text size but has a natural cap (e.g. the Catat record button), use `@ScaledMetric(relativeTo:)` and clamp the result (see §6).
- Dynamic Type must be tested at the largest accessibility size on every screen: no clipped text, no overlapping controls. Multi-line text uses `.multilineTextAlignment` and `.fixedSize(horizontal: false, vertical: true)` where a fixed frame would otherwise clip it.
- Text is left-aligned, never justified.

---

## 4. Iconography

SF Symbols only, sized with `.font()`/`.imageScale()`, never custom raster icons for UI chrome.

| Symbol | Meaning |
|---|---|
| `doc.badge.clock` | Review tab |
| `mic.fill` | Catat tab, Catat record button (idle and listening), widget glyph |
| `book.closed` | Riwayat tab |
| `arrow.up.right` | Utang / debt direction |
| `arrow.down.left` | Piutang / receivable direction |
| `person.2` | Personal (Utang/Piutang) flow |
| `person.3.fill` | Split Bill flow |
| `checkmark.circle.fill` | Linked contact, completed/valid state |
| `exclamationmark.triangle.fill` | Warning, invalid state, autosave failure |
| `person.crop.circle.badge.questionmark` | Unlinked contact |
| `person.crop.circle.badge.plus` | "Buat Kontak Baru" |
| `bell.badge` | Notification primer |
| `gear` | Open Pengaturan |
| `chevron.right` | Disclosure / navigation affordance |
| `rectangle.3.group.bubble.left.fill` | Widget setup illustration |

Decorative icons that duplicate an adjacent text label are `.accessibilityHidden(true)`. Icons that are the only carrier of meaning (e.g. the debt/receivable arrow when text is color-only) get an explicit `.accessibilityLabel`.

---

## 5. Core components

Defined in `UcapHutang/Core/DesignSystem/AppDesignSystem.swift` unless noted.

- **`AppSectionCard`** — padded content block, `AppColors.surface` background, `AppRadius.medium` clip. Default container for grouped content outside of `Form`/`List`.
- **`AppEmptyState`** — wraps `ContentUnavailableView(title, systemImage:, description:)`. Use for every empty list/search state instead of a bespoke placeholder.
- **`AppFilterChip`** — capsule toggle chip, `.font(.subheadline.weight(.semibold))`, 44pt min height, selected state fills `AppColors.surface` and sets `.accessibilityAddTraits(.isSelected)`, unselected is transparent with an `AppColors.border` stroke.
- **`FilterSegmentBar`** (Riwayat) — a row of filter pills wrapped in `ViewThatFits`; falls back to a horizontally scrollable row only when it truly cannot fit, never clips a pill.
- **`SmartContactCardView`** (Review) — one card per participant with three states:
  - **unlinked** — border/background in `AppColors.destructive` opacity, "Hubungkan" action, VoiceOver hint "Hubungkan dulu" when required and missing.
  - **suggestion** — shown only when Contacts access is authorized and exactly one contact matches the typed name; requires explicit confirmation, never auto-links.
  - **linked** — checkmark, contact display name, "Ganti"/"Bukan dia?" action to re-open the picker.
- **`SplitParticipantRow`** — trailing amount, editable `TextField` (numberPad) only in Custom split mode, otherwise a plain `Text` with `.rupiahFormatted`.
- **`ReviewCardView`** (Review list) — avatar (scales with Dynamic Type), `lineLimit(3)` on the description, relative time, signed amount in `.primary` (not colored — see §1 color rule for why the direction still needs an icon/label).
- **`PersonCardRow`** (Riwayat) — direction arrow icon + VoiceOver label, name, balance amount, "Belum terhubung" badge for legacy unlinked people.
- Currency formatting always goes through the shared **`Int64.rupiahFormatted`** extension — never hand-roll `"Rp\(amount)"` string interpolation.

---

## 6. Screen-specific specs

### 6.1 Catat (voice capture)

- **Record control**: a circle, diameter driven by `@ScaledMetric(relativeTo: .largeTitle) private var scaledControlDiameter: CGFloat = 250`, clamped with `min(scaledControlDiameter, 320)` so it never exceeds 320pt even at the largest accessibility text size. Dashed stroke ring (`AppColors.textSecondary.opacity(0.65)`, `StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])`).
- **Idle state**: `mic.fill` icon (`.largeTitle.weight(.bold)`), caption "Tekan untuk catat\nvia suara".
- **Listening state**:
  - A radial-gradient glow behind the button (`AppColors.accent.opacity(0.24)` → `Color.purple.opacity(0.10)` → clear) that grows in real time with the microphone's smoothed input level (`speech.audioLevel`, 0...1).
  - Three stroked rings (gradient `AppColors.accent.opacity(0.85)` → `Color.purple.opacity(0.42)`) that pulse outward on a staggered, repeating loop.
  - The mic icon itself gently rotates/scales ("wobbles") while listening.
  - All glow/ring sizes scale proportionally with the control's Dynamic-Type-driven diameter (`scale = diameter / 250`), not with a hardcoded pixel size.
  - Caption becomes "Tekan untuk\nberhenti"; live transcript (or a stage headline like "Mendengarkan…") appears below the control.
  - An "Ulangi" pill button is pinned to the bottom of the screen (`.safeAreaInset(edge: .bottom)`) with a subtle drop shadow, not floating mid-layout.
- **Processing state**: the dashed ring stays, the icon/caption are replaced by a centered `ProgressView`.
- **Reduce Motion**: every animation above (`.animation(...)`) is guarded by `@Environment(\.accessibilityReduceMotion)` — when on, the glow and rings render at a fixed, still size/opacity and the mic wobble is disabled. Never remove the visual entirely for Reduce Motion, just its motion.
- After a successful save: the sheet closes, a "Tersimpan ke Review" `AccessibilityNotification.Announcement` fires, and the Review tab shows a transient banner + tab badge — no in-app modal confirmation.
- Permission-denied state shows body text plus a "Buka Pengaturan" button (opens `UIApplication.openSettingsURLString`), never a dead-end error.
- If on-device speech recognition isn't available, a footnote discloses: "Ucapan diproses oleh server Apple."

### 6.2 Catat flow chooser

- Two large tappable cards (Split Bill / Utang-Piutang), each: icon in a tinted circle (`flowAccent(flow).opacity(0.14)` background), title (`.title3.weight(.bold)`), one-line description, trailing chevron, subtle linear-gradient card background (`AppColors.surface` → `flowAccent(flow).opacity(0.08)`), thin `flowAccent(flow).opacity(0.25)` stroke.
- Navigation title is the screen purpose ("Pilih jenis pencatatan"), inline display mode — not a large title, since this is a modal-style chooser, not a top-level tab root.
- Cards are disabled (with reduced opacity, standard `.disabled()`) when the on-device LLM isn't ready yet; do not hide the cards or silently swallow the tap.

### 6.3 Review (single unified screen)

- Fields, top to bottom: autosave status card → Waktu (DatePicker, `id_ID` locale) → Nominal → Deskripsi → Jenis (personal) / Metode bagi + "Saya ikut dihitung" (Split Bill) → Orang (contact cards; Split Bill adds "Nama orang baru" + "Tambah", then "+ Pilih dari kontak") → Catatan Opsional → split summary (Split Bill only) → save-status sentence → "Simpan Catatan" → "Hapus catatan ini".
- **Autosave status card** (top of screen, always visible): a leading icon + text.
  - Saving: `ProgressView()` + "Menyimpan perubahan…"
  - Saved: `checkmark.circle.fill` (green/receivable) + "Tersimpan otomatis sebagai draft" / "Kamu bisa menutup halaman ini dan melanjutkan nanti dari tab Review."
  - Failed: `exclamationmark.triangle.fill` (destructive) + "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini." Never shown as a blocking alert — inline only.
- **Save-status sentence** directly above the primary button:
  - All linked: "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat."
  - Otherwise: "Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat."
- **Primary button** "Simpan Catatan": `.borderedProminent`, `.controlSize(.large)`, `.tint(.primary)`, 44pt min height, shows an inline `ProgressView` while saving (never disables silently without feedback).
- **Destructive action** "Hapus catatan ini": plain destructive-role text button below the primary button, always behind a `.confirmationDialog`, never a single-tap delete.
- Removing a Split Bill participant is via context menu / long-press ("Hapus dari catatan"), mirrored as an `.accessibilityAction` for VoiceOver users who cannot long-press.
- A field currently failing validation gets `AppColors.warning.opacity(0.12)` fill + `AppColors.warning` stroke, not just a red asterisk.

### 6.4 Contact picker sheet

- `.searchable` search field, "Kontak yang pernah dicatat" section first (recent/linked history), then "Kontak di iPhone" (device contacts, A–Z when the query is blank).
- "Buat Kontak Baru" row (single-select context) or in the empty state (no matches): opens the system `CNContactViewController` "New Contact" form prefilled with the searched name.
  - Single selection: the created contact is linked immediately and the sheet closes.
  - Multiple selection: the created contact is auto-selected (shown checked) and the sheet stays open so more people can be added.
- Empty state uses `ContentUnavailableView` with title "Tidak menemukan kontak?", description "Kamu tetap bisa membuat kontak baru dari nama yang sedang dicari.", and a "Buat Kontak" action button — not a bare text label.
- Multi-select rows show a trailing `checkmark.circle.fill` / `circle` toggle; single-select rows are a plain tappable row with no checkmark.

### 6.5 Riwayat (history / ledger)

- Two summary cards at the top: "Piutang" (receivable, green tint, `arrow.down.left`) and "Utang" (debt, red tint, `arrow.up.right`), each showing a total amount and a caption count ("N orang berutang" / "N tanggungan aktif"). Cards use `ViewThatFits` to sit side-by-side normally and stack at large Dynamic Type sizes.
- Filter pills (`FilterSegmentBar`) below the summary cards.
- `.searchable` on the person list.
- Each `PersonCardRow`: direction arrow + accessibility label, name, amount (plain `.primary` text — direction is carried by the arrow/label, not by coloring the amount), and, for a legacy unlinked person, a "Belum terhubung" badge plus a disabled/hinted state on payment and reminder actions until they link a contact.
- Linking flow reuses the same `ReviewContactPickerSheet` and "Buat Kontak Baru" behavior as Review (§6.4) — do not build a second, divergent contact picker for Riwayat.
- Merging a legacy unlinked person into a real contact requires an explicit confirmation dialog ("Gabungkan riwayat?") before combining balances.

### 6.6 Payment sheet

- Info banner: "Pembayaran dilakukan di luar aplikasi. UcapHutang hanya mencatat pelunasan." (`info.circle`, secondary style) — this is a record-keeping action, not a real money transfer, and the UI must not imply otherwise.
- Primary action `.borderedProminent` tint `.primary`; a "Batal" button to dismiss without recording.

### 6.7 Reminders, onboarding, Pengaturan

- **Notification primer** (first launch): centered `bell.badge` symbol, explanation copy, two 44pt-min buttons — "Izinkan Notifikasi" (`.borderedProminent`, tint `.primary`) and "Nanti Saja" (plain). Shown once via `fullScreenCover`.
- **Widget prompt**: an `.alert` ("Catat lebih cepat dengan Widget?") shown once, and only after the notification primer has been dismissed (never stacked on top of it). "Ya, Mau" opens `WidgetSetupInstructionsView`; "Nanti Saja" dismisses. Persisted via `@AppStorage("hasAskedAboutCatatWidget")`.
- **Widget setup instructions**: numbered steps (circular numeral badge, `AppColors.accent` fill), each step plain body text; a pinned "Mengerti" primary button at the bottom via `.safeAreaInset(edge: .bottom)`.
- **Pengaturan**: standard grouped `Form` — reminder on/off toggle, time `DatePicker` (`id_ID` locale, `.hourAndMinute`), and, when notifications are denied, an inline explanation + "Buka Pengaturan" link to system Settings. Never re-request a permission the system has already marked denied — only deep-link to Settings.
- Silent daily reminder notifications (no sound), routed via `[.list]` foreground presentation — never an intrusive banner while the app is open.

### 6.8 Home Screen widget ("Catat Cepat")

- `systemSmall` and `systemMedium` families only.
- Layout: `mic.fill` in a colored gradient circle (top-leading), title "Catat Cepat", one caption line "Utang, piutang, atau Split Bill" (`lineLimit(2)`), `containerBackground(.background, for: .widget)`.
- Tapping the widget opens `ucaphutang://catat`, which selects the Catat tab and dismisses any sheet already open over it — it must never leave the user looking at a screen that isn't the Catat chooser.

---

## 7. Motion & haptics

- Implicit `.animation(_:value:)` always names the `value:` it reacts to — never a bare `.animation(.default)` with no value that fires on unrelated state changes.
- Every "flourish" animation (mic aura, pulsing rings, card wobble) has a Reduce-Motion fallback that keeps the same information at a static state, never disappears entirely.
- `.sensoryFeedback(.success, trigger:)` is used for save confirmations (Review save, Catat save-to-Review, saved banner) — a haptic that mirrors a user-visible state flip, never a haptic with no matching visual change.
- Never repurpose a reserved system gesture (swipe-back, pull-to-refresh, modal swipe-to-dismiss) for a custom action.

---

## 8. Accessibility checklist (run against every screen change)

1. Every interactive element ≥ 44×44pt.
2. Every icon-only or color-only signal has an `.accessibilityLabel`/`.accessibilityHint`, or is `.accessibilityHidden(true)` if purely decorative next to labeled text.
3. Related elements are grouped with `.accessibilityElement(children: .combine)` where they read as one unit (e.g. an amount + its direction icon).
4. Dynamic Type tested at the largest size: no clipped or overlapping content; multi-line text wraps instead of truncating where the content matters (transcripts, validation messages).
5. Reduce Motion tested: decorative animation stops, information does not disappear.
6. VoiceOver can complete the entire flow (record → review → confirm, and link-a-contact) without a sighted assist.
7. Dark Mode tested: no hardcoded white/black, no token used for opposite-of-its-name purpose.
8. No meaning conveyed by color alone (§1).

**Scoring** (from the HIG audit convention already used on this project): 1 point per satisfied row above (max 8), plus the color/typography/native-idiom bonuses in the `ios-hig-design` skill's Quick Diagnostic when doing a full screen audit. Target 9–10/10 before calling a screen "done"; anything ≤ 6 must list the specific fix needed, not just a score.

---

## 9. What NOT to do

- Do not hardcode a `Color(red:green:blue:)`, a `.font(.system(size:))`, or a raw point value for spacing/radius outside `AppDesignSystem` — add a token instead.
- Do not reintroduce `AppPrimaryButtonStyle`, `ContactResolutionService`, `ContactMatchCandidate`, or a second/duplicate contact-picker implementation — the current single `ReviewContactPickerSheet` + `ReviewContactPickerViewModel` is the only one.
- Do not change "Utang" back to "Hutang" anywhere in UI copy.
- Do not stack the widget prompt on top of the notification primer.
- Do not encode debt/receivable direction by color alone — always pair with an icon + accessibility label.
- Do not skip the Reduce Motion / Dynamic Type / Dark Mode pass on a new or changed screen.
- Do not invent new design decisions beyond this document without asking the product owner first — if a screen isn't covered here, ask rather than guess.
