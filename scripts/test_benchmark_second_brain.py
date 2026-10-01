"""Actual-socket synthetic harness contracts; no model/GPU inference claim."""
from contextlib import contextmanager, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

import benchmark_second_brain as bench


@contextmanager
def server(responder):
    calls = []
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.handle_request(None)
        def do_POST(self):
            raw = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            self.handle_request(json.loads(raw))
        def handle_request(self, body):
            calls.append((self.path, body, dict(self.headers)))
            status, reply = responder(self.path, body, self.headers)
            encoded = reply if isinstance(reply, bytes) else json.dumps(reply).encode()
            self.send_response(status)
            self.end_headers()
            self.wfile.write(encoded)
        def log_message(self, *args):
            pass
    service = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=service.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{service.server_port}", calls
    finally:
        service.shutdown()
        service.server_close()
        thread.join(timeout=5)
        assert not thread.is_alive()


def reply(route, body, headers):
    if route == "/health":
        return 200, {"status": "ready", "backend": "cuda", "model": "fixture",
                     "context": 4096, "max_tokens": 256, "model_digest": "sha256:" + "0" * 64,
                     "capabilities": {"exact_prefix_reuse": True}}
    if route == "/api/version":
        return 200, {"version": "synthetic-harness"}
    if route == "/api/ps":
        return 200, {"models": [{"model": "fixture", "context_length": 4096}]}
    if route == "/api/chat" and body["messages"] == []:
        return 200, {"model": "fixture", "done": True, "load_duration": 3}
    if route == "/v1/generate":
        return 200, {"backend": "cuda", "model": "fixture", "text": "Four. Complete public reply.",
                     "prompt_tokens": 37, "generated_tokens": body["max_tokens"],
                     "finish_reason": "length"}
    return 200, {"model": "fixture", "done": True, "message": {"content": "Four. Different complete public reply."},
                 "prompt_eval_count": 57, "eval_count": body["options"]["num_predict"],
                 "done_reason": "length", "load_duration": 0,
                 "prompt_eval_duration": 100, "eval_duration": 200}


