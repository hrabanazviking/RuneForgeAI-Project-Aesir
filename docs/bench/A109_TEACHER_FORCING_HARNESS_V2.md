# A-109 — Teacher-forcing harness v2 (Wave 13 opener)

Method (raw-oracle discipline): ONE harness
(aesir_engine/core/teacher_forcing_harness.mojo) grades every
backend through the single entry point tf_grade_rows:
teacher-forcing rank + logit gap on RAW prompts only, using the
banked A-045 arithmetic (core/parity_battery). Bands: rank 1 =
faithful; rank <= 2 with gap < 1.0 = near-tie (faithful band);
else divergence requiring a verdict class. CPU engine vs CPU
comparator only for the A-045 reproduction; a run naming any
other oracle, or no oracle, is rejected by the harness gate
(tf_validate_run) as a comparator artifact (BACKEND_MISMATCH /
NO_ORACLE_BACKEND), never filed as engine divergence.

Template rejection (acceptance clause 2): tf_detect_template
runs inside the harness before any grading. Measured: the bench
driver in template mode (deliberately ChatML-rendered prompt)
printed TF109_REJECTED verdict=TEMPLATE_RENDERED and graded
nothing. Evidence: hidden_files/a109_bench.log.

A-045 reproduction (acceptance clause 1), measured on
purpleraider with the v2 bench driver
(tests/bench_teacher_forcing_a109.mojo), oracle =
stories260K.F16.gguf sha256
57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
(== TF_CPU_ORACLE_SHA pin; verified before and after the runs;
fixtures read from team-03 hidden_files/fixtures):

| Format | Faithful | Near-tie | Divergent | Worst rank | Max gap | Mean gap | vs A-045 |
|---|---|---|---|---|---|---|---|
| F16 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | exact |
| BF16 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | exact |
| Q8_0 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | exact |
| Q4_0 | 27 | 3 | 2 | 3 | 1.5703 | 0.0962 | exact |
| Q5_0 | 31 | 1 | 0 | 2 | 0.0156 | 0.0005 | exact |
| Q2_K | 27 | 3 | 2 | 3 | 1.5703 | 0.0962 | exact (fixture artifact, = Q4_0 bytes, as A-045) |
| Q3_K_M | 29 | 1 | 2 | 5 | 1.3828 | 0.0657 | exact |
| Q4_K_M | 31 | 1 | 0 | 2 | 0.0938 | 0.0029 | exact |
| Q5_K_M | 32 | 0 | 0 | 1 | 0.0 | 0.0 | exact |
| Q6_K | 32 | 0 | 0 | 1 | 0.0 | 0.0 | exact (fixture artifact, = Q8_0 bytes, as A-045) |

All ten measured A-045 rows reproduce cell-for-cell (the
harness also carries the matrix as data; tf_reproduces_a045 is
an exact check and a drifted matrix is caught by unit test).
The 9 IQ-labelled rows stay fixture-limited exactly as in
A-045 (stories260K dims cannot satisfy the 256-value IQ
super-block); IQ is graded on coherence, never token-exactness.
Each bench summary carries an FNV-1a digest; F16 digest
13489300323619257158 reproduced across runs.

Suite: 7 new oracle.tf_* cases in
tests/test_teacher_forcing_harness_a109.mojo; run_all finish
pin 670 -> 677. Full-suite counts in hidden_files/A109_LEDGER.md
and hidden_files/a109_run_all.log.
