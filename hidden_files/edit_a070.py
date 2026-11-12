#!/usr/bin/env python3
"""A-070 edits (complete version; supersedes the truncated
17:19 draft, whose pairs 1-5 are preserved verbatim below):
CpuAssistStats instrumentation + policy classifier + lm_head
zero-fill removal in vulkan_real_model.mojo; ping-pong layer
scratch in vulkan_decode.mojo; A070_STATS print in the bench
driver. Every anchor must occur exactly once or abort."""
import sys

def apply(path, pairs):
    src = open(path).read()
    for old, new in pairs:
        n = src.count(old)
        if n != 1:
            print(f"ANCHOR FAIL ({n}x) in {path}: {old[:70]!r}")
            sys.exit(1)
        src = src.replace(old, new)
    open(path, "w").write(src)
    print(f"OK {path}: {len(pairs)} edits")

RM = "/home/volmarr/aesir-team-03/aesir_engine/core/vulkan_real_model.mojo"
DC = "/home/volmarr/aesir-team-03/aesir_engine/core/vulkan_decode.mojo"
BN = "/home/volmarr/aesir-team-03/aesir_engine/tests/bench_cpu_assist_a070.mojo"

rm_pairs = [
    # 1. timing import
    (
        "from std.math import isinf, isnan\n",
        "from std.math import isinf, isnan\nfrom std.time import perf_counter_ns\n",
    ),
    # 2. header paragraph
    (
        "# Embedding lookup is a host gather + dequant of ONE row per\n",
        "# A-070 (lawful CPU assist): every host participation in\n"
        "# this path is instrumented in CpuAssistStats (streamed\n"
        "# weight upload, norm-gain upload, embedding gather, RoPE\n"
        "# permutation round trip, KV history readback + pack\n"
        "# upload, lm_head readback + stitch, logit sanitize),\n"
        "# accumulated per decode_step and exposed via\n"
        "# assist_stats(). Verdicts + measurements:\n"
        "# docs/bench/A070_CPU_ASSIST_INVENTORY.md. Removed in\n"
        "# A-070: the lm_head zero-fill pass (the row is built by\n"
        "# appending chunk outputs directly). Roaded there with\n"
        "# evidence: total weight residency (streaming is\n"
        "# load-bearing under the 128-slot shim cap), persistent\n"
        "# device KV for this path (A-066 owns the pattern), and\n"
        "# a GPU RoPE permutation.\n"
        "#\n"
        "# Embedding lookup is a host gather + dequant of ONE row per\n",
    ),
    # 3. CpuAssistStats + policy classifier before VulkanRealModel
    (
        "struct VulkanRealModel:\n",
        "struct CpuAssistStats(Copyable, ImplicitlyCopyable):\n"
        "    \"\"\"Per-assist CPU accounting for the GPU decode path\n"
        "    (A-070). Times are host wall nanoseconds spent in the\n"
        "    named assist inside decode_step/_layer; bytes are the\n"
        "    bytes that assist moves. step_ns is the decode_step\n"
        "    wall the assists are part of. Zero = nothing measured.\"\"\"\n"
        "\n"
        "    var steps: Int\n"
        "    var step_ns: Int\n"
        "    var stream_uploads: Int\n"
        "    var stream_bytes: Int\n"
        "    var stream_ns: Int\n"
        "    var gains_uploads: Int\n"
        "    var gains_bytes: Int\n"
        "    var gains_ns: Int\n"
        "    var embed_calls: Int\n"
        "    var embed_ns: Int\n"
        "    var permute_calls: Int\n"
        "    var permute_bytes: Int\n"
        "    var permute_ns: Int\n"
        "    var kv_readback_bytes: Int\n"
        "    var kvpack_calls: Int\n"
        "    var kvpack_bytes: Int\n"
        "    var kvpack_ns: Int\n"
        "    var logits_readback_bytes: Int\n"
        "    var logits_ns: Int\n"
        "    var sanitize_ns: Int\n"
        "\n"
        "    def __init__(out self):\n"
        "        self.steps = 0\n"
        "        self.step_ns = 0\n"
        "        self.stream_uploads = 0\n"
        "        self.stream_bytes = 0\n"
        "        self.stream_ns = 0\n"
        "        self.gains_uploads = 0\n"
        "        self.gains_bytes = 0\n"
        "        self.gains_ns = 0\n"
        "        self.embed_calls = 0\n"
        "        self.embed_ns = 0\n"
        "        self.permute_calls = 0\n"
        "        self.permute_bytes = 0\n"
        "        self.permute_ns = 0\n"
        "        self.kv_readback_bytes = 0\n"
        "        self.kvpack_calls = 0\n"
        "        self.kvpack_bytes = 0\n"
        "        self.kvpack_ns = 0\n"
        "        self.logits_readback_bytes = 0\n"
        "        self.logits_ns = 0\n"
        "        self.sanitize_ns = 0\n"
        "\n"
        "    def assist_ns(self) -> Int:\n"
        "        \"\"\"Sum of the named assist times (disjoint regions).\"\"\"\n"
        "        return (\n"
        "            self.stream_ns + self.gains_ns + self.embed_ns\n"
        "            + self.permute_ns + self.kvpack_ns + self.logits_ns\n"
        "            + self.sanitize_ns\n"
        "        )\n"
        "\n"
        "\n"
        "# A-070 assist inventory + lawful-assist policy (pure).\n"
        "# Canonical inventory order; every id has exactly one\n"
        "# name and every in-path assist above has a stats field.\n"
        "comptime ASSIST_STREAM_UPLOAD = 0\n"
        "comptime ASSIST_GAINS_UPLOAD = 1\n"
        "comptime ASSIST_EMBED_GATHER = 2\n"
        "comptime ASSIST_ROPE_PERMUTE = 3\n"
        "comptime ASSIST_KV_PACK = 4\n"
        "comptime ASSIST_LM_HEAD_STITCH = 5\n"
        "comptime ASSIST_SANITIZE = 6\n"
        "comptime ASSIST_HOST_ARGMAX = 7\n"
        "comptime ASSIST_GPU_GREEDY_CHECK = 8\n"
        "comptime ASSIST_DECODE_ALLOC_CHURN = 9\n"
        "comptime ASSIST_COUNT = 10\n"
        "\n"
        "comptime VERDICT_LAWFUL_SPILLOVER = 0\n"
        "comptime VERDICT_LAWFUL_MASSIVE = 1\n"
        "comptime VERDICT_LAWFUL_TRIVIAL = 2\n"
        "comptime VERDICT_UNMEASURED = 3\n"
        "comptime VERDICT_UNMEASURED_DOMINANT = 4\n"
        "comptime VERDICT_DOES_NOT_PAY = 5\n"
        "\n"
        "comptime MASSIVE_SPEEDUP_X10 = 10\n"
        "comptime DOMINANT_SHARE_PCT = 50\n"
        "\n"
        "\n"
        "def assist_name(assist_id: Int) -> String:\n"
        "    \"\"\"Canonical inventory name for an assist id.\"\"\"\n"
        "    if assist_id == ASSIST_STREAM_UPLOAD:\n"
        "        return String(\"stream_upload\")\n"
        "    if assist_id == ASSIST_GAINS_UPLOAD:\n"
        "        return String(\"gains_upload\")\n"
        "    if assist_id == ASSIST_EMBED_GATHER:\n"
        "        return String(\"embed_gather\")\n"
        "    if assist_id == ASSIST_ROPE_PERMUTE:\n"
        "        return String(\"rope_permute\")\n"
        "    if assist_id == ASSIST_KV_PACK:\n"
        "        return String(\"kv_pack\")\n"
        "    if assist_id == ASSIST_LM_HEAD_STITCH:\n"
        "        return String(\"lm_head_stitch\")\n"
        "    if assist_id == ASSIST_SANITIZE:\n"
        "        return String(\"sanitize\")\n"
        "    if assist_id == ASSIST_HOST_ARGMAX:\n"
        "        return String(\"host_argmax\")\n"
        "    if assist_id == ASSIST_GPU_GREEDY_CHECK:\n"
        "        return String(\"gpu_greedy_check\")\n"
        "    if assist_id == ASSIST_DECODE_ALLOC_CHURN:\n"
        "        return String(\"decode_alloc_churn\")\n"
        "    return String(\"unknown\")\n"
        "\n"
        "\n"
        "def assist_verdict(\n"
        "    measured: Bool,\n"
        "    spillover: Bool,\n"
        "    assist_ns: Int,\n"
        "    alternative_ns: Int,\n"
        "    step_ns: Int,\n"
        ") -> Int:\n"
        "    \"\"\"Accelerator-First verdict for one assist. CPU work\n"
        "    is lawful only as (1) spillover for what exceeds\n"
        "    device residency, or (2) a measured assist that\n"
        "    massively helps (>= 10x the GPU alternative) or is\n"
        "    a trivial share (< 1%) of the step it serves. An\n"
        "    unmeasured assist never survives; one that is also\n"
        "    a dominant share of the step is the worst class.\"\"\"\n"
        "    if not measured:\n"
        "        if step_ns > 0 and assist_ns * 100 >= step_ns * DOMINANT_SHARE_PCT:\n"
        "            return VERDICT_UNMEASURED_DOMINANT\n"
        "        return VERDICT_UNMEASURED\n"
        "    if spillover:\n"
        "        return VERDICT_LAWFUL_SPILLOVER\n"
        "    if alternative_ns >= assist_ns * MASSIVE_SPEEDUP_X10:\n"
        "        return VERDICT_LAWFUL_MASSIVE\n"
        "    if step_ns > 0 and assist_ns * 100 < step_ns:\n"
        "        return VERDICT_LAWFUL_TRIVIAL\n"
        "    return VERDICT_DOES_NOT_PAY\n"
        "\n"
        "\n"
        "def assist_is_lawful(\n"
        "    measured: Bool,\n"
        "    spillover: Bool,\n"
        "    assist_ns: Int,\n"
        "    alternative_ns: Int,\n"
        "    step_ns: Int,\n"
        ") -> Bool:\n"
        "    var v = assist_verdict(\n"
        "        measured, spillover, assist_ns, alternative_ns, step_ns\n"
        "    )\n"
        "    return (\n"
        "        v == VERDICT_LAWFUL_SPILLOVER\n"
        "        or v == VERDICT_LAWFUL_MASSIVE\n"
        "        or v == VERDICT_LAWFUL_TRIVIAL\n"
        "    )\n"
        "\n"
        "\n"
        "def stitch_chunk_append(chunks: List[List[Float32]]) -> List[Float32]:\n"
        "    \"\"\"lm_head stitch, A-070 form: the logit row is built\n"
        "    by appending chunk outputs directly (no zero-fill).\"\"\"\n"
        "    var out = List[Float32]()\n"
        "    for c in range(len(chunks)):\n"
        "        var chunk = chunks[c].copy()\n"
        "        for i in range(len(chunk)):\n"
        "            out.append(chunk[i])\n"
        "    return out^\n"
        "\n"
        "\n"
        "def stitch_chunk_scatter(\n"
        "    chunks: List[List[Float32]], total: Int\n"
        ") -> List[Float32]:\n"
        "    \"\"\"Pre-A-070 lm_head stitch, kept as the equivalence\n"
        "    oracle: zero-fill a total-length row, scatter chunks.\"\"\"\n"
        "    var out = List[Float32]()\n"
        "    for _ in range(total):\n"
        "        out.append(Float32(0.0))\n"
        "    var done = 0\n"
        "    for c in range(len(chunks)):\n"
        "        var chunk = chunks[c].copy()\n"
        "        for i in range(len(chunk)):\n"
        "            out[done + i] = chunk[i]\n"
        "        done += len(chunk)\n"
        "    return out^\n"
        "\n"
        "\n"
        "struct VulkanRealModel:\n",
    ),
    # 4. assist field
    (
        "    var last_nonfinite_count: Int\n    var _seer: GGUFSeer\n",
        "    var last_nonfinite_count: Int\n    var assist: CpuAssistStats\n    var _seer: GGUFSeer\n",
    ),
    # 5. assist init
    (
        "        self.last_nonfinite_count = 0\n        self._seer = GGUFSeer(path)\n",
        "        self.last_nonfinite_count = 0\n        self.assist = CpuAssistStats()\n        self._seer = GGUFSeer(path)\n",
    ),
    # 6. _upload -> mut + stream timing
    (
        "    def _upload(\n        self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]\n    ) raises:\n",
        "    def _upload(\n        mut self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]\n    ) raises:\n",
    ),
    (
        "        var dst = VulkanBuffers.map(alloc)\n        _copy_bytes(dst, t.data.unsafe_bitcast[UInt8](), n)\n        VulkanBuffers.unmap(alloc)\n",
        "        var t0 = perf_counter_ns()\n        var dst = VulkanBuffers.map(alloc)\n        _copy_bytes(dst, t.data.unsafe_bitcast[UInt8](), n)\n        VulkanBuffers.unmap(alloc)\n        self.assist.stream_uploads += 1\n        self.assist.stream_bytes += n\n        self.assist.stream_ns += perf_counter_ns() - t0\n",
    ),
    # 7. _upload_gains -> mut + timing
    (
        "    def _upload_gains(\n        self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]\n    ) raises:\n",
        "    def _upload_gains(\n        mut self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]\n    ) raises:\n",
    ),
    (
        "        var dst = VulkanBuffers.map(alloc).unsafe_bitcast[Float32]()\n        for i in range(self.dim):\n",
        "        var t0 = perf_counter_ns()\n        var dst = VulkanBuffers.map(alloc).unsafe_bitcast[Float32]()\n        for i in range(self.dim):\n",
    ),
    (
        "            dst.unsafe_store(\n                i, t.data.unsafe_load(i).cast[DType.float32]()\n            )\n        VulkanBuffers.unmap(alloc)\n",
        "            dst.unsafe_store(\n                i, t.data.unsafe_load(i).cast[DType.float32]()\n            )\n        VulkanBuffers.unmap(alloc)\n        self.assist.gains_uploads += 1\n        self.assist.gains_bytes += self.dim * 4\n        self.assist.gains_ns += perf_counter_ns() - t0\n",
    ),
    # 8. _embed -> mut + timing
    (
        "    def _embed(self, token: Int) raises -> List[Float32]:\n",
        "    def _embed(mut self, token: Int) raises -> List[Float32]:\n        var t0 = perf_counter_ns()\n",
    ),
    (
        "        return out^\n\n    def _write_f32(\n",
        "        self.assist.embed_calls += 1\n        self.assist.embed_ns += perf_counter_ns() - t0\n        return out^\n\n    def _write_f32(\n",
    ),
    # 9. permute round trip timing in _layer
    (
        "        var q_host = permute_rope_pairs(self._read_f32(self._q, self.dim), self.head_dim)\n",
        "        var tp0 = perf_counter_ns()\n        var q_host = permute_rope_pairs(self._read_f32(self._q, self.dim), self.head_dim)\n",
    ),
    (
        "        var k_host = permute_rope_pairs(self._read_f32(self._k, self.kv_dim), self.head_dim)\n        self._write_f32(self._k, k_host)\n",
        "        var k_host = permute_rope_pairs(self._read_f32(self._k, self.kv_dim), self.head_dim)\n        self._write_f32(self._k, k_host)\n        self.assist.permute_calls += 2\n        self.assist.permute_bytes += (self.dim + self.kv_dim) * 8\n        self.assist.permute_ns += perf_counter_ns() - tp0\n",
    ),
    # 10. KV readback + pack timing in _layer
    (
        "        var k_roped = self._read_f32(self._k, self.kv_dim)\n",
        "        var tk0 = perf_counter_ns()\n        var k_roped = self._read_f32(self._k, self.kv_dim)\n",
    ),
    (
        "        self._write_f32(self._kpack, kpack)\n        self._write_f32(self._vpack, vpack)\n",
        "        self._write_f32(self._kpack, kpack)\n        self._write_f32(self._vpack, vpack)\n        self.assist.kv_readback_bytes += self.kv_dim * 8\n        self.assist.kvpack_calls += 1\n        self.assist.kvpack_bytes += (len(kpack) + len(vpack)) * 4\n        self.assist.kvpack_ns += perf_counter_ns() - tk0\n",
    ),
    # 11. decode_step: step timer start
    (
        "        var x = self._embed(token)\n        var xa = self._x_a\n",
        "        var t_step0 = perf_counter_ns()\n        var x = self._embed(token)\n        var xa = self._x_a\n",
    ),
    # 12. lm_head: zero-fill removal + stitch via append + timing,
    #     sanitize timing, step accounting
    (
        "        var logits = List[Float32]()\n        for i in range(self.vocab):\n            logits.append(Float32(0.0))\n        var done = 0\n        for c in range(len(self._lm_chunks)):\n            var rows = self._lm_chunk_rows[c]\n            self._gemv(self._lm_fmt, self._lm_chunks[c], self._h, self._chunk_y, rows, self.dim)\n            var part = self._read_f32(self._chunk_y, rows)\n            for i in range(rows):\n                logits[done + i] = part[i]\n            done += rows\n        self.last_nonfinite_count = sanitize_logit_row(logits)\n        return logits^\n",
        "        var tl0 = perf_counter_ns()\n        var chunks = List[List[Float32]]()\n        for c in range(len(self._lm_chunks)):\n            var rows = self._lm_chunk_rows[c]\n            self._gemv(self._lm_fmt, self._lm_chunks[c], self._h, self._chunk_y, rows, self.dim)\n            chunks.append(self._read_f32(self._chunk_y, rows))\n        var logits = stitch_chunk_append(chunks)\n        self.assist.logits_readback_bytes += self.vocab * 4\n        self.assist.logits_ns += perf_counter_ns() - tl0\n        if len(logits) != self.vocab:\n            raise Error(\"VulkanRealModel: lm_head stitch length drift\")\n        var ts0 = perf_counter_ns()\n        self.last_nonfinite_count = sanitize_logit_row(logits)\n        self.assist.sanitize_ns += perf_counter_ns() - ts0\n        self.assist.steps += 1\n        self.assist.step_ns += perf_counter_ns() - t_step0\n        return logits^\n",
    ),
    # 13. assist_stats accessor before gpu_greedy_token
    (
        "    def gpu_greedy_token(mut self, logits: List[Float32]) raises -> Int:\n",
        "    def assist_stats(self) -> CpuAssistStats:\n        \"\"\"Snapshot of the A-070 per-assist accounting.\"\"\"\n        return self.assist.copy()\n\n    def gpu_greedy_token(mut self, logits: List[Float32]) raises -> Int:\n",
    ),
]

