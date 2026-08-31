# tests/test_gbnf_grammar.mojo
# Verification of GBNF grammar parser & tokenizer-aware state automaton

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import Scalar, f16
from core.grammar import GBNFGrammar, GBNFRule, GBNFAutomatonState

def test_gbnf_rule_construction() raises:
    print("--- Testing GBNF Rule Construction & Automaton ---")
    var rule = GBNFRule("root", "choice", "true|false")
    if rule.name != "root" or rule.rule_type != "choice" or rule.pattern != "true|false":
        raise Error("GBNFRule construction mismatch")

    var state = GBNFAutomatonState(0, 0, False)
    if state.current_state != 0 or state.is_accepting:
        raise Error("GBNFAutomatonState initial state mismatch")

    print("GBNF rule construction: PASS")


def test_gbnf_token_validation_and_masking() raises:
    print("--- Testing bounded token-text grammar masking ---")
    var grammar = GBNFGrammar("boolean")

    var token_texts: List[String] = ["t", "f", "true", "false", "x", ""]
    var vocab_size = len(token_texts)
    var logits_ptr = alloc(Layout[Scalar[f16]](count=vocab_size)).unsafe_leak()
    for i in range(vocab_size):
        logits_ptr.unsafe_store(i, Scalar[f16](2.0))
    grammar.apply_token_grammar_mask(logits_ptr, token_texts)
    for index in range(4):
        if logits_ptr.unsafe_load(index) != Scalar[f16](2.0):
            raise Error("boolean grammar masked a valid token-text prefix")
    if logits_ptr.unsafe_load(4) != Scalar[f16](-65504.0) or logits_ptr.unsafe_load(5) != Scalar[f16](-65504.0):
        raise Error("boolean grammar retained an invalid candidate")
    logits_ptr.unsafe_free()

    grammar.advance_state("t")
    if not grammar.is_token_valid("rue") or grammar.is_token_valid("false"):
        raise Error("boolean grammar failed to preserve committed prefix state")
    grammar.advance_state("rue")
    if not grammar.automaton.is_accepting or grammar.accepted_text != "true":
        raise Error("boolean grammar failed to reach its accepting state")
    var rejected = False
    try:
        grammar.advance_state("x")
    except:
        rejected = True
    if not rejected:
        raise Error("boolean grammar accepted text after a complete literal")

    var number = GBNFGrammar("number")
    if not number.is_token_valid("-") or number.is_token_valid("01") or number.is_token_valid("."):
        raise Error("JSON-number grammar prefix admission mismatch")
    number.advance_state("-12")
    number.advance_state(".5")
    number.advance_state("e+")
    if number.automaton.is_accepting:
        raise Error("JSON-number grammar accepted an incomplete exponent")
    number.advance_state("2")
    if not number.automaton.is_accepting or number.accepted_text != "-12.5e+2":
        raise Error("JSON-number grammar failed to reach an accepting state")

    var legacy_logits = alloc(Layout[Scalar[f16]](count=2)).unsafe_leak()
    rejected = False
    try:
        grammar.apply_grammar_mask(legacy_logits, 2)
    except error:
        rejected = "decoded token text is required" in String(error)
    legacy_logits.unsafe_free()
    if not rejected:
        raise Error("legacy token-ID-only grammar mask did not fail closed")

    var general = GBNFGrammar("json")
    var general_logits = alloc(Layout[Scalar[f16]](count=1)).unsafe_leak()
    var general_tokens: List[String] = ["{"]
    rejected = False
    try:
        general.apply_token_grammar_mask(general_logits, general_tokens)
    except error:
        rejected = "not implemented" in String(error)
    general_logits.unsafe_free()
    if not rejected:
        raise Error("general JSON grammar path claimed unsupported behavior")
    print("bounded token-text grammar masking: PASS")


def main() raises:
    test_gbnf_rule_construction()
    test_gbnf_token_validation_and_masking()
