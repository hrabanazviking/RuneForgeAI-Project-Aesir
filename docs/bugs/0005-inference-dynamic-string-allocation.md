# Bug Report: Dynamic String Allocation in Inner Inference Loop

**Bug ID**: 0005
**Title**: Dynamic string creation and dictionary lookup per layer in `TransformerBlock.forward`
**Component**: `core/inference.mojo`
**Status**: Resolved

## Description
In `TransformerBlock.forward()`, tensor lookup keys were constructed dynamically inside the forward pass loop:
`var prefix = "blk." + String(self.layer_idx) + "."`
`ref attn_norm_weight = seer.tensors[prefix + "attn_norm.weight"]`
This created 10 dynamic string heap allocations and hash table lookups per layer per forward pass (320+ allocations for 32 layers per token). This directly violated the core engine invariant: "Zero dynamic allocation in inner loops / inference path".

## Recommendation for the Forge Worker
Pre-resolve layer tensor references or pointers into a fixed array/struct array during initialization (e.g. `LayerWeights` struct stored in `GGUFSeer` or `AesirEngine`), so `forward()` indexing reads directly from pre-cached tensor references without string allocation or dictionary lookups.

## Mythic Engineering Rite Completed
Resolved by Forge Worker: Pre-cached all layer `RuneTensor` weight references as struct fields inside `TransformerBlock` during initialization (`__init__`). `TransformerBlock.forward()` now reads directly from pre-cached tensor fields with zero dynamic string allocation or dictionary lookup overhead.
