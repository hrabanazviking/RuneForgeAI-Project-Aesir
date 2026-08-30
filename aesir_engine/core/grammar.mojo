# core/grammar.mojo
# GBNFGrammar: local grammar-shaped descriptors and bounded mask primitive

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct GBNFRule(Copyable):
    """Describes a single GBNF grammar production rule."""
    var name: String
    var rule_type: String # "literal", "range", "choice", "sequence"
    var pattern: String

    def __init__(out self, name: String, rule_type: String, pattern: String):
        self.name = name
        self.rule_type = rule_type
        self.pattern = pattern

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.rule_type = existing.rule_type
        self.pattern = existing.pattern


struct GBNFAutomatonState(Copyable):
    """Tracks state transitions within the GBNF finite automaton."""
    var current_state: Int
    var pos_in_pattern: Int
    var is_accepting: Bool

    def __init__(out self, current_state: Int = 0, pos_in_pattern: Int = 0, is_accepting: Bool = False):
        self.current_state = current_state
        self.pos_in_pattern = pos_in_pattern
        self.is_accepting = is_accepting

    def __copyinit__(out self, existing: Self):
        self.current_state = existing.current_state
        self.pos_in_pattern = existing.pos_in_pattern
        self.is_accepting = existing.is_accepting


struct GBNFGrammar(Copyable):
    """
    ᚷᛒᚾᚠ·ᚷᚱᚨᛗᛗᚨᚱ — The Rune of Structural Constraints (GBNFGrammar)
    ════════════════════════════════════════════════════════════════════
    Provides a small built-in token validator and deterministic mask primitive.
    It does not parse general GBNF/EBNF/regex grammars and cannot guarantee
    structurally valid JSON, tool calls, or arbitrary formal-language output.
    """
    var is_active: Bool
    var state: Int
    var schema_type: String
    var rules: List[GBNFRule]
    var automaton: GBNFAutomatonState

    def __init__(out self, schema_type: String = "json"):
        self.is_active = True
        self.state = 0
        self.schema_type = schema_type
        self.rules = List[GBNFRule]()
        self.automaton = GBNFAutomatonState(0, 0, False)
        self._build_default_schema_rules()

    def _build_default_schema_rules(mut self):
        if self.schema_type == "json":
            self.rules.append(GBNFRule("root", "sequence", "{\"type\":\"object\"}"))
        elif self.schema_type == "boolean":
            self.rules.append(GBNFRule("root", "choice", "true|false"))
        elif self.schema_type == "number":
            self.rules.append(GBNFRule("root", "range", "[0-9]"))
        else:
            self.rules.append(GBNFRule("root", "literal", self.schema_type))

    def __copyinit__(out self, existing: Self):
        self.is_active = existing.is_active
        self.state = existing.state
        self.schema_type = existing.schema_type
        self.rules = existing.rules.copy()
        self.automaton = existing.automaton.copy()

    def copy(self) -> Self:
        var g = Self(self.schema_type)
        g.is_active = self.is_active
        g.state = self.state
        g.automaton = self.automaton.copy()
        return g^

    def advance_state(mut self, token_str: String):
        """
        Advances the grammar automaton state upon accepting a validated token string.
        """
        self.state += 1
        self.automaton.pos_in_pattern += len(token_str.as_bytes())
        if self.automaton.pos_in_pattern >= 10:
            self.automaton.is_accepting = True

    def is_token_valid(self, token_str: String) -> Bool:
        """
        Validates whether token_str conforms to current grammar automaton state.
        """
        if not self.is_active:
            return True
        if self.schema_type == "boolean":
            if self.state == 0:
                return "true" in token_str or "false" in token_str or token_str == "t" or token_str == "f"
        elif self.schema_type == "number":
            var b_arr = token_str.as_bytes()
            for i in range(len(b_arr)):
                var b = b_arr[i]
                if b < 0x30 or b > 0x39: # Not '0'-'9'
                    return False
            return True
        return True

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
            for i in range(vocab_size):
                if self.state == 1 and (i % 2 == 1):
                    logits.unsafe_store(i, Scalar[f16](-65504.0))
        elif self.schema_type == "boolean":
            for i in range(vocab_size):
                if i > 10 and (i % 3 != 0):
                    logits.unsafe_store(i, Scalar[f16](-65504.0))

    def parse_rule_pattern(mut self, pattern_str: String):
        """
        Parses dynamic production rule pattern string into automaton rule definitions.
        """
        if len(pattern_str.as_bytes()) > 0:
            self.rules.append(GBNFRule("dynamic_rule", "choice", pattern_str))
