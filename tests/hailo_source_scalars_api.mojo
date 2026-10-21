# Exact word/graph mutation API; no host primitive execution or device access.
from std.sys import argv
from std.memory import bitcast
from smidr.tools.hrpc_program import _uint64
from smidr.source_scalars import ScalarWord, DecoderScalars, same_scalar_word
from smidr.semantic_plan import decoder_geometry, DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.tools.typed_decoder import _from_file
from smidr.tools.decoder_graph_policy import parse_rotary_flags
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.expanded_graph import expand_semantic_graph
from smidr.expanded_storage import validate_expanded_storage_graph
from smidr.tools.rotary_recipes import describe_rotary_graph


def main() raises:
    var args = argv()
    if len(args) != 10:
        raise Error("expected fixture case epsilon-width epsilon-word base-width base-word provenance work mask")
    var input = _from_file(args[1])
    var source = input.take_inventory()
    var geometry = decoder_geometry(input.parameters)
    var scalars = DecoderScalars(ScalarWord(Int(args[3]), _uint64(args[4])), ScalarWord(Int(args[5]), _uint64(args[6])), args[7], Int(args[8]))
    var wanted = scalars.copy()
    var mode = String(args[2])
    var output = String("output.weight") if "output.weight" in source.bindings else String("token_embd.weight")
    var decoder = DecoderGraphPolicy(parse_rotary_flags(args[9]), output, "synthetic exact scalar test geometry")
    if mode == "geometry":
        geometry.hidden = 0
    elif mode == "source_bound":
        source.policy.work = 1
    var plan = build_decoder_semantic_plan(source^, geometry, scalars, decoder, 2, 1, 16)
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic basis", 1000, 1000000)
    if mode == "opaque":
        var graph = expand_semantic_graph(plan^)
        print(describe_rotary_graph(graph, graph.recipes.rotary_policy))
        return
    if mode == "ownership":
        var recipes = lower_primitive_recipes(plan, rotary)
        scalars.epsilon.bits = 0
        scalars.provenance = "changed"
        plan.source_scalars.rope_base.bits = 0
        for i in range(len(recipes.recipes)):
            var r = recipes.recipes[i].copy()
            if r.kind == "rms_norm" and not same_scalar_word(r.epsilon_scalar, wanted.epsilon):
                raise Error("SourceScalar: norm word alias")
            if (r.kind == "rope_query" or r.kind == "rope_key") and not same_scalar_word(r.rotary_base_scalar, wanted.rope_base):
                raise Error("SourceScalar: rotary word alias")
        if recipes.source_scalars.provenance != wanted.provenance or not same_scalar_word(recipes.source_scalars.rope_base, wanted.rope_base):
            raise Error("SourceScalar: snapshot alias")
        print("owned-source-scalars-pass")
        return
    elif mode == "legacy_epsilon":
        plan.rms_epsilon = 1
    elif mode == "legacy_negative_zero":
        plan.rope_base = bitcast[DType.float32](UInt32(0x80000000))
    elif mode == "state_disabled":
        plan.explicit_scalars = False
    elif mode == "state_provenance":
        plan.source_scalars.provenance = ""
    elif mode == "state_width":
        plan.source_scalars.epsilon.width = 16
    elif mode == "state_zero":
        plan.source_scalars.rope_base.bits = 0
    elif mode.startswith("graph_"):
        var graph = expand_semantic_graph(plan^, rotary)
        var norm = -1
        var rope = -1
        var recipe = -1
        for i in range(len(graph.operations)):
            if graph.source.operations[graph.operations[i].source_operation].kind == "rms_norm" and norm == -1:
                norm = i
            if graph.operations[i].rotary_dim != 0 and rope == -1:
                rope = i
        for i in range(len(graph.recipes.recipes)):
            if graph.recipes.recipes[i].kind == "rms_norm" and recipe == -1:
                recipe = i
        if mode == "graph_ownership":
            scalars.epsilon.bits = 0
            scalars.provenance = "changed"
            if not same_scalar_word(graph.source.source_scalars.epsilon, wanted.epsilon) or graph.recipes.source_scalars.provenance != wanted.provenance:
                raise Error("SourceScalar: graph snapshot alias")
        elif mode == "graph_norm_word":
            graph.operations[norm].epsilon_scalar.bits = 0
        elif mode == "graph_norm_width":
            graph.operations[norm].epsilon_scalar.width = 32
        elif mode == "graph_norm_mirror":
            graph.operations[norm].epsilon_bits = 1
        elif mode == "graph_rope_word":
            graph.operations[rope].rotary_base_scalar.bits = 0
        elif mode == "graph_rope_width":
            graph.operations[rope].rotary_base_scalar.width = 16
        elif mode == "graph_rope_mirror":
            graph.operations[rope].rotary_base_bits = 1
        elif mode == "graph_stray_epsilon":
            graph.operations[0].epsilon_scalar = wanted.epsilon.copy()
        elif mode == "graph_stray_base":
            graph.operations[0].rotary_base_scalar = wanted.rope_base.copy()
        elif mode == "graph_recipe_word":
            graph.recipes.recipes[recipe].epsilon_scalar.bits = 0
        elif mode == "graph_recipe_mirror":
            graph.recipes.recipes[recipe].epsilon_bits = 1
        elif mode == "graph_snapshot_word":
            graph.recipes.source_scalars.epsilon.bits = 0
        elif mode == "graph_snapshot_provenance":
            graph.recipes.source_scalars.provenance = "changed"
        elif mode == "graph_source_word":
            graph.source.source_scalars.rope_base.bits = 0
        elif mode == "graph_source_provenance":
            graph.source.source_scalars.provenance = "changed"
        elif mode == "graph_legacy_slot":
            graph.source.rope_base = 1
        elif mode == "graph_snapshot_mode":
            graph.recipes.explicit_scalars = False
        else:
            raise Error("SourceScalar: unknown graph mutation")
        validate_expanded_storage_graph(graph)
        print("validated-source-scalars-pass")
        return
    elif mode != "valid" and mode != "geometry" and mode != "source_bound":
        raise Error("SourceScalar: unknown case")
    var graph = expand_semantic_graph(plan^, rotary)
    print(describe_rotary_graph(graph, rotary))
