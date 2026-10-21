# The caller retains the full original architecture and unresolved modifiers.
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture
from smidr.activation_policy import DecoderActivationPolicy, activation_policy_charge, validate_activation_policy


def source_decoder_activations(architecture: SourceDecoderArchitecture, provenance: String,
                               work: Int) raises -> DecoderActivationPolicy:
    validate_decoder_architecture(architecture, architecture.policy)
    var kind = architecture.activation
    if kind == "gelu":
        kind = "gelu_erf"
    elif kind != "silu" and kind != "relu":
        raise Error("DecoderActivation: source selector lowering remains implementation work")
    var layers = architecture.layers.layer_count
    if layers <= 0 or layers > work // 128:
        raise Error("DecoderActivation: source selector allocation bound exceeded")
    # Fixed qualified names are at most eight bytes; charge before creating a list.
    var size = kind.byte_length()
    if size > 0 and layers > 9223372036854775807 // size:
        raise Error("DecoderActivation: source selector charge overflow")
    _ = activation_policy_charge(layers, provenance, layers * size, work, architecture.policy.work)
    var kinds = List[String]()
    for _ in range(layers):
        kinds.append(kind)
    var result = DecoderActivationPolicy(kinds^, provenance, work)
    _ = validate_activation_policy(result, layers, architecture.policy.work)
    return result^
