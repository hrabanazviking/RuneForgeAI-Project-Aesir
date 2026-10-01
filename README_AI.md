# Project Aesir contributor orientation

Read TODO.md, CAPABILITY_LEDGER.md, AI.rules.part2.md, RULES.AI.md and the owning
INTERFACE.md before changing code. The capability ledger owns present-tense truth;
historical roadmaps and attractive filenames are not evidence of runtime support.
Write and publish a task contract before substantial implementation. Preserve
reference code, user artifacts, model bytes and unrelated changes.

Native inference is Mojo. Python scripts only prepare, supervise, test or measure
it; no provider substitution belongs in compute. Loader owns validated GGUF
spans, core owns numerics/session state, CLI/server own configuration and socket
contracts. Current narrowly exercised second-brain native profile is Llama 3.2
3B Q4_K_M on an RTX 2060 Max-Q, sm_75. Do not infer broad models/devices from that.

For builds/readiness see docs/LOCAL_LAUNCH.md and docs/SECOND_BRAIN.md. For prefix
ownership, cancellation, reset and sampling see docs/NATIVE_PERFORMANCE.md. For
packed arithmetic, fixed RMS tiles and performance evidence gates see
docs/NATIVE_EFFICIENCY.md. The hosted workflow compiles opt-in CUDA probes while
local physical tests must prove their actual execution separately.

Rebuild after final Mojo edits. Serialize GPU probes and benchmarks. Preserve
all raw failures, compare identical model/control/request/reply work and verify
the exact pushed CI revision. For four-token 3B prefill and compact checked buffers read
docs/NATIVE_LONG_TOKENS.md. Leave full-model independent logits, broader-profile
batched prefill, broader-device speeds and locked-runtime context recreation open until
their own acceptance gates pass. Keep private API keys and source corpus out of
repository commits, reports and prompts.
