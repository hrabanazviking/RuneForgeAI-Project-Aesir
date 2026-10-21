from smidr.window_policy import DecoderWindowPolicy
from smidr.tools.source_inventory import _quote


def parse_window_widths(raw: String) raises -> List[Int]:
    var values = List[Int]()
    for word in raw.split(","):
        values.append(Int(String(word)))
    return values^


def describe_window_policy(p: DecoderWindowPolicy, charged: Int) -> String:
    var text = String("{\"windows\":[")
    for i in range(len(p.windows)):
        if i != 0:
            text += ","
        text += String(p.windows[i])
    return text + "],\"origin\":" + _quote(p.origin) + ",\"provenance\":" + _quote(p.provenance) + ",\"work\":" + String(p.work) + ",\"charged_work\":" + String(charged) + "}"
