# Original Mojo owned ordinary source collections

Date: 2026-10-23. Published pre-code contract:
`TASK_hailo10h_sealed_source_collection.md` atd218e01.
Owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Evidence: `evidence/sealed-collection-native-2026-10-23/`.

## Implemented input lifetime

New `smidr/sealed_source_collection.mojo` retains sealed config/index metadata
and every actual sealed Safetensors backing file for indexed or unindexed
ordinary folders. It uses the existing beneath-root opens, sealed copy, consuming
parsers, inventory projection, storage validation and checked aggregate helpers.
No existing production module changes; no parser, conversion, copy, hash or root
resolution algorithm is copied. Production OS effects use existing HAILBRU.

A consuming SourceRegularFile bridge checks the actual host, borrows its exact
live descriptor to the existing sealed-copy routine, and closes the original
before parsing. Each original closes before its own sealed parser; the directory
closes before return. Partial construction and later-file/join failures clean
previously admitted owners through field destruction. Explicit close attempts all
metadata/shard owners and reports the first error from existing raising close
interfaces. Existing Safetensors close remains nonraising; this slice does not
claim that it reports all underlying syscall failures.

The aggregate copied-source-byte permit covers every actual file byte, including
padding. Copy/read/write/digest attempt permits apply independently per file and
hash phase. Root, parser and collection work/metadata/payload policies retain
their distinct scopes. Known metadata extents are checked before sealed allocation
or copying. Checked charges enforce remaining aggregate limits. Shard labels are
deduplicated; complete tensor membership, label assignment, global uniqueness and
declared total_size are verified against actual parsed storage descriptors.

Bounded byte/constant helpers read retained sealed owners and check actual live
seals, extent and captured mapping capacity. Byte reads reuse the existing8192-byte
positional helper and single EOF lookahead. No borrowed-fd owner, fd duplication,
proc/label reopen or old collection path reader replaces retained ownership.
Existing root policy remains `RESOLVE_BENEATH|RESOLVE_NO_MAGICLINKS`; ordinary
relative symlink behavior is unchanged, while tested absolute symlinks and escapes
refuse. No stronger general symlink ban is claimed.

## Stable native acceptance

| Receipt | Actual result |
|---|---|
| Old source/test continuity |All669 old Mojo sources and72 Python inputs unchanged;672/73 current |
| Frozen controls |119 pre-code primary controls plus one previously pinned historical auxiliary root API |
| Final current builds |14 zero-diagnostic Mojo entries:12 selected existing controls and two new entries |
| Test shims |Six zero-diagnostic C builds with warnings treated as errors |
| Final suites / methods |Seven /41, all pass |
| Qualified entry calls |1484:1315 current and169 explicit frozen calls; paired controls additional |
| Complete frozen comparisons |971 across all12 selected controls:556 success /415 refusal |
| File mutation / directory rename pairs |28 /1, including full preimages, postimages and deletion state |
| Independent complete fault-log pairs |65 |

All final binaries/shims link from stable inputs before native acceptance.
The119 primary controls remain immutable; unrelated entries are not claimed as
rebuilt. The historical root API is separately identified and verified against its
previously pinned binary. All21 inherited auxiliary inputs remain exact. The real
new-leaf import closure contains only its inspector and API. Fourteen ELF dependency
tables are inspected separately from syscall effects. Qualified-call counts apply
to registered entry identities; other oracle child outputs remain in suite logs.
No whole-repository or hosted-CI pass is claimed.

The new eight methods make398 calls:244 success and154 refusal. They compare190
complete metadata/storage/counter projections,182 full backing-byte/component
snapshots,245684 shard bytes and6120 exact raw/binary32 component words. Fixtures
include F16/BF16/F32 special/seeded words, scalar and empty shapes, Unicode/NUL
names/metadata, null/default modifiers, nested shard labels and shared-label
deduplication. Full SHA-256 and raw backing bytes match independent Python values;
complete overlapping metadata/storage outputs match frozen collection tools.

Exact4095/4096/4097,8191/8192/8193 and16383/16384/16385-byte fixtures exercise
copy/hash/page/metadata boundaries. Tests cover independent writable caches and
claimed hashes, moves, close, retained independent byte/constant copies, invalid
owner extent and byte/window limits. Root/parser/aggregate/copy permits, malformed
headers/JSON, missing/extra/duplicate/misassigned tensors, declared sizes and
unsupported dtype behavior are checked without turning current missing formats or
operations into permanent eligibility restrictions.

Forty-four mutation runs restore complete preimages before independent repeats:
20 truncate/zero/replace/rename/same-size writes after return and24 targeted changes
after actual copy/original close before parsing. Complete sealed outputs, original
postimages and rename/deletion states match. Faults target config and a later shard
with earlier owners already admitted: open/copy/read/write/seal/hash/map, metadata,
original-close and reported metadata-close failures. Short reads complete the full
input; every refusal is followed by a fresh successful load. Tests retain the
established nonraising Safetensors close behavior explicitly.

## Observed effects and retained attempts

All290 new PID/name/fd-generation traces balance269 root,868 original-file and778
sealed-file lifetimes, with336 exact sealed maps/unmaps. Original close precedes
observed parser hash/mapping. There are1490 complete observed sealed hash phases,
930 metadata phases and930 observed EOF phases. Zero-extent hashes require no read
syscalls and are not fabricated as observed hash phases. Test seam logs remain
separate from actual syscall effects. No original file is mapped or reopened by a
production parser/helper.

The491 other traces form a disjoint partition with199629 logical records. Two
literal unreturned worker sigaltstack records remain opaque; no return or effect is
inferred. No target-device, network, ioctl, inference-runtime or external-crypto
effects are observed. No numerical hardware execution occurred.

Retained attempts include the inspector's argv Span/List type mismatch, a test-only
unlink/rename string without guaranteed NUL termination, and the first auditor's
incorrect assumption that the existing root policy forbade all symlinks. The test
uses the existing C-string helper; the auditor checks the actual existing policy.
A second accepted run's coverage census correctly refused qualification because
two sealed-copy jobs still routed to older binaries. The runner now resolves both
historical and current source identities. The complete seven-suite rerun covers
all14 current entries and all12 control pairs, with no omitted comparisons.
Production did not change for these test/runner/auditor corrections. First and
final stable builds, all three acceptance attempts and exact source/test snapshots
are preserved by the archive manifest.

## Remaining work

Only scoped owned observed-collection lifetime is verified. Writable parsed
caches, labels and digest fields are not global source/compiler/artifact identity.
Copies can observe mixed writes or different file revisions; no atomic multi-file
original version is claimed. Semantic adapters, numerical device format/fit/
placement, compiled-artifact identity, execution and device-access flags remain
false. Static source component conversion is not model execution.

Compiler binding must rehydrate and validate retained bytes. Remaining formats,
architectures and operations, actual H10H numerical encoding/configuration,
packing/placement, original-program delivery/activation, results and cleanup remain
required work toward broad100% ordinary-model support. No DFC, outside compiler,
external compilation machine, vendor-precompiled prerequisite, host model forward
or inference proxy is introduced. All LLM execution remains on Hailo-10H.
