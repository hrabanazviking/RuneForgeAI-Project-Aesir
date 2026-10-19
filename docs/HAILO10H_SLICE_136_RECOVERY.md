# Slice 136: generation timeout recovery on Hailo-10H

Completed 2026-10-12. A read failure calls the Hailo completion's `abort()`;
after successful abort it clears the partially updated model context. The
original request returns its real HailoRT status and recovery outcome. A retry
is a new user request, not an automatic prompt replay. If reset fails, the
session requires an explicit clear or reopen before another generation.

Live check on the same Hailo-10H session, HailoRT/firmware 5.3.0 and the matching
Qwen2.5-1.5B-Instruct artifact:

1. Requested a long explanation with a deliberate 1 ms completion-read
   timeout. HailoRT returned `HAILO_TIMEOUT (4)`.
2. The bridge reported `generation aborted and context cleared`.
3. Live diagnostics showed context usage 0/2048, `needs_reset=false`, and
   `last_completion=read_failed`.
4. Sent “What is 2 plus 3? Reply with only the number.” with a 30 s timeout.
   It returned `5.<|im_end|>` with `last_completion=end_of_generation` and
   context usage 46/2048. The numeric answer passed the independent arithmetic
   check after accounting for the model's reported stop marker.

Diagnostics expose configured stop tokens from the loaded model, allowing
output formatting to follow its real contract. This check proves recovery
from a completion-read timeout on this exact stack. It does not prove recovery
from device removal, driver failure, unsuccessful abort, or all native errors.
The timeout covers reading completions; model loading, submission and recovery
have HailoRT's own timing behavior.

The bridge compiled with warnings treated as errors. No CPU LLM computation,
device reset, driver reconfiguration, or inference service was used.
