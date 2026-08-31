# loader/onnx.mojo
# Bounded ONNX protobuf metadata parser and explicit execution boundary.

from std.ffi import external_call
from std.memory import Pointer
from core.mimir_well import MimirWell

comptime MAX_ONNX_STRING_BYTES = 1024 * 1024
comptime MAX_ONNX_NODES = 1000000

struct ONNXNodeDescriptor(Copyable):
    """Validated metadata for one recognized ONNX graph node."""
    var op_type: String
    var name: String
    var input_count: Int
    var output_count: Int

    def __init__(out self, op_type: String, name: String = "", input_count: Int = 1, output_count: Int = 1):
        self.op_type = op_type
        self.name = name
        self.input_count = input_count
        self.output_count = output_count

    def __copyinit__(out self, existing: Self):
        self.op_type = existing.op_type
        self.name = existing.name
        self.input_count = existing.input_count
        self.output_count = existing.output_count

def is_recognized_onnx_op(op_type: String) -> Bool:
    """Returns whether the metadata validator recognizes this operator."""
    if op_type == "MatMul" or op_type == "Add" or op_type == "Mul" or op_type == "Sub" or op_type == "Div":
        return True
    if op_type == "Relu" or op_type == "Softmax" or op_type == "Reshape" or op_type == "Transpose":
        return True
    if op_type == "LayerNormalization" or op_type == "Gather" or op_type == "Concat" or op_type == "Cast":
        return True
    return op_type == "Gemm" or op_type == "Sigmoid" or op_type == "Erf" or op_type == "Gelu"

def validate_onnx_node_op(op_type: String) raises:
    """Rejects operators outside the currently declared metadata subset."""
    if not is_recognized_onnx_op(op_type):
        raise Error("Unsupported ONNX operator type '" + op_type + "' - not in Aesir ONNX metadata subset")

struct _ProtobufCursor:
    """Bounds-checked protobuf wire cursor over caller-owned bytes."""
    var bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin]
    var position: Int
    var size: Int

    def __init__(out self, bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin], size: Int) raises:
        if Int(bytes) == 0 or Int(bytes) == 1:
            raise Error("ONNX protobuf byte pointer is null or sentinel")
        if size <= 0:
            raise Error("ONNX protobuf byte span must be non-empty")
        self.bytes = bytes
        self.position = 0
        self.size = size

    def _require(self, end: Int, byte_count: Int) raises:
        if end < 0 or end > self.size or byte_count < 0:
            raise Error("ONNX protobuf cursor range is invalid")
        if self.position < 0 or self.position > end or byte_count > end - self.position:
            raise Error("ONNX protobuf field is truncated")

    def read_varint(mut self, end: Int) raises -> UInt64:
        """Reads one canonical unsigned protobuf varint (at most 10 bytes)."""
        var value = UInt64(0)
        for index in range(10):
            self._require(end, 1)
            var byte = UInt64(self.bytes.unsafe_load(self.position))
            self.position += 1
            if index == 9 and byte > 1:
                raise Error("ONNX protobuf varint overflows uint64")
            value |= (byte & 0x7F) << UInt64(index * 7)
            if (byte & 0x80) == 0:
                if index > 0 and byte == 0:
                    raise Error("ONNX protobuf contains a non-canonical varint")
                return value
        raise Error("ONNX protobuf varint exceeds 10 bytes")

    def read_key(mut self, end: Int) raises -> Int:
        var key = self.read_varint(end)
        if key == 0 or key > UInt64(0xFFFFFFFF):
            raise Error("ONNX protobuf field key is invalid")
        return Int(key)

    def read_length_end(mut self, end: Int) raises -> Int:
        var encoded = self.read_varint(end)
        if encoded > UInt64(end - self.position):
            raise Error("ONNX protobuf length-delimited field is truncated")
        return self.position + Int(encoded)

    def skip_field(mut self, wire_type: Int, end: Int) raises:
        if wire_type == 0:
            _ = self.read_varint(end)
            return
        if wire_type == 1:
            self._require(end, 8)
            self.position += 8
            return
        if wire_type == 2:
            self.position = self.read_length_end(end)
            return
        if wire_type == 5:
            self._require(end, 4)
            self.position += 4
            return
        raise Error("ONNX protobuf uses an unsupported wire type")

    def _valid_utf8(self, start: Int, count: Int) -> Bool:
        var index = start
        var end = start + count
        while index < end:
            var first = Int(self.bytes.unsafe_load(index))
            if first < 128:
                index += 1
                continue
            var continuation_count: Int
            var codepoint: Int
            var minimum: Int
            if first >= 194 and first <= 223:
                continuation_count = 1
                codepoint = first & 31
                minimum = 128
            elif first >= 224 and first <= 239:
                continuation_count = 2
                codepoint = first & 15
                minimum = 2048
            elif first >= 240 and first <= 244:
                continuation_count = 3
                codepoint = first & 7
                minimum = 65536
            else:
                return False
            if index + continuation_count >= end:
                return False
            for offset in range(1, continuation_count + 1):
                var next = Int(self.bytes.unsafe_load(index + offset))
                if next < 128 or next > 191:
                    return False
                codepoint = (codepoint << 6) | (next & 63)
            if codepoint < minimum or codepoint > 1114111 or (codepoint >= 55296 and codepoint <= 57343):
                return False
            index += continuation_count + 1
        return True

    def read_string(mut self, end: Int) raises -> String:
        var field_end = self.read_length_end(end)
        var count = field_end - self.position
        if count > MAX_ONNX_STRING_BYTES:
            raise Error("ONNX protobuf string exceeds the 1 MiB metadata limit")
        if not self._valid_utf8(self.position, count):
            raise Error("ONNX protobuf string is not valid UTF-8")
        var output = List[Int8]()
        for index in range(count):
            output.append(Int8(self.bytes.unsafe_load(self.position + index)))
        output.append(0)
        self.position = field_end
        return String(unsafe_from_utf8_ptr=output.unsafe_ptr())

