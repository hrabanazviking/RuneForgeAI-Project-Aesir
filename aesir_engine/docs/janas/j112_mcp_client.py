#!/usr/bin/env python3
"""J-112 MCP services client proof: a real MCP client
session against the compiled Aesir MCP stdio host,
exercising the services surface (J-112) on top of the
J-109 behaviours.

Standard library only (no MCP SDK is installed on this
machine -- the J-109 doc section 0.1 records the
choice). This client speaks actual MCP framing over
stdio: newline-delimited JSON-RPC 2.0 -- initialize,
notifications/initialized, tools/list, tools/call,
ping -- plus the protocol error cases. It calls no
server internal; the server is a subprocess whose
stdin/stdout are the whole interface, exactly as an
editor's MCP client drives it.

The services exercised here are the ones that need no
live model: aesir_census (the catalogue population +
the services inventory), aesir_grade (a faithful cell,
an unstated-comparator cell, an inconsistent record),
aesir_bench (a real report: the host's own observed
device inventory composed with the filed per-model
evidence table), and aesir_tokenize in its honest
unbound form (no tokenizer is bound in this host).
The J-109 behaviours are re-checked standing: the
seven-tool list, model_info, the embed refusal, the
unbound generate error, ping, and the error codes.

Usage: j112_mcp_client.py <server-binary>
Every exchange is printed to the transcript; every
expectation is asserted; the exit code is 0 only if
all assertions pass.
"""

import json
import subprocess
import sys

FAILURES = []


def check(cond, what):
    print(("  OK  " if cond else "  FAIL") + "  " + what)
    if not cond:
        FAILURES.append(what)


