# HS-7 results — stable-order memory injection contract

Date: 2026-11-14. Branch `yrsa/hip-serve`. Builds on HS-1…HS-6.
This completes the seven-slice HIP-serve line.

## What shipped

- `core/memory_injection.mojo` — the contract module:
  - `MemoryBlock {key, text, order}`.
  - Deterministic order: blocks render sorted by (order, key),
    regardless of arrival order.
  - Token budget: admission estimate = ceil(bytes/4) of the rendered
    line + 1 token newline allowance (a documented estimate, not an
    exact tokenizer count). A block is admitted whole or not at all;
    an oversize block is skipped and later smaller blocks are still
    considered.
  - Render format: one `[key] text` line per admitted block.
  - Append-stability: when blocks are only appended (the new block
    sorts after the existing ones), turn N's render is a byte-for-byte
    prefix of turn N+1's render, so the cached prefix never churns.
- `server/openai.mojo` — requests may carry `memory_blocks`:
  [{key, text, order}] with bounds: key 1..128 B, text ≤16 KiB each,
  ≤64 KiB total, ≤64 blocks.
- `cli/native_serve.mojo` — the render enters the SYSTEM position of
  the composed prompt (effective system = render + "\n" + caller
  system), under a serve budget of 25% of the context
  (context // 4 tokens). Because HS-6 residency keys on the effective
  system, unchanged blocks keep the resident delta-only path; an
  appended block changes the effective system and the session reseeds
  honestly through the stateless path. `/health` advertises
  `"memory_injection":true`.

## Proof

- Pure tests `tests/test_memory_injection.mojo` PASS standalone (log
  `memory-injection-test.log`, RUN_EXIT=0): (order, key) sorting from a
  shuffled input; whole-block budget admission (budget 10 admits exactly
  the 10-token first line, nothing partial); zero budget and empty input
  render empty; append-stability — render([A,B]) is a byte-prefix of
  render([A,B,C]). Registered in run_all as
  `serve.memory_injection_render` / `serve.memory_injection_append_stability`.
- Live bench `hs7_bench.py` (log `hs7-bench.log`), gate = llama3-3b on
  HIP, ctx 8192, fenced 24G/32G:
  - T1 (seed, blocks A = user-name + home): prompt 50; the model's reply
    used the injected facts verbatim: "Your name is Volmarr, and you
    live in Indiana."
  - T2 (same blocks, continuation): **reused 64, evaluated 19** — the
    resident delta-only path holds with memory attached.
  - T3 (third block appended): reseeded as designed — evaluated 108 —
    and **reused exactly 25**, which is the append-stable injected
    prefix (BOS + system header + the two original memory lines): the
    shared prefix up to the newest block survives byte-for-byte, as the
    contract promises. The reply used the new block: "You're working on
    Aesir, a local AI engine."
  - Honest boundary: on an append turn, conversation tokens AFTER the
    system slot are re-evaluated on the stateless path, because the new
    block inserts ahead of them. The guarantee is exactly the one the
    slice specified — the injected prefix itself never churns — and the
    resident path (blocks unchanged) never pays even that.
- Engine rebuilt clean (ENGINE_BUILD_EXIT=0); gate restarted on the new
  binary and verified (/health ready, memory_injection true).

## Kobold dossier gap

As with HS-6: `~/workspace/your_files/studies/koboldcpp/` does not exist
on the coordinator VM, so no Kobold memory/KV patterns were folded in;
the contract follows the Voxta study's stable-order recall finding
(memory rendered in a stable order so prefix caching survives) and
Aesir's own session internals.
