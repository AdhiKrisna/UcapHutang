# Merge main (PR #3) into fix/all Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the conflicts of PR #4 (`fix/all` → `main`) by merging `origin/main` (which now contains PR #3 `feature/catat`) into `fix/all`, keeping the `fix/all` architecture and porting only the PR #3 features the developer approved.

**Architecture:** Task 1 is one merge commit that takes `fix/all` for every conflicting code file and takes `main` only for the new widget target, deep link, Info.plist files, project file and docs. Tasks 2–9 port approved PR #3 behavior into the `fix/all` files with TDD (feature-first MVVM, `@Observable`, domain validation in `DraftValidator`). Task 10 updates the spec and runs final verification.

**Tech Stack:** Swift 5 mode, SwiftUI (iOS 26.5), SwiftData (`SchemaV2`), Observation, Contacts/ContactsUI, WidgetKit, XCTest. Xcode 26.6 on the developer's Mac.

## Global Constraints

- Merge strategy: `git merge origin/main` into `fix/all` (merge commit). Never rebase, never force-push.
- Base code: `fix/all`. Do NOT restore any PR #3 file that `fix/all` deleted or replaced (`ReviewView.swift`, `ReviewViewModel.swift`, `ContactPickerSheet.swift`, `Domain/Models/DraftValidator.swift`, `Domain/Models/SwiftDataEntities.swift`, `Domain/Repositories/SwiftDataTransactionRepository.swift`, `Features/Catat/CatatView.swift`, `Features/Ledger/**`).
- Split Bill rules stay exactly as in `fix/all` (`includesUser`, custom total = sum of friend shares). Do NOT add `userShareAmount` anywhere.
- No new SwiftData schema version. `SchemaV2` must not change.
- UI wording uses "Utang" (never "Hutang"); the Catat flow title stays "Utang / Piutang". Code identifiers (`TransactionType.hutang`, app name `UcapHutang`) are unchanged.
- Do not change `DEVELOPMENT_TEAM` or any other signing setting. Do not edit `UcapHutang.xcodeproj/project.pbxproj` by hand; it comes from the merge only.
- Do not modify `UcapHutangWidget/UcapHutangWidget.swift` or either `Info.plist`.
- Copy strings in this plan are approved. Use them verbatim.
- Never stage `.xcede/` or `xcede.yml`. Always `git add` explicit paths.
- Do not push. The developer pushes after reviewing.
- Test command (use exactly):
  `xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"`
- Single test class: append `-only-testing:UcapHutangTests/<ClassName>` before `2>&1`.
- Build-only command:
  `xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
- If any build fails with a signing / team / provisioning error, STOP and report it to the developer. Do not change signing to work around it.

---

## Approved decisions (2026-09-13)

| Topic | Decision |
|---|---|
| Strategy | Merge `origin/main` into `fix/all` |
| Base | `fix/all`; port selected PR #3 features |
| Old data from PR #3 builds | Not needed; no extra schema version |
| Split Bill | Keep `fix/all` rules; drop PR #3 split rules and its 3 split tests |
| "Buat Kontak Baru" | Port into `ReviewContactPickerSheet` (Review and Riwayat both use it) |
| Contact created during multi-select | Auto-selected, sheet stays open |
| Widget | Keep widget, deep link `ucaphutang://catat`, and the widget prompt, shown only after the notification primer is gone |
| Wording | "Utang" / "Utang / Piutang" |
| Catat mic | Port PR #3 animations fully (mic icon, audio-reactive aura, rings, wobbling mic, "Ulangi" pinned at the bottom), keeping Dynamic Type sizing and Reduce Motion |
| Catat flow chooser | Keep `fix/all` design |
| Review extras | Autosave on every edit + status card; add person by typing a name; reject generic names in `DraftValidator`; save status sentence |
| Notes | Add "Catatan Opsional" under the people list |
| Copy | Adjusted to the Review tab and lowercase "kontak" |
| Widget signing team | Leave as is |

## File map

