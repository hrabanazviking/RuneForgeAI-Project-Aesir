"""Streamed mixture-of-experts session (J-022): the first MoE forward in
Aesir, built for OLMoE from the Part II streaming machinery.

The resident set (J-017 D1) -- embeddings, attention, norms, routers,
output head -- is read through the ordinary GGUFSeer mmap. The routed
experts are NEVER touched through the mmap: each (layer, expert) is
admitted, bypassed, or refused by the J-018 ExpertCache (whole-expert
unit, byte budget, segmented probationary/frequency policy), and its
three slabs are read from the file at directory-true offsets through
the J-019 StreamReader (explicit pread + willneed advice for the next
selected expert). Payload bytes live in per-expert buffers whose total
tracks the cache's own residency: when the cache evicts, the payload
is dropped before the next admission is loaded.

Routing follows the file's published rule (J-016's adopted readings):
softmax over the router logits, top-k selection, weights renormalized
to sum 1; Q/K RMSNorm applied full-width (the file stores hidden-wide
norm vectors); RoPE is the NeoX rotate-half form at the file's base;
attention, norms, and GEMMs are the engine's existing host primitives,
the same ones the dense TransformerBlock uses.

Only arch "olmoe" is admitted. Any other architecture is refused by
name in the constructor: a mixture whose block maths this module does
not implement (shared experts, hybrid recurrence, per-head QK-norm
variants) must fail closed, never silently run dense-shaped.
"""
from std.collections import Dict
from std.math import exp

from loader.gguf import GGUFSeer, GGMLType
from core.mimir_well import MimirWell, KVCache, RuneTensor, f16, f32
from core.compute import rmsnorm, gemm_f16, silu, apply_rope, flash_attention_gqa
from core.inference import _embed_token_into
from core.expert_cache import (
    ExpertCache,
    ExpertCacheStats,
    ACCESS_HIT,
    ACCESS_MISS_ADMITTED,
    ACCESS_MISS_BYPASSED,
    ACCESS_MISS_TOO_LARGE,
)
from core.stream_reader import StreamReader


