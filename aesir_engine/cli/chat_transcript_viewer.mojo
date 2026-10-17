"""Model-free interactive transcript navigation over committed turns."""

from cli.conversation import ConversationState
from cli.terminal_editor_screen import TerminalEditorScreen
from cli.terminal_events import TerminalEventReader
from cli.terminal_input import TerminalRawMode, interactive_terminal_available
from cli.terminal_transcript_view import TranscriptPager
from cli.terminal_view import terminal_editor_size
from cli.terminal_keys import (
    KEY_TEXT_BYTE, KEY_ESCAPE, KEY_INTERRUPT, KEY_EOF, KEY_IDLE,
    KEY_DOWN, KEY_UP,
)


def read_chat_transcript(
    conversation: ConversationState, interrupt_fd: Int = -1,
) raises -> Bool:
    """Show committed history only; return false if a usable PTY is absent."""
    if not interactive_terminal_available():
        print("[Transcript view requires interactive stdin and stdout]")
        return False
    try:
        _ = terminal_editor_size()
    except error:
        print("[Transcript view unavailable: " + String(error) + "]")
        return False
    var mode = TerminalRawMode()
    var screen = TerminalEditorScreen()
    var reader = TerminalEventReader()
    var pager = TranscriptPager()
    var last_columns = 0
    var last_rows = 0
    var discard_input = False
    var failure = String("")
    try:
        while True:
            var size = terminal_editor_size()
            if (not pager.rendered or size.columns != last_columns
                    or size.rows != last_rows):
                screen.draw_rows(pager.render(conversation, size.columns, size.rows))
                last_columns = size.columns
                last_rows = size.rows
            var event = reader.next(interrupt_fd, 250)
            if event.kind == KEY_IDLE:
                continue
            if event.kind == KEY_EOF:
                break
            if event.kind == KEY_ESCAPE or event.kind == KEY_INTERRUPT:
                discard_input = True
                break
            if event.kind == KEY_TEXT_BYTE:
                if event.text == "q" or event.text == "Q":
                    discard_input = True
                    break
                if event.text == "n" or event.text == "N":
                    _ = pager.advance()
                elif event.text == "p" or event.text == "P":
                    _ = pager.back()
            elif event.kind == KEY_DOWN:
                _ = pager.advance()
            elif event.kind == KEY_UP:
                _ = pager.back()
            # Bracketed paste is inert: pasted q/n/p is never navigation.
    except error:
        discard_input = True
        failure = String(error)
    if discard_input and not mode.discard_pending_input():
        failure = "Cannot discard pending transcript keys"
    screen.close()
    if not mode.restore():
        raise Error("Transcript terminal mode restore failed")
    if failure != "":
        print("[Transcript view closed: " + failure + "]")
        return False
    return True
