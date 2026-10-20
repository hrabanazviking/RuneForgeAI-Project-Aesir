# AES500-251 — live request parser bounds contract

## Objective and owner

Define the bounded HTTP/1.1 request-head and body admission contract for the
native loopback service. Primary owners are
`server/local_transport.mojo::receive_head` and `receive_body`, followed by
`server/local_protocol.mojo::LocalHTTPHead` and its bounded flat JSON parsers.
This slice covers framing, limits, deadlines, and pre-inference rejection; it
does not expand API compatibility.

## Inputs and outputs

Inputs are a connected accepted socket, an absolute monotonic I/O deadline, a
borrowed cancellation descriptor, and for body reads the admitted nonnegative
content length. Head parsing returns only a complete bounded CRLF-terminated
header block; body parsing returns exactly the admitted number of bytes. The
protocol layer returns validated request metadata or a specific rejection
status before session reset/generation.

## Invariants

1. Request-line and headers are bounded to the documented 8 KiB head limit;
   overlong, incomplete, malformed-line-ending, duplicate/conflicting, or
   unsupported framing headers reject before body admission.
2. Content length is decimal, nonnegative, within the named request-body limit,
   and not combined with unsupported transfer encoding. The reader consumes
   exactly the declared byte count or fails closed on EOF/error.
3. One absolute I/O deadline covers head and body reception; partial reads do
   not reset it. Polling observes the borrowed interrupt descriptor and does
   not consume/close it.
4. Host, route, authorization, method, content type, JSON UTF-8, duplicate
   fields, string/number grammar, depth/schema, and per-field limits are
   checked before inference session reset. Untrusted request bytes never enter
   error text or logs.
5. Any rejection leaves model/session state untouched and the accepted socket
   remains under its one `OwnedFD` owner until response/close.
6. Unsupported pipelining, chunked input, keep-alive reuse, `Expect`, and
   unbounded request data stay explicit rejects.

## Exclusions

No complete RFC HTTP parser, arbitrary JSON, compression, multipart upload,
remote/TLS service, endpoint parity, or sustained-load guarantee is promised.
Physical CUDA request execution is not needed to establish parser admission;
separate physical service receipts remain separately scoped.

## Acceptance

Capture source/tool/pre-change admission outputs and hashes; add precise public
limit/error-order documentation; use focused accepted/rejected boundary and
mutation-free tests, then built-process integration where a model is not
required. Run malformed UTF-8, framing, integer overflow, oversized head/body,
partial deadline, disconnect, FIFO and cleanup checks; reconcile interface,
API matrix, ledger, TODO and devlog; run master, fresh build, docs checker, diff
checks, push each slice, and verify exact remote SHA plus directly observed
hosted CI state. Primary and independent reviewer availability are recorded
separately.
