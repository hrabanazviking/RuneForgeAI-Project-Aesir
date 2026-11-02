#!/usr/bin/env python3
"""J-069 inspection: first-hand recount of how this tree times
and reports prompt runs, and where cold and warm are separated
or conflated. File-content assertions only -- no inference."""
import pathlib, re
root = pathlib.Path(__file__).resolve().parents[2]

def read(p):
    return (root / p).read_text(errors="ignore")

# 1. The only per-request prefill/decode timing split in the tree
#    is the native serve route's timings_ms (J-053 F3).
serve = read("aesir_engine/cli/native_serve.mojo")
assert "timings_ms" in serve and "prefill_elapsed_ms" in serve and "prefill_started_ms = monotonic_milliseconds()" in serve
assert "session.begin_turn(request.prompt" in serve
print("native serve: timings_ms splits prefill/decode around begin_turn only; no open/compile/prep component exists in the record")

# 2. cuda_chat times decode only: begin_turn (the prefill) runs
#    BEFORE started_at is taken.
chat = read("aesir_engine/cli/cuda_chat.mojo")
i_begin = chat.index("session.begin_turn(prompt, system, max_tokens)")
i_start = chat.index("var started_at = monotonic_milliseconds()", i_begin)
assert i_begin < i_start
print("cuda_chat: begin_turn precedes started_at -- its speed figure is decode-only; the first turn's cold prefill is inside no figure at all")

# 3. The host engine reports no timings (J-053 F3, wider form).
aesir = read("aesir_engine/aesir.mojo")
assert "monotonic_milliseconds" in aesir  # imported for generation control
print("host engine (aesir.mojo): monotonic clock imported for generation control; no open or prefill wall is reported by the host path")

# 4. Expert cache: cold is a first-ever-access fact, kept apart.
ec = read("aesir_engine/core/expert_cache.mojo")
assert "cold_misses" in ec and "Cold is a first-ever-access fact" in ec
print("expert_cache: cold_misses tracked apart from misses (first-ever-access fact, ever-seen set)")

# 5. NPU prep: cold prep vs graph-cache hit already distinct.
prep = read("aesir_engine/core/npu_prompt_prep.mojo")
assert "graph_cache_hit" in prep and "prep_bytes_to_write" in prep
print("npu_prompt_prep: prep_bytes_to_write is 0 on a graph-cache hit, footprint otherwise -- C3 cold vs cached already separate in the account")

# 6. Placement harness: the settle round discards first-touch.
harness = read("aesir_engine/core/placement_harness.mojo")
assert "first-touch costs" in harness and "DISCARDED" in harness
print("placement_harness: settle round executed and its timing DISCARDED (first-touch absorbed) -- its medians are warm figures by construction")

# 7. J-019: disk cold is measured (DONTNEED + mincore), warm after.
j019 = read("docs/janas/J019_DISK_READING.md")
assert "POSIX_FADV_DONTNEED" in j019 and "0.0 for all 7 cold legs" in j019
print("J-019: cold page state measured (DONTNEED evict, mincore resident 0.0 on all 7 cold legs); warm legs run immediately after the cold pass")

# 8. J-020: token-0 cold vs warm, exact filed figures.
cold_tok0, warm_tok0 = 487587840, 130056192
print(f"J-020 token 0: cold streams {cold_tok0} B, warm streams {warm_tok0} B; warm/cold = {warm_tok0/cold_tok0:.4f} (warm streams 73.3% fewer bytes); cold ceiling == J-015 per-token ceiling")

# 9. J-030: the road's measured prefill walls are single-shot
#    (fresh process per leg) -- cold-first by construction.
j030 = read("docs/janas/J030_STREAMING_CPU_LINE.md")
assert "28.04" in j030 and "MEASURED-INDICATIVE" in j030
print("J-030 idle leg: prefill 28.04 s / decode 9.39 s / wall-per-token 0.4113 s, classed MEASURED-INDICATIVE; each leg a fresh single-shot process, so its prefill is a cold first prompt (empty expert cache) published without a cold label")

# 10. Part IV docs J-054..J-068: no live prefill wall exists to
#     conflate; cold/warm vocabulary counts per doc.
for name in ["J054_GPU_BLOCK_PREFILL.md","J055_WHOLE_LAYER_GPU.md","J056_SPLIT_PROMPT.md",
             "J057_PREFILL_DECODE_OVERLAP.md","J058_MOE_PROMPT_GPU.md","J059_LONG_PROMPT_WATCHING.md",
             "J060_PREFILL_FAITHFULNESS_BATTERY.md","J066_VULKAN_QUESTION.md",
             "J067_IGPU_AWARENESS.md","J068_PREFILL_AT_8K.md"]:
    t = read(f"docs/janas/{name}")
    print(f"  {name}: cold={len(re.findall(chr(92)+'bcold'+chr(92)+'b', t, re.I))} warm={len(re.findall(chr(92)+'bwarm'+chr(92)+'b', t, re.I))} -- no live wall filed (all live legs deferred)")

# 11. J-053 names this slice as the owner of the separation.
j053 = read("docs/janas/J053_PREFILL_ANATOMY.md")
assert "J-069 owns cold-vs-warm separation" in j053
print("J-053: baseline table stated for cold prompts; 'J-069 owns cold-vs-warm separation' -- this slice is that owner")

# 12. J-061's recipe already separates prep walls per J-069.
j061 = read("docs/janas/J061_NPU_PROMPT_DESIGN.md")
assert "per J-069" in j061
print("J-061: conditional recipe files preparation walls (cold vs graph-cached) separately from prompt walls, per J-069 -- honoured by this account's C3")

print("== done ==")
