# armvegr/infer.mojo
# H059 — TinyLlama inference in pure Mojo (Domain D1 ARMVEGR).
# H136 — production hardening: fail-closed error paths on load/forward
# (missing tensor, shape mismatch, unloaded model, token out of range,
# KV-cache capacity), Inference.reset/prefill/free, forward_nocache
# (cache-free reference for the H051-style cache-correctness check), and
# TinyLlama.shallow_copy for weight-shared batching (H137).
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
from armvegr.gemm_tuned import gemm_fp16_tuned, gemm_default_tune


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
    var owns_weights: Bool

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
        self.owns_weights = True

    def shallow_copy(self) -> TinyLlama:
        """H136/H137 — share weight buffers without copying (batching).

        The copy references the same dequantized FP16 buffers; only the
        owner (owns_weights=True) may free them. Lets N Inference states
        share one 2.2 GiB weight set instead of loading it N times.
        """
        var c = TinyLlama()
        c.dim = self.dim
        c.n_layers = self.n_layers
        c.n_heads = self.n_heads
        c.n_kv_heads = self.n_kv_heads
        c.head_dim = self.head_dim
        c.ffn_dim = self.ffn_dim
        c.vocab = self.vocab
        c.weights = self.weights.copy()
        c.weight_sizes = self.weight_sizes.copy()
        c.loaded = self.loaded
        c.owns_weights = False
        return c^

    def _expect_shape(self, name: String, got: Int, want: Int) raises:
        if got != want:
            raise Error(
                "infer: tensor shape mismatch: " + name + " has "
                + String(got) + " elements, expected " + String(want)
                + " (wrong model file?)"
            )

    def load(mut self, path: String) raises:
        var loader = GGUFLoader()
        loader.open(path)
        # Dequantize all weights to FP16, validating shapes fail-closed
        # (a corrupt or wrong model file must never silently mis-generate).
        var names = List[String]()
        var wants = List[Int]()
        names.append("token_embd.weight"); wants.append(32000 * 2048)
        names.append("output.weight"); wants.append(32000 * 2048)
        names.append("output_norm.weight"); wants.append(2048)
        for layer in range(self.n_layers):
            var p = String("blk.") + String(layer) + String(".")
            names.append(p + "attn_norm.weight"); wants.append(2048)
            names.append(p + "attn_q.weight"); wants.append(2048 * 2048)
            names.append(p + "attn_k.weight"); wants.append(256 * 2048)
            names.append(p + "attn_v.weight"); wants.append(256 * 2048)
            names.append(p + "attn_output.weight"); wants.append(2048 * 2048)
            names.append(p + "ffn_norm.weight"); wants.append(2048)
            names.append(p + "ffn_gate.weight"); wants.append(5632 * 2048)
            names.append(p + "ffn_up.weight"); wants.append(5632 * 2048)
            names.append(p + "ffn_down.weight"); wants.append(2048 * 5632)
        for i in range(len(names)):
            var name = names[i]
            var idx = loader.find(name)  # raises on missing tensor
            ref d = loader.descs[idx]
            var n = d.element_count()
            self._expect_shape(name, n, wants[i])
            var buf = unsafe_alloc[Float16](n)
            loader.dequantize(name, buf)
            self.weights[name] = buf
            self.weight_sizes[name] = n
        loader.close()
        self.loaded = True
        self.owns_weights = True

    def free(mut self) raises:
        if self.owns_weights:
            for name in self.weights.keys():
                self.weights[name].unsafe_free()
        self.weights = Dict[String, Pointer[Float16, MutUntrackedOrigin]]()
        self.weight_sizes = Dict[String, Int]()
        self.loaded = False
        self.owns_weights = True


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
    # H173 — preallocated attention score buffer (max_seq fp32): forward()
    # no longer allocates/frees per head per layer per step.
    var scores_buf: Pointer[Float32, MutUntrackedOrigin]
    # H173 — precomputed weight-dict key strings: forward() no longer
    # builds "blk.<layer>.<name>" Strings per layer per step.
    var wkey_embd: String
    var wkey_out: String
    var wkey_out_norm: String
    var wkey_attn_norm: List[String]
    var wkey_attn_q: List[String]
    var wkey_attn_k: List[String]
    var wkey_attn_v: List[String]
    var wkey_attn_out: List[String]
    var wkey_ffn_norm: List[String]
    var wkey_ffn_gate: List[String]
    var wkey_ffn_up: List[String]
    var wkey_ffn_down: List[String]

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
        self.scores_buf = unsafe_alloc[Float32](max_seq)
        self.wkey_embd = String("token_embd.weight")
        self.wkey_out = String("output.weight")
        self.wkey_out_norm = String("output_norm.weight")
        self.wkey_attn_norm = List[String]()
        self.wkey_attn_q = List[String]()
        self.wkey_attn_k = List[String]()
        self.wkey_attn_v = List[String]()
        self.wkey_attn_out = List[String]()
        self.wkey_ffn_norm = List[String]()
        self.wkey_ffn_gate = List[String]()
        self.wkey_ffn_up = List[String]()
        self.wkey_ffn_down = List[String]()
        for layer in range(22):
            var lp = String("blk.") + String(layer) + String(".")
            self.wkey_attn_norm.append(lp + "attn_norm.weight")
            self.wkey_attn_q.append(lp + "attn_q.weight")
            self.wkey_attn_k.append(lp + "attn_k.weight")
            self.wkey_attn_v.append(lp + "attn_v.weight")
            self.wkey_attn_out.append(lp + "attn_output.weight")
            self.wkey_ffn_norm.append(lp + "ffn_norm.weight")
            self.wkey_ffn_gate.append(lp + "ffn_gate.weight")
            self.wkey_ffn_up.append(lp + "ffn_up.weight")
            self.wkey_ffn_down.append(lp + "ffn_down.weight")

    def load(mut self, path: String) raises:
        self.model.load(path)

    def reset(mut self):
        """H136 — start a new sequence. Cache slots are always written
        before they are read at every position, so resetting seq_len is
        a clean session reset (verified by H137 Test C)."""
        self.seq_len = 0

    def free(mut self) raises:
        """H136 — release every owned buffer, then the model weights."""
        self.k_cache.unsafe_free()
        self.v_cache.unsafe_free()
        self.x.unsafe_free()
        self.h.unsafe_free()
        self.q.unsafe_free()
        self.k.unsafe_free()
        self.v.unsafe_free()
        self.attn_out.unsafe_free()
        self.ffn_g.unsafe_free()
        self.ffn_u.unsafe_free()
        self.logits.unsafe_free()
        self.scores_buf.unsafe_free()
        self.model.free()

    def prefill(
        mut self, tokens: List[Int]
    ) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """H136 — prefill orchestration: run the prompt through the model,
        growing the KV cache. Returns the last step's logits (decode can
        continue directly). Raises fail-closed on bad input."""
        if len(tokens) == 0:
            raise Error("infer: prefill needs >= 1 token")
        var lp = self.forward(tokens[0])
        for i in range(1, len(tokens)):
            lp = self.forward(tokens[i])
        return lp

    def prefill_chunked(
        mut self, tokens: List[Int], chunk: Int
    ) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """H161/H174 — chunked prefill orchestration. chunk <= 1 behaves
        exactly like prefill(). H174 replaces the chunk interior with
        batched GEMM computation; the H161 baseline processes each chunk
        token-by-token (bit-identical to prefill by construction)."""
        if len(tokens) == 0:
            raise Error("infer: prefill_chunked needs >= 1 token")
        if chunk <= 1:
            return self.prefill(tokens)
        var done = 0
        # Initialized to self.logits (forward_chunk always returns it);
        # overwritten by the first chunk below.
        var lp: Pointer[Float16, MutUntrackedOrigin] = self.logits
        while done < len(tokens):
            var csz = chunk
            if done + csz > len(tokens):
                csz = len(tokens) - done
            var sub = List[Int]()
            for j in range(csz):
                sub.append(tokens[done + j])
            lp = self.forward_chunk(sub, csz)
            done += csz
        return lp

    def forward_chunk(
        mut self, tokens: List[Int], chunk: Int
    ) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """H174 — chunked prefill: process up to `chunk` tokens with batched
        GEMMs (compute-bound) for the projections and FFN, per-token
        attention identical to forward(). Returns the last token's logits.

        Correctness: logits within 1e-3 of prefill() (test-asserted); the
        attention math is the same fp32 code as forward(), only the
        projection/FFN summation order differs (blocked GEMM vs GEMV)."""
        var ntok = len(tokens)
        if ntok == 0:
            raise Error("infer: forward_chunk needs >= 1 token")
        if chunk <= 0 or chunk < ntok:
            raise Error("infer: forward_chunk chunk must cover tokens")
        if not self.model.loaded:
            raise Error("infer: forward_chunk on unloaded model")
        if self.seq_len + ntok > self.max_seq:
            raise Error("infer: forward_chunk exceeds max_seq")
        for t in range(ntok):
            var tid = tokens[t]
            if tid < 0 or tid >= self.model.vocab:
                raise Error("infer: token id out of range in forward_chunk")
        var C = ntok
        var theta = Float32(10000.0)
        # Chunk workspace (per call, not per decode step).
        var xc = unsafe_alloc[Float16](C * 2048)
        var hc = unsafe_alloc[Float16](C * 2048)
        var ht = unsafe_alloc[Float16](2048 * C)
        var qall = unsafe_alloc[Float16](2048 * C)
        var kall = unsafe_alloc[Float16](256 * C)
        var vall = unsafe_alloc[Float16](256 * C)
        var oall = unsafe_alloc[Float16](2048 * C)
        var gg = unsafe_alloc[Float16](5632 * C)
        var uu = unsafe_alloc[Float16](5632 * C)
        var qh = unsafe_alloc[Float16](64)
        var kh = unsafe_alloc[Float16](64)
        var vh = unsafe_alloc[Float16](64)
        var oh = unsafe_alloc[Float16](64)
        var tune = gemm_default_tune()
        # Embedding gather.
        var emb = self.model.weights[self.wkey_embd]
        for c in range(C):
            var eoff = tokens[c] * 2048
            for i in range(2048):
                xc.unsafe_offset(c * 2048 + i).unsafe_store(
                    emb.unsafe_offset(eoff + i).unsafe_load()
                )
        var pos0 = self.seq_len
        for layer in range(22):
            var w_attn_norm = self.model.weights[self.wkey_attn_norm[layer]]
            var w_q = self.model.weights[self.wkey_attn_q[layer]]
            var w_k = self.model.weights[self.wkey_attn_k[layer]]
            var w_v = self.model.weights[self.wkey_attn_v[layer]]
            var w_o = self.model.weights[self.wkey_attn_out[layer]]
            var w_ffn_norm = self.model.weights[self.wkey_ffn_norm[layer]]
            var w_g = self.model.weights[self.wkey_ffn_gate[layer]]
            var w_u = self.model.weights[self.wkey_ffn_up[layer]]
            var w_d = self.model.weights[self.wkey_ffn_down[layer]]
            # Attn norm per row.
            for c in range(C):
                rmsnorm_fp16(
                    xc.unsafe_offset(c * 2048), w_attn_norm,
                    hc.unsafe_offset(c * 2048), 2048, Float32(1e-5),
                )
            _transpose_f16(hc, ht, C, 2048)
            # QKV as batched GEMMs: [out,2048] x [2048,C].
            gemm_fp16_tuned(w_q, ht, qall, 2048, C, 2048, tune)
            gemm_fp16_tuned(w_k, ht, kall, 256, C, 2048, tune)
            gemm_fp16_tuned(w_v, ht, vall, 256, C, 2048, tune)
            # Per-token RoPE + cache append + attention (same math as
            # forward(), fp32 scores).
            for c in range(C):
                var pos = pos0 + c
                for hk in range(4):
                    for d in range(64):
                        kh.unsafe_offset(d).unsafe_store(
                            kall.unsafe_offset((hk * 64 + d) * C + c).unsafe_load()
                        )
                        vh.unsafe_offset(d).unsafe_store(
                            vall.unsafe_offset((hk * 64 + d) * C + c).unsafe_load()
                        )
                    rope_fp16(kh, kh, 64, pos, theta)
                    var kd = self._k_ptr(layer, pos, hk)
                    var vd = self._v_ptr(layer, pos, hk)
                    for d in range(64):
                        kd.unsafe_offset(d).unsafe_store(kh.unsafe_offset(d).unsafe_load())
                        vd.unsafe_offset(d).unsafe_store(vh.unsafe_offset(d).unsafe_load())
                for hq in range(32):
                    var khq = hq // 8
                    for d in range(64):
                        qh.unsafe_offset(d).unsafe_store(
                            qall.unsafe_offset((hq * 64 + d) * C + c).unsafe_load()
                        )
                    rope_fp16(qh, qh, 64, pos, theta)
                    var m = Float32(-1e30)
                    for st in range(pos + 1):
                        var kp = self._k_ptr(layer, st, khq)
                        var dot = Float32(0.0)
                        for d in range(64):
                            dot += Float32(qh.unsafe_offset(d).unsafe_load()) * Float32(
                                kp.unsafe_offset(d).unsafe_load()
                            )
                        var sc = dot / Float32(8.0)
                        self.scores_buf.unsafe_offset(st).unsafe_store(sc)
                        if sc > m:
                            m = sc
                    var esum = Float32(0.0)
                    for st in range(pos + 1):
                        var e = exp(self.scores_buf.unsafe_offset(st).unsafe_load() - m)
                        self.scores_buf.unsafe_offset(st).unsafe_store(e)
                        esum += e
                    var inv = Float32(1.0) / esum
                    for d in range(64):
                        var acc = Float32(0.0)
                        for st in range(pos + 1):
                            var vp = self._v_ptr(layer, st, khq)
                            acc += (
                                self.scores_buf.unsafe_offset(st).unsafe_load()
                                * inv
                                * Float32(vp.unsafe_offset(d).unsafe_load())
                            )
                        oh.unsafe_offset(d).unsafe_store(Float16(acc))
                    for d in range(64):
                        oall.unsafe_offset((hq * 64 + d) * C + c).unsafe_store(
                            oh.unsafe_offset(d).unsafe_load()
                        )
            # Attn output proj as GEMM.
            gemm_fp16_tuned(w_o, oall, ht, 2048, C, 2048, tune)
            _transpose_f16(ht, hc, 2048, C)
            for c in range(C):
                for i in range(2048):
                    var xv = Float32(xc.unsafe_offset(c * 2048 + i).unsafe_load())
                    var hv = Float32(hc.unsafe_offset(c * 2048 + i).unsafe_load())
                    xc.unsafe_offset(c * 2048 + i).unsafe_store(Float16(xv + hv))
            # FFN norm per row, then batched GEMMs.
            for c in range(C):
                rmsnorm_fp16(
                    xc.unsafe_offset(c * 2048), w_ffn_norm,
                    hc.unsafe_offset(c * 2048), 2048, Float32(1e-5),
                )
            _transpose_f16(hc, ht, C, 2048)
            gemm_fp16_tuned(w_g, ht, gg, 5632, C, 2048, tune)
            gemm_fp16_tuned(w_u, ht, uu, 5632, C, 2048, tune)
            for i in range(5632 * C):
                var gv = Float32(gg.unsafe_offset(i).unsafe_load())
                var uv = Float32(uu.unsafe_offset(i).unsafe_load())
                var silu = gv / (Float32(1.0) + exp(-gv))
                gg.unsafe_offset(i).unsafe_store(Float16(silu * uv))
            gemm_fp16_tuned(w_d, gg, ht, 2048, C, 5632, tune)
            _transpose_f16(ht, hc, 2048, C)
            for c in range(C):
                for i in range(2048):
                    var xv2 = Float32(xc.unsafe_offset(c * 2048 + i).unsafe_load())
                    var hv2 = Float32(hc.unsafe_offset(c * 2048 + i).unsafe_load())
                    xc.unsafe_offset(c * 2048 + i).unsafe_store(Float16(xv2 + hv2))
        # Final norm on the last token only, then the LM head.
        var last = (C - 1) * 2048
        rmsnorm_fp16(
            xc.unsafe_offset(last), self.model.weights[self.wkey_out_norm],
            self.h, 2048, Float32(1e-5),
        )
        gemv_fp16(self.model.weights[self.wkey_out], self.h, self.logits, 32000, 2048)
        self.seq_len += ntok
        xc.unsafe_free()
        hc.unsafe_free()
        ht.unsafe_free()
        qall.unsafe_free()
        kall.unsafe_free()
        vall.unsafe_free()
        oall.unsafe_free()
        gg.unsafe_free()
        uu.unsafe_free()
        qh.unsafe_free()
        kh.unsafe_free()
        vh.unsafe_free()
        oh.unsafe_free()
        return self.logits

    def _k_ptr(self, layer: Int, pos: Int, kh: Int) -> Pointer[Float16, MutUntrackedOrigin]:
        var off = ((layer * self.max_seq + pos) * 4 + kh) * 64
        return self.k_cache.unsafe_offset(off)

    def _v_ptr(self, layer: Int, pos: Int, kh: Int) -> Pointer[Float16, MutUntrackedOrigin]:
        var off = ((layer * self.max_seq + pos) * 4 + kh) * 64
        return self.v_cache.unsafe_offset(off)

    def forward(mut self, token: Int) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """One decode step. Returns pointer to 32000 logits (FP16).

        H136 fail-closed guards: unloaded model, token id out of range,
        and KV-cache capacity are all hard errors — never silent.
        """
        if not self.model.loaded:
            raise Error("infer: forward on unloaded model (call load() first)")
        if token < 0 or token >= self.model.vocab:
            raise Error(
                "infer: token id out of range: " + String(token)
                + " (vocab " + String(self.model.vocab) + ")"
            )
        if self.seq_len >= self.max_seq:
            raise Error(
                "infer: sequence length " + String(self.seq_len)
                + " reached max_seq " + String(self.max_seq)
                + " (KV cache full; reset() or raise max_seq)"
            )
        var pos = self.seq_len
        # rope_fp16 takes raw theta (it computes ln(theta) internally).
        var theta = Float32(10000.0)
        # Embedding.
        var emb = self.model.weights[self.wkey_embd]
        var eoff = token * 2048
        for i in range(2048):
            self.x.unsafe_offset(i).unsafe_store(emb.unsafe_offset(eoff + i).unsafe_load())
        # Layers.
        for layer in range(22):
            # Attn norm.
            rmsnorm_fp16(
                self.x, self.model.weights[self.wkey_attn_norm[layer]], self.h, 2048, Float32(1e-5)
            )
            # QKV.
            gemv_fp16(self.model.weights[self.wkey_attn_q[layer]], self.h, self.q, 2048, 2048)
            gemv_fp16(self.model.weights[self.wkey_attn_k[layer]], self.h, self.k, 256, 2048)
            gemv_fp16(self.model.weights[self.wkey_attn_v[layer]], self.h, self.v, 256, 2048)
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
                # Scores (H173: reused preallocated buffer — no per-head alloc).
                var scores = self.scores_buf
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
            # Attn output proj.
            gemv_fp16(
                self.model.weights[self.wkey_attn_out[layer]],
                self.attn_out, self.h, 2048, 2048,
            )
            # Residual.
            for i in range(2048):
                var xv = Float32(self.x.unsafe_offset(i).unsafe_load())
                var hv = Float32(self.h.unsafe_offset(i).unsafe_load())
                self.x.unsafe_offset(i).unsafe_store(Float16(xv + hv))
            # FFN norm.
            rmsnorm_fp16(
                self.x, self.model.weights[self.wkey_ffn_norm[layer]], self.h, 2048, Float32(1e-5)
            )
            # Gate and Up.
            gemv_fp16(self.model.weights[self.wkey_ffn_gate[layer]], self.h, self.ffn_g, 5632, 2048)
            gemv_fp16(self.model.weights[self.wkey_ffn_up[layer]], self.h, self.ffn_u, 5632, 2048)
            # SiLU(gate) * up.
            for i in range(5632):
                var g = Float32(self.ffn_g.unsafe_offset(i).unsafe_load())
                var u = Float32(self.ffn_u.unsafe_offset(i).unsafe_load())
                var silu = g / (Float32(1.0) + exp(-g))
                self.ffn_g.unsafe_offset(i).unsafe_store(Float16(silu * u))
            # Down.
            gemv_fp16(
                self.model.weights[self.wkey_ffn_down[layer]], self.ffn_g, self.h, 2048, 5632
            )
            # Residual.
            for i in range(2048):
                var xv2 = Float32(self.x.unsafe_offset(i).unsafe_load())
                var hv2 = Float32(self.h.unsafe_offset(i).unsafe_load())
                self.x.unsafe_offset(i).unsafe_store(Float16(xv2 + hv2))
        # Final norm.
        rmsnorm_fp16(
            self.x, self.model.weights[self.wkey_out_norm], self.h, 2048, Float32(1e-5)
        )
        # LM head.
        gemv_fp16(self.model.weights[self.wkey_out], self.h, self.logits, 32000, 2048)
        self.seq_len += 1
        return self.logits

    def forward_nocache(
        mut self, tokens: List[Int]
    ) raises -> Pointer[Float16, MutUntrackedOrigin]:
        """H136 — cache-free reference forward (H051-style check on the real model).

        Recomputes K/V for the ENTIRE prefix from scratch into private
        scratch buffers: no reads from the persistent KV cache, no use of
        seq_len. Returns the logits for the LAST token (in self.logits).

        This is a deliberately independent code path from forward(): if
        the incremental KV-cache machinery (append indexing, seq_len/pos
        bookkeeping) is wrong, per-step logits from forward() diverge
        from this reference. Bit-identical results are expected when the
        cache is correct (same FP16 op order); the H136 gate allows
        max abs error <= 1e-3 across all 32000 logits.
        """
        if not self.model.loaded:
            raise Error("infer: forward_nocache on unloaded model")
        var n = len(tokens)
        if n == 0:
            raise Error("infer: forward_nocache needs >= 1 token")
        if n > self.max_seq:
            raise Error("infer: forward_nocache prefix exceeds max_seq")
        for t in range(n):
            var tok = tokens[t]
            if tok < 0 or tok >= self.model.vocab:
                raise Error("infer: forward_nocache token out of range")

        # Scratch K/V: [n_layers, n, n_kv_heads, head_dim], FP16.
        var kd = 22 * n * 4 * 64
        var sk = unsafe_alloc[Float16](kd)
        var sv = unsafe_alloc[Float16](kd)

        var theta = Float32(10000.0)
        for pos in range(n):
            var token = tokens[pos]
            var emb = self.model.weights["token_embd.weight"]
            var eoff = token * 2048
            for i in range(2048):
                self.x.unsafe_offset(i).unsafe_store(
                    emb.unsafe_offset(eoff + i).unsafe_load()
                )
            for layer in range(22):
                var p = String("blk.") + String(layer) + String(".")
                rmsnorm_fp16(
                    self.x, self.model.weights[p + "attn_norm.weight"],
                    self.h, 2048, Float32(1e-5),
                )
                gemv_fp16(self.model.weights[p + "attn_q.weight"], self.h, self.q, 2048, 2048)
                gemv_fp16(self.model.weights[p + "attn_k.weight"], self.h, self.k, 256, 2048)
                gemv_fp16(self.model.weights[p + "attn_v.weight"], self.h, self.v, 256, 2048)
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
                # Scratch KV append (never touches the persistent cache).
                for hk in range(4):
                    var base = ((layer * n + pos) * 4 + hk) * 64
                    for i in range(64):
                        sk.unsafe_offset(base + i).unsafe_store(
                            self.k.unsafe_offset(hk * 64 + i).unsafe_load()
                        )
                        sv.unsafe_offset(base + i).unsafe_store(
                            self.v.unsafe_offset(hk * 64 + i).unsafe_load()
                        )
                # GQA attention over scratch K/V.
                for hq in range(32):
                    var kh = hq // 8
                    var qh = self.q.unsafe_offset(hq * 64)
                    var scores = unsafe_alloc[Float32](pos + 1)
                    var m = Float32(-1e30)
                    for s in range(pos + 1):
                        var kbase = ((layer * n + s) * 4 + kh) * 64
                        var dot = Float32(0.0)
                        for d in range(64):
                            dot += Float32(qh.unsafe_offset(d).unsafe_load()) * Float32(
                                sk.unsafe_offset(kbase + d).unsafe_load()
                            )
                        var sc = dot / Float32(8.0)
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
                            var vbase = ((layer * n + s) * 4 + kh) * 64
                            acc += (
                                scores.unsafe_offset(s).unsafe_load()
                                * inv
                                * Float32(sv.unsafe_offset(vbase + d).unsafe_load())
                            )
                        oh.unsafe_offset(d).unsafe_store(Float16(acc))
                    scores.unsafe_free()
                gemv_fp16(
                    self.model.weights[p + "attn_output.weight"],
                    self.attn_out, self.h, 2048, 2048,
                )
                for i in range(2048):
                    var xv = Float32(self.x.unsafe_offset(i).unsafe_load())
                    var hv = Float32(self.h.unsafe_offset(i).unsafe_load())
                    self.x.unsafe_offset(i).unsafe_store(Float16(xv + hv))
                rmsnorm_fp16(
                    self.x, self.model.weights[p + "ffn_norm.weight"],
                    self.h, 2048, Float32(1e-5),
                )
                gemv_fp16(self.model.weights[p + "ffn_gate.weight"], self.h, self.ffn_g, 5632, 2048)
                gemv_fp16(self.model.weights[p + "ffn_up.weight"], self.h, self.ffn_u, 5632, 2048)
                for i in range(5632):
                    var g = Float32(self.ffn_g.unsafe_offset(i).unsafe_load())
                    var u = Float32(self.ffn_u.unsafe_offset(i).unsafe_load())
                    var silu = g / (Float32(1.0) + exp(-g))
                    self.ffn_g.unsafe_offset(i).unsafe_store(Float16(silu * u))
                gemv_fp16(
                    self.model.weights[p + "ffn_down.weight"],
                    self.ffn_g, self.h, 2048, 5632,
                )
                for i in range(2048):
                    var xv2 = Float32(self.x.unsafe_offset(i).unsafe_load())
                    var hv2 = Float32(self.h.unsafe_offset(i).unsafe_load())
                    self.x.unsafe_offset(i).unsafe_store(Float16(xv2 + hv2))
            rmsnorm_fp16(
                self.x, self.model.weights["output_norm.weight"],
                self.h, 2048, Float32(1e-5),
            )
            gemv_fp16(self.model.weights["output.weight"], self.h, self.logits, 32000, 2048)
        sk.unsafe_free()
        sv.unsafe_free()
        return self.logits


def _transpose_f16(
    src: Pointer[Float16, MutUntrackedOrigin],
    dst: Pointer[Float16, MutUntrackedOrigin],
    R: Int,
    C: Int,
):
    """dst[C,R] = src[R,C]^T (row-major both)."""
    for r in range(R):
        for c in range(C):
            dst.unsafe_offset(c * R + r).unsafe_store(
                src.unsafe_offset(r * C + c).unsafe_load()
            )


# H174 is implemented as Inference.forward_chunk (below), appended to the
# struct via this extension block. (Mojo structs are extended here by
# defining the method on Inference directly in the struct body — see the
# inserted method after prefill_chunked.)

def infer_version() -> String:
    return "0.2.0"
