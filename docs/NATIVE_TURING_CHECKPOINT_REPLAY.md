# Exact-boundary checkpoint replay in the optional Turing fixture

This is an in-memory reset/replay gateway in the owning process and CUDA context.
Read [decode quality](NATIVE_TURING_DECODE_QUALITY.md),
[workspace admission](NATIVE_TURING_FIXTURE_ADMISSION.md) and
[cooperative controls](NATIVE_TURING_FIXTURE_CONTROLS.md) first. Production runtime
admission remains one/four; the existing persisted v1 conversation format remains
unchanged. Cross-process persistence and context recreation have separate gates.

## Plan and preflight ownership

FixtureReplayPlan copies committed token IDs and exact original1/four/32-token
tile counts, owner mode, weight/activation/KV allocation identities, policy/draw
state and the caller's pending native choice. The pending choice has been sampled
but has not entered KV/history. A retained FNV64 mutation checksum includes every
field and list value. It detects accidental plan changes; it is not an
authentication mechanism. No network endpoint accepts these plans.

The pure plan admits context1536/vocab128256, nonempty committed history below
1536, a valid nonterminal pending ID, validated existing sampling policy and
bounded draws. Native owner0 permits1/four tiles; optional owner1 additionally
permits32. Every count/total/ID must fit the copied history; temperature0 uses zero
draws. The plan owns no device allocation or external command/file path.

restore preflights structure/checksum/actual allocation identities/sampler window,
paired healthy idle state, disabled controls and no reset-required state before
any reset/reconfiguration/GPU operation. It rechecks strict3B geometry, context,
canonical native layout/physical lengths, disabled native prefix cache and checked
fixture spans. Foreign/damaged plans leave existing sampled and committed state
untouched. A changed repetition window requires a new sampler/session.

After admission, restore applies the saved policy and explicitly resets the owner.
It replays copied IDs with the exact captured tile boundaries, using existing
kernels with sampling disabled. It synchronizes the owning stream, verifies every
committed ID/history/position, then restores the draw count and checks allocation
identity again. An unexpected replay exception poisons that owner; further reuse
requires context recreation. This is a failure policy, with no physical GPU-fault
repair or cross-context restoration claim. The gateway uses no new global device
workspace or weight copy.

## Why record boundaries

The existing flat-token native restore reblocks history into four-token groups.
A32-token prefix followed by scalar generated IDs needs its original boundaries
for an exact own-owner numerical replay. The new test-owned plan retains those
boundaries explicitly. It does not silently extend the public persisted format
or reinterpret older snapshots.

The physical collector uses the existing37-ID graph prompt and the already
admitted greedy/seed1234 policies. Eight native-selected scalar additions create
45 committed IDs and a ninth pending prediction. Native boundaries are nine
four-token groups plus nine scalar IDs; matrix boundaries are32/four plus nine
scalar IDs. Both owners retain their separate KV/sampler state and shared weights.

The collector generates four continuation predictions, saves two four-frame F32
host snapshots (4104192bytes/3.914MiB), checks fixture guards, resets/replays both
owners and repeats those predictions on the recorded native causal IDs. It exports
complete before/after128256 native/matrix vectors, choices, history/draw positions,
plan counts, refusal and allocation-preservation records. Twelve damaged-plan
attempts must refuse without mutating either healthy owner's committed/sampled
state. Baseline/restored fixture guards total4352.

## Complete streaming and independent acceptance

check_turing_checkpoint_replay.py admits an ordered regular/no-follow CSV under
256MiB, with inherited1024-byte line/field limits and same-descriptor EOF/hash
checks. Every copied ID/tile/state/vector/replay/guard/refusal/total is mandatory.
The accepted decode report is itself bounded/no-follow, SHA-pinned, duplicate/
nonfinite-JSON rejecting, complete and independently passing under unchanged
budgets. It binds the actual checkpoint IDs, pending choices and continuation
choices to the prior public trajectories. Its raw CSV SHA remains recorded.

