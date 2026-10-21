from smidr.bias_policy import DecoderBiasPolicy
from smidr.tools.source_inventory import _quote


def _flags(values: List[Int]) -> String:
    var text = String("[")
    for i in range(len(values)):
        if i != 0:
            text += ","
        text += String(values[i])
    return text + "]"


def describe_bias_policy(policy: DecoderBiasPolicy, charged: Int) -> String:
    return String("{\"attention\":") + _flags(policy.attention) + ",\"mlp\":" + _flags(policy.mlp) + ",\"provenance\":" + _quote(policy.provenance) + ",\"work\":" + String(policy.work) + ",\"charged_work\":" + String(charged) + "}"
