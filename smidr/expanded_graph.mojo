from smidr.session_graph import validate_plan_session_state
from smidr.session_policy import same_session_policy
from smidr.activation_graph import validate_plan_activation_state
from smidr.activation_policy import same_activation_policy, activation_kind_supported
# Original source-to-global mathematical IR integration; never execution.
from std.collections import Dict
from smidr.bias_policy import same_bias_policy
from smidr.bias_graph import validate_plan_bias_state
from smidr.source_inventory import validate_source_weight
from smidr.semantic_plan import SemanticPlan, checked_product, validate_plan_scalar_state, rms_scalar, rotary_scalar
from smidr.source_scalars import ScalarWord, same_scalar_word, same_decoder_scalars, scalar32_mirror
from smidr.primitive_recipes import PrimitiveRecipes, lower_primitive_recipes
from smidr.primitive_recipes import _rotary_recipe, _projection_bias_recipe, _activation_recipe, _selected_silu_recipe
from smidr.rotary_policy import RotaryLoweringPolicy, validate_rotary_policy


@fieldwise_init
struct ExpandedValue(Copyable, Movable):
    var name: String
    var shape: List[Int]
    var elements: Int
    var domain: String
    var storage: String
    var producer: Int
    var last_use: Int
    var alias_of: Int
    var source_tensor: Int
    var source_weight: String


@fieldwise_init
struct ExpandedOperation(Copyable, Movable):
    var kind: String
    var inputs: List[Int]
    var output: Int
    var source_operation: Int
    var recipe_step: Int
    var width: Int
    var epsilon_bits: UInt32
    var epsilon_scalar: ScalarWord
    var source_weight: String
    var runtime_preconditions: List[String]
    var rotary_dim: Int
    var rotary_base_bits: UInt32
    var rotary_base_scalar: ScalarWord
    var rotary_pairing: String
    var rotary_provenance: String


struct ExpandedGraph(Movable):
    var source: SemanticPlan
    var recipes: PrimitiveRecipes
    var values: List[ExpandedValue]
    var operations: List[ExpandedOperation]
    var source_values: Dict[Int, Int]
    var weight_values: Dict[String, Int]
    var result: Int

    def __init__(out self, var source: SemanticPlan, var recipes: PrimitiveRecipes):
        self.source = source^
        self.recipes = recipes^
        self.values = List[ExpandedValue]()
        self.operations = List[ExpandedOperation]()
        self.source_values = Dict[Int, Int]()
        self.weight_values = Dict[String, Int]()
        self.result = -1

    def value(mut self, name: String, var shape: List[Int], domain: String,
              storage: String, producer: Int = -1, alias_of: Int = -1,
              source_tensor: Int = -1, source_weight: String = "") raises -> Int:
        if len(shape) == 0:
            raise Error("ExpandedGraph: empty value shape")
        var elements = 1
        for dimension in shape:
            elements = checked_product(elements, dimension)
        if alias_of != -1:
            if alias_of < 0 or alias_of >= len(self.values) or storage != "kv_view":
                raise Error("ExpandedGraph: invalid alias reference")
            var base = self.values[alias_of].copy()
            if base.storage != "persistent_kv" or base.elements < elements or len(base.shape) != len(shape):
                raise Error("ExpandedGraph: invalid persistent alias extent")
            for axis in range(1, len(shape)):
                if base.shape[axis] != shape[axis]:
                    raise Error("ExpandedGraph: incompatible cache view axes")
        elif storage == "kv_view":
            raise Error("ExpandedGraph: cache view has no base")
        var index = len(self.values)
        self.values.append(ExpandedValue(name, shape^, elements, domain, storage,
                                         producer, producer, alias_of, source_tensor, source_weight))
        return index

    def weight_reference(mut self, name: String, vector: Bool) raises -> Int:
        if name not in self.source.source.bindings:
            raise Error("ExpandedGraph: missing source weight binding")
        var binding = self.source.source.bindings[name]
        validate_source_weight(self.source.source, name, binding.columns, binding.rows, vector)
        var shape: List[Int]
        if vector:
            if binding.rows != 1:
                raise Error("ExpandedGraph: vector weight has matrix rows")
            shape = [binding.columns]
        else:
            # Logical math axes; physical packed source kind/layout is retained
            # in the source binding and remains an independent conversion gate.
            shape = [binding.rows, binding.columns]
        if name in self.weight_values:
            var old = self.weight_values[name]
            if len(self.values[old].shape) != len(shape):
                raise Error("ExpandedGraph: conflicting weight reference roles")
            for axis in range(len(shape)):
                if self.values[old].shape[axis] != shape[axis]:
                    raise Error("ExpandedGraph: conflicting weight reference shape")
            return old
        var result = self.value(name, shape^, "real", "source_weight", -1, -1, -1, name)
        self.weight_values[name] = result
        return result

    def emit(mut self, kind: String, name: String, var inputs: List[Int],
             var shape: List[Int], domain: String, storage: String,
             source_operation: Int, recipe_step: Int = -1, width: Int = 0,
             epsilon_bits: UInt32 = 0, source_weight: String = "",
             preconditions: List[String] = List[String](), alias_of: Int = -1,
             source_tensor: Int = -1, rotary_dim: Int = 0, rotary_base_bits: UInt32 = 0,
             rotary_pairing: String = "", rotary_provenance: String = "",
             epsilon_scalar: ScalarWord = ScalarWord(0, 0),
             rotary_base_scalar: ScalarWord = ScalarWord(0, 0)) raises -> Int:
        var step = len(self.operations)
        for input_id in inputs:
            if input_id < 0 or input_id >= len(self.values) or self.values[input_id].producer >= step:
                raise Error("ExpandedGraph: input is unavailable")
            self.values[input_id].last_use = step
        var output = self.value(name, shape^, domain, storage, step, alias_of, source_tensor)
        self.operations.append(ExpandedOperation(kind, inputs^, output, source_operation,
            recipe_step, width, epsilon_bits, epsilon_scalar.copy(), source_weight, preconditions.copy(),
            rotary_dim, rotary_base_bits, rotary_base_scalar.copy(), rotary_pairing, rotary_provenance))
        return output


