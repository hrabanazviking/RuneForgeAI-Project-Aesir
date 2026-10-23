from pathlib import Path
import json
out=Path('tests/hailo_owned_ordinary_compiler_api.mojo')
s='''# Test-only ordinary mathematical compiler ownership and consumed intent mutations.
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
'''
req={'query_tokens':' += 1','past_tokens':' += 1','context_capacity':' += 1','rope_dim':' += 2','session_mode':' = "other"','return_override':' = 1 - r.return_override','source_work':' += 1','scalar_work':' += 1','provenance':' = "other"','rotary.pairing':' = "other"','rotary.provenance':' = "other"','rotary.max_recipes':' += 1','rotary.work':' += 1'}
for i,(f,v) in enumerate(req.items()):s+=f'    {"if" if i==0 else "elif"} field == {json.dumps(f)}:\n        r.{f}{v}\n'
s+='    else:\n        raise Error("test: unknown request field")\n\n\ndef _damage_plan(mut p: SemanticPlan, operation: Int, field: String) raises:\n'
fields={}
for f in ['layers','hidden','feed_forward','heads','kv_heads','key_dim','value_dim','rope_dim','vocabulary','context_capacity','query_tokens','past_tokens','dynamic_source_context','dynamic_work','bias_work','activation_work','session_work','window_work','scaling_work']:fields[f]=' += 1'
for f in ['source_layout','decoder_policy.output_weight','decoder_policy.provenance','source_scalars.provenance','bias_policy.provenance','activation_policy.provenance','session_policy.provenance','window_policy.provenance','scaling_policy.provenance']:fields[f]=' = "other"'
for f in ['explicit_scalars','explicit_bias','explicit_activation','explicit_session','explicit_window','explicit_scaling','explicit_dynamic']:fields[f]=f' = not p.{f}'
fields.update({'rope_base':' = 3','rms_epsilon':' = 3','decoder_policy.rope_enabled[0]':' ^= 1','source_scalars.epsilon.width':' = 32','source_scalars.epsilon.bits':' ^= 1','source_scalars.rope_base.width':' = 32','source_scalars.rope_base.bits':' ^= 1','source_scalars.work_limit':' += 1','bias_policy.attention[0]':' ^= 1','bias_policy.mlp[0]':' ^= 1','bias_policy.work':' += 1','activation_policy.kinds[0]':' = "other"','activation_policy.work':' += 1','session_policy.mode':' = "other"','session_policy.return_cache':' ^= 1','session_policy.source_use_cache':' ^= 1','session_policy.origin':' = "other"','session_policy.work':' += 1','window_policy.windows[0]':' += 1','window_policy.origin':' = "other"','window_policy.work':' += 1','scaling_policy.kind':' = "other"','scaling_policy.factor.width':' = 32','scaling_policy.factor.bits':' ^= 1','scaling_policy.origin':' = "other"','scaling_policy.work':' += 1','cache_exports':' .append(-99)'})
# Resolve exact policy field names from sources before emitting below.
sources={n:Path('smidr/'+n+'_policy.mojo').read_text() for n in ['session','window']}
# Explicit actual names, not a parallel parser implementation.
fields={k.replace('session_policy.source_use_cache','session_policy.source_return_cache').replace('session_policy.origin','session_policy.return_origin'):v for k,v in fields.items()}
for f in ['kind','weight','scaling_kind']:fields['operations[operation].'+f]=' = "other"'
for f in ['output','window_tokens','position_start','dynamic_reference','dynamic_selected']:fields['operations[operation].'+f]=' += 1'
fields.update({'operations[operation].inputs':'.append(-99)','operations[operation].scaling_factor.width':' = 32','operations[operation].scaling_factor.bits':' ^= 1','operations[operation].dynamic_factor.width':' = 32','operations[operation].dynamic_factor.bits':' ^= 1','tensors[p.operations[operation].output].name':' = "other"','tensors[p.operations[operation].output].shape[0]':' += 1','tensors[p.operations[operation].output].elements':' += 1','tensors[p.operations[operation].output].producer':' += 1','tensors[p.operations[operation].output].last_use':' += 1','tensors[p.operations[operation].output].persistent':' = not p.tensors[p.operations[operation].output].persistent','tensors[p.operations[operation].output].alias_of':' += 1','source.storage["token_embd.weight"].original_name':' = "other"','source.storage["token_embd.weight"].file_offset':' += 1','source.bindings["token_embd.weight"].columns':' += 1','source.architecture':' = "other"','source.alias_provenance':' = "other"','source.source_bytes':' += 1','source.data_offset':' += 1','source.weight_bytes':' += 1'})
for f in ['source_kind','byte_count','rows','file_offset']:
 fields['source.bindings["token_embd.weight"].'+f]=' += 1'
