# Complete generation quality after optional Turing matrix prefill

This test earns post-prefill numerical, sampling and fresh replay evidence for
an isolated strict Llama3.2 3B fixture. Read
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md),
[cooperative controls](NATIVE_TURING_FIXTURE_CONTROLS.md) and
[whole-model operation](NATIVE_TURING_MODEL_PREFILL.md) first. Production runtime
admission remains one/four tokens; this collector never serves requests.

## Causal execution and policies

test_turing_decode_quality.mojo creates one native four-token session and the
original mode0 optional32/four/scalar fixture. Both share immutable original
packed weights and a device context, with separate KV/sampler/output ownership.
The exact existing public37/1070-token prompts each run two policies:

| Policy | Evaluated prediction cap | Controls |
|---|---:|---|
| Plain greedy | 32 | temperature0, repetition1; existing defaults top_k40/top_p.95/min_p0/window64/seed42 |
| Seeded | 16 | temperature.7, top_k40, top_p.9, min_p.05, repetition1.1, window64, seed1234 |

Both owners sample using their existing native GPU samplers. Each actual native
chosen token is then supplied to both owners for the next prediction. Every
comparison therefore describes the same causal IDs. The matrix owner's actual
sample is retained even when different. This is teacher forcing, with no claim
about divergent, free-running matrix trajectories or general sampling-distribution
equivalence. Stop on the native EOS128001/EOT128009 or the declared cap; retain
actual finish and length. A prediction includes its sampled token even if it is
EOS. That final chosen token has not been fed back or committed to KV yet.

Every frame exports all128256 native/matrix logits, actual choices, position,
sampler history/draw counts and a verified complete committed-ID history. Plain
greedy consumes zero random draws; seeded consumes one per prediction. Reset and
configuration preserve the declared policy while clearing history/draw position.
A second fresh replay uses the first run's recorded native causal IDs. Each owner's
full vector is compared by actual F32 bits, including signed zero, plus exact
choice/state. A mismatch remains evidence rather than changing the replay inputs.

Pinned host snapshots retain one case only, at most two32×128256 F32 arrays:
32833536bytes/31.313MiB. They add no global device workspace or weight copy.
Fixture outer/padding guards are checked after each case,4352 total. Native
admission and exact committed-history checks remain mandatory; the guard count
refers to the optional fixture's existing red zones.

## Streaming evidence and unchanged gates

check_turing_decode_quality.py opens a regular file with O_NOFOLLOW/O_NONBLOCK,
rejects bytes above2GiB, reads one line at a time with a1024-byte limit and bounds
field counts/lengths. Ordered metadata/policies/public-ID digests/frames/full
vectors/replays/guards/totals are mandatory. Missing, duplicate, unknown, mixed,
late, nonfinite or inexact-F32 evidence rejects. EOF verifies the same descriptor's
size/modification time and exact streamed SHA-256. It never reads the whole CSV
into a String/list. At most96 first-round prediction frames are admitted.

Only one frame's two vectors and numerical scratch are retained at a time. The
JSON keeps every frame's metrics, actual choices, replay result and original IDs.
The independent CPU model's own weights/context allocations are separate from
this streaming bound. Numerical/sample/replay failures retain the complete
collection; structural failures preserve the partial report and refuse acceptance.
Output creation is exclusive. All outcomes have speed_scored=False.

The pinned test-only CPU oracle uses NumPy2.4.4/llama-cpp-python0.3.23, original
source/derived-F32/converter identity, context4096, F16KV, zero GPU layers,
non-flash attention and four CPU threads. It evaluates the exact public prefix
and every recorded native-forced token. Both owners must pass the original .05
maximum/.005 RMS/matching-full-vocabulary-argmax gates against CPU; the matrix
must also pass those gates against native. Actual native/matrix sampled choices
must equal for these cases, and each owner must replay exactly. No budget, seed,
prompt, cap or policy may be changed to turn a failed candidate into acceptance.
Model hashes are verified before and after the oracle. The native runtime never
imports Python, NumPy or llama-cpp.

## Reproduction and operations

Use MODEL/MODEL_SHA/ARTIFACTS and the separately derived reference/oracle variables
from the whole-model manual. Keep all attempts outside Git with new artifact
names. Finish all sm75/sm89/master and normal launcher builds before GPU work.
Capture the GPU collector once, then run the CPU checker. Hosted CI only compiles
GPU probes and tests synthetic malformed evidence; it cannot establish physical
execution. Confirm the normal binary/readiness separately.

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_decode_quality.mojo \
  -o "$ARTIFACTS/decode-probe"
timeout 900 "$ARTIFACTS/decode-probe" "$MODEL" > "$ARTIFACTS/decode.csv" 2>&1
"$ORACLE_PYTHON" scripts/check_turing_decode_quality.py "$ARTIFACTS/decode.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" --output "$ARTIFACTS/decode.json"
python3 scripts/test_check_turing_decode_quality.py
```

Exit0 requires the complete unchanged numerical/sample/replay gates. Exit1
retains failure/error evidence. Existing outputs refuse overwrite. A stopped or
failed collector retains its raw file but cannot pass the complete-record gate;
repeat with a fresh artifact name. Process wall times include logit copies/text
export/replay and are unscored. No throughput/provider ratio is produced.
Persisted restoration, production32-token integration, broader models/contexts,
concurrent requests, long soak and refreshed provider comparisons are separate
gates. Cooperative deadline checks do not guarantee hard real-time preemption.

## Verified acceptance — 2026-10-02

All four declared cases finish at their caps:96 prediction frames/12312576 complete
logit values per owner. Both owners pass every fixed CPU budget; matrix/native
also passes. All96 actual sample choices agree; every own fresh vector replays
bit-exactly, including committed-ID/history/draw checks and4352 fixture guards.
Worst matrix/CPU max.02834225/RMS.0039867654; native/CPU max.01564026/RMS.0026899044;
matrix/native max.02740193/RMS.0029158002. All frame metrics remain in reviewed
[physical evidence](evidence/turing-decode-quality-2026-10-02/README.md).

Master189 passes/zero failures/one explicit skip; nine portable streaming
contracts pass. sm75/sm89 probes compile. All host builds precede owned GPU
capture; CPU reference follows. The raw stream is680806792bytes, with complete
exclusive reports and no scored time. Normal binary remains f3442a1e;
authenticated active readiness/exact pushed CI are separate receipts. Reset and
restoration must preserve execution boundaries before production32 promotion;
this slice earns only the explicitly bounded generation/replay quality above.
