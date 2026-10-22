# Owned sealed GGUF parser and source-reader integration

Date: 2026-10-22. Pre-code contract39d187d and route clarification/native parent
f208472: `TASK_hailo10h_sealed_gguf_source.md`. Fixed broad ordinary-model scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

Aesir now copies an ordinary source into its existing bounded sealed owner,
closes the original descriptor, recomputes the full actual sealed digest,
transfers exclusive descriptor ownership and invokes its original GGUF parser
on a read-only shared mapping of that exact descriptor. The diagnostic label is
never reopened. No user conversion or outside model compiler is involved.
The digest-call permit applies separately to copy hashing and parser hashing.
A writable claimed digest is ignored. Transfer validates actual seals and exact
extent before invalidating the old owner; failures retain or clean the actual
owner once. The mapped descriptor stays owned until unmapping.

`GGUFSeer` records successful mapping capacity independently of mutable
`file_size`, for both ordinary-path and sealed-fd routes. Checked ranges are
bounded by both values; cleanup uses the captured extent. Sealed admission
persists after close, so reopen and metadata reentry cannot open a source label.
Busy admission refuses an alias without closing the existing descriptor and
cleans distinct incoming ownership. This is not a defense against arbitrary
caller memory/state corruption.

The existing `PackedGGUF` table interpreter was factored into one shared method.
Its original body is byte-for-byte identical; both constructors use it. Existing
geometry, metadata, width, rank, default and error semantics remain intact.
Only the three contracted production modules changed;653 old Mojo sources and
68 old Python test inputs are unchanged. Four new Mojo files comprise two
production leaves and two test entrypoints.

The scoped new inspector reports `sealed_input_bytes_bound=true` only after
actual seals, extent, recomputed digest, mapping and parser gates. Existing
fingerprint, immutable-source, artifact-binding, execution and device flags
remain false. The parsed source and its payload views refer to one owned sealed
file; a mixed original copy remains possible under concurrent original writes.

## Verification

Evidence: `evidence/sealed-gguf-source-2026-10-22/`.

- 109 clean stable Mojo builds: every106 frozen current primitive entrypoint,
  including all100 affected and six conservatively rebuilt unaffected controls,
  plus three new entrypoints. Two original C fault shims build cleanly. All
  linking finishes before native test execution.660 actual source snapshots,
  original656 snapshots,68 original Python snapshots and106 old binary
  identities are retained.
- The six new methods make221 child calls:156 zero exits, including handled
  refusal/recovery seams, and65 expected nonzero refusals. They compare55
  complete metadata/axes/binding/payload/file snapshots,90687 raw byte values,
  6924 complete constant components,426 byte tiles and eight complete structural
  semantic graphs with weight bindings, including tied weights. These are
  source/structural compiler checks, with no tensor, layer or attention forward.
- All15 current GGUF geometries, scalar words, arrays, embedded NUL/Unicode,
  default/explicit alignment, odd/page/tensor boundaries and25 complete
  old/new parser refusal pairs pass. Original truncation, same-size mutation and
  path replacement after copying leave parsed metadata and payload unchanged;
  all three complete final original-file contents are independently compared.
- Actual seal checks, transfer/default/closed/forged-owner refusal and recovery,
  invalid/unsealed/wrong-size descriptor admission, busy aliases/distinct owners,
  old/new capacity poisoning, exact cleanup and sealed-route lifetime pass.
  Copy, parser-hash, transfer, admission, mmap, header and table failure cleanup
  is exercised. Public test seams are restored before destruction except the
  intentional cleanup-capacity tests.
- 95 new traces contain105 matched source opens/closes,93 matched anonymous
  creates/closes,71 read-only sealed maps,one read-only ordinary-path map and72
  exact-capacity unmaps.306 actual kernel positional reads and106 writes are
  retained. Trace parsing joins split records by actual PID/name, including
  literal unresolved names. No new opaque effect or forbidden access is found.

- Canonical acceptance comprises46 suites,322 methods and14257 recorded primary
  child calls. All106 rebuilt controls match13123 complete frozen comparisons:
  7272 successful outputs and5851 nonzero exit/stdout/handled-error cases.
  Six original-file mutation pairs restore the preimage before the control,
  compare complete postmutation bytes and restore the primary postimage.
  Forty fault cases retain separate, completely equal diagnostic logs.
- Ninety-three old copy traces and28 old digest traces retain their ownership,
  bounds and cleanup checks. The complete legacy set, including the three
  corrected directory-suite reruns, contains407 traces with no forbidden access.
  One resumed-but-unreturned worker sigaltstack record at process termination is
  retained as opaque; no effect is inferred. The auditor now joins the matching
  PID/name before classifying its literal unfinished tail. The failed audit and
  corrected script/results are preserved; no native rerun was needed for it.

Compile-time test API naming/list syntax diagnostics and an unused assignment
warning are retained in development evidence. Those development binaries were
never executed. The final native source/test suites needed no production or old-test correction.
The initial full regression run stopped because its primary and frozen control
shared a fault-log pathname, doubling diagnostic attempt counts. The corrected
harness retains separate logs and requires complete byte equality while proving
the primary log unchanged. A fresh full acceptance run repeats every suite. Its coverage check catches
three suites still reaching consumers through a historical binary directory;
all three are then rerun using source-identified current aliases and full frozen
pairs. The canonical46-suite set covers every106 control with no omissions.
Initial compatibility runs, both harness refusals and all records remain archived.
The evidence recorder's first attempt assumed every call manifest was a list;
its failure is retained and corrected to read the history suite's explicit
calls/native_child_calls fields. No test or result is omitted.
Dependency inspection is separate from actual API traces. Historical raw
attempts and prior evidence remain preserved.

## Remaining work

This establishes owned immutable observed GGUF input at the existing parser,
constant-reader, byte-tile and structural graph boundary. It does not establish
an atomic original-file version, compiled-artifact/session identity, hardware
precision/packing/placement, numerical instructions/configuration, program
upload/activation/results/cleanup or source-model execution. Coherent compiler
and artifact ownership across the source lifetime is next, alongside ordinary
format/architecture/operation coverage and actual numerical backend work.

The bounded public search returned product/compiler-wrapper descriptions and
qualified no arithmetic bit/register/opcode definition. It is not a proof of
public absence and supplies no new execution capability. No external source body
was adopted or model/compiler invoked by that search.

The owner's broad ordinary unmodified model target remains100%. Missing formats,
ranks, architectures and operations remain implementation work. All LLM execution
stays on Hailo-10H. No whole-repository or hosted-CI pass is claimed.
