# Project Audit and Remediation Plan

## Current verified state

- The complete `Qwen3-0.6B-4bit` directory is locally installed at `UcapHutang/Resources/Models/Qwen3-0.6B-4bit/` and excluded from Git.
- The copied `model.safetensors` SHA-256 matches the POC source: `392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2`.
- MLX Swift packages are pinned to the versions proven by the POC and `MLXQwenClient` is used by the production `AppContainer`.
- The local model is bundled by Xcode. The current file-system-synchronized target flattens the model resource files into the app bundle root, so the loader explicitly accepts that generated layout as well as the documented nested layout.
- Simulator build validates compilation and packaging only. Real inference performance and memory behavior still require a physical Apple Silicon iPhone/iPad.

## Findings and prioritized remediation

### P0 — financial correctness and data integrity

1. **Prevent duplicate ledger entries on repeated confirmation** — implemented.
   - Both repositories now return early when an already-confirmed draft is confirmed again.
   - The Review ViewModel also guards concurrent save taps.
2. **Make confirmation atomic** — implemented.
   - Draft mutation and ledger insertion now share one final `ModelContext.save()` boundary.
   - Repeated confirmation is idempotent through confirmed-status and `sourceDraftID` checks.
3. **Define stable person identity and merge policy.**
   - Linked entries use the Contacts identifier; unlinked entries use lowercase display names. Renaming or later linking can split one human into multiple ledgers.
   - Add a stable local `Person` entity with optional contact identifier and an explicit merge operation.
4. **Strengthen custom split validation.**
   - Current UI blocks totals above the transaction but permits under-allocation without explaining the user's retained share.
   - Display total, friends' allocated amount, user's share, and remaining amount. Decide and encode whether custom allocation may intentionally leave a user share.

### P0 — extraction trust boundary

1. **Stop fabricating semantic defaults** — implemented for fallback drafts.
   - Generic person/title placeholders were removed.
   - Missing or ambiguous direction now stays `unknown` and must be selected in Review before confirmation.
2. **Restore strict schema validation before deterministic refinement.**
   - `QwenOutputDecoder` currently treats invalid or missing JSON as `{}` and accepts `NSNumber` without rejecting Bool/fractions.
   - Validate allowed keys, nested shapes, integer types, amount ceilings, output size, and exactly one JSON object before grounding/refinement.
3. **Improve participant extraction fixtures.**
   - The screenshots expose `Satria` becoming `Teman` and named split participants becoming generic placeholders.
   - Add fixture tests for real transcripts, including `Satria ngutang 20.000 beli kopi` and `Aku bayarin makan 90.000 untuk Satria Kans dan Ari`.
4. **Represent ambiguous direction explicitly.**
   - Unknown personal direction currently defaults to Piutang. Preserve unknown in the draft or require explicit user selection before save; never silently choose a financial direction.
5. **Preserve itemized split tuples end to end.**
   - Current transcript-grounding rebuilds receivables from names and discards model-provided `(person, item, amount)` values.
   - Ground each tuple independently and add fixtures proving that multiple itemized amounts are not flattened or reassigned.
6. **Do not use the first detected amount as a split total.**
   - Parse totals only from explicit total markers or a proven conservation equation. Multiple unlabelled amounts must remain ambiguous and require review.

### P1 — model lifecycle and release setup

1. **Add an in-app model readiness state.**
   - Before recording, show Installed / Loading / Ready / Missing / Failed and prevent users from waiting without feedback.
2. **Add a model manifest.**
   - Ship expected filenames, model ID, package versions, asset version, and SHA-256 in a small tracked manifest; verify it before loading.
3. **Automate Release installation.**
   - Add a script that downloads the exact release asset, verifies SHA-256, extracts to the ignored path, and fails loudly on a mismatch.
4. **Physical-device benchmark gate.**
   - Measure cold load, warm load, first-token latency, total generation time, peak memory, thermal state, and cancellation on intended devices.

### P1 — Review and user-facing validation

1. **Place raw transcript first** — implemented.
2. **Explain save destination** — implemented.
   - Linked Contacts and ordinary names both become per-person ledger history; contact linking is optional.
3. **Replace generic validation alerts** — implemented.
   - Field-level Indonesian messages identify missing amount, title, person, split share, duplicate names, and over-allocation.
4. **Permit direct name editing** — implemented.
5. **Improve field presentation.**
   - Add inline red/orange treatment beside each invalid field and scroll/focus the first invalid field after Save.
