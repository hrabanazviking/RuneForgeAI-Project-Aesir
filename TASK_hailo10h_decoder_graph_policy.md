# Connect explicit per-layer rotary and output policies to the native graph

Date:2026-10-20. Parent: `TASK_hailo10h_ordinary_semantic_adapter.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Inputs: verified tagged per-file source bindings and owned ordinary layer intent.

Audit and publish the exact API/compatibility/consumer migration contract before
code. Existing DenseDecoderParameters lacks per-layer policy; its GGUF builder
always emits both rotary operations and chooses output fallback from presence.
Cache layout currently requires k_rotary/rope_key in every layer and validates
its position/key operands. This must migrate with NoPE graph support, not become
an accidental model restriction or a fallback inferred from missing names.

Narrow a source-neutral typed mathematical graph builder with explicit owned
per-layer rotary flags, output-weight identity and provenance. The existing
GGUF adapter must supply its existing all-rotary recipe and historical output
selection through a compatibility wrapper, preserving every legacy emitted
field/lifetime/layout gate. Ordinary output decisions must eventually come from
actual config tie semantics, never a missing lm_head heuristic. No numerical
execution or complete ordinary model adapter follows from this typed graph API.

NoPE layers must omit rotary operations and consume actual unrotated Q/K
projection tensors, with correctly recalculated operation/tensor IDs, producers,
last uses and KV aliases. Cache validation must use explicit validated layer
policy: rotary key writer plus checked projection/positions when enabled;
direct checked key projection when disabled. Reject inconsistent policy, writer,
projection, position, shape, alias and lifetime state. Audit all recipe/expanded/
storage/matrix/byte/cache consumers and migrate affected ones atomically.

Keep the owned ordinary config/layer intent and every unresolved modifier;
connecting its mask does not authorize guessed dimensions, source orientation,
rotary component pairing, bias/tie/scaling/window/architecture semantics. Publish
and implement their actual adapters next. Full ordinary source-model execution
still requires actual numerical Hailo encoding/configuration/precision/packing/
placement/upload/activation/results/cleanup. No CPU/CUDA/cloud model/layer/
attention forward, vendor artifact, DFC or outside model compiler prerequisite.

Freeze current inspectors; verify complete old GGUF outputs, independent
structural NoPE graph/lifetime/cache oracles, all relevant refusal/ownership/
bounds cases and every affected compiler regression. Commit/publish, verify
remote heads and automatically continue toward the unchanged broad-model target.
