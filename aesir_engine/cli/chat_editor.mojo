"""Opt-in native interactive draft editor; model and transcript stay outside."""

from cli.chat_compose import ComposeResult
from cli.cursor_draft import CursorDraft
from cli.terminal_editor_screen import TerminalEditorScreen
from cli.terminal_events import TerminalEventReader
from cli.terminal_input import TerminalRawMode, interactive_terminal_available
from cli.terminal_view import terminal_editor_size
from cli.terminal_keys import (
    KEY_TEXT_BYTE, KEY_ENTER, KEY_NEWLINE, KEY_BACKSPACE, KEY_DELETE,
    KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_INTERRUPT, KEY_EOF,
    KEY_ESCAPE, KEY_PASTE_END, KEY_PASTE_REJECTED, KEY_IDLE,
)


def read_chat_editor(interrupt_fd: Int) raises -> ComposeResult:
    """Enter submits nonempty text; Ctrl+J adds a line; cancel discards it."""
    if not interactive_terminal_available():
        print("[/edit requires interactive stdin and stdout; use /compose here]")
        return ComposeResult("", False, False)
    var last_columns: Int
    var last_rows: Int
    try:
        var initial = terminal_editor_size()
        last_columns = initial.columns
        last_rows = initial.rows
    except error:
        print("[/edit unavailable: " + String(error) + "]")
        return ComposeResult("", False, False)
    var mode = TerminalRawMode()
    var screen = TerminalEditorScreen()
    var reader = TerminalEventReader()
    var draft = CursorDraft()
    try:
        screen.draw(draft)
    except error:
        var discarded = mode.discard_pending_input()
        screen.close()
        if not mode.restore():
            raise Error("Editor terminal mode restore failed")
        if not discarded:
            raise Error("Editor could not discard pending draft input")
        print("[Draft cancelled: " + String(error) + "]")
        return ComposeResult("", False, False)
    while True:
        var event = reader.next(interrupt_fd, 250)
        var notice = String("")
        if event.kind == KEY_IDLE:
            var changed = True
            try:
                var current = terminal_editor_size()
                changed = current.columns != last_columns or current.rows != last_rows
            except:
                pass
            if not changed:
                continue
        elif event.kind == KEY_TEXT_BYTE or event.kind == KEY_PASTE_END:
            if not draft.insert(event.text):
                notice = "Draft limit: 64 KiB / 128 lines"
        elif event.kind == KEY_PASTE_REJECTED:
            notice = "Paste rejected: 64 KiB / 128 lines"
        elif event.kind == KEY_NEWLINE:
            if not draft.insert("\n"):
                notice = "Draft limit: 64 KiB / 128 lines"
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
        elif event.kind == KEY_DELETE:
            _ = draft.erase_right()
        elif event.kind == KEY_ESCAPE or event.kind == KEY_INTERRUPT:
            var discarded = mode.discard_pending_input()
            screen.close()
            if not mode.restore():
                raise Error("Editor terminal mode restore failed")
            if not discarded:
                raise Error("Editor could not discard pending draft input")
            print("[Draft cancelled]")
            return ComposeResult("", False, False)
        elif event.kind == KEY_EOF:
            screen.close()
            if not mode.restore():
                raise Error("Editor terminal mode restore failed")
            print("[Draft cancelled at EOF]")
            return ComposeResult("", False, True)
        elif event.kind == KEY_ENTER:
            if draft.text().strip() == "":
                notice = "Draft is empty; type text or cancel"
            else:
                screen.close()
                if not mode.restore():
                    raise Error("Editor terminal mode restore failed")
                return ComposeResult(draft.text(), True, False)
        try:
            screen.draw(draft, notice)
            var shown = terminal_editor_size()
            last_columns = shown.columns
            last_rows = shown.rows
        except error:
            var discarded = mode.discard_pending_input()
            screen.close()
            if not mode.restore():
                raise Error("Editor terminal mode restore failed")
            if not discarded:
                raise Error("Editor could not discard pending draft input")
            print("[Draft cancelled: " + String(error) + "]")
            return ComposeResult("", False, False)
