import pathlib
p = pathlib.Path('/home/volmarr/aesir-team-27/aesir_engine/tests/run_all.mojo')
s = p.read_text()
imp_anchor = 'from tests.test_placement_planner_a100 import ('
imp = '''from tests.test_coherence_harness_a127 import (
    test_coherence_axes_product,
    test_coherence_digest_deterministic,
    test_coherence_enumeration_unique,
    test_coherence_invalid_axes_refused,
    test_coherence_metrics_exact_counts,
    test_coherence_not_graded_reasons,
    test_coherence_policy_coherence_only,
    test_coherence_sanity_degenerate_fails,
    test_coherence_sanity_echo_and_empty,
    test_coherence_sanity_garbage_fails,
    test_coherence_sanity_good_passes,
    test_coherence_sanity_offtopic_fails,
    test_coherence_sanity_repetition_fails,
    test_coherence_summary_sums,
    test_coherence_unique_and_run,
)
'''
assert s.count(imp_anchor) == 1, 'import anchor'
s = s.replace(imp_anchor, imp + imp_anchor)
case_anchor = '    run_case(ledger, "planner.standard_fixtures", test_planner_standard_fixtures)'
cases = '''    run_case(ledger, "coherence.harness_axes_product", test_coherence_axes_product)
    run_case(ledger, "coherence.harness_enumeration_unique", test_coherence_enumeration_unique)
    run_case(ledger, "coherence.harness_policy_coherence_only", test_coherence_policy_coherence_only)
    run_case(ledger, "coherence.harness_metrics_exact_counts", test_coherence_metrics_exact_counts)
    run_case(ledger, "coherence.harness_unique_and_run", test_coherence_unique_and_run)
    run_case(ledger, "coherence.harness_sanity_good_passes", test_coherence_sanity_good_passes)
    run_case(ledger, "coherence.harness_sanity_repetition_fails", test_coherence_sanity_repetition_fails)
    run_case(ledger, "coherence.harness_sanity_garbage_fails", test_coherence_sanity_garbage_fails)
    run_case(ledger, "coherence.harness_sanity_offtopic_fails", test_coherence_sanity_offtopic_fails)
    run_case(ledger, "coherence.harness_sanity_degenerate_fails", test_coherence_sanity_degenerate_fails)
    run_case(ledger, "coherence.harness_sanity_echo_and_empty", test_coherence_sanity_echo_and_empty)
    run_case(ledger, "coherence.harness_not_graded_reasons", test_coherence_not_graded_reasons)
    run_case(ledger, "coherence.harness_summary_sums", test_coherence_summary_sums)
    run_case(ledger, "coherence.harness_invalid_axes_refused", test_coherence_invalid_axes_refused)
    run_case(ledger, "coherence.harness_digest_deterministic", test_coherence_digest_deterministic)
'''
assert s.count(case_anchor) == 1, 'case anchor'
s = s.replace(case_anchor, cases + case_anchor)
pin_anchor = '''    # A-124 re-pin at banking: 840 -> 853 -- thirteen RoPE scaling
    # battery cases (rope.scaling_* in
    # tests/test_rope_scaling_battery_a124.mojo) counted on top of
    # the A-123 seat pin (union composed at the seat; the A-122
    # and A-123 cases are kept).
    ledger.finish(853)'''
pin_new = '''    # A-124 re-pin at banking: 840 -> 853 -- thirteen RoPE scaling
    # battery cases (rope.scaling_* in
    # tests/test_rope_scaling_battery_a124.mojo) counted on top of
    # the A-123 seat pin (union composed at the seat; the A-122
    # and A-123 cases are kept).
    # A-127 re-pin: 853 -> 868 -- fifteen coherence harness
    # cases (coherence.harness_* in
    # tests/test_coherence_harness_a127.mojo) counted on top
    # of the A-124 seat pin.
    ledger.finish(868)'''
assert s.count(pin_anchor) == 1, 'pin anchor'
s = s.replace(pin_anchor, pin_new)
p.write_text(s)
print('run_all edited ok')
