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

## profile_native_cuda.py / check_cuda_trace.py

The optional capture wrapper owns a separate strict-3B CLI process, exclusive
private artifact directory, explicit prompt/policy and bounded child lifetime.
It checks the launcher/catalog/model digest, observed VRAM and installed tool
identity before GPU operations. Matching complete profiled/unprofiled replies
gate non-mutation. A matching installed importer handles split-package location
failure. No attach, unrelated service stop, installation or permission changes.

`analyze` owns read-only bounded Nsight 2023 SQLite admission. It accepts concrete
tables, one actual CUDA process/device and unique successful launch/kernel
correlations, validates timestamps and emits GPU interval unions and recorded
kernel/API/copy groups. Linux descriptor paths close final-file replacement
races; query-only/authorizer/VM limits prohibit mutable or input-supplied SQL.
API and GPU intervals overlap; uncovered time has no inferred cause. No automatic
prefill/decode or per-layer attribution. See [the operator manual](../docs/NATIVE_CUDA_TRACE.md)
for resource limits, exit codes, artifact privacy and exercised physical scope.
