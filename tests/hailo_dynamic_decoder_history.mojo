from std.sys import argv
from smidr.tools.hrpc_program import _uint64
from smidr.source_scalars import ScalarWord
from smidr.dynamic_decoder_policy import DynamicDecoderPolicy, DynamicDecoderHistory, validate_dynamic_decoder_policy, initial_dynamic_decoder_history, validate_dynamic_decoder_history, advance_dynamic_decoder_history, history_dynamic_rotary_coefficients
from smidr.tools.dynamic_decoder_policy import parse_dynamic_history_words, describe_dynamic_decoder_history


def main() raises:
    var a = argv()
    if len(a) != 20:
        raise Error("expected reference limit theta_width theta_bits factor_width factor_bits origin reference_origin provenance policy_work history_work source_work initial ends contexts past query capacity case")
    var source_work = Int(a[12])
    var provenance = String(a[9])
    if a[19] == "nul":
        provenance += "\0tail"
    var policy = DynamicDecoderPolicy(ScalarWord(Int(a[5]), _uint64(a[6])),
        ScalarWord(Int(a[3]), _uint64(a[4])), Int(a[1]), Int(a[2]), a[7], a[8], provenance, Int(a[10]))
    _ = validate_dynamic_decoder_policy(policy, source_work)
    var h = DynamicDecoderHistory(policy.copy(), Int(a[13]),
        parse_dynamic_history_words(a[14], Int(a[11])), parse_dynamic_history_words(a[15], Int(a[11])), Int(a[11]))
    var past = Int(a[16])
    var query = Int(a[17])
    var capacity = Int(a[18])
    var mode = a[19]
    if mode == "initial":
        if a[14] != "-" or a[15] != "-" or past != 0:
            raise Error("initial probe requires an empty prefix")
        h = initial_dynamic_decoder_history(policy, Int(a[13]), Int(a[11]), source_work)
        mode = "valid"
    elif mode == "nul":
        mode = "copy"
    if mode.startswith("mutate:"):
        var field = Int(String(mode.split(":")[1]))
        if field == 0:
            h.policy.factor.width = 0
        elif field == 1:
            h.policy.factor.bits = 0
        elif field == 2:
            h.policy.theta.width = 0
        elif field == 3:
            h.policy.theta.bits = 0
        elif field == 4:
            h.policy.reference = 0
        elif field == 5:
            h.policy.limit = 0
        elif field == 6:
            h.policy.origin = "changed"
        elif field == 7:
            h.policy.reference_origin = "changed"
        elif field == 8:
            h.policy.provenance = ""
        elif field == 9:
            h.policy.work = 0
        elif field == 10:
            h.initial_selected = 0
        elif field == 11:
            h.end_tokens.append(past + 1)
        elif field == 12:
            h.selected_contexts.append(0)
        elif field == 13:
            h.work = 0
        elif field == 14:
            h.end_tokens[0] = 0
        elif field == 15:
            h.selected_contexts[0] += 1
        elif field == 16:
            h.end_tokens[len(h.end_tokens) - 1] -= 1
        elif field == 17:
            h.selected_contexts.clear()
        elif field == 18:
            h.policy.reference += 1
        else:
            raise Error("unknown mutation field")
        _ = validate_dynamic_decoder_history(h, past, source_work)
        raise Error("INVALID: mutation accepted")
    var before = describe_dynamic_decoder_history(h, past, source_work)
    var next = advance_dynamic_decoder_history(h, query, past, capacity, source_work)
    if describe_dynamic_decoder_history(h, past, source_work) != before:
        raise Error("advance mutated original history")
    if mode == "copy":
        var owner = next.copy()
        policy.factor.bits = 0
        h.policy.theta.bits = 0
        h.end_tokens.clear()
        next.end_tokens[0] = 0
        next.policy.provenance = "changed"
        for _ in range(11):
            var bad = owner.copy()
            bad.selected_contexts[0] += 1
            var refused = False
            try:
                _ = validate_dynamic_decoder_history(bad, past + query, source_work)
            except:
                refused = True
            if not refused:
                raise Error("invalid insertion history accepted during recovery")
            _ = validate_dynamic_decoder_history(owner, past + query, source_work)
        next = owner^
    elif mode != "valid":
        raise Error("unknown history case")
    var c = history_dynamic_rotary_coefficients(next, past + query, 6, 1, source_work)
    print(String("{\"before\":") + before + ",\"after\":" + describe_dynamic_decoder_history(next, past + query, source_work) + ",\"coefficients\":[" + String(c.theta_num) + "," + String(c.theta_den) + "," + String(c.gain_num) + "," + String(c.gain_den) + "," + String(c.delta_num) + "," + String(c.delta_den) + "]}")
