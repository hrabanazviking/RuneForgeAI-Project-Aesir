# Original configure and stream RPC wire codec

Date: 2026-10-20. Contract: `TASK_hailo10h_configure_rpc_codec.md`.
Published field/receiver facts:
`HAILO10H_NUMERICAL_ENCODING_LEADS_2026-10-20.md`.

Original `hailbru/hrpc_configure.mojo` exposes owned stream/configuration values,
a plain-stream constructor, action4 request construction and typed handle/queue
reply decoding. It reuses original Aesir frame/protobuf primitives, with no
HailoRT/protobuf production dependency and no external implementation copied
or translated. The native diagnostic only prints/inspects frames.

Every public stream field is carried: UTF-8 name, format order/type, two raw
fixed32 float words and three unsigned NMS limits. Raw words preserve negative
zero, infinity and NaN payloads without evaluating floats. The plain constructor
explicitly sends binary32-1 and unsigned all-ones NMS unset sentinels; implicit
proto3 zeros would instead request NMS settings. A raw stream descriptor carries
exact caller values. Empty stream lists retain model defaults; each supplied
stream name must be nonempty and valid UTF-8. Embedded NUL is retained as wire
metadata and never passed to a syscall. Duplicate names within a direction
reject; the same name across input/output directions is allowed.

Nested zero handles preserve presence; all-ones invalid handles reject. Batch
zero-auto and0..65535 match the public C++ structure. Power/latency/format values
are carried as uint32 wire metadata, not hardware-qualified enum selections.
In particular host FLOAT32 format type3 does not certify device FP32 math.
Exact constructed bodies cannot exceed the observed2048-byte frame bound;
lengths are checked before copying children. No accepted option is dropped.

Reply parsing checks expected action/message/status, one required nested handle,
optional uint32 queue default0, exact known wire types, duplicates, truncated/
overflowed varints and lengths. Supported unknown wire fields skip under the
existing reader; group wire types reject. A zero queue is a protocol default,
not proof of a usable configured model or physical resource ownership.

## Acceptance

Final warning-free Mojo1.1.0 build and independent frozen-schema checks:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/hrpc_configure.mojo -o ../hrpc-configure-clean
python3 tests/test_hailo_hrpc_configure.py --binary ../hrpc-configure-clean --schema ../hailort-v530-study/rpc.proto --enum-header ../hailort-v530-study/serializer.hpp --protoc /usr/bin/protoc --strace /usr/bin/strace --evidence docs/evidence/configure-rpc-2026-10-20/final
```

Eight methods/83 native calls pass (36 accepted,47 refused). Independent classes
from the frozen public schema/protoc3.21.12 and installed protobuf6.33.6 compare
whole request packets, all stream fields, default presence, exact NMS sentinels,
UTF-8 bytes versus characters, embedded NUL, raw float words (including a
signaling-NaN word), exact2048/2049-byte bounds and returned-frame independence.
Reply tests cover default/max handles/queues, order-independent known fields,
supported unknown fields, malformed/duplicate/overflowed fields, wrong wire
kinds and correlation/action/status failures. The read-only trace opens no
Hailo/CUDA/HailoRT/ggml path and performs no ioctl. Initial accepted runs and
build warning evidence are preserved; unused variable initializations were
removed before the final warning-free build and complete rerun.

Rebuilt program codec: eight methods/140 calls pass. Rebuilt device codec:
ten methods pass. No physical backend regression is claimed by these host
checks. Evidence: `docs/evidence/configure-rpc-2026-10-20/`, including frozen
schema/header/descriptor hashes, action enum, oracle versions and licenses.
No generated schema/library or vendor code is shipped. Hosted master CI still
has its separately recorded legacy compile failure; this is targeted acceptance.

## Remaining compiler and physical gates

Frames own copied bytes, not live configured handles. There is no program
transfer or device configure/activation consumer in this slice. Immutable
original program bytes, complete target/container metadata and checksums,
actual numerical CCW/register encoding, precision/packing/placement, bounded
submission and first real arithmetic result/cleanup remain required.
`TASK_hailo10h_program_integrity.md` contracts the next original writer gap.
All inspector hardware/execution flags stay false. Broad ordinary-model support
remains the target; no DFC, external compile host, inference proxy or specially
compiled model becomes a prerequisite.
