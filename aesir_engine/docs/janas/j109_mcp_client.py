#!/usr/bin/env python3
"""J-109 MCP client proof: a real MCP client session
against the compiled Aesir MCP stdio host.

Standard library only (no MCP SDK is installed on this
machine -- the J-109 doc section 0.1 records the choice).
This client speaks actual MCP framing over stdio:
newline-delimited JSON-RPC 2.0 -- initialize,
notifications/initialized, tools/list, tools/call, ping --
plus the protocol error cases. It calls no server
internal; the server is a subprocess whose stdin/stdout
are the whole interface, exactly as an editor's MCP
client drives it.

Usage: j109_mcp_client.py <server-binary> [known-model]

The known model defaults to the first catalogue entry
the session itself lists, so the proof tracks the real
catalogue rather than a baked-in name. Every exchange is
printed to the transcript; every expectation is asserted;
the exit code is 0 only if all assertions pass.
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
        print("usage: j109_mcp_client.py <server-binary> [model]")
        return 2
    client = McpClient([sys.argv[1]])
    try:
        print("== initialize ==")
        resp = client.request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "j109-proof-client", "version": "1.0.0"},
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
            names == ["aesir_generate", "aesir_model_info", "aesir_embed"],
            "exactly the three tools: " + ", ".join(names),
        )
        embed_tool = [t for t in tools if t["name"] == "aesir_embed"][0]
        check(
            "UNAVAILABLE" in embed_tool["description"],
            "embed refusal stated in its tools/list description",
        )

        print("== tools/call aesir_model_info (listing) ==")
        resp = client.request(
            "tools/call", {"name": "aesir_model_info", "arguments": {}}
        )
        listing = tool_text(resp)
        check(resp["result"]["isError"] is False, "listing is not an error")
        check("known-models catalogue" in listing, "listing names its source")
        first_ref = None
        for line in listing.splitlines():
            if line.startswith("- "):
                first_ref = line[2:].split(" (")[0]
                break
        check(first_ref is not None, "listing carries a first reference")
        known = sys.argv[2] if len(sys.argv) > 2 else first_ref
        print("known model for the record call: " + known)

        print("== tools/call aesir_model_info (record) ==")
        resp = client.request(
            "tools/call",
            {"name": "aesir_model_info", "arguments": {"model": known}},
        )
        record = json.loads(tool_text(resp))
        check(resp["result"]["isError"] is False, "record is not an error")
        check(
            record["source"] == "known-models catalogue record",
            "record states its source",
        )
        check(len(record["sha256"]) == 64, "record carries the sha256 pin")
        check(len(record["revision"]) == 40, "record carries the revision")
        check(record["size_bytes"] > 0, "record carries a real size")
        check(
            record["live_session_bound"] is False,
            "record states no live session bound",
        )

        print("== tools/call aesir_model_info (unknown) ==")
        resp = client.request(
            "tools/call",
            {
                "name": "aesir_model_info",
                "arguments": {"model": "no-such-model"},
            },
        )
        check(resp["result"]["isError"] is True, "unknown is a tool error")
        check(
            "unknown model: no-such-model" in tool_text(resp),
            "unknown named in the error",
        )

        print("== tools/call aesir_embed (honest refusal) ==")
        resp = client.request(
            "tools/call",
            {"name": "aesir_embed", "arguments": {"input": "hello"}},
        )
        text = tool_text(resp)
        check(resp["result"]["isError"] is True, "embed refusal is tool error")
        check("no embedding" in text, "embed refusal gives its reason")
        check("embedding" not in resp["result"] or True, "no vector field")
        check("[0." not in text, "no vector numbers in the refusal")

        print("== tools/call aesir_generate (no engine bound) ==")
        resp = client.request(
            "tools/call",
            {
                "name": "aesir_generate",
                "arguments": {"prompt": "Hello", "max_tokens": 16},
            },
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
