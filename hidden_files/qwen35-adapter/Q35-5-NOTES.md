# Q35-5 — Residency + prefix snapshots for hybrid state (worker slice)

Worker ran all six Forge roles sequentially in one seat (recon ->
design -> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-hipserve @ yrsa/hip-serve 874acdd6, sole writer.
NOT committed / NOT pushed — coordinator verifies and banks.
Scope: fixture-grade CPU serve only. No real GGUF was loaded through
the forward/serve path (the Q35-2 regression and the ripple probe
read the real file's metadata only, as banked). Real-file serve
stays parent-gated (Q35-3b/Q35-4b).

## Design

### KV finding (item 1 — which treatment is TRUE)
KVCache (core/mimir_well.mojo) is an append-only fixed buffer:
append() writes at (layer * max_seq_len + pos) * kv_dim, positions
are chronological, nothing wraps or reorders. So WITHIN one live
cache the prefix [0, boundary) is positionally stable and a
boundary length would suffice. But a snapshot must survive
reset(), which redraws a fresh KVCache over the same pool region
(pool.offset returns to runtime_offset), and any intervening
conversation overwrites prefix rows in place. Therefore the honest
treatment is COPY: a snapshot stores the full-attention layers' KV
rows [0, boundary) (K and V, f16, bit-exact) and restore writes
them back into the current cache at the same layer/pos offsets.
Only full-attention layers are copied — SSM layers never write the
cache (fixture: 1 of 4 layers; real 27B: 16 of 64).

### Snapshot primitives + keying
New Qwen35Snapshot (in aesir_engine/qwen35_session.mojo):
- boundary = committed token count (position == len(stream) at a
  finished turn); stream = the committed token stream copy — the
  snapshot's binding (the Llama session's cached_tokens pattern,
  generalized: stream + state, not stream alone).
- s_data + conv_data: element copies of Qwen35State's heap f32
  buffers (fixture: 3 layers x 4 v-heads x 16 x 16 = 3072 f32 +
  3 x 3 x 128 = 1152 f32).
- kv_k / kv_v: full-attention layers' prefix rows, packed in layer
  order, f16 (the cache's own type — the copy is bit-exact).
- conv_text + generated_text: the serve-presented conversation
  text for this conversation up to this boundary, and this turn's
  generated reply text — the text-level binding (below).
Session API: snapshot_boundaries() (0 first: the zero-state is a
virtual snapshot — restoring it IS state.reset(), no bytes stored
and it is never evicted) and restore_snapshot(boundary) -> Bool
(False when evicted/unknown). Snapshots are taken automatically
in next_chunk at every finished turn (eos and length/context
endings both), AFTER the final token's forward, so position ==
len(stream) and the state summarizes exactly the stored stream.
Re-snapshotting an identical boundary+stream replaces the older
entry (becomes newest). reset() deliberately does NOT clear the
store — surviving reset is the store's purpose. Cancelled turns
take no snapshot (reset_required stands).

### Reuse rule (begin_turn at position 0 only)
Restore the LONGEST snapshot whose committed stream is an exact
prefix of the new request's stream; evaluate only the remainder;
anything else evaluates cold. Two exact verifications, no fuzzy
matching, checked in this order:
1. Text-extension (the serve/stateless-client path): the resent
   prompt text must be byte-exactly snapshot.conv_text +
   "Assistant: " + snapshot.generated_text + "\n" + "User: " +
   one new user message + "\n" (the serve's chat format; exactly
   one new turn, mirroring resident_delta's shape rule; a delta
   containing "\nAssistant: " or "\nUser: " is refused). Then the
   new request's token stream is BY CONSTRUCTION snapshot.stream +
   tokenize(new message) — an exact token prefix, with the
   generated tokens carried as IDs, never re-tokenized. (This is
   the seam the HS-6 docstring names: re-tokenizing resent reply
   TEXT cannot reproduce the generated token IDs — the fixture's
   fresh-instance control proves it, prompt 193 vs stream 90 — so
   token-stream equality for a text resend can only be established
   this way, by verifying the text and reconstructing the stream.)
2. Token-prefix (the general path): reusable_prompt_prefix(
   snapshot.stream, tokenized_prompt) >= snapshot.boundary. This
   also enforces the prompt_prefix contract that the final prompt
   token always recomputes: a snapshot covering the WHOLE new
   prompt offers no reuse (its boundary exceeds the capped match).
Usage accounting on a snapshot hit follows the resident convention:
prompt_tokens counts the reconstructed committed stream (boundary +
delta on path 1; the full tokenized prompt on path 2),
reused_prompt_tokens == boundary, evaluated == prompt - reused.
Resident continuation (start > 0) is untouched: no snapshot logic
runs, reused stays 0 in-session and the serve adds resident_base
as before (Q35-4a bench re-run passes verbatim, below).

### Store bound + real-model cost (item 2)
Bound: session field snapshot_limit = 4 turn-boundary snapshots
(configurable per session), FIFO eviction of the oldest, zero-state
excluded. Per-snapshot cost at the real shapes:
- 27B SSM: s_data 150,994,944 B + conv rings 7,864,320 B =
  158,859,264 B (~159 MB); KV prefix: 16 layers x boundary x 1024
  x 2 B x (K+V) = boundary x 65,536 B (boundary 4096 -> 268,435,456 B;
  8192 -> 536,870,912 B). K=4 at ctx 4096: ~0.64 GB of SSM + up to
  ~1.07 GB of KV worst case — an informed bound, not an accident:
  chat turn boundaries in this serve's Voxta pattern are short, so
  typical KV prefixes are far below the ctx-bound worst case.
- 40B SSM state alone ~235 MB per snapshot (Q35-2 memory plan
  geometry), KV wider still; K=4 -> ~0.94 GB SSM alone. If the 40B
  is ever served, snapshot_limit should be re-set with these
  numbers in hand — the field exists for exactly that.

### Capability wording (item 3)
serve_loaded gains ONE optional parameter prefix_reuse_detail
(default ""); the /health capabilities object gains the key
"exact_prefix_reuse_detail" ONLY when a detail is supplied, so
every other profile's health payload is byte-identical to before.
The qwen35 call site now passes prefix_cache=True with detail
"snapshot-based at committed turn boundaries only". Verbatim from
the bench health body: "exact_prefix_reuse": true,
"exact_prefix_reuse_detail": "snapshot-based at committed turn
boundaries only". A bare positional-KV implication is never made:
the qualifier travels with the boolean in the same object.

### F1 interaction (stated precisely)
Q35-3 F1: cross-path (per-token vs batched-block) state is
f16-ulp-close, NOT bit-identical (s 0.0008479953, conv 0.0078125,
logits 0.013671875); same-path continuation is bit-exact (d1/d2).
Snapshot/restore here is a byte copy plus a continuation evaluated
the SAME way as the reference run, so proof (a) claims bit-exact
0.0 — and gets it (below). NO cross-path snapshot equality is
claimed: a snapshot taken after a batched prefill, restored and
continued per-token, would inherit exactly F1's ulp diffs vs a
per-token reference. All Q35-5 proofs compare like-for-like paths.

## Files changed
- aesir_engine/qwen35_session.mojo: Qwen35Snapshot struct;
  snapshot store + _take_snapshot/_restore_at/restore_snapshot/
  snapshot_boundaries; begin_turn snapshot paths (text-extension,
  token-prefix) at position 0; reset() preserves the store;
  next_chunk accumulates reply text and snapshots at turn end;
  module docstring rewritten for the Q35-5 contract.
- aesir_engine/cli/native_serve.mojo: serve_loaded optional
  prefix_reuse_detail param + health key (emitted only when set);
  qwen35 call site passes True + the snapshot detail string.
- aesir_engine/tests/test_qwen35_snapshot_q35_5.mojo: NEW proof.
- hidden_files/qwen35-adapter/q35_5_bench.py: NEW bench;
  q35_4_bench.py: capability assertion updated to the Q35-5 truth
  (deliberate extension; resident assertions untouched);
  build-q35-5.sh (build-q35-4.sh + the new test binary).

## Proof (fixture, side port 18435, fenced units; logs q35-5-*)

Session level (q35-5-session-test.log, ALL PASS, exit 0):
- (a1) RESTORE_DIFF s=0.0 conv=0.0 kv=0.0 — restore at B1=72
  reproduces the boundary state bit-exact.
- (a2) RERUN_B DIFF s=0.0 conv=0.0 logits=0.0 — B re-run after
  restore == resident B bit-exact (state + next-token logits),
  reply equal (R2 verbatim as Q35-4a).
- (a3) STATELESS_BEGIN prompt_tokens=90 reused=72 position=90;
  STATELESS_RERUN DIFF s=0.0 logits=0.0; reply == resident R2.
- (c) DIVERGED_BEGIN prompt_tokens=191 reused=0; R_DIV == fresh
  cold reference exactly (reply tok0406...tok0444, the same text
  the Q35-4a fresh-instance control produced for its resend).
- (d) D_BOUNDARIES trace over 6 turns (max_tokens 4):
  0 60 80 / 0 60 80 100 / 0 60 80 100 123 / 0 80 100 123 144 /
  0 100 123 144 168 — store holds exactly 4, boundary 60 evicted,
  restore_snapshot(60) == False.

Serve level (q35-5-bench.log, ALL PASS, exit 0), one instance:
- HEALTH: exact_prefix_reuse=true WITH the detail qualifier
  (verbatim body in the log).
- RESIDENT T1 prompt=56 reused=0 reply==R1; T2 prompt=90
  reused=72 reply==R2 (Q35-4a path unchanged).
- STATELESS: intervening different-session request (prompt=56,
  reused=0) destroys residency; full-history resend then:
  prompt_tokens=90, reused_prompt_tokens=72 (evaluated=18),
  reply == resident R2 — via snapshot restore, not residency.
- DIVERGED (no session): prompt_tokens=191, reused=0, reply ==
  in-process diverged reference R_DIV.
- BOUND: resident T3 reused=106, T4 reused=138 (snapshots now
  exceed 4, turn-1 boundary evicted); resend of the oldest
  history: prompt_tokens=193, reused=0 (cold full evaluation).

## Regression
- Full engine compile exit 0 (q35-5-build.log, ENGINE_BUILD_EXIT=0;
  all test/probe builds exit 0).
- Q35-1 loader: ALL PASS (q35-5-regress-q35-1.log).
- Q35-2 registry: ALL PASS (q35-5-regress-q35-2.log).
- Q35-3a forward: ALL PASS, greedy sequence identical to banked
  (q35-5-regress-q35-3.log).
- Q35-4a session reference: ALL PASS (q35-5-regress-q35-4.log) —
  resident R1/R2, reset reproduction, fresh reproduction.
- Q35-4a HTTP resident bench re-run: ALL PASS
  (q35-5-regress-q35-4-bench.log; health now shows the Q35-5
  capability truth); fresh-instance control ALL PASS
  (q35-5-regress-q35-4-fresh.log: prompt=193, reused=0, reply
  differs from resident R2 as required).
- Ripple/admission probe: ALL PASS (q35-5-ripple.log), unchanged
  expectations (admission truth untouched by this slice).
- Full 905 matrix NOT re-run (slice order; baseline 901/905 stands).
- Proof units stopped; port 18435 free; aesir-gate (:18434)
  active and untouched throughout.

## Named gaps / next
- Snapshot store is per-session in-memory only; nothing persists
  across serve restarts, and suspend/restore as a serve feature
  remains unimplemented (stated in the session docstring).
- Text-extension reconstruction is bound to the serve's current
  chat format ("User: "/"Assistant: " lines) — the same format
  resident_delta already depends on; a format change must update
  both together.
- Real-file (27B/40B) snapshot cost is computed, not measured;
  measuring it is Q35-4b/Q35-3b-gated like all real-file serve work.
