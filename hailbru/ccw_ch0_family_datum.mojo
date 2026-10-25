# ccw_ch0_family_datum.mojo - Aesir reference encoders for the
# six largest non-champion lane-0 burst families ON CHANNEL 0
# (AES-NUM-031).
#
# Each family's 24-bit lane-2 datum is a GF(2)-affine image of
# its 64-bit lane-1 operand word, fitted exactly over the
# family's full channel-0 corpus population across all 7 HEF
# artifacts (zero inconsistencies, zero verification failures;
# canonical data: ccw_ch0_family_bases.json). The channel-0
# champion family (05280000...) has its own encoder in
# ccw_ch0_datum.mojo and is NOT served here; the channels-1/2
# families live in ccw_family_datum.mojo (AES-NUM-028).
#
# Honesty contract: an unknown lane-0 family, or an operand
# word that does not reduce to zero under its family's basis
# (augmented constant included), is OUT OF SPAN - the encoder
# returns None and the caller must treat the datum as
# unknown, never guess it.

def ccw_ch0_family_datum(lane0: UInt64, lane1: UInt64) -> Optional[UInt32]:
    var a = lane1
    var c = True
    var y: UInt32 = 0
    if lane0 == 0x0028000000000419:
        if c:
            a ^= 0x74fc74fc74fc74fc
            y ^= 0x1e8465
            c = False
        if ((a >> 62) & 1) == 1:
            a ^= 0x4cb64cb64cb64cb6
            y ^= 0x5efef1
        if ((a >> 60) & 1) == 1:
            a ^= 0x1f971f971f971f97
            y ^= 0x2b3bb6
        if ((a >> 59) & 1) == 1:
            a ^= 0x0b020b020b020b02
            y ^= 0x2f6bd3
        if ((a >> 58) & 1) == 1:
            a ^= 0x0733073307330733
            y ^= 0x3760a5
        if ((a >> 57) & 1) == 1:
            a ^= 0x0389038903890389
            y ^= 0x5412f4
        if ((a >> 56) & 1) == 1:
            a ^= 0x01f401f401f401f4
            y ^= 0x2fcb06
        if ((a >> 55) & 1) == 1:
            a ^= 0x00aa00aa00aa00aa
            y ^= 0x74a766
        if ((a >> 54) & 1) == 1:
            a ^= 0x0074007400740074
            y ^= 0x044ab6
        if ((a >> 53) & 1) == 1:
            a ^= 0x0031003100310031
            y ^= 0x312f90
        if ((a >> 52) & 1) == 1:
            a ^= 0x0018001800180018
            y ^= 0x5ca02f
        if ((a >> 51) & 1) == 1:
            a ^= 0x0008000800080008
            y ^= 0x5396ba
        if ((a >> 50) & 1) == 1:
            a ^= 0x0007000700070007
            y ^= 0x49572c
        if ((a >> 49) & 1) == 1:
            a ^= 0x0003000300030003
            y ^= 0x609c71
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0028000000800015:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x7aaa79
            c = False
        if ((a >> 63) & 1) == 1:
            a ^= 0xfd7cfd7cfd7cfd7c
            y ^= 0x12646f
        if ((a >> 60) & 1) == 1:
            a ^= 0x102c102c102c102c
            y ^= 0x07be45
        if ((a >> 59) & 1) == 1:
            a ^= 0x0b240b240b240b24
            y ^= 0x5825fa
        if ((a >> 58) & 1) == 1:
            a ^= 0x042c042c042c042c
            y ^= 0x7cd36f
        if ((a >> 57) & 1) == 1:
            a ^= 0x02a802a802a802a8
            y ^= 0x383ee9
        if ((a >> 56) & 1) == 1:
            a ^= 0x0128012801280128
            y ^= 0x1fce88
        if ((a >> 55) & 1) == 1:
            a ^= 0x00ab00ab00ab00ab
            y ^= 0x54d349
        if ((a >> 54) & 1) == 1:
            a ^= 0x0074007400740074
            y ^= 0x044ab6
        if ((a >> 53) & 1) == 1:
            a ^= 0x0021002100210021
            y ^= 0x3e1905
        if ((a >> 52) & 1) == 1:
            a ^= 0x0015001500150015
            y ^= 0x0689e7
        if ((a >> 51) & 1) == 1:
            a ^= 0x0009000900090009
            y ^= 0x73e295
        if ((a >> 50) & 1) == 1:
            a ^= 0x0004000400040004
            y ^= 0x29cb5d
        if ((a >> 49) & 1) == 1:
            a ^= 0x0002000200020002
            y ^= 0x40e85e
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0028000000000415:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x4650f5
            c = False
        if ((a >> 61) & 1) == 1:
            a ^= 0x3ffe3ffe3ffe3ffe
            y ^= 0x1568ac
        if ((a >> 59) & 1) == 1:
            a ^= 0x09cd09cd09cd09cd
            y ^= 0x7cb568
        if ((a >> 58) & 1) == 1:
            a ^= 0x04ea04ea04ea04ea
            y ^= 0x509e90
        if ((a >> 57) & 1) == 1:
            a ^= 0x025c025c025c025c
            y ^= 0x45c0f7
        if ((a >> 56) & 1) == 1:
            a ^= 0x01c901c901c901c9
            y ^= 0x64b971
        if ((a >> 55) & 1) == 1:
            a ^= 0x00d900d900d900d9
            y ^= 0x39bafc
        if ((a >> 54) & 1) == 1:
            a ^= 0x004f004f004f004f
            y ^= 0x261bc2
        if ((a >> 53) & 1) == 1:
            a ^= 0x003b003b003b003b
            y ^= 0x225174
        if ((a >> 52) & 1) == 1:
            a ^= 0x0012001200120012
            y ^= 0x4fdecb
        if ((a >> 51) & 1) == 1:
            a ^= 0x000b000b000b000b
            y ^= 0x330acb
        if ((a >> 50) & 1) == 1:
            a ^= 0x0007000700070007
            y ^= 0x49572c
        if ((a >> 49) & 1) == 1:
            a ^= 0x0003000300030003
            y ^= 0x609c71
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0228000000800219:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x6fe0eb
            c = False
        if ((a >> 62) & 1) == 1:
            a ^= 0x4336433643364336
            y ^= 0x502a76
        if ((a >> 61) & 1) == 1:
            a ^= 0x3bae3bae3bae3bae
            y ^= 0x3e67cf
        if ((a >> 60) & 1) == 1:
            a ^= 0x1b0d1b0d1b0d1b0d
            y ^= 0x5624cd
        if ((a >> 59) & 1) == 1:
            a ^= 0x0a250a250a250a25
            y ^= 0x2a64cd
        if ((a >> 58) & 1) == 1:
            a ^= 0x0672067206720672
            y ^= 0x79fbc6
        if ((a >> 57) & 1) == 1:
            a ^= 0x0348034803480348
            y ^= 0x310827
        if ((a >> 56) & 1) == 1:
            a ^= 0x01fc01fc01fc01fc
            y ^= 0x7c5dbc
        if ((a >> 55) & 1) == 1:
            a ^= 0x0093009300930093
            y ^= 0x161e4c
        if ((a >> 54) & 1) == 1:
            a ^= 0x0046004600460046
            y ^= 0x55f957
        if ((a >> 53) & 1) == 1:
            a ^= 0x003c003c003c003c
            y ^= 0x6b0658
        if ((a >> 52) & 1) == 1:
            a ^= 0x0015001500150015
            y ^= 0x0689e7
        if ((a >> 51) & 1) == 1:
            a ^= 0x000f000f000f000f
            y ^= 0x1ac196
        if ((a >> 50) & 1) == 1:
            a ^= 0x0005000500050005
            y ^= 0x09bf72
        if ((a >> 49) & 1) == 1:
            a ^= 0x0002000200020002
            y ^= 0x40e85e
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0228000000001719:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x4a6b41
            c = False
        if ((a >> 58) & 1) == 1:
            a ^= 0x0601060106010601
            y ^= 0x34e65c
        if ((a >> 57) & 1) == 1:
            a ^= 0x0234023402340234
            y ^= 0x34e133
        if ((a >> 56) & 1) == 1:
            a ^= 0x0150015001500150
            y ^= 0x61d9d9
        if ((a >> 55) & 1) == 1:
            a ^= 0x00c500c500c500c5
            y ^= 0x4cd18e
        if ((a >> 54) & 1) == 1:
            a ^= 0x0055005500550055
            y ^= 0x3a53b3
        if ((a >> 53) & 1) == 1:
            a ^= 0x003e003e003e003e
            y ^= 0x2bee06
        if ((a >> 52) & 1) == 1:
            a ^= 0x001a001a001a001a
            y ^= 0x1c4871
        if ((a >> 51) & 1) == 1:
            a ^= 0x000e000e000e000e
            y ^= 0x3ab5b9
        if ((a >> 50) & 1) == 1:
            a ^= 0x0004000400040004
            y ^= 0x29cb5d
        if ((a >> 49) & 1) == 1:
            a ^= 0x0003000300030003
            y ^= 0x609c71
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0028000000000819:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x5c59c1
            c = False
        if ((a >> 59) & 1) == 1:
            a ^= 0x0bef0bef0bef0bef
            y ^= 0x2e41cd
        if ((a >> 58) & 1) == 1:
            a ^= 0x0639063906390639
            y ^= 0x762b59
        if ((a >> 57) & 1) == 1:
            a ^= 0x0266026602660266
            y ^= 0x47e5ac
        if ((a >> 56) & 1) == 1:
            a ^= 0x0163016301630163
            y ^= 0x101e17
        if ((a >> 55) & 1) == 1:
            a ^= 0x00ef00ef00ef00ef
            y ^= 0x41c240
        if ((a >> 54) & 1) == 1:
            a ^= 0x0070007000700070
            y ^= 0x2d81eb
        if ((a >> 53) & 1) == 1:
            a ^= 0x0020002000200020
            y ^= 0x1e6d2a
        if ((a >> 51) & 1) == 1:
            a ^= 0x000d000d000d000d
            y ^= 0x5a29c8
        if c or a != 0:
            return None
        return y
    return None


def main():
    # Smoke checks (the full 133-pair verification harness is
    # generated on-device from the source artifacts; see
    # docs/HAILO10H_CHANNEL0_FREEZES_2026-10-24.md).
    var unknown = ccw_ch0_family_datum(0x0528000000000000, 0)
    print("champion via ch0 family encoder present:", unknown != None)