def expand_semantic_graph(var plan: SemanticPlan) raises -> ExpandedGraph:
    var recipes = lower_primitive_recipes(plan)
    return _expand_semantic_graph(plan^, recipes^)


def expand_semantic_graph(var plan: SemanticPlan, policy: RotaryLoweringPolicy) raises -> ExpandedGraph:
    var recipes = lower_primitive_recipes(plan, policy)
    return _expand_semantic_graph(plan^, recipes^)


def _expand_semantic_graph(var plan: SemanticPlan, var recipes: PrimitiveRecipes) raises -> ExpandedGraph:
    var graph = ExpandedGraph(plan^, recipes^)
    var recipe_for_source = Dict[Int, Int]()
    for i in range(len(graph.recipes.recipes)):
        recipe_for_source[graph.recipes.recipes[i].source_operation] = i
    var source_end = len(graph.source.operations)
    # Original external inputs and persistent bases have no producing operation.
    for i in range(len(graph.source.tensors)):
        var tensor = graph.source.tensors[i].copy()
        if tensor.producer != -1:
            continue
        if tensor.alias_of != -1:
            raise Error("ExpandedGraph: preexisting value cannot be an append view")
        var domain = String("index")
        var storage = String("index")
        if tensor.persistent:
            if tensor.last_use != source_end:
                raise Error("ExpandedGraph: persistent source lifetime is incomplete")
            domain = String("real")
            storage = String("persistent_kv")
        elif tensor.name != "tokens" and tensor.name != "positions":
            raise Error("ExpandedGraph: external input domain is unresolved")
        elif len(tensor.shape) != 1 or tensor.shape[0] != graph.source.query_tokens:
            raise Error("ExpandedGraph: external index shape is invalid")
        var mapped = graph.value(tensor.name, tensor.shape.copy(), domain, storage, -1, -1, i)
        if graph.values[mapped].elements != tensor.elements:
            raise Error("ExpandedGraph: preexisting shape/product mismatch")
        graph.source_values[i] = mapped
    for index in range(source_end):
        var source_op = graph.source.operations[index].copy()
        if source_op.output < 0 or source_op.output >= len(graph.source.tensors) or source_op.output in graph.source_values:
            raise Error("ExpandedGraph: duplicate or invalid source output")
        var source_out = graph.source.tensors[source_op.output].copy()
        if source_out.producer != index or source_out.persistent:
            raise Error("ExpandedGraph: source output producer/storage mismatch")
        for input_id in source_op.inputs:
            if input_id not in graph.source_values or graph.source.tensors[input_id].last_use < index:
                raise Error("ExpandedGraph: unmapped or expired source input")
        if index in recipe_for_source:
            var recipe = graph.recipes.recipes[recipe_for_source[index]].copy()
            var local = Dict[Int, Int]()
            if len(recipe.source_inputs) != len(recipe.input_values):
                raise Error("ExpandedGraph: incomplete primitive source input mapping")
            for input in range(len(recipe.source_inputs)):
                local[recipe.input_values[input]] = graph.source_values[recipe.source_inputs[input]]
            if recipe.weight_name.byte_length() != 0:
                local[1] = graph.weight_reference(recipe.weight_name, True)
            for j in range(len(recipe.operations)):
                var op = recipe.operations[j].copy()
                var inputs = List[Int]()
                for input_id in op.inputs:
                    if input_id not in local:
                        raise Error("ExpandedGraph: unmapped primitive input")
                    inputs.append(local[input_id])
                var value = recipe.values[op.output].copy()
                var is_result = op.output == recipe.result
                var name = source_out.name if is_result else source_out.name + ".primitive." + String(j)
                var source_id = source_op.output if is_result else -1
                var weight = recipe.weight_name if op.kind == "multiply_source_vector" or op.kind == "add_source_projection_vector" else String("")
                local[op.output] = graph.emit(op.kind, name, inputs^, value.shape.copy(),
                    value.domain, "activation", index, j, recipe.divisor,
                    recipe.epsilon_bits, weight, recipe.runtime_preconditions,
                    -1, source_id, recipe.rotary_dim, recipe.rotary_base_bits,
                    recipe.rotary_pairing, recipe.rotary_provenance,
                    recipe.epsilon_scalar, recipe.rotary_base_scalar)
            graph.source_values[source_op.output] = local[recipe.result]
        else:
            var inputs = List[Int]()
            for input_id in source_op.inputs:
                inputs.append(graph.source_values[input_id])
            if source_op.weight.byte_length() != 0:
                inputs.append(graph.weight_reference(source_op.weight, False))
            var alias_of = -1
            var storage = String("activation")
            if source_out.alias_of != -1:
                if source_out.alias_of not in graph.source_values:
                    raise Error("ExpandedGraph: unmapped cache base")
                alias_of = graph.source_values[source_out.alias_of]
                storage = String("kv_view")
            var mapped = graph.emit(source_op.kind, source_out.name, inputs^,
                source_out.shape.copy(), "real", storage, index, -1, 0, 0,
                source_op.weight, List[String](), alias_of, source_op.output)
            if graph.values[mapped].elements != source_out.elements:
                raise Error("ExpandedGraph: source result shape/product mismatch")
            graph.source_values[source_op.output] = mapped
    if len(graph.source_values) != len(graph.source.tensors) or graph.source.logits not in graph.source_values:
        raise Error("ExpandedGraph: source value/export mapping is incomplete")
    graph.result = graph.source_values[graph.source.logits]
    var end = len(graph.operations)
    graph.values[graph.result].last_use = end
    for id in graph.source.cache_exports:
        graph.values[graph.source_values[id]].last_use = end
    for i in range(len(graph.values)):
        if graph.values[i].storage == "persistent_kv" or graph.values[i].storage == "source_weight":
            graph.values[i].last_use = end
    return graph^


