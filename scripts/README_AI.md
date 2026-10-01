# Aesir build, deployment and verification tooling

These Python programs prepare, launch or independently test the native Mojo
engine. They never supply model inference or substitute Ollama answers for
native execution. launch.py owns the frozen offline build/checksum gate.
second_brain_service.py validates an explicit policy and registered model through
that gate and the native settings preview, then writes one new user-systemd unit.
It refuses overwrites, does not create or disclose keys, and does not enable the
service itself. second_brain_service.json owns this deployment's bounded policy.
Linux/systemd is the only exercised deployment target.

benchmark_second_brain.py is an opt-in actual-socket comparator. Run it after all
other GPU tests have ended. Preserve raw samples, include warmup and all failure
results, and distinguish KV cache formats/prefix reuse from full numerical parity.
Its output uses exclusive creation; choose a new filename for each experiment.
See ../docs/SECOND_BRAIN.md for commands and the exact measured support boundary.

benchmark_native.py measures an explicit binary in an owned authenticated
process. Reports retain its hash, actual capabilities, replies, all timings and
failures. --no-prefix-cache distinguishes fresh prefill from repeated prefixes.
Run measurements while other GPU tests are idle. It owns its temporary process
and key, not the supervised deployment. See ../docs/NATIVE_PERFORMANCE.md.
