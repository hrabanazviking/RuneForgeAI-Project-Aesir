# Explicit basis compiler inspector; no numerical host/device execution.
from std.sys import argv
from smidr.semantic_plan import SemanticPlan, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.typed_decoder import _from_file
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.expanded_storage import ExpandedStorageAssumptions, estimate_expanded_storage
from smidr.tools.primitive_recipes import describe_primitive_recipes
from smidr.tools.expanded_graph import describe_expanded_graph
from smidr.tools.semantic_plan import describe_semantic_plan, _integers
from smidr.tools.source_inventory import _quote
from smidr.tools.source_scalars import describe_scalar_word


def rotary_plan(path: String, query: Int, past: Int, capacity: Int, mask: String) raises -> SemanticPlan:
    var input = _from_file(path)
    var source = input.take_inventory()
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var decoder = DecoderGraphPolicy(parse_rotary_flags(mask), output, "explicit synthetic fixture decoder policy")
    return build_decoder_semantic_plan(source^, input.parameters, decoder, query, past, capacity)


def describe_rotary_graph(graph: ExpandedGraph, policy: RotaryLoweringPolicy) raises -> String:
    var assumptions = ExpandedStorageAssumptions(2, 1, 2, 8, 16, graph.source.source.weight_bytes, 0, 9223372036854775807, "explicit hypothetical inspector widths; not measured Hailo")
    var storage = estimate_expanded_storage(graph, assumptions)
    var text = String("{\"scope\":\"explicit_rotary_mathematical_lowering\",\"executable_program\":false,\"device_execution_verified\":false,\"ordinary_model_admitted\":false,\"hardware_fit_verified\":false,\"source_identity_verified\":false")
    text += ",\"policy\":{\"pairing\":" + _quote(policy.pairing) + ",\"provenance\":" + _quote(policy.provenance) + ",\"max_recipes\":" + String(policy.max_recipes) + ",\"work\":" + String(policy.work) + ",\"charged_work\":" + String(graph.recipes.rotary_work) + "}"
    text += ",\"source_graph\":" + describe_semantic_plan(graph.source)
    text += ",\"recipes\":" + describe_primitive_recipes(graph.recipes, graph.source)
    text += ",\"expanded\":" + describe_expanded_graph(graph)
    text += ",\"rotary_mappings\":["
    var first = True
    for i in range(len(graph.recipes.recipes)):
        var r = graph.recipes.recipes[i].copy()
        if r.rotary_dim == 0:
            continue
        if not first:
            text += ","
        first = False
        text += "{\"source_operation\":" + String(r.source_operation) + ",\"source_inputs\":" + _integers(r.source_inputs) + ",\"input_values\":" + _integers(r.input_values)
        text += ",\"rotary_dim\":" + String(r.rotary_dim) + ",\"rotary_base_bits\":" + (String("null") if r.rotary_base_scalar.width == 64 else String(r.rotary_base_bits)) + ",\"pairing\":" + _quote(r.rotary_pairing) + ",\"provenance\":" + _quote(r.rotary_provenance) + "}"
    text += "],\"expanded_rotary_metadata\":["
    first = True
    for i in range(len(graph.operations)):
        var op = graph.operations[i].copy()
        if op.rotary_dim == 0:
            continue
        if not first:
            text += ","
        first = False
        text += "{\"operation\":" + String(i) + ",\"rotary_dim\":" + String(op.rotary_dim) + ",\"rotary_base_bits\":" + (String("null") if op.rotary_base_scalar.width == 64 else String(op.rotary_base_bits)) + ",\"pairing\":" + _quote(op.rotary_pairing) + ",\"provenance\":" + _quote(op.rotary_provenance) + "}"
    text += "],\"storage\":{\"activation_width\":2,\"predicate_width\":1,\"kv_width\":2,\"index_width\":8,\"alignment\":16,\"assumed_device_weight_bytes\":" + String(assumptions.device_weight_bytes)
    text += ",\"value_bytes\":" + _integers(storage.value_bytes) + ",\"real_live_bytes\":" + _integers(storage.real_live_bytes) + ",\"predicate_live_bytes\":" + _integers(storage.predicate_live_bytes) + ",\"activation_live_bytes\":" + _integers(storage.activation_live_bytes)
    text += ",\"persistent_kv_bytes\":" + String(storage.persistent_kv_bytes) + ",\"input_bytes\":" + String(storage.input_bytes) + ",\"peak_activation_bytes\":" + String(storage.peak_activation_bytes) + ",\"peak_step\":" + String(storage.peak_step) + ",\"total_bytes\":" + String(storage.total_bytes) + "}}"
    if graph.source.explicit_window:
        text = text.replace("\"storage\":{", "\"storage\":{\"index_live_bytes\":" + _integers(storage.index_live_bytes) + ",")
    return text


def main() raises:
    var args = argv()
    if len(args) != 10:
        raise Error("usage: rotary_recipes <fixture.gguf> <query> <past> <capacity> <pairing> <provenance> <max_recipes> <work> <CSVmask>")
    var plan = rotary_plan(args[1], Int(args[2]), Int(args[3]), Int(args[4]), args[9])
    var policy = RotaryLoweringPolicy(args[5], args[6], Int(args[7]), Int(args[8]))
    var graph = expand_semantic_graph(plan^, policy)
    print(describe_rotary_graph(graph, policy))
