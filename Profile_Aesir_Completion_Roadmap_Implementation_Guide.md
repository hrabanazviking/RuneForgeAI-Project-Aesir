# RuneForgeAI: Project A.E.S.I.R. - Completion Roadmap & Implementation Guide

**Version:** 1.0  
**Date:** August 30, 2026  
**Target:** Production-Ready Local LLM Inference Engine  
**Estimated Effort:** 4-6 months (2-3 engineers)

---

## Executive Summary

This roadmap transforms Project A.E.S.I.R. from its current **verified CPU vertical slice with GPU proofs** into a **production-ready, cross-platform, multi-backend local LLM inference server** with full API compatibility, comprehensive quantization support, and enterprise-grade reliability.

**Current State:** 68/107 capabilities verified, 25 missing  
**Target State:** 100+ capabilities verified, production-ready

---

## Phase Overview

| Phase | Duration | Focus | Deliverable |
|-------|----------|-------|-------------|
| **Phase 1** | 2-3 weeks | Quantized Inference | Real Q4_0/Q4_K_M GGUF execution |
| **Phase 2** | 3-4 weeks | PagedAttention | Dynamic KV cache, batching, 10x throughput |
| **Phase 3** | 4-5 weeks | Multi-GPU & Accelerators | CUDA/Metal/ROCm full transformer |
| **Phase 4** | 3-4 weeks | Server & APIs | OpenAI/Ollama compatibility |
| **Phase 5** | 2-3 weeks | RAG & Embeddings | Persistent knowledge base |
| **Phase 6** | 2-3 weeks | Production Hardening | Security, observability, packaging |

---

## Phase 1: Real Quantized GGUF Inference

### Goal
Complete AES-QNT-003 and AES-LDR-006: Load and execute real quantized GGUF models with token/logit parity against llama.cpp.

### Implementation: Quantized Tensor Mapping

