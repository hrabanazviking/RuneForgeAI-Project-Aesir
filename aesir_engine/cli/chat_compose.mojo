"""Bounded line-mode drafts for interactive native chat only."""

from std.ffi import external_call
from cli.interrupts import read_interruptible_line_result


comptime COMPOSE_MAX_LINES = 128
comptime COMPOSE_MAX_BYTES = 65536


struct ChatDraft:
    var lines: List[String]
    var bytes_used: Int

    def __init__(out self):
        self.lines = List[String]()
        self.bytes_used = 0

    def append(mut self, line: String) -> Bool:
        var separator = 0 if len(self.lines) == 0 else 1
        if len(self.lines) >= COMPOSE_MAX_LINES or line.byte_length() > COMPOSE_MAX_BYTES - self.bytes_used - separator:
            return False
        self.lines.append(line)
        self.bytes_used += line.byte_length() + separator
        return True

    def undo(mut self) -> Bool:
        if len(self.lines) == 0:
            return False
        var removed = self.lines.pop()
        self.bytes_used -= removed.byte_length()
        if len(self.lines) > 0:
            self.bytes_used -= 1
        return True

    def prompt(self) -> String:
        var result = String("")
        for i in range(len(self.lines)):
            if i > 0:
                result += "\n"
            result += self.lines[i]
        return result


struct ComposeResult:
    var text: String
    var submitted: Bool
    var eof: Bool

    def __init__(out self, text: String, submitted: Bool, eof: Bool):
        self.text = text
        self.submitted = submitted
        self.eof = eof


def read_chat_compose(interrupt_fd: Int) raises -> ComposeResult:
    """Only /send commits a draft; EOF/interrupt/cancel discard it."""
    var draft = ChatDraft()
    print("[Compose: one line at a time; /send, /undo, /cancel. Blank lines are kept; // escapes a command. Max 128 lines / 64 KiB.]")
    while True:
        print("... ", end="")
        _ = external_call["fflush", Int32](Int(0))
        var line = read_interruptible_line_result(interrupt_fd)
        if line.interrupted:
            print("\n[Draft cancelled by interrupt]")
            return ComposeResult("", False, False)
        if line.eof:
            print("\n[Draft cancelled at EOF]")
            return ComposeResult("", False, True)
        if line.text == "/cancel":
            print("[Draft cancelled]")
            return ComposeResult("", False, False)
        if line.text == "/undo":
            if draft.undo():
                print("[Last line removed]")
            else:
                print("[Draft is empty]")
            continue
        if line.text == "/send":
            var prompt = draft.prompt()
            if prompt.strip() == "":
                print("[Draft is empty; add text or /cancel]")
                continue
            return ComposeResult(prompt, True, False)
        var content = line.text
        if content.startswith("//"):
            var escaped = String(content[byte=1:])
            content = escaped
        if not draft.append(content):
            print("[Draft limit reached; /undo, /send or /cancel]")
