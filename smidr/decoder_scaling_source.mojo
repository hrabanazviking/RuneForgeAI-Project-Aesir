# Selected source projection; complete originals remain with the caller.
from std.memory import bitcast
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture, _number
from smidr.decoder_layers import _bytes, _null, _text
from smidr.source_config import SourceConfigPolicy, parse_source_config
from smidr.source_scalars import ScalarWord
from smidr.scaling_policy import DecoderScalingPolicy, scaling_policy_charge, validate_scaling_policy


def source_decoder_scaling(architecture: SourceDecoderArchitecture,
                           provenance: String, work: Int) raises -> DecoderScalingPolicy:
    validate_decoder_architecture(architecture, architecture.policy)
    if work < 160 or work > architecture.policy.work or provenance.byte_length() == 0 or provenance.byte_length() > work - 160:
        raise Error("DecoderScaling: bounded projection work/provenance required")
    var kind = String("default")
    var origin = String("source:absent")
    var factor = ScalarWord(64, 4607182418800017408)
    if "rope_scaling" in architecture.layers.source.fields:
        var raw = architecture.layers.source.fields["rope_scaling"]
        if _null(raw):
            origin = "source:null"
        else:
            var size = raw.byte_length()
            if size <= 0 or size > architecture.policy.work // 4:
                raise Error("DecoderScaling: source object byte/work bound exceeded")
            var nested = parse_source_config(_bytes(raw), SourceConfigPolicy(size, architecture.policy.entries, architecture.policy.work, 64))
            if "type" in nested.fields:
                kind = _text(nested.fields["type"])
                origin = "source:legacy"
            elif "rope_type" in nested.fields:
                kind = _text(nested.fields["rope_type"])
                origin = "source:modern"
            else:
                raise Error("DecoderScaling: source selector interpretation remains implementation work")
            if kind == "linear":
                if "factor" not in nested.fields:
                    raise Error("DecoderScaling: source linear factor semantics required")
                factor = ScalarWord(64, bitcast[DType.uint64](_number(nested.fields["factor"])))
            elif kind != "default":
                raise Error("DecoderScaling: selected source variant lowering remains implementation work")
    _ = scaling_policy_charge(kind, origin, provenance, work, architecture.policy.work)
    var result = DecoderScalingPolicy(kind, factor^, origin, provenance, work)
    _ = validate_scaling_policy(result, architecture.policy.work)
    return result^
