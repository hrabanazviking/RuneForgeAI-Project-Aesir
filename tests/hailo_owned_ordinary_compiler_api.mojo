# Test-only ordinary mathematical compiler ownership and consumed intent mutations.
from std.sys import argv
from smidr.owned_ordinary_compiler import *
from smidr.semantic_plan import SemanticPlan
from smidr.owned_ordinary_binding import compile_owned_indexed_ordinary, compile_owned_unindexed_ordinary
from smidr.tools.owned_ordinary_binding import _binding_policy
from smidr.tools.owned_ordinary_compiler import _request, _report
from smidr.tools.sealed_source_collection import _indexed, _unindexed, describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.tools.source_inventory import _quote
from hailo_owned_ordinary_binding_api import _damage_schema, _damage_policy, _damage_shard, _cache_shard, _cache_config
from hailo_sealed_collection_api import _mutate
from hailo_sealed_safetensors_api import _window


def _damage_request(mut r: OrdinaryCompilationRequest, field: String) raises:
    if field == "query_tokens":
        r.query_tokens += 1
    elif field == "past_tokens":
        r.past_tokens += 1
    elif field == "context_capacity":
        r.context_capacity += 1
    elif field == "rope_dim":
        r.rope_dim += 2
    elif field == "session_mode":
        r.session_mode = "other"
    elif field == "return_override":
        r.return_override = 1 - r.return_override
    elif field == "source_work":
        r.source_work += 1
    elif field == "scalar_work":
        r.scalar_work += 1
    elif field == "provenance":
        r.provenance = "other"
    elif field == "rotary.pairing":
        r.rotary.pairing = "other"
    elif field == "rotary.provenance":
        r.rotary.provenance = "other"
    elif field == "rotary.max_recipes":
        r.rotary.max_recipes += 1
    elif field == "rotary.work":
        r.rotary.work += 1
    else:
        raise Error("test: unknown request field")


