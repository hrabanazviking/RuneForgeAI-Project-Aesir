# core/error_guard.mojo
# ErrorGuard: sentinel-address checks, bounds predicates, and logit sanitization

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct ErrorGuard:
    """
    ᛖᚱᚱᛟᚱ·ᚷᚢᚨᚱᛞ — The Shield of Invariance (ErrorGuard)
    ═════════════════════════════════════════════════════
    Provides narrow sentinel-address checks, slice bounds predicates, and
    NaN/Inf float16 logit sanitization. Callers remain responsible for pointer
    provenance, allocation span, alignment, lifetime, and synchronization.
    """

    @staticmethod
    def validate_pointer[T: AnyType](ptr: Pointer[T, MutUntrackedOrigin]) -> Bool:
        """
        ᛈᛟᛁᚾᛏᛖᚱ·ᚠᚨᛚᛁᛞᚨᛏᛖ — Pointer Alignment & Validity Gate (validate_pointer)
        ══════════════════════════════════════════════════════════════════════════
        Rejects null and address-one sentinels only. It cannot prove allocation
        ownership, accessible span, alignment, or lifetime.
        """
        var addr = Int(ptr)
        return addr != 0 and addr != 1

    @staticmethod
    def bounds_check(index: Int, max_len: Int) -> Bool:
        """
        ᛒᛟᚢᚾᛞᛋ·ᚲᚺᛖᚲᚴ — The Boundary Rune (bounds_check)
        ════════════════════════════════════════════════
        Checks whether one index is within [0, max_len). The caller must apply
        the result before every access and retain ownership of the actual span.
        """
        return index >= 0 and index < max_len

    @staticmethod
    def sanitize_logits(
        logits: Pointer[Scalar[f16], MutUntrackedOrigin], count: Int
    ) raises:
        """
        ᛋᚨᚾᛁᛏᛁᛉᛖ·ᛚᛟᚷᛁᛏᛋ — The Cleansing Fire of Logits (sanitize_logits)
        ═══════════════════════════════════════════════════════════════════
        Replaces NaN and infinite Float16 values in a caller-owned logits buffer.
        Replaces non-finite values with safe minimum scalar bounds (-65504.0).
        It does not prove pointer ownership or general numerical stability.
        """
        var addr = Int(logits)
        if addr == 0 or addr == 1:
            raise Error("logit sanitizer requires a non-sentinel pointer")
        if count <= 0:
            raise Error("logit sanitizer count must be positive")

        for i in range(count):
            var val = logits.unsafe_load(i)
            # Check for NaN / Inf range overflow in f16
            if val != val or val > Scalar[f16](65504.0) or val < Scalar[f16](-65504.0):
                logits.unsafe_store(i, Scalar[f16](-65504.0))
