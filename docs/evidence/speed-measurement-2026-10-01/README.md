# First SPD-00 measurement evidence — 2026-10-01

This implemented slice adds portable provider measurement and an independent
strict-3B numerical gate. Production inference kernels, original GGUF bytes and
second-brain provider policy are unchanged. All SPD-00 remains open: detailed
kernel/launch/CPU/socket attribution, complete cache/residency isolation, a second
independent provider session and wider numerical/quality coverage are still needed.

Owner: performance scripts and opt-in tests. Consumer contracts and full commands
are in [SPEED_MEASUREMENT.md](../../SPEED_MEASUREMENT.md),
[scripts/INTERFACE.md](../../../scripts/INTERFACE.md) and the test interface.
[provenance.json](provenance.json) lists sizes, SHA-256 identities, schema/storage
boundaries and exact source hashes. These are project-authored public prompts and
measurement records. Model and dependency licenses remain upstream; no model
weights or vendor inference code are redistributed here.

## Installed-service measurements

Each case has one retained first appearance followed by scored repeats. Provider
order alternates per round; both models were observed resident, with Ollama kept
alive for ten minutes. Current native prefix reuse remains enabled. Times are
whole HTTP wall time, and first appearances can still reuse common prefixes.
The series ran serially after GPU probes/compilation stopped. These records cover
84 requests without a failed request or setup error.

| Case / output ceiling | Repeats per provider | First AESIR / Ollama seconds | Repeated AESIR / Ollama median seconds |
|---|---:|---:|---:|
| arithmetic / 32 | 3 | 0.274 / 0.437 | 0.091 / 0.332 |
| passage / 32 | 3 | 1.054 / 0.904 | 0.813 / 0.875 |
| 237-token prompt / 32 | 3 | 3.180 / 1.003 | 0.843 / 0.890 |
| 1070-token prompt / 128 | 10 | 13.627 / 3.311 | 3.689 / 2.920 |
| sustained output / 128 | 10 | 3.818 / 2.815 | 3.414 / 2.739 |
| 1070-token prompt / 256 | 3 | 17.027 / 3.776 | 4.254 / 3.758 |
| sustained output / 256 | 3 | 7.210 / 5.235 | 6.802 / 5.182 |

Read the exact requests, complete replies, counters, telemetry, ordering and
descriptive distributions in [paired-32.json](paired-32.json),
[paired-128.json](paired-128.json) and [paired-256.json](paired-256.json).
Arithmetic is excluded from speed scoring. The long 256-ceiling case reaches
early EOS with different provider output counts (146 versus 167 on first
appearance), so its ratio is null. The other text scoring cases reach their
requested ceiling, but their text/quality parity is not established. A ceiling
is not a promise that a model generates that many useful tokens.

The observed native PID owns the loopback API socket, and its executable hash
matches the validated local binary. Native and local Ollama blob hashes match
`dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff`.
API metadata alone is not an attestation of the runner's loaded bytes. Observed
Ollama runner model basename and q8_0 K/V flags are separately retained in
[ollama-runner-observed.json](ollama-runner-observed.json). Native K/V is F16;
Ollama's chat framing adds 20 prompt tokens in this series. Installed Ollama
reports version 0.0.0. This is the installed comparison, not a claim about every
Ollama release or identical arithmetic/cache/template policies.

The repeated 32-token text subset slightly favors AESIR in this session; 128/256
sustained generation still favors Ollama. One session and three repeats for some
cases cannot certify a lead. No report marks quality parity or a certified lead.

## Independent numerical evidence

The physical probe exports every final-prompt logit and exact input IDs for four
public cases: arithmetic, graph explanation, Unicode and a 1070-token passage.
Each vector contains 128256 values, for 513024 compared values. The predeclared
budget is maximum absolute error <= 0.05, RMS error <= 0.005 and identical
full-vocabulary argmax. The budget was not relaxed after failure.

| Case | Maximum absolute error | RMS error | Native / reference argmax |
|---|---:|---:|---:|
| arithmetic | 0.00841045 | 0.00178439 | 28070 / 28070 |
| graph explanation | 0.00486183 | 0.00103929 | 32 / 32 |
| Unicode | 0.00417709 | 0.00097332 | 32 / 32 |
| long passage | 0.01274157 | 0.00167414 | 791 / 791 |

The complete final comparison passes in [oracle-final.json](oracle-final.json).
CPU llama-cpp-python 0.3.23 / NumPy 2.4.4 independently evaluates the exported IDs,
context 4096, F16 K/V, no flash attention and zero GPU layers. The reference is
test-only; production inference remains Mojo. It uses an explicit F32 expansion
of the original packed weight values, not the production runtime's arithmetic.
The derived artifact is 12,858,837,216 bytes with SHA-256
`b0dd20c95a6605d9773d9d3153c52f89f21628f21048ff81bb184684b6f7a42b`.
Actual conversion hashes/logs and the first successful comparison are retained in
[oracle-f32-derivation.json](oracle-f32-derivation.json). The final repeat verifies
that exact derived hash before use. Preserve the derivation when reusing it.

