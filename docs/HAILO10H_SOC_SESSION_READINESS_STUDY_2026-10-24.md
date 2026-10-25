# SoC session readiness protocol — Track R item R2 study (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.6 (AES-NUM-006), Track R.
**Research only — no payload contract, no physical child, no
invented values.** Two questions, both left open by AES-NUM-001's
Track R addendum and AES-NUM-004 finding F1:

- **R2:** how is readiness signaled between host and receiver on
  the SoC RPC session — the layer underneath
  `RpcConnection::read_buffers`' `wait_for_read_async_ready`
  call — and what are the size/chunking terms of one async
  transfer?
- **F1:** is any *program-result* readback path described in the
  pinned sources (AES-NUM-004 tightened AES-NUM-003 layer 7
  because none was qualified)?

**Verdict: R2 ESTABLISHED at source level, with one sub-part
NOT PROVEN.** The pinned sources answer the readiness question
exactly, and the answer is that **there is no wire-level
readiness signal to discover**: readiness is a purely *local*
admission condition at each end of the session (a bounded
ongoing-transfer queue), the transfer size is known to the
receiver only from the preceding RPC message, and the byte
stream itself is the synchronization. **F1: a program-result
readback path IS described at source level** (client-registered
read buffers, read after a success reply, before the completion
callback; the configured-infer-model HRPC client builds them
from output bindings) — it remains **unqualified in Aesir**,
so AES-NUM-004's caution stands as a qualification statement.
Per-sub-question grades are in §2–§4; the re-grade of
AES-NUM-003 layers 4 and 7 and the 4.4 gate re-run on those
changed layers only are in §5.

## 1. Search bounds (what was actually searched)

1. **Pinned public HailoRT** `d503417f2a0db186a838390fb08690c4ea0f415e`
   (v5.3.0, MIT, interface facts only) — read this slice, at the
   pin, via their public GitHub URLs: the full hrpc tree listing
   (766 blobs, not truncated) for any SoC session file;
   `libhailort/include/hailo/hailo_session.hpp` (the Session
   interface contract); `hrpc/hailo_session.cpp` (transport
   dispatch); `hrpc/rpc_connection.{hpp,cpp}`;
   `hrpc/session_internal/eth_session.{hpp,cpp}` (OsSession);
   `hrpc/session_internal/async_actions_thread.cpp`;
   `hrpc/session_internal/pcie_session_internal.cpp`
   (RawPcieSession, contrast case); `hrpc/client.cpp`;
   `libhailort/src/net_flow/pipeline/configured_infer_model_hrpc_client.cpp`
   (F1 call sites).
2. **This repo's own evidence** — grep for the readiness entry
   points and session terms across docs, TASK contracts, Mojo
   and tests. The only prior touch is AES-NUM-001's addendum
   itself; Aesir's own session work (Campaigns 1–3) speaks the
   grouped-control/session protocols it qualified there and
   does not implement HailoRT's Session layer.
3. **Open web** — one bounded query on the exact entry-point
   name. Results were Hailo community threads about the
   higher-level infer API's `wait_for_async_ready`; nothing
   describes a session-layer wire protocol. Lane D is not a
   readiness source (its stack sits above HailoRT; AES-NUM-005
   §1 stands).

Bounded-search caveat, same as AES-NUM-001/005: graded results
over the sources named, not proof of absence everywhere. The
on-chip firmware below the public session layer is not a
public source; anything only it could answer is graded
NOT PROVEN, not guessed (§3, third bullet).

## 2. R2a — the readiness interface contract: ESTABLISHED

At the pin, `hailo/hailo_session.hpp` defines the contract in
so many words: `Session::wait_for_read_async_ready(transfer_size,
timeout)` (and its write twin) — "Waits until the session is
ready to launch a new call to `Session::read_async()`. **Each
session has a limited-size queue for ongoing transfers**."
Expiry returns `HAILO_TIMEOUT`. The header's standing note is
the whole peer-synchronization contract: "the write pattern
should match the read pattern" — transfers are consumed in
posted order and size.

