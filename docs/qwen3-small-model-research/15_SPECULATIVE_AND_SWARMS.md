# 15 - Speculative Decoding and Multi-Model Swarms

**Research snapshot:** 2026-11-02

The Qwen3 0.6B/1.7B/4B/8B family is an unusually attractive laboratory for speculative decoding because the models share tokenizer and chat-template lineage while spanning more than an order of magnitude in parameter count.

Aesir already contains substantial draft/speculation design work, but some real integration paths intentionally fail closed until a real draft-model decoding loop is wired. This document focuses on how to turn the family into a measured production feature.

---

# 1. Core speculative idea

A cheap model drafts several future tokens. The target model verifies them in one batched pass. The longest valid prefix is accepted, then generation continues.

Concept:

```text
drafter proposes: A B C D E
                  | | x
 target verifies: A B F ...
 accept A B, reconcile at mismatch
```

Correct speculative sampling must preserve the target model's output distribution. Greedy-mode verification is simpler, but sampled generation requires mathematically correct reconciliation.

---

# 2. Qwen3 pair candidates

All pairs worth measuring:

```text
0.6B -> 1.7B
0.6B -> 4B
0.6B -> 8B
1.7B -> 4B
1.7B -> 8B
4B   -> 8B
```

Likely intuition:

- smaller drafter = cheaper proposals, lower acceptance;
- larger drafter = more expensive proposals, higher acceptance.

The optimum is the minimum total wall time, not maximum acceptance or maximum drafter speed independently.

---

# 3. Why same-family tokenization matters

Cross-family speculative decoding can fail at the first step if tokenizers segment text differently. These Qwen3 dense models share the same tokenizer family and vocabulary shape, greatly simplifying token-level proposal verification.

Still verify exact tokenizer artifacts/revisions before enabling a pair. Same family name does not authorize assuming identical token IDs if files differ.

---

# 4. Draft length `k`

A fixed `k` is simple but rarely optimal.

If acceptance is high:

```text
increase k
```

If acceptance falls:

```text
decrease k
```

If speculation loses repeatedly:

```text
disable temporarily
```

Suggested bounds for experiments:

```text
k = 1, 2, 4, 8, 12, 16
```

Track rolling accepted tokens per verification pass.

---

# 5. Profitability equation

A useful conceptual criterion:

```text
baseline_target_time
-
(speculative_target_verify_time
 + drafter_time
 + reconcile/sync overhead)
> 0
```

The drafter can have 90% acceptance and still lose if it runs on the same bandwidth-saturated GPU and slows target verification.

---

# 6. Heterogeneous speculation

Promising placements:

```text
0.6B CPU  -> 4B GPU
1.7B CPU  -> 8B GPU
0.6B NPU  -> 8B GPU
1.7B NPU  -> 8B GPU
```

This can overlap independent compute resources.

On unified-memory hardware, test contention because CPU drafter and GPU target may fight for the same DRAM bandwidth.

---

# 7. Thinking mode complication

Thinking trajectories may diverge more strongly across model sizes than ordinary prose.

Hypotheses to test:

- non-thinking mode yields higher acceptance;
- structured tool output yields high acceptance after the target has chosen the same tool;
- simple prose/code boilerplate yields high acceptance;
- hard reasoning yields low acceptance, making speculation less useful.

Aesir should allow workload-aware speculation rather than one global switch.

---

# 8. Quantization complication

Drafter quant matters.

Example possibility:

```text
0.6B Q2: 200 tok/s, 35% acceptance
0.6B Q5: 150 tok/s, 65% acceptance
```

The slower Q5 drafter may produce greater net speedup.

Therefore the benchmark key is:

```text
drafter model + drafter quant + target model + target quant + workload
```

---

# 9. KV state

Both drafter and target need synchronized context state.

After a proposal:

- accepted tokens remain in both caches;
- rejected draft suffix must be rolled back;
- target's corrective token must be appended to both histories before next proposal.

Paged KV makes rollback naturally cheap if checkpoints store logical length and tail-page state.

---

# 10. Sampler state

For sampled speculative decoding, rollback includes more than KV:

- RNG state;
- repetition/presence penalty history;
- grammar state;
- stop-state machine;
- token-frequency counts;
- any dynamic sampler filters.