The initial setup failed because the pinned reference object has no context-manager
contract; the corrected implementation closes it in `finally`. That report is
preserved in [oracle-setup-failure.json](oracle-setup-failure.json). The subsequent
complete same-byte packed CPU comparison failed all four original error budgets,
with matching argmax IDs; see [oracle-packed-failure.json](oracle-packed-failure.json).
Pinned CPU K-quant dot products quantize activations into Q8_K, unlike native F32
activation dots. Expanding packed weight values into F32 avoids that arithmetic
difference without changing production weights or adjusting budgets.
[Pinned CPU implementation](https://github.com/ggml-org/llama.cpp/blob/7d442abf5c6244117fd5a1dc51a5d19f00792491/ggml/src/ggml-cpu/ggml-cpu.c),
[converter implementation](https://github.com/ggml-org/llama.cpp/blob/f8def7fe1/src/llama-quant.cpp).

This proves four final-prompt vectors through 1070 input tokens. It does not prove
every generation position, maximum context, every model/device, bit-exact equality
or useful-output parity with the installed Ollama service.

## Physical timings and conditional feasibility

The final nonuniform-copy probe executed in one owning CUDA context on sm_75
RTX 2060 Max-Q / 6 GiB. It verified all 8,388,611 and 33,554,437 copied UInt32 words
and retained ten samples per span, with ten D2D copies per sample. The larger
span's median aggregate read-plus-write bandwidth is 238.418 GB/s. Actual native
fresh generation has three scored export-free calls per case, with prefix reuse
disabled in the test-owned session. Full-logit export/printing is outside the
two scored intervals.

| Native case | Prefill median seconds | Generation-loop median seconds | Generated tokens |
|---|---:|---:|---:|
| arithmetic | 0.328 | 0.069 | 2 |
| graph explanation | 0.391 | 2.006 | 82 |
| Unicode | 0.355 | 0.945 | 38 |
| long passage | 12.687 | 3.615 | 128 |

The logical active projection span is 2,010,839,040 bytes, plus norms, one
embedding row and RoPE minima; KV unique-head/history accounting adds 114688
bytes per history position. At the observed copy rate, fixed logical traffic
corresponds to about 8.44 ms per decode step before history/compute/launch costs.
This is a conditional roofline reference. D2D copy is not decoder DRAM-counter
measurement, an upper bound on all achievable bandwidth, or a guaranteed speed.

The long fresh native call spends about 78% of its combined measured stages in
prefill. Genuine matrix prefill under SPD-01 is therefore the next optimization
candidate after the remaining SPD-00 controls/trace gates. Repeated sustained
128-output service cost is 3.414 seconds against Ollama's 2.739 seconds: reaching
the roadmap's 2x goal for this case would require about 1.370 seconds including
service/prefill work. The 3x target implies about 141 output tokens/second even
before those costs, above this copy-based fixed-traffic reference of about 119
steps/second. That motivates careful bandwidth measurements and consideration of
less traffic or verified speculative output; it does not prove a physical
impossibility or authorize changing arithmetic before its own numerical gate.

The full authoritative CSV is `native-final.csv`, SHA-256
`5c2c398d5729d01fc82e8f6c773c01b0758b672f1186b319d087d64ac95dad89`.
The earlier uniform-copy CSV is `native-original.csv`, SHA-256
`20a0e381e796a9600b779a616b226952bd62940042e1ffb4fe163872cac9c989`.
Both are retained in the user's local output folder, not Git; the initial failed
and derivation reports identify that original CSV. Git contains all timing rows,
input IDs and oracle metrics in JSON. There is no public download of the full
raw-logit CSVs. Regenerate them with the manual's physical probe command; the
exact output hash depends on real timing. The 12.86 GB derived model and test
binaries remain outside Git.

## Verification and publication boundary

Fourteen real-loopback/synthetic protocol tests and nine CSV/numerical/artifact
contract tests pass; retained output is in [provider-tests.txt](provider-tests.txt)
and [oracle-tests.txt](oracle-tests.txt). The existing four evidence-comparator
tests also pass: [comparator-tests.txt](comparator-tests.txt). Synthetic protocol
responses prove admission/scoring contracts, not model inference. The physical
probe and optional independent reference provide the actual execution evidence.

The counted master rerun passes 187 cases, zero failures, one explicit external
skip, total 188: [master-final.txt](master-final.txt). The first master attempt
failed because its existing socket test bound the active native service's port;
[master-port-collision.txt](master-port-collision.txt) retains that failure. The
test now requests an OS-assigned port in its test-owned sockaddr and verifies it
with getsockname. Production port-zero rejection and service policy are unchanged.
[negative-control.txt](negative-control.txt) confirms the expected nonzero failure.
The final sm_75 release build/check and the opt-in sm_89 probe compile pass.
Repository drift/fixture checks and their regression tests pass; preexisting
legacy artifact warnings remain outside this task. Diagnostic checkout paths are
masked in public logs and source hashes/transforms are listed in provenance.

The production binary SHA-256 remains
`f3442a1e5915cb43ec4da8a0f885ff38710a02b6ef795515dbe1f72c36ceda2b`;
the validated local build and running PID hashes agree. No service restart was
needed; [service-final.json](service-final.json) records observed readiness and
identity. Source hashes and dirty-parent measurement provenance are explicit in the
manifest. Final local gates and exact pushed CI are recorded in the publication
receipt delivered with the user's outputs; hosted compilation alone never proves
GPU execution. This folder does not claim a future CI outcome.
