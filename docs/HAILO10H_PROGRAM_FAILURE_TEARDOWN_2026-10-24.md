# Program lifecycle — failure teardown accounting + payload-phase source study (2026-10-24)

Roadmap Campaign 3, slice 3.4 (AES-PROG-004), with the Track R
companion study the AES-PROG-003 write-up called for. Host-side
contracts and source specification only — **no physical run** in
this slice.

## Part 1 — Partial-creation failure accounting (host-qualified)

`smidr/tools/program_mock.mojo` gained `fail-at-<stage>` scenarios
(a sequential runner stops at the first failing stage; later stages
are never attempted, per the poison law), and the suite
(`tests/test_hailo_program_mock.py`, on Mimir) grew tests 09–10.
**Result: 10 tests OK, 148 runs, zero physical calls** (the full
AES-PROG-002 battery included).

For every stage, corrupting that stage's reply (status 7) produces
exactly the designed accounting — the owner stops, poisons, and
prints its residue tier:

| Failing stage | Stages done | Exchanges | Residue (server-side, by tier) |
|---|---|---|---|
| create | 0 | 1 | infer object possibly created, **handle never learned** |
| configure | 1 | 2 | infer handle known |
| activate | 2 | 3 | configured + infer known |
| deactivate | 3 | 4 | configured + infer known |
| shutdown | 4 | 5 | configured + infer known |
| destroy-configured | 5 | 6 | configured + infer known |
| destroy-infer | 6 | 7 | infer known only (configured destroyed) |

A transport-level failure at create (launch fault) accounts as
0 stages / 0 completed exchanges, poisoned. Two design facts this
locks in:

- **The create-failure residue is the worst class**: if the
  receiver created the object but its reply was corrupted, the
  handle exists server-side and was never learned. No client-side
  accounting can name it. (See Part 2 for what the receiver does
  with such residue.)
- **Recovery-by-adoption is NOT implemented, deliberately.** A
  fresh `SocProgram` cannot adopt a handle learned by a poisoned
  owner: whether handles are valid across sessions/connections is
  unestablished, and inventing adoption would fabricate a recovery
  guarantee. Known-tier residue is recorded for a future contract
  to address explicitly.

## Part 2 — Track R: the receiver's read path (pinned sources)

Studied: `hailort_server.cpp` at the pinned HailoRT revision
`d503417f2a0db186a838390fb08690c4ea0f415e` (MIT), the receiver
implementations behind the delivery boundary study. Facts, each
with what it does and does not prove:

- **ESTABLISHED — the payload phase's shape.**
  `VDeviceCreateInferModelHandler::parse_request` deserializes the
  action-2 metadata (vdevice handle, hef_size, name), then calls
  `client_connection->read_buffer(m_hef_buffer, LONG_RPC_ACTION_TIMEOUT)`
  for **exactly hef_size bytes**, and only then does `do_action`
  run `vdevice->create_infer_model(...)` and write the reply. The
  phase is a **raw connection-level read of exactly the declared
  size, between the metadata request and the reply** — which is
  precisely the behavior AES-PROG-003 observed physically as B2
  (no reply to metadata alone). It does NOT by itself establish
  how a connection read is realized on the SoC VDMA transport
  (what the host must launch, in what chunks) — that is the
  connection layer's business, the next study step.
- **ESTABLISHED — destroy-configured includes shutdown.**
  `handle_configured_infer_model_destroy` calls the configured
  object's `shutdown()` itself, cleans its buffer pools, releases
  the resource, then replies. The AES-PROG-001 Q6 precondition
  question is therefore answered at source level for this pair:
  **the receiver does not require a prior explicit shutdown**
  (our owner's conservative client-side order remains safe and is
  retained — it costs nothing and stays valid if a different
  receiver build differs).
- **ESTABLISHED — disconnect cleanup.** `cleanup_client_resources`
  releases **all** of a client's server-side resources (configured
  models, infer models, infer-model infos, vdevice) when the
  client connection is cleaned up. Source-level consequence for
  the recorded residue class (AES-CONTROL-018, AES-TRANSFER-004,
  AES-PROG-003): those handles are the *connection's* resources;
  what event on the SoC transport constitutes the client cleanup
  for our sessions is NOT established by this source alone, so
  the residue record stands as written — but there is now a
  named, source-backed mechanism by which such residue is
  reclaimed, and no basis for treating it as permanent leakage.
- **Consistent — configure.** The action-4 handler applies stream
  formats, batch, power mode, latency flags and KV-cache from the
  request, calls `configure()`, allocates DMA buffer pools, and
  replies with the configured id + async queue size — matching
  AES-PROG-001 Q5 exactly.

## NOT ESTABLISHED (updated)

- The SoC connection layer's realization of `read_buffer` /
  `write_buffer` (chunk sizes, transfer pairing, who launches) —
  the next Track R step, in the pinned `hrpc` connection sources.
  Only when that is specified may a successor to the 3.3 contract
  admit sending the staged two-part payload.
- Whether our sessions' termination triggers the server's client
  cleanup on this transport.
- Everything numerical, as ever. Campaign 3's exit remains
  unmet: no program object has been created on the device.
