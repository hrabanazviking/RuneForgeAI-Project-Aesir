# Q35-4a — Qwen35 CPU serve session, fixture-grade proof (worker slice)

Worker ran all six Forge roles sequentially in one seat (recon ->
design -> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-hipserve @ yrsa/hip-serve 0e8e5855, sole writer.
NOT committed / NOT pushed — coordinator verifies and banks.
Scope: fixture-grade CPU serve only. No real GGUF was loaded through
the forward/serve path (the Q35-2 regression and the admission probe
read the real file's metadata only, as banked). Real-file serve is
Q35-4b/Q35-3b territory and stays parent-gated.

## Design decisions

### Admission (runtime_plan) — the fixture goes through the front door
Recon found the fixture is refused by the REGISTRY's family-signature
pin (classify() sets native_profile "qwen35" only for 64L/5120), NOT
by validate_qwen35: the validator is formula-driven (relations +
per-layer tensor contract + formula tensor count) and the fixture
satisfies it fully. No existing serve-level experimental mechanism
existed (native_settings/Modelfile/catalog all checked), so the
slice adds the smallest explicit one, exactly as ordered:
- NativeModelPlan gains a 4th constructor argument
  `experimental_qwen35: Bool = False` and a plan field `experimental`.
- Explicit `--profile qwen35` on a qwen35 file whose detected
  native_profile is not "qwen35": without the opt-in the plan raises
  the registry's own friendly_error (unchanged refusal); with the
  opt-in it sets experimental=True and the qwen35 branch still runs
  qwen35_profile_for + validate_qwen35 IN FULL + qwen35_memory_plan.
  Only the signature pin is skipped. Auto never admits experimental.
- Serve surface: `--experimental-qwen35` flag in dispatch_native_serve;
  misuse on another profile is refused by name. plan.experimental is
  passed to serve_loaded and reported in /health as
  capabilities.experimental_admission and in the startup line as
  admission=experimental|native.
- The plan's final else is now gemma4-explicit; an unknown resolved
  profile refuses with its own name. Gemma4 behavior unchanged.
- Variant naming follows the existing pattern: "qwen35-" +
  compatibility.model_variant (real file "qwen35-27B"; fixture
  "qwen35-4L/128d"). Serve family/parameter_size derive from the
  loaded file the same way (family "qwen35", size = variant suffix;
  no hard-coded "27B").

### CPU session + reset semantics
New Qwen35CPUSession (aesir_engine/qwen35_session.mojo, 248 lines;
lives at engine root because `from aesir import AesirEngine` does not
resolve from inside core/ — proven by compile error, same reason the
cli/ modules sit where they do). It wraps AesirEngine, which already
holds qwen35_blocks + the persistent qwen35_state (Q35-3a).
- Prefill: batched path in _prefill_batch_cap chunks (pure-prefill
  chunks + one sampling chunk); decode: per-token _forward_position.
- reset(): serve calls it before every NON-resident request.
  It snapshots the committed stream into cached_stream (inspection
  only — no reuse is claimed or performed), draws a fresh KVCache
  for the full-attention layers, and returns position to 0. It does
  NOT wipe qwen35_state itself: the wipe is owned by the engine's
  reset-on-position-0 rule (core/inference.mojo — both qwen35
  forwards call state.reset() exactly when start_pos == 0), so the
  next conversation's first forward starts from zeroed SSM state
  while a resident continuation (which skips reset and never
  restarts at position 0) keeps the state bit-exact (Q35-3a d1/d2).
  A genuinely new conversation = reset() + begin_turn at position 0.
- cancel() mid-turn sets reset_required: a cancelled SSM stream is
  not resumable; the next begin_turn refuses until reset() (whose
  position-0 forward wipes state honestly).
- Text: no chat template in the fixture, so the session encodes the
  serve's prompt text as one plain stream (system first at position
  0, BOS at position 0 only) — the _run_generation raw-text contract.
  Sampling maps NativeSamplingConfig -> GenerationConfig
  (temperature/top_k/top_p/repetition_penalty/seed; min_p and
  repeat_last_n have no CPU-forward counterpart and are not claimed).

### Capability truth table (qwen35 CPU session)
| capability | value | basis |
|---|---|---|
| session_residency | TRUE | persistent qwen35_state + KV across resident turns; proven below |
| exact_prefix_reuse | FALSE | no KV/SSM snapshot reuse; Q35-5 owns it; serve passes prefix_cache=False for qwen35 so /health reports false |
| conversation suspend/restore | NOT implemented | no state copy in/out; nothing faked |
| structured output (json_boolean) | refused | configure_output raises for any mode |
| tool calls | refused | configure_tool raises for any name |
| memory_injection (health flag) | serve-level flag unchanged | the OpenAI route's system-text injection works over any session; not a session capability claim |
| anchor/post_history | works | serve-level text append, session-agnostic |

### Dispatch (native_serve / native_settings)
- Gate: acceleration "cpu" admitted ONLY with profile "qwen35";
  cpu + any other profile keeps the verbatim refusal "Native service
  requires a supported CUDA or HIP profile; no CPU fallback".
  qwen35 + cuda/hip/auto refuses: "Qwen 3.5 native serve is CPU-only
  in Q35-4a; HIP qwen35 execution lands in Q35-6".
- CPU path constructs NativeModelPlan directly (no device selection);
  construction branch builds Qwen35CPUSession and calls serve_loaded
  with plan.memory.device_bytes, backend="cpu", prefix_cache=False,
  experimental=plan.experimental. Resident-continuation gate in the
  OpenAI route gains profile "qwen35" (line 475).
- native_settings: config acceleration_backend whitelist gains "cpu"
  (commands.mojo already admitted "cpu" for the general CLI).

### Fixture tokenizer (item 5)
The forward fixture carried only tokNNNN spellings: RuneWeaver would
encode all text to per-byte <unk>. Generator extended (weights and
RNG consumption untouched): id 0/1/2 = <unk>/<s>/</s>, id 3 = newline,
ids 4..98 = printable ASCII 0x20..0x7E in order, ids 99..1023 keep
tok%04d. RuneWeaver's SentencePiece path splits per codepoint, so
text encodes one token per character and every generated id decodes
to its own spelling. Regenerated fixture sha256
140e1750e44c8bdc27115153bfe7743304863172c0b5656672d46150b7cbfe55
(Q35-1 tiny fixtures regenerate byte-identical, sha256 93d5864d...
et al. unchanged; Q35-3 forward test still ALL PASS with the banked
greedy sequence 1019 675 143 ... — tensor payloads untouched).

## Files changed
- aesir_engine/core/runtime_plan.mojo: qwen35 whitelist + branch
  (lines 21-22, 28, 33-45, 64-75), experimental field (19),
  gemma4-explicit else.
- aesir_engine/qwen35_session.mojo: NEW, Qwen35CPUSession.
- aesir_engine/cli/native_serve.mojo: session import (11),
  serve_loaded experimental param (300) + startup line (318) +
  /health experimental_admission (585), resident gate (475),
  --experimental-qwen35 flag (714, 744), dispatch gates (797-806),
  CPU plan branch (843-858), family/parameter_size (864-866),
  qwen35 construction branch (869-871).
- aesir_engine/cli/native_settings.mojo: "cpu" config backend (20-21).
- scripts/make_qwen35_fixtures.py: forward-fixture toy tokenizer.
- aesir_engine/tests/test_qwen35_session_q35_4.mojo: NEW reference.
- aesir_engine/tests/probe_qwen35_runtime_ripple_q35_2.mojo:
  UPDATED expectations (see Regression).
- hidden_files/qwen35-adapter/: build-q35-4.sh, q35_4_bench.py,
  logs (q35-4-*.log), these notes.

## Proof (side port 18435, fenced units, fixture, greedy)
Serve command: aesir serve <forward fixture> --accel cpu --profile
qwen35 --experimental-qwen35 --port 18435 --context 512
--max-tokens 16 --model-store .aesir/q354-store (isolated store: the
live gate owns .aesir/models; an absolute store path is refused by
design). Startup: "backend=cpu; profile=qwen35; context=512;
admission=experimental".
- /health 200 (q35-4-bench-resident.log): profile qwen35, backend
  cpu, capabilities session_residency=true, exact_prefix_reuse=
  false, experimental_admission=true.
- Turn 1 (session_id, system + "alpha bravo charlie"): 200,
  prompt_tokens=56, reply == in-process reference R1 exactly.
- Turn 2 resident (full history resent with session_id): 200,
  usage prompt_tokens=90, reused_prompt_tokens=72 (the exact
  committed position after turn 1), evaluated=18 (the raw delta
  "delta echo foxtrot" at one token per char). Reply == the
  in-process A+B reference R2 EXACTLY (reference computed with the
  session class itself over AesirEngine forwards, greedy; token
  streams printed in q35-4-session-test.log: STREAM1/STREAM2 are
  the token-ID ground truth, POS1=72, POS2=106).
- Fresh-instance control (second unit, same turn-2 request, same
  session_id): 200, reused=0, prompt_tokens=193 (full re-eval), and
  a DIFFERENT continuation (q35-4-bench-fresh.log).
- Refusals (q35-4-refusals.log): cpu+llama3 -> verbatim no-CPU-
  fallback refusal; hip+qwen35 -> CPU-only message; cpu+qwen35
  fixture WITHOUT --experimental-qwen35 -> registry refusal "Qwen
  3.5 hybrid is recognized, but this geometry has no matching
  native profile yet.", nothing served.
- Both proof units stopped; port 18435 free; aesir-gate (:18434)
  active and untouched throughout.

## Regression
- Full engine compile exit 0 (q35-4-engine-build.log,
  ENGINE_BUILD_EXIT=0; build-q35-4.sh full run in q35-4-build.log).
- Q35-1 loader test: ALL PASS (q35-4-regress-q35-1.log).
- Q35-2 registry test: ALL PASS, unchanged sources
  (q35-4-regress-q35-2.log) — signature refusals for real files
  (Q40-1-style) intact: classify/inspect untouched.
- Q35-3a forward test: ALL PASS (q35-4-regress-q35-3.log), greedy
  sequence identical to banked.
- Session reference test: ALL PASS (q35-4-session-test.log):
  resident R2 == reference, turn 1 after reset reproduces exactly,
  fresh session reproduces R1+R2.
- Ripple probe UPDATED (item 7): the Q35-2 probe asserted
  NativeModelPlan REFUSES qwen35 under auto and explicit — that
  expectation is superseded by this slice's purpose (serve
  admission is Q35-4's own deliverable). The probe now asserts the
  new truth and ALL PASS (q35-4-ripple.log): (r1) real file auto ->
  native qwen35, experimental=False; (r2) explicit -> native;
  (r3) fixture refused without the opt-in; (r4) fixture admitted
  with the opt-in as experimental, variant qwen35-4L/128d, context
  512; (r5) unknown profile still refused by name. The aesir-gate
  unit (HIP llama3) does not pass through this admission at
  runtime and is untouched.
- Full 905 matrix NOT re-run (slice order; baseline 901/905 stands).

## Named gaps / next
- Real-file CPU serve (27B) unproven here: session construction is
  geometry-generic, but loading the real file through the forward
  path is Q35-3b-gated (F16 materialization cannot fit beside the
  live set anyway).
- Resident continuation feeds the raw new user message (the serve's
  resident_delta contract), while a stateless resend tokenizes the
  formatted "User: ..." stream — the two token streams differ by
  design of the existing HS-6 seam; the resident stream is the
  continuation the reference proves.
- SSM snapshot/prefix reuse (Q35-5), HIP qwen35 (Q35-6) untouched.
