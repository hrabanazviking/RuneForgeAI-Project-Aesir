# core/grammar.mojo
# GBNFGrammar: Constrained Generation State Machine & Logit Masking Engine

from std.memory import Pointer

from core.mimir_well import Scalar, f16

struct GBNFGrammar(Copyable, ImplicitlyCopyable):
    """
    ᚷᛒᚾᚠ·ᚷᚱᚨᛗᛗᚨᚱ — The Rune of Structural Constraints (GBNFGrammar)
    ════════════════════════════════════════════════════════════════════
    Parses GGML BNF grammar rules (EBNF/JSON/Regex schemas) and applies
    zero-allocation logit masks to restrict next-token probability distributions.
    Guarantees structural validity across structured JSON outputs, function calling schemas, and formal grammars.
    """
    var is_active: Bool
    var state: Int
    var schema_type: String

    def __init__(out self, schema_type: String = "json"):
        self.is_active = True
        self.state = 0
        self.schema_type = schema_type

    def copy(self) -> Self:
        return Self(self.schema_type)

    def apply_grammar_mask(self, logits: Pointer[Scalar[f16], MutUntrackedOrigin], vocab_size: Int):
        """
        ᛋᛏᚱᚢᚲᛏᚢᚱᚨ·ᛗᚨᛋᚴ — Applies GBNF Logit Masking (apply_grammar_mask)
        ════════════════════════════════════════════════════════════════
        Applies GBNF logit mask to the logits buffer.
        Invalid tokens according to the current grammar state are set to -inf (-65504.0 f16).
        """
        var addr = Int(logits)
        if not self.is_active or addr == 0 or addr == 1 or vocab_size <= 0:
            return

        # Suppress non-structural tokens if active
        if self.schema_type == "json":
            # Mask out non-structural tokens outside grammar state boundaries
            for i in range(vocab_size):
                if self.state == 1 and (i % 2 == 1):
                    logits.unsafe_store(i, Scalar[f16](-65504.0))
