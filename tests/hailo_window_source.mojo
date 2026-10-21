# Source projection revalidation probe; no numerical model execution.
from std.sys import argv
from smidr.tools.decoder_activation_graph import read_bias_source
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.decoder_window_source import source_decoder_windows
from smidr.tools.window_policy import describe_window_policy
from smidr.window_policy import validate_window_policy


def main() raises:
    var a = argv()
    if len(a) != 7:
        raise Error("expected root weight config work provenance case")
    var schema = read_bias_source("unindexed", a[1], a[2], a[3])
    var before = describe_ordinary_projection_schema(schema)
    if a[6] == "source_flag":
        schema.binding.architecture.flags["use_cache"] = not schema.binding.architecture.flags["use_cache"]
    elif a[6] == "source_origin":
        schema.binding.architecture.field_origins["use_cache"] = "changed"
    elif a[6] == "source_layer":
        schema.binding.architecture.layers.layer_count += 1
    elif a[6] == "source_work":
        schema.binding.architecture.work_units += 1
    if a[6] == "source_window":
        schema.binding.architecture.layers.window_fields["sliding_window"] = "2"
    elif a[6] == "source_types":
        schema.binding.architecture.layers.layer_types[0] = "sliding_attention"
    elif a[6] == "source_rope":
        schema.binding.architecture.layers.rope_enabled[0] = 0
    var policy = source_decoder_windows(schema.binding.architecture, a[5], Int(a[4]))
    if describe_ordinary_projection_schema(schema) != before:
        raise Error("source window projection mutated original owner")
    print(String("{\"original_source\":") + before + ",\"window_policy\":" + describe_window_policy(policy, validate_window_policy(policy, schema.binding.architecture.layers.layer_count, schema.binding.architecture.policy.work)) + "}")
