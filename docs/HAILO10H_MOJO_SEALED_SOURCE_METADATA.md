# Original Mojo owned sealed config and index metadata

Date: 2026-10-23. Pre-code contract:
`TASK_hailo10h_sealed_source_metadata.md`, published at06c7158.
Controlling owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Evidence: `evidence/sealed-metadata-native-2026-10-23/`.

## Implemented boundary

New `smidr/sealed_source_metadata.mojo` retains a movable SealedSourceBytes with
an existing SourceConfiguration or SourceShardIndex. Explicit close delegates to
the byte owner; field destruction handles exceptions and moves. The consuming
parsers check the actual host, seals and regular-file extent, recompute the full
actual digest, ignore the writable claimed digest, and borrow the same owner to
ONE existing regular-byte helper and ONE existing config/index parser. Original
path descriptors close before parsing. No existing production module changes.

The borrowed helper checks a positive explicit bound before allocation, retains
8192-byte requests and one EOF lookahead, and rechecks actual seals/extent after
reading. Hash/copy stages retain their separate4096-byte requests and explicit
permits. Metadata reads make progress or refuse within source_bytes+1 calls;
negative results are refused without retry. Parsed raw values and copied byte
lists survive close; fresh reads after close refuse. Labels are diagnostic only.
No duplicate fd owner, mapping, label reopen, JSON algorithm copy or external
parser/compiler/runtime is added. All production OS effects use existing HAILBRU.

## Native acceptance

| Receipt | Actual result |
|---|---|
| Old source / Python continuity | All666 old Mojo sources and71 Python inputs unchanged |
| Pre-code native controls |117 immutable controls verified; no claim that all were rebuilt in this slice |
| Real new-leaf consumer closure |Only the new inspector and test API; no old importer |
| Stable builds before acceptance |Eight zero-diagnostic Mojo builds: six selected old entries and two new; four clean C test shims |
| Final suites / methods |Four /27, all pass |
| Qualified entry calls |1268:1189 current and79 explicit frozen calls; paired controls additional |
| Complete frozen comparisons |892 across all six selected controls:390 success /502 refusal |
| Mutation / independent fault-log pairs |Four /40; complete stdout, stderr, exit and handled-message equality |
| New ownership suite |Six methods /376 calls:260 success /116 refusal |

The new suite checks48 independent complete raw JSON vectors, decoded Unicode/
NUL keys, copied raw fields, maps/metadata/unknown values, member counts and work
counters, and complete existing frozen serializer outputs. It covers null/default
modifiers, empty/scalar/wrong-root/missing-map cases, malformed UTF8/escapes,
escaped duplicates, nesting/member/work/extent bounds and typed integer overflow.
Large exponents remain valid raw JSON metadata; no numeric conversion is claimed.

Exact4095/4096/4097,8191/8192/8193 and16383/16384/16385-byte fixtures exercise
page/read boundaries. Actual full SHA-256 and every copied byte match independent
Python oracles despite forged writable digest claims. Tests cover moves, repeat
close, retained independent copies, writable parsed caches, invalid live extent,
architecture, closed/oversized/unsealed descriptors and fresh recovery. Sixteen
independent mutation runs restore complete preimages, change originals by
truncate/zero/replacement or same-size byte write after copy before parsing, and
compare complete sealed outputs and original postimages. Copy/hash/seal and
metadata short/error/EINTR/EOF/extra-count/lookahead/post-read faults are followed
by fresh successes; short reads complete the entire exact metadata value.

## Observed effects and preserved attempts

The253 new traces pass PID/name joins and generation-aware fd accounting:
273 original opens/closes,251 sealed creates/closes,1485 positional reads and309
positional writes. The audit observes416 complete sealed hash phases, two
intentionally bounded partial phases,294 metadata phases and292 observed EOF
phases. Every successful nonempty metadata read follows two complete hashes on
the same live sealed descriptor and original close. Empty source hashes require
no read syscall; malformed empty JSON is refused. No source mappings occur.
Injected user-space failures are recorded separately from observed syscalls.

All109 other traces form a disjoint audit partition. Three literal unreturned
worker sigaltstack records remain opaque; no return/effect is inferred. No target
access, network, ioctl, external-crypto or inference-runtime effects are observed.
Eight ELF dependency tables are inspected separately from syscall effects.

The first run's six ownership methods had one incorrect harness expectation:
a syntactically valid huge exponent was expected to refuse. The corrected test
asserts its exact raw spelling; production and old tests did not change. Both
complete attempts remain preserved. Auditor corrections account for a fresh fd
generation after intentionally failed admission and zero-extent hashes with no
read calls. Final inputs, complete traces, failed attempts and raw identities
are pinned in the evidence manifest. No whole-repository or hosted-CI pass is
claimed. Documentation drift and schema checks retain inherited failures.

## Evidence boundary and next work

Only scoped `sealed_metadata_bytes_bound=true` follows these gates. Writable
parsed caches/digest fields are not identity proofs; arbitrary unsafe corruption
is outside this boundary. Sealed copies may observe mixed concurrent original
writes. Atomic original-version/global source/binding/artifact identity,
architecture semantics, numerical format/fit/placement and execution flags stay
false. This is an owned compiler-input component, not source-model execution.

Owned ordinary shard collections and compiler bindings, remaining source formats,
architectures and operations, actual H10H numerical encoding/configuration,
packing/placement, original program delivery/activation, results and cleanup remain
required work toward the unchanged broad100% ordinary-model target. Users need
no DFC, outside compiler, external compilation machine or vendor-precompiled
prerequisite. All LLM execution remains on Hailo-10H.
