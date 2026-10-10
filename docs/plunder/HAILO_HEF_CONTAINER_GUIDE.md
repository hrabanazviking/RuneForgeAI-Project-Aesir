# Hailo HEF Container Guide (clean-room study)

**Purpose:** Understand what a HEF contains so SMIÐR can generate an
equivalent from-scratch configuration. Per L3, Aesir will NEVER create,
read, parse, or require a HEF — this study exists to know what to replace,
not to use.
**Studied:** `HailoRT` (MIT) documentation + parser source — see
`CLEAN_ROOM_LOG.md` for the audit trail. No `.hef` file was downloaded,
opened, or parsed; a repo-wide scan confirms zero `.hef` files in the tree.
**Date:** 2026-10-10. **Studied by:** MIMISBRUNNR Campaign 1 worker.

> Original prose only. No format diagrams reproduced verbatim; no parser
> code copied. File names cited for re-verification.

## 1. What a HEF is, logically

A HEF ("Hailo Executable Format") is a serialized container — built on a
schema-definition language — that bundles everything a Hailo runtime needs
to run one compiled neural network. Logically it has six sections:

### 1.1 Header — compatibility gating

Names the target hardware architecture (an enum of chip families), the
creation timestamp, the SDK version that produced it (both as text and as
structured numbers), the container format version, and the minimum runtime
version that may load it. Purpose: the runtime refuses anything built for
the wrong chip or for a newer format than it understands.

Notable: the older Hailo-10H architecture slot in the enum is marked
deprecated; the 10H family is now classed under the HAILO1XH
architecture ID — consistent with the kernel driver naming its device
support `hailo1x`.

*Studied: `hailort/hailort/libhailort/hef.proto` (header message).*

### 1.2 Network groups — what runs, in what order

The unit of execution. Each network group carries a name, an
execution-order index, and a small computational graph: operation nodes
(each node is either a core operation for the Hailo compute array, a
non-maximum-suppression post-process, or a logits post-process) linked by
typed edges between named input/output pads. Alongside sits metadata: how
many compute operations the group holds, simulated latency and throughput
figures, and how many DMA channels are reserved for configuration.
Purpose: this is the *program structure* — which pieces run and how data
flows between them.

*Studied: `hailort/hailort/libhailort/hef.proto` (network-group message).*

### 1.3 Core-op configuration — the chip-executable payload

Per network group, the container holds a preliminary configuration plus a
list of *contexts*. A context is the actual hardware programming: the
scheduler tables, control words, and data-movement programs the chip's
sequencers execute. Groups are further broken into partial core-ops, each
with a physical layout describing how that piece maps onto the chip's
physical resources, plus metadata about fused layers and the ordered list
of output names. Purpose: **the contexts are the only thing the silicon
actually executes** — everything else is envelope. This section is the
heart of what SMIÐR must learn to emit.

*Studied: `hailort/hailort/libhailort/hef.proto` (core-op messages),
`hailort/hailort/libhailort/src/hef/hef.cpp` (how the parser walks
contexts per network group).*

### 1.4 Mapping blob — the packed compiler output

An opaque byte string carried next to the structured data. Purpose: the
compiled binary configuration in packed form — what the firmware consumes
directly, as opposed to the structured metadata the host runtime reads.

### 1.5 Feature flags and extensions — optional code paths

A set of boolean capability flags (posted writes, DDR usage, multi-context
execution, compressed parameters, hardware sequencer, padded buffers,
transpose handling) plus a typed extension list (NMS algorithm variants,
padding modes, batch register configuration, per-feature output scaling,
and similar). Purpose: tells the runtime which optional behaviors the
compiled payload relies on, so it enables exactly those code paths.

### 1.6 External resources — out-of-band blobs

Named binary blobs referenced by offset, size, and a content hash.
Purpose: large data (e.g., weight blobs) kept outside the structured
portion so it can be loaded efficiently without parsing.

## 2. What SMIÐR must generate INSTEAD of a HEF

Aesir never touches the HEF format (L3). The from-scratch configuration
path must therefore produce its own equivalents of the *functional*
content — the envelope will be Aesir's own, never HEF-shaped:

### 2.1 Hardware context blobs (MUST-HAVE)

The per-context scheduler/control-word streams that program the compute
array and its data movers. Rationale: the HEF's contexts are the sole
chip-executable content; the entire Phase-D research assault exists to
learn how to emit valid contexts without the proprietary dataflow
compiler. Nothing else SMIÐR generates matters if the contexts are wrong.

### 2.2 Tensor descriptors (MUST-HAVE)

Shape, data type, memory layout, and quantization parameters for every
input, output, and intermediate tensor of the offloaded operation.
Rationale: the runtime must know exact buffer sizes, formats, and padding
to program DMA transfers and interpret results; the HEF carries this as
metadata, so SMIÐR must derive it from the model graph itself.

### 2.3 Memory allocation plan (MUST-HAVE for the minimal proof)

On-chip SRAM assignment for the operation's working set and the layout of
any host-side DMA buffers per context. Rationale: the HEF ships a physical
layout per partial core-op; without an equivalent placement of its own,
SMIÐR's dataflow would collide in on-chip memory. For the minimal
vector-op proof this can be a single fixed arena; it grows into a real
allocator later.

### 2.4 Execution schedule (MUST-HAVE)

The order contexts execute in, context-switch sequencing, and the
completion-signaling contract (which interrupt/status bit means "done").
Rationale: the HEF's group indices, pad edges, and sorted outputs define
the dataflow order; SMIÐR must emit an equivalent schedule or operations
execute out of order and results are garbage.

### 2.5 Aesir's own versioned envelope (LATER, structural)

A small header declaring target architecture, SMIÐR format version, and a
distinct magic value that can never be confused with a HEF. Rationale: the
HEF header exists for compatibility gating, and any durable configuration
format needs the same — but L3 forbids HEF-shaped output, so the envelope
must be Aesir's own design from the start, even though it only becomes
load-bearing once configurations persist across runs.
