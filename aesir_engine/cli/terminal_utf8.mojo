"""Incremental validated UTF-8 text for native terminal input."""

from std.collections import InlineArray


comptime UTF8_PENDING = 0
comptime UTF8_READY = 1
comptime UTF8_REJECTED = 2


struct Utf8InputResult:
    var status: Int
    var text: String

    def __init__(out self, status: Int, text: String = ""):
        self.status = status
        self.text = text


struct TerminalUtf8Decoder:
    """Build one safe scalar at a time; never emit partial UTF-8."""

    var buffer: InlineArray[UInt8, 5]
    var expected: Int
    var seen: Int
    var scalar: Int
    var minimum: Int

    def __init__(out self):
        self.buffer = InlineArray[UInt8, 5](fill=0)
        self.expected = 0
        self.seen = 0
        self.scalar = 0
        self.minimum = 0

    def reset(mut self):
        self.expected = 0
        self.seen = 0
        self.scalar = 0
        self.minimum = 0

    def flush(mut self) -> Bool:
        var incomplete = self.expected != 0
        self.reset()
        return incomplete

    def _start(mut self, byte: UInt8) -> Utf8InputResult:
        var value = Int(byte)
        if value >= 32 and value <= 126:
            self.buffer[0] = byte
            self.buffer[1] = 0
            return Utf8InputResult(UTF8_READY, String(unsafe_from_utf8_ptr=self.buffer.unsafe_ptr()))
        if value >= 194 and value <= 223:
            self.expected = 2
            self.scalar = value & 31
            self.minimum = 128
        elif value >= 224 and value <= 239:
            self.expected = 3
            self.scalar = value & 15
            self.minimum = 2048
        elif value >= 240 and value <= 244:
            self.expected = 4
            self.scalar = value & 7
            self.minimum = 65536
        else:
            return Utf8InputResult(UTF8_REJECTED)
        self.buffer[0] = byte
        self.seen = 1
        return Utf8InputResult(UTF8_PENDING)

    def feed(mut self, byte: UInt8) -> Utf8InputResult:
        if self.expected == 0:
            return self._start(byte)
        var value = Int(byte)
        if value < 128 or value > 191:
            self.reset()
            return self._start(byte)
        self.buffer[self.seen] = byte
        self.scalar = (self.scalar << 6) | (value & 63)
        self.seen += 1
        if self.seen < self.expected:
            return Utf8InputResult(UTF8_PENDING)
        var codepoint = self.scalar
        var valid = (codepoint >= self.minimum and codepoint <= 1114111
                     and not (codepoint >= 55296 and codepoint <= 57343)
                     and not (codepoint >= 128 and codepoint <= 159)
                     and codepoint != 1564
                     and codepoint != 8203
                     and codepoint != 8206
                     and codepoint != 8207
                     and not (codepoint >= 8232 and codepoint <= 8238)
                     and not (codepoint >= 8288 and codepoint <= 8303)
                     and codepoint != 65279)
        self.buffer[self.seen] = 0
        self.reset()
        if not valid:
            return Utf8InputResult(UTF8_REJECTED)
        return Utf8InputResult(UTF8_READY, String(unsafe_from_utf8_ptr=self.buffer.unsafe_ptr()))
