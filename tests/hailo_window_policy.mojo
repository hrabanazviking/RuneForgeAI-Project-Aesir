from std.sys import argv
from smidr.window_policy import DecoderWindowPolicy, validate_window_policy
from smidr.tools.window_policy import parse_window_widths, describe_window_policy


def main() raises:
    var a = argv()
    if len(a) != 7:
        raise Error("expected widths origin provenance work layers source_work")
    var input = DecoderWindowPolicy(parse_window_widths(a[1]), a[2], a[3], Int(a[4]))
    var charge = validate_window_policy(input, Int(a[5]), Int(a[6]))
    var owner = input.copy()
    input.windows[0] = -1
    input.origin = "changed"
    input.provenance = "changed"
    input.work = 1
    if validate_window_policy(owner, Int(a[5]), Int(a[6])) != charge:
        raise Error("policy copy aliases caller state")
    print(describe_window_policy(owner, charge))
