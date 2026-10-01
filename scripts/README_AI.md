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

The optional extended suite and --max-tokens exercise larger public prompts and
sustained generation. compare_native_benchmarks.py requires complete identical
request/reply sequences and actual model/policy identity, recomputes warm medians
and refuses ratios on errors or mismatch. Its synthetic mutation tests prove only
evidence validation. check_dense_normalization.py is an independent standard-library
oracle for physical probe output. See ../docs/NATIVE_EFFICIENCY.md for commands.

benchmark_native.py --prefill-batch 1|4 requests and verifies observed startup
policy. compare_native_benchmarks.py --allow-prefill-batch-change allows only that
declared change while preserving all other policy and complete-response gates.
check_long_attention.py independently verifies the physical CSV with test-only
NumPy 2.4.4. See ../docs/NATIVE_LONG_TOKENS.md for buffer cost and recovery limits.

The optional stress benchmark suite exercises a 3150-token public prompt and
128-token output ceiling at context4096; preserve standard/extended defaults.