| File | Task | Change |
|---|---|---|
| (merge) pbxproj, `UcapHutang/Info.plist`, `UcapHutangWidget/*`, `UcapHutang/App/AppDeepLink.swift`, `docs/ARCHITECTURE_PLAN.md`, `docs/PROJECT_REMEDIATION_PLAN.md` | 1 | Taken from `main` |
| `UcapHutang/App/AppRouter.swift` | 2 | Add `open(_:)` |
| `UcapHutang/Features/Onboarding/Models/WidgetPrompt.swift` | 2 | Create |
| `UcapHutang/Features/Onboarding/Views/WidgetSetupInstructionsView.swift` | 2 | Create (HIG version of PR #3 view) |
| `UcapHutang/App/RootTabView.swift` | 2 | Widget prompt + deep link |
| `UcapHutangTests/AppDeepLinkTests.swift`, `WidgetPromptTests.swift` | 2 | Create |
| `UcapHutangTests/AppRouterTests.swift` | 2 | Add test |
| `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift` | 3 | Update participants in place |
| `UcapHutangTests/SwiftDataDraftAutosaveTests.swift` | 3 | Create |
| `UcapHutang/Domain/Validation/DraftValidator.swift` | 4 | Generic-name issue |
| `UcapHutangTests/DraftValidatorIssuesTests.swift` | 4 | Add tests |
| `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift` | 5, 6 | Autosave, add by name, notes, save status |
| `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift` | 5 | `saveDraftError` |
| `UcapHutangTests/ReviewDetailViewModelTests.swift` | 5, 6 | Tests |
| `UcapHutang/Features/Review/Views/ReviewDetailView.swift` | 7 | UI for Tasks 5–6 |
| `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift` | 8 | Created-contact handling |
| `UcapHutang/Features/Review/Components/NewContactView.swift` | 8 | Create |
| `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift` | 8 | "Buat Kontak Baru" |
| `UcapHutangTests/ReviewContactPickerViewModelTests.swift` | 8 | Add tests |
| `UcapHutang/Domain/Protocols/SpeechTranscribing.swift` | 9 | `audioLevel` |
| `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift` | 9 | `audioLevel` |
| `UcapHutang/Features/Catat/Views/CatatView.swift` | 9 | Mic animations |
| `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` | 10 | Addendum |

Expected test counts: start 116 → T1 116 → T2 119 → T3 120 → T4 122 → T5 125 → T6 129 → T7 129 → T8 131 → T9 131 → T10 131.

---

### Task 1: Merge commit with conflict resolution

**Files:** see the "(merge)" row of the file map. No hand-written code.

**Interfaces:**
- Consumes: `origin/main` at `bd6056f` (PR #3 merged), `fix/all` containing `c866d9a`.
- Produces: `AppDeepLink` (`enum AppDeepLink: Equatable { case catatChooser; init?(url: URL) }`) in `UcapHutang/App/AppDeepLink.swift`, the `UcapHutangWidget` target, and `UcapHutang/Info.plist` with URL scheme `ucaphutang`.

- [ ] **Step 1: Preconditions**

Run:
```bash
git status --short
git fetch origin
git switch fix/all
git pull --ff-only origin fix/all
git rev-parse --short origin/main
git merge-base --is-ancestor c866d9a HEAD && echo "fix/all OK"
```
Expected: `git status --short` prints only `?? .xcede/` and `?? xcede.yml`; `origin/main` is `bd6056f`; `fix/all OK` is printed.
If `origin/main` is not `bd6056f` (someone merged more work), STOP and ask the developer; this plan only covers PR #3.

- [ ] **Step 2: Start the merge without committing**

Run:
```bash
git merge --no-ff --no-commit origin/main
```
Expected: the merge stops with exactly these conflicts:
```
CONFLICT (content): Merge conflict in UcapHutang/App/RootTabView.swift
CONFLICT (modify/delete): UcapHutang/Domain/Models/DraftValidator.swift deleted in HEAD and modified in origin/main.
CONFLICT (modify/delete): UcapHutang/Domain/Models/SwiftDataEntities.swift deleted in HEAD and modified in origin/main.
CONFLICT (modify/delete): UcapHutang/Domain/Repositories/SwiftDataTransactionRepository.swift deleted in HEAD and modified in origin/main.
CONFLICT (modify/delete): UcapHutang/Features/Catat/CatatView.swift deleted in HEAD and modified in origin/main.
CONFLICT (modify/delete): UcapHutang/Features/Ledger/Views/LedgerListView.swift deleted in HEAD and modified in origin/main.
CONFLICT (modify/delete): UcapHutang/Features/Review/ContactPickerSheet.swift deleted in HEAD and modified in origin/main.
CONFLICT (rename/delete): UcapHutang/Features/Review/ReviewDraftView.swift renamed to UcapHutang/Features/Review/ReviewView.swift in origin/main, but deleted in HEAD.
```
(Line wording may differ slightly by git version; the file list must match.)

- [ ] **Step 3: Keep fix/all for every conflicting or wrongly auto-merged code file**

In this merge "ours"/`HEAD` is `fix/all`, "theirs" is `main`.

Run:
```bash
git checkout --ours UcapHutang/App/RootTabView.swift
git add UcapHutang/App/RootTabView.swift

git rm -f --quiet \
  UcapHutang/Domain/Models/DraftValidator.swift \
  UcapHutang/Domain/Models/SwiftDataEntities.swift \
  UcapHutang/Domain/Repositories/SwiftDataTransactionRepository.swift \
  UcapHutang/Features/Catat/CatatView.swift \
  UcapHutang/Features/Ledger/Views/LedgerListView.swift \
  UcapHutang/Features/Review/ContactPickerSheet.swift \
  UcapHutang/Features/Review/ReviewView.swift \
  UcapHutang/Features/Review/ReviewViewModel.swift
git rm --quiet --ignore-unmatch UcapHutang/Features/Review/ReviewDraftView.swift

git checkout HEAD -- \
  UcapHutang/Domain/Models/TransactionModels.swift \
  UcapHutang/Data/Persistence/InMemoryTransactionRepository.swift \
  UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift \
  UcapHutangTests/CoreFlowTests.swift
```
Why the last command: git auto-merged these four files, but the result mixes PR #3 split rules (`userShareAmount`, `where participant.shareAmount > 0`), the "Hutang Personal" title, the PR #3 chooser design, and PR #3 tests that call deleted types. The approved PR #3 tests are re-added in Tasks 2, 3 and 5.

- [ ] **Step 4: Verify the staged result**

Run:
```bash
git status --short
grep -rn '<<<<<<<\|>>>>>>>' UcapHutang UcapHutangTests UcapHutangWidget || echo "no markers"
git diff --cached --name-status HEAD
```
Expected `git diff --cached --name-status HEAD` output, exactly:
```
M	UcapHutang.xcodeproj/project.pbxproj
A	UcapHutang/App/AppDeepLink.swift
A	UcapHutang/Info.plist
A	UcapHutangWidget/Info.plist
A	UcapHutangWidget/UcapHutangWidget.swift
M	docs/ARCHITECTURE_PLAN.md
M	docs/PROJECT_REMEDIATION_PLAN.md
```
and `no markers`. If any other path appears, fix it with the Step 3 commands before continuing.

- [ ] **Step 5: Build and run the full suite**

Run the test command from Global Constraints.
Expected: `Executed 116 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 6: Commit the merge**

Run:
```bash
git commit -m "Merge origin/main (PR #3 feature/catat) into fix/all" -m "Keep fix/all for all conflicting code (MVVM structure, unified Review, SchemaV2, split rules, Utang wording). Take main's Catat Cepat widget target, ucaphutang://catat deep link, Info.plist files and docs. Approved PR #3 features are ported in follow-up commits."
git log --oneline -1
```
Expected: a merge commit on `fix/all`.

- [ ] **Step 7: Developer checkpoint**

Tell the developer: "Merge commit created (116 tests pass). Please run the app in the simulator once and confirm it launches before Task 2." Wait for confirmation.

---
### Task 2: Widget deep link routing and widget prompt after the primer

**Files:**
- Create: `UcapHutangTests/AppDeepLinkTests.swift`
- Create: `UcapHutangTests/WidgetPromptTests.swift`
- Modify: `UcapHutangTests/AppRouterTests.swift`
- Modify: `UcapHutang/App/AppRouter.swift`
- Create: `UcapHutang/Features/Onboarding/Models/WidgetPrompt.swift`
- Create: `UcapHutang/Features/Onboarding/Views/WidgetSetupInstructionsView.swift`
- Modify (full replacement): `UcapHutang/App/RootTabView.swift`

**Interfaces:**
- Consumes: `AppDeepLink` (Task 1), `AppRouter.selectedTab: AppTab`, `NotificationPrimerViewModel.shouldShow(scheduler:settingsStore:) async -> Bool`.
- Produces: `AppRouter.open(_ link: AppDeepLink)`, `enum WidgetPrompt { static let hasAskedKey: String; static func shouldPresent(hasAsked: Bool, isShowingNotificationPrimer: Bool) -> Bool }`, `struct WidgetSetupInstructionsView: View` (no parameters).

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/AppDeepLinkTests.swift` (ported from PR #3 `CoreFlowTests`):
```swift
import XCTest
@testable import UcapHutang

@MainActor
final class AppDeepLinkTests: XCTestCase {
    func testWidgetDeepLinkRoutesOnlyToCatatChooser() {
        XCTAssertEqual(AppDeepLink(url: URL(string: "ucaphutang://catat")!), .catatChooser)
        XCTAssertNil(AppDeepLink(url: URL(string: "ucaphutang://unknown")!))
        XCTAssertNil(AppDeepLink(url: URL(string: "https://example.com/catat")!))
    }
}
```

Create `UcapHutangTests/WidgetPromptTests.swift`:
```swift
import XCTest
@testable import UcapHutang

@MainActor
final class WidgetPromptTests: XCTestCase {
    func testWidgetPromptWaitsForThePrimerAndIsAskedOnce() {
        XCTAssertTrue(WidgetPrompt.shouldPresent(hasAsked: false, isShowingNotificationPrimer: false))
        XCTAssertFalse(WidgetPrompt.shouldPresent(hasAsked: false, isShowingNotificationPrimer: true))
        XCTAssertFalse(WidgetPrompt.shouldPresent(hasAsked: true, isShowingNotificationPrimer: false))
        // Same key as PR #3 so testers who already answered are not asked again.
        XCTAssertEqual(WidgetPrompt.hasAskedKey, "hasAskedAboutCatatWidget")
    }
}
```

In `UcapHutangTests/AppRouterTests.swift`, add this method inside `AppRouterTests`, after `testSavedBannerOpensTheReviewTabAndClears()`:
```swift
    func testCatatDeepLinkSelectsTheCaptureTab() {
        let router = AppRouter()
        router.selectedTab = .ledger

        router.open(.catatChooser)

        XCTAssertEqual(router.selectedTab, .capture)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/AppRouterTests -only-testing:UcapHutangTests/WidgetPromptTests -only-testing:UcapHutangTests/AppDeepLinkTests`.
Expected: build FAILS with `error:` lines for `value of type 'AppRouter' has no member 'open'` and `cannot find 'WidgetPrompt' in scope`.

- [ ] **Step 3: Implement the router method and the prompt gate**

In `UcapHutang/App/AppRouter.swift`, add this method inside `AppRouter`, after `openReviewFromBanner()`:
```swift
    /// Handles `ucaphutang://` links opened from the Catat Cepat widget.
    func open(_ link: AppDeepLink) {
        switch link {
        case .catatChooser:
            selectedTab = .capture
        }
    }
```

Create `UcapHutang/Features/Onboarding/Models/WidgetPrompt.swift`:
```swift
import Foundation

/// Decides when to ask "Catat lebih cepat dengan Widget?".
enum WidgetPrompt {
    /// `@AppStorage` key. Kept identical to PR #3 so people who already answered are not asked again.
    static let hasAskedKey = "hasAskedAboutCatatWidget"

    /// The widget question is asked once, and never while the notification primer is on screen.
    static func shouldPresent(hasAsked: Bool, isShowingNotificationPrimer: Bool) -> Bool {
        !hasAsked && !isShowingNotificationPrimer
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2.
Expected: the 3 test cases pass, `TEST SUCCEEDED`.

- [ ] **Step 5: Add the instructions screen**

Create `UcapHutang/Features/Onboarding/Views/WidgetSetupInstructionsView.swift`. Copy comes from PR #3 unchanged; layout follows the HIG rules already used by `NotificationPrimerView` (text styles, 44 pt button, adaptive primary button).
```swift
import SwiftUI

struct WidgetSetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .subheadline) private var stepBadgeSize: CGFloat = 28

    private let steps = [
        "Tekan dan tahan area kosong di Home Screen.",
        "Pilih Edit, lalu Tambah Widget.",
        "Cari UcapHutang dan pilih widget Catat Cepat.",
        "Tambahkan widget ke Home Screen."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    Image(systemName: "rectangle.3.group.bubble.left.fill")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.small) {
                        Text("Tambahkan Widget UcapHutang")
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("iOS mengharuskan widget ditambahkan sendiri dari Home Screen. Setelah dipasang, sekali tap akan langsung membuka tab Catat untuk memilih Utang/Piutang atau Split Bill.")
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                            instruction(number: index + 1, text: step)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Mengerti")
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(AppColors.background)
            .navigationTitle("Widget Catat Cepat")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func instruction(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: stepBadgeSize, height: stepBadgeSize)
                .background(AppColors.accent, in: Circle())
            Text(text)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, 3)
        }
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 6: Wire the prompt and the deep link into RootTabView**

Replace the whole content of `UcapHutang/App/RootTabView.swift` with:
```swift
import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(WidgetPrompt.hasAskedKey) private var hasAskedAboutCatatWidget = false
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var pendingReviewCount = 0
    @State private var isShowingSettings = false
    @State private var isShowingNotificationPrimer = false
    @State private var isShowingWidgetPrompt = false
    @State private var isShowingWidgetInstructions = false

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(
                    repository: container.repository,
                    onSelect: { draftID in reviewDraftItem = IdentifiableUUID(draftID) },
                    onOpenSettings: { isShowingSettings = true }
                )
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router) { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository, contacts: container.contacts)
            }
        }
        .sensoryFeedback(.success, trigger: container.router.savedBannerID) { _, newValue in
            newValue != nil
        }
        .task {
            await refreshPendingReviewCount()
            isShowingNotificationPrimer = await NotificationPrimerViewModel.shouldShow(
                scheduler: container.reminderScheduler,
                settingsStore: container.reminderSettings
            )
            presentWidgetPromptIfNeeded()
            await container.reminderScheduler.sync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task {
                await refreshPendingReviewCount()
                await container.reminderScheduler.sync()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await container.reminderScheduler.sync() }
            }
        }
        .onOpenURL { url in
            guard let link = AppDeepLink(url: url) else { return }
            // Close anything covering the tabs so the Catat chooser is actually visible.
            reviewDraftItem = nil
            selectedCaptureFlow = nil
            isShowingSettings = false
            container.router.open(link)
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
        .sheet(isPresented: $isShowingSettings) {
            PengaturanView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .sheet(isPresented: $isShowingWidgetInstructions) {
            WidgetSetupInstructionsView()
        }
        .fullScreenCover(isPresented: $isShowingNotificationPrimer, onDismiss: presentWidgetPromptIfNeeded) {
            NotificationPrimerView(scheduler: container.reminderScheduler, settingsStore: container.reminderSettings)
        }
        .alert("Catat lebih cepat dengan Widget?", isPresented: $isShowingWidgetPrompt) {
            Button("Ya, Mau") {
                hasAskedAboutCatatWidget = true
                isShowingWidgetInstructions = true
            }
            Button("Nanti Saja", role: .cancel) {
                hasAskedAboutCatatWidget = true
            }
        } message: {
            Text("Apakah kamu mau memakai widget untuk mencatat utang, piutang, atau Split Bill secara instan dari Home Screen?")
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }

    /// Called at launch and again when the notification primer closes.
    private func presentWidgetPromptIfNeeded() {
        isShowingWidgetPrompt = WidgetPrompt.shouldPresent(
            hasAsked: hasAskedAboutCatatWidget,
            isShowingNotificationPrimer: isShowingNotificationPrimer
        )
    }
}
```

- [ ] **Step 7: Run the full suite**

Run the test command.
Expected: `Executed 119 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add UcapHutang/App/AppRouter.swift UcapHutang/App/RootTabView.swift UcapHutang/Features/Onboarding/Models/WidgetPrompt.swift UcapHutang/Features/Onboarding/Views/WidgetSetupInstructionsView.swift UcapHutangTests/AppDeepLinkTests.swift UcapHutangTests/WidgetPromptTests.swift UcapHutangTests/AppRouterTests.swift
git commit -m "feat: route Catat Cepat widget link and ask about the widget after the notification primer"
```

---

### Task 3: Update draft participants in place (PR #3 repository fix)

Autosave (Task 5) writes the draft on every edit. PR #3 changed the SwiftData repository to update existing participant rows instead of deleting and re-inserting rows that have a unique `id`. Port that fix.

**Files:**
- Create: `UcapHutangTests/SwiftDataDraftAutosaveTests.swift`
- Modify: `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift` (method `apply(_:to:)`)

**Interfaces:**
- Consumes: `SwiftDataTransactionRepository(modelContainer:)`, `SchemaV2`, typealias `SDTransactionParticipant`.
- Produces: no API change. `saveDraft` keeps participant rows whose `id` still exists and deletes rows whose `id` was removed.

- [ ] **Step 1: Write the test**

Create `UcapHutangTests/SwiftDataDraftAutosaveTests.swift`:
```swift
import XCTest
import SwiftData
@testable import UcapHutang

@MainActor
final class SwiftDataDraftAutosaveTests: XCTestCase {
    func testRepeatedSavesUpdateParticipantsInPlace() async throws {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try SwiftData.ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataTransactionRepository(modelContainer: container)
        var draft = TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: 90_000,
            splitMethod: .equal,
            participants: [
                TransactionParticipant(name: "Satria", contactIdentifier: "contact-satria", shareAmount: 30_000),
                TransactionParticipant(name: "Ari", shareAmount: 30_000)
            ],
            rawTranscript: "makan malam"
        )
        try await repository.saveDraft(draft)
        let firstRows = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
        let satriaRowID = firstRows.first { $0.name == "Satria" }?.persistentModelID
        XCTAssertNotNil(satriaRowID)

        draft.title = "Makan siang"
        try await repository.saveDraft(draft)
        draft.participants[0].shareAmount = 45_000
        draft.participants.remove(at: 1)
        try await repository.saveDraft(draft)

        let stored = try await repository.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Makan siang")
        XCTAssertEqual(stored?.participants.map(\.id), [draft.participants[0].id])
        XCTAssertEqual(stored?.participants.first?.shareAmount, 45_000)
        let rows = try container.mainContext.fetch(FetchDescriptor<SDTransactionParticipant>())
        XCTAssertEqual(rows.count, 1, "Removed participants must be deleted")
        XCTAssertEqual(rows.first?.persistentModelID, satriaRowID, "Existing participant rows are updated, not re-created")
    }
}
```

- [ ] **Step 2: Run the test**

Run the test command with `-only-testing:UcapHutangTests/SwiftDataDraftAutosaveTests`.
Expected: FAIL on the `persistentModelID` assertion, because `apply(_:to:)` currently deletes and re-inserts every participant. If it unexpectedly passes, note that in the commit message and still do Step 3.

- [ ] **Step 3: Replace `apply(_:to:)`**

In `UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift`, replace the whole `private func apply(_ draft: TransactionDraft, to entity: SDTransactionDraft)` method with:
```swift
    private func apply(_ draft: TransactionDraft, to entity: SDTransactionDraft) {
        entity.statusRaw = draft.status.rawValue
        entity.flowRaw = draft.flow.rawValue
        entity.typeRaw = draft.type.rawValue
        entity.transactionDate = draft.transactionDate
        entity.title = draft.title
        entity.totalAmount = draft.totalAmount
        entity.splitMethodRaw = draft.splitMethod?.rawValue
        entity.includesUser = draft.includesUser
        entity.notes = draft.notes
        entity.rawTranscript = draft.rawTranscript
        entity.rawModelResponse = draft.rawModelResponse
        entity.reviewWarningsRaw = draft.reviewWarnings

        // Update rows in place: autosave calls this on every edit and participant ids are unique.
        let storedByID = Dictionary(entity.participants.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let incomingIDs = Set(draft.participants.map(\.id))
        let removed = entity.participants.filter { !incomingIDs.contains($0.id) }

        entity.participants = draft.participants.map { participant in
            let row = storedByID[participant.id] ?? SDTransactionParticipant(id: participant.id, name: participant.name)
            row.name = participant.name
            row.contactIdentifier = participant.contactIdentifier
            row.shareAmount = participant.shareAmount
            row.itemTitle = participant.itemTitle
            row.notes = participant.notes
            return row
        }

        for row in removed {
            context.delete(row)
        }
    }
```
Do not change `makeParticipantEntities(from:)`; `makeDraftEntity(from:)` still uses it for new drafts.

- [ ] **Step 4: Run the full suite**

Run the test command.
Expected: `Executed 120 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Data/Persistence/SwiftDataTransactionRepository.swift UcapHutangTests/SwiftDataDraftAutosaveTests.swift
git commit -m "fix: update draft participants in place on repeated saves (from PR #3)"
```

---

### Task 4: Reject generic participant names in DraftValidator

**Files:**
- Modify: `UcapHutangTests/DraftValidatorIssuesTests.swift`
- Modify: `UcapHutang/Domain/Validation/DraftValidator.swift`

**Interfaces:**
- Consumes: `DraftValidator.issues(for:)`, `DraftValidationIssue`.
- Produces: `DraftValidationIssue.participantNameGeneric(participantID: UUID, label: String)` with message `"Ganti nama \(label) dengan nama yang bisa kamu kenali."`. `label` is `"orang terkait"` for the personal flow and `"peserta ke-N"` (1-based position) for Split Bill. Generic names (trimmed, case-insensitive): `teman`, `teman 1`, `teman 2`, `orang`, `orang a`, `orang b`. The issue is reported for linked and unlinked participants, right after the empty-name issues.

- [ ] **Step 1: Write the failing tests**

In `UcapHutangTests/DraftValidatorIssuesTests.swift`, add these methods inside the class, after `testParticipantNameMissing()`:
```swift
    func testGenericPersonalNameIsRejected() {
        var draft = linkedPersonalDraft()
        draft.participants[0].name = "Teman"
        let id = draft.participants[0].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.participantNameGeneric(participantID: id, label: "orang terkait")])
        XCTAssertEqual(
            DraftValidationIssue.participantNameGeneric(participantID: id, label: "orang terkait").message,
            "Ganti nama orang terkait dengan nama yang bisa kamu kenali."
        )
    }

    func testGenericSplitNameUsesParticipantPosition() {
        var draft = linkedSplitDraft()
        draft.participants[1].name = " orang B "
        let id = draft.participants[1].id
        XCTAssertEqual(DraftValidator.issues(for: draft), [.participantNameGeneric(participantID: id, label: "peserta ke-2")])
        XCTAssertEqual(
            DraftValidationIssue.participantNameGeneric(participantID: id, label: "peserta ke-2").message,
            "Ganti nama peserta ke-2 dengan nama yang bisa kamu kenali."
        )
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/DraftValidatorIssuesTests`.
Expected: build FAILS with `type 'DraftValidationIssue' has no member 'participantNameGeneric'`.

- [ ] **Step 3: Implement**

In `UcapHutang/Domain/Validation/DraftValidator.swift`:

1. In `enum DraftValidationIssue`, add this case directly after `case participantNameMissing(participantID: UUID)`:
```swift
    case participantNameGeneric(participantID: UUID, label: String)
```

2. In `var message: String`, add this branch directly after the `.participantNameMissing` branch:
```swift
        case .participantNameGeneric(_, let label):
            "Ganti nama \(label) dengan nama yang bisa kamu kenali."
```

3. In `static func issues(for:)`, directly after the `for participant in draft.participants where participant.name...isEmpty { ... }` loop, add:
```swift
        for (index, participant) in draft.participants.enumerated() where isGenericName(participant.name) {
            let label = draft.flow == .personal ? "orang terkait" : "peserta ke-\(index + 1)"
            issues.append(.participantNameGeneric(participantID: participant.id, label: label))
        }
```

4. Inside `enum DraftValidator`, directly before `private static func isLinked(_:)`, add:
```swift
    /// Placeholder names that do not identify a real person (from PR #3).
    private static let genericNames: Set<String> = ["teman", "teman 1", "teman 2", "orang", "orang a", "orang b"]

    private static func isGenericName(_ name: String) -> Bool {
        genericNames.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the test command.
Expected: `Executed 122 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Validation/DraftValidator.swift UcapHutangTests/DraftValidatorIssuesTests.swift
git commit -m "feat: reject generic participant names before confirming a draft"
```

---

### Task 5: Autosave every Review edit

**Files:**
- Modify: `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift`
- Modify: `UcapHutangTests/ReviewDetailViewModelTests.swift`
- Modify (full replacement): `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`

**Interfaces:**
- Consumes: `TransactionRepository.saveDraft/deleteDraft/confirmDraft`.
- Produces on `ReviewDetailViewModel`:
  - `private(set) var isAutosaving: Bool`
  - `private(set) var autosaveErrorMessage: String?` (value on failure: `"Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."`)
  - `func flushPendingEdits() async` (replaces `persistEditsIfNeeded()`; waits for queued saves, then saves anything still unsaved; never confirms)
  - `func awaitPendingAutosave() async` (waits for queued saves only; used by tests)
  - Every edit that goes through `mutate` queues one automatic `saveDraft`. Saves run one after another. `delete()` waits for queued saves before deleting. `save()` flushes before validating.
- Produces on `SpyTransactionRepository`: `var saveDraftError: Error?` (when set, `saveDraft` counts the call and throws it).

- [ ] **Step 1: Let the spy fail saves**

In `UcapHutangTests/TestDoubles/SpyTransactionRepository.swift`:

Add below `private(set) var deleteDraftCallCount = 0`:
```swift
    /// When set, `saveDraft` counts the call and throws this error.
    var saveDraftError: Error?
```
Replace the `saveDraft` method with:
```swift
    func saveDraft(_ draft: TransactionDraft) async throws {
        saveDraftCallCount += 1
        if let saveDraftError { throw saveDraftError }
        try await base.saveDraft(draft)
    }
```

- [ ] **Step 2: Write the failing tests**

In `UcapHutangTests/ReviewDetailViewModelTests.swift`:

Replace the two methods `testPersistEditsSavesADirtyDraftWithoutConfirming()` and `testPersistEditsDoesNothingWhenClean()` with:
```swift
    func testFlushPendingEditsSavesADirtyDraftWithoutConfirming() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setTitle("Kopi susu")
        await viewModel.flushPendingEdits()

        XCTAssertEqual(spy.saveDraftCallCount, 1)
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Kopi susu")
        XCTAssertEqual(stored?.status, .needsReview)
    }

    func testFlushPendingEditsDoesNothingWhenClean() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft())

        await viewModel.flushPendingEdits()

        XCTAssertEqual(spy.saveDraftCallCount, 0)
    }
```

Add these methods at the end of the class (before the final `}`), ported from PR #3:
```swift
    func testEditsAreSavedToTheDraftAutomaticallyWithoutConfirming() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)
        let participantID = viewModel.draft!.participants[0].id
        let newDate = draft.transactionDate.addingTimeInterval(3_600)

        viewModel.setTotalAmount(35_000)
        viewModel.setTitle("Bensin")
        viewModel.setTransactionDate(newDate)
        viewModel.handlePicked([satria], for: .link(participantID: participantID, prefill: "Satria"))
        await viewModel.awaitPendingAutosave()

        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.totalAmount, 35_000)
        XCTAssertEqual(stored?.title, "Bensin")
        XCTAssertEqual(stored?.transactionDate, newDate)
        XCTAssertEqual(stored?.participants.first?.name, "Satria Kans")
        XCTAssertEqual(stored?.participants.first?.contactIdentifier, "contact-satria")
        XCTAssertEqual(stored?.participants.first?.shareAmount, 35_000)
        XCTAssertEqual(stored?.status, .needsReview)
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        let entries = try await spy.ledgerEntries()
        XCTAssertTrue(entries.isEmpty)
        XCTAssertNil(viewModel.autosaveErrorMessage)
    }

    func testAutosaveFailureIsReportedWithoutAnAlert() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)
        spy.saveDraftError = RepositoryError.invalidAmount

        viewModel.setTitle("Bensin")
        await viewModel.flushPendingEdits()

        XCTAssertNil(viewModel.alert)
        XCTAssertEqual(
            viewModel.autosaveErrorMessage,
            "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."
        )
        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Kopi")
    }

    func testDeleteWaitsForPendingAutosaveAndDoesNotRecreateTheDraft() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setTitle("Kopi susu")
        await viewModel.delete()
        await viewModel.flushPendingEdits()

        XCTAssertTrue(viewModel.didFinish)
        XCTAssertEqual(spy.deleteDraftCallCount, 1)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored)
    }
```

- [ ] **Step 3: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/ReviewDetailViewModelTests`.
Expected: build FAILS with `value of type 'ReviewDetailViewModel' has no member 'flushPendingEdits'` (and `awaitPendingAutosave`, `autosaveErrorMessage`).

- [ ] **Step 4: Implement autosave**

Replace the whole content of `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift` with:
```swift
import Foundation
import Observation

@Observable
final class ReviewDetailViewModel {
    enum LoadState: Equatable {
        case loading
        case loaded
        case notFound
    }

    static let autosaveFailedMessage = "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."

    let draftID: UUID
    private(set) var loadState: LoadState = .loading
    private(set) var draft: TransactionDraft?
    private(set) var suggestions: [UUID: ContactRef] = [:]
    private(set) var hasAttemptedSave = false
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var didFinish = false
    /// True while an edit is being written back to the draft.
    private(set) var isAutosaving = false
    /// Set when the last automatic draft save failed. Shown inline, never as an alert.
    private(set) var autosaveErrorMessage: String?
    var alert: ReviewAlert?
    var pickerRequest: ContactPickerRequest?
    var isConfirmingDelete = false

    @ObservationIgnored private var savedSnapshot: TransactionDraft?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.draftID = draftID
        self.repository = repository
        self.contacts = contacts
    }

    // MARK: - Derived state

    var issues: [DraftValidationIssue] {
        guard let draft else { return [] }
        return DraftValidator.issues(for: draft)
    }

    var isDirty: Bool {
        draft != savedSnapshot
    }

    var isCustomSplit: Bool {
        guard let draft, draft.flow == .splitBill else { return false }
        return (draft.splitMethod ?? .equal) == .custom
    }

    var friendsTotal: Int64 {
        SplitCalculationEngine.customTotal(draft?.participants.map(\.shareAmount) ?? []) ?? 0
    }

    var userShare: Int64 {
        guard let draft, draft.flow == .splitBill, !isCustomSplit, draft.includesUser else { return 0 }
        return max(0, draft.totalAmount - friendsTotal)
    }

    func cardState(for participant: TransactionParticipant) -> ContactCardState {
        if Self.isLinked(participant), let identifier = participant.contactIdentifier {
            return .linked(ContactRef(identifier: identifier, displayName: participant.name, phoneNumber: nil))
        }
        if let suggestion = suggestions[participant.id] {
            return .suggestion(suggestion)
        }
        return .unlinked
    }

    func showsRequiredMarker(for participantID: UUID) -> Bool {
        hasAttemptedSave && issues.contains(.participantNotLinked(participantID: participantID))
    }

    // MARK: - Loading

    func load() async {
        do {
            guard var loaded = try await repository.draft(id: draftID) else {
                loadState = .notFound
                return
            }
            Self.recalculate(&loaded)
            draft = loaded
            savedSnapshot = loaded
            loadState = .loaded
            await refreshSuggestions()
        } catch {
            loadState = .notFound
        }
    }

    // MARK: - Field edits

    func setTransactionDate(_ date: Date) {
        mutate { $0.transactionDate = date }
    }

    func setTotalAmount(_ amount: Int64) {
        guard !isCustomSplit else { return }
        mutate { $0.totalAmount = max(0, amount) }
    }

    func setTitle(_ title: String) {
        mutate { $0.title = title }
    }

    func setType(_ type: TransactionType) {
        mutate { $0.type = type }
    }

    func setSplitMethod(_ method: SplitMethod) {
        mutate { $0.splitMethod = method }
    }

    func setIncludesUser(_ includesUser: Bool) {
        mutate { $0.includesUser = includesUser }
    }

    func setShare(participantID: UUID, amount: Int64) {
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].shareAmount = max(0, amount)
        }
    }

    func removeParticipant(id: UUID) {
        mutate { draft in
            guard draft.flow == .splitBill else { return }
            draft.participants.removeAll { $0.id == id }
        }
        suggestions[id] = nil
    }

    // MARK: - Contacts

    func requestPicker(_ request: ContactPickerRequest) async {
        switch await contacts.access() {
        case .authorized:
            pickerRequest = request
        case .denied:
            alert = .contactsAccessRequired
        case .notDetermined:
            if await contacts.requestAccess() == .authorized {
                pickerRequest = request
                await refreshSuggestions()
            } else {
                alert = .contactsAccessRequired
            }
        }
    }

    func confirmSuggestion(participantID: UUID) {
        guard let contact = suggestions[participantID] else { return }
        link(participantID: participantID, to: contact)
    }

    func handlePicked(_ picked: [ContactRef], for request: ContactPickerRequest) {
        switch request {
        case .link(let participantID, _):
            guard let contact = picked.first else { return }
            link(participantID: participantID, to: contact)
        case .addParticipants:
            addParticipants(picked)
        }
    }

    // MARK: - Save / delete / close

    func save() async {
        guard !isSaving, draft != nil else { return }
        isSaving = true
        defer { isSaving = false }
        hasAttemptedSave = true
        await flushPendingEdits()
        guard let current = draft else { return }
        let currentIssues = DraftValidator.issues(for: current)
        guard currentIssues.isEmpty else {
            alert = .incomplete(messages: Self.distinctMessages(currentIssues))
            return
        }
        do {
            try await repository.confirmDraft(current)
            savedSnapshot = current
            didSave = true
            didFinish = true
        } catch {
            alert = .saveFailed(message: error.localizedDescription)
        }
    }

    func delete() async {
        await awaitPendingAutosave()
        do {
            try await repository.deleteDraft(id: draftID)
            didFinish = true
        } catch {
            alert = .deleteFailed(message: error.localizedDescription)
        }
    }

    /// Waits for queued automatic saves, then writes any edit that is still unsaved. Never confirms.
    /// Called when the screen disappears.
    func flushPendingEdits() async {
        await awaitPendingAutosave()
        await persistIfDirty()
    }

    /// Waits until every queued automatic save has finished.
    func awaitPendingAutosave() async {
        await autosaveTask?.value
    }

    // MARK: - Split math

    static func recalculate(_ draft: inout TransactionDraft) {
        switch draft.flow {
        case .personal:
            for index in draft.participants.indices {
                draft.participants[index].shareAmount = draft.totalAmount
            }
        case .splitBill:
            if (draft.splitMethod ?? .equal) == .custom {
                if let total = SplitCalculationEngine.customTotal(draft.participants.map(\.shareAmount)) {
                    draft.totalAmount = total
                }
            } else {
                let shares = SplitCalculationEngine.shares(
                    total: draft.totalAmount,
                    friendCount: draft.participants.count,
                    includesUser: draft.includesUser
                )
                for (index, share) in shares.enumerated() {
                    draft.participants[index].shareAmount = share
                }
            }
        }
    }

    // MARK: - Private

    private func mutate(_ change: (inout TransactionDraft) -> Void) {
        guard var updated = draft else { return }
        change(&updated)
        Self.recalculate(&updated)
        draft = updated
        scheduleAutosave()
    }

    /// Queues a save after any save already in flight, so writes never overlap.
    private func scheduleAutosave() {
        let previous = autosaveTask
        autosaveTask = Task { [weak self] in
            await previous?.value
            await self?.persistIfDirty()
        }
    }

    private func persistIfDirty() async {
        guard !didFinish, loadState == .loaded, let current = draft, current != savedSnapshot else { return }
        isAutosaving = true
        defer { isAutosaving = false }
        do {
            try await repository.saveDraft(current)
            savedSnapshot = current
            autosaveErrorMessage = nil
        } catch {
            autosaveErrorMessage = Self.autosaveFailedMessage
        }
    }

    private func link(participantID: UUID, to contact: ContactRef) {
        guard let current = draft else { return }
        let usedByAnother = current.participants.contains {
            $0.id != participantID && $0.contactIdentifier == contact.identifier
        }
        guard !usedByAnother else {
            alert = .duplicateContact
            return
        }
        mutate { draft in
            guard let index = draft.participants.firstIndex(where: { $0.id == participantID }) else { return }
            draft.participants[index].name = contact.displayName
            draft.participants[index].contactIdentifier = contact.identifier
        }
        suggestions[participantID] = nil
    }

    private func addParticipants(_ picked: [ContactRef]) {
        guard let current = draft, current.flow == .splitBill else { return }
        var usedIdentifiers = Set(current.participants.compactMap(\.contactIdentifier))
        var additions: [TransactionParticipant] = []
        var foundDuplicate = false
        for contact in picked {
            guard !usedIdentifiers.contains(contact.identifier) else {
                foundDuplicate = true
                continue
            }
            usedIdentifiers.insert(contact.identifier)
            additions.append(TransactionParticipant(
                name: contact.displayName,
                contactIdentifier: contact.identifier,
                shareAmount: 0
            ))
        }
        mutate { $0.participants.append(contentsOf: additions) }
        if foundDuplicate {
            alert = .duplicateContact
        }
    }

    private func refreshSuggestions() async {
        guard let current = draft, await contacts.access() == .authorized else {
            suggestions = [:]
            return
        }
        var result: [UUID: ContactRef] = [:]
        for participant in current.participants where !Self.isLinked(participant) {
            let name = participant.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let matches = await contacts.search(name: name)
            if matches.count == 1 {
                result[participant.id] = matches[0]
            }
        }
        suggestions = result
    }

    private static func isLinked(_ participant: TransactionParticipant) -> Bool {
        let identifier = participant.contactIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !identifier.isEmpty
    }

    private static func distinctMessages(_ issues: [DraftValidationIssue]) -> [String] {
        var seen = Set<String>()
        return issues.map(\.message).filter { seen.insert($0).inserted }
    }
}
```

- [ ] **Step 5: Keep the view compiling**

In `UcapHutang/Features/Review/Views/ReviewDetailView.swift`, replace:
```swift
                Task { await viewModel.persistEditsIfNeeded() }
