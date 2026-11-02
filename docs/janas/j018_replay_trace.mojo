# J-018 trace replay: feeds the J-016 measured OLMoE trace
# (j016_trace_olmoe.jsonl, pre-flattened to /tmp/j018/accesses.csv as
# layer,expert,scaled_size rows) through the real ExpertCache module.
# Sizes are the header's per-layer expert bytes divided by 1024 (exact
# for both layer classes); budgets scale by the same factor, so every
# byte comparison the policies make is preserved.
from core.expert_cache import ExpertCache


def replay(access_text: String, budget: Int, policy: String) raises:
    var cache = ExpertCache(budget, policy)
    for line in access_text.split("\n"):
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        _ = cache.access(
            atol(String(parts[0])),
            atol(String(parts[1])),
            atol(String(parts[2])),
        )
    var stats = cache.snapshot()
    print(policy, "budget", budget, stats.describe())


def main() raises:
    var text: String
    with open("/tmp/j018/accesses.csv", "r") as source:
        text = source.read()
    # Mean scaled pair size is 3720; budgets are pair-class x mean, the
    # same construction as J-016's approx_bytes_at_mean_expert column.
    replay(text, 128 * 3720, String("lru"))
    replay(text, 128 * 3720, String("lfu"))
    replay(text, 128 * 3720, String("segmented"))
    replay(text, 512 * 3720, String("lru"))
    replay(text, 512 * 3720, String("lfu"))
    replay(text, 512 * 3720, String("segmented"))
