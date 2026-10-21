# Selected scalar projection; the caller retains the complete architecture owner.
from std.memory import bitcast
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture
from smidr.source_scalars import ScalarWord, DecoderScalars, validate_decoder_scalars


def source_decoder_scalars(intent: SourceDecoderArchitecture, provenance: String,
                           work_limit: Int) raises -> DecoderScalars:
    if work_limit <= 2 or provenance.byte_length() == 0 or provenance.byte_length() > work_limit - 2:
        raise Error("SourceScalar: scalar projection work bound exceeded")
    validate_decoder_architecture(intent, intent.policy)
    var values = DecoderScalars(ScalarWord(64, bitcast[DType.uint64](intent.scalars["rms_norm_eps"])),
        ScalarWord(64, bitcast[DType.uint64](intent.scalars["rope_theta"])), provenance, work_limit)
    _ = validate_decoder_scalars(values)
    return values^
