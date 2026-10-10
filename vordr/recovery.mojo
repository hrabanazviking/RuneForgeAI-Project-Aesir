# VÖRÐR crash-resistant recovery state machine (H149).
#
#   IDLE -> DEGRADED (transient) -> RESETTING (persistent)
#        -> REINITING -> VERIFYING -> IDLE
# Fatal errors drive any state -> HALTED (fail closed).
#
# Transitions are driven by the H145 taxonomy classification
# (transient/persistent/fatal); EVERY transition is logged with its
# cause. Illegal transitions (e.g. VERIFYING -> RESETTING) are
# rejected with the named error IllegalTransition.

from hailbru.errors import herror
from vordr.events import event_emit_slice


def _state_name(s: Int) -> String:
    if s == 0:
        return "IDLE"
    if s == 1:
        return "DEGRADED"
    if s == 2:
        return "RESETTING"
    if s == 3:
        return "REINITING"
    if s == 4:
        return "VERIFYING"
    return "HALTED"


def _legal(frm: Int, to: Int) -> Bool:
    # IDLE=0, DEGRADED=1, RESETTING=2, REINITING=3, VERIFYING=4, HALTED=5
    if to == 5:
        return frm != 5  # any live state may halt; HALTED is terminal
    if frm == 0:
        return to == 1 or to == 2
    if frm == 1:
        return to == 0 or to == 2
    if frm == 2:
        return to == 3
    if frm == 3:
        return to == 4
    if frm == 4:
        return to == 0
    return False


struct RecoveryMachine:
    var state: Int
    var transitions: List[String]

    def __init__(out self):
        self.state = 0
        self.transitions = List[String]()

    def current(self) -> String:
        return _state_name(self.state)

    def transition(
        mut self, arch: String, log_path: String, to: Int, cause: String
    ) raises:
        var frm = self.state
        if not _legal(frm, to):
            raise herror(
                "IllegalTransition",
                "recovery: illegal transition " + _state_name(frm)
                + " -> " + _state_name(to) + " (cause: " + cause + ")",
            )
        self.state = to
        var entry = _state_name(frm) + " -> " + _state_name(to)
        self.transitions.append(entry)
        event_emit_slice(
            arch, log_path, "H149", "RecoveryTransition",
            "\"from\": \"" + _state_name(frm) + "\", \"to\": \""
            + _state_name(to) + "\", \"cause\": \"" + cause + "\"",
        )

    def on_classified(
        mut self, arch: String, log_path: String, cls: String, name: String
    ) raises:
        # Drive the machine from a taxonomy classification.
        if cls == "transient":
            if self.state == 0:
                self.transition(arch, log_path, 1, name)
            # already DEGRADED: stay, the retry policy absorbs it
        elif cls == "persistent":
            if self.state == 0:
                self.transition(arch, log_path, 2, name)
            elif self.state == 1:
                self.transition(arch, log_path, 2, name + " (escalated)")
        elif cls == "fatal":
            self.transition(arch, log_path, 5, name)
        else:
            raise herror(
                "BadClassification",
                "unknown taxonomy class '" + cls + "' for " + name,
            )

    def recovered(mut self, arch: String, log_path: String) raises:
        # Transient absorbed: back to IDLE.
        self.transition(arch, log_path, 0, "transient absorbed")

    def reset_done(mut self, arch: String, log_path: String) raises:
        self.transition(arch, log_path, 3, "reset complete")

    def reinit_done(mut self, arch: String, log_path: String) raises:
        self.transition(arch, log_path, 4, "re-init complete")

    def verified(mut self, arch: String, log_path: String, ok: Bool) raises:
        if ok:
            self.transition(arch, log_path, 0, "post-reset verification clean")
        else:
            self.transition(arch, log_path, 5, "post-reset verification FAILED")


def scenario_transient(
    arch: String, log_path: String
) raises -> List[String]:
    # Scripted scenario 1: transient error -> recovery.
    var m = RecoveryMachine()
    m.on_classified(arch, log_path, "transient", "HangDetected:decode_step")
    m.recovered(arch, log_path)
    return m.transitions^


def scenario_persistent(
    arch: String, log_path: String
) raises -> List[String]:
    # Scripted scenario 2: persistent error -> reset + re-init.
    var m = RecoveryMachine()
    m.on_classified(arch, log_path, "persistent", "PciStatus.ReceivedMasterAbort")
    m.reset_done(arch, log_path)
    m.reinit_done(arch, log_path)
    m.verified(arch, log_path, True)
    return m.transitions^


def scenario_fatal(
    arch: String, log_path: String
) raises -> List[String]:
    # Scripted scenario 3: fatal error -> fail-closed halt.
    var m = RecoveryMachine()
    m.on_classified(arch, log_path, "fatal", "DeviceRemoved")
    return m.transitions^
