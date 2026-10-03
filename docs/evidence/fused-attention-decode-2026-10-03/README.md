# Fused attention causal decode — 2026-10-03

Explicit strategy4 passes every fixed gate: 96 full-vocabulary frames /
12312576 F32 values per native/matrix owner on public37/1070
prefixes with greedy32/seeded16 caps, native-forced causal IDs, exact samples/
positions/history/draws, unchanged .05/.005/full-argmax independent zero-GPU
expanded-F32 budgets,4352 guards and actual own fresh UInt32 replay including
signed zero. Both policies' initial vectors match accepted whole-model4 bytes.
The final chosen ID remains uncommitted; actual EOS/frame counts are retained.

| Prefix | Policy | Frames / finish | Down calls | Fused calls | Original queries initial/replay | Initial source bits / own replay |
| --- | --- | --- | ---: | ---: | --- | --- |
| 37 | greedy | 32 / length | 28 | 56 | 28/896 | pass / pass |
| 37 | seeded | 16 / length | 28 | 56 | 28/448 | pass / pass |
| 1070 | greedy | 32 / length | 924 | 1008 | 56/924 | pass / pass |
| 1070 | seeded | 16 / length | 924 | 1008 | 56/476 | pass / pass |

| Comparison | Worst full-vector maximum | Worst full-vector RMS |
| --- | ---: | ---: |
| native | 0.0156402587891 | 0.00268990435899 |
| matrix | 0.0283422470093 | 0.00398676536648 |
| matrix_vs_native | 0.0274019241333 | 0.00291580018152 |

Source admission verifies complete four-case model4 parsed/declarative numerical/
ID/cache/rotary/elementwise/down/fused/original counters, fixed CPU scope and
accepted3 predecessor byte/cache proof with exact CSV/report identities. Source
model binary SHA and current decode binary SHA are required before/after. Source
triplet is exclusive with down3 pair; default readers reject4. Capture/model/
derived/derivation/source/current binary hashes are rechecked after oracle;
supervisor pre/post source hashes agree. Strict bounded regular no-follow streaming,
ordered records, complete retained failures and exclusive JSON remain. Interrupted
validation/cleanup cannot pass.

Eleven portable adversarial contracts cover signed zero, altered counters/marker/
CPU metrics/scope/predecessor/source bits/cache/IDs, strict JSON, both binary hashes,
all eight changed artifacts, incomplete/exclusive source arguments and interrupted
cleanup/output. Existing model/down/decode/grid/checkpoint/control/trace gates pass.
Both sm75/sm89/original/master/normal/check builds precede GPU then CPU. Master190
passes/zero fails/one skip. Unsupported5 refuses before model/CUDA. Every elapsed
process/export/oracle time is unscored; speed_scored is false.

Normal f3442a1e stays active/authenticated ready/prefill4/cpuoffload0. These public
native-forced trajectories/fresh replay do not certify free-running candidate,
sealed checkpoint replay, enabled controls, production32, broader contexts/devices,
concurrency/soak or provider speed. Next earn owning-context sealed replay and
control recovery for4. Exact push/CI receipts are separate.
[Operation](../../NATIVE_FUSED_ATTENTION_DECODE.md).
