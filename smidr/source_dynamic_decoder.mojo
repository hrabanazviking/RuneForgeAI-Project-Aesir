# Qualified source intent; complete original architecture stays with its caller.
from std.memory import bitcast
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture, _number
from smidr.decoder_layers import _bytes, _null, _text
from smidr.source_config import SourceConfigPolicy, parse_source_config
from smidr.source_scalars import ScalarWord
from smidr.dynamic_decoder_policy import DynamicDecoderPolicy, dynamic_decoder_policy_charge, validate_dynamic_decoder_policy, same_dynamic_decoder_policy


def source_dynamic_decoder_policy(architecture: SourceDecoderArchitecture, limit: Int,
                                  provenance: String, work: Int) raises -> DynamicDecoderPolicy:
    validate_decoder_architecture(architecture, architecture.policy)
    if work < 256 or work > architecture.policy.work or provenance.byte_length() == 0 or provenance.byte_length() > work - 256:
        raise Error("DynamicDecoder: bounded source projection work/provenance required")
    if "rope_scaling" not in architecture.layers.source.fields or _null(architecture.layers.source.fields["rope_scaling"]):
        raise Error("DynamicDecoder: explicit source dynamic object required; other projections remain separate")
    var raw = architecture.layers.source.fields["rope_scaling"]
    var size = raw.byte_length()
    if size <= 0 or size > architecture.policy.work // 4:
        raise Error("DynamicDecoder: nested source byte/work bound exceeded")
    var nested = parse_source_config(_bytes(raw), SourceConfigPolicy(size, architecture.policy.entries, architecture.policy.work, 64))
    var kind = String("")
    var origin = String("")
    if "type" in nested.fields:
        kind = _text(nested.fields["type"])
        origin = "source:legacy"
    elif "rope_type" in nested.fields:
        kind = _text(nested.fields["rope_type"])
        origin = "source:modern"
    if kind != "dynamic" or "factor" not in nested.fields:
        raise Error("DynamicDecoder: explicit dynamic selector/factor semantics required; other variants remain work")
    var ref_origin = architecture.field_origins["max_position_embeddings"]
    _ = dynamic_decoder_policy_charge(origin, ref_origin, provenance, work, architecture.policy.work)
    var result = DynamicDecoderPolicy(ScalarWord(64, bitcast[DType.uint64](_number(nested.fields["factor"]))),
        ScalarWord(64, bitcast[DType.uint64](architecture.scalars["rope_theta"])),
        architecture.dimensions["max_position_embeddings"], limit, origin, ref_origin, provenance, work)
    _ = validate_dynamic_decoder_policy(result, architecture.policy.work)
    return result^


def validate_source_dynamic_decoder_policy(architecture: SourceDecoderArchitecture,
                                         policy: DynamicDecoderPolicy) raises:
    var expected = source_dynamic_decoder_policy(architecture, policy.limit, policy.provenance, policy.work)
    if not same_dynamic_decoder_policy(policy, expected):
        raise Error("DynamicDecoder: selected policy differs from complete source projection")
