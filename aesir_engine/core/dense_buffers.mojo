"""Checked compact dense-GQA scratch ownership, with shared scores/logits."""
from core.dense_gqa_profile import DenseGQAProfile


def buffer_add(a: Int, b: Int) raises -> Int:
    if a < 0 or b < 0 or a > 9223372036854775807 - b:
        raise Error("Dense buffer offset overflow")
    return a + b


def buffer_mul(a: Int, b: Int) raises -> Int:
    if a <= 0 or b <= 0 or a > 9223372036854775807 // b:
        raise Error("Dense buffer span overflow")
    return a * b


def effective_prefill_batch(profile: DenseGQAProfile, requested: Int = 0) raises -> Int:
    if requested != 0 and requested != 1 and requested != 4:
        raise Error("Native prefill batch must be auto, one or four")
    var exercised = profile.architecture == "llama" and profile.hidden_size == 3072 and profile.layer_count == 28
    if requested == 4 and not exercised:
        raise Error("Four-token prefill is admitted only for the exercised 3B profile")
    return (4 if exercised else 1) if requested == 0 else requested


struct DenseBufferLayout(Copyable, ImplicitlyCopyable):
    var norm: Int
    var query: Int
    var key: Int
    var value: Int
    var attention: Int
    var temporary: Int
    var up: Int
    var gate: Int
    var stride: Int
    var logits: Int
    var scores: Int
    var elements: Int
    var batch: Int

    def __init__(out self, profile: DenseGQAProfile, context: Int, requested: Int = 0) raises:
        if context < 2 or context > profile.context_cap:
            raise Error("Dense buffer context exceeds admitted bounds")
        self.batch = effective_prefill_batch(profile, requested)
        var q = buffer_mul(profile.attention_heads, profile.head_dim)
        var kv = buffer_mul(profile.kv_heads, profile.head_dim)
        self.norm = buffer_mul(profile.hidden_size, 1)
        self.query = buffer_add(self.norm, profile.hidden_size)
        self.key = buffer_add(self.query, q)
        self.value = buffer_add(self.key, kv)
        self.attention = buffer_add(self.value, kv)
        self.temporary = buffer_add(self.attention, q)
        self.up = buffer_add(self.temporary, profile.hidden_size)
        self.gate = buffer_add(self.up, buffer_mul(profile.feed_forward_size, 1))
        self.stride = buffer_add(self.gate, profile.feed_forward_size)
        self.logits = buffer_mul(self.stride, self.batch)
        self.scores = buffer_add(self.logits, buffer_mul(profile.vocabulary_size, 1))
        self.elements = buffer_add(self.scores, buffer_mul(profile.attention_heads, context))
        if self.elements > 9223372036854775807 // 4:
            raise Error("Dense scratch byte span overflow")

    def token_base(self, token: Int) raises -> Int:
        if token < 0 or token >= self.batch:
            raise Error("Dense scratch token is outside allocated tile")
        return token * self.stride
