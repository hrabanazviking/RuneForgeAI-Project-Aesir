# tests/test_onnx.mojo
# Verification of ONNX protobuf binary header & operator dispatcher validator

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.ffi import external_call
from loader.onnx import ONNXModelSeer, is_recognized_onnx_op, validate_onnx_node_op

def test_onnx_recognized_operators() raises:
    print("--- Testing ONNX recognized metadata operator subset ---")
    if not is_recognized_onnx_op("MatMul"):
        raise Error("MatMul should be recognized in ONNX metadata subset")
    if not is_recognized_onnx_op("Add"):
        raise Error("Add should be recognized in ONNX metadata subset")
    if not is_recognized_onnx_op("Softmax"):
        raise Error("Softmax should be recognized in ONNX metadata subset")
    if not is_recognized_onnx_op("LayerNormalization"):
        raise Error("LayerNormalization should be recognized in ONNX metadata subset")

    # Verify unsupported operator rejection
    if is_recognized_onnx_op("CustomUnsupportedOp99"):
        raise Error("CustomUnsupportedOp99 should NOT be supported")

    var rejected = False
    try:
        validate_onnx_node_op("CustomUnsupportedOp99")
    except:
        rejected = True
    if not rejected:
        raise Error("validate_onnx_node_op failed to reject unsupported ONNX op")

    print("ONNX recognized metadata operator subset: PASS")


def _fixture_bytes(values: List[UInt8]) -> Pointer[Scalar[DType.uint8], MutUntrackedOrigin]:
    var output = alloc(Layout[Scalar[DType.uint8]](count=len(values))).unsafe_leak()
    for index in range(len(values)):
        output.unsafe_store(index, values[index])
    return output


def _write_fixture_file(values: List[UInt8]) raises -> String:
    var template = List[Int8]()
    for byte in String("/tmp/aesir-onnx-XXXXXX").as_bytes():
        template.append(Int8(byte))
    template.append(0)
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("failed to create ONNX test fixture")
    var offset = 0
    while offset < len(values):
        var wrote = external_call["write", Int](
            Int(fd), values.unsafe_ptr().unsafe_offset(offset), len(values) - offset
        )
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to write ONNX test fixture")
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close ONNX test fixture")
    return String(unsafe_from_utf8_ptr=template.unsafe_ptr())


def test_onnx_seer_header_validation() raises:
    print("--- Testing bounded ONNX ModelProto metadata parser ---")
    var seer = ONNXModelSeer("models/test.onnx")

    # ModelProto: ir_version=9, producer_name="fixture", one MatMul node,
    # and default-domain opset 17. This is protobuf wire data, not a magic-byte
    # surrogate.
    var model: List[UInt8] = [
        0x08, 0x09,
        0x12, 0x07, 0x66, 0x69, 0x78, 0x74, 0x75, 0x72, 0x65,
        0x3A, 0x1A,
          0x0A, 0x18,
            0x0A, 0x01, 0x78,
            0x0A, 0x01, 0x77,
            0x12, 0x01, 0x79,
            0x1A, 0x05, 0x64, 0x65, 0x6E, 0x73, 0x65,
            0x22, 0x06, 0x4D, 0x61, 0x74, 0x4D, 0x75, 0x6C,
        0x42, 0x02, 0x10, 0x11,
    ]
    var bytes_ptr = _fixture_bytes(model)
    var ok = seer.parse_onnx_header_bytes(bytes_ptr, len(model))
    if not ok:
        raise Error("ONNXModelSeer failed to parse valid ModelProto metadata")
    if seer.ir_version != 9:
        raise Error("ONNXModelSeer IR version mismatch")
    if seer.producer_name != "fixture" or seer.opset_version != 17:
        raise Error("ONNXModelSeer producer/opset metadata mismatch")
    if seer.num_nodes != 1 or len(seer.nodes) != 1:
        raise Error("ONNXModelSeer parsed node count mismatch")
    if seer.nodes[0].op_type != "MatMul" or seer.nodes[0].name != "dense":
        raise Error("ONNXModelSeer parsed node identity mismatch")
    if seer.nodes[0].input_count != 2 or seer.nodes[0].output_count != 1:
        raise Error("ONNXModelSeer parsed node arity mismatch")
    bytes_ptr.unsafe_free()

    var fixture_path = _write_fixture_file(model)
    var file_seer = ONNXModelSeer(fixture_path)
    try:
        if not file_seer.parse_onnx_header():
            raise Error("ONNXModelSeer file parser returned false")
    except error:
        var failed_path = List[Int8]()
        for byte in fixture_path.as_bytes():
            failed_path.append(Int8(byte))
        failed_path.append(0)
        _ = external_call["unlink", Int32](failed_path.unsafe_ptr())
        raise error
    var path = List[Int8]()
    for byte in fixture_path.as_bytes():
        path.append(Int8(byte))
    path.append(0)
    _ = external_call["unlink", Int32](path.unsafe_ptr())
    if file_seer.ir_version != 9 or file_seer.num_nodes != 1:
        raise Error("ONNXModelSeer file parser metadata mismatch")

    # A failed parse must leave previously committed metadata untouched.
    var truncated: List[UInt8] = [0x08, 0x09, 0x12, 0x05, 0x61]
    var truncated_ptr = _fixture_bytes(truncated)
    var rejected = False
    try:
        _ = seer.parse_onnx_header_bytes(truncated_ptr, len(truncated))
    except:
        rejected = True
    truncated_ptr.unsafe_free()
    if not rejected:
        raise Error("ONNXModelSeer accepted a truncated length-delimited field")
    if seer.ir_version != 9 or seer.num_nodes != 1:
        raise Error("failed ONNX parse mutated committed model metadata")

    var sentinel = Pointer[Scalar[DType.uint8], MutUntrackedOrigin](unsafe_from_address=1)
    rejected = False
    try:
        _ = seer.parse_onnx_header_bytes(sentinel, 8)
    except:
        rejected = True
    if not rejected:
        raise Error("ONNXModelSeer accepted a sentinel byte pointer")

    var unsupported: List[UInt8] = [
        0x08, 0x09,
        0x3A, 0x09, 0x0A, 0x07, 0x22, 0x05,
        0x42, 0x6F, 0x67, 0x75, 0x73,
        0x42, 0x02, 0x10, 0x11,
    ]
    var unsupported_ptr = _fixture_bytes(unsupported)
    rejected = False
    try:
        _ = seer.parse_onnx_header_bytes(unsupported_ptr, len(unsupported))
    except error:
        rejected = "Unsupported ONNX operator" in String(error)
    unsupported_ptr.unsafe_free()
    if not rejected:
        raise Error("ONNXModelSeer accepted an operator outside its declared subset")
    print("bounded ONNX ModelProto metadata parser: PASS")


def main() raises:
    test_onnx_recognized_operators()
    test_onnx_seer_header_validation()
