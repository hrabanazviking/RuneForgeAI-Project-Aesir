#!/usr/bin/env python3
"""J-110 consumer: Runmal's backend prober shape, bound to Aesir over MCP.

This is the ecosystem consumer for J-109's MCP surface. It lives on the
consumer side of the boundary: its only contact with Aesir is spawning the
compiled MCP host process and speaking newline-delimited JSON-RPC 2.0 (MCP)
on its stdio. It calls no Aesir internal.

The shape is Runmal's own connection-probe contract (on disk:
~/workspace/runmal/src/runmal/connections/service.py, S211): a prober maps
a backend to an outcome {ok, capabilities, detail, models}, latency is
measured around the probe, and a health result {profile_id, ok,
latency_ms, capabilities, detail, models} is what the health check stores.
Here the backend is "aesir-mcp": instead of HTTP-probing a base URL, the
prober spawns `aesir mcp` (the compiled host binary) and the model list --
the thing a Runmal profile offers its user -- comes from the MCP tool
aesir_model_info.

The tool results are USED, not merely received:
  1. the catalogue listing becomes the probe's models list;
  2. the first model's full record is verified before it is trusted
     (64-hex sha256 pin, 40-hex revision, positive size) and its pin is
     carried into the probe detail -- the pin is what a later download
     would be verified against (J-103's contract);
  3. a real aesir_generate call decides whether "generate" may be
     advertised in capabilities: only what the tools actually did in
     this session is advertised. In the J-109 host build no engine is
     bound, so generation is recorded unavailable-with-reason and is
     NOT advertised;
  4. the health report is written as JSON to the path named by argv[2]
     (default: j110_consumer_report.json beside this script).

Usage: j110_runmal_consumer.py <host-binary> [report-path] [profile-id]
Exit code 0 iff every consumer assertion passes.
Python 3 standard library only.
"""

import json
import re
import subprocess
import sys
import time

FAILURES = []
OKS = [0]


def check(cond, what):
    if cond:
        OKS[0] += 1
        print("OK: " + what)
    else:
        FAILURES.append(what)
        print("FAIL: " + what)
    return cond


class McpClient:
    """Minimal newline-delimited JSON-RPC (MCP) client over stdio."""

    def __init__(self, argv):
        self.proc = subprocess.Popen(
            argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True
        )
        self.next_id = 1

    def request(self, method, params=None):
        rid = self.next_id
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        line = json.dumps(msg)
        print(">> " + line)
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        resp_line = self.proc.stdout.readline()
        print("<< " + resp_line.rstrip())
        resp = json.loads(resp_line)
        assert resp.get("id") == rid, "response id mismatch"
        return resp

    def notify(self, method, params=None):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        line = json.dumps(msg)
        print(">> " + line + "  (notification, no reply expected)")
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def close(self):
        self.proc.stdin.close()
        return self.proc.wait(timeout=30)


def tool_text(resp):
    content = resp["result"]["content"]
    assert len(content) == 1 and content[0]["type"] == "text"
    return content[0]["text"]


