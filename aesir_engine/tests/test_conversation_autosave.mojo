"""Atomic conversation autosave generations and recovery invariants."""

from std.sys import argv
from std.ffi import external_call
from cli.conversation import ConversationState
from cli.conversation_autosave import (
    AUTOSAVE_HEADER,
    INFLIGHT_HEADER,
    ConversationAutosave,
    _autosave_record,
    _parse_inflight,
    _parse_manifest,
    _serialize_inflight,
    _serialize_manifest,
)


def _autosave_test_cstring(value: String) -> List[Int8]:
    var result = List[Int8]()
    for byte in value.as_bytes():
        result.append(Int8(byte))
    result.append(0)
    return result^


def _autosave_test_exists(path: String) -> Bool:
    var encoded = _autosave_test_cstring(path)
    return external_call["access", Int32](encoded.unsafe_ptr(), 0) == 0


def _autosave_test_unlink(path: String):
    var encoded = _autosave_test_cstring(path)
    _ = external_call["unlink", Int32](encoded.unsafe_ptr())


def _autosave_test_state(turn_count: Int) raises -> ConversationState:
    var state = ConversationState(
        "sha256:autosave-fixture", "llama3", 64,
        "Remember.", "greedy; seed=42",
    )
    for index in range(turn_count):
        state.tokens.append(100 + index)
        state.append_turn(
            "user-" + String(index + 1), "assistant-" + String(index + 1)
        )
    state.sampler_draws = turn_count
    return state^


def _autosave_test_checkpoint(
    root: String, turn_count: Int, retain: Int = 2
) raises:
    var autosave = ConversationAutosave(root, retain)
    autosave.checkpoint(_autosave_test_state(turn_count), turn_count)


def _autosave_test_begin(root: String, turn: Int, retain: Int = 2) raises:
    var autosave = ConversationAutosave(root, retain)
    autosave.begin(turn)


def _autosave_test_recover(root: String, retain: Int = 2) raises -> Tuple[Int, Int, Int]:
    var autosave = ConversationAutosave(root, retain)
    var state = autosave.load_latest()
    return (
        len(state.turns), autosave.interrupted_generation(),
        autosave.interrupted_turn_number(),
    )


def _autosave_test_discard(root: String, retain: Int = 2) raises:
    var autosave = ConversationAutosave(root, retain)
    autosave.discard_interrupted()


def test_conversation_autosave_generations() raises:
    var root = "/tmp/aesir-autosave-unit-" + String(external_call["getpid", Int32]())
    var root_bytes = _autosave_test_cstring(root)
    if external_call["mkdir", Int32](root_bytes.unsafe_ptr(), 448) != 0:
        raise Error("unable to create autosave test directory")
    var sentinel = root + "/user-note.txt"
    var sentinel_bytes = _autosave_test_cstring(sentinel)
    var sentinel_fd = external_call["open64", Int32](
        sentinel_bytes.unsafe_ptr(), Int32(193), Int32(384)
    )
    if sentinel_fd < 0 or external_call["close", Int32](sentinel_fd) != 0:
        raise Error("unable to create autosave retention sentinel")

    try:
        _autosave_test_checkpoint(root, 1)
        _autosave_test_checkpoint(root, 2)
        _autosave_test_checkpoint(root, 3)
        if (
            _autosave_test_exists(root + "/generation-1.aesir")
            or not _autosave_test_exists(root + "/generation-2.aesir")
            or not _autosave_test_exists(root + "/generation-3.aesir")
            or not _autosave_test_exists(sentinel)
        ):
            raise Error("autosave retention escaped its owned generation set")
        var recovered = _autosave_test_recover(root)
        if recovered[0] != 3 or recovered[1] != 0:
            raise Error("autosave did not recover the latest committed generation")

        _autosave_test_begin(root, 4)
        recovered = _autosave_test_recover(root)
        if recovered[0] != 3 or recovered[1] != 4 or recovered[2] != 4:
            raise Error("autosave did not preserve committed state across interruption")
        _autosave_test_discard(root)
        if _autosave_test_exists(root + "/inflight") or not _autosave_test_exists(sentinel):
            raise Error("autosave interruption cleanup touched an unowned file")
    except error:
        _autosave_test_unlink(root + "/inflight")
        _autosave_test_unlink(root + "/current")
        for generation in range(1, 5):
            _autosave_test_unlink(root + "/generation-" + String(generation) + ".aesir")
        _autosave_test_unlink(sentinel)
        _ = external_call["rmdir", Int32](root_bytes.unsafe_ptr())
        raise error

    _autosave_test_unlink(root + "/current")
    _autosave_test_unlink(root + "/generation-2.aesir")
    _autosave_test_unlink(root + "/generation-3.aesir")
    _autosave_test_unlink(sentinel)
    if external_call["rmdir", Int32](root_bytes.unsafe_ptr()) != 0:
        raise Error("unable to remove autosave test directory")
    print("conversation autosave generations: PASS")


def _expect_manifest_rejection(raw: String, label: String) raises:
    var rejected = False
    try:
        _ = _parse_manifest(raw)
    except:
        rejected = True
    if not rejected:
        raise Error("corrupt autosave manifest accepted: " + label)


