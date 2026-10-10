# armvegr/infer.mojo
# H059 — TinyLlama inference in pure Mojo (Domain D1 ARMVEGR).
#
# Decode loop for TinyLlama-1.1B-Chat-v1.0 (Q4_0, GQA 32Q/4KV). Uses the
# ARMVEGR compute substrate: gemv_fp16, rmsnorm_fp16, rope_fp16, and the
# sampler. Weights are dequantized once at load time to FP16.

from std.collections import Dict
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin
from std.math import exp

from armvegr.gguf_loader import GGUFLoader
from armvegr.gemv import gemv_fp16
from armvegr.rmsnorm import rmsnorm_fp16
from armvegr.rope import rope_fp16
from armvegr.sampler import Sampler
from armvegr.sp_tokenizer import SPTokenizer
from armvegr.kv_cache import KVCache


struct TinyLlama:
    """TinyLlama-1.1B-Chat-v1.0 inference engine."""
    var dim: Int
    var n_layers: Int
    var n_heads: Int
    var n_kv_heads: Int
    var head_dim: Int
    var ffn_dim: Int
    var vocab: Int
    var weights: Dict[String, Pointer[Float16, MutUntrackedOrigin]]
    var weight_sizes: Dict[String, Int]
    var loaded: Bool

    def __init__(out self):
        self.dim = 2048
        self.n_layers = 22
        self.n_heads = 32
        self.n_kv_heads = 4
        self.head_dim = 64
        self.ffn_dim = 5632
        self.vocab = 32000
        self.weights = Dict[String, Pointer[Float16, MutUntrackedOrigin]]()
        self.weight_sizes = Dict[String, Int]()
        self.loaded = False

    def load(mut self, path: String) raises:
        var loader = GGUFLoader()
        loader.open(path)
        # Dequantize all weights to FP16.
        var names = List[String]()
        names.append("token_embd.weight")
        names.append("output.weight")
        names.append("output_norm.weight")
        for layer in range(self.n_layers):
            var p = String("blk.") + String(layer) + String(".")
            names.append(p + "attn_norm.weight")
            names.append(p + "attn_q.weight")
            names.append(p + "attn_k.weight")
            names.append(p + "attn_v.weight")
            names.append(p + "attn_output.weight")
            names.append(p + "ffn_norm.weight")
            names.append(p + "ffn_gate.weight")
            names.append(p + "ffn_up.weight")
            names.append(p + "ffn_down.weight")
        for i in range(len(names)):
            var name = names[i]
            var idx = loader.find(name)
            ref d = loader.descs[idx]
            var n = d.element_count()
            var buf = unsafe_alloc[Float16](n)
            loader.dequantize(name, buf)
            self.weights[name] = buf
            self.weight_sizes[name] = n
        loader.close()
        self.loaded = True

    def free(mut self) raises:
        for name in self.weights.keys():
            self.weights[name].unsafe_free()
        self.weights = Dict[String, Pointer[Float16, MutUntrackedOrigin]]()
        self.weight_sizes = Dict[String, Int]()
        self.loaded = False


