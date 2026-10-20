# Original lazy contraction schedules. No numerical evaluation or device code.
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.source_inventory import SourceTensorBinding
from smidr.storage_estimate import checked_sum, aligned_bytes
from loader.packed_gguf import packed_row_bytes


@fieldwise_init
struct MatrixTilePolicy(Copyable, Movable):
    var rows: Int
    var outputs: Int
    var contraction: Int
    var input_width: Int
    var weight_width: Int
    var accumulator_width: Int
    var alignment: Int
    var workspace_bound: Int
    var provenance: String


@fieldwise_init
struct MatrixSchedule(Copyable, Movable):
    var operation: Int
    var input_tensor: Int
    var output_tensor: Int
    var weight_name: String
    var binding: SourceTensorBinding
    var source_bytes: Int
    var data_offset: Int
    var input_shape: List[Int]
    var output_shape: List[Int]
    var m: Int
    var n: Int
    var c: Int
    var policy: MatrixTilePolicy


@fieldwise_init
struct MatrixTile(Copyable, Movable):
    var row: Int
    var output: Int
    var contraction: Int
    var rows: Int
    var outputs: Int
    var contractions: Int
    var input_element: Int
    var input_row_stride: Int
    var weight_element: Int
    var weight_row_stride: Int
    var output_element: Int
    var output_row_stride: Int
    var initialize_accumulator: Bool
    var finalize_output: Bool


def _ceil_tiles(extent: Int, tile: Int) raises -> Int:
    if extent <= 0 or tile <= 0:
        raise Error("MatrixTiles: positive extent and tile required")
    # Division first avoids the overflowing extent + tile - 1 idiom.
    return (extent - 1) // tile + 1


def _shape_elements(shape: List[Int]) raises -> Int:
    if len(shape) == 0:
        raise Error("MatrixTiles: empty tensor shape")
    var result = 1
    for dimension in shape:
        result = checked_product(result, dimension)
    return result


def _validate_dimensions(input_shape: List[Int], output_shape: List[Int],
                         m: Int, n: Int, c: Int) raises:
    if _shape_elements(input_shape) != checked_product(m, c):
        raise Error("MatrixTiles: input shape/product mismatch")
    if input_shape[len(input_shape) - 1] != c:
        raise Error("MatrixTiles: contraction must be the final input axis")
    # Preserve every outer input axis; the output axis may be head-split.
    var outer = len(input_shape) - 1
    if len(output_shape) <= outer:
        raise Error("MatrixTiles: output has no projection axes")
    for i in range(outer):
        if input_shape[i] != output_shape[i]:
            raise Error("MatrixTiles: output outer axes differ from input")
    var projected = 1
    for i in range(outer, len(output_shape)):
        projected = checked_product(projected, output_shape[i])
    if projected != n or _shape_elements(output_shape) != checked_product(m, n):
        raise Error("MatrixTiles: output projection shape mismatch")


def validate_matrix_schedule(schedule: MatrixSchedule) raises:
    var p = schedule.policy.copy()
    if p.rows <= 0 or p.outputs <= 0 or p.contraction <= 0 or p.input_width <= 0 or p.weight_width <= 0 or p.accumulator_width <= 0 or p.workspace_bound <= 0 or p.provenance.byte_length() == 0:
        raise Error("MatrixTiles: explicit positive policy and provenance required")
    _ = aligned_bytes(1, 1, p.alignment)
    if schedule.operation < 0 or schedule.input_tensor < 0 or schedule.output_tensor < 0 or schedule.input_tensor == schedule.output_tensor or schedule.weight_name.byte_length() == 0:
        raise Error("MatrixTiles: invalid operation/tensor/weight identity")
    _validate_dimensions(schedule.input_shape, schedule.output_shape, schedule.m, schedule.n, schedule.c)
    var b = schedule.binding
    if b.columns != schedule.c or b.rows != schedule.n:
        raise Error("MatrixTiles: source matrix shape mismatch")
    var source_extent = checked_product(packed_row_bytes(b.source_kind, b.columns), b.rows)
    if schedule.data_offset < 0 or schedule.data_offset > schedule.source_bytes or b.file_offset < schedule.data_offset or b.file_offset > schedule.source_bytes or b.byte_count != source_extent or b.byte_count > schedule.source_bytes - b.file_offset:
        raise Error("MatrixTiles: source matrix byte extent mismatch")
    # Prove every relative scalar and assumed dense byte span representable.
    _ = checked_product(checked_product(schedule.m, schedule.c), p.input_width)
    _ = checked_product(checked_product(schedule.n, schedule.c), p.weight_width)
    _ = checked_product(checked_product(schedule.m, schedule.n), p.accumulator_width)
    var mt = _ceil_tiles(schedule.m, p.rows)
    var nt = _ceil_tiles(schedule.n, p.outputs)
    var ct = _ceil_tiles(schedule.c, p.contraction)
    _ = checked_product(checked_product(mt, nt), ct)
    # One input rectangle, one dense converted weight rectangle and one retained
    # accumulator rectangle. No full product tensor, double buffering or hidden
    # conversion staging is assumed by this explicit workspace scenario.
    var rows = min(schedule.m, p.rows)
    var outputs = min(schedule.n, p.outputs)
    var contractions = min(schedule.c, p.contraction)
    var input_bytes = aligned_bytes(checked_product(rows, contractions), p.input_width, p.alignment)
    var weight_bytes = aligned_bytes(checked_product(outputs, contractions), p.weight_width, p.alignment)
    var accumulator_bytes = aligned_bytes(checked_product(rows, outputs), p.accumulator_width, p.alignment)
    if checked_sum(checked_sum(input_bytes, weight_bytes), accumulator_bytes) > p.workspace_bound:
        raise Error("MatrixTiles: workspace scenario exceeds explicit bound")


