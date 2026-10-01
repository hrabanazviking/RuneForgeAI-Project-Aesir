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


def main() raises:
    test_prompt_prefix()
    print("PASS exact prompt prefix admission")
