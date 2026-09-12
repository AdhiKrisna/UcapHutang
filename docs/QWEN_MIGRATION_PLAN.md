# Qwen + MLX Migration Plan

## Source and target

Source POC:

The original local MLX proof-of-concept project (not part of this repository).

Target app:

The root of this `UcapHutang` repository.

The source currently uses `mlx-community/Qwen3-0.6B-4bit`, MLX Swift 0.31.6, MLX Swift LM 3.31.4, Swift Transformers 1.3.4, token streaming, mode-specific prompts, strict/tolerant decoding, deterministic date/amount/split logic, and Indonesian Speech recognition.

Do not copy the whole POC tree or its project file. Migrate reviewed responsibilities behind target protocols.

## Model release contract

The model directory is intentionally excluded from Git and distributed as a repository Release asset.

Recommended asset:

`Qwen3-0.6B-4bit.zip`

Expected extracted layout:

```text
UcapHutang/Resources/Models/Qwen3-0.6B-4bit/
├── config.json
├── generation_config.json        # if supplied
├── tokenizer.json
├── tokenizer_config.json
├── special_tokens_map.json       # if supplied
└── model.safetensors             # or all indexed shards + index JSON
```

Release checklist:

1. Zip the complete Hugging Face/MLX model directory, not only `model.safetensors`.
2. Attach it to a versioned GitHub Release.
3. Publish SHA-256 in the release notes.
4. Update the exact release URL and checksum in `README.md` before calling setup complete.
5. Never commit the extracted model, zip, `.safetensors`, or generated build copies.

## Package migration

Add Swift packages to the app target and pin versions initially to the proven POC lockfile:

- `https://github.com/ml-explore/mlx-swift` — 0.31.6
- `https://github.com/ml-explore/mlx-swift-lm` — 3.31.4
- `https://github.com/huggingface/swift-transformers` — 1.3.4

Required products observed in the POC:

- `MLXLLM`
- `MLXLMCommon`
- `MLXHuggingFace`
- `HuggingFace`
- `Tokenizers`

`MLX` is imported directly by the adapter and may be linked transitively; add it explicitly if Xcode does not expose the module.

Also add:

- microphone and speech-recognition usage descriptions
- increased-memory-limit capability where supported
- a physical-device build/run gate; simulator success is not sufficient evidence for usable inference

## Responsibility mapping

Migrate and reshape these source responsibilities:

| POC source | Target responsibility |
|---|---|
| `AI/LLM/LLMClientProtocol.swift` | `Services/AI/LLMGenerating.swift` |
| `AI/LLM/MLXLLMClient.swift` | `Services/AI/MLXQwenClient.swift` |
| `AI/LLM/LLMConfig.swift` | `QwenModelConfiguration` + `QwenPromptBuilder` |
| `Models/CaptureFlow.swift` decoder | mode-specific DTOs + `QwenOutputDecoder` |
| `Utils/SpeechRecognizer.swift` | `AppleSpeechRecognitionService` |
| `Utils/TransactionDateResolver.swift` | deterministic date utility |
| `Utils/SplitCalculationEngine.swift` | deterministic money allocation utility |
| `Models/TransactionDraftFactory.swift` | `DraftExtractionService` mapping DTO -> domain draft |
| `Services/ContactResolutionService.swift` | contacts adapter; migrate after core review flow |

Do not migrate `ChatViewModel`: this product is not a chat interface. `CaptureViewModel` should orchestrate speech, extraction, repository save, and navigation.

## Model lookup policy

Production should be deterministic and offline-first:

1. Look only for `Bundle.main/.../Resources/Models/Qwen3-0.6B-4bit` (or an explicitly configured Application Support directory if post-install download is later approved).
2. Verify required tokenizer/config/weight files and optional manifest checksum.
3. Load the local container lazily once and reuse it.
4. Return a clear `modelMissing` error with setup instructions when absent.
5. Do not silently download from Hugging Face at runtime; Release setup must remain reproducible and avoid unexpected network/data usage.

