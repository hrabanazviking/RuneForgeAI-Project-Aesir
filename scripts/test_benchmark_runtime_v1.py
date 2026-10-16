"""Offline synthetic contracts for S25 raw benchmark measurements."""
import copy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

from benchmark_runtime_v1 import catalog_digest, main, percentile, streamed_request, validate_stream


DIGEST = "sha256:" + "a" * 64


def records():
    return [(1.0, {"text": "Four", "done": False}),
            (1.1, {"text": ".", "done": False}),
            (1.2, {"text": "", "done": True, "model": "gemma4-e2b:latest",
                   "model_digest": DIGEST, "backend": "cuda", "cpu_offload": 0,
                   "finish_reason": "eos", "prompt_tokens": 20,
                   "generated_tokens": 2, "context_used": 23,
                   "timings_ms": {"prefill": 40, "decode": 25}})]


class BenchmarkContracts(unittest.TestCase):
    def test_failed_artifact_is_exclusive_and_retains_context(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "failed.json"
            args = ["benchmark_runtime_v1.py", "--binary", str(Path(temp) / "missing"),
                    "--model", "gemma4-e2b:latest", "--store", temp,
                    "--samples", "2", "--output", str(output)]
            with patch("sys.argv", args):
                self.assertEqual(main(), 1)
            artifact = json.loads(output.read_text())
            self.assertEqual(artifact["status"], "failed")
            self.assertEqual(artifact["model"], "gemma4-e2b:latest")
            self.assertEqual(artifact["errors"], ["FileNotFoundError"])
            with patch("sys.argv", args), self.assertRaises(FileExistsError):
                main()

    def test_failure_preserves_completed_raw_samples(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "partial.json"
            args = ["benchmark_runtime_v1.py", "--binary", "unused", "--model", "fixture:latest",
                    "--store", temp, "--samples", "2", "--output", str(output)]

            def interrupted(_args, report):
                report["samples"].append({"case": "arithmetic", "wall_seconds": 1.25})
                raise RuntimeError("synthetic failure")

            with patch("sys.argv", args), patch("benchmark_runtime_v1.run", side_effect=interrupted):
                self.assertEqual(main(), 1)
            artifact = json.loads(output.read_text())
            self.assertEqual(artifact["status"], "failed")
            self.assertEqual(artifact["samples"], [{"case": "arithmetic", "wall_seconds": 1.25}])
            self.assertEqual(artifact["errors"], ["RuntimeError"])

    def test_percentiles_are_recomputed_from_raw_values(self):
        self.assertEqual(percentile([1, 2, 3, 4, 5], .5), 3)
        self.assertAlmostEqual(percentile([1, 2, 3, 4, 5], .95), 4.8)
        for bad in ([], [float("nan")], [-1], [True]):
            with self.assertRaises(ValueError):
                percentile(bad, .95)

    def test_catalog_requires_unique_pinned_identity(self):
        row = "NAME:gemma4-e2b\nTAG:latest\nDIGEST:" + DIGEST + "\n"
        with tempfile.TemporaryDirectory() as temp:
            catalog = Path(temp) / "catalog.v1"
            catalog.write_text("ENTRY:" + row.encode().hex() + "\n")
            self.assertEqual(catalog_digest(Path(temp), "gemma4-e2b:latest"), DIGEST)
            with self.assertRaises(ValueError):
                catalog_digest(Path(temp), "other:latest")
            catalog.write_text("ENTRY:" + row.encode().hex() + "\nENTRY:" + row.encode().hex() + "\n")
            with self.assertRaises(ValueError):
                catalog_digest(Path(temp), "gemma4-e2b:latest")

    def test_stream_requires_complete_identity_counts_and_phase_timers(self):
        good = records()
        result = validate_stream(good, "gemma4-e2b:latest", DIGEST, 8, 512)
        self.assertEqual(result["text"], "Four.")
        self.assertEqual(result["first_arrival"], 1.0)
        for mutation in (
            lambda r: r.pop(),
            lambda r: r[0][1].update(done=True),
            lambda r: r[-1][1].update(model_digest="sha256:" + "b" * 64),
            lambda r: r[-1][1].update(generated_tokens=9),
            lambda r: r[-1][1].update(context_used=513),
            lambda r: r[-1][1]["timings_ms"].update(prefill=0),
            lambda r: r[-1][1].update(timings_ms={"prefill": 1}),
            lambda r: r[-1][1].update(finish_reason="timeout"),
            lambda r: r[0][1].update(text=""),
        ):
            changed = copy.deepcopy(good)
            mutation(changed)
            if changed[0][1].get("text") == "" and len(changed) == 3:
                changed[1][1]["text"] = ""
            with self.assertRaises(ValueError):
                validate_stream(changed, "gemma4-e2b:latest", DIGEST, 8, 512)

    def test_independent_http_client_observes_first_chunk_before_terminal(self):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                self.rfile.read(int(self.headers["Content-Length"]))
                if self.path != "/v1/generate" or self.headers.get("Authorization") != "Bearer key":
                    self.send_error(400)
                    return
                self.send_response(200)
                self.send_header("Content-Type", "application/x-ndjson")
                self.send_header("Connection", "close")
                self.end_headers()
                for _, item in records():
                    self.wfile.write(json.dumps(item).encode() + b"\n")
                    self.wfile.flush()
                    time.sleep(.02)

            def log_message(self, *args):
                pass

        service = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=service.serve_forever, daemon=True)
        worker.start()
        try:
            result = streamed_request(service.server_port, "key", "gemma4-e2b:latest",
                                      DIGEST, "2+2?", 8, 512)
            self.assertEqual(result["text"], "Four.")
            self.assertLess(result["ttft_seconds"], result["wall_seconds"])
            self.assertEqual(result["record_count"], 3)
        finally:
            service.shutdown()
            service.server_close()
            worker.join(timeout=5)
            self.assertFalse(worker.is_alive())


if __name__ == "__main__":
    unittest.main()
