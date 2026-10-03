# Tests Domain Interface Specification

`test_turing_prefill_trace.mojo` owns an opt-in direct native process and new0600
CSV. Installed NVTX symbols load dynamically before model work; fresh strategy2
case1/3 prefill is enclosed by one same-thread named range after reset/sync and
before synchronized pop. Complete actual committed IDs/state/F32 vectors, host
enqueue counts, guarded-cache SHA and guards export outside. No runtime dispatch
or numerical kernel changes. Read docs/NATIVE_TURING_PREFILL_TRACE.md; hosted
compile is not hardware execution, and profiler durations are never speed scores.

Optional explicit projection tracing binds each actual loaded tensor's complete
offset/kind/shape to query/key/value/output/gate/up/down/head and batch1/4/32.
Default remains disabled; only the direct probe owns globally loaded NVTX. No
new buffers/arithmetic/synchronization. Read docs/NATIVE_TURING_PROJECTION_TRACE.md
for source-bound launch projection and callback failure/poison scope.

Native CUDA opt-in evidence is documented in `docs/GEMMA4_CUDA.md`:
`test_gemma4_cuda.mojo` executes the actual dense model,
`test_gemma4_quant_parity.mojo` compares physical GPU matvec results against
independently generated real-weight expectations, and `inspect_gemma4.mojo`
supports the independent tokenizer check. `test_cuda_chat_admission` remains
hardware-free in the counted master suite. `scripts/check_gemma4_conversation.py`
validates 20 actual transcript turns, context accounting, limits and retained
facts; it does not fabricate responses or certify general model intelligence.

Native sampling/upload checks are documented in `docs/NATIVE_RUNTIME.md`:
`test_sampling_config.mojo` and `test_upload_admission.mojo` are counted,
hardware-independent validation cases. `test_cuda_sampling.mojo` is a physical
CUDA probe checked by the independent `scripts/test_cuda_sampling.py` reference.
`test_cuda_upload.mojo` checks actual GPU round-trip bytes and transfer rejection.
Hosted CI compiles these probes but never runs them without a GPU.
`scripts/test_native_chat_controls.py` loads both real model profiles and checks
sampled/greedy replay, reset, rejected settings/prompts and protected logs.
No synthetic logits or transfer buffers count as full-model inference evidence.

`test_conversation_autosave.mojo` is a hardware-free native transaction test
for generation ordering, latest-state recovery, bounded retention, interruption
markers, and preservation of unrelated files. `scripts/test_conversation_autosave.py`
SIGKILLs the compiled probe after its inflight marker is durable, then proves a
fresh process recovers the prior committed turn, identifies the interruption,
and rejects a corrupted authoritative manifest. This is process-crash evidence,
not sudden-power-loss or physical CUDA continuation evidence.

## Public Test Modules