struct Inference:
    """Single-sequence decode loop over a TinyLlama model."""
    var model: TinyLlama
    var k_cache: Pointer[Float16, MutUntrackedOrigin]
    var v_cache: Pointer[Float16, MutUntrackedOrigin]
    var max_seq: Int
    var seq_len: Int
    # Reusable activation buffers (FP16).
    var x: Pointer[Float16, MutUntrackedOrigin]
    var h: Pointer[Float16, MutUntrackedOrigin]
    var q: Pointer[Float16, MutUntrackedOrigin]
    var k: Pointer[Float16, MutUntrackedOrigin]
    var v: Pointer[Float16, MutUntrackedOrigin]
    var attn_out: Pointer[Float16, MutUntrackedOrigin]
    var ffn_g: Pointer[Float16, MutUntrackedOrigin]
    var ffn_u: Pointer[Float16, MutUntrackedOrigin]
    var logits: Pointer[Float16, MutUntrackedOrigin]

    def __init__(out self, max_seq: Int = 256):
        self.model = TinyLlama()
        self.max_seq = max_seq
        self.seq_len = 0
        var kd = 22 * max_seq * 4 * 64
        self.k_cache = unsafe_alloc[Float16](kd)
        self.v_cache = unsafe_alloc[Float16](kd)
        for i in range(kd):
            self.k_cache.unsafe_offset(i).unsafe_store(Float16(0.0))
            self.v_cache.unsafe_offset(i).unsafe_store(Float16(0.0))
        self.x = unsafe_alloc[Float16](2048)
        self.h = unsafe_alloc[Float16](2048)
        self.q = unsafe_alloc[Float16](2048)
        self.k = unsafe_alloc[Float16](256)
        self.v = unsafe_alloc[Float16](256)
        self.attn_out = unsafe_alloc[Float16](2048)
        self.ffn_g = unsafe_alloc[Float16](5632)
        self.ffn_u = unsafe_alloc[Float16](5632)
        self.logits = unsafe_alloc[Float16](32000)

    def load(mut self, path: String) raises:
        self.model.load(path)

    def _k_ptr(self, layer: Int, pos: Int, kh: Int) -> Pointer[Float16, MutUntrackedOrigin]:
        var off = ((layer * self.max_seq + pos) * 4 + kh) * 64
        return self.k_cache.unsafe_offset(off)

    def _v_ptr(self, layer: Int, pos: Int, kh: Int) -> Pointer[Float16, MutUntrackedOrigin]:
        var off = ((layer * self.max_seq + pos) * 4 + kh) * 64
        return self.v_cache.unsafe_offset(off)

    def forward(mut self, token: Int) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """One decode step. Returns pointer to 32000 logits (FP16)."""
        var pos = self.seq_len
        # rope_fp16 takes raw theta (it computes ln(theta) internally).
        var theta = Float32(10000.0)
        # Embedding.
        var emb = self.model.weights["token_embd.weight"]
        var eoff = token * 2048
        for i in range(2048):
            self.x.unsafe_offset(i).unsafe_store(emb.unsafe_offset(eoff + i).unsafe_load())
        # Layers.
        for layer in range(22):
            var p = String("blk.") + String(layer) + String(".")
            # Attn norm.
            rmsnorm_fp16(
                self.x, self.model.weights[p + "attn_norm.weight"], self.h, 2048, Float32(1e-5)
            )
            # QKV.
            gemv_fp16(self.model.weights[p + "attn_q.weight"], self.h, self.q, 2048, 2048)
            gemv_fp16(self.model.weights[p + "attn_k.weight"], self.h, self.k, 256, 2048)
            gemv_fp16(self.model.weights[p + "attn_v.weight"], self.h, self.v, 256, 2048)
            # RoPE (in-place on q/k).
            for hq in range(32):
                rope_fp16(
                    self.q.unsafe_offset(hq * 64),
                    self.q.unsafe_offset(hq * 64),
                    64, pos, theta,
                )
            for hk in range(4):
                rope_fp16(
                    self.k.unsafe_offset(hk * 64),
                    self.k.unsafe_offset(hk * 64),
                    64, pos, theta,
                )
            # KV cache append.
            for hk in range(4):
                var kd = self._k_ptr(layer, pos, hk)
                var vd = self._v_ptr(layer, pos, hk)
                for i in range(64):
                    kd.unsafe_offset(i).unsafe_store(self.k.unsafe_offset(hk * 64 + i).unsafe_load())
                    vd.unsafe_offset(i).unsafe_store(self.v.unsafe_offset(hk * 64 + i).unsafe_load())
            # GQA attention.
            for hq in range(32):
                var kh = hq // 8
                var qh = self.q.unsafe_offset(hq * 64)
                # Scores.
                var scores = unsafe_alloc[Float32](pos + 1)
                var m = Float32(-1e30)
                for s in range(pos + 1):
                    var kp = self._k_ptr(layer, s, kh)
                    var dot = Float32(0.0)
                    for d in range(64):
                        dot += Float32(qh.unsafe_offset(d).unsafe_load()) * Float32(
                            kp.unsafe_offset(d).unsafe_load()
                        )
                    var sc = dot / Float32(8.0)  # sqrt(64)
                    scores.unsafe_offset(s).unsafe_store(sc)
                    if sc > m:
                        m = sc
                var esum = Float32(0.0)
                for s in range(pos + 1):
                    var e = exp(scores.unsafe_offset(s).unsafe_load() - m)
                    scores.unsafe_offset(s).unsafe_store(e)
                    esum += e
                var inv = Float32(1.0) / esum
                var oh = self.attn_out.unsafe_offset(hq * 64)
                for d in range(64):
                    var acc = Float32(0.0)
                    for s in range(pos + 1):
                        var vp = self._v_ptr(layer, s, kh)
                        acc += (
                            scores.unsafe_offset(s).unsafe_load()
                            * inv
                            * Float32(vp.unsafe_offset(d).unsafe_load())
                        )
                    oh.unsafe_offset(d).unsafe_store(Float16(acc))
                scores.unsafe_free()
            # Attn output proj.
            gemv_fp16(
                self.model.weights[p + "attn_output.weight"],
                self.attn_out, self.h, 2048, 2048,
            )
            # Residual.
            for i in range(2048):
                var xv = Float32(self.x.unsafe_offset(i).unsafe_load())
                var hv = Float32(self.h.unsafe_offset(i).unsafe_load())
                self.x.unsafe_offset(i).unsafe_store(Float16(xv + hv))
            # FFN norm.
            rmsnorm_fp16(
                self.x, self.model.weights[p + "ffn_norm.weight"], self.h, 2048, Float32(1e-5)
            )
            # Gate and Up.
            gemv_fp16(self.model.weights[p + "ffn_gate.weight"], self.h, self.ffn_g, 5632, 2048)
            gemv_fp16(self.model.weights[p + "ffn_up.weight"], self.h, self.ffn_u, 5632, 2048)
            # SiLU(gate) * up.
            for i in range(5632):
                var g = Float32(self.ffn_g.unsafe_offset(i).unsafe_load())
                var u = Float32(self.ffn_u.unsafe_offset(i).unsafe_load())
                var silu = g / (Float32(1.0) + exp(-g))
                self.ffn_g.unsafe_offset(i).unsafe_store(Float16(silu * u))
            # Down.
            gemv_fp16(
                self.model.weights[p + "ffn_down.weight"], self.ffn_g, self.h, 2048, 5632
            )
            # Residual.
            for i in range(2048):
                var xv2 = Float32(self.x.unsafe_offset(i).unsafe_load())
                var hv2 = Float32(self.h.unsafe_offset(i).unsafe_load())
                self.x.unsafe_offset(i).unsafe_store(Float16(xv2 + hv2))
        # Final norm.
        rmsnorm_fp16(
            self.x, self.model.weights["output_norm.weight"], self.h, 2048, Float32(1e-5)
        )
        # LM head.
        gemv_fp16(self.model.weights["output.weight"], self.h, self.logits, 32000, 2048)
        self.seq_len += 1
        return self.logits


def infer_version() -> String:
    return "0.1.0"