for f in ['source_format','source_path','axis_order']:
 fields['source.storage["token_embd.weight"].'+f]=' = "other"'
for f in ['source_kind','byte_count','elements']:
 fields['source.storage["token_embd.weight"].'+f]=' += 1'
fields['source.storage["token_embd.weight"].source_shape[0]']=' += 1'
for f in ['files','tensors','rank','work']:
 fields['source.policy.'+f]=' += 1'
fields['source.files[p.source.storage["token_embd.weight"].source_path].source_format']=' = "other"'
for f in ['source_bytes','data_offset']:
 fields['source.files[p.source.storage["token_embd.weight"].source_path].'+f]=' += 1'
for i,(f,v) in enumerate(fields.items()):s+=f'    {"if" if i==0 else "elif"} field == {json.dumps(f)}:\n        p.{f}{v}\n'
s+='    else:\n        raise Error("test: unknown plan field")\n'
for kind,start,count in [('indexed',47,64),('unindexed',42,59)]:
 load='_indexed' if kind=='indexed' else '_unindexed';own='owner.shards[0]' if kind=='indexed' else 'owner.shard';ctxshard='context.binding.owner.shards[0]' if kind=='indexed' else 'context.binding.owner.shard'
 s+=f'''

def _move_{kind}(var context: Owned{kind.title()}OrdinaryCompiler) -> Owned{kind.title()}OrdinaryCompiler:
    return context^


def _run_{kind}(args: List[String], mode: String) raises:
    var policy = _binding_policy(args, 3, {str(kind=='indexed')})
    var request = _request(args, {start})
    var operation = Int(args[{start+13}])
    var first = Int(args[{start+14}])
    var count = Int(args[{start+15}])
    var cap = Int(args[{start+16}])
    var owner = {load}(args, 3)
    var binding = compile_owned_{kind}_ordinary(owner^, policy)
    if mode == "pre_cache":
        _cache_config(binding.owner.config)
        _cache_shard(binding.{own})
    if mode.startswith("before:"):
        _mutate(binding.owner.config.label, String(mode[byte=7:]))
        _mutate(binding.{own}.owner.label, String(mode[byte=7:]))
    if mode.startswith("pre_schema:"):
        _damage_schema(binding.schema, String(mode[byte=11:]))
    if mode.startswith("pre_shard:"):
        _damage_shard(binding.{own}, String(mode[byte=10:]))
    var context = compile_owned_{kind}_ordinary_graph(binding^, policy, request)
    if mode == "move":
        context = _move_{kind}(context^)
    if mode == "post_cache":
        _cache_config(context.binding.owner.config)
        _cache_shard({ctxshard})
    if mode.startswith("after:"):
        _mutate(context.binding.owner.config.label, String(mode[byte=6:]))
        _mutate({ctxshard}.owner.label, String(mode[byte=6:]))
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
        _damage_shard({ctxshard}, String(mode[byte=11:]))
    if mode == "closed":
        context.close()
    if mode == "recover":
        context.graph.source.hidden += 1
        var refused = False
        try:
            _ = read_owned_{kind}_operation_component(context, operation, first, count, cap, policy, request)
        except:
            refused = True
        context.graph.source.hidden -= 1
        if not refused:
            raise Error("test: changed graph selection accepted")
    var one = read_owned_{kind}_operation_component(context, operation, first, count, cap, policy, request)
    var two = read_owned_{kind}_operation_component(context, operation, first, count, cap, policy, request)
    var saved = _window(two)
    var windows = String("[")
    if mode == "all":
        var n = 0
        for i in range(len(context.graph.source.operations)):
            var name = context.graph.source.operations[i].weight
            if name.byte_length() == 0:
                continue
            var elements = context.graph.source.source.storage[name].elements
            var window = read_owned_{kind}_operation_component(context, i, 0, elements, 131072, policy, request)
            if n != 0:
                windows += ","
            windows += "{{\\"operation\\":" + String(i) + ",\\"canonical\\":" + _quote(name) + ",\\"window\\":" + _window(window) + "}}"
            n += 1
    var text = _report(describe_{kind}(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
    context.close()
    context.close()
    if len(one.raw_words) > 0:
        one.raw_words[0] ^= 1
    if _window(two) != saved:
        raise Error("test: component copies alias or depend on owner")
    print(text)
    print(windows + "]")
    print(saved)
'''
s+='''

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
'''
out.write_text(s)
import json
Path('../owned-ordinary-compiler-native-development/mutations.json').write_text(json.dumps({'requests':list(req),'plans':list(fields)},indent=2)+'\n')