def probe_aesir_mcp(host_argv, profile_id):
    """Runmal S211 prober shape: returns the HealthResult-shaped dict."""
    started = time.monotonic()
    client = McpClient(host_argv)
    capabilities = []
    models = []
    detail_bits = []
    annex = {}
    try:
        resp = client.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "runmal-prober (J-110 consumer)", "version": "1.0.0"},
            },
        )
        check("result" in resp, "initialize answered with a result")
        check(
            resp["result"]["protocolVersion"] == "2024-11-05",
            "server protocol version is 2024-11-05",
        )
        check(
            resp["result"]["serverInfo"]["name"] == "aesir",
            "server identifies itself as aesir",
        )
        client.notify("notifications/initialized")

        resp = client.request("tools/list")
        tools = [t["name"] for t in resp["result"]["tools"]]
        check(
            sorted(tools)
            == ["aesir_embed", "aesir_generate", "aesir_model_info"],
            "discovery finds exactly the three J-109 tools",
        )

        print("== consumer use 1: the model list a profile would offer ==")
        resp = client.request(
            "tools/call", {"name": "aesir_model_info", "arguments": {}}
        )
        check(resp["result"]["isError"] is False, "listing call succeeded")
        listing = tool_text(resp)
        for line in listing.splitlines():
            if line.startswith("- "):
                models.append(line[2:].split(" (")[0])
        check(len(models) >= 1, "listing produced a non-empty models list")
        print("models offered to the profile user: " + ", ".join(models))
        if models:
            capabilities.append("local-models")

        print("== consumer use 2: verify the first model's record ==")
        record = None
        if models:
            resp = client.request(
                "tools/call",
                {"name": "aesir_model_info", "arguments": {"model": models[0]}},
            )
            check(resp["result"]["isError"] is False, "record call succeeded")
            record = json.loads(tool_text(resp))
            check(
                record["source"] == "known-models catalogue record",
                "record states its catalogue source",
            )
            check(
                re.fullmatch(r"[0-9a-f]{64}", record["sha256"]) is not None,
                "record sha256 pin is 64-hex (verified before trust)",
            )
            check(
                re.fullmatch(r"[0-9a-f]{40}", record["revision"]) is not None,
                "record revision is 40-hex (verified before trust)",
            )
            check(record["size_bytes"] > 0, "record size is positive")
            check(
                record["live_session_bound"] is False,
                "record honestly states no live session bound",
            )
            capabilities.append("model-info")
            detail_bits.append(
                "aesir-mcp catalogue: %d models; %s pin %s... verified"
                % (len(models), models[0], record["sha256"][:12])
            )
            annex["first_model_record"] = record

        print("== consumer use 3: may generation be advertised? ==")
        resp = client.request(
            "tools/call",
            {
                "name": "aesir_generate",
                "arguments": {"prompt": "Name the raven of memory.", "max_tokens": 16},
            },
        )
        gen_text = tool_text(resp)
        if resp["result"]["isError"]:
            annex["generate"] = {"advertised": False, "reason": gen_text}
            check(
                "no live model session is bound" in gen_text,
                "generate refuses honestly (no engine bound) -- not advertised",
            )
        else:
            annex["generate"] = {"advertised": True, "sample": gen_text}
            capabilities.append("generate")
            check(True, "generate answered with text -- advertised")
    finally:
        code = client.close()
    check(code == 0, "host exited cleanly at EOF (code 0)")
    latency_ms = (time.monotonic() - started) * 1000.0
    report = {
        "profile_id": profile_id,
        "ok": len(FAILURES) == 0,
        "latency_ms": round(latency_ms, 1),
        "capabilities": capabilities,
        "detail": "; ".join(detail_bits) if detail_bits else "aesir-mcp probe",
        "models": models,
        "backend": "aesir-mcp",
        "annex": annex,
    }
    return report


def main():
    if len(sys.argv) < 2:
        print("usage: j110_runmal_consumer.py <host-binary> [report-path] [profile-id]")
        return 2
    host = sys.argv[1]
    report_path = (
        sys.argv[2] if len(sys.argv) > 2 else "j110_consumer_report.json"
    )
    profile_id = sys.argv[3] if len(sys.argv) > 3 else "aesir-mcp-local"
    print("consumer: runmal-shaped prober; host: " + host)
    report = probe_aesir_mcp([host], profile_id)
    with open(report_path, "w") as fh:
        json.dump(report, fh, indent=2)
    print("== health report written to " + report_path + " ==")
    print(json.dumps(report, indent=2))
    if FAILURES:
        print("CONSUMER PROOF: FAIL (%d failures)" % len(FAILURES))
        return 1
    print("CONSUMER PROOF: ALL PASS (%d OK, 0 FAIL)" % OKS[0])
    return 0


if __name__ == "__main__":
    sys.exit(main())
