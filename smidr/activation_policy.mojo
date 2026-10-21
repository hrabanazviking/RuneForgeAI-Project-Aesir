# Owned finite-real mathematical selectors, never device eligibility rules.
@fieldwise_init
struct DecoderActivationPolicy(Copyable, Movable):
    var kinds: List[String]
    var provenance: String
    var work: Int


def empty_activation_policy() -> DecoderActivationPolicy:
    return DecoderActivationPolicy(List[String](), "", 0)


def same_activation_policy(a: DecoderActivationPolicy, b: DecoderActivationPolicy) -> Bool:
    return a.kinds == b.kinds and a.provenance == b.provenance and a.work == b.work


def activation_kind_supported(kind: String) -> Bool:
    return kind == "silu" or kind == "gelu_erf" or kind == "relu"


def activation_policy_charge(layers: Int, provenance: String, kind_bytes: Int, work: Int,
                             source_work: Int) raises -> Int:
    if layers <= 0 or work <= 0 or work > source_work or layers > work // 128 or provenance.byte_length() == 0 or kind_bytes < 0:
        raise Error("DecoderActivation: bounded positive policy/provenance required")
    var used = layers * 128
    if provenance.byte_length() > work - used:
        raise Error("DecoderActivation: provenance work bound exceeded")
    used += provenance.byte_length()
    if kind_bytes > work - used:
        raise Error("DecoderActivation: selector work bound exceeded")
    return used + kind_bytes


def validate_activation_policy(policy: DecoderActivationPolicy, layers: Int,
                               source_work: Int) raises -> Int:
    if len(policy.kinds) != layers:
        raise Error("DecoderActivation: one mathematical selector per layer required")
    var used = activation_policy_charge(layers, policy.provenance, 0, policy.work, source_work)
    for i in range(layers):
        if not activation_kind_supported(policy.kinds[i]):
            raise Error("DecoderActivation: selector lowering remains implementation work")
        if policy.kinds[i].byte_length() > policy.work - used:
            raise Error("DecoderActivation: selector work bound exceeded")
        used += policy.kinds[i].byte_length()
    return used
