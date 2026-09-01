"""Strict bounded HTTP/JSON input for the native loopback service.

This intentionally implements a small protocol, not general HTTP pipelining or
OpenAI compatibility. Transport must pass exactly the declared body bytes.
"""
from core.observation_integer import bounded_decimal


def valid_utf8(text: String) -> Bool:
    var bytes = text.as_bytes()
    var i = 0
    while i < len(bytes):
        var b = Int(bytes[i])
        if b < 128:
            i += 1
            continue
        var count: Int
        var cp: Int
        var minimum: Int
        if b >= 194 and b <= 223:
            count = 1
            cp = b & 31
            minimum = 128
        elif b >= 224 and b <= 239:
            count = 2
            cp = b & 15
            minimum = 2048
        elif b >= 240 and b <= 244:
            count = 3
            cp = b & 7
            minimum = 65536
        else:
            return False
        if i + count >= len(bytes):
            return False
        for j in range(1, count + 1):
            var next = Int(bytes[i + j])
            if next < 128 or next > 191:
                return False
            cp = (cp << 6) | (next & 63)
        if cp < minimum or cp > 1114111 or (cp >= 55296 and cp <= 57343):
            return False
        i += count + 1
    return True


struct JSONField(Copyable, ImplicitlyCopyable):
    var name: String
    var value: String
    var kind: String

    def __init__(out self, name: String, value: String, kind: String):
        self.name = name
        self.value = value
        self.kind = kind


struct FlatJSON:
    var source: String
    var position: Int

    def __init__(out self, source: String) raises:
        if source.byte_length() > 131072 or not valid_utf8(source):
            raise Error("JSON body exceeds limit or is not UTF-8")
        self.source = source
        self.position = 0

    def peek(self) -> Int:
        if self.position >= self.source.byte_length():
            return -1
        return Int(self.source.as_bytes()[self.position])

    def space(mut self):
        while self.peek() == 32 or self.peek() == 9 or self.peek() == 10 or self.peek() == 13:
            self.position += 1

    def take(mut self, byte: Int) raises:
        self.space()
        if self.peek() != byte:
            raise Error("Malformed JSON object")
        self.position += 1

    def hex4(mut self) raises -> Int:
        var value = 0
        for _ in range(4):
            var digit = self.peek()
            self.position += 1
            if digit >= 48 and digit <= 57:
                digit -= 48
            elif digit >= 65 and digit <= 70:
                digit -= 55
            elif digit >= 97 and digit <= 102:
                digit -= 87
            else:
                raise Error("Invalid JSON Unicode escape")
            value = value * 16 + digit
        return value

    def string(mut self) raises -> String:
        self.take(34)
        var output = List[Int8]()
        while True:
            var byte = self.peek()
            self.position += 1
            if byte == 34:
                break
            if byte < 32:
                raise Error("Unterminated JSON string or unescaped control")
            if byte != 92:
                output.append(Int8(byte))
                continue
            byte = self.peek()
            self.position += 1
            if byte == 34 or byte == 92 or byte == 47:
                output.append(Int8(byte))
            elif byte == 98:
                output.append(8)
            elif byte == 102:
                output.append(12)
            elif byte == 110:
                output.append(10)
            elif byte == 114:
                output.append(13)
            elif byte == 116:
                output.append(9)
            elif byte == 117:
                var cp = self.hex4()
                if cp >= 55296 and cp <= 56319:
                    # No whitespace may separate the surrogate pair.
                    if self.peek() != 92:
                        raise Error("Missing low surrogate")
                    self.position += 1
                    if self.peek() != 117:
                        raise Error("Missing low surrogate escape")
                    self.position += 1
                    var low = self.hex4()
                    if low < 56320 or low > 57343:
                        raise Error("Invalid low surrogate")
                    cp = 65536 + ((cp - 55296) << 10) + low - 56320
                elif cp >= 56320 and cp <= 57343:
                    raise Error("Unpaired low surrogate")
                if cp == 0:
                    raise Error("NUL is unsupported in native text requests")
                if cp < 128:
                    output.append(Int8(cp))
                elif cp < 2048:
                    output.append(Int8(192 | (cp >> 6)))
                    output.append(Int8(128 | (cp & 63)))
                elif cp < 65536:
                    output.append(Int8(224 | (cp >> 12)))
                    output.append(Int8(128 | ((cp >> 6) & 63)))
                    output.append(Int8(128 | (cp & 63)))
                else:
                    output.append(Int8(240 | (cp >> 18)))
                    output.append(Int8(128 | ((cp >> 12) & 63)))
                    output.append(Int8(128 | ((cp >> 6) & 63)))
                    output.append(Int8(128 | (cp & 63)))
            else:
                raise Error("Invalid JSON string escape")
        output.append(0)
        var result = String(unsafe_from_utf8_ptr=output.unsafe_ptr())
        _ = output
        return result

    def fields(mut self) raises -> List[JSONField]:
        self.take(123)
        self.space()
        var fields = List[JSONField]()
        if self.peek() != 125:
            while True:
                var name = self.string()
                if name.byte_length() > 64 or len(fields) >= 16:
                    raise Error("Too many JSON fields or oversized field name")
                for old in fields:
                    if old.name == name:
                        raise Error("Duplicate JSON field")
                self.take(58)
                self.space()
                var value: String
                var kind: String
                if self.peek() == 34:
                    kind = "string"
                    value = self.string()
                else:
                    kind = "number"
                    # Preserve strict JSON numeric syntax for later range checks.
                    var start = self.position
                    if self.peek() == 45:
                        self.position += 1
                    if self.peek() == 48:
                        self.position += 1
                    elif self.peek() >= 49 and self.peek() <= 57:
                        while self.peek() >= 48 and self.peek() <= 57:
                            self.position += 1
                    else:
                        raise Error("Expected JSON string or number")
                    if self.peek() == 46:
                        self.position += 1
                        var first = self.position
                        while self.peek() >= 48 and self.peek() <= 57:
                            self.position += 1
                        if self.position == first:
                            raise Error("JSON fraction requires digits")
                    if self.peek() == 101 or self.peek() == 69:
                        self.position += 1
                        if self.peek() == 43 or self.peek() == 45:
                            self.position += 1
                        var first = self.position
                        while self.peek() >= 48 and self.peek() <= 57:
                            self.position += 1
                        if self.position == first:
                            raise Error("JSON exponent requires digits")
                    if self.position - start > 64:
                        raise Error("JSON number exceeds limit")
                    value = String(self.source[byte=start:self.position])
                fields.append(JSONField(name, value, kind))
                self.space()
                if self.peek() != 44:
                    break
                self.position += 1
        self.take(125)
        self.space()
        if self.peek() != -1:
            raise Error("Trailing JSON content")
        return fields^


