"""Deterministic native-chat recovery policy, independent of CUDA hardware."""


struct ChatStartupState:
    """Records whether a loaded session crossed the recoverable startup gate."""

    var ready: Bool
    var admitted: Bool
    var current_model: String
    var previous_model: String

    def __init__(out self):
        self.ready = False
        self.admitted = False
        self.current_model = "selected model"
        self.previous_model = ""


struct ChatTurnAttempt:
    """Marks the exact point where a generated turn has closed in session KV."""

    var closed: Bool

    def __init__(out self):
        self.closed = False


struct ChatTurnRecovery(Copyable):
    """The only actions allowed after a native chat turn raises."""

    var continue_session: Bool
    var discard_inflight: Bool
    var reset_required: Bool
    var turn_committed: Bool
    var instruction: String

    def __init__(
        out self, continue_session: Bool, discard_inflight: Bool,
        reset_required: Bool, instruction: String,
        turn_committed: Bool = False,
    ):
        self.continue_session = continue_session
        self.discard_inflight = discard_inflight
        self.reset_required = reset_required
        self.turn_committed = turn_committed
        self.instruction = instruction

    def __copyinit__(out self, existing: Self):
        self.continue_session = existing.continue_session
        self.discard_inflight = existing.discard_inflight
        self.reset_required = existing.reset_required
        self.turn_committed = existing.turn_committed
        self.instruction = existing.instruction


def decide_chat_turn_recovery(
    healthy: Bool, generating: Bool, reset_required: Bool,
    inflight_generation: Int, turn_closed: Bool = False,
) -> ChatTurnRecovery:
    """Classifies a failed turn without inspecting or mutating GPU resources."""
    if turn_closed:
        return ChatTurnRecovery(
            False, False, reset_required,
            "turn closed in the live session but post-turn finalization failed; restart Aesir and follow autosave recovery output before deciding whether to retry the prompt",
            True,
        )
    if healthy and not generating:
        var suffix = String("")
        if inflight_generation > 0:
            suffix = "; uncommitted autosave intent discarded"
        if reset_required:
            return ChatTurnRecovery(
                True, inflight_generation > 0, True,
                "turn rejected; no turn committed" + suffix
                + "; interrupted prefill requires /clear before another prompt",
            )
        return ChatTurnRecovery(
            True, inflight_generation > 0, False,
            "turn rejected; no turn committed" + suffix
            + "; session remains ready",
        )
    return ChatTurnRecovery(
        False, False, reset_required,
        "native chat session is not safely recoverable; restart Aesir with the same model; failed turn was not committed",
    )


def chat_startup_failure_instruction(
    current_model: String, previous_model: String,
) -> String:
    """Returns a precise restart path after allocation/load/startup failure."""
    if previous_model != "":
        return (
            "model switch target failed before its session became ready; "
            "the previous model was unloaded and the conversation was reset; "
            "restart Aesir with the previous model reference '" + previous_model
            + "'; no target turn was committed"
        )
    return (
        "native chat failed before model session startup completed; "
        "check model integrity and available device memory, then restart Aesir "
        "with model reference '" + current_model + "'; no turn was committed"
    )


def chat_runtime_failure_instruction(model: String) -> String:
    """Returns the terminal action after a loaded session becomes unusable."""
    return (
        "native chat session became unusable; restart Aesir with model reference '"
        + model + "'; the current operation could not be safely finalized, so "
        "follow autosave recovery output before retrying a prompt"
    )
