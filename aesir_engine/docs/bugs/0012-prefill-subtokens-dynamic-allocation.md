# Bug Report: Dynamic Sub-token List Allocation During Streaming Prefill

**Bug ID**: 0012
**Title**: `generate_stream` creates heap-allocated `List[Int]` per token during prompt prefill
**Component**: `aesir.mojo`
**Status**: Resolved

## Description
In `aesir.mojo`, during streaming autoregressive prefill:
```mojo
for i in range(len(tokens) - 1):
    var sub_tokens = List[Int]()
    for j in range(i + 1):
        sub_tokens.append(tokens[j])
    _ = forward_pass(sub_tokens, self.parser, self.pool, kv_cache, i)
```
Creating a heap-allocated `List[Int]` slice for every token index $i$ in prompt prefill violates the core engine invariant ("Zero dynamic allocation in inner inference loop"). Since `forward_pass()` only needs the target token at position `start_pos`, allocating $N$ dynamic lists for prompt length $N$ is unnecessary and degrades prefill performance.

## Fix Applied
Updated `forward_pass()` token indexing to read `tokens[start_pos]` directly so `generate_stream()` passes `tokens` without allocating intermediate `sub_tokens` sub-lists.

## Mythic Engineering Rite Completed
Additive fix applied to maintain zero dynamic allocation invariants in inference paths.