dc_pairs = [
    # D1. header note
    (
        "# template exists anywhere in this path).\n",
        "# template exists anywhere in this path).\n#\n# A-070 (lawful CPU assist): the one host participation in\n# this loop was allocator churn - one scratch allocation +\n# free per layer per step (measured 15 us per alloc/free\n# pair, bench_cpu_assist_a070; 12 layers x 32 steps = 384\n# pairs per generate on the A-066 fixture). The layer\n# scratch is now ping-pong: two buffers allocated once and\n# alternated (every gateway dispatch is synchronous, so a\n# buffer is free for reuse two layers later). Per-step\n# alloc/free in the loop: zero. Inventory + verdicts:\n# docs/bench/A070_CPU_ASSIST_INVENTORY.md.\n",
    ),
    # D2. ping-pong scratch allocation
    (
        "        var tok_out = VulkanBuffers.allocate(4)\n",
        "        var tok_out = VulkanBuffers.allocate(4)\n        var scratch_a = VulkanBuffers.allocate(dim * 4)\n        var scratch_b = VulkanBuffers.allocate(dim * 4)\n",
    ),
    # D3. loop body: owned-list churn -> ping-pong
    (
        "            var cur = x\n            var owned = List[VulkanAllocation]()\n            for li in range(len(weights.layers)):\n                var nxt = VulkanBuffers.allocate(dim * 4)\n",
        "            var cur = x\n            var use_a = True\n            for li in range(len(weights.layers)):\n                var nxt = scratch_a if use_a else scratch_b\n",
    ),
    (
        "                owned.append(nxt)\n                cur = nxt\n",
        "                use_a = not use_a\n                cur = nxt\n",
    ),
    (
        "            for i in range(len(owned)):\n                VulkanBuffers.free(owned[i])\n",
        "            # A-070: ping-pong scratch - nothing freed per step.\n",
    ),
    # D4. free scratch at the end
    (
        "        VulkanBuffers.free(x)\n        VulkanBuffers.free(normed)\n",
        "        VulkanBuffers.free(x)\n        VulkanBuffers.free(scratch_a)\n        VulkanBuffers.free(scratch_b)\n        VulkanBuffers.free(normed)\n",
    ),
]

