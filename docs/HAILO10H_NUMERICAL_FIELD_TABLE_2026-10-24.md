# Numerical interface — field table (2026-10-24)

Roadmap Campaign 4, slice 4.1 (AES-NUM-001). **Specification only.**
Every candidate device-program field gets a row: width, domain,
source, physical corroboration, allowed values, effect, unknowns,
and a verdict — **IN** (may enter PlacedIR/ContextIR) or **OUT**
(insufficient evidence; the field does not exist for the compiler
yet). Sources are pinned: HailoRT `d503417f2a0db186a838390fb08690c4ea0f415e`
(v5.3.0, MIT — interface facts only) and this repo's own qualified
evidence (AES-CONTROL-*, AES-TRANSFER-*, AES-PROG-*).

## A. Program container metadata (hef.proto)

| Field | Width | Source | Phys. | Allowed values | Effect | Unknowns | Verdict |
|---|---|---|---|---|---|---|---|
| Header hw-arch | enum | hef.proto @pin | no | HAILO1XH=103 for this target (HAILO10H=5 deprecated in both declarations) | Program target selection | Whether the receiver rejects other values on this profile | **IN** (metadata) |
| Runtime arch enum | enum | hailort.h @pin | n/a | HAILO_ARCH_HAILO10H=6 | Host-side identity only — **not** the program field; confusing the two namespaces is a recorded trap | — | **IN** (as a distinction) |
| CCW pointer action f1 offset | u64 | hef.proto @pin | no | Any u64 (container-relative) | References CCW bytes elsewhere in the container | Semantics of the referenced CCWs | **IN** (reference only) |
| CCW pointer action f2 size | u32 | hef.proto @pin | no | u32 | Length of referenced CCW region | — | **IN** (reference only) |
| CCW pointer action f3 config-channel index | u32 | hef.proto @pin | no | u32 | Selects configuration channel | Channel count/semantics on this target | **IN** (reference only) |
| CCW inline action f1 bytes | bytes | hef.proto @pin | no | opaque | Carries CCW bytes inline | CCW semantics | **IN** (carrier only) |
| CCW inline action f2 channel index | u32 | hef.proto @pin | no | u32 | As pointer f3 | As pointer f3 | **IN** (carrier only) |
| Partial-layout bitmap | u32 | hef.proto @pin | no | bitmap | Multi-layout selection — the multi-layout branch is selected only for HAILO8L/HAILO15M programs | Any Hailo-10H applicability | **OUT** for this target |
| Stream metadata (name/shape/format entries) | structured | hef.proto @pin; configure handler source (AES-PROG-004) | partial (names/formats are consumed by configure) | per schema | Binds program streams to configure params | Numeric format semantics (see E) | **IN** (structure) |

## B. Context-switch action records (context_switch_defs.h, packed)

Common form: action id u8 + timestamp u32 (initializer all-ones).
Aesir serialization owners already exist and are host-qualified
for part of this family (AES-CONTROL-001 LCU records,
AES-CONTROL-002 sequencer configuration/completion). **Layout IN;
every row's safe *values* remain bounded by its Unknowns.**

| Field | Width | Source | Phys. | Allowed values | Effect | Unknowns | Verdict |
|---|---|---|---|---|---|---|---|
| Action id | u8 | context_switch_defs.h @pin | no | Published enum ids | Selects the record kind | Ids beyond the published subset | **IN** (layout) |
| Timestamp | u32 | context_switch_defs.h @pin | no | Initializer all-ones in public construction | Sequencing metadata | Runtime semantics | **IN** (layout) |
| ID 0 descriptor fetch: count | u16 | context_switch_defs.h @pin | no | u16 | Descriptor fetch size | Safe counts for a real program | **IN** (layout) |
| ID 0 descriptor fetch: packed channel | u8 (6 bits channel + 2 bits engine) | context_switch_defs.h @pin | no | bit fields | Channel/engine selection | This machine's channel/engine counts | **IN** (layout) |
| ID 3 default LCU enable: packed LCU | u8 (4 bits unit + 3 bits cluster, bit7 reserved) | context_switch_defs.h @pin | no | bit fields | Enables default LCU set | Actual unit/cluster counts; which LCUs a program may claim | **IN** (layout) |
| ID 3: network | u8 | context_switch_defs.h @pin | no | u8 | Network selection | Valid network indices | **IN** (layout) |
| ID 4 nondefault LCU enable (13 B total): packed LCU + network + completion-address u16 + completion-count u32 | mixed | context_switch_defs.h @pin (LCU boundary study 2026-10-22) | no | per field | Enables a named LCU with completion reporting | Completion address space | **IN** (layout) |
| ID 5 LCU disable (6 B): packed LCU | u8 | context_switch_defs.h @pin | no | bit fields | Disables an LCU | — | **IN** (layout) |
| ID 27 CCW-burst fetch: bursts u16 + stream byte | mixed | context_switch_defs.h @pin | no | u16 + u8 | Fetches CCW bursts for a stream | Burst semantics vs CCW layout | **IN** (layout) |
| ID 35 typed data write: address u32, type byte, data u32, shift byte, mask u32, network byte | mixed | context_switch_defs.h @pin | no | per field; type distinguishes general/batch | Writes a typed value at an address | **Address/register meaning — none established. No safe address exists in evidence.** | **IN** (layout); **every address value OUT** |
| ID 36 batch switch (11 B): packed LCU + network + completion-count u32 | mixed | context_switch_defs.h @pin | no | per field | Switches batch context on an LCU | — | **IN** (layout) |
| Control-protocol chunk markers (context kinds: preliminary/dynamic/batch-switch/activation; first/last chunk; type/length/data) | structured | control_protocol.h @pin | no | per protocol | Chunks context delivery | Relation of chunks to the read_buffer phase (Campaign 3 gate) | **IN** (container fact) |