```mojo
# tests/run_all.mojo
def main() raises: ...

# tests/test_ledger.mojo
struct TestLedger:
    var passed: Int
    var failed: Int
    var skipped: Int
    var failure_details: List[String]

    def record_pass(mut self, name: String): ...
    def record_failure(mut self, name: String, message: String): ...
    def record_skip(mut self, name: String, reason: String): ...
    def total(self) -> Int: ...
    def finish(self, expected_total: Int) raises: ...

def run_case(mut ledger: TestLedger, name: String, test: def () thin raises): ...
def record_skip(mut ledger: TestLedger, name: String, reason: String): ...

# tests/test_compute.mojo
def test_gemm() raises: ...
def test_flash_attention() raises: ...
def test_silu() raises: ...
def test_geglu() raises: ...
def test_dequantize_q4_k_m() raises: ...  # canonical raw 144-byte GGML block

# tests/test_gguf.mojo
def test_gguf_parsing() raises: ...
def test_ggml_type() raises: ...

# tests/test_tokenizer.mojo
def test_tokenizer(): ...

# tests/test_inference.mojo
def test_forward_pass() raises: ...
def test_generation_stop_policy() raises: ...
def test_unsupported_runtime_config() raises: ...

# tests/test_kv_cache.mojo
def test_kv_cache() raises: ...

# tests/test_mimir_well.mojo
def test_kv_cache_fixed_capacity() raises: ...
def test_kv_cache_ring_buffer() raises: ...  # compatibility wrapper only

# tests/test_rag.mojo (Slice 5)
def test_cosine_similarity() raises: ...
def test_mimir_store() raises: ...
def report_engine_integration_boundary(): ...
def test_rag() raises: ...

# tests/test_real_gguf.mojo (opt-in external fixture)
def validate_reference_model(seer: GGUFSeer, tokenizer: RuneWeaver) raises: ...
def main() raises: ...

# tests/test_gpu_reachability.mojo (opt-in NVIDIA hardware proof)
def affine_kernel(input: Pointer[Float32, ...], output: Pointer[Float32, ...], count: Int32): ...
def expected_input(index: Int, execution_round: Int) -> Float32: ...
def validate_identity(host_input: HostBuffer[DType.float32], host_roundtrip: HostBuffer[DType.float32], execution_round: Int) raises: ...
def validate_kernel_output(host_output: HostBuffer[DType.float32], execution_round: Int, inject_mismatch: Bool) raises: ...
def main() raises: ...

# tests/test_hardware_discovery.mojo (CPU-only injected records)
def test_discovery_status_classification() raises: ...
def test_physical_device_admission() raises: ...
def test_topology_discovery_accumulation() raises: ...
def test_topology_stable_selection() raises: ...

# tests/test_gpu_discovery.mojo (opt-in physical CUDA discovery proof)
def main() raises: ...

# tests/test_cuda_resource_budget.mojo (CPU-only GPU-2 policy tests)
def test_cuda_budget_accounting() raises: ...
def test_cuda_budget_rejection_is_transactional() raises: ...
def test_cuda_budget_overflow_and_rollback() raises: ...
def test_cuda_resource_policy_admission() raises: ...

# tests/test_gpu_resources.mojo (opt-in physical GPU-2 resource proof)
def expected_value(index: Int, transfer_round: Int, allocation_tag: Int, session_round: Int) -> Scalar[f16]: ...
def exercise_allocation(mut allocation: CUDAF16Allocation, allocation_tag: Int, session_round: Int, inject_mismatch: Bool) raises: ...
def run_resource_session(physical_device: PhysicalDevice, session_round: Int, inject_mismatch: Bool) raises: ...
def main() raises: ...

# tests/test_cuda_gemm_plan.mojo (CPU-only GPU-3 planning tests)
def test_cuda_gemm_plan_counts_and_launch() raises: ...
def test_cuda_gemm_plan_shape_rejection() raises: ...
def test_cuda_gemm_plan_overflow_and_abi_rejection() raises: ...
def test_cuda_gemm_batch_budget_transaction() raises: ...

# tests/test_gpu_gemm.mojo (opt-in physical GPU-3 compute proof)
def validate_output(a: RuneTensor[f16], b: RuneTensor[f16], c: RuneTensor[f16], execution_round: Int, exact_values: Bool, inject_mismatch: Bool) raises -> Scalar[f32]: ...
def exercise_shape(mut resources: CUDADeviceResources, plan: CUDAGemmPlan, exact_values: Bool, inject_mismatch: Bool) raises -> Scalar[f32]: ...
def prove_insufficient_budget_rejection(physical_device: PhysicalDevice, plan: CUDAGemmPlan) raises: ...
def main() raises: ...

# tests/test_sharding.mojo (Slice 6)
def test_device_topology() raises: ...
def test_shard_tensor() raises: ...
def test_tensor_partitioning() raises: ...
def test_all_reduce_sum() raises: ...
def test_sharded_gemm_parity() raises: ...
def test_sharding() raises: ...

# tests/test_npu_edge.mojo (Slice 7)
def test_npu_backend_enum() raises: ...
def test_device_topology_npu() raises: ...
def test_npu_buffer_zero_copy() raises: ...
def test_arm_neon_precision() raises: ...
def test_npu_gemm_parity() raises: ...

# tests/test_gpu_realms.mojo (Slice 8)
def test_gpu_realm_enum() raises: ...
def test_device_topology_gpus() raises: ...
def test_gpu_buffer_zero_copy() raises: ...
def test_gpu_gemm_parity() raises: ...

# tests/test_cli.mojo (Slice 9)
def test_modelfile_parser() raises: ...
def test_model_manifest_store() raises: ...
def test_cli_command_dispatch() raises: ...
def test_cuda_model_switch_syntax() raises: ...

# tests/test_model_preferences.mojo
def test_model_preferences_codec() raises: ...
def test_model_favorite_selection() raises: ...

# tests/test_quantization.mojo (Slice 10)
def test_compressed_format_enum() raises: ...
def test_dequantization_kernels() raises: ...

# tests/test_multi_engine.mojo (Slice 11)
def test_openai_api_formatter() raises: ...
def test_gbnf_grammar() raises: ...
def test_speculative_engine() raises: ...
def test_onnx_model_seer() raises: ...
def test_multi_engine_cli() raises: ...
def test_unsupported_http_responses() raises: ...

# tests/test_resilience.mojo (Slice 12)
def test_error_guard() raises: ...
def test_state_vault() raises: ...
def test_event_bus() raises: ...
def test_thread_pool() raises: ...
def test_supervisor_recovery_boundary() raises: ...

# tests/test_huggingface.mojo (Slice 13)
def test_hf_repo_parsing() raises: ...
def test_hf_download_url_builder() raises: ...
def test_hf_download_parameter_boundary() raises: ...

# tests/test_swarm_cluster.mojo (Phase 14)
def test_swarm_node_role() raises: ...
def test_peer_node_metrics() raises: ...
def test_peer_registry_and_load_balancer() raises: ...
def test_swarm_cluster_task_dispatch() raises: ...
```

