# Original grouped USERPTR launch value codec

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_soc_group_codec.md`,published
at`6e70ff2fc4b16fbd09e7c13534ba8c7f810e4b7c`. Public declaration qualification:
`HAILO10H_GROUPED_TRANSFER_BOUNDARY_2026-10-23.md`. Fixed owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

Original `hailbru/soc_group.mojo` owns copied address/size span values and the
channel,descriptor handle and actual span list. `SocUserptrGroup` validates
all values before copying. `encode_soc_group` rechecks every public mutable
field and actual list count before allocating the141-byte result. It reuses
original soc_abi channel,handle,length,word and zero-storage helpers.

`decode_soc_group` requires exactly141 bytes,one through eight spans,USERPTR
type0,debug false,engine0,noncyclic and zero unused slots. It validates every
used/unused field before copying independent values. The count comes from the
actual current list when encoding;no cached offsets or count are trusted.
Ordered spans,full unsigned64 addresses/handles and positive UInt32 sizes are
preserved. Nonzero pointers and checked unsigned address+extent are required.
The new overflow refusal is deliberately stricter than unchanged soc_transfer;
one-buffer bytes match the original throughout the selected compatible domain.

The profile is an explicit component choice,not a permanent hardware/model
eligibility restriction. Address values are synthetic scalars only. No alignment,
pinning,mapping,physical address safety,descriptor capacity,completion behavior or
valid executable program is inferred. The bounded diagnostic never dereferences
addresses. No mapping,sync,driver request,ioctl or live SocRpcClient integration
was added. Source model compilation/execution is still required implementation.

## Native evidence

| Gate | Result |
|---|---|
| Stable links before acceptance |3 Mojo and2 C++ public-header oracles |
| Selected suites |2 suites/20 methods,all pass:8 new and12 original ABI |
| Primary native calls |2179 |
| Additional full frozen comparisons |218:156 accept,62 refuse |
| Complete retained stdout/stderr/exit pairs |2397 |
| New suite |1856 calls,including227 independent public-header object vectors |
| Every new Mojo call traced |1609:456 accept,1153 refuse |
| Direct ownership/mutable-value recovery |177 refusal/fresh-success cycles |
| Separate dependency inspection |5 executables/10 ELF dynamic and symbol tables |

Complete bytes are checked independently against Python struct packing and
actual objects from the pinned public UAPI. Counts1..8,every slot,order reversal,
zero/max/asymmetric words,all64 address walking bits,all32 size walking bits,
random values,all256 encoded count values,used-slot types,all unused bytes and
tail flags are exercised. All141 truncations and20 trailing extents refuse;
malformed decimal/hex/argument work bounds and fresh success after refusals pass.
The direct API checks constructor-copy independence,span/list replacement,
returned/source byte independence,moves,scope expiry,all eight mutable slots,
channel/handle mutation,empty/nine-element lists and direct truncated inputs.

The original ABI suite reruns12 methods/323 native calls. All198 original Mojo
invocations plus20 additional selected old calls are paired with the pre-code
frozen consumer using complete stdout,stderr and exit status. The old overflow
acceptance is recorded separately from the new stricter refusal. The final old
binary and its three inherited warning diagnostics exactly equal the pre-code
build. Each new consumer inherits one unchanged unused-index warning from
soc_abi.mojo;there are no new-code warnings. These builds are not described as
warning-free. No old production or test input was edited.

Every new trace joins one exec to its returned exit_group status,including
unfinished/resumed syscall lines,with no observed Hailo open,connect,ioctl or
excluded inference runtime load. This scopes the tested consumers,not the whole
engine. Test-only C++ includes the qualified public declaration header outside
production. Driver root GPL-2.0 and UAPI expression
`(GPL-2.0 WITH Linux-syscall-note) AND MIT` remain exact;no vendor implementation
was copied or translated.

Before production,actual684 Mojo/78 Python inputs were copied and verified,
134 retained controls rehashed,and the missing original ABI consumer freshly
built/frozen. Final actual copies contain687 Mojo/79 Python inputs. All old
inputs,controls and compiler hash remain exact. Import closure identifies the
two new executable consumers. Both first/final link snapshots are retained.

Preserved verification corrections: the baseline script initially asserted an
incorrect zero-warning assumption after a successful old link;that assertion was
scoped and completed before production. A Python method shadowing unittest.run
was caught by inspection before tests and corrected in fresh frozen inputs.
The first census expected unsplit exit_group text;the second joins the actual
unfinished/resumed trace lines. No native build or acceptance test failed.
Raw identities and the independent census are under
`evidence/soc-group-native-2026-10-23/`. Inherited document drift and nine schema
errors remain scoped;no whole-repository or hosted-CI pass is claimed.

## Required next work

This closes the grouped value serialization gap. It does not allocate,map,pin,
sync or submit metadata/program storage. Existing RPC storage/progress remain
fixed to2068 bytes and single-span accounting. Actual grouped descriptor
semantics,immutable compiler output,in-flight lifetime,total deadlines and
late-error cleanup must be established before a live payload phase. Numerical
precision/packing/configuration/placement,original program activation/results
and broad ordinary UNMODIFIED source-model execution remain open work toward
the fixed100% target. All LLM execution stays Hailo-10H only. No outside compiler,
DFC,external machine,vendor-precompiled prerequisite or host/proxy inference
route is introduced. No device request/reset/rebind/firmware/kernel change ran.
