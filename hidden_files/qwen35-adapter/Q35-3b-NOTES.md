# Q35-3b — real-file oracle grade (worker slice)

Worker runs all six Forge roles sequentially in one seat. Seat:
/home/volmarr/aesir-q35-3b @ yrsa/q35-3b, base 9853ba62.
Target file: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
  size on disk re-verified 2026-11-14: 28,596,003,296 B (matches brief).

## Recon (2026-11-14 ~13:34 EST, measured)
- MemAvailable 121,454 MB (free -m available col); load 0.12; up 3:32.
- aesir-gate / ollama / voxta all inactive (Volmarr's ordered stop stands).
- Worktree clean at base 9853ba62 on yrsa/q35-3b.
- No llama.cpp binary or source on box (confirms QC-0 U-QC1); ollama binary exists at /usr/local/bin/ollama (service stopped). g++ 15.3, cmake 4.3.4, git 2.55, 32 cores available for builds.
- Grading arithmetic = banked A-045/A-111: parity_logit_rank/gap (core/parity_battery.mojo), near-tie band rank<=2 AND gap<1.0 (core/near_tie_gate.mojo). Rows from KVCache.capture_logit_row sink (forward_pass_qwen35 honors it, Q35-3a fix 6).
- Load path decision: RESIDENT (qwen35_resident=True). Reasons: (1) Q35-3r proved resident numerics identical to default (logits diff 0.0, same packed views/kernels) so the grade is of the same forward; (2) resident avoids the 53.8 GB F16 materialization term — the only path that fits the fence honestly; (3) the real file passes resident validation (Q35-3r census: 498 large tensors all Q8_0).
- Battery honesty: core/qwen_battery_a119.mojo qwen_smoke_status(qwen35)=LOAD_FAIL_NAMED_CAUSE is a DATA row (A-048 era), asserted by tests/test_qwen_battery_a119.mojo. If the real load+forward succeeds here, that row is stale; disposition decided after the grade (deliberate in-slice update with citation, or named Q35-7 scope-out).
- Named risks carried from Q35-3: U1 recurrence semantics beyond layout (THIS slice arbitrates); rope dimension_sections [11,11,10,0] unread by engine; 1/sqrt(d_state) q-readout scale placement.

## Comparator plan
- Build llama.cpp natively (no Docker) OUTSIDE the repo at ~/llama.cpp-build; record commit + flags here. First check: does upstream llama.cpp know arch "qwen35" at all — if not, substitution must be named honestly.
- Teacher forcing: ONE token stream, tokenized once from the file's own tokenizer (Aesir RuneWeaver encode of RAW prompts, add_bos per file tokenizer config — to be pinned in recon of both tokenizers); the identical ID stream is fed to both engines. No chat template anywhere.

## Findings (streamed)
- Comparator: llama.cpp built NATIVELY (no Docker) at ~/llama.cpp-build, upstream ggml-org/llama.cpp commit a956a852c9c8bc1fb07206364838ddef299178c0 (shallow clone 2026-11-14), flags: -DGGML_NATIVE=ON -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release, targets llama-cli + llama-perplexity, BUILD_DONE_EXIT=0. Upstream KNOWS arch "qwen35" (src/llama-arch.cpp LLM_ARCH_QWEN35) — no substitution needed; the plan's named comparator grades the same file.
- Comparator tool: ~/llama.cpp-build/q35grade/q35grade.cpp (kept OUT of the repo with the build tree) — feeds token IDs from the tokens file, one decode per position, raw logits rows via llama_get_logits_ith; computes argmax + rank/gap of the true next token per position; greedy witness (40 tokens) for prompt 0. CPU only (n_gpu_layers=0).
- Aesir driver: aesir_engine/tests/grade_qwen35_oracle_q35_3b.mojo — modes grade/gen/batch, resident load, banked parity arithmetic imported from core.parity_battery (no re-typed band). Tokenize-once probe: aesir_engine/tests/probe_qwen35_tokens_q35_3b.mojo (metadata-only parse; round-trip decode witness per prompt).
- Grading set: 5 RAW prompts (factual / prose narrative / code / long prose / counting), exact token counts recorded in q35-3b-tokens.log when the probe runs.
