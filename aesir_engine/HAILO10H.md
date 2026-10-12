# Æsir direct Hailo-10H inference

The Hailo inference entry point is `hailo10h_direct.mojo`. It calls Æsir's C ABI bridge in `hailo10h_bridge.cpp`, which directly owns an in-process HailoRT GenAI `LLM` session. The model's inference pipeline executes on Hailo-10H. This path does not call Hailo-Ollama, a REST service, CPU inference, CUDA inference, or cloud inference.

## Build and run on the qualified Pi/Hailo host

From the repository root:

```sh
g++ -std=c++17 -Wall -Wextra -Werror -fPIC -shared \
  aesir_engine/hailo10h_bridge.cpp -I/usr/include -L/usr/lib \
  -lhailort -pthread -Wl,-rpath,/usr/lib \
  -o work/libaesir_hailo10h.so

mojo run -I . \
  -Xlinker -L"$PWD/work" -Xlinker -laesir_hailo10h \
  -Xlinker -L/usr/lib -Xlinker -lhailort -Xlinker -lstdc++ \
  -Xlinker -rpath -Xlinker "$PWD/work" \
  aesir_engine/hailo10h_direct.mojo -- \
  --model-path /path/to/model.hef --max-tokens 32 \
  --prompt 'Your prompt here'
```

Use a Hailo-10H-compatible GenAI artifact built for the installed HailoRT version. The direct module defaults to the checked-in-worktree artifact path used for the initial smoke run when `--model-path` is omitted. Do not commit large model artifacts into source control.

The C++ bridge is intentionally narrow and exposes only open, generate, clear-context, and close operations. Its mutex serializes calls because HailoRT permits one active generator per LLM. Generation is greedy for the first vertical slice. Error/status details are returned to Æsir; they never trigger CPU fallback.

## Qualified smoke evidence

- Hailo-10H PCI device `0001:01:00.0`, firmware and HailoRT 5.3.0.
- Artifact: official Qwen2.5-1.5B-Instruct, Hailo 5.3.0 artifact; 2,464,582,493 bytes.
- SHA-256: `0856a10c2b804cfe1590b80aa5e28369eb7169a9b36de836420a0b8cdf5b8d05`.
- Built the C++ shared bridge against installed HailoRT headers/library with warnings treated as errors.
- Mojo direct entry point executed on the device and returned `OK.` to “Reply with the single word READY.” with an 8-token maximum.
- The full legacy CLI currently cannot compile under the machine's installed Mojo 1.1 environment because unrelated existing imports require unavailable `std.collections.InlineArray` and `max.gpu` modules. The direct Hailo entry point avoids that import graph; integrating it into the legacy CLI remains follow-up work.
