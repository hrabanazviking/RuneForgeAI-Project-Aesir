# Original source byte streaming. No dequantization, model math or device code.
from loader.packed_gguf import PackedGGUF, packed_row_bytes
from smidr.source_inventory import SourceTensorBinding, SourceFileExtent
from smidr.source_storage import SourceStorageTensor
from smidr.semantic_plan import checked_product
from smidr.storage_estimate import checked_sum
from smidr.matrix_tiles import MatrixSchedule, matrix_tile


@fieldwise_init
struct SourceWeightSpan(Copyable, Movable):
    var row: Int
    var file_offset: Int
    var byte_count: Int
    var covered_column: Int
    var covered_elements: Int
    var prefix_elements: Int
    var suffix_elements: Int
    var payload_offset: Int


@fieldwise_init
struct SourceWeightTile(Movable):
    var weight_name: String
    var binding: SourceTensorBinding
    var storage: SourceStorageTensor
    var extent: SourceFileExtent
    var first_column: Int
    var column_count: Int
    var first_row: Int
    var row_count: Int
    var spans: List[SourceWeightSpan]
    var payload: List[UInt8]


def read_source_weight_tile(source: PackedGGUF, schedule: MatrixSchedule,
                            tile_index: Int, host_byte_bound: Int) raises -> SourceWeightTile:
    # A closed GGUFSeer retains file_size. Check actual ownership before using
    # any descriptor, and use only its checked half-word reader for copying.
    if not source.source.is_mapped or source.source.fd < 0:
        raise Error("SourceWeightTiles: live mapped source owner required")
    var tile = matrix_tile(schedule, tile_index)
    if host_byte_bound <= 0:
        raise Error("SourceWeightTiles: explicit positive host byte bound required")
    var storage = schedule.storage.copy()
    if storage.source_format != "gguf" or storage.source_path != source.source.file_path:
        raise Error("SourceWeightTiles: actual GGUF owner/path required for GGUF byte reader")
    if Int(source.source.file_size) != schedule.source_bytes or source.data_offset != schedule.data_offset or storage.original_name not in source.tensors:
        raise Error("SourceWeightTiles: source mapping/weight differs from schedule")
    var axes = source.tensor_shape(storage.original_name)
    if len(axes) != len(storage.source_shape):
        raise Error("SourceWeightTiles: live original source rank differs")
    for i in range(len(axes)):
        if axes[i] != storage.source_shape[i]:
            raise Error("SourceWeightTiles: live original source axes differ")
    var actual = source.tensors[storage.original_name]
    var binding = schedule.binding
    if actual.offset != binding.file_offset or actual.columns != binding.columns or actual.rows != binding.rows or actual.kind != binding.source_kind or actual.byte_count != binding.byte_count:
        raise Error("SourceWeightTiles: live source binding differs from schedule")
    var row_bytes = packed_row_bytes(actual.kind, actual.columns)
    var block_elements = 1
    var block_bytes = 2
    if actual.kind == 0:
        block_bytes = 4
    elif actual.kind == 8:
        block_elements = 32
        block_bytes = 34
    elif actual.kind == 12 or actual.kind == 13 or actual.kind == 14:
        block_elements = 256
        block_bytes = row_bytes // (actual.columns // block_elements)
    # Current packed scalar formats all have even byte spans. The kind and
    # exact extent were checked by matrix_tile and the live binding comparison.
    var first_block = tile.contraction // block_elements
    var last_column = checked_sum(tile.contraction, tile.contractions)
    var last_block = (last_column - 1) // block_elements + 1
    var covered_column = checked_product(first_block + 1, block_elements) - block_elements
    var covered_elements = checked_product(last_block - first_block, block_elements)
    var prefix = tile.contraction - covered_column
    var suffix = covered_elements - prefix - tile.contractions
    var span_bytes = checked_product(last_block - first_block, block_bytes)
    var total_bytes = checked_product(span_bytes, tile.outputs)
    if total_bytes > host_byte_bound:
        raise Error("SourceWeightTiles: selected source bytes exceed host bound")
    var spans = List[SourceWeightSpan]()
    spans.reserve(tile.outputs)
    var payload = List[UInt8]()
    payload.reserve(total_bytes)
    # Prove every span before reading any byte. Selection remains within the
    # exact matrix row, even where a packed block includes adjacent constants.
    for i in range(tile.outputs):
        var row = checked_sum(tile.output, i)
        var row_offset = checked_product(row + 1, row_bytes) - row_bytes
        var column_offset = checked_product(first_block + 1, block_bytes) - block_bytes
        if column_offset > row_bytes or span_bytes > row_bytes - column_offset:
            raise Error("SourceWeightTiles: selected span crosses its source row")
        var relative = checked_sum(row_offset, column_offset)
        if relative > binding.byte_count or span_bytes > binding.byte_count - relative:
            raise Error("SourceWeightTiles: selected span crosses its tensor")
        var file_offset = checked_sum(binding.file_offset, relative)
        source.source._require_range(file_offset, span_bytes)
        var payload_offset = checked_product(i + 1, span_bytes) - span_bytes
        spans.append(SourceWeightSpan(row, file_offset, span_bytes, covered_column,
            covered_elements, prefix, suffix, payload_offset))
    for span in spans:
        for cursor in range(span.file_offset, span.file_offset + span.byte_count, 2):
            var pair = source.source._read_u16(cursor)
            payload.append(UInt8(pair & 255))
            payload.append(UInt8(pair >> 8))
    return SourceWeightTile(schedule.weight_name, binding, storage^,
        SourceFileExtent("gguf", schedule.source_bytes, schedule.data_offset), tile.contraction,
        tile.contractions, tile.output, tile.outputs, spans^, payload^)