`RpcConnection` (rpc_connection.{hpp,cpp} @pin) consumes it
exactly as AES-NUM-001 recorded, now confirmed line by line:
`read_buffers` sums the buffers, calls
`wait_for_read_buffer_async_ready(total_size, timeout)` —
which forwards verbatim to
`m_session->wait_for_read_async_ready(buffer_size, timeout)` —
then posts **one** `read_async` carrying all buffers, and
blocks on the completion callback (condition variable) up to
the same timeout. `TRANSFER_TIMEOUT` defaults to
**10,000 ms**. The write side is symmetric
(`wait_for_write_buffer_async_ready` → `write_buffer_async`).

## 3. R2b — the mechanism: ESTABLISHED; no wire signal exists

`hrpc/hailo_session.cpp` @pin dispatches `Session::connect` /
`SessionListener::create` on device type, and the tree holds
exactly three session realizations — **there is no separate
SoC session implementation in the public sources**: PCIe →
`RawPcieSession`, USB → `UsbSession`, and **ETH and INTEGRATED
→ `OsSession`** (a socket session; the integrated SoC device
takes the OS-socket path, server port 12133 per
rpc_connection.hpp). The receiver Aesir's Campaign 3 slices
traced is the pinned hrpc server; in the pinned sources that
server sits on this same session layer.

- **OsSession (the INTEGRATED path):** `wait_for_read_async_ready`
  and `wait_for_write_async_ready` **ignore `transfer_size`
  entirely** (the parameter is unnamed in both definitions)
  and delegate to `AsyncActionsThread::wait_for_enqueue_ready(timeout)`,
  which waits on a condition variable until the thread's local
  action queue holds fewer than its maximum capacity
  (`async_actions_thread.cpp` @pin). The posted action then
  performs one socket `recvall`/`sendall` of exactly the
  posted buffer sizes. **Readiness never leaves the process**:
  no ready byte, no size announcement, no handshake is sent
  to or awaited from the peer at this layer.
- **RawPcieSession (contrast):** its `wait_for_read_async_ready`
  *is* size-sensitive — it waits until the VDMA session's
  `is_read_ready(transfer_size)` holds. Two transports, two
  different local conditions, one shared interface: readiness
  is a per-transport local admission rule, **not a protocol**
  — there is no transport-independent signal for a study to
  find, and inferring the PCIe rule onto the SoC path (or vice
  versa) would violate the Do Not Infer table.
- **Where the size comes from:** the preceding RPC message.
  For the payload phase this is the action-2 message carrying
  `hef_size` (AES-PROG-004, receiver side: handler calls
  `read_buffer` of exactly that size between message and
  reply). Host side, `Client::execute_request_async_impl`
  @pin concatenates the request message and all write buffers
  into **one** `write_message_async` transfer — announcement
  and payload framing are the message itself; no chunking
  exists at this layer.
- **NOT PROVEN sub-part:** any maximum size for one async
  transfer, and any firmware-side acceptance rule *below* the
  public session layer. No cap appears in the searched
  session/connection sources (the 2048-byte `MAX_BODY_SIZE`
  caps RPC *messages* only — AES-NUM-004 finding F2, confirmed
  again here); OsSession posts one logical exact-size transfer
  of whatever size it is given. A cap inside the on-chip
  firmware, if one exists, is not in any public source and is
  recorded NOT PROVEN rather than inferred from the message
  cap or from PCIe behaviour.

**What this means for a future payload contract** (statement
of the sourced mechanism, not a contract): the host does not
wait for a device readiness signal before streaming a payload,
because none exists in the receiver's own stack; the receiver
posts its exact-size read when its handler reaches it, and
the stream carries the bytes. AES-NUM-003 layer 4 step 1's
gate — "specified but cannot yet be scheduled" — was premised
on an undiscovered signal; the signal's *absence* is now the
established fact, which is a different (and schedulable)
premise, still subject to a future slice's own contract and
gates before any physical step.

## 4. F1 — program-result readback: DESCRIBED at source level

The pinned client layer *does* describe result readback over
the RPC connection, in `hrpc/client.cpp` @pin:

