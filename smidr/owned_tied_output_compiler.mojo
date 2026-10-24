# Original retained source reconciliation. Structural graphs, never execution.
from smidr.ordinary_tensor_identity import OrdinaryTensorComparison, compare_owned_indexed_tensors, compare_owned_unindexed_tensors
from smidr.source_weight_sharing import SourceWeightAlias, SourceWeightSharingPolicy, validate_source_weight_sharing, _same_sharing_policy
from smidr.owned_ordinary_binding import OrdinaryBindingPolicy, OwnedIndexedOrdinaryBinding, OwnedUnindexedOrdinaryBinding, _same_binding_policy, _refresh_indexed, _refresh_unindexed, _same_schema, load_owned_indexed_ordinary, load_owned_unindexed_ordinary, read_owned_indexed_component, read_owned_unindexed_component
from smidr.owned_ordinary_compiler import OrdinaryCompilationRequest, _same_request, _admit_request, _ordinary_plan, _selected_weight
from smidr.ordinary_projection_schema import OrdinaryProjectionSchema
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.expanded_storage import validate_expanded_storage_graph
from smidr.rotary_policy import validate_rotary_policy
from smidr.safetensors_constants import SafetensorsConstantWindow
from smidr.source_root import SourceRootPolicy
from smidr.sealed_source_collection import SealedCollectionCopyPolicy


@fieldwise_init
struct OwnedIndexedTiedOutputCompiler(Movable):
    var binding: OwnedIndexedOrdinaryBinding
    var graph: ExpandedGraph
    var request: OrdinaryCompilationRequest
    var sharing: SourceWeightSharingPolicy
    var observation: OrdinaryTensorComparison
    var total_elements: Int
    var chunk_elements: Int

    def close(mut self) raises:
        self.binding.close()


@fieldwise_init
struct OwnedUnindexedTiedOutputCompiler(Movable):
    var binding: OwnedUnindexedOrdinaryBinding
    var graph: ExpandedGraph
    var request: OrdinaryCompilationRequest
    var sharing: SourceWeightSharingPolicy
    var observation: OrdinaryTensorComparison
    var total_elements: Int
    var chunk_elements: Int

    def close(mut self) raises:
        self.binding.close()


def _sharing(schema: OrdinaryProjectionSchema, request: OrdinaryCompilationRequest,
             observed: OrdinaryTensorComparison) raises -> SourceWeightSharingPolicy:
    _admit_request(schema, request)
    ref architecture = schema.binding.architecture
    if "tie_word_embeddings" not in architecture.flags or not architecture.flags["tie_word_embeddings"] or "tie_word_embeddings" not in architecture.field_origins or schema.binding.output_weight != "token_embd.weight":
        raise Error("OwnedTiedOutput: actual source requires a tied embedding output")
    if not observed.all_elements_equal or observed.differing_elements != 0:
        raise Error("OwnedTiedOutput: present tied output source bytes differ")
    var aliases = List[SourceWeightAlias]()
    aliases.append(SourceWeightAlias("output.weight", "token_embd.weight",
        architecture.field_origins["tie_word_embeddings"]))
    var result = SourceWeightSharingPolicy(aliases^, request.provenance, request.source_work)
    _ = validate_source_weight_sharing(schema.binding.source, result)
    return result^


def _bounds(total: Int, chunk: Int, supplied_total: Int, supplied_chunk: Int) raises:
    if total <= 0 or chunk <= 0 or supplied_total != total or supplied_chunk != chunk:
        raise Error("OwnedTiedOutput: supplied and owned positive comparison bounds differ")


