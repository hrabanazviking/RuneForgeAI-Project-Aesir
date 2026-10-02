# Complete decode and seeded replay evidence — 2026-10-02

Original strict3B/context1536/F16KV mode0, RTX2060 Max-Q sm75. The owned GPU
collector exits0 with96 actual prediction frames,12312576 full logit values per
mode,4352 fixture guard checks and exact own F32-bit replay. Both greedy32 and
seeded16 caps finish by length for both public37/1070-token prefixes. Every actual
native/matrix sample choice agrees; exact committed IDs/history/draws pass.

Pinned CPU F32-expanded inference on the exact native-forced streams passes all
original .05-max/.005-RMS/matching-argmax budgets for both owners, plus matrix
versus native. Worst matrix/CPU absolute error .02834225; worst RMS .0039867654.
Worst native/CPU max .01564026/RMS .0026899044; matrix/native max .02740193/RMS
.0029158002. All96 metrics/choices/replays remain in decode.json. No timing ratio.

All sm75/sm89/master/normal builds end before GPU capture; CPU oracle follows.
Master189 passes/0 fails/one explicit skip. Nine portable adversarial contracts
cover bounded streaming, malformed identity/state/causal/finish/vector/replay,
complete numeric failures, model-change and cleanup failure retention. Failed
initial master command and all raw artifacts remain outside Git. The680806792-byte
CSV is streamed under2GiB/1024-byte limits rather than loaded wholesale.
Pinned one-case host snapshots cap32833536bytes/31.313MiB.

Normal binary remains f3442a1e and authenticated active readiness remains ready,
prefill4/cpuoffload0. provenance.json records hashes/ownership/build/process
ordering; exact publication/CI are separate receipts. No free-running matrix
trajectory, general sampling equivalence, restoration, production32 admission,
broader contexts/models/concurrency or provider lead is earned.

[Operation and policy](../../NATIVE_TURING_DECODE_QUALITY.md).
