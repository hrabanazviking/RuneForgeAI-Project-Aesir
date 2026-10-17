"""Bounded UTF-8 cursor state for a future native chat editor."""

from cli.chat_compose import COMPOSE_MAX_BYTES, COMPOSE_MAX_LINES


def _continuation(value: UInt8) -> Bool:
    return (value & 192) == 128


def _scalar_end(text: String, start: Int) -> Int:
    var raw = text.as_bytes()
    var end = start + 1
    while end < len(raw) and _continuation(raw[end]):
        end += 1
    return end


def _scalar_start(text: String, end: Int) -> Int:
    var raw = text.as_bytes()
    var start = end - 1
    while start > 0 and _continuation(raw[start]):
        start -= 1
    return start


def _scalar_value(text: String, start: Int) -> Int:
    """Decode only enough UTF-8 to classify a trailing mark; fail closed."""
    var raw = text.as_bytes()
    var first = Int(raw[start])
    if first < 128:
        return first
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
    if width == 0 or start + width > len(raw):
        return -1
    for offset in range(1, width):
        var next_byte = Int(raw[start + offset])
        if next_byte < 128 or next_byte > 191:
            return -1
        scalar = (scalar << 6) | (next_byte & 63)
    if (width == 2 and scalar < 128
            or width == 3 and scalar < 2048
            or width == 4 and scalar < 65536
            or scalar > 1114111
            or scalar >= 55296 and scalar <= 57343):
        return -1
    return scalar


def _trailing_mark(text: String, start: Int) -> Bool:
    var scalar = _scalar_value(text, start)
    return (scalar >= 768 and scalar <= 879
            or scalar >= 6832 and scalar <= 6911
            or scalar >= 7616 and scalar <= 7679
            or scalar >= 8400 and scalar <= 8447
            or scalar >= 65024 and scalar <= 65039
            or scalar >= 65056 and scalar <= 65071
            or scalar >= 127995 and scalar <= 127999)


def _hard_break(text: String, start: Int) -> Bool:
    var scalar = _scalar_value(text, start)
    return scalar >= 0 and (scalar < 32 or scalar == 127)


def _emoji_base(text: String, start: Int) -> Bool:
    var scalar = _scalar_value(text, start)
    return (scalar >= 9728 and scalar <= 10175
            or (scalar >= 126976 and scalar <= 129791
                and not (scalar >= 127462 and scalar <= 127487)))


def _regional_indicator(text: String, start: Int) -> Bool:
    var scalar = _scalar_value(text, start)
    return scalar >= 127462 and scalar <= 127487


def _ri_count_before(text: String, end: Int) -> Int:
    var count = 0
    var position = end
    while position > 0:
        var previous = _scalar_start(text, position)
        if not _regional_indicator(text, previous):
            break
        count += 1
        position = previous
    return count


def _base_before(text: String, end: Int) -> Int:
    var start = _scalar_start(text, end)
    while start > 0 and _trailing_mark(text, start):
        var previous = _scalar_start(text, start)
        if _hard_break(text, previous):
            break
        start = previous
    return start


def _joined_emoji_end(text: String, end: Int, base: Int) -> Int:
    var current_end = end
    var current_base = base
    while _emoji_base(text, current_base) and current_end < text.byte_length():
        if _scalar_value(text, current_end) != 8205:
            break
        var joined = _scalar_end(text, current_end)
        if joined == text.byte_length() or not _emoji_base(text, joined):
            break
        current_base = joined
        current_end = _scalar_end(text, joined)
        while (current_end < text.byte_length()
                and _trailing_mark(text, current_end)):
            current_end = _scalar_end(text, current_end)
    return current_end


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
