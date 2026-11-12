# tests/test_parity_battery_a045.mojo
# A-045: CPU parity battery -- the grading arithmetic (core/
# parity_battery.mojo) and the KVCache logit-row sink defaults.
# The MEASURED per-format battery over real fixtures is the standalone
# driver (tests/bench_parity_battery_a045.mojo), filed in the A-045
# ledger; these cases prove the machinery that battery relies on,
# with synthetic rows labelled as synthetic.

from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_code,
    parity_verdict_name,
)
from core.mimir_well import MimirWell, KVCache


def _row() -> List[Float32]:
    var r = List[Float32]()
    r.append(Float32(1.0)); r.append(Float32(3.5)); r.append(Float32(-2.0))
    r.append(Float32(3.5)); r.append(Float32(0.25))
    return r^


def test_parity_top_token_ties() raises:
    var r = _row()
    if parity_top_token(r) != 1:
        raise Error("A045: top token must be the lowest-id maximum")
    var empty = List[Float32]()
    if parity_top_token(empty) != -1:
        raise Error("A045: empty row top token must be -1")
    print("A045 top token (lowest-id tie): PASS")


def test_parity_rank_arithmetic() raises:
    var r = _row()
    # Tied maxima share rank 1; 1.0 has two greater logits -> rank 3;
    # -2.0 has four greater -> rank 5.
    if parity_logit_rank(r, 1) != 1 or parity_logit_rank(r, 3) != 1:
        raise Error("A045: tied maxima must both be rank 1")
    if parity_logit_rank(r, 0) != 3:
        raise Error("A045: rank of 1.0 must be 3")
    if parity_logit_rank(r, 2) != 5:
        raise Error("A045: rank of -2.0 must be 5")
    if parity_logit_rank(r, 5) != -1 or parity_logit_rank(r, -1) != -1:
        raise Error("A045: out-of-range rank must be -1")
    print("A045 rank arithmetic (ties, range): PASS")


def test_parity_gap_arithmetic() raises:
    var r = _row()
    if parity_logit_gap(r, 1) != Float32(0.0):
        raise Error("A045: gap of a top token must be 0")
    if parity_logit_gap(r, 0) != Float32(2.5):
        raise Error("A045: gap of 1.0 vs top 3.5 must be 2.5")
    if parity_logit_gap(r, 2) != Float32(5.5):
        raise Error("A045: gap of -2.0 vs top 3.5 must be 5.5")
    if parity_logit_gap(r, 9) != Float32(-1.0):
        raise Error("A045: out-of-range gap must be the -1 sentinel")
    print("A045 logit-gap arithmetic: PASS")


def test_parity_verdict_bands() raises:
    if parity_verdict_code(1, Float32(0.0)) != 0:
        raise Error("A045: rank 1 must be faithful")
    if parity_verdict_code(1, Float32(4.0)) != 0:
        raise Error("A045: rank 1 is faithful regardless of gap")
    if parity_verdict_code(2, Float32(0.5)) != 1:
        raise Error("A045: rank 2 with sub-logit gap must be near-tie")
    if parity_verdict_code(2, Float32(0.999)) != 1:
        raise Error("A045: rank 2 gap 0.999 must be near-tie")
    if parity_verdict_code(2, Float32(1.0)) != 2:
        raise Error("A045: rank 2 gap 1.0 is NOT sub-logit -> divergence")
    if parity_verdict_code(3, Float32(0.1)) != 2:
        raise Error("A045: rank 3 must be divergence even with small gap")
    if parity_verdict_code(-1, Float32(0.0)) != -1:
        raise Error("A045: invalid rank must be invalid")
    if parity_verdict_name(0) != String("faithful") or parity_verdict_name(1) != String("near-tie") or parity_verdict_name(2) != String("divergence") or parity_verdict_name(-1) != String("invalid"):
        raise Error("A045: verdict names wrong")
    print("A045 verdict bands (faithful / near-tie / divergence): PASS")


def test_parity_logit_sink_defaults() raises:
    # The A-045 sink is off by default on a fresh cache, starts empty,
    # and survives a copy (the battery toggles it per run).
    var well = MimirWell(4 * 1024 * 1024)
    var cache = KVCache(16, 64, well, 2)
    if cache.capture_logit_row:
        raise Error("A045: capture_logit_row must default to False")
    if len(cache.last_logit_row) != 0:
        raise Error("A045: last_logit_row must start empty")
    cache.capture_logit_row = True
    cache.last_logit_row.append(Float32(7.0))
    var copied = cache.copy()
    if not copied.capture_logit_row or len(copied.last_logit_row) != 1:
        raise Error("A045: KVCache copy must carry the sink state")
    print("A045 logit-row sink defaults + copy: PASS")
