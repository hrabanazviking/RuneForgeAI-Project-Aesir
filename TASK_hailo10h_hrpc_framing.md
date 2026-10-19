# Mojo integrated-device RPC framing

Date: 2026-10-19. Status: implemented; native and independent wire/API acceptance pass.
Parent objective: `TASK_hailo10h_mojo_model_execution.md`; the owner target
remains source models on Hailo-10H through Mojo, without a precompiled-only
model restriction.

## Evidence and experiment

The historic raw firmware mailbox failed. Pinned HailoRT v5.3.0 source
`d503417f2a0db186a838390fb08690c4ea0f415e` instead routes host device
identification through `DeviceHrpcClient`, a PCIe `Session`, an RPC frame and
typed request payload. Its frame protocol is separately visible in
`hailort/hrpc/rpc_connection.hpp` and `.cpp`: five 32-bit fields with a
2048-byte maximum body. The pinned MIT license was read before source study.
This is a concrete alternate transport lead, not compute-encoding proof.

Implement an independently written, bounded pure-Mojo frame codec in
HAILBRÚ, consumed by a real native SMIÐR frame-inspection tool and focused
tests. Extract protocol facts only; do not copy or translate vendor code.
The tool accepts recorded hex frames, exposes IDs/status/body and rejects
invalid framing. It performs no device access or LLM inference.

## Scope and acceptance

- Encode/decode the pinned little-endian five-word envelope and preserve
  opaque payload bytes exactly. Accept all UInt32 IDs/statuses without
  inventing meanings for unknown action values.
- Enforce magic, complete header/body, declared maximum, exact packet length,
  and an explicitly selected fixed-size padded DMA-buffer mode.
- Keep body and padding separate; no unknown padding bytes become payload.
- Validate through independent Python `struct` wire vectors, boundary lengths,
  malformed/truncated/oversized packets, nonzero remote statuses and native
  encode/decode parity. Structural tests do not prove a device round trip.
- Build the native tool on the installed Mojo 1.1.0 environment. Serialize no
  GPU/NPU work because this slice does not touch a compute device.

Files: `hailbru/hrpc_frame.mojo`, `smidr/tools/hrpc_frame.mojo`, a focused
TEST-ONLY Python driver, HAILBRÚ's API, study/attribution log and a dated
receipt. Use existing error ownership. No dependency additions, OS changes,
driver mutation, model downloads or vendor-precompiled model work.

Completion requires the real tool and focused independent tests to pass,
honest documentation and a verified remote commit. Then automatically begin
the next integrated-device session/request slice. Actual source compilation,
device completion and compute program generation remain required; this codec
alone must not be presented as those capabilities.
