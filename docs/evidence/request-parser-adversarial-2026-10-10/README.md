# Request parser transport adversarial evidence — 2026-10-10

AES500-257 local evidence against source revision `6f3ae857077667f6e4f7518e90fd657c60acc197`.

`test_request_transport_adversarial` uses local Linux socketpairs and verifies:

- An 8192-byte unterminated head is rejected at the configured ceiling.
- A declared four-byte body whose peer sends two bytes and closes rejects as short EOF.
- NUL-containing body bytes reject before constructing a Mojo string.
- A 131073-byte requested body rejects before buffer allocation.

Focused transport module passes. The master suite reports 248 passed, 0 failed, 1 skipped (249 total), including `local_service.transport_adversarial`. Both doc drift scripts and `git diff --check` pass after the E-MASTER ledger update. Evidence covers parser/transport rejection only; it does not establish remote network or physical inference behavior.
