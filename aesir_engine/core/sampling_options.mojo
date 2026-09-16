"""Pure native sampling value grammar shared by CLI, sessions and protocols."""
from std.math import isfinite
from std.memory import bitcast
from core.sampling_config import NativeSamplingConfig


def sampling_uint(text: String) raises -> UInt64:
    if text.byte_length() == 0 or text.byte_length() > 20:
        raise Error("Sampling integer must be unsigned decimal within UInt64")
    var result = UInt64(0)
    for byte in text.as_bytes():
        if byte < 48 or byte > 57:
            raise Error("Sampling integer must contain only decimal digits")
        var digit = UInt64(byte - 48)
        if result > (UInt64(18446744073709551615) - digit) // 10:
            raise Error("Sampling integer overflow")
        result = result * 10 + digit
    return result


def sampling_decimal(text: String) raises -> Float32:
    # Deliberately small grammar: digits and at most one decimal point. No
    # partial parses, whitespace, signs, exponent syntax, NaN or infinity.
    if text.byte_length() == 0 or text.byte_length() > 64:
        raise Error("Sampling decimal must contain 1..64 characters")
    var value: Float64 = 0
    var divisor: Float64 = 1
    var fraction = False
    var digits = 0
    for byte in text.as_bytes():
        if byte == 46 and not fraction:
            fraction = True
        elif byte >= 48 and byte <= 57:
            value = value * 10 + Float64(byte - 48)
            if fraction:
                divisor *= 10
            digits += 1
        else:
            raise Error("Sampling value must be an unsigned decimal (for example 0.8)")
    var result = Float32(value / divisor)
    if digits == 0 or not isfinite(result):
        raise Error("Sampling value must be a finite decimal")
    return result


def _sampling_exponent(text: String) raises -> Int:
    if text.byte_length() == 0:
        raise Error("Sampling exponent is empty")
    var negative = False
    var index = 0
    var source = text.as_bytes()
    if source[0] == 43 or source[0] == 45:
        negative = source[0] == 45
        index = 1
    if index == len(source):
        raise Error("Sampling exponent has no digits")
    var result = 0
    while index < len(source):
        var byte = source[index]
        if byte < 48 or byte > 57 or result > 999:
            raise Error("Sampling exponent is malformed or excessive")
        result = result * 10 + Int(byte - 48)
        index += 1
    return -result if negative else result


def sampling_decimal_text(value: Float32) raises -> String:
    """Returns exact Float32 text accepted by the strict public CLI grammar."""
    if not isfinite(value) or value < 0:
        raise Error("Sampling handoff value must be finite and nonnegative")
    if value == 0:
        return "0"
    var raw = String(value)
    var exponent_at = -1
    var decimal_at = -1
    var source = raw.as_bytes()
    for index in range(len(source)):
        if source[index] == 46:
            if decimal_at >= 0:
                raise Error("Sampling formatter produced multiple decimal points")
            decimal_at = index
        elif source[index] == 101 or source[index] == 69:
            exponent_at = index
            break
        elif source[index] < 48 or source[index] > 57:
            raise Error("Sampling formatter produced unsupported text")
    if exponent_at < 0:
        if bitcast[DType.uint32](sampling_decimal(raw)) != bitcast[DType.uint32](value):
            raise Error("Sampling decimal handoff did not round-trip")
        return raw

    var exponent = _sampling_exponent(String(raw[byte=exponent_at + 1:]))
    var digits = String("")
    var digits_before = 0
    for index in range(exponent_at):
        if source[index] == 46:
            digits_before = digits.byte_length()
        else:
            digits += String(raw[byte=index : index + 1])
    if decimal_at < 0:
        digits_before = digits.byte_length()
    var position = digits_before + exponent
    var output: String
    if position <= 0:
        output = "0."
        for _ in range(-position):
            output += "0"
        output += digits
    elif position >= digits.byte_length():
        output = digits
        for _ in range(position - digits.byte_length()):
            output += "0"
    else:
        output = String(digits[byte=0:position]) + "." + String(digits[byte=position:])
    if output.byte_length() > 64:
        raise Error("Sampling decimal handoff exceeds the CLI grammar bound")
    if bitcast[DType.uint32](sampling_decimal(output)) != bitcast[DType.uint32](value):
        raise Error("Sampling decimal handoff did not round-trip")
    return output


def with_sampling_option(config: NativeSamplingConfig, name: String, value: String) raises -> NativeSamplingConfig:
    var result = config
    if name == "temperature":
        result.temperature = sampling_decimal(value)
    elif name == "top-p":
        result.top_p = sampling_decimal(value)
    elif name == "min-p":
        result.min_p = sampling_decimal(value)
    elif name == "repeat-penalty":
        result.repetition_penalty = sampling_decimal(value)
    elif name == "seed":
        result.seed = sampling_uint(value)
    elif name == "top-k" or name == "repeat-last-n":
        var number = sampling_uint(value)
        if number > 8192:
            raise Error("Sampling count exceeds 8192")
        if name == "top-k":
            result.top_k = Int(number)
        else:
            result.repeat_last_n = Int(number)
    else:
        raise Error("Unknown sampling setting: " + name)
    result.validate()
    return result
