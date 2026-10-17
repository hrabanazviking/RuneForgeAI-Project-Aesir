"""S33i model-free terminal-mode harness."""

from std.collections import InlineArray
from std.ffi import external_call
from cli.terminal_input import TerminalRawMode, interactive_terminal_available


def main() raises:
    if not interactive_terminal_available():
        print("TTY_REQUIRED")
        return
    var mode = TerminalRawMode()
    print("RAW_READY")
    _ = external_call["fflush", Int32](Int(0))
    var byte = InlineArray[UInt8, 1](fill=0)
    if external_call["read", Int](Int(0), byte.unsafe_ptr(), Int(1)) != 1:
        raise Error("raw terminal input failed")
    if byte[0] == 101:
        raise Error("injected raw-mode failure")
    if byte[0] != 122:
        raise Error("raw terminal input was not the expected byte")
    if not mode.restore():
        raise Error("terminal mode restore failed")
    print("RESTORED")
