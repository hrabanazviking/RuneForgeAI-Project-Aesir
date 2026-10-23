# Original sealed two-part transaction backing

Date:2026-10-23. Pre-code contract:`TASK_hailo10h_sealed_transfer_backing.md`,
published at`5e977a4d635f5035d59cfa521f77fc80de63cab0`. Fixed broad owner scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented host owner

Original `smidr/sealed_transfer_backing.mojo` retains a moved existing sealed
program owner and a separately owned anonymous sealed2068-byte metadata file.
The parts remain ordered metadata0/program1. No existing production or test file
changed. There is no driver,view mapping,channel,transfer or model consumer here.

Construction validates the actual program owner,full outer integrity,complete
request and canonical metadata before metadata allocation. It reuses qualified
original memfd/fcntl/regular-extent/CLOEXEC/positional-I/O/close interfaces. It
writes all metadata with an independent positive attempt bound,handles bounded
short/EINTR progress,rejects zero/excess progress,checks exact extent,applies all
four seals,and checks the full actual metadata readback. Program and metadata
read attempts have separate bounds. No external implementation or new raw OS
interface is introduced.

Every window access checks signed/work/extent bounds before allocation,then
revalidates consumed host/owner/request values,the actual sealed program and
its complete integrity,and the metadata descriptor's actual seals/extent/flags.
It rereads all2068 actual metadata bytes and compares them with freshly canonical
intent,including for empty/end windows and program-part reads. It trusts no
cached validation flag or mutable metadata list. Metadata and program descriptors
must be distinct. Any descriptor deliberately forged in tests is restored before
destruction. No caller-supplied scalar address is dereferenced.

Returned windows are independent copies and survive moves,closure and source
scope expiry. Explicit close invalidates each descriptor before reporting errors,
continues independent host-owner cleanup,and preserves combined metadata/program
close errors. It never retries an uncertain descriptor. Partial construction
retains the moved program until the containing host owner unwinds. Destructors
close only descriptors still owned by their objects.

This establishes immutable bytes in the actual sealed objects. Independently
substituted valid objects still do not establish historical global artifact
identity or source-to-executable coherence. A valid outer envelope does not admit
its opaque contents as numerical instructions. This is transaction byte backing,
not source-model execution or physical delivery.

## Actual acceptance

| Gate | Verified result |
|---|---|
| Pre-code actual source/test copies |692 Mojo/82 Python |
| Frozen old controls |148 |
| Final actual source/test copies |695 Mojo/83 Python |
| Stable links before acceptance |11 Mojo/6 C or C++ |
| New executable consumers |2,both warning-free |
| Selected old Mojo consumers |All9 binary hashes exactly equal pre-code controls |
| Selected suites |7 suites/57 methods,all pass |
| Primary native calls,including historical counterexamples |5291 |
| Complete frozen comparisons |4699:3093 accept,1606 refuse |
| Complete retained stdout/stderr/exit triples |9990 |
| New diagnostic/API traces |236 |
| Independent new returned-byte comparisons |149639 |
| Direct mutable-field/bound refusals |2099 |
| Actual metadata C/kernel checks |2246,each comparing all2068 bytes |
| Independently inspected actual metadata bytes |4644728 |
| Actual kernel protection refusals |8984 |
| Actual new-consumer memfds |6622 acquired,6619 explicitly closed,3 retained until exit |
| Separate ELF audit |17 artifacts/34 dynamic and symbol tables |

Independent Python struct,pinned public RPC schema/protobuf and test-only XXH3
oracles construct full synthetic metadata/program/windows. Fixtures cover empty
residue,odd/page/multiblock program sizes,UTF8,UInt32 request limits and bounded
text/numeric input. A separate original C/kernel seam inspects the actual owned
metadata file,its full bytes,seals and CLOEXEC,then independently attempts and
observes write/grow/shrink/shared-writable-map EPERM refusals. Refused shared
mapping attempts are test evidence;no successful metadata/program view is created.
The schema compiler and checksum library are isolated test oracles,not production
model compiler or native runtime dependencies.

