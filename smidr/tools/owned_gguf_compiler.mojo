# Observed compiler input and structural lowering; no numerical execution.
from std.sys import argv
from smidr.owned_gguf_compiler import load_owned_gguf_compiler
from smidr.tools.semantic_plan import describe_semantic_plan
from smidr.tools.primitive_recipes import describe_primitive_recipes
from smidr.tools.expanded_graph import describe_expanded_graph


def main() raises:
    var args = argv()
    if len(args) != 9:
        raise Error("usage: owned_gguf_compiler path byte_bound read_calls write_calls digest_calls query past capacity")
    var context = load_owned_gguf_compiler(args[1], Int(args[2]), Int(args[3]),
        Int(args[4]), Int(args[5]), Int(args[6]), Int(args[7]), Int(args[8]))
    var text = String("{\"schema_version\":1,\"scope\":\"owned_gguf_compiler_input\",\"compiler_input_bytes_bound\":true,\"atomic_original_snapshot_verified\":false,\"source_fingerprint_verified\":false,\"immutable_source_verified\":false,\"binding_identity_verified\":false,\"compiled_artifact_identity_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false,\"source_bytes\":") + String(context.owner.source_bytes)
    text += ",\"digest_hex\":\"" + context.owner.digest_hex + "\",\"semantic\":" + describe_semantic_plan(context.graph.source)
    text += ",\"recipes\":" + describe_primitive_recipes(context.graph.recipes, context.graph.source)
    text += ",\"expanded\":" + describe_expanded_graph(context.graph) + "}"
    context.close()
    print(text)
