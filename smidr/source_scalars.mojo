# Source mathematical constants. Width describes representation, not device math.
from std.math import isfinite
from std.memory import bitcast


@fieldwise_init
struct ScalarWord(Copyable, Movable):
    var width: Int
    var bits: UInt64


@fieldwise_init
struct DecoderScalars(Copyable, Movable):
    var epsilon: ScalarWord
    var rope_base: ScalarWord
    var provenance: String
    var work_limit: Int


def empty_decoder_scalars() -> DecoderScalars:
    return DecoderScalars(ScalarWord(0, 0), ScalarWord(0, 0), "", 0)


def same_scalar_word(a: ScalarWord, b: ScalarWord) -> Bool:
    return a.width == b.width and a.bits == b.bits


def validate_scalar_word(value: ScalarWord) raises:
    if value.width == 32:
        if value.bits > 4294967295:
            raise Error("SourceScalar: binary32 word has nonzero upper bits")
        var decoded = bitcast[DType.float32](UInt32(value.bits))
        if not isfinite(decoded) or decoded <= 0:
            raise Error("SourceScalar: finite positive binary32 value required")
    elif value.width == 64:
        var decoded = bitcast[DType.float64](value.bits)
        if not isfinite(decoded) or decoded <= 0:
            raise Error("SourceScalar: finite positive binary64 value required")
    else:
        raise Error("SourceScalar: source scalar encoding work required")


def validate_decoder_scalars(values: DecoderScalars) raises -> Int:
    if values.work_limit <= 2 or values.provenance.byte_length() == 0 or values.provenance.byte_length() > values.work_limit - 2:
        raise Error("SourceScalar: bounded nonempty scalar provenance required")
    validate_scalar_word(values.epsilon)
    validate_scalar_word(values.rope_base)
    return 2 + values.provenance.byte_length()


def same_decoder_scalars(a: DecoderScalars, b: DecoderScalars) -> Bool:
    return same_scalar_word(a.epsilon, b.epsilon) and same_scalar_word(a.rope_base, b.rope_base) and a.provenance == b.provenance and a.work_limit == b.work_limit


def scalar32_mirror(value: ScalarWord) -> UInt32:
    return UInt32(value.bits) if value.width == 32 else UInt32(0)
