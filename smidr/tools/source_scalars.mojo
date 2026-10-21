# Exact source representation JSON; no numeric rendering/conversion required.
from smidr.source_scalars import ScalarWord, DecoderScalars
from smidr.tools.source_inventory import _quote


def describe_scalar_word(value: ScalarWord) -> String:
    if value.width == 0:
        return String("null")
    return String("{\"width\":") + String(value.width) + ",\"bits\":" + String(value.bits) + "}"


def describe_decoder_scalars(values: DecoderScalars) raises -> String:
    return String("{\"epsilon\":") + describe_scalar_word(values.epsilon) + ",\"rope_base\":" + describe_scalar_word(values.rope_base) + ",\"provenance\":" + _quote(values.provenance) + ",\"work_limit\":" + String(values.work_limit) + ",\"charged_work\":" + String(2 + values.provenance.byte_length()) + "}"
