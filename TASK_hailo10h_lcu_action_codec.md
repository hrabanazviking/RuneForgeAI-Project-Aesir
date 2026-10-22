# Original nondefault LCU control action codec

Date:2026-10-22. Publish this contract before production edits. Parent:
TASK_hailo10h_numerical_encoding_sources.md. Public field qualification:
docs/HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md. Fixed broad ordinary
source-model/Hailo-only execution target remains unchanged.

Implement an isolated original Mojo smidr/lcu_actions.mojo with an owned scalar
LcuAction value:kind,timestamp,cluster,lcu,network,kernel_done_address,
kernel_done_count. All seven fields explicit. Add encode/decode/validate APIs
and a separate bounded host inspector. Preserve smidr/context_actions.mojo and
its old constructors, four accepted kinds, refused kinds and complete output.
No source-model eligibility restriction follows from this bounded subset.

Qualified kinds only4(nondefault enable),5(disable),36(batch switch). Exact
complete sizes13,6,11 bytes including action u8/timestamp u32 common header;
serialize little-endian public packed bodies. Cluster0..7,LCU0..15; reserved
packed bit7 must refuse on decode. Timestamp/count unsigned32,network unsigned8,
completion address unsigned16. All range/shape checks precede narrowing/access.
Disable's absent network/address/count must be exactlyzero; switch's absent
address must be exactlyzero. Kind4 explicitly carries address/count including
zero; do not replace it with default action3 or infer a safe physical address.
All records are wire intent, not a validity/placement/execution assertion.

Encode returns independent owned bytes; decode returns independent scalar state.
Reject unknown kind,wrong extent,truncated/trailing bytes,reserved bits,
noncanonical absent state and signed/width overflow. Maximum output13bytes;
no allocation based on numeric address/count. Native copy/mutation/refusal and
fresh-success probes exercise ownership and recovery. No module device/syscall,
HailoRT or model execution dependency and no physical request in this slice.

Acceptance uses separately compiled C++ object representations from hash-pinned
MIT public headers outside production, independent Python struct bytes, native
roundtrips and strict malformed/extreme/ownership checks. Cover every field,
all128 valid packed unit/cluster identities,bit7refusal,timestamp/count/address
boundaries and every truncated/excess extent. Freeze old action sources/tests/
binaries before edits; rebuild affected old native probes and compare complete
old accepted/error outputs. Never run historical master/E-REAL or host LLM oracle.
Record exact sources/binaries/inputs,clean compiler diagnostics,call counts and
consistency delta. Commit,publish,verify remote,FFmain and continue automatically.

Consumer is future original program/control generation once H10H numerical
encoding,placement and valid activation/result/cleanup are established. A host
codec cannot qualify arbitrary action upload or provide numerical instructions.
Continue actual physical configuration/CCW/transport research alongside the
remaining compiler work; no DFC/external compiler/machine/precompiled prerequisite.

## Verified serialization checkpoint

docs/HAILO10H_MOJO_LCU_ACTIONS.md records6 clean builds and17 methods/2113
primary calls,plus244 additional frozen comparisons. New456 vectors/492 refusals
and18 internal recovery cycles pass. This is host byte serialization only.
Continue TASK_hailo10h_numerical_encoding_sources.md toward actual physical
configuration/CCW/placement/transport fields; no guessed hardware request.
