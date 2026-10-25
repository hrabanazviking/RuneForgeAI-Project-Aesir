# ccw_datum.mojo — Aesir reference encoder for the champion-burst
# CCW datum (AES-NUM-026).
#
# The 24-bit lane-2 datum of a champion-form 24-byte CCW burst is a
# GF(2)-linear image of the 64-bit lane-1 operand word
# (AES-NUM-022/023), under one global map fitted exactly across
# 1,189 distinct operand words from 7 HEF artifacts with zero
# inconsistencies (AES-NUM-025). This module freezes that map as a
# 16-row reduction basis (canonical data: ccw_datum_basis.json,
# sha256 7a1635cb32fbd48e935d7902e532a3f700ef28edfed4bee09d2470a8a92a7e5a).
#
# Honesty contract: an operand word that does not reduce to zero
# under the basis is OUT OF SPAN — the encoder returns None and
# the caller must treat the datum as unknown, never guess it.

def ccw_datum(lane1: UInt64) -> Optional[UInt32]:
    var x = lane1
    var y: UInt32 = 0
    if ((x >> 61) & 1) == 1:
        x ^= 0x2d80025000008000
        y ^= 0x56898c
    if ((x >> 60) & 1) == 1:
        x ^= 0x18f0025020000c00
        y ^= 0x1b0633
    if ((x >> 59) & 1) == 1:
        x ^= 0x0e00000000001c00
        y ^= 0x493bd3
    if ((x >> 58) & 1) == 1:
        x ^= 0x0400000000001000
        y ^= 0x410d20
    if ((x >> 57) & 1) == 1:
        x ^= 0x0200000000003000
        y ^= 0x23a7ec
    if ((x >> 56) & 1) == 1:
        x ^= 0x010e00980000a001
        y ^= 0x22c43d
    if ((x >> 47) & 1) == 1:
        x ^= 0x0000828800000001
        y ^= 0x3b71fa
    if ((x >> 34) & 1) == 1:
        x ^= 0x0000000400000000
        y ^= 0x462fa0
    if ((x >> 29) & 1) == 1:
        x ^= 0x0000000030000000
        y ^= 0x4a4ed8
    if ((x >> 16) & 1) == 1:
        x ^= 0x0000000000017800
        y ^= 0x7d0633
    if ((x >> 15) & 1) == 1:
        x ^= 0x000000000000c000
        y ^= 0x366c9b
    if ((x >> 14) & 1) == 1:
        x ^= 0x0000000000006000
        y ^= 0x4f3bbd
    if ((x >> 13) & 1) == 1:
        x ^= 0x0000000000003000
        y ^= 0x73902e
    if ((x >> 12) & 1) == 1:
        x ^= 0x0000000000001000
        y ^= 0x497945
    if ((x >> 11) & 1) == 1:
        x ^= 0x0000000000000c00
        y ^= 0x48e9fb
    if ((x >> 10) & 1) == 1:
        x ^= 0x0000000000000400
        y ^= 0x3858a9
    if x != 0:
        return None
    return y


def main():
    # Smoke checks (the full 1,189-pair verification harness is
    # generated on-device from the source artifacts; see
    # docs/HAILO10H_ENCODER_FREEZE_2026-10-24.md).
    var zero = ccw_datum(0)
    print("datum(0) present:", zero != None, "value:", zero.or_else(0xffffff))
    # Special skeleton pair (AES-NUM-022): the 0x2d80 ladder word.
    var special = ccw_datum(0x2d80025000008000)
    print("datum(special) present:", special != None, "value:", special.or_else(0xffffff))
