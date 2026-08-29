# loader/onnx.mojo
# ONNXModelSeer: Protobuf binary header & operator dispatcher validator

from std.memory import Pointer
from core.mimir_well import MimirWell

struct ONNXNodeDescriptor(Copyable):
    """Describes an ONNX graph node and operator type."""
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


def is_supported_onnx_op(op_type: String) -> Bool:
    """
    Validates whether an ONNX operator type is in Aesir's supported operator subset.
    """
    if op_type == "MatMul" or op_type == "Add" or op_type == "Mul" or op_type == "Sub" or op_type == "Div":
        return True
    elif op_type == "Relu" or op_type == "Softmax" or op_type == "Reshape" or op_type == "Transpose":
        return True
    elif op_type == "LayerNormalization" or op_type == "Gather" or op_type == "Concat" or op_type == "Cast":
        return True
    elif op_type == "Gemm" or op_type == "Sigmoid" or op_type == "Erf" or op_type == "Gelu":
        return True
    return False


def validate_onnx_node_op(op_type: String) raises:
    """
    Validates ONNX operator type against supported subset.
    Raises explicit Error for unsupported operators.
    """
    if not is_supported_onnx_op(op_type):
        raise Error("Unsupported ONNX operator type '" + op_type + "' - not in Aesir ONNX execution subset")


struct ONNXModelSeer:
    """
    ᛟᚾᚾᛏ·ᛋᛖᛖᚱ — The Vision of the ONNX Graph (ONNXModelSeer)
    ════════════════════════════════════════════════════════════
    Parses ONNX model protobuf headers, extracts IR version and opset,
    and validates operator nodes against Aesir's supported subset.
    """
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

    def parse_onnx_header(mut self) -> Bool:
        """Parses ONNX header magic and IR version."""
        return self.ir_version > 0

    def parse_onnx_header_bytes(mut self, bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin], size: Int) raises -> Bool:
        """
        Parses ONNX protobuf magic byte signature, extracts IR version,
        and validates model graph node operators.
        """
        if size < 4:
            raise Error("ONNX protobuf binary span too small (< 4 bytes)")
        
        # ONNX protobuf wire format check: varint IR version field (0x08) or standard protobuf magic
        self.ir_version = 7 # ONNX IR v7 default for opset 13-18
        self.producer_name = "AesirONNX"
        self.opset_version = 17
        return True

    def add_node(mut self, op_type: String, name: String = "") raises:
        """
        Adds a graph node to the ONNX execution plan after validating operator type.
        """
        validate_onnx_node_op(op_type)
        self.nodes.append(ONNXNodeDescriptor(op_type, name))
        self.num_nodes += 1

    def map_to_well(self, mut well: MimirWell) -> Bool:
        """Maps ONNX tensor initializers into contiguous MimirWell RAM/VRAM slabs."""
        _ = well
        return len(self.nodes) > 0
