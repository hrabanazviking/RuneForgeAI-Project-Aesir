"""Strict persisted-text byte admission boundaries."""
from core.text_admission import admit_text_bytes


def _text_bytes(values: List[Int]) -> List[Byte]:
    var result = List[Byte]()
    for value in values:
        result.append(Byte(value))
    return result^


def test_persisted_text_admission() raises:
    var valid = _text_bytes([
        65, 194, 128, 224, 160, 128, 237, 159, 191,
        240, 144, 128, 128, 244, 143, 191, 191,
    ])
    var accepted = admit_text_bytes(valid, "fixture", 64)
    if accepted.byte_length() != 17:
        raise Error("Valid UTF-8 boundary sequence changed during admission")

    var invalid = List[List[Int]]()
    invalid.append([65, 0, 66])
    invalid.append([128])
    invalid.append([192, 128])
    invalid.append([194])
    invalid.append([224, 159, 128])
    invalid.append([237, 160, 128])
    invalid.append([240, 143, 128, 128])
    invalid.append([244, 144, 128, 128])
    invalid.append([245, 128, 128, 128])
    invalid.append([226, 130])
    for index in range(len(invalid)):
        var rejected = False
        try:
            _ = admit_text_bytes(_text_bytes(invalid[index]), "fixture", 64)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed persisted UTF-8 case was accepted: " + String(index))

    var size_rejected = False
    try:
        _ = admit_text_bytes(_text_bytes([65, 66]), "fixture", 1)
    except:
        size_rejected = True
    if not size_rejected:
        raise Error("Persisted text exceeded its byte limit")
