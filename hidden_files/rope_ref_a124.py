# rope_ref_a124.py -- A-124 independent reference computation.
#
# The comparator for core/rope_scaling_battery_a124.mojo: a
# float64 Python (numpy) implementation of the published
# RoPE scaling formulas (NONE / LINEAR / NTK-aware / YaRN
# NTK-by-parts + attention factor 1 + 0.1*ln(factor)),
# sharing no code with the Mojo module under judgement.
# Its outputs at the filed sample dims are transcribed
# value-for-value into the module's filed records
# (filed_freqs_x1e12 / filed_attn_x10000 /
# filed_angle63_micro). Run on purpleraider:
#   python3 hidden_files/rope_ref_a124.py
import math

import numpy as np

D = 128
SAMPLE = [0, 1, 2, 4, 8, 16, 32, 48, 63]


def ladder(theta, mode, factor, orig, low, high):
    i = np.arange(0, D // 2, dtype=np.float64)
    inv = theta ** (-2.0 * i / D)
    if mode == "none":
        return inv, 1.0
    if mode == "linear":
        return inv / factor, 1.0
    if mode == "ntk":
        base = theta * (factor ** (D / (D - 2)))
        return base ** (-2.0 * i / D), 1.0
    # yarn: NTK-by-parts over wavelengths
    wl = 2 * math.pi / inv
    low_wl = orig / low
    high_wl = orig / high
    scaled = np.where(wl > low_wl, inv / factor, inv)
    smooth = np.clip((orig / wl - low) / (high - low), 0.0, 1.0)
    sm = (1 - smooth) * inv / factor + smooth * inv
    out = np.where((wl <= low_wl) & (wl >= high_wl), sm, scaled)
    return out, 0.1 * math.log(factor) + 1.0


CFGS = [
    ("none", 10000.0, "none", 1.0, 4096, 1.0, 4.0),
    ("linear", 10000.0, "linear", 32.0, 4096, 1.0, 4.0),
    ("ntk", 10000.0, "ntk", 32.0, 4096, 1.0, 4.0),
    ("yarn", 500000.0, "yarn", 32.0, 8192, 1.0, 4.0),
]

for name, theta, mode, factor, orig, low, high in CFGS:
    out, att = ladder(theta, mode, factor, orig, low, high)
    print(name, "att_x10000=", round(att * 10000))
    for i in SAMPLE:
        print(
            f"  i={i} scaled_x1e12={round(out[i] * 1e12)}"
            f" angle65536_micro={round(65536 * out[i] * 1e6)}"
        )
