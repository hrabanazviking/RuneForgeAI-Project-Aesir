"""CLI flag adapter; pure value parsing belongs to core sampling policy."""
from core.sampling_options import sampling_uint, sampling_decimal, sampling_decimal_text, with_sampling_option


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
