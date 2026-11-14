# RESIDENCY NOTE — 27B Q4_K_M serve coexistence, for the Q35-7 gate decision

Filed by QC-7 as a sibling of QC_RESULTS.md in this folder.
Placement choice, with justification: this note is a SEPARATE file,
not a section of QC_RESULTS.md, because Q35-7 consumes it as a gate
configuration input on its own — it must be citable, diffable and
updatable by the Q35-7 slice without touching the compression
workstream results record, which is closed by QC-7. QC_RESULTS.md
section 3 points here for the residency numbers.

Every number traces to a banked file in this folder, cited inline.
No new heavy run was made for this note.

## The coexistence math (from QC-6-NOTES.md, residency note)

Measured peak RSS of a full load + forward (time -v), Aesir CPU:

- Q8_0 source, resident path: 30,998,948 KB (grade p3) /
  30,999,304 KB (gen) — the ~31.0 GB class.
- Q4_K_M product, default packed path: 19,536,880 KB (grade p3) /
  19,537,308 KB (gen) — ~19.5 GB.
- Saving: ~11.46 GB of resident footprint (-37%) for a stored
  saving of 12.37 GB (-43.3%): stored 28,596,003,296 B ->
  16,223,236,576 B (56.7%).
- KV at ctx 8192: 536,870,912 B (~0.54 GB), from the registry
  memory plan as cited in QC-6-NOTES.md. (Cross-check in
  Q35-5-NOTES.md: the same 536,870,912 B figure at ctx 8192.)

QC-6 conclusion, as banked: product load ~19.5 GB + KV ~0.54 GB at
ctx 8192 leaves the product servable beside a second 27B-class
resident on this 121 GB box, where two Q8_0 residents (2x ~31 GB +
pools) were the previous budget unit; on a 32 GB-class device the
product fits where the source does not.

## Serve peaks already measured for the Q8_0 source (for comparison)

- Q35-4b (CPU resident serve, :18435, ctx 4096): serve process
  VmHWM 31,312,080 kB (~31.3 GB) from /proc; in-process reference
  peaks 31,621,040 kB (turns) and 31,626,896 kB (long) by time -v —
  the honest peak class ~31.3-31.6 GB, inside the expected
  31-35 GB band from Q35-3b. The systemd MemoryPeak figures
  (5.35 GB / 4.50 GB) UNDERCOUNT (mmap weight pages are not charged
  to the cgroup the way RSS counts them) and must not be used for
  the gate decision. Source: Q35-4b-NOTES.md.
- Q35-6b (HIP serve, ctx 4096, --experimental-qwen35): serve VmHWM
  30,055,972 KB (~30.1 GB). In-process HIP runs: gen witness max
  RSS 25.6 GB; grade P5 RSS 29.4 GB. Source: Q35-6-NOTES.md.
- Q35-6b pace warning, banked for the same decision: HIP decode
  ~0.07-0.09 tok/s (naive byte-load GEMV, ~11-14 s/token) vs
  Q35-4b CPU resident end-to-end ~1.5-1.8 tok/s (grade decode
  ~2.2 tok/s). Sources: Q35-6-NOTES.md, Q35-4b-NOTES.md.

## What this means for the Q35-7 gate configuration decision

Stated for the decision, not as the decision (Q35-7 owns it):

1. Memory is no longer the binding constraint for a Q4_K_M gate
   candidate on this box: ~19.5 GB packed load + ~0.54 GB KV at
   ctx 8192 vs ~31.0-31.6 GB measured for the Q8_0 resident serve.
2. The product does NOT satisfy the Q35-3r resident contract today
   (Q8_0-only; refuses the product by name — QC-6-NOTES.md). A gate
   swap to the product therefore requires either the Q4_K_M
   resident-analogue contract (named remaining work, QC_RESULTS.md
   section 5 item 2) or an explicit decision to serve it through
   the default packed path with that mode honestly reported.
3. No serve-surface smoke of the product exists yet: QC-6 graded
   through the driver, not the serve surface; the two-turn serve
   smoke belongs with Q35-7 gate work (QC-6 risk 2).
4. Speed evidence for the product on the serve surface does not
   exist yet either; the only serve pace numbers on record are the
   Q8_0 source numbers above. Do not carry them across tiers
   without a Q35-7 measurement.
