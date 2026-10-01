"""Exact-token prefix matching; never reuse a prediction or a mismatched slot."""


def reusable_prompt_prefix(cached: List[Int], prompt: List[Int]) -> Int:
    # The final prompt token always recomputes activations/logits. This also
    # excludes empty prompts without permitting a negative loop extent.
    var limit = min(len(cached), max(0, len(prompt) - 1))
    var count = 0
    while count < limit and cached[count] == prompt[count]:
        count += 1
    return count
