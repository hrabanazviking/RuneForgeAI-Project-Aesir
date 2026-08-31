# tests/test_speculative.mojo
# Verification of validated speculative acceptance arithmetic.

from core.speculative import (
    SpeculativeEngine,
    DraftProposal,
    SpeculativeVerificationResult,
)

def test_speculative_proposal_and_verification() raises:
    print("--- Testing speculative probability-ratio acceptance ---")
    var engine = SpeculativeEngine(4)
    var proposal = DraftProposal()
    proposal.draft_tokens = [10, 11, 12]
    proposal.draft_probs = [0.5, 0.4, 0.2]
    var target: List[Float64] = [0.25, 0.4, 0.1]
    var draws: List[Float64] = [0.49, 0.99, 0.6]
    var result = engine.evaluate_acceptance(proposal, target, draws, 7)
    if result.accepted_count != 2 or len(result.accepted_tokens) != 2:
        raise Error("speculative acceptance ratio produced the wrong prefix")
    if result.accepted_tokens[0] != 10 or result.accepted_tokens[1] != 11:
        raise Error("speculative acceptance result changed token order")
    if result.rollback_token_id != 12 or result.target_kv_step != 9:
        raise Error("speculative rejection/KV marker mismatch")
    print("speculative probability-ratio acceptance: PASS")


def test_speculative_rollback_on_rejection() raises:
    print("--- Testing speculative validation and unsupported integrations ---")
    var engine = SpeculativeEngine(4)
    var proposal = DraftProposal()
    proposal.draft_tokens = [1]
    proposal.draft_probs = [0.0]
    var target: List[Float64] = [0.5]
    var draws: List[Float64] = [0.1]
    var rejected = False
    try:
        _ = engine.evaluate_acceptance(proposal, target, draws)
    except error:
        rejected = "draft token probabilities" in String(error)
    if not rejected:
        raise Error("speculative acceptance allowed a zero draft probability")

    proposal.draft_probs = [0.5]
    var missing_draws = List[Float64]()
    rejected = False
    try:
        _ = engine.evaluate_acceptance(proposal, target, missing_draws)
    except error:
        rejected = "lengths must match" in String(error)
    if not rejected:
        raise Error("speculative acceptance allowed mismatched observations")
    print("speculative validation and unsupported integrations: PASS")


def main() raises:
    test_speculative_proposal_and_verification()
    test_speculative_rollback_on_rejection()