`test_model_manifest_store()` covers the versioned restart-safe catalog plus
content-addressed ingestion: strict recipe/blob identity-size coupling, exact SHA-256/size, owner-read-only publication,
deduplication, restart persistence, expected-identity rollback without catalog
or blob mutation, full verification, same-size corruption, missing blobs,
validate-before-delete GC failure, unreachable-blob and stale-stage collection,
referenced-blob retention, exact reclaimed-byte accounting, and
registered-pull syntax admission without network I/O. The separate built CLI
harness adds concurrent processes and the same GC lifecycle; the opt-in live Hugging Face harness proves
one pinned external pull-to-store transaction.

The model-preference cases cover bounded checksummed alias/favorite records,
corruption and path-shaped alias rejection, stable favorite-first selection,
and visible favorite marking. The catalog restart case additionally proves that
preferences survive process-local reconstruction and that an alias resolves to
the canonical verified content-addressed blob.

`test_cuda_model_switch_syntax()` verifies the interactive model-control grammar.
The opt-in `scripts/test_native_model_switch.py` harness performs physical
Gemma → Qwen → Gemma CUDA switching in one task, checks persistent settings and
one inherited transcript, and proves invalid targets reject before unload.

`test_forward_pass()` includes the Transformer-block construction contract:
missing, empty, and address-1 layer weights fail before inference; the legacy
constructor is non-runnable; and a valid block copy preserves its metadata and
validated tensor views.

`test_kv_cache()` also proves `RuneTensor.checked()` accepts a valid view and
rejects zero dimensions, wrapped shape products, and address-1 pointers before
dereference. Its two-sequence `PagedKVCache` case verifies real logical page
mapping, cross-page/layer values, physical exhaustion, release/reuse, owner
invariants, unwritten recycled-layer rejection, independent snapshot copies,
double-free rejection, and logical-gap rejection.

`test_generation_stop_policy()` proves the stable EOS, length, continuation,
and context-exhaustion decisions independently of model logits.

The external-fixture `main()` additionally proves all 32 greedy generated token
IDs, exact decoded text, prompt/generated counts, the `length` stop reason, and
the one-token ID 265 regression against the pinned `llama.cpp` oracle registered
as `gguf.stories260k-f16-v3` in the root `fixture_manifest.json`.

The opt-in GPU reachability `main()` requires a physical NVIDIA GPU, a compatible
`ptxas`, and the locked MAX accelerator library. It creates a CUDA
`DeviceContext`, pinned host buffers, device buffers, explicit H2D/D2H copies,
and a real Mojo GPU kernel launch. It validates 257 elements over three rounds
against a separately calculated host formula and offers `--negative-control` to
prove a mismatch exits nonzero. Run it with:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_reachability.mojo
```

This isolated test proves only MAX 26.5 toolchain reachability on the observed
device. It is not production buffer ownership, GEMM, model inference,
generalized CUDA support, NPU execution, or hardware CI.

The CPU master suite injects validated discovery records to prove failure
classification, admission, accumulation, deduplication, and selection without
pretending hosted CI has a GPU. The separate physical discovery proof exercises
the production MAX CUDA adapter and topology on an actual device:

```bash
pixi run mojo run aesir_engine/tests/test_gpu_discovery.mojo
```

That proof establishes engine-facing CUDA enumeration and selection only. It
does not establish persistent device resources or any engine compute path.

The opt-in GPU-2 resource proof selects the GPU-1 record, opens a project-owned
CUDA session, allocates two unequal paired F16 resources, and validates repeated
synchronized H2D/D2H identity across two successive session scopes. It also
proves zero and over-budget requests leave accounting unchanged. Run it with:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_resources.mojo
```

