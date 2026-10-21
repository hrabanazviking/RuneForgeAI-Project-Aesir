# Original selected real-frequency semantics; source words are not device formats.
from smidr.source_scalars import ScalarWord, same_scalar_word, validate_scalar_word


@fieldwise_init
struct DecoderScalingPolicy(Copyable, Movable):
    var kind: String
    var factor: ScalarWord
    var origin: String
    var provenance: String
    var work: Int


def empty_scaling_policy() -> DecoderScalingPolicy:
    return DecoderScalingPolicy("", ScalarWord(0, 0), "", "", 0)


def same_scaling_policy(a: DecoderScalingPolicy, b: DecoderScalingPolicy) -> Bool:
    return a.kind == b.kind and same_scalar_word(a.factor, b.factor) and a.origin == b.origin and a.provenance == b.provenance and a.work == b.work


def scaling_policy_charge(kind: String, origin: String, provenance: String,
                          work: Int, source_work: Int) raises -> Int:
    if work < 160 or work > source_work or (kind != "default" and kind != "linear") or provenance.byte_length() == 0:
        raise Error("DecoderScaling: bounded kind/work/provenance required")
    if origin != "invocation" and origin != "source:absent" and origin != "source:null" and origin != "source:modern" and origin != "source:legacy":
        raise Error("DecoderScaling: explicit qualified origin required")
    var used = 160
    for size in List[Int]([kind.byte_length(), origin.byte_length(), provenance.byte_length()]):
        if size > work - used:
            raise Error("DecoderScaling: descriptor work bound exceeded")
        used += size
    return used


def validate_scaling_policy(p: DecoderScalingPolicy, source_work: Int) raises -> Int:
    var charge = scaling_policy_charge(p.kind, p.origin, p.provenance, p.work, source_work)
    validate_scalar_word(p.factor)
    var unity = p.factor.bits == UInt64(1065353216) if p.factor.width == 32 else p.factor.bits == UInt64(4607182418800017408)
    if p.kind == "default" and not unity:
        raise Error("DecoderScaling: default factor must be exact unity")
    if (p.origin == "source:absent" or p.origin == "source:null") and (p.kind != "default" or p.factor.width != 64 or not unity):
        raise Error("DecoderScaling: source default representation changed")
    if (p.origin == "source:modern" or p.origin == "source:legacy") and p.factor.width != 64:
        raise Error("DecoderScaling: qualified source factor must retain binary64")
    return charge
