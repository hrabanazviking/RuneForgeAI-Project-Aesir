#!/usr/bin/env python3
"""J-108 inspect: mechanically re-derive the server
browser page slice's load-bearing claims from this tree.

Run from anywhere (paths resolve from this file). Every
check prints PASS or FAIL; the summary line states the
tally. Claims covered: the page layer (route predicate,
content type, the document extracted byte-for-byte from
its literal -- self-containment, the audited calls, the
J-107 stream vocabulary, textContent-only insertion,
the design-law numbers, the size bound, no backslash);
the origin discipline's rules; the head layer's narrow
execution of them (the three rule calls, the single
page predicate in the Bearer condition); the serve
branch (route, content type, placement before the
501/404 fallthrough, both modes); the J-106 audit flip
(GET / served, 9 served); the doc's stated tallies; the
suites' structure; the filed test output's tallies; and
repo hygiene (no README, no .gguf in the slice diff,
diff == the expected file set).
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AESIR = ROOT / "aesir_engine"
BASE = "68c78d6c2cde4c42ba575e153e3049edb7aed940"

results = []


def check(name, ok):
    results.append((name, bool(ok)))
    print(("PASS" if ok else "FAIL") + ": " + name)


def read(path):
    return Path(path).read_text(encoding="utf-8")


layer = read(AESIR / "core/browser_page.mojo")
head_src = read(AESIR / "server/local_protocol.mojo")
serve = read(AESIR / "cli/native_serve.mojo")
audit = read(AESIR / "core/openai_audit.mojo")
test = read(AESIR / "tests/test_browser_page.mojo")
audit_test = read(AESIR / "tests/test_openai_audit.mojo")
local_test = read(AESIR / "tests/test_local_protocol.mojo")
doc = read(AESIR / "docs/janas/J108_SERVER_BROWSER_PAGE.md")
test_output = read(AESIR / "docs/janas/j108_test_output.txt")

# --- the page layer -------------------------------------------------------------
check("layer: route, document, content type and the three rules all present",
      "def is_browser_page_request" in layer
      and "def browser_page_html" in layer
      and "def browser_page_content_type" in layer
      and "def browser_origin_allowed" in layer
      and "def browser_referer_allowed" in layer
      and "def browser_fetch_site_allowed" in layer)
check("layer: the route is GET / exactly",
      'return method == "GET" and path == "/"' in layer)
check("layer: content type is text/html with charset",
      '"text/html; charset=utf-8"' in layer)
check("layer: serving origins are the two loopback spellings at the port",
      '"http://127.0.0.1:"' in layer and '"http://localhost:"' in layer)
check("layer: fetch-site allows same-origin and none only",
      'value == "same-origin" or value == "none"' in layer)
check("layer: referer must be the origin or under it",
      'referer == allowed or referer.startswith(allowed + "/")' in layer)

# --- the document, extracted from its literal ------------------------------------
start = layer.find('"""<!DOCTYPE html>')
check("document: the literal opens with the doctype", start >= 0)
page = ""
if start >= 0:
    body_start = start + 3
    body_end = layer.find('"""', body_start)
    page = layer[body_start:body_end]
page_bytes = len(page.encode("utf-8"))
check("document: closes the html element", page.rstrip().endswith("</html>"))
check("document: zero external references",
      "http://" not in page and "https://" not in page)
check("document: no backslash anywhere (served bytes are literal)",
      "\\" not in page)
check("document: textContent only, no innerHTML",
      "textContent" in page and "innerHTML" not in page)
check("document: inline style and script, empty data-URI favicon",
      "<style>" in page and "<script>" in page
      and '<link rel="icon" href="data:,">' in page)
check("document: calls only the audited routes",
      "/v1/models" in page and "/v1/chat/completions" in page)
check("document: the J-107 stream vocabulary is handled",
      "prefill_progress" in page and "[DONE]" in page
      and "include_usage" in page and "stream_options" in page)
check("document: errors stated in words, key presented to the API",
      '"Error: "' in page and "Authorization" in page
      and 'type="password"' in page)
check("document: design-law numbers (16px text, 44px targets, labels, live region)",
      "font-size: 16px" in page and "min-height: 44px" in page
      and "min-width: 44px" in page
      and '<label for="model">' in page and '<label for="key">' in page
      and '<label for="input">' in page
      and 'aria-live="polite"' in page and 'role="status"' in page)
check("document: the accent marks the send control",
      "#send { background: #d9a441" in page
      and page.count("#d9a441") == 3)
