# Partial-state teardown preconditions — Track R item R5 study (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.9 (AES-NUM-009), Track R.
**Research only — no code, no physical run, no invented
ordering.** Question, left open by AES-PROG-001 Q6 and
AES-NUM-003 layer 8: for partial states, what are the receiver's
teardown ordering rules and preconditions — a configured object
alive at infer destroy, destroy on partially configured objects,
receiver behaviour on out-of-order teardown, and the
disconnect-cleanup trigger conditions on this profile?
AES-PROG-004 already answered two points at source level
(destroy-configured performs shutdown receiver-side; disconnect
cleanup releases all of a client's resources); this study
deepens both into per-sub-question grades and adds the handler
semantics PROG-004 did not need.

**Verdict: PARTIALLY ESTABLISHED.** At the pinned receiver's
*handler level* the preconditions are now ESTABLISHED, and the
headline is that **the destroy actions carry no preconditions
at all**: every destroy handler ignores its release result and
replies success, destroy-infer performs no check for live
configured children, and destroy-configured performs its own
shutdown internally (§2–§4). The disconnect cleanup's *trigger*
is likewise ESTABLISHED at source level for the pinned hRPC
server: its per-client serve loop runs the cleanup on **any**
request-handling failure, communication-closed included, in a
fixed tier order (§5). What remains **NOT PROVEN** is
everything below that layer: the firmware/device consequences
of out-of-order teardown, and whether Aesir's grouped-control
session termination on the installed SoC profile constitutes
the client disconnect that triggers this server's cleanup —
the same profile gap AES-PROG-004 recorded, unchanged by
anything in this slice. AES-NUM-003 layer 8 therefore
re-grades by addendum (§6) but does **not** clear; the 4.4
gate re-run on layer 8 only **passes** (§6).

## 1. Search bounds (what was actually searched)

1. **Pinned public HailoRT** `d503417f2a0db186a838390fb08690c4ea0f415e`
   (v5.3.0, MIT, interface facts only) — read this slice, at
   the pin, via the GitHub connector (study copies kept
   outside the Git tree):
   - `hailort/hailort_server/hailort_server.cpp` (1,256 lines;
     sha256 `80b8c3c6…`) — every lifecycle handler: vdevice
     destroy, infer-model destroy, create-configured, and the
     configured destroy / activate / deactivate / shutdown
     handlers, plus `cleanup_client_resources`.
   - `hailort/hrpc/server.cpp` (sha256 `278f5457…`) — the
     per-client serve loop that calls the cleanup, and the
     ClientConnection action thread.
   - `hailort/hrpc/server_resource_manager.hpp` (sha256
     `a9445bfa…`) — `release_resource` / `release_by_id` /
     `execute` semantics every handler above stands on.
   - `hailort/libhailort/src/net_flow/pipeline/infer_model.cpp`
     (sha256 `393be20f…`) and
     `hailort/libhailort/include/hailo/infer_model.hpp`
     (sha256 `65428f54…`) — what a configured object actually
     holds, its `shutdown()` / `deactivate()` / destructor,
     and `InferModelBase::configure()`'s construction order.
2. **This repo's own evidence** — AES-PROG-001 Q6 (the
   question, and the two handle tiers), AES-PROG-002 (the
   owner's conservative client-side order, host-qualified),
   AES-PROG-004 (the two source-level answers this study
   deepens; its residue table), AES-NUM-003 layer 8.
3. **Open web** — not needed; the behaviour in question is
   stated in the pinned code, and no web source is claimed.

Bounded-search caveat, as in AES-NUM-005..008: graded results
over the sources named. Everything below is **source-level**
(PUBLIC INTERFACE FACT): what the pinned receiver code does,
not a physical observation on Mimir. Handler behaviour is
not firmware behaviour (§4, last bullet).

## 2. R5a — configured object alive at infer destroy: ESTABLISHED (handler level)

`handle_infer_model_destroy` @pin does exactly three things:
deserialize the infer handle, call
`ServerResourceManager<InferModel>::release_resource(handle,
client_id)` with the result void-cast, and reply
`HAILO_SUCCESS`. There is **no precondition**: no lookup of
configured objects derived from that infer model, no refusal,
no cascade, and no cleanup of the server's
`m_infer_model_to_info_id` entry for the handle (that map is
erased only by disconnect cleanup, §5) or of any configured
object's buffer pools (those are cleaned only by the
configured destroy handler or disconnect cleanup).

The independence is structural, not just procedural.
`InferModelBase::configure()` @pin builds the configured
object around a **shared `ConfiguredNetworkGroup`**
(`network_groups[0]`) plus an async runner;
`ConfiguredInferModelImpl` holds that network group
(`m_cng`) and the runner — it does **not** hold the
`InferModel`. The two tiers are registered in two independent
resource managers under the same client id. Releasing the
infer tier therefore removes exactly one manager entry; the
configured tier's registered existence is untouched by it.

