# HAILBRU parsing utilities (H061+). Pure functions, no OS, no hardware.

from hailbru.errors import herror


def is_hex_digit(b: UInt8) -> Bool:
    var c = Int(b)
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102)


def hex_val(b: UInt8) -> Int:
    var c = Int(b)
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 65 and c <= 70:
        return c - 55
    return c - 87


def trim(s: String) -> String:
    # Strip ASCII whitespace (space, \t, \n, \r) from both ends.
    var bs = List[UInt8]()
    for b in s.bytes():
        bs.append(b)
    var lo = 0
    var hi = len(bs)
    while lo < hi:
        var c = bs[lo]
        if c == 32 or c == 9 or c == 10 or c == 13:
            lo += 1
        else:
            break
    while hi > lo:
        var c = bs[hi - 1]
        if c == 32 or c == 9 or c == 10 or c == 13:
            hi -= 1
        else:
            break
    var out = String("")
    for i in range(lo, hi):
        out += String(chr(Int(bs[i])))
    return out


def parse_u64_hex(s: String) raises -> UInt64:
    # Accepts "0x..." or bare hex; raises BadSysfs on garbage.
    var t = trim(s)
    var bs = List[UInt8]()
    for b in t.bytes():
        bs.append(b)
    var i = 0
    if len(bs) >= 2 and bs[0] == 48 and (bs[1] == 120 or bs[1] == 88):
        i = 2
    if i >= len(bs):
        raise herror("BadSysfs", "empty hex value in '" + s + "'")
    var v = UInt64(0)
    for j in range(i, len(bs)):
        if not is_hex_digit(bs[j]):
            raise herror(
                "BadSysfs", "bad hex digit in '" + s + "'"
            )
        v = (v << UInt64(4)) | UInt64(hex_val(bs[j]))
    return v


def parse_u16_hex(s: String) raises -> UInt16:
    var v = parse_u64_hex(s)
    if v > UInt64(0xFFFF):
        raise herror("BadSysfs", "hex value out of u16 range: '" + s + "'")
    return UInt16(v)


def parse_u64_dec(s: String) raises -> UInt64:
    var t = trim(s)
    var v = UInt64(0)
    var any_digit = False
    for b in t.bytes():
        var c = Int(b)
        if c < 48 or c > 57:
            raise herror("BadSysfs", "bad decimal digit in '" + s + "'")
        v = v * UInt64(10) + UInt64(c - 48)
        any_digit = True
    if not any_digit:
        raise herror("BadSysfs", "empty decimal value in '" + s + "'")
    return v


def is_power_of_two(v: UInt64) -> Bool:
    return v != UInt64(0) and (v & (v - UInt64(1))) == UInt64(0)


def split_lines(s: String) -> List[String]:
    var out = List[String]()
    var cur = String("")
    for b in s.bytes():
        if b == 10:
            out.append(cur)
            cur = String("")
        else:
            cur += String(chr(Int(b)))
    out.append(cur)
    return out^


def split_ws(s: String) -> List[String]:
    # Split on ASCII whitespace runs.
    var out = List[String]()
    var cur = String("")
    for b in s.bytes():
        var c = Int(b)
        if c == 32 or c == 9 or c == 10 or c == 13:
            if cur.byte_length() > 0:
                out.append(cur)
                cur = String("")
        else:
            cur += String(chr(c))
    if cur.byte_length() > 0:
        out.append(cur)
    return out^
