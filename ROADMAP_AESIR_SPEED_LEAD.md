# AESIR speed-lead roadmap

Established 2026-10-01. Owner: native compute, runtime and measurement domains.
Status: **active plan; SPD-00 measurement and native timeline slices implemented, full gates open**.

Volmarr's objective is to make AESIR substantially faster than Ollama while
preserving useful answers, stable operation and the second-brain integrations.
The first goal is a repeatable **2× lead in each designated meaningful workload**
on the existing RTX 2060 Max-Q. The stretch goal is a **3× lead**. These are
acceptance targets, not promises that every hardware/model combination can reach
them. Hardware feasibility and measured quality decide what can be shipped.

This is the focused speed track within [BEST_IN_CLASS_GAMEPLAN.md](BEST_IN_CLASS_GAMEPLAN.md).
It supplies the next performance work orders without replacing the application
program. [CAPABILITY_LEDGER.md](CAPABILITY_LEDGER.md) owns current capabilities;
[AI.rules.part2.md](AI.rules.part2.md) owns evidence and failure rules. All SPD
items below retain open acceptance gates, including items referring to existing
primitives. The first implemented SPD-00 slice is documented in
[SPEED_MEASUREMENT.md](docs/SPEED_MEASUREMENT.md): portable provider controls,
checked physical stage/traffic measurements and four independent 3B logit vectors.
It changes measurement, not inference kernels, and earns no general speed lead.
The next [owned CUDA timeline slice](docs/NATIVE_CUDA_TRACE.md) physically admits
30224/450082 matching kernel launches for short/long prompts. Projections dominate
measured GPU work; long scores/attention are secondary. Raw trace/process overhead
is kept separate from service scores. Semantic stage, cache/residency and broad
quality/second-session gates remain open.

## 1. Measured starting point