Aesir's draft framework should treat sampler checkpointing as part of correctness.

---

# 11. Batch verification

Target verification should process the draft as a short prefill-like batch rather than decode each draft token individually. Otherwise speculation cannot save target launches/work.

Aesir needs a `draft_check` execution phase tuned for approximately 2-16 tokens, distinct from both long prefill and single-token decode.

The repository's Janas work already recognizes a draft-check placement band. This research library recommends making it a first-class kernel/scheduler phase.

---

# 12. Aesir existing groundwork

Relevant repository artifacts include:

- `docs/janas/J071...` verification-first design;
- `J072_DRAFT_LOOP.md`;
- `J074_CROSS_MODEL_DRAFTS.md`;
- `J078_ASSISTANT_MODEL_DRAFTS.md`;
- `J081_DRAFTS_PLACEMENT.md`;
- `J083_DRAFT_CONFIG_SURFACE.md`;
- `J084_WHEN_DRAFTS_LOSE.md`;
- `aesir_engine/core/speculative.mojo`;
- `aesir_engine/core/speculative_verify.mojo`.

Some production integration paths still fail closed with explicit errors requiring a real draft-model loop. That is the correct boundary until fully wired.

---

# 13. Runtime auto-policy

Proposed scheduler logic:

```text
if no compatible drafter:
    normal decode
elif task class historically poor for speculation:
    normal decode
else:
    start with small k
    measure rolling acceptance and time
    increase k if profitable
    decrease/disable if not
```

Persist performance history by pair and workload class.

---

# 14. Multi-model swarm beyond speculation

The same models can cooperate even when tokens are not speculatively verified.

Example research workflow:

```text
0.6B: classify subquestions
1.7B workers: gather/transform data
4B: synthesize draft
8B: review only uncertain sections
```

Example coding workflow:

```text
0.6B: identify likely task category
1.7B: scan/summarize relevant files
4B: implement
8B: architecture/security review
```

The difference from speculation is that workers produce semantic intermediate results, not candidate next tokens.

---

# 15. Parallel workers

If hardware permits, run multiple 0.6B/1.7B workers concurrently.

But shared memory bandwidth can become the limiting resource. Measure:

```text
1 worker
2 workers
4 workers
8 workers
```

and compare total completed tasks/s versus latency.

---

# 16. Supervisor routing

A supervisor should not always be the biggest model. For ordinary tasks, 4B can supervise 0.6/1.7 workers and escalate to 8B only if:

- worker disagreement;
- validation failure;
- task complexity threshold;
- explicit high-quality mode;
- low confidence according to calibrated system signals.

This lowers average compute.

---

# 17. Benchmarks

For every pair:

```text
proposals/sec
acceptance rate
mean accepted run
p50/p95 accepted run
target verification time
net output tok/s
TTFT effect
memory overhead
energy/token
```

Workload classes:

- casual prose;
- technical prose;
- code completion;
- code reasoning;
- math;
- tool calls;
- JSON;
- multilingual;
- thinking versus non-thinking.

---

# 18. Correctness tests

Speculative output must match target-only behavior according to the algorithm's guarantee.

For greedy:

- exact token sequence equality.

For sampled:

- deterministic seeded comparison where algorithm permits;
- statistical distribution tests;
- sampler checkpoint/rollback unit tests;
- no duplicated/dropped tokens around rejection boundary.

---

# 19. Recommended implementation order

1. real drafter session interface;
2. exact token-history synchronization;
3. greedy speculative loop;
4. batched target verification;
5. KV rollback;
6. adaptive k;
7. auto-disable when losing;
8. sampled reconciliation;
9. heterogeneous placement;
10. persisted pair autotuning.

---

# 20. Aesir references

- `docs/janas/J074_CROSS_MODEL_DRAFTS.md`
- `docs/janas/J078_ASSISTANT_MODEL_DRAFTS.md`
- `docs/janas/J072_DRAFT_LOOP.md`
- `docs/janas/J081_DRAFTS_PLACEMENT.md`
- `docs/janas/J084_WHEN_DRAFTS_LOSE.md`
- `aesir_engine/core/speculative.mojo`
- `aesir_engine/core/speculative_verify.mojo`
