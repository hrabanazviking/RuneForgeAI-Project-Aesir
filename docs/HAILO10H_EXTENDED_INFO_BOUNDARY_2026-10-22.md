# Extended-info metadata is not a numerical configuration specification

Date:2026-10-22. Active research contract:
TASK_hailo10h_numerical_encoding_sources.md. The HailoRT MIT license was re-read
before inspecting declarations/receiver boundaries. Six retained files match
exact Git blobs at d503417f2a0db186a838390fb08690c4ea0f415e(v5.3.0).

The public hRPC action DEVICE__EXTENDED_INFO has value23,with a device-handle
request and typed feature/identity fields. This is independent of GGUF source
tag23 IQ4_XS. Neither namespace is a numerical instruction selector.

In the pinned IntegratedDevice path,neural_network_core_clock_rate is explicitly
a deprecated field populated with NOT_AVAILABLE=0. It is not a measured zero
clock and cannot provide an NNC frequency budget. The reply has no arithmetic
instruction,register-placement or allocatable-model-memory description. Under
a Linux conditional,the H10H branch invokes GpioReader().read;that helper's
physical effects have not been qualified here. No live query was made. Public
source behavior also does not identify the exact server binary on this module.

The separate performance-statistics schema contains ram_size_total/used and a
sampling-period request. Those names alone do not prove allocatable NPU model
memory,an appropriate measurement procedure or a compatible callable endpoint.
They must not become physical placement/fit admission based only on the schema.

This bounded source review closes a misleading lead,not the numerical backend.
No new native capability,device access,numerical program or model execution is
claimed. Source evidence and original provenance-selection correction remain in
 docs/evidence/extended-info-boundary-2026-10-22. Continue actual numerical ISA,
configuration/precision/packing/placement/program delivery/results/cleanup work.

Pinned primary sources:
[protocol declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc_protocol/rpc.proto),
[action namespace](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hrpc_protocol/serializer.hpp),
[integrated-device boundary](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/vdma/integrated/integrated_device.cpp),
[license](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/LICENSE).