def _damage_plan(mut p: SemanticPlan, operation: Int, field: String) raises:
    if field == "layers":
        p.layers += 1
    elif field == "hidden":
        p.hidden += 1
    elif field == "feed_forward":
        p.feed_forward += 1
    elif field == "heads":
        p.heads += 1
    elif field == "kv_heads":
        p.kv_heads += 1
    elif field == "key_dim":
        p.key_dim += 1
    elif field == "value_dim":
        p.value_dim += 1
    elif field == "rope_dim":
        p.rope_dim += 1
    elif field == "vocabulary":
        p.vocabulary += 1
    elif field == "context_capacity":
        p.context_capacity += 1
    elif field == "query_tokens":
        p.query_tokens += 1
    elif field == "past_tokens":
        p.past_tokens += 1
    elif field == "dynamic_source_context":
        p.dynamic_source_context += 1
    elif field == "dynamic_work":
        p.dynamic_work += 1
    elif field == "bias_work":
        p.bias_work += 1
    elif field == "activation_work":
        p.activation_work += 1
    elif field == "session_work":
        p.session_work += 1
    elif field == "window_work":
        p.window_work += 1
    elif field == "scaling_work":
        p.scaling_work += 1
    elif field == "source_layout":
        p.source_layout = "other"
    elif field == "decoder_policy.output_weight":
        p.decoder_policy.output_weight = "other"
    elif field == "decoder_policy.provenance":
        p.decoder_policy.provenance = "other"
    elif field == "source_scalars.provenance":
        p.source_scalars.provenance = "other"
    elif field == "bias_policy.provenance":
        p.bias_policy.provenance = "other"
    elif field == "activation_policy.provenance":
        p.activation_policy.provenance = "other"
    elif field == "session_policy.provenance":
        p.session_policy.provenance = "other"
    elif field == "window_policy.provenance":
        p.window_policy.provenance = "other"
    elif field == "scaling_policy.provenance":
        p.scaling_policy.provenance = "other"
    elif field == "explicit_scalars":
        p.explicit_scalars = not p.explicit_scalars
    elif field == "explicit_bias":
        p.explicit_bias = not p.explicit_bias
    elif field == "explicit_activation":
        p.explicit_activation = not p.explicit_activation
    elif field == "explicit_session":
        p.explicit_session = not p.explicit_session
    elif field == "explicit_window":
        p.explicit_window = not p.explicit_window
    elif field == "explicit_scaling":
        p.explicit_scaling = not p.explicit_scaling
    elif field == "explicit_dynamic":
        p.explicit_dynamic = not p.explicit_dynamic
    elif field == "rope_base":
        p.rope_base = 3
    elif field == "rms_epsilon":
        p.rms_epsilon = 3
    elif field == "decoder_policy.rope_enabled[0]":
        p.decoder_policy.rope_enabled[0] ^= 1
    elif field == "source_scalars.epsilon.width":
        p.source_scalars.epsilon.width = 32
    elif field == "source_scalars.epsilon.bits":
        p.source_scalars.epsilon.bits ^= 1
    elif field == "source_scalars.rope_base.width":
        p.source_scalars.rope_base.width = 32
    elif field == "source_scalars.rope_base.bits":
        p.source_scalars.rope_base.bits ^= 1
    elif field == "source_scalars.work_limit":
        p.source_scalars.work_limit += 1
    elif field == "bias_policy.attention[0]":
        p.bias_policy.attention[0] ^= 1
    elif field == "bias_policy.mlp[0]":
        p.bias_policy.mlp[0] ^= 1
    elif field == "bias_policy.work":
        p.bias_policy.work += 1
    elif field == "activation_policy.kinds[0]":
        p.activation_policy.kinds[0] = "other"
    elif field == "activation_policy.work":
        p.activation_policy.work += 1
    elif field == "session_policy.mode":
        p.session_policy.mode = "other"
    elif field == "session_policy.return_cache":
        p.session_policy.return_cache ^= 1
    elif field == "session_policy.source_return_cache":
        p.session_policy.source_return_cache ^= 1
    elif field == "session_policy.return_origin":
        p.session_policy.return_origin = "other"
    elif field == "session_policy.work":
        p.session_policy.work += 1
    elif field == "window_policy.windows[0]":
        p.window_policy.windows[0] += 1
    elif field == "window_policy.origin":
        p.window_policy.origin = "other"
    elif field == "window_policy.work":
        p.window_policy.work += 1
    elif field == "scaling_policy.kind":
        p.scaling_policy.kind = "other"
    elif field == "scaling_policy.factor.width":
        p.scaling_policy.factor.width = 32
    elif field == "scaling_policy.factor.bits":
        p.scaling_policy.factor.bits ^= 1
    elif field == "scaling_policy.origin":
        p.scaling_policy.origin = "other"
    elif field == "scaling_policy.work":
        p.scaling_policy.work += 1
    elif field == "cache_exports":
        p.cache_exports .append(-99)
    elif field == "operations[operation].kind":
        p.operations[operation].kind = "other"
    elif field == "operations[operation].weight":
        p.operations[operation].weight = "other"
    elif field == "operations[operation].scaling_kind":
        p.operations[operation].scaling_kind = "other"
    elif field == "operations[operation].output":
        p.operations[operation].output += 1
    elif field == "operations[operation].window_tokens":
        p.operations[operation].window_tokens += 1
    elif field == "operations[operation].position_start":
        p.operations[operation].position_start += 1
    elif field == "operations[operation].dynamic_reference":
        p.operations[operation].dynamic_reference += 1
    elif field == "operations[operation].dynamic_selected":
        p.operations[operation].dynamic_selected += 1
    elif field == "operations[operation].inputs":
        p.operations[operation].inputs.append(-99)
    elif field == "operations[operation].scaling_factor.width":
        p.operations[operation].scaling_factor.width = 32
    elif field == "operations[operation].scaling_factor.bits":
        p.operations[operation].scaling_factor.bits ^= 1
    elif field == "operations[operation].dynamic_factor.width":
        p.operations[operation].dynamic_factor.width = 32
    elif field == "operations[operation].dynamic_factor.bits":
        p.operations[operation].dynamic_factor.bits ^= 1
    elif field == "tensors[p.operations[operation].output].name":
        p.tensors[p.operations[operation].output].name = "other"
    elif field == "tensors[p.operations[operation].output].shape[0]":
        p.tensors[p.operations[operation].output].shape[0] += 1
    elif field == "tensors[p.operations[operation].output].elements":
        p.tensors[p.operations[operation].output].elements += 1
    elif field == "tensors[p.operations[operation].output].producer":
        p.tensors[p.operations[operation].output].producer += 1
    elif field == "tensors[p.operations[operation].output].last_use":
        p.tensors[p.operations[operation].output].last_use += 1
    elif field == "tensors[p.operations[operation].output].persistent":
        p.tensors[p.operations[operation].output].persistent = not p.tensors[p.operations[operation].output].persistent
    elif field == "tensors[p.operations[operation].output].alias_of":
        p.tensors[p.operations[operation].output].alias_of += 1
    elif field == "source.storage[\"token_embd.weight\"].original_name":
        p.source.storage["token_embd.weight"].original_name = "other"
    elif field == "source.storage[\"token_embd.weight\"].file_offset":
        p.source.storage["token_embd.weight"].file_offset += 1
    elif field == "source.bindings[\"token_embd.weight\"].columns":
        p.source.bindings["token_embd.weight"].columns += 1
    elif field == "source.architecture":
        p.source.architecture = "other"
    elif field == "source.alias_provenance":
        p.source.alias_provenance = "other"
    elif field == "source.source_bytes":
        p.source.source_bytes += 1
    elif field == "source.data_offset":
        p.source.data_offset += 1
    elif field == "source.weight_bytes":
        p.source.weight_bytes += 1
    elif field == "source.bindings[\"token_embd.weight\"].source_kind":
        p.source.bindings["token_embd.weight"].source_kind += 1
    elif field == "source.bindings[\"token_embd.weight\"].byte_count":
        p.source.bindings["token_embd.weight"].byte_count += 1
    elif field == "source.bindings[\"token_embd.weight\"].rows":
        p.source.bindings["token_embd.weight"].rows += 1
    elif field == "source.bindings[\"token_embd.weight\"].file_offset":
        p.source.bindings["token_embd.weight"].file_offset += 1
    elif field == "source.storage[\"token_embd.weight\"].source_format":
        p.source.storage["token_embd.weight"].source_format = "other"
    elif field == "source.storage[\"token_embd.weight\"].source_path":
        p.source.storage["token_embd.weight"].source_path = "other"
    elif field == "source.storage[\"token_embd.weight\"].axis_order":
        p.source.storage["token_embd.weight"].axis_order = "other"
    elif field == "source.storage[\"token_embd.weight\"].source_kind":
        p.source.storage["token_embd.weight"].source_kind += 1
    elif field == "source.storage[\"token_embd.weight\"].byte_count":
        p.source.storage["token_embd.weight"].byte_count += 1
    elif field == "source.storage[\"token_embd.weight\"].elements":
        p.source.storage["token_embd.weight"].elements += 1
    elif field == "source.storage[\"token_embd.weight\"].source_shape[0]":
        p.source.storage["token_embd.weight"].source_shape[0] += 1
    elif field == "source.policy.files":
        p.source.policy.files += 1
    elif field == "source.policy.tensors":
        p.source.policy.tensors += 1
    elif field == "source.policy.rank":
        p.source.policy.rank += 1
    elif field == "source.policy.work":
        p.source.policy.work += 1
    elif field == "source.files[p.source.storage[\"token_embd.weight\"].source_path].source_format":
        p.source.files[p.source.storage["token_embd.weight"].source_path].source_format = "other"
    elif field == "source.files[p.source.storage[\"token_embd.weight\"].source_path].source_bytes":
        p.source.files[p.source.storage["token_embd.weight"].source_path].source_bytes += 1
    elif field == "source.files[p.source.storage[\"token_embd.weight\"].source_path].data_offset":
        p.source.files[p.source.storage["token_embd.weight"].source_path].data_offset += 1
    else:
        raise Error("test: unknown plan field")


