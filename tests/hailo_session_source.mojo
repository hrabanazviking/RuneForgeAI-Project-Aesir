# Source projection revalidation probe; no numerical model execution.
from std.sys import argv
from smidr.tools.decoder_activation_graph import read_bias_source
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.decoder_session_source import source_decoder_session
from smidr.tools.session_policy import describe_session_policy
from smidr.session_policy import validate_session_policy


def main() raises:
    var a = argv()
    if len(a) != 9:
        raise Error("expected root weight config mode override work provenance case")
    var schema = read_bias_source("unindexed", a[1], a[2], a[3])
    var before = describe_ordinary_projection_schema(schema)
    if a[8] == "source_flag":
        schema.binding.architecture.flags["use_cache"] = not schema.binding.architecture.flags["use_cache"]
    elif a[8] == "source_origin":
        schema.binding.architecture.field_origins["use_cache"] = "changed"
    elif a[8] == "source_layer":
        schema.binding.architecture.layers.layer_count += 1
    elif a[8] == "source_work":
        schema.binding.architecture.work_units += 1
    var policy = source_decoder_session(schema.binding.architecture, a[4], Int(a[5]), a[7], Int(a[6]))
    if describe_ordinary_projection_schema(schema) != before:
        raise Error("source session projection mutated original owner")
    print(String("{\"original_source\":") + before + ",\"session_policy\":" + describe_session_policy(policy, validate_session_policy(policy, schema.binding.architecture.layers.layer_count, schema.binding.architecture.policy.work)) + "}")
