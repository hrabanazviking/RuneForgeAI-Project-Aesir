# CASE-75 HUNT — state notes (worker: case75-suite-segfault)

Commission: root-cause and fix the counted master run's deterministic
segfault inside case `rag.cosine_similarity`, under Volmarr's
never-leave-a-bug-unfixed rule. Base: platform/llvm-split-crash-fix
87b68e3e (carries compiler fix 0907593a). Evidence pack:
llvm-crash-checkpoint/NOTES.md updates 2–3 (read in full, 2026-10-28).

## Established facts (from the evidence pack, to be re-confirmed)

- run_all (271 counted: 270 run_case + 1 skip) compiles clean (JIT + AOT)
  on the fixed tree; executes, then SEGFAULTS inside
  rag.cosine_similarity. AOT on PRISTINE BASE 562591e9: identical
  (build exit 0, dies in the same case). Pre-existing; independent of
  the compiler fix; runtime-independent (JIT and AOT).
- Crash worker counted 74 [CASE PASS] lines before death; call-order
  extraction (2026-10-28, this hunt) shows 78 run_case calls precede
  cosine in main()'s order — the 4-line gap is consistent with stdout
  block-buffering losing the tail at the segfault. The cosine case DID
  start (its header "SIMD Cosine Similarity" was the final output).
  Working model: all 78 preceding cases completed; crash is inside
  test_cosine_similarity itself.
- The case passes standalone; the pair (sharding.host_gemm_parity ->
  cosine) passes. Trigger = accumulated state across the prefix.
- Victim case anatomy: fresh MimirWell(64 KiB); three 35-element f16
  RuneTensors from well.allocate; cosine_similarity is a plain SIMD
  f16 loop (@always_inline, no par_for, no async). Code reads clean.
- Possible kinship (UNPROVEN): checkpoint anomaly (a) — a direct
  gemm_q4_k_m call in one inlining pattern zeroed a weight block's
  first 16 bytes; suspect named there: inlining/address-stability
  around _gemm_k_fast's heap ctx. _gemm_k_fast itself (read this hunt):
  alloc[Int64](9) ctx, par_for (synchronous, joins — thread_par.c
  contract verified), unsafe_free after join. par_for wrapper
  (core/parallel.mojo) also degrades to serial safely. No defect
  proven there yet.
- par_for/C shim audited this hunt: contract sound (join-before-return,
  serial fallbacks). Not exonerated: every caller of it in the prefix.

## Prefix (call order, 1..78) — the bisect space

1-7 hardware/storage admission; 8 compute.gemm_f16; 9 gemm_f16 gpgpu
fallback; 10 flash_attention; 11 silu; 12 geglu; 13 dequantize_q4_k;
14-26 gguf loader set (incl. 26 tensor_directory_pool_adversarial);
27-30 vision (encoder_stages = 29); 31-45 tokenizer set (45 =
linear_bpe_perf); 46 memory.telemetry_and_recycling; 47
inference.synthetic_forward; 48-55 sampling set; 56 rmsnorm_integration;
57 stop_policy; 58 unsupported_runtime_config; 59 prompt_byte_bound;
60 kv_cache; 61 memory.allocation_bounds; 62 checked_span; 63
rune_tensor_layout; 64-66 rmsnorm x3; 67-69 rope x3; 70-73 attention x4;
74-78 sharding set (78 = host_gemm_parity). Victim: 79
rag.cosine_similarity.

## Plan

1. Reproduce AOT in this worktree (step-3 build shape), confirm.
2. Bisect driver: generated Mojo driver importing the same test fns,
   argv-selected prefix [lo,hi) + cosine always last; AOT-built once.
   Binary-search the minimal arming prefix; then single-case + cosine
   probes over suspects inside it (pair exoneration is weak evidence:
   corruption is heap-layout dependent, so single-case probes run
   against a NEUTRAL filler prefix that mimics heap history).
3. Characterize: gdb fault address/backtrace on the AOT binary;
   MALLOC_CHECK_=3 run to catch heap-metadata corruption at the
   corrupting free; canary checks around suspect allocations.
