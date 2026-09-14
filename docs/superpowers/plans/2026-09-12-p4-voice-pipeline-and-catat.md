# P4 — Three-Stage Voice Pipeline and "Saved to Review" Catat Flow Implementation Plan

> **For agentic workers (Gemini 3.7 Flash):** Execute the tasks in order, one step at a time. Steps use checkbox (`- [ ]`) syntax — tick each one as you finish it. When a step gives a complete file, replace the **entire** file with it. Never skip a "run the test and confirm it fails" step. If an actual result differs from the "Expected" text, stop and report instead of improvising.

**Goal:** Split voice capture into three testable stages (Speech → LLM extraction → mapping + save), prefer on-device speech recognition, and change Catat so that after processing the sheet closes, the user is told the note is in the Review tab, and the Review tab shows a pending badge.

**Architecture:** Stage 1 `SpeechRecognizer` conforms to the domain protocol `SpeechTranscribing` and throws typed permission errors. Stage 2 `QwenDraftExtractionService` (protocol `DraftExtracting`, in `Services/AI`) returns an `ExtractionResult`. Stage 3 is the pure `DraftMapper` plus `VoiceCapturePipeline`, which conforms to the domain protocol `VoiceCapturing`. `CatatViewModel` depends only on `SpeechTranscribing` and `VoiceCapturing`. An `@Observable AppRouter` owns the selected tab and the "saved" banner.

**Tech Stack:** Swift 5 mode, SwiftUI (iOS 26.5), Observation, Speech, AVFoundation, MLX Qwen (unchanged), XCTest.

**Spec:** `docs/superpowers/specs/2026-09-12-voice-draft-remediation-design.md` (§3, §5.2, §5.4, §7, §14 P4).

## Global Constraints

- Work on branch `fix/all`. **P0–P3 must be finished** and the developer must have confirmed the P3 checklist. Suite at start: 78 tests passing.
- **Never stage `.xcede/` or `xcede.yml`.** Always `git add` explicit paths (or `git mv`/`git rm`); never `git add -A`, `git add .`, or `git commit -a`.
- Do not edit `UcapHutang.xcodeproj/project.pbxproj`.
- Build settings in effect (do not change): `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_VERSION = 5.0`.
- ViewModels import only `Foundation` and `Observation`.
- **Do not change** `QwenPromptBuilder`'s prompt text, `MLXQwenClient`, `QwenOutputDecoder`, or `TransactionDateResolver` behavior. Move/split code only as instructed.
- The Catat flow must never open the review form after this phase.
- Reminder scheduling is **not** part of this phase (P6 adds it to the pipeline).
- Exact user-facing copy (Indonesian) for this phase:

  | Where | Text |
  |-------|------|
  | Microphone denied | `Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan.` |
  | Speech denied | `Izin Speech Recognition ditolak. Buka Pengaturan untuk mengaktifkan.` |
  | Speech restricted | `Speech Recognition dibatasi pada perangkat ini.` |
  | Speech not determined (existing) | `Izin Speech Recognition belum ditentukan.` |
  | Speech status unknown (existing) | `Status otorisasi Speech Recognition tidak dikenal.` |
  | Audio session failure (existing) | `Gagal menginisialisasi AVAudioSession: <detail>` |
  | Audio engine failure (existing) | `Gagal memulai AudioEngine: <detail>` |
  | Recognition failure while listening (existing) | `Speech recognition error: <detail>` |
  | Settings button under a permission message | `Buka Pengaturan` |
  | Server-based speech footnote | `Ucapan diproses oleh server Apple.` |
  | Empty transcript (existing) | `Suara tidak terdeteksi. Silakan coba lagi.` |
  | Processing error alert title (existing) | `Gagal Memproses` |
  | Record button VoiceOver label | `Mulai merekam` / `Berhenti merekam` |
  | Stage headlines (existing, also the VoiceOver value) | `Mendengarkan...`, `Menyelesaikan transkrip...`, `Menganalisis data...` |
  | Banner text / button | `Tersimpan ke Review` / `Lihat` |
  | VoiceOver announcement | `Tersimpan ke Review` |

- Full test command:

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

- Single test class command (replace `<Class>`):

  ```bash
  xcodebuild test -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:UcapHutangTests/<Class> 2>&1 | grep -E "Test Case '.*' (passed|failed)|error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED"
  ```

Expected test totals: start 78 → Task 1: 84 → Task 2: 86 → Task 3: 87 → Task 4: 93.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `UcapHutang/Services/AI/DraftExtracting.swift` | Create | `ExtractionResult` + `DraftExtracting` (stage 2 contract). |
| `UcapHutang/Services/AI/QwenDraftExtractionService.swift` | Create | Stage 2 implementation. |
| `UcapHutang/Services/Capture/DraftMapper.swift` | Create | Stage 3 pure mapping. |
| `UcapHutang/Domain/Protocols/VoiceCapturing.swift` | Create | What Catat depends on. |
| `UcapHutang/Services/Capture/VoiceCapturePipeline.swift` | Create | Orchestrates stages 2–3 + save. |
| `UcapHutang/App/AppRouter.swift` | Create | Selected tab + saved banner; owns `AppTab`. |
| `UcapHutang/Domain/Models/SpeechModels.swift` | Create | `SpeechRecognizerState`, `SpeechPermissionError`, `SpeechRecognitionError`. |
| `UcapHutang/Domain/Protocols/SpeechTranscribing.swift` | Create | Stage 1 contract. |
| `UcapHutang/Services/Speech/SpeechRecognizer.swift` | Replace | Conforms to `SpeechTranscribing`; on-device when supported. |
| `UcapHutang/Services/AI/DraftExtractionService.swift` | Rename + trim | Becomes `QwenPromptBuilder.swift` (request, client protocol, errors, prompt). |
| `UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift` | Replace | Uses `SpeechTranscribing` + `VoiceCapturing`. |
| `UcapHutang/Features/Catat/Views/CatatView.swift` | Replace | Close + banner; permission message; footnote; accessibility. |
| `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift` | Replace | Shows the banner. |
| `UcapHutang/Features/Catat/Components/SavedToReviewBanner.swift` | Create | Banner view. |
| `UcapHutang/App/AppContainer.swift` | Replace | `extraction`, `capture`, `router`, `makeSpeechTranscriber`. |
| `UcapHutang/App/RootTabView.swift` | Replace | Router selection, Review badge, success haptic. |
| `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift` | Create | Test double. |
| `UcapHutangTests/TestDoubles/SpyVoiceCapture.swift` | Create | Test double. |
| `UcapHutangTests/DraftMapperTests.swift` | Create | Stage 3 tests. |
| `UcapHutangTests/QwenDraftExtractionServiceTests.swift` | Create | Stage 2 test. |
| `UcapHutangTests/VoiceCapturePipelineTests.swift` | Create | Pipeline tests. |
| `UcapHutangTests/AppRouterTests.swift` | Create | Router test. |
| `UcapHutangTests/SpeechPermissionErrorTests.swift` | Create | Copy test. |
| `UcapHutangTests/CatatViewModelTests.swift` | Create | Catat behavior. |
| `UcapHutangTests/QwenMigrationTests.swift` | Modify | Use the new stage 2 + 3 APIs. |
| `UcapHutangTests/CoreFlowTests.swift` | Modify | Use the new stage 2 + 3 APIs. |

---

### Task 1: Stage 2 contract, Qwen extraction service, and stage 3 mapper