Append `--negative-control` to inject a post-transfer mismatch that must exit
nonzero. This proves resource ownership and transfer integrity on the observed
host, not GPU compute or model inference.

The hardware-independent GPU-3 plan cases validate exact allocation sizes,
launch-tail rounding, all three tensor shapes, Int32 device ABI limits,
overflow rejection, atomic three-buffer reservation, and rollback. They open no
device and are part of `run_all.mojo`.

The opt-in GPU-3 proof calls the production `gemm_f16_cuda` gateway through two
reusable fixed-shape executors. It executes `2×3×4` binary-exact GEMM and an
unaligned `17×19×23` GEMM for three rounds each, proves no execution-time
allocation, checks every output against an independent host F32 calculation,
and verifies shape, storage, and insufficient-budget rejection before launch:

```bash
MODULAR_NVPTX_COMPILER_PATH=/usr/bin/ptxas pixi run mojo run aesir_engine/tests/test_gpu_gemm.mojo
```

Append `--negative-control` to corrupt one expected value only after real GPU
execution; the command must exit nonzero. This proof establishes one explicit
CUDA F16 GEMM on the observed MAX host. It does not establish model inference,
persistent device weights, Tensor Core execution, generalized CUDA support,
other operators/backends, performance, or hardware CI.

## Process Contract

- Any existing asserted mismatch in a test invoked by `run_all.main()` raises
  or propagates `Error`.
- `run_case()` catches an error only at one named case boundary, records exactly
  one pass or failure, and returns so later cases can execute.
- The runner registers 167 executable named cases and one explicit skip in a
  deterministic order.
- `TestLedger.finish(148)` prints `[SUMMARY]` pass/fail/skip/total/status keys and
  raises after reporting if any case failed or the total is not 148.
- `report_engine_integration_boundary()` is the one explicit external-fixture
  skip. It increments only the skip count and is not a pass.
- `test_gpu_reachability.mojo`, `test_gpu_discovery.mojo`,
  `test_gpu_resources.mojo`, and `test_gpu_gemm.mojo` are intentionally absent
  from `run_all.mojo` so the default suite stays deterministic and
  hardware-independent.
- Synthetic/scaffold assertions establish only their local deterministic
  invariants. They do not establish hardware, format, protocol, network,
  resilience, concurrency, or distributed compatibility.
- Unsupported-boundary cases prove that runtime configuration, accelerator
  gateways, model/network commands, downloads, ONNX/multi-engine entry points,
  HTTP routes, and swarm network actions do not report fabricated success.

## Native model profile proofs

Physical Gemma and Stheno tests stay opt-in because they require external large
weights and an NVIDIA GPU. `inspect_llama3.mojo` plus
`scripts/test_llama3_tokenizer.py` compare native token IDs, UTF-8 round trips and
chat framing with independently generated Hugging Face expectations.
`test_llama3_quant_parity.mojo` checks 35 real-weight dot products;
`inspect_llama3_kernels.mojo` plus `scripts/check_llama3_kernels.py` compare
34,816 CUDA values with NumPy. `test_llama3_session_limits.mojo` deliberately
forces ordinary token IDs to test length/context closure and state rejection;
its output is never conversation-quality evidence.

`scripts/run_stheno_roleplay.py` invokes native chat and records GPU telemetry;
`scripts/check_stheno_conversation.py` validates the unedited 20-turn transcript
and retained-context accounting. Coherence requires separately reading the
actual responses. These checks do not establish full-model logit parity or a
general performance benchmark. Commands and artifact pins are documented in
`docs/GEMMA4_CUDA.md` and `docs/STHENO_CUDA.md`.

`test_llama3_profile.mojo` uses the real GGUF metadata but no GPU allocations;
it proves admission of the documented profile and rejection of eight mutated
metadata/tensor/context cases. Its mutations affect only the in-memory index,
never the mapped model file.

## Second-brain Turing evidence (2026-10-01)

