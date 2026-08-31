"""Pure bounded-protocol adversarial checks; physical service tests are separate."""
from server.local_protocol import FlatJSON, LocalHTTPHead, valid_utf8
from cli.native_serve import GenerateRequest
from server.local_transport import c_path_bytes


def test_local_path_bounds() raises:
    var bytes = c_path_bytes("Halló")
    if len(bytes) != 7 or bytes[6] != 0 or UInt8(bytes[4]) != 195 or UInt8(bytes[5]) != 179:
        raise Error("Native C path lost UTF-8 or terminator")
    var long_path = String("")
    for _ in range(4096):
        long_path += "x"
    var cases: List[String] = ["", "bad\0path", long_path]
    for path in cases:
        var rejected = False
        try:
            _ = c_path_bytes(path)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid native path accepted")


def test_local_json() raises:
    var parser = FlatJSON(" {\"prompt\":\"Halló \\uD83C\\uDF0A\\n\",\"max_tokens\":32} ")
    var fields = parser.fields()
    if len(fields) != 2 or fields[0].value != "Halló 🌊\n" or fields[1].value != "32":
        raise Error("JSON decoding failed")
    var cases: List[String] = ["{\"x\":01}", "{\"x\":+1}", "{\"x\":1.}", "{\"x\":1e}", "{\"x\":NaN}", "{\"x\":{}}", "{\"x\":1,\"x\":2}", "{\"x\":1,}", "{}{}", "{\"x\":\"\\uD800\"}", "{\"x\":\"\\uDC00\"}", "{\"x\":\"\\u0000\"}", "{\"x\":\"a\n\"}", "{\"x\":\"\\q\"}", "{\"x\":\""]
    for source in cases:
        var rejected = False
        try:
            var invalid = FlatJSON(source)
            _ = invalid.fields()
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed JSON accepted")


def test_local_http() raises:
    var key = String("test-key")
    var head = String("POST /v1/generate HTTP/1.1\r\nHost: 127.0.0.1:18434\r\nAuthorization: Bearer test-key\r\nContent-Type: application/json\r\nContent-Length: 16\r\n\r\n")
    var accepted = LocalHTTPHead(head, 18434, key)
    if accepted.status != 200 or accepted.length != 16:
        raise Error("Valid local request rejected")
    if LocalHTTPHead(head, 18434, "wrong-key").status != 401:
        raise Error("Wrong key accepted")
    if LocalHTTPHead(head, 18435, key).status != 403:
        raise Error("Untrusted Host accepted")
    var cases: List[String] = ["GET / HTTP/1.0\r\n\r\n", "GET / HTTP/1.1\n\n", "GET / HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n", "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n", "GET / HTTP/1.1\r\n X: folded\r\n\r\n", "GET / HTTP/1.1\r\nContent-Length: -1\r\n\r\n", "GET / HTTP/1.1\r\nX: a\nInjected: b\r\n\r\n"]
    for source in cases:
        var rejected = False
        try:
            _ = LocalHTTPHead(source, 18434, key)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed HTTP accepted")


def main() raises:
    test_local_json()
    test_local_http()
    test_local_generation_request()
    test_local_path_bounds()
    print("PASS bounded JSON and HTTP rejection")


def test_local_generation_request() raises:
    var valid = GenerateRequest("{\"prompt\":\"Halló 🌊\",\"seed\":18446744073709551615,\"max_tokens\":16}", 64, 1000)
    if valid.prompt != "Halló 🌊" or valid.sampling.seed != UInt64(18446744073709551615) or valid.max_tokens != 16:
        raise Error("Native generation request lost text or integer precision")
    var cases: List[String] = [
        "{}", "{\"prompt\":1}", "{\"prompt\":\"\"}", "{\"prompt\":\"x\",\"seed\":18446744073709551616}",
        "{\"prompt\":\"x\",\"max_tokens\":0}", "{\"prompt\":\"x\",\"max_tokens\":65}",
        "{\"prompt\":\"x\",\"timeout_ms\":0}", "{\"prompt\":\"x\",\"timeout_ms\":1001}",
        "{\"prompt\":\"x\",\"top_k\":257}", "{\"prompt\":\"x\",\"top_p\":0}",
        "{\"prompt\":\"x\",\"stream\":true}", "{\"prompt\":\"x\",\"temperature\":\"0.8\"}",
        "{\"prompt\":\"x\",\"unknown\":1}", "{\"prompt\":\"x\",\"temperature\":-1}",
    ]
    for body in cases:
        var rejected = False
        try:
            _ = GenerateRequest(body, 64, 1000)
        except:
            rejected = True
        if not rejected:
            raise Error("Unsupported generation request accepted")
