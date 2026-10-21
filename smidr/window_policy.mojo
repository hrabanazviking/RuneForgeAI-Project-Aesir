# Original bounded per-layer mathematical mask choice, never device encoding.
@fieldwise_init
struct DecoderWindowPolicy(Copyable, Movable):
    var windows: List[Int]
    var origin: String
    var provenance: String
    var work: Int


def empty_window_policy() -> DecoderWindowPolicy:
    return DecoderWindowPolicy(List[Int](), "", "", 0)


def same_window_policy(a: DecoderWindowPolicy, b: DecoderWindowPolicy) -> Bool:
    return a.windows == b.windows and a.origin == b.origin and a.provenance == b.provenance and a.work == b.work


def window_policy_charge(layers: Int, origin: String, provenance: String,
                         work: Int, source_work: Int) raises -> Int:
    if layers <= 0 or work <= 0 or work > source_work or layers > work // 129 or (origin != "source" and origin != "invocation") or provenance.byte_length() == 0:
        raise Error("DecoderWindow: bounded layers/work/origin/provenance required")
    var used = layers * 129
    if origin.byte_length() > work - used:
        raise Error("DecoderWindow: origin work bound exceeded")
    used += origin.byte_length()
    if provenance.byte_length() > work - used:
        raise Error("DecoderWindow: provenance work bound exceeded")
    return used + provenance.byte_length()


def validate_window_policy(p: DecoderWindowPolicy, layers: Int, source_work: Int) raises -> Int:
    var charge = window_policy_charge(layers, p.origin, p.provenance, p.work, source_work)
    if len(p.windows) != layers:
        raise Error("DecoderWindow: one width per source layer required")
    for width in p.windows:
        if width < 0:
            raise Error("DecoderWindow: window width cannot be negative")
    return charge


def window_key_admitted(position: Int, key: Int, width: Int) raises -> Bool:
    # Isolated integer relation only; never reads scores or performs attention.
    if position < 0 or key < 0 or width < 0:
        raise Error("DecoderWindow: nonnegative index/width required")
    if key > position:
        return False
    return width == 0 or position - key < width
