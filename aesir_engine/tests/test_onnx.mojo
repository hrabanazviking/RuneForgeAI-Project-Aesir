# tests/test_onnx.mojo
# Verification of ONNX local descriptors and unsupported parser boundary

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from loader.onnx import ONNXModelSeer, is_supported_onnx_op, validate_onnx_node_op

def test_onnx_supported_operators() raises:
    print("--- Testing ONNX Supported Operator Subset ---")
    if not is_supported_onnx_op("MatMul"):
        raise Error("MatMul should be supported in ONNX subset")
    if not is_supported_onnx_op("Add"):
        raise Error("Add should be supported in ONNX subset")
    if not is_supported_onnx_op("Softmax"):
        raise Error("Softmax should be supported in ONNX subset")
    if not is_supported_onnx_op("LayerNormalization"):
        raise Error("LayerNormalization should be supported in ONNX subset")

    # Verify unsupported operator rejection
    if is_supported_onnx_op("CustomUnsupportedOp99"):
        raise Error("CustomUnsupportedOp99 should NOT be supported")

    var rejected = False
    try:
        validate_onnx_node_op("CustomUnsupportedOp99")
    except:
        rejected = True
    if not rejected:
        raise Error("validate_onnx_node_op failed to reject unsupported ONNX op")

    print("ONNX supported operator subset: PASS")


def test_onnx_seer_header_validation() raises:
    print("--- Testing ONNXModelSeer fail-closed parser boundary ---")
    var seer = ONNXModelSeer("models/test.onnx")
    
    var bytes_ptr = alloc(Layout[Scalar[DType.uint8]](count=16)).unsafe_leak()
    bytes_ptr.unsafe_store(0, 0x08) # Protobuf varint IR version tag
    bytes_ptr.unsafe_store(1, 0x07) # IR v7
    bytes_ptr.unsafe_store(2, 0x12)
    bytes_ptr.unsafe_store(3, 0x0A)

    var parser_rejected = False
    try:
        _ = seer.parse_onnx_header_bytes(bytes_ptr, 16)
    except error:
        parser_rejected = True
        if "not implemented" not in String(error):
            raise Error("ONNX parser rejection omitted truth boundary")
    if not parser_rejected:
        raise Error("ONNXModelSeer accepted synthetic fixed metadata")
    if seer.ir_version != 0 or seer.opset_version != 0:
        raise Error("ONNXModelSeer fabricated metadata after rejection")

    seer.add_node("MatMul", "node_0")
    seer.add_node("Add", "node_1")
    seer.add_node("Softmax", "node_2")

    if len(seer.nodes) != 3:
        raise Error("ONNXModelSeer node count mismatch")

    bytes_ptr.unsafe_free()
    print("ONNXModelSeer fail-closed parser boundary: PASS")


def main() raises:
    test_onnx_supported_operators()
    test_onnx_seer_header_validation()
