from core.checked_span import checked_span


def expect_rejection(
    start: Int, length: Int, capacity: Int, expected: String
) raises:
    var rejected = False
    try:
        _ = checked_span(start, length, capacity)
    except error:
        rejected = True
        if expected not in String(error):
            raise Error(
                "CheckedSpan rejection did not identify the invalid field"
            )
    if not rejected:
        raise Error("CheckedSpan admitted an invalid range")


def test_checked_span() raises:
    var ordinary = checked_span(3, 4, 10)
    if ordinary.start != 3 or ordinary.end != 7 or ordinary.length != 4:
        raise Error("CheckedSpan changed ordinary half-open range geometry")

    var empty = checked_span(5, 0, 10)
    if empty.start != 5 or empty.end != 5 or empty.length != 0:
        raise Error("CheckedSpan changed an interior empty range")

    var endpoint_empty = checked_span(10, 0, 10)
    if endpoint_empty.start != 10 or endpoint_empty.end != 10:
        raise Error("CheckedSpan rejected the empty capacity endpoint")

    var full = checked_span(0, 10, 10)
    if full.start != 0 or full.end != 10 or full.length != 10:
        raise Error("CheckedSpan changed the full-capacity range")

    expect_rejection(-1, 0, 10, "start must be nonnegative")
    expect_rejection(0, -1, 10, "length must be nonnegative")
    expect_rejection(0, 0, -1, "capacity must be nonnegative")
    expect_rejection(11, 0, 10, "start exceeds capacity")
    expect_rejection(8, 3, 10, "length exceeds remaining capacity")
    expect_rejection(0, Int(1) << 62, 10, "length exceeds remaining capacity")

    # Maximum signed capacity is valid when the addition is exactly bounded.
    var maximum = checked_span(
        (Int(1) << 62) - 1,
        (Int(1) << 62),
        (Int(1) << 63) - 1,
    )
    if maximum.end != (Int(1) << 63) - 1:
        raise Error("CheckedSpan rejected the maximum representable endpoint")
    print(
        "PASS: checked span range, empty policy, bounds and overflow admission"
    )


def main() raises:
    test_checked_span()
