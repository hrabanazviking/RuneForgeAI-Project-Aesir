# Original retained ordinary source-to-mathematical-graph lifetime.
# No complete architecture admission, target encoding or numerical execution.
from smidr.owned_ordinary_binding import (
    OrdinaryBindingPolicy, OwnedIndexedOrdinaryBinding, OwnedUnindexedOrdinaryBinding,
    _refresh_indexed, _refresh_unindexed, _same_binding_policy, _same_schema,
    load_owned_indexed_ordinary, load_owned_unindexed_ordinary,
    read_owned_indexed_component, read_owned_unindexed_component,
)
from smidr.source_root import SourceRootPolicy
from smidr.sealed_source_collection import SealedCollectionCopyPolicy
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema
from smidr.decoder_projections import _same_source
from smidr.source_inventory import SourceTensorInventory
from smidr.decoder_scalar_source import source_decoder_scalars
from smidr.decoder_activation_source import source_decoder_activations
from smidr.decoder_session_source import source_decoder_session
from smidr.decoder_window_source import source_decoder_windows
from smidr.decoder_scaling_source import source_decoder_scaling
from smidr.bias_policy import DecoderBiasPolicy, same_bias_policy
from smidr.activation_policy import same_activation_policy
from smidr.session_policy import same_session_policy
from smidr.window_policy import same_window_policy
from smidr.scaling_policy import same_scaling_policy
from smidr.source_scalars import same_decoder_scalars, same_scalar_word
from smidr.bias_graph import validate_plan_bias_state
from smidr.activation_graph import validate_plan_activation_state
from smidr.session_graph import validate_plan_session_state
from smidr.semantic_plan import (
    SemanticPlan, DecoderGeometry, DecoderGraphPolicy, build_decoder_semantic_plan,
    validate_plan_scalar_state, validate_plan_window_state, validate_plan_scaling_state,
    validate_plan_dynamic_state,
)
from smidr.rotary_policy import RotaryLoweringPolicy, validate_rotary_policy
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.safetensors_constants import SafetensorsConstantWindow


@fieldwise_init
struct OrdinaryCompilationRequest(Copyable, Movable):
    var query_tokens: Int
    var past_tokens: Int
    var context_capacity: Int
    # Explicit selected mathematical width and pairing, not inferred device layout.
    var rope_dim: Int
    var session_mode: String
    var return_override: Int
    var source_work: Int
    var scalar_work: Int
    var provenance: String
    var rotary: RotaryLoweringPolicy


@fieldwise_init
struct OwnedIndexedOrdinaryCompiler(Movable):
    var binding: OwnedIndexedOrdinaryBinding
    var graph: ExpandedGraph
    var request: OrdinaryCompilationRequest

    def close(mut self) raises:
        self.binding.close()


@fieldwise_init
struct OwnedUnindexedOrdinaryCompiler(Movable):
    var binding: OwnedUnindexedOrdinaryBinding
    var graph: ExpandedGraph
    var request: OrdinaryCompilationRequest

    def close(mut self) raises:
        self.binding.close()


def _admit_request(schema: OrdinaryProjectionSchema, r: OrdinaryCompilationRequest) raises:
    var limit = min(schema.binding.source.policy.work, schema.binding.architecture.policy.work)
    if r.source_work <= 0 or r.source_work > limit or r.scalar_work <= 0 or r.scalar_work > limit or r.rotary.work <= 0 or r.rotary.work > limit or r.rotary.max_recipes <= 0:
        raise Error("OwnedOrdinaryCompiler: explicit bounded interpreter/recipe work required")
    if r.provenance.byte_length() == 0 or r.provenance.byte_length() > r.source_work or r.session_mode.byte_length() > r.source_work - r.provenance.byte_length():
        raise Error("OwnedOrdinaryCompiler: bounded request provenance required")
    if r.rotary.provenance.byte_length() == 0 or r.rotary.provenance.byte_length() > r.rotary.work or r.rotary.pairing.byte_length() > r.rotary.work - r.rotary.provenance.byte_length():
        raise Error("OwnedOrdinaryCompiler: bounded rotary provenance required")
    var layers = schema.binding.architecture.layers.layer_count
    if layers <= 0 or layers > r.source_work // 128:
        raise Error("OwnedOrdinaryCompiler: layer policy allocation bound exceeded")


def _same_request(a: OrdinaryCompilationRequest, b: OrdinaryCompilationRequest) raises:
    if a.query_tokens != b.query_tokens or a.past_tokens != b.past_tokens or a.context_capacity != b.context_capacity or a.rope_dim != b.rope_dim or a.session_mode != b.session_mode or a.return_override != b.return_override or a.source_work != b.source_work or a.scalar_work != b.scalar_work or a.provenance != b.provenance or a.rotary.pairing != b.rotary.pairing or a.rotary.provenance != b.rotary.provenance or a.rotary.max_recipes != b.rotary.max_recipes or a.rotary.work != b.rotary.work:
        raise Error("OwnedOrdinaryCompiler: supplied and owned compilation request differ")


