# Qwen35 Adapter Campaign — Ledger

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
