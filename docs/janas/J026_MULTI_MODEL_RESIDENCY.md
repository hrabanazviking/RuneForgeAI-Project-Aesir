# J-026 — Multi-model residency: two models, one process, one shared cache budget

**Roadmap:** J-026 (Part II), "Two models open in one process with a
shared cache budget (the server case); fairness rule; measured."
**Branch:** `yrsa/janas-j026`, based on `yrsa/janas-j025` tip
`c427b965` (the MoE stack — `expert_cache.mojo` with the fsketch
default, `moe_session.mojo` — is not on origin/main; origin/main
untouched at `ba7ee09b`, as in J-023/J-024/J-025).
**Verdict in one line:** the shared-budget layer is BUILT and PROVEN
at the cache layer (pool sizing + floor-and-borrow arbiter in
`expert_cache.mojo`, 7/7 unit-test groups PASS on the VM, and the
interleaved two-tenant measurement reproduced EXACTLY by the real
Mojo module); the fairness rule beats static partition where the
tenants' activity differs and ties it under flat concurrency; the
live two-session run is NOT PROVEN (blocked-with-reason, §8).

## 1. The question, and the clean-room record

Janas's public documentation specifies a per-process expert cache
sized from free memory with a hard cap. It does **not** specify how
one budget is divided when two models are open in one process (the
Part I census records no multi-model fairness rule). Per the road's
clean-room law this question is **answered-locally**: the rule in §3
is Aesir's own, derived from Aesir's sizing arithmetic (§2) and the
J-016/J-024 measurements. No Janas source was opened.

## 2. Inspection: the over-commit this slice exists to fix

In the J-025 tree, a cache budget reaches `ExpertCache` two ways,
neither coordinated:

- `plan_expert_cache_budget(free_at_open, total, hard_cap, resident,
  kv, scratch, per_token)` computes `budget = min(cap, free −
  reserve)`, where the reserve charges the resident set, a KV
  allowance, scratch, and an OS headroom of **one fifth of total
  memory**. Two sessions sized independently against the same
  free-memory snapshot each subtract their own reserve and each take
  up to the full remainder: on the unit test's stated machine
  (free = total = 10,000 B, per-session resident 300 / KV 200 /
  scratch 100) one session's budget is 7,400 B, so **two sessions
  claim 14,800 B of a 10,000 B machine** — and the OS headroom,
  which exists to protect everything else on the box, is silently
  charged (and spent) twice.
- `MoEStreamSession.__init__` takes `cache_budget_bytes` directly
  and constructs `ExpertCache(cache_budget_bytes, "fsketch")` with
  it. Two sessions in one process each hold exactly the budget they
  were handed; nothing anywhere sums the two. The session's payload
  store is per-session (its own `Dict` of expert payloads), so two
  sessions of the *same* file duplicate payloads rather than sharing
  entries — the budget is the shared resource, and it was unmanaged.

Statistics vocabulary (unchanged, J-016/J-018): per cache — accesses,
hits, misses, cold misses, bypasses, admissions, promotions,
evictions, evicted-before-reuse, bytes streamed / evicted / resident,
entries. The pool adds no new per-cache counters; the arbiter's own
actions surface as ordinary evictions in the lending cache and as
budget changes, and the measurement (§6) counts arbiter actions
(reclaims, enforcements) in the harness that drives them.

## 3. The fairness rule — floor-and-borrow (stated before measuring)

- **One pool per process.** The host sums the per-session reserves
  (resident sets, KV allowances, scratch) and sizes the pool ONCE
  (`plan_shared_cache_pool`, §4): the OS headroom is charged once,
  for the process. The pool total T is the sum the tenants' caches
  may ever hold together.
- **Per-tenant floor F = T / (2N)** for N tenants (N = 2 here, so
  F = T/4). The floor is a **return guarantee, not standing empty
  space**: it is the residency a tenant can always reclaim, not
  space that sits idle on its behalf.
- **Cap:** tenant i's instantaneous cap is
  `cap_i = max(F, T − Σ_{j≠i} P_j)`, where a peer's protected bytes
  `P_j` are its full resident bytes while it is **active**, and
  only `min(resident_j, F)` while it is **inactive** (idle or
  finished, session still open).
- **Work-conserving:** a lone or first tenant may use the whole
  pool; unused space is borrowed, never left idle while a peer
  streams.
- **Shrink behaviour:** caps are re-applied before a tenant's
  access. A borrower whose cap fell (peer returned, peer grew, or
  the pool itself contracted) is shrunk to its cap through its own
  cache's shrink order (fsketch: lowest sketch frequency, ties by
  LRU), pins held — a pinned overage is returned visibly, never
  forced (the J-018 contract). If a tenant's raw cap would fall
  below its floor, the arbiter first shrinks the other tenants
  toward their protected levels (active peers toward T − F, never
  below their own floor residency at N = 2; inactive peers toward
  their floor), then the tenant proceeds at F.
