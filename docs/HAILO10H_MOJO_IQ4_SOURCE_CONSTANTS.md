# Original Mojo nonlinear IQ4 source components

Date: 2026-10-22. Pre-code contract:
TASK_hailo10h_iq4_source_constants.md, published `efb0ec0` before production.
Qualified fields: HAILO10H_IQ4_SOURCE_LAYOUT.md. The owner’s full broad ordinary,
unmodified source-model target remains unchanged.

## Implementation

The original packed GGUF geometry admits20 IQ4_NL,32 elements/18 bytes, and23
IQ4_XS,256/136. IQ4_NL has an explicit32-element row-alignment path and diagnostic;
it no longer falls through the K256 path. Old formats, width bounds, signatures
and unrelated diagnostics stay unchanged. The existing source_weight_tiles
consumer uses shared geometry and needs no production edit or duplicated dispatch.

The new source_iq4_constants reader returns owned bounded components: raw d
binary16 words, exact expanded binary32 representations, group-scale presence,
signed group scale, original four-bit nonlinear code and its signed source
value. IQ4_NL preserves absent/fixed1 scale;IQ4_XS preserves present-32..31.
The16-value codebook is published source-format data from the pinned public MIT
definition, with attribution and retained license. The lookup and bit access are
original;no external implementation algorithm is copied/translated or introduced
as a runtime dependency. Production evaluates no floating tensor product.

Live owner, exact axes/kind, checked products, full data-origin/tensor/file span,
selection and explicit host bounds precede requested allocation/payload access.
Special words and signed zeros stay as exact source bits. File offsets and
source component values establish no device address, precision, packing or ISA.
Dense vectors/matrices are the current importer boundary;remaining source ranks,
formats, architectures and operations remain implementation work toward100% of
the broad target.

## Verified acceptance

| Gate | Recorded result |
|---|---|
| Native rebuild | 102 current Mojo entrypoints with zero diagnostics;649 actual source snapshots/identities and100 binaries frozen before IQ4 production. |
| Targeted acceptance | 43 suites,305 methods,13,399 recorded primary child calls. Existing isolated C/C++ oracle calls are included in the child-call census and are not Mojo builds. |
| New IQ4 suite | 14 methods/546 calls:345 accepted,201 expected refusals;327,602 complete component comparisons and27,584 source-byte comparisons. |
| Preserved behavior | 100 pre-code controls;6,379 complete successful stdout pairs and5,561 nonzero exit/stdout/handled-error pairs. 99 controls have successful cases;the original storage-scenario API is mutation-only. |
| Source lifetime/access | 27 actual new trace files,36 matched read-only whole-fixture mappings/opens/closes/unmaps;unchanged source bytes and zero target-device/network/ioctl/inference-runtime access. |
| Independent format | Separate clean pinned public-header C++ object;2048 finite synthetic constant values against isolated static functions. CPU backend OFF;no external model/context/graph/forward API. |

All65 old Python inputs remain unchanged. Among646 prior Mojo sources,only the
packed loader changes;645 are unchanged and three new Mojo files bring the
current census to649. Every one of100 controls was frozen before IQ4 production.
Conservative import inventory covers every affected safe SMIÐR/Hailo entrypoint,
including the full actual source_storage suite. Engine host-model/historical
entrypoints are excluded from execution. Full source/binary/input identities
are checked before/after build and test execution.

Every native success compares complete stdout;nonzero cases compare exit,stdout
and handled error routing/message. Direct and strace-wrapped API calls are paired;
ldd remains a separate dependency inspection on current/pre-code binaries. No
unrelated native pair is skipped. Actual source_storage_api arithmetic proves
20[32] changes from K-alignment refusal to18 bytes,20[256] from unsupported to144
bytes,and23[256] from unsupported to136 bytes. Safetensors dtype,metadata type,
file-format and device/control namespaces remain separate. Old test inputs need
no changed negative sentinel.

Independent writers compare1200 one-bit/group cases and278528 full component
records as a subset of the complete comparisons. They cover all packed quant/
scale bits,16 nonlinear codes,signed
scale extremes,special d words,vector/matrix and lane16/32/256/block/row/final-byte
windows,Unicode/NUL names,truncation,bounds,coherent overflow axes,live/schedule
mutations,ownership and recovery. Actual original compiler bindings and lazy
source tiles are exercised. Tiny isolated public static functions check only
synthetic finite constants,not model/context/graph/forward execution or exact
signed-zero numerical results. Exact source bits are compared independently.

All43 native suites passed in the initial run. The older Q8 audit then rejected
a successful resumed mmap because its pattern required exactly one space after
the closing parenthesis. The raw trace and failure remain intact. An additive
review applies the already qualified whitespace-tolerant/PID-aware auditor to
the same copied raw traces,retaining every access/size/lifetime check and deriving
the trace count. No native suite is rerun and no source,binary or test input
changes. All five final audits pass. The previously unexecuted frozen control/
admission/dependency/header footer then completes against those native results.

PID-aware trace auditing joins unfinished/resumed syscalls with normal spacing
before/after closing parentheses. Whole-fixture read-only shared mappings include
synthetic payload;unchanged hashes and matched opens/maps/unmaps/closes are proven.
Counts derive from actual records. Full original outputs remain in hashed outside
archives;published large-output receipts contain sizes/hashes after complete
comparisons ran. Those receipts are not described as digest-only component tests.
Runner status/report filenames are distinct.

Evidence: docs/evidence/iq4-source-constants-2026-10-22. The repository consistency
checker still reports23296 historical issues,including nine existing strict
ledger-schema diagnostics;normalized additions/removals for this slice are zero added/zero removed.
No whole-repository or hosted-CI pass is claimed. No physical device request,
model download,external compiler/model prerequisite,numerical Hailo or source-
model execution is introduced.

## Continued numerical work

Two bounded official-interface searches establish no new numerical instruction,
register or placement field. This is an observation,not an absence proof or new
capability. Numerical lowering,actual configuration/precision/packing/placement,
valid original program delivery/activation/results/cleanup and broad ordinary-
source execution remain open under TASK_hailo10h_numerical_encoding_sources.md.
