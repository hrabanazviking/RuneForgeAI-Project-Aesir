"""S33l model-free incremental UTF-8 terminal input regressions."""

from cli.terminal_utf8 import TerminalUtf8Decoder, UTF8_PENDING, UTF8_READY, UTF8_REJECTED


def expect_text(mut decoder: TerminalUtf8Decoder, value: String) raises:
    var raw = value.as_bytes()
    for index in range(len(raw)):
        var result = decoder.feed(raw[index])
        if index + 1 < len(raw):
            if result.status != UTF8_PENDING:
                raise Error("UTF-8 scalar emitted before final byte")
        elif result.status != UTF8_READY or result.text != value:
            raise Error("valid UTF-8 scalar changed")


def main() raises:
    var decoder = TerminalUtf8Decoder()
    expect_text(decoder, "A")
    expect_text(decoder, "é")
    expect_text(decoder, "世")
    expect_text(decoder, "🛡")
    expect_text(decoder, "́")
    if (decoder.feed(UInt8(0)).status != UTF8_REJECTED
            or decoder.feed(UInt8(27)).status != UTF8_REJECTED
            or decoder.feed(UInt8(127)).status != UTF8_REJECTED):
        raise Error("ASCII terminal control was accepted as draft text")
    if decoder.feed(UInt8(128)).status != UTF8_REJECTED:
        raise Error("stray continuation was accepted")
    if decoder.feed(UInt8(192)).status != UTF8_REJECTED:
        raise Error("overlong lead was accepted")
    if decoder.feed(UInt8(195)).status != UTF8_PENDING:
        raise Error("valid lead was not pending")
    if decoder.feed(UInt8(40)).text != "(":
        raise Error("ASCII after malformed continuation was lost")
    if decoder.feed(UInt8(226)).status != UTF8_PENDING or not decoder.flush():
        raise Error("truncated scalar was not discarded")
    expect_text(decoder, "Z")
    _ = decoder.feed(UInt8(224))
    _ = decoder.feed(UInt8(128))
    if decoder.feed(UInt8(128)).status != UTF8_REJECTED:
        raise Error("overlong three-byte scalar was accepted")
    _ = decoder.feed(UInt8(237))
    _ = decoder.feed(UInt8(160))
    if decoder.feed(UInt8(128)).status != UTF8_REJECTED:
        raise Error("surrogate scalar was accepted")
    _ = decoder.feed(UInt8(244))
    _ = decoder.feed(UInt8(144))
    _ = decoder.feed(UInt8(128))
    if decoder.feed(UInt8(128)).status != UTF8_REJECTED:
        raise Error("out-of-range scalar was accepted")
    _ = decoder.feed(UInt8(194))
    if decoder.feed(UInt8(128)).status != UTF8_REJECTED:
        raise Error("C1 terminal control was accepted")
    _ = decoder.feed(UInt8(226))
    _ = decoder.feed(UInt8(128))
    if decoder.feed(UInt8(174)).status != UTF8_REJECTED:
        raise Error("bidi override was accepted")
    _ = decoder.feed(UInt8(226))
    _ = decoder.feed(UInt8(129))
    if decoder.feed(UInt8(166)).status != UTF8_REJECTED:
        raise Error("bidi isolate was accepted")
    _ = decoder.feed(UInt8(226))
    _ = decoder.feed(UInt8(128))
    if decoder.feed(UInt8(141)).status != UTF8_READY:
        raise Error("emoji zero-width joiner was rejected")
    expect_text(decoder, "界")
    if decoder.flush():
        raise Error("empty decoder reported an incomplete scalar")
    print("terminal UTF-8 assembly, rejection and recovery: PASS")
