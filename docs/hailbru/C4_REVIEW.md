# Campaign 4 Review — HAILBRÚ Driver (H061–H080)

**Verdict: NOT-READY for Phase C.** The driver is real, probed on hardware,
and fail-closed where the kernel forbids. Phase C (inference) needs the
F3-unblocked kernel.

## Sólrún audit decision (recorded in MIMISBRUNNR_PROGRESS.md)

Route (b) per Volmarr's directive: implement HAILBRÚ as far as the current
kernel honestly allows; VFIO/UIO-dependent slices F3-banked with exact
prerequisites. Route (a) kernel rebuild is off the table — operator action,
Volmarr's hands-only decision.

## Slice checklist

| Slice | Status | Evidence |
|-------|--------|----------|
| H061 discovery | DONE (real) | `discover` → 0001:01:00.0 on Mimir |
| H062 identity | DONE (real) | 1e60:45c4, MSI cap 0xE0, no MSI-X |
| H063 BARs | DONE (real) | BAR0/2/4 table on Mimir |
| H064 VFIO probe | DONE (fail-closed) | `MechanismUnavailable`, H012 cited |
| H065 UIO path | DONE (fail-closed) | `MechanismUnavailable`, H013 cited; bind steps gated |
| H066/H067 DMA | DONE (re-scoped) | CPU alloc/mlock real; IOMMU F3-banked |
| H068 registers | DONE (re-scoped) | 50/50 coherency reads 0x1e60 on live device; writes forbidden per H005 §6 |
| H069/H070 IRQ | DONE (re-scoped) | eventfd/ppoll real (10000/10000); device MSI-X F3-banked |
| H071 link/caps | DONE (real) | Gen3 x1, PM cap 0xF8, D3hot/D0 probed |
| H072 reg doc | DONE | `docs/plunder/HAILO_FW_LOAD_REGISTERS.md` (study-accurate; corrected BAR0 0x0600/0x0700 mislabels) |
| H073 fwcheck | DONE (real) | 17 blobs, 112MB, pure-Mojo SHA-256; found H014 catalogue corruption |
| H074/H075/H076 boot | F3-BANKED | Chunk planner + pollers real & self-tested; DMA/IRQ halves need F3 |
| H077 gate | DONE | `docs/hailbru/PHASE_B_GATE.md` — honest NO-GO |
| H078 tests | DONE | 28 error-path tests, x86_64 + aarch64 green |
| H079 API | DONE | `hailbru/API.md` + compile-time surface test |
| H080 review | DONE | this document + `F3_UNBLOCK_RUNBOOK.md` |

## API table

See `hailbru/API.md` for the frozen surface (discovery, identity, BARs,
mechanism, VFIO/UIO, DMA, registers, IRQ, firmware). Downstream: VÖRÐR (D6),
SMIÐR (D3).

## L12 verification

```
$ grep -rln "/dev/vfio\|/dev/uio\|sys/bus/pci\|resource0\|VFIO_\|UIO_" \
    --include="*.mojo" . | grep -v "^./hailbru/"
./spikes/phase_a/posix_baseline.mojo
```

The single hit is a Campaign 1–3 Phase-A spike reading a sysfs vendor text
file (read-only discovery, predates hailbru; not a /dev node, BAR mmap, or
ioctl). **No shipped domain outside `hailbru/` touches device nodes.**
`grep -ri "matmul\|softmax\|tensor" hailbru/` returns empty — no
model-semantics code in the driver.

## Key measured numbers

- Vendor mirror: 50/50 reads → 0x1e60 (live device, D0)
- IRQ status at rest: 0x00800000; mask 0x00000000; channel bitmaps 0
- Firmware: 17 blobs / 112,287,372 bytes SHA-256-verified
- Tests: 28/28 error-path (x86_64), 28/28 (aarch64); 11 CLI selftests green
- D3hot→D0 via PM-control 0xFC←0x2008; restored to 0x200b after probing

## What Phase C needs

The F3 runbook (`docs/hailbru/F3_UNBLOCK_RUNBOOK.md`): kernel rebuild with
CONFIG_VFIO, CONFIG_UIO_PCI_GENERIC, CONFIG_ARM_SMMU (operator action),
then F3-1 (IOMMU DMA) → F3-3 (MSI) → F3-4 (firmware boot). Zero re-research.