## C. Config buffer units

| Field | Width | Source | Phys. | Allowed values | Effect | Unknowns | Verdict |
|---|---|---|---|---|---|---|---|
| CCW header unit | 8 bytes | config_buffer sources @pin (public-actions study) | no | — | Heads a CCW region | Bit layout of the header itself | **IN** (existence/unit only) |
| NOP padding unit | 8 bytes, all zero | config_buffer sources @pin | no | all-zero | Padding between CCW data | — | **IN** |
| CCW words | — | — | no | — | The arithmetic configuration itself | **Everything: opcode layout, register addresses, operand encoding. No public definition was found (delivery-boundary study: bounded search, not proof of absence).** | **OUT** |

## D. Transport / control fields (physically corroborated)

| Field | Width | Source | Phys. | Allowed values | Effect | Unknowns | Verdict |
|---|---|---|---|---|---|---|---|
| HRPC frame magic/length/id/action/status | 5×u32 | rpc.proto + AES-CONTROL-015..018, AES-TRANSFER-004, AES-PROG-003 | **yes** | status: request 1, reply 0 | RPC framing | — | **IN** |
| Action numbers 20/22/21 (device), 2/4/3/5/10/11/12 (program) | u32 | serializer.hpp @pin | 20 yes; 2 metadata launched (B2) | published enum only | Lifecycle verbs | Program actions' physical completion (Campaign 3 gate) | **IN** |
| Descriptor page size for grouped spans | 512 (policy) | kernel diagnostic + AES-CONTROL-016/017/018 | **yes** | descriptor pages of 512 on this profile | Span admission | Other profiles | **IN** |
| Span offset page-divisibility | rule | AES-CONTROL-016 (EINVAL at 20) / 018 (0,512 admitted) | **yes** | offsets divisible by the descriptor page | USERPTR span admission | — | **IN** |
| Launch return = descriptor count | integer | AES-TRANSFER-001 S2; -004/-003 physical | **yes** | observed-return policy 1 ≤ n < 65536 | Admission evidence | Per-span vs contiguous formula (recorded consistent-not-proven) | **IN** |
| IRQ completion record data | u8 per channel record | pinned UAPI + -018 decode + -004 | **yes** (1 = completed observed; 0xFF = NOT_ACTIVE observed in -018) | 1 completed; 0 none yet; 0xFE channel error; 0xFF not active | Completion law | — | **IN** |

## E. Numerical semantics — the missing bridge (all OUT)

| Candidate field | Status |
|---|---|
| Quantization scale / zero-point encoding per tensor | **OUT** — no public field definition with a known meaning in the pinned sources |
| Accumulator width, rounding mode, saturation behavior | **OUT** — not established anywhere in evidence |
| Tile dimensions / tiling order for any operation | **OUT** |
| Cluster / subcluster / APU assignment values for a real program | **OUT** — widths exist (B), counts and safe values do not |
| Local-memory bank/window assignment, L2/L3 offsets | **OUT** |
| Kernel weight layout / packing order | **OUT** |
| CCW encoding of any arithmetic operation | **OUT** — see C, CCW words |

## What this table buys (and what it does not)

Slice 4.2 may select the first operation **by evidence strength**
from groups A/B/D (structure and control), knowing in advance that
its layer (5) static configuration and layer (6) dynamic actions
will be only as strong as rows B/C allow, and its numerical
definition (layer 1) cannot borrow anything from group E — the
operation's arithmetic must be defined by Aesir and checked
against an independent oracle, while the *device's* encoding of
that arithmetic remains the open research problem (Track R +
Campaign 5's encoder gate). No row in this table, alone or
combined, yet describes a complete operation: that is 4.3's test,
and the table predicts — honestly, in advance — that **no
operation can clear all eight layers until at least the CCW word
layout (C) or an equivalent device-consumed encoding is
established**. Campaign 4's iteration loop (research until one
operation clears) is therefore expected to run through Track R's
connection-layer and CCW studies, not around them.

## Track R addendum — the connection layer (same study pass)

`hailort/hrpc/rpc_connection.cpp` at the same pin (MIT) narrows
the AES-PROG-004 unknown one layer further:

- **ESTABLISHED:** RPC *messages* are capped at a 2048-byte body
  (`MAX_BODY_SIZE`, matching the repository's own codec law);
  *buffers* are a separate mechanism. `read_buffer` becomes
  `read_buffers`: the receiver first calls the session's
  `wait_for_read_async_ready(total_size, timeout)`, then posts
  **one async session read of the total declared size** and waits
  for its completion callback. The payload phase is therefore a
  single logical transfer of exactly `hef_size`, not a series of
  RPC messages.
- **STILL NOT ESTABLISHED:** the session layer underneath —
  how readiness is signaled between host and receiver on the SoC
  RPC engine, the maximum size of one async transfer, and how a
  host-side writer must chunk/announce a large buffer. The pinned
  connection code is written against a session abstraction
  (PCIe session in-tree); the SoC session's readiness protocol is
  the remaining study target before any payload contract.
