# Slice 137: canonical AESIR Hailo command line

Completed 2026-10-12 for the qualified HailoRT 5.3.0 / Qwen2.5-1.5B-Instruct
profile. `aesir_engine/main.mojo` now dispatches the direct Hailo commands
without importing the legacy CPU/CUDA CLI graph. Existing unrelated source
remains available as historical code, not as an inference route in this build.

`bash scripts/build_hailo10h.sh` builds the native bridge with warnings treated
as errors and the canonical Mojo executable. A successful build publishes a
matched binary/library generation; a failed build leaves the previous binary
pair available. The Hailo bridge uses a sibling library search path.

Supported commands require an explicit Hailo model artifact:

```sh
work/aesir run --model-path artifacts/Qwen2.5-1.5B-Instruct.hef --max-tokens 32 --prompt "What is 2 plus 3? Reply with only the number."
work/aesir chat --model-path artifacts/Qwen2.5-1.5B-Instruct.hef
work/aesir hardware --model-path artifacts/Qwen2.5-1.5B-Instruct.hef --format json
```

`--max-tokens`, `--timeout-ms`, and text/JSON output are connected to actual
generation. The default is greedy generation, 128 output tokens, and a 60 s
completion-read timeout. Chat retains one device session and supports `/clear`,
`/info`, `/help`, and `/bye`. Invalid arguments are rejected before opening
hardware. Input is validated UTF-8, including pasted Unicode and CRLF; an
oversized input line is drained and reported before the next turn is read.

## Observed behavior and fixes

- Canonical build completed; parser/boundary regression methods passed,
  including 16 invalid CLI subcases.
- Live single-shot arithmetic returned `5.`. A complete terminal suffix is
  removed only when it is among the loaded model's reported stop tokens and
  generation ended logically. No arbitrary internal text is removed.
- Persistent chat recalled `ember` after an earlier turn, with context usage
  growing from 43 to 72 tokens. `/clear` returned usage to zero; the following
  arithmetic request returned `5.`.
- The strict word-only recall request returned `ember\nOK.` rather than only
  `ember`. Recall works, but strict instruction formatting remains an open
  quality defect; this experiment is not marked as a strict-format pass.
- A large input previously exposed HailoRT's context-full warning while still
  returning success. AESIR now asks the device tokenizer for the prompt count
  and admits prompt/output/history against actual model capacity with a
  declared 64-token structured-template reserve. The reserve is an admission
  policy for this qualified profile, not a universal model property.
- The 2,500-token oversized input was rejected without changing the prior
  43-token context. Subsequent recall still returned `ember\nOK.`.
- With existing history, an actual 1 ms completion timeout aborted the failed
  request and restored the saved device context to the previous 43 tokens.
  A subsequent request recalled the word. This snapshot is opaque context
  transfer; it does not execute model computation on the host.
- If abort does not confirm stopped generation, the bridge requires session
  reopen and refuses an unsafe context-clear operation. That exceptional path
  is guarded but has not been induced on hardware.
- Text responses are delivered without a diagnostics dependency. JSON retains
  completed text and reports any optional diagnostic failure explicitly.

This slice connects usable direct inference and chat. Model-quality acceptance,
additional artifact support, cancellation signals, device removal recovery,
deployment packaging, and performance acceptance remain later roadmap work.
