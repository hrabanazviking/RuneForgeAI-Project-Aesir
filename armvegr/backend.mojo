# H036 — Backend-selection interface (CPU stage).
# H139 — SKIPTI AUTO = CPU-only honest mode (NO-GO branch).
#
# Phase-D ended H111 = NO-GO (the Compiler Wall held): the NPU compute path
# is honestly closed. select_backend() now resolves EVERYTHING (CPU and
# AUTO wants) to CPU, and every dispatch logs the declared reason
# "NPU unavailable (Phase-D NO-GO H111), using verified CPU path" (L11:
# fail closed, degrade honestly — no silent fallback, no masquerade).
# An explicit NPU want raises the named NpuUnavailable error citing the
# H111 verdict. The NpuBackendStub type remains as the documented extension
# point, but NO code path can select NPU in this build (the old
# want==NPU-and-ready branch is deleted, not just unreachable).

from std.collections import List


def BACKEND_CPU() -> Int:
    return 0


def BACKEND_NPU() -> Int:
    return 1


def BACKEND_AUTO() -> Int:
    return 2


def NPU_UNAVAILABLE_REASON() -> String:
    """The declared reason every CPU dispatch logs (H139, L11)."""
    return String(
        "NPU unavailable (Phase-D NO-GO H111), using verified CPU path"
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
    """H139 — resolve the backend for one op, honestly.

    want BACKEND_CPU or BACKEND_AUTO -> BACKEND_CPU, logging
    NPU_UNAVAILABLE_REASON() (L11: the degradation is declared, never
    silent). want BACKEND_NPU -> raises the named NpuUnavailable error:
    the NPU compute path is closed by the Phase-D H111 NO-GO verdict.
    """
    if want == BACKEND_NPU():
        raise Error(
            String("NpuUnavailable: explicit NPU backend requested for ")
            + op + String(", but the NPU compute path is closed ")
            + String("(MIMISBRUNNR Phase-D H111 = NO-GO, the Compiler Wall ")
            + String("held). No NPU code path exists in this build; ")
            + String("request BACKEND_CPU or BACKEND_AUTO.")
        )
    var reason = NPU_UNAVAILABLE_REASON()
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
