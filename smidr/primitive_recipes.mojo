# Mathematical compiler IR only. No numerical host kernel or device program.
from std.math import isfinite
from smidr.bias_policy import DecoderBiasPolicy, empty_bias_policy
from smidr.bias_graph import projection_bias_width, validate_plan_bias_state
from smidr.source_storage import SourceStorageTensor
from std.memory import bitcast
from smidr.semantic_plan import SemanticPlan, checked_product, validate_plan_scalar_state, rms_scalar, rotary_scalar
from smidr.source_scalars import ScalarWord, DecoderScalars, empty_decoder_scalars, scalar32_mirror
from smidr.rotary_policy import RotaryLoweringPolicy, validate_rotary_policy
from smidr.source_inventory import SourceTensorBinding, SourceFileExtent, validate_source_weight, validate_source_inventory


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
    var source_inputs: List[Int]
    var input_values: List[Int]
    var source_output: Int
    var kind: String
    var weight_name: String
    var weight: SourceTensorBinding
    var weight_storage: SourceStorageTensor
    var weight_extent: SourceFileExtent
    var divisor: Int
    var epsilon_bits: UInt32
    var epsilon_scalar: ScalarWord
    var rotary_dim: Int
    var rotary_base_bits: UInt32
    var rotary_base_scalar: ScalarWord
    var rotary_pairing: String
    var rotary_provenance: String
    var runtime_preconditions: List[String]
    var values: List[RecipeValue]
    var operations: List[RecipeOperation]
    var result: Int

    def __init__(out self, source_operation: Int, source_input: Int,
                 source_output: Int, kind: String):
        self.source_operation = source_operation
        self.source_input = source_input
        self.source_inputs = [source_input]
        self.input_values = [0]
        self.source_output = source_output
        self.kind = kind
        self.weight_name = String("")
        self.weight = SourceTensorBinding(0, 0, 0, 0, 0)
        self.weight_storage = SourceStorageTensor("", 0, "", "", List[Int](), "", 0, 0, 0)
        self.weight_extent = SourceFileExtent("", 0, 0)
        self.divisor = 0
        self.epsilon_bits = 0
        self.epsilon_scalar = ScalarWord(0, 0)
        self.rotary_dim = 0
        self.rotary_base_bits = 0
        self.rotary_base_scalar = ScalarWord(0, 0)
        self.rotary_pairing = String("")
        self.rotary_provenance = String("")
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
    var rotary_policy: RotaryLoweringPolicy
    var rotary_work: Int
    var explicit_bias: Bool
    var bias_policy: DecoderBiasPolicy
    var bias_work: Int
    var explicit_scalars: Bool
    var source_scalars: DecoderScalars

    def __init__(out self):
        self.recipes = List[PrimitiveRecipe]()
        self.remaining_source_operations = List[Int]()
        self.rotary_policy = RotaryLoweringPolicy("", "", 0, 0)
        self.rotary_work = 0
        self.explicit_bias = False
        self.bias_policy = empty_bias_policy()
        self.bias_work = 0
        self.explicit_scalars = False
        self.source_scalars = empty_decoder_scalars()


def lower_primitive_recipes(plan: SemanticPlan) raises -> PrimitiveRecipes:
    return _lower_primitive_recipes(plan, RotaryLoweringPolicy("", "", 0, 0), False)


def lower_primitive_recipes(plan: SemanticPlan, policy: RotaryLoweringPolicy) raises -> PrimitiveRecipes:
    _ = validate_rotary_policy(plan, policy)
    return _lower_primitive_recipes(plan, policy, True)


