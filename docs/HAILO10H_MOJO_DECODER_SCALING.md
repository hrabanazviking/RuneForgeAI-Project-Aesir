# Original owned default/linear rotary scaling compiler integration

Date:2026-10-21. Exact pre-code contract0b6b8d0 was published before production
changes. Design:docs/HAILO10H_DECODER_SCALING_DESIGN.md. The broad ordinary-model
target and Hailo-only LLM execution remain fixed. This is selected mathematical
compiler support; complete source-model execution remains open.

## Original source and semantic ownership

DecoderScalingPolicy owns kind, factor:ScalarWord, source/invocation origin,
UTF8 provenance and work. Its exact logical charge160+UTF8(kind/origin/provenance)
is checked with remaining-budget arithmetic before policy copies. default requires
exact unity; linear requires a finite positive factor, including explicit factors
below1. Binary32 upper bits are checked; source factories preserve binary64 words.
Factor representation is independent of theta/epsilon representation. No silent
narrowing or factor-sized allocation is introduced. The optional empty state is unique.

The source projector validates the complete original architecture and preserves
all raw/default/dormant/unresolved facts. Absent and null scaling have distinct
origins. Qualified legacy type precedence retains the original modern/legacy
conflict. Selected default retains dormant factor/custom fields in the original
source; selected linear parses a positive source factor. Unknown variants remain
required implementation, never permanent model eligibility restrictions. External
constructor warnings do not certify model validity. Training/pretraining_tp and
other unresolved architecture facts remain visible. No source normalization or
special model conversion is required.

New typed/scalar builder overloads retain independent scaling/session/window/
bias/activation/graph owners. Each enabled source Q/K rotary operation binds
kind and exact factor independently of its policy. NoPE layers retain no rotary
source operations. Shared guards reject changed flags/factors/kinds/origins/work,
wrong source roles, counts, producer/edge/shape/product/storage/lifetime changes,
bypasses and stray metadata before relevant compiler consumers use them.

## Original mathematical recipe and storage

The existing explicit adjacent/split_half basis and real rotation/partial-tail
assembly remain unchanged. Default retains13 operations. Linear inserts exactly
one real-vector rotary_frequency_scale division before angles, including at
factor1:frequency(j)=theta^(-2*j/d)/factor. Positions remain integer-domain and
attention multiplier is1. These are abstract mathematical operations, never
Hailo instructions or a host attention executor.

Recipe/global state retains selected kind/factor words and exact source maps,
domains, local/global products, result mappings and recomputed lifetimes. Unused
weight/extent/storage/epsilon/window metadata must remain empty. Expanded storage
charges the extra ephemeral real[pairs] vector at the existing hypothetical
activation width. Factor is metadata, not a phantom source/device buffer. Default
retains complete old topology and storage. Cache modes/exports, windows, source
projection weights and exact epsilon/base words remain intact.

Only explicit schema7 serializes new policy/source/recipe/global factor metadata.
Complete older outputs remain unchanged. The new source inspector retains the
complete original owner and reports ordinary_model_admitted false and
device execution unverified. Existing constructors/overloads preserve positional
calls through optional trailing metadata. An explicit scaling plan needs an
explicit rotary basis for lowering; no basis is guessed.

## Targeted local acceptance

Final24 suites/161 methods/6387 native child calls pass. All64 entrypoints rebuilt
with zero diagnostics from one unchanged197-Mojo-source snapshot;65 verification
input identities are unchanged. New7 methods/932 calls include300 accepted and
632 expected refusals. All560 explicit mutation cases refuse across both scalar
paths/session modes/return flags. Native source/default/legacy/modern policy,
exact32/64 factor/base/epsilon words, all-NoPE/mixed/all-enabled patterns, both
bases, partial tails and large unallocated context capacities are covered.

Sixteen complete frozen GGUF/eight ordinary default comparisons preserve prior
outputs after removing only new explicit schema/scaling descriptors. Every
local/global mapping/domain/lifetime and hypothetical storage timeline/peak is
independently rederived. All prior154 methods/5455 calls remain passing.
Eight ownership traces cover160 refused-to-fresh-success cycles. Root/config/
weight descriptors each open43/close43 per trace, source bytes remain unchanged,
reads stay in admitted headers, no payload mmap and no device/inference-library
access occurs. Complete source/binary/input/log/run/trace/negative/preliminary
identities are retained under docs/evidence/decoder-scaling-2026-10-21.

The pinned48-case/120-word external Float32 constants and an independent
high-precision real formula qualify selected metadata/mathematics only. No native
frequency/activation, layer/attention/model forward or device numerical execution
is claimed. The isolated oracle is not a production dependency. No external
implementation was copied/translated into Aesir. Initial compile argument/copy
errors and a no-op mutation-probe error are preserved separately; corrected
probes and final rebuilt acceptance pass. No preliminary mixed snapshot is
counted as final acceptance.

Whole-repository consistency remains failing:baseline22073/current23254;
all1181 added diagnostics concern retained scaling receipt paths,
with no new nonreceipt issue after Markdown line normalization. Ledger census113
verified/158 unique IDs; nine historical strict-schema diagnostics are unchanged.
Targeted local acceptance passes. No historical-master, whole-repository or
hosted-CI pass is claimed.

## Continuing required work

Dynamic/YaRN/LongRoPE/Llama3/context/partial/attention scaling, architecture and
training semantics, all other formats/operations and immutable source identity
remain required work toward the same broad target. Dynamic constant/context/cache
qualification follows under TASK_hailo10h_ordinary_scaling_semantics.md.

Actual Hailo precision/packing/placement/resource budgets, numerical register/CCW/
configuration generation, original program delivery/activation/results/cleanup
and source-model execution remain open under the numerical-encoding task. No
invented opcodes or hardware writes occurred. Host IR, public research and
hypothetical memory estimates cannot close those gates. No DFC, outside compiler/
machine, precompiled-model prerequisite, special conversion or inference proxy.
Only Hailo-10H performs LLM execution. Continue automatically after publication.