def _ordinary_plan(mut schema: OrdinaryProjectionSchema,
                   r: OrdinaryCompilationRequest) raises -> SemanticPlan:
    _admit_request(schema, r)
    ref architecture = schema.binding.architecture
    var geometry = DecoderGeometry(architecture.layers.layer_count,
        architecture.dimensions["hidden_size"], architecture.dimensions["intermediate_size"],
        architecture.dimensions["num_attention_heads"], architecture.dimensions["num_key_value_heads"],
        schema.binding.key_dim, schema.binding.value_dim, r.rope_dim,
        architecture.dimensions["vocab_size"], architecture.dimensions["max_position_embeddings"],
        "row_major_outermost_first")
    var scalars = source_decoder_scalars(architecture, r.provenance, r.scalar_work)
    var policy = DecoderGraphPolicy(architecture.layers.rope_enabled.copy(),
        schema.binding.output_weight, r.provenance)
    var attention = List[Int]()
    var mlp = List[Int]()
    for _ in range(geometry.layers):
        attention.append(Int(architecture.flags["attention_bias"]))
        mlp.append(Int(architecture.flags["mlp_bias"]))
    var bias = DecoderBiasPolicy(attention^, mlp^, r.provenance, r.source_work)
    var activation = source_decoder_activations(architecture, r.provenance, r.source_work)
    var session = source_decoder_session(architecture, r.session_mode, r.return_override,
        r.provenance, r.source_work)
    var window = source_decoder_windows(architecture, r.provenance, r.source_work)
    var scaling = source_decoder_scaling(architecture, r.provenance, r.source_work)
    # Only an independently rederived temporary is consumed. The retained binding
    # and its complete raw source/default/modifier intent stay independently owned.
    var source = schema.binding.source^
    schema.binding.source = SourceTensorInventory()
    return build_decoder_semantic_plan(source^, geometry, scalars, policy, bias,
        activation, session, window, scaling, r.query_tokens, r.past_tokens, r.context_capacity)


