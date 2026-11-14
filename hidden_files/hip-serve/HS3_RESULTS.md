# HS-3 results - two-turn KV bench, 2026-11-14 (purpleraider, gfx1151, 100 GiB GTT cap live)

Serve: aesir-gate unit, llama3-3b:latest on :18434, backend hip, context 4096 for the bench.
Contention: Ollama loaded with no model during all benches; desktop idle; MemAvailable 124 GB
at bench start, ~27 GB while a HIP session lives (the HIP runtime takes its arena), back to
~124 GB when the unit stops.

## Native surface (/v1/generate), raw prompts - hs3-bench.log / hs3-bench2.log
- turn1: prompt 50, reused 0, evaluated 50, prefill 332 ms, wall 828 ms
- turn2 (history resent with \n seams): prompt 92, reused 44, evaluated 48, prefill 347 ms
- turn3 control (system changed): prompt 81, reused 5, evaluated 76 - reuse collapses as designed
- B-turn2 (append-exact P1+reply+P2): prompt 92, reused 44, evaluated 48
- B-turn3 (one \n seam, vs the longer committed stream): prompt 92, reused 71, evaluated 21

## Chat surface (/v1/chat/completions) - hs3-bench3-chat.log
- C-turn1: prompt 52, reused 0, evaluated 52, wall 825 ms
- C-turn2 (full message list resent): prompt 98, reused 46, evaluated 52, wall 610 ms
- C-turn3 control (system changed): prompt 87, reused 5, evaluated 82
- Streamed chat probe: SSE chunks + [DONE], text assembled cleanly (hs3-bench5-stream.log)

## The seam finding (measured three ways, probe in hs3-bench4-probe.log)
- Identical prompt resent: reused = prompt - 1 (49/50). The prefix mechanism is exact.
- Any resend that extends past a generation seam loses ~6 tokens at the seam: the resent
  string tokenizes its tail differently than the committed token stream did. Prefix
  matching cannot bridge the hole, so the span after the seam re-evaluates that turn.
- Consequence at chat scale: each turn reuses everything up to the previous turn's seam
  (system + history head: the big, stable part) and pays ~seam + the newest exchange.
  Against the Ollama/Voxta baseline (14,712 of 14,712 tokens re-evaluated, 52.1 s), even
  this first form removes the standing-context cost from every turn.
- Full fix = token-level stateful sessions (compose by splicing committed token ids,
  tokenize only the new segment). Recorded as an HS-6 design requirement.

## Instrumentation shipped with this slice
- NativeGenerationStatus carries reused_prompt_tokens (Llama3 reports the session count;
  Gemma4 reports 0 until HS-4 gives it a cache).
- /v1/generate bodies and the OpenAI usage objects report reused_prompt_tokens;
  evaluated = prompt_tokens - reused_prompt_tokens. Old callers unaffected (defaulted param).