- `Client::execute_request(action_id, request, write_buffers,
  read_buffers, timeout)` registers the caller's `read_buffers`
  against the outgoing message id before sending.
- The reply thread, on a reply whose header status is
  `HAILO_SUCCESS` **and** which has registered read buffers,
  calls `m_connection->read_buffers(std::move(read_buffers))`
  — the same wait-ready + single async read of §2 — **before**
  invoking the request's callback. On a non-success reply no
  buffer read is attempted.
- The production call site is the configured infer model:
  `ConfiguredInferModelHrpcClient` builds `write_buffers` from
  the input bindings and `read_buffers` from the **output**
  bindings (`get_read_buffers` iterates `m_output_names`) and
  passes both into its run paths — i.e. inference results
  return to the host as post-reply read buffers over this
  connection, in binding order, at sizes the host itself
  declared by registering the buffers.

So a program-result readback path exists and is fully
described at source level. **Qualification status in Aesir:
none.** No Aesir code has host-qualified this path against an
oracle and no physical attempt has exercised it; AES-NUM-004's
F1 therefore stands, narrowed from "no path is described" to
"the path is described (this slice) and unqualified (F1's
point)". Layer 7's wording is corrected accordingly in §5.

## 5. Re-grades and the 4.4 gate, changed layers only

Addendum to AES-NUM-003 (also appended to that document):

- **Layer 4 (data-movement plan):** step 1's blocking unknown
  is resolved at source level — the SoC session readiness
  protocol is ESTABLISHED (§2–§3: local queue admission; no
  wire signal; size from the preceding message; 10 s default
  connection timeout). Layer 4 re-grades from "SPECIFIED
  (host), NOT ESTABLISHED (device)" to **SPECIFIED (host),
  readiness ESTABLISHED (device, source level)**. The layer
  as a whole remains short of COMPLETE: step 2's device
  stream-binding semantics and step 4's device-internal
  movement are still unsourced, and no payload movement is
  physically proven (slice 3.3's single physical child remains
  the only payload-phase evidence, and it is negative).
- **Layer 7 (completion contract):** the F1 term is corrected
  to read: output is read back through the **source-described,
  Aesir-unqualified** result path (§4). No other layer-7 term
  changes; the path's qualification joins R4 (sequencing) as
  future work, it is not claimed here.
- **Gate re-run (4.4 terms, layers 4 and 7 only):** every new
  or changed statement above carries a pin-cited source and a
  known meaning, or is explicitly graded NOT PROVEN (the
  firmware-cap sub-part, §3). No Do Not Infer entry is
  violated: transport mechanisms are **not** cross-inferred
  (the PCIe/OsSession contrast is recorded precisely to forbid
  that), the 2048 message cap is **not** read as a transfer
  cap, and source-level establishment is **not** read as
  Aesir qualification or physical proof. **PASS on the changed
  layers.**

Unchanged and still blocking: layers 2/3/5/6 and layer 8's
device half (R1 NOT PROVEN; R3, R4, R5 open). **Campaign 4
EXIT still NOT MET; operation UNQUALIFIED; Campaign 5 NOT
contracted.**

## 6. R2 disposition and what remains

- **R2: ESTABLISHED** (interface + integrated-path mechanism,
  §2–§3), with the firmware-cap sub-part recorded **NOT
  PROVEN**. R2 closes under the 4.4 gate's terms (closes only
  on IN-grade evidence or recorded NOT PROVEN — here: both,
  per sub-question).
- **F1: answered** — readback path described at source level,
  unqualified in Aesir; layer 7 corrected by addendum (§5).
- Remaining Track R order: **R3 placement values** (slice
  4.7), R4 action sequencing (+ the §4 path's qualification
  question), R5 partial-state teardown.

## 7. Audit

Research only. No code, no emitter, no bytes constructed, no
physical child, no device contact. Sources: pinned HailoRT
files read at `d503417f…` via their public GitHub URLs (tree
listing via the public GitHub API); repo grep as in §1; one
bounded web query as in §1.
