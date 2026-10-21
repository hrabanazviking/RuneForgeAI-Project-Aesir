from smidr.dynamic_decoder_policy import DynamicDecoderPolicy, DynamicDecoderHistory, validate_dynamic_decoder_policy, validate_dynamic_decoder_history, history_dynamic_rotary_coefficients
from smidr.tools.source_inventory import _quote


def parse_dynamic_history_words(raw: String, work: Int) raises -> List[Int]:
    if work <= 0 or raw.byte_length() > work:
        raise Error("DynamicDecoder: history text work bound exceeded")
    var result = List[Int]()
    if raw == "-":
        return result^
    for part in raw.split(","):
        if len(result) >= work // 128:
            raise Error("DynamicDecoder: history text record bound exceeded")
        result.append(Int(String(part)))
    return result^


def describe_dynamic_decoder_policy(p: DynamicDecoderPolicy, source_work: Int) raises -> String:
    var charge = validate_dynamic_decoder_policy(p, source_work)
    return String("{\"kind\":\"dynamic\",\"factor\":{\"width\":") + String(p.factor.width) + ",\"bits\":" + String(p.factor.bits) + "},\"theta\":{\"width\":" + String(p.theta.width) + ",\"bits\":" + String(p.theta.bits) + "},\"reference\":" + String(p.reference) + ",\"limit\":" + String(p.limit) + ",\"origin\":" + _quote(p.origin) + ",\"reference_origin\":" + _quote(p.reference_origin) + ",\"provenance\":" + _quote(p.provenance) + ",\"work\":" + String(p.work) + ",\"charged_work\":" + String(charge) + "}"


def describe_dynamic_decoder_history(h: DynamicDecoderHistory, past: Int, source_work: Int) raises -> String:
    var charge = validate_dynamic_decoder_history(h, past, source_work)
    var text = String("{\"policy\":") + describe_dynamic_decoder_policy(h.policy, source_work) + ",\"initial_selected\":" + String(h.initial_selected) + ",\"end_tokens\":["
    for i in range(len(h.end_tokens)):
        if i != 0:
            text += ","
        text += String(h.end_tokens[i])
    text += "],\"selected_contexts\":["
    for i in range(len(h.selected_contexts)):
        if i != 0:
            text += ","
        text += String(h.selected_contexts[i])
    var c = history_dynamic_rotary_coefficients(h, past, 2, 0, source_work)
    return text + "],\"work\":" + String(h.work) + ",\"charged_work\":" + String(charge) + ",\"pair0_identity\":{\"width\":2,\"pair\":0,\"theta_num\":" + String(c.theta_num) + ",\"theta_den\":" + String(c.theta_den) + ",\"gain_num\":" + String(c.gain_num) + ",\"gain_den\":" + String(c.gain_den) + ",\"delta_num\":" + String(c.delta_num) + ",\"delta_den\":" + String(c.delta_den) + "}}"