The POC's fallback scan of bundle root and multiple folder names should not be carried over because it hides packaging mistakes.

## Prompt contract

The selected capture flow is authoritative.

Personal schema:

```json
{"direction":"hutang|piutang|unknown","person":null,"amount":null,"title":null,"notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
```

Constraints:

- Exactly one counterparty and one transaction.
- `hutang`: user owes the named person.
- `piutang`: named person owes the user.
- Preserve names exactly from transcript; never respell.
- Missing/ambiguous fields stay null/unknown.

User-paid Split Bill schema:

```json
{"basis":"equal|custom|unknown","title":null,"total_amount":null,"split_count":null,"includes_user":true,"receivables":[{"person":"...","item":null,"amount":null}],"notes":null,"transaction_time":{"day":null,"month":null,"year":null,"hour":null,"minute":null}}
```

Constraints:

- User is always payer and implicitly included.
- Reject an explicitly third-party-paid utterance as unsupported; never reverse it.
- Preserve `(person, item, amount)` as one tuple.
- A total is not an individual's share.
- Qwen extracts semantics; Swift computes equal shares/remainders.
- Return JSON only; temperature 0; start with max 150 generated tokens and measure truncation.

## Trust boundary

Treat model output as untrusted:

1. Cap raw output size.
2. Extract exactly one JSON object.
3. Validate top-level and nested keys per selected mode.
4. Reject booleans/fractions in integer fields and cap amounts/counts before allocation.
5. Ground names, titles, and amounts against the transcript.
6. Resolve Indonesian dates deterministically with transcript precedence, then validated model components, then current local time.
7. Compute split allocations in Swift with checked arithmetic and exact Rupiah conservation.
8. Persist raw transcript/model output/warnings separately from user-editable fields.
9. On any failure, create a partial `needsReview` draft retaining mode and evidence; never fabricate semantic fields.

## Implementation phases and exit criteria

### Phase 1 — deterministic core

Port decoder DTOs, date resolver, amount normalizer, split calculator, and draft mapper with tests first.

Exit: adversarial tests pass for malformed JSON, bool/fraction/overflow amounts, invalid dates, multiple amounts, duplicate participants, and remainder allocation.

### Phase 2 — local MLX adapter

Add packages and implement `MLXQwenClient` behind `LLMGenerating`. Load only the release-installed bundle directory and expose loading/generating/error states.

Exit: app builds for simulator and device; missing model produces a recoverable error; a device loads the model once without network access.

### Phase 3 — speech integration

Port `SpeechRecognizer` as a service protocol implementation. Preserve `id-ID`, partial transcripts, domain `contextualStrings`, audio levels, final-result wait, timeout, permission/error states, and cancellation cleanup.

Exit: permission denied, empty speech, cancellation, and finalization are manually verified; trailing names survive stop.

### Phase 4 — vertical Catat flow

Implement chooser -> capture -> speech finalization -> Qwen -> validation -> atomic draft save -> shared Review. Guard against re-entrance with one active task/request ID.

Exit: exactly one draft is created per recording and direct navigation opens that exact UUID.

### Phase 5 — benchmark and hardening

Run a versioned Indonesian utterance fixture set for Personal and Split Bill. Record extraction accuracy, invalid-output rate, model load time, first-token latency, total inference latency, peak memory, and thermal behavior on intended devices.

Exit: acceptance thresholds are agreed from measured data. Model/package upgrades occur only in isolated branches with the benchmark repeated.

## Known migration corrections

- The POC contains legacy combined prompts and automatic flow detection. Do not migrate those paths; only `CapturePromptBuilder`-style mode-specific behavior is valid.
- The POC allows a Hugging Face network fallback. Remove it for reproducible Release-based setup.
- The POC's broad deterministic refiners contain product assumptions and phrase-specific rules. Port only rules covered by fixtures; do not copy blindly.
- Avoid persisting a mutable aggregate balance. Confirmed charge and payment ledger events must be the source of truth.
