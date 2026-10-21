from smidr.scaling_policy import DecoderScalingPolicy
from smidr.tools.source_inventory import _quote


def describe_scaling_policy(p: DecoderScalingPolicy, charged: Int) -> String:
    return String("{\"kind\":") + _quote(p.kind) + ",\"factor\":{\"width\":" + String(p.factor.width) + ",\"bits\":" + String(p.factor.bits) + "},\"origin\":" + _quote(p.origin) + ",\"provenance\":" + _quote(p.provenance) + ",\"work\":" + String(p.work) + ",\"charged_work\":" + String(charged) + "}"
