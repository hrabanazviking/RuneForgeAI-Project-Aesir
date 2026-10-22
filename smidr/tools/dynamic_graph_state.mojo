# Exact compiler declarations only; no frequency evaluation or device program.
from smidr.dynamic_decoder_policy import DynamicDecoderHistory, validate_dynamic_decoder_history
from smidr.source_scalars import ScalarWord
from smidr.tools.source_scalars import describe_scalar_word
from smidr.tools.dynamic_decoder_policy import describe_dynamic_decoder_history


def describe_dynamic_numbers(reference: Int, selected: Int, factor: ScalarWord) -> String:
    return String("\"dynamic_reference\":") + String(reference) + ",\"dynamic_selected\":" + String(selected) + ",\"dynamic_factor\":" + describe_scalar_word(factor)


def describe_dynamic_state(before: DynamicDecoderHistory, after: DynamicDecoderHistory,
                           past: Int, query: Int, configured: Int, charged: Int,
                           source_work: Int, return_cache: Int) raises -> String:
    _ = validate_dynamic_decoder_history(before, past, source_work)
    _ = validate_dynamic_decoder_history(after, past + query, source_work)
    var text = String("{\"source_context\":") + String(configured) + ",\"charged_work\":" + String(charged)
    text += ",\"before\":" + describe_dynamic_decoder_history(before, past, source_work)
    text += ",\"after\":" + describe_dynamic_decoder_history(after, past + query, source_work)
    text += ",\"context_output\":{\"reference\":" + String(after.policy.reference) + ",\"selected\":" + String(after.selected_contexts[len(after.selected_contexts) - 1]) + ",\"limit\":" + String(after.policy.limit) + "}"
    text += ",\"cache_history_output\":"
    if return_cache == 1:
        text += describe_dynamic_decoder_history(after, past + query, source_work)
    else:
        text += "{\"policy\":{\"factor\":{\"width\":0,\"bits\":0},\"theta\":{\"width\":0,\"bits\":0},\"reference\":0,\"limit\":0,\"origin\":\"\",\"reference_origin\":\"\",\"provenance\":\"\",\"work\":0},\"initial_selected\":0,\"end_tokens\":[],\"selected_contexts\":[],\"work\":0}"
    return text + "}"
