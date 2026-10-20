# USERPTR mapping and cache-sync ABI

Date: 2026-10-19. Contract: `TASK_hailo10h_dma_storage.md` acceptance 1.

The independently authored Mojo codec and native byte inspector now encode
USERPTR map/unmap tuples and sync requests for the installed 5.3.0 driver.
The existing test-only C++ oracle includes the installed UAPI; no vendor
implementation or declarations are shipped in production.

| Object | Bytes | Packed fields |
|---|---:|---|
| USERPTR map/unmap | 32 | address 0/u64, size 8/u64, direction 16/u32, type 20/u32, returned handle 24/u64 |
| Cache sync | 28 | handle 0/u64, CPU/device selector 8/u32, offset 12/u64, count 20/u64 |

Map is `_IOWR('v',3,32)`, unmap `_IOR('v',4,32)`, sync `_IOR('v',5,28)`.
The oracle verifies these values. The currently admitted codec subset uses
USERPTR type 0 and explicit directions 1/2; other buffer mechanisms remain
future coverage, without changing the source-model objective.

Unmap uses the original tuple, as verified in the reference observation;
its output-handle slot is zero. Sync uses the returned mapping handle. Zero
handles are preserved; the all-ones sentinel is refused. A map reply must
preserve all 24 tuple bytes. Extent and sync bounds are checked using
subtraction to avoid unsigned wrap; empty extents/ranges are rejected.

## Verification

Native Mojo and installed-header C++ builds pass. Twelve test methods pass:
the previous session ABI suite plus 40 complete mapping/sync C-object byte
comparisons, reply identity/type/length/handle checks and boundary refusals.
All fifteen admitted ioctl values match the installed header. Evidence:
`evidence/dma-storage-2026-10-19/abi-tests.txt`, `build-abi.txt` and
`build-oracle.txt` in that directory. The toolchain reports existing unused
variable warnings; compilation and execution succeed.

This receipt proves byte representation and refusal behavior only. It opens
no device, pins no page and submits no DMA. Owned allocation/map/unmap,
completion cancellation, real RPC and source-model compute generation remain
separate gates under the same fixed goal.