bn_pairs = [
    # B1. A070_STATS print before close
    (
        "    model.close()\n    print(\"A070_DONE\")\n",
        "    var st = model.assist_stats()\n    print(\"A070_STATS steps=\", st.steps, \"step_ms_avg=\", st.step_ns // st.steps // 1_000_000)\n    print(\"A070_STATS stream_uploads=\", st.stream_uploads, \"stream_mb=\", st.stream_bytes // 1_000_000, \"stream_ms_per_step=\", st.stream_ns // st.steps // 1_000_000)\n    print(\"A070_STATS gains_uploads=\", st.gains_uploads, \"gains_us_per_step=\", st.gains_ns // st.steps // 1000)\n    print(\"A070_STATS embed_calls=\", st.embed_calls, \"embed_us_per_step=\", st.embed_ns // st.steps // 1000)\n    print(\"A070_STATS permute_calls=\", st.permute_calls, \"permute_us_per_step=\", st.permute_ns // st.steps // 1000)\n    print(\"A070_STATS kvpack_calls=\", st.kvpack_calls, \"kvpack_us_per_step=\", st.kvpack_ns // st.steps // 1000, \"kvpack_kb_per_step=\", st.kvpack_bytes // st.steps // 1000)\n    print(\"A070_STATS logits_kb_per_step=\", st.logits_readback_bytes // st.steps // 1000, \"logits_us_per_step=\", st.logits_ns // st.steps // 1000)\n    print(\"A070_STATS sanitize_us_per_step=\", st.sanitize_ns // st.steps // 1000)\n    print(\"A070_STATS assist_ms_per_step=\", st.assist_ns() // st.steps // 1_000_000, \"assist_pct_x10=\", st.assist_ns() * 1000 // st.step_ns)\n    model.close()\n    print(\"A070_DONE\")\n",
    ),
]

apply(RM, rm_pairs)
apply(DC, dc_pairs)
apply(BN, bn_pairs)
print("ALL EDITS APPLIED")
