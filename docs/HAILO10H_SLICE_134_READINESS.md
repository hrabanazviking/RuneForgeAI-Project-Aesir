# Slice 134: live device and model readiness

Completed 2026-10-12 on the attached Pi. The direct AESIR bridge now identifies
the physical device and requires exactly one Hailo-10H before `LLM::create`.
Unsupported hardware cannot proceed into model loading. HailoRT status names
accompany numeric errors.

Built the bridge with `g++ -std=c++17 -Wall -Wextra -Werror -fPIC -shared`
against the installed HailoRT 5.3.0 headers/library. A native readiness check
opened the matching Qwen2.5-1.5B-Instruct artifact, queried live model/device
state, asserted the Hailo architecture and empty initial context, then closed
the session. It reported:

```json
{"backend":"hailort-genai","architecture":"HAILO10H","device_id":"0001:01:00.0","runtime_version":"5.3.0","firmware_version":"5.3.0","context_capacity":2048,"context_usage":0}
```

`aesir_hailo10h_describe` exposes this evidence to the Mojo caller. Device
identity and context values come from HailoRT queries; they are not model
filename assumptions. This slice loads the accelerator model and verifies
readiness; it does not establish generation quality, throughput, recovery,
or a general custom-model compiler. Hardware access required execution outside
the desktop sandbox because the sandbox hides the device node.

API sources: installed `/usr/include/hailo/device.hpp`, `vdevice.hpp`,
`hailort.h`, and `genai/llm/llm.hpp` from HailoRT 5.3.0. The next slice gives
this session automatic cleanup and safe handle lifetime.
