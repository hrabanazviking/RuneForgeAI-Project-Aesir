"""Scoped alternate-screen output for the native draft view."""

from std.ffi import external_call
from std.memory import Pointer
from cli.cursor_draft import CursorDraft
from cli.terminal_editor_view import render_editor_rows
from cli.terminal_input import interactive_terminal_available
from cli.terminal_view import terminal_editor_size


def _write_terminal(value: String) raises:
    var raw = value.as_bytes()
    var offset = 0
    while offset < len(raw):
        var count = external_call["write", Int](Int(1), raw.unsafe_ptr().unsafe_offset(offset), len(raw) - offset)
        if count < 0:
            if external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() == 4:
                continue
            raise Error("Terminal editor output failed")
        if count == 0:
            raise Error("Terminal editor output stalled")
        offset += count


struct TerminalEditorScreen:
    """Owns only the alternate screen and hidden physical cursor."""

    var active: Bool

    def __init__(out self) raises:
        self.active = False
        if not interactive_terminal_available():
            raise Error("Terminal editor screen requires interactive streams")
        self.active = True
        _write_terminal("\x1b[?1049h\x1b[?25l\x1b[?2004h")

    def draw(self, draft: CursorDraft, notice: String = "") raises:
        var size = terminal_editor_size()
        var rows = render_editor_rows(draft, size.columns, size.rows, notice)
        var frame = String("\x1b[H\x1b[2J")
        for index in range(len(rows)):
            frame += "\x1b[" + String(index + 1) + ";1H\x1b[2K" + rows[index]
        _write_terminal(frame)

    def close(mut self) raises:
        if not self.active:
            return
        _write_terminal("\x1b[?2004l\x1b[?25h\x1b[?1049l")
        self.active = False

    def __deinit__(deinit self):
        if self.active:
            var ending = String("\x1b[?2004l\x1b[?25h\x1b[?1049l")
            var raw = ending.as_bytes()
            var offset = 0
            while offset < len(raw):
                var count = external_call["write", Int](
                    Int(1), raw.unsafe_ptr().unsafe_offset(offset), len(raw) - offset,
                )
                if count > 0:
                    offset += count
                elif count < 0 and external_call[
                    "__errno_location", Pointer[Int32, MutUntrackedOrigin]
                ]().unsafe_load() == 4:
                    continue
                else:
                    break
