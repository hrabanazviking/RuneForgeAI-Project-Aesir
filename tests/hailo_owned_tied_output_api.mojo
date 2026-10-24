# Test-only retained sharing, graph and owner intent mutation gates.
from std.sys import argv
from smidr.owned_tied_output_compiler import *
from smidr.owned_ordinary_binding import load_owned_indexed_ordinary, load_owned_unindexed_ordinary
from smidr.source_weight_sharing import SourceWeightSharingPolicy, SourceWeightAlias
from smidr.sealed_safetensors_source import load_sealed_safetensors
from smidr.expanded_graph import ExpandedGraph
from smidr.semantic_plan import SemanticPlan
from smidr.tools.owned_ordinary_binding import _binding_policy, _root_policy, _copy_policy
from smidr.tools.owned_ordinary_compiler import _request, _report
from smidr.tools.sealed_source_collection import describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.ordinary_tensor_identity import describe_comparison
from smidr.tools.source_inventory import _quote
from hailo_owned_ordinary_binding_api import _damage_schema, _damage_policy, _damage_shard, _cache_shard, _cache_config
from hailo_owned_ordinary_compiler_api import _damage_plan, _damage_request
from hailo_sealed_collection_api import _mutate
from hailo_sealed_safetensors_api import _window


def _damage_sharing(mut p: SourceWeightSharingPolicy, mode: String) raises:
    if mode == "alias":
        p.aliases[0].alias_name = "other"
    elif mode == "target":
        p.aliases[0].target_name = "other"
    elif mode == "self":
        p.aliases[0].target_name = p.aliases[0].alias_name
    elif mode == "reverse":
        p.aliases[0].alias_name = "token_embd.weight"
        p.aliases[0].target_name = "output.weight"
    elif mode == "origin":
        p.aliases[0].source_origin = "forged"
    elif mode == "provenance":
        p.provenance = "forged"
    elif mode == "work":
        p.work += 1
    elif mode == "duplicate":
        var second = p.aliases[0].copy()
        p.aliases.append(second^)
    elif mode == "missing":
        p.aliases.clear()
    elif mode == "empty":
        p.aliases.clear()
        p.provenance = ""
        p.work = 0
    else:
        raise Error("test: unknown sharing mutation")


def _damage_expanded(mut g: ExpandedGraph, mode: String) raises:
    var id = g.weight_values["output.weight"]
    if mode == "map":
        g.weight_values["output.weight"] = g.weight_values["token_embd.weight"]
    elif mode == "missing":
        _ = g.weight_values.pop("output.weight")
    elif mode == "extra":
        g.weight_values["other"] = id
    elif mode == "name":
        g.values[id].name = "other"
    elif mode == "source":
        g.values[id].source_weight = "token_embd.weight"
    elif mode == "shape":
        g.values[id].shape[0] += 1
    elif mode == "elements":
        g.values[id].elements += 1
    elif mode == "producer":
        g.values[id].producer = 0
    elif mode == "last":
        g.values[id].last_use -= 1
    elif mode == "storage":
        g.values[id].storage = "activation"
    elif mode == "alias":
        g.values[id].alias_of = g.weight_values["token_embd.weight"]
    elif mode == "domain":
        g.values[id].domain = "index"
    else:
        raise Error("test: unknown expanded mutation")


def _move_indexed(var c: OwnedIndexedTiedOutputCompiler) -> OwnedIndexedTiedOutputCompiler:
    return c^


