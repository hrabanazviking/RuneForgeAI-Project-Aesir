# armvegr/kv_cache.mojo
# H050/H051/H052 — KV cache in pure Mojo (Domain D1 ARMVEGR).
#
# FP16 key/value cache for transformer decoding. Layout (flat FP16 buffer):
#   offset(layer, is_v, pos) = ((layer*2 + is_v) * max_seq_len + pos)
#                            * n_kv_heads * head_dim   (in FP16 elements)
# Exact byte count: n_layers * 2 * max_seq_len * n_kv_heads * head_dim * 2.
# All out-of-bounds access fails closed. H052 adds sliding-window eviction
# with attention sinks.

struct KVCache:
    var n_layers: Int
    var n_kv_heads: Int
    var head_dim: Int
    var max_seq_len: Int
    var seq_len: Int
    var data: List[Float16]
    var sink_tokens: Int  # H052: number of attention sinks to preserve (0 = disabled)

    def __init__(out self, n_layers: Int, n_kv_heads: Int, head_dim: Int, max_seq_len: Int):
        self.n_layers = n_layers
        self.n_kv_heads = n_kv_heads
        self.head_dim = head_dim
        self.max_seq_len = max_seq_len
        self.seq_len = 0
        self.sink_tokens = 0
        var total = n_layers * 2 * max_seq_len * n_kv_heads * head_dim
        self.data = List[Float16](length=total, fill=Float16(0.0))

    def byte_count(self) -> Int:
        """Exact byte-count formula for the cache allocation."""
        return self.n_layers * 2 * self.max_seq_len * self.n_kv_heads * self.head_dim * 2

    def allocated_bytes(self) -> Int:
        return len(self.data) * 2

    def _check(self, layer: Int, pos: Int) raises:
        if layer < 0 or layer >= self.n_layers:
            raise Error("kvcache: layer out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("kvcache: position out of bounds")
        if pos >= self.seq_len:
            raise Error("kvcache: reading unwritten position")

    def _offset(self, layer: Int, is_v: Int, pos: Int) -> Int:
        return ((layer * 2 + is_v) * self.max_seq_len + pos) * self.n_kv_heads * self.head_dim

    def write_kv(
        mut self, layer: Int, pos: Int, k: List[Float16], v: List[Float16]
    ) raises:
        """Write K and V for one position. k/v are [n_kv_heads * head_dim]."""
        if layer < 0 or layer >= self.n_layers:
            raise Error("kvcache: layer out of bounds")
        if pos < 0 or pos >= self.max_seq_len:
            raise Error("kvcache: position out of bounds")
        var want = self.n_kv_heads * self.head_dim
        if len(k) != want or len(v) != want:
            raise Error("kvcache: k/v wrong size")
        var ok = self._offset(layer, 0, pos)
        var ov = self._offset(layer, 1, pos)
        for i in range(want):
            self.data[ok + i] = k[i]
            self.data[ov + i] = v[i]

    def read_k(self, layer: Int, pos: Int) raises -> List[Float16]:
        self._check(layer, pos)
        var want = self.n_kv_heads * self.head_dim
        var o = self._offset(layer, 0, pos)
        var out = List[Float16]()
        for i in range(want):
            out.append(self.data[o + i])
        return out.copy()

    def read_v(self, layer: Int, pos: Int) raises -> List[Float16]:
        self._check(layer, pos)
        var want = self.n_kv_heads * self.head_dim
        var o = self._offset(layer, 1, pos)
        var out = List[Float16]()
        for i in range(want):
            out.append(self.data[o + i])
        return out.copy()

    def prepare_position(mut self) raises -> Int:
        """Return the physical slot for the next logical position.
        If full and sliding window is enabled (H052), evicts the oldest
        non-sink slot first. Call commit_position() after writing all layers.
        """
        if self.seq_len < self.max_seq_len:
            return self.seq_len
        if self.sink_tokens <= 0:
            raise Error("kvcache: full (no eviction)")
        var s = self.sink_tokens
        var want = self.n_kv_heads * self.head_dim
        for layer in range(self.n_layers):
            for pos in range(s, self.max_seq_len - 1):
                var dst_k = self._offset(layer, 0, pos)
                var src_k = self._offset(layer, 0, pos + 1)
                var dst_v = self._offset(layer, 1, pos)
                var src_v = self._offset(layer, 1, pos + 1)
                for i in range(want):
                    self.data[dst_k + i] = self.data[src_k + i]
                    self.data[dst_v + i] = self.data[src_v + i]
        return self.max_seq_len - 1

    def commit_position(mut self):
        if self.seq_len < self.max_seq_len:
            self.seq_len += 1

    def append_kv(mut self, layer: Int, k: List[Float16], v: List[Float16]) raises -> Int:
        """Legacy single-layer append: prepare + write + commit."""
        var pos = self.prepare_position()
        self.write_kv(layer, pos, k, v)
        self.commit_position()
        return pos

    def enable_sliding_window(mut self, sink_tokens: Int) raises:
        if sink_tokens < 0 or sink_tokens >= self.max_seq_len:
            raise Error("kvcache: bad sink count")
        self.sink_tokens = sink_tokens


def kvcache_version() -> String:
    return "0.1.0"