def compile_owned_indexed_ordinary_graph(var binding: OwnedIndexedOrdinaryBinding,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> OwnedIndexedOrdinaryCompiler:
    _same_binding_policy(binding.policy, policy)
    var actual = _refresh_indexed(binding.owner, policy)
    _same_schema(binding.schema, actual, policy)
    var plan = _ordinary_plan(actual, request)
    var graph = expand_semantic_graph(plan^, request.rotary)
    return OwnedIndexedOrdinaryCompiler(binding^, graph^, request.copy())


def compile_owned_unindexed_ordinary_graph(var binding: OwnedUnindexedOrdinaryBinding,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> OwnedUnindexedOrdinaryCompiler:
    _same_binding_policy(binding.policy, policy)
    var actual = _refresh_unindexed(binding.owner, policy)
    _same_schema(binding.schema, actual, policy)
    var plan = _ordinary_plan(actual, request)
    var graph = expand_semantic_graph(plan^, request.rotary)
    return OwnedUnindexedOrdinaryCompiler(binding^, graph^, request.copy())


def load_owned_indexed_ordinary_compiler(path: String, index_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> OwnedIndexedOrdinaryCompiler:
    var binding = load_owned_indexed_ordinary(path, index_label, config_label, root, copy, policy)
    return compile_owned_indexed_ordinary_graph(binding^, policy, request)


def load_owned_unindexed_ordinary_compiler(path: String, weight_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> OwnedUnindexedOrdinaryCompiler:
    var binding = load_owned_unindexed_ordinary(path, weight_label, config_label, root, copy, policy)
    return compile_owned_unindexed_ordinary_graph(binding^, policy, request)


def _selected_weight(plan: SemanticPlan, actual: SemanticPlan, operation: Int) raises -> String:
    # This guards a semantic operation's static component selection. It is not a
    # generic immutable identity for every expanded value, recipe or operation.
    _same_source(plan.source, actual.source)
    if len(plan.operations) != len(actual.operations) or len(plan.tensors) != len(actual.tensors) or operation < 0 or operation >= len(actual.operations):
        raise Error("OwnedOrdinaryCompiler: semantic operation selection differs")
    if plan.layers != actual.layers or plan.hidden != actual.hidden or plan.feed_forward != actual.feed_forward or plan.heads != actual.heads or plan.kv_heads != actual.kv_heads or plan.key_dim != actual.key_dim or plan.value_dim != actual.value_dim or plan.rope_dim != actual.rope_dim or plan.vocabulary != actual.vocabulary or plan.context_capacity != actual.context_capacity or plan.query_tokens != actual.query_tokens or plan.past_tokens != actual.past_tokens or plan.source_layout != actual.source_layout or plan.rope_base != actual.rope_base or plan.rms_epsilon != actual.rms_epsilon:
        raise Error("OwnedOrdinaryCompiler: semantic geometry differs from actual source/request")
    if plan.decoder_policy.rope_enabled != actual.decoder_policy.rope_enabled or plan.decoder_policy.output_weight != actual.decoder_policy.output_weight or plan.decoder_policy.provenance != actual.decoder_policy.provenance or plan.explicit_scalars != actual.explicit_scalars or not same_decoder_scalars(plan.source_scalars, actual.source_scalars):
        raise Error("OwnedOrdinaryCompiler: source scalar/rotary/output policy differs")
    if plan.explicit_bias != actual.explicit_bias or not same_bias_policy(plan.bias_policy, actual.bias_policy) or plan.bias_work != actual.bias_work or plan.explicit_activation != actual.explicit_activation or not same_activation_policy(plan.activation_policy, actual.activation_policy) or plan.activation_work != actual.activation_work or plan.explicit_session != actual.explicit_session or not same_session_policy(plan.session_policy, actual.session_policy) or plan.session_work != actual.session_work or plan.cache_exports != actual.cache_exports:
        raise Error("OwnedOrdinaryCompiler: source bias/activation/session policy differs")
    if plan.explicit_window != actual.explicit_window or not same_window_policy(plan.window_policy, actual.window_policy) or plan.window_work != actual.window_work or plan.explicit_scaling != actual.explicit_scaling or not same_scaling_policy(plan.scaling_policy, actual.scaling_policy) or plan.scaling_work != actual.scaling_work or plan.explicit_dynamic != actual.explicit_dynamic or plan.dynamic_source_context != actual.dynamic_source_context or plan.dynamic_work != actual.dynamic_work:
        raise Error("OwnedOrdinaryCompiler: source window/scaling/dynamic policy differs")
    validate_plan_scalar_state(plan)
    validate_plan_bias_state(plan)
    validate_plan_activation_state(plan)
    validate_plan_session_state(plan)
    validate_plan_window_state(plan)
    validate_plan_scaling_state(plan)
    validate_plan_dynamic_state(plan)
    ref a = plan.operations[operation]
    ref b = actual.operations[operation]
    if a.kind != b.kind or a.inputs != b.inputs or a.output != b.output or a.weight != b.weight or a.window_tokens != b.window_tokens or a.scaling_kind != b.scaling_kind or not same_scalar_word(a.scaling_factor, b.scaling_factor) or a.position_start != b.position_start or a.dynamic_reference != b.dynamic_reference or a.dynamic_selected != b.dynamic_selected or not same_scalar_word(a.dynamic_factor, b.dynamic_factor):
        raise Error("OwnedOrdinaryCompiler: consumed semantic operation differs")
    # Rebuilt indices are bounds checked before any retained tensor dereference.
    var ids = b.inputs.copy()
    ids.append(b.output)
    for id in ids:
        if id < 0 or id >= len(actual.tensors):
            raise Error("OwnedOrdinaryCompiler: consumed semantic tensor missing")
        ref x = plan.tensors[id]
        ref y = actual.tensors[id]
        if x.name != y.name or x.shape != y.shape or x.elements != y.elements or x.producer != y.producer or x.last_use != y.last_use or x.persistent != y.persistent or x.alias_of != y.alias_of:
            raise Error("OwnedOrdinaryCompiler: consumed semantic tensor differs")
    if b.weight.byte_length() == 0 or b.weight not in actual.source.storage:
        raise Error("OwnedOrdinaryCompiler: selected operation has no static source component")
    return b.weight


def read_owned_indexed_operation_component(mut context: OwnedIndexedOrdinaryCompiler,
        operation: Int, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> SafetensorsConstantWindow:
    _same_binding_policy(context.binding.policy, policy)
    _same_request(context.request, request)
    var actual = _refresh_indexed(context.binding.owner, policy)
    _same_schema(context.binding.schema, actual, policy)
    var plan = _ordinary_plan(actual, request)
    _ = validate_rotary_policy(plan, request.rotary)
    var name = _selected_weight(context.graph.source, plan, operation)
    # Reuse the binding guard and reader, including a fresh actual-byte check.
    return read_owned_indexed_component(context.binding, name, first, count, element_bound, policy)


def read_owned_unindexed_operation_component(mut context: OwnedUnindexedOrdinaryCompiler,
        operation: Int, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest) raises -> SafetensorsConstantWindow:
    _same_binding_policy(context.binding.policy, policy)
    _same_request(context.request, request)
    var actual = _refresh_unindexed(context.binding.owner, policy)
    _same_schema(context.binding.schema, actual, policy)
    var plan = _ordinary_plan(actual, request)
    _ = validate_rotary_policy(plan, request.rotary)
    var name = _selected_weight(context.graph.source, plan, operation)
    return read_owned_unindexed_component(context.binding, name, first, count, element_bound, policy)