def _run_indexed(args: List[String]) raises:
    var mode = args[2]
    var policy = _binding_policy(args, 3, True)
    var request = _request(args, 47)
    var total = Int(args[60])
    var chunk = Int(args[61])
    var operation = Int(args[62])
    var first = Int(args[63])
    var count = Int(args[64])
    var cap = Int(args[65])
    var binding = load_owned_indexed_ordinary(args[3], args[4], args[5], _root_policy(args, 3), _copy_policy(args, 30), policy)
    if mode == "pre_cache":
        _cache_config(binding.owner.config)
        for i in range(len(binding.owner.shards)):
            _cache_shard(binding.owner.shards[i])
    elif mode.startswith("pre_schema:"):
        _damage_schema(binding.schema, String(mode[byte=11:]))
    elif mode.startswith("before:"):
        _mutate(args[3] + "/config.json", String(mode[byte=7:]))
        for i in range(len(binding.owner.shards)):
            _mutate(args[3] + "/" + binding.owner.shards[i].label, String(mode[byte=7:]))
    var context = compile_owned_indexed_tied_output(binding^, policy, request, total, chunk)
    if mode == "move":
        context = _move_indexed(context^)
    elif mode == "cache":
        _cache_config(context.binding.owner.config)
        for i in range(len(context.binding.owner.shards)):
            _cache_shard(context.binding.owner.shards[i])
    elif mode == "observation":
        context.observation.all_elements_equal = False
        context.observation.differing_elements = 999
        context.observation.first_differing_element = 88
        context.observation.left.source_path = "forged"
        context.observation.right.source_shape.clear()
        context.observation.raw_elements_read = 0
    elif mode.startswith("schema:"):
        _damage_schema(context.binding.schema, String(mode[byte=7:]))
    elif mode.startswith("policy:"):
        _damage_policy(context.binding.policy, String(mode[byte=7:]))
    elif mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    elif mode.startswith("request:"):
        _damage_request(context.request, String(mode[byte=8:]))
    elif mode.startswith("supplied:"):
        _damage_request(request, String(mode[byte=9:]))
    elif mode.startswith("sharing:"):
        _damage_sharing(context.sharing, String(mode[byte=8:]))
    elif mode.startswith("graph_sharing:"):
        _damage_sharing(context.graph.source.source_sharing, String(mode[byte=14:]))
    elif mode == "sharing_charge":
        context.graph.source.sharing_work += 1
    elif mode == "forge_empty_use":
        context.graph.source.source_sharing.aliases.clear()
        context.graph.source.source_sharing.provenance = ""
        context.graph.source.source_sharing.work = 0
        context.graph.source.sharing_work = 0
        context.graph.source.used_weights["output.weight"] = True
    elif mode == "fake_use":
        context.graph.source.used_weights["output.weight"] = True
    elif mode == "missing_use":
        _ = context.graph.source.used_weights.pop("token_embd.weight")
    elif mode == "false_use":
        context.graph.source.used_weights["token_embd.weight"] = False
    elif mode.startswith("plan:"):
        _damage_plan(context.graph.source, operation, String(mode[byte=5:]))
    elif mode.startswith("expanded:"):
        _damage_expanded(context.graph, String(mode[byte=9:]))
    elif mode.startswith("shard:"):
        _damage_shard(context.binding.owner.shards[0], String(mode[byte=6:]))
    elif mode.startswith("after:"):
        _mutate(args[3] + "/config.json", String(mode[byte=6:]))
        for i in range(len(context.binding.owner.shards)):
            _mutate(args[3] + "/" + context.binding.owner.shards[i].label, String(mode[byte=6:]))
    elif mode == "replace_sealed":
        var path = context.binding.schema.binding.source.storage["output.weight"].source_path
        _mutate(path, "same_size")
        for i in range(len(context.binding.owner.shards)):
            if context.binding.owner.shards[i].storage.source_path == path:
                context.binding.owner.shards[i].owner.close()
                context.binding.owner.shards[i].owner = load_sealed_safetensors(path, 16777216, 16384, 16384, 16384, policy.fd.header_bytes, policy.fd.tensors, policy.fd.rank, policy.fd.work, policy.fd.depth)
        context.observation.all_elements_equal = True
        context.observation.differing_elements = 0
    elif mode == "bound_total":
        context.total_elements += 1
    elif mode == "bound_chunk":
        context.chunk_elements += 1
    elif mode == "supplied_total":
        total += 1
    elif mode == "supplied_chunk":
        chunk += 1
    elif mode == "closed":
        context.close()
    var selected = read_owned_indexed_tied_component(context, operation, first, count, cap, policy, request, total, chunk)
    var views = String("[")
    if mode == "all":
        var comma = False
        for i in range(len(context.graph.source.operations)):
            var name = context.graph.source.operations[i].weight
            if name.byte_length() == 0:
                continue
            var elements = context.graph.source.source.storage[name].elements
            var window = read_owned_indexed_tied_component(context, i, 0, elements, cap, policy, request, total, chunk)
            if comma:
                views += ","
            comma = True
            views += "{\"canonical\":" + _quote(name) + ",\"window\":" + _window(window) + "}"
    views += "]"
    var text = _report(describe_indexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
    var observed = describe_comparison(context.observation)
    context.close()
    print(text)
    print(observed)
    print(views)
    print(_window(selected))


def _move_unindexed(var c: OwnedUnindexedTiedOutputCompiler) -> OwnedUnindexedTiedOutputCompiler:
    return c^


def _run_unindexed(args: List[String]) raises:
    var mode = args[2]
    var policy = _binding_policy(args, 3, False)
    var request = _request(args, 42)
    var total = Int(args[55])
    var chunk = Int(args[56])
    var operation = Int(args[57])
    var first = Int(args[58])
    var count = Int(args[59])
    var cap = Int(args[60])
    var binding = load_owned_unindexed_ordinary(args[3], args[4], args[5], _root_policy(args, 3), _copy_policy(args, 25), policy)
    if mode == "pre_cache":
        _cache_config(binding.owner.config)
        _cache_shard(binding.owner.shard)
    elif mode.startswith("pre_schema:"):
        _damage_schema(binding.schema, String(mode[byte=11:]))
    elif mode.startswith("before:"):
        _mutate(args[3] + "/config.json", String(mode[byte=7:]))
        _mutate(args[3] + "/" + binding.owner.shard.label, String(mode[byte=7:]))
    var context = compile_owned_unindexed_tied_output(binding^, policy, request, total, chunk)
    if mode == "move":
        context = _move_unindexed(context^)
    elif mode == "cache":
        _cache_config(context.binding.owner.config)
        _cache_shard(context.binding.owner.shard)
    elif mode == "observation":
        context.observation.all_elements_equal = False
        context.observation.differing_elements = 999
        context.observation.first_differing_element = 88
        context.observation.left.source_path = "forged"
        context.observation.right.source_shape.clear()
        context.observation.raw_elements_read = 0
    elif mode.startswith("schema:"):
        _damage_schema(context.binding.schema, String(mode[byte=7:]))
    elif mode.startswith("policy:"):
        _damage_policy(context.binding.policy, String(mode[byte=7:]))
    elif mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    elif mode.startswith("request:"):
        _damage_request(context.request, String(mode[byte=8:]))
    elif mode.startswith("supplied:"):
        _damage_request(request, String(mode[byte=9:]))
    elif mode.startswith("sharing:"):
        _damage_sharing(context.sharing, String(mode[byte=8:]))
    elif mode.startswith("graph_sharing:"):
        _damage_sharing(context.graph.source.source_sharing, String(mode[byte=14:]))
    elif mode == "sharing_charge":
        context.graph.source.sharing_work += 1
    elif mode == "forge_empty_use":
        context.graph.source.source_sharing.aliases.clear()
        context.graph.source.source_sharing.provenance = ""
        context.graph.source.source_sharing.work = 0
        context.graph.source.sharing_work = 0
        context.graph.source.used_weights["output.weight"] = True
    elif mode == "fake_use":
        context.graph.source.used_weights["output.weight"] = True
    elif mode == "missing_use":
        _ = context.graph.source.used_weights.pop("token_embd.weight")
    elif mode == "false_use":
        context.graph.source.used_weights["token_embd.weight"] = False
    elif mode.startswith("plan:"):
        _damage_plan(context.graph.source, operation, String(mode[byte=5:]))
    elif mode.startswith("expanded:"):
        _damage_expanded(context.graph, String(mode[byte=9:]))
    elif mode.startswith("shard:"):
        _damage_shard(context.binding.owner.shard, String(mode[byte=6:]))
    elif mode.startswith("after:"):
        _mutate(args[3] + "/config.json", String(mode[byte=6:]))
        _mutate(args[3] + "/" + context.binding.owner.shard.label, String(mode[byte=6:]))
    elif mode == "replace_sealed":
        var path = context.binding.owner.shard.owner.label
        _mutate(path, "same_size")
        context.binding.owner.shard.owner.close()
        context.binding.owner.shard.owner = load_sealed_safetensors(path, 16777216, 16384, 16384, 16384, policy.fd.header_bytes, policy.fd.tensors, policy.fd.rank, policy.fd.work, policy.fd.depth)
        context.observation.all_elements_equal = True
        context.observation.differing_elements = 0
    elif mode == "bound_total":
        context.total_elements += 1
    elif mode == "bound_chunk":
        context.chunk_elements += 1
    elif mode == "supplied_total":
        total += 1
    elif mode == "supplied_chunk":
        chunk += 1
    elif mode == "closed":
        context.close()
    var selected = read_owned_unindexed_tied_component(context, operation, first, count, cap, policy, request, total, chunk)
    var views = String("[")
    if mode == "all":
        var comma = False
        for i in range(len(context.graph.source.operations)):
            var name = context.graph.source.operations[i].weight
            if name.byte_length() == 0:
                continue
            var elements = context.graph.source.source.storage[name].elements
            var window = read_owned_unindexed_tied_component(context, i, 0, elements, cap, policy, request, total, chunk)
            if comma:
                views += ","
            comma = True
            views += "{\"canonical\":" + _quote(name) + ",\"window\":" + _window(window) + "}"
    views += "]"
    var text = _report(describe_unindexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
    var observed = describe_comparison(context.observation)
    context.close()
    print(text)
    print(observed)
    print(views)
    print(_window(selected))


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 66 and args[1] == "indexed":
        _run_indexed(args)
    elif len(args) == 61 and args[1] == "unindexed":
        _run_unindexed(args)
    else:
        raise Error("test: expected mode binding request comparison and selection arguments")
