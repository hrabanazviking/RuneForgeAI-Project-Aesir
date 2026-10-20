> **WITHDRAWN — owner clarification 2026-10-20:** Aesir must own broad
> model loading/execution without outside model compilers or specially compiled
> model prerequisites. This experiment is historical only. Active native work:
> `TASK_hailo10h_native_matrix_tiles.md`; owner scope:
> `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

# Original first-operation compiler input

Date: 2026-10-20. Parent: `TASK_hailo10h_program_delivery.md`.

## Current numerical-program boundary

The complete frozen HailoRT source archive at
`d503417f2a0db186a838390fb08690c4ea0f415e` was obtained under its already-read
MIT license. Archive SHA-256:
`8d0b85c85f35c449f1204f8c96bf6647a2074407cc1323b62594d96072e604f5`.
A bounded search of common/include and libhailort/src for CCW header/opcode/
register/address/bit declarations found the known padding unit, opaque
configuration buffers and container pointer/section handling. No arithmetic
CCW/register encoding was established. Third-party subtrees were excluded;
this result does not prove no public information exists elsewhere. No source
implementation is copied, no compiled model is opened and no device is touched.

A filename-only search of ordinary local download/project/tool locations found
no Hailo Dataflow Compiler wheel. DFC availability, its separate license and an
appropriate compile host therefore remain unestablished. The owner has been
asked for an existing resource path/name while independent Mojo work continues.
No compiler install, remote provisioning or account/license action occurred.

## Concrete first-operation input

An original tiny Add graph gives a reviewable input for a future licensed
compiler experiment. This would compile Aesir-authored source, with two runtime
inputs; it cannot substitute a vendor-precompiled model for the owner's goal.
Its numerical execution, compiler acceptance, device representation and any
future reuse as a primitive kernel remain unverified. All LLM operations must
still run on Hailo-10H; a tiny standalone primitive oracle is not an LLM forward.

The source format is ONNX. License-first schema study uses ONNX v1.16.2 at
`3bf92c03a9f27eba3bda1e5b9e63ea20ec213557`, Apache-2.0 license read before the
schema/operator interface. License SHA-256:
`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`.
The pinned proto3 schema SHA-256 is
`e0760a581390404923d6b63a497e8daffc1849d42d370aaeb467736da8b151da`;
operator documentation SHA-256
`0b9d72c82d15f9a8d348c8c276e23423e7e9458cdaaa7154cd0928da39c7c263`.
Only format facts are used; external implementation/schema files remain outside
Git and no existing exporter is copied or translated.

### Protobuf fields used by the original emitter

| Message | Relevant field numbers |
|---|---|
| ModelProto | ir_version/int64 1; producer_name/string 2; graph/message 7; opset_import/repeated message 8 |
| OperatorSetIdProto | domain/string 1 (empty default for standard operators); version/int64 2 |
| GraphProto | node/repeated message 1; name/string 2; input/repeated ValueInfo 11; output/repeated ValueInfo 12 |
| NodeProto | input/repeated string 1; output/repeated string 2; name/string 3; op_type/string 4 |
| ValueInfoProto | name/string 1; type/message 2 |
| TypeProto | tensor_type/message 1 |
| TypeProto.Tensor | elem_type/int32 1; shape/message 2 |
| TensorShapeProto | dim/repeated Dimension 1 |
| Dimension | dim_value/int64 1 |

The fixture profile selects IR version 8, standard opset 17, FLOAT element type
1, two equal static `[1,1,1,N]` inputs named a/b and output c, one Add node,
and no initializers/weights/custom operators. Add has standard elementwise
addition semantics; the equal-shape fixture uses no broadcasting. These are
explicit source/test choices, not hardware capability declarations. Require
positive N and an explicit host element bound before constructing metadata.
The emitter evaluates no numerical operator and allocates no tensor payload.

Next original implementation: `TASK_hailo10h_first_primitive_source.md`.
Validate complete bytes with generated public-schema protobuf and a separately
licensed test-only ONNX checker where available. Compiler invocation, actual
program encoding, transfer/activation and the first hardware result need
separate bounded acceptance after a legitimate compilation resource is known.
Continue public CCW/placement work alongside this source-input path.

Primary sources:
[public ONNX schema](https://github.com/onnx/onnx/blob/3bf92c03a9f27eba3bda1e5b9e63ea20ec213557/onnx/onnx.proto3),
[Add interface](https://github.com/onnx/onnx/blob/3bf92c03a9f27eba3bda1e5b9e63ea20ec213557/docs/Operators.md#Add),
[ONNX license](https://github.com/onnx/onnx/blob/3bf92c03a9f27eba3bda1e5b9e63ea20ec213557/LICENSE).
