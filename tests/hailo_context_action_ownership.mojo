# Direct value ownership test, no device or numerical operation.
from smidr.context_actions import ContextAction, encode_context_action, decode_context_action


def main() raises:
    var action = ContextAction(35, 4294967295, [287454020, 1, 1432778632, 31, 4294967295, 7])
    var bytes = encode_context_action(action)
    var saved = bytes.copy()
    action.values[0] = 0
    if bytes[5] != 68:
        raise Error("encoded bytes alias original fields")
    var decoded = decode_context_action(bytes)
    bytes[5] = 0
    if decoded.values[0] != 287454020:
        raise Error("decoded fields alias source bytes")
    var canonical = encode_context_action(decoded)
    for i in range(len(saved)):
        if saved[i] != canonical[i]:
            raise Error("owned canonical bytes changed")
    print("owned-value-snapshots-pass")