def _rotary_recipe(plan: SemanticPlan, index: Int, policy: RotaryLoweringPolicy) raises -> PrimitiveRecipe:
    var op = plan.operations[index].copy()
    if len(op.inputs) != 2 or op.weight.byte_length() != 0 or op.output < 0 or op.output >= len(plan.tensors):
        raise Error("RotaryRecipe: invalid source arity/output/weight")
    for id in op.inputs:
        if id < 0 or id >= len(plan.tensors) or plan.tensors[id].producer < -1 or plan.tensors[id].producer >= index or plan.tensors[id].last_use < index or plan.tensors[id].last_use > len(plan.operations):
            raise Error("RotaryRecipe: invalid source input/order/lifetime")
    var x = plan.tensors[op.inputs[0]].copy()
    var pos = plan.tensors[op.inputs[1]].copy()
    var out = plan.tensors[op.output].copy()
    var heads = plan.heads if op.kind == "rope_query" else plan.kv_heads
    if plan.query_tokens <= 0 or heads <= 0 or plan.key_dim <= 0 or plan.rope_dim <= 0 or plan.rope_dim > plan.key_dim or plan.rope_dim % 2 != 0 or (not plan.explicit_scalars and (not isfinite(plan.rope_base) or plan.rope_base <= 0)):
        raise Error("RotaryRecipe: invalid typed dimensions/base")
    if x.persistent or x.alias_of != -1 or out.persistent or out.alias_of != -1 or out.producer != index or out.last_use < index or out.last_use > len(plan.operations) or len(x.shape) != 3 or len(out.shape) != 3:
        raise Error("RotaryRecipe: invalid activation/output roles")
    var expected = List[Int]([plan.query_tokens, heads, plan.key_dim])
    var elements = 1
    for axis in range(3):
        if x.shape[axis] != expected[axis] or out.shape[axis] != expected[axis]:
            raise Error("RotaryRecipe: source activation axes mismatch")
        elements = checked_product(elements, expected[axis])
    if x.elements != elements or out.elements != elements or pos.name != "positions" or pos.producer != -1 or pos.persistent or pos.alias_of != -1 or len(pos.shape) != 1 or pos.shape[0] != plan.query_tokens or pos.elements != plan.query_tokens:
        raise Error("RotaryRecipe: source product/position identity mismatch")
    var r = PrimitiveRecipe(index, op.inputs[0], op.output, op.kind)
    r.source_inputs = op.inputs.copy()
    r.input_values = [0, 1]
    r.rotary_dim = plan.rope_dim
    r.rotary_base_scalar = rotary_scalar(plan)
    r.rotary_base_bits = scalar32_mirror(r.rotary_base_scalar)
    r.rotary_pairing = policy.pairing
    r.rotary_provenance = policy.provenance
    r.runtime_preconditions = ["finite_activation_inputs", "positions_equal_past_plus_query_index", "finite_exact_integer_positions", "real_rotation_identity_only_precision_unqualified"]
    var activation = r.value(x.shape.copy())
    var positions = r.value(pos.shape.copy(), "index")
    var pairs = plan.rope_dim // 2
    var angle_shape = List[Int]([plan.query_tokens, pairs])
    var pair_shape = List[Int]([plan.query_tokens, heads, pairs])
    var frequency = r.emit("rotary_inverse_frequency", List[Int](), [pairs])
    var angles = r.emit("rotary_angles", [positions, frequency], angle_shape.copy())
    var cosine = r.emit("cos", [angles], angle_shape.copy())
    var sine = r.emit("sin", [angles], angle_shape.copy())
    var first = r.emit("rotary_first", [activation], pair_shape.copy())
    var second = r.emit("rotary_second", [activation], pair_shape.copy())
    var fc = r.emit("multiply_rotary_cos", [first, cosine], pair_shape.copy())
    var ss = r.emit("multiply_rotary_sin", [second, sine], pair_shape.copy())
    var a = r.emit("subtract", [fc, ss], pair_shape.copy())
    var fs = r.emit("multiply_rotary_sin", [first, sine], pair_shape.copy())
    var sc = r.emit("multiply_rotary_cos", [second, cosine], pair_shape.copy())
    var b = r.emit("add", [fs, sc], pair_shape.copy())
    r.result = r.emit("rotary_assemble", [a, b, activation], x.shape.copy())
    r.values[r.result].last_use = len(r.operations)
    return r^


def _projection_bias_recipe(plan: SemanticPlan, index: Int) raises -> PrimitiveRecipe:
    var width = projection_bias_width(plan, index)
    var op = plan.operations[index].copy()
    var input = plan.tensors[op.inputs[0]].copy()
    var recipe = PrimitiveRecipe(index, op.inputs[0], op.output, op.kind)
    recipe.weight_name = op.weight
    recipe.weight = plan.source.bindings[op.weight].copy()
    recipe.weight_storage = plan.source.storage[op.weight].copy()
    recipe.weight_extent = plan.source.files[recipe.weight_storage.source_path].copy()
    recipe.runtime_preconditions = ["real_projection_bias_addition_precision_unqualified"]
    var x = recipe.value(input.shape.copy())
    var bias = recipe.value([width])
    recipe.result = recipe.emit("add_source_projection_vector", [x, bias], input.shape.copy())
    recipe.values[recipe.result].last_use = len(recipe.operations)
    return recipe^


def _lower_primitive_recipes(plan: SemanticPlan, policy: RotaryLoweringPolicy, rotary: Bool) raises -> PrimitiveRecipes:
    validate_source_inventory(plan.source)
    validate_plan_scalar_state(plan)
    validate_plan_bias_state(plan)
    var lowered = PrimitiveRecipes()
    lowered.explicit_bias = plan.explicit_bias
    lowered.bias_policy = plan.bias_policy.copy()
    lowered.bias_work = plan.bias_work
    lowered.explicit_scalars = plan.explicit_scalars
    lowered.source_scalars = plan.source_scalars.copy()
    if rotary:
        lowered.rotary_work = validate_rotary_policy(plan, policy)
        lowered.rotary_policy = policy.copy()
    for index in range(len(plan.operations)):
        var operation = plan.operations[index].copy()
        if operation.kind == "add_projection_bias":
            lowered.recipes.append(_projection_bias_recipe(plan, index))
            continue
        if rotary and (operation.kind == "rope_query" or operation.kind == "rope_key"):
            lowered.recipes.append(_rotary_recipe(plan, index, policy))
            continue
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
            if len(input.shape) != 2 or (not plan.explicit_scalars and (not isfinite(plan.rms_epsilon) or plan.rms_epsilon <= 0)):
                raise Error("PrimitiveRecipe: RMSNorm requires a matrix and finite positive epsilon")
            var width = input.shape[1]
            if operation.weight not in plan.source.bindings:
                raise Error("PrimitiveRecipe: normalization source weight is missing")
            var weight = plan.source.bindings[operation.weight]
            validate_source_weight(plan.source, operation.weight, width, 1, True)
            recipe.weight_name = operation.weight
            recipe.weight = weight
            recipe.weight_storage = plan.source.storage[operation.weight].copy()
            recipe.weight_extent = plan.source.files[recipe.weight_storage.source_path].copy()
            recipe.divisor = width
            recipe.epsilon_scalar = rms_scalar(plan)
            recipe.epsilon_bits = scalar32_mirror(recipe.epsilon_scalar)
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
