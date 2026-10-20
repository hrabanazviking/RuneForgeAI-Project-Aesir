# Test-only typed policy ownership and adversarial graph checks. No math.
from std.sys import argv
from smidr.semantic_plan import DecoderGraphPolicy, build_decoder_semantic_plan
from smidr.source_inventory import SourceTensorInventory
from smidr.tools.typed_decoder import _from_file
from smidr.tools.decoder_graph_policy import parse_rotary_flags, describe_decoder_graph
from smidr.tools.semantic_storage import append_path
from smidr.cache_layout import CacheLayoutAssumptions, plan_cache_layout
from smidr.source_config import SourceConfigPolicy, read_source_config
from smidr.decoder_layers import DecoderLayerPolicy, source_decoder_layers, validate_decoder_layers


def main() raises:
    var args = argv()
    if len(args) < 4:
        raise Error("expected metadata.gguf mask test_case [source/config paths]")
    var input = _from_file(args[1])
    var source = input.take_inventory()
    var mode = String(args[3])
    var policy = DecoderGraphPolicy(parse_rotary_flags(args[2]), "output.weight", "synthetic typed test policy")
    if mode == "safe":
        source = SourceTensorInventory()
        source.architecture = "explicit synthetic safetensors mathematical recipe"
        for i in range(4, len(args)):
            append_path(source, "safetensors", args[i], "")
    elif mode == "intent":
        if len(args) != 5:
            raise Error("expected ordinary config path")
        var config = read_source_config(args[4], SourceConfigPolicy(1048576, 10000, 10000000, 64))
        var intent = source_decoder_layers(config, DecoderLayerPolicy(1000, 100000, 10000000))
        validate_decoder_layers(intent, intent.policy)
        policy.rope_enabled = intent.rope_enabled.copy()
        policy.provenance = "typed test mask from owned ordinary intent; other semantics unresolved"
        if len(intent.source.fields) != len(config.fields):
            raise Error("lost full config snapshot")
        config.fields.clear()
        validate_decoder_layers(intent, intent.policy)
    elif mode == "source_work":
        source.policy.work = 1
    elif mode == "source_tensors":
        source.policy.tensors = 1
    elif mode == "policy_exact" or mode == "policy_short":
        source.policy.work = 10000
        policy.provenance = ""
        for _ in range(10000 - len(policy.rope_enabled) - policy.output_weight.byte_length()):
            policy.provenance += "x"
        if mode == "policy_short":
            source.policy.work -= 1
    var plan = build_decoder_semantic_plan(source^, input.parameters, policy, 3, 2, 16)
    if mode == "ownership":
        var flags = policy.rope_enabled.copy()
        policy.rope_enabled.clear()
        policy.output_weight = "changed"
        policy.provenance = "changed"
        if len(plan.decoder_policy.rope_enabled) != len(flags) or plan.decoder_policy.output_weight != "output.weight" or plan.decoder_policy.provenance != "synthetic typed test policy":
            raise Error("policy owner alias")
        for i in range(len(flags)):
            if plan.decoder_policy.rope_enabled[i] != flags[i]:
                raise Error("policy flags alias")
    elif mode != "safe" and mode != "intent" and mode != "valid" and mode != "policy_exact":
        var base = -1
        var view = -1
        var key = -1
        var positions = -1
        var norm = -1
        var rotary = -1
        for i in range(len(plan.tensors)):
            var name = plan.tensors[i].name
            if name == "blk.0.key_cache":
                base = i
            elif name == "blk.0.keys_view":
                view = i
            elif name == "blk.0.k":
                key = i
            elif name == "positions":
                positions = i
            elif name == "blk.0.attn_norm":
                norm = i
            elif name == "blk.0.k_rotary":
                rotary = i
        var writer = rotary if plan.decoder_policy.rope_enabled[0] == 1 else key
        var append = plan.tensors[view].producer
        var projection = plan.tensors[key].producer
        var writer_op = plan.tensors[writer].producer
        if mode == "mask_flip":
            plan.decoder_policy.rope_enabled[0] = 1 - plan.decoder_policy.rope_enabled[0]
        elif mode == "mask_invalid":
            plan.decoder_policy.rope_enabled[0] = 2
        elif mode == "mask_short":
            plan.decoder_policy.rope_enabled.clear()
        elif mode == "provenance_empty":
            plan.decoder_policy.provenance = ""
        elif mode == "provenance_bound":
            plan.source.policy.work = 1
        elif mode == "output_missing":
            plan.decoder_policy.output_weight = "missing"
        elif mode == "output_changed":
            plan.decoder_policy.output_weight = "token_embd.weight"
        elif mode == "append_writer":
            plan.operations[append].inputs[1] = base
        elif mode == "projection_input":
            plan.operations[projection].inputs[0] = base
        elif mode == "projection_arity":
            plan.operations[projection].inputs = [norm, positions]
        elif mode == "projection_weight":
            plan.operations[projection].weight = "blk.0.attn_v.weight"
        elif mode == "projection_shape":
            plan.tensors[key].shape[0] += 1
        elif mode == "projection_producer":
            plan.tensors[key].producer = append
        elif mode == "projection_alias":
            plan.tensors[key].alias_of = base
        elif mode == "projection_lifetime":
            plan.tensors[key].last_use -= 1
        elif mode == "norm_shape":
            plan.tensors[norm].shape[0] += 1
        elif mode == "norm_producer":
            plan.tensors[norm].producer = projection
        elif mode == "writer_lifetime":
            plan.tensors[writer].last_use -= 1
        elif mode == "writer_kind":
            plan.operations[writer_op].kind = "other"
        elif mode == "writer_output":
            plan.operations[writer_op].output = base
        elif mode == "position_shape":
            plan.tensors[positions].shape[0] += 1
        elif mode == "position_lifetime":
            plan.tensors[positions].last_use -= 1
        elif mode == "norm_output":
            plan.operations[plan.tensors[norm].producer].output = key
        elif mode == "output_consumed":
            plan.used_weights["output.weight"] = False
        elif mode == "output_shape":
            plan.tensors[plan.logits].shape[1] += 1
        elif mode == "position_owner":
            plan.tensors[positions].persistent = True
        elif mode == "rotary_input":
            plan.operations[writer_op].inputs[0] = base
        elif mode == "rotary_position":
            plan.operations[writer_op].inputs[1] = norm
        elif mode == "rotary_weight":
            plan.operations[writer_op].weight = "blk.0.attn_k.weight"
        elif mode == "view_lifetime":
            plan.tensors[view].last_use -= 1
        elif mode == "base_lifetime":
            plan.tensors[base].last_use -= 1
        else:
            raise Error("unknown test mutation")
        var layout = plan_cache_layout(plan, CacheLayoutAssumptions(2, 1, 64, 64, 64, 1048576, "test"))
        print(layout.total_bytes)
        return
    print(describe_decoder_graph(plan^))
