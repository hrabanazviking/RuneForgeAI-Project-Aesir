"""Shared bounded NUL-free UTF-8 admission for persisted text records."""


@always_inline
def _is_utf8_continuation(value: Int) -> Bool:
    return value >= 128 and value <= 191


def validate_utf8_bytes(source: List[Byte], label: String) raises:
    """Rejects NUL, truncation, overlong forms, surrogates, and out-of-range UTF-8."""
    for index in range(len(source)):
        if source[index] == 0:
            raise Error(label + " contains a NUL byte at offset " + String(index))

    var index = 0
    while index < len(source):
        var first = Int(source[index])
        if first <= 127:
            index += 1
            continue
        if first >= 194 and first <= 223:
            if index + 1 >= len(source) or not _is_utf8_continuation(Int(source[index + 1])):
                raise Error(label + " contains malformed UTF-8 at offset " + String(index))
            index += 2
            continue
        if first >= 224 and first <= 239:
            if index + 2 >= len(source):
                raise Error(label + " contains truncated UTF-8 at offset " + String(index))
            var second = Int(source[index + 1])
            var third = Int(source[index + 2])
            var valid_second = _is_utf8_continuation(second)
            if first == 224:
                valid_second = second >= 160 and second <= 191
            elif first == 237:
                valid_second = second >= 128 and second <= 159
            if not valid_second or not _is_utf8_continuation(third):
                raise Error(label + " contains malformed UTF-8 at offset " + String(index))
            index += 3
            continue
        if first >= 240 and first <= 244:
            if index + 3 >= len(source):
                raise Error(label + " contains truncated UTF-8 at offset " + String(index))
            var second = Int(source[index + 1])
            var third = Int(source[index + 2])
            var fourth = Int(source[index + 3])
            var valid_second = _is_utf8_continuation(second)
            if first == 240:
                valid_second = second >= 144 and second <= 191
            elif first == 244:
                valid_second = second >= 128 and second <= 143
            if (not valid_second or not _is_utf8_continuation(third)
                    or not _is_utf8_continuation(fourth)):
                raise Error(label + " contains malformed UTF-8 at offset " + String(index))
            index += 4
            continue
        raise Error(label + " contains malformed UTF-8 at offset " + String(index))


def admit_text_bytes(
    source: List[Byte], label: String, max_bytes: Int,
    allow_empty: Bool = False,
) raises -> String:
    """Validates raw persisted bytes before constructing a Mojo String."""
    if max_bytes <= 0:
        raise Error("text admission limit must be positive")
    if len(source) == 0 and not allow_empty:
        raise Error(label + " is empty")
    if len(source) > max_bytes:
        raise Error(label + " exceeds " + String(max_bytes) + " bytes")
    validate_utf8_bytes(source, label)
    var terminated = List[Byte]()
    for byte in source:
        terminated.append(byte)
    terminated.append(0)
    return String(unsafe_from_utf8_ptr=terminated.unsafe_ptr())
