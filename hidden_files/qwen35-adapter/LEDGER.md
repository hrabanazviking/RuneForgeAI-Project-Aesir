# Qwen35 Adapter Campaign — Ledger

## 2026-11-14 — 40B line opened (coordinator): recon verdict + separate-worktree road

- Volmarr's new primary objective: get the 40B (Qwen3.8-40B-Ultimate-
  Heretic Q8_0, 41,537,542,144 B) working on Aesir properly. SHA-256
  verified on-device: ccf16c2874da7846268901ab300d5138e896f08ed16811ff
  0b58b7f0126ac426.
- Header recon (read-only python parse + the loader probe below):
  architecture **qwen35** — the same hybrid family as the 27B, deeper:
  **96 blocks (72 SSM + 24 full-attention, interval 4)**, hidden 5120,
  FFN 17408, 24/4 heads, head dim 256, context 262,144. Per-layer
  geometry IDENTICAL to the 27B (groups 16, state 128, dt_rank 48,
  inner 6144, qkv width 10240, conv kernel 4, partial rope 64 with
  rope.dimension_sections [11, 11, 10, 0]). Tensors 1275 = 746 Q8_0 +
  529 F32; the census arithmetic closes exactly against the layer
  counts; no vision tensors (text stack only, despite the "vl"
  finetune name). Vocab 248,320.
- Road taken: **separate worktree** /home/volmarr/aesir-q35-40b on
  branch **yrsa/qwen35-40b**, based on banked yrsa/hip-serve @
  17cd0c98 — because the seat worktree had an active writer (the
  Q35-2 worker, mid-slice: registry/profile edits in flight at
  11:18–11:22). Q35 slices merge in as they bank; the adapter is
  never re-implemented in parallel. Volmarr ruled the earlier
  two-crew overlap a misunderstanding — no fault either side.
- Q35-1 generalization check: the loader validator is formula-driven
  from config (verified in the banked diff) — no 27B hardcoding to
  fix. First 40B proof already landed: the Q35-1 real-file probe run
  against the 40B file → **VALIDATION PASS** (96 blocks, 1275
  tensors, 3,965,696 F32 elements converted, small peak; log:
  q40-probe.log in this folder). Reading note: the probe's PASS line
  still prints "real 27B" — that is the probe's hard-coded text from
  Q35-1; its file argument was the 40B. Recorded here so the log is
  never misread; the text fix belongs to the probe's home line.
- Known gap for this line: the Q35-2 registry design pins
  native_profile on the 64L/5120 geometry — the 96L 40B needs the
  family-geometry generalization once Q35-2's final form is banked
  and merged in. Forward/session/HIP/serve follow the Q35 plan's
  order. Full-residency loads stay parent-gated: report MemAvailable
  + live set + expected peak + 100 GiB GTT fit before any attempt.

## 2026-11-14 — Q35-1: loader truth (worker slice; verified + banked by coordinator)

- `_validate_qwen35_tensors` fixed: qkv rows and ssm_conv1d rows now
  `qkv_width = 2*groups*state + inner` from config (real file: 10240);
  type constants aligned to the real census (Q8_0 weight matrices,
  F32 small tensors; 498 Q8_0 + 353 F32 re-verified by header parse).
- U2 SETTLED: types are recorded, not enforced — `_require_tensor_shape`
  never compares expected_type (code read), and the type-probe fixture
  (attn_gate stored F16 vs validator Q8_0) still validates (test (c)).
- Synthetic fixtures (scripts/make_qwen35_fixtures.py; tiny correct
  geometry, qkv 56): good PASS, bad-qkv (88) rejected with the shape
  error, type-probe PASS. Log: q35-1-test.log, ALL PASS.
- Real-file probe PASS through the no-materialization seam
  (inject_mmproj-style staging + direct _validate_required_tensors;
  zero-copy views + only 2,645,504 F32 elements converted; unit peak
  226 MB): q35-1-realfile-probe.log.
- Full notes: Q35-1-NOTES.md (incl. the pre-existing
  gguf.tensor_directory_interface regression note — unchanged,
  out of scope). Next: Q35-2 (registry + profile + inspect).

Running record. Newest entries at the top. Every entry from disk or a
tool result, never from a summary.

## 2026-11-14 — QA-0: campaign opened, plan adopted, seat verified

- Campaign commissioned by Volmarr in chat ("yes make the adopter for
  that kind") after the HS line's 27B gate verdict (NOT RUNNABLE:
  no qwen35 adapter, no recurrent-state session, no HIP path).
- Ground truth read on-device: GATE_AND_27B_RESULTS.md, MAP.md
  (HS line), inspect-27b.log, and the prior crew's QWEN35_PLAN.md —
  a complete verified recon (four-part blocker stack: registry,
  loader validator, engine-core forward geometry, serve layer) with
  slices Q35-1…Q35-7 and unknowns U1–U5. **Adopted as this
  campaign's plan**; it was banked by the prior crew at a8215e29
  ("Qwen35 line: recon + slice plan (Q35-1..Q35-7) banked") while
  this campaign was opening — local HEAD == origin/yrsa/hip-serve ==
  a8215e29, verified by fetch + ls-remote. Seat checked quiet (no
  build/git processes) before this campaign's first write.
- Target file SHA-256 verified on-device this session:
  1fca6eefc37607b5ab458f9a76815b36aeb38cf21ac36c49fdc0ab4eb186f08e
  (28,596,003,296 B) — matches the gate doc.
- Machine state at open: MemAvailable ~27 GB of 127 GB; aesir-gate,
  ollama, voxta all active (live for Volmarr's Voxta testing — never
  to be touched). The tracked `hidden_files/hip-serve/serve-bench.log`
  modification in git status is the live gate's own log; left alone.
- Full-suite baseline to defend (from the gate doc): 901/905 with
  only the two proven pre-existing failures
  (gguf.tensor_directory_interface; gpu.hip_q4k_gemv_no_leak).
- Next: Q35-1 (loader truth) — validator formula fix + type-policy
  probe + synthetic fixture. The real-file load probe in Q35-1
  reaches tensor materialization only; the full CPU residency proof
  is Q35-3 and carries the U3 memory exception decision with it.
