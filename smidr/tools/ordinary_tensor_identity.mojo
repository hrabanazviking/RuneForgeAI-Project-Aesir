# Scoped compiler source-byte comparison inspector. No model execution.
from std.sys import argv
from smidr.ordinary_tensor_identity import OrdinaryTensorComparison, compare_owned_indexed_tensors, compare_owned_unindexed_tensors
from smidr.owned_ordinary_binding import load_owned_indexed_ordinary, load_owned_unindexed_ordinary
from smidr.source_storage import SourceStorageTensor
from smidr.tools.owned_ordinary_binding import _binding_policy, _root_policy, _copy_policy
from smidr.tools.source_inventory import _quote
from smidr.tools.semantic_plan import _integers


def _tensor(t: SourceStorageTensor) -> String:
    return String("{\"source_format\":") + _quote(t.source_format) + ",\"source_kind\":" + String(t.source_kind) + ",\"original_name\":" + _quote(t.original_name) + ",\"source_path\":" + _quote(t.source_path) + ",\"source_shape\":" + _integers(t.source_shape) + ",\"axis_order\":" + _quote(t.axis_order) + ",\"elements\":" + String(t.elements) + ",\"file_offset\":" + String(t.file_offset) + ",\"byte_count\":" + String(t.byte_count) + "}"


def describe_comparison(result: OrdinaryTensorComparison) -> String:
    return String("{\"schema_version\":1,\"scope\":\"retained_complete_raw_representation_comparison\",\"left_name\":") + _quote(result.left_name) + ",\"right_name\":" + _quote(result.right_name) + ",\"left\":" + _tensor(result.left) + ",\"right\":" + _tensor(result.right) + ",\"elements_per_operand\":" + String(result.elements_per_operand) + ",\"bytes_per_operand\":" + String(result.bytes_per_operand) + ",\"raw_elements_read\":" + String(result.raw_elements_read) + ",\"chunks\":" + String(result.chunks) + ",\"differing_elements\":" + String(result.differing_elements) + ",\"first_differing_element\":" + String(result.first_differing_element) + ",\"all_elements_equal\":" + ("true" if result.all_elements_equal else "false") + ",\"graph_alias_resolved\":false,\"compiled_artifact_identity_verified\":false,\"execution_tested\":false,\"device_access\":false}"


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) != 50 and len(args) != 45:
        raise Error("usage: ordinary_tensor_identity indexed|unindexed binding arguments then left right total-elements chunk-elements")
    var indexed = args[1] == "indexed"
    if (indexed and len(args) != 50) or (not indexed and (args[1] != "unindexed" or len(args) != 45)):
        raise Error("OrdinaryTensorIdentity: invalid inspector mode/arguments")
    var policy = _binding_policy(args, 2, indexed)
    var offset = 46 if indexed else 41
    if indexed:
        var context = load_owned_indexed_ordinary(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 29), policy)
        var result = compare_owned_indexed_tensors(context, args[offset], args[offset+1], Int(args[offset+2]), Int(args[offset+3]), policy)
        context.close()
        print(describe_comparison(result))
    else:
        var context = load_owned_unindexed_ordinary(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 24), policy)
        var result = compare_owned_unindexed_tensors(context, args[offset], args[offset+1], Int(args[offset+2]), Int(args[offset+3]), policy)
        context.close()
        print(describe_comparison(result))