The existing model-registry counted cases now include the strict 3B layout and
COMPATIBLE classification. `inspect_llama3_kernels.mojo` plus the independent
NumPy checker exercises scaled RoPE at positions 0, 1, 127 and 8191 and residual
addition including alias/tail cases, alongside existing SiLU/GQA checks. This is
physical GPU primitive evidence over constructed inputs, not whole-model parity.
The generalized profile and quant-parity probes admit the real tied-weight 3B
GGUF, reject incompatible RoPE metadata and compare 35 real-weight dot products
against a separately generated GGUF/NumPy oracle. Actual live socket tests and
benchmarks are separate opt-in checks in ../../docs/evidence/second-brain-2026-10-01.md.

## Native performance probes (2026-10-01)

The efficiency follow-up extends packed projection to 738 exact reference rows,
1404 tail guards, six widths and row counts crossing block boundaries.
test_dense_normalization.mojo emits 233472 physical values after 48 exact-reference
and span-guard cases; scripts/check_dense_normalization.py independently checks
the equations. Hosted CI only compiles these opt-in physical probes. Independent
real-weight and full service/recovery gates remain separate requirements.

The counted master adds core.prompt_prefix_exact and covers snapshot-family
mapping in native.model_registry. Expected count is 187: 186 pass and one skipped
external fixture on the exercised host. Negative control must still exit nonzero.

test_packed_projection.mojo is an opt-in physical Q4/Q5/Q6 exact scalar-reference
comparison over 63 synthetic rows, three widths and row/tail guards. It is not
external model evidence. test_cuda_prompt_prefix.mojo takes a real model path and
compares seven cache-disabled/enabled completions in one context, including
divergence, system framing, seeded sampling, repetition settings and deadline/reset
recovery. It does not prove in-process CUDA context recreation. The separate real
GGUF row oracle and HTTP/service probes remain required. CI compiles these probes;
physical execution requires the documented compatible device and supplied model.

## Long-token and buffer probes (2026-10-01)

core.dense_buffer_layout is a pure counted master case for compact checked spans,
byte counts, context/tile/default bounds and overflow. test_four_projection.mojo
executes 2952 exact reference rows/5616 guards. test_long_attention.mojo covers
24 chronological reference cases and emits 65536 complete values for independent
check_long_attention.py (NumPy 2.4.4). test_cuda_prefill.mojo uses one owning CUDA
context and compares 641280 full logits, five completions, exact-token restore and
invalid-tile non-mutation. Native sequential logits are a regression reference,
not an external whole-model oracle. CI compiles opt-in probes; physical execution
and speed require separate hardware evidence. See docs/NATIVE_LONG_TOKENS.md.

## SPD-00 actual-call timing and independent logit export

test_cuda_measurement.mojo admits only the strict Llama 3.2 3B fixture and uses
one owning CUDA context, context4096, prefix disabled and four-token prefill.
It exports all 128256 final-prompt logits and exact input IDs in four public cases,
then preserves three export-free fresh repeats per case. CSV requires a final
completion marker. begin_turn/decode-loop/first-visible timings use synchronized
actual calls and include host/native work; they are not isolated GPU kernel times.

measurement_kernels.mojo owns the checked equal/nonempty D2D transfer helper.
Two bounded nonuniform spans produce 20 timings; every copied word is verified.
Validated tensor descriptors provide logical minimum projection/norm/embedding/
RoPE/KV accounting. This conditional bandwidth reference cannot prove a hard
hardware ceiling or decoder speed. CI compiles the probe; local CUDA execution
and the optional independent CPU numerical gate remain separate physical checks.

scripts/check_llama3_logits.py owns strict CSV validation, independent F32 reference
and unchanged predeclared numerical budgets. scripts/test_check_llama3_logits.py
uses synthetic evidence solely to prove rejection/scoring contracts. See
[the measurement manual](../../docs/SPEED_MEASUREMENT.md).

The existing server.posix_socket master case requests an OS-assigned port only
in its test-owned sockaddr, then verifies the bound address with getsockname.
Production BifrostGate still requires an explicit port in 1..65535; constructor
zero rejection, nonblocking setup and close semantics remain asserted. The test
does not require the live native service's 18434 socket to be stopped.

## Optional packed matrix primitive evidence

test_packed_matrix.mojo owns 144 synthetic tail/guard cases, 12 invalid span
rejections, 1,658,880 complete real native-reference values and 560 paired timing
records across 28 cases. Mandatory final PASS marker bounds completion. It owns
one strict 3B CUDA context; no live service changes. Timing excludes printing and
allocation but includes actual launches/synchronize. check_packed_matrix.py uses
gguf 0.19.0/NumPy 2.4.4 for 2100 selected independent real-weight Float64 dots. Six
portable adversarial tests prove evidence rejection only. Hosted CI compiles the
probe; physical execution is separately recorded. No model-level speed claim.