class Contracts(unittest.TestCase):
    def run_harness(self, directory, responder=reply, **options):
        key = "synthetic-private-key-for-redaction"
        keyfile = Path(directory) / "key"
        keyfile.write_text(key)
        output = Path(directory) / "report.json"
        with server(responder) as (origin, calls):
            args = ["--aesir", origin, "--ollama", origin, "--key-file", str(keyfile),
                    "--model", "fixture", "--samples", "2", "--output", str(output)]
            for flag, value in options.items():
                args.append("--" + flag.replace("_", "-"))
                if value is not True:
                    args.append(str(value))
            binary = Path(directory) / "binary"
            binary.write_bytes(b"synthetic build validation fixture")
            with patch.object(bench.launch, "validate_build", return_value=binary), \
                    patch.object(bench, "gpu_snapshot", return_value={"unavailable": True}), \
                    redirect_stdout(io.StringIO()):
                result = bench.main(args)
        return result, json.loads(output.read_text()), calls, key

    def test_portable_lengths_complete_evidence_and_order(self):
        for ceiling in (32, 128, 256):
            with self.subTest(ceiling=ceiling), tempfile.TemporaryDirectory() as directory:
                result, report, calls, key = self.run_harness(directory, suite="extended", max_tokens=ceiling)
                self.assertEqual(result, 0)
                self.assertEqual(len(report["samples"]), 12)
                self.assertEqual([s["provider"] for s in report["samples"][:6]],
                                 ["aesir", "ollama", "ollama", "aesir", "aesir", "ollama"])
                self.assertTrue(all(s["generated_tokens"] == ceiling and s["text"] and s["reply"] for s in report["samples"]))
                self.assertNotIn(key, json.dumps(report))
                self.assertFalse(report["speed_ratios"]["long_context"]["quality_parity_established"])
                self.assertEqual(report["distributions_seconds"]["aesir"]["long_context"]["n"], 2)
                for route, body, headers in calls:
                    if route.startswith("/api/"):
                        self.assertNotIn("Authorization", headers)

    def test_loaded_residency_has_explicit_preload(self):
        with tempfile.TemporaryDirectory() as directory:
            result, report, calls, _ = self.run_harness(directory, residency="loaded")
            self.assertEqual(result, 0)
            preload = [body for route, body, _ in calls if route == "/api/chat" and not body["messages"]]
            self.assertEqual(len(preload), 1)
            self.assertEqual(preload[0]["keep_alive"], "10m")
            self.assertFalse(report["cache_policy"]["first_appearance_is_cache_disabled"])

    def test_response_identity_count_and_shape_fail_closed(self):
        for field, value in [("model", "other"), ("backend", "cpu"),
                             ("generated_tokens", True), ("generated_tokens", 257),
                             ("generated_tokens", 1), ("text", ""), ("finish_reason", "timeout")]:
            def broken(route, body, headers):
                status, data = reply(route, body, headers)
                if route == "/v1/generate":
                    data[field] = value
                return status, data
            with self.subTest(field=field, value=value), tempfile.TemporaryDirectory() as directory:
                result, report, _, _ = self.run_harness(directory, broken)
                self.assertEqual(result, 1)
                self.assertGreater(report["failed_samples"], 0)
                self.assertTrue(all(v["ollama_over_aesir"] is None for v in report["speed_ratios"].values()))
                self.assertTrue(any("reply" in s and "failure_category" in s for s in report["samples"]))
        for done in (None, False, 1):
            def unfinished(route, body, headers):
                status, data = reply(route, body, headers)
                if route == "/api/chat" and body["messages"]:
                    data["done"] = done
                return status, data
            with self.subTest(done=done), tempfile.TemporaryDirectory() as directory:
                result, report, _, _ = self.run_harness(directory, unfinished)
                self.assertEqual(result, 1)
                self.assertTrue(report["failed_samples"])
                self.assertTrue(all(v["ollama_over_aesir"] is None for v in report["speed_ratios"].values()))

    def test_initial_failure_is_retained_and_disables_all_ratios(self):
        failed = False
        def responder(route, body, headers):
            nonlocal failed
            if route == "/v1/generate" and not failed:
                failed = True
                return 503, {"error": "synthetic busy"}
            return reply(route, body, headers)
        with tempfile.TemporaryDirectory() as directory:
            result, report, _, _ = self.run_harness(directory, responder)
            self.assertEqual((result, report["failed_samples"]), (1, 1))
            self.assertEqual(report["samples"][0]["phase"], "warmup")
            self.assertTrue(all(s["ollama_over_aesir"] is None for s in report["speed_ratios"].values()))

    def test_eos_length_difference_excluded_from_score(self):
        def responder(route, body, headers):
            status, data = reply(route, body, headers)
            if route == "/api/chat" and body["messages"]:
                data.update(eval_count=2, done_reason="stop")
            return status, data
        with tempfile.TemporaryDirectory() as directory:
            result, report, _, _ = self.run_harness(directory, responder)
            self.assertEqual(result, 0)
            self.assertTrue(all(s["ollama_over_aesir"] is None for s in report["speed_ratios"].values()))

    def test_echoed_key_redacted_from_nested_reply(self):
        def responder(route, body, headers):
            status, data = reply(route, body, headers)
            if route == "/v1/generate":
                data["echo"] = [{"secret": headers["Authorization"]}]
                data["text"] += headers["Authorization"]
            return status, data
        with tempfile.TemporaryDirectory() as directory:
            result, report, _, key = self.run_harness(directory, responder)
            self.assertEqual(result, 0)
            self.assertNotIn(key, json.dumps(report))
            self.assertIn("[REDACTED]", json.dumps(report))

    def test_native_disable_intent_must_be_observed(self):
        with tempfile.TemporaryDirectory() as directory:
            result, report, calls, _ = self.run_harness(directory, native_no_prefix_cache=True)
            self.assertEqual(result, 1)
            self.assertFalse(report["samples"])
            self.assertTrue(report["errors"])
            self.assertEqual(len(calls), 1)

    def test_report_reserved_before_any_operations(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            output.write_text("preserve original")
            with patch.object(bench, "measure") as measure:
                with self.assertRaises(FileExistsError):
                    bench.main(["--ollama", "http://127.0.0.1:9", "--key-file", "missing",
                                "--model", "fixture", "--output", str(output)])
                measure.assert_not_called()
            self.assertEqual(output.read_text(), "preserve original")

    def test_setup_failure_retains_artifact(self):
        with tempfile.TemporaryDirectory() as directory, redirect_stdout(io.StringIO()):
            output = Path(directory) / "report.json"
            result = bench.main(["--ollama", "http://127.0.0.1:9", "--key-file", "missing",
                                 "--model", "fixture", "--output", str(output)])
            report = json.loads(output.read_text())
            self.assertEqual(result, 1)
            self.assertTrue(report["errors"])
            self.assertFalse(report["samples"])

    def test_schedule_seed_grouping_and_balance(self):
        prompts = {"one": "p", "two": "q"}
        a = bench.schedule(prompts, 10, "randomized", 71)
        self.assertEqual(a, bench.schedule(prompts, 10, "randomized", 71))
        self.assertNotEqual(a, bench.schedule(prompts, 10, "randomized", 72))
        self.assertEqual(len(a), 44)
        self.assertEqual(bench.schedule(prompts, 1, "grouped", 1)[:4],
                         [("one", 0, "aesir"), ("one", 1, "aesir"), ("one", 0, "ollama"), ("one", 1, "ollama")])

    def test_untrusted_json_status_and_response_size(self):
        for raw in (b'{}', b'{"a":NaN}', b'{"a":1e999}', b'[' * 2000 + b'0' + b']' * 2000, b'{"a":1,"a":2}', b'[]', b'{invalid', b'x' * (bench.RESPONSE_LIMIT + 1)):
            with self.subTest(raw=raw[:20]), server(lambda *a: (200, raw)) as (origin, _):
                if raw == b'{}':
                    self.assertEqual(bench.request(origin, "/health")[1], {})
                else:
                    with self.assertRaises((ValueError, json.JSONDecodeError)):
                        bench.request(origin, "/health")

    def test_interrupt_is_failure_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            keyfile = Path(directory) / "key"
            keyfile.write_text("synthetic-key")
            args = bench.parser().parse_args(["--ollama", "http://127.0.0.1:9", "--key-file", str(keyfile),
                                             "--model", "fixture", "--output", str(Path(directory) / "report")])
            with patch.object(bench, "preflight", side_effect=KeyboardInterrupt):
                report = bench.measure(args)
            self.assertEqual(report["errors"], ["Interrupted"])
            self.assertTrue(all(v["ollama_over_aesir"] is None for v in report["speed_ratios"].values()))

    def test_credentials_and_url_admission(self):
        for origin in ("https://127.0.0.1", "http://user:pass@127.0.0.1", "http://127.0.0.1/path",
                       "http://127.0.0.1?x=1", "http://localhost", "http://example.invalid"):
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                bench.request(origin, "/health", key="synthetic-secret")

    def test_nonfinite_or_negative_provider_duration_rejected(self):
        for duration in (-1, True, "10", 1.5):
            def responder(route, body, headers):
                status, data = reply(route, body, headers)
                if route == "/api/chat" and body["messages"]:
                    data["eval_duration"] = duration
                return status, data
            with self.subTest(duration=duration), tempfile.TemporaryDirectory() as directory:
                result, report, _, _ = self.run_harness(directory, responder)
                self.assertEqual(result, 1)
                self.assertTrue(report["failed_samples"])


if __name__ == "__main__":
    unittest.main()
