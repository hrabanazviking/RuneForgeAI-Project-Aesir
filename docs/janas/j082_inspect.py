#!/usr/bin/env python3
"""J-082 inspection recount: every load-bearing claim in
docs/janas/J082_SAMPLING_CORRECTNESS.md as an assertion over
the tree and the filed records. Exit 0 iff all checks pass."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
checks = []


def check(name, ok):
    checks.append((name, bool(ok)))
    print(f"{'PASS' if ok else 'FAIL'}: {name}")


def read(rel):
    return (ROOT / rel).read_text()


module = read("aesir_engine/core/speculative_sampling.mojo")
suite = read("aesir_engine/tests/test_speculative_sampling.mojo")
doc = read("docs/janas/J082_SAMPLING_CORRECTNESS.md")
mirror_out = read("docs/janas/j082_mirror_output.txt")
mirror_src = read("docs/janas/j082_mirror.py")
sampler = read("aesir_engine/core/sampler.mojo")
legacy = read("aesir_engine/core/speculative.mojo")
verify = read("aesir_engine/core/speculative_verify.mojo")
options = read("aesir_engine/core/placement_options.mojo")
facade = read("aesir_engine/aesir.mojo")

check("new module exists and names J-082", "J-082" in module)
check("verdict rule is in the module header before the code",
      module.index("THE VERDICT RULE") < module.index("def shape_distribution"))
check("k band constants are the J-071 band 1..15",
      "SAMPLED_K_MIN = 1" in module and "SAMPLED_K_MAX = 15" in module)
check("zero-bin sentinel is the named constant -1.0",
      "CHI_SQUARE_ZERO_BIN = -1.0" in module)
check("alpha=0.001 critical table in the module (df 2/3/7)",
      "13.816" in module and "16.266" in module and "24.322" in module)
check("correction consumes SHAPED distributions (host contract)",
      "the correction must consume the" in module
      and "SHAPED" in module)
check("residual and bonus rules stated in the module header",
      "norm(max(0, p - q))" in module and "BONUS token" in module)
check("no speed/wall/tok-per-s claim function in the module",
      "tok_per_s" not in module and "wall_seconds" not in module)

check("shaping binds the engine sampler's RuneRNG by import",
      "from core.sampler import RuneRNG" in module)
check("sampler's shaping stack exists as recorded (temp/top-k/top-p)",
      "def apply_temperature" in sampler
      and "def apply_top_k" in sampler
      and "def apply_top_p" in sampler
      and "struct RuneRNG" in sampler)
check("legacy engine's min(1, p/q) arithmetic stands as recorded",
      "var acceptance = target_probability / draft_probability" in legacy
      and "acceptance = 1.0" in legacy)
check("legacy residual/KV refusal stands (layer is additive)",
      "residual sampling, and KV coordination" in legacy)
check("module's acceptance is the same arithmetic over shaped p/q",
      "var a = p_x / q_x" in module)

check("use gate still fails closed (J-036, unedited by this slice)",
      "raise Error(" in options and "draft-check passes do not exist" in options)
check("facade speculative_generate still raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented"
      in facade)
check("J-071 greedy zero-draw invariant stands unedited",
      "consumes zero RNG draws" in verify)

check("suite has 17 groups", suite.count("def test_") == 17)
check("suite pins the registered seeds and N",
      "20261101" in suite and "424242" in suite and "60000" in suite)
check("suite requires the naive control to FAIL",
      "naive control must FAIL" in suite)
check("doc registers the verdict rule (N, seed, alpha)",
      "60,000" in doc and "20261101" in doc and "α = 0.001" in doc)
check("mirror is an independent RuneRNG replica, filed with output",
      "class RuneRNG" in mirror_src and "corr=" in mirror_out)
check("doc's filed statistics match the mirror's statistics",
      all(s in mirror_out for s in (
          "corr=8.518318", "corr=5.676114", "corr=0.641060",
          "corr=1.674679", "corr=5.596804", "chi2=6.747471",
          "rounds=34835"))
      and all(s in doc for s in (
          "8.518", "5.676", "0.641", "1.675", "5.597", "6.747",
          "34,835")))

failed = [n for n, ok in checks if not ok]
print(f"== {len(checks) - len(failed)}/{len(checks)} checks PASS ==")
sys.exit(1 if failed else 0)
