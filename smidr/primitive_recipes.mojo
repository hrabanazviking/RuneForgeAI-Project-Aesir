# Mathematical compiler IR only. No numerical host kernel or device program.
from std.math import isfinite
from std.memory import bitcast
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.source_inventory import SourceTensorBinding


@fieldwise_init
struct RecipeValue(Copyable, Movable):
    var shape: List[Int]
    var elements: Int
    var domain: String
    var producer: Int
    var last_use: Int


@fieldwise_init
struct RecipeOperation(Copyable, Movable):
    var kind: String
    var inputs: List[Int]
    var output: Int


struct PrimitiveRecipe(Copyable, Movable):
    var source_operation: Int
    var source_input: Int
    var source_output: Int
    var kind: String
    var weight_name: String
    var weight: SourceTensorBinding
    var divisor: Int
    var epsilon_bits: UInt32
    var runtime_preconditions: List[String]
    var values: List[RecipeValue]
    var operations: List[RecipeOperation]
    var result: Int

    def __init__(out self, source_operation: Int, source_input: Int,
                 source_output: Int, kind: String):
        self.source_operation = source_operation
        self.source_input = source_input
        self.source_output = source_output
        self.kind = kind
        self.weight_name = String("")
        self.weight = SourceTensorBinding(0, 0, 0, 0, 0)
        self.divisor = 0
        self.epsilon_bits = 0
        self.runtime_preconditions = ["finite_inputs"]
        self.values = List[RecipeValue]()
        self.operations = List[RecipeOperation]()
        self.result = -1

    def value(mut self, var shape: List[Int], domain: String = "real", producer: Int = -1) raises -> Int:
        if len(shape) == 0:
            raise Error("PrimitiveRecipe: empty shape")
        var elements = 1
        for dim in shape:
            elements = checked_product(elements, dim)
        var index = len(self.values)
        self.values.append(RecipeValue(shape^, elements, domain, producer, producer))
        return index

    def emit(mut self, kind: String, var inputs: List[Int], var shape: List[Int], domain: String = "real") raises -> Int:
        var step = len(self.operations)
        for input_id in inputs:
            if input_id < 0 or input_id >= len(self.values):
                raise Error("PrimitiveRecipe: input value is unavailable")
            self.values[input_id].last_use = step
        var output = self.value(shape^, domain, step)
        self.operations.append(RecipeOperation(kind, inputs^, output))
        return output


struct PrimitiveRecipes(Movable):
    var recipes: List[PrimitiveRecipe]
    var remaining_source_operations: List[Int]

    def __init__(out self):
        self.recipes = List[PrimitiveRecipe]()
        self.remaining_source_operations = List[Int]()