def constant_time_equal(left: String, right: String) -> Bool:
    # Length is not secret; scan every byte of equal-length values.
    if left.byte_length() != right.byte_length():
        return False
    var difference = UInt8(0)
    for i in range(left.byte_length()):
        difference |= left.as_bytes()[i] ^ right.as_bytes()[i]
    return difference == 0


struct LocalHTTPHead:
    var method: String
    var path: String
    var authorization: String
    var length: Int
    var status: Int

    def __init__(out self, head: String, port: Int, key: String) raises:
        self.method = ""
        self.path = ""
        self.authorization = ""
        self.length = 0
        self.status = 200
        if head.byte_length() > 8192 or not head.endswith("\r\n\r\n"):
            raise Error("Invalid HTTP header framing")
        var header_bytes = head.as_bytes()
        for i in range(len(header_bytes)):
            var byte = header_bytes[i]
            if byte == 13 and (i + 1 >= len(header_bytes) or header_bytes[i + 1] != 10):
                raise Error("Bare CR in HTTP headers")
            if byte == 10 and (i == 0 or header_bytes[i - 1] != 13):
                raise Error("Bare LF in HTTP headers")
            if byte > 126 or (byte < 32 and byte != 13 and byte != 10):
                raise Error("Unsupported HTTP header byte")
        var lines = head.split("\r\n")
        var words = String(lines[0]).split(" ")
        if len(words) != 3 or String(words[2]) != "HTTP/1.1":
            raise Error("HTTP/1.1 required")
        self.method = String(words[0])
        self.path = String(words[1])
        var seen = List[String]()
        var host = String("")
        var content_type = String("")
        for i in range(1, len(lines) - 2):
            var line = String(lines[i])
            var parts = line.split(":", 1)
            if len(parts) != 2 or len(seen) >= 64:
                raise Error("Invalid HTTP header")
            var name = String(parts[0]).lower()
            if name.byte_length() == 0:
                raise Error("Empty HTTP header name")
            for byte in name.as_bytes():
                if not ((byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) or byte == 45):
                    raise Error("Unsupported HTTP header name")
            if name in seen:
                raise Error("Duplicate HTTP header")
            seen.append(name)
            var value = String(parts[1].strip())
            if value.byte_length() > 1024 or "\r" in value or "\n" in value:
                raise Error("Invalid HTTP header value")
            if name == "host":
                host = value
            elif name == "authorization":
                self.authorization = value
            elif name == "content-length":
                self.length = bounded_decimal(value)
            elif name == "content-type":
                content_type = value
            elif name == "transfer-encoding" or name == "expect":
                raise Error("Transfer encoding and Expect are unsupported")
            elif name == "origin" or name == "referer" or name == "sec-fetch-site":
                self.status = 403
        if host != "127.0.0.1:" + String(port) and host != "localhost:" + String(port):
            self.status = 403
        if not constant_time_equal(self.authorization, "Bearer " + key):
            self.status = 401
        if self.length > 131072:
            self.status = 413
        if self.method == "POST":
            if "content-length" not in seen or self.length == 0:
                self.status = 411
            elif content_type != "application/json":
                self.status = 415
        elif self.method != "GET":
            self.status = 405
        elif self.length != 0:
            raise Error("GET body is unsupported")
