# AES500-261 — HTTP framing rejection contract

## Objective and owner

Specify fail-closed framing rules at the live HTTP/1.1 boundary. Primary owner
is `server/local_protocol.mojo::LocalHTTPHead`; transport entry points are
`receive_head` and `receive_body`. The contract covers request-line/header
syntax, duplicate and ambiguous framing fields, methods and the declared body
length. JSON field/schema behavior is covered separately by the API v1 matrix.

## Inputs and outputs

Input is one complete CRLFCRLF-terminated header block, configured local port,
expected bearer key and authentication policy. Output is the accepted
`LocalHTTPHead` with method/path/auth/content length/status, or an explicit
parse failure / HTTP rejection status. The caller may read a body only after
the head has passed the mode's status checks.

## Invariants

1. Require exactly three request-line tokens and HTTP/1.1; reject empty or
ambiguous whitespace forms, unsupported bytes, bare CR/LF and malformed lines.
2. Header names are nonempty ASCII letters/digits/hyphen; duplicates reject
case-insensitively. Values are bounded and cannot inject CR/LF.
3. Reject `Transfer-Encoding` and `Expect`; do not allow request smuggling
through combined Content-Length/Transfer-Encoding or repeated lengths.
4. POST requires one decimal Content-Length in 1..131072 and exact
`application/json`; GET rejects nonzero body length. Other methods return 405.
5. Wrong Host and browser Origin/Referer/Sec-Fetch-Site are forbidden; required
authentication failure is 401. Error responses do not echo raw request bytes.
6. Incomplete/oversized heads and premature body EOF fail closed before
session reset, while cancellation/deadline remains observable.

## Exclusions

No HTTP/2, chunked upload, trailers, compression, proxy forwarding, URL
normalization compatibility guarantee, complete RFC grammar, or arbitrary
third-party client compatibility is claimed. This is local native service
admission only.

## Acceptance

Record the exact pre-change rule/response matrix; make the framing contract
explicit in the public server/API docs; test duplicate/case-variant headers,
conflicting framing, malformed request lines, bare line endings, unsupported
methods, exact body lengths, and authorization/Host rejection. Verify no body
read/session mutation follows a rejected head using socketpair or built-process
evidence. Run focused/master/doc/build gates and publish exact revision, scope,
remote SHA and hosted CI status.
