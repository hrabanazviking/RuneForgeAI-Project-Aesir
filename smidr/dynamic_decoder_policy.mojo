# Original source-neutral compiler declarations, never cache-data execution.
from smidr.source_scalars import ScalarWord, validate_scalar_word, same_scalar_word
from smidr.dynamic_rotary_context import DynamicRotaryContext, validate_dynamic_context, select_dynamic_context, DynamicRotaryCoefficients, dynamic_rotary_coefficients


@fieldwise_init
struct DynamicDecoderPolicy(Copyable, Movable):
    var factor: ScalarWord
    var theta: ScalarWord
    var reference: Int
    var limit: Int
    var origin: String
    var reference_origin: String
    var provenance: String
    var work: Int


def dynamic_decoder_policy_charge(origin: String, reference_origin: String,
                                 provenance: String, work: Int,
                                 source_work: Int) raises -> Int:
    if work < 256 or work > source_work or provenance.byte_length() == 0:
        raise Error("DynamicDecoder: bounded policy work/provenance required")
    if origin == "invocation":
        if reference_origin != "invocation":
            raise Error("DynamicDecoder: invocation reference origin required")
    elif origin == "source:modern" or origin == "source:legacy":
        if reference_origin != "source" and reference_origin != "documented_default:32768":
            raise Error("DynamicDecoder: qualified source reference origin required")
    else:
        raise Error("DynamicDecoder: selected origin interpretation remains implementation work")
    var used = 256
    for size in List[Int]([origin.byte_length(), reference_origin.byte_length(), provenance.byte_length()]):
        if size > work - used:
            raise Error("DynamicDecoder: policy descriptor work exceeded")
        used += size
    return used


def validate_dynamic_decoder_policy(p: DynamicDecoderPolicy,
                                    source_work: Int) raises -> Int:
    var charge = dynamic_decoder_policy_charge(p.origin, p.reference_origin,
                                              p.provenance, p.work, source_work)
    validate_dynamic_context(DynamicRotaryContext(p.reference, p.reference, p.limit))
    validate_scalar_word(p.factor)
    validate_scalar_word(p.theta)
    if p.origin != "invocation" and (p.factor.width != 64 or p.theta.width != 64):
        raise Error("DynamicDecoder: source words must retain binary64")
    return charge


def same_dynamic_decoder_policy(a: DynamicDecoderPolicy, b: DynamicDecoderPolicy) -> Bool:
    return same_scalar_word(a.factor, b.factor) and same_scalar_word(a.theta, b.theta) and a.reference == b.reference and a.limit == b.limit and a.origin == b.origin and a.reference_origin == b.reference_origin and a.provenance == b.provenance and a.work == b.work


@fieldwise_init
struct DynamicDecoderHistory(Copyable, Movable):
    var policy: DynamicDecoderPolicy
    var initial_selected: Int
    var end_tokens: List[Int]
    var selected_contexts: List[Int]
    var work: Int


def dynamic_decoder_history_charge(policy: DynamicDecoderPolicy, records: Int,
                                  work: Int, source_work: Int) raises -> Int:
    var base = validate_dynamic_decoder_policy(policy, source_work)
    if records < 0 or work > policy.work or work < base or work - base < 128:
        raise Error("DynamicDecoder: bounded history work required")
    base += 128
    if records > (work - base) // 128:
        raise Error("DynamicDecoder: insertion history work exceeded")
    return base + records * 128


def validate_dynamic_decoder_history(history: DynamicDecoderHistory, past: Int,
                                    source_work: Int) raises -> Int:
    var count = len(history.end_tokens)
    var charge = dynamic_decoder_history_charge(history.policy, count, history.work, source_work)
    if past < 0 or past > history.policy.limit or count != len(history.selected_contexts):
        raise Error("DynamicDecoder: bounded matching history extents required")
    var state = DynamicRotaryContext(history.policy.reference, history.initial_selected, history.policy.limit)
    validate_dynamic_context(state)
    var end = 0
    for i in range(count):
        var next_end = history.end_tokens[i]
        if next_end <= end or next_end > past:
            raise Error("DynamicDecoder: insertion ends must strictly cover the declared prefix")
        state = select_dynamic_context(state, next_end - 1)
        if history.selected_contexts[i] != state.selected:
            raise Error("DynamicDecoder: recorded insertion context differs from replay")
        end = next_end
    if end != past:
        raise Error("DynamicDecoder: history does not end at declared past extent")
    return charge


