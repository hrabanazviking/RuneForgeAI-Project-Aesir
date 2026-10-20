# Public structure facts for Aesir-generated programs

Date: 2026-10-20. Parent: `TASK_hailo10h_program_delivery.md`.
Study under the already-read HailoRT MIT license at frozen revision
`d503417f2a0db186a838390fb08690c4ea0f415e`. Interface/data-format facts only;
no external implementation is copied/translated. No vendor compiled artifact
is opened or extracted. Provenance is recorded in
`docs/evidence/program-structure-study-2026-10-20/`.

## Architecture namespaces are distinct

The public container schema's hardware enum assigns HAILO1XH 103; its old
HAILO10H entry 5 is commented deprecated. Container value 6 means HAILO15L.
The device API's HAILO10H identifier is 6 in a separate enum namespace. A
numeric cast from device identity to container architecture would select the
wrong target. The pinned DeviceBase compatibility declaration maps HAILO1XH,
GINGER and LAVENDER family targets to Hailo15H/Hailo10H; HAILO15M also admits
Hailo10H in that coarse map. These are runtime family-compatibility facts,
not proof of resource layout or acceptance of any generated numerical program.
No target is selected by this study, and the owner's hardware goal is fixed.

## Outer header and section boundaries

The public packed header has a 12-byte common prefix: magic/u32 at 0,
format version/u32 at 4, protobuf byte count/u32 at 8. The numeric magic is
0x01484546; these fields use big-endian byte order. This differs from hRPC's
little-endian envelope. Published header sizes are 32/28/44/56 bytes for outer
versions 0/1/2/3 respectively. The public parser handles each version distinctly.

For an incremental version-3 writer/descriptor, the remaining fields are:

| Offset | Width | Meaning / representation |
|---|---|---|
| 12 | 8 | residue XXH3-64 field, big-endian integer |
| 20 | 8 | CCW section byte count including preceding alignment padding, big-endian |
| 28 | 4 | padding byte count, big-endian |
| 32 | 8 | additional-information section byte count, big-endian |
| 40 | 8 | protobuf XXH3-64 field, big-endian |
| 48 | 8 | reserved bytes; an original emitter must supply zeros |

Let N be protobuf bytes, W CCW bytes including padding, P padding and A
additional-info bytes. Header size H=56. Regions are protobuf `[H,H+N)`,
padding `[H+N,H+N+P)`, CCWs `[H+N+P,H+N+W)` and additional information
`[H+N+W,H+N+W+A)`. Require P≤W and checked sums; total H+N+W+A must match any
later actual owned buffer. Pointer-action offsets are resolved using the CCW
origin H+N+P, not file offset zero. Padding/alignment rules and checksum scopes
must be separately earned before a complete writer is admitted. An integer
hash field is data; retaining it does not validate a checksum. The public
version-3 parser can validate a nonzero protobuf hash separately and defer
remaining checks, so a header-only codec must never claim payload integrity.

## Metadata and configuration are further compiler output

The protobuf root has header/target information and repeated network groups,
extensions/features and external-resource references. Network groups contain
typed core subgraphs/pads/edges; core operations have preliminary configuration
and contexts. Each context operation has a trigger and actions. The public
core-op schema does not directly encode the source graph's linear/RMSNorm/
SiLU/softmax operation recipes as numerical instructions.

Required metadata additionally includes network/context identities, config
channel/engine bindings, stream ordering/directions, actual/padded shapes,
device data representation, buffer sizing/resource indices, context-switch
connections and numerical quantization data. CCW pointer/inline actions carry
opaque payload references/bytes, as recorded in the delivery boundary. Exact
register meanings, arithmetic control bit fields, physical geometry and a
placed first-operation schedule remain missing from the inspected structures.
Source semantic shapes or hypothetical storage widths cannot fill these with
guesses. Existing SMIDR-CFG and COMPUTE_UNKNOWN remain non-executable.

## Concrete next slice

Implement an original host-only version-3 header value codec and checked
section-layout arithmetic under `TASK_hailo10h_program_header.md`, using only
these facts and synthetic bytes. It is an output-builder primitive, with no
file parser, model read, full-container emission, checksum validation or
device submission. Continue bounded public register/CCW/placement research
alongside this format work. All actual numerical configuration, source-model
execution and first hardware result/cleanup gates stay open.

Primary sources:
[public packed header declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/hef/hef_internal.hpp),
[header byte-order/section interface](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/hef/hef.cpp),
[program metadata schema](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/hef.proto),
[coarse target compatibility](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/device_common/device_internal.cpp).
