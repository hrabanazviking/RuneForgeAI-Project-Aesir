"""Hardware-independent fault injection for native chat lifecycle policy."""
from std.ffi import external_call
from cli.chat_recovery import (
    chat_runtime_failure_instruction,
    chat_startup_failure_instruction,
    decide_chat_turn_recovery,
)
from cli.conversation import (
    ConversationState,
    deserialize_conversation,
    require_conversation_compatible,
    serialize_conversation,
)
from cli.cuda_chat import ChatTranscript


def _release_owned_transcript(fd: Int32) raises:
    var transcript = ChatTranscript("", Int(fd))
    transcript.emit("")
    raise Error("injected recovery unwind")


def test_chat_recovery_policy() raises:
    # Allocation failure before an initial session owns no recoverable state.
    var allocation = chat_startup_failure_instruction("gemma", "")
    if ("available device memory" not in allocation
            or "restart Aesir" not in allocation
            or "gemma" not in allocation):
        raise Error("Initial allocation failure lacks a precise restart path")

    # A post-exec target load failure cannot resurrect the unloaded process;
    # it must retain the exact previous reference for a manual restart.
    var switched_load = chat_startup_failure_instruction("qwen", "llama-old")
    if ("previous model was unloaded" not in switched_load
            or "llama-old" not in switched_load
            or "no target turn was committed" not in switched_load):
        raise Error("Model-switch load failure obscures prior-session state")

    # Timeout during prefill leaves a healthy, idle session whose KV must be
    # explicitly reset. The uncommitted autosave marker is safe to discard.
    var prefill_timeout = decide_chat_turn_recovery(
        True, False, True, 7, False,
    )
    if (not prefill_timeout.continue_session
            or not prefill_timeout.discard_inflight
            or not prefill_timeout.reset_required
            or prefill_timeout.turn_committed
            or "/clear" not in prefill_timeout.instruction):
        raise Error("Prefill timeout recovery changed its reset invariant")

    var rejected = decide_chat_turn_recovery(
        True, False, False, 0, False,
    )
    if (not rejected.continue_session or rejected.discard_inflight
            or rejected.turn_committed
            or "session remains ready" not in rejected.instruction):
        raise Error("Safe pre-generation rejection no longer preserves session")

    # Once output has closed in KV, an I/O/finalization error must never invite
    # a blind retry or discard evidence that restart recovery needs to inspect.
    var closed = decide_chat_turn_recovery(True, False, False, 8, True)
    if (closed.continue_session or closed.discard_inflight
            or not closed.turn_committed
            or "autosave recovery" not in closed.instruction):
        raise Error("Closed-turn finalization failure permits a false retry")

    var execution = decide_chat_turn_recovery(False, True, False, 9, False)
    if (execution.continue_session or execution.discard_inflight
            or execution.turn_committed
            or "restart Aesir" not in execution.instruction):
        raise Error("Unhealthy generation failure was treated as recoverable")
    if "safely finalized" not in chat_runtime_failure_instruction("qwen"):
        raise Error("Terminal runtime failure overclaims commit state")

    # Process-image handoff resources remain scope-owned even on recovery paths.
    var name = List[Int8]()
    for byte in String("aesir-s15-transcript").as_bytes():
        name.append(Int8(byte))
    name.append(0)
    var fd = external_call["memfd_create", Int32](
        name.unsafe_ptr(), UInt32(0)
    )
    if fd < 0:
        raise Error("Unable to create recovery resource fixture")
    var unwound = False
    try:
        _release_owned_transcript(fd)
    except error:
        unwound = "injected recovery unwind" in String(error)
    if not unwound:
        raise Error("Recovery resource fixture did not exercise error unwind")
    if external_call["fcntl", Int32](fd, Int32(3), Int64(0)) >= 0:
        _ = external_call["close", Int32](fd)
        raise Error("Recovery transcript ownership leaked its descriptor")


def _recovery_snapshot_fixture() raises -> ConversationState:
    var state = ConversationState(
        "sha256:recovery-fixture", "llama3", 64,
        "Remember.", "greedy; seed=42",
    )
    state.tokens.append(100)
    state.tokens.append(101)
    state.append_turn("user-1", "assistant-1")
    state.sampler_draws = 2
    return state^


def _expect_snapshot_rejection(raw: String, label: String) raises:
    var rejected = False
    try:
        _ = deserialize_conversation(raw)
    except:
        rejected = True
    if not rejected:
        raise Error("corrupt recovery snapshot accepted: " + label)


def _expect_foreign_rejection(
    saved: ConversationState, current: ConversationState, label: String
) raises:
    var rejected = False
    try:
        require_conversation_compatible(saved, current)
    except error:
        rejected = True
    if not rejected:
        raise Error("foreign recovery snapshot accepted: " + label)


def test_chat_recovery_snapshot_validation() raises:
    # The recovery policy must never advise resuming from a dead session.
    var dead = decide_chat_turn_recovery(False, True, False, 5, False)
    if dead.continue_session or "restart Aesir" not in dead.instruction:
        raise Error("recovery policy advised resuming a dead session")

    # A well-formed snapshot round-trips through the codec.
    var saved = _recovery_snapshot_fixture()
    var encoded = serialize_conversation(saved)
    var decoded = deserialize_conversation(encoded)
    if len(decoded.turns) != 1 or decoded.model_identity != saved.model_identity:
        raise Error("valid recovery snapshot failed to deserialize")

    # Corrupt snapshots are rejected before any resume advice: bad magic.
    _expect_snapshot_rejection(
        encoded.replace("AESIR_CONVERSATION_V1", "BOGUS_MAGIC"), "bad magic"
    )

    # A tampered payload fails its checksum.
    _expect_snapshot_rejection(
        encoded.replace("USER:", "USERS:"), "tampered payload"
    )

    # A truncated snapshot is rejected.
    _expect_snapshot_rejection(
        String(encoded[byte=0:len(encoded.bytes()) // 2]), "truncated snapshot"
    )

    # Foreign snapshots are rejected before KV restore: different model.
    var foreign = _recovery_snapshot_fixture()
    foreign.model_identity = "sha256:other-model"
    _expect_foreign_rejection(saved, foreign, "different model identity")

    # Different model profile.
    foreign = _recovery_snapshot_fixture()
    foreign.profile = "gemma4"
    _expect_foreign_rejection(saved, foreign, "different model profile")

    # Different sampling identity.
    foreign = _recovery_snapshot_fixture()
    foreign.sampling_identity = "cuda; temperature=0.9"
    _expect_foreign_rejection(saved, foreign, "different sampling identity")

    # Different system prompt.
    foreign = _recovery_snapshot_fixture()
    foreign.system_prompt = "Forget."
    _expect_foreign_rejection(saved, foreign, "different system prompt")

    # The identical session identity is still admitted.
    require_conversation_compatible(saved, _recovery_snapshot_fixture())
    print("chat recovery snapshot validation: PASS")
