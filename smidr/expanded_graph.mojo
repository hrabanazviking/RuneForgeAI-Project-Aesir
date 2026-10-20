# Original source-to-global mathematical IR integration; never execution.
from std.collections import Dict
from smidr.semantic_plan import SemanticPlan, checked_product
from smidr.primitive_recipes import PrimitiveRecipes, lower_primitive_recipes


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
        if binding.columns <= 0 or binding.rows <= 0 or binding.file_offset < self.source.source.data_offset or binding.file_offset > self.source.source.source_bytes or binding.byte_count <= 0 or binding.byte_count > self.source.source.source_bytes - binding.file_offset:
            raise Error("ExpandedGraph: invalid source weight extent")
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
             source_tensor: Int = -1) raises -> Int:
        var step = len(self.operations)
        for input_id in inputs:
            if input_id < 0 or input_id >= len(self.values) or self.values[input_id].producer >= step:
                raise Error("ExpandedGraph: input is unavailable")
            self.values[input_id].last_use = step
        var output = self.value(name, shape^, domain, storage, step, alias_of, source_tensor)
        self.operations.append(ExpandedOperation(kind, inputs^, output, source_operation,
            recipe_step, width, epsilon_bits, source_weight, preconditions.copy()))
        return output


def expand_semantic_graph(var plan: SemanticPlan) raises -> ExpandedGraph:
    var recipes = lower_primitive_recipes(plan)
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
            local[0] = graph.source_values[recipe.source_input]
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
                    -1, source_id)
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
