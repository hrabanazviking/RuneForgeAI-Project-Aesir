# Slice 135: owning Hailo sessions and complete text buffers

Completed 2026-10-12. Native handles are registered numeric IDs with shared
ownership during each operation. An invalid or closed ID returns an explicit
error instead of being dereferenced as a pointer. Close removes the handle and
allows existing operations to finish before releasing the model/device.
Repeated close is idempotent. Every exported operation contains its native
exception boundary.

The Mojo `Hailo10HSession` has an automatic destructor, and its explicit close
zeros the local handle. Completed responses use an allocated native byte span
with a matching release owner; the caller copies and validates the complete
UTF-8 text by reported byte length. There is no fixed 64 KiB response buffer.

## Evidence

- Built native code with all compiler warnings treated as errors and built
  the real Mojo caller against that bridge.
- Ran `tests/test_hailo10h_boundary.py` with the real library, canonical CLI,
  and explicit model artifact: 11 test methods passed, including 16 CLI
  rejection subcases and real device open/describe/close/stale-handle checks.
- Built and ran `aesir_engine/tests/test_hailo10h_lifetime.mojo` on hardware.
  After a request exception, the native handle was no longer present in the
  same process; repeat close returned success. No LLM arithmetic was needed
  for this cleanup check.
- A real 32-token Hailo request asking “What is 2 plus 3?” returned
  `5.<|im_end|>`. Its live context usage was 46 of 2048 tokens. This confirms
  native response bytes survive the wrapper correctly; it is one arithmetic
  example, not a quality evaluation. The end marker remains to be formatted
  according to the model's stop-token contract.

No mocks, CPU LLM inference, or inference proxy was involved. The next slice
adds explicit abort/context recovery after a generation timeout; that recovery
is not claimed by this ownership result.
