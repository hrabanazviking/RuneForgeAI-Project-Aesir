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
    print("--- Testing GBNF Token Candidate Validation & Logit Masking ---")
    var grammar = GBNFGrammar("boolean")
    
    if not grammar.is_token_valid("true"):
        raise Error("GBNFGrammar should validate 'true' for boolean schema")
    if not grammar.is_token_valid("false"):
        raise Error("GBNFGrammar should validate 'false' for boolean schema")

    grammar.advance_state("true")
    if grammar.state != 1:
        raise Error("GBNFGrammar advance_state failed to update state counter")

    # Logit masking check
    var vocab_size = 32
    var logits_ptr = alloc(Layout[Scalar[f16]](count=vocab_size)).unsafe_leak()
    for i in range(vocab_size):
        logits_ptr.unsafe_store(i, Scalar[f16](2.0))

    grammar.apply_grammar_mask(logits_ptr, vocab_size)

    var masked_count = 0
    for i in range(vocab_size):
        if logits_ptr.unsafe_load(i) == Scalar[f16](-65504.0):
            masked_count += 1

    if masked_count == 0:
        raise Error("GBNFGrammar apply_grammar_mask failed to mask non-conforming logits")

    logits_ptr.unsafe_free()
    print("GBNF token candidate validation & logit masking: PASS")


def main() raises:
    test_gbnf_rule_construction()
    test_gbnf_token_validation_and_masking()
