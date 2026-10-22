# Original nondefault LCU control serialization

Date:2026-10-22. Pre-code TASK_hailo10h_lcu_action_codec.md published7724738.
Qualified MIT public fields:HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md.
Production is original Mojo. No vendor implementation is copied or translated.

smidr/lcu_actions.mojo adds an owned seven-scalar LcuAction with independent
validation,encoding and decoding. Qualified IDs4,5,36 preserve complete public
packed records of13,6,11 bytes. Scalar widths,exact extents and reserved bit7
are validated before narrowing or reading. Absent disable fields and the absent
batch-switch address must be zero. Nondefault enable remains explicit even if
its completion values resemble another action's defaults. No address/count is
interpreted as a valid physical LCU program or an instruction.

The old four-action module,inspector,ownership probe,Python suite and object
oracle are unchanged. A separate bounded inspector accepts only the new records.
There is no device/syscall/model dependency in the production value codec.

## Targeted verification

- Six zero-diagnostic builds:four Mojo entrypoints,two C++ object oracles.
- Seventeen methods/2113 primary calls:10 new/1869 and7 legacy/244. Primary
  calls include502 C++ header-oracle/layout calls and1611 Mojo calls.
- New456 vectors compare complete bytes against independent Python struct and
  hash-pinned public-header object layouts; each accepted vector is also decoded.
  All128 valid cluster/unit combinations per kind and unsigned boundaries pass.
- New492 expected native refusals cover reserved IDs/packed bits,signed/width/
  absent fields,all truncated/excess extents and malformed input. Direct native
  snapshots and18 mutable-field refusal/fresh-success cycles pass.
- Additional244 frozen legacy calls match every exit and complete stdout;
  135 successful outputs and109 handled-error cases. They are not added to the
  primary-call total. All three frozen executables and pre-code inputs unchanged.
- Seven new syscall traces show zero target-device/network/ioctl/inference-runtime
  access. No model/layer/attention forward or numerical tensor evaluation runs.

Evidence:docs/evidence/lcu-actions-2026-10-22. Exact637 Mojo identities and actual
outside snapshots,reviewed inputs,six binary hashes,logs,case identities,trace
hashes and failure retention are recorded.637 is an identity count,not a build
or test count. The first compile refused a Copyable implicit return; an explicit
move corrected it. That failure remains preserved and excluded from acceptance.

## Remaining work

This closes three host control-record serialization gaps. It does not establish
numerical CCW/LCU instruction encodings,register maps,placement,real hardware
resources,a reachable raw-context hRPC upload,program activation or result/cleanup.
The Pi's rejected NNC-family boundary remains unchanged. Continue the numerical
encoding/public-interface task and original compiler work toward broad ordinary
unmodified source-model support. No DFC,outside compiler/machine,precompiled
prerequisite,inference proxy or CPU/CUDA/cloud LLM execution is introduced.

Documentation consistency still reports23296 historical diagnostics,zero
normalized added/removed lines. Ledger117 verified/162 unique IDs; nine existing
strict schema diagnostics remain. No whole-repository or hosted-CI pass.
