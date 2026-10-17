"""S33m model-free real-PTY event and draft harness."""

from std.ffi import external_call
from cli.cursor_draft import CursorDraft
from cli.terminal_input import TerminalRawMode, interactive_terminal_available
from cli.terminal_events import TerminalEventReader
from cli.terminal_keys import (
    KEY_TEXT_BYTE, KEY_ENTER, KEY_BACKSPACE, KEY_LEFT, KEY_RIGHT,
    KEY_HOME, KEY_END, KEY_INTERRUPT, KEY_EOF,
)


def main() raises:
    if not interactive_terminal_available():
        print("TTY_REQUIRED")
        return
    var mode = TerminalRawMode()
    var reader = TerminalEventReader()
    var rejected_busy_poll = False
    try:
        _ = reader.next(-1, 0)
    except:
        rejected_busy_poll = True
    if not rejected_busy_poll:
        raise Error("Terminal event reader accepted a zero-timeout busy loop")
    var draft = CursorDraft()
    print("EVENT_READY")
    _ = external_call["fflush", Int32](Int(0))
    while True:
        var event = reader.next()
        if event.kind == KEY_TEXT_BYTE:
            _ = draft.insert(event.text)
        elif event.kind == KEY_LEFT:
            _ = draft.move_left()
        elif event.kind == KEY_RIGHT:
            _ = draft.move_right()
        elif event.kind == KEY_HOME:
            draft.move_home()
        elif event.kind == KEY_END:
            draft.move_end()
        elif event.kind == KEY_BACKSPACE:
            _ = draft.erase_left()
        elif event.kind == KEY_INTERRUPT or event.kind == KEY_EOF:
            if not mode.restore():
                raise Error("PTY mode was not restored after cancellation")
            print("CANCELLED")
            return
        elif event.kind == KEY_ENTER:
            if not mode.restore():
                raise Error("PTY mode was not restored after submission")
            print("SUBMITTED=" + draft.text())
            return
