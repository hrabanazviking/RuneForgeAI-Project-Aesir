# J-024 integration replay: feeds the J-016 measured OLMoE trace
# (j016_trace_olmoe.jsonl, pre-flattened to /tmp/j024/accesses.csv as
# layer,expert,scaled_size rows) through the REAL ExpertCache module.
# Sizes are the header's per-layer expert bytes divided by 1024 (exact
# for both layer classes); budgets scale by the same factor, so every
# byte comparison the policies make is preserved -- the scaled
# construction J-018/J-020/J-024 used.
#
# Runs: fsketch at 128/256/512/1024 pairs (the integration gate: these
# counters must reproduce the J-024 tournament's fsketch counters
# EXACTLY) and segmented at the same budgets (post-starvation-fix
# counters, filed in the J-024 doc's integration addendum).
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
    with open("/tmp/j024/accesses.csv", "r") as source:
        text = source.read()
    # Mean scaled pair size is 3720; budgets are pair-class x mean, the
    # same construction as J-016/J-018/J-024.
    replay(text, 128 * 3720, String("fsketch"))
    replay(text, 256 * 3720, String("fsketch"))
    replay(text, 512 * 3720, String("fsketch"))
    replay(text, 1024 * 3720, String("fsketch"))
    replay(text, 128 * 3720, String("segmented"))
    replay(text, 256 * 3720, String("segmented"))
    replay(text, 512 * 3720, String("segmented"))
    replay(text, 1024 * 3720, String("segmented"))
