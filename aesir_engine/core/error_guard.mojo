# core/error_guard.mojo
# ErrorGuard: sentinel-address checks, bounds predicates, and logit sanitization

from std.memory import Pointer
from core.mimir_well import Scalar, f16, f32

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

    @staticmethod
    def is_finite_f32(v: Scalar[f32]) -> Bool:
        """
        ᚠᛁᚾᛁᛏᛖ·ᚠ32 — The Still-Water Rune (is_finite_f32)
        ══════════════════════════════════════════════════
        True iff the Float32 scalar is neither NaN nor ±Inf. Read-only;
        it never mutates the caller-owned value.
        """
        if v != v:
            return False
        if v > Scalar[f32](3.4028234663852886e38) or v < Scalar[f32](-3.4028234663852886e38):
            return False
        return True

    @staticmethod
    def is_finite_f64(v: Float64) -> Bool:
        """
        ᚠᛁᚾᛁᛏᛖ·ᚠ64 — The Deep-Water Rune (is_finite_f64)
        ═════════════════════════════════════════════════
        True iff the Float64 scalar is neither NaN nor ±Inf. Read-only;
        it never mutates the caller-owned value.
        """
        if v != v:
            return False
        if v > Float64(1.7976931348623157e308) or v < Float64(-1.7976931348623157e308):
            return False
        return True

    @staticmethod
    def count_nonfinite_f32(
        ptr: Pointer[Scalar[f32], MutUntrackedOrigin], count: Int
    ) raises -> Int:
        """
        ᚲᛟᚢᚾᛏ·ᚾᛟᚾᚠᛁᚾᛁᛏᛖ — The Tally of Troubled Waters (count_nonfinite_f32)
        ════════════════════════════════════════════════════════════════════════
        Counts NaN and infinite Float32 values in a caller-owned buffer without
        modifying it. Applies the same pointer/count gates as sanitize_logits:
        rejects null and address-one sentinels, and requires count > 0.
        """
        var addr = Int(ptr)
        if addr == 0 or addr == 1:
            raise Error("logit sanitizer requires a non-sentinel pointer")
        if count <= 0:
            raise Error("logit sanitizer count must be positive")

        var bad = 0
        for i in range(count):
            if not ErrorGuard.is_finite_f32(ptr.unsafe_load(i)):
                bad += 1
        return bad
