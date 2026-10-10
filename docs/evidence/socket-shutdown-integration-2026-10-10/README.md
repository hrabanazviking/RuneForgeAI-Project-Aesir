# Socket shutdown integration evidence — 2026-10-10

AES500-245 integration evaluation at source revision `546768abdb13ac10c43281486f90484d2b52e87f`.

- Existing pure unit path: `local_service.fd_ownership` verifies descriptor transfer and one-time close via a nonblocking pipe.
- Existing native socket seam: master case `server.posix_socket` exercises listener setup/options; `server.http_parser` covers request routing/framing independently.
- Existing end-to-end path: `scripts/test_native_service.py` starts a real CLI service, verifies `/proc` loopback bind, authenticated request/replay, malformed/slow-client handling, generation deadline recovery, and sends SIGINT while generation is active before checking clean process exit and port release. See the historical raw receipt linked by the baseline at `docs/evidence/native-efficiency-2026-10-01/service-faults.txt`.
- No fresh physical model process was launched: the repository-local model is a zero-byte placeholder. Do not treat historical GPU evidence as a result against the current source SHA.

Integration evidence is therefore source/harness-path inspection plus local socket setup unit coverage for this slice; fresh physical active-shutdown remains environment-limited.
