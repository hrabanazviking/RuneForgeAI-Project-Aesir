# Explicit mathematical projection-bias selection, never device arithmetic.
@fieldwise_init
struct DecoderBiasPolicy(Copyable, Movable):
    var attention: List[Int]
    var mlp: List[Int]
    var provenance: String
    var work: Int


def empty_bias_policy() -> DecoderBiasPolicy:
    return DecoderBiasPolicy(List[Int](), List[Int](), "", 0)


def same_bias_policy(a: DecoderBiasPolicy, b: DecoderBiasPolicy) -> Bool:
    return a.attention == b.attention and a.mlp == b.mlp and a.provenance == b.provenance and a.work == b.work


def validate_bias_policy(policy: DecoderBiasPolicy, layers: Int,
                         source_tensors: Int, source_work: Int) raises -> Int:
    if layers <= 0 or source_tensors < 2 or layers > (source_tensors - 2) // 9 or len(policy.attention) != layers or len(policy.mlp) != layers:
        raise Error("DecoderBias: policy length exceeds source layer evidence")
    if policy.work <= 0 or policy.work > source_work or layers > policy.work // 2 or policy.provenance.byte_length() == 0:
        raise Error("DecoderBias: bounded positive policy/provenance required")
    var used = layers * 2
    if policy.provenance.byte_length() > policy.work - used:
        raise Error("DecoderBias: provenance work bound exceeded")
    used += policy.provenance.byte_length()
    for i in range(layers):
        var attention = policy.attention[i]
        var mlp = policy.mlp[i]
        if (attention != 0 and attention != 1) or (mlp != 0 and mlp != 1):
            raise Error("DecoderBias: flags must be zero or one")
        var amount = (attention * 4 + mlp * 3) * 128
        if amount > policy.work - used:
            raise Error("DecoderBias: operation work bound exceeded")
        used += amount
    return used