**NOT PROVEN:** what the firmware/device does with the
underlying network group if the configured object is *used*
(run, activated) after its infer model was destroyed — the
pinned public sources describe manager and object lifetimes,
not device state under that sequence, and this study does
not infer one from the other.

## 3. R5b — destroy on partially configured objects: ESTABLISHED (handler level)

**Destroy-configured has no state precondition.**
`handle_configured_infer_model_destroy` @pin: deserialize,
execute a shutdown lambda on the handle with the result
**void-cast**, `cleanup_cim_buffer_pools` for that handle,
`release_resource` void-cast, reply `HAILO_SUCCESS`. Because
the shutdown result is discarded, the handler succeeds the
same way on a configured object in any state the manager can
hold — never activated, activated, or already shut down.
This confirms and widens AES-PROG-004's Q6 answer: not only
is no *prior explicit shutdown* required, no state of the
object makes this handler refuse.

What that internal shutdown does is also sourced
(`infer_model.cpp` @pin): `ConfiguredInferModelImpl::shutdown()`
aborts the async runner, waits (bounded) for ongoing parallel
transfers to reach zero, then `deactivate()` — which simply
drops the activated-network-group pointer (`m_ang = nullptr`)
and returns success. And the object's **destructor calls
`shutdown()`**: the last shared-pointer release of a
configured object is itself a teardown path, which is what
makes the manager-release cleanups in §5 meaningful at
source level.

**Partial-configure failure residue — ESTABLISHED.** The
create-configured handler @pin registers the `InferModelInfo`
and the configured object with their managers **before** it
creates the DMA buffer pool and the run-async info pool, and
several `TRY` steps sit between registration and the reply.
A failure in those later steps returns an error with both
objects already registered and their handles **never sent to
the client** — a server-side residue of exactly the
handle-never-learned class AES-PROG-004 named for create,
now sourced for configure as well. The client cannot destroy
what it cannot name; the only sourced reclaim is disconnect
cleanup (§5). (If `configure()` itself fails, by contrast,
nothing is registered and the infer object survives — the
failure returns before any registration.)

## 4. R5c — out-of-order teardown: ESTABLISHED (handler level), device consequences NOT PROVEN

The pinned handlers split into two consistent classes:

- **Destroy actions are tolerant; their replies prove
  nothing about prior state.** All three destroy handlers
  (vdevice, infer-model, configured) void-cast their release
  results and reply `HAILO_SUCCESS` unconditionally after
  deserialization. `release_resource` on a missing or
  already-released handle logs an INFO line and returns
  null — so a repeated destroy, a destroy of a never-created
  handle, and a destroy in any cross-tier order (configured
  before infer, infer before configured, vdevice at any
  point) all earn the same success reply. VDevice destroy
  likewise releases only its own tier and removes the
  client's vdevice entry; it performs no check for live
  infer or configured objects.
- **Non-destroy actions on a handle are strict.** Activate,
  deactivate, shutdown (and every other `execute`-based
  handler) `CHECK_SUCCESS` the manager's `execute`, whose
  lookup fails with `HAILO_NOT_FOUND` for a missing handle.
  So *using* a destroyed handle fails at the receiver, while
  *re-destroying* it does not: after teardown, a handle is
  dead for work and inert for destruction.
- **Per-client execution is serial.** Each ClientConnection
  runs its actions on a single action thread fed by a queue
  (`hrpc/server.cpp` @pin), so one client's teardown actions
  execute in the order that client sent them — "out of
  order" at this layer means a different *sequence*, never
  concurrent partial execution of two teardowns.

**NOT PROVEN:** the device/firmware consequences of any
out-of-order sequence — e.g. whether an activated network
group is force-deactivated when its vdevice resource is
released first, or whether infer destroy under a live,
activated configured object leaves device state the next
configure inherits. No searched public source states them.

## 5. R5d — disconnect cleanup: trigger ESTABLISHED (pinned server), profile trigger NOT PROVEN

**Trigger — ESTABLISHED at source level.** In
`Server::serve_client` (`hrpc/server.cpp` @pin), the serve
loop calls `handle_client_request` until it returns a
non-success status, then — unconditionally on that exit
path — shuts down the client's action thread, calls
`cleanup_client_resources(client_connection)`, and closes
the connection. Request handling fails, and the loop
therefore exits to cleanup, on **any** of: the read failing
with `HAILO_COMMUNICATION_CLOSED` (the client closed the
communication — a disconnect), a parse/dispatch failure, or
a handler `parse_request` failure (the create-infer-model
handler's payload `read_buffer` reports communication-closed
the same way). There is no separate disconnect message and
no timeout trigger in this code: **cleanup is what the
serve loop does when serving that client ends, for any
reason.**

