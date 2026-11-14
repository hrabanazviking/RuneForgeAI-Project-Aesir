p = "/home/volmarr/aesir-team-26/CAPABILITY_LEDGER.md"
src = open(p).read()

# 1. E-MASTER phrase 812/814 -> 825/827
a1 = "812 named executable cases are registered, 2 external-fixture case is explicitly skipped, total 814"
b1 = "825 named executable cases are registered, 2 external-fixture case is explicitly skipped, total 827"
assert src.count(a1) == 1, "phrase count %d" % src.count(a1)
src = src.replace(a1, b1)

# 2. Z13-P5-123 entry appended after the Z13-P5-121 entry
a2 = "Evidence: docs/bench/A121_MOE_BATTERY.md, hidden_files/a121_battery.log, hidden_files/a121_run_all.log.\n"
entry = (
    "- Z13-P5-123 Sliding-window attention parity (A-123). Status: verified. "
    "Sliding-window attention rows judged at window-boundary lengths specifically "
    "(the roadmap acceptance): core/sliding_window_battery_a123.mojo files windows "
    "(16, 512, 4096 -- 4096 is the Gemma2 local-layer window the engine config "
    "carries; 512 and 16 are reduced windows over the same kernel rule, stated as "
    "such) x boundary lengths (W-1, W, W+1, 2W-1, 2W, 2W+1, query_pos = L-1) x 4 "
    "backends (exactly A-109 tf_harness_backends: cpu, vulkan, hip, npu) = 72 rows. "
    "The engine rule under test is core/compute.mojo flash_attention_gqa: a position "
    "is attended iff query_pos - position < sliding_window (the kernel skips when "
    "query_pos - position >= sliding_window). CPU rows EXECUTE that banked kernel "
    "against an independent two-pass scalar reference written in-module from the "
    "definition, and every CPU row's attended count must equal min(L, W) exactly. "
    "The fixture is a deterministic LCG fixture labelled SYNTHETIC in every line, "
    "with a sharp boundary probe (boosted keys, values +/-4.0 at the first-included "
    "and first-excluded positions) so an off-by-one window moves the output far "
    "beyond the parity bound; the parity bound is A-043's filed LCG bound (max abs "
    "diff <= 0.01). Pre-registered rule: non-cpu -> NOT_GRADED "
    "(BACKEND_NO_CPU_COMPARATOR; CPU vs CPU only, no device-execution evidence, "
    "accelerator-visible is not accelerator-run); cpu -> FAITHFUL iff attended == "
    "min(L, W) and parity within bound. Filed battery (hidden_files/a123_battery.log, "
    "MOJO_EXIT=0, digest 14784864525343607696): rows FAITHFUL 18 / NOT_GRADED 54, "
    "every CPU row at max_diff_x10000 = 0 (bitwise against the reference), policy "
    "owed 72 (Q4_K_M -> TOKEN_EXACTNESS_OWED, read from the banked A-115 policy by "
    "call) / coherence 0. Seeded synthetic defects, each discriminated on this very "
    "fixture: SYN_OFF_BY_ONE DIVERGENT (WINDOW_BOUNDARY_OFF_BY_ONE, max_diff "
    "3.4849), SYN_WINDOW_IGNORED DIVERGENT (WINDOW_NOT_APPLIED, max_diff 3.7456), "
    "SYN_WINDOW_FREE FAITHFUL (a window cannot bind at or below W), SYN_MISMATCH "
    "COMPARATOR_ARTIFACT (BACKEND_MISMATCH). A-111's near-tie gate governs "
    "teacher-forcing token rows; this battery files none, so the gate is not "
    "invoked. A-116 remains the tool for divergent ENGINE rows; this battery files "
    "none. SUITE_RESULT_A123 13 E-MASTER cases (sliding.battery_*). +13 run_all "
    "cases, pin 814 -> 827. Evidence: docs/bench/A123_SLIDING_WINDOW_ATTENTION.md, "
    "hidden_files/a123_battery.log, hidden_files/a123_run_all.log.\n"
)
assert src.count(a2) == 1, "anchor2 count %d" % src.count(a2)
src = src.replace(a2, a2 + entry)

open(p, "w").write(src)
print("CAPABILITY_LEDGER.md edits applied OK")
