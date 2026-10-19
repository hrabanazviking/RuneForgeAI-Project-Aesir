# Hailo-10H PCIe access census

**Roadmap Slice 011 — read-only device-access inventory (2026-10-12)**

## Observed facts

- Hailo-10H enumerates at PCI BDF `0001:01:00.0` and is bound to the kernel
  driver `hailo1x`.
- The negotiated PCIe link is 8.0 GT/s, one lane. The endpoint reports a
  maximum capability of 8.0 GT/s, four lanes; this host is currently using one
  lane.
- BAR resources are exposed through the bound kernel driver; their physical
  addresses are intentionally not copied into this summary.
- The running kernel config has `CONFIG_VFIO_PCI=y` and
  `CONFIG_UIO_PCI_GENERIC=m`.
- `/dev/vfio/vfio` exists, but the Hailo endpoint has no IOMMU group. No
  `/dev/vfio/<group>` for Hailo was observed.
- HailoRT can scan and identify the device through the currently bound Hailo
  driver. No `/dev/hailo*` node was present in this read-only check.

## Implications and limits

The present setup supports the installed Hailo stack, but it does not establish
that Æsir can safely take direct userspace ownership. VFIO's compiled kernel
support is not enough without an IOMMU group. UIO is compiled as a module, but
its availability, safe DMA model, interrupt behavior, and suitability for
Hailo-10H were not exercised. The device remains bound to `hailo1x`; it was not
unbound, reset, or rebound for this census.

The one-lane negotiated link is the current transport ceiling on this host,
even though the endpoint advertises four lanes. Measure actual workload impact
only after a permitted, verified Hailo inference path exists.

## Slice 011 acceptance

- BDF, driver binding, negotiated/max PCIe link, BAR presence, and kernel
  mechanism config are recorded from read-only host inspection.
- Missing IOMMU group is distinguished from general VFIO kernel support.
- No driver, device, firmware, or system configuration was changed.
- No CPU LLM work or fallback is proposed.