check("document: size inside the filed bound (2048 < bytes <= 24576)",
      2048 < page_bytes <= 24576)
check("document: extracted size matches the filed test output",
      ("actual " + str(page_bytes)) in test_output)

# --- the head layer ---------------------------------------------------------------
check("head: imports the page layer's rules",
      "from core.browser_page import" in head_src)
check("head: the three browser headers decided by the layer's rules",
      "browser_origin_allowed(value, port)" in head_src
      and "browser_referer_allowed(value, port)" in head_src
      and "browser_fetch_site_allowed(value)" in head_src)
check("head: the Bearer condition exempts exactly the page request",
      "is_browser_page_request(self.method, self.path)" in head_src
      and '"Bearer " + key' in head_src)

# --- the serve wiring ---------------------------------------------------------------
check("serve: imports the page document and its content type",
      "from core.browser_page import browser_page_html, browser_page_content_type"
      in serve)
branch = serve.find('head.path == "/"')
fallthrough = serve.find("route_verdict(head.method, head.path)")
check("serve: the page branch answers GET / with the document",
      branch >= 0 and "browser_page_html()" in serve
      and "browser_page_content_type()" in serve)
check("serve: the page branch sits before the 501/404 fallthrough",
      0 <= branch < fallthrough)
check("serve: the host-contract comment records the page and its discipline",
      "The browser page (Janas road J-108)" in serve)

# --- the audit flip ------------------------------------------------------------------
check("audit: GET / is in the served route set",
      'names.append(String("GET /"))' in audit)
check("audit: the J-108 evolution is recorded in the module",
      "J-108 EVOLUTION" in audit and "8 -> 9 served" in audit)

# --- doc + suites ---------------------------------------------------------------------
check("doc: tallies stated (9 served; page 9,576 bytes; 8/8 and 7/7 suites)",
      "9 served" in doc and "9,576" in doc
      and "8/8" in doc and "7/7" in doc)
check("suite: test_browser_page has 8 groups and the ALL PASS line",
      test.count("def test_") == 8
      and "ALL PASS: browser page (8 groups)" in test)
check("suite: audit suite carries the flipped route table",
      "9 served incl. page + retrieve" in audit_test
      and 'route_verdict("GET", "/")' in audit_test)
check("suite: local protocol suite carries the J-108 head cases",
      "Browser page discipline (J-108, T16)" in local_test
      and "Same-origin browser API call refused" in local_test)
check("filed output: browser page 8/8",
      "ALL PASS: browser page (8 groups)" in test_output)
check("filed output: openai audit 7/7 at the flipped route table",
      "ALL PASS: openai audit (7 groups)" in test_output
      and "9 served incl. page" in test_output)
check("filed output: local protocol neighbour PASS",
      "test_local_protocol" in test_output
      and "PASS HTTP framing" in test_output)
check("filed output: native serve compile driver PASS",
      "native serve + browser page modules compile + import: PASS"
      in test_output)

# --- repo hygiene -----------------------------------------------------------------------
diff = subprocess.run(
    ["git", "-C", str(ROOT), "diff", "--name-only", BASE],
    capture_output=True, text=True).stdout.splitlines()
status = subprocess.run(
    ["git", "-C", str(ROOT), "status", "--porcelain"],
    capture_output=True, text=True).stdout.splitlines()
changed = set(diff) | {line[3:] for line in status if line.strip()}
check("no README in the slice diff", not any(p.endswith("README.md") for p in changed))
check("no .gguf in the slice diff", not any(p.endswith(".gguf") for p in changed))
expected = {
    "aesir_engine/cli/native_serve.mojo",
    "aesir_engine/core/browser_page.mojo",
    "aesir_engine/core/openai_audit.mojo",
    "aesir_engine/docs/janas/J108_SERVER_BROWSER_PAGE.md",
    "aesir_engine/docs/janas/j108_inspect.py",
    "aesir_engine/docs/janas/j108_inspect_output.txt",
    "aesir_engine/docs/janas/j108_test_output.txt",
    "aesir_engine/server/local_protocol.mojo",
    "aesir_engine/tests/test_browser_page.mojo",
    "aesir_engine/tests/test_local_protocol.mojo",
    "aesir_engine/tests/test_openai_audit.mojo",
}
check("slice diff is exactly the expected file set", changed == expected)

failed = [name for name, ok in results if not ok]
print("INSPECT: %d/%d PASS" % (len(results) - len(failed), len(results)))
if failed:
    print("FAILED: " + "; ".join(failed))
    sys.exit(1)
