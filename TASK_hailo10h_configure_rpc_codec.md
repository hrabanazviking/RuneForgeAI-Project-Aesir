# Original configure and stream parameter RPC codec

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_program_delivery.md`.
Controlling scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Facts: `docs/HAILO10H_NUMERICAL_ENCODING_LEADS_2026-10-20.md`.

Consumer: future HAILBRÚ original-program configure/lifetime owner. Implement
owned stream/configuration values, exact action4 request body and typed reply
handle/queue decoding from the pinned public protobuf schema. Include every
stream field, retain exact fixed32 float representation bits and use explicit
-1 NMS sentinel values for the plain-stream constructor. Preserve nested zero
handles and batch zero auto; enforce16-bit batch range, uint32 wire ranges,
valid handles and the existing observed2048-byte frame body bound. Duplicate
stream names within each direction, malformed known reply fields, duplicate
fields, wrong correlation/action/status, truncated/overflowed lengths and
unknown unsupported wire types must reject. Unknown supported fields may skip.
No accepted option may be dropped; serialization is not hardware admission.

Use the original project frame/protobuf helpers, no vendor/protobuf runtime.
Construct independently from field facts; do not copy/translate external code.
Verify exact requests against frozen-schema generated protobuf, including all
NMS fields/sentinels, zero/maximum ranges, multilingual/embedded-NUL names,
negative zero and raw float words, exact body limits, defaults/presence,
mutation/ownership/error cases and existing program/device codec regressions.
Record the actual oracle versions/licenses/hashes before use.

This slice has no device/syscall/program transfer/configure/run consumer and
no LLM or layer evaluation. All physical ownership/submission/activation gates
remain open. It cannot supply missing arithmetic CCWs or justify a precompiled-
model/outside-compiler requirement. Publish verified narrow host bytes and
continue actual compiler/configuration/transport gaps automatically toward the
same broad ordinary-model execution target.
