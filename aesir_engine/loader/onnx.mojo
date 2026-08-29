# loader/onnx.mojo
# ONNXModelSeer: local descriptors and unsupported parser boundary

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
    Preserves local ONNX node descriptors and operator allow-list validation.
    Protobuf parsing, tensor decoding, planning, and execution are unsupported.
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
        Rejects synthetic header parsing until a bounded protobuf parser exists.
        """
        _ = bytes
        if size < 4:
            raise Error("ONNX protobuf binary span too small (< 4 bytes)")
        raise Error(
            "ONNX protobuf parsing is not implemented; "
            "fixed metadata is prohibited"
        )

    def add_node(mut self, op_type: String, name: String = "") raises:
        """
        Adds a local operator descriptor after validating its name.
        """
        validate_onnx_node_op(op_type)
        self.nodes.append(ONNXNodeDescriptor(op_type, name))
        self.num_nodes += 1

    def map_to_well(self, mut well: MimirWell) -> Bool:
        """Returns false until ONNX initializers are parsed and mapped."""
        _ = well
        return False
