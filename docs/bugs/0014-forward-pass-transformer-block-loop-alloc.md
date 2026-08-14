# Bug Report: `TransformerBlock` Re-Instantiation and String Allocation in Inner Forward Loop

**Bug ID**: 0014
**Title**: `forward_pass()` re-instantiates `TransformerBlock` inside layer iteration loop, causing dynamic string allocations per token
**Component**: `core/inference.mojo`
**Status**: Resolved

## Description
In `core/inference.mojo`, `forward_pass()` executes layer forward passes via a `for` loop:
```mojo
for layer_idx in range(num_layers):
    var block = TransformerBlock(layer_idx, head_dim, num_heads, seer)
    block.forward(x, seer, well, seq_len, start_pos, kv_cache, topology)
```
Instantiating `TransformerBlock` inside the layer loop on every single token step calls `TransformerBlock.__init__`, which constructs dynamic string keys:
`var prefix = "blk." + String(self.layer_idx) + "."`
`if prefix + "attn_norm.weight" in seer.tensors:`
This executes 9 dynamic string heap allocations and hash map lookup operations per layer per token (288+ heap allocations for 32 layers per token step), violating the core engine invariant: "Zero dynamic memory allocation in the inner inference path."

## Recommendation for the Forge Worker
Pre-instantiate and cache a `List[TransformerBlock]` inside `AesirEngine` or `GGUFSeer` during model loading, so `forward_pass()` indexes into pre-built layer blocks without constructing strings or allocating heap memory during token generation.

## Mythic Engineering Rite Completed
Resolved by The Forge Worker (Eldra Járnsdóttir / Eiríkr Járnhönd): Pre-instantiated and cached `List[TransformerBlock]` inside `AesirEngine` during model loading and updated `forward_pass()` to accept pre-cached blocks, eliminating dynamic string allocations and hash table lookups during token generation.
