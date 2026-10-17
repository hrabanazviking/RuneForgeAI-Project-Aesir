"""Bounded UTF-8 cursor state for a future native chat editor."""

from cli.chat_compose import COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES


def _continuation(value: UInt8) -> Bool:
    return (value & 192) == 128


struct CursorDraft:
    """Keep the cursor on UTF-8 scalar boundaries, without terminal policy."""

    var content: String
    var cursor: Int

    def __init__(out self):
        self.content = ""
        self.cursor = 0

    def text(self) -> String:
        return self.content

    def insert(mut self, value: String) -> Bool:
        if value.byte_length() > COMPOSE_MAX_BYTES - self.content.byte_length():
            return False
        var lines = 1
        for byte in self.content.as_bytes():
            if byte == 10:
                lines += 1
        for byte in value.as_bytes():
            if byte == 10:
                lines += 1
        if lines > COMPOSE_MAX_LINES:
            return False
        var before = String(self.content[byte=0:self.cursor])
        var after = String(self.content[byte=self.cursor:])
        self.content = before + value + after
        self.cursor += value.byte_length()
        return True

    def move_left(mut self) -> Bool:
        if self.cursor == 0:
            return False
        var raw = self.content.as_bytes()
        self.cursor -= 1
        while self.cursor > 0 and _continuation(raw[self.cursor]):
            self.cursor -= 1
        return True

    def move_right(mut self) -> Bool:
        if self.cursor == self.content.byte_length():
            return False
        var raw = self.content.as_bytes()
        self.cursor += 1
        while self.cursor < len(raw) and _continuation(raw[self.cursor]):
            self.cursor += 1
        return True

    def erase_left(mut self) -> Bool:
        if self.cursor == 0:
            return False
        var end = self.cursor
        _ = self.move_left()
        self.content = String(self.content[byte=0:self.cursor]) + String(self.content[byte=end:])
        return True

    def move_home(mut self):
        self.cursor = 0

    def move_end(mut self):
        self.cursor = self.content.byte_length()
