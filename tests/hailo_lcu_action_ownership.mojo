# Direct small-value ownership, mutable-field refusal and recovery; no model.
from smidr.lcu_actions import LcuAction, encode_lcu_action, decode_lcu_action, validate_lcu_action


def _reject(action: LcuAction) raises:
    var refused = False
    try:
        _ = encode_lcu_action(action)
    except:
        refused = True
    if not refused:
        raise Error("invalid mutable LCU state was encoded")
    refused = False
    try:
        validate_lcu_action(action)
    except:
        refused = True
    if not refused:
        raise Error("invalid mutable LCU state was validated")
    var fresh = encode_lcu_action(LcuAction(4, 4294967295, 7, 15, 255, 65535, 4294967295))
    if len(fresh) != 13 or fresh[5] != 127:
        raise Error("fresh valid LCU record failed after refusal")


def main() raises:
    var original = LcuAction(4, 2309737967, 5, 10, 113, 4660, 1432778632)
    var encoded = encode_lcu_action(original)
    var saved = encoded.copy()
    original.kernel_done_address = 0
    original.kernel_done_count = 0
    if encoded[7] != 52 or encoded[9] != 136:
        raise Error("encoded bytes alias scalar source")
    var decoded = decode_lcu_action(encoded)
    encoded[5] = 0
    encoded[7] = 0
    if decoded.cluster != 5 or decoded.lcu != 10 or decoded.kernel_done_address != 4660:
        raise Error("decoded scalar state aliases bytes")
    var copied = decoded.copy()
    decoded.kernel_done_count = 0
    var canonical = encode_lcu_action(copied)
    for i in range(len(saved)):
        if saved[i] != canonical[i]:
            raise Error("copied canonical record changed")
    for field in range(7):
        for boundary in range(2):
            var bad = copied.copy()
            var value = -1 if boundary == 0 else 4294967296
            if field == 0:
                bad.kind = value
            elif field == 1:
                bad.timestamp = value
            elif field == 2:
                bad.cluster = value
            elif field == 3:
                bad.lcu = value
            elif field == 4:
                bad.network = value
            elif field == 5:
                bad.kernel_done_address = value
            else:
                bad.kernel_done_count = value
            _reject(bad)
    for field in range(3):
        var bad = LcuAction(5, 0, 0, 0, 0, 0, 0)
        if field == 0:
            bad.network = 1
        elif field == 1:
            bad.kernel_done_address = 1
        else:
            bad.kernel_done_count = 1
        _reject(bad)
    _reject(LcuAction(36, 0, 0, 0, 0, 1, 0))
    print("owned-lcu-values-pass;18-refusal-and-fresh-success-cycles")
