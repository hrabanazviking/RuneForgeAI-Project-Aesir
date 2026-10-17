"""Small Linux terminal presentation observations shared by CLI views."""

from std.collections import InlineArray
from std.ffi import external_call


struct PreviewAtom:
    var fragment: String
    var byte_count: Int
    var cells: Int

    def __init__(out self, fragment: String, byte_count: Int, cells: Int):
        self.fragment = fragment
        self.byte_count = byte_count
        self.cells = cells


def terminal_preview_atom(text: String, index: Int) raises -> PreviewAtom:
    """One sanitized scalar; non-ASCII display is charged two cells."""
    var raw = text.as_bytes()
    var first = Int(raw[index])
    if first < 128:
        if first >= 32 and first < 127:
            return PreviewAtom(String(text[byte=index:index + 1]), 1, 1)
        return PreviewAtom(" ", 1, 1)
    var width = 0
    var scalar = 0
    if first >= 194 and first <= 223:
        width = 2
        scalar = first & 31
    elif first >= 224 and first <= 239:
        width = 3
        scalar = first & 15
    elif first >= 240 and first <= 244:
        width = 4
        scalar = first & 7
    var valid = width > 0 and index + width <= len(raw)
    if valid:
        for offset in range(1, width):
            var next_byte = Int(raw[index + offset])
            if next_byte < 128 or next_byte > 191:
                valid = False
                break
            scalar = (scalar << 6) | (next_byte & 63)
        if (width == 2 and scalar < 128
                or width == 3 and scalar < 2048
                or width == 4 and scalar < 65536
                or scalar > 1114111
                or scalar >= 55296 and scalar <= 57343):
            valid = False
    if not valid:
        return PreviewAtom("?", 1, 1)
    if (scalar >= 128 and scalar <= 159
            or scalar == 1564
            or scalar >= 8203 and scalar <= 8207
            or scalar >= 8232 and scalar <= 8238
            or scalar >= 8288 and scalar <= 8303
            or scalar == 65279):
        return PreviewAtom(" ", width, 1)
    return PreviewAtom(String(text[byte=index:index + width]), width, 2)


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
