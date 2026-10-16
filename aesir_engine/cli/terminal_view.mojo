"""Small Linux terminal presentation observations shared by CLI views."""

from std.collections import InlineArray
from std.ffi import external_call


def terminal_columns() -> Int:
    """Re-read PTY width; redirected output gets an 80-column layout."""
    var window = InlineArray[UInt16, 4](fill=0)
    if external_call["ioctl", Int32](Int32(1), UInt64(21523), window.unsafe_ptr()) != 0:
        return 80
    var columns = Int(window[1])
    if columns < 24:
        return 24
    if columns > 240:
        return 240
    return columns
