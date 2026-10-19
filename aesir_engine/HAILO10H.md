# Æsir direct Hailo-10H inference

The canonical `main.mojo` dispatches `run`, persistent `chat`, and `hardware`
through `cli/hailo_commands.mojo` and `Hailo10HSession`. The narrow C++ bridge
owns an in-process HailoRT GenAI session. Model inference executes on the
physically identified Hailo-10H. An explicit compatible artifact is required.

## Build and use

From the repository root, with the qualified Mojo and HailoRT toolchain:

```sh
bash scripts/build_hailo10h.sh work/hailo-build
work/hailo-build/aesir run --model-path "$AESIR_HAILO_MODEL" \
  --max-tokens 32 --format json --prompt "What is 2 plus 3? Reply with only the number."
work/hailo-build/aesir chat --model-path "$AESIR_HAILO_MODEL" --format json
work/hailo-build/aesir hardware --model-path "$AESIR_HAILO_MODEL" --format json
```

`AESIR_HAILO_MODEL` names the operator's installed artifact; model bytes remain
external to source control. Chat supports `/info`, `/clear`, `/help` and `/bye`.
The direct build avoids the historical CPU/CUDA import graph. Successful builds
publish a matched executable/library generation; model availability does not
require a proxy service.

## Current qualified evidence

The [slice-140 physical acceptance](../docs/HAILO10H_SLICE_140_SMOKE.md) passed
on Pi 5 with Hailo-10H `0001:01:00.0`, HailoRT/firmware 5.3.0, and the
2,464,582,493-byte Qwen2.5-1.5B-Instruct compiled artifact whose SHA-256 is
`0856a10c2b804cfe1590b80aa5e28369eb7169a9b36de836420a0b8cdf5b8d05`.
Canonical inference returns `5.` for the arithmetic prompt. Persistent recall,
context-overflow refusal without history mutation, reset-to-zero and post-reset
generation pass. Final boundary/lifecycle checks pass 12/12 and Mojo exception
cleanup releases the native session.

Responses disclose observed device/runtime/model identity and completion state.
Model fingerprints bind the opened artifact inode; ordinary file changes during
hash/load are rejected. Special-file admission is nonblocking and requires a
nonempty regular file before device creation. The
[interface](HAILO10H_INTERFACE.md) defines ownership, buffer and recovery rules.

## Remaining gates

The qualified capacity is 2048 tokens with a declared 64-token template reserve.
Generation is greedy. Exact word-only recall formatting fails on the recorded
public prompts; a max-token response may retain a stop-token spelling. These
smoke checks do not establish general quality, decode throughput, per-layer
telemetry, device-removal/cancellation recovery, additional model/platform
support, deployment packaging or full-roadmap release acceptance.
