#!/usr/bin/env python3
"""J-071 inspection recount: first-hand facts about Aesir's speculative
state, the draft-check gate, and the session/sampler/KV structures the
verify pass must bind to. Assertions in code, not prose. Run from the
worktree root of yrsa/janas-j071."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
fails = []

def check(label, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + label + ((" -- " + detail) if detail else ""))
    if not cond:
        fails.append(label)

def read(p):
    return (ROOT / p).read_text()

spec = read("aesir_engine/core/speculative.mojo")
lines = spec.splitlines()
check("speculative.mojo is 142 lines", len(lines) == 142, str(len(lines)))
check("speculative is acceptance arithmetic: min(1, p_target/p_draft) stated",
      "min(1, p_target/p_draft)" in spec)
check("speculative docstring disclaims integration",
      "does not run a draft model, batch target verification" in spec)
for frag in ["draft proposal requires a real draft-model decoding loop",
             "speculative reconciliation requires per-step normalized distributions, residual sampling, and KV coordination",
             "legacy speculative token verification is unsupported"]:
    check("fail-closed raise present: " + frag[:40] + "...", frag in spec)
check("draft bound: default 4, hard limit 64",
      "num_draft_tokens: Int = 4" in spec and "> 64" in spec)
check("evaluate_acceptance returns prefix + rollback marker + kv step",
      all(s in spec for s in ["accepted_tokens", "rollback_token_id", "target_kv_step"]))

aesir = read("aesir_engine/aesir.mojo")
check("engine facade speculative_generate raises not-implemented",
      "speculative model generation and KV reconciliation are not implemented" in aesir)

hits = []
for p in ROOT.glob("aesir_engine/**/*.mojo"):
    t = p.read_text(errors="ignore")
    if "SpeculativeEngine" in t:
        hits.append(str(p.relative_to(ROOT)))
check("SpeculativeEngine referenced only by its module + tests (wired to no session)",
      sorted(hits) == ["aesir_engine/core/speculative.mojo",
                        "aesir_engine/tests/test_multi_engine.mojo",
                        "aesir_engine/tests/test_speculative.mojo"],
      ", ".join(sorted(hits)))

po = read("aesir_engine/core/placement_options.mojo")
check("require_draft_check_use raises naming G1 and J-071/J-072",
      "require_draft_check_use" in po and "gap G1" in po and "J-071/J-072" in po)
ph = read("aesir_engine/core/placement_harness.mojo")
check("harness classifies draft-check UNMEASURABLE-WITH-REASON (G1, no proxy)",
      "PASS_DRAFTS" in ph and "no draft-check pass to measure" in ph)
check("draft_placement chooser exists (J-042, Part V input surface)",
      (ROOT / "aesir_engine/core/draft_placement.mojo").exists())

sampler = read("aesir_engine/core/sampler.mojo")
greedy_at = sampler.find("if temperature <= 0.0 or top_k == 1:")
rng_at = sampler.find("rng.next_float32()", greedy_at)
check("sampler greedy branch (temperature<=0 or top_k==1) precedes any RNG use in sample_token_from_logits",
      greedy_at > 0 and rng_at > greedy_at)
check("greedy tie-break documented: equal finite maxima choose the lowest ID",
      "greedy equal finite maxima choose the lowest ID" in sampler)
check("RuneRNG state is a single UInt64 word (snapshot = one word)",
      "struct RuneRNG" in sampler and "var state: UInt64" in sampler)

well = read("aesir_engine/core/mimir_well.mojo")
kv = well[well.find("struct KVCache"):]
kv = kv[:kv.find("struct ", 10)] if kv.find("struct ", 10) > 0 else kv
check("KVCache is fixed-capacity contiguous positions [0, max_seq_len), no wrap/reorder",
      "does not wrap or reorder positions" in kv and "max_seq_len" in kv)
check("KVCache appends by explicit position (append / append_block exist)",
      "def append(" in well and "def append_block(" in well)
check("no rollback/truncate machinery exists anywhere in mimir_well.mojo",
      "rollback" not in well and "truncate" not in well)

moe = read("aesir_engine/core/moe_session.mojo")
check("MoE session carries kv_cache: KVCache and a single position counter",
      "var kv_cache: KVCache" in moe and "var position: Int" in moe)
check("MoE step() forwards at self.position then position += 1",
      "self._layer_forward(layer, x, self.position)" in moe and "self.position += 1" in moe)

sess = read("aesir_engine/core/session.mojo")
check("SessionContext carries active_tokens + session_kv_offset (host session state)",
      "var active_tokens: Int" in sess and "var session_kv_offset: Int" in sess)

inf = read("aesir_engine/core/inference.mojo")
check("host forward bounds KV reads by active_seq_len = min(start_pos + 1, max_seq_len)",
      "active_seq_len = min(start_pos + 1, kv_cache.max_seq_len)" in inf)

print("== done ==" if not fails else "== FAILURES: %d ==" % len(fails))
sys.exit(1 if fails else 0)