Only one frame's four vectors and numerical scratch are retained. Actual F32
bytes, including signed zero, determine own-replay mismatch counts; printed counts
must agree with those bytes. Every actual sample and state must repeat. Both
before/after matrix/native comparisons and all four CPU comparisons use the
original .05-max/.005-RMS/matching-full-vocabulary-argmax gates. The CPU oracle
uses pinned NumPy2.4.4/llama-cpp-python0.3.23, four threads, context4096/F16KV,
zero GPU layers and exact recorded native-forced IDs.

Complete numerical/replay/source failures retain every metric in an exclusive
JSON report. Structural or unexpected terminal evidence refuses acceptance with
its raw/partial report retained. Every outcome has speed_scored=False. Original/
derived model hashes and the accepted report are verified before/after the oracle;
CPU/model allocations are separate from the streaming bound. Nine portable
adversarial contracts prove parser/binding/bitwise behavior, not GPU execution.

## Operations

Use MODEL/MODEL_SHA/ARTIFACTS and the independent reference/oracle variables from
[whole-model operation](NATIVE_TURING_MODEL_PREFILL.md). ACCEPTED_REPORT is the
passing decode JSON, and ACCEPTED_REPORT_SHA is its verified SHA-256. Preserve all
attempts using new names. Finish sm75/sm89/master/normal builds before serial GPU
capture, then run the CPU checker. Hosted CI compiles GPU probes only.

```bash
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_checkpoint_replay.mojo \
  -o "$ARTIFACTS/checkpoint-probe"
set -o noclobber
timeout 300 "$ARTIFACTS/checkpoint-probe" "$MODEL" > "$ARTIFACTS/checkpoint.csv" 2>&1
"$ORACLE_PYTHON" scripts/check_turing_checkpoint_replay.py "$ARTIFACTS/checkpoint.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" \
  --reference-model "$REFERENCE_MODEL" --reference-sha256 "$REFERENCE_SHA" \
  --reference-provenance "$REFERENCE_PROVENANCE" \
  --accepted-report "$ACCEPTED_REPORT" --accepted-report-sha256 "$ACCEPTED_REPORT_SHA" \
  --output "$ARTIFACTS/checkpoint.json"
python3 scripts/test_check_turing_checkpoint_replay.py
```

Exit0 requires complete exact replay, source binding and every unchanged numerical
budget. Exit1 retains failure/error evidence. An existing report refuses overwrite;
a killed/incomplete capture cannot pass. Process/export/replay wall times are
unscored. Context recreation, persisted execution-plan schema, long-history/window
wrap restore, broader models/contexts, production32 integration, concurrency and
refreshed provider lead remain separate gates.

## Verified acceptance — 2026-10-02

All1026048 logits per before/after owner mode pass unchanged independent budgets,
source/sample binding and exact own F32-bit replay. The two policies each complete
four continuation predictions from their45-ID checkpoints. Worst matrix/CPU
max.009345055/RMS.0016755042; native/CPU max.008972168/RMS.0016683992. All copied
IDs/history/draw/pending/allocation checks,12 nonmutating damaged-plan refusals
and4352 fixture guards pass. [Reviewed physical evidence](evidence/turing-checkpoint-replay-2026-10-02/README.md)
retains every metric and source identity.

Master190 passes/zero failures/one explicit skip. Nine checkpoint/nine legacy
decode contracts pass, sm75/sm89 probes compile, and all builds precede GPU
capture with CPU reference afterward. The95727284-byte raw stream is bounded;
no time is scored. Initial typed-shift compile failure/source remains. Normal
binary stays f3442a1e; authenticated ready/prefill4 and exact pushed CI are separate
receipts. Next scope bounded batched causal attention/launch reduction under
existing exact vectors before broader runtime admission. Persisted/cross-context/
long-history/window-wrap/concurrency/provider gates stay open.
