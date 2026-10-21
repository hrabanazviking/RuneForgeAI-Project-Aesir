from std.sys import argv
from smidr.dynamic_rotary_context import DynamicRotaryContext, DynamicRotaryCoefficients, validate_dynamic_context, initial_dynamic_context, select_dynamic_context, dynamic_rotary_coefficients, validate_dynamic_rotary_coefficients


def describe(value: DynamicRotaryCoefficients):
    print(value.context.reference, value.context.selected, value.context.limit,
          value.width, value.pair_index, value.theta_num, value.theta_den,
          value.gain_num, value.gain_den, value.delta_num, value.delta_den)


def main() raises:
    var a = argv()
    if len(a) < 2:
        raise Error("expected initial/select/coefficients/mutate/isolation and integer arguments")
    if a[1] == "initial":
        if len(a) != 4:
            raise Error("initial requires reference limit")
        var state = initial_dynamic_context(Int(a[2]), Int(a[3]))
        print(state.reference, state.selected, state.limit)
    elif a[1] == "select":
        if len(a) < 6 or (len(a) - 2) % 4 != 0:
            raise Error("select requires groups of reference selected limit max_position")
        for i in range(2, len(a), 4):
            var state = DynamicRotaryContext(Int(a[i]), Int(a[i+1]), Int(a[i+2]))
            var result = select_dynamic_context(state, Int(a[i+3]))
            print(result.reference, result.selected, result.limit)
    elif a[1] == "coefficients":
        if len(a) < 7 or (len(a) - 2) % 5 != 0:
            raise Error("coefficients requires groups of reference selected limit width pair_index")
        for i in range(2, len(a), 5):
            var state = DynamicRotaryContext(Int(a[i]), Int(a[i+1]), Int(a[i+2]))
            var value = dynamic_rotary_coefficients(state, Int(a[i+3]), Int(a[i+4]))
            validate_dynamic_rotary_coefficients(value)
            describe(value)
    elif a[1] == "mutate":
        if len(a) != 3:
            raise Error("mutate requires field selector")
        var state = DynamicRotaryContext(8, 17, 64)
        var value = dynamic_rotary_coefficients(state, 8, 2)
        var field = Int(a[2])
        if field == 0:
            value.context.reference = 0
        elif field == 1:
            value.context.selected = 0
        elif field == 2:
            value.context.limit = 0
        elif field == 3:
            value.width = 7
        elif field == 4:
            value.pair_index = -1
        elif field == 5:
            value.theta_num += 1
        elif field == 6:
            value.theta_den += 1
        elif field == 7:
            value.gain_num += 1
        elif field == 8:
            value.gain_den += 1
        elif field == 9:
            value.delta_num += 1
        elif field == 10:
            value.delta_den += 1
        else:
            raise Error("unknown mutation field")
        validate_dynamic_rotary_coefficients(value)
        raise Error("INVALID: mutation accepted")
    elif a[1] == "isolation":
        if len(a) != 2:
            raise Error("isolation takes no arguments")
        var input = initial_dynamic_context(8, 64)
        var result = select_dynamic_context(input, 16)
        var value = dynamic_rotary_coefficients(result, 2, 0)
        var owner = value.copy()
        input.reference = 0
        result.selected = 0
        value.context.limit = 0
        validate_dynamic_rotary_coefficients(owner)
        for _ in range(11):
            var bad = owner.copy()
            bad.delta_den = 0
            var refused = False
            try:
                validate_dynamic_rotary_coefficients(bad)
            except:
                refused = True
            if not refused:
                raise Error("invalid schedule accepted during recovery")
            validate_dynamic_rotary_coefficients(owner)
        describe(owner)
    else:
        raise Error("unknown mode")
