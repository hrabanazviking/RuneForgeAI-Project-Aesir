"""Strict native chat sampling syntax, shared by flags and interactive settings."""
from std.math import isfinite
from aesir import NativeSamplingConfig


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


def sampling_option_name(flag: String) -> String:
    if flag == "--temperature":
        return "temperature"
    if flag == "--top-k":
        return "top-k"
    if flag == "--top-p":
        return "top-p"
    if flag == "--min-p":
        return "min-p"
    if flag == "--repeat-penalty":
        return "repeat-penalty"
    if flag == "--repeat-last-n":
        return "repeat-last-n"
    if flag == "--seed":
        return "seed"
    return ""
