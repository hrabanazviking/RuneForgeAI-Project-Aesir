# Original structural source sharing intent. Byte authority stays with owners.
from std.collections import Dict
from smidr.source_inventory import SourceTensorInventory, validate_source_inventory
from smidr.source_storage import source_storage_bytes


@fieldwise_init
struct SourceWeightAlias(Copyable, Movable):
    var alias_name: String
    var target_name: String
    var source_origin: String


@fieldwise_init
struct SourceWeightSharingPolicy(Copyable, Movable):
    var aliases: List[SourceWeightAlias]
    var provenance: String
    var work: Int


def empty_source_weight_sharing() -> SourceWeightSharingPolicy:
    return SourceWeightSharingPolicy(List[SourceWeightAlias](), "", 0)


def _same_sharing_policy(a: SourceWeightSharingPolicy, b: SourceWeightSharingPolicy) raises:
    if len(a.aliases) != len(b.aliases) or len(a.aliases) > 1 or a.provenance != b.provenance or a.work != b.work:
        raise Error("SourceWeightSharing: retained sharing policy differs")
    for i in range(len(a.aliases)):
        if a.aliases[i].alias_name != b.aliases[i].alias_name or a.aliases[i].target_name != b.aliases[i].target_name or a.aliases[i].source_origin != b.aliases[i].source_origin:
            raise Error("SourceWeightSharing: retained source relation differs")


def _charge(used: Int, amount: Int, bound: Int) raises -> Int:
    if used < 0 or amount < 0 or used > bound or amount > bound - used:
        raise Error("SourceWeightSharing: explicit work bound exceeded")
    return used + amount


def validate_source_weight_sharing(source: SourceTensorInventory,
        policy: SourceWeightSharingPolicy) raises -> Int:
    if len(policy.aliases) == 0:
        if policy.provenance.byte_length() != 0 or policy.work != 0:
            raise Error("SourceWeightSharing: stray empty sharing state")
        return 0
    if len(policy.aliases) != 1 or policy.work <= 0 or policy.work > source.policy.work or policy.provenance.byte_length() == 0:
        raise Error("SourceWeightSharing: one bounded explicit relation required")
    var charge = _charge(0, 64, policy.work)
    charge = _charge(charge, policy.provenance.byte_length(), policy.work)
    ref alias = policy.aliases[0]
    charge = _charge(charge, alias.alias_name.byte_length(), policy.work)
    charge = _charge(charge, alias.target_name.byte_length(), policy.work)
    charge = _charge(charge, alias.source_origin.byte_length(), policy.work)
    if alias.alias_name != "output.weight" or alias.target_name != "token_embd.weight" or alias.source_origin.byte_length() == 0:
        raise Error("SourceWeightSharing: source relation semantics unresolved")
    validate_source_inventory(source)
    if alias.alias_name not in source.storage or alias.target_name not in source.storage:
        raise Error("SourceWeightSharing: retained source relation endpoint missing")
    ref a = source.storage[alias.alias_name]
    ref b = source.storage[alias.target_name]
    charge = _charge(charge, len(a.source_shape), policy.work)
    if a.source_format != "safetensors" or b.source_format != a.source_format or a.source_kind != b.source_kind or a.axis_order != b.axis_order or len(a.source_shape) != 2 or a.source_shape != b.source_shape or a.elements != b.elements or a.byte_count != b.byte_count or source_storage_bytes(a) != a.byte_count or source_storage_bytes(b) != b.byte_count:
        raise Error("SourceWeightSharing: incompatible stored source representations")
    return charge


def validate_shared_source_coverage(source: SourceTensorInventory,
        actual: Dict[String, Bool], policy: SourceWeightSharingPolicy) raises:
    _ = validate_source_weight_sharing(source, policy)
    if len(actual) + len(policy.aliases) != len(source.bindings):
        raise Error("SourceWeightSharing: incomplete source use and relation coverage")
    for name in actual:
        if name not in source.bindings or not actual[name]:
            raise Error("SourceWeightSharing: invalid actual operation source use")
    for alias in policy.aliases:
        if alias.alias_name in actual or alias.target_name not in actual or not actual[alias.target_name]:
            raise Error("SourceWeightSharing: relation lacks a distinct actual used target")
    for name in source.bindings:
        if name not in actual and (len(policy.aliases) != 1 or name != policy.aliases[0].alias_name):
            raise Error("SourceWeightSharing: unaccounted retained source binding")
