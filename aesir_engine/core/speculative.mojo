# core/speculative.mojo
# Validated speculative-token acceptance arithmetic and explicit integration gaps.

from std.math import isinf, isnan
from std.memory import Pointer
from core.mimir_well import Scalar, f16

struct DraftProposal(Copyable):
    """Caller-supplied proposed tokens and their normalized draft probabilities."""
    var draft_tokens: List[Int]
    var draft_probs: List[Float64]

    def __init__(out self):
        self.draft_tokens = List[Int]()
        self.draft_probs = List[Float64]()

    def __copyinit__(out self, existing: Self):
        self.draft_tokens = existing.draft_tokens.copy()
        self.draft_probs = existing.draft_probs.copy()

struct SpeculativeVerificationResult(Copyable):
    """Acceptance-prefix result; it does not mutate or claim ownership of KV state."""
    var accepted_tokens: List[Int]
    var accepted_count: Int
    var rollback_token_id: Int
    var target_kv_step: Int

    def __init__(out self):
        self.accepted_tokens = List[Int]()
        self.accepted_count = 0
        self.rollback_token_id = -1
        self.target_kv_step = 0

    def __copyinit__(out self, existing: Self):
        self.accepted_tokens = existing.accepted_tokens.copy()
        self.accepted_count = existing.accepted_count
        self.rollback_token_id = existing.rollback_token_id
        self.target_kv_step = existing.target_kv_step

struct SpeculativeEngine(Copyable):
    """Probability-ratio acceptance primitive for caller-observed token probabilities.

    This type does not run a draft model, batch target verification, sample the
    residual correction distribution, or mutate KV caches. Those integration
    paths fail explicitly rather than substituting logits or fabricated values.
    """
    var num_draft_tokens: Int

    def __init__(out self, num_draft_tokens: Int = 4):
        self.num_draft_tokens = num_draft_tokens

    def __copyinit__(out self, existing: Self):
        self.num_draft_tokens = existing.num_draft_tokens

    def copy(self) -> Self:
        return Self(self.num_draft_tokens)

    def evaluate_acceptance(
        self,
        proposal: DraftProposal,
        target_token_probs: List[Float64],
        uniform_draws: List[Float64],
        starting_kv_step: Int = 0,
    ) raises -> SpeculativeVerificationResult:
        """Evaluates the standard min(1, p_target/p_draft) acceptance prefix.

        Inputs are probabilities for each proposed token at its corresponding
        autoregressive step. Uniform draws are explicit so callers own RNG state
        and tests can reproduce the decision exactly.
        """
        var count = len(proposal.draft_tokens)
        if self.num_draft_tokens <= 0 or self.num_draft_tokens > 64:
            raise Error("speculative draft-token limit must be between 1 and 64")
        if count <= 0 or count > self.num_draft_tokens:
            raise Error("speculative proposal count is outside the configured limit")
        if len(proposal.draft_probs) != count or len(target_token_probs) != count or len(uniform_draws) != count:
            raise Error("speculative probability and draw lengths must match proposed tokens")
        if starting_kv_step < 0:
            raise Error("speculative starting KV step must be non-negative")

        var result = SpeculativeVerificationResult()
        result.target_kv_step = starting_kv_step
        for index in range(count):
            var token_id = proposal.draft_tokens[index]
            var draft_probability = proposal.draft_probs[index]
            var target_probability = target_token_probs[index]
            var draw = uniform_draws[index]
            if token_id < 0:
                raise Error("speculative token IDs must be non-negative")
            if isnan(draft_probability) or isinf(draft_probability) or draft_probability <= 0.0 or draft_probability > 1.0:
                raise Error("draft token probabilities must be finite in (0, 1]")
            if isnan(target_probability) or isinf(target_probability) or target_probability < 0.0 or target_probability > 1.0:
                raise Error("target token probabilities must be finite in [0, 1]")
            if isnan(draw) or isinf(draw) or draw < 0.0 or draw >= 1.0:
                raise Error("speculative uniform draws must be finite in [0, 1)")
            var acceptance = target_probability / draft_probability
            if acceptance > 1.0:
                acceptance = 1.0
            if draw <= acceptance:
                result.accepted_tokens.append(token_id)
                result.accepted_count += 1
                result.target_kv_step += 1
            else:
                result.rollback_token_id = token_id
                break
        return result^

    def propose_draft_tokens(
        self,
        draft_logits: Pointer[Scalar[f16], MutUntrackedOrigin],
        vocab_size: Int,
        count: Int,
    ) raises -> DraftProposal:
        """Refuses to invent an autoregressive proposal from one logit vector."""
        _ = draft_logits
        _ = vocab_size
        _ = count
        raise Error("draft proposal requires a real draft-model decoding loop")

    def verify_and_reconcile(
        self,
        proposal: DraftProposal,
        target_logits: Pointer[Scalar[f16], MutUntrackedOrigin],
        target_vocab_size: Int,
    ) raises -> SpeculativeVerificationResult:
        """Refuses logits-as-probabilities and unimplemented residual/KV handling."""
        _ = proposal
        _ = target_logits
        _ = target_vocab_size
        raise Error("speculative reconciliation requires per-step normalized distributions, residual sampling, and KV coordination")

    def verify_tokens(
        self,
        draft_tokens: Pointer[Int, MutUntrackedOrigin],
        target_logits: Pointer[Scalar[f16], MutUntrackedOrigin],
        count: Int,
    ) raises -> Int:
        """Refuses the legacy pointer contract, which lacks probability bounds."""
        _ = draft_tokens
        _ = target_logits
        _ = count
        raise Error("legacy speculative token verification is unsupported")
