"""Pure admission for the isolated guarded matrix fixture; no runtime promotion."""
from core.dense_buffers import DenseBufferLayout, buffer_add, buffer_mul
from core.dense_gqa_profile import DenseGQAProfile
from core.sampling_config import sampling_device_bytes


def same_fixture_layout(a: DenseBufferLayout,b: DenseBufferLayout) -> Bool:
    return (a.norm == b.norm and a.query == b.query and a.key == b.key and
        a.value == b.value and a.attention == b.attention and a.temporary == b.temporary and
        a.up == b.up and a.gate == b.gate and a.stride == b.stride and
        a.logits == b.logits and a.scores == b.scores and a.elements == b.elements and a.batch == b.batch)


def admit_fixture_profile(profile: DenseGQAProfile) raises:
    if (profile.architecture != "llama" or profile.layer_count != 28 or
        profile.hidden_size != 3072 or profile.feed_forward_size != 8192 or
        profile.attention_heads != 24 or profile.kv_heads != 8 or
        profile.head_dim != 128 or profile.vocabulary_size != 128256 or profile.context_cap < 1536):
        raise Error("Matrix fixture requires the exercised strict3B geometry and context")


struct TuringFixturePlan(Copyable):
    var layout: DenseBufferLayout
    var activation_elements: Int
    var cache_elements: Int
    var device_bytes: Int
    var required_free_bytes: Int

    def __init__(out self,profile: DenseGQAProfile,reference: DenseBufferLayout,
        major: Int,minor: Int,free_bytes: Int,precision: Int = 0) raises:
        if precision < 0 or precision > 4:
            raise Error("Fixture activation precision must be0/1/2/3/4")
        if major != 7 or minor != 5:
            raise Error("Optional Turing fixture requires observed CUDA capability7.5")
        admit_fixture_profile(profile)
        var canonical = DenseBufferLayout(profile,1536,4)
        if not same_fixture_layout(reference,canonical):
            raise Error("Matrix fixture reference layout drifted from its checked plan")
        self.layout = canonical
        self.layout.batch = 32
        self.layout.stride = buffer_add(canonical.stride,32)
        self.layout.logits = buffer_mul(self.layout.stride,32)
        self.layout.scores = buffer_add(self.layout.logits,128256)
        self.layout.elements = buffer_add(self.layout.scores,buffer_mul(24,1536))
        self.activation_elements = buffer_add(self.layout.elements,32)
        self.cache_elements = buffer_add(buffer_mul(buffer_mul(28,2),buffer_mul(1536,1024)),32)
        self.device_bytes = buffer_add(buffer_mul(self.activation_elements,4),buffer_mul(self.cache_elements,2))
        self.device_bytes = buffer_add(self.device_bytes,buffer_add(sampling_device_bytes(128256),8))
        self.required_free_bytes = buffer_add(self.device_bytes,268435456)
        if free_bytes < self.required_free_bytes:
            raise Error("Matrix fixture exceeds observed device headroom")

    def admit_buffers(self,layout: DenseBufferLayout,actual_a: Int,actual_kv: Int) raises:
        if not same_fixture_layout(layout,self.layout):
            raise Error("Matrix fixture layout changed after allocation")
        if actual_a != self.activation_elements or actual_kv != self.cache_elements:
            raise Error("Matrix fixture actual buffer span disagrees with plan")
