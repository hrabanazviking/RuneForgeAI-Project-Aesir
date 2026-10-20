# Public v5.4 interface delta and remaining numerical gap

Date: 2026-10-20. Contract: `TASK_hailo10h_public_encoding_delta.md`.
Owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Compared frozen v5.3.0 `d503417f2a0db186a838390fb08690c4ea0f415e`
with public v5.4.0 `f51959034a8a49b7ee53cd0034a161faa30352ba`.
Read `hailort/LICENSE` before source bodies; root common headers also explicitly
declare MIT. Source stays outside Git; facts only, no implementation copied or
translated. The exact archive/license and selected old/new file hashes are in
`docs/evidence/public-encoding-delta-2026-10-20/provenance.json`.

## Exact useful differences

| Boundary | Public difference | Consequence for original Aesir work |
|---|---|---|
| Program root schema and context actions | `hef.proto`, `context_switch_defs.h`, and context action declarations/definitions are byte-identical across these two pins. | This release delta does not establish new arithmetic CCW fields, register meanings or physical placement. Existing opaque payload references remain opaque. |
| Program transfer extent | Selected chunks retain original file offsets. The newer transfer helper sizes the destination to the maximum selected chunk end, replacing file-size-minus-local-resource-sizes arithmetic. | A future sparse output transfer must preserve original offsets and checked extent maxima. Removing a local resource cannot justify shifting later resources or shrinking below a retained span. The current original full-envelope constructor does not remove any resources. |
| CCW descriptor padding | When transferred bytes already divide the descriptor page size, padding count is zero. Other remainders need only the distance to the next page boundary. | Do not append a whole extra NOP page to an aligned transfer. This host descriptor padding is distinct from outer-file padding and unknown numerical instruction encoding. |
| Asynchronous CCW readiness | The newer internal resource manager waits for an explicit success/failure completion before syncing CCW section buffers. The LLM receiver signals that event after chunk arrival; failure/shutdown unblocks waiters. | Future original asynchronous delivery needs owned completion/error/cancellation ordering before device consumption and cleanup. This event is an internal object, not a new Pi upload RPC. |
| Generic hRPC program/create/configure | The only `rpc.proto` change is `Device_FetchLogs_Request.should_clear`, bool field 4. Program-size/create/configure fields are unchanged. | Existing v5.3 schema codecs need no invented new action number or numerical payload field. New log-clear behavior is unrelated to source-model compilation. |
| Direct firmware-control protocol | Packed common headers drop flags/sequence; responses use a single status field; fixed parameter-length scaffolding is removed in many controls, and packing changes. | Do not combine newer direct-control layouts with the installed v5.3 path. This does not make that Pi path's unsupported raw firmware control callable. |

The newer host `DeviceHrpcClient::fw_interact_impl` still reports
NOT_IMPLEMENTED. The separate inner device resource manager is not a host
permission or address map. No register, opcode or hardware write was guessed,
and no installed driver/runtime/firmware was changed. No device was opened.

The hash-selected v3 parser branches and 56-byte outer header remain unchanged
in this inspected delta. The new readiness event does not provide an arithmetic
program generator. This is a bounded primary-source result; it does not claim
that no useful specification can ever be found elsewhere.

## Next independent work

Continue the numerical encoding/physical configuration/transport search toward
a valid original first operation. In parallel, broaden Aesir's ordinary-source
input path through a bounded safetensors inventory adapter, starting by auditing
the existing project reader and the licensed public format facts under
`TASK_hailo10h_safetensors_inventory.md`. Preserve the historical reader and CPU
inference guards. Source metadata alone cannot establish hardware execution.
Missing dtype/architecture/shard/lowering coverage remains work toward the full
broad target; it must not become a permanent eligibility rule.

No outside model compiler, DFC, external compilation host, vendor model catalog,
inference proxy or host LLM evaluation is introduced. The target remains
ordinary unmodified source models loaded and internally translated by Aesir in
Mojo, with all LLM execution on Hailo-10H.

Primary public sources:
[license](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/LICENSE),
[program metadata schema](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/libhailort/hef.proto),
[transfer extent and header parsing](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/libhailort/src/hef/hef.cpp),
[descriptor padding](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/libhailort/src/core_op/resource_manager/config_buffer.cpp),
[CCW sync boundary](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/libhailort/src/core_op/resource_manager/resource_manager.cpp),
[hRPC schema](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/hailort/hrpc_protocol/rpc.proto),
[direct-control declarations](https://github.com/hailo-ai/hailort/blob/f51959034a8a49b7ee53cd0034a161faa30352ba/common/include/control_protocol.h).