class McpClient:
    def __init__(self, argv):
        self.proc = subprocess.Popen(
            argv,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.next_id = 1

    def send_raw(self, text):
        print(">>> " + text)
        self.proc.stdin.write(text + "\n")
        self.proc.stdin.flush()

    def request(self, method, params=None):
        rid = self.next_id
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self.send_raw(json.dumps(msg))
        line = self.proc.stdout.readline()
        if not line:
            raise RuntimeError("server closed stdout on " + method)
        print("<<< " + line.rstrip("\n"))
        resp = json.loads(line)
        assert resp.get("id") == rid, "id echo mismatch"
        return resp

    def notify(self, method, params=None):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        self.send_raw(json.dumps(msg))

    def call(self, tool, arguments):
        return self.request(
            "tools/call", {"name": tool, "arguments": arguments}
        )

    def close(self):
        self.proc.stdin.close()
        rc = self.proc.wait(timeout=30)
        print("server exit code: " + str(rc))
        return rc


def tool_text(resp):
    content = resp["result"]["content"]
    assert len(content) == 1 and content[0]["type"] == "text"
    return content[0]["text"]


def main():
    if len(sys.argv) < 2:
        print("usage: j112_mcp_client.py <server-binary>")
        return 2
    client = McpClient([sys.argv[1]])
    try:
        print("== initialize ==")
        resp = client.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "j112-proof-client", "version": "1.0.0"},
            },
        )
        result = resp["result"]
        check(
            result["protocolVersion"] == "2024-11-05",
            "protocol version 2024-11-05",
        )
        check(
            result["serverInfo"]["name"] == "aesir", "serverInfo name aesir"
        )
        check("tools" in result["capabilities"], "tools capability offered")
        client.notify("notifications/initialized")

        print("== tools/list ==")
        resp = client.request("tools/list")
        tools = resp["result"]["tools"]
        names = [t["name"] for t in tools]
        check(
            names
            == [
                "aesir_generate",
                "aesir_model_info",
                "aesir_embed",
                "aesir_tokenize",
                "aesir_grade",
                "aesir_census",
                "aesir_bench",
            ],
            "exactly the seven tools: " + ", ".join(names),
        )
        tokenize_tool = [t for t in tools if t["name"] == "aesir_tokenize"][0]
        check(
            "honest" in tokenize_tool["description"],
            "tokenize states its model-bound honesty in tools/list",
        )
        grade_tool = [t for t in tools if t["name"] == "aesir_grade"][0]
        check(
            "COMPARATOR_ARTIFACT" in grade_tool["description"],
            "grade states the comparator default in tools/list",
        )

        print("== tools/call aesir_census ==")
        resp = client.call("aesir_census", {})
        text = tool_text(resp)
        check(resp["result"]["isError"] is False, "census is not an error")
        check(
            "known-models census: 5 entries" in text,
            "census counts the real catalogue",
        )
        check("bytes total" in text, "census carries the total bytes")
        check(
            "olmoe-1b-7b:q4_k_m" in text, "census names the OLMoE entry"
        )
        check(
            "aesir services (9 inventoried)" in text,
            "census carries the services inventory",
        )
        check(
            "embed [REFUSED]" in text, "inventory states the embed refusal"
        )
        check(
            "mcp_client [DEFERRED]" in text,
            "inventory states the T22 deferral",
        )

        print("== tools/call aesir_grade (faithful cell) ==")
        resp = client.call(
            "aesir_grade",
            {"rank": 0, "gap_milli": 0, "comparator_valid": True},
        )
        text = tool_text(resp)
        check(resp["result"]["isError"] is False, "grade is not an error")
        check("step EXACT" in text, "exact step class")
        check("verdict FAITHFUL" in text, "faithful verdict")

        print("== tools/call aesir_grade (unstated comparator) ==")
        resp = client.call("aesir_grade", {"rank": 1, "gap_milli": 250})
        text = tool_text(resp)
        check("step NEAR_TIE" in text, "near-tie step class")
        check(
            "COMPARATOR_ARTIFACT" in text,
            "unstated comparator grades COMPARATOR_ARTIFACT",
        )

        print("== tools/call aesir_grade (inconsistent record) ==")
        resp = client.call(
            "aesir_grade",
            {"rank": 0, "gap_milli": 5, "comparator_valid": True},
        )
        check(
            resp["result"]["isError"] is True,
            "inconsistent record is a tool error",
        )
        check(
            "grade refused" in tool_text(resp),
            "inconsistent record refused with its reason",
        )

        print("== tools/call aesir_bench (real report) ==")
        resp = client.call("aesir_bench", {})
        text = tool_text(resp)
        check(resp["result"]["isError"] is False, "bench is not an error")
        check(
            "bench report (the report form" in text,
            "bench answers the report form",
        )
        check(
            "per-model read/write (filed evidence)" in text,
            "bench carries the filed evidence table",
        )
        check("OLMoE" in text, "bench table names the OLMoE row")
        check("NOT PROVEN" in text, "bench table keeps its honesty classes")
        check(
            "CLI-only" in text, "bench states the sweep is CLI-only"
        )

        print("== tools/call aesir_tokenize (no tokenizer bound) ==")
        resp = client.call("aesir_tokenize", {"text": "hello world"})
        text = tool_text(resp)
        check(
            resp["result"]["isError"] is True,
            "unbound tokenize is a tool error",
        )
        check(
            "no tokenizer is bound" in text,
            "unbound tokenize states why, in plain words",
        )
        check("ids: [" not in text, "no fake id list in the refusal")

        print("== tools/call aesir_model_info (listing, J-109 standing) ==")
        resp = client.call("aesir_model_info", {})
        listing = tool_text(resp)
        check(resp["result"]["isError"] is False, "listing is not an error")
        check("known-models catalogue" in listing, "listing names its source")

        print("== tools/call aesir_embed (honest refusal, standing) ==")
        resp = client.call("aesir_embed", {"input": "hello"})
        text = tool_text(resp)
        check(resp["result"]["isError"] is True, "embed refusal is tool error")
        check("no embedding" in text, "embed refusal gives its reason")

        print("== tools/call aesir_generate (no engine bound, standing) ==")
        resp = client.call(
            "aesir_generate", {"prompt": "Hello", "max_tokens": 16}
        )
        text = tool_text(resp)
        check(
            resp["result"]["isError"] is True,
            "unbound generate is a tool error",
        )
        check(
            "no live model session is bound" in text,
            "unbound generate states why, in plain words",
        )

        print("== ping ==")
        resp = client.request("ping")
        check(resp["result"] == {}, "ping answers {}")

        print("== unknown method ==")
        resp = client.request("resources/list")
        check(
            resp["error"]["code"] == -32601,
            "unknown method is -32601",
        )

        print("== malformed line ==")
        client.send_raw("{not json")
        line = client.proc.stdout.readline()
        print("<<< " + line.rstrip("\n"))
        resp = json.loads(line)
        check(resp["error"]["code"] == -32700, "malformed is -32700")
        check(resp["id"] is None, "parse error id is null")
    finally:
        rc = client.close()
    check(rc == 0, "server exits cleanly at EOF")
    if FAILURES:
        print("CLIENT PROOF: FAIL (" + str(len(FAILURES)) + ")")
        return 1
    print("CLIENT PROOF: ALL PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
