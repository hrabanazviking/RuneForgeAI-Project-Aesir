# F2 Partial-Acceleration Survey (H117)

**Date:** 2026-10-10
**Requires:** H111 = NO-GO.

## Verdict: no viable F2 interface found

F2 = "partial acceleration of whatever documented interfaces yield."
The C6 assault examined every documented interface for partial utility
short of full compute. None proved usable. Each candidate below lists
what it does, the evidence, and why it is rejected. No candidate is
claimed; therefore no microbenchmark is owed (per the acceptance
criteria, unclaimed candidates need none).

## Examined and rejected

### 1. Firmware mailbox (BAR4 + doorbell 0x1754)

- **What it does:** command submission to the on-chip firmware
  (control protocol: IDENTIFY and friends).
- **Evidence:** H102 — writes land readback-verified; firmware silent
  on both doorbell targets (app-CPU 0x1, core 0x2), 5 hardening
  variants, 5 s timeouts, vendor ioctl rejected.
- **Rejected:** a silent mailbox accelerates nothing. Without a
  response, there is no partial use.

### 2. VDMA descriptor-ring DMA engine (BAR2, 16 channels)

- **What it does:** per H005, descriptor-ring DMA between host memory
  and the device (page-size/control, addr lo/hi, remaining/status).
- **Evidence:** field set study-documented; chip-side byte layout and
  channel-programming sequence **uncorroborated** (BAR2 never
  programmed live).
- **Rejected:** two independent reasons. First, utility: F1 is a CPU
  engine — bulk transfer to a silent device's memory does not
  accelerate CPU inference. Second, safety: blind-programming a bus-
  mastering DMA engine with a guessed descriptor layout risks
  misdirected DMA writes against host memory; the exact programming
  sequence is unknown, so this is not a legitimate avenue. A future
  attempt with a responding firmware could revisit it.

### 3. MSI interrupt path (/dev/uio0)

- **What it does:** device-to-host signaling.
- **Evidence:** C5 received one genuine MSI (source unidentified —
  the expected SOFT_RESET bit never appeared in istatus).
- **Rejected:** an interrupt of unknown provenance is not an
  acceleration interface. Nothing to build on.

### 4. H103/H104 host-side artifacts (descriptors, SMIÐR-CFG v1)

- **What they do:** well-formed command descriptors and deterministic
  test-vector generation — on the host.
- **Evidence:** H103/H104 PASS, independently validated.
- **Rejected as F2:** they are CPU-side tooling, not acceleration.
  (They remain valuable as the F3 banked record and as the test
  harness any future firmware dialogue would use.)

### 5. Hailo-10 on-chip SRAM as scratchpad

- **What it would do:** fast staging memory for CPU inference.
- **Evidence:** none — SRAM access requires the firmware handshake
  (H019 element 7), which is the H102 failure.
- **Rejected:** no path to the SRAM without a responding firmware.

## What this means for F1

F1 proceeds as a pure-CPU engine with **no partial-acceleration
claims**. If a future campaign restores the firmware dialogue, this
survey is the starting point: the VDMA engine is the first interface
to re-examine, and the H103/H104 artifacts are the test harness.
