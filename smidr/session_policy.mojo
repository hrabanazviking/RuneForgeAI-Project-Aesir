# Original mathematical input/return contract, not device cache allocation.
@fieldwise_init
struct DecoderSessionPolicy(Copyable, Movable):
    var mode: String
    var return_cache: Int
    var source_return_cache: Int
    var return_origin: String
    var provenance: String
    var work: Int


def empty_session_policy() -> DecoderSessionPolicy:
    return DecoderSessionPolicy("", 0, 0, "", "", 0)


def same_session_policy(a: DecoderSessionPolicy, b: DecoderSessionPolicy) -> Bool:
    return a.mode == b.mode and a.return_cache == b.return_cache and a.source_return_cache == b.source_return_cache and a.return_origin == b.return_origin and a.provenance == b.provenance and a.work == b.work


def session_policy_charge(mode: String, returned: Int, source_returned: Int,
                          origin: String, provenance: String, layers: Int,
                          work: Int, source_work: Int) raises -> Int:
    if mode != "cached_append" and mode != "full_prefix":
        raise Error("DecoderSession: explicit input mode required")
    if (returned != 0 and returned != 1) or (source_returned != 0 and source_returned != 1) or (origin != "source" and origin != "invocation") or (origin == "source" and returned != source_returned):
        raise Error("DecoderSession: invalid cache-return flags/origin")
    if layers <= 0 or work <= 0 or work > source_work or layers > work // 128 or provenance.byte_length() == 0:
        raise Error("DecoderSession: bounded positive work/layers/provenance required")
    var used = layers * 128
    if work - used < 2:
        raise Error("DecoderSession: fixed field work bound exceeded")
    used += 2
    if mode.byte_length() > work - used:
        raise Error("DecoderSession: mode work bound exceeded")
    used += mode.byte_length()
    if origin.byte_length() > work - used:
        raise Error("DecoderSession: origin work bound exceeded")
    used += origin.byte_length()
    if provenance.byte_length() > work - used:
        raise Error("DecoderSession: provenance work bound exceeded")
    return used + provenance.byte_length()


def validate_session_policy(p: DecoderSessionPolicy, layers: Int, source_work: Int) raises -> Int:
    return session_policy_charge(p.mode, p.return_cache, p.source_return_cache,
        p.return_origin, p.provenance, layers, p.work, source_work)
