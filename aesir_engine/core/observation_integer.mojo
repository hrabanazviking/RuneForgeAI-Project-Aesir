"""Strict bounded decimal parsing for kernel observations and admission."""


def bounded_decimal(text: String) raises -> Int:
    var value = 0
    if text.byte_length() == 0:
        raise Error("Expected an unsigned decimal integer")
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("Expected an unsigned decimal integer")
        var digit = Int(byte - 48)
        if value > (9223372036854775807 - digit) // 10:
            raise Error("Integer overflow")
        value = value * 10 + digit
    return value
