# AES500-241 — socket ownership and shutdown contract

## Objective and owners

Define the lifecycle contract for the existing native Linux loopback service.
Primary owner is `aesir_engine/cli/native_serve.mojo::serve_loaded`, with
transport ownership in `aesir_engine/server/local_transport.mojo::OwnedFD`,
`listen_local`, `accept_local`, `accept_local_ready`, `receive_head`,
`receive_body` and `send_local`, and signal cancellation supplied by the CLI
entry point. This slice scopes ownership and cooperative shutdown; it does not
redesign the transport or expand compatibility APIs.

## Inputs and observable behavior

Inputs are a successfully loaded controlled text session, validated loopback
port, API key policy, request limits, queue bounds and a caller-owned
interruptible descriptor. On readiness, the service owns one listening socket,
at most one active client descriptor and no more than the configured number of
queued client descriptors. Requests are processed serially through one resident
inference session. Shutdown is signaled by the borrowed interrupt descriptor;
the service must not consume or close that descriptor.

## Lifecycle invariants

1. Listener creation binds only IPv4 `127.0.0.1`; failure before readiness
   releases every descriptor acquired by the listener setup path.
2. Every accepted client has one clear RAII owner. Moving between a pending
   queue and active request transfers ownership exactly once; queue removal,
   rejection, timeout, request failure and normal completion release it.
3. The listener is owned by the service call, and queued clients are owned by
   the service queue. The caller-owned interrupt descriptor is borrowed.
4. Poll/read/write loops use bounded deadlines and observe interruption;
   partial I/O, `EINTR`, disconnect and timeout remain explicit outcomes.
5. Cooperative SIGINT/SIGTERM stops admission and active generation at the
   generation-control boundary. Stack unwinding releases active client,
   queued clients and listener; the session owner then releases inference
   resources. A client may observe a closed connection during shutdown.
6. Shutdown does not promise cancellation of an in-flight GPU kernel before
   its current native cancellation boundary, nor does it alter signal ownership
   or masks borrowed from the CLI bootstrap.
7. Startup readiness follows successful model load and listener bind. A failed
   bind cannot be reported as ready.

## Exclusions

No daemon/supervisor lifecycle, remote bind, TLS, multi-session scheduling,
parallel generation, distributed shutdown, cross-platform POSIX abstraction,
hard GPU-kernel preemption, or guaranteed response delivery during shutdown is
promised. Existing legacy `BifrostGate` formatter/socket scaffolding is outside
the live service owner. Physical CUDA shutdown evidence is environment-specific
and must name the model, binary, device and observed signal path.

## Acceptance

Capture source/tool and prior evidence baseline; make owner/borrower and
success/failure semantics explicit in the server interface; inspect whether the
current code satisfies this contract before editing; run focused descriptor,
queue and request lifecycle unit/integration evidence, then the native service
shutdown harness when its required physical models/GPU are available. Record
environment and limits, reconcile the capability ledger and service guide,
run the master/build/doc gates, and push each slice with exact remote-SHA and
hosted-CI status checks. Primary review and independent reviewer availability
must be reported separately.