4. Fix root cause; proof = full counted run past case 75 to its
   counted completion (or to the next named pre-existing failure,
   documented, if one waits beyond).

## Log

- 2026-10-28 ~01:20 EDT: worktree + branch created at 87b68e3e.
  Evidence pack read. Case-list extraction done (above). Code read:
  cosine_similarity, MimirWell.allocate, _gemm_k_fast, par_for,
  thread_par.c contract.
- 2026-10-28 ~01:45 EDT: REPRODUCED on this tree (AOT, step-3 shape):
  exit 139. Three probes (plain/MALLOC_CHECK_=3/MALLOC_PERTURB_=165)
  all segfault identically; MALLOC_CHECK did not move or convert the
  crash (early hint the allocator is not glibc's).
- **BREAKTHROUGH — the victim is NOT fixed at case 75.** Symbolized
  trace (LLVM_SYMBOLIZER_PATH) of this AOT build:
  #4 libAsyncRTRuntimeGlobals.so+0x4f2c2 (fault) <- #5
  std::memory::alloc::_alloc_bytes <- #6
  tests::test_rune_tensor_layout::test_rune_tensor_layout <- run_case
  <- main. I.e. THIS build dies inside **case 63
  (memory.rune_tensor_layout)**, during a byte-buffer allocation.
  Visible output ends exactly after [CASE PASS] memory.checked_span
  (62) — consistent, no buffering-loss assumption needed.
- libAsyncRTRuntimeGlobals.so contains **TCMalloc** (exported symbols
  TCMallocInternal*): the Mojo runtime's global allocator. The fault
  offset +0x4f2c2 is inside TCMalloc internals — the SAME offset the
  crash worker saw in JIT mode where the in-binary caller was the
  cosine case. Reframed theory: an earlier case corrupts TCMalloc
  state (double free / wild free / overflow into allocator metadata);
  the NEXT allocation that walks the poisoned structure faults, and
  WHICH case that is depends on the build's allocation pattern
  (JIT->cosine #79 there, AOT->rune_tensor_layout #63 here). "Case 75"
  is a victim address, not a culprit. Isolation passes fit: small
  allocation histories never reach the poisoned structure.
- Prime suspect class: ownership double-free — tests/engine code that
  unsafe_free()s a pointer a RuneTensor (or List/String) ALSO owns and
  frees on drop; or a free of an interior/misaligned pointer.
  Bisect driver (hunt_prefix.mojo, env-selected prefix + cosine) built
  to find the minimal arming prefix for this build; note the arming
  prefix may differ per build — culprit identification must end in a
  code-level mechanism, not just a case name.
- RuneTensor is a NON-OWNING view (Copyable, no __del__); MimirWell
  has NO __del__ either (arenas leak by design). Tensor double-free
  theory dead; manual free pairs remain suspect.
- BISECT (driver v1, detonator=cosine): HI bisect: 46 OK, 60 OK,
  61 CRASH, 62 CRASH -> trigger factor = case 61
  (memory.allocation_bounds). LO bisect (HI=61): 16 OK, 13 OK,
  11 CRASH, 12 CRASH -> early factor = case 12 (compute.geglu;
  case 11 silu not isolated yet). Case 61 alone OK; case 63 alone OK.
  Model: TWO factors {geglu, allocation_bounds} + a detonator
  allocation in a later case (63 or 79 in observed builds).
- FAULT ANATOMY (objdump of libAsyncRTRuntimeGlobals +0x4f2c2): the
  faulting instruction is TCMalloc's thread-cache free-list POP:
  mov (%rax),%r8 with rax = list head. The list link was overwritten
  with garbage -> a dangling-pointer WRITE of pointer-width data into
  a freed small object (or a double free) is the mechanism family.
- **SMOKING GUN (ptrace register capture, run 1..61+cosine):**
  rax = 0x3ebb3ebb3ebb3ebb at the fault. 0x3ebb is the f16 encoding
  of ~1.6826 — test_geglu's exact expected output value
  (2.0 * GELU(1.0) ~= 1.6826), which fills geglu's result tensor.
  So the poisoned free-list link was overwritten with geglu's OUTPUT
  DATA (4 x f16 1.6826). The writer is geglu's store path or a copy
  of its results — yet geglu's own stores audit in-bounds and its
  arena is a leaked 64 KiB well. Open question: through what pointer
  do geglu-result bytes reach a freed heap object? Hypotheses:
  (i) a stale tensor/view of geglu's arena retained and re-stored by
  a later op after the arena was somehow freed; (ii) the value
  propagates through a legit copy into another buffer that is later
  written past ITS bounds; (iii) 61's role: its tiny 16-byte wells /
  error strings reshape the thread cache so the poisoned class gets
  exercised by the detonator.
  Next: driver v2 pair tests {12}+61, {12}+{13}+61, {11}+61 with rax
  capture per config; a geglu-value variant test (change fill values
  in a copied test -> rax pattern must follow the new result value
  if the writer is geglu's data path).
- PAIRS INSUFFICIENT (driver v2): {12}+61, {11}+61, {13}+61 all
  survive. Middle cases contribute. Middle bisect (12..k + 61):
  k=50 OK, k=58 OK, k=59 CRASH -> third factor = case 59
  (inference.prompt_byte_bound: builds a 1 MiB String one char at a
  time — MAX_PROMPT_BYTES=1048576 — ~1M append/grow/free cycles,
  the allocator-churn amplifier).
- TRIAD SUFFICIENT (driver v3): {12} + [59..61] + cosine CRASHES;
  {12}+[60..61] OK (59 necessary); [59..61] alone OK (12 necessary);
  {12}+[59..61]+probe63 SURVIVES (with the minimal set only cosine
  detonates; the full prefix primes case 63 as a second detonator).
  (Case 60's individual necessity inside the triad untested —
  contiguous-range limit; secondary.)
- RAX STABLE: tracer on the minimal triad again gives
  rax = 0x3ebb3ebb3ebb3ebb, fault in cosine. One poison source.
- geglu kernel + test re-audited: all loads/stores in-bounds within
  the 70-element tensor; arena is a leaked 64 KiB well. The poison
  bytes therefore reach the freed object by a COPY or by the arena
  itself being recycled — value-swap experiment (driver v4, geglu
  variant with x=1.0/y=2.0 -> f16 0x3FD2 pattern) discriminates:
  poison follows the value => geglu data path is the source.
- VALUE-SWAP DECISIVE (driver v4 + tracer): variant geglu head value
  1.9550781 (f16 0x3FD2) and the crash poison became
  rax = 0x3fd23fd23fd23fd2. THE POISON IS GEGLU'S OUTPUT DATA.
- HEAP SCAN (trace_scan.py, triad config): at crash time the poison
  pattern exists in exactly TWO writable places: (1) the thread-cache
  slot itself (METADATA region), (2) ONE spot in a TCMalloc NORMAL
  region at a 64 KiB-aligned address: [>=512 B of zeros][8 B pattern]
  ['x' x 49,152 B exactly][zeros]. 49,152 = a String-growth capacity
  step of case 59's boundary string. Reading: a freed ~49,152-byte
  string buffer whose first 8 bytes hold geglu's output — the buffer
  plausibly landed in the recycled geglu arena span (data starting
  after an 8-byte string header, header retaining arena bytes), was
  freed on the next growth step, and its first word (pattern) became
  the free-list link. NOTABLY ABSENT: no second pattern copy at an
  intact geglu arena head — the arena span was recycled (arena freed
  somehow despite MimirWell having no destructor — mechanism TBD).
  Faulting allocation in the detonator carries size 65536 in
  rbx/rdx (= a MimirWell(1024*64) request) — cosine's own well alloc
  walks the poisoned list.
- Driver v5 (address prints: geglu arena addr + string buffer addr
  at growth milestones, same run as the heap scan) will confirm or
  kill the arena-recycling theory by direct address comparison.
- ADDRESS MATCH (driver v5 + scan, same run): variant geglu arena
  addr == heap-scan hit addr == 0x11debfc00000, diff 0. The geglu
  arena span IS the recycled span. Repro round 2 (real MimirWell +
  real geglu, well scoped in a helper): case-59-style string growth
  lands its 49,152-length buffer at arena+8 (Mojo String header
  offset) — the arena is being freed and recycled.
- ROOT CAUSE FOUND (engine source, core/mimir_well.mojo:1480):
  MimirWell has an explicit `__deinit__` calling
  `self.base_ptr.unsafe_free()`. (The hunt's early grep missed it —
  it searched the deprecated `__del__` spelling.) MimirWell has NO
  ownership tracking: its copy is the synthesized field-wise copy,
  so every by-value copy of a well is a co-owner whose destruction
  frees the shared arena, while RuneTensor views and other wells
  still alias it. Wells are passed by value throughout the engine
  (KVCache/PagedKVCache/session paths), and every test's well dies
  at scope exit. In the counted suite: test_geglu's arena is freed
  at case 12's exit, recycled as case 59's 64 KiB-class string
  buffer (data at +8, header word keeps geglu's output bytes), and
  the corrupted free-list link (geglu's output value, proven by the
  value-swap) detonates a later allocation — case 63 or 79
  depending on the build. RuneTensor exonerated (repro ST2: tensor
  drop frees nothing). PagedKVCache.__deinit__ (line 1181) audited
  and KEPT: it frees only deep-copied private buffers guarded by
  owns_storage — correct RAII. Engine-wide grep: MimirWell's was
  the only freeing destructor over shared/aliased memory.
- DIRECT PROOF (repro_free ST1): a lone MimirWell created in a
  helper and dropped -> the next 49,160-byte allocation reuses the
  EXACT arena address, and the allocation after that segfaults at
  the suite's identical TCMalloc offset (+0x4f2c2). ST2/ST4
  controls (tensor only / raw alloc) clean.
- FIX APPLIED (core/mimir_well.mojo): MimirWell's freeing
  __deinit__ removed, with an in-place comment recording why arenas
  are process-lifetime (matching __init__'s unsafe_leak and the
  non-owning RuneTensor view design). No numerics or case semantics
  touched. The synthesized destructor now only destroys the small
  npu_backends List (a plain Pointer field's destruction does not
  free — micro-probe P2).
- FIX VERIFIED IN REPRO: rebuilt repro_free_fixed — ST1 and ST3
  probes no longer reuse the arena (SAME-AS-ARENA: False x4) and
  ST1's segfault is gone (rc=0).
- Full counted-suite AOT rebuild with the fix launched
  (hunt-build/run_all_fixed); proof run pending.
- PROOF (2026-10-28, run_all_fixed): NO SEGFAULT. Full counted run
  completes and prints its summary. From hunt-build/ (no config in
  CWD): Passed 268, Failed 2, Skipped 1, Total 271. From the repo
  root (aesir.config.json present): Passed 269, Failed 1,
  Skipped 1, Total 271. [CASE PASS] rag.cosine_similarity — the
  victim case passes in the full run; the case-63 victim also
  passes. The skip is the expected record_skip
  (rag.real_engine_integration, external GGUF fixture).
- REMAINING FAILURE (separate, pre-existing, OUT OF SCOPE — never
  reachable before this fix because the run died at case 79):
  cli.truthful_command_boundaries :: "unsupported CLI command
  returned successfully: ps". Its sibling cli.flag_options_parser
  fails only when the CWD lacks aesir.config.json (environment
  sensitivity in the CLI cases, also worth a later look). Neither
  involves MimirWell or the allocator corruption; not fixed here,
  reported per the never-leave-a-bug rule for the parent to route.
- BANKED ON THIS BRANCH: the fix (core/mimir_well.mojo), these
  notes, and the two isolation repros
  aesir_engine/tests/hunt_repro_free.mojo (ST1: well-drop frees the
  arena; with the fix it does not) and
  aesir_engine/tests/hunt_repro_scope.mojo (string buffer reuses
  the dropped well's arena at +8). The hunt_prefix* bisect drivers
  were scratch and are not banked; their design and full results
  are recorded above. Build/run: stage the two shim libs, then
  pixi run mojo build -I . --target-accelerator sm_89
  aesir_engine/tests/run_all.mojo -Xlinker -L<staging> -Xlinker
  -laesir_hailo10h -Xlinker -laesir_par; run from the repo root.
