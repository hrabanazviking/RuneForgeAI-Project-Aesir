# Explicit mathematical basis only; never a hardware precision/layout claim.
from smidr.semantic_plan import SemanticPlan
from smidr.storage_estimate import checked_sum
from smidr.semantic_plan import checked_product


@fieldwise_init
struct RotaryLoweringPolicy(Copyable, Movable):
    var pairing: String
    var provenance: String
    var max_recipes: Int
    var work: Int


def validate_rotary_policy(plan: SemanticPlan, policy: RotaryLoweringPolicy) raises -> Int:
    if (policy.pairing != "adjacent" and policy.pairing != "split_half") or policy.provenance.byte_length() == 0 or policy.max_recipes <= 0 or policy.work <= 0:
        raise Error("RotaryRecipe: explicit basis/provenance and positive bounds required")
    if len(plan.operations) > policy.work:
        raise Error("RotaryRecipe: source operation scan exceeds work policy")
    var count = 0
    for i in range(len(plan.operations)):
        if plan.operations[i].kind == "rope_query" or plan.operations[i].kind == "rope_key":
            count = checked_sum(count, 1)
            if count > policy.max_recipes:
                raise Error("RotaryRecipe: recipe count exceeds policy")
    var unit = checked_sum(128, policy.pairing.byte_length())
    unit = checked_sum(unit, policy.provenance.byte_length())
    var work = checked_sum(len(plan.operations), checked_product(count, unit) if count > 0 else 0)
    if work > policy.work:
        raise Error("RotaryRecipe: descriptor work exceeds policy")
    return work