def validate_rotary_expansion(graph: ExpandedGraph) raises:
    validate_session_expansion(graph)
    validate_scalar_expansion(graph)
    validate_bias_expansion(graph)
    validate_activation_expansion(graph)
    var enabled = graph.recipes.rotary_policy.pairing.byte_length() != 0
    if enabled:
        if validate_rotary_policy(graph.source, graph.recipes.rotary_policy) != graph.recipes.rotary_work:
            raise Error("RotaryExpansion: stale descriptor work")
    elif graph.recipes.rotary_work != 0 or graph.recipes.rotary_policy.provenance.byte_length() != 0 or graph.recipes.rotary_policy.max_recipes != 0 or graph.recipes.rotary_policy.work != 0:
        raise Error("RotaryExpansion: partial explicit policy")
    var cursor = 0
    var seen = Dict[Int, Bool]()
    var stored_for_source = Dict[Int, Int]()
    if enabled:
        if len(graph.recipes.recipes) > len(graph.source.operations):
            raise Error("RotaryExpansion: excessive stored recipe count")
        for i in range(len(graph.recipes.recipes)):
            var id = graph.recipes.recipes[i].source_operation
            if id < 0 or id >= len(graph.source.operations) or id in stored_for_source:
                raise Error("RotaryExpansion: invalid stored recipe identity")
            stored_for_source[id] = i
    while cursor < len(graph.operations):
        var op = graph.operations[cursor].copy()
        if op.source_operation < 0 or op.source_operation >= len(graph.source.operations):
            raise Error("RotaryExpansion: invalid source operation")
        var source = graph.source.operations[op.source_operation].copy()
        var rotary = source.kind == "rope_query" or source.kind == "rope_key"
        if not enabled or not rotary:
            if op.rotary_dim != 0 or op.rotary_base_bits != 0 or op.rotary_pairing.byte_length() != 0 or op.rotary_provenance.byte_length() != 0 or op.kind.startswith("rotary_") or op.kind.startswith("multiply_rotary_"):
                raise Error("RotaryExpansion: stray rotary metadata")
            cursor += 1
            continue
        if op.source_operation in seen:
            raise Error("RotaryExpansion: duplicate recipe group")
        seen[op.source_operation] = True
        var recipe = _rotary_recipe(graph.source, op.source_operation, graph.recipes.rotary_policy)
        if op.source_operation not in stored_for_source:
            raise Error("RotaryExpansion: missing owned source recipe")
        var stored = graph.recipes.recipes[stored_for_source[op.source_operation]].copy()
        if stored.source_inputs != recipe.source_inputs or stored.input_values != recipe.input_values or stored.source_input != recipe.source_input or stored.source_output != recipe.source_output or stored.kind != recipe.kind or not same_scalar_word(stored.rotary_base_scalar, recipe.rotary_base_scalar) or stored.rotary_dim != recipe.rotary_dim or stored.rotary_base_bits != recipe.rotary_base_bits or stored.rotary_pairing != recipe.rotary_pairing or stored.rotary_provenance != recipe.rotary_provenance or stored.runtime_preconditions != recipe.runtime_preconditions or stored.result != recipe.result or len(stored.values) != len(recipe.values) or len(stored.operations) != len(recipe.operations) or stored.divisor != 0 or stored.epsilon_bits != 0 or stored.weight_name.byte_length() != 0:
            raise Error("RotaryExpansion: changed owned recipe/mapping")
        for i in range(len(recipe.values)):
            if stored.values[i].shape != recipe.values[i].shape or stored.values[i].elements != recipe.values[i].elements or stored.values[i].domain != recipe.values[i].domain or stored.values[i].producer != recipe.values[i].producer or stored.values[i].last_use != recipe.values[i].last_use:
                raise Error("RotaryExpansion: changed owned recipe value")
        for i in range(len(recipe.operations)):
            if stored.operations[i].kind != recipe.operations[i].kind or stored.operations[i].inputs != recipe.operations[i].inputs or stored.operations[i].output != recipe.operations[i].output:
                raise Error("RotaryExpansion: changed owned recipe operation")
        var local = Dict[Int, Int]()
        for i in range(len(recipe.source_inputs)):
            if recipe.source_inputs[i] not in graph.source_values:
                raise Error("RotaryExpansion: missing source input mapping")
            local[recipe.input_values[i]] = graph.source_values[recipe.source_inputs[i]]
        for j in range(len(recipe.operations)):
            if cursor >= len(graph.operations):
                raise Error("RotaryExpansion: truncated recipe")
            var actual = graph.operations[cursor].copy()
            var expected = recipe.operations[j].copy()
            if actual.source_operation != recipe.source_operation or actual.recipe_step != j or actual.kind != expected.kind or len(actual.inputs) != len(expected.inputs) or not same_scalar_word(actual.rotary_base_scalar, recipe.rotary_base_scalar) or actual.rotary_dim != recipe.rotary_dim or actual.rotary_base_bits != recipe.rotary_base_bits or actual.rotary_pairing != recipe.rotary_pairing or actual.rotary_provenance != recipe.rotary_provenance or actual.width != 0 or actual.epsilon_bits != 0 or actual.source_weight.byte_length() != 0 or actual.runtime_preconditions != recipe.runtime_preconditions:
                raise Error("RotaryExpansion: changed recipe operation/metadata")
            for i in range(len(expected.inputs)):
                if expected.inputs[i] not in local or actual.inputs[i] != local[expected.inputs[i]]:
                    raise Error("RotaryExpansion: changed recipe edge")
            if actual.output < 0 or actual.output >= len(graph.values):
                raise Error("RotaryExpansion: invalid recipe result")
            var value = graph.values[actual.output].copy()
            var wanted = recipe.values[expected.output].copy()
            if value.shape != wanted.shape or value.elements != wanted.elements or value.domain != wanted.domain or value.storage != "activation" or value.producer != cursor or value.alias_of != -1:
                raise Error("RotaryExpansion: changed recipe value")
            local[expected.output] = actual.output
            cursor += 1
        if recipe.source_output not in graph.source_values or graph.source_values[recipe.source_output] != local[recipe.result]:
            raise Error("RotaryExpansion: changed exported mapping")
    if enabled:
        for i in range(len(graph.source.operations)):
            if (graph.source.operations[i].kind == "rope_query" or graph.source.operations[i].kind == "rope_key") and i not in seen:
                raise Error("RotaryExpansion: missing complete source recipe")


