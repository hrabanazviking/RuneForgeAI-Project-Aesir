"""S33k model-free terminal key sequence regressions."""

from cli.terminal_keys import (
    TerminalKeyDecoder, KEY_PENDING, KEY_TEXT_BYTE, KEY_ENTER,
    KEY_BACKSPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
    KEY_HOME, KEY_END, KEY_DELETE, KEY_ESCAPE, KEY_INTERRUPT,
    KEY_EOF, KEY_UNKNOWN, KEY_NEWLINE, KEY_PASTE_START, KEY_PASTE_END,
)


def expect(mut decoder: TerminalKeyDecoder, sequence: String, kind: Int) raises:
    var last = KEY_UNKNOWN
    for byte in sequence.as_bytes():
        last = decoder.feed(byte).kind
    if last != kind:
        raise Error("terminal key sequence classified incorrectly")


def main() raises:
    var decoder = TerminalKeyDecoder()
    expect(decoder, "a", KEY_TEXT_BYTE)
    if decoder.feed(UInt8(228)).byte != 228:
        raise Error("high UTF-8 byte was not preserved")
    expect(decoder, "\r", KEY_ENTER)
    expect(decoder, "\n", KEY_NEWLINE)
    expect(decoder, "\x7f", KEY_BACKSPACE)
    expect(decoder, "\x08", KEY_BACKSPACE)
    expect(decoder, "\x03", KEY_INTERRUPT)
    expect(decoder, "\x04", KEY_EOF)
    expect(decoder, "\x1b[A", KEY_UP)
    expect(decoder, "\x1b[B", KEY_DOWN)
    expect(decoder, "\x1b[C", KEY_RIGHT)
    expect(decoder, "\x1b[D", KEY_LEFT)
    expect(decoder, "\x1b[H", KEY_HOME)
    expect(decoder, "\x1b[F", KEY_END)
    expect(decoder, "\x1bOH", KEY_HOME)
    expect(decoder, "\x1bOF", KEY_END)
    expect(decoder, "\x1b[3~", KEY_DELETE)
    expect(decoder, "\x1b[200~", KEY_PASTE_START)
    expect(decoder, "\x1b[201~", KEY_PASTE_END)
    expect(decoder, "\x1b[202~", KEY_UNKNOWN)
    expect(decoder, "\x1b[1;5D", KEY_UNKNOWN)
    expect(decoder, "b", KEY_TEXT_BYTE)
    if decoder.feed(UInt8(27)).kind != KEY_PENDING or decoder.flush().kind != KEY_ESCAPE:
        raise Error("lone escape did not flush")
    if decoder.feed(UInt8(27)).kind != KEY_PENDING or decoder.feed(UInt8(91)).kind != KEY_PENDING:
        raise Error("incomplete CSI was not pending")
    if decoder.flush().kind != KEY_UNKNOWN or decoder.feed(UInt8(99)).kind != KEY_TEXT_BYTE:
        raise Error("incomplete CSI failed to recover")
    expect(decoder, "\x1b[12345678901234567890~", KEY_UNKNOWN)
    expect(decoder, "d", KEY_TEXT_BYTE)
    expect(decoder, "\x1b[1234567890123456~", KEY_UNKNOWN)
    expect(decoder, "e", KEY_TEXT_BYTE)
    print("terminal key decoder controls, escapes and recovery: PASS")