- **Reclaim on admission (the lending settlement):** an inactive
  lender's above-floor bytes are *lent, not freed* — they still
  occupy the pool. When a borrower's admission would push the
  summed residency over T, the arbiter reclaims the lender's
  above-floor bytes first (shrink order, down to its floor, never
  below). The invariant after every admission is
  **Σ resident ≤ T**.

Design notes: the floor fraction 1/(2N) leaves at least half the
pool contestable under full concurrency while making starvation
impossible — with N tenants all demanding their floors
simultaneously, ΣF = T/2 ≤ T always fits. Equal partition is the
special case where borrowing is forbidden; §6 prices that choice.

## 4. What was built (Mojo, the Aesir way)

All in `aesir_engine/core/expert_cache.mojo`; `moe_session.mojo`
gains only the documented host contract (its constructor already
takes the budget it is given — the pool discipline is the host's):

- `plan_shared_cache_pool(...)` — one sizing for the process:
  summed reserves through the exact J-018 reserve arithmetic, OS
  headroom charged once.
- `SharedExpertBudget` — the arbiter as pure arithmetic:
  `floor_bytes`, `protected_bytes(resident, active)`,
  `cap_for(tenant, residents, actives)`,
  `lender_reclaim_target(lender_resident, summed_resident)`.
  It refuses a pool too small to guarantee a floor.
- `ExpertCache.resize_budget(new)` — grow (cap only) or shrink
  (cap + policy-order shed, pins held) under an arbiter.
  `shrink()` is now its reducing case, semantics unchanged.
- `ExpertCache.shed_to_resident(target)` — the reclaim operation:
  evict to a resident ceiling **without changing the budget** (a
  lender's entitlement survives being lent from).

**Wiring honesty:** no Aesir surface today constructs two live MoE
sessions in one process — the MoE session is a library object, and
J-012's ledger has the server as an OpenAI-shaped core with no MoE
wiring. The slice therefore delivers the shared-budget cache layer
and proves it at that layer (unit tests + real-module two-cache
replay, §5–§6), with the host loop specified in §3 and exercised
verbatim by both the tests and the replay. No live two-model run is
faked or claimed (§8).

**Unit tests (PROVEN, VM, lightest target only** —
`mojo run -I aesir_engine aesir_engine/tests/test_expert_cache.mojo`,
the J-018 recipe; VM MemAvailable ~0.8 GB, no inference): all **7
groups PASS** — the 5 pre-existing (sizing/cap grammar; admission/
promotion/pin/shrink/cap; LRU/LFU; fsketch; no-scarcity fix) plus
two new J-026 groups: *shared pool sizing and arbiter arithmetic*
(the 14,800-of-10,000 over-commit pinned as arithmetic; pool budget
6,900 sized once; floor/cap/protected/reclaim values exact;
floorless pool refused) and *shared pool drive* (two real LRU
caches driven by the arbiter through contention — tenant 1 capped
at 200 against a 600-resident peer, Σ = 800 = T — idle lending with
reclaim to exactly the floor, the return with cap restored, a pool
contraction 800 → 500 shrinking a tenant back to its new floor cap,
and a 200-round churn holding Σ resident ≤ T with accounting
closing per cache).

## 5. Validation gate (passed before any two-tenant number)

Same discipline as J-024/J-025. The measurement simulator
(`j026_multi.py`, built on J-024's `FSketchCache`, itself validated
EXACT against the real module in J-024) must reproduce the known
single-tenant fsketch counters on the full J-016 trace (sha256
re-verified `85e1d241…cf99a`; 577 tokens, 73,856 accesses):

- vs the J-024 tournament's global fsketch runs at 128/256/512 —
  **EXACT** (hits, misses, cold, bypasses, admissions, evictions,
  evicted-before-reuse, streamed bytes, entries, resident).
- vs the real Mojo module's replay counters at 256/512
  (`j024_replay_results.txt`: hits 39,394/56,781, streamed scaled
  128,259,888/63,662,880, cold 1,024) — **EXACT**.
- The pool subclass run solo (cap machinery present, one tenant)
  at 256/512 — **EXACT** (the machinery is a no-op solo).

Then, after the measurement, the **real-module cross-check**
(`j026_replay.mojo`): two real `ExpertCache` fsketch instances
driven by the real `SharedExpertBudget` over the flattened
interleaved schedule (`j026_flatten.py`, exhaustion markers
included) reproduce the simulator's interleaved pool counters
**EXACTLY at both totals, all 10 exported counters for both
tenants** (e.g. @256: A hits 11,605 / streamed scaled 83,485,056 /
evictions 733; B hits 13,403 / streamed 98,074,800 / evictions 796;
@512: A 18,184 / 59,081,136; B 20,317 / 72,544,272). The
interleaved pool numbers in §6 are therefore **real-module numbers
with a simulator cross-check**, not simulator-only numbers. The
static/naive/ceiling numbers rest on the gate above (their caches
are the validated class at fixed budgets); the sequential and
return schedules are simulator-only and labelled SIMULATED.

## 6. Measurement (offline, on the real J-016 trace)

**Tenants (the honest server-case construction):** both tenants are
sessions of the **same OLMoE model file** serving disjoint prompt
subsets of the trace — tenant A = prose + code + technical
(266 tokens, 34,048 accesses), tenant B = structured + numbers +
instructions (311 tokens, 39,808 accesses). This is two sessions in
one process, **not two different model files**; per-tenant caches
hold separate payloads (as `MoEStreamSession` does), so the
measurement isolates the budget question. The split is asymmetric
by the J-016/J-024 evidence — A carries code (700 cold pairs,
isolated fsketch hit 0.924 @512) while B carries numbers +
instructions (~1,010 cold pairs each, isolated 0.668/0.713 @512) —
which is exactly where a fairness rule has something to decide.
Entry *sharing* between two sessions of one file is a different
optimisation, not built here (§8).

**Schedules:** *interleaved* (primary; token round-robin, the
concurrent server case; a tenant whose stream exhausts becomes
inactive and the other finishes under the same rule), *sequential*
(both sessions open, one serving at a time), and *return* (A serves
its first half, B serves in full while A idles, A returns).
**Budgets:** shared totals T = 256 and 512 pairs, built as
J-016/J-018/J-024 built them (pairs × mean scaled pair size 3,720;
full-scale bytes = scaled × 1,024). **Schemes:** (a) naive —
each tenant sized independently at the full T (the pre-J-026
behaviour; commitment 2T); (b) static — equal partition T/2 each,
fixed; (c) pool — floor-and-borrow (§3), commitment T; (d) ceiling
— each tenant alone at the full T. (a)'s per-tenant counters are
**identical to (d)'s, verified** — independent caches cannot tell
the schedules apart; (a) is (d)'s quality bought at twice the
commitment, infeasible under a T budget. Fairness: relative hit
r_i = hit_i / ceiling_i; worst-tenant r; Jain index over r.

### Interleaved (concurrent server case)

| T=256 | A hit | A MB/tok | B hit | B MB/tok | worst r | Jain r | Σ streamed |
|---|---|---|---|---|---|---|---|
| ceiling (d) / naive (a) | 0.512 | 238.1 | 0.512 | 237.7 | 1.000 | 1.000 | 137.3 GB @ 2T |
| static (b) | 0.342 | 320.7 | 0.323 | 329.8 | 0.630 | 0.9991 | 187.9 GB |
| **pool (c)** | 0.341 | 321.4 | **0.337** | **322.9** | **0.657** | **1.0000** | **185.9 GB** |

| T=512 | A hit | A MB/tok | B hit | B MB/tok | worst r | Jain r | Σ streamed |
|---|---|---|---|---|---|---|---|
| ceiling (d) / naive (a) | 0.737 | 128.7 | 0.757 | 118.6 | 1.000 | 1.000 | 71.1 GB @ 2T |
| static (b) | 0.512 | 238.1 | 0.512 | 237.7 | 0.677 | 0.9998 | 137.3 GB |
| **pool (c)** | **0.534** | **227.4** | 0.510 | 238.9 | 0.674 | 0.9987 | **134.8 GB** |

At T=256 the pool strictly helps the worst tenant: B (the
poor-locality tenant) gains +1.4 hit points over static (0.337 vs
0.323, worst r 0.657 vs 0.630) at no cost to A (−0.15 points), and
streams 1.1% less in total. At T=512 the pool redistributes toward
the first-moving tenant A (+2.2 points) and the worst tenant is a
wash (r 0.674 vs 0.677, −0.3 points) while total streamed bytes
fall 1.8%. The pool's summed residency reached exactly T at both
totals (static also fills T; naive reaches 2T — the over-commit,
measured). Arbiter actions under interleaving were only lending
reclaims in the exhaustion tail (62 @256, 144 @512); floor
enforcement and shrink-back never fired on these schedules — those
paths are covered by the Mojo unit tests, not by this trace, and
are claimed only as such.

### Sequential and return schedules (SIMULATED on the measured trace)

Where activity differs, lending is decisive. Sequential: the first
tenant reaches its ceiling exactly (r = 1.000 at both totals —
it borrows the whole pool), the second reaches r 0.827 @256 /
0.857 @512 against static's 0.630 / 0.677 (worst-tenant). Return:
the returning tenant A keeps r 0.917 @256 / 0.922 @512 of its
ceiling despite having lent its cache down to the floor during
B's phase, and B reaches 0.831 / 0.856 — worst-tenant r 0.831 /
0.856 vs static's 0.630 / 0.677. (Static's numbers are identical
across all three schedules — independent fixed caches cannot tell
schedules apart; that invariance is itself the contrast.) Reclaims:
187/374 (sequential), 313/618 (return) at 256/512.

## 7. Verdict

- **The over-commit is fixed in the engine**: one sizing per
  process (`plan_shared_cache_pool`) + an arbiter that holds
  Σ resident ≤ T after every admission — PROVEN at the cache layer
  (unit tests + real-module replay, §4–§5).
- **Floor-and-borrow is kept as the multi-model rule.** Under flat
  concurrency it ties or beats static partition (better worst
  tenant @256, better totals @512, worst-tenant wash @512); under
  any activity asymmetry — the actual server case, where models
  take turns being busy — it dominates static decisively, and its
  floor guarantee held in every measured schedule (no tenant ever
  fell below the residency its floor protects; the return schedule
  is the direct evidence).
- The naive independent sizing is recorded as what it is: ceiling
  quality at double commitment — on a memory-bound machine it is
  not a fairness scheme but the bug this slice removes.

## 8. Honesty ledger

- **PROVEN** (VM, lightest target): the pool/arbiter/resize/shed
  implementation and its unit tests (7/7 groups); the validation
  gate (simulator EXACT vs tournament + real-module replay); the
  real-module two-cache replay EXACT vs the simulator at both
  totals (interleaved pool counters are real-module numbers).
- **SIMULATED on the MEASURED trace**: the static/naive/ceiling
  comparisons and the sequential/return schedules (gate-validated
  simulator; the interleaved pool row is the real-module exception
  above).
- **NOT PROVEN — live two-session leg**: no live run of two
  `MoEStreamSession`s in one process was executed. Blocker: the
  204 road's S-095 is live on purplelongship (launched ~10:22 EDT
  per `ROADMAP_204_STATE.md`'s heartbeat, checked before any heavy
  run; this slice yields by the coordination law), and no Aesir
  surface yet hosts two MoE sessions (§4 wiring honesty). The leg
  is roaded to the Part II integration/gate slices (J-034 must
  re-cite it): two OLMoE sessions constructed with pool caps in one
  process on purplelongship, token-identity per session against
  its solo run, in a guarded idle gap.
