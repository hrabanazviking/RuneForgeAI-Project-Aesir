from std.sys import argv
from smidr.tools.decoder_activation_graph import read_bias_source
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.source_dynamic_decoder import source_dynamic_decoder_policy, validate_source_dynamic_decoder_policy
from smidr.dynamic_decoder_policy import DynamicDecoderHistory, initial_dynamic_decoder_history, validate_dynamic_decoder_history, advance_dynamic_decoder_history
from smidr.tools.dynamic_decoder_policy import parse_dynamic_history_words, describe_dynamic_decoder_history


def main() raises:
    var a = argv()
    if len(a) != 15:
        raise Error("expected mode root label config limit initial ends contexts past query capacity work provenance case")
    var schema = read_bias_source(a[1], a[2], a[3], a[4])
    var original = describe_ordinary_projection_schema(schema)
    var provenance = String(a[13])
    if a[14] == "nul":
        provenance += "\0tail"
    var p = source_dynamic_decoder_policy(schema.binding.architecture, Int(a[5]), provenance, Int(a[12]))
    var mode = a[14]
    if mode == "source_policy_factor":
        p.factor.bits += 1
    elif mode == "source_policy_theta":
        p.theta.bits += 1
    elif mode == "source_policy_reference":
        p.reference += 1
    elif mode == "source_policy_origin":
        p.origin = "source:legacy" if p.origin == "source:modern" else "source:modern"
    elif mode == "source_policy_reference_origin":
        p.reference_origin = "documented_default:32768" if p.reference_origin == "source" else "source"
    elif mode == "source_policy_width":
        p.factor.width = 32
    elif mode == "source_flag":
        schema.binding.architecture.flags["use_cache"] = not schema.binding.architecture.flags["use_cache"]
    elif mode == "source_layer":
        schema.binding.architecture.layers.layer_count += 1
    elif mode == "source_work":
        schema.binding.architecture.work_units += 1
    elif mode == "source_raw":
        schema.binding.architecture.layers.source.fields["rope_scaling"] = "null"
    validate_source_dynamic_decoder_policy(schema.binding.architecture, p)
    if mode != "valid" and mode != "copy" and mode != "nul":
        raise Error("INVALID: source mutation accepted")
    if describe_ordinary_projection_schema(schema) != original:
        raise Error("dynamic source projection mutated original owner")
    var source_work = schema.binding.architecture.policy.work
    var h = DynamicDecoderHistory(p.copy(), Int(a[6]), parse_dynamic_history_words(a[7], Int(a[12])), parse_dynamic_history_words(a[8], Int(a[12])), Int(a[12]))
    var past = Int(a[9])
    if past == 0 and a[7] == "-" and a[8] == "-":
        h = initial_dynamic_decoder_history(p, Int(a[6]), Int(a[12]), source_work)
    var query = Int(a[10])
    var before = describe_dynamic_decoder_history(h, past, source_work)
    var next = advance_dynamic_decoder_history(h, query, past, Int(a[11]), source_work)
    if mode == "copy" or mode == "nul":
        p.factor.bits = 0
        h.policy.theta.bits = 0
        schema.binding.architecture.work_units += 1
        _ = validate_dynamic_decoder_history(next, past + query, source_work)
    print(String("{\"scope\":\"source_dynamic_context_intent\",\"ordinary_model_admitted\":false,\"source_graph_integrated\":false,\"device_execution_verified\":false,\"original_source\":") + original + ",\"before\":" + before + ",\"after\":" + describe_dynamic_decoder_history(next, past + query, source_work) + "}")
