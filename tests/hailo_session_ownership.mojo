# Test-only ownership proof through public builders and recipe snapshots.
from std.sys import argv
from hailo_decoder_session_api import session_fixture
from smidr.session_policy import same_session_policy
from smidr.activation_policy import same_activation_policy
from smidr.source_inventory import SourceTensorInventory
from smidr.semantic_plan import DecoderGeometry, DenseDecoderParameters, build_decoder_semantic_plan
from smidr.source_scalars import ScalarWord
from smidr.bias_policy import same_bias_policy
from smidr.rotary_policy import RotaryLoweringPolicy
from smidr.primitive_recipes import lower_primitive_recipes
from smidr.expanded_graph import expand_semantic_graph
from smidr.tools.rotary_recipes import describe_rotary_graph


def main() raises:
    var args = argv()
    if len(args) != 7:
        raise Error("expected root weight config scalar_mode mode returned")
    var past = 0 if args[5] == "full_prefix" else 1
    var rotary = RotaryLoweringPolicy("split_half", "explicit synthetic bias basis", 10000, 10000000)
    var reference = session_fixture(args[1], args[2], args[3], "1,1", "1,1", args[4], "gelu_erf,relu", args[5], Int(args[6]), past, 8)
    var expected_graph = expand_semantic_graph(reference^, rotary)
    var expected = describe_rotary_graph(expected_graph, rotary)
    var seed = session_fixture(args[1], args[2], args[3], "1,1", "1,1", args[4], "gelu_erf,relu", args[5], Int(args[6]), past, 8)
    var geometry = DecoderGeometry(seed.layers, seed.hidden, seed.feed_forward,
        seed.heads, seed.kv_heads, seed.key_dim, seed.value_dim, seed.rope_dim,
        seed.vocabulary, 64, seed.source_layout)
    var scalars = seed.source_scalars.copy()
    var bias = seed.bias_policy.copy()
    var activation = seed.activation_policy.copy()
    var session = seed.session_policy.copy()
    var decoder = seed.decoder_policy.copy()
    var source = seed.source^
    seed.source = SourceTensorInventory()
    if args[4] == "source64":
        var plan = build_decoder_semantic_plan(source^, geometry, scalars, decoder, bias, activation, session, 2, past, 8)
        session.mode = "changed"
        session.return_cache = 2
        session.source_return_cache = 2
        session.return_origin = "changed"
        session.provenance = "changed"
        session.work = 1
        activation.kinds[0] = "changed"
        activation.provenance = "changed"
        activation.work = 1
        geometry.hidden += 1
        scalars.epsilon = ScalarWord(0, 0)
        bias.attention[0] = 0
        bias.mlp[0] = 0
        bias.provenance = "changed"
        bias.work = 1
        decoder.rope_enabled[0] = 1
        decoder.output_weight = "changed"
        decoder.provenance = "changed"
        var graph = expand_semantic_graph(plan^, rotary)
        if describe_rotary_graph(graph, rotary) != expected:
            raise Error("source64 builder aliases caller policy/scalar state")
    elif args[4] == "requested32":
        var parameters = DenseDecoderParameters(geometry.layers, geometry.hidden, geometry.feed_forward,
            geometry.heads, geometry.kv_heads, geometry.key_dim, geometry.value_dim, geometry.rope_dim,
            geometry.vocabulary, geometry.source_context, seed.rope_base, seed.rms_epsilon, geometry.source_layout)
        var plan = build_decoder_semantic_plan(source^, parameters, decoder, bias, activation, session, 2, past, 8)
        session.mode = "changed"
        session.return_cache = 2
        session.source_return_cache = 2
        session.return_origin = "changed"
        session.provenance = "changed"
        session.work = 1
        activation.kinds[0] = "changed"
        activation.provenance = "changed"
        activation.work = 1
        parameters.hidden += 1
        bias.attention[0] = 0
        bias.mlp[0] = 0
        bias.provenance = "changed"
        bias.work = 1
        decoder.rope_enabled[0] = 1
        decoder.output_weight = "changed"
        decoder.provenance = "changed"
        var graph = expand_semantic_graph(plan^, rotary)
        if describe_rotary_graph(graph, rotary) != expected:
            raise Error("scalar32 builder aliases caller policy state")
    else:
        raise Error("unknown scalar mode")
    var plan = session_fixture(args[1], args[2], args[3], "1,1", "1,1", args[4], "gelu_erf,relu", args[5], Int(args[6]), past, 8)
    var lowered = lower_primitive_recipes(plan, rotary)
    var saved = lowered.session_policy.copy()
    var saved_exports = lowered.cache_exports.copy()
    plan.session_policy.mode = "changed"
    plan.session_policy.return_cache = 2
    plan.session_policy.source_return_cache = 2
    plan.session_policy.return_origin = "changed"
    plan.session_policy.provenance = "changed"
    plan.session_policy.work = 1
    plan.cache_exports.append(0)
    plan.activation_policy.kinds[0] = "changed"
    plan.activation_policy.provenance = "changed"
    plan.activation_policy.work = 1
    plan.bias_policy.attention[0] = 0
    plan.bias_policy.mlp[0] = 0
    plan.bias_policy.provenance = "changed"
    plan.bias_policy.work = 1
    if not same_session_policy(saved, lowered.session_policy) or saved_exports != lowered.cache_exports:
        raise Error("lowered bias snapshot aliases mutable source plan")
    for _ in range(20):
        var refused = False
        try:
            _ = session_fixture(args[1], args[2], args[3], "1,1", "1,1", args[4], "gelu_erf,relu", args[5], 2, past, 8)
        except:
            refused = True
        if not refused:
            raise Error("invalid bias flag accepted during recovery cycle")
        var fresh = session_fixture(args[1], args[2], args[3], "1,1", "1,1", args[4], "gelu_erf,relu", args[5], Int(args[6]), past, 8)
        var graph = expand_semantic_graph(fresh^, rotary)
        if describe_rotary_graph(graph, rotary) != expected:
            raise Error("fresh bias graph changed after refusal/recovery cycle")
    print(expected)