- **NOT PROVEN / not built**: entry sharing between two sessions
  of the same model file (would change B's numbers fundamentally —
  the tenants' expert universes are identical here); N > 2 tenants
  measured (the arbiter is N-general and unit-tested at N = 2;
  the floor arithmetic is stated for general N); any tok/s or
  latency claim (offline replay has no wall); behaviour when the
  pool total itself shrinks mid-run beyond the unit-test
  contraction (that is J-028's slice).

## 9. Defects found and fixed in scope

- **Simulator v1 omitted the lending settlement**: caps alone let
  summed residency reach T + F (an inactive lender's bytes were
  treated as freed while still resident). The slice's own
  invariant check (Σ resident ≤ T, asserted after every access)
  caught it before any number was reported; the reclaim-on-
  admission step (§3) was added to the rule, the simulator, the
  Mojo host pattern, and the unit tests, and every number in §6
  comes from the fixed version. The fairness rule as filed
  includes the fix — a lending rule without a settlement step is
  an over-commit with better manners.
- **Environment incident**: /tmp (512 MB tmpfs) was at 100% during
  this slice and pixi's environment activation failed with
  StorageFull. Nothing was deleted to free disk (standing law);
  the runs were executed with `TMPDIR` redirected to the workspace
  overlay (`~/workspace/.verify-tmp/`), which is also where the
  replay CSV lives.

## 10. Files

- Engine: `aesir_engine/core/expert_cache.mojo` (pool sizing,
  `SharedExpertBudget`, `resize_budget`, `shed_to_resident`),
  `aesir_engine/core/moe_session.mojo` (host-contract doc),
  `aesir_engine/tests/test_expert_cache.mojo` (two new groups).
- This doc; `docs/janas/j026_replay.mojo` +
  `docs/janas/j026_replay_results.txt` (real-module replay);
  `docs/janas/j026_multi.py` + `docs/janas/j026_multi_results.json`
  + `docs/janas/j026_flatten.py` (measurement + schedule flattening;
  campaign copies in `~/workspace/model-tests/janas/`).
- Trace: the J-016 trace, sha256
  `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a`,
  kept in campaign records (not committed), as before.