6. **Surface extraction warnings.**
   - Show model missing/load/decoder/date warnings in a dedicated review banner rather than retaining them invisibly in `reviewWarnings`.

### P1 — capture and navigation reliability

1. **Guard speech-to-inference re-entry** — implemented.
   - Capture assigns an active request UUID before finalizing speech, ignores re-entry, and cancels the tracked generation task on disappearance.
2. **Cancel safely on disappearance.**
   - Ensure tab changes, dismissal, interruption, and app background cancel audio taps and active generation.
3. **Clarify navigation ownership.**
   - Avoid calling dismiss and navigation callback in the same update if it can race. Route the created draft ID through one coordinator/path transaction.
4. **Permission recovery.**
   - Provide settings deep links and human-readable denied/restricted states for microphone, speech, and contacts.
5. **Enforce the stated speech privacy mode.**
   - Set `requiresOnDeviceRecognition` only after checking device support. If unavailable, disclose the behavior and obtain an explicit product decision instead of implying all speech is offline.

### P1 — SwiftData robustness

1. Add a versioned `VersionedSchema` and `SchemaMigrationPlan` before distributing builds with real user data.
2. Do not replace relationship arrays without explicitly deleting orphaned participant models; verify cascade behavior with integration tests.
3. **Remove silent production fallback** — implemented. A persistent-container failure now presents a blocking storage error and no longer seeds plausible preview records.
4. Add export/import and recovery strategy for financial history.
5. Align deletion copy and behavior: either physically delete sensitive discarded drafts and participants, or label the action as archive/soft-delete and define retention controls.
6. **Refresh Draft/Ledger and revalidate payment** — implemented. Repository changes notify visible projections, detail reloads after payment, and payment validation derives the latest balance from ledger entries.

### P2 — architecture and maintainability

1. Split the large Review file into `ReviewDraftViewModel`, transcript, transaction fields, participants, save guidance, and actions subviews.
2. Move validation into a domain `DraftValidator` used by both UI and repositories so persistence cannot bypass UI rules.
3. Separate model generation protocol and extraction orchestration files; add explicit model state/progress.
4. Remove global retroactive `Int: Identifiable`; use a local wrapper for sheet selection.
5. Replace `print` diagnostics with privacy-aware `Logger` categories.
6. Request Contacts permission only after the user taps `Hubungkan`; do not auto-link or mutate a name merely because one fuzzy candidate was returned.
7. Add a stable dirty-state/autosave policy so Review edits are not lost when its sheet is dismissed interactively.

### P2 — testing, accessibility, and release readiness

1. Add unit-test target covering amount parsing, dates, strict JSON decoding, direction, split conservation, validation, ledger signs, partial payment, duplicate confirmation, and identity aggregation.
2. Add SwiftData integration tests using an in-memory container.
3. Add UI tests for Personal capture -> Review -> save and Split Bill -> edit -> save -> settle partial.
4. Add accessibility labels/values to microphone state, participant contact status, segmented controls, and monetary fields; verify Dynamic Type and dark/light modes.
5. Lower or justify the iOS 26.5 deployment target based on the Academy test-device fleet.
6. Update `README.md` to reflect completed Speech/MLX/SwiftData/Contacts integration and publish a real Release URL/checksum before onboarding another developer.
7. Add the required App Store icon assets; the current AppIcon catalog has declarations but no image filenames.
8. Validate percentage splitting separately: percentages must total 100 and checked arithmetic must preserve the full Rupiah total.

## Recommended delivery order

1. P0 atomic ledger confirmation + domain validator + strict decoder tests.
2. Model readiness UI + device inference smoke test.
3. Extraction fixture suite from recorded UT transcripts.
4. Versioned SwiftData schema and removal of silent in-memory fallback.
5. Capture cancellation/navigation hardening.
6. Accessibility, UI tests, benchmark, and release automation.

## Acceptance criteria for the next milestone

- Saving the same draft twice produces exactly one set of ledger entries.
- No missing/ambiguous semantic field is replaced by a plausible generic value.
- Every blocked save lists the exact fields to fix in Indonesian.
- Contact linking remains optional; an ordinary non-empty name creates stable ledger history.
- Model readiness is visible before recording.
- Personal and Split Bill fixture suites pass with strict JSON validation.
- A physical device loads the packaged model offline and completes inference within agreed memory/latency thresholds.
