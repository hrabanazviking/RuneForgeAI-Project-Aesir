# Original source-bound projection bias arithmetic

Date:2026-10-21. Publish before code. Active task:
TASK_hailo10h_decoder_bias_graph.md. Head/bias source binding is published on
both branches379bcbf. Owner scope remains broad ordinary model support with
Aesir-owned internal translation and Hailo-only LLM execution.

## Explicit mathematical policy and graph ownership

Add DecoderBiasPolicy(Copyable,Movable) in smidr/bias_policy.mojo, containing
attention:List[Int], mlp:List[Int], provenance:String, work:Int. Arrays contain
one0/1 flag per layer. Work is positive and no greater than source.policy.work;
logical charge is2*layers+provenance.UTF8+128*enabled_bias_operations, with four
attention and three MLP operations per enabled layer. Admit lengths, positive
layer/source evidence, flags, provenance and all checked charges before copying
or allocating policy/graph state. A unique empty optional policy has empty arrays,
empty provenance and work0. Work is compiler descriptor accounting, not bytes
or execution cost on Hailo.

Keep existing builders and complete output schemas unchanged. New opt-in
build_decoder_semantic_plan overloads take either DenseDecoderParameters or
DecoderGeometry+DecoderScalars, existing DecoderGraphPolicy, DecoderBiasPolicy
and the current query/past/capacity arguments. SemanticPlan retains explicit_bias,
an owned bias_policy snapshot and bias_work; legacy construction retains false,
the unique empty policy and0. Explicit all-zero flags are valid mathematical
policy, distinct from source semantics certification. Both source scalar32/64
paths remain exact; no bias API may round an ordinary source constant.

For each enabled projection, validate and consume its actual tagged rank1 bias
source. Emit add_projection_bias immediately between that linear result and its
mathematical consumers: Q/K/V before rotary/cache/scores, O before residual,
gate before activation/multiplication, up before multiplication and down before
residual. Output aliases use the corresponding attn_q/k/v/output.bias and
ffn_gate/up/down.bias source names. Exact consumed source coverage is retained;
disabled or otherwise unexplained extra sources remain unresolved implementation
work. The policy does not silently derive a bias from an absent tensor.

Input/output shape stays [query,features] or [query,heads,width]. Bias length is
the product of every feature axis after query. For rank3, bias index is
head*width+component, never component alone; for rank2 it is feature. Logical
identity is output[q,feature_axes]=input[q,feature_axes]+bias[flatten(feature_axes)].
All inputs, outputs and bias values have real domain. New activation results have
their own producers and exact last uses; no in-place alias or new KV allocation.

## Original primitive recipe and expanded storage

Lower each add_projection_bias into one add_source_projection_vector recipe
operation with an activation input and a distinct source-vector reference.
Retain complete weight binding, tagged storage and backing extent snapshots.
No epsilon, rotary base, divisor, invented device opcode or arithmetic format is
introduced. The vector's full projection width is recoverable from its source
binding and feature axes. Existing RMS multiply_source_vector semantics stay
unchanged. Expanded source-weight values remain retained references with their
actual rank1 shape; operation source_weight identifies the bias. Keep old JSON
outputs unchanged; explicit bias plans expose a versioned policy/accounting
extension alongside existing scalar metadata.

Validate plan bias state at recipe/expanded/storage boundaries. Reject stray
legacy policy state, policy/work/provenance mutation, incorrect flags/lengths,
missing/extra bias operations, wrong source names/ranks/widths, non-linear bias
inputs, mismatched shapes/products/lifetimes and any raw linear result bypassing
its required bias. Match each enabled source role exactly once. Recompute uses
from operation inputs rather than trusting mutable last_use alone. Preserve all
unrelated graph behavior. PrimitiveRecipes owns a bias-policy/work snapshot;
expanded validation compares it and exactly rederives bias recipes and mappings,
source snapshots, metadata/domains and last uses before hypothetical storage
estimation. Mutated stored and expanded weight references must be rejected.

## Acceptance and continued integration

Freeze all current affected consumer binaries first. Independent synthetic
source fixtures cover all flag combinations, per-layer mixtures, Q/K/V/O widths
including independent source K/V geometry, NoPE/explicit rotary, scalar32/64,
source formats and output ties. Check exact graph order, full-width bias indices,
all producers/consumers/mappings, source byte coverage and recomputed lifetimes/
storage. Isolated single-add primitive oracles use tiny synthetic constants;
never execute a model, decoder layer or attention forward on CPU/CUDA/cloud.

Exercise source rank/width/role, policy boundary/overflow, ownership and retained/
derived mutation refusals; repeated failure recovery and cleanup. Rebuild every
affected entrypoint and compare complete frozen legacy graph/recipe/storage
outputs. Publish verified code/evidence, verify both remote heads and continue
the complete ordinary graph adapter and remaining activation/scaling/window/
cache/training semantics, plus actual numerical Hailo encoding/configuration/
placement/upload/activation/results/cleanup. This source-neutral mathematical
policy is not a complete ordinary adapter, source fingerprint, physical fit,
hardware arithmetic/precision claim or LLM execution. Broad support remains the
target; no DFC, outside compiler/machine or special model conversion prerequisite.
