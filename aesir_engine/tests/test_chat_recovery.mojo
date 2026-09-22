"""Hardware-independent fault injection for native chat lifecycle policy."""
from std.ffi import external_call
from cli.chat_recovery import (
    chat_runtime_failure_instruction,
    chat_startup_failure_instruction,
    decide_chat_turn_recovery,
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
