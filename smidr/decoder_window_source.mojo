# Qualified source pattern projection; complete original owner stays with caller.
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture
from smidr.decoder_layers import _null, _positive
from smidr.window_policy import DecoderWindowPolicy, window_policy_charge


def source_decoder_windows(architecture: SourceDecoderArchitecture, provenance: String,
                           work: Int) raises -> DecoderWindowPolicy:
    validate_decoder_architecture(architecture, architecture.policy)
    var layers = architecture.layers.layer_count
    _ = window_policy_charge(layers, "source", provenance, work, architecture.policy.work)
    var width = 0
    if "sliding_window" in architecture.layers.window_fields:
        var raw = architecture.layers.window_fields["sliding_window"]
        if not _null(raw):
            width = _positive(raw)
    var declared = len(architecture.layers.layer_types) != 0
    var windows = List[Int]()
    for layer in range(layers):
        var selected = 0
        if declared:
            var kind = architecture.layers.layer_types[layer]
            if kind == "sliding_attention":
                if width == 0:
                    raise Error("DecoderWindow: source sliding type needs positive window semantics")
                selected = width
            elif kind != "full_attention":
                raise Error("DecoderWindow: source attention type lowering remains implementation work")
        elif architecture.layers.use_sliding_window and width != 0 and architecture.layers.rope_enabled[layer] == 0:
            selected = width
        windows.append(selected)
    return DecoderWindowPolicy(windows^, "source", provenance, work)
