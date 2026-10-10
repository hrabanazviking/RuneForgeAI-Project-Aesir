"""Pure checked arithmetic for caller-bounded half-open spans."""


struct CheckedSpan(Copyable, ImplicitlyCopyable):
    """A half-open interval whose values use one caller-defined integer unit."""

    var start: Int
    var end: Int
    var length: Int

    def __init__(out self, start: Int, end: Int, length: Int):
        self.start = start
        self.end = end
        self.length = length


def checked_span(start: Int, length: Int, capacity: Int) raises -> CheckedSpan:
    """Admit [start, start+length) within capacity, allowing empty spans."""
    if capacity < 0:
        raise Error("CheckedSpan: capacity must be nonnegative")
    if start < 0:
        raise Error("CheckedSpan: start must be nonnegative")
    if length < 0:
        raise Error("CheckedSpan: length must be nonnegative")
    if start > capacity:
        raise Error("CheckedSpan: start exceeds capacity")
    if length > capacity - start:
        raise Error("CheckedSpan: length exceeds remaining capacity")
    return CheckedSpan(start, start + length, length)
