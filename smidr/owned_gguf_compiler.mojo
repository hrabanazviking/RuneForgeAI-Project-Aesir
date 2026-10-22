# Original compiler-owned observed source lifetime. Structural lowering only.
from hailbru.syscall import os_host_architecture
from hailbru.source_sealed_copy import _require_sealed_source
from hailbru.source_digest import digest_borrowed_regular_window
from smidr.sealed_gguf_source import SealedPackedGGUF, load_sealed_packed_gguf
from smidr.source_inventory import inventory_from_source, validate_source_inventory
from smidr.semantic_plan import gguf_dense_decoder_parameters, build_dense_semantic_plan
from smidr.expanded_graph import ExpandedGraph, expand_semantic_graph
from smidr.matrix_tiles import MatrixTilePolicy, plan_matrix_contraction
from smidr.source_weight_tiles import SourceWeightTile, read_source_weight_tile


@fieldwise_init
struct OwnedGGUFCompiler(Movable):
    var owner: SealedPackedGGUF
    var graph: ExpandedGraph

    def close(mut self):
        # GGUFSeer owns cleanup, including the captured mapping capacity.
        self.owner.source.source.close()


def _require_compiler_source(owner: SealedPackedGGUF) raises:
    ref source = owner.source.source
    if not source._sealed_route or not source.is_mapped or source.fd < 0 or owner.source_bytes <= 0 or source.file_size != owner.source_bytes or source._mapping_extent != owner.source_bytes:
        raise Error("OwnedGGUFCompiler: live exact sealed mapping required")
    _require_sealed_source(os_host_architecture(), Int64(source.fd), owner.source_bytes)


def compile_owned_gguf(var owner: SealedPackedGGUF, query_tokens: Int,
        past_tokens: Int, context_capacity: Int,
        digest_call_bound: Int) raises -> OwnedGGUFCompiler:
    _require_compiler_source(owner)
    if digest_call_bound <= 0:
        raise Error("OwnedGGUFCompiler: explicit positive digest-call bound required")
    var digest = digest_borrowed_regular_window(os_host_architecture(),
        Int64(owner.source.source.fd), owner.source_bytes, 0,
        Int(owner.source_bytes), Int(owner.source_bytes), digest_call_bound)
    owner.digest_hex = digest.digest_hex
    # Rehydrate mutable parser caches through the one existing interpreter.
    owner.source.fields.clear()
    owner.source.field_types.clear()
    owner.source.tensors.clear()
    owner.source.tensor_shapes.clear()
    owner.source.data_offset = 0
    owner.source.source._parse_header()
    owner.source._interpret_tables()
    var parameters = gguf_dense_decoder_parameters(owner.source)
    var inventory = inventory_from_source(owner.source)
    var plan = build_dense_semantic_plan(inventory^, parameters,
        query_tokens, past_tokens, context_capacity)
    var graph = expand_semantic_graph(plan^)
    return OwnedGGUFCompiler(owner^, graph^)


def load_owned_gguf_compiler(path: String, source_byte_bound: Int,
        read_call_bound: Int, write_call_bound: Int, digest_call_bound: Int,
        query_tokens: Int, past_tokens: Int,
        context_capacity: Int) raises -> OwnedGGUFCompiler:
    var owner = load_sealed_packed_gguf(path, source_byte_bound,
        read_call_bound, write_call_bound, digest_call_bound)
    return compile_owned_gguf(owner^, query_tokens, past_tokens,
        context_capacity, digest_call_bound)


def _require_compiler_inventory(context: OwnedGGUFCompiler) raises:
    _require_compiler_source(context.owner)
    ref expected = context.graph.source.source
    validate_source_inventory(expected)
    var actual = inventory_from_source(context.owner.source)
    if actual.architecture != expected.architecture or actual.source_bytes != expected.source_bytes or actual.data_offset != expected.data_offset or actual.weight_bytes != expected.weight_bytes or actual.alias_provenance != expected.alias_provenance or len(actual.bindings) != len(expected.bindings) or len(actual.files) != len(expected.files):
        raise Error("OwnedGGUFCompiler: compiler inventory differs from owned source")
    for path in actual.files:
        if path not in expected.files:
            raise Error("OwnedGGUFCompiler: compiler backing source differs")
        var a = actual.files[path].copy()
        var b = expected.files[path].copy()
        if a.source_format != b.source_format or a.source_bytes != b.source_bytes or a.data_offset != b.data_offset:
            raise Error("OwnedGGUFCompiler: compiler backing extent differs")
    for name in actual.bindings:
        if name not in expected.bindings or name not in expected.storage:
            raise Error("OwnedGGUFCompiler: compiler binding missing")
        var a = actual.bindings[name]
        var b = expected.bindings[name]
        if a.file_offset != b.file_offset or a.columns != b.columns or a.rows != b.rows or a.source_kind != b.source_kind or a.byte_count != b.byte_count:
            raise Error("OwnedGGUFCompiler: compiler binding differs")
        ref x = actual.storage[name]
        ref y = expected.storage[name]
        if x.source_format != y.source_format or x.source_kind != y.source_kind or x.original_name != y.original_name or x.source_path != y.source_path or x.axis_order != y.axis_order or x.elements != y.elements or x.file_offset != y.file_offset or x.byte_count != y.byte_count or len(x.source_shape) != len(y.source_shape):
            raise Error("OwnedGGUFCompiler: compiler storage differs")
        for i in range(len(x.source_shape)):
            if x.source_shape[i] != y.source_shape[i]:
                raise Error("OwnedGGUFCompiler: compiler source axes differ")


def read_owned_gguf_weight_tile(context: OwnedGGUFCompiler, operation: Int,
        policy: MatrixTilePolicy, index: Int,
        host_byte_bound: Int) raises -> SourceWeightTile:
    _require_compiler_inventory(context)
    var schedule = plan_matrix_contraction(context.graph.source, operation, policy)
    return read_source_weight_tile(context.owner.source, schedule, index, host_byte_bound)
