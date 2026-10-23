# Original Mojo sequencer configuration and completion bytes

Date:2026-10-23. Contract:`TASK_hailo10h_sequencer_actions.md`, published at
`a7ca592334ea547f5ea151da749efc5995b6d198` before production. Field facts:
`HAILO10H_SEQUENCER_INTERFACE_2026-10-23.md`. Fixed broad ordinary-source-model
target:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

New original `smidr/sequencer_actions.mojo` exposes owned copyable/movable
`SequencerAction`, `validate_sequencer_action`, `encode_sequencer_action` and
`decode_sequencer_action`. Trigger1 has49 complete packed bytes; completion17
has6. All eleven scalar members use unsigned64 storage; narrower kind,
timestamp,index,L3 and activity fields are explicitly checked before encoding.
The four full-width bitmap/offset members preserve every64-bit pattern.
Completion refuses nonzero absent configuration fields. Decode admits exact
extents and known kinds only. Returned bytes and scalar values are independent.

The bounded diagnostic tool reuses existing hexadecimal and unsigned-decimal
parsers after checking98 hex characters/20 scalar digits. It neither opens
input files nor submits records. Its generic index means cluster-index for
trigger, sequencer-index for completion; no physical correspondence is inferred.
The distinct protobuf representation is not converted by this slice.

Zero old production/test edits. All678 pre-code Mojo files and76 Python inputs
remain exact; the Python freeze includes the75 previously selected tests plus
one existing observation auxiliary. All126 pre-code native controls remain
exact. New code adds one module, one tool, one direct ownership test, one C++
header-object oracle and one Python suite. Final actual copies contain681 Mojo
files and77 Python inputs. The recomputed import closure has exactly the two
new executable Mojo consumers. Six Mojo and three C++ entries linked cleanly
against stable inputs before the first acceptance call.

## Independent native acceptance

| Gate | Actual result |
|---|---|
| Three selected suites |27 methods,6094 primary native calls; all pass |
| New sequencer suite |10 methods,3981 calls |
| Independent Python and public-header vectors |1100 exact object-byte vectors, each also native encode/decode |
| New external refusals |678, each with empty stdout and a returned error |
| Direct mutable-value/ownership recovery |30 refusal/fresh-success cycles, plus copies,moves and byte independence |
| Old context and LCU suites |17 methods,2113 primary calls |
| Complete additional frozen comparisons |1611:1010 accept,601 refuse; full stdout/stderr/exit compared |
| New traces |2880, covering every new Mojo consumer call |
| Separate ELF inspection |9 executables,18 tables; no excluded runtime or MD5 function symbols |

Actual public-header objects independently confirm enum1/17, common header5,
configuration43, trigger-body44, completion-body1, member offsets and the
all-ones timestamp initializer on this little-endian host. Cases include every
walking bit in every field, every8-bit index, zero/max/asymmetric/random words,
high-bit unsigned64 offsets/bitmaps, every truncation, trailing/wrong extents,
every unknown8-bit record ID, narrow overflows, absent fields, negative/invalid/
oversized text, uppercase hex and canonical recovery. No model arithmetic runs.

All7705 primary/frozen calls retain complete stdout/stderr/exit in independent
raw files or full run records. The final census independently rereads each
paired output, reconstructs new accepted words with Python struct packing,
joins every new trace to its returned exit, and rechecks actual source and
control hashes. Each new trace contains one observed executable launch and no
observed Hailo open, network connect, ioctl or excluded inference runtime load.
No new consumer launches a child executable. This is an observation of the
bounded tested consumers, not a whole-engine effect proof.

Two development type probes refused unsupported tuple/List syntax and were
never executed. Their diagnostics are retained; the second failed source is
explicitly reconstructed from retained generator/edit history. A header-license
gate stopped before C linking at md5.h; its public-domain dedication/permissive
fallback was inspected before the completed oracle builds. Only declarations
are included: no MD5 implementation or function is linked. An early census
refused incomplete suite results; the final independent census passes after
all results return. No acceptance test failed. Final production/test snapshots
and all linked entries are actual copies, independently hashed.

Raw immutable identities and census:
`evidence/sequencer-action-native-2026-10-23/`. Existing document-drift output
and the nine inherited ledger-schema errors remain byte-identical. The ledger
census gains only the narrowly worded AES-CONTROL-002 entry. No whole-repository
or hosted-CI pass is claimed.

## Remaining required work

These are host control bytes carrying explicit wire intent. No valid physical
index, bitmap, L2 address, arithmetic opcode/register, placement or numerical
program is generated. No raw-context hRPC endpoint is admitted and the Pi's
NNC restriction is unchanged. No device was opened, configured or executed.

Continue actual numerical precision/configuration/packing/placement and
original program upload/activation/results/cleanup under
`TASK_hailo10h_numerical_encoding_sources.md`. Broad ordinary unmodified model
coverage remains100% the fixed target; missing source/architecture/operation
support, including duplicate tied-output semantics, remains required work.
This codec supplies no source-model execution evidence. No DFC, outside model
compiler/machine, vendor-precompiled prerequisite, host LLM forward or inference
proxy is introduced.