The separate test_matrix_tile_tuning.mojo owns five explicit staging choices;
original probe owns32/32. Each repeats144 synthetic tails,12 span rejections,
complete real output/oracle/timing gates. TILE identity is validated by the checker;
legacy CSV defaults32/32. Seven portable rejection tests pass. Hosted CI only compiles.

test_turing_mma.mojo owns108 exact-binary cases, all50688 equations,5400 guards
and9 invalid metadata rejections. Complete Float64-text export preserves actual
F32 values; final PASS is mandatory. check_turing_mma.py independently checks
every output with integer equations. See ../../docs/NATIVE_TURING_MMA.md for the
isolated target, initial failures and separate instruction/trace/hardware proof.
Hosted compilation earns no physical or full-model speed/precision capability.

test_packed_turing_matrix.mojo reuses synthetic/real_batch/exercise through an
explicit turing=True template selector; SIMT defaults remain unchanged. MODE
identifies split-weight F16/F32 computation. It repeats144 synthetic tails,
12 invalid spans, all1,658,880 native output pairs and560 alternating equal-work
timings. Selected independent2100 real dots pass fixed budgets; all speeds lose.
Read ../../docs/NATIVE_PACKED_TURING_MATRIX.md for evidence/precision boundaries.

test_turing_shared_staging.mojo exercises explicit16/32/64 CTA rows through
staged_rows with original SIMT/direct defaults unchanged and conflicting selector
combinations rejected at compile time. Each repeats every synthetic/span/native/
selected-independent/timing gate; combined native count is4,976,640. All budgets
pass; speed gains are larger-batch primitive evidence only. MODE records rows.

test_turing_wide_staging.mojo owns only rows32/64 with input columns64/128.
staged_columns defaults32; an unused nondefault selector is rejected at compile
time. Four configurations repeat576 synthetic tails,48 rejected spans,6,635,520
full native values,8400 selected independent dots and2240 paired timing records.
All budgets pass, wider timing loses to prior32-column staging, and no default
is promoted. MODE records separate CTA rows and staged-input columns.

test_turing_activations.mojo captures three final-layer source buffers after two
unchanged native four-token prompt replays. Seven layer27 projections at batch4/
32 compare all outputs and preserve input/guards;32 repeats the four sources.
Q/K/V normalized inputs are representative FFN norms, while output/gate/up/down
use actual operands. COMPLETE means collection only; numerical failures remain
in full output and require check_turing_activations.py. No timing/model-quality
claim or production inference capture hook. Read ../../docs/NATIVE_TURING_ACTIVATIONS.md.

turing_prefill_fixture.mojo owns isolated checked32-token scratch/guarded F16 KV
and sampler while sharing a normal reference session's immutable weights/context.
Normal buffers/admission are never changed. test_turing_model_prefill.mojo runs
four public prompts, all513024 final logits per mode, exact repeats/committed IDs,
eight mutation-free rejections and32 warm/scored alternating timing records.
COMPLETE means collection; independent CPU/full-native budgets own acceptance.
No generation/control/restore/runtime promotion. Read
../../docs/NATIVE_TURING_MODEL_PREFILL.md before refining or integrating.

Both activation/model probes accept optional final precision0/1/2, with legacy
zero metadata/defaults preserved. The owning fixture selects explicit staged
three/four-term kernels for nonzero modes; no normal session buffer/dispatch is
changed. Complete source/output/guard/repeat/timing gates stay mandatory. Nonzero
full-model native-reference RMS additionally must be<=.0005. Read
../../docs/NATIVE_TURING_ACTIVATION_RESIDUAL.md before measuring or promoting.

Explicit precision3/4 extend both probes and the fixture with scaled weight/input
residuals and distinct high-high accumulation orders. Complete captured/model
coverage and .0005 native-reference RMS requirement stay unchanged. Unknown
precision rejects before fixture allocation. No normal runtime admission change.
Read ../../docs/NATIVE_TURING_SCALED_RESIDUAL.md for representation and gates.

TuringFixturePlan owns the isolated context1536/strict3B guarded32-token plan.
Every normal reference layout field must match its canonical four-token plan;
observed CUDA capability7.5 and450396872 free bytes are required before extra
workspace allocation. It retains checked1247520 F32/88080416 F16 element counts,
181961416-byte allowance and256MiB reserve, preserving native buffers. Before
every tile, admit_buffers rejects any layout-field or actual-length drift.
The registered portable case covers all13 fields, headroom and hostile identity.
Read ../../docs/NATIVE_TURING_FIXTURE_ADMISSION.md; runtime promotion stays open.

