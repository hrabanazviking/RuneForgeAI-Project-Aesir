"""Conversation snapshot codec and compatibility invariants."""

from cli.conversation import (
    ConversationState,
    deserialize_conversation,
    require_conversation_compatible,
    serialize_conversation,
)


def _conversation_fixture() raises -> ConversationState:
    var state = ConversationState(
        "sha256:0123456789abcdef",
        "llama3",
        512,
        "Remember the whole thread.\nNo network.",
        "greedy; temperature=0.0; seed=42",
    )
    state.tokens = [128000, 128006, 882, 128007, 271, 9906, 128009]
    state.sampler_draws = 2
    state.append_turn("Hello, ᚠ!", "Hi there.\nStill here.")
    return state^


def test_conversation_codec() raises:
    var staged = ConversationState(
        "model", "gemma4", 64, "", "greedy"
    )
    staged.append_turn("hello", "hi")
    var unsnapshotted_rejected = False
    try:
        _ = serialize_conversation(staged)
    except error:
        unsnapshotted_rejected = "exact token stream" in String(error)
    if not unsnapshotted_rejected:
        raise Error("conversation save accepted turns without a token snapshot")

    var original = _conversation_fixture()
    var encoded = serialize_conversation(original)
    var decoded = deserialize_conversation(encoded)
    if (
        decoded.model_identity != original.model_identity
        or decoded.profile != "llama3"
        or decoded.context_length != 512
        or decoded.system_prompt != original.system_prompt
        or decoded.sampling_identity != original.sampling_identity
        or decoded.sampler_draws != 2
        or len(decoded.tokens) != len(original.tokens)
        or len(decoded.turns) != 1
        or decoded.turns[0].user != "Hello, ᚠ!"
        or decoded.turns[0].assistant != "Hi there.\nStill here."
    ):
        raise Error("conversation snapshot round trip drifted")
    for index in range(len(original.tokens)):
        if decoded.tokens[index] != original.tokens[index]:
            raise Error("conversation exact token stream drifted")

    var corrupted = encoded.replace("CHECKSUM:", "CHECKSUM:0")
    var corruption_rejected = False
    try:
        _ = deserialize_conversation(corrupted)
    except error:
        corruption_rejected = "checksum" in String(error)
    if not corruption_rejected:
        raise Error("conversation checksum corruption was not rejected")


def test_conversation_compatibility() raises:
    var saved = _conversation_fixture()
    var current = _conversation_fixture()
    require_conversation_compatible(saved, current)
    current.context_length = 1024
    var mismatch_rejected = False
    try:
        require_conversation_compatible(saved, current)
    except error:
        mismatch_rejected = "context length" in String(error)
    if not mismatch_rejected:
        raise Error("conversation load accepted a context mismatch")

    current = _conversation_fixture()
    current.model_identity = "different-model"
    mismatch_rejected = False
    try:
        require_conversation_compatible(saved, current)
    except error:
        mismatch_rejected = "different model" in String(error)
    if not mismatch_rejected:
        raise Error("conversation load accepted a model mismatch")