Baseline runtime revision: `59094de4fdcd9f423c974043f802c295a217a533`.
Binary SHA-256: `f3442a1e5915cb43ec4da8a0f885ff38710a02b6ef795515dbe1f72c36ceda2b`.
Model: Llama 3.2 3B Q4_K_M, weights SHA-256
`dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
Hardware: RTX 2060 Max-Q, 6 GiB, sm_75; driver 595.91.07.
Locked tooling: Mojo 1.0.0 / MAX 26.5.0. Physical native execution is Linux x86-64.

AESIR already has prepared layer descriptors, packed Q4/Q5/Q6 projections, fixed
RMS tiles, exact-prefix retention, four-token causal prefill, checked compact
scratch, F16 KV and tested service/deadline/reset boundaries. Four-token prefill
made the fresh 1070/128 native request about 1.82× faster than its preceding
native build. It has **not** established an overall speed lead over Ollama.
See [the long-token manual](docs/NATIVE_LONG_TOKENS.md) and
[its native regression evidence](docs/evidence/native-long-tokens-2026-10-01.md).

The paired installed-service series used identical GGUF bytes, context 4096,
greedy sampling, the same requested user/system text and equal output ceilings.
Each repeat value is the median of three samples. All 40 requests completed.

| Workload | AESIR seconds | Installed Ollama seconds | Current result |
|---|---:|---:|---|
| First appearance, short input, 32 output tokens | 1.057 | 0.904 | Ollama 1.17× faster |
| First appearance, short input, 128 output tokens | 3.698 | 2.769 | Ollama 1.34× faster |
| First appearance, longer input, 32 output tokens | 3.192 | 1.023 | Ollama 3.12× faster |
| First appearance, long input, 128 output tokens | 13.559 | 3.325 | Ollama 4.08× faster |
| Repeated short input, 32 output tokens | 0.820 | 0.870 | AESIR 1.06× faster |
| Repeated longer input, 32 output tokens | 0.845 | 0.880 | AESIR 1.04× faster |
| Repeated long input, 128 output tokens | 3.557 | 2.869 | Ollama 1.24× faster |
| Repeated short input, 128 output tokens | 3.314 | 2.719 | Ollama 1.22× faster |

First appearances can share earlier prefix/framing tokens; they are not strictly
cache-disabled tests. The one-word arithmetic case favors AESIR, but is excluded
from the speed-lead score: token counts differ and it cannot represent sustained
inference. Ollama's first arithmetic call also included loading an initially
unloaded model while AESIR was resident.

Ollama uses q8_0 K/V; AESIR uses F16 KV. Chat templates differ by 20 prompt tokens
in these cases, and longer output texts differ. Ollama first/repeated completions
can also differ despite greedy settings. Its installed service reports version
0.0.0 and uses a CUDA llama-server runner. These observations describe this
installed service, not every upstream Ollama release or full numerical parity.

[Baseline explanation](docs/evidence/provider-speed-2026-10-01/COMPARISON.md),
[32-token samples](docs/evidence/provider-speed-2026-10-01/paired-current.json),
[128-token samples](docs/evidence/provider-speed-2026-10-01/paired-long-output.json)
and [actual runner flags](docs/evidence/provider-speed-2026-10-01/provider-runtime.json)
are committed alongside this roadmap. [Evidence provenance and schema](docs/evidence/provider-speed-2026-10-01/README.md)
record request ordering and the missing full-response/timing boundaries.

## 2. Define “faster by far” numerically

For equal successful work, latency speed ratio is Ollama elapsed time divided by
AESIR elapsed time. A 2× lead means at most half the time. Evaluate prompt
processing, decode and whole-request latency separately, then require the
application result to agree. Do not add or multiply isolated kernel speedups to
predict a whole-request win.

These illustrative limits are arithmetic goals against the archived observations:

| Designated case | Historical Ollama seconds | AESIR 2× target seconds | AESIR improvement needed versus current |
|---|---:|---:|---:|
| First short input / 32 output | 0.904426 | ≤0.452213 | about 2.34× |
| First short input / 128 output | 2.768652 | ≤1.384326 | about 2.67× |
| First longer input / 32 output | 1.022593 | ≤0.511297 | about 6.24× |
| First long input / 128 output | 3.324745 | ≤1.662373 | about 8.16× |
| Repeated short input / 32 output | 0.870499 | ≤0.435249 | about 1.88× |
| Repeated longer input / 32 output | 0.879837 | ≤0.439918 | about 1.92× |
| Repeated long input / 128 output | 2.868817 | ≤1.434408 | about 2.48× |
| Repeated short input / 128 output | 2.719279 | ≤1.359639 | about 2.44× |

Refresh the competitor at release time: the actual goal is half its **current**
paired median, not victory over a stale reference. A 3× stretch divides the new
Ollama median by three. The overall lead requires each designated case to pass;
a geometric mean cannot conceal a losing case. Declare exact hardware, model,
precision mode, cache policy and concurrency for every earned claim.

Milestones:

1. **M0: trustworthy measurement.** Separate fresh prefill, cached work, decode,
   first-token latency, memory and service overhead; establish feasibility.
2. **M1: parity.** AESIR no slower than current Ollama in every designated case.
3. **M2: clear lead.** At least 2× in each designated case, with quality/recovery
   gates and no material regression in the extended suite.
4. **M3: stretch lead.** At least 3× in each designated case, revalidated under
   thermal steady state and the declared workload/concurrency boundaries.

If hardware measurements rule out a target through ordinary one-token decode,
record the ceiling and move to verified work reuse. Never replace a failed
same-model target with a smaller model, fewer output tokens or silent offload.

## 3. Benchmark and quality contract

Use two complementary tracks:

- **Installed-service comparison:** preserve each provider's declared default
  template/KV policy, compare the same human requests and useful output lengths,
  and describe policy differences. This measures the service Volmarr experiences.
- **Controlled engine comparison:** pin tokenizer/template and exact input IDs,
  model bytes, KV precision, sampling and cache policy where both providers can
  actually expose them. Keep unsupported controls explicit. This isolates engine
  differences without pretending the current API comparison is identical math.

SPD-00 must make the following matrix executable. Existing tooling does not yet
supply every mode:

| Dimension | Required coverage |
|---|---|
| Input length | approximately 32, 256, 1024 and 3072 tokens; exact actual IDs/counts retained |
| Output length | 32, 128 and 256 generated tokens; isolate early EOS from length-controlled cases |
| Cache | disabled fresh; changed prompt with shared system text; exact repeat; continued conversation |
| Residency | already loaded; separately controlled load/startup; no cached-versus-cold score mixing |
| Metrics | prefill tokens/s, decode tokens/s excluding first token, first-token latency, request latency, median/p95, failure counts, peak VRAM/RSS and allocation growth |
| Sampling | greedy first; fixed-seed sampled/repetition cases for correctness |
| Operation | single request first; bounded competing clients as a distinct throughput/latency track |

Run both resident and individually isolated GPU-residency modes when they fit.
Alternate/randomize provider order with a recorded seed. Keep host compilation
and unrelated GPU work idle. Record clocks, temperature, throttling and power when
available; lack of counters is a limitation, not permission to invent telemetry.
Use at least 10 measured samples per scoring case, two independent sessions and
interval estimates. Tail/soak runs need enough observations to interpret p95;
three-sample exploratory timings cannot certify stable superiority.

Retain every warmup, failure, complete response, token count, binary/model hash,
provider version, declared policy and measurement harness revision. A failed
candidate remains in the evidence record. Compare the strict native reference
against optimized AESIR with full-logit/token checks; the cross-provider tool
must not demand text equality where templates/precision differ.

Precision contracts are separate. Order-preserving paths retain the current
exact-reference gate. Tensor-Core arithmetic, changed reductions or quantized KV
may change logits: define independent error/top-token/probability and quality
budgets **before** tuning, publish the change and keep a strict reference mode.
Evaluate held-out factual, code, Unicode, long-context retrieval, repetition and
sampling cases. Arbitrary tolerances selected after seeing results are invalid.
Fewer tokens, hidden truncation, missing citations or reduced context cannot earn
a performance win.

## 4. Work sequence, ownership and dependency gates

Each slice uses a scoped TASK file published before implementation, focused
INTERFACE updates, physical evidence, a complete runtime connection, and a
measured release decision. Existing primitives do not make these tasks complete.

| ID | Priority | Owning domain | Deliverable | Dependencies |
|---|---|---|---|---|
| SPD-00 | First | scripts/tests/runtime observations | Fair benchmark modes, independent correctness baseline and hardware feasibility | current measured release |
| SPD-01 | Highest | core projection/session/buffers | Genuine matrix prefill and shape-selected bounded chunks | SPD-00 |
| SPD-02 | Highest | core GPU primitives/toolchain | Proven sm_75 Tensor-Core prefill candidate | SPD-00; integrate with SPD-01 |
| SPD-03 | High | core attention/session | Fused causal attention with bounded workspace | SPD-01 interface; SPD-00 |
| SPD-04 | High | core execution/runtime ownership | Reduced launches, transfers and synchronization; graph replay if supported | SPD-00; stable SPD-01 shapes |
| SPD-05 | High | core projection/sampling | Decode kernels selected by measured bandwidth and full-model quality | SPD-00; SPD-04 where useful |
| SPD-06 | Medium | core cache/memory/session | Validated cache layouts, optional q8 KV and allocation reuse | SPD-00; SPD-03 |
| SPD-07 | Conditional high | core/session/paradigms | Verified speculative/assisted decode when ordinary decode hits a ceiling | SPD-01/02; SPD-05; quality baseline |
| SPD-08 | Later | core runtime/server admission | Bounded multi-sequence GPU throughput | stable single-request M1; SPD-06 |
| SPD-09 | Required | tests/operations/release | Soak, adverse-path gates, reproducible per-device tuning and rollback | each promoted candidate |
| SPD-10 | Final | integration/application | Earn M2/M3 and validate second-brain provider selection | required cases and SPD-09 pass |

### SPD-00 — Establish trustworthy measurements and a hardware ceiling

Extend the existing paired provider tool to explicit output lengths, recorded
first/repeat/cache-disabled modes, complete results and observed controls.
Add opt-in native timing boundaries around tokenization, prefill, logits/sampling,
GPU synchronization, decode and socket work. Instrumentation must be disabled in
release speed scoring unless the cost is measured and identical.

Trace a full representative forward. Attribute time to Q/K/V, output projection,
FFN gate/up/down, attention, RMS/RoPE/SiLU, sampler, CPU enqueue gaps and copies.
Measure sustainable bandwidth on this actual Max-Q device at observed clocks.
Count active weight/KV bytes per generated token from validated tensor spans;
GGUF file size alone is not an exact DRAM traffic measurement. Estimate the
one-token traffic floor using active bytes and sustainable bandwidth, separately
from launch and arithmetic cost. Use Amdahl's law to reject low-impact detours.

Build an independent full-model logit/token oracle for the pinned 3B fixture;
current sequential/tiled equality proves a regression reference, not an external
oracle. Record why Ollama first/repeat outputs can differ before treating its
responses as a quality reference. Use primary format/model/runtime sources.

**Exit:** reproducible profiles, independent numerical contract, raw measurement
schema and a written feasibility decision for M1/M2/M3. No estimated ceiling may
be presented as achieved throughput. Existing restricted hardware-counter access
must not trigger driver or permission changes in this slice.

### SPD-01 — Replace four independent dot products with matrix prefill

First optional SIMT shared-tile candidate is [implemented and physically checked](docs/NATIVE_MATRIX_CANDIDATE.md).
Complete native-reference values and selected independent real-weight dots pass
fixed primitive budgets. Batch 4 loses every tested shape, so dispatch is unchanged.
Batch 32 gains up to about 1.27x on FFN in this session but K/V still lose. Larger
shared-column/row tuning now exercises six bounded choices. Every batch-four
choice loses; no default promotion. Best batch32 FFN reaches about1.29x in this
session. [Tuning evidence](docs/evidence/matrix-tile-tuning-2026-10-01/README.md).
The next prerequisite is physical Turing Tensor-Core execution; full-model/control
integration remains open.

The four-token path shares weight decoding but still launches many token-local
operations and performs independent scalar/warp dot products. Treat it as the
reference bridge, not the final prefill design.

Implement tiled packed-weight matrix multiplication for a bounded prompt block.
Reuse decoded weight/activation tiles across rows and input positions. Sweep
chunk sizes such as 8/16/32/64 under a measured workspace budget; do not assume
larger is faster. Keep all token-local intermediates disjoint and plan live ranges
so shared workspace is reused only after queued consumers finish. Integrate
batched RMS, Q/K/V, gate/up/down and output projection as supported by proofs.

Retain batch-one/four references and explicit policy controls. Select chunk size
by admitted shape/device/remaining input and a bounded control-time budget.
Current controls poll at at most four input tokens: larger chunks cannot become
default until measured cancellation/deadline latency is no worse, or an explicitly
reviewed interface policy defines the change. Count only synchronized positions
as committed; process smaller tails without reading padding or future KV.

**Exit:** independent projection checks, full model/reference logits, 1024/3072
input cases, tail/context guards, sampling/restore and interruption recovery.
Aim first for at least 2× **prefill-only** improvement over current AESIR; M1/M2
still require the actual paired whole-request results.

### SPD-02 — Prove Tensor-Core prefill on Turing

Physical prerequisite completed2026-10-01: public m16n8k8 F16/F32 MMA on the
locked toolchain passes all50688 exact independent synthetic outputs,5400 guards
and9 invalid spans. The pinned RTX2060 target's +ptx63 caused LLVM selection and
PTX JIT failures; the isolated matching +ptx65/sm_75 DeviceFunction target works.
Offline emitted-PTX disassembly contains HMMA.1688.F32. Initial compile/JIT,
CSV-formatter and trace-admission failures are retained. No default dispatch or
real-weight precision/speed claim. [Operation](docs/NATIVE_TURING_MMA.md).
The next slice must validate original packed Q4_K/Q5_K/Q6_K projections with
bounded F16 conversion, fixed numerical budgets and complete equal-work timing.

That first packed candidate now passes1,658,880 complete native-reference values,
2100 selected independent dots,144 synthetic tails and12 rejected spans after
split-weight F16 high/residual refinement. The initial single-component precision
failure remains. All28 measured shape/batch speed cases lose; no promotion.
[Operation](docs/NATIVE_PACKED_TURING_MATRIX.md). Next measure coalesced shared
staging, preserving budgets and strict references. Full-model gates remain open.

The shared-staging refinement passes three row choices/all4,976,640 native values
and6300 selected independent dots. Rows64/batch32 ratios are1.782/1.054/.771/
1.797/1.920/1.876/1.524 across Q/K/V/output/gate/up/down. Every batch4 shape
still loses. These are larger-batch primitive gains only; production remains
strict. Next measure wider staging, then separately earn full-model precision,
state/control/recovery and provider gates. Same operation manual owns reproduction.

Confirm that the locked Mojo/MAX toolchain can compile and physically execute an
appropriate sm_75 matrix primitive. Start with a minimal real matrix smoke test,
then all model projection shapes. Current online TensorCore APIs are research
pointers; they do not prove this pinned runtime or GPU supports the same path.
NVIDIA documents Turing FP16 input / FP32 accumulation support. [Turing guide](https://docs.nvidia.com/cuda/turing-tuning-guide/index.html),
[Modular TensorCore API](https://max.modular.com/stable/api/mojo/layout/tensor_core/TensorCore/).

Decode packed blocks into bounded matrix tiles, evaluate layout/alignment,
shared-memory reuse, bank conflicts, register pressure and tail masks. Keep
workspace bounded. A full F16 copy of roughly 3B parameters plus KV/runtime
memory is unsuitable as the default strategy on a 6 GiB device. GGUF Q4_K/Q5_K/
Q6_K are not directly interchangeable with integer Tensor-Core operand formats;
any conversion requires its own scale/layout/precision contract.

FP16 operands/reordered reductions may differ from the F32 reference. Evaluate
and publish that numerical/quality boundary; do not call it bit-exact without
proof. Keep strict operation available. Do not substitute an external inference
engine or copy another project's kernels without license/provenance review.

**Exit:** physical matrix execution, real-weight errors, full-model quality and a
measured fresh-prefill gain beyond SPD-01. If the lock cannot support it, record
the blocker; an isolated toolchain-change task needs compile/ABI/platform evidence.
Do not silently upgrade dependencies or assume Ampere/Hopper-only mechanisms.

### SPD-03 — Reduce long-attention memory and launch work

Profile scores, softmax and value reduction together. Evaluate a tiled causal
online-softmax attention kernel that avoids a full materialized score matrix and
reduces repeated GQA K/V reads. Reuse each admitted KV head across its query group
where the schedule permits. Bound both prefill and decode attention workspace.

Preserve scaled RoPE, masks, position/head mapping, context limits and numerical
stability. Online reductions change arithmetic order; validate independently and
under the declared quality mode. Cover zero/invalid rows, nonfinite inputs,
non-power-of-two history and near-context tails. Derive unaligned guards before
using shared memory. Keep the existing chronological kernel as a reference.

**Exit:** independent attention math, full-model quality at tested long contexts,
lower measured workspace/traffic and end-to-end gain. Synthetic 8192-history
attention alone cannot certify whole-model maximum-context operation.

### SPD-04 — Reduce CPU launch and synchronization overhead

Use SPD-00 traces to decide whether enqueue/synchronization is significant. Fuse
compatible residual/RMS and RoPE/cache operations; test a combined gate/up/SiLU
schedule when register pressure permits. Keep attention dependencies explicit.
Avoid host round trips for intermediate tensors. Retain the minimum host-visible
sampled token/control result needed by streaming and tokenization.

Evaluate CUDA graph replay for one decode step or bounded prompt chunks after
proving capture support in the locked runtime. NVIDIA describes graphs as reusable
work submission that can reduce repeated CPU launch setup. [CUDA Graphs](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cuda-graphs.html).
Graph keys must cover model identity, shape, context buckets and precision policy;
position, token, sampler state and current bounds must update correctly. Own graph
and buffer lifetimes, and invalidate them on model/process changes.

Keep commit synchronization, poison semantics, EOF/cancellation and bounded
streaming response times. If capture is unsupported, retain the proven stream
path before execution. A failed GPU launch never authorizes reuse through a
fallback. Avoid persistent whole-model kernels until residency/deadlock and
control responsiveness are proved.

**Exit:** reduced CPU gaps/launch counts, matching numerical/state behavior,
measured first-token/request improvement and no deadline/disconnect regression.

### SPD-05 — Optimize sustained decode against the measured bottleneck

Treat single-token decode as a separate shape from prompt matrix processing.
Optimize coalesced packed reads, row/block scheduling, bounded integer unpacking,
register use and vector loads for actual Q4/Q5/Q6 shapes. Evaluate Q/K/V and
FFN gate/up fusion where it shares activation reads without forcing spills.
Include the large tied vocabulary projection and sampler in the profile.

Measure practical bytes per token and achieved bandwidth. If sampling matters,
optimize exact greedy selection and admitted top-k/top-p/repetition algorithms;
never prune the vocabulary, silently change sampling or skip required logits.
Device-side multi-step decode can reduce host launch work only if it preserves
EOS, context boundaries, RNG state and responsive streaming/control polls.

**Exit:** at least parity in the current repeated 128-token cases, then M2 targets;
full sampled/greedy/Unicode/EOS replay and no short-request regression. Keep
ordinary decode as the reference for speculative paths. A bandwidth-bound trace
redirects work toward reducing verified target passes, not endless unrolling.

### SPD-06 — Improve KV layout, prefix use and buffer lifetime

Keep F16 KV as the strict reference. Evaluate layout changes and an explicit q8
KV mode only after independent quantize/dequantize, scales, tail handling and
long-context quality checks. Compare F16 versus F16 and q8 versus q8 where the
competitor admits them; separately report the real installed-service comparison.
Quantized KV may save memory but add conversion cost, so enable by measured shape
rather than assumption.

Reuse owning GPU/host workspace across requests and bound pinned staging, token
rings, decoder buffers, attention scratch and retained prefix bookkeeping.
Additional prefix entries require quotas and keys for model/tokenizer/RoPE,
position, precision and tenant isolation; cache eviction cannot invalidate live
consumers. Do not introduce cross-client shared mutable sampling/conversation
state. Logical reset remains distinct from secure erasure.

**Exit:** exact allocation/accounting, no growth across repeated resets, bounded
cache/eviction behavior, numerical/quality checks, and measured memory/latency gain.
Count cold conversion/cache preparation cost instead of hiding it in warmup.

### SPD-07 — Add verified assisted/speculative decode if needed

If ordinary decode cannot reach M2 under its traffic ceiling, reduce target-model
passes per accepted token. First investigate bounded token/ngram proposals, then
an optional small draft model only if the full VRAM budget fits. Verify proposals
in batches through the actual target model; the existence of an acceptance helper
in core does not supply a connected speculative decoder.

For greedy mode, preserve the target's verified token choices. For sampled mode,
implement the appropriate acceptance and residual correction distribution and
an explicit RNG/replay contract. Proposal/target KV, committed position, sampler
history and UTF-8 output must roll back together on rejection. Emit only verified
tokens, never speculative guesses. Track accepted tokens per target pass, draft
cost, rejection rate, memory, latency and streaming behavior.

The research establishes a mechanism to investigate, not a speed claim for this
model/hardware. [Speculative sampling paper](https://arxiv.org/abs/2302.01318).

**Exit:** independent verification/sampling evidence, adversarial rejection,
EOS/context/cancel rollback and a whole-request win including every draft cost.
Keep low-acceptance workloads on ordinary decode through preselected policy.
Existing capability-ledger speculative primitives remain non-integrated until
these real model/state gates pass.

### SPD-08 — Add bounded throughput across concurrent requests

After single-request M1, evaluate microbatching separate sequences so their
weights are reused in the same matrix work. Session owns each sequence's KV and
sampling; server owns queue/admission/fairness. Include independent cache identity,
per-client quotas, cancellation, deadlines, maximum wait and memory admission.

Throughput and individual latency are separate scoreboards. A many-client tokens/s
win cannot claim faster one-user chat. Keep the original serialized path for
small workloads, and refuse unsupported pressure instead of oversubscribing VRAM.

**Exit:** real overlapping clients, isolation/fairness and queue-pressure tests,
bounded memory, measured throughput gain and declared per-request latency costs.

### SPD-09 — Make optimization selection stable and recoverable

Store validated tuning decisions by device capability, driver/runtime/source
fingerprint, model digest, shape and precision mode. Measure candidates at bounded
cost; reject nonfinite/mismatched outputs before retaining timings. A deterministic
known-good path remains available. Stale/corrupt tuning files must fail safely.

Admission includes weights, KV, all live scratch, graph/planning allocations,
staging and a reserve for the desktop/embedding service. Every multiplication and
alignment remains checked. Report actual allocated memory; do not assume a free
memory snapshot guarantees subsequent allocation success. Exercise constrained
VRAM, delayed clients, socket pressure, cancellation, SIGTERM, disk-full tuning
publication, failed model load, and process-kill/restart ownership boundaries.

Run a thermal soak plus at least 1000 request/reset operations with RSS/VRAM
trend tracking, diverse public prompts and concurrent-client cases when enabled.
No leaked buffers, stale cache, wrong-model output or unbounded retry loops.
GPU fault recovery requires its own safe injected/observed test; until then poison
reuse and let the supervising process restart. Keep process replacement for model
switching while in-process CUDA context recreation remains unproved.

**Exit:** repeatable tuning, stable memory, truthful failures, recovery evidence,
clean build/launch fingerprints and no service/auth/resource regression.

### SPD-10 — Earn the lead and connect it to the second brain

Run the refreshed M0 benchmark matrix and quality/recovery gates on the exact
candidate binary, then verify exact pushed CI and the deployed checksum.
Publish per-case results, tails, failures and precision policy. Enable a fast path
only for the physically proved model/device/shape scope. Broader Llama/Qwen/Gemma,
other GPUs, CPU and platforms need their own gates.

Only after current representative HyDE/search/cluster-label requests favor AESIR
with useful complete answers should a separate integration slice propose changing
Bifröst's provider default. Preserve external AI keys/scopes, bounded append
queues, quotas, original embeddings and source provenance. Inference benchmarks
must not rebuild or overwrite the production knowledge graph.

**Exit:** M2 or M3 earned in each declared case, live recovery/identity checks,
operator/AI manuals and preserved rollback. If a target is infeasible, publish
its measured bound and a precise next research step; do not label the overall
objective achieved merely because a microbenchmark improved.

## 5. Architecture and release rules

Loader owns GGUF shapes, packed spans and format interpretation. Core owns
numerics, scratch/KV, execution and state. The aesir facade exposes supported
policies/capabilities. CLI/server own request parsing, authentication, queues,
framing and service observations. Python tools only build, supervise, measure or
independently test; they do not perform or substitute model inference.

Before each implementation slice: publish its task contract, update owning
interfaces and preserve the current measured binary/manifest plus scalar/native
references. During work: admit unsupported hardware/shapes before launching,
keep controls/cleanup explicit and retain failed trials. After work: run relevant
independent numerical, real model, state/API and memory gates, document actual
scope, push to main and observe exact CI before claiming success.

Current live defaults remain context 4096, completion 256, deadline 45000 ms and
queue 2 until a separately justified policy change. Benchmark-only larger outputs
or deadlines require an isolated process and an explicit report; they do not
silently become production defaults. Hosted sm_89 compilation is not proof of
physical sm_75 performance. Correctness and security checks cannot be disabled
for a speed score. Dynamic settings must remain user-visible and portable.

Do not depend on Ampere cp.async, Hopper TMA/warp-group MMA, FP8 or newer device
features on the Turing baseline. Modern vendor examples may guide a separate
newer-device path, but the locked sm_75 kernel needs its own verified instruction,
layout and synchronization contract. NVIDIA's guidance makes memory access and
occupancy important tuning considerations; measure them rather than maximizing
registers or tile size by intuition. [Turing guide](https://docs.nvidia.com/cuda/turing-tuning-guide/index.html),
[CUDA best practices](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html).

## 6. Exact next implementation work order

Start with **SPD-00**, followed by SPD-01 and the small SPD-02 capability spike.
Do not implement all future techniques in one patch.

- Publish `TASK_speed_measurement_and_roofline.md` before substantial code.
- Own changes in `scripts/benchmark_second_brain.py`,
  `scripts/benchmark_native.py`, their evidence tests, and optional core timing
  boundaries with documented overhead. Keep benchmark data/config outside
  production compute code and avoid machine-local paths.
- Preserve and refresh the installed-provider baseline. Add explicit 32/128/256
  limits, cache/residency modes, provider ordering and reproducible prompt inputs.
- Separate first-token, prefill, decode, CPU enqueue and socket time; retain actual
  counts, complete text, failures, model/version/hash and all observed policy.
- Establish independent 3B logit/reference validation and the measured device
  bandwidth/traffic ceiling. Document which M2 cases need matrix prefill, reduced
  launch overhead or speculative target-pass reuse.
- Reject malformed/missing/mismatched evidence before computing ratios.
- Run a focused physical profile with other GPU work idle, then publish the raw
  evidence, the feasibility decision, exact source revision and next SPD-01 task.

## 7. Roadmap tracking

- [x] Record the measured installed-service baseline and its limitations.
- [x] Define parity, 2× lead and 3× stretch acceptance targets.
- [x] Map owners, dependencies, precision/memory contracts and release gates.
- [ ] SPD-00: implement fair modes, independent logits and hardware feasibility.
- [x] First SPD-00 slice: portable balanced 32/128/256 measurements, complete
  redacted evidence, physical stage/traffic/D2D checks and four strict-3B
  final-prompt vectors versus an independent F32-expanded CPU reference.
  [Results and remaining SPD-00 gates](docs/evidence/speed-measurement-2026-10-01/README.md).
- [ ] SPD-01: implement and validate genuine matrix prefill.
- [ ] SPD-02: prove and integrate the sm_75 Tensor-Core candidate.
- [ ] SPD-03: prove causal fused attention.
- [ ] SPD-04: reduce measured launch/transfer overhead; validate graph support.
- [ ] SPD-05: reach decode parity and then the declared lead.
- [ ] SPD-06: validate cache/layout/precision and bounded buffer reuse.
- [ ] SPD-07: connect verified speculative decode if required by the ceiling.
- [ ] SPD-08: earn separately measured concurrent throughput.
- [ ] SPD-09: pass tuning, memory stability, adverse-path and soak gates.
- [ ] SPD-10: earn and publish the complete scoped speed lead.

## 8. Reproduce the existing baseline

Run from a prepared checkout with the registered model, private native key and
explicit actual Ollama origin. Other GPU work should be idle. Reports use
exclusive creation; choose a fresh evidence filename. Replace the environment
variables with deployment values without publishing credentials.

```sh
python3 scripts/launch.py --check
python3 scripts/benchmark_second_brain.py --ollama "$OLLAMA_ORIGIN" --key-file "$AESIR_KEY_FILE" --model llama3.2:3b --ollama-gguf "$OLLAMA_GGUF" --context 4096 --samples 3 --order grouped --residency as-is --output paired-32.json
python3 scripts/benchmark_native.py --binary .aesir/launch/aesir --model llama3.2:3b --suite extended --max-tokens 128 --samples 3 --no-prefix-cache --output native-extended.json
```

The baseline paired script fixed its output ceiling at 32. The first SPD-00
slice now owns portable 32/128/256 controls, explicit order/residency and an
observed native cache-disable intent; it cannot disable Ollama caching. The
historical grouped/as-is command above preserves baseline policy. The original
archived 128-token paired JSON came from an isolated measurement harness; refreshed
portable evidence and commands are in docs/SPEED_MEASUREMENT.md. The native
extended command measures AESIR alone and cannot establish a provider speed ranking.
The native extended command starts a separate benchmark process and requires
verified VRAM headroom. Schedule its isolated GPU-residency session; do not add
it to already resident providers when the combined budget cannot fit. It does
not stop those services for you. No command here installs a future kernel or
changes the live provider.

## 9. Research basis and remaining uncertainty

Consulted 2026-10-01; these are primary research pointers, not certified locked
runtime implementations. Preserve licensing/attribution before adapting source.

- [NVIDIA Turing tuning guide](https://docs.nvidia.com/cuda/turing-tuning-guide/index.html):
  hardware-aware occupancy, memory and matrix-operation constraints.
- [NVIDIA CUDA best practices](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html):
  practical bandwidth and transfer measurement principles.
- [NVIDIA CUDA Graphs](https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/cuda-graphs.html):
  graph lifetime/submission mechanisms; locked-runtime capture remains to prove.
- [Modular TensorCore API](https://max.modular.com/stable/api/mojo/layout/tensor_core/TensorCore/):
  candidate native API; exact lock/device support remains to prove.
- [Chen et al., speculative sampling](https://arxiv.org/abs/2302.01318):
  proposal/verification research; no native AESIR speed or distribution proof yet.

The roadmap is complete as a planning artifact. The speed objective stays open
until its benchmark, quality, robustness and publication gates actually pass.
