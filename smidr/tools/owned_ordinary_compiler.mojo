# Diagnostic retained mathematical compiler inspector, never a conversion workflow.
from std.sys import argv
from smidr.owned_ordinary_compiler import *
from smidr.tools.owned_ordinary_binding import _binding_policy, _root_policy, _copy_policy
from smidr.tools.sealed_source_collection import describe_indexed, describe_unindexed
from smidr.tools.ordinary_projection_schema import describe_ordinary_projection_schema
from smidr.tools.rotary_recipes import describe_rotary_graph
from smidr.rotary_policy import RotaryLoweringPolicy


def _request(args: List[String], base: Int) raises -> OrdinaryCompilationRequest:
    return OrdinaryCompilationRequest(Int(args[base]), Int(args[base+1]), Int(args[base+2]),
        Int(args[base+3]), args[base+4], Int(args[base+5]), Int(args[base+6]),
        Int(args[base+7]), args[base+8], RotaryLoweringPolicy(args[base+9], args[base+10],
        Int(args[base+11]), Int(args[base+12])))


def _report(collection: String, schema: String, lowered: String) -> String:
    return String("{\"schema_version\":1,\"scope\":\"owned_observed_ordinary_mathematical_graph\",\"collection\":") + collection + ",\"schema\":" + schema + ",\"lowered\":" + lowered + ",\"complete_architecture_verified\":false,\"compiled_artifact_identity_verified\":false,\"device_format_verified\":false,\"device_fit_verified\":false,\"device_placement_verified\":false,\"execution_tested\":false,\"device_access\":false}"


def main() raises:
    var args = List[String]()
    for arg in argv():
        args.append(String(arg))
    if len(args) == 59 and args[1] == "indexed":
        var policy = _binding_policy(args, 2, True)
        var request = _request(args, 46)
        var context = load_owned_indexed_ordinary_compiler(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 29), policy, request)
        var text = _report(describe_indexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
        context.close()
        print(text)
    elif len(args) == 54 and args[1] == "unindexed":
        var policy = _binding_policy(args, 2, False)
        var request = _request(args, 41)
        var context = load_owned_unindexed_ordinary_compiler(args[2], args[3], args[4], _root_policy(args, 2), _copy_policy(args, 24), policy, request)
        var text = _report(describe_unindexed(context.binding.owner), describe_ordinary_projection_schema(context.binding.schema), describe_rotary_graph(context.graph, request.rotary))
        context.close()
        print(text)
    else:
        raise Error("expected indexed|unindexed binding arguments then query past capacity rope_dim session_mode return_override source_work scalar_work provenance pairing rotary_provenance max_recipes rotary_work")