**Files:**
- Create: `UcapHutang/Services/AI/DraftExtracting.swift`
- Create: `UcapHutang/Services/AI/QwenDraftExtractionService.swift`
- Create: `UcapHutang/Services/Capture/DraftMapper.swift`
- Create: `UcapHutangTests/DraftMapperTests.swift`
- Create: `UcapHutangTests/QwenDraftExtractionServiceTests.swift`

**Interfaces:**
- Consumes (existing, unchanged): `CaptureOutput`, `PersonalCaptureOutput(direction:person:amount:title:notes:transactionTime:)`, `SplitCaptureOutput(basis:title:totalAmount:splitCount:includesUser:receivables:notes:transactionTime:)`, `SplitReceivable(person:item:amount:)`, `QwenOutputDecoder.decode(_:for:transcript:)`, `TransactionDateResolver.resolve(transcript:modelComponents:referenceNow:)` (returns a value with `.date` and `.warning`), `QwenPromptBuilder.prompt(for: DraftExtractionRequest)`, `LLMClientProtocol`, `DraftExtractionError`, `SplitCalculationEngine.shares(total:friendCount:includesUser:)`, `.customTotal(_:)`.
- Produces:
  - `struct ExtractionResult: Sendable { let output: CaptureOutput; let resolvedDate: Date; let rawModelResponse: String?; let warnings: [String] }`
  - `protocol DraftExtracting: Sendable { func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult }`
  - `struct QwenDraftExtractionService: DraftExtracting` with `init(llmClient: (any LLMClientProtocol)? = nil)`.
  - `enum DraftMapper { static func makeDraft(flow: CaptureFlow, transcript: String, result: ExtractionResult, createdAt: Date) -> TransactionDraft }`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/DraftMapperTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class DraftMapperTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
    private let resolvedDate = Date(timeIntervalSince1970: 1_799_990_000)

    func testPersonalOutputMapsEveryField() {
        let result = ExtractionResult(
            output: .personal(PersonalCaptureOutput(
                direction: .piutang,
                person: "Satria",
                amount: 20_000,
                title: "kopi",
                notes: "bayar besok",
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: "{\"direction\":\"piutang\"}",
            warnings: ["peringatan"]
        )

        let draft = DraftMapper.makeDraft(flow: .personal, transcript: "Satria ngutang 20 ribu", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.status, .needsReview)
        XCTAssertEqual(draft.flow, .personal)
        XCTAssertEqual(draft.type, .piutang)
        XCTAssertEqual(draft.title, "kopi")
        XCTAssertEqual(draft.totalAmount, 20_000)
        XCTAssertNil(draft.splitMethod)
        XCTAssertTrue(draft.includesUser)
        XCTAssertEqual(draft.participants.map(\.name), ["Satria"])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [20_000])
        XCTAssertNil(draft.participants.first?.contactIdentifier)
        XCTAssertEqual(draft.notes, "bayar besok")
        XCTAssertEqual(draft.rawTranscript, "Satria ngutang 20 ribu")
        XCTAssertEqual(draft.rawModelResponse, "{\"direction\":\"piutang\"}")
        XCTAssertEqual(draft.reviewWarnings, ["peringatan"])
        XCTAssertEqual(draft.transactionDate, resolvedDate)
        XCTAssertEqual(draft.createdAt, createdAt)
    }

    func testPersonalMissingFieldsStayEmptyAndUnknown() {
        let result = ExtractionResult(
            output: .personal(PersonalCaptureOutput(direction: .unknown, person: nil, amount: nil, title: nil, notes: nil, transactionTime: nil)),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .personal, transcript: "catat ini dulu", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.totalAmount, 0)
        XCTAssertEqual(draft.participants.map(\.name), [""])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [0])
    }

    func testEqualSplitIncludesUserAndIgnoresModelSplitCount() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .equal,
                title: "tiket konser",
                totalAmount: 800_000,
                splitCount: 5,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: nil, amount: nil),
                    SplitReceivable(person: "Arif", item: nil, amount: nil),
                    SplitReceivable(person: "Ros", item: nil, amount: nil)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "tiket konser", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.type, .splitBill)
        XCTAssertEqual(draft.splitMethod, .equal)
        XCTAssertTrue(draft.includesUser)
        XCTAssertEqual(draft.totalAmount, 800_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [200_000, 200_000, 200_000])
        XCTAssertTrue(draft.participants.allSatisfy { $0.contactIdentifier == nil })
    }

    func testCustomSplitTotalIsTheSumWhenEveryAmountIsPresent() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .custom,
                title: "makan",
                totalAmount: 100_000,
                splitCount: 3,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: "nasi", amount: 30_000),
                    SplitReceivable(person: "Ari", item: "sate", amount: 50_000)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "makan", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.splitMethod, .custom)
        XCTAssertEqual(draft.totalAmount, 80_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [30_000, 50_000])
        XCTAssertEqual(draft.participants.map(\.itemTitle), ["nasi", "sate"])
    }

    func testCustomSplitKeepsModelTotalWhenAnAmountIsMissing() {
        let result = ExtractionResult(
            output: .split(SplitCaptureOutput(
                basis: .custom,
                title: "makan",
                totalAmount: 100_000,
                splitCount: 3,
                includesUser: true,
                receivables: [
                    SplitReceivable(person: "Satria", item: nil, amount: 30_000),
                    SplitReceivable(person: "Ari", item: nil, amount: nil)
                ],
                notes: nil,
                transactionTime: nil
            )),
            resolvedDate: resolvedDate,
            rawModelResponse: nil,
            warnings: []
        )

        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: "makan", result: result, createdAt: createdAt)

        XCTAssertEqual(draft.totalAmount, 100_000)
        XCTAssertEqual(draft.participants.map(\.shareAmount), [30_000, 0])
    }
}
```

Create `UcapHutangTests/QwenDraftExtractionServiceTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class QwenDraftExtractionServiceTests: XCTestCase {
    func testBlankTranscriptThrows() async {
        let service = QwenDraftExtractionService()
        do {
            _ = try await service.extract(flow: .personal, transcript: "   ", referenceDate: Date())
            XCTFail("A blank transcript must throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Ekstraksi gagal: Transkrip kosong.")
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the full test command.

Expected: `error:` lines such as `cannot find 'ExtractionResult' in scope`, `cannot find 'DraftMapper' in scope`, `cannot find 'QwenDraftExtractionService' in scope`; `** TEST FAILED **`.

- [ ] **Step 3: Implement stage 2**

Create `UcapHutang/Services/AI/DraftExtracting.swift`:

```swift
import Foundation

/// Output of stage 2 (transcript → structured data).
struct ExtractionResult: Sendable {
    let output: CaptureOutput
    let resolvedDate: Date
    let rawModelResponse: String?
    let warnings: [String]
}

/// Stage 2 contract. Lives in Services/AI because `ExtractionResult` exposes the decoder's `CaptureOutput`.
protocol DraftExtracting: Sendable {
    /// Throws only for a blank transcript. Model or decoder failures fall back to an empty
    /// structure and add a warning, so the user can still complete the draft in Review.
    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult
}
```

Create `UcapHutang/Services/AI/QwenDraftExtractionService.swift`:

```swift
import Foundation

struct QwenDraftExtractionService: DraftExtracting {
    private let llmClient: (any LLMClientProtocol)?

    init(llmClient: (any LLMClientProtocol)? = nil) {
        self.llmClient = llmClient
    }

    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw DraftExtractionError.extractionFailed("Transkrip kosong.")
        }

        var warnings: [String] = []
        var rawResponse: String?
        if let llmClient {
            let request = DraftExtractionRequest(flow: flow, transcript: cleanTranscript, referenceDate: referenceDate)
            do {
                rawResponse = try await llmClient.generate(prompt: QwenPromptBuilder.prompt(for: request))
            } catch {
                warnings.append(error.localizedDescription)
            }
        }

        let output: CaptureOutput
        if let rawResponse {
            do {
                output = try QwenOutputDecoder.decode(rawResponse, for: flow, transcript: cleanTranscript)
            } catch {
                warnings.append(error.localizedDescription)
                output = try QwenOutputDecoder.decode("{}", for: flow, transcript: cleanTranscript)
            }
        } else {
            output = try QwenOutputDecoder.decode("{}", for: flow, transcript: cleanTranscript)
        }

        let temporalComponents: TransactionTemporalComponents?
        switch output {
        case .personal(let personal):
            temporalComponents = personal.transactionTime
            if let warning = personal.warning { warnings.append(warning) }
        case .split(let split):
            temporalComponents = split.transactionTime
            if let warning = split.warning { warnings.append(warning) }
        }

        let resolved = TransactionDateResolver.resolve(
            transcript: cleanTranscript,
            modelComponents: temporalComponents,
            referenceNow: referenceDate
        )
        if let warning = resolved.warning { warnings.append(warning) }

        return ExtractionResult(
            output: output,
            resolvedDate: resolved.date,
            rawModelResponse: rawResponse,
            warnings: warnings
        )
    }
}
```

- [ ] **Step 4: Implement stage 3 mapper**

Create `UcapHutang/Services/Capture/DraftMapper.swift`:

```swift
import Foundation

/// Stage 3: structured output → a `needsReview` draft. Pure and deterministic.
enum DraftMapper {
    static func makeDraft(flow: CaptureFlow, transcript: String, result: ExtractionResult, createdAt: Date) -> TransactionDraft {
        switch result.output {
        case .personal(let personal):
            let type: TransactionType
            switch personal.direction {
            case .hutang: type = .hutang
            case .piutang: type = .piutang
            case .unknown: type = .unknown
            }
            let amount = personal.amount ?? 0
            return TransactionDraft(
                status: .needsReview,
                flow: .personal,
                type: type,
                transactionDate: result.resolvedDate,
                title: personal.title ?? "",
                totalAmount: amount,
                splitMethod: nil,
                includesUser: true,
                participants: [
                    TransactionParticipant(name: personal.person ?? "", contactIdentifier: nil, shareAmount: amount)
                ],
                notes: personal.notes,
                rawTranscript: transcript,
                rawModelResponse: result.rawModelResponse,
                reviewWarnings: result.warnings,
                createdAt: createdAt
            )

        case .split(let split):
            let method: SplitMethod = split.basis == .custom ? .custom : .equal
            var participants = split.receivables.map { receivable in
                TransactionParticipant(
                    name: receivable.person,
                    contactIdentifier: nil,
                    shareAmount: receivable.amount ?? 0,
                    itemTitle: receivable.item
                )
            }
            var totalAmount = split.totalAmount ?? 0

            switch method {
            case .equal:
                let shares = SplitCalculationEngine.shares(
                    total: totalAmount,
                    friendCount: participants.count,
                    includesUser: true
                )
                for (index, share) in shares.enumerated() {
                    participants[index].shareAmount = share
                }
            case .custom:
                let everyAmountPresent = !split.receivables.isEmpty
                    && split.receivables.allSatisfy { ($0.amount ?? 0) > 0 }
                if everyAmountPresent,
                   let sum = SplitCalculationEngine.customTotal(participants.map(\.shareAmount)) {
                    totalAmount = sum
                }
            }

            return TransactionDraft(
                status: .needsReview,
                flow: .splitBill,
                type: .splitBill,
                transactionDate: result.resolvedDate,
                title: split.title ?? "",
                totalAmount: totalAmount,
                splitMethod: method,
                includesUser: true,
                participants: participants,
                notes: split.notes,
                rawTranscript: transcript,
                rawModelResponse: result.rawModelResponse,
                reviewWarnings: result.warnings,
                createdAt: createdAt
            )
        }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run the single test class command with `<Class>` = `DraftMapperTests`. Expected: `Executed 5 tests, with 0 failures`.

Run the single test class command with `<Class>` = `QwenDraftExtractionServiceTests`. Expected: `Executed 1 test, with 0 failures`.

Run the full test command. Expected: `Executed 84 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add UcapHutang/Services/AI/DraftExtracting.swift UcapHutang/Services/AI/QwenDraftExtractionService.swift UcapHutang/Services/Capture/DraftMapper.swift UcapHutangTests/DraftMapperTests.swift UcapHutangTests/QwenDraftExtractionServiceTests.swift
git commit -m "feat: split voice extraction into stage 2 service and stage 3 mapper"
```

---

### Task 2: `VoiceCapturing` and `VoiceCapturePipeline`

**Files:**
- Create: `UcapHutang/Domain/Protocols/VoiceCapturing.swift`
- Create: `UcapHutang/Services/Capture/VoiceCapturePipeline.swift`
- Create: `UcapHutangTests/VoiceCapturePipelineTests.swift`

**Interfaces:**
- Consumes: `DraftExtracting`, `ExtractionResult`, `DraftMapper` (Task 1); `TransactionRepository` (P2).
- Produces:
  - `protocol VoiceCapturing: Sendable { func process(flow: CaptureFlow, transcript: String) async throws -> UUID }`
  - `final class VoiceCapturePipeline: VoiceCapturing` with `init(extraction: any DraftExtracting, repository: any TransactionRepository, now: @escaping () -> Date = Date.init)`.

- [ ] **Step 1: Write the failing tests**

Create `UcapHutangTests/VoiceCapturePipelineTests.swift`:

```swift
import XCTest
@testable import UcapHutang

private struct StubDraftExtractor: DraftExtracting {
    let result: ExtractionResult

    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        result
    }
}

private struct FailingDraftExtractor: DraftExtracting {
    func extract(flow: CaptureFlow, transcript: String, referenceDate: Date) async throws -> ExtractionResult {
        throw DraftExtractionError.extractionFailed("Transkrip kosong.")
    }
}

@MainActor
final class VoiceCapturePipelineTests: XCTestCase {
    func testProcessSavesTheMappedDraftAndReturnsItsID() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let repository = InMemoryTransactionRepository()
        let extractor = StubDraftExtractor(result: ExtractionResult(
            output: .personal(PersonalCaptureOutput(direction: .piutang, person: "Satria", amount: 20_000, title: "kopi", notes: nil, transactionTime: nil)),
            resolvedDate: now,
            rawModelResponse: nil,
            warnings: []
        ))
        let pipeline = VoiceCapturePipeline(extraction: extractor, repository: repository, now: { now })

        let draftID = try await pipeline.process(flow: .personal, transcript: "  Satria ngutang 20 ribu  ")

        let stored = await repository.draft(id: draftID)
        XCTAssertEqual(stored?.status, .needsReview)
        XCTAssertEqual(stored?.rawTranscript, "Satria ngutang 20 ribu")
        XCTAssertEqual(stored?.participants.first?.name, "Satria")
        XCTAssertEqual(stored?.createdAt, now)
    }

    func testExtractionFailureSavesNothing() async throws {
        let repository = InMemoryTransactionRepository()
        let pipeline = VoiceCapturePipeline(extraction: FailingDraftExtractor(), repository: repository)

        do {
            _ = try await pipeline.process(flow: .personal, transcript: "")
            XCTFail("Expected the extraction error to propagate")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Ekstraksi gagal: Transkrip kosong.")
        }

        let count = await repository.pendingDraftCount()
        XCTAssertEqual(count, 0)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `VoiceCapturePipelineTests`.

Expected: `error: cannot find 'VoiceCapturePipeline' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/Domain/Protocols/VoiceCapturing.swift`:

```swift
import Foundation

/// Turns a finished transcript into a saved `needsReview` draft and returns its ID.
protocol VoiceCapturing: Sendable {
    func process(flow: CaptureFlow, transcript: String) async throws -> UUID
}
```

Create `UcapHutang/Services/Capture/VoiceCapturePipeline.swift`:

```swift
import Foundation

final class VoiceCapturePipeline: VoiceCapturing {
    private let extraction: any DraftExtracting
    private let repository: any TransactionRepository
    private let now: () -> Date

    init(
        extraction: any DraftExtracting,
        repository: any TransactionRepository,
        now: @escaping () -> Date = Date.init
    ) {
        self.extraction = extraction
        self.repository = repository
        self.now = now
    }

    func process(flow: CaptureFlow, transcript: String) async throws -> UUID {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let referenceDate = now()
        // Stage 2: transcript → structured output.
        let result = try await extraction.extract(flow: flow, transcript: cleanTranscript, referenceDate: referenceDate)
        // Stage 3: structured output → draft → SwiftData.
        let draft = DraftMapper.makeDraft(flow: flow, transcript: cleanTranscript, result: result, createdAt: referenceDate)
        try await repository.saveDraft(draft)
        return draft.id
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `VoiceCapturePipelineTests`. Expected: `Executed 2 tests, with 0 failures`.

Run the full test command. Expected: `Executed 86 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/Domain/Protocols/VoiceCapturing.swift UcapHutang/Services/Capture/VoiceCapturePipeline.swift UcapHutangTests/VoiceCapturePipelineTests.swift
git commit -m "feat: add VoiceCapturePipeline that saves mapped drafts"
```

---

### Task 3: `AppRouter`

**Files:**
- Create: `UcapHutang/App/AppRouter.swift`
- Modify: `UcapHutang/App/RootTabView.swift` (remove the `AppTab` enum, which moves to `AppRouter.swift`)
- Create: `UcapHutangTests/AppRouterTests.swift`

**Interfaces:**
- Produces:
  - `enum AppTab: Hashable { case review, capture, ledger }` (moved, unchanged).
  - `@Observable final class AppRouter` — `var selectedTab: AppTab` (default `.review`), `private(set) var savedBannerID: UUID?`, `func showSavedToReviewBanner()`, `func dismissSavedBanner()`, `func openReviewFromBanner()`.

- [ ] **Step 1: Write the failing test**

Create `UcapHutangTests/AppRouterTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class AppRouterTests: XCTestCase {
    func testSavedBannerOpensTheReviewTabAndClears() {
        let router = AppRouter()
        router.selectedTab = .capture

        router.showSavedToReviewBanner()
        XCTAssertNotNil(router.savedBannerID)

        router.openReviewFromBanner()
        XCTAssertEqual(router.selectedTab, .review)
        XCTAssertNil(router.savedBannerID)

        router.showSavedToReviewBanner()
        router.dismissSavedBanner()
        XCTAssertNil(router.savedBannerID)
        XCTAssertEqual(router.selectedTab, .review)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the single test class command with `<Class>` = `AppRouterTests`.

Expected: `error: cannot find 'AppRouter' in scope`, `** TEST FAILED **`.

- [ ] **Step 3: Implement**

Create `UcapHutang/App/AppRouter.swift`:

```swift
import Foundation
import Observation

enum AppTab: Hashable {
    case review
    case capture
    case ledger
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .review
    /// Non-nil while the "Tersimpan ke Review" banner is visible. A new ID restarts the banner timer.
    private(set) var savedBannerID: UUID?

    func showSavedToReviewBanner() {
        savedBannerID = UUID()
    }

    func dismissSavedBanner() {
        savedBannerID = nil
    }

    func openReviewFromBanner() {
        selectedTab = .review
        savedBannerID = nil
    }
}
```

In `UcapHutang/App/RootTabView.swift`, delete exactly this block (it now lives in `AppRouter.swift`):

```swift
enum AppTab: Hashable {
    case review
    case capture
    case ledger
}
```

- [ ] **Step 4: Run to verify it passes**

Run the single test class command with `<Class>` = `AppRouterTests`. Expected: `Executed 1 test, with 0 failures`.

Run the full test command. Expected: `Executed 87 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add UcapHutang/App/AppRouter.swift UcapHutang/App/RootTabView.swift UcapHutangTests/AppRouterTests.swift
git commit -m "feat: add AppRouter for tab selection and saved banner"
```

---

### Task 4: Speech protocol, Catat close + banner, badge, and old API removal

**Files:**
- Create: `UcapHutang/Domain/Models/SpeechModels.swift`
- Create: `UcapHutang/Domain/Protocols/SpeechTranscribing.swift`
- Replace: `UcapHutang/Services/Speech/SpeechRecognizer.swift`
- Rename + trim: `UcapHutang/Services/AI/DraftExtractionService.swift` → `UcapHutang/Services/AI/QwenPromptBuilder.swift`
- Replace: `UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift`
- Replace: `UcapHutang/Features/Catat/Views/CatatView.swift`
- Replace: `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift`
- Create: `UcapHutang/Features/Catat/Components/SavedToReviewBanner.swift`
- Replace: `UcapHutang/App/AppContainer.swift`
- Replace: `UcapHutang/App/RootTabView.swift`
- Create: `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift`
- Create: `UcapHutangTests/TestDoubles/SpyVoiceCapture.swift`
- Create: `UcapHutangTests/SpeechPermissionErrorTests.swift`
- Create: `UcapHutangTests/CatatViewModelTests.swift`
- Modify: `UcapHutangTests/QwenMigrationTests.swift`
- Modify: `UcapHutangTests/CoreFlowTests.swift`

These changes are one task because the old `SpeechRecognizer` API, `HybridQwenExtractionService`, `AppContainer.extractionService`, and `CatatViewModel` all reference each other.

**Interfaces:**
- Consumes: `AppRouter`, `AppTab` (Task 3); `VoiceCapturing`, `VoiceCapturePipeline` (Task 2); `QwenDraftExtractionService`, `DraftMapper` (Task 1); `ContactsProviding`, `SystemContactsProvider`, `ReviewListView`, `ReviewDetailView` (P3); `TransactionRepository.pendingDraftCount()` (P2).
- Produces (P5–P7 rely on these):
  - `enum SpeechRecognizerState: Equatable, Sendable { case idle, listening, finalizing, failed(String) }`
  - `enum SpeechPermissionError: LocalizedError, Equatable { case microphoneDenied, speechDenied, restricted }`
  - `enum SpeechRecognitionError: LocalizedError, Equatable { case authorizationNotDetermined, authorizationUnknown, audioSession(String), audioEngine(String) }`
  - `@MainActor protocol SpeechTranscribing: AnyObject { var state: SpeechRecognizerState { get }; var liveTranscript: String { get }; var usesOnDeviceRecognition: Bool { get }; func start() async throws; func finish() async -> String; func cancel() }`
  - `@Observable final class SpeechRecognizer: SpeechTranscribing` (also exposes `audioLevel: Float`).
  - `@Observable final class CatatViewModel` — `init(flow: CaptureFlow, speech: any SpeechTranscribing, capture: any VoiceCapturing)`; `flow`, `speech`, `isStartingRecording`, `isProcessing`, `savedDraftID`, `permissionMessage`, `errorMessage`, `isListening`, `stageHeadline`, `recordButtonLabel`; `handleMicTap() async`, `restartRecording() async`, `handleSpeechStateChange(_:)`, `cancel()`.
  - `@Observable final class AppContainer` — `repository`, `extraction: any DraftExtracting`, `capture: any VoiceCapturing`, `contacts: any ContactsProviding`, `router: AppRouter`, `makeSpeechTranscriber: @MainActor () -> any SpeechTranscribing`, `storageErrorMessage`; `init(repository:extraction:contacts:router:makeSpeechTranscriber:storageErrorMessage:)` (the last three have defaults).
  - `struct CatatFlowChooserView: View` — `init(router: AppRouter, onSelect: @escaping (CaptureFlow) -> Void)`.
  - `struct SavedToReviewBanner: View` — `init(bannerID: UUID, onOpen: @escaping () -> Void, onTimeout: @escaping () -> Void)`.
  - Removed: `DraftExtractionService` protocol, `HybridQwenExtractionService`, `AppContainer.extractionService`, `SpeechRecognizer.startRecording(onTranscript:)`, `finishRecording()`, `cancelRecording()`, `isRecording`, `errorMessage`.

- [ ] **Step 1: Write the failing tests and migrate the old extraction tests**

Create `UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift`:

```swift
import Foundation
@testable import UcapHutang

@MainActor
final class FakeSpeechTranscriber: SpeechTranscribing {
    var state: SpeechRecognizerState = .idle
    var liveTranscript: String
    var usesOnDeviceRecognition = true
    var startError: Error?
    var finalTranscript: String
    private(set) var cancelCallCount = 0

    init(finalTranscript: String = "", liveTranscript: String = "", startError: Error? = nil) {
        self.finalTranscript = finalTranscript
        self.liveTranscript = liveTranscript
        self.startError = startError
    }

    func start() async throws {
        if let startError { throw startError }
        state = .listening
    }

    func finish() async -> String {
        state = .idle
        return finalTranscript
    }

    func cancel() {
        cancelCallCount += 1
        state = .idle
    }
}
```

Create `UcapHutangTests/TestDoubles/SpyVoiceCapture.swift`:

```swift
import Foundation
@testable import UcapHutang

@MainActor
final class SpyVoiceCapture: VoiceCapturing {
    struct Call: Equatable {
        let flow: CaptureFlow
        let transcript: String
    }

    var result: Result<UUID, Error> = .success(UUID())
    private(set) var calls: [Call] = []

    func process(flow: CaptureFlow, transcript: String) async throws -> UUID {
        calls.append(Call(flow: flow, transcript: transcript))
        return try result.get()
    }
}
```

Create `UcapHutangTests/SpeechPermissionErrorTests.swift`:

```swift
import XCTest
@testable import UcapHutang

final class SpeechPermissionErrorTests: XCTestCase {
    func testPermissionMessagesPointToPengaturan() {
        XCTAssertEqual(SpeechPermissionError.microphoneDenied.errorDescription, "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertEqual(SpeechPermissionError.speechDenied.errorDescription, "Izin Speech Recognition ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertEqual(SpeechPermissionError.restricted.errorDescription, "Speech Recognition dibatasi pada perangkat ini.")
    }
}
```

Create `UcapHutangTests/CatatViewModelTests.swift`:

```swift
import XCTest
@testable import UcapHutang

@MainActor
final class CatatViewModelTests: XCTestCase {
    func testSuccessfulCaptureReportsTheSavedDraft() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "Satria ngutang 20 ribu")
        let capture = SpyVoiceCapture()
        let savedID = UUID()
        capture.result = .success(savedID)
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        XCTAssertTrue(viewModel.isListening)
        XCTAssertEqual(viewModel.recordButtonLabel, "Berhenti merekam")

        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.savedDraftID, savedID)
        XCTAssertEqual(capture.calls, [SpyVoiceCapture.Call(flow: .personal, transcript: "Satria ngutang 20 ribu")])
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testEmptyTranscriptShowsNoSpeechMessage() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "   ", liveTranscript: "")
        let capture = SpyVoiceCapture()
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.errorMessage, "Suara tidak terdeteksi. Silakan coba lagi.")
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertNil(viewModel.savedDraftID)
    }

    func testFallsBackToLiveTranscriptWhenFinalIsEmpty() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "", liveTranscript: "Dito pinjam 50 ribu")
        let capture = SpyVoiceCapture()
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(capture.calls.map(\.transcript), ["Dito pinjam 50 ribu"])
    }

    func testMicrophoneDeniedShowsInlinePermissionMessage() async {
        let speech = FakeSpeechTranscriber(startError: SpeechPermissionError.microphoneDenied)
        let viewModel = CatatViewModel(flow: .splitBill, speech: speech, capture: SpyVoiceCapture())

        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.permissionMessage, "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan.")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isListening)
    }

    func testCaptureFailureShowsTheErrorAndSavesNothing() async {
        let speech = FakeSpeechTranscriber(finalTranscript: "Satria ngutang 20 ribu")
        let capture = SpyVoiceCapture()
        capture.result = .failure(DraftExtractionError.extractionFailed("model error"))
        let viewModel = CatatViewModel(flow: .personal, speech: speech, capture: capture)

        await viewModel.handleMicTap()
        await viewModel.handleMicTap()

        XCTAssertEqual(viewModel.errorMessage, "Ekstraksi gagal: model error")
        XCTAssertNil(viewModel.savedDraftID)
    }
}
```

In `UcapHutangTests/QwenMigrationTests.swift`, replace the two methods `testSplitDecoderExtractsAdjacentNamesAndEqualShares` and `testInvalidModelOutputFallsBackToModePreservingDraftWithWarning` with:

```swift
    func testSplitDecoderExtractsAdjacentNamesAndEqualShares() async throws {
        let service = QwenDraftExtractionService(
            llmClient: StubLLMClient(output: "{\"basis\":\"equal\",\"title\":\"tiket konser\",\"total_amount\":800000,\"split_count\":4,\"includes_user\":true,\"receivables\":[{\"person\":\"Satria\",\"item\":null,\"amount\":null},{\"person\":\"Arif\",\"item\":null,\"amount\":null},{\"person\":\"Ros\",\"item\":null,\"amount\":null}],\"notes\":null,\"transaction_time\":{\"day\":null,\"month\":null,\"year\":null,\"hour\":null,\"minute\":null}}")
        )
        let transcript = "Gua beli tiket konser nalangin Satria Arif dan Ros totalnya 800.000"
        let result = try await service.extract(flow: .splitBill, transcript: transcript, referenceDate: Date())
        let draft = DraftMapper.makeDraft(flow: .splitBill, transcript: transcript, result: result, createdAt: Date())
        XCTAssertEqual(draft.type, .splitBill)
        XCTAssertEqual(draft.totalAmount, 800_000)
        XCTAssertEqual(draft.participants.map(\.name), ["Satria", "Arif", "Ros"])
        XCTAssertEqual(draft.participants.map(\.shareAmount), [200_000, 200_000, 200_000])
    }

    func testInvalidModelOutputFallsBackToModePreservingDraftWithWarning() async throws {
        let service = QwenDraftExtractionService(llmClient: StubLLMClient(output: "not json"))
        let transcript = "catat ini dulu"
        let result = try await service.extract(flow: .personal, transcript: transcript, referenceDate: Date())
        let draft = DraftMapper.makeDraft(flow: .personal, transcript: transcript, result: result, createdAt: Date())
        XCTAssertEqual(draft.flow, .personal)
        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.participants.first?.name, "")
        XCTAssertFalse(draft.reviewWarnings.isEmpty)
    }
```

In `UcapHutangTests/CoreFlowTests.swift`, replace the method `testMissingSemanticFieldsStayEmpty` with:

```swift
    func testMissingSemanticFieldsStayEmpty() async throws {
        let service = QwenDraftExtractionService()
        let transcript = "catat ini dulu"
        let result = try await service.extract(flow: .personal, transcript: transcript, referenceDate: Date())
        let draft = DraftMapper.makeDraft(flow: .personal, transcript: transcript, result: result, createdAt: Date())
        XCTAssertEqual(draft.type, .unknown)
        XCTAssertEqual(draft.title, "")
        XCTAssertEqual(draft.participants.first?.name, "")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run the full test command.

Expected: `error:` lines such as `cannot find 'SpeechTranscribing' in scope`, `cannot find 'SpeechPermissionError' in scope`, `extra arguments ... 'speech', 'capture'`; `** TEST FAILED **`.

- [ ] **Step 3: Speech domain types and protocol**

Create `UcapHutang/Domain/Models/SpeechModels.swift`:

```swift
import Foundation

enum SpeechRecognizerState: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case failed(String)
}

/// Permission problems the Catat screen shows inline with a "Buka Pengaturan" button.
enum SpeechPermissionError: LocalizedError, Equatable {
    case microphoneDenied
    case speechDenied
    case restricted

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan."
        case .speechDenied: "Izin Speech Recognition ditolak. Buka Pengaturan untuk mengaktifkan."
        case .restricted: "Speech Recognition dibatasi pada perangkat ini."
        }
    }
}

/// Non-permission failures while starting speech recognition.
enum SpeechRecognitionError: LocalizedError, Equatable {
    case authorizationNotDetermined
    case authorizationUnknown
    case audioSession(String)
    case audioEngine(String)

    var errorDescription: String? {
        switch self {
        case .authorizationNotDetermined: "Izin Speech Recognition belum ditentukan."
        case .authorizationUnknown: "Status otorisasi Speech Recognition tidak dikenal."
        case .audioSession(let detail): "Gagal menginisialisasi AVAudioSession: \(detail)"
        case .audioEngine(let detail): "Gagal memulai AudioEngine: \(detail)"
        }
    }
}
```

Create `UcapHutang/Domain/Protocols/SpeechTranscribing.swift`:

```swift
import Foundation

/// Stage 1 contract: microphone audio → Indonesian transcript.
@MainActor
protocol SpeechTranscribing: AnyObject {
    var state: SpeechRecognizerState { get }
    var liveTranscript: String { get }
    /// True when the device can recognize `id-ID` speech without sending audio to Apple's servers.
    var usesOnDeviceRecognition: Bool { get }
    /// Requests microphone + speech permission when needed, then starts listening.
    /// Throws `SpeechPermissionError` or `SpeechRecognitionError`.
    func start() async throws
    /// Stops listening and waits (bounded) for the final transcript.
    func finish() async -> String
    func cancel()
}
```

- [ ] **Step 4: Replace `SpeechRecognizer.swift`**

Replace the entire content of `UcapHutang/Services/Speech/SpeechRecognizer.swift` with:

```swift
import Foundation
import Speech
import AVFoundation
import Observation

@Observable
final class SpeechRecognizer: SpeechTranscribing {
    private(set) var state: SpeechRecognizerState = .idle
    private(set) var liveTranscript = ""
    private(set) var audioLevel: Float = 0.0

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID")) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var hasInstalledInputTap = false
    @ObservationIgnored private var activeTranscript: String = ""
    @ObservationIgnored private var transcriptContinuation: CheckedContinuation<String, Never>?

    private static let vocabulary = [
        "nalangin", "nalagin", "talangin", "bayarin", "nombokin", "tombokin",
        "ngutang", "piutang", "hutang", "pinjem", "minjem", "minjemin",
        "split bill", "splitbill", "patungan", "bagi rata", "urunan",
        "gacoan", "ramen", "kopi", "bensin", "konser", "tiket",
        "ribu", "juta", "jt", "rb", "k"
    ]

    init() {}

    var usesOnDeviceRecognition: Bool {
        speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    func start() async throws {
        liveTranscript = ""
        activeTranscript = ""

        let microphoneGranted = await AVAudioApplication.requestRecordPermission()
        guard microphoneGranted else {
            throw SpeechPermissionError.microphoneDenied
        }

        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        switch status {
        case .authorized:
            break
        case .denied:
            throw SpeechPermissionError.speechDenied
        case .restricted:
            throw SpeechPermissionError.restricted
        case .notDetermined:
            throw SpeechRecognitionError.authorizationNotDetermined
        @unknown default:
            throw SpeechRecognitionError.authorizationUnknown
        }

        try beginRecognition()
    }

    func finish() async -> String {
        guard state == .listening else {
            return activeTranscript
        }
        state = .finalizing
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()

        return await withCheckedContinuation { continuation in
            self.transcriptContinuation = continuation

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard let self, self.state == .finalizing else { return }
                self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
            }
        }
    }

    func cancel() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
        removeInputTap()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
        audioLevel = 0.0

        if let continuation = transcriptContinuation {
            transcriptContinuation = nil
            continuation.resume(returning: activeTranscript)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecognition() throws {
        if recognitionTask != nil {
            cancel()
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechRecognitionError.audioSession(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = usesOnDeviceRecognition
        request.contextualStrings = Self.vocabulary
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.activeTranscript = text
                Task { @MainActor in
                    self.liveTranscript = text
                }
                if result.isFinal {
                    self.finishTaskAndCleanup(finalTranscript: text)
                }
            }

            if let error {
                if self.state == .finalizing {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                } else if self.state == .listening {
                    self.finishTaskAndCleanup(finalTranscript: self.activeTranscript)
                    self.state = .failed("Speech recognition error: \(error.localizedDescription)")
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            self.processAudioLevel(from: buffer)
        }
        hasInstalledInputTap = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
            state = .listening
        } catch {
            removeInputTap()
            throw SpeechRecognitionError.audioEngine(error.localizedDescription)
        }
    }

    private func finishTaskAndCleanup(finalTranscript: String) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        state = .idle
        audioLevel = 0.0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let continuation = transcriptContinuation {
            transcriptContinuation = nil
            continuation.resume(returning: finalTranscript)
        }
    }

    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        var sum: Float = 0.0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let db = 20 * log10(max(rms, 0.0001))

        let minDb: Float = -50.0
        let maxDb: Float = -5.0
        let normalized = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))

        Task { @MainActor [weak self] in
            guard let self, self.state == .listening else { return }
            self.audioLevel = (self.audioLevel * 0.4) + (normalized * 0.6)
        }
    }

    private func removeInputTap() {
        guard hasInstalledInputTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasInstalledInputTap = false
    }
}
```

- [ ] **Step 5: Trim the old extraction file into `QwenPromptBuilder.swift`**

```bash
git mv UcapHutang/Services/AI/DraftExtractionService.swift UcapHutang/Services/AI/QwenPromptBuilder.swift
```

In `UcapHutang/Services/AI/QwenPromptBuilder.swift`:

1. Delete exactly these lines:

   ```swift
   protocol DraftExtractionService: Sendable {
       func extract(_ request: DraftExtractionRequest) async throws -> TransactionDraft
   }
   ```

2. Delete **everything from the line** `struct HybridQwenExtractionService: DraftExtractionService {` **to the end of the file** (including that line). Do not touch anything above it — the prompt strings inside `QwenPromptBuilder` must stay byte-for-byte identical.

Verify:

```bash
grep -nE "^(struct|enum|protocol) " UcapHutang/Services/AI/QwenPromptBuilder.swift
```

Expected exactly these four lines (line numbers may differ):

```text
3:struct DraftExtractionRequest: Sendable {
15:protocol LLMClientProtocol: Sendable {
19:enum DraftExtractionError: LocalizedError {
31:enum QwenPromptBuilder {
```

- [ ] **Step 6: Replace `CatatViewModel.swift`**

Replace the entire content of `UcapHutang/Features/Catat/ViewModels/CatatViewModel.swift` with:

```swift
import Foundation
import Observation

@Observable
final class CatatViewModel {
    let flow: CaptureFlow
    let speech: any SpeechTranscribing
    private let capture: any VoiceCapturing

    private(set) var isStartingRecording = false
    private(set) var isProcessing = false
    private(set) var savedDraftID: UUID?
    private(set) var permissionMessage: String?
    var errorMessage: String?

    @ObservationIgnored private var processingTask: Task<Void, Never>?

    init(flow: CaptureFlow, speech: any SpeechTranscribing, capture: any VoiceCapturing) {
        self.flow = flow
        self.speech = speech
        self.capture = capture
    }

    var isListening: Bool {
        isStartingRecording || speech.state == .listening
    }

    var stageHeadline: String {
        if isProcessing { return "Menganalisis data..." }
        if speech.state == .finalizing { return "Menyelesaikan transkrip..." }
        if isListening { return "Mendengarkan..." }
        return ""
    }

    var recordButtonLabel: String {
        isListening ? "Berhenti merekam" : "Mulai merekam"
    }

    func handleMicTap() async {
        guard !isProcessing, !isStartingRecording else { return }
        if speech.state == .listening {
            await finishAndProcess()
        } else {
            await startRecording()
        }
    }

    func restartRecording() async {
        guard !isProcessing else { return }
        speech.cancel()
        await startRecording()
    }

    func handleSpeechStateChange(_ state: SpeechRecognizerState) {
        if case .failed(let message) = state, !isProcessing {
            errorMessage = message
        }
    }

    func cancel() {
        speech.cancel()
        processingTask?.cancel()
        processingTask = nil
        isStartingRecording = false
        isProcessing = false
    }

    private func startRecording() async {
        permissionMessage = nil
        isStartingRecording = true
        defer { isStartingRecording = false }
        do {
            try await speech.start()
        } catch let error as SpeechPermissionError {
            permissionMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishAndProcess() async {
        isProcessing = true
        let task = Task {
            defer { self.isProcessing = false }
            let finalTranscript = await self.speech.finish()
            guard !Task.isCancelled else { return }

            let candidate = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? self.speech.liveTranscript
                : finalTranscript
            let transcript = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                self.errorMessage = "Suara tidak terdeteksi. Silakan coba lagi."
                return
            }

            do {
                let draftID = try await self.capture.process(flow: self.flow, transcript: transcript)
                guard !Task.isCancelled else { return }
                self.savedDraftID = draftID
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
        }
        processingTask = task
        await task.value
        processingTask = nil
    }
}
```

- [ ] **Step 7: Replace `AppContainer.swift`**

Replace the entire content of `UcapHutang/App/AppContainer.swift` with:

```swift
import Foundation
import Observation
import SwiftData

@Observable
final class AppContainer {
    let repository: any TransactionRepository
    let extraction: any DraftExtracting
    let capture: any VoiceCapturing
    let contacts: any ContactsProviding
    let router: AppRouter
    let makeSpeechTranscriber: @MainActor () -> any SpeechTranscribing
    let storageErrorMessage: String?

    init(
        repository: any TransactionRepository,
        extraction: any DraftExtracting,
        contacts: any ContactsProviding,
        router: AppRouter = AppRouter(),
        makeSpeechTranscriber: @escaping @MainActor () -> any SpeechTranscribing = { SpeechRecognizer() },
        storageErrorMessage: String? = nil
    ) {
        self.repository = repository
        self.extraction = extraction
        self.capture = VoiceCapturePipeline(extraction: extraction, repository: repository)
        self.contacts = contacts
        self.router = router
        self.makeSpeechTranscriber = makeSpeechTranscriber
        self.storageErrorMessage = storageErrorMessage
    }

    static func makeDefault() -> AppContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let contacts = SystemContactsProvider()
        let extraction = QwenDraftExtractionService(llmClient: MLXQwenClient())
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: UcapHutangMigrationPlan.self,
                configurations: config
            )
            let repo = SwiftDataTransactionRepository(modelContainer: container)
            return AppContainer(repository: repo, extraction: extraction, contacts: contacts)
        } catch {
            let fallbackRepo = InMemoryTransactionRepository()
            // SwiftData has no migration-specific error type. If a store file already exists,
            // the failure happened while opening/migrating existing data.
            let storeExists = FileManager.default.fileExists(atPath: config.url.path)
            let message = storeExists
                ? "Migrasi data ke versi terbaru gagal. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
                : "Penyimpanan lokal tidak dapat dibuka. Demi mencegah kehilangan data, pencatatan dinonaktifkan sementara. Tutup lalu buka kembali aplikasi. Detail: \(error.localizedDescription)"
            return AppContainer(
                repository: fallbackRepo,
                extraction: extraction,
                contacts: contacts,
                storageErrorMessage: message
            )
        }
    }
}
```

- [ ] **Step 8: Banner component and Catat screens**

Create `UcapHutang/Features/Catat/Components/SavedToReviewBanner.swift`:

```swift
import SwiftUI

struct SavedToReviewBanner: View {
    let bannerID: UUID
    let onOpen: () -> Void
    let onTimeout: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label("Tersimpan ke Review", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Button("Lihat", action: onOpen)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityFocused($isFocused)
        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        .task(id: bannerID) {
            try? await Task.sleep(for: .seconds(4))
            // Keep the banner while VoiceOver focus is on it.
            while isFocused && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            onTimeout()
        }
    }
}
```

Replace the entire content of `UcapHutang/Features/Catat/Views/CatatFlowChooserView.swift` with:

```swift
import SwiftUI

struct CatatFlowChooserView: View {
    let router: AppRouter
    let onSelect: (CaptureFlow) -> Void
    private let readiness = MLXQwenClient.readiness()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("Pilih jenis pencatatan")
                    .font(.largeTitle.weight(.semibold))

                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(readiness.title).font(.subheadline.weight(.semibold))
                        Text(readiness.detail).font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                } icon: {
                    Image(systemName: readiness == .ready ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(readiness == .ready ? Color.green : Color.orange)
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))

                ForEach(CaptureFlow.allCases) { flow in
                    Button { onSelect(flow) } label: {
                        HStack {
                            Image(systemName: flow == .personal ? "person.fill" : "person.3.fill")
                                .frame(width: 32)
                            Text(flow.title).font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(AppSpacing.large)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(readiness != .ready)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Catat")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                if let bannerID = router.savedBannerID {
                    SavedToReviewBanner(
                        bannerID: bannerID,
                        onOpen: { router.openReviewFromBanner() },
                        onTimeout: { router.dismissSavedBanner() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .animation(reduceMotion ? nil : .default, value: router.savedBannerID)
        }
    }
}
```

Replace the entire content of `UcapHutang/Features/Catat/Views/CatatView.swift` with:

```swift
import SwiftUI

struct CatatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Button {
                        Task { await viewModel.handleMicTap() }
                    } label: {
                        recordingControl
                    }
                    .disabled(viewModel.isProcessing)
                    .accessibilityLabel(viewModel.recordButtonLabel)
                    .accessibilityValue(viewModel.stageHeadline)

                    if viewModel.isListening {
                        Button("Ulangi") {
                            Task { await viewModel.restartRecording() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.border))

                        Text(viewModel.speech.liveTranscript.isEmpty ? viewModel.stageHeadline : viewModel.speech.liveTranscript)
                            .font(viewModel.speech.liveTranscript.isEmpty ? .body : .body.weight(.medium))
                            .foregroundStyle(viewModel.speech.liveTranscript.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.speech.liveTranscript)
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
                }

                Spacer()

                if !viewModel.speech.usesOnDeviceRecognition {
                    Text("Ucapan diproses oleh server Apple.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
            }
            .padding(.horizontal, 24)
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
            Circle()
                .stroke(
                    AppColors.textSecondary.opacity(0.65),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 7])
                )
                .frame(width: 250, height: 250)
            if viewModel.isProcessing || viewModel.speech.state == .finalizing {
                ProgressView().tint(AppColors.textPrimary).scaleEffect(1.3)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                    Text(viewModel.isListening ? "Tekan untuk\nberhenti" : "Tekan untuk catat\nvia suara")
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: 250, height: 250)
    }

    private var tipText: String {
        flow == .personal
            ? "Dito pinjam 50 ribu buat beli bensin"
            : "Split bill makan 100 ribu sama Satria dan Arif bagi rata"
    }
}
```

(The fixed 250 pt control and the hard-coded icon size are fixed in P7.)

- [ ] **Step 9: Replace `RootTabView.swift`**

Replace the entire content of `UcapHutang/App/RootTabView.swift` with:

```swift
import SwiftUI

struct IdentifiableUUID: Identifiable, Equatable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

struct RootTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var reviewDraftItem: IdentifiableUUID?
    @State private var selectedCaptureFlow: CaptureFlow?
    @State private var pendingReviewCount = 0

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Review", systemImage: "doc.badge.clock", value: AppTab.review) {
                ReviewListView(repository: container.repository) { draftID in
                    reviewDraftItem = IdentifiableUUID(draftID)
                }
            }
            .badge(pendingReviewCount)

            Tab("Catat", systemImage: "mic.fill", value: AppTab.capture) {
                CatatFlowChooserView(router: container.router) { flow in
                    selectedCaptureFlow = flow
                }
            }

            Tab("Riwayat", systemImage: "book.closed", value: AppTab.ledger) {
                LedgerListView(repository: container.repository)
            }
        }
        .sensoryFeedback(.success, trigger: container.router.savedBannerID) { _, newValue in
            newValue != nil
        }
        .task { await refreshPendingReviewCount() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionRepositoryDidChange)) { _ in
            Task { await refreshPendingReviewCount() }
        }
        .sheet(item: $reviewDraftItem) { item in
            NavigationStack {
                ReviewDetailView(draftID: item.id, repository: container.repository, contacts: container.contacts)
            }
        }
        .sheet(item: $selectedCaptureFlow) { flow in
            CatatView(flow: flow, container: container)
        }
    }

    private func refreshPendingReviewCount() async {
        pendingReviewCount = (try? await container.repository.pendingDraftCount()) ?? 0
    }
}
```

- [ ] **Step 10: Run the tests**

Run the full test command. Expected: `Executed 93 tests, with 0 failures`, `** TEST SUCCEEDED **`.

- [ ] **Step 11: Verify removed APIs are gone**

```bash
grep -rn --include='*.swift' -E "HybridQwenExtractionService|\bDraftExtractionService\b|extractionService|startRecording\(onTranscript|finishRecording\(|cancelRecording\(|isRecording|createdDraftID|navigationDestination\(item: \\\$viewModel" UcapHutang UcapHutangTests
```

Expected: **no output**.

- [ ] **Step 12: Commit**

```bash
git add UcapHutang/Domain/Models/SpeechModels.swift UcapHutang/Domain/Protocols/SpeechTranscribing.swift UcapHutang/Services/Speech/SpeechRecognizer.swift UcapHutang/Services/AI/QwenPromptBuilder.swift UcapHutang/Features/Catat UcapHutang/App/AppContainer.swift UcapHutang/App/RootTabView.swift UcapHutangTests/TestDoubles/FakeSpeechTranscriber.swift UcapHutangTests/TestDoubles/SpyVoiceCapture.swift UcapHutangTests/SpeechPermissionErrorTests.swift UcapHutangTests/CatatViewModelTests.swift UcapHutangTests/QwenMigrationTests.swift UcapHutangTests/CoreFlowTests.swift
git commit -m "feat: close Catat after saving to Review with banner, badge and on-device speech"
```

---

### Task 5: Device check (report to the developer)

**Files:** none changed.

- [ ] **Step 1: Simulator build smoke check**

```bash
xcodebuild build -project UcapHutang.xcodeproj -scheme UcapHutang -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/DerivedData -quiet
```

Expected: no `error:` lines.

- [ ] **Step 2: Hand the device checklist to the developer**

Send this checklist verbatim and wait for confirmation before starting P5:

1. Catat → Personal → record "Satria ngutang 20 ribu beli kopi" → stop. The sheet closes, a success haptic plays, the Catat tab shows "Tersimpan ke Review · Lihat" for about 4 seconds, and the Review tab badge increases by 1. The review form does **not** open.
2. Tap **Lihat** on the banner → the app switches to the Review tab and the new draft is listed.
3. With VoiceOver on, repeat step 1 → "Tersimpan ke Review" is announced; while VoiceOver focus is on the banner it does not disappear.
4. On a device where `id-ID` on-device recognition is **not** available, the Catat screen shows "Ucapan diproses oleh server Apple." (On a supported device the footnote is absent.)
5. In iOS Settings, turn the microphone off for UcapHutang, then tap record → "Izin mikrofon ditolak. Buka Pengaturan untuk mengaktifkan." with a **Buka Pengaturan** button that opens Settings.
6. Open the new draft from the Review tab → the fields match the recording, and saving still requires linking contacts.

## Phase exit checklist

- [ ] `git status --porcelain` shows only `?? .xcede/` and `?? xcede.yml`.
- [ ] `git log --oneline -4` shows the four P4 commits.
- [ ] Full test command: `Executed 93 tests, with 0 failures`, `** TEST SUCCEEDED **`.
- [ ] The developer confirmed the Task 5 checklist.
