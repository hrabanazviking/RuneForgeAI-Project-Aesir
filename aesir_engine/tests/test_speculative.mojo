# tests/test_speculative.mojo
# Verification of SpeculativeEngine draft proposal & rejection sampling verification

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import Scalar, f16
from core.speculative import (
    SpeculativeEngine,
    DraftProposal,
    SpeculativeVerificationResult,
)

def test_speculative_proposal_and_verification() raises:
    print("--- Testing Speculative Engine Proposal & Rejection Verification ---")
    var engine = SpeculativeEngine(4)
    var vocab_size = 32

    # Allocate target logits
    var logits_ptr = alloc(Layout[Scalar[f16]](count=vocab_size)).unsafe_leak()
    for i in range(vocab_size):
        logits_ptr.unsafe_store(i, Scalar[f16](1.5))

    var proposal = engine.propose_draft_tokens(logits_ptr, vocab_size, 4)
    if len(proposal.draft_tokens) != 4:
        raise Error("SpeculativeEngine propose_draft_tokens failed to generate 4 draft tokens")

    var result = engine.verify_and_reconcile(proposal, logits_ptr, vocab_size)
    if result.accepted_count != 4:
        raise Error("SpeculativeEngine verify_and_reconcile failed to accept all valid tokens")

    if result.target_kv_step != 4:
        raise Error("SpeculativeEngine verify_and_reconcile target_kv_step mismatch")

    logits_ptr.unsafe_free()
    print("Speculative proposal & rejection verification: PASS")


def test_speculative_rollback_on_rejection() raises:
    print("--- Testing Speculative Engine Rejection & Rollback ---")
    var engine = SpeculativeEngine(4)
    var vocab_size = 32

    var logits_ptr = alloc(Layout[Scalar[f16]](count=vocab_size)).unsafe_leak()
    for i in range(vocab_size):
        logits_ptr.unsafe_store(i, Scalar[f16](1.5))

    # Mask token 2 to simulate rejection
    logits_ptr.unsafe_store(2, Scalar[f16](-65504.0))

    var proposal = DraftProposal()
    proposal.draft_tokens.append(0)
    proposal.draft_tokens.append(1)
    proposal.draft_tokens.append(2) # Masked token
    proposal.draft_tokens.append(3)

    var result = engine.verify_and_reconcile(proposal, logits_ptr, vocab_size)
    if result.accepted_count != 2:
        raise Error("SpeculativeEngine verify_and_reconcile should accept exactly 2 tokens before rejection")

    if result.rollback_token_id != 2:
        raise Error("SpeculativeEngine verify_and_reconcile failed to record rejected rollback token ID")

    logits_ptr.unsafe_free()
    print("Speculative rejection & rollback: PASS")


def main() raises:
    test_speculative_proposal_and_verification()
    test_speculative_rollback_on_rejection()
