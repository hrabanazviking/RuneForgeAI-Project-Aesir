from smidr.session_policy import DecoderSessionPolicy
from smidr.tools.source_inventory import _quote


def describe_session_policy(p: DecoderSessionPolicy, charged: Int) -> String:
    return String("{\"mode\":") + _quote(p.mode) + ",\"return_cache\":" + String(p.return_cache) + ",\"source_return_cache\":" + String(p.source_return_cache) + ",\"return_origin\":" + _quote(p.return_origin) + ",\"provenance\":" + _quote(p.provenance) + ",\"work\":" + String(p.work) + ",\"charged_work\":" + String(charged) + "}"


def describe_cache_exports(values: List[Int]) -> String:
    var text = String("[")
    for i in range(len(values)):
        if i != 0:
            text += ","
        text += String(values[i])
    return text + "]"
