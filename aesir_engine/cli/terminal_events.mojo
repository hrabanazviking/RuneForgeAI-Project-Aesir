"""Poll raw terminal bytes into validated editor events."""

from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from cli.chat_compose import COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES
from cli.interrupts import consume_interrupts
from cli.terminal_keys import (
    TerminalKeyDecoder, KEY_PENDING, KEY_TEXT_BYTE, KEY_ESCAPE,
    KEY_INTERRUPT, KEY_EOF, KEY_UNKNOWN,
    KEY_PASTE_START, KEY_PASTE_END, KEY_PASTE_REJECTED, KEY_IDLE,
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
    var in_paste: Bool
    var paste_match: Int
    var paste_cr: Bool
    var paste_bytes: List[Int8]
    var paste_lines: Int
    var paste_overflow: Bool

    def __init__(out self):
        self.keys = TerminalKeyDecoder()
        self.utf8 = TerminalUtf8Decoder()
        self.in_paste = False
        self.paste_match = 0
        self.paste_cr = False
        self.paste_bytes = List[Int8]()
        self.paste_lines = 1
        self.paste_overflow = False

    def _paste_append(mut self, value: String):
        if self.paste_overflow:
            return
        if value.byte_length() > COMPOSE_MAX_BYTES - len(self.paste_bytes):
            self.paste_overflow = True
            self.paste_bytes = List[Int8]()
            return
        for byte in value.as_bytes():
            self.paste_bytes.append(Int8(byte))

    def _paste_line(mut self):
        if self.paste_overflow:
            return
        if self.paste_lines >= COMPOSE_MAX_LINES:
            self.paste_overflow = True
            self.paste_bytes = List[Int8]()
            return
        self.paste_lines += 1
        self._paste_append("\n")

    def _paste_end_byte(self, index: Int) -> UInt8:
        if index == 0:
            return 27
        if index == 1:
            return 91
        if index == 2:
            return 50
        if index == 3:
            return 48
        if index == 4:
            return 49
        return 126

    def _paste_byte(mut self, byte: UInt8) -> TerminalEvent:
        """Drop escape prefixes; only a full ESC[201~ ends pasted text."""
        if byte == 3:
            self.in_paste = False
            self.paste_match = 0
            self.paste_bytes = List[Int8]()
            _ = self.utf8.flush()
            return TerminalEvent(KEY_INTERRUPT)
        if self.paste_match > 0:
            if byte == self._paste_end_byte(self.paste_match):
                self.paste_match += 1
                if self.paste_match == 6:
                    self.in_paste = False
                    self.paste_match = 0
                    _ = self.utf8.flush()
                    if self.paste_overflow:
                        self.paste_bytes = List[Int8]()
                        return TerminalEvent(KEY_PASTE_REJECTED)
                    self.paste_bytes.append(0)
                    var content = String(unsafe_from_utf8_ptr=self.paste_bytes.unsafe_ptr())
                    self.paste_bytes = List[Int8]()
                    return TerminalEvent(KEY_PASTE_END, content)
                return TerminalEvent(KEY_PENDING)
            self.paste_match = 0
        if byte == 27:
            self.paste_match = 1
            self.paste_cr = False
            _ = self.utf8.flush()
            return TerminalEvent(KEY_PENDING)
        if byte == 13:
            self.paste_cr = True
            _ = self.utf8.flush()
            self._paste_line()
            return TerminalEvent(KEY_PENDING)
        if byte == 10:
            if self.paste_cr:
                self.paste_cr = False
                return TerminalEvent(KEY_PENDING)
            _ = self.utf8.flush()
            self._paste_line()
            return TerminalEvent(KEY_PENDING)
        self.paste_cr = False
        if byte < 32 or byte == 127:
            _ = self.utf8.flush()
            return TerminalEvent(KEY_PENDING)
        var scalar = self.utf8.feed(byte)
        if scalar.status == UTF8_READY:
            self._paste_append(scalar.text)
        return TerminalEvent(KEY_PENDING)

    def next(
        mut self, interrupt_fd: Int = -1, idle_timeout_ms: Int = -1,
    ) raises -> TerminalEvent:
        if idle_timeout_ms != -1 and (idle_timeout_ms < 50 or idle_timeout_ms > 60000):
            raise Error("Terminal idle timeout must be 50..60000 ms")
        var input_byte = InlineArray[UInt8, 1](fill=0)
        while True:
            var timeout = idle_timeout_ms
            if self.keys.state != 0 and not self.in_paste:
                if timeout < 0 or timeout > 30:
                    timeout = 30
            elif self.utf8.expected != 0:
                if timeout < 0 or timeout > 250:
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
                if idle_timeout_ms >= 0:
                    return TerminalEvent(KEY_IDLE)
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
            if self.in_paste:
                var pasted = self._paste_byte(input_byte[0])
                if pasted.kind == KEY_PENDING:
                    continue
                return pasted^
            var key = self.keys.feed(input_byte[0])
            if key.kind != KEY_TEXT_BYTE:
                _ = self.utf8.flush()
            if key.kind == KEY_PENDING or key.kind == KEY_UNKNOWN:
                continue
            if key.kind == KEY_PASTE_START:
                self.in_paste = True
                self.paste_match = 0
                self.paste_cr = False
                self.paste_bytes = List[Int8]()
                self.paste_lines = 1
                self.paste_overflow = False
                return TerminalEvent(KEY_PASTE_START)
            if key.kind == KEY_PASTE_END:
                continue
            if key.kind == KEY_TEXT_BYTE:
                var scalar = self.utf8.feed(key.byte)
                if scalar.status == UTF8_READY:
                    return TerminalEvent(KEY_TEXT_BYTE, scalar.text)
                continue
            return TerminalEvent(key.kind)