**Cleanup order — ESTABLISHED** (`hailort_server.cpp` @pin,
confirming AES-PROG-004 with the order now explicit):
configured infer models first (`release_by_id` for the
client id, plus their buffer pools and run-async info), then
infer-model infos, then infer models (plus the
info-id map), then the vdevice (`release_by_id` plus
`remove_vdevice`). Releases drop the manager's shared
pointers; for configured objects the destructor-mediated
`shutdown()` of §3 is the sourced mechanism by which a
release becomes a device-side stop, with the caveat that
any *other* outstanding reference would defer destruction —
whether any exists at cleanup time is NOT PROVEN.

**Profile sub-part — NOT PROVEN (unchanged).** All of the
above describes the pinned hRPC server's own clients.
Aesir's Campaign 1–3 sessions do not connect to that server
as an hRPC client (AES-NUM-006: the INTEGRATED→OsSession
socket path is HailoRT's client realization, not Aesir's
grouped-control transport). No searched source establishes
that terminating an Aesir grouped-control session makes
this server's serve loop exit for a corresponding client,
so on the installed profile the cleanup remains a **named,
source-backed reclaim path — never a guarantee**, exactly
as AES-PROG-004 and AES-NUM-003 layer 8 recorded. The three
recorded handle residues therefore stand as written.

## 6. Re-grade and the 4.4 gate, changed layer only

Addendum to AES-NUM-003 (also appended to that document):

- **Layer 8 (cleanup contract):** its open term narrows.
  Was: teardown ordering and preconditions for partial
  states NOT ESTABLISHED in full. Now: the **receiver
  handler-level preconditions are ESTABLISHED** — destroy
  actions carry none (§2–§4: no cross-tier check, internal
  shutdown on destroy-configured, tolerant success replies,
  strict use-after-destroy), a **partial-configure residue
  class is sourced** (§3), and the **disconnect cleanup's
  trigger and tier order are ESTABLISHED** for the pinned
  server (§5). Still NOT PROVEN: the firmware/device
  consequences of out-of-order teardown, and whether
  Aesir's session termination triggers that cleanup on
  this profile (§5). Layer 8 stays **SPECIFIED (host) /
  NOT ESTABLISHED (device, partial states)** — a contract
  whose device half rests on a reclaim path that cannot be
  credited on our profile does not clear, and the honest
  host terms (conservative order, residue recording) remain
  load-bearing precisely because the tolerant destroy
  replies prove nothing.
- **Gate re-run (4.4 terms, layer 8 only):** every new
  statement carries a pin-cited source or an explicit
  NOT PROVEN grade. No Do Not Infer entry is violated: a
  destroy's success reply is **not** read as proof the
  object existed or was device-destroyed (§4 — the entry
  against crediting unestablished completions is enforced
  by this study's own terms); handler behaviour is **not**
  read as firmware behaviour (§2/§4); the pinned server's
  cleanup is **not** read as an Aesir-session guarantee
  (§5). **PASS on the changed layer.**

Unchanged and still blocking: layers 2/3/5 (R1, R3 NOT
PROVEN) and layer 6's base list (R4 PARTIAL). **Campaign 4
EXIT still NOT MET; operation UNQUALIFIED; Campaign 5 NOT
contracted.**

## 7. R5 disposition and what remains

- **R5: PARTIALLY ESTABLISHED** — handler-level teardown
  preconditions, the partial-configure residue class, and
  the disconnect-cleanup trigger/order ESTABLISHED at
  source level; device consequences of out-of-order
  teardown and the cleanup's applicability to Aesir's
  profile NOT PROVEN. R5 closes this study pass under the
  4.4 gate's terms (each sub-question closed on IN-grade
  evidence or recorded NOT PROVEN).
- **Track R is now complete as a study pass:** R1 NOT
  PROVEN, R2 ESTABLISHED, R3 NOT PROVEN, R4 PARTIALLY
  ESTABLISHED, R5 PARTIALLY ESTABLISHED. Campaign 4's exit
  still turns on R1/R3-class public evidence (a public CCW
  layout and a placement census) that no searched source
  contains; no further Track R study slice is named by the
  roadmap for this iteration, and Campaign 5 remains
  uncontracted until the exit is met.

## 8. Audit

Research only. No code, no emitter, no bytes constructed,
no physical child, no device contact. Sources: pinned
HailoRT files read at `d503417f…` via the GitHub connector
(§1, with sha256 recorded per file); repo evidence as cited.
