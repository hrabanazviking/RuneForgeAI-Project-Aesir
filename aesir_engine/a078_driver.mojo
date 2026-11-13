from tests.test_gpu_fuzz_a078 import (
    test_gpu_fuzz_seed_replay,
    test_gpu_fuzz_case_coverage,
    test_gpu_fuzz_verdict_classifier,
    test_gpu_fuzz_synthetic_row_battery,
    test_gpu_fuzz_sampling_greedy,
    test_gpu_fuzz_sampling_temperature,
    test_gpu_fuzz_real_model_random_prompts,
)


def main() raises:
    test_gpu_fuzz_seed_replay()
    test_gpu_fuzz_case_coverage()
    test_gpu_fuzz_verdict_classifier()
    test_gpu_fuzz_synthetic_row_battery()
    test_gpu_fuzz_sampling_greedy()
    test_gpu_fuzz_sampling_temperature()
    test_gpu_fuzz_real_model_random_prompts()
    print("A078_DRIVER_ALL_PASS")
