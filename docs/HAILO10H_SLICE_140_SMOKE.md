# Slice 140 — real direct-backend acceptance

Passed on this Pi 5 / Hailo-10H on 2026-10-19. The canonical Mojo executable
and in-process C++ bridge execute HailoRT GenAI directly. The repeatable runner
from slice 139 completed all three subprocesses successfully, with no timeout.

| Observation | Measured result |
|---|---|
| Physical device | HAILO10H, `0001:01:00.0` |
| HailoRT / firmware | 5.3.0 / 5.3.0 |
| Model | Qwen2.5-1.5B-Instruct compiled Hailo artifact |
| Model size / SHA-256 | 2,464,582,493 bytes / `0856a10c2b804cfe1590b80aa5e28369eb7169a9b36de836420a0b8cdf5b8d05` |
| Context capacity | 2048 tokens |
| Fresh arithmetic | `5.` for 2 + 3 |
| Persistent context | 0 → 73 → 108 tokens; word `ember` recalled |
| Oversized prompt | Explicit `ContextCapacityExceeded`; context unchanged at 108 |
| Recall after rejection | `ember` recalled; context grows to 142 |
| Explicit reset | Context returns to 0 |
| Generation after reset | `5.`, usage 46 |
| Final C ABI / CLI / lifecycle checks | 12/12 pass, no skips |
| Mojo exception ownership | Native session released; repeat close safe |

The runner independently fingerprints model bytes before execution and
rechecks source, binary, bridge, profile and model after all requests.
The tested local commit `1436200dcd2f1906e1bf6c448f8855ab9958ab9d` and
published slice-139 commit `d5625694ae248def914a215985bd4fc94961925a`
have identical Git tree `da769003c42dcccd82254176d5a337d7c8125996`.
The API publication was used because the shell's active GitHub identity did
not have push permission; Git settings and credentials were not changed.

Public machine-readable evidence:

- [Receipt and original raw-artifact digests](evidence/hailo10h-140-2026-10-19/receipt.json)
- [Actual responses and context transitions](evidence/hailo10h-140-2026-10-19/transcript.json)
- [Boundary/lifecycle output](evidence/hailo10h-140-2026-10-19/boundary-tests.txt)
- [Mojo cleanup output](evidence/hailo10h-140-2026-10-19/mojo-lifetime.txt)

The public transcript omits only the machine-specific model-path field. Raw
stdout/stderr, process metadata and public inputs remain in the original local
evidence directory; their content digests are preserved in the receipt.

Both exact word-only recall instructions failed: the model added explanatory
phrasing. A max-token completion also retained a stop-token spelling. Recall
and lifecycle checks pass; these results do not establish strict formatting or
general model quality. HailoRT identity and completion support device execution
under its GenAI API contract; independent per-layer utilization is not claimed.
The recorded process durations include model loading and orchestration, so
they must not be quoted as decode throughput or time to first token.

The remaining roadmap begins at slice 141. Broader artifact/runtime/platform
compatibility, quality, cancellation, performance, packaging and release gates
remain open.

Hosted push CI for slice 139 [failed in run 39314556676](https://github.com/hrabanazviking/RuneForgeAI-Project-Aesir/actions/runs/39314556676):
four historical `test_inference.mojo` calls omit `enable_gpu_realm` from
`validate_runtime_backend_config`. Those source files are unchanged by this
continuation. This failure remains an open integration/release gate; the
physical smoke does not override it.
