"""Hardware-independent sampling validation; no inference capability claims."""
from std.memory import bitcast
from core.sampling_config import NativeSamplingConfig
from cli.sampling import sampling_decimal, sampling_decimal_text, sampling_uint, with_sampling_option


def test_sampling_syntax() raises:
    if sampling_decimal(".75") != Float32(0.75) or sampling_decimal("0") != 0:
        raise Error("Valid decimal rejected")
    if sampling_uint("18446744073709551615") != UInt64(18446744073709551615):
        raise Error("Maximum UInt64 seed corrupted")
    var cases: List[String] = ["", ".", "1.2.3", "NaN", "inf", "1e2", "-1", " 1", "1 ", "2junk"]
    for value in cases:
        var rejected = False
        try:
            _ = sampling_decimal(value)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed sampling decimal accepted: " + value)
    var integers: List[String] = ["", "-1", "+1", "0.5", "18446744073709551616", "99999999999999999999"]
    for value in integers:
        var rejected = False
        try:
            _ = sampling_uint(value)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed sampling integer accepted")


def test_sampling_config_rejection() raises:
    NativeSamplingConfig().validate()
    NativeSamplingConfig(0.8, 256, 1, 1, 0.5, 8192, 0).validate()
    for choice in range(11):
        var config = NativeSamplingConfig()
        if choice == 0:
            config.temperature = -1
        elif choice == 1:
            config.temperature = bitcast[DType.float32](UInt32(0x7fc00000))
        elif choice == 2:
            config.top_k = 0
        elif choice == 3:
            config.top_k = 257
        elif choice == 4:
            config.top_p = 0
        elif choice == 5:
            config.top_p = 1.01
        elif choice == 6:
            config.min_p = -0.1
        elif choice == 7:
            config.min_p = 1.01
        elif choice == 8:
            config.repetition_penalty = bitcast[DType.float32](UInt32(0x7f800000))
        elif choice == 9:
            config.repeat_last_n = 0
        else:
            config.repeat_last_n = 8193
        var rejected = False
        try:
            config.validate()
        except:
            rejected = True
        if not rejected:
            raise Error("Unsafe sampling configuration accepted")


def test_sampling_config_updates() raises:
    var bit_patterns: List[UInt32] = [
        0, 0x80000000, 1, 2, 0x00000100, 0x007fffff, 0x00800000,
        0x00800001, 0x3f000000, 0x3f800000, 0x3f800001, 0x41200000,
        0x4b000001, 0x7f000000, 0x7f7fffff,
    ]
    for exponent in range(1, 255):
        bit_patterns.append(UInt32(exponent << 23))
        bit_patterns.append(UInt32((exponent << 23) | 1))
        bit_patterns.append(UInt32((exponent << 23) | 0x003fffff))
        bit_patterns.append(UInt32((exponent << 23) | 0x007fffff))
    for bits in bit_patterns:
        var value = bitcast[DType.float32](bits)
        var text = sampling_decimal_text(value)
        if text.byte_length() == 0 or text.byte_length() > 64 or "e" in text or "E" in text or "+" in text or "-" in text:
            raise Error("Sampling handoff text escaped the public decimal grammar")
        var parsed = sampling_decimal(text)
        if value == 0:
            if text != "0":
                raise Error("Sampling handoff did not canonicalize signed zero")
        elif parsed != value:
            raise Error("Sampling handoff changed a finite Float32 value")
    var invalid_values: List[Float32] = [
        -1, bitcast[DType.float32](UInt32(0x7f800000)),
        bitcast[DType.float32](UInt32(0x7fc00000)),
    ]
    for value in invalid_values:
        var rejected = False
        try:
            _ = sampling_decimal_text(value)
        except:
            rejected = True
        if not rejected:
            raise Error("Sampling handoff accepted negative or nonfinite input")
    var original = NativeSamplingConfig()
    var changed = with_sampling_option(original, "temperature", "0.8")
    changed = with_sampling_option(changed, "seed", "0")
    if not original.plain_greedy() or changed.plain_greedy() or changed.seed != 0:
        raise Error("Sampling update corrupted its source or ignored seed zero")
    var rejected = False
    try:
        _ = with_sampling_option(changed, "unknown", "1")
    except:
        rejected = True
    if not rejected:
        raise Error("Unknown sampling update accepted")


def main() raises:
    test_sampling_syntax()
    test_sampling_config_rejection()
    test_sampling_config_updates()
    print("PASS native sampling syntax, validation and round trips")
