# core/grammar.mojo
# Token-text-aware constrained decoding for a deliberately bounded subset.

from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct GBNFRule(Copyable):
    """Describes one declared grammar rule."""
    var name: String
    var rule_type: String
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
    """Observable state for the bounded token-text automaton."""
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

def _number_state(text: String) -> Int:
    """Returns a JSON-number DFA state, or -1 for an impossible prefix."""
    var state = 0
    var bytes = text.as_bytes()
    for index in range(len(bytes)):
        var byte = Int(bytes[index])
        if state == 0:
            if byte == 45:
                state = 1
            elif byte == 48:
                state = 2
            elif byte >= 49 and byte <= 57:
                state = 3
            else:
                return -1
        elif state == 1:
            if byte == 48:
                state = 2
            elif byte >= 49 and byte <= 57:
                state = 3
            else:
                return -1
        elif state == 2:
            if byte == 46:
                state = 4
            elif byte == 69 or byte == 101:
                state = 6
            else:
                return -1
        elif state == 3:
            if byte >= 48 and byte <= 57:
                state = 3
            elif byte == 46:
                state = 4
            elif byte == 69 or byte == 101:
                state = 6
            else:
                return -1
        elif state == 4:
            if byte >= 48 and byte <= 57:
                state = 5
            else:
                return -1
        elif state == 5:
            if byte >= 48 and byte <= 57:
                state = 5
            elif byte == 69 or byte == 101:
                state = 6
            else:
                return -1
        elif state == 6:
            if byte == 43 or byte == 45:
                state = 7
            elif byte >= 48 and byte <= 57:
                state = 8
            else:
                return -1
        elif state == 7:
            if byte >= 48 and byte <= 57:
                state = 8
            else:
                return -1
        elif state == 8:
            if byte < 48 or byte > 57:
                return -1
            state = 8
    return state

def _number_accepting(state: Int) -> Bool:
    return state == 2 or state == 3 or state == 5 or state == 8

struct GBNFGrammar(Copyable):
    """Token-aware automaton for exact booleans and JSON numbers only.

    General GBNF, JSON objects, regexes and tokenizer integration are not
    implemented. Callers must supply the actual decoded text for every token;
    token IDs alone contain no grammar information.
    """
    var is_active: Bool
    var state: Int
    var schema_type: String
    var rules: List[GBNFRule]
    var automaton: GBNFAutomatonState
    var accepted_text: String

    def __init__(out self, schema_type: String = "json"):
        self.is_active = schema_type == "boolean" or schema_type == "number"
        self.state = 0
        self.schema_type = schema_type
        self.rules = List[GBNFRule]()
        self.automaton = GBNFAutomatonState(0, 0, False)
        self.accepted_text = ""
        if schema_type == "boolean":
            self.rules.append(GBNFRule("root", "choice", "true|false"))
        elif schema_type == "number":
            self.rules.append(GBNFRule("root", "json-number", "-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?"))

    def __copyinit__(out self, existing: Self):
        self.is_active = existing.is_active
        self.state = existing.state
        self.schema_type = existing.schema_type
        self.rules = existing.rules.copy()
        self.automaton = existing.automaton.copy()
        self.accepted_text = existing.accepted_text

    def copy(self) -> Self:
        var grammar = Self(self.schema_type)
        grammar.is_active = self.is_active
        grammar.state = self.state
        grammar.rules = self.rules.copy()
        grammar.automaton = self.automaton.copy()
        grammar.accepted_text = self.accepted_text
        return grammar^

    def _require_supported(self) raises:
        if not self.is_active:
            raise Error("general GBNF/JSON/regex grammars are not implemented; supported schemas are boolean and number")

    def is_token_valid(self, token_text: String) -> Bool:
        """Checks whether non-empty decoded token text preserves a valid prefix."""
        if not self.is_active or len(token_text.as_bytes()) == 0:
            return False
        var candidate = self.accepted_text + token_text
        if self.schema_type == "boolean":
            return String("true").startswith(candidate) or String("false").startswith(candidate)
        return _number_state(candidate) >= 0

    def advance_state(mut self, token_text: String) raises:
        """Commits one previously validated decoded token string."""
        self._require_supported()
        if not self.is_token_valid(token_text):
            raise Error("decoded token text violates the active grammar")
        self.accepted_text += token_text
        self.state += 1
        self.automaton.pos_in_pattern = len(self.accepted_text.as_bytes())
        if self.schema_type == "boolean":
            self.automaton.current_state = self.automaton.pos_in_pattern
            self.automaton.is_accepting = self.accepted_text == "true" or self.accepted_text == "false"
        else:
            self.automaton.current_state = _number_state(self.accepted_text)
            self.automaton.is_accepting = _number_accepting(self.automaton.current_state)

    def apply_token_grammar_mask(
        self,
        logits: Pointer[Scalar[f16], MutUntrackedOrigin],
        token_texts: List[String],
    ) raises:
        """Masks candidates using their decoded token text and current state."""
        self._require_supported()
        var address = Int(logits)
        if address == 0 or address == 1:
            raise Error("grammar logits pointer is null or sentinel")
        if len(token_texts) <= 0:
            raise Error("grammar candidate list must be non-empty")
        var valid_count = 0
        for token_id in range(len(token_texts)):
            if self.is_token_valid(token_texts[token_id]):
                valid_count += 1
            else:
                logits.unsafe_store(token_id, Scalar[f16](-65504.0))
        if valid_count == 0:
            raise Error("grammar rejected every candidate token")

    def apply_grammar_mask(
        self,
        logits: Pointer[Scalar[f16], MutUntrackedOrigin],
        vocab_size: Int,
    ) raises:
        """Refuses the legacy token-ID-only masking contract."""
        _ = logits
        _ = vocab_size
        raise Error("token-ID-only grammar masking is unsupported; decoded token text is required")

    def parse_rule_pattern(mut self, pattern: String) raises:
        """Accepts only the exact built-in subset; no general parser is claimed."""
        self._require_supported()
        if self.schema_type == "boolean" and pattern == "true|false":
            return
        if self.schema_type == "number" and pattern == self.rules[0].pattern:
            return
        raise Error("general GBNF rule parsing is not implemented")
