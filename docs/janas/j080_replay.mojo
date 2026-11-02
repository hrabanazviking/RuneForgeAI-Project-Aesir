# J-080 real-module replay: feeds the J-080 headline schedule
# (BATCH-ALL, k=4, regime=hot -- the J-016 trace re-issued in
# layer-major verification order with rejected-suffix waste
# charged, pre-flattened by j080_flatten.py to
# layer,expert,scaled_size rows) through the REAL ExpertCache
# (fsketch, the shipping default) at both operating budgets.
#
# The counters printed here must reproduce j080_streaming.py's
# BATCH-ALL k=4 hot counters EXACTLY (the simulator is the
# J-024-gate-validated one; this replay is the cross-check that
# the batch order behaves identically in the real module).
from core.expert_cache import ExpertCache


def replay(access_text: String, budget: Int) raises:
    var cache = ExpertCache(budget, String("fsketch"))
    for line in access_text.split("\n"):
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        _ = cache.access(
            atol(String(parts[0])),
            atol(String(parts[1])),
            atol(String(parts[2])),
        )
    print("batch_all k4 hot budget", budget, cache.snapshot().describe())


def main() raises:
    var text: String
    with open("j080_accesses.csv", "r") as source:
        text = source.read()
    # Mean scaled pair size is 3720; budgets are pair-class x
    # mean, the same construction as J-016/J-018/J-024.
    replay(text, 128 * 3720)
    replay(text, 512 * 3720)