FixtureControl reuses native GenerationControl and owns enabled/start/abort/reset
policy. Enabled TuringPrefillFixture checkpoints after each owning-stream synced
layer and before commit. Healthy drain requires explicit reset with no partial
ID/position commit; unexpected execution/observer errors poison reuse. Default
disabled queue policy remains intact. Thin observer is test-only. The physical
control probe exports all recovered vectors/guard/mask/state proofs; read
../../docs/NATIVE_TURING_FIXTURE_CONTROLS.md before expanding control or recovery.


test_turing_decode_quality.mojo owns mode0 post-prefill prediction evidence for
public37/1070-token prefixes under greedy32 and explicit seeded16 caps. prepare
resets/configures both existing samplers; advance teacher-forces the native
choice. causal verifies every committed ID, state records actual choice/history/
draw position and collect exports every F32 logit plus actual EOS/cap completion.
Fresh own replay compares all vector bits, choices and state, continuing the
first round's recorded IDs. Pinned snapshots cap32833536bytes per case, no extra
device workspace. Read ../../docs/NATIVE_TURING_DECODE_QUALITY.md; no throughput/
provider score, free-running matrix, restoration or production32 admission.


FixtureReplayPlan owns copied nonempty committed IDs/1/four/32 counts, context/
vocabulary, actual allocation identities, pending choice, config/draws and FNV64
mutation seal. admit revalidates every field/value and owner/window before reset.
Native mode0 rejects32; matrix mode1 permits it. Pure registered tests have no GPU
allocation. turing_checkpoint_replay.restore preflights paired idle/healthy/control
state and actual canonical native/fixture spans, then resets/replays exact counts
without sampling, synchronizes/verifies exact IDs/history/position and restores
draws. Unexpected replay exceptions poison reuse. test_turing_checkpoint_replay
exports full before/after vectors/states/guards and12 pre-reset damaged-plan
refusals. Read ../../docs/NATIVE_TURING_CHECKPOINT_REPLAY.md; same owning context
only, no new persisted schema, process recovery, runtime32 or speed score.

## Optional batched rotary/cache fixture

TuringPrefillFixture adds precision0-only batched=False and rope_cache_calls;
grid-y wrappers batch disjoint four/32-token rotary/cache rows before unchanged
causal attention. Scalar and disabled paths retain old kernels. guarded_cache_digest
owns synchronized full F16 host copy, anonymous memfd/exact-FD SHA and all-path
close; unscored with no persistent cache dump. FixtureReplayPlan/restore bind
strategy0/1 before reset; native strategy stays0. Decode/checkpoint optional final
flag emits strict ATTENTION metadata; omission stays legacy. Read
../../docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md before measurement or promotion.

## Batched elementwise strategy2

TuringPrefillFixture adds elementwise=False, elementwise_calls and
execution_strategy0/1/2. Explicit2 requires batched rotary/cache and precision0
before load/every tile. norm_rows groups four independent warps per CTA; residual
and silu rows retain original arithmetic and stream dependencies without extra
global workspace. Counters reset on fresh runs. Plans bind actual strategy2
before reset; scalar/default paths stay unchanged. Shared collectors accept flag2
and its distinct ATTENTION marker, exporting actual elementwise host counts. Read
../../docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md for full state/source acceptance.

## Enabled batched fixture controls

The physical control collector accepts optional0/1/2 before caller-owned signal
mask setup. Explicit marker binds recovered vectors to the matching independently
accepted strategy. Existing deadline/SIGINT/invalid-fd/reset/refusal/poison/guard
records remain mandatory. No new recovery fallback. Read
../../docs/NATIVE_TURING_BATCHED_CONTROLS.md; actual GPU faults remain unproved.

## Three-owner primitive header experiment

The primitive harness adds final cache_headers=False. True snapshots native
values on bounded host storage, then compares cached/original bits using existing
two device output spans. New test_turing_block_headers exports exact Float64 text
for native/cached/original,144 synthetic/12 invalid spans/all guards and840
rotating ten-sample three-owner records. Legacy defaults/schemas remain. Explicit
mode binds rows64/width32. Read ../../docs/NATIVE_TURING_BLOCK_HEADERS.md.

## Larger row three-owner primitive experiment

