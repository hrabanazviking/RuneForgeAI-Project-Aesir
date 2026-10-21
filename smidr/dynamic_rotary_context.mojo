# Original integer coefficient scheduling; no floating model or device execution.


@fieldwise_init
struct DynamicRotaryContext(Copyable, Movable):
    var reference: Int
    var selected: Int
    var limit: Int


def validate_dynamic_context(state: DynamicRotaryContext) raises:
    if state.reference <= 0 or state.selected < state.reference or state.limit < state.selected:
        raise Error("DynamicRotaryContext: require 1 <= reference <= selected <= limit")


def initial_dynamic_context(reference: Int, limit: Int) raises -> DynamicRotaryContext:
    var result = DynamicRotaryContext(reference, reference, limit)
    validate_dynamic_context(result)
    return result^


def select_dynamic_context(state: DynamicRotaryContext, max_position: Int) raises -> DynamicRotaryContext:
    validate_dynamic_context(state)
    if max_position < 0 or max_position >= state.limit:
        raise Error("DynamicRotaryContext: maximum position outside explicit index bound")
    var observed = max_position + 1
    var selected = state.reference if observed < state.reference else max(state.selected, observed)
    return DynamicRotaryContext(state.reference, selected, state.limit)


@fieldwise_init
struct DynamicRotaryCoefficients(Copyable, Movable):
    var context: DynamicRotaryContext
    var width: Int
    var pair_index: Int
    var theta_num: Int
    var theta_den: Int
    var gain_num: Int
    var gain_den: Int
    var delta_num: Int
    var delta_den: Int


def dynamic_rotary_coefficients(context: DynamicRotaryContext, width: Int,
                                pair_index: Int) raises -> DynamicRotaryCoefficients:
    validate_dynamic_context(context)
    if width < 2 or width % 2 != 0 or pair_index < 0 or pair_index >= width // 2:
        raise Error("DynamicRotaryCoefficients: even width and bounded pair index required")
    var numerator = -(2 * pair_index)
    var theta_den = 1 if pair_index == 0 else width
    var gain_den = 1 if pair_index == 0 else width - 2
    return DynamicRotaryCoefficients(context.copy(), width, pair_index, numerator,
                                    theta_den, numerator, gain_den,
                                    context.selected - context.reference, context.reference)


def validate_dynamic_rotary_coefficients(value: DynamicRotaryCoefficients) raises:
    var expected = dynamic_rotary_coefficients(value.context, value.width, value.pair_index)
    if value.theta_num != expected.theta_num or value.theta_den != expected.theta_den or value.gain_num != expected.gain_num or value.gain_den != expected.gain_den or value.delta_num != expected.delta_num or value.delta_den != expected.delta_den:
        raise Error("DynamicRotaryCoefficients: canonical rational schedule changed")