def initial_dynamic_decoder_history(policy: DynamicDecoderPolicy, initial_selected: Int,
                                    work: Int, source_work: Int) raises -> DynamicDecoderHistory:
    _ = dynamic_decoder_history_charge(policy, 0, work, source_work)
    validate_dynamic_context(DynamicRotaryContext(policy.reference, initial_selected, policy.limit))
    return DynamicDecoderHistory(policy.copy(), initial_selected, List[Int](), List[Int](), work)


def advance_dynamic_decoder_history(history: DynamicDecoderHistory, query: Int,
                                    past: Int, capacity: Int,
                                    source_work: Int) raises -> DynamicDecoderHistory:
    _ = validate_dynamic_decoder_history(history, past, source_work)
    if query <= 0 or capacity <= 0 or capacity > history.policy.limit or past > capacity or query > capacity - past:
        raise Error("DynamicDecoder: invalid invocation query/past/capacity extent")
    # The reservation bounds count+1 before it is formed or any list is copied.
    var charge = dynamic_decoder_history_charge(history.policy, len(history.end_tokens), history.work, source_work)
    if history.work - charge < 128:
        raise Error("DynamicDecoder: next insertion record exceeds history work")
    var selected = history.initial_selected if len(history.selected_contexts) == 0 else history.selected_contexts[len(history.selected_contexts) - 1]
    var end = past + query
    var next = select_dynamic_context(DynamicRotaryContext(history.policy.reference, selected, history.policy.limit), end - 1)
    var result = history.copy()
    result.end_tokens.append(end)
    result.selected_contexts.append(next.selected)
    _ = validate_dynamic_decoder_history(result, end, source_work)
    return result^


def history_dynamic_rotary_coefficients(history: DynamicDecoderHistory, past: Int,
                                       width: Int, pair: Int,
                                       source_work: Int) raises -> DynamicRotaryCoefficients:
    _ = validate_dynamic_decoder_history(history, past, source_work)
    var selected = history.initial_selected if len(history.selected_contexts) == 0 else history.selected_contexts[len(history.selected_contexts) - 1]
    return dynamic_rotary_coefficients(DynamicRotaryContext(history.policy.reference, selected, history.policy.limit), width, pair)


# Optional legacy sentinels only. Positive explicit policies never accept these.
def empty_dynamic_decoder_policy() -> DynamicDecoderPolicy:
    return DynamicDecoderPolicy(ScalarWord(0, 0), ScalarWord(0, 0), 0, 0, "", "", "", 0)


def empty_dynamic_decoder_history() -> DynamicDecoderHistory:
    return DynamicDecoderHistory(empty_dynamic_decoder_policy(), 0, List[Int](), List[Int](), 0)


def same_dynamic_decoder_history(a: DynamicDecoderHistory, b: DynamicDecoderHistory,
                                 source_work: Int) raises -> Bool:
    # Bound mutable lists and strings before equality scans, including sentinels.
    if source_work < 0 or len(a.end_tokens) > source_work // 128 or len(b.end_tokens) > source_work // 128 or len(a.selected_contexts) > source_work // 128 or len(b.selected_contexts) > source_work // 128:
        raise Error("DynamicDecoder: equality history work exceeded")
    if a.policy.origin.byte_length() > source_work or b.policy.origin.byte_length() > source_work or a.policy.reference_origin.byte_length() > source_work or b.policy.reference_origin.byte_length() > source_work or a.policy.provenance.byte_length() > source_work or b.policy.provenance.byte_length() > source_work:
        raise Error("DynamicDecoder: equality policy work exceeded")
    return same_dynamic_decoder_policy(a.policy, b.policy) and a.initial_selected == b.initial_selected and a.end_tokens == b.end_tokens and a.selected_contexts == b.selected_contexts and a.work == b.work
