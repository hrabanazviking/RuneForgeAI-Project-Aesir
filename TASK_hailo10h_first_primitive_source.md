# Mojo-authored first arithmetic compiler input

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_program_delivery.md`.
Published format facts: `docs/HAILO10H_FIRST_PRIMITIVE_SOURCE_FACTS.md`.

Consumer: a future licensed compiler experiment for the first Aesir-generated
arithmetic operation on Hailo-10H. Implement an original pure Mojo ONNX Add
fixture emitter using only the published protobuf field facts, with two
FLOAT inputs and one output of static shape [1,1,1,N], IR 8/opset 17, no source
weights or initializers. Require positive checked N and explicit host element
bound. Return owned serialized metadata, with no file I/O, tensor allocation,
operator evaluation, foreign runtime dependency or device action. Diagnostic
output must distinguish valid source format from compiler/device acceptance.

Acceptance: independently generated public-schema protobuf/complete-byte
comparison, structural/operator/type/shape/name checks with an official ONNX
test-only checker where available, explicit bound/integer refusals, repeated
determinism and returned ownership. Record test dependencies/licenses before
use; keep external/generated sources outside Git. Produce a small original
N=16 fixture artifact for concrete review. Do not run a model/layer/attention
or CPU/CUDA/cloud/proxy LLM inference path. No DFC invocation or installation,
model/artifact download, program upload, activation or hardware write in this
slice. Tiny isolated Add test data/math would remain test-only primitive scope.

This is an original source graph, not a numerical Hailo program or inference
completion. A licensed compile resource, device numerical/quantization/layout
acceptance, original output identity, bounded owned upload/configure and real
hardware result/cleanup remain required. A potential primitive-kernel route
must preserve broad source-model compilation/execution and Mojo ownership;
it cannot restrict the product to vendor-precompiled model compatibility.
Publish verified work then continue actual numerical program work automatically.
