# H036 — Backend-selection interface; revised for the owner-approved Hailo-only mission.
# CPU inference and automatic CPU fallback are prohibited. Until a verified
# Hailo-10 implementation exists, every inference backend request fails closed.

from std.collections import List


def BACKEND_CPU() -> Int:
    return 0


def BACKEND_NPU() -> Int:
    return 1


def BACKEND_AUTO() -> Int:
    return 2


def NPU_UNAVAILABLE_REASON() -> String:
    """Reason the Hailo backend currently fails closed."""
    return String(
        "Hailo-10 inference backend is not implemented; CPU fallback is disabled"
    )


struct NpuBackendStub:
    # Extension point for the D4 SKIPTI backend. Exists, compiles, and is
    # never selected: ready is always False. Post-H111-NO-GO there is no
    # selection branch at all — the NPU path reports itself honestly
    # unavailable (see select_backend).
    var ready: Bool

    def __init__(out self):
        self.ready = False

    def is_ready(self) -> Bool:
        return self.ready

def select_backend(
    op: String,
    m: Int,
    n: Int,
    k: Int,
    want: Int,
    mut log: List[String],
) raises -> Int:
    """Select Hailo only; refuse CPU/AUTO and unimplemented Hailo requests.

    This compatibility entrypoint intentionally never returns a CPU backend.
    A later implementation may return BACKEND_NPU only after the Hailo path
    passes its device execution gate. Until then all requests fail closed.
    """
    var context = (
        op + " m=" + String(m) + " n=" + String(n) + " k=" + String(k)
    )
    if want == BACKEND_CPU():
        raise Error(
            String("CpuInferenceProhibited: ") + context
            + String(" cannot execute on the Pi CPU; request Hailo-10")
        )
    if want == BACKEND_AUTO():
        raise Error(
            String("HailoUnavailable: ") + context
            + String(" has no verified Hailo backend; automatic CPU fallback is disabled")
        )
    if want == BACKEND_NPU():
        raise Error(
            String("HailoUnavailable: ") + context + String("; ")
            + NPU_UNAVAILABLE_REASON()
        )
    raise Error(String("Unsupported backend selection: ") + String(want))