The harness adds large_rows=0; explicit128 selects the separate public wrapper,
mutually excluding header cache. Native snapshot/original64/new exact F32 exports
and three-owner rotation reuse the existing bounded two-output device storage.
New test_turing_large_rows admits CLI128 before model load;256 is rejected after
a retained physical resource failure. All144 synthetic/12 invalid span/real full
output/guard/840 sample gates remain. Read ../../docs/NATIVE_TURING_LARGE_ROWS.md.

## Down-only128 actual-F32 activation gate

test_turing_down_activations reuses unchanged public normal four-token capture.
Only batch32 final-layer down selects128; collection has28 total cases and exactly two down128 selections. Existing two output spans plus
bounded native host snapshot export all native/new/original F32, actual state/
operands/guards/12 invalid spans with strict new metadata. No timing/default
change. Read ../../docs/NATIVE_TURING_DOWN_ACTIVATIONS.md.

## Down-only128 complete model strategy3

TuringPrefillFixture adds final down128=False/counter; True requires precision0
plus original batched elementwise strategy. Only loaded down/count32/canonical
up-to-temporary spans select128; counter increments after enqueue/resets fresh.
Strategy3 refuses enabled controls/tracing pre-step. Sealed replay plans now
admit3 through explicit owning-context admission. Project is mut for its counter, final vocabulary descriptor copied to
avoid aliasing. Shared fresh-repeat checks compare actual F32 bits. New collector
exports full source/cache/ID vectors, admission and actual down counts; default
model collectors remain0/1/2. Read ../../docs/NATIVE_TURING_DOWN_MODEL.md.

## Explicit down128 decode collection

Existing test_turing_decode_quality.mojo accepts final optional strategy3, with
pre-model0/1/2/3 admission. Omission/default and prior flags preserve prior schema.
New3 requires original precision0/batched/elementwise/down128 and distinct marker.
Actual initial DOWN_ROWS128/replay REPLAY_DOWN_ROWS128 counters remain28/924:
scalar decode cannot add128-row calls. Existing four public prefix/policy cases,
96 full-vocabulary frames/native-forced causal IDs, EOS/caps/guards/sample/draw/
state and actual own fresh F32-bit replay remain unchanged. No added GPU workspace.
Read ../../docs/NATIVE_TURING_DOWN_DECODE.md; hosted compile is not GPU evidence,
no speed score/production selection. Explicit sealed replay has its separate gate;
enabled controls remain closed3.

## Down128 sealed owning-context checkpoint replay

FixtureReplayPlan admits matching matrix3 while native remains0 and unsupported4
refuses; copied/checksummed tokens/tiles/config/draws/owner identities remain.
Counted pure test includes positive3 and owner/strategy/seal/native-mode refusal.
TuringPrefillFixture.admit_execution_strategy is one pure flag admission shared
by step and replay gateway before reset/config mutation. Existing checkpoint
collector adds explicit3, actual before/restored down counts28 and18 total damaged
plan/flag refusals with healthy sampled/committed state/counter/buffer ownership
unchanged. Two policies/eight full-vocabulary continuations/all four baseline/
restored owners retain exact actual F32 bits, independent/sample/state/guards.
Default0/1/2 schema/math remains. GPU/replay exceptions still poison actual owner.
Read ../../docs/NATIVE_TURING_DOWN_CHECKPOINT.md; no persisted/crash/context-
recreated/runtime/elapsed admission. Enabled controls/tracing remain closed3.

## Explicit down128 control capability and recovery

TuringPrefillFixture adds final down128_controls=False. True requires down128
before model load, pure execution flags before step/configure/start/replay reset
and original precision0/batched/elementwise geometry. Ordinary down128 still
refuses enabled controls; True uses existing synchronized cooperative checkpoints/
drain/reset-required/healthy recovery and unexpected failure poison. Tracing stays
closed. No new device workspace/math. Existing model collector optional
control-capable mode exports CONTROL_CAPABLE,3,1, tests negative settings/trace
refusal and all original disabled source vectors/cache/state/timings. Defaults stay.
Control collector explicit3 constructs capability True; actual abort down counts
must equal completed layers, recovered counts28 and poison1. All four aborts/
513024 recovered values per owner/9792 guards/owned SIGINT/mask/reset/allocations/
refusals remain. Read ../../docs/NATIVE_TURING_DOWN_CONTROLS.md; no GPU-fault repair,
hard real time, production32/concurrency/provider gate. Hosted compile is not GPU.