def lower_primitive_recipes(plan: SemanticPlan) raises -> PrimitiveRecipes:
    var lowered = PrimitiveRecipes()
    for index in range(len(plan.operations)):
        var operation = plan.operations[index].copy()
        if operation.kind != "rms_norm" and operation.kind != "silu" and operation.kind != "softmax":
            lowered.remaining_source_operations.append(index)
            continue
        if len(operation.inputs) != 1 or operation.inputs[0] < 0 or operation.inputs[0] >= len(plan.tensors) or operation.output < 0 or operation.output >= len(plan.tensors):
            raise Error("PrimitiveRecipe: invalid source operation extent")
        var input = plan.tensors[operation.inputs[0]].copy()
        var output = plan.tensors[operation.output].copy()
        if input.producer >= index or output.producer != index or input.last_use < index:
            raise Error("PrimitiveRecipe: invalid source dependency/lifetime")
        if len(input.shape) == 0 or len(input.shape) != len(output.shape):
            raise Error("PrimitiveRecipe: source shape rank mismatch")
        var elements = 1
        for axis in range(len(input.shape)):
            if input.shape[axis] != output.shape[axis]:
                raise Error("PrimitiveRecipe: source operation changes shape")
            elements = checked_product(elements, input.shape[axis])
        if input.elements != elements or output.elements != elements:
            raise Error("PrimitiveRecipe: source shape product mismatch")
        var recipe = PrimitiveRecipe(index, operation.inputs[0], operation.output, operation.kind)
        var x = recipe.value(input.shape.copy())
        if operation.kind == "rms_norm":
            if len(input.shape) != 2 or not isfinite(plan.rms_epsilon) or plan.rms_epsilon <= 0:
                raise Error("PrimitiveRecipe: RMSNorm requires a matrix and finite positive epsilon")
            var width = input.shape[1]
            if operation.weight not in plan.source.bindings:
                raise Error("PrimitiveRecipe: normalization source weight is missing")
            var weight = plan.source.bindings[operation.weight]
            if weight.columns != width or weight.rows != 1 or weight.file_offset < plan.source.data_offset or weight.file_offset > plan.source.source_bytes or weight.byte_count <= 0 or weight.byte_count > plan.source.source_bytes - weight.file_offset:
                raise Error("PrimitiveRecipe: normalization source weight shape/extent mismatch")
            recipe.weight_name = operation.weight
            recipe.weight = weight
            recipe.divisor = width
            recipe.epsilon_bits = bitcast[DType.uint32](plan.rms_epsilon)
            var w = recipe.value([width])
            var square = recipe.emit("multiply", [x, x], input.shape.copy())
            var summed = recipe.emit("reduce_sum_last", [square], [input.shape[0], 1])
            var mean = recipe.emit("divide_by_width", [summed], [input.shape[0], 1])
            var adjusted = recipe.emit("add_epsilon", [mean], [input.shape[0], 1])
            var inv = recipe.emit("reciprocal_sqrt", [adjusted], [input.shape[0], 1])
            var norm = recipe.emit("multiply_row_scale", [x, inv], input.shape.copy())
            recipe.result = recipe.emit("multiply_source_vector", [norm, w], input.shape.copy())
        elif operation.kind == "softmax":
            if operation.weight.byte_length() != 0:
                raise Error("PrimitiveRecipe: softmax has an unexpected source weight")
            recipe.runtime_preconditions = ["no_nan_or_positive_infinity", "at_least_one_finite_value_per_last_axis_row", "negative_infinity_mask_values_allowed"]
            var row_shape = input.shape.copy()
            row_shape[len(row_shape) - 1] = 1
            var maximum = recipe.emit("reduce_max_last", [x], row_shape.copy())
            var shifted = recipe.emit("subtract_last_axis", [x, maximum], input.shape.copy())
            var e = recipe.emit("exp", [shifted], input.shape.copy())
            var summed = recipe.emit("reduce_sum_last", [e], row_shape.copy())
            recipe.result = recipe.emit("divide_last_axis", [e, summed], input.shape.copy())
        else:
            if operation.weight.byte_length() != 0:
                raise Error("PrimitiveRecipe: SiLU has an unexpected source weight")
            # Finite-real identity with no positive exponential argument.
            # Device rounding/underflow/special-value policies are still open.
            var magnitude = recipe.emit("abs", [x], input.shape.copy())
            var negative = recipe.emit("negate", [magnitude], input.shape.copy())
            var e = recipe.emit("exp", [negative], input.shape.copy())
            var denominator = recipe.emit("add_one", [e], input.shape.copy())
            var inv = recipe.emit("reciprocal", [denominator], input.shape.copy())
            var negative_sigmoid = recipe.emit("multiply", [e, inv], input.shape.copy())
            var predicate = recipe.emit("compare_nonnegative", [x], input.shape.copy(), "predicate")
            var sigmoid = recipe.emit("select", [predicate, inv, negative_sigmoid], input.shape.copy())
            recipe.result = recipe.emit("multiply", [x, sigmoid], input.shape.copy())
        recipe.values[recipe.result].last_use = len(recipe.operations)
        lowered.recipes.append(recipe^)
    return lowered^