def matrix_workspace_bytes(schedule: MatrixSchedule) raises -> Int:
    validate_matrix_schedule(schedule)
    var p = schedule.policy.copy()
    var rows = min(schedule.m, p.rows)
    var outputs = min(schedule.n, p.outputs)
    var contractions = min(schedule.c, p.contraction)
    return checked_sum(checked_sum(
        aligned_bytes(checked_product(rows, contractions), p.input_width, p.alignment),
        aligned_bytes(checked_product(outputs, contractions), p.weight_width, p.alignment)),
        aligned_bytes(checked_product(rows, outputs), p.accumulator_width, p.alignment))


def matrix_tile_count(schedule: MatrixSchedule) raises -> Int:
    validate_matrix_schedule(schedule)
    return checked_product(checked_product(_ceil_tiles(schedule.m, schedule.policy.rows),
        _ceil_tiles(schedule.n, schedule.policy.outputs)),
        _ceil_tiles(schedule.c, schedule.policy.contraction))


def plan_matrix_contraction(plan: SemanticPlan, operation: Int,
                            policy: MatrixTilePolicy) raises -> MatrixSchedule:
    if operation < 0 or operation >= len(plan.operations):
        raise Error("MatrixTiles: operation index outside source graph")
    var op = plan.operations[operation].copy()
    if op.kind != "linear" or len(op.inputs) != 1 or op.weight not in plan.source.bindings or op.weight not in plan.used_weights:
        raise Error("MatrixTiles: source-bound linear operation required")
    if not plan.used_weights[op.weight]:
        raise Error("MatrixTiles: source weight is not consumed")
    var input = op.inputs[0]
    if input < 0 or input >= len(plan.tensors) or op.output < 0 or op.output >= len(plan.tensors) or input == op.output:
        raise Error("MatrixTiles: invalid graph edge")
    var x = plan.tensors[input].copy()
    var y = plan.tensors[op.output].copy()
    if x.producer < -1 or x.producer >= operation or x.last_use < operation or x.last_use > len(plan.operations) or y.producer != operation or y.last_use < operation or y.last_use > len(plan.operations) or y.persistent or y.alias_of != -1:
        raise Error("MatrixTiles: invalid dependency/lifetime/output ownership")
    if _shape_elements(x.shape) != x.elements or _shape_elements(y.shape) != y.elements:
        raise Error("MatrixTiles: source tensor element count mismatch")
    var c = x.shape[len(x.shape) - 1]
    var m = x.elements // c
    var binding = plan.source.bindings[op.weight]
    var schedule = MatrixSchedule(operation, input, op.output, op.weight, binding,
        plan.source.source_bytes, plan.source.data_offset, x.shape.copy(),
        y.shape.copy(), m, binding.rows, c, policy.copy())
    validate_matrix_schedule(schedule)
    return schedule^


def matrix_tile(schedule: MatrixSchedule, index: Int) raises -> MatrixTile:
    var count = matrix_tile_count(schedule)
    if index < 0 or index >= count:
        raise Error("MatrixTiles: tile index outside schedule")
    var p = schedule.policy.copy()
    var nt = _ceil_tiles(schedule.n, p.outputs)
    var ct = _ceil_tiles(schedule.c, p.contraction)
    # M then N then C: one output accumulator survives all C slices.
    var contraction_tile = index % ct
    var output_tile = (index // ct) % nt
    var row_tile = index // checked_product(nt, ct)
    # These products are bounded by their validated parent extents.
    var row = row_tile * p.rows
    var output = output_tile * p.outputs
    var contraction = contraction_tile * p.contraction
    return MatrixTile(row, output, contraction, min(p.rows, schedule.m - row),
        min(p.outputs, schedule.n - output), min(p.contraction, schedule.c - contraction),
        row * schedule.c + contraction, schedule.c,
        output * schedule.c + contraction, schedule.c,
        row * schedule.n + output, schedule.n, contraction_tile == 0,
        contraction_tile == ct - 1)
