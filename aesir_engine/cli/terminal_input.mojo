"""Scoped Linux raw-mode lease for future native cursor editing."""

from std.collections import InlineArray
from std.ffi import external_call


def interactive_terminal_available() -> Bool:
    return (external_call["isatty", Int32](Int32(0)) == 1
            and external_call["isatty", Int32](Int32(1)) == 1)


struct TerminalRawMode:
    """Owns one stdin termios transition; never used for redirected streams."""

    var saved: InlineArray[UInt8, 64]
    var active: Bool

    def __init__(out self) raises:
        self.saved = InlineArray[UInt8, 64](fill=0)
        self.active = False
        if not interactive_terminal_available():
            raise Error("Cursor editing requires interactive stdin and stdout")
        if external_call["tcgetattr", Int32](Int32(0), self.saved.unsafe_ptr()) != 0:
            raise Error("Cannot read terminal mode")
        var raw = InlineArray[UInt8, 64](fill=0)
        for index in range(64):
            raw[index] = self.saved[index]
        external_call["cfmakeraw", NoneType](raw.unsafe_ptr())
        if external_call["tcsetattr", Int32](Int32(0), Int32(0), raw.unsafe_ptr()) != 0:
            raise Error("Cannot enter terminal raw mode")
        self.active = True

    def restore(mut self) -> Bool:
        if not self.active:
            return True
        if external_call["tcsetattr", Int32](Int32(0), Int32(0), self.saved.unsafe_ptr()) != 0:
            return False
        self.active = False
        return True

    def __deinit__(deinit self):
        if self.active:
            _ = external_call["tcsetattr", Int32](Int32(0), Int32(0), self.saved.unsafe_ptr())
