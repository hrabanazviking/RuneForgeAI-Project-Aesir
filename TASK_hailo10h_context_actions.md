# Public context-action byte primitive

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`; immutable source-model/Hailo goal.

Implement original Mojo value codecs for a small corroborated public context
switch action subset: configuration-descriptor fetch, CCW-burst fetch, default
LCU enable and typed data write. Cover the five-byte action header and only
these established packed bodies. Preserve full timestamp values. Validate field
ranges before narrowing and refuse other action IDs, truncation and trailing
bytes. Return owned value bytes; no source pointer or borrowed storage escapes.

Consumer: a native host inspector, followed by future SMIÐR program scheduling
when hardware placement, CCWs, operation encodings and a valid upload endpoint
are established. This codec is not the endpoint, a CCW generator or a numerical
operation. It must not gain a device/syscall import or be submitted through the
read-only device RPC tool. Do not parse/repackage a vendor model container.

Acceptance: compare all bytes, enum constants, packed sizes and offsets with a
small C++ test oracle using operator-supplied pinned public headers outside the
repository. Independently check bytes using Python struct fixtures; check
extreme/range/malformed input and ownership. Production is original Mojo, never
copied or translated implementation. No vendor header is shipped in this tree.
No device access, inference, reset, firmware or driver/binding change.

Interface facts/license hashes are recorded first in
`docs/HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`. The integrated-device host hRPC class
has no raw firmware-control implementation; a successful message exchange is
not permission to invent a raw-context hRPC action. Continue investigating the
configuration/activation endpoint and actual compute encoding toward the same
source-model execution target after this primitive is verified/published.
