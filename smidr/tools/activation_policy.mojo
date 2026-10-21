from smidr.activation_policy import DecoderActivationPolicy
from smidr.tools.source_inventory import _quote


def describe_activation_policy(policy: DecoderActivationPolicy, charged: Int) -> String:
    var text = String("{\"kinds\":[")
    for i in range(len(policy.kinds)):
        if i != 0:
            text += ","
        text += _quote(policy.kinds[i])
    return text + "],\"provenance\":" + _quote(policy.provenance) + ",\"work\":" + String(policy.work) + ",\"charged_work\":" + String(charged) + "}"
