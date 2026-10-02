# Exact-state batched rotary/cache evidence — 2026-10-02

Optional original precision0/strict3B/context1536/F16KV on RTX2060 Max-Q sm75.
Grid-y rows batch four/32-token Q/K rotation and KV stores while per-token causal
scores/softmax/value reduction retain their original arithmetic. Scalar/default
paths preserve existing entry points. Public inline device operations avoid a
pinned compiler offload conflict; existing production kernel bodies stay intact.
No extra global workspace/weights. Master190 passes/zero fails/one skip; six new
portable variant/cache/source contracts plus all nine legacy model/decode/checkpoint
contracts pass. Complete metadata/strategy drift refuses before admission/reset.

All513024 values per model owner and exact public IDs match the earlier accepted
mode0 baseline, and new1 equals explicit0 F32 bytes in all four cases. All four
176160832-byte full guarded-F16-cache hashes agree. Actual host enqueue counts
match the admitted causal tile plan. Eight invalid-tile refusals, repetitions/
committed IDs and4352 guards pass. Both CPU numerical reports pass unchanged
.05-max/.005-RMS/full-vocabulary-argmax gates. Every ratio requires all these gates.

| Input IDs | Original rotary/cache host calls | Batched host calls | Native seconds | Batched fixture seconds | Native/fixture ratio |
|---:|---:|---:|---:|---:|---:|
| 30 | 2520 | 756 | 0.350611 | 0.358211 | 0.978785 |
| 37 | 3108 | 252 | 0.417514 | 0.251547 | 1.659787 |
| 31 | 2604 | 840 | 0.375342 | 0.382069 | 0.982393 |
| 1070 | 89880 | 3192 | 13.039423 | 7.435146 | 1.753755 |

One unscored warm/export pair precedes three alternating fresh pairs per case;
all64 timing records across both variants remain. These are native-to-fixture
exploratory ratios, not a cross-session old-to-new or provider score. Full host
cache copy/digest/export are unscored; transient copy is176160832bytes/168.000061MiB.
No persistent cache dump is written. Actual host calls are not GPU profiler counters.

Explicit batched decode repeats all96 greedy32/seeded16 frames after public37/1070
prefixes,12312576 complete values per owner. Every unchanged independent/native
budget, actual sample/causal state/draw and own F32-bit replay gate passes. Batched
checkpoint repeats eight continuations before/after exact-boundary same-context
reset/replay,1026048 values per mode; source/sample/state/bit/12 damaged-plan refusal
and4352 guard gates pass. Those complete reports always withhold speed scores.
Execution strategy0/1 is sealed and checked with actual allocation/window/geometry
before reset. Persisted formats and public sessions remain unchanged.

Every sm75/sm89/master/normal build ends before the four serialized GPU captures;
CPU-only reference checks follow all GPU work. Preserved attempts include missing
mutability/borrow admission, kernel-entry offload and host write ABI errors.
Normal binary remains f3442a1e with active authenticated ready/prefill4/cpuoffload0.
provenance.json contains hashes/build/process ordering and portable path labels;
raw private receipts/CSVs remain outside Git. Exact push/CI are separate receipts.

No runtime32, broader contexts/families/devices, GPU-fault repair, persisted/context
recreation, concurrency/soak or Ollama lead is claimed. Next reduce other independent
per-token elementwise launches under the same exact vector/cache/state gates.

[Operation](../../NATIVE_TURING_BATCHED_ROPE_CACHE.md).