```mojo
# loader/quantized_tensor.mojo
# Maps GGUF quantized tensors with proper block layout validation

from memory import UnsafePointer
from std.math import ceil

struct QuantizedTensorMapping:
    """Validated mapping of GGUF quantized tensor to dequantized workspace."""
    
    var ggml_type: GGMLType
    var original_shape: List[Int]
    var num_blocks: Int
    var block_size: Int
    var scales_ptr: UnsafePointer[Float32]
    var biases_ptr: UnsafePointer[Float32]
    var weights_ptr: UnsafePointer[Int8]
    var dequantized_buffer: UnsafePointer[Float16]
    var dequantized_len: Int
    
    fn __init__(
        out self,
        gguf_tensor: GGUFSeer.TensorDescriptor,
        pool: MimirWell,
    ) raises:
        """Validate block layout and allocate dequantization workspace."""
        
        self.ggml_type = gguf_tensor.ggml_type
        self.original_shape = gguf_tensor.shape.copy()
        
        # Validate supported quantized types
        if self.ggml_type not in [
            GGMLType.Q4_0, GGMLType.Q4_1, 
            GGMLType.Q4_K_M, GGMLType.Q4_K_S,
            GGMLType.Q5_0, GGMLType.Q5_1,
            GGMLType.Q8_0,
        ]:
            raise Error("QuantizedTensorMapping: unsupported GGML type: " + 
                       ggml_type_to_string(self.ggml_type))
        
        # Calculate block parameters based on GGML spec
        self.block_size = self._get_block_size(self.ggml_type)
        self.num_blocks = self._calculate_blocks(gguf_tensor)
        
        # Validate tensor size matches expected block layout
        var expected_bytes = self._calculate_expected_bytes()
        if gguf_tensor.data_len != expected_bytes:
            raise Error(
                "QuantizedTensorMapping: size mismatch. Expected " + 
                String(expected_bytes) + " bytes, got " + 
                String(gguf_tensor.data_len)
            )
        
        # Map raw quantized data
        self.weights_ptr = gguf_tensor.data.bitcast[Int8]()
        
        # Allocate dequantized workspace in pool
        var total_elements = self._calculate_total_elements()
        self.dequantized_len = total_elements
        
        var bytes_needed = total_elements * sizeof[Float16]()
        self.dequantized_buffer = pool.allocate(bytes_needed).bitcast[Float16]()
        
        # Extract scales/biases based on quantization type
        self._map_metadata(gguf_tensor)
        
        # Immediate dequantization into pool
        self._dequantize_all()
    
    fn _dequantize_all(self) raises:
        """Dequantize all blocks into F16 workspace."""
        
        for block_idx in range(self.num_blocks):
            var src_offset = block_idx * self.block_size
            var dst_offset = block_idx * self._get_elements_per_block()
            
            match self.ggml_type:
                case GGMLType.Q4_0:
                    self._dequantize_q4_0_block(src_offset, dst_offset)
                case GGMLType.Q4_K_M:
                    self._dequantize_q4_k_m_block(src_offset, dst_offset)
                case GGMLType.Q8_0:
                    self._dequantize_q8_0_block(src_offset, dst_offset)
                case _:
                    raise Error("Dequantization not implemented for type")
    
    fn _dequantize_q4_0_block(self, src_offset: Int, dst_offset: Int):
        """Dequantize Q4_0 block: 32 weights, 1 scale (F16)."""
        var scale = self.scales_ptr.load(src_offset // self.block_size)
        var weights_base = self.weights_ptr + src_offset
        
        for i in range(32):
            var byte = weights_base.load(i // 2)
            var nibble = byte & 0xF if i % 2 == 0 else (byte >> 4) & 0xF
            var dequant = scale * Float32(nibble) - 8.0  # Zero-point 8
            self.dequantized_buffer[dst_offset + i] = Float16(dequant)
    
    fn _dequantize_q4_k_m_block(self, src_offset: Int, dst_offset: Int):
        """Dequantize Q4_K_M block: 256 weights, 4-bit with K-quant scaling."""
        # K-quant block structure: d (F16), d_min (F16), scales[8], weights[144]
        var block_base = src_offset
        var scale = self.scales_ptr.load((src_offset // self.block_size) * 2)
        var min_val = self.scales_ptr.load((src_offset // self.block_size) * 2 + 1)
        
        var scales = self.weights_ptr + block_base
        var weights = scales + 8
        
        for i in range(256):
            var weight_idx = i // 2
            var byte = weights.load(weight_idx)
            var nibble = byte & 0xF if i % 2 == 0 else (byte >> 4) & 0xF
            
            var scale_idx = i // 32
            var block_scale = Float32(scales.load(scale_idx)) * scale / 64.0
            
            var dequant = block_scale * Float32(nibble) + min_val
            self.dequantized_buffer[dst_offset + i] = Float16(dequant)
    
    fn get_dequantized_tensor(self) -> RuneTensor:
        """Return RuneTensor view over dequantized F16 data."""
        return RuneTensor.checked(
            shape=self.original_shape,
            data=self.dequantized_buffer,
            dtype=TensorType.F16,
            source="QuantizedTensorMapping.dequantized_buffer"
        )
    
    fn __del__(owned self):
        """Cleanup handled by MimirWell pool reset."""
        pass  # Pool ownership manages lifetime
Integration: Quantized Forward Pass
mojo
# core/quantized_inference.mojo
# Full transformer forward pass with quantized weights

struct QuantizedTransformerBlock:
    """Transformer block using quantized weights dequantized on-demand."""
    
    var attention_norm: RuneTensor  # F32 converted to F16
    var wq: QuantizedTensorMapping
    var wk: QuantizedTensorMapping
    var wv: QuantizedTensorMapping
    var wo: QuantizedTensorMapping
    
    var ffn_norm: RuneTensor
    var w1: QuantizedTensorMapping  # Gate projection
    var w2: QuantizedTensorMapping  # Down projection
    var w3: QuantizedTensorMapping  # Up projection (for GeGLU)
    
    fn __init__(
        out self,
        layer_weights: GGUFSeer.LayerWeights,
        pool: MimirWell,
    ) raises:
        """Load and validate all quantized tensors for layer."""
        
        # Attention weights (typically Q4_K_M or Q4_0)
        self.wq = QuantizedTensorMapping(layer_weights.wq, pool)
        self.wk = QuantizedTensorMapping(layer_weights.wk, pool)
        self.wv = QuantizedTensorMapping(layer_weights.wv, pool)
        self.wo = QuantizedTensorMapping(layer_weights.wo, pool)
        
        # FFN weights
        self.w1 = QuantizedTensorMapping(layer_weights.w1, pool)
        self.w2 = QuantizedTensorMapping(layer_weights.w2, pool)
        self.w3 = QuantizedTensorMapping(layer_weights.w3, pool)
        
        # Norms are F32 in GGUF, convert to F16 in pool
        self.attention_norm = convert_f32_to_f16_tensor(
            layer_weights.attention_norm, pool
        )
        self.ffn_norm = convert_f32_to_f16_tensor(
            layer_weights.ffn_norm, pool
        )
    
    fn forward(
        self,
        x: RuneTensor,
        position: Int,
        kv_cache: KVCache,
        pool: MimirWell,
    ) raises -> RuneTensor:
        """Execute transformer block with quantized matmul."""
        
        # Attention path
        var normed = rmsnorm(x, self.attention_norm)
        
        # QKV projections using dequantized weights
        var q = gemm_f16(normed, self.wq.get_dequantized_tensor())
        var k = gemm_f16(normed, self.wk.get_dequantized_tensor())
        var v = gemm_f16(normed, self.wv.get_dequantized_tensor())
        
        # Apply RoPE
        apply_rope(q, k, position, self.head_dim)
        
        # GQA Attention
        var attn_out = flash_attention_gqa(q, k, v, kv_cache)
        
        # Output projection
        var attn_proj = gemm_f16(attn_out, self.wo.get_dequantized_tensor())
        
        # Residual
        var post_attn = add_tensors(x, attn_proj)
        
        # FFN with GeGLU
        var ffn_normed = rmsnorm(post_attn, self.ffn_norm)
        
        var gate = gemm_f16(ffn_normed, self.w1.get_dequantized_tensor())
        var up = gemm_f16(ffn_normed, self.w3.get_dequantized_tensor())
        
        # GeGLU activation
        var activated = geglu_gate_up_product(gate, up)
        
        var down = gemm_f16(activated, self.w2.get_dequantized_tensor())
        
        # Final residual
        return add_tensors(post_attn, down)
Acceptance Criteria
bash
# Test command for Phase 1 completion
pixi run mojo run aesir_engine/tests/test_quantized_gguf.mojo \
    /path/to/tinyllama-q4_0.gguf

# Must match llama.cpp token-for-token:
# - First token ID identical
# - 32-token sequence identical
# - Stop reason identical
# - Logits within 0.1% tolerance

Phase 2: PagedAttention Implementation
Goal
Complete AES-MEM-004: Replace fixed-capacity KV cache with dynamic page-table allocation for 10x throughput improvement via batching.
Architecture: Page Table Design
mojo
# core/paged_attention.mojo
# Dynamic page-based KV cache with reference counting

alias PAGE_SIZE = 256  # Tokens per page
alias MAX_PAGES = 4096  # ~1M tokens total capacity
alias BLOCK_SIZE = 16   # For flash attention

struct PageTableEntry:
    """Single page metadata."""
    var physical_page_id: Int
    var ref_count: Int32      # For copy-on-write sharing
    var is_allocated: Bool
    var last_accessed: UInt64 # For LRU eviction

struct KVPageBlock:
    """Physical storage for K/V tensors."""
    var k_data: UnsafePointer[Float16]
    var v_data: UnsafePointer[Float16]
    var layer_count: Int
    var kv_dim: Int
    
    fn __init__(out self, layer_count: Int, kv_dim: Int, pool: MimirWell):
        self.layer_count = layer_count
        self.kv_dim = kv_dim
        
        # Allocate [layer_count, PAGE_SIZE, kv_dim] for K and V
        var k_size = layer_count * PAGE_SIZE * kv_dim * sizeof[Float16]()
        var v_size = layer_count * PAGE_SIZE * kv_dim * sizeof[Float16]()
        
        self.k_data = pool.allocate(k_size).bitcast[Float16]()
        self.v_data = pool.allocate(v_size).bitcast[Float16]()

struct PagedKVCache:
    """Production KV cache with page table management."""
    
    # Page table: logical -> physical mapping per sequence
    var page_tables: Dict[String, List[PageTableEntry]]
    
    # Physical page pool
    var physical_pages: List[KVPageBlock]
    var free_page_list: List[Int]
    var allocated_page_count: Int
    
    # Configuration
    var num_layers: Int
    var num_kv_heads: Int
    var head_dim: Int
    var kv_dim: Int
    
    fn __init__(
        out self,
        num_layers: Int,
        num_kv_heads: Int,
        head_dim: Int,
        max_pages: Int = MAX_PAGES,
    ) raises:
        self.num_layers = num_layers
        self.num_kv_heads = num_kv_heads
        self.head_dim = head_dim
        self.kv_dim = num_kv_heads * head_dim
        
        self.page_tables = Dict[String, List[PageTableEntry]]()
        self.physical_pages = List[KVPageBlock]()
        self.free_page_list = List[Int]()
        self.allocated_page_count = 0
        
        # Pre-allocate all physical pages (but don't map them yet)
        # Actual allocation happens on first use
        for i in range(max_pages):
            self.free_page_list.append(i)
    
    fn allocate_sequence(
        mut self,
        sequence_id: String,
        prompt_len: Int,
    ) raises -> List[PageTableEntry]:
        """Allocate pages for new sequence."""
        
        var pages_needed = (prompt_len + PAGE_SIZE - 1) // PAGE_SIZE
        
        if pages_needed > len(self.free_page_list):
            # Try eviction or fail
            self._evict_lru_pages(pages_needed)
        
        if pages_needed > len(self.free_page_list):
            raise Error("PagedKVCache: out of physical pages")
        
        var table = List[PageTableEntry]()
        
        for i in range(pages_needed):
            var phys_id = self.free_page_list.pop_back()
            self.allocated_page_count += 1
            
            var entry = PageTableEntry(
                physical_page_id=phys_id,
                ref_count=1,
                is_allocated=True,
                last_accessed=now_ns(),
            )
            table.append(entry)
        
        self.page_tables[sequence_id] = table
        return table
    
    fn append_token(
        mut self,
        sequence_id: String,
        layer: Int,
        k_vec: RuneTensor,
        v_vec: RuneTensor,
    ) raises:
        """Append single token KV to sequence, allocating new page if needed."""
        
        if sequence_id not in self.page_tables:
            raise Error("PagedKVCache: sequence not found: " + sequence_id)
        
        var table = self.page_tables[sequence_id]
        var position = self._get_current_length(table)
        var page_idx = position // PAGE_SIZE
        var offset_in_page = position % PAGE_SIZE
        
        # Allocate new page if needed
        if page_idx >= len(table):
            if len(self.free_page_list) == 0:
                self._evict_lru_pages(1)
            
            var phys_id = self.free_page_list.pop_back()
            var new_entry = PageTableEntry(
                physical_page_id=phys_id,
                ref_count=1,
                is_allocated=True,
                last_accessed=now_ns(),
            )
            table.append(new_entry)
        
        var entry = table[page_idx]
        var page = self.physical_pages[entry.physical_page_id]
        
        # Write K and V vectors
        var k_dst = page.k_data + (layer * PAGE_SIZE + offset_in_page) * self.kv_dim
        var v_dst = page.v_data + (layer * PAGE_SIZE + offset_in_page) * self.kv_dim
        
        memcpy(k_dst, k_vec.data, self.kv_dim)
        memcpy(v_dst, v_vec.data, self.kv_dim)
        
        entry.last_accessed = now_ns()
    
    fn get_kv_for_attention(
        self,
        sequence_id: String,
        layer: Int,
        position_start: Int,
        position_end: Int,
    ) raises -> (RuneTensor, RuneTensor):
        """Gather K/V tensors for attention computation."""
        
        var table = self.page_tables[sequence_id]
        var seq_len = position_end - position_start
        
        # Allocate contiguous gather buffer
        var k_gathered = allocate_tensor([seq_len, self.kv_dim], F16)
        var v_gathered = allocate_tensor([seq_len, self.kv_dim], F16)
        
        for pos in range(position_start, position_end):
            var page_idx = pos // PAGE_SIZE
            var offset = pos % PAGE_SIZE
            
            if page_idx >= len(table):
                raise Error("PagedKVCache: position out of bounds")
            
            var entry = table[page_idx]
            var page = self.physical_pages[entry.physical_page_id]
            
            # Copy from paged to contiguous
            var src_k = page.k_data + (layer * PAGE_SIZE + offset) * self.kv_dim
            var src_v = page.v_data + (layer * PAGE_SIZE + offset) * self.kv_dim
            
            var dst_k_offset = (pos - position_start) * self.kv_dim
            var dst_v_offset = (pos - position_start) * self.kv_dim
            
            memcpy(k_gathered.data + dst_k_offset, src_k, self.kv_dim)
            memcpy(v_gathered.data + dst_v_offset, src_v, self.kv_dim)
        
        return (k_gathered, v_gathered)
    
    fn _evict_lru_pages(mut self, count: Int) raises:
        """Evict least-recently-used pages (not referenced by active sequences)."""
        # Implementation: scan for lowest last_accessed with ref_count == 1
        pass
    
    fn batch_decode(
        self,
        sequences: List[String],
        query_states: List[RuneTensor],  # One per sequence
    ) raises -> List[RuneTensor]:
        """Batched attention for multiple sequences."""
        # Optimized path: group by similar lengths, use flash attention kernel
        pass
Batching Scheduler
mojo
# core/batch_scheduler.mojo

struct BatchScheduler:
    """Schedules concurrent requests for PagedAttention batching."""
    
    var waiting_queue: List[InferenceRequest]
    var active_batch: List[InferenceRequest]
    var max_batch_size: Int
    var max_tokens_per_batch: Int
    
    fn schedule(mut self) -> List[InferenceRequest]:
        """Form optimal batch from waiting queue."""
        
        var batch = List[InferenceRequest]()
        var current_tokens = 0
        
        # Priority: similar sequence lengths for efficiency
        self.waiting_queue.sort(fn(a, b) -> Bool {
            return a.current_length < b.current_length
        })
        
        for req in self.waiting_queue:
            if len(batch) >= self.max_batch_size:
                break
            
            var projected_tokens = current_tokens + req.current_length + req.max_new_tokens
            
            if projected_tokens > self.max_tokens_per_batch:
                break
            
            batch.append(req)
            current_tokens += req.current_length
        
        return batch

Phase 3: Multi-GPU & Cross-Platform Acceleration
Goal
Complete AES-ACC-004, AES-ACC-006, AES-ACC-008, AES-FND-006: Full transformer execution on CUDA, Metal, ROCm with automatic device selection.
CUDA Full Transformer Implementation
mojo
# core/cuda_transformer.mojo
# Complete transformer layer on NVIDIA GPU

from gpu.cuda import Stream, Event, memcpy_h2d_async, memcpy_d2h_async

struct CUDATransformerLayer:
    """GPU-resident transformer layer with persistent weights."""
    
    # Device memory handles
    var d_wq: CUDAFloat16Tensor
    var d_wk: CUDAFloat16Tensor
    var d_wv: CUDAFloat16Tensor
    var d_wo: CUDAFloat16Tensor
    var d_w1: CUDAFloat16Tensor
    var d_w2: CUDAFloat16Tensor
    var d_w3: CUDAFloat16Tensor
    
    var d_norm_attn: CUDAFloat16Tensor
    var d_norm_ffn: CUDAFloat16Tensor
    
    # CUDA kernels
    var gemm_kernel: CUDAGemmKernel
    var rmsnorm_kernel: CUDARMSNormKernel
    var rope_kernel: CUDARoPEKernel
    var flash_attn_kernel: CUDAFlashAttentionKernel
    
    fn __init__(
        out self,
        cpu_weights: TransformerBlock,
        stream: Stream,
    ) raises:
        """Upload weights to GPU once, reuse for all forward passes."""
        
        # Async H2D copy of all weights
        self.d_wq = upload_tensor(cpu_weights.wq, stream)
        self.d_wk = upload_tensor(cpu_weights.wk, stream)
        self.d_wv = upload_tensor(cpu_weights.wv, stream)
        self.d_wo = upload_tensor(cpu_weights.wo, stream)
        
        self.d_w1 = upload_tensor(cpu_weights.w1, stream)
        self.d_w2 = upload_tensor(cpu_weights.w2, stream)
        self.d_w3 = upload_tensor(cpu_weights.w3, stream)
        
        self.d_norm_attn = upload_tensor(cpu_weights.attention_norm, stream)
        self.d_norm_ffn = upload_tensor(cpu_weights.ffn_norm, stream)
        
        # Initialize kernels
        self.gemm_kernel = CUDAGemmKernel(stream)
        self.rmsnorm_kernel = CUDARMSNormKernel(stream)
        self.rope_kernel = CUDARoPEKernel(stream)
        self.flash_attn_kernel = CUDAFlashAttentionKernel(stream)
        
        stream.synchronize()
    
    fn forward(
        self,
        d_input: CUDAFloat16Tensor,
        position: Int,
        kv_cache: CUDAPagedKVCache,
        stream: Stream,
    ) raises -> CUDAFloat16Tensor:
        """GPU-only forward pass, no CPU sync until end."""
        
        # Attention norm
        var d_normed = self.rmsnorm_kernel.launch(d_input, self.d_norm_attn)
        
        # QKV projections (overlapped if possible)
        var d_q = self.gemm_kernel.launch(d_normed, self.d_wq)
        var d_k = self.gemm_kernel.launch(d_normed, self.d_wk)
        var d_v = self.gemm_kernel.launch(d_normed, self.d_wv)
        
        # RoPE
        self.rope_kernel.launch(d_q, d_k, position)
        
        # Write K/V to paged cache
        kv_cache.append_tokens(d_k, d_v)
        
        # Flash Attention
        var d_k_gathered = kv_cache.gather_k(position)
        var d_v_gathered = kv_cache.gather_v(position)
        var d_attn = self.flash_attn_kernel.launch(d_q, d_k_gathered, d_v_gathered)
        
        # Output projection
        var d_proj = self.gemm_kernel.launch(d_attn, self.d_wo)
        
        # Residual
        var d_post_attn = cuda_add(d_input, d_proj)
        
        # FFN
        var d_ffn_norm = self.rmsnorm_kernel.launch(d_post_attn, self.d_norm_ffn)
        var d_gate = self.gemm_kernel.launch(d_ffn_norm, self.d_w1)
        var d_up = self.gemm_kernel.launch(d_ffn_norm, self.d_w3)
        var d_activated = cuda_geglu(d_gate, d_up)
        var d_down = self.gemm_kernel.launch(d_activated, self.d_w2)
        
        # Final residual
        return cuda_add(d_post_attn, d_down)
Multi-GPU Pipeline Parallelism
mojo
# core/multi_gpu_pipeline.mojo

struct PipelineParallelTransformer:
    """Split transformer layers across multiple GPUs."""
    
    var devices: List[CUDADevice]
    var layer_ranges: List[Tuple[Int, Int]]  # (start_layer, end_layer) per device
    var pipelines: List[CUDATransformerPipeline]
    var communication_queue: Queue[TensorShard]
    
    fn __init__(
        out self,
        model_path: String,
        num_gpus: Int,
    ) raises:
        """Distribute layers evenly across available GPUs."""
        
        self.devices = discover_cuda_devices()
        if len(self.devices) < num_gpus:
            raise Error("Requested " + String(num_gpus) + " GPUs, found " + 
                       String(len(self.devices)))
        
        # Calculate layer distribution
        var total_layers = get_model_layer_count(model_path)
        var layers_per_gpu = total_layers // num_gpus
        
        for gpu_id in range(num_gpus):
            var start = gpu_id * layers_per_gpu
            var end = start + layers_per_gpu if gpu_id < num_gpus - 1 else total_layers
            
            self.layer_ranges.append((start, end))
            
            # Initialize pipeline on each GPU
            var pipeline = CUDATransformerPipeline(
                device=self.devices[gpu_id],
                layer_range=(start, end),
                model_path=model_path,
            )
            self.pipelines.append(pipeline)
    
    fn forward(
        self,
        input_ids: Tensor,
    ) raises -> Tensor:
        """Pipeline parallelism: each GPU processes micro-batches."""
        
        # Split input into micro-batches
        var micro_batches = split_into_microbatches(input_ids, len(self.pipelines))
        
        # Pipeline execution with bubble reduction
        var outputs = List[Tensor]()
        
        for i in range(len(micro_batches) + len(self.pipelines) - 1):
            # Forward pass through pipeline
            for gpu_id in range(len(self.pipelines)):
                var batch_idx = i - gpu_id
                if 0 <= batch_idx < len(micro_batches):
                    var hidden = micro_batches[batch_idx]
                    
                    # Async transfer to GPU if needed
                    var d_hidden = upload_if_needed(hidden, gpu_id)
                    
                    # Execute this GPU's layers
                    d_hidden = self.pipelines[gpu_id].forward(d_hidden)
                    
                    # Pass to next GPU or collect output
                    if gpu_id == len(self.pipelines) - 1:
                        outputs.append(download_tensor(d_hidden))
                    else:
                        self._pass_to_next_gpu(d_hidden, gpu_id)
        
        return concatenate(outputs)
Cross-Platform Abstraction
mojo
# core/accelerator_backend.mojo

trait AcceleratorBackend:
    """Unified interface for GPU/NPU backends."""
    
    fn upload_weights(self, weights: TransformerBlock) raises -> DeviceWeights
    fn forward(self, input: DeviceTensor, kv_cache: DeviceKVCache) raises -> DeviceTensor
    fn synchronize(self)
    fn get_memory_stats(self) -> MemoryStats

struct CUDABackend(AcceleratorBackend):
    """NVIDIA CUDA implementation."""
    var context: CUDAContext
    var stream: CUDAStream
    
    fn forward(...) raises -> DeviceTensor:
        # CUDA-specific implementation
        pass

struct MetalBackend(AcceleratorBackend):
    """Apple Metal implementation."""
    var device: MTLDevice
    var command_queue: MTLCommandQueue
    
    fn forward(...) raises -> DeviceTensor:
        # Metal-specific implementation
        pass

struct ROCmBackend(AcceleratorBackend):
    """AMD ROCm/HIP implementation."""
    var context: HIPContext
    
    fn forward(...) raises -> DeviceTensor:
        # HIP-specific implementation
        pass

Phase 4: Production Server & API Compatibility
Goal
Complete AES-SRV-006, AES-SRV-007, AES-SRV-008, AES-SRV-009: Full OpenAI and Ollama API compatibility with streaming, authentication, and rate limiting.
OpenAI-Compatible Server
mojo
# server/openai_server.mojo

from std.http import HTTPRequest, HTTPResponse, StatusCode
from std.json import JSONObject, JSONParser, JSONSerializer
from std.sync import Mutex, RwLock

struct OpenAICompatibleServer:
    """Production HTTP server with OpenAI API compatibility."""
    
    var engine: AesirEngine
    var config: ServerConfig
    
    # Concurrency control
    var request_semaphore: Semaphore
    var active_requests: Atomic[Int]
    var rate_limiter: TokenBucketRateLimiter
    
    # Authentication
    var api_key_store: APIKeyStore
    var auth_middleware: AuthMiddleware
    
    # Observability
    var metrics: PrometheusMetrics
    var request_logger: StructuredLogger
    
    fn __init__(
        out self,
        engine: AesirEngine,
        config: ServerConfig,
    ) raises:
        self.engine = engine
        self.config = config
        
        # Limit concurrent requests to prevent OOM
        self.request_semaphore = Semaphore(config.max_concurrent_requests)
        self.active_requests = Atomic[Int](0)
        
        # Rate limiting: 100 requests/minute per API key
        self.rate_limiter = TokenBucketRateLimiter(
            rate=100,
            burst=150,
            window_seconds=60,
        )
        
        self.api_key_store = APIKeyStore(config.keys_file)
        self.auth_middleware = AuthMiddleware(self.api_key_store)
        
        self.metrics = PrometheusMetrics()
        self.request_logger = StructuredLogger()
    
    fn handle_chat_completions(
        mut self,
        request: HTTPRequest,
    ) raises -> HTTPResponse:
        """POST /v1/chat/completions - OpenAI compatible."""
        
        var start_time = now_ns()
        var request_id = generate_request_id()
        
        # Authentication
        var auth_result = self.auth_middleware.verify(request)
        if not auth_result.success:
            return HTTPResponse.unauthorized()
        
        var api_key = auth_result.api_key
        
        # Rate limiting
        if not self.rate_limiter.allow(api_key):
            self.metrics.rate_limit_hits.increment()
            return HTTPResponse.too_many_requests()
        
        # Semaphore acquisition (backpressure)
        if not self.request_semaphore.try_acquire(timeout_ms=5000):
            return HTTPResponse.service_unavailable("Server at capacity")
        
        defer self.request_semaphore.release()
        
        # Parse request
        var body = JSONParser.parse(request.body)
        
        var messages = body.get_array("messages")
        var model = body.get_string("model", "default")
        var max_tokens = body.get_int("max_tokens", 16)
        var temperature = body.get_float("temperature", 0.7)
        var stream = body.get_bool("stream", False)
        var stop = body.get_string_array("stop", List[String]())
        
        # Validate parameters
        if max_tokens > self.config.max_tokens_limit:
            return HTTPResponse.bad_request("max_tokens exceeds limit")
        
        # Convert messages to prompt
        var prompt = self.format_chat_messages(messages)
        
        # Generation config
        var gen_config = GenerationConfig(
            max_new_tokens=max_tokens,
            temperature=temperature,
            stop_strings=stop,
        )
        
        # Stream or blocking response
        if stream:
            return self.handle_streaming_response(
                request_id, prompt, gen_config, request.client_fd
            )
        else:
            return self.handle_blocking_response(
                request_id, prompt, gen_config
            )
    
    fn handle_streaming_response(
        self,
        request_id: String,
        prompt: String,
        config: GenerationConfig,
        client_fd: Int32,
    ) raises -> HTTPResponse:
        """SSE streaming response."""
        
        # Send headers immediately
        var headers = HTTPHeaders()
        headers.set("Content-Type", "text/event-stream")
        headers.set("Cache-Control", "no-cache")
        headers.set("X-Request-ID", request_id)
        
        write_response_headers(client_fd, 200, headers)
        
        # Stream tokens
        var stream_callback = fn(token_text: String, is_last: Bool) -> Bool:
            var event = ServerSentEvent(
                data=JSONObject({
                    "id": request_id,
                    "object": "chat.completion.chunk",
                    "choices": [{
                        "delta": {"content": token_text},
                        "finish_reason": null if not is_last else "stop",
                    }],
                }).to_string(),
            )
            
            write_sse_event(client_fd, event)
            return true  # Continue streaming
        
        try:
            self.engine.generate_stream(prompt, config, stream_callback)
            
            # Final [DONE] event
            write_sse_event(client_fd, ServerSentEvent(data="[DONE]"))
            close_connection(client_fd)
            
        except e:
            # Log error and send error event
            self.request_logger.error("Streaming error", e, request_id)
            write_sse_event(client_fd, ServerSentEvent(
                data=JSONObject({"error": str(e)}).to_string(),
                event="error",
            ))
        
        return HTTPResponse.ok()  # Already sent headers
    
    fn handle_blocking_response(
        self,
        request_id: String,
        prompt: String,
        config: GenerationConfig,
    ) raises -> HTTPResponse:
        """Standard JSON response."""
        
        var result = self.engine.generate_tokens_config(prompt, config)
        
        var response = JSONObject({
            "id": request_id,
            "object": "chat.completion",
            "created": unix_timestamp(),
            "model": "aesir",
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": result.text,
                },
                "finish_reason": result.stop_reason,
            }],
            "usage": {
                "prompt_tokens": result.prompt_token_count,
                "completion_tokens": result.generated_token_count,
                "total_tokens": result.prompt_token_count + result.generated_token_count,
            },
        })
        
        return HTTPResponse.ok(response.to_string())
Ollama API Compatibility
mojo
# server/ollama_server.mojo

struct OllamaCompatibleServer:
    """Ollama API compatibility layer."""
    
    var model_store: DurableModelStore
    var engine_pool: EnginePool
    
    fn handle_generate(
        mut self,
        request: HTTPRequest,
    ) raises -> HTTPResponse:
        """POST /api/generate - Ollama generate endpoint."""
        
        var body = JSONParser.parse(request.body)
        var model_name = body.get_string("model")
        var prompt = body.get_string("prompt")
        var stream = body.get_bool("stream", True)
        var options = body.get_object("options", JSONObject())
        
        # Load model if not cached
        var model_path = self.model_store.resolve_model(model_name)
        var engine = self.engine_pool.get_or_create(model_path)
        
        # Convert Ollama options to GenerationConfig
        var config = GenerationConfig(
            temperature=options.get_float("temperature", 0.7),
            top_k=options.get_int("top_k", 40),
            top_p=options.get_float("top_p", 0.9),
            num_predict=options.get_int("num_predict", 128),
        )
        
        # Generate
        var result = engine.generate(prompt, config)
        
        return HTTPResponse.ok(JSONObject({
            "model": model_name,
            "response": result,
            "done": true,
        }).to_string())
    
    fn handle_pull(
        mut self,
        request: HTTPRequest,
    ) raises -> HTTPResponse:
        """POST /api/pull - Download model from registry."""
        
        var body = JSONParser.parse(request.body)
        var model_name =
