# Direct Hailo backend interface

Owner: AESIR backend orchestration. Caller: canonical `main.mojo` through
`cli/hailo_commands.mojo`. Native implementation: `hailo10h_bridge.cpp` with
HailoRT 5.3.0 GenAI. This route requires a physical Hailo-10H and an explicit
compatible artifact; it has no alternate inference backend.

`Hailo10HSession(path)` owns a noncopyable native session. `generate(prompt,
max_tokens=128, timeout_ms=60000)` returns complete validated UTF-8 text.
`describe()` returns a JSON object with observed identity/context/status, the
opened artifact's SHA-256/size, and declared template reserve.
`clear_context()` explicitly starts a fresh
conversation. `close()` is idempotent; the destructor also releases ownership
on exceptional exit.

The C ABI uses numeric `uint64_t` session IDs. Each operation acquires a shared
owner; close removes future lookup access while active calls retain lifetime.
All pointers supplied to this ABI must address their stated writable/readable
span for the complete call. Public functions are:

- `aesir_hailo10h_open(path, handle_out, error, error_capacity)`.
- `aesir_hailo10h_generate(handle, prompt, max_tokens, timeout_ms, text_out,
  byte_length_out, error, error_capacity)`.
- `aesir_hailo10h_describe(handle, output, output_capacity, error,
  error_capacity)`.
- `aesir_hailo10h_clear_context(handle, error, error_capacity)`.
- `aesir_hailo10h_close(handle)`.
- `aesir_hailo10h_free_text(text)`.

Status zero denotes success. Native failures return a nonzero Hailo status or
negative adapter status and an explanatory bounded NUL-terminated error.
Failed generation initializes text and length outputs to null/zero. A
successful text buffer must be released once with `free_text`; the Mojo owner
does this automatically after copying its complete byte span. Description
uses an 8 KiB caller buffer and reports overflow; optional CLI diagnostics
never suppress a completed answer.

Calls within a session are serialized. A completion-read timeout aborts the
request before restoring previous completed context, or clearing empty
context. Requests are not automatically replayed. Failed abort requires
session reopen; failed context restoration requires explicit reset/reopen.
Loading, submission, abort and restoration use HailoRT's own timing behavior,
so `timeout_ms` is not a deadline for the whole request lifecycle.

Resource admission: model paths contain 1..4095 bytes; prompts contain at most
1 MiB of UTF-8. Positive generation settings must fit UInt32. The loaded
model's actual context capacity, device-tokenized prompt length, requested
output budget, current usage, and a declared 64-token template reserve must
fit before submission. This qualified profile's capacity is 2048, regardless
of the upstream training model's larger advertised context.

Evidence: `docs/HAILO10H_SLICE_134_READINESS.md` through
`docs/HAILO10H_SLICE_137_CLI.md`. Full model quality, all failure recovery,
concurrent performance and additional host/platform support are not implied.