def compile_owned_indexed_tied_output(var binding: OwnedIndexedOrdinaryBinding,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> OwnedIndexedTiedOutputCompiler:
    _same_binding_policy(binding.policy, policy)
    _bounds(total_elements, chunk_elements, total_elements, chunk_elements)
    var observed = compare_owned_indexed_tensors(binding, "token_embd.weight", "output.weight", total_elements, chunk_elements, policy)
    var actual = _refresh_indexed(binding.owner, policy)
    _same_schema(binding.schema, actual, policy)
    var sharing = _sharing(actual, request, observed)
    var plan = _ordinary_plan(actual, request, sharing)
    var graph = expand_semantic_graph(plan^, request.rotary)
    validate_expanded_storage_graph(graph)
    return OwnedIndexedTiedOutputCompiler(binding^, graph^, request.copy(), sharing^,
        observed^, total_elements, chunk_elements)


def compile_owned_unindexed_tied_output(var binding: OwnedUnindexedOrdinaryBinding,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> OwnedUnindexedTiedOutputCompiler:
    _same_binding_policy(binding.policy, policy)
    _bounds(total_elements, chunk_elements, total_elements, chunk_elements)
    var observed = compare_owned_unindexed_tensors(binding, "token_embd.weight", "output.weight", total_elements, chunk_elements, policy)
    var actual = _refresh_unindexed(binding.owner, policy)
    _same_schema(binding.schema, actual, policy)
    var sharing = _sharing(actual, request, observed)
    var plan = _ordinary_plan(actual, request, sharing)
    var graph = expand_semantic_graph(plan^, request.rotary)
    validate_expanded_storage_graph(graph)
    return OwnedUnindexedTiedOutputCompiler(binding^, graph^, request.copy(), sharing^,
        observed^, total_elements, chunk_elements)


def load_owned_indexed_tied_output(path: String, index_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> OwnedIndexedTiedOutputCompiler:
    var binding = load_owned_indexed_ordinary(path, index_label, config_label, root, copy, policy)
    return compile_owned_indexed_tied_output(binding^, policy, request, total_elements, chunk_elements)


def load_owned_unindexed_tied_output(path: String, weight_label: String, config_label: String,
        root: SourceRootPolicy, copy: SealedCollectionCopyPolicy,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> OwnedUnindexedTiedOutputCompiler:
    var binding = load_owned_unindexed_ordinary(path, weight_label, config_label, root, copy, policy)
    return compile_owned_unindexed_tied_output(binding^, policy, request, total_elements, chunk_elements)


def read_owned_indexed_tied_component(mut context: OwnedIndexedTiedOutputCompiler,
        operation: Int, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> SafetensorsConstantWindow:
    _bounds(context.total_elements, context.chunk_elements, total_elements, chunk_elements)
    _same_binding_policy(context.binding.policy, policy)
    _same_request(context.request, request)
    var observed = compare_owned_indexed_tensors(context.binding, "token_embd.weight", "output.weight", total_elements, chunk_elements, policy)
    var actual = _refresh_indexed(context.binding.owner, policy)
    _same_schema(context.binding.schema, actual, policy)
    var sharing = _sharing(actual, request, observed)
    _same_sharing_policy(context.sharing, sharing)
    var plan = _ordinary_plan(actual, request, sharing)
    _ = validate_rotary_policy(plan, request.rotary)
    validate_expanded_storage_graph(context.graph)
    var name = _selected_weight(context.graph.source, plan, operation)
    context.observation = observed^
    return read_owned_indexed_component(context.binding, name, first, count, element_bound, policy)


def read_owned_unindexed_tied_component(mut context: OwnedUnindexedTiedOutputCompiler,
        operation: Int, first: Int, count: Int, element_bound: Int,
        policy: OrdinaryBindingPolicy, request: OrdinaryCompilationRequest,
        total_elements: Int, chunk_elements: Int) raises -> SafetensorsConstantWindow:
    _bounds(context.total_elements, context.chunk_elements, total_elements, chunk_elements)
    _same_binding_policy(context.binding.policy, policy)
    _same_request(context.request, request)
    var observed = compare_owned_unindexed_tensors(context.binding, "token_embd.weight", "output.weight", total_elements, chunk_elements, policy)
    var actual = _refresh_unindexed(context.binding.owner, policy)
    _same_schema(context.binding.schema, actual, policy)
    var sharing = _sharing(actual, request, observed)
    _same_sharing_policy(context.sharing, sharing)
    var plan = _ordinary_plan(actual, request, sharing)
    _ = validate_rotary_policy(plan, request.rotary)
    validate_expanded_storage_graph(context.graph)
    var name = _selected_weight(context.graph.source, plan, operation)
    context.observation = observed^
    return read_owned_unindexed_component(context.binding, name, first, count, element_bound, policy)
