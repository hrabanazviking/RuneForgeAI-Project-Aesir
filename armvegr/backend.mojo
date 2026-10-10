# H036 — Backend-selection interface (CPU stage).
#
# The interface SKIPTI (D4) will later extend: a Backend id set
# (CPU / NPU / AUTO), select_backend(op, shapes, want, log), and the
# C2-stage rule that EVERY op resolves to CPU with the decision logged.
# A stub NPU backend type exists and compiles (proving the extension
# point) but is never selected: NPU unready means CPU, loudly (L11
# fail-closed). A test asserts no code path can return NPU at this stage.

from std.collections import List


def BACKEND_CPU() -> Int:
    return 0


def BACKEND_NPU() -> Int:
    return 1


def BACKEND_AUTO() -> Int:
    return 2


struct NpuBackendStub:
    # Extension point for the D4 SKIPTI backend. Exists, compiles, and is
    # never selected at the C2 stage: ready is always False, and any
    # dispatch attempt fails closed to CPU with a logged reason.
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
) -> Int:
    # want: BACKEND_CPU / BACKEND_NPU / BACKEND_AUTO request.
    # At the C2 stage every op resolves to CPU; the decision is appended
    # to log as "op m=.. n=.. k=.. want=.. -> CPU (reason)".
    var stub = NpuBackendStub()
    var reason = String(
        "NPU backend unready at C2 stage; CPU is the only verified backend (L11 fail-closed)"
    )
    if want == BACKEND_NPU() and stub.is_ready():
        # Unreachable at this stage (stub.ready is always False); kept as
        # the documented extension point for D4.
        log.append(op + " -> NPU")
        return BACKEND_NPU()
    var entry = (
        op
        + " m="
        + String(m)
        + " n="
        + String(n)
        + " k="
        + String(k)
        + " want="
        + String(want)
        + " -> CPU ("
        + reason
        + ")"
    )
    log.append(entry)
    return BACKEND_CPU()
