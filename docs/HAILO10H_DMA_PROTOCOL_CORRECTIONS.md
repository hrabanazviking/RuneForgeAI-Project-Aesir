# Mojo request status and transfer-result corrections

Completed 2026-10-19 under `TASK_hailo10h_dma_observation.md`, following the
published physical reference facts at `7359ad3`. No target or model-scope
change is made.

`hailbru/hrpc_device.mojo` now emits request status 1 (`HAILO_UNINITIALIZED`)
for create/identify/destroy. Successful replies still require status 0. The
previous host-only implementation emitted request status 0; observation of
the installed reference established 1. Its historical host-test receipts
remain dated evidence, not physical exchange proof.

`hailbru/soc_driver.mojo` now returns the raw nonnegative ioctl result as
`Int64`. Negative results use captured errno and raise `SocIoctlFailed`.
Positive results are admitted only for transfer launch; unexpected positives
from other admitted operations raise `SocDriverMismatch`. The observed count
5 is preserved instead of being rejected as an error. The future ring owner
must validate that count against its own submission/list; preserving a raw
zero or other positive value does not certify that any work completed.

## Verification

All six native builds pass. The native create request with message ID 0
matches the independently observed reference's full 20-byte create header
exactly. Ten independent protobuf-backed methods pass with request status 1
and reply status 0, retaining zero handles, bounds, error and correlation
coverage. The direct production-handler consumer checks seven assertions:
actual positive count 5, raw nonnegative results, stale errno independence,
and negative/unexpected result refusal. It performs no device access.

Fresh rebuilt driver-owner tests pass 11/11 on this Pi, and rebuilt connection
lifecycle tests pass 7/7, including all six prior lifecycle error injections,
ordered cleanup, exception unwinding and fresh reconnection. These exercise
the updated shared method without submitting a user DMA buffer or message.

```sh
mojo build -I . smidr/tools/hrpc_device.mojo -o work/hrpc-device
python3 tests/test_hailo_hrpc_device.py --binary work/hrpc-device -v
mojo build -I . tests/hailo_soc_result_api.mojo -o work/soc-result-api
work/soc-result-api
```

Physical owner/lifecycle recipes are documented in
`HAILO10H_MOJO_DRIVER_OWNER.md` and `HAILO10H_MOJO_SESSION_LIFECYCLE.md`.
[Receipt and source/binary hashes](evidence/dma-protocol-corrections-2026-10-19/receipt.json)
include raw build/test output and actual header comparison. No independent
Mojo remote RPC or source-model execution is claimed. Next: owned
map/unmap/sync storage and bounded interrupt-wait/cancellation proof before
the first typed physical Mojo exchange.
