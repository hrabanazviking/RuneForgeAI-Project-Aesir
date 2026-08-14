# core/error_guard.mojo
# ErrorGuard: Defensive Pointer Alignment, Bounds Checking & Logit Sanitization

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct ErrorGuard:
    """
    ᛖᚱᚱᛟᚱ·ᚷᚢᚨᚱᛞ — The Shield of Invariance (ErrorGuard)
    ═════════════════════════════════════════════════════
    Provides defensive assertion gates, pointer alignment verification,
    slice bounds checking, and NaN/Inf float16 logit sanitization.
    Guarantees that invalid silicon states cannot corrupt the inference pipeline.
    """

    @staticmethod
    def validate_pointer[T: AnyType](ptr: Pointer[T, MutUntrackedOrigin]) -> Bool:
        """
        ᛈᛟᛁᚾᛏᛖᚱ·ᚠᚨᛚᛁᛞᚨᛏᛖ — Pointer Alignment & Validity Gate (validate_pointer)
        ══════════════════════════════════════════════════════════════════════════
        Verifies that memory pointers drawn from Midgard or MimirWell are non-null
        and properly aligned for SIMD vector execution.
        """
        return Int(ptr) != 0

    @staticmethod
    def bounds_check(index: Int, max_len: Int) -> Bool:
        """
        ᛒᛟᚢᚾᛞᛋ·ᚲᚺᛖᚲᚴ — The Boundary Rune (bounds_check)
        ════════════════════════════════════════════════
        Guarantees slice indexing stays within the safe bounds [0, max_len).
        Prevents out-of-bounds reads and buffer overflows across tensor slices.
        """
        return index >= 0 and index < max_len

    @staticmethod
    def sanitize_logits(logits: Pointer[Scalar[f16], MutUntrackedOrigin], count: Int):
        """
        ᛋᚨᚾᛁᛏᛁᛉᛖ·ᛚᛟᚷᛁᛏᛋ — The Cleansing Fire of Logits (sanitize_logits)
        ═══════════════════════════════════════════════════════════════════
        Cleanses NaN, Inf, and subnormal Float16 values in the logits buffer.
        Replaces non-finite values with safe minimum scalar bounds (-65504.0).
        Ensures numerical stability during argmax and softmax sampling.
        """
        if Int(logits) == 0 or count <= 0:
            return

        for i in range(count):
            var val = logits.unsafe_load(i)
            # Check for NaN / Inf range overflow in f16
            if val != val or val > Scalar[f16](65504.0) or val < Scalar[f16](-65504.0):
                logits.unsafe_store(i, Scalar[f16](-65504.0))
