# Bug Report 0001: MimirWell Leak & Compute Dimensionality

## Description
During the Mythic Engineering audit of Slice 3: The Forward Pass, several critical bugs and invariant violations were found and resolved.

1. **MimirWell Invariant Violation (Memory Leak):**
   - The `MimirWell` is designed as a bump allocator (`offset` increments). During `forward_pass`, intermediate tensors (Q, K, V, residuals, up/gate projections) were allocated for every layer without resetting the `offset`. 
   - This caused linear memory leakage during inference, which would instantly exhaust the "Waters of Mimir" (OOM) after a few tokens. 
   - **Fix Additive:** Captured the `start_offset` at the beginning of `TransformerBlock.forward` and `initial_offset` in `forward_pass`, restoring them at the end of their respective scopes.

2. **Compute Kernel Dimensionality (`gemm_f16`):**
   - The GEMM kernel `gemm_f16` assumed that since `B` is transposed in memory, `N` (output features) should be `B.cols`. However, for a transposed weight matrix `(out_features, in_features)`, the memory layout implies `B.rows = out_features`. 
   - **Fix:** Corrected `var N = B.cols` to `var N = B.rows` to prevent incorrect output tensor sizing and memory out-of-bounds access.

3. **Compute Kernel Multi-Head Support (`flash_attention_2`):**
   - The flash attention implementation only processed the first attention head and ignored `num_heads`. Furthermore, its indexing logic (`i * head_dim + k`) ignored the row stride of `Q`, `K`, and `V` (`num_heads * head_dim`), which would read from the wrong rows.
   - **Fix:** Added an outer loop over `num_heads = Q.cols // head_dim` and updated the tensor indexing to correctly stride across heads (`h * head_dim`) and rows (`Q.cols`).

## Resolution
The codebase was purified directly by The Auditor. The fixes abide by the "additive fix" and "zero dynamic allocation" principles. The Aesir Engine is now battle-ready.
