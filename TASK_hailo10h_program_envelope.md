# Original owned program envelope construction

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_program_delivery.md`.
Scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Facts: `docs/HAILO10H_PROGRAM_INTEGRITY_FACTS.md` and
`docs/HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md`.

Connect the original header/layout codec and XXH3 window hash into an owned
version-3 outer-envelope constructor for the future original SMIÐR writer.
Accept borrowed protobuf, CCW and additional byte lists, an explicit zero-filled
padding count, explicit selected checksum domain and positive host output bound.
Check all UInt32/UInt64/Int extent arithmetic before allocation or mutation.
Return one independent owned byte list, with exact big endian lengths and
checksums. Compute both residue and protobuf hashes; in full-residue mode write
zero into the protobuf selector. In protobuf-only mode reject an unrepresentable
zero protobuf hash rather than silently changing the caller's mode. Check the
result through the original exact-extent/integrity validator. No supplied hash
may be trusted, and caller lists must not be mutated or retained.

Padding is a caller-owned serialization policy; an integer padding count does
not establish a hardware alignment rule. Arbitrary input protobuf/CCW bytes are
opaque at this boundary, not qualified executable metadata/instructions. The
constructor must never call a device, HailoRT, external compiler or hash runtime,
evaluate a model, or claim a complete executable program. Broad ordinary-model
support and the actual numerical configuration/placement/activation gaps remain
the target. This output is internal Aesir compiler work, not a special model
file requirement imposed on users.

Verify complete synthetic output against an independent big endian struct and
isolated licensed XXH3 test oracle, all empty/nonempty section combinations,
size-class/block transitions, exact/insufficient/zero bounds, padding positions,
selector behavior, byte-for-byte input preservation and independent output
ownership after input mutation/destruction. Preserve failed evidence, publish
verified narrow output construction and continue actual numerical compiler and
transport dependencies automatically.
