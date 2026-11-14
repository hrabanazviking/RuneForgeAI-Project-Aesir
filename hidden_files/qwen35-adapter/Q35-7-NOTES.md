# Q35-7 — Gate swap to the 27B + full-suite gate (campaign closing slice)

Worker ran all six Forge roles sequentially in one seat (recon ->
design -> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-q35-7 @ yrsa/q35-7, base f3655d35 (campaign tip:
QC-6/QC-7/Q35-6/F-3b-1 merged). A sibling QC-7 worker was active in
its own tree (records only, already merged at base); never touched.
Services: aesir-gate STOPPED at start (per the coordinator's
license the campaign may stop/start it; Voxta stayed OFF; Ollama
never needed). MemAvailable ~124 GB at start; machine up 7:53
(not freshly booted). One heavy run at a time throughout; heavy
runs fenced in machine-level systemd units.

## Configuration decision (stage 2, on the banked evidence)

The gate serves the 27B in the Q8_0 RESIDENT CPU configuration
(Q35-4b-proven end-to-end: native admission, ~1.5-1.8 tok/s,
31.3 GB class) on :18434. NOT chosen, recorded as named
remaining work: the HIP path (experimental-flagged, ~0.07-0.09
tok/s decode, Q35-6) and the QC-6 Q4_K_M product (packed path
only, no resident-analogue contract). Recon confirmed the
decision; nothing contradicted it.

## Stage 1 — the named preconditions

### F-4b-2 stop tokens (FIXED)
- Root cause: Qwen35CPUSession.next_chunk stopped only on
  tokenizer.eos_token_id (248046, <|im_end|>). The model also
  ends turns on <|endoftext|> (248044) and then free-runs
  control spellings (<|im_start|>...) to the cap.
- Fix (qwen35_session.mojo + mirrored in qwen35_hip_session.mojo):
  the stop set is DERIVED at session init from the model's own
  tokenizer — eos plus every vocabulary entry whose GGUF
  token_type is CONTROL (3). On the real file that is 27 ids:
  eos=248046, stops=248046,248044,248045,248047..248057,
  248060..248065,248070..248076 (independently verified against
  a raw GGUF metadata parse; the type-4 USER_DEFINED entries —
  <tool_call>, <think> etc. — are correctly NOT stop tokens, so
  think blocks in replies are unaffected). A stop token is
  forwarded (committed stream + snapshots stay exact) but never
  decoded into the reply and never counted in generated_tokens
  — the pre-existing eos accounting, generalized. finish_reason
  stays "eos" (the serve maps it to stop).
- Proof (in-process reference, q35-7-ref-turns.log): the Q35-4b
  short-answer shape ("Say the word hello.", cap 8, no system)
  now returns STOPCASE="\n\nhello", generated=4, finish=eos —
  in Q35-4b the same shape served
  'Assistant:\n\nhello<|endoftext|><|im_start|><|im_start|>...'
  to the cap. Served on :18435 and on the gate :18434 the case
  returns '\n\nhello', completion_tokens=4 < 8, finish=stop.

### F-4b-1 reply hygiene (FIXED)
- The raw-continuation surface makes the model generate the
  "Assistant:" role marker as its first text. The trim lives in
  the sessions' presentation path (next_chunk): initial decoded
  bytes are held while they are a proper prefix of a marker
  block — shapes "Assistant:", "\nAssistant:", "\n\nAssistant:"
  (T1/long carry the first, T2 the second; the third is the
  same block with one more newline) — and exactly that block
  is dropped. turn_generated_text is the trimmed text
  everywhere (served reply, snapshot text, resident history),
  so resident/stateless reuse checks stay consistent; bytes
  that merely prefix the marker are flushed verbatim if
  generation ends first. The forward engine is untouched.
- Proof: new reference replies == banked Q35-4b replies minus
  exactly the leading marker block, byte-otherwise-identical
  (bench TRIM PROOF lines for R1/R2/LONG, q35-7-bench-*.log).
  First trim version missed T2's leading-newline shape; the
  bench caught it and v2 fixed it (recorded honestly).
- Comparability note: the Q35-4b reference driver drives the
  session, so it inherits BOTH stage-1 rules — the reference
  is defined with the same stop rule and trim as the serve,
  exactly as the brief allows; the driver also gained a
  standalone `stop` mode + the STOPCASE assertions in turns mode.

### A-119 successor attestation (FILED)
- core/qwen_battery_a119.mojo: A-048's qwen_smoke_status
  account is byte-untouched (still LOAD_FAIL_NAMED_CAUSE).
  Beside it, qwen35_successor_status() files the successor
  row in the battery's own format: qwen35 ->
  REAL_FILE_LOAD_PASS_ADAPTER_RESIDENT; any other arch ->
  NO_FILED_SUCCESSOR_ROW. Header text cites the attesting
  evidence (Q35-3b FAITHFUL grade + Q35-4b resident serve).
  The existing test case test_qbattery_arch_strings_and_smoke
  was extended in place (no new run_all case; the 905 count
  is unchanged) and passes in the full suite.

### /health variant truth (ADDED)
- serve_loaded gains model_variant (default ""), emitted in
  capabilities ONLY when non-empty — the Q35-3r
  weight_load_mode pattern, so other profiles' health bytes
  are unchanged. The qwen35 call sites (CPU + HIP) pass
  plan.variant. Gate health now carries
  "model_variant": "qwen35-27B" beside
  "weight_load_mode": "q8_0_resident".

### Stage-1 regressions (all on this tree)
Engine compile exit 0; Q35-1 loader, Q35-2 registry, Q35-3a
forward, Q35-3r resident, Q35-4a session, Q35-5 snapshot,
Q35-6 HIP session, ripple/admission probe: ALL PASS.
Real-file reference: turns ALL PASS (resident reuse 55,
stateless reuse 55, replies == served), long ALL PASS
(483-token witness, peak RSS 31,506,604 kB). Side-port serve
proof :18435: bench ALL PASS (q35-7-bench-stage1.log).
(First regression pass failed on missing git-ignored fixture
files in the fresh worktree — copied from the campaign tree;
the rerun is the record.)

## Stage 2 — the swap

- Backup BEFORE change: hidden_files/hip-serve/
  aesir-gate-llama3-3b-config-backup-q35-7.txt (the exact
  pre-swap transient-unit configuration).
- VOXTA_SWITCHOVER.md updated: 27B resident = primary,
  llama3-3b = documented fallback with the exact rollback
  steps; context note for the 4096 configuration.
- Fence: serve VmHWM measured 31,616,528 kB on the gate;
  MemoryHigh=48G / MemoryMax=64G (measured headroom ~124 GB
  MemAvailable at swap time).
- Gate command: aesir-gate machine unit, this tree's binary,
  serve <real 27B path> --accel cpu --profile qwen35
  --qwen35-resident --context 4096 --max-tokens 512
  --timeout-ms 900000 --port 18434. (After the coordinator
  merges yrsa/q35-7, restart from the aesir-hipserve tree —
  noted in VOXTA_SWITCHOVER.md.)
- Verification on :18434 (q35-7-bench-gate.log, ALL PASS):
  health profile=qwen35, model_variant=qwen35-27B, backend
  cpu, weight_load_mode=q8_0_resident, session_residency
  true, exact_prefix_reuse true (snapshot detail),
  experimental false. T1 23 prompt / 32 completion / reused
  0, reply == reference; T2 resident reused=55 (== POS1),
  evaluated 10, reply == reference; STOPCASE '\n\nhello'
  completion 4 < cap 8 finish stop; stateless resend
  reused=55 via snapshot, reply == resident R2; LONG 483
  tokens == reference. Served T1 text: '\n\nThe capital of
  France is **Paris**. One of the most famous museums
  located there is the **Louvre**, which is renowned for
  housing masterpieces' (32-token cap cut).
- The gate was stopped twice during stage 3 (suite-isolation
  diagnostics) and restarted in the swapped configuration;
  final state: RUNNING on the 27B, health + one completion
  re-verified after the final restart ('\n\nhello', 4 tokens).

## Stage 3 — full-suite gate

Four fenced runs of scripts/build_matrix.sh amd from this
tree (logs q35-7-suite-run1..4.log + matrix drivers):
- Run 1: 899/905 — failures: the two proven pre-existing +
  hardware.hip_config_gate + resilience.state_vault_rejects_growth.
- hip_config_gate FIXED IN SCOPE: Q35-4a (this campaign)
  added cpu to the admitted-backend error message in
  native_settings.mojo; the HS-1 test still expected the old
  string "auto, cuda or hip". The expectation now reads
  "auto, cpu, cuda or hip" (the true admitted set); the case
  still asserts hip admission + tpu refusal. Passes in-suite
  from run 2 on and standalone.
- Runs 2-4: 900 passed / 3 failed / 2 skipped / 905.
  Remaining failures: gguf.tensor_directory_interface and
  gpu.hip_q4k_gemv_no_leak (the two proven pre-existing;
  their accounts untouched) and
  resilience.state_vault_rejects_growth, dispositioned:
  * the case is a scheduling race by construction — a forked
    child appends one byte per syscall while the parent makes
    up to 500 read attempts and requires one to land mid-growth;
  * standalone (driver_q35_7_cases, both cases only): PASS 3/3
    on a quiet box (q35-7-cases-rerun1..3.log);
  * standalone under synthetic full contention (32 `yes`
    spinners): FAILS 1/3 with the identical message
    (q35-7-cases-load1.log) — the mechanism reproduced;
  * it PASSED in-suite in the pre-campaign baseline
    (hipserve tree build_matrix_amd.log) and fails in-suite
    4/4 today, with and without the gate resident — the
    suite process's own post-800-case thread state starves
    the child within the attempt budget;
  * no vault/resilience code is touched by this campaign
    (the slice diff is sessions, battery, native_serve, one
    test expectation, records).
  Verdict: evidenced contention flake, NOT a product
  regression; the defended close count is 900/905 with every
  failure named. (901 was the count with this case passing,
  as its standalone and baseline results show it does when
  the child gets scheduled.)

## Files

- QWEN35_RESULTS.md (this folder): the campaign results record.
- LEDGER.md head entry + MAP.md completion states updated.
