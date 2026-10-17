"""Bounded UTF-8 cursor state for a future native chat editor."""

from cli.chat_compose import COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES
from cli.unicode_clusters import (
    _scalar_end, _scalar_start, _scalar_value, _trailing_mark, _hard_break,
    _emoji_base, _regional_indicator, _ri_count_before, _base_before,
    _joined_emoji_end,
)


struct CursorDraft:
    """Keep the cursor on UTF-8 boundaries and attached trailing marks."""

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
        if value.byte_length() > 0 and not _hard_break(
            value, _scalar_start(value, value.byte_length()),
        ):
            while self.cursor < self.content.byte_length() and _trailing_mark(
                self.content, self.cursor,
            ):
                self.cursor = _scalar_end(self.content, self.cursor)
            var base = _base_before(self.content, self.cursor)
            if (_scalar_value(self.content, base) == 8205 and base > 0
                    and self.cursor < self.content.byte_length()
                    and _emoji_base(self.content, self.cursor)):
                var prior = _base_before(self.content, base)
                if _emoji_base(self.content, prior):
                    var joined = self.cursor
                    self.cursor = _scalar_end(self.content, joined)
                    while (self.cursor < self.content.byte_length()
                            and _trailing_mark(self.content, self.cursor)):
                        self.cursor = _scalar_end(self.content, self.cursor)
                    self.cursor = _joined_emoji_end(
                        self.content, self.cursor, joined,
                    )
            else:
                self.cursor = _joined_emoji_end(self.content, self.cursor, base)
            if self.cursor < self.content.byte_length() and _regional_indicator(
                self.content, _scalar_start(self.content, self.cursor),
            ):
                if (_ri_count_before(self.content, self.cursor) % 2 == 1
                        and _regional_indicator(self.content, self.cursor)):
                    self.cursor = _scalar_end(self.content, self.cursor)
        return True

    def move_left(mut self) -> Bool:
        if self.cursor == 0:
            return False
        var ending = self.cursor
        self.cursor = _base_before(self.content, self.cursor)
        if _regional_indicator(self.content, self.cursor):
            if _ri_count_before(self.content, ending) % 2 == 0:
                self.cursor = _scalar_start(self.content, self.cursor)
            return True
        while self.cursor > 0 and _emoji_base(self.content, self.cursor):
            var joiner = _scalar_start(self.content, self.cursor)
            if _scalar_value(self.content, joiner) != 8205 or joiner == 0:
                break
            var previous = _base_before(self.content, joiner)
            if not _emoji_base(self.content, previous):
                break
            self.cursor = previous
        return True

    def move_right(mut self) -> Bool:
        if self.cursor == self.content.byte_length():
            return False
        var break_scalar = _hard_break(self.content, self.cursor)
        var base = self.cursor
        var preceding_ri = 0
        if _regional_indicator(self.content, base):
            preceding_ri = _ri_count_before(self.content, base)
        self.cursor = _scalar_end(self.content, self.cursor)
        if not break_scalar:
            while self.cursor < self.content.byte_length() and _trailing_mark(
                self.content, self.cursor,
            ):
                self.cursor = _scalar_end(self.content, self.cursor)
            self.cursor = _joined_emoji_end(self.content, self.cursor, base)
            if (preceding_ri % 2 == 0 and _regional_indicator(self.content, base)
                    and self.cursor < self.content.byte_length()
                    and _regional_indicator(self.content, self.cursor)):
                self.cursor = _scalar_end(self.content, self.cursor)
        return True

    def erase_left(mut self) -> Bool:
        if self.cursor == 0:
            return False
        var end = self.cursor
        _ = self.move_left()
        self.content = String(self.content[byte=0:self.cursor]) + String(self.content[byte=end:])
        return True

    def erase_right(mut self) -> Bool:
        if self.cursor == self.content.byte_length():
            return False
        var start = self.cursor
        _ = self.move_right()
        var end = self.cursor
        self.content = String(self.content[byte=0:start]) + String(self.content[byte=end:])
        self.cursor = start
        return True

    def move_home(mut self):
        self.cursor = 0

    def move_end(mut self):
        self.cursor = self.content.byte_length()
