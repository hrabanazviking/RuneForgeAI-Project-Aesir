# ccw_ch0_datum.mojo - Aesir reference encoder for the channel-0
# champion-burst CCW datum (AES-NUM-031).
#
# The 24-bit lane-2 datum of a channel-0 champion-form 24-byte
# CCW burst is a GF(2)-linear image of the 64-bit lane-1 operand
# word (AES-NUM-030), under one channel-0 map fitted exactly
# across 1,120 distinct operand words from 7 HEF artifacts with
# zero inconsistencies (AES-NUM-031). This map is DISJOINT from
# the channels-1/2 champion map of ccw_datum.mojo: the operand
# populations share no word, and neither encoder serves the
# other channel group. Canonical data: ccw_ch0_datum_basis.json,
# sha256 cfd5c48878dc378c461376b38786e17c4ad9e2c55cfde39a001d2208a704a7bd.
#
# Honesty contract: an operand word that does not reduce to zero
# under the basis is OUT OF SPAN - the encoder returns None and
# the caller must treat the datum as unknown, never guess it.

def ccw_ch0_datum(lane1: UInt64) -> Optional[UInt32]:
    var x = lane1
    var y: UInt32 = 0
    if ((x >> 61) & 1) == 1:
        x ^= 0x2a00016800000000
        y ^= 0x1d7710
    if ((x >> 60) & 1) == 1:
        x ^= 0x10f0025000000000
        y ^= 0x577acd
    if ((x >> 59) & 1) == 1:
        x ^= 0x0800000000000c00
        y ^= 0x580131
    if ((x >> 58) & 1) == 1:
        x ^= 0x0400000000002000
        y ^= 0x329d0e
    if ((x >> 57) & 1) == 1:
        x ^= 0x0200000000000000
        y ^= 0x5037c2
    if ((x >> 56) & 1) == 1:
        x ^= 0x0100015800000000
        y ^= 0x589de8
    if ((x >> 55) & 1) == 1:
        x ^= 0x0080026000000000
        y ^= 0x089e9e
    if ((x >> 49) & 1) == 1:
        x ^= 0x000201c000000001
        y ^= 0x55c8ae
    if ((x >> 47) & 1) == 1:
        x ^= 0x0000828800000001
        y ^= 0x3b71fa
    if ((x >> 44) & 1) == 1:
        x ^= 0x000012ec00002000
        y ^= 0x7e1b5f
    if ((x >> 43) & 1) == 1:
        x ^= 0x0000094880002000
        y ^= 0x799bbb
    if ((x >> 42) & 1) == 1:
        x ^= 0x000004f000002000
        y ^= 0x340d50
    if ((x >> 39) & 1) == 1:
        x ^= 0x000000d800000000
        y ^= 0x52e15c
    if ((x >> 38) & 1) == 1:
        x ^= 0x0000007400000000
        y ^= 0x45bd4d
    if ((x >> 37) & 1) == 1:
        x ^= 0x0000002080000fff
        y ^= 0x49cfc5
    if ((x >> 36) & 1) == 1:
        x ^= 0x0000001c00000000
        y ^= 0x2ae243
    if ((x >> 35) & 1) == 1:
        x ^= 0x0000000800000000
        y ^= 0x2444a1
    if ((x >> 34) & 1) == 1:
        x ^= 0x0000000400002000
        y ^= 0x7cc6cb
    if ((x >> 30) & 1) == 1:
        x ^= 0x0000000040000400
        y ^= 0x10a337
    if ((x >> 16) & 1) == 1:
        x ^= 0x0000000000015400
        y ^= 0x0f06a3
    if ((x >> 15) & 1) == 1:
        x ^= 0x0000000000008000
        y ^= 0x43be4d
    if ((x >> 14) & 1) == 1:
        x ^= 0x0000000000006000
        y ^= 0x4f3bbd
    if ((x >> 13) & 1) == 1:
        x ^= 0x0000000000003000
        y ^= 0x73902e
    if ((x >> 12) & 1) == 1:
        x ^= 0x0000000000001001
        y ^= 0x661e3e
    if ((x >> 11) & 1) == 1:
        x ^= 0x0000000000000c00
        y ^= 0x48e9fb
    if ((x >> 10) & 1) == 1:
        x ^= 0x0000000000000400
        y ^= 0x3858a9
    if ((x >> 0) & 1) == 1:
        x ^= 0x0000000000000001
        y ^= 0x2f677b
    if x != 0:
        return None
    return y


def main():
    # Smoke checks (the full 1,120-pair verification harness is
    # generated on-device from the source artifacts; see
    # docs/HAILO10H_CHANNEL0_FREEZES_2026-10-24.md).
    var zero = ccw_ch0_datum(0)
    print("datum(0) present:", zero != None, "value:", zero.or_else(0xffffff))
    # Most frequent channel-0 operand (AES-NUM-030):
    # 0x2a00016800000000, 1,504 bursts.
    var top = ccw_ch0_datum(0x2a00016800000000)
    print("datum(top) present:", top != None, "value:", top.or_else(0xffffff))