def _move_indexed(var context: OwnedIndexedOrdinaryCompiler) -> OwnedIndexedOrdinaryCompiler:
    return context^


def _run_indexed(args: List[String], mode: String) raises:
    var policy = _binding_policy(args, 3, True)
    var request = _request(args, 47)
    var operation = Int(args[60])
    var first = Int(args[61])
    var count = Int(args[62])
    var cap = Int(args[63])
    var owner = _indexed(args, 3)
    var binding = compile_owned_indexed_ordinary(owner^, policy)
    if mode == "pre_cache":
        _cache_config(binding.owner.config)
        _cache_shard(binding.owner.shards[0])
    if mode.startswith("before:"):
        _mutate(binding.owner.config.label, String(mode[byte=7:]))
        _mutate(binding.owner.shards[0].owner.label, String(mode[byte=7:]))
    if mode.startswith("pre_schema:"):
        _damage_schema(binding.schema, String(mode[byte=11:]))
    if mode.startswith("pre_shard:"):
        _damage_shard(binding.owner.shards[0], String(mode[byte=10:]))
    var context = compile_owned_indexed_ordinary_graph(binding^, policy, request)
    if mode == "move":
        context = _move_indexed(context^)
    if mode == "post_cache":
        _cache_config(context.binding.owner.config)
        _cache_shard(context.binding.owner.shards[0])
    if mode.startswith("after:"):
        _mutate(context.binding.owner.config.label, String(mode[byte=6:]))
        _mutate(context.binding.owner.shards[0].owner.label, String(mode[byte=6:]))
    if mode.startswith("schema:"):
        _damage_schema(context.binding.schema, String(mode[byte=7:]))
    if mode.startswith("policy:"):
        _damage_policy(context.binding.policy, String(mode[byte=7:]))
    if mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    if mode.startswith("request:"):
        _damage_request(context.request, String(mode[byte=8:]))
    if mode.startswith("supplied:"):
        _damage_request(request, String(mode[byte=9:]))
    if mode.startswith("plan:"):
        _damage_plan(context.graph.source, operation, String(mode[byte=5:]))
    if mode.startswith("post_shard:"):
        _damage_shard(context.binding.owner.shards[0], String(mode[byte=11:]))
    if mode == "closed":
        context.close()
    if mode == "recover":
        context.graph.source.hidden += 1
        var refused = False
        try:
            _ = read_owned_indexed_operation_component(context, operation, first, count, cap, policy, request)
        except:
            refused = True
        context.graph.source.hidden -= 1
        if not refused:
            raise Error("test: changed graph selection accepted")
    var one = read_owned_indexed_operation_component(context, operation, first, count, cap, policy, request)
    var two = read_owned_indexed_operation_component(context, operation, first, count, cap, policy, request)
    var saved = _window(two)
    var windows = String("[")
    if mode == "all":
        var n = 0
        for i in range(len(context.graph.source.operations)):
            var name = context.graph.source.operations[i].weight
            if name.byte_length() == 0:
                continue
            var elements = context.graph.source.source.storage[name].elements
            var window = read_owned_indexed_operation_component(context, i, 0, elements, 131072, policy, request)
            if n != 0:
                windows += ","
            windows += "{\"operation\":" + String(i) + ",\"canonical\":" + _quote(name) + ",\"window\":" + _window(window) + "}"
            n += 1
    var text = _report(describe_indexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
    context.close()
    context.close()
    if len(one.raw_words) > 0:
        one.raw_words[0] ^= 1
    if _window(two) != saved:
        raise Error("test: component copies alias or depend on owner")
    print(text)
    print(windows + "]")
    print(saved)


def _move_unindexed(var context: OwnedUnindexedOrdinaryCompiler) -> OwnedUnindexedOrdinaryCompiler:
    return context^


def _run_unindexed(args: List[String], mode: String) raises:
    var policy = _binding_policy(args, 3, False)
    var request = _request(args, 42)
    var operation = Int(args[55])
    var first = Int(args[56])
    var count = Int(args[57])
    var cap = Int(args[58])
    var owner = _unindexed(args, 3)
    var binding = compile_owned_unindexed_ordinary(owner^, policy)
    if mode == "pre_cache":
        _cache_config(binding.owner.config)
        _cache_shard(binding.owner.shard)
    if mode.startswith("before:"):
        _mutate(binding.owner.config.label, String(mode[byte=7:]))
        _mutate(binding.owner.shard.owner.label, String(mode[byte=7:]))
    if mode.startswith("pre_schema:"):
        _damage_schema(binding.schema, String(mode[byte=11:]))
    if mode.startswith("pre_shard:"):
        _damage_shard(binding.owner.shard, String(mode[byte=10:]))
    var context = compile_owned_unindexed_ordinary_graph(binding^, policy, request)
    if mode == "move":
        context = _move_unindexed(context^)
    if mode == "post_cache":
        _cache_config(context.binding.owner.config)
        _cache_shard(context.binding.owner.shard)
    if mode.startswith("after:"):
        _mutate(context.binding.owner.config.label, String(mode[byte=6:]))
        _mutate(context.binding.owner.shard.owner.label, String(mode[byte=6:]))
    if mode.startswith("schema:"):
        _damage_schema(context.binding.schema, String(mode[byte=7:]))
    if mode.startswith("policy:"):
        _damage_policy(context.binding.policy, String(mode[byte=7:]))
    if mode.startswith("external:"):
        _damage_policy(policy, String(mode[byte=9:]))
    if mode.startswith("request:"):
        _damage_request(context.request, String(mode[byte=8:]))
    if mode.startswith("supplied:"):
        _damage_request(request, String(mode[byte=9:]))
    if mode.startswith("plan:"):
        _damage_plan(context.graph.source, operation, String(mode[byte=5:]))
    if mode.startswith("post_shard:"):
        _damage_shard(context.binding.owner.shard, String(mode[byte=11:]))
    if mode == "closed":
        context.close()
    if mode == "recover":
        context.graph.source.hidden += 1
        var refused = False
        try:
            _ = read_owned_unindexed_operation_component(context, operation, first, count, cap, policy, request)
        except:
            refused = True
        context.graph.source.hidden -= 1
        if not refused:
            raise Error("test: changed graph selection accepted")
    var one = read_owned_unindexed_operation_component(context, operation, first, count, cap, policy, request)
    var two = read_owned_unindexed_operation_component(context, operation, first, count, cap, policy, request)
    var saved = _window(two)
    var windows = String("[")
    if mode == "all":
        var n = 0
        for i in range(len(context.graph.source.operations)):
            var name = context.graph.source.operations[i].weight
            if name.byte_length() == 0:
                continue
            var elements = context.graph.source.source.storage[name].elements
            var window = read_owned_unindexed_operation_component(context, i, 0, elements, 131072, policy, request)
            if n != 0:
                windows += ","
            windows += "{\"operation\":" + String(i) + ",\"canonical\":" + _quote(name) + ",\"window\":" + _window(window) + "}"
            n += 1
    var text = _report(describe_unindexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
    context.close()
    context.close()
    if len(one.raw_words) > 0:
        one.raw_words[0] ^= 1
    if _window(two) != saved:
        raise Error("test: component copies alias or depend on owner")
    print(text)
    print(windows + "]")
    print(saved)


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 64 and args[1] == "indexed":
        _run_indexed(args, args[2])
    elif len(args) == 59 and args[1] == "unindexed":
        _run_unindexed(args, args[2])
    else:
        raise Error("test: expected mode case binding/request and operation first count bound")
