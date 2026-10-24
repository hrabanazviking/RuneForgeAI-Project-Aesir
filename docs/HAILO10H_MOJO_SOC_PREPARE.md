# Original grouped preparation and cancellation wire values

Date:2026-10-24. Pre-code contract:`TASK_hailo10h_soc_prepare_codec.md`,published
af2406f before production. Qualified public fields:
`HAILO10H_PREPARE_INTERFACE_2026-10-24.md`. Fixed owner scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`;broad ordinary UNMODIFIED model
support100% and Hailo-10H-only LLM execution stay unchanged.

## Original implementation

New `hailbru/soc_prepare.mojo` exposes original encode/decode functions for the
139-byte prepare body and8-byte cancellation handle. No old production or test
file changed. Preparation uses the existing sole group encoder to revalidate
all current fields,then copies the complete139-byte body. Decoding requires
exact139 bytes,appends only canonical engine0/cyclicfalse bytes and invokes the
existing full group decoder. No slot/parser/overflow rule is duplicated or relaxed.

The returned group owns copied spans;returned bytes own their storage. Channel,
handle,actual count1..8,USERPTR type0,positive UInt32 extent,checked pointer+extent,
debug false and unused-slot zeros retain their established guards. Input/list/
byte mutation,moves and source-scope expiry cannot alter independent results.
These explicit codec choices are not permanent model eligibility restrictions.

Cancellation reuses the existing checked8-byte scalar helper and exact length/
handle guards. Handle0 remains valid;UInt64max refuses. A cancellation value is
not a descriptor-release operation or an authority to cancel active DMA. The
bounded inspector handles signed/oversized/invalid numeric or exact hex input
before allocation and never dereferences synthetic addresses.

No driver,request submission,mapping,cache sync,channel,server or execution path
is added. The existing preparation status policy is unchanged;no descriptor
count/capacity or safe physical sequencing is inferred. A valid byte object is
not a valid physical transaction or numerical program.

## Actual native acceptance

| Gate | Result |
|---|---|
| Actual old/final Mojo files |705 /708 |
| Actual old/final Python tests |86 /87 |
| Frozen current qualified controls |156 |
| Old production/test edits |0 |
| Stable links before acceptance |5 Mojo /3 C++ |
| Old selected Mojo binary hashes |All3 exact |
| New statement warnings |0;the inherited soc_abi loop warning stays scoped |
| Selected methods |25:5 new,8 group,12 ABI |
| Primary calls |5459 |
| Complete current/frozen stdout/stderr/exit comparisons |2763 |
| Frozen accepts/refusals |1548 /1215 |
| Complete retained output triples |8222 |
| New-consumer traces |2988 |
| Observed descriptor generations/actual closes |52684 /52684 |
| Individually joined new inspector refusal→fresh success |977 |
| Additional direct in-process guarded recovery cycles |324 |
| Independent complete prepare/header/launch-prefix vectors |224 |
| Independent complete cancellation/header/scalar vectors |68 |
| Separate ELF tables |16 across8 images |

Independent Python struct packing and original test-only public-header objects
compare complete bytes for every span count/slot,asymmetric/reversed order,
metadata2068/program70,maxima,walking64/32-bit values and seeded vectors. The
same source values produce exactly prepare bytes plus two zero flags through
the frozen launch codec. Cancellation matches actual public-header objects and
the qualified scalar helper without equating their request operation numbers.

A separate Python admission predicate checks every-byte mutations at counts1,2,8,
all256 count bytes,each unused byte,each used type byte,debug and sentinel values.
Every shorter prepare/cancel length and sampled trailing lengths are exercised
through inspector and direct API guards. All mutable group fields,empty/extra/
replacement lists,address overflow,input bounds and independent source/result
lifetimes pass. The unmodified group/ABI suites and their auxiliary ownership/
C++ oracles retain every complete frozen comparison.

Every new trace has actual PID/call joins and fully classified records;all
observed fd acquisitions close. No opaque syscall record is ignored. Traces
show no Hailo open,ioctl,network,memfd or excluded inference/checksum/protobuf
runtime. Dynamic and symbol evidence is separate from observed behavior. No
model/layer/attention forward or physical operation occurs. All868 pre-code
archive paths,156 controls,actual old/final source/test copies and compiler
identity are reverified. The actual affected executable closure contains only
the two new Mojo consumers.

## Preserved evidence and continuation

The pre-code declaration probe's copied-executable permission refusal is retained
in its868-path contract archive;the corrected17 object probes pass. Native
implementation links and acceptance have no failed build/test attempt. A second
independent audit adds explicit classification of every trace line/syscall;
both audit inputs/results remain. No warning on a new statement is accepted.

Immutable native archive:
`evidence/soc-prepare-native-2026-10-24/archive-identities.json`.
Its21120 paths cover204112014 aggregate bytes in3 manifest pages;SHA256:
`b5d30d53122f4d92cb5e5d995d35a4124ddd633d0805f028d3f19417b2f72793`.
Never edit these raw directories or rerun their recipes into them. Publication gates retain the identical nine inherited schema errors. Drift
reports23410 findings:23409 inherited plus one literal compiler path in retained
audit evidence. Census succeeds with141 verified/186 total. Complete output
identities and delta are retained;no whole-repository or hosted-CI pass is claimed.

Continue actual same-file channel/storage ownership,descriptor accounting,
completion/total deadlines/late cleanup and numerical H10H encoding/packing/
placement/program activation/results. None is established by host wire values
or earlier two-part map-only receipts. Missing formats,architectures and
operations remain required implementation work toward the fixed broad target.
No DFC,outside model compiler/machine,vendor-precompiled prerequisite,host/CUDA/
cloud LLM forward/proxy,guessed descriptor count/opcode/register/write,reset/
rebind,kernel or firmware change is introduced.
