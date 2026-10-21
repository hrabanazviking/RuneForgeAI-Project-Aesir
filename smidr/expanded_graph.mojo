# Original source-to-global mathematical IR integration; never execution.
from std.collections import Dict
from smidr.source_inventory import validate_source_weight
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.primitive_recipes import PrimitiveRecipes, lower_primitive_recipes
from smidr.primitive_recipes import _rotary_recipe
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
    var source_weight: String
    var runtime_preconditions: List[String]
    var rotary_dim: Int
    var rotary_base_bits: UInt32
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
             rotary_pairing: String = "", rotary_provenance: String = "") raises -> Int:
        var step = len(self.operations)
        for input_id in inputs:
            if input_id < 0 or input_id >= len(self.values) or self.values[input_id].producer >= step:
                raise Error("ExpandedGraph: input is unavailable")
            self.values[input_id].last_use = step
        var output = self.value(name, shape^, domain, storage, step, alias_of, source_tensor)
        self.operations.append(ExpandedOperation(kind, inputs^, output, source_operation,
            recipe_step, width, epsilon_bits, source_weight, preconditions.copy(),
            rotary_dim, rotary_base_bits, rotary_pairing, rotary_provenance))
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
                var weight = recipe.weight_name if op.kind == "multiply_source_vector" else String("")
                local[op.output] = graph.emit(op.kind, name, inputs^, value.shape.copy(),
                    value.domain, "activation", index, j, recipe.divisor,
                    recipe.epsilon_bits, weight, recipe.runtime_preconditions,
                    -1, source_id, recipe.rotary_dim, recipe.rotary_base_bits,
                    recipe.rotary_pairing, recipe.rotary_provenance)
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
    for i in range(len(graph.values)):
        if graph.values[i].storage == "persistent_kv" or graph.values[i].storage == "source_weight":
            graph.values[i].last_use = end
    return graph^


def validate_rotary_expansion(graph: ExpandedGraph) raises:
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
        if stored.source_inputs != recipe.source_inputs or stored.input_values != recipe.input_values or stored.source_input != recipe.source_input or stored.source_output != recipe.source_output or stored.kind != recipe.kind or stored.rotary_dim != recipe.rotary_dim or stored.rotary_base_bits != recipe.rotary_base_bits or stored.rotary_pairing != recipe.rotary_pairing or stored.rotary_provenance != recipe.rotary_provenance or stored.runtime_preconditions != recipe.runtime_preconditions or stored.result != recipe.result or len(stored.values) != len(recipe.values) or len(stored.operations) != len(recipe.operations) or stored.divisor != 0 or stored.epsilon_bits != 0 or stored.weight_name.byte_length() != 0:
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
            if actual.source_operation != recipe.source_operation or actual.recipe_step != j or actual.kind != expected.kind or len(actual.inputs) != len(expected.inputs) or actual.rotary_dim != recipe.rotary_dim or actual.rotary_base_bits != recipe.rotary_base_bits or actual.rotary_pairing != recipe.rotary_pairing or actual.rotary_provenance != recipe.rotary_provenance or actual.width != 0 or actual.epsilon_bits != 0 or actual.source_weight.byte_length() != 0 or actual.runtime_preconditions != recipe.runtime_preconditions:
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
