"""Pure exact-prefix admission boundaries; no model or device evidence."""
from core.prompt_prefix import reusable_prompt_prefix


def test_prompt_prefix() raises:
    var empty = List[Int]()
    var prompt: List[Int] = [1, 2, 3, 4]
    var one: List[Int] = [1]
    var different: List[Int] = [8, 2, 3]
    var diverging: List[Int] = [1, 9, 3]
    var shorter: List[Int] = [1, 2]
    if (reusable_prompt_prefix(empty, prompt) != 0
            or reusable_prompt_prefix(prompt, empty) != 0
            or reusable_prompt_prefix(prompt, prompt) != 3
            or reusable_prompt_prefix(prompt, one) != 0
            or reusable_prompt_prefix(prompt, different) != 0
            or reusable_prompt_prefix(prompt, diverging) != 1
            or reusable_prompt_prefix(shorter, prompt) != 2):
        raise Error("Exact prompt prefix admission changed or reused final logits")


def test_prompt_prefix_hardening() raises:
    # R019 regression pins: the final prompt token always recomputes.
    var cached: List[Int] = [1, 2, 3, 4]
    var empty = List[Int]()
    if reusable_prompt_prefix(cached, empty) != 0 or reusable_prompt_prefix(empty, empty) != 0:
        raise Error("empty prompt must reuse 0 tokens")
    if reusable_prompt_prefix(cached, cached) != len(cached) - 1:
        raise Error("exact cache must reuse len(prompt)-1 tokens")
    var long_cached: List[Int] = [1, 2, 3, 4, 5, 6, 7, 8]
    var short_prompt: List[Int] = [1, 2, 3]
    var r = reusable_prompt_prefix(long_cached, short_prompt)
    if r != len(short_prompt) - 1:
        raise Error("longer cache must reuse exactly len(prompt)-1 tokens")
    var other: List[Int] = [9, 9, 9, 9]
    if reusable_prompt_prefix(other, cached) != 0:
        raise Error("no common prefix must reuse 0 tokens")
    var partial: List[Int] = [1, 2, 9, 9]
    if reusable_prompt_prefix(partial, cached) != 2:
        raise Error("partial prefix must reuse the exact common count")
    var one: List[Int] = [1]
    if reusable_prompt_prefix(cached, one) != 0:
        raise Error("length-1 prompt must reuse 0 tokens")


def main() raises:
    test_prompt_prefix()
    test_prompt_prefix_hardening()
    print("PASS exact prompt prefix admission")
