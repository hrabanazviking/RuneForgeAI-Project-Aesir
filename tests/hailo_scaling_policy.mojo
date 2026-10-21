from std.sys import argv
from smidr.tools.hrpc_program import _uint64
from smidr.source_scalars import ScalarWord
from smidr.scaling_policy import DecoderScalingPolicy, validate_scaling_policy
from smidr.tools.scaling_policy import describe_scaling_policy


def main() raises:
    var a = argv()
    if len(a) != 8:
        raise Error("expected kind width bits origin provenance work source_work")
    var input = DecoderScalingPolicy(a[1], ScalarWord(Int(a[2]), _uint64(a[3])), a[4], a[5], Int(a[6]))
    var charge = validate_scaling_policy(input, Int(a[7]))
    var owner = input.copy()
    input.kind = "changed"
    input.factor.bits = 0
    input.origin = "changed"
    input.provenance = "changed"
    input.work = 0
    if validate_scaling_policy(owner, Int(a[7])) != charge:
        raise Error("scaling policy copy aliases caller state")
    print(describe_scaling_policy(owner, charge))
