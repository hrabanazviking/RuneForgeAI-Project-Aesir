"""Server browser page (J-108): the served try-it page's
pure layer -- the one route (GET / exactly), the document
contract (self-contained, zero external references, only
the J-106-audited calls, the J-107 stream vocabulary,
textContent-only insertion, the Cyber-Viking design-law
numbers), the size bound, and the T16 origin discipline
(the serving origin allowed in both spellings; every
cross-site value refused).

No number in this suite is a behaviour of a live server
or a real browser: no socket was opened, no page was
rendered. The live browser leg is deferred-with-reason
in the J-108 doc (section 5), re-cited at the J-118 gate.
"""
from core.browser_page import (
    browser_fetch_site_allowed,
    browser_origin_allowed,
    browser_page_content_type,
    browser_page_html,
    browser_referer_allowed,
    is_browser_page_request,
)


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "BrowserPage " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("BrowserPage " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("BrowserPage " + what + ": expected false")


def expect_str(actual: String, expected: String, what: String) raises:
    if actual != expected:
        raise Error(
            "BrowserPage " + what + ": expected '" + expected
            + "', got '" + actual + "'"
        )


def expect_in(haystack: String, needle: String, what: String) raises:
    if needle not in haystack:
        raise Error(
            "BrowserPage " + what + ": expected '" + needle
            + "' inside the page"
        )


def expect_not_in(haystack: String, needle: String, what: String) raises:
    if needle in haystack:
        raise Error(
            "BrowserPage " + what + ": did not expect '" + needle
            + "' inside the page"
        )


def test_route_predicate() raises:
    expect_true(is_browser_page_request("GET", "/"), "GET / is the page")
    expect_false(is_browser_page_request("POST", "/"), "POST / is not the page")
    expect_false(is_browser_page_request("GET", "/chat"), "no /chat alias")
    expect_false(is_browser_page_request("GET", "//"), "no // alias")
    expect_false(is_browser_page_request("GET", "/index.html"), "no file alias")
    expect_false(is_browser_page_request("GET", ""), "empty path is not the page")
    expect_false(is_browser_page_request("get", "/"), "method is case-exact")
    print("PASS: route predicate (GET / exactly; no alias, no other method)")


def test_content_type() raises:
    expect_str(browser_page_content_type(), "text/html; charset=utf-8",
               "page content type")
    print("PASS: content type (text/html; charset=utf-8)")


def test_document_shape() raises:
    var page = browser_page_html()
    expect_true(page.startswith("<!DOCTYPE html>"), "doctype first")
    expect_in(page, "<html lang=\"en\">", "document element")
    expect_in(page, "</html>", "document closes")
    expect_in(page, "<style>", "inline style opens")
    expect_in(page, "</style>", "inline style closes")
    expect_in(page, "<script>", "inline script opens")
    expect_in(page, "</script>", "inline script closes")
    expect_in(page, "<link rel=\"icon\" href=\"data:,\">",
              "favicon is an empty data URI, never fetched")
    print("PASS: document shape (one self-contained HTML document)")


def test_document_calls() raises:
    var page = browser_page_html()
    expect_in(page, "/v1/models", "the model list route (J-106 served)")
    expect_in(page, "/v1/chat/completions", "the chat route (J-106 served)")
    expect_in(page, "messages", "the audited messages field")
    expect_in(page, "stream_options", "the J-107 stream options field")
    expect_in(page, "include_usage", "usage requested when streaming")
    expect_in(page, "prefill_progress", "the J-107 progress event is handled")
    expect_in(page, "[DONE]", "the stream terminator is handled")
    expect_in(page, "delta", "streamed content chunks are handled")
    expect_in(page, "usage", "the usage chunk is rendered as counts")
    expect_in(page, "\"Error: \"", "errors are stated in words")
    expect_in(page, "Authorization", "the operator key is presented to the API")
    print("PASS: document calls (only the audited shape; J-107 stream vocabulary)")


def test_document_hygiene() raises:
    var page = browser_page_html()
    expect_not_in(page, "http://", "no external reference (http)")
    expect_not_in(page, "https://", "no external reference (https)")
    expect_not_in(page, "innerHTML", "no markup insertion anywhere")
    expect_in(page, "textContent", "text inserted as text only")
    expect_not_in(page, "\\", "no backslash anywhere (served bytes are literal)")
    expect_not_in(page, "cdn", "no CDN named")
    print("PASS: document hygiene (zero external references; textContent only)")


def test_design_law() raises:
    var page = browser_page_html()
    expect_in(page, "font-size: 16px", "body text in the 14-18px band")
    expect_in(page, "min-height: 44px", "controls at least 44px tall")
    expect_in(page, "min-width: 44px", "controls at least 44px wide")
    expect_in(page, "#d9a441", "the one accent colour is present")
    expect_eq(page.count("#d9a441"), 3,
              "accent used sparingly (send, its border, focus outline)")
    expect_in(page, "<label for=\"model\">", "model field labelled")
    expect_in(page, "<label for=\"key\">", "key field labelled")
    expect_in(page, "<label for=\"input\">", "message field labelled")
    expect_in(page, "aria-live=\"polite\"", "transcript announced politely")
    expect_in(page, "role=\"status\"", "status line is a status region")
    expect_in(page, "type=\"password\"", "the key field masks its text")
    expect_in(page, "id=\"stream\" checked", "streaming defaults on")
    expect_in(page, "max-width: 52rem", "fluid measure, scales with text")
    print("PASS: design law (16px text, 44px targets, labels, words-not-colour status)")


def test_size_bound() raises:
    var page = browser_page_html()
    var size = page.byte_length()
    expect_true(size > 2048, "the page is a real document, not a stub")
    expect_true(size <= 24576, "the page stays inside the 24 KiB bound")
    print("PASS: size bound (2048 < page <= 24576 bytes; actual "
          + String(size) + ")")


def test_origin_discipline() raises:
    expect_true(browser_origin_allowed("http://127.0.0.1:18434", 18434),
                "serving origin (ipv4 spelling) allowed")
    expect_true(browser_origin_allowed("http://localhost:18434", 18434),
                "serving origin (localhost spelling) allowed")
    expect_false(browser_origin_allowed("http://127.0.0.1:9999", 18434),
                 "another loopback port refused")
    expect_false(browser_origin_allowed("http://127.0.0.1:18434", 9999),
                 "the origin names the serving port or nothing")
    expect_false(browser_origin_allowed("https://127.0.0.1:18434", 18434),
                 "https spelling refused (the service is plain http)")
    expect_false(browser_origin_allowed("http://example.com", 18434),
                 "a foreign origin refused")
    expect_false(browser_origin_allowed("http://127.0.0.1:18434/", 18434),
                 "an Origin with a path is not the origin")
    expect_false(browser_origin_allowed("", 18434), "empty origin refused")
    expect_true(browser_referer_allowed("http://127.0.0.1:18434", 18434),
                "referer at the origin allowed")
    expect_true(browser_referer_allowed("http://127.0.0.1:18434/", 18434),
                "the page's own URL as referer allowed")
    expect_true(browser_referer_allowed("http://localhost:18434/", 18434),
                "localhost page URL as referer allowed")
    expect_false(browser_referer_allowed("http://127.0.0.1:9999/", 18434),
                 "a referer from another port refused")
    expect_false(browser_referer_allowed("http://127.0.0.1:18434.evil.com/", 18434),
                 "a lookalike host refused")
    expect_false(browser_referer_allowed("", 18434), "empty referer refused")
    expect_true(browser_fetch_site_allowed("same-origin"),
                "a fetch from the served page allowed")
    expect_true(browser_fetch_site_allowed("none"),
                "a direct navigation allowed")
    expect_false(browser_fetch_site_allowed("same-site"),
                 "another loopback port's page refused")
    expect_false(browser_fetch_site_allowed("cross-site"),
                 "a cross-site fetch refused")
    expect_false(browser_fetch_site_allowed(""), "empty fetch-site refused")
    print("PASS: origin discipline (serving origin only; cross-site refused)")


def main() raises:
    test_route_predicate()
    test_content_type()
    test_document_shape()
    test_document_calls()
    test_document_hygiene()
    test_design_law()
    test_size_bound()
    test_origin_discipline()
    print("ALL PASS: browser page (8 groups)")
