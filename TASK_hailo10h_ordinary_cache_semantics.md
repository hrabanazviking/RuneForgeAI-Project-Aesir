# Ordinary cache/output and inference-session semantics

Date:2026-10-21. Child of TASK_hailo10h_ordinary_rotary_modifiers.md.
Fixed broad source-model/Hailo-only execution scope remains
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

Continue automatically after activation publication. The original owned
architecture retains use_cache and unresolved source-cache-disabled semantics;
the selected mathematical decoder currently always constructs persistent KV
storage. The pinned ordinary source declares use_cache:false. Do not silently
mark this field handled or claim the current explicit recipe is a complete
ordinary adapter. Source flags, invocation/session choices and actual device
storage have distinct evidence boundaries.

Audit public versioned interface declarations and existing original graph/cache/
storage consumers. Preserve complete raw source fields, original origins, all
unresolved notes, scalar words, selected activation/bias policy and output/head
identity. Qualify cached continuation versus complete-prefix input, cache
export/lifetime and positions/past behavior. Retain unknown/training/rotary/
window modifiers rather than assuming they have no inference effect.

Publish an exact owned session-policy/graph integration contract before code,
including source-versus-invocation provenance, source bounds, legacy complete
output compatibility, persistent/ephemeral KV representation, all consumers and
independent mutation/ownership/refusal/recovery checks. Isolated index/address
and constant primitives are permitted. No model/layer/attention forward, DFC,
external compiler/machine, user conversion, inference proxy or host LLM execution.

Keep missing cache/window/scaling/training/architecture coverage as implementation
work toward broad support. In parallel, continue bounded license-first research
and original work toward actual numerical Hailo configuration/encoding/packing/
placement/program delivery/activation/results/cleanup. Never invent opcodes or
count public API prose or a host graph as device execution/physical fit.
Verify, commit/publish, verify both heads and continue automatically.

Primary public interface for the audit:
[SmolLM3 v4.57.1 public interface](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3).
The parameter and return declarations describe cache return/use and unprocessed
input with past keys/values. They do not prove a physical backend allocation or
all architecture implementation behavior. No external implementation is copied
or translated and no model was instantiated/evaluated in this audit.

2026-10-21 read-only audit and exact API/mode/lifetime/consumer contract:
docs/HAILO10H_DECODER_SESSION_DESIGN.md. Publish before production changes.
Forty-six controls are frozen; source cache return and invocation mode must be
kept distinct. No new execution capability is claimed by this audit/design.
