# Chip-Executable Configuration Surface Survey (H019)

**Date:** 2026-10-10
**Sources:** clean-room studies H005 (`HAILO_PCIE_TRANSPORT_GUIDE.md`) and
H006 (`HAILO_HEF_CONTAINER_GUIDE.md`). Original prose; no copied structures.
**Purpose:** the requirements list SMIÐR's generator (C6) must satisfy
before emitting a single configuration byte.

A "configuration" here means everything the Hailo-10 needs, beyond the
transport itself, to execute one offloaded operation: what to compute, where
the data lives, in what order things happen, and how completion is reported.
The transport (mailbox/doorbell, VDMA rings, MSI) moves bits; the
configuration gives those bits meaning.

## Elements

### 1. Operation descriptors — MUST-HAVE

The per-operation control words that tell the compute array *what* to do:
opcode, operand widths, activation/quantization mode, and any per-operation
flags. Purpose: without these, the chip has data movement but no compute.

### 2. Tensor descriptors — MUST-HAVE

Shape, data type, memory layout (strides, padding), and quantization
parameters for every input, output, and intermediate tensor. Purpose: the
runtime needs exact buffer sizes and formats to program DMA and interpret
results bit-correctly.

### 3. Memory allocation directives — MUST-HAVE

Assignment of the operation's working set to on-chip SRAM regions plus the
layout of host-side DMA buffers per execution context. Purpose: prevents
on-chip memory collisions between concurrent dataflows; for the minimal
proof this can be one fixed arena.

### 4. Data-movement programs — MUST-HAVE

The VDMA descriptor sequences (source/destination addresses, lengths,
channel assignments across the 16 BAR2 channels) that ferry tensors
between host memory and on-chip SRAM. Purpose: compute without operands is
idle silicon; the studied transport shows all bulk transfer rides these
rings.

### 5. Scheduling and ordering primitives — MUST-HAVE

The execution order of operations/contexts, context-switch sequencing, and
dependency edges (what must complete before what starts). Purpose: out-of-order
execution against shared SRAM corrupts results; the schedule is what makes
a dataflow graph deterministic on hardware.

### 6. Completion signaling contract — MUST-HAVE

Which interrupt/status bit (or mailbox reply slot) means "operation done,"
and the exact acknowledgment sequence (e.g., read-and-clear of the BAR0
status register). Purpose: the host cannot safely read back results or
reuse buffers until it knows the chip finished, unambiguously.

### 7. Firmware handshake preamble — MUST-HAVE

The mailbox/doorbell exchange that hands a configuration to the on-chip
firmware and confirms acceptance before execution begins. Purpose: the
transport study shows configuration is *submitted* to firmware, not just
DMA'd — an unacknowledged configuration may never execute.

### 8. Error and timeout descriptors — LATER

Per-operation watchdog limits, fault-status decoding, and recovery actions
(retry, abort, reset channel). Purpose: needed for robustness and
self-healing, but the minimal vector-op proof can fail loudly instead.

### 9. Multi-context switching tables — LATER

The scheduler tables for interleaving multiple network groups/contexts on
the array. Purpose: required for full-model inference with many layers;
the minimal proof runs a single context.

### 10. Power and clock directives — LATER

Performance-state requests and clock-gating hints per operation phase.
Purpose: efficiency tuning; correctness does not depend on it.

### 11. Debug and trace descriptors — LATER

Instrumentation taps, performance counters, and trace-buffer layouts.
Purpose: invaluable for bring-up, but not part of a minimal executable
configuration.

### 12. Aesir's own versioned envelope — LATER (structural)

Target-architecture tag, SMIÐR format version, and a magic value that can
never be confused with a vendor HEF. Purpose: compatibility gating and
forward-evolution of SMIÐR's own format; the first proofs can use an
implicit version zero.

## Prioritized backlog for C6

**MUST-HAVE (minimal vector-op proof):** 1, 2, 3, 4, 5, 6, 7 — the chip
cannot execute anything useful without all seven. **LATER (full layers and
hardening):** 8, 9, 10, 11, 12.

The critical unknown remains *encoding*: the studies describe what each
element must express, not the bit layouts the silicon expects. Learning
those encodings without the proprietary dataflow compiler is the Phase-D
research assault (H101–H110); this survey defines what "learned" means per
element.