```
with:
```swift
                Task { await viewModel.flushPendingEdits() }
```
(Task 7 replaces this file completely; this one-line change keeps Task 5 buildable.)

- [ ] **Step 6: Run the full suite**

Run the test command.
Expected: `Executed 125 tests, with 0 failures`, `TEST SUCCEEDED`.
Also run `grep -rn "persistEditsIfNeeded" UcapHutang UcapHutangTests || echo "none"` → `none`.

- [ ] **Step 7: Commit**

```bash
git add UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift UcapHutang/Features/Review/Views/ReviewDetailView.swift UcapHutangTests/ReviewDetailViewModelTests.swift UcapHutangTests/TestDoubles/SpyTransactionRepository.swift
git commit -m "feat: autosave every Review edit to the draft (from PR #3)"
```

---

### Task 6: Add a person by name, notes, and the save status sentence (ViewModel)

**Files:**
- Modify: `UcapHutangTests/ReviewDetailViewModelTests.swift`
- Modify: `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`

**Interfaces:**
- Consumes: Task 5 `ReviewDetailViewModel` (`mutate`, `awaitPendingAutosave()`), `ReviewAlert.duplicateContact`.
- Produces on `ReviewDetailViewModel`:
  - `var newParticipantName: String` (bound to the "Nama orang baru" field)
  - `func addParticipantFromName() async` — Split Bill only. Trims the name; ignores empty; if any participant already has that name (trimmed, case-insensitive) sets `alert = .duplicateContact` and keeps the typed text; otherwise appends an unlinked participant, recalculates shares, autosaves, clears `newParticipantName`, and refreshes contact suggestions.
  - `func setNotes(_ notes: String)` — empty string stores `nil`.
  - `var saveStatusMessage: String` — `"Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat."` when the draft has at least one participant and all are linked; otherwise `"Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat."`.

- [ ] **Step 1: Write the failing tests**

Add these methods at the end of `ReviewDetailViewModelTests` (before the final `}`):
```swift
    func testAddingAPersonByNameAddsAnUnlinkedParticipantAndRecomputesShares() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]))
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [45_000])

        viewModel.newParticipantName = "  Ari "
        await viewModel.addParticipantFromName()

        XCTAssertEqual(viewModel.draft!.participants.map(\.name), ["Satria", "Ari"])
        XCTAssertNil(viewModel.draft!.participants[1].contactIdentifier)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
        XCTAssertEqual(viewModel.newParticipantName, "")
        await viewModel.awaitPendingAutosave()
        XCTAssertEqual(spy.saveDraftCallCount, 1)
    }

    func testAddingANameAlreadyInTheNoteShowsDuplicateAlert() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]))

        viewModel.newParticipantName = "satria"
        await viewModel.addParticipantFromName()

        XCTAssertEqual(viewModel.alert, .duplicateContact)
        XCTAssertEqual(viewModel.draft!.participants.count, 1)
        XCTAssertEqual(viewModel.newParticipantName, "satria")
        await viewModel.awaitPendingAutosave()
        XCTAssertEqual(spy.saveDraftCallCount, 0)
    }

    func testNotesAreSavedAndClearedWhenEmpty() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setNotes("Bayar minggu depan")
        await viewModel.awaitPendingAutosave()
        var stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.notes, "Bayar minggu depan")

        viewModel.setNotes("")
        await viewModel.awaitPendingAutosave()
        stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored?.notes)
    }

    func testSaveStatusMessageFollowsContactLinks() async throws {
        let (viewModel, _) = try await makeViewModel(seed: personalDraft())
        XCTAssertEqual(viewModel.saveStatusMessage, "Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat.")

        let participantID = viewModel.draft!.participants[0].id
        viewModel.handlePicked([satria], for: .link(participantID: participantID, prefill: "Satria"))

        XCTAssertEqual(viewModel.saveStatusMessage, "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat.")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/ReviewDetailViewModelTests`.
Expected: build FAILS with `value of type 'ReviewDetailViewModel' has no member 'newParticipantName'` (and `addParticipantFromName`, `setNotes`, `saveStatusMessage`).

- [ ] **Step 3: Implement**

In `UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift`:

1. Directly below `var isConfirmingDelete = false`, add:
```swift
    /// Text of the "Nama orang baru" field (Split Bill).
    var newParticipantName = ""
```

2. In `// MARK: - Derived state`, directly after the `userShare` property, add:
```swift
    var saveStatusMessage: String {
        guard let draft, !draft.participants.isEmpty, draft.participants.allSatisfy(Self.isLinked) else {
            return "Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat."
        }
        return "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat."
    }
```

3. In `// MARK: - Field edits`, directly after `setType(_:)`, add:
```swift
    func setNotes(_ notes: String) {
        mutate { $0.notes = notes.isEmpty ? nil : notes }
    }
```

4. In `// MARK: - Field edits`, directly after `removeParticipant(id:)`, add:
```swift
    /// Split Bill: adds a person typed by name. They stay unlinked until connected to a contact.
    func addParticipantFromName() async {
        guard let current = draft, current.flow == .splitBill else { return }
        let name = newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let alreadyAdded = current.participants.contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame
        }
        guard !alreadyAdded else {
            alert = .duplicateContact
            return
        }
        mutate { $0.participants.append(TransactionParticipant(name: name, shareAmount: 0)) }
        newParticipantName = ""
        await refreshSuggestions()
    }
```

- [ ] **Step 4: Run the full suite**

Run the test command.
Expected: `Executed 129 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Features/Review/ViewModels/ReviewDetailViewModel.swift UcapHutangTests/ReviewDetailViewModelTests.swift
git commit -m "feat: add people by name, notes and save status to Review (from PR #3)"
```

---

### Task 7: Review screen UI for autosave status, add by name, notes and save status

**Files:**
- Modify (full replacement): `UcapHutang/Features/Review/Views/ReviewDetailView.swift`

**Interfaces:**
- Consumes (from Tasks 5–6): `isAutosaving`, `autosaveErrorMessage`, `flushPendingEdits()`, `newParticipantName`, `addParticipantFromName()`, `setNotes(_:)`, `saveStatusMessage`.
- Produces: no new API.

Layout, top to bottom: autosave status card → Waktu → Nominal → Deskripsi → Jenis / Metode bagi (+ "Saya ikut dihitung") → Orang (cards; Split Bill adds the "Nama orang baru" field + "Tambah", then "+ Pilih dari kontak") → Catatan Opsional → split summary (Split Bill) → save status sentence → "Simpan Catatan" → "Hapus catatan ini".

Approved copy used here: "Tersimpan otomatis sebagai draft", "Kamu bisa menutup halaman ini dan melanjutkan nanti dari tab Review.", "Menyimpan perubahan…", "Nama orang baru", "Tambah", "+ Pilih dari kontak", "Catatan Opsional", "Tambahkan catatan jika diperlukan". The autosave failure text comes from `autosaveErrorMessage` (PR #3 copy).

- [ ] **Step 1: Replace the view**

Replace the whole content of `UcapHutang/Features/Review/Views/ReviewDetailView.swift` with:
```swift
import SwiftUI

struct ReviewDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ReviewDetailViewModel
    private let repository: any TransactionRepository
    private let contacts: any ContactsProviding

    init(draftID: UUID, repository: any TransactionRepository, contacts: any ContactsProviding) {
        self.repository = repository
        self.contacts = contacts
        _viewModel = State(initialValue: ReviewDetailViewModel(
            draftID: draftID,
            repository: repository,
            contacts: contacts
        ))
    }

    var body: some View {
        content
            .navigationTitle("Review Catatan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .onDisappear {
                Task { await viewModel.flushPendingEdits() }
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
            .sensoryFeedback(.success, trigger: viewModel.didSave)
            .sheet(item: $viewModel.pickerRequest) { request in
                ReviewContactPickerSheet(request: request, contacts: contacts, repository: repository) { picked in
                    viewModel.handlePicked(picked, for: request)
                }
            }
            .confirmationDialog("Hapus catatan ini?", isPresented: $viewModel.isConfirmingDelete, titleVisibility: .visible) {
                Button("Hapus", role: .destructive) {
                    Task { await viewModel.delete() }
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Catatan dan transkripnya akan dihapus permanen.")
            }
            .alert(
                viewModel.alert?.title ?? "",
                isPresented: Binding(
                    get: { viewModel.alert != nil },
                    set: { if !$0 { viewModel.alert = nil } }
                ),
                presenting: viewModel.alert
            ) { alert in
                switch alert {
                case .incomplete:
                    Button("Periksa Lagi", role: .cancel) {}
                case .contactsAccessRequired:
                    Button("Buka Pengaturan") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Nanti", role: .cancel) {}
                case .duplicateContact, .saveFailed, .deleteFailed:
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                if let message = alert.message {
                    Text(message)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .notFound:
            ContentUnavailableView("Catatan ini tidak ditemukan.", systemImage: "doc.questionmark")
        case .loaded:
            if let draft = viewModel.draft {
                form(draft)
            }
        }
    }

    private func form(_ draft: TransactionDraft) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                autosaveStatus

                field("Waktu") {
                    DatePicker(
                        "Waktu",
                        selection: Binding(
                            get: { viewModel.draft?.transactionDate ?? Date() },
                            set: { viewModel.setTransactionDate($0) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "id_ID"))
                }

                field("Nominal") {
                    if viewModel.isCustomSplit {
                        Text(draft.totalAmount.rupiahFormatted)
                            .font(.body.weight(.semibold))
                    } else {
                        TextField(
                            "Nominal",
                            value: Binding(
                                get: { viewModel.draft?.totalAmount ?? 0 },
                                set: { viewModel.setTotalAmount($0) }
                            ),
                            format: .number
                        )
                        .keyboardType(.numberPad)
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                }

                field("Deskripsi") {
                    TextField(
                        "Deskripsi transaksi",
                        text: Binding(
                            get: { viewModel.draft?.title ?? "" },
                            set: { viewModel.setTitle($0) }
                        )
                    )
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
                }

                if draft.flow == .personal {
                    field("Jenis") {
                        Picker("Jenis", selection: Binding(
                            get: { viewModel.draft?.type ?? .unknown },
                            set: { viewModel.setType($0) }
                        )) {
                            Text("Utang").tag(TransactionType.hutang)
                            Text("Piutang").tag(TransactionType.piutang)
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    field("Metode bagi") {
                        Picker("Metode bagi", selection: Binding(
                            get: { viewModel.draft?.splitMethod ?? .equal },
                            set: { viewModel.setSplitMethod($0) }
                        )) {
                            Text("Bagi Rata").tag(SplitMethod.equal)
                            Text("Custom").tag(SplitMethod.custom)
                        }
                        .pickerStyle(.segmented)
                    }
                    if !viewModel.isCustomSplit {
                        Toggle("Saya ikut dihitung", isOn: Binding(
                            get: { viewModel.draft?.includesUser ?? true },
                            set: { viewModel.setIncludesUser($0) }
                        ))
                        .font(.body)
                    }
                }

                peopleSection(draft)

                field("Catatan Opsional") {
                    TextField(
                        "Tambahkan catatan jika diperlukan",
                        text: Binding(
                            get: { viewModel.draft?.notes ?? "" },
                            set: { viewModel.setNotes($0) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .frame(minHeight: 44)
                }

                if draft.flow == .splitBill {
                    splitSummary(draft)
                }

                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var autosaveStatus: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if viewModel.isAutosaving {
                    ProgressView()
                } else if viewModel.autosaveErrorMessage != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.destructive)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.receivable)
                }
            }
            .accessibilityHidden(true)

            if viewModel.isAutosaving {
                Text("Menyimpan perubahan…")
                    .font(.subheadline.weight(.semibold))
            } else if let errorMessage = viewModel.autosaveErrorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.destructive)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tersimpan otomatis sebagai draft")
                        .font(.subheadline.weight(.semibold))
                    Text("Kamu bisa menutup halaman ini dan melanjutkan nanti dari tab Review.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func peopleSection(_ draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Orang")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(draft.participants) { participant in
                if draft.flow == .splitBill {
                    participantBlock(participant, in: draft)
                        .contextMenu {
                            Button("Hapus dari catatan", role: .destructive) {
                                viewModel.removeParticipant(id: participant.id)
                            }
                        }
                        .accessibilityAction(named: "Hapus dari catatan") {
                            viewModel.removeParticipant(id: participant.id)
                        }
                } else {
                    participantBlock(participant, in: draft)
                }
            }

            if draft.flow == .splitBill {
                addByNameRow

                Button {
                    Task { await viewModel.requestPicker(.addParticipants) }
                } label: {
                    Text("+ Pilih dari kontak")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }

    private var addByNameRow: some View {
        HStack(spacing: 8) {
            TextField("Nama orang baru", text: $viewModel.newParticipantName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit {
                    Task { await viewModel.addParticipantFromName() }
                }
                .frame(minHeight: 44)

            Button("Tambah") {
                Task { await viewModel.addParticipantFromName() }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
            .disabled(viewModel.newParticipantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func participantBlock(_ participant: TransactionParticipant, in draft: TransactionDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SmartContactCardView(
                name: participant.name,
                state: viewModel.cardState(for: participant),
                showsRequiredMarker: viewModel.showsRequiredMarker(for: participant.id),
                onLink: { openPicker(for: participant) },
                onConfirmSuggestion: { viewModel.confirmSuggestion(participantID: participant.id) },
                onChooseOther: { openPicker(for: participant) },
                onChange: { openPicker(for: participant) }
            )
            if draft.flow == .splitBill {
                SplitParticipantRow(
                    amount: participant.shareAmount,
                    isEditable: viewModel.isCustomSplit,
                    onAmountChange: { viewModel.setShare(participantID: participant.id, amount: $0) }
                )
                .padding(.horizontal, 14)
            }
        }
    }

    private func openPicker(for participant: TransactionParticipant) {
        Task {
            await viewModel.requestPicker(.link(participantID: participant.id, prefill: participant.name))
        }
    }

    private func splitSummary(_ draft: TransactionDraft) -> some View {
        VStack(spacing: 8) {
            summaryRow("Bagian teman", viewModel.friendsTotal)
            if !viewModel.isCustomSplit && draft.includesUser {
                summaryRow("Bagian kamu", viewModel.userShare)
            }
            Divider()
            summaryRow("Total transaksi", draft.totalAmount)
                .font(.body.weight(.semibold))
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }

    private func summaryRow(_ label: String, _ amount: Int64) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(amount.rupiahFormatted)
        }
        .font(.body)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Text(viewModel.saveStatusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.save() }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Text("Simpan Catatan")
                            .font(.headline)
                    }
                }
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.primary)
            .disabled(viewModel.isSaving)

            Button("Hapus catatan ini", role: .destructive) {
                viewModel.isConfirmingDelete = true
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.top, 12)
    }
}

#if DEBUG
private final class PreviewContactsProvider: ContactsProviding {
    func access() async -> ContactsAccess { .authorized }
    func requestAccess() async -> ContactsAccess { .authorized }
    func search(name: String) async -> [ContactRef] {
        [ContactRef(identifier: "preview-dito", displayName: "Andito Rizkika", phoneNumber: "+62 812")]
    }
    func contacts(withIdentifiers ids: [String]) async -> [ContactRef] { [] }
}

#Preview("Review Personal") {
    let draft = TransactionDraft(
        flow: .personal,
        type: .hutang,
        title: "Pinjam buat makan siang",
        totalAmount: 150_000,
        participants: [TransactionParticipant(name: "Dito", shareAmount: 150_000)],
        rawTranscript: "Pinjam 150 ribu ke Dito buat makan siang"
    )
    return NavigationStack {
        ReviewDetailView(
            draftID: draft.id,
            repository: InMemoryTransactionRepository(seedDrafts: [draft]),
            contacts: PreviewContactsProvider()
        )
    }
}
#endif
```

- [ ] **Step 2: Run the full suite**

Run the test command.
Expected: `Executed 129 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add UcapHutang/Features/Review/Views/ReviewDetailView.swift
git commit -m "feat: show autosave status, add-by-name, notes and save status on Review"
```

---

### Task 8: "Buat Kontak Baru" in the contact picker

**Files:**
- Modify: `UcapHutangTests/ReviewContactPickerViewModelTests.swift`
- Modify: `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift`
- Create: `UcapHutang/Features/Review/Components/NewContactView.swift`
- Modify (full replacement): `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift`

**Interfaces:**
- Consumes: `ContactRef(identifier:displayName:phoneNumber:)`, `ContactsProviding.search(name:)`.
- Produces on `ReviewContactPickerViewModel`:
  - `var newContactName: String` — trimmed `searchQuery`, or the trimmed initial query when the search field is empty. Used to prefill the system New Contact form.
  - `func didCreateContact(_ contact: ContactRef) async -> Bool` — single selection: returns `true` (the sheet hands the contact back and closes). Multiple selection: adds the contact to `selectedContacts` (once), sets `searchQuery` to the contact's name, refreshes `deviceContacts`, returns `false` (the sheet stays open).
- Produces: `struct NewContactView: UIViewControllerRepresentable` with `init(suggestedName: String, onComplete: @escaping (ContactRef?) -> Void)`; `onComplete(nil)` on cancel.
- Both Review (`ReviewDetailView`) and Riwayat (`PersonLedgerDetailView`) already present `ReviewContactPickerSheet`, so both get the button without further changes.

Approved copy (from PR #3): row "Buat Kontak Baru"; empty state title "Tidak menemukan kontak?", description "Kamu tetap bisa membuat kontak baru dari nama yang sedang dicari.", button "Buat Kontak".

- [ ] **Step 1: Write the failing tests**

Add these methods at the end of `ReviewContactPickerViewModelTests` (before the final `}`):
```swift
    func testCreatedContactIsHandedBackInSingleSelection() async {
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: false,
            initialQuery: "Dito",
            contacts: FakeContactsProvider(contacts: [ari]),
            repository: InMemoryTransactionRepository()
        )
        XCTAssertEqual(viewModel.newContactName, "Dito")
        viewModel.searchQuery = "Andito "
        XCTAssertEqual(viewModel.newContactName, "Andito")
        viewModel.searchQuery = ""
        XCTAssertEqual(viewModel.newContactName, "Dito")

        let dito = ContactRef(identifier: "c-dito", displayName: "Andito Rizkika", phoneNumber: nil)
        let shouldClose = await viewModel.didCreateContact(dito)

        XCTAssertTrue(shouldClose)
        XCTAssertEqual(viewModel.selectedContacts, [])
    }

    func testCreatedContactIsSelectedAndShownInMultipleSelection() async {
        let provider = FakeContactsProvider(contacts: [ari, budi])
        let viewModel = ReviewContactPickerViewModel(
            allowsMultipleSelection: true,
            initialQuery: "",
            contacts: provider,
            repository: InMemoryTransactionRepository()
        )
        viewModel.toggle(ari)
        let dina = ContactRef(identifier: "c-dina", displayName: "Dina Putri", phoneNumber: nil)
        provider.allContacts.append(dina) // The system form saved it to Contacts.

        let shouldClose = await viewModel.didCreateContact(dina)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(viewModel.selectedContacts, [ari, dina])
        XCTAssertEqual(viewModel.searchQuery, "Dina Putri")
        XCTAssertEqual(viewModel.deviceContacts, [dina])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:UcapHutangTests/ReviewContactPickerViewModelTests`.
Expected: build FAILS with `value of type 'ReviewContactPickerViewModel' has no member 'newContactName'` (and `didCreateContact`).

- [ ] **Step 3: Implement the ViewModel changes**

In `UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift`:

1. Directly below `private(set) var selectedContacts: [ContactRef] = []`, add:
```swift
    private let initialQuery: String
```

2. In `init`, directly below `self.searchQuery = initialQuery`, add:
```swift
        self.initialQuery = initialQuery
```

3. Directly after the `hasNoResults` property, add:
```swift
    /// Name used to prefill the system "New Contact" form.
    var newContactName: String {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? initialQuery.trimmingCharacters(in: .whitespacesAndNewlines) : query
    }
```

4. Directly after `isSelected(_:)`, add:
```swift
    /// Returns `true` when the sheet should hand `contact` back and close.
    /// In multiple selection the new contact is selected and shown, and the sheet stays open.
    func didCreateContact(_ contact: ContactRef) async -> Bool {
        guard allowsMultipleSelection else { return true }
        if !selectedContacts.contains(contact) {
            selectedContacts.append(contact)
        }
        searchQuery = contact.displayName
        await search()
        return false
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the same command as Step 2.
Expected: all `ReviewContactPickerViewModelTests` pass, `TEST SUCCEEDED`.

- [ ] **Step 5: Add the system New Contact form wrapper**

Create `UcapHutang/Features/Review/Components/NewContactView.swift` (adapted from PR #3 `NativeContactCreationView`, returning `ContactRef`):
```swift
import SwiftUI
import Contacts
import ContactsUI

/// The system "New Contact" form, prefilled with a name. Calls `onComplete` with the saved contact, or `nil` when cancelled.
struct NewContactView: UIViewControllerRepresentable {
    let suggestedName: String
    let onComplete: (ContactRef?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()
        let components = PersonNameComponentsFormatter().personNameComponents(from: suggestedName)
        contact.givenName = components?.givenName ?? suggestedName
        contact.middleName = components?.middleName ?? ""
        contact.familyName = components?.familyName ?? ""

        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onComplete: (ContactRef?) -> Void

        init(onComplete: @escaping (ContactRef?) -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            guard let contact else {
                onComplete(nil)
                return
            }
            let formatted = CNContactFormatter.string(from: contact, style: .fullName)
                ?? "\(contact.givenName) \(contact.familyName)"
            onComplete(ContactRef(
                identifier: contact.identifier,
                displayName: formatted.trimmingCharacters(in: .whitespacesAndNewlines),
                phoneNumber: contact.phoneNumbers.first?.value.stringValue
            ))
        }
    }
}
```

- [ ] **Step 6: Replace the picker sheet**

Replace the whole content of `UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift` with:
```swift
import SwiftUI

struct ReviewContactPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReviewContactPickerViewModel
    @State private var isCreatingContact = false
    @State private var createdContact: ContactRef?
    private let onPick: ([ContactRef]) -> Void

    init(
        allowsMultipleSelection: Bool,
        initialQuery: String,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        _viewModel = State(initialValue: ReviewContactPickerViewModel(
            allowsMultipleSelection: allowsMultipleSelection,
            initialQuery: initialQuery,
            contacts: contacts,
            repository: repository
        ))
        self.onPick = onPick
    }

    init(
        request: ContactPickerRequest,
        contacts: any ContactsProviding,
        repository: any TransactionRepository,
        onPick: @escaping ([ContactRef]) -> Void
    ) {
        self.init(
            allowsMultipleSelection: request.allowsMultipleSelection,
            initialQuery: request.initialQuery,
            contacts: contacts,
            repository: repository,
            onPick: onPick
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.hasNoResults {
                    Section {
                        Button {
                            isCreatingContact = true
                        } label: {
                            createContactRow
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !viewModel.filteredRecentContacts.isEmpty {
                    Section("Kontak yang pernah dicatat") {
                        ForEach(viewModel.filteredRecentContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
                if !viewModel.deviceContacts.isEmpty {
                    Section("Kontak di iPhone") {
                        ForEach(viewModel.deviceContacts, id: \.identifier) { contact in
                            row(contact)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if viewModel.hasNoResults {
                    ContentUnavailableView {
                        Label("Tidak menemukan kontak?", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("Kamu tetap bisa membuat kontak baru dari nama yang sedang dicari.")
                    } actions: {
                        Button("Buat Kontak") {
                            isCreatingContact = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Hubungkan ke kontak")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cari kontak"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                if viewModel.allowsMultipleSelection {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Selesai") {
                            onPick(viewModel.selectedContacts)
                            dismiss()
                        }
                        .disabled(viewModel.selectedContacts.isEmpty)
                    }
                }
            }
            .task { await viewModel.load() }
            .task(id: viewModel.searchQuery) { await viewModel.search() }
            .sheet(isPresented: $isCreatingContact, onDismiss: finishContactCreation) {
                NewContactView(suggestedName: viewModel.newContactName) { contact in
                    createdContact = contact
                    isCreatingContact = false
                }
            }
        }
    }

    private var createContactRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Buat Kontak Baru")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Spacer(minLength: 8)
            if !viewModel.newContactName.isEmpty {
                Text(viewModel.newContactName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func row(_ contact: ContactRef) -> some View {
        Button {
            if viewModel.allowsMultipleSelection {
                viewModel.toggle(contact)
            } else {
                onPick([contact])
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    if let phone = contact.phoneNumber {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if viewModel.allowsMultipleSelection {
                    Image(systemName: viewModel.isSelected(contact) ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(viewModel.isSelected(contact) ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewModel.allowsMultipleSelection && viewModel.isSelected(contact) ? .isSelected : [])
    }

    /// Runs after the New Contact sheet is fully dismissed, so this sheet can close safely.
    private func finishContactCreation() {
        guard let contact = createdContact else { return }
        createdContact = nil
        Task {
            if await viewModel.didCreateContact(contact) {
                onPick([contact])
                dismiss()
            }
        }
    }
}
```

- [ ] **Step 7: Run the full suite**

Run the test command.
Expected: `Executed 131 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add UcapHutang/Features/Review/ViewModels/ReviewContactPickerViewModel.swift UcapHutang/Features/Review/Components/NewContactView.swift UcapHutang/Features/Review/Views/ReviewContactPickerSheet.swift UcapHutangTests/ReviewContactPickerViewModelTests.swift
git commit -m "feat: create a new contact from the contact picker (from PR #3)"
```

---

### Task 9: Port the PR #3 Catat microphone animations

**Files:**
- Modify: `UcapHutang/Domain/Protocols/SpeechTranscribing.swift`
- Modify: `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift`
- Modify (full replacement): `UcapHutang/Features/Catat/Views/CatatView.swift`

**Interfaces:**
- Consumes: `SpeechRecognizer.audioLevel` (already exists in `fix/all` as `private(set) var audioLevel: Float`), `CatatViewModel.speech/isListening/isProcessing/stageHeadline/recordButtonLabel`.
- Produces: `SpeechTranscribing.audioLevel: Float { get }` (0…1 while listening, 0 otherwise).

Behavior kept from `fix/all`: close + "Tersimpan ke Review" banner after saving, Dynamic Type sized control (`@ScaledMetric`, max 320 pt), 44 pt targets, Reduce Motion, permission message, server footnote.
Ported from PR #3: `mic.fill` idle icon, audio-reactive glow, three expanding rings, wobbling mic while listening, "Ulangi" pinned at the bottom with a shadow. PR #3 hardcoded font sizes are replaced by text styles, and ring/glow sizes scale with the control.

- [ ] **Step 1: Expose the audio level through the protocol**

In `UcapHutang/Domain/Protocols/SpeechTranscribing.swift`, directly below `var liveTranscript: String { get }`, add:
```swift
    /// Smoothed microphone loudness from 0 (silent) to 1 while listening; 0 otherwise.
    var audioLevel: Float { get }
```

In `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift`, directly below `var liveTranscript: String`, add:
```swift
    var audioLevel: Float = 0
```

Run:
```bash
grep -rn ": SpeechTranscribing" UcapHutang UcapHutangTests
```
Expected: exactly two conformers, `SpeechRecognizer` and `FakeSpeechTranscriber`. If there are more, add `var audioLevel: Float { 0 }` to each before continuing.

- [ ] **Step 2: Replace CatatView**

Replace the whole content of `UcapHutang/Features/Catat/Views/CatatView.swift` with:
```swift
import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var scaledControlDiameter: CGFloat = 250
    @State private var viewModel: CatatViewModel
    private let router: AppRouter

    let flow: CaptureFlow

    init(flow: CaptureFlow, container: AppContainer) {
        self.flow = flow
        self.router = container.router
        _viewModel = State(initialValue: CatatViewModel(
            flow: flow,
            speech: container.makeSpeechTranscriber(),
            capture: container.capture
        ))
    }

    /// Grows with Dynamic Type but never wider than a phone screen allows.
    private var controlDiameter: CGFloat {
        min(scaledControlDiameter, 320)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Button {
                        Task { await viewModel.handleMicTap() }
                    } label: {
                        recordingControl
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessing)
                    .accessibilityLabel(viewModel.recordButtonLabel)
                    .accessibilityValue(viewModel.stageHeadline)

                    if viewModel.isListening {
                        Text(viewModel.speech.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.speech.liveTranscript)
                            .font(viewModel.speech.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                            .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
                    } else if !viewModel.isProcessing {
                        Text("Tip: \(tipText)")
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }

                    if let permissionMessage = viewModel.permissionMessage {
                        VStack(spacing: 8) {
                            Text(permissionMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Buka Pengaturan") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                        .frame(maxWidth: 300)
                    }

                    if !viewModel.speech.usesOnDeviceRecognition {
                        Text("Ucapan diproses oleh server Apple.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isListening {
                    Button("Ulangi") {
                        Task { await viewModel.restartRecording() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 44)
                    .background(AppColors.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppColors.border))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(flow.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear { viewModel.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { viewModel.cancel(); dismiss() }
                }
            }
            .alert("Gagal Memproses", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: {
                Text(viewModel.errorMessage ?? "Terjadi kesalahan.")
            }
            .onChange(of: viewModel.speech.state) { _, state in
                viewModel.handleSpeechStateChange(state)
            }
            .onChange(of: viewModel.savedDraftID) { _, draftID in
                guard draftID != nil else { return }
                router.showSavedToReviewBanner()
                AccessibilityNotification.Announcement("Tersimpan ke Review").post()
                dismiss()
            }
        }
    }

    private var recordingControl: some View {
        ZStack {
            if viewModel.isListening {
                ListeningMicAura(speech: viewModel.speech, diameter: controlDiameter, reduceMotion: reduceMotion)
            }
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
            if viewModel.isProcessing || viewModel.speech.state == .finalizing {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColors.textPrimary)
            } else {
                VStack(spacing: 12) {
                    Group {
                        if viewModel.isListening {
                            SpeakingMicIcon(reduceMotion: reduceMotion)
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.largeTitle.weight(.bold))
                        }
                    }
                    .accessibilityHidden(true)
                    Text(viewModel.isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(AppColors.textPrimary)
                .padding(24)
            }
        }
        .frame(width: controlDiameter, height: controlDiameter)
        .contentShape(Circle())
    }

    private var tipText: String {
        flow == .personal
            ? "Dito pinjam 50 ribu buat beli bensin"
            : "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
    }
}

/// Glow and rings shown while listening (from PR #3).
/// Reads `audioLevel` here so only this view redraws on every audio buffer.
private struct ListeningMicAura: View {
    let speech: any SpeechTranscribing
    let diameter: CGFloat
    let reduceMotion: Bool

    @State private var isRinging = false

    /// PR #3 tuned these sizes for a 250 pt control; scale them with the Dynamic Type control size.
    private var scale: CGFloat { diameter / 250 }

    var body: some View {
        let level = CGFloat(speech.audioLevel)
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppColors.accent.opacity(0.24), Color.purple.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 30 * scale,
                        endRadius: 82 * scale
                    )
                )
                .frame(width: (136 + level * 46) * scale, height: (136 + level * 46) * scale)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.18, dampingFraction: 0.55),
                    value: level
                )

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.85), Color.purple.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 108 * scale, height: 108 * scale)
                    .scaleEffect(reduceMotion ? 1.12 : (isRinging ? 1.72 : 0.92))
                    .opacity(reduceMotion ? 0.42 : (isRinging ? 0 : 0.68))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: 1.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.4),
                        value: isRinging
                    )
            }
        }
        .frame(width: 176 * scale, height: 176 * scale)
        .accessibilityHidden(true)
        .onAppear { isRinging = true }
    }
}

/// Mic icon that wobbles while listening (from PR #3). Still when Reduce Motion is on.
private struct SpeakingMicIcon: View {
    let reduceMotion: Bool

    @State private var isSpeaking = false

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
            .rotationEffect(.degrees(reduceMotion ? 0 : (isSpeaking ? 4 : -4)))
            .scaleEffect(reduceMotion ? 1 : (isSpeaking ? 1.08 : 0.96))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.16).repeatForever(autoreverses: true),
                value: isSpeaking
            )
            .onAppear { isSpeaking = true }
    }
}
```

- [ ] **Step 3: Run the full suite**

Run the test command.
Expected: `Executed 131 tests, with 0 failures`, `TEST SUCCEEDED`.
Also run `grep -n "font(.system(size" UcapHutang/Features/Catat/Views/CatatView.swift || echo "none"` → `none`.

- [ ] **Step 4: Commit**

```bash
git add UcapHutang/Domain/Protocols/SpeechTranscribing.swift UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift UcapHutang/Features/Catat/Views/CatatView.swift
git commit -m "feat: animate the Catat microphone while listening (from PR #3)"
```

---

### Task 10: Spec addendum and final verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (append at the end of the file)

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: no code.

- [ ] **Step 1: Append the addendum to the spec**

Append this text to the end of `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md`:
```markdown

## 16. Addendum — merge with main (PR #3 `feature/catat`), approved 2026-09-13

Where this addendum conflicts with earlier sections, the addendum wins.

- **Merge:** `origin/main` merged into `fix/all`; `fix/all` code is the base. PR #3's `ReviewView`, `ReviewViewModel`, `ContactPickerSheet`, `userShareAmount` and its Split Bill rules are not used. Split Bill rules stay as in §6.6.
- **Schema:** no new version. Stores created by PR #3 builds are not migrated (not needed).
- **Widget:** the "Catat Cepat" widget (`UcapHutangWidget` target) and `ucaphutang://catat` stay. The link selects the Catat tab and closes open sheets. The alert "Catat lebih cepat dengan Widget?" is shown once (`@AppStorage("hasAskedAboutCatatWidget")`), only when the notification primer (§10.4) is not on screen; "Ya, Mau" opens the widget instructions.
- **Wording:** UI uses "Utang"; the Catat flow title is "Utang / Piutang".
- **Catat (§7.4):** the record control uses `mic.fill`, an audio-reactive glow, three rings and a wobbling mic while listening, with "Ulangi" pinned at the bottom. Reduce Motion stops the motion. The flow chooser keeps the `fix/all` design.
- **Review fields (§8.2):** add "Catatan Opsional" under the people list. Split Bill can add a person by typing a name ("Nama orang baru" + "Tambah"); that person must still be linked before saving. The contact picker button is "+ Pilih dari kontak".
- **Review save (§8.5):** every edit is saved to the draft automatically (never confirmed). A status card shows "Tersimpan otomatis sebagai draft" / "Kamu bisa menutup halaman ini dan melanjutkan nanti dari tab Review.", "Menyimpan perubahan…", or "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini.". Above "Simpan Catatan": "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat." or "Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat.".
- **Validation (§6):** `DraftValidator` rejects the names `teman`, `teman 1`, `teman 2`, `orang`, `orang a`, `orang b` with "Ganti nama orang terkait / peserta ke-N dengan nama yang bisa kamu kenali.".
- **Linking (§8.4, §9):** the contact picker offers "Buat Kontak Baru", which opens the system New Contact form prefilled with the searched name. In single selection the new contact is linked immediately; in multiple selection it is selected and the picker stays open.
- **Repository:** saving a draft updates participant rows in place and deletes removed ones.
```

- [ ] **Step 2: Final automated verification**

Run each command and compare with the expected output:
```bash
git status --short
```
Expected: only `M docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md`, `?? .xcede/`, `?? xcede.yml`.

```bash
grep -rn 'Hutang Personal\|"Hutang"\|Catat hutang' UcapHutang UcapHutangWidget || echo "none"
grep -rn 'userShareAmount\|ReviewViewModel\b\|ContactMatchCandidate\|ContactResolutionService\|AppPrimaryButtonStyle' UcapHutang UcapHutangTests UcapHutangWidget || echo "none"
grep -rn '<<<<<<<\|>>>>>>>' UcapHutang UcapHutangTests UcapHutangWidget || echo "none"
```
Expected: `none` three times.

Run the test command.
Expected: `Executed 131 tests, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md
git commit -m "docs: record decisions from merging PR #3 into fix/all"
```

- [ ] **Step 4: Manual QA on the simulator (developer checkpoint)**

Hand this checklist to the developer and wait for their results. Do not push.

1. Fresh install (delete the app from the simulator first, then run): the notification primer appears; after "Izinkan Notifikasi" or "Nanti Saja", the alert "Catat lebih cepat dengan Widget?" appears. "Ya, Mau" opens "Widget Catat Cepat". Relaunch: neither appears again.
2. With the app running, run `xcrun simctl openurl booted ucaphutang://catat`: the Catat tab is selected and any open sheet closes.
3. Home Screen → add the "Catat Cepat" widget → tap it: the app opens on the Catat tab.
4. Catat: while listening the glow grows with your voice, rings pulse, the mic wobbles, and "Ulangi" sits at the bottom. Turn on Settings → Accessibility → Motion → Reduce Motion: the glow and rings stay still.
5. Review a personal draft: change Deskripsi, then close with "Tutup" and reopen: the change is kept, the status card says "Tersimpan otomatis sebagai draft", and the draft is still in the Review list (not in Riwayat).
6. Review a Split Bill draft: type "Ari" → "Tambah": Ari appears unlinked and shares are recalculated. Typing an existing name shows "Orang ini sudah ada di catatan.".
7. Type "Teman" as a participant name via add-by-name, link everyone else, tap "Simpan Catatan": the alert lists "Ganti nama peserta ke-N dengan nama yang bisa kamu kenali." (and the unlinked message).
8. "Catatan Opsional": type a note, close, reopen: the note is kept; after saving, the Riwayat entry shows the note.
9. Contact picker from Review "Hubungkan": search a name that does not exist → "Buat Kontak" → save the form: the person is linked. From "+ Pilih dari kontak": create a contact → it appears checked and the picker stays open.
10. Riwayat → an unlinked legacy person → "Hubungkan" → "Buat Kontak Baru" works the same way.
11. Everything in Dark Mode and at the largest Dynamic Type size: no clipped text on Review, picker, widget instructions, Catat.

After the developer approves, they push `fix/all` and re-check that PR #4 shows no conflicts.