def validate_bias_expansion(graph: ExpandedGraph) raises:
    validate_plan_bias_state(graph.source)
    if graph.recipes.explicit_bias != graph.source.explicit_bias or graph.recipes.bias_work != graph.source.bias_work or not same_bias_policy(graph.recipes.bias_policy, graph.source.bias_policy):
        raise Error("ExpandedStorage: retained bias policy/accounting changed")
    var stored = Dict[Int, Int]()
    for i in range(len(graph.recipes.recipes)):
        var id = graph.recipes.recipes[i].source_operation
        if id < 0 or id >= len(graph.source.operations):
            raise Error("ExpandedStorage: invalid retained bias recipe identity")
        if graph.source.operations[id].kind == "add_projection_bias":
            if id in stored:
                raise Error("ExpandedStorage: duplicate retained bias recipe")
            stored[id] = i
    var seen = Dict[Int, Bool]()
    for i in range(len(graph.operations)):
        var actual = graph.operations[i].copy()
        if actual.source_operation < 0 or actual.source_operation >= len(graph.source.operations):
            raise Error("ExpandedStorage: missing bias source identity")
        if graph.source.operations[actual.source_operation].kind != "add_projection_bias":
            if actual.kind == "add_source_projection_vector":
                raise Error("ExpandedStorage: stray projection bias operation")
            continue
        var id = actual.source_operation
        if id in seen or id not in stored:
            raise Error("ExpandedStorage: duplicate or missing complete bias recipe")
        seen[id] = True
        var expected = _projection_bias_recipe(graph.source, id)
        var retained = graph.recipes.recipes[stored[id]].copy()
        if retained.kind != expected.kind or retained.source_operation != expected.source_operation or retained.source_input != expected.source_input or retained.source_inputs != expected.source_inputs or retained.input_values != expected.input_values or retained.source_output != expected.source_output or retained.weight_name != expected.weight_name or retained.result != expected.result or retained.divisor != 0 or retained.rotary_dim != 0 or retained.rotary_pairing.byte_length() != 0 or retained.rotary_provenance.byte_length() != 0 or retained.runtime_preconditions != expected.runtime_preconditions or len(retained.values) != 3 or len(retained.operations) != 1:
            raise Error("ExpandedStorage: changed retained bias recipe metadata")
        var a = retained.weight
        var b = expected.weight
        if a.file_offset != b.file_offset or a.columns != b.columns or a.rows != b.rows or a.source_kind != b.source_kind or a.byte_count != b.byte_count:
            raise Error("ExpandedStorage: changed retained bias source binding")
        var x = retained.weight_storage.copy()
        var y = expected.weight_storage.copy()
        if x.source_format != y.source_format or x.source_kind != y.source_kind or x.original_name != y.original_name or x.source_path != y.source_path or x.source_shape != y.source_shape or x.axis_order != y.axis_order or x.elements != y.elements or x.file_offset != y.file_offset or x.byte_count != y.byte_count or retained.weight_extent.source_format != expected.weight_extent.source_format or retained.weight_extent.source_bytes != expected.weight_extent.source_bytes or retained.weight_extent.data_offset != expected.weight_extent.data_offset:
            raise Error("ExpandedStorage: changed retained bias tagged storage/extent")
        for j in range(3):
            if retained.values[j].shape != expected.values[j].shape or retained.values[j].elements != expected.values[j].elements or retained.values[j].domain != expected.values[j].domain or retained.values[j].producer != expected.values[j].producer or retained.values[j].last_use != expected.values[j].last_use:
                raise Error("ExpandedStorage: changed retained bias value/lifetime")
        if retained.operations[0].kind != expected.operations[0].kind or retained.operations[0].inputs != expected.operations[0].inputs or retained.operations[0].output != expected.operations[0].output:
            raise Error("ExpandedStorage: changed retained bias operation")
        if actual.kind != "add_source_projection_vector" or actual.recipe_step != 0 or actual.source_weight != expected.weight_name or actual.width != 0 or actual.rotary_dim != 0 or actual.rotary_pairing.byte_length() != 0 or actual.rotary_provenance.byte_length() != 0 or actual.runtime_preconditions != expected.runtime_preconditions or len(actual.inputs) != 2:
            raise Error("ExpandedStorage: changed expanded bias metadata")
        if expected.source_input not in graph.source_values or expected.source_output not in graph.source_values or expected.weight_name not in graph.weight_values or actual.inputs[0] != graph.source_values[expected.source_input] or actual.inputs[1] != graph.weight_values[expected.weight_name] or actual.output != graph.source_values[expected.source_output] or actual.output < 0 or actual.output >= len(graph.values):
            raise Error("ExpandedStorage: changed expanded bias source/weight/result mapping")
        var value = graph.values[actual.output].copy()
        if value.shape != expected.values[expected.result].shape or value.elements != expected.values[expected.result].elements or value.domain != "real" or value.storage != "activation" or value.producer != i or value.alias_of != -1 or value.name != graph.source.tensors[expected.source_output].name:
            raise Error("ExpandedStorage: changed expanded bias result")
    for i in range(len(graph.source.operations)):
        if graph.source.operations[i].kind == "add_projection_bias":
            if i not in seen:
                raise Error("ExpandedStorage: missing complete projection bias")
            for id in graph.recipes.remaining_source_operations:
                if id == i:
                    raise Error("ExpandedStorage: lowered bias marked as remaining")


