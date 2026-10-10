# Phase-A Gate Review (H010)

**Date:** 2026-10-10
**Scope:** H001–H009 (Campaign C1, Phase A: Recon & Spikes)
**Question:** Does the campaign have the understanding it needs to enter
Phase B, or does it halt?

## Slice verdicts

| Slice | Verdict | Evidence |
|-------|---------|----------|
| H001 — Mojo toolchain (native) | **GO / NATIVE-WORKS** | `docs/phase_a/MOJO_TOOLCHAIN_VERDICT.md`; Mojo 1.1.0 compiles and runs natively on Mimir via pixi shim |
| H002 — Cross-compile | **GO** | `docs/phase_a/CROSS_COMPILE_RECIPE.md`; aarch64 binary built on forge, runs on Mimir, bit-identical rebuilds (deterministic) |
| H003 — PCIe census | **GO** | `data/phase_a/pcie_census/`; Hailo-10 at 0001:01:00.0, 1e60:45c4, BARs mapped, Gen3 x1 |
| H004 — Mechanism verdict | **NO-GO** | `docs/phase_a/MECHANISM_VERDICT.md`; VFIO rejected (no IOMMU, no CONFIG_VFIO), uio_pci_generic rejected (not built), raw sysfs not selectable. Routes to F2/F3 |
| H005 — Transport study | **GO** | `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md`; BAR0/2/4 roles, MSI, doorbell, VDMA rings documented from clean-room study |
| H006 — HEF study | **GO** | `docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md`; HEF = protobuf container, SMIÐR requirements listed |
| H007 — NEON baseline | **GO** | `data/phase_a/neon_baseline.json`; 16.0 GFLOPS median, 0.0 max abs err (bit-exact) |
| H008 — Loader port check | **PARTIAL** | `data/phase_a/loader_port_check.json`; ARM64 GGUF parse byte-identical to x86_64. Blockers filed: GGUFSeer won't compile on Mojo 1.1.0 (InlineArray removed); Hladgerð has no implementation |
| H009 — Version pins | **GO** | `data/phase_a/VERSION_PINS.md` |

## Against the Phase-A go gate

The architecture's Phase-A go gate (roadmap line 124) requires four things:

1. **Mojo runs on the Pi 5 (natively or cross-compiled)** — PASS (H001, H002).
   Both paths proven with executables run on hardware.
2. **Hailo-10 BDF/BARs visible from userspace** — PASS (H003). Full census.
3. **One of VFIO/UIO/sysfs confirmed workable on Mimir's kernel** — FAIL
   (H004). None are viable; H004 verdicts NO-GO with measured blocking facts.
4. **Protocol map documented** — PASS (H005, H006). Transport + HEF guides.

Three of four pass. The failure is narrow and specific: the *userspace PCIe
driver mechanism*, not Mojo-on-Pi, not the recon itself.

## GATE VERDICT: GO-WITH-CONDITIONS

Phase A recon is complete and the campaign proceeds. The H004 NO-GO does
not void Phase A — it *is* Phase A's most important finding, and the
architecture pre-planned for it (F1/F2/F3). However, Phase B (HAILBRÚ
userspace driver, H061–H080) cannot execute as originally drawn on this
kernel. The following conditions gate specific downstream work:

**Condition 1 — Driver mechanism (gates H061).** Before any HAILBRÚ driver
slice runs, one of the following must be true: (a) Mimir's kernel is rebuilt
with `CONFIG_VFIO_PCI` (and IOMMU) or `CONFIG_UIO_PCI_GENERIC`, verified by
`/dev/vfio` or `/dev/uio*` appearing; or (b) the driver is re-scoped to the
F2 mechanism (partial acceleration via documented interfaces). Owner: H061
(or the kernel-rebuild slice, if one is cut). Until then, H061–H080 are
blocked; D1 ARMVEGR CPU work, studies, and F3 banking are not.

**Condition 2 — GGUFSeer 1.1.0 migration (gates loader-dependent slices).**
`aesir_engine/loader/gguf.mojo` must compile under Mojo 1.1.0 (replace the
removed `InlineArray`) before any slice that depends on GGUFSeer parsing.
Owner: the 1.1.0-migration slice (to be cut; not H008, which was port-check
only). Checkable: `mojo build` of the loader succeeds on both arches.

**Condition 3 — Hladgerð/safetensors scope (gates safetensors slices).**
The campaign must explicitly decide: implement a safetensors loader (new
work, possibly named Hladgerð) or defer safetensors support indefinitely.
Owner: campaign coordinator. Checkable: a decision recorded in the roadmap
or progress log. Until decided, no slice may assume safetensors parsing
exists.

## What is NOT blocked

- All D1 ARMVEGR pure-Mojo CPU engine work (H007 proves the baseline).
- Clean-room studies (H005/H006 done; H017/H018/H019 proceed).
- PRÓF test harnesses (H016).
- F3 deliverables (driver + protocol docs).
- The H111 compiler-wall gate and all Phase C–J planning.

## Risks carried forward

- **The Wall (H111):** the Hailo-10 configuration interface remains
  undocumented; H004's mechanism NO-GO compounds this. The F1 CPU-engine
  fallback is the campaign's guaranteed trunk.
- **Toolchain drift:** Mojo 1.1.0 removed `alias`, `InlineArray`, and
  changed `Pointer` semantics. The repo predates 1.1.0; further
  incompatibilities should be expected and migrated as a block, not
  per-slice.
