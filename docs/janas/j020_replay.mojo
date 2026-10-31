# J-020 replay: feeds the J-016 measured OLMoE trace through the REAL
# J-018 ExpertCache module (aesir_engine/core/expert_cache.mojo) and dumps
# per-token cold/warm behaviour + the exact miss streams the J-020 disk
# bench replays on purplelongship.
#
# Runs (budget = 512 pairs x mean scaled size 3720, the J-016/J-018
# construction; sizes are header expert bytes / 1024, exact):
#   cold       segmented, fresh cache, full 577-token session
#   warm       segmented, SAME cache instance, session replayed at once
#   prose_cold segmented, fresh cache, prose prompt only (71 tokens)
#   lru_cold   lru baseline, fresh cache, session (validation vs J-016)
#
# Output lines:
#   TOK  <run> <token_idx> hits misses bypasses streamed_scaled
#        admissions promotions evictions entries_now resident_scaled
#   MISS <run> <token_idx> <layer> <expert>
#   TOTAL <run> <ExpertCacheStats.describe()>
from core.expert_cache import ExpertCache, ACCESS_HIT, ACCESS_MISS_BYPASSED


def load_accesses(
    path: String,
) raises -> Tuple[List[Int], List[Int], List[Int], List[Int]]:
    var toks = List[Int]()
    var lays = List[Int]()
    var exps = List[Int]()
    var szs = List[Int]()
    var text: String
    with open(path, "r") as source:
        text = source.read()
    for line in text.split("\n"):
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        toks.append(atol(String(parts[0])))
        lays.append(atol(String(parts[1])))
        exps.append(atol(String(parts[2])))
        szs.append(atol(String(parts[3])))
    return (toks^, lays^, exps^, szs^)


def run_pass(
    mut cache: ExpertCache,
    label: String,
    toks: List[Int],
    lays: List[Int],
    exps: List[Int],
    szs: List[Int],
) raises:
    var i = 0
    var n = len(toks)
    while i < n:
        var ti = toks[i]
        var before = cache.snapshot()
        var hits = 0
        var misses = 0
        var bypasses = 0
        var streamed: Int = 0
        while i < n and toks[i] == ti:
            var code = cache.access(lays[i], exps[i], szs[i])
            if code == ACCESS_HIT:
                hits += 1
            else:
                misses += 1
                streamed += szs[i]
                if code == ACCESS_MISS_BYPASSED:
                    bypasses += 1
                print("MISS", label, ti, lays[i], exps[i])
            i += 1
        var after = cache.snapshot()
        print(
            "TOK",
            label,
            ti,
            hits,
            misses,
            bypasses,
            streamed,
            after.admissions - before.admissions,
            after.promotions - before.promotions,
            after.evictions - before.evictions,
            after.entries_now,
            after.bytes_resident_now,
        )
    var total = cache.snapshot()
    print("TOTAL", label, total.describe())


def main() raises:
    var budget = 512 * 3720
    var loaded = load_accesses("/tmp/j020/session_accesses.csv")
    var toks = loaded[0].copy()
    var lays = loaded[1].copy()
    var exps = loaded[2].copy()
    var szs = loaded[3].copy()

    var seg = ExpertCache(budget, String("segmented"))
    run_pass(seg, String("cold"), toks, lays, exps, szs)
    run_pass(seg, String("warm"), toks, lays, exps, szs)

    var ploaded = load_accesses("/tmp/j020/prose_accesses.csv")
    var ptoks = ploaded[0].copy()
    var plays = ploaded[1].copy()
    var pexps = ploaded[2].copy()
    var pszs = ploaded[3].copy()
    var pseg = ExpertCache(budget, String("segmented"))
    run_pass(pseg, String("prose_cold"), ptoks, plays, pexps, pszs)

    var lru = ExpertCache(budget, String("lru"))
    run_pass(lru, String("lru_cold"), toks, lays, exps, szs)
