"""Evidence-validator failure gates; synthetic reports, no inference claim."""
import copy
import unittest
from compare_native_benchmarks import compare


def evidence():
    digest = "sha256:" + "a" * 64
    health = {"status": "ready", "backend": "cuda", "cpu_offload": 0,
              "model": "test", "context": 512, "model_digest": digest,
              "capabilities": {"exact_prefix_reuse": False}}
    reply = {"text": "Four.", "finish_reason": "eos", "prompt_tokens": 30,
             "generated_tokens": 2, "context_used": 33, "backend": "cuda",
             "cpu_offload": 0, "model": "test", "model_digest": digest}
    return {"errors": [], "failed_samples": 0, "binary_sha256": "b" * 64,
            "model": "test", "context": 512, "samples_per_case": 2,
            "system": "test", "max_tokens": 32, "sampling": "greedy",
            "prefix_cache": False, "prefix_cache_requested": False,
            "health": health, "medians_seconds": {"test": 999},
            "samples": [{"case": "test", "prompt": "2+2?", "phase": phase,
                         "seconds": seconds, "status": 200, "reply": reply.copy()}
                        for phase, seconds in (("warmup", 100), ("warm", 2), ("warm", 4))]}


class ComparisonTests(unittest.TestCase):
    def test_recomputes_warm_medians(self):
        a, b = evidence(), evidence()
        for sample in b["samples"]:
            sample["seconds"] /= 2
        result = compare(a, b)
        self.assertEqual(result["matched_replies"], 3)
        self.assertEqual(result["cases"]["test"]["speed_ratio"], 2)

    def test_fail_closed_mutations(self):
        mutations = [
            lambda r: r["errors"].append("Timeout"),
            lambda r: r.update(failed_samples=1),
            lambda r: r.update(binary_sha256="unknown"),
            lambda r: r.update(prefix_cache=True),
            lambda r: r["health"].update(model_digest="sha256:" + "f" * 64),
            lambda r: r["health"].update(backend="ollama"),
            lambda r: r["samples"].pop(),
            lambda r: r["samples"].append(copy.deepcopy(r["samples"][-1])),
            lambda r: r["samples"][1].update(phase="warmup"),
            lambda r: r["samples"][1].update(seconds=float("nan")),
            lambda r: r["samples"][1].update(seconds=0),
            lambda r: r["samples"][1].update(status=504),
            lambda r: r["samples"][1].update(prompt="different"),
            lambda r: r["samples"][1]["reply"].update(text="Five."),
            lambda r: r["samples"][1]["reply"].update(generated_tokens=40),
            lambda r: r["samples"][1]["reply"].update(context_used=513),
            lambda r: r.update(system="different"),
            lambda r: r.update(sampling="different"),
            lambda r: r.update(suite="extended"),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                a, b = evidence(), evidence()
                mutation(b)
                with self.assertRaises(ValueError):
                    compare(a, b)


if __name__ == "__main__":
    unittest.main()