def validate_scalar_expansion(graph: ExpandedGraph) raises:
    validate_plan_scalar_state(graph.source)
    if graph.recipes.explicit_scalars != graph.source.explicit_scalars or not same_decoder_scalars(graph.recipes.source_scalars, graph.source.source_scalars):
        raise Error("ExpandedStorage: retained recipe scalar snapshot changed")
    var empty = ScalarWord(0, 0)
    for i in range(len(graph.recipes.recipes)):
        var recipe = graph.recipes.recipes[i].copy()
        if recipe.source_operation < 0 or recipe.source_operation >= len(graph.source.operations) or recipe.kind != graph.source.operations[recipe.source_operation].kind:
            raise Error("ExpandedStorage: invalid recipe source role")
        var epsilon = rms_scalar(graph.source) if recipe.kind == "rms_norm" else empty.copy()
        var base = rotary_scalar(graph.source) if recipe.kind == "rope_query" or recipe.kind == "rope_key" else empty.copy()
        if not same_scalar_word(recipe.epsilon_scalar, epsilon) or not same_scalar_word(recipe.rotary_base_scalar, base) or recipe.epsilon_bits != scalar32_mirror(epsilon) or recipe.rotary_base_bits != scalar32_mirror(base):
            raise Error("ExpandedStorage: retained recipe scalar/mirror changed")
    for i in range(len(graph.operations)):
        var op = graph.operations[i].copy()
        if op.source_operation < 0 or op.source_operation >= len(graph.source.operations):
            raise Error("ExpandedStorage: missing source operation identity")
        var kind = graph.source.operations[op.source_operation].kind
        var epsilon = rms_scalar(graph.source) if kind == "rms_norm" else empty.copy()
        var base = rotary_scalar(graph.source) if (kind == "rope_query" or kind == "rope_key") and op.recipe_step >= 0 else empty.copy()
        if not same_scalar_word(op.epsilon_scalar, epsilon) or not same_scalar_word(op.rotary_base_scalar, base) or op.epsilon_bits != scalar32_mirror(epsilon) or op.rotary_base_bits != scalar32_mirror(base):
            raise Error("ExpandedStorage: expanded scalar/mirror changed")



