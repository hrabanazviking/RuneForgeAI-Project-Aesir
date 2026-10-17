"""Pure bounded UTF-8 cluster boundaries shared by native CLI views."""


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
