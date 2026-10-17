"""Poll raw terminal bytes into validated editor events."""

from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from cli.interrupts import consume_interrupts
from cli.terminal_keys import (
    TerminalKeyDecoder, KEY_PENDING, KEY_TEXT_BYTE, KEY_ESCAPE,
    KEY_INTERRUPT, KEY_EOF, KEY_UNKNOWN,
)
from cli.terminal_utf8 import TerminalUtf8Decoder, UTF8_READY


struct TerminalEvent:
    var kind: Int
    var text: String

    def __init__(out self, kind: Int, text: String = ""):
        self.kind = kind
        self.text = text


struct TerminalEventReader:
    """Owns decoding state, not the terminal lease or conversation."""

    var keys: TerminalKeyDecoder
    var utf8: TerminalUtf8Decoder

    def __init__(out self):
        self.keys = TerminalKeyDecoder()
        self.utf8 = TerminalUtf8Decoder()

    def next(mut self, interrupt_fd: Int = -1) raises -> TerminalEvent:
        var input_byte = InlineArray[UInt8, 1](fill=0)
        while True:
            var timeout = -1
            if self.keys.state != 0:
                timeout = 30
            elif self.utf8.expected != 0:
                timeout = 250
            var descriptors = InlineArray[UInt64, 2](fill=0)
            descriptors[0] = UInt64(1) << 32
            var count = UInt64(1)
            if interrupt_fd >= 0:
                descriptors[1] = UInt64(UInt32(interrupt_fd)) | (UInt64(1) << 32)
                count = 2
            var ready = external_call["poll", Int32](descriptors.unsafe_ptr(), count, Int32(timeout))
            if ready < 0:
                if external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() == 4:
                    continue
                raise Error("Terminal editor input poll failed")
            if ready == 0:
                if self.keys.state != 0:
                    var pending = self.keys.flush()
                    _ = self.utf8.flush()
                    if pending.kind == KEY_ESCAPE:
                        return TerminalEvent(KEY_ESCAPE)
                elif self.utf8.expected != 0:
                    _ = self.utf8.flush()
                continue
            if interrupt_fd >= 0 and descriptors[1] >> 48 != 0:
                _ = consume_interrupts(interrupt_fd)
                _ = self.utf8.flush()
                return TerminalEvent(KEY_INTERRUPT)
            var bytes_read = external_call["read", Int](Int(0), input_byte.unsafe_ptr(), Int(1))
            if bytes_read < 0:
                if external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() == 4:
                    continue
                raise Error("Terminal editor input read failed")
            if bytes_read == 0:
                _ = self.utf8.flush()
                return TerminalEvent(KEY_EOF)
            var key = self.keys.feed(input_byte[0])
            if key.kind != KEY_TEXT_BYTE:
                _ = self.utf8.flush()
            if key.kind == KEY_PENDING or key.kind == KEY_UNKNOWN:
                continue
            if key.kind == KEY_TEXT_BYTE:
                var scalar = self.utf8.feed(key.byte)
                if scalar.status == UTF8_READY:
                    return TerminalEvent(KEY_TEXT_BYTE, scalar.text)
                continue
            return TerminalEvent(key.kind)
