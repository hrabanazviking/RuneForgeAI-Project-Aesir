# Performance measurement tool contracts

Owner: Python supervision/measurement domain. Native inference stays in Mojo.
Other build/operator tools are indexed by [README_AI.md](README_AI.md) and their
linked manuals; this interface owns the new provider and numerical evidence tools.

## benchmark_second_brain.py

CLI `main` reserves one new UTF-8 JSON report before operational work. It accepts
explicit HTTP origins, a local native key file, model/context/output ceilings,
public suite, repeat count, deterministic provider order, residency mode, optional
same-weight blob/PID checks and timeout. Schemas and operations are described in
[the manual](../docs/SPEED_MEASUREMENT.md).

`request` allows credential transmission only to native 127.0.0.1, bounds timeout
and response bytes, rejects duplicate/nonfinite/malformed JSON, and always closes
its connection. `schedule` deterministically covers each provider/case/round.
`sample_reply` validates observed identity, counts/context, completion and provider
reported duration types, retaining redacted decoded responses on failure.
`summarize` refuses ratios on any failure or unequal required output counts;
no result establishes quality parity or a certified lead.

Exit 0 means the declared requests/protocol completed. Exit 1 means failed samples
or setup, with retained evidence. Ctrl-C exits 130 with collected samples. Existing
output paths are never overwritten. Native credentials and production corpus are
forbidden evidence inputs. Provider calls may load/retain the declared Ollama
model; they do not restart managed services, change native policy or write corpus.

## check_llama3_logits.py

`parse_probe` requires the complete strict-3B native CSV schema; `compare_case`
applies the fixed predeclared 0.05 maximum / 0.005 RMS / matching-argmax contract.
`summarize_physical` reports actual-call timing and a conditional logical-traffic
reference against observed D2D bandwidth, not a guaranteed decoder ceiling.

CLI accepts source GGUF plus expected byte hash, CSV, bounded CPU threads, and
one new JSON report. Optional test-only llama-cpp-python 0.3.23/NumPy 2.4.4 own
independent CPU inference on the exact exported input IDs, F16 KV, no flash
attention and zero GPU layers. The native runtime never imports this module.

Optional explicit F32 expansion owns one new derived artifact through the supplied
quantizer and records its hash/exit/logs. It never overwrites an existing destination
or the source. Verified reference reuse requires its own SHA-256 and retained
derivation provenance. Each real reference is closed even after comparison errors.
Exit 0 requires complete physical data and every independent numerical case to
pass unchanged budgets. Exit 1 preserves failure/error evidence and never certifies
numerical support or speed. Unsupported reference versions fail before evaluation.
