# Source-model execution research — fixed Mojo target

Started 2026-10-19 under `TASK_hailo10h_mojo_model_execution.md`.

## Purpose and license gate

Understand the device execution and source-graph compilation interfaces needed
for Aesir's own Mojo path. The target is unchanged: source models of the right
size must run on Hailo-10H. Vendor-precompiled catalog selection is withdrawn.
No studied implementation is copied, translated or vendored in this work.

The existing clean-room log records HailoRT's MIT license. Revalidate against
the exact v5.3.0 source license before implementation-source study. The pinned
official runtime revision is `d503417f2a0db186a838390fb08690c4ea0f415e`.
Its actual license path is `hailort/LICENSE`, read and confirmed MIT on
2026-10-19; the historical `hailort/libhailort/LICENSE` path no longer exists
at that revision.

Independent project `l-nmch/hailo-10h-llm-compiler` at
`c870419f7d6315e1277e06a9fa5eadd955b8e1af` has an MIT license, read before
studying its findings. Its author documents a source-checkpoint compilation
experiment. It still delegates device code generation to proprietary DFC and
serves through an excluded proxy, so its implementation is not Aesir's route.
Its independently reported graph/cache/shape findings may inform experiments
without importing those dependencies or substituting its objective.

## Current repository facts

- `smidr/config_gen.mojo` generates deterministic host-side fp16 test payloads
  and a manifest. It does not generate an executable NPU operation.
- `smidr/descriptor.mojo` explicitly records unknown compute encoding with a
  sentinel. Replacing this with invented values would not advance execution.
- Historical H102 failed the attempted raw firmware mailbox path. It did not
  test every integrated-device transport. The later supported API's actual
  completion provides evidence that the device is reachable through another
  path; it does not disclose compute-array encoding.
- H019 separately identifies operation encoding, SRAM placement, data movement,
  scheduling, completion and handshake contracts. These must be investigated
  as distinct interfaces, not one undifferentiated compiler wall.
- Source GGUF/safetensors parsers already exist. The repository's 24-byte
  `aesir_engine/model.gguf` is not a real source-model fixture and must not be
  presented as one.

## Immediate experiments to define

1. Trace the official integrated-device host transport and contrast it with
   the historical mailbox assumptions, initially through source study only.
2. Identify the executable context/configuration boundary and which fields
   have public definitions versus opaque payloads.
3. Use an independently specified small source graph to design the first
   Mojo-generated operation/program acceptance. Prove actual execution and
   output before extending graph or model coverage.
4. Connect existing source-model parsing to the owned compiler representation
   and resource plan, with a real consumer and explicit device-generation gaps.

## Pinned-source transport finding — 2026-10-19

Studied official files `hailort/hrpc/rpc_connection.hpp`, `.cpp`,
`session_internal/pcie_session_internal.cpp`, `hrpc_protocol/rpc.proto`, and
`libhailort/src/device/device_hrpc_client.cpp`. The host-side device create /
identify operations use typed RPC requests over a PCIe session. The RPC
envelope has five 32-bit fields and a 2048-byte body maximum; the little-endian
host profile is implemented independently in `hailbru/hrpc_frame.mojo`.

This gives an alternate control-transport lead to the historical mailbox.
The source-level connection is established; an independent Mojo device
round-trip still needs its own physical acceptance. Framing tests alone
cannot prove it.

The generic infer-model RPC names an executable-container byte length and
transfers those bytes separately. That is a container-loading interface,
not proof that only a vendor catalog model could ever be used. Aesir's
source compiler must produce the actual device program and required metadata;
repacking metadata without valid compute contexts would not satisfy the goal.
Executable contexts / operation encoding remain a separate investigation.

Research findings are hypotheses until their named independent or physical
gate passes. An opaque field is an engineering problem to investigate; it
does not authorize changing the target or declaring success.

## Primary references

- [Official HailoRT pinned source](https://github.com/hailo-ai/hailort/tree/d503417f2a0db186a838390fb08690c4ea0f415e)
- [Independent author's source-compilation report](https://community.hailo.ai/t/i-compiled-an-llm-for-the-hailo-10h/19685)
- [Independent research revision](https://github.com/l-nmch/hailo-10h-llm-compiler/tree/c870419f7d6315e1277e06a9fa5eadd955b8e1af)
- Existing H019/H102/H105 evidence in this repository, retained as dated results.