def validate_activation_expansion(graph: ExpandedGraph) raises:
    validate_plan_activation_state(graph.source)
    if graph.recipes.explicit_activation != graph.source.explicit_activation or graph.recipes.activation_work != graph.source.activation_work or not same_activation_policy(graph.recipes.activation_policy, graph.source.activation_policy):
        raise Error("ExpandedStorage: retained activation policy/accounting changed")
    if not graph.source.explicit_activation:
        return
    var stored = Dict[Int, Int]()
    for i in range(len(graph.recipes.recipes)):
        var id = graph.recipes.recipes[i].source_operation
        if id < 0 or id >= len(graph.source.operations) or id in stored:
            raise Error("ExpandedStorage: invalid retained activation recipe identity")
        stored[id] = i
    var seen = Dict[Int, Bool]()
    var cursor = 0
    while cursor < len(graph.operations):
        var id = graph.operations[cursor].source_operation
        if id < 0 or id >= len(graph.source.operations):
            raise Error("ExpandedStorage: invalid activation source identity")
        var kind = graph.source.operations[id].kind
        if not activation_kind_supported(kind):
            var k = graph.operations[cursor].kind
            if k == "maximum_zero" or k == "multiply_inverse_sqrt_two" or k == "erf" or k == "multiply_half":
                raise Error("ExpandedStorage: stray selected activation primitive")
            cursor += 1
            continue
        if id in seen or id not in stored:
            raise Error("ExpandedStorage: duplicate/missing activation recipe group")
        seen[id] = True
        var expected = _selected_silu_recipe(graph.source, id) if kind == "silu" else _activation_recipe(graph.source, id)
        var retained = graph.recipes.recipes[stored[id]].copy()
        if retained.source_operation != expected.source_operation or retained.source_input != expected.source_input or retained.source_inputs != expected.source_inputs or retained.input_values != expected.input_values or retained.source_output != expected.source_output or retained.kind != expected.kind or retained.result != expected.result or retained.runtime_preconditions != expected.runtime_preconditions or len(retained.values) != len(expected.values) or len(retained.operations) != len(expected.operations):
            raise Error("ExpandedStorage: changed retained activation identity/mapping")
        if retained.weight_name.byte_length() != 0 or retained.weight.file_offset != 0 or retained.weight.columns != 0 or retained.weight.rows != 0 or retained.weight.source_kind != 0 or retained.weight.byte_count != 0 or retained.weight_storage.source_format.byte_length() != 0 or retained.weight_storage.source_kind != 0 or retained.weight_storage.original_name.byte_length() != 0 or retained.weight_storage.source_path.byte_length() != 0 or len(retained.weight_storage.source_shape) != 0 or retained.weight_storage.axis_order.byte_length() != 0 or retained.weight_storage.elements != 0 or retained.weight_storage.file_offset != 0 or retained.weight_storage.byte_count != 0 or retained.weight_extent.source_format.byte_length() != 0 or retained.weight_extent.source_bytes != 0 or retained.weight_extent.data_offset != 0 or retained.divisor != 0 or retained.epsilon_bits != 0 or retained.rotary_dim != 0 or retained.rotary_base_bits != 0 or retained.rotary_pairing.byte_length() != 0 or retained.rotary_provenance.byte_length() != 0:
            raise Error("ExpandedStorage: stray retained activation metadata")
        for j in range(len(expected.values)):
            if retained.values[j].shape != expected.values[j].shape or retained.values[j].elements != expected.values[j].elements or retained.values[j].domain != expected.values[j].domain or retained.values[j].producer != expected.values[j].producer or retained.values[j].last_use != expected.values[j].last_use:
                raise Error("ExpandedStorage: changed activation local value/lifetime")
        var local = Dict[Int, Int]()
        if expected.source_input not in graph.source_values:
            raise Error("ExpandedStorage: missing activation input mapping")
        local[0] = graph.source_values[expected.source_input]
        for j in range(len(expected.operations)):
            if cursor >= len(graph.operations):
                raise Error("ExpandedStorage: truncated activation recipe")
            var actual = graph.operations[cursor].copy()
            var op = expected.operations[j].copy()
            if retained.operations[j].kind != op.kind or retained.operations[j].inputs != op.inputs or retained.operations[j].output != op.output:
                raise Error("ExpandedStorage: changed retained activation operation")
            if actual.source_operation != id or actual.recipe_step != j or actual.kind != op.kind or len(actual.inputs) != len(op.inputs) or actual.runtime_preconditions != expected.runtime_preconditions or actual.width != 0 or actual.epsilon_bits != 0 or actual.rotary_dim != 0 or actual.rotary_base_bits != 0 or actual.rotary_pairing.byte_length() != 0 or actual.rotary_provenance.byte_length() != 0 or actual.source_weight.byte_length() != 0:
                raise Error("ExpandedStorage: changed expanded activation metadata")
            for k in range(len(op.inputs)):
                if op.inputs[k] not in local or actual.inputs[k] != local[op.inputs[k]]:
                    raise Error("ExpandedStorage: changed activation primitive edge")
            if actual.output < 0 or actual.output >= len(graph.values):
                raise Error("ExpandedStorage: invalid activation primitive result")
            var value = graph.values[actual.output].copy()
            var wanted = expected.values[op.output].copy()
            var result = op.output == expected.result
            var name = graph.source.tensors[expected.source_output].name
            var source_id = expected.source_output if result else -1
            if not result:
                name += ".primitive." + String(j)
            if value.shape != wanted.shape or value.elements != wanted.elements or value.domain != wanted.domain or value.producer != cursor or value.storage != "activation" or value.alias_of != -1 or value.name != name or value.source_tensor != source_id or value.source_weight.byte_length() != 0:
                raise Error("ExpandedStorage: changed activation primitive result role")
            local[op.output] = actual.output
            cursor += 1
        if expected.source_output not in graph.source_values or graph.source_values[expected.source_output] != local[expected.result]:
            raise Error("ExpandedStorage: changed activation result mapping")
        for remaining in graph.recipes.remaining_source_operations:
            if remaining == id:
                raise Error("ExpandedStorage: lowered activation marked as remaining")
    for i in range(len(graph.source.operations)):
        if activation_kind_supported(graph.source.operations[i].kind) and i not in seen:
            raise Error("ExpandedStorage: omitted selected activation expansion")



