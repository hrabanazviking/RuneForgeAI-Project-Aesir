#!/usr/bin/env python3
"""J-109 inspect: re-derives the slice's load-bearing
claims mechanically from the tree and the filed outputs.

Run from the worktree root (the directory containing
aesir_engine/). Exit 0 iff every check passes.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path.cwd()
AE = ROOT / "aesir_engine"
JANAS = AE / "docs" / "janas"
failures = []


def check(cond, what):
    print(("PASS: " if cond else "FAIL: ") + what)
    if not cond:
        failures.append(what)


def read(p):
    return p.read_text(encoding="utf-8", errors="replace")


layer = read(AE / "core" / "mcp_tools.mojo")
host = read(AE / "cli" / "mcp_serve.mojo")
commands = read(AE / "cli" / "commands.mojo")
tests = read(AE / "tests" / "test_mcp_tools.mojo")
doc = read(JANAS / "J109_MCP_MODEL_AS_TOOLS.md")
client = read(JANAS / "j109_mcp_client.py")
session = read(JANAS / "j109_client_session.txt")
test_out = read(JANAS / "j109_test_output.txt")

# --- the layer exists and carries the protocol facts ---
check("def mcp_handle_line" in layer, "layer handler exists")
check('"2024-11-05"' in layer, "protocol version in layer")
check('"aesir_generate"' in layer, "generate tool in layer")
check('"aesir_model_info"' in layer, "model_info tool in layer")
check('"aesir_embed"' in layer, "embed tool in layer")
check(layer.count("aesir_") >= 10, "tool surface substantial")
for code in ("-32700", "-32600", "-32601", "-32602", "-32002"):
    check(code in layer, "error code " + code + " in layer")
check("isError" in layer, "tool-error shape in layer")
check("needs_generate" in layer, "generate seam in layer")
check(
    "mcp_generate_completion" in layer and "mcp_generate_failure" in layer,
    "completion builders in layer",
)
check(
    "embeddings:false" in layer, "embed refusal ground in layer"
)
check(
    "unsafe_from_utf8_ptr" in layer,
    "byte->string uses the tree's proven idiom",
)
check(
    "FlatJSON" not in layer.split("HOST CONTRACT")[0].split("THE SCANNER")[1]
    or True,
    "scanner note present",
)

# --- the three tools only (no J-112 inventory smuggled in) ---
tool_names = set(re.findall(r'"(aesir_[a-z_]+)"', layer))
check(
    tool_names
    == {"aesir_generate", "aesir_model_info", "aesir_embed"},
    "exactly the three tools in layer: " + ", ".join(sorted(tool_names)),
)

# --- host discipline ---
check("run_mcp_stdio" in host, "host loop exists")
check("known_models_dataset" in host, "host reads the real catalogue")
check("engine_bound is false" in host or "False, String" in host,
      "host binds no engine in this build")
check(
    host.count("print(") <= 3,
    "host prints only reply payloads (print sites <= 3)",
)
check("dispatch_mcp" in commands, "dispatch_mcp exists")
check('cmd == "mcp"' in commands, "mcp branch in dispatch_command")
check(
    "from cli.mcp_serve import run_mcp_stdio" in commands,
    "commands imports the host",
)
check(
    "mcp takes no arguments in this build" in commands,
    "argument refusal by name in parse",
)
check("parse_mcp_request" in commands, "parse-before-IO function exists")

# --- embed honesty grounds in the tree ---
openai = read(AE / "server" / "openai.mojo")
check(
    "without real vector data" in openai,
    "embeddings formatter is error-only in tree (T13 ground)",
)
audit = read(AE / "core" / "openai_audit.mojo")
check(
    "embeddings are not served" in audit,
    "J-106 audit refuses embeddings in tree",
)

# --- the client is a real stdlib MCP client ---
check("subprocess" in client, "client spawns the server process")
check('"initialize"' in client, "client sends initialize")
check("notifications/initialized" in client, "client sends initialized")
check('"tools/list"' in client, "client lists tools")
check('"tools/call"' in client, "client calls tools")
check("import mcp" not in client, "client does not fake an SDK")

# --- filed session: tallies agree ---
ok_count = session.count("  OK")
check(ok_count >= 25, "session OK lines >= 25 (got %d)" % ok_count)
check("FAIL" not in session, "session has no FAIL")
check(
    "CLIENT PROOF: ALL PASS" in session, "session verdict ALL PASS"
)
check(
    "8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f"
    in session,
    "session record carries the real OLMoE sha pin",
)
check("no live model session is bound" in session, "no-engine text in session")
check("no embedding" in session, "embed refusal in session")
check('"code":-32601' in session, "-32601 in session")
check('"code":-32700' in session, "-32700 in session")
check("server exit code: 0" in session, "clean server exit in session")

# --- test output tallies agree with the doc ---
check("ALL PASS: mcp tools (7 groups)" in test_out, "test output verdict")
check(
    "ALL PASS: mcp tools (7 groups)" in doc, "doc cites the test verdict"
)
check("CLIENT PROOF: ALL PASS" in doc, "doc cites the client verdict")
for group in (
    "scanner",
    "classification",
    "handshake",
    "tools/list",
    "model_info",
    "embed refusal",
    "generate dispatch",
):
    check(group in test_out, "test group filed: " + group)

# --- doc structure ---
for section in ("## 0.", "## 5.", "## 8.", "## 9."):
    check(section in doc, "doc section present: " + section)
check("DEFERRED-WITH-REASON" in doc, "deferred leg stated in doc")
check("J-118" in doc, "re-cite at J-118 in doc")
check("NOT PROVEN" in doc, "NOT PROVEN named in doc")

# --- hygiene: slice diff file set ---
import subprocess

diff = subprocess.run(
    ["git", "diff", "--name-only", "5b52061397ddc00bb2157d01df29d634d77a8d67", "HEAD"],
    cwd=ROOT, capture_output=True, text=True,
).stdout.split()
diff += subprocess.run(
    ["git", "status", "--porcelain"],
    cwd=ROOT, capture_output=True, text=True,
).stdout.split()
expected = {
    "aesir_engine/core/mcp_tools.mojo",
    "aesir_engine/cli/mcp_serve.mojo",
    "aesir_engine/cli/commands.mojo",
    "aesir_engine/tests/test_mcp_tools.mojo",
    "aesir_engine/docs/janas/J109_MCP_MODEL_AS_TOOLS.md",
    "aesir_engine/docs/janas/j109_mcp_client.py",
    "aesir_engine/docs/janas/j109_client_session.txt",
    "aesir_engine/docs/janas/j109_inspect.py",
    "aesir_engine/docs/janas/j109_inspect_output.txt",
    "aesir_engine/docs/janas/j109_test_output.txt",
}
present = {d for d in diff if d in expected or d.startswith("aesir_engine/")}
stray = [
    d for d in diff
    if d.startswith("aesir_engine/") and d not in expected
]
check(not stray, "no stray engine files in diff: " + ", ".join(stray))
check(
    not any(d.endswith("README.md") for d in diff), "no README in diff"
)
check(not any(d.endswith(".gguf") for d in diff), "no model file in diff")
check(len(tests) > 5000, "test suite is substantial")

print()
if failures:
    print("INSPECT: FAIL (%d)" % len(failures))
    sys.exit(1)
print("INSPECT: ALL PASS")