def _expect_inflight_rejection(raw: String, label: String) raises:
    var rejected = False
    try:
        _ = _parse_inflight(raw)
    except:
        rejected = True
    if not rejected:
        raise Error("corrupt autosave inflight record accepted: " + label)


def test_conversation_autosave_corrupt_records() raises:
    # A well-formed manifest round-trips exactly.
    var good = _parse_manifest(_serialize_manifest(3, [1, 2, 3]))
    if len(good) != 3 or good[0] != 1 or good[1] != 2 or good[2] != 3:
        raise Error("valid autosave manifest failed to parse")

    # Duplicate generation numbers are rejected.
    _expect_manifest_rejection(
        _serialize_manifest(3, [2, 2, 3]), "duplicate generation"
    )
    # Non-monotonic generation sequences are rejected.
    _expect_manifest_rejection(
        _serialize_manifest(3, [3, 2, 1]), "non-monotonic generations"
    )
    # Zero and negative generation IDs are rejected.
    _expect_manifest_rejection(
        _serialize_manifest(3, [0]), "zero generation"
    )
    _expect_manifest_rejection(
        _autosave_record(AUTOSAVE_HEADER + "\nRETAIN:3\nGENERATIONS:-1\n"),
        "negative generation",
    )
    # Empty generation fields are rejected.
    _expect_manifest_rejection(
        _autosave_record(AUTOSAVE_HEADER + "\nRETAIN:3\nGENERATIONS:1,,2\n"),
        "empty generation field",
    )
    # An empty generation list is rejected.
    _expect_manifest_rejection(
        _autosave_record(AUTOSAVE_HEADER + "\nRETAIN:3\nGENERATIONS:\n"),
        "empty generation list",
    )
    # The generation count may not exceed the retained count.
    _expect_manifest_rejection(
        _autosave_record(AUTOSAVE_HEADER + "\nRETAIN:1\nGENERATIONS:1,2\n"),
        "generation count exceeds retention",
    )
    # A truncated record is rejected.
    _expect_manifest_rejection(
        _autosave_record(AUTOSAVE_HEADER + "\nRETAIN:3\n"),
        "truncated manifest",
    )
    # A wrong magic header is rejected.
    _expect_manifest_rejection(
        _autosave_record("BOGUS_HEADER\nRETAIN:3\nGENERATIONS:1,2,3\n"),
        "wrong header",
    )
    # A tampered payload fails its checksum.
    _expect_manifest_rejection(
        _serialize_manifest(3, [1, 2, 3]).replace("GENERATIONS:1,2,3", "GENERATIONS:1,2,4"),
        "checksum mismatch",
    )

    # A well-formed inflight record round-trips exactly.
    var flight = _parse_inflight(_serialize_inflight(5, 3))
    if flight[0] != 5 or flight[1] != 3:
        raise Error("valid autosave inflight record failed to parse")
    # Negative generations and turns are rejected.
    _expect_inflight_rejection(
        _autosave_record(INFLIGHT_HEADER + "\nGENERATION:-1\nTURN:3\n"),
        "negative generation",
    )
    _expect_inflight_rejection(
        _autosave_record(INFLIGHT_HEADER + "\nGENERATION:5\nTURN:-1\n"),
        "negative turn",
    )
    # Out-of-range generations and turns are rejected.
    _expect_inflight_rejection(
        _autosave_record(INFLIGHT_HEADER + "\nGENERATION:2147483648\nTURN:3\n"),
        "generation beyond bound",
    )
    _expect_inflight_rejection(
        _autosave_record(INFLIGHT_HEADER + "\nGENERATION:5\nTURN:1025\n"),
        "turn beyond bound",
    )
    # A truncated record is rejected.
    _expect_inflight_rejection(
        _autosave_record(INFLIGHT_HEADER + "\nGENERATION:5\n"),
        "truncated inflight",
    )
    # A tampered payload fails its checksum.
    _expect_inflight_rejection(
        _serialize_inflight(5, 3).replace("TURN:3", "TURN:4"),
        "inflight checksum mismatch",
    )
    print("conversation autosave corrupt records: PASS")


def main() raises:
    var arguments = argv()
    if len(arguments) == 1:
        test_conversation_autosave_generations()
        return
    if len(arguments) != 3:
        raise Error("usage: test_conversation_autosave <seed|begin|recover|discard> <root>")
    var command = arguments[1]
    var root = arguments[2]
    if command == "seed":
        _autosave_test_checkpoint(root, 1, 3)
        print("SEEDED turns=1")
    elif command == "begin":
        var autosave = ConversationAutosave(root, 3)
        autosave.begin(2)
        print("READY generation=2 turn=2")
        _ = external_call["fflush", Int32](Int(0))
        while True:
            _ = external_call["pause", Int32]()
            if not autosave.enabled():
                raise Error("autosave lock owner closed unexpectedly")
    elif command == "recover":
        var recovered = _autosave_test_recover(root, 3)
        print(
            "RECOVERED turns=" + String(recovered[0])
            + " interrupted_generation=" + String(recovered[1])
            + " interrupted_turn=" + String(recovered[2])
        )
    elif command == "discard":
        _autosave_test_discard(root, 3)
        print("DISCARDED")
    else:
        raise Error("unknown autosave probe command")