struct ONNXModelSeer:
    """Parses bounded ONNX model metadata without claiming tensor execution."""
    var model_path: String
    var ir_version: Int64
    var producer_name: String
    var opset_version: Int64
    var num_nodes: Int
    var nodes: List[ONNXNodeDescriptor]

    def __init__(out self, model_path: String):
        self.model_path = model_path
        self.ir_version = 0
        self.producer_name = ""
        self.opset_version = 0
        self.num_nodes = 0
        self.nodes = List[ONNXNodeDescriptor]()

    def _parse_node(mut self, mut cursor: _ProtobufCursor, node_end: Int) raises -> ONNXNodeDescriptor:
        var name = String("")
        var op_type = String("")
        var input_count = 0
        var output_count = 0
        while cursor.position < node_end:
            var key = cursor.read_key(node_end)
            var field = key >> 3
            var wire = key & 7
            if field == 1:
                if wire != 2:
                    raise Error("ONNX NodeProto.input has the wrong wire type")
                _ = cursor.read_string(node_end)
                input_count += 1
            elif field == 2:
                if wire != 2:
                    raise Error("ONNX NodeProto.output has the wrong wire type")
                _ = cursor.read_string(node_end)
                output_count += 1
            elif field == 3:
                if wire != 2:
                    raise Error("ONNX NodeProto.name has the wrong wire type")
                name = cursor.read_string(node_end)
            elif field == 4:
                if wire != 2:
                    raise Error("ONNX NodeProto.op_type has the wrong wire type")
                op_type = cursor.read_string(node_end)
            else:
                cursor.skip_field(wire, node_end)
        if cursor.position != node_end or len(op_type.as_bytes()) == 0:
            raise Error("ONNX NodeProto is malformed or omits op_type")
        validate_onnx_node_op(op_type)
        return ONNXNodeDescriptor(op_type, name, input_count, output_count)

    def _parse_graph(mut self, mut cursor: _ProtobufCursor, graph_end: Int, mut parsed_nodes: List[ONNXNodeDescriptor]) raises:
        while cursor.position < graph_end:
            var key = cursor.read_key(graph_end)
            var field = key >> 3
            var wire = key & 7
            if field == 1:
                if wire != 2:
                    raise Error("ONNX GraphProto.node has the wrong wire type")
                if len(parsed_nodes) >= MAX_ONNX_NODES:
                    raise Error("ONNX graph exceeds the 1000000 node limit")
                var node_end = cursor.read_length_end(graph_end)
                parsed_nodes.append(self._parse_node(cursor, node_end))
            else:
                cursor.skip_field(wire, graph_end)
        if cursor.position != graph_end:
            raise Error("ONNX GraphProto did not end on a field boundary")

    def _parse_opset(self, mut cursor: _ProtobufCursor, opset_end: Int) raises -> Int64:
        var domain = String("")
        var version = Int64(0)
        var saw_version = False
        while cursor.position < opset_end:
            var key = cursor.read_key(opset_end)
            var field = key >> 3
            var wire = key & 7
            if field == 1:
                if wire != 2:
                    raise Error("ONNX OperatorSetIdProto.domain has the wrong wire type")
                domain = cursor.read_string(opset_end)
            elif field == 2:
                if wire != 0 or saw_version:
                    raise Error("ONNX OperatorSetIdProto.version is malformed or duplicated")
                var encoded = cursor.read_varint(opset_end)
                if encoded == 0 or encoded > UInt64(0x7FFFFFFFFFFFFFFF):
                    raise Error("ONNX opset version is outside the supported integer range")
                version = Int64(encoded)
                saw_version = True
            else:
                cursor.skip_field(wire, opset_end)
        if cursor.position != opset_end:
            raise Error("ONNX OperatorSetIdProto did not end on a field boundary")
        if (domain == "" or domain == "ai.onnx") and saw_version:
            return version
        return Int64(0)

    def parse_onnx_header(mut self) raises -> Bool:
        """Safely maps model_path, parses metadata, then releases the mapping."""
        if len(self.model_path.as_bytes()) == 0:
            raise Error("ONNX model path must not be empty")
        var path = List[Int8]()
        for byte in self.model_path.as_bytes():
            path.append(Int8(byte))
        path.append(0)
        var fd = external_call["open64", Int32](path.unsafe_ptr(), Int32(0xA0000), Int32(0))
        if fd < 0:
            raise Error("Failed to safely open ONNX model: " + self.model_path)
        var file_size = external_call["lseek", Int64](fd, Int64(0), Int32(2))
        if file_size <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("ONNX model has an invalid file size")
        var mapped = external_call["mmap", Int](Int(0), file_size, Int32(1), Int32(2), fd, Int64(0))
        if mapped == -1:
            _ = external_call["close", Int32](fd)
            raise Error("Failed to mmap ONNX model")
        var bytes = Pointer[Scalar[DType.uint8], MutUntrackedOrigin](unsafe_from_address=mapped)
        try:
            _ = self.parse_onnx_header_bytes(bytes, Int(file_size))
        except error:
            _ = external_call["munmap", Int32](bytes, file_size)
            _ = external_call["close", Int32](fd)
            raise error
        _ = external_call["munmap", Int32](bytes, file_size)
        _ = external_call["close", Int32](fd)
        return True

    def parse_onnx_header_bytes(mut self, bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin], size: Int) raises -> Bool:
        """Parses ModelProto metadata transactionally from protobuf bytes."""
        var cursor = _ProtobufCursor(bytes, size)
        var parsed_ir = Int64(0)
        var parsed_producer = String("")
        var parsed_opset = Int64(0)
        var parsed_nodes = List[ONNXNodeDescriptor]()
        var saw_ir = False
        var saw_producer = False
        var saw_graph = False
        var saw_default_opset = False
        while cursor.position < size:
            var key = cursor.read_key(size)
            var field = key >> 3
            var wire = key & 7
            if field == 1:
                if wire != 0 or saw_ir:
                    raise Error("ONNX ModelProto.ir_version is malformed or duplicated")
                var encoded = cursor.read_varint(size)
                if encoded == 0 or encoded > UInt64(0x7FFFFFFFFFFFFFFF):
                    raise Error("ONNX IR version is outside the supported integer range")
                parsed_ir = Int64(encoded)
                saw_ir = True
            elif field == 2:
                if wire != 2 or saw_producer:
                    raise Error("ONNX ModelProto.producer_name is malformed or duplicated")
                parsed_producer = cursor.read_string(size)
                saw_producer = True
            elif field == 7:
                if wire != 2 or saw_graph:
                    raise Error("ONNX ModelProto.graph is malformed or duplicated")
                var graph_end = cursor.read_length_end(size)
                self._parse_graph(cursor, graph_end, parsed_nodes)
                saw_graph = True
            elif field == 8:
                if wire != 2:
                    raise Error("ONNX ModelProto.opset_import has the wrong wire type")
                var opset_end = cursor.read_length_end(size)
                var version = self._parse_opset(cursor, opset_end)
                if version > 0:
                    if saw_default_opset:
                        raise Error("ONNX ModelProto has duplicate default-domain opsets")
                    parsed_opset = version
                    saw_default_opset = True
            else:
                cursor.skip_field(wire, size)
        if not saw_ir or not saw_graph or not saw_default_opset:
            raise Error("ONNX ModelProto must contain ir_version, graph, and a default-domain opset")
        self.ir_version = parsed_ir
        self.producer_name = parsed_producer
        self.opset_version = parsed_opset
        self.nodes = parsed_nodes^
        self.num_nodes = len(self.nodes)
        return True

    def add_node(mut self, op_type: String, name: String = "") raises:
        """Adds caller-supplied node metadata after operator validation."""
        validate_onnx_node_op(op_type)
        self.nodes.append(ONNXNodeDescriptor(op_type, name))
        self.num_nodes = len(self.nodes)

    def map_to_well(mut self, mut well: MimirWell) raises -> Bool:
        """Refuses execution until initializer decoding and tensor mapping exist."""
        _ = well
        raise Error("ONNX tensor initializer mapping and execution are not implemented")
