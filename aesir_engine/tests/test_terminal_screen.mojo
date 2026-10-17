"""S33o model-free, real-PTY alternate-screen editor harness."""

from std.ffi import external_call
from cli.cursor_draft import CursorDraft
from cli.terminal_editor_screen import TerminalEditorScreen
from cli.terminal_events import TerminalEventReader
from cli.terminal_input import TerminalRawMode, interactive_terminal_available
from cli.terminal_keys import (
    KEY_TEXT_BYTE, KEY_ENTER, KEY_NEWLINE, KEY_BACKSPACE,
    KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_INTERRUPT, KEY_EOF,
    KEY_ESCAPE,
)


def main() raises:
    if not interactive_terminal_available():
        print("TTY_REQUIRED")
        return
    var mode = TerminalRawMode()
    var screen = TerminalEditorScreen()
    var reader = TerminalEventReader()
    var draft = CursorDraft()
    screen.draw(draft)
    print("SCREEN_READY")
    _ = external_call["fflush", Int32](Int(0))
    while True:
        var event = reader.next()
        if event.kind == KEY_TEXT_BYTE:
            _ = draft.insert(event.text)
        elif event.kind == KEY_NEWLINE:
            _ = draft.insert("\n")
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
        elif event.kind == KEY_ESCAPE:
            raise Error("injected editor failure")
        elif event.kind == KEY_INTERRUPT or event.kind == KEY_EOF:
            screen.close()
            if not mode.restore():
                raise Error("editor terminal mode restore failed")
            print("CANCELLED")
            return
        elif event.kind == KEY_ENTER:
            screen.close()
            if not mode.restore():
                raise Error("editor terminal mode restore failed")
            print("SUBMITTED=" + draft.text())
            return
        screen.draw(draft)
