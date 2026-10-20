# Integrate primitive recipes into the source graph

Date: 2026-10-19. Contract before implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: a native Mojo compiler pass producing one owned expanded graph from
the source semantic plan and its original RMSNorm/SiLU/softmax recipes. Splice
local primitive values into global deterministic IDs; retain source operation
and local step provenance, exact source epsilon bits/integer width, explicit
real/predicate/index domains and source-weight references. Source norm vector
references are constants, not activation allocations. Preserve aliases to
persistent K/V bases, both residual chains, exported logits and all unexpanded
operations. No host numerical execution or device submission.

Recompute global producers/last uses after splicing. No stale source indices
may masquerade as global values. Validate every mapped edge, shape/product,
constant reference, alias and exported result. Ownership must survive moving
or mutating the input plan without dangling borrowed data. Source file identity,
actual precision/layout and runtime-value preconditions remain explicit gates.

Acceptance: independently construct expected expanded operation order and ID
mapping for tiny source fixtures, check every edge/weight/scalar/domain/shape/
lifetime, compare repeated layers and prefill/decode/cached shapes, and test
malformed mapping/ownership. Preserve prior standalone recipe tests. Only tiny
primitive mathematical oracles are allowed; never execute a source model,
attention/layer or CPU/CUDA/cloud LLM forward.

Follow with checked storage accounting on the expanded schedule, explicitly
charging predicates and constants according to declared policy. The previous
storage scenario remains valid only for its old schedule. Actual device costs,
placement, program encoding, upload/activation and numerical hardware proof
remain open. Publish each verified slice and immediately continue the next.
The broad owner source-model/Hailo-10H target cannot be revised by this work.
