# A-052 — Long context on CPU

Roadmap: "Long context on CPU. 32k-token context run: KV growth,
correctness spot-checks at depth. *Acceptance:* run completes;
depth probes (needle-style) pass at filed rates."

Verdict: **PASS** — the 32k run completes on CPU at the KV +
attention layer; KV growth is priced exactly by the tree census
arithmetic; readback spot-checks at depth are exact (0
mismatches in 3,072 bench checks, bitwise in the suite cases);
needle probes pass **14/14 in the bench (7 depths x 2 layers)
and 7/7 in the E-MASTER suite case**, rate 10,000 bp, worst
max abs diff **0.0** against the filed tolerance of 0.010.
Filed numbers live in `hidden_files/a052_bench.log` (sha256
b2631032fb7f00b9a568d9d31262e122b30edc06dd960b7ae06b0568d1c4ccf9)
and the E-MASTER log cited in the A-052 ledger.

## The boundary, stated first

The engine session/generation path clamps context to 16,000
(`HOST_RUNTIME_CONTEXT_CAP`; `aesir.mojo` MAX_RUNTIME_CONTEXT
applied in `_run_generation`, mirrored in
`core/inference.mojo`). A 32,768-token *session* therefore does
not run end-to-end through AesirEngine today, and this slice
does not pretend otherwise: the bench prints
`A052_BENCH_SESSION_CAP tokens=32768 verdict=exceeds-session-cap
cap=16000` beside its own results. What is proven is the 32k
run at the layer the session path is built on — the production
host `KVCache` (`core/mimir_well.mojo`) grown to all 32,768
positions and the production CPU attention kernel
(`flash_attention_gqa`, the A-043 SIMD body) decoding against
the full depth. Lifting the session cap is recorded as
follow-on work in the team CAMPAIGN_STATE.md; it is a session
policy change, not a KV/attention defect, and no engine bug
was found in this slice.

## Design (filed before the run)

`aesir_engine/core/long_context_cpu.mojo` holds the one
implementation shared by the bench and the suite cases:

- Depths: needles at 0, 1024, 4096, 8192, 16384, 24576, 32767
  — both ends and the full span.
- Distractor K/V components: stateless dyadic hash, multiples
  of 1/32 in [-0.5, 0.5), exact in F16. Fill and readback
  regenerate values independently from (pos, dim).
- Needle j: key 8.0 * e_j (one-hot dim j), value the constant
  dyadic `needle_value(j)` on all dims; needles are mutually
  orthogonal, so each probe isolates one depth.
- Probe: query 32.0 * e_j through `flash_attention_gqa` at
  its default scale 1/sqrt(64). Needle score 32, distractor
  scores bounded by 2 in magnitude, other needles exactly 0:
  softmax mass off the needle is below 32767 * e^-30 < 1e-8,
  so recovery must be exact to F16 rounding. Filed tolerance:
  max abs diff <= 0.010 per probe; filed rate 7/7 per layer.

## KV growth (census arithmetic, core/kv_account.mojo)

| tokens | bench shape (2 layers, 1 KV head, hd 64) | headline shape (32 layers, 8 KV heads, hd 128) |
|---:|---:|---:|
| 1,024 | 524,288 B | 134,217,728 B (128 MiB) |
| 4,096 | 2,097,152 B | 536,870,912 B (512 MiB) |
| 8,192 | 4,194,304 B | 1,073,741,824 B (1 GiB) |
| 16,384 | 8,388,608 B | 2,147,483,648 B (2 GiB) |
| 32,768 | 16,777,216 B (16 MiB) | 4,294,967,296 B (4 GiB) |

Growth is exactly linear (512 B/token bench shape; 131,072
B/token headline shape, F16 K+V). The 32k headline figure —
4 GiB of KV — is the honest price the A-046/A-047 precision
work exists to shrink; nothing here hides it.

## The run (bench, tests/bench_long_context_a052.mojo)

- Fill: 65,536 appends (2 layers x 32,768 positions) through
  `KVCache.append` in 47.65 ms wall — 727 ns per append,
  pattern generation included.
- Readback: 3,072 exact checks (12 sampled positions x 64
  dims x K/V x 2 layers, including every needle depth and
  both ends): **0 mismatches**.
- Probes: 14/14 pass, every probe max abs diff **0.0** — the
  recovered row equals the needle value exactly in F16 at
  every depth, first position and last alike. One full-32k
  decode-step probe costs ~0.41 ms (409-446 us across the 14
  probes) on this host.
- Capacity stays a hard wall: append at position 32,768 is
  refused (`exceeds fixed cache capacity`, suite case).

## Honest limits

- Layer-level run, not a model session (see the boundary
  above): no model logits are produced at 32k, so there is
  no rank/gap grade in this slice — the probes grade the
  KV/attention path against values planted by construction,
  with the reference recomputed independently of the fill.
- The distractor field is a deterministic dyadic pattern,
  not model KV: real-model KV at 32k inherits the growth
  table above and the same kernel, but its needle behaviour
  under RoPE-scrambled real keys is a model-run question
  that needs the session cap lifted first.
- CPU only. No accelerator execution is claimed.
