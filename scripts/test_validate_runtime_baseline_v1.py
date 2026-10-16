"""Independent S25 baseline validator mutation checks; no GPU needed."""
import copy
import unittest

from validate_runtime_baseline_v1 import EXPECTED_PROMPT_SHA256, validate


def fixture():
    def sample(case, phase):
        return {"case": case, "phase": phase,
                "prompt_sha256": EXPECTED_PROMPT_SHA256[case],
                "text": "Hello.", "finish_reason": "eos", "prompt_tokens": 10,
                "generated_tokens": 2, "record_count": 3,
                "wall_seconds": 2.0, "ttft_seconds": 1.0,
                "prefill_ms": 100, "decode_ms": 200}
    return {"schema_version": 1, "status": "passed", "errors": [],
            "binary_sha256": "b" * 64, "model_digest": "sha256:" + "a" * 64,
            "model": "fixture:latest", "context": 512, "max_tokens": 8,
            "samples_per_case": 2,
            "gpu": {"name": "fixture GPU", "driver_version": "1", "total_mib": 8000},
            "load_processes": [{"kind": name, "ready_seconds": 3.0,
                                "process_memory_kib": {"VmHWM": 4000},
                                "prelaunch_device_vram_mib": 100,
                                "sampled_device_vram_peak_mib": 200,
                                "sampled_process_vram_peak_mib": None}
                               for name in ("first_process", "repeat_process")],
            "samples": [sample(case, phase) for case in ("arithmetic", "long_prompt")
                        for phase in ("warmup", "sample", "sample")],
            "summary": {case: {"latency_p50_seconds": 2.0,
                               "latency_p95_seconds": 2.0,
                               "ttft_p50_seconds": 1.0,
                               "prefill_tokens_per_second_p50": 100.0,
                               "decode_tokens_per_second_p50": 10.0}
                        for case in ("arithmetic", "long_prompt")}}


class BaselineValidator(unittest.TestCase):
    def test_complete_fixture_and_missing_process_vram_are_explicit(self):
        result = validate(fixture())
        self.assertEqual(result["sample_count"], 6)
        self.assertFalse(result["process_vram_available"])

    def test_fail_closed_mutations(self):
        mutations = (
            lambda d: d.update(status="failed"),
            lambda d: d.update(binary_sha256="missing"),
            lambda d: d["load_processes"].pop(),
            lambda d: d["load_processes"][0].update(sampled_device_vram_peak_mib=50),
            lambda d: d["samples"].pop(),
            lambda d: d["samples"][0].update(ttft_seconds=3.0),
            lambda d: d["samples"][0].update(prefill_ms=0),
            lambda d: d["samples"][1].update(prompt_sha256="d" * 64),
            lambda d: [item.update(prompt_sha256="d" * 64) for item in d["samples"]
                       if item["case"] == "arithmetic"],
            lambda d: d["samples"][2].update(text=""),
            lambda d: d["summary"]["arithmetic"].update(latency_p95_seconds=3.0),
        )
        for mutation in mutations:
            data = copy.deepcopy(fixture())
            mutation(data)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                validate(data)


if __name__ == "__main__":
    unittest.main()