def _tensor_byte_size(element_count: Int, tensor_type: UInt32) raises -> Int:
    """Byte size of one tensor (or one expert slab) from its GGUF type.

    Mirrors the loader's own table for the types a MoE file carries;
    anything else raises rather than guessing a stride.
    """
    if tensor_type == 0:  # F32
        return element_count * 4
    if tensor_type == 1:  # F16
        return element_count * 2
    if tensor_type == 2:  # Q4_0
        return (element_count // 32) * 18
    if tensor_type == 8:  # Q8_0
        return (element_count // 32) * 34
    if tensor_type == 10:  # Q2_K
        return (element_count // 256) * 84
    if tensor_type == 11:  # Q3_K
        return (element_count // 256) * 110
    if tensor_type == 12:  # Q4_K
        return (element_count // 256) * 144
    if tensor_type == 13:  # Q5_K
        return (element_count // 256) * 176
    if tensor_type == 14:  # Q6_K
        return (element_count // 256) * 210
    raise Error("MoE session: unsupported GGUF tensor type " + String(Int(tensor_type)))


def _read_expert_slabs(
    mut reader: StreamReader,
    seer: GGUFSeer,
    layer: Int,
    expert: Int,
    gate_bytes: Int,
    up_bytes: Int,
    down_bytes: Int,
    mut payload: _ExpertPayload,
) raises:
    """Read one expert's three slabs at directory-true offsets."""
    var prefix = "blk." + String(layer) + "."
    var gate_off = seer.tensor_file_offsets[prefix + "ffn_gate_exps.weight"] + expert * gate_bytes
    var up_off = seer.tensor_file_offsets[prefix + "ffn_up_exps.weight"] + expert * up_bytes
    var down_off = seer.tensor_file_offsets[prefix + "ffn_down_exps.weight"] + expert * down_bytes
    reader.read_slab(gate_off, gate_bytes, payload.gate)
    reader.read_slab(up_off, up_bytes, payload.up)
    reader.read_slab(down_off, down_bytes, payload.down)


struct _ExpertPayload(Movable):
    """The three slabs of one expert, as read from disk."""

    var gate: List[UInt8]
    var up: List[UInt8]
    var down: List[UInt8]

    def __init__(out self, gate_bytes: Int, up_bytes: Int, down_bytes: Int):
        self.gate = List[UInt8](length=gate_bytes, fill=0)
        self.up = List[UInt8](length=up_bytes, fill=0)
        self.down = List[UInt8](length=down_bytes, fill=0)


struct MoEStreamSession(Movable):
    var seer: GGUFSeer
    var well: MimirWell
    var kv_cache: KVCache
    var reader: StreamReader
    var cache: ExpertCache
    var payloads: Dict[Int, _ExpertPayload]
    var payload_keys: List[Int]
    var scratch: _ExpertPayload
    var layer_count: Int
    var hidden: Int
    var ffn: Int
    var head_dim: Int
    var num_heads: Int
    var num_kv_heads: Int
    var expert_count: Int
    var expert_used: Int
    var context_length: Int
    var position: Int
    var cache_budget_bytes: Int
    var expert_bytes_total: Int
    var gate_slab_bytes: List[Int]
    var up_slab_bytes: List[Int]
    var down_slab_bytes: List[Int]
    var max_gate_bytes: Int
    var max_up_bytes: Int
    var max_down_bytes: Int

    def __init__(
        out self,
        path: String,
        context_length: Int,
        cache_budget_bytes: Int,
        well_bytes: Int = 536870912,
    ) raises:
        self.seer = GGUFSeer(path)
        self.well = MimirWell(well_bytes)
        self.seer.mmap_and_load(self.well)
        var arch = self.seer.config.architecture
        if arch != "olmoe":
            raise Error(
                "MoE stream session: architecture '"
                + arch
                + "' is not admitted -- this module implements the olmoe"
                + " block only (no shared experts, no hybrid recurrence);"
                + " other MoE families are refused by name, never run"
                + " dense-shaped"
            )
        self.layer_count = self.seer.config.block_count
        self.hidden = self.seer.config.embedding_length
        self.ffn = self.seer.config.feed_forward_length
        self.head_dim = self.seer.config.head_dim()
        self.num_heads = self.seer.config.head_count
        self.num_kv_heads = self.seer.config.head_count_kv
        self.expert_count = self.seer.config.expert_count
        self.expert_used = self.seer.config.expert_used_count
        self.context_length = context_length
        self.position = 0
        self.cache_budget_bytes = cache_budget_bytes
        self.kv_cache = KVCache(
            context_length, self.seer.config.kv_dim(), self.well, self.layer_count
        )
        self.reader = StreamReader(path)
        self.reader.advise_sequential()
        self.cache = ExpertCache(cache_budget_bytes, String("segmented"))
        self.payloads = Dict[Int, _ExpertPayload]()
        self.payload_keys = List[Int]()
        # Directory-true per-layer slab sizes: the folded tensor's byte
        # size divided by the expert count (J-015: slabs are uniform
        # within a tensor; the down tensor's type varies by layer).
        self.gate_slab_bytes = List[Int]()
        self.up_slab_bytes = List[Int]()
        self.down_slab_bytes = List[Int]()
        self.max_gate_bytes = 0
        self.max_up_bytes = 0
        self.max_down_bytes = 0
        self.expert_bytes_total = 0
        for layer in range(self.layer_count):
            var prefix = "blk." + String(layer) + "."
            var gate_name = prefix + "ffn_gate_exps.weight"
            var up_name = prefix + "ffn_up_exps.weight"
            var down_name = prefix + "ffn_down_exps.weight"
            var gate_b = (
                _tensor_byte_size(
                    self.ffn * self.hidden, self.seer.tensor_types[gate_name]
                )
            )
            var up_b = (
                _tensor_byte_size(
                    self.ffn * self.hidden, self.seer.tensor_types[up_name]
                )
            )
            var down_b = (
                _tensor_byte_size(
                    self.ffn * self.hidden, self.seer.tensor_types[down_name]
                )
            )
            self.gate_slab_bytes.append(gate_b)
            self.up_slab_bytes.append(up_b)
            self.down_slab_bytes.append(down_b)
            if gate_b > self.max_gate_bytes:
                self.max_gate_bytes = gate_b
            if up_b > self.max_up_bytes:
                self.max_up_bytes = up_b
            if down_b > self.max_down_bytes:
                self.max_down_bytes = down_b
            self.expert_bytes_total += (gate_b + up_b + down_b) * self.expert_count
        self.scratch = _ExpertPayload(
            self.max_gate_bytes, self.max_up_bytes, self.max_down_bytes
        )
        print(
            "[MOE] arch=olmoe layers="
            + String(self.layer_count)
            + " hidden="
            + String(self.hidden)
            + " experts="
            + String(self.expert_count)
            + " topk="
            + String(self.expert_used)
            + " expert_bytes="
            + String(self.expert_bytes_total)
            + " cache_budget_bytes="
            + String(self.cache_budget_bytes)
            + " context="
            + String(self.context_length)
        )

    def _slab_tensor(
        self, buffer: List[UInt8], rows: Int, cols: Int, tensor_type: UInt32
    ) raises -> RuneTensor[f16]:
        var ptr = Pointer[Scalar[f16], MutUntrackedOrigin](
            unsafe_from_address=Int(buffer.unsafe_ptr())
        )
        var fmt = GGMLType.to_compressed_format(tensor_type)
        return RuneTensor[f16].checked(rows, cols, ptr, True, fmt)

    def _reconcile_payloads(mut self) raises:
        """Drop payloads the cache no longer holds (evicted keys)."""
        var kept = List[Int]()
        for i in range(len(self.payload_keys)):
            var key = self.payload_keys[i]
            var layer = key // 1048576
            var expert = key % 1048576
            if self.cache.contains(layer, expert):
                kept.append(key)
            else:
                _ = self.payloads.pop(key)
        self.payload_keys = kept^

    def _expert_ffn(
        mut self,
        layer: Int,
        expert: Int,
        xn: RuneTensor[f16],
        weight: Float32,
        mut acc: List[Float32],
    ) raises:
        var size_bytes = (
            self.gate_slab_bytes[layer]
            + self.up_slab_bytes[layer]
            + self.down_slab_bytes[layer]
        )
        var code = self.cache.access(layer, expert, size_bytes)
        var key = layer * 1048576 + expert
        var use_scratch = False
        if code == ACCESS_HIT and key not in self.payloads:
            print(
                "[MOE-DEBUG] HIT without payload: layer=",
                layer,
                " expert=",
                expert,
                " contains=",
                self.cache.contains(layer, expert),
            )
        if code == ACCESS_HIT:
            pass
        elif code == ACCESS_MISS_ADMITTED:
            self._reconcile_payloads()
            var payload = _ExpertPayload(
                self.gate_slab_bytes[layer],
                self.up_slab_bytes[layer],
                self.down_slab_bytes[layer],
            )
            _read_expert_slabs(
                self.reader, self.seer, layer, expert,
                self.gate_slab_bytes[layer], self.up_slab_bytes[layer],
                self.down_slab_bytes[layer], payload,
            )
            self.payloads[key] = payload^
            self.payload_keys.append(key)
        else:
            # Bypassed or larger than the whole budget: compute from a
            # scratch payload; the bytes are streamed and not retained.
            # The reader demands exact-size buffers, so the scratch is
            # re-sized to this layer's slabs (its home size is the max).
            use_scratch = True
            self.scratch = _ExpertPayload(
                self.gate_slab_bytes[layer],
                self.up_slab_bytes[layer],
                self.down_slab_bytes[layer],
            )
            _read_expert_slabs(
                self.reader, self.seer, layer, expert,
                self.gate_slab_bytes[layer], self.up_slab_bytes[layer],
                self.down_slab_bytes[layer], self.scratch,
            )

        var prefix = "blk." + String(layer) + "."
        var gate_type = self.seer.tensor_types[prefix + "ffn_gate_exps.weight"]
        var up_type = self.seer.tensor_types[prefix + "ffn_up_exps.weight"]
        var down_type = self.seer.tensor_types[prefix + "ffn_down_exps.weight"]

        var gate_ptr = self.well.allocate(self.ffn)
        var up_ptr = self.well.allocate(self.ffn)
        var gate_out = RuneTensor[f16](1, self.ffn, gate_ptr, False)
        var up_out = RuneTensor[f16](1, self.ffn, up_ptr, False)

        if use_scratch:
            var gate_view = self._slab_tensor(self.scratch.gate, self.ffn, self.hidden, gate_type)
            var up_view = self._slab_tensor(self.scratch.up, self.ffn, self.hidden, up_type)
            gemm_f16(xn, gate_view, gate_out)
            gemm_f16(xn, up_view, up_out)
            silu(gate_out)
            for i in range(self.ffn):
                up_out.data.unsafe_store(
                    i, up_out.data.unsafe_load(i) * gate_out.data.unsafe_load(i)
                )
            var down_view = self._slab_tensor(self.scratch.down, self.hidden, self.ffn, down_type)
            var down_ptr = self.well.allocate(self.hidden)
            var down_out = RuneTensor[f16](1, self.hidden, down_ptr, False)
            gemm_f16(up_out, down_view, down_out)
            for i in range(self.hidden):
                acc[i] += weight * down_out.data.unsafe_load(i).cast[DType.float32]()
        else:
            ref payload = self.payloads[key]
            var gate_view = self._slab_tensor(payload.gate, self.ffn, self.hidden, gate_type)
            var up_view = self._slab_tensor(payload.up, self.ffn, self.hidden, up_type)
            gemm_f16(xn, gate_view, gate_out)
            gemm_f16(xn, up_view, up_out)
            silu(gate_out)
            for i in range(self.ffn):
                up_out.data.unsafe_store(
                    i, up_out.data.unsafe_load(i) * gate_out.data.unsafe_load(i)
                )
            var down_view = self._slab_tensor(payload.down, self.hidden, self.ffn, down_type)
            var down_ptr = self.well.allocate(self.hidden)
            var down_out = RuneTensor[f16](1, self.hidden, down_ptr, False)
            gemm_f16(up_out, down_view, down_out)
            for i in range(self.hidden):
                acc[i] += weight * down_out.data.unsafe_load(i).cast[DType.float32]()

    def _layer_forward(
        mut self, layer: Int, mut x: RuneTensor[f16], position: Int
    ) raises:
        var prefix = "blk." + String(layer) + "."
        var epsilon: Scalar[f32] = 1e-5
        if self.seer.config.rms_epsilon > 0.0:
            epsilon = self.seer.config.rms_epsilon
        var mark = self.well.offset

        # Residual copy.
        var residual_ptr = self.well.allocate(self.hidden)
        var residual = RuneTensor[f16](1, self.hidden, residual_ptr, False)
        for i in range(self.hidden):
            residual.data.unsafe_store(i, x.data.unsafe_load(i))

        # Attention: norm, QKV, full-width Q/K norm, NeoX RoPE, KV append,
        # flash attention, output projection -- the dense block's host
        # primitives, in the dense block's order.
        rmsnorm(x, self.seer.tensors[prefix + "attn_norm.weight"], epsilon)
        var q_ptr = self.well.allocate(self.num_heads * self.head_dim)
        var k_ptr = self.well.allocate(self.num_kv_heads * self.head_dim)
        var v_ptr = self.well.allocate(self.num_kv_heads * self.head_dim)
        var q = RuneTensor[f16](1, self.num_heads * self.head_dim, q_ptr, False)
        var k = RuneTensor[f16](1, self.num_kv_heads * self.head_dim, k_ptr, False)
        var v = RuneTensor[f16](1, self.num_kv_heads * self.head_dim, v_ptr, False)
        gemm_f16(x, self.seer.tensors[prefix + "attn_q.weight"], q)
        gemm_f16(x, self.seer.tensors[prefix + "attn_k.weight"], k)
        gemm_f16(x, self.seer.tensors[prefix + "attn_v.weight"], v)
        rmsnorm(q, self.seer.tensors[prefix + "attn_q_norm.weight"], epsilon)
        rmsnorm(k, self.seer.tensors[prefix + "attn_k_norm.weight"], epsilon)
        apply_rope(
            q, k, position, self.head_dim,
            self.seer.config.rope_freq_base, True,
        )
        self.kv_cache.append(layer, position, k, v)
        var active = min(position + 1, self.kv_cache.max_seq_len)
        var k_slice = self.kv_cache.get_k_slice(layer, active)
        var v_slice = self.kv_cache.get_v_slice(layer, active)
        var attn_ptr = self.well.allocate(self.num_heads * self.head_dim)
        var attn_out = RuneTensor[f16](1, self.num_heads * self.head_dim, attn_ptr, False)
        flash_attention_gqa(
            q, k_slice, v_slice, attn_out, active, self.head_dim,
            self.num_heads, self.num_kv_heads,
            Scalar[f32](0.0), Scalar[f32](0.0), 0, position,
        )
        gemm_f16(attn_out, self.seer.tensors[prefix + "attn_output.weight"], x)
        for i in range(self.hidden):
            x.data.unsafe_store(i, x.data.unsafe_load(i) + residual.data.unsafe_load(i))

        # FFN: norm, router, softmax, top-k, renormalize (J-016 rules).
        for i in range(self.hidden):
            residual.data.unsafe_store(i, x.data.unsafe_load(i))
        rmsnorm(x, self.seer.tensors[prefix + "ffn_norm.weight"], epsilon)
        var logits_ptr = self.well.allocate(self.expert_count)
        var logits = RuneTensor[f16](1, self.expert_count, logits_ptr, False)
        gemm_f16(x, self.seer.tensors[prefix + "ffn_gate_inp.weight"], logits)

        var probs = List[Float32]()
        var max_logit = logits.data.unsafe_load(0).cast[DType.float32]()
        for e in range(1, self.expert_count):
            var val = logits.data.unsafe_load(e).cast[DType.float32]()
            if val > max_logit:
                max_logit = val
        var denom: Float32 = 0.0
        for e in range(self.expert_count):
            var p = exp(logits.data.unsafe_load(e).cast[DType.float32]() - max_logit)
            probs.append(p)
            denom += p
        for e in range(self.expert_count):
            probs[e] = probs[e] / denom

        var chosen = List[Int]()
        var chosen_w = List[Float32]()
        var picked = List[Bool]()
        for _ in range(self.expert_count):
            picked.append(False)
        var wsum: Float32 = 0.0
        for _ in range(self.expert_used):
            var best = -1
            var best_p: Float32 = -1.0
            for e in range(self.expert_count):
                if not picked[e] and probs[e] > best_p:
                    best_p = probs[e]
                    best = e
            picked[best] = True
            chosen.append(best)
            chosen_w.append(best_p)
            wsum += best_p
        for i in range(len(chosen_w)):
            chosen_w[i] = chosen_w[i] / wsum

        # J-019 pipeline discipline: advise the kernel for every chosen
        # expert's slabs before the first read of this layer.
        for i in range(len(chosen)):
            var e = chosen[i]
            var gate_off = self.seer.tensor_file_offsets[prefix + "ffn_gate_exps.weight"] + e * self.gate_slab_bytes[layer]
            self.reader.advise_willneed(gate_off, self.gate_slab_bytes[layer])
            var up_off = self.seer.tensor_file_offsets[prefix + "ffn_up_exps.weight"] + e * self.up_slab_bytes[layer]
            self.reader.advise_willneed(up_off, self.up_slab_bytes[layer])
            var down_off = self.seer.tensor_file_offsets[prefix + "ffn_down_exps.weight"] + e * self.down_slab_bytes[layer]
            self.reader.advise_willneed(down_off, self.down_slab_bytes[layer])

        var acc = List[Float32]()
        for _ in range(self.hidden):
            acc.append(Float32(0.0))
        for i in range(len(chosen)):
            self._expert_ffn(layer, chosen[i], x, chosen_w[i], acc)
        for i in range(self.hidden):
            x.data.unsafe_store(
                i,
                residual.data.unsafe_load(i) + Scalar[f16](acc[i]),
            )
        self.well.offset = mark

    def step(mut self, token: Int) raises -> Int:
        """Process one token at the current position; return the greedy
        next token (argmax over the final norm + output projection)."""
        if token < 0 or self.position >= self.context_length:
            raise Error("MoE stream session token/context bound exceeded")
        var mark = self.well.offset
        var x_ptr = self.well.allocate(self.hidden)
        _embed_token_into(self.seer, token, x_ptr)
        var x = RuneTensor[f16](1, self.hidden, x_ptr, False)
        for layer in range(self.layer_count):
            self._layer_forward(layer, x, self.position)
        var epsilon: Scalar[f32] = 1e-5
        if self.seer.config.rms_epsilon > 0.0:
            epsilon = self.seer.config.rms_epsilon
        if "output_norm.weight" in self.seer.tensors:
            rmsnorm(x, self.seer.tensors["output_norm.weight"], epsilon)
        ref output_weight = self.seer.tensors["output.weight"]
        var vocab_size = output_weight.rows
        var logits_ptr = self.well.allocate(vocab_size)
        var logits = RuneTensor[f16](1, vocab_size, logits_ptr, False)
        var output_weight_eff = output_weight.copy()
        gemm_f16(x, output_weight_eff, logits)
        var best = 0
        var best_value = logits.data.unsafe_load(0).cast[DType.float32]()
        for i in range(1, vocab_size):
            var value = logits.data.unsafe_load(i).cast[DType.float32]()
            if value > best_value:
                best_value = value
                best = i
        self.well.offset = mark
        self.position += 1
        return best

    def cache_stats(mut self) -> ExpertCacheStats:
        return self.cache.snapshot()

    def describe_stream(self) -> String:
        return self.reader.describe()
