# Slice 138: observed response provenance and model fingerprint

Completed 2026-10-12 on the qualified Linux/Hailo profile. JSON responses now
include the SHA-256 and size of the opened model artifact, alongside the
physically identified Hailo architecture/device, runtime and firmware versions,
model context capacity/usage, completion status, and declared template reserve.

The bridge opens a nonempty regular artifact file, hashes it using installed
OpenSSL 3.0.22 EVP SHA-256, and loads HailoRT through that owning process's
procfs descriptor path. The descriptor remains owned for the model lifetime.
File identity, size, modification time, and change time are compared before
and after hashing/loading. A detected change is an explicit retry condition.
This binds ordinary path replacement to the already-open inode; it is not a
claim of protection from every privileged or adversarial mutation.

`/proc/self/fd` loading was rejected by the HailoRT existence check. Naming the
actual descriptor-owning PID in the procfs path resolved that incompatibility
and completed direct generation. This loading mechanism is Linux-specific.

Live canonical CLI result:

```json
{"response":"5.","provenance":{"backend":"hailort-genai","architecture":"HAILO10H","device_id":"0001:01:00.0","model_sha256":"0856a10c2b804cfe1590b80aa5e28369eb7169a9b36de836420a0b8cdf5b8d05","model_size_bytes":2464582493,"runtime_version":"5.3.0","firmware_version":"5.3.0","context_capacity":2048,"context_usage":46,"last_completion":"end_of_generation"}}
```

The fingerprint matches the independently computed artifact digest retained
from the first qualified transfer. The response came through the canonical
AESIR executable, using the exact descriptor-backed artifact. Native code
compiled with warnings treated as errors, and the Mojo executable built.

Device identity, versions, context and stop tokens come from runtime queries.
The model fingerprint/size come from file operations. Full LLM-pipeline device
placement is the HailoRT GenAI API contract combined with actual generation on
the physically checked device; independent per-layer utilization telemetry is
not exposed or claimed. No CPU LLM inference, Hailo-Ollama call, package
installation, or OS change was involved. OpenSSL is only a file-integrity
dependency; its license/profile is recorded in the dependency manifest.
