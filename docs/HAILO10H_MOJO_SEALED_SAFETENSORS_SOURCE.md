# Original Mojo owned sealed Safetensors source

Date: 2026-10-22. Pre-code work order:
`TASK_hailo10h_sealed_safetensors_source.md`, published at42686ee.
Controlling owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Evidence: `evidence/sealed-safetensors-native-2026-10-22/`.

## Implemented boundary

The existing mapped Safetensors reader now admits an exclusively owned sealed
fd, captures mapping extent independently of writable declared size, and prevents
the sealed route from reopening a path after close. Only
`armvegr/safetensors.mojo` changes among existing production modules. Its40
existing parser, conversion and query routines remain byte-identical. The old
ordinary-path parser, precision, explicit cleanup and reopen behavior are retained.
The shared loader gains no implicit destructor.

New `smidr/sealed_safetensors_source.mojo` provides a movable owner, consuming
parser, bounded path factory and constant helper. It recomputes the full actual
sealed byte digest, ignores writable hash claims, transfers the same fd through
existing `take_fd` and calls ONE existing header parser. The original descriptor
is closed before parsing. Cleanup uses captured capacity on partial construction,
exceptions, moves and repeated close. The helper verifies actual live seals,
regular-file extent and mapping capacity before the existing component reader.
The scoped tool reports `sealed_input_bytes_bound=true` only after these gates.
All global identity, physical-format, fit, placement and execution flags stay false.

## Stable native acceptance

| Receipt | Actual result |
|---|---|
| Current source identities / unchanged old sources |666 /662; one permitted old module changed and three Mojo leaves added |
| Current Python inputs / unchanged old inputs |71 /70 |
| Current native entries |117; all built before native acceptance |
| Frozen controls |111 qualified before code, plus four late controls compiled from the frozen pre-code source snapshot |
| Total Mojo builds |121;119 with zero diagnostics and two with the same inherited legacy warning |
| C fault shims |Five clean builds with `-Wall -Wextra -Werror` |
| Final suites / methods |50 /354; all pass |
| Qualified entry calls |14519:14465 current-entry calls and54 explicit frozen-baseline calls; additional paired controls counted separately |
| Complete frozen comparisons |14325 across all115 controls:8116 zero exits and6209 nonzero refusals |
| Full legacy mutation / separate fault-log pairs |16 /45; complete stdout, stderr, exit and handled-message equality; no omitted comparison |

The conservative current import closure contains107 qualified entries, including
both new entries; every one and all remaining qualified controls were rebuilt.
Three directory-based consumer groups resolve through actual source identities.
The legacy `h043_st_check` runs only in header mode, never its optional load mode.
All supplied native binaries, C shims, Python/C inputs and21 previously qualified
auxiliary oracle/source inputs remain exact. ELF dependency inspection is recorded
separately from actual syscall effects. No whole-repository or hosted-CI pass is
claimed; the documentation drift comparison records inherited failures.

The two nonempty build diagnostics are the frozen/current legacy `h043_st_check`
warning about an unused UInt16 initialization in an unchanged conversion body.
Complete warning text, with only inclusion-path and shifted-line labels normalized,
is identical. No old conversion body was changed to suppress it.

## Independent representation and lifetime cases

The new eight methods make176 calls:110 zero exits and66 refusals. They compare
263212 complete raw/binary32 component words,21 full windows,15 complete header/
metadata/axes/binding/source snapshots and62587 source bytes. Fixtures include all
65536 F16 and BF16 source words, special/seeded F32 words, scalar/rank64/empty
shapes, Unicode/NUL names and metadata, and4095/4096/4097/16383/16384/16385-byte
boundaries. Existing source-format namespaces and unsupported-dtype behavior remain
unchanged; further dtypes and ranks remain implementation work toward broad support.

Four complete lifetime component pairs cover moves, busy alias/distinct ownership,
close, copied windows, capacity and recovery. Sixteen complete parser-refusal pairs
match old behavior. Truncate, zero-size mutation, replacement and a separate
same-extent byte write occur after copying and before parsing; independent repeats
restore complete preimages, compare complete postimages and retain sealed outputs.
Nine injected failures are each followed by a fresh successful factory call.

## Observed effects and preserved attempts

All102 new traces pass the actual PID/name-joined audit:110 source opens/closes,
96 sealed creates/closes,69 sealed read-only shared maps and three ordinary
read-only private maps, with72 exact unmaps. Original close precedes sealed
admission. Every sealed map follows two complete actual sealed hash phases;
172 complete phases and one intentionally bounded partial phase are observed.
The630 other traces are a disjoint partition, with258029 decoded logical records.
Two new and one old unreturned worker syscall records remain literal and opaque;
no return or effect is inferred for them. No target-device, network, ioctl,
external-crypto or inference-runtime effects are observed in these traces.

Retained development/preparation attempts include the test-only Int/Int64 syntax
correction, inherited-warning strict-gate refusal, context result-path routing,
four custom parsers refusing a runner-added verbosity flag, and the fd rename
comparator assuming an alternate still existed. A full50-suite rerun uses original
argument conventions and compares both rename files, including deletion state.
Initial trace analysis also retained its split-call spacing refusal and the
subsequent disjoint path-normalized partition review. No production algorithm or
old Python test changed for these harness corrections. Early test-expression and
temporary rename inputs reconstructed from unchanged builders are labeled as
reconstructions, not raw pre-run captures. All final inputs and raw attempts are
retained locally by 4889 pinned identities; 6245 prior archived files verify unchanged.

## Evidence boundary and remaining work

This establishes ownership of immutable OBSERVED Safetensors bytes through the
existing parser and static component reader. It does not establish an atomic
original-file version, global source/binding identity, compiled chip artifact,
numerical device format, hardware fit/placement or source-model execution. A copy
may observe mixed concurrent original writes. Arbitrary unsafe caller-state
corruption is outside the claim.

The broad100% ordinary-model target remains fixed. Config/index/shard ownership
and compiler bindings, remaining formats/dtypes/ranks/architectures/operations,
and actual H10H numerical configuration, packing, placement, original-program
transfer, results and cleanup remain implementation work. No DFC, outside compiler,
external compilation machine or vendor-precompiled prerequisite is introduced.
All LLM execution remains on Hailo-10H; this slice performs none.