def is_expanded_export(graph: ExpandedGraph, value: Int) raises -> Bool:
    if value == graph.result:
        return True
    if len(graph.source.cache_exports) > graph.source.source.policy.work:
        raise Error("DecoderSession: expanded export work bound exceeded")
    for id in graph.source.cache_exports:
        if id not in graph.source_values:
            raise Error("DecoderSession: missing expanded export mapping")
        if graph.source_values[id] == value:
            return True
    return False


def validate_session_expansion(graph: ExpandedGraph) raises:
    validate_plan_session_state(graph.source)
    if graph.recipes.explicit_session != graph.source.explicit_session or graph.recipes.session_work != graph.source.session_work or not same_session_policy(graph.recipes.session_policy, graph.source.session_policy) or graph.recipes.cache_exports != graph.source.cache_exports:
        raise Error("ExpandedStorage: retained session policy/export snapshot changed")
    for id in graph.source.cache_exports:
        if id not in graph.source_values:
            raise Error("ExpandedStorage: missing cache export source mapping")
        var mapped = graph.source_values[id]
        if mapped < 0 or mapped >= len(graph.values):
            raise Error("ExpandedStorage: cache export map out of range")
        var v = graph.values[mapped].copy()
        var source = graph.source.tensors[id].copy()
        if v.source_tensor != id or v.name != source.name or v.shape != source.shape or v.elements != source.elements or v.domain != "real" or v.last_use != len(graph.operations) or (v.storage != "activation" and v.storage != "kv_view"):
            raise Error("ExpandedStorage: changed cache export identity/shape/lifetime")