Direct API tests independently perturb each of the2068 metadata bytes in a
separate sealed file. They also exercise every consumed owner/request field,
distinct-fd/host/extent/seal/flag guards,program metadata mutation,empty-window
validation,independent read bounds,default/closed owners,moves,scope expiry and
owned copies. Fresh valid owners follow corrupt-field refusals. Construction
rejects a changed source before allocating metadata storage.

Fault injection covers metadata create/oversized-fd/extent/stat/seal/get-seals/
flags/read/write errors,zero/excess progress,bounded repeated or single EINTR,
positive shorts,late readback corruption and late validation failures. Separate
short-progress recovery checks prove fresh in-process success after exhausted
read/write attempts. Metadata-only and combined metadata/program close failures
are injected before and after effect;both owners are invalidated independently,
combined errors survive and a fresh owner succeeds. The three before-effect
descriptors intentionally remain open until process exit;they are not falsely
counted as explicit balanced closes.

Selected old sealed-program6,payload8,integrity11,group8,ABI12 and corrected
session6 methods all pass. Nine selected old Mojo binaries are freshly linked
and hash-identical. Older session normal/argument comparators add12 complete
historical pairs;two superseded close-error counterexamples remain separately
identified. Historical old-gap results do not become corrected cleanup evidence.
All old production and Python inputs and the pinned compiler remain unchanged.
Actual import closure finds exactly the two new executable consumers. Old group,
ABI and session warnings remain inherited and scoped;no warning-free claim is
made for those old consumers.

## Trace audit and preserved failures

Every new native child has a full PID-reconstructed trace across interrupted
calls,one exec and its returned exit. Actual memfd acquisitions,seals,positional
I/O,protection refusals and closes match the retained evidence. New traces show
no Hailo open,ioctl,network connect or excluded inference/hash/protobuf runtime.
ELF dependency/symbol evidence is inspected separately. No real storage/wait/RPC
consumer is run against the device;session checks use harmless mocked host files.

The first CLI used the RPC hex parser and incorrectly refused program fixtures
above2068 bytes. Its first full run has two failed methods and all six old suites
passing. That exact source,linked snapshot,test input and full output remain.
The CLI was corrected to the existing bounded program parser,a fresh final
snapshot was linked,and all57 methods pass. The direct backing implementation
did not change after its first link. Additional direct-bound tests are retained
in the new API snapshot. The first C probe's two indentation warnings were refused
under `-Werror` and corrected before stable acceptance. A pre-code control-name
selection refusal and first combined-census category omission are also preserved;
the corrected census includes all12 historical normal pairs and both old gaps.

Immutable local raw archives contain48040 files,379138714 bytes. Manifest:
`evidence/sealed-transfer-backing-native-2026-10-23/archive-identities.json`,SHA256
`dde40cf5fe3b5af3ec92b1d9ea571fdcee1422f8740b0151e6deba1882e6d8a5`.
Actual source/test/control copies,failed and passing complete outputs,all raw
traces,oracle inputs,links and recipes are retained. Never rerun archived recipes
into their directories. Public summaries separate original and supplementary
censuses. Inherited documentation drift and nine schema errors remain scoped;
no whole-repository or hosted-CI pass is claimed.

## Continued physical and numerical work

Both ordered byte parts now have actual sealed host backing. No actual grouped
mapping,descriptor accounting,cache coherence,DMA submission,total deadline,
late cleanup,receiver/program activation or numerical operation is certified.
The separate single-buffer physical pin receipt remains bounded to its cases.
Continue actual grouped storage/descriptor/completion/deadline qualification and
exact numerical precision/packing/configuration/placement/program/results.
All missing formats,architectures and operations remain implementation work
toward broad ordinary UNMODIFIED model support100%. All eventual LLM execution
stays Hailo-10H. No DFC,outside compiler/machine,precompiled prerequisite,
host/CUDA/cloud forward/proxy or guessed opcode/write was introduced.
