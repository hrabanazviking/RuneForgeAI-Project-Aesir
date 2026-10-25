# ccw_family_datum.mojo - Aesir reference encoders for the six
# largest non-champion lane-0 burst families (AES-NUM-028).
#
# Each family's 24-bit lane-2 datum is a GF(2)-affine image of
# its 64-bit lane-1 operand word, fitted exactly over the
# family's full corpus population across all 7 HEF artifacts
# (zero inconsistencies, zero verification failures; canonical
# data: ccw_family_bases.json). The champion family
# (05280000...) has its own encoder in ccw_datum.mojo and is
# NOT served here.
#
# Honesty contract: an unknown lane-0 family, or an operand
# word that does not reduce to zero under its family's basis
# (augmented constant included), is OUT OF SPAN - the encoder
# returns None and the caller must treat the datum as
# unknown, never guess it.

def ccw_family_datum(lane0: UInt64, lane1: UInt64) -> Optional[UInt32]:
    var a = lane1
    var c = True
    var y: UInt32 = 0
    if lane0 == 0x0028000000802419:
        if c:
            a ^= 0x7ffe7ffe7ffe7ffe
            y ^= 0x5d21bd
            c = False
        if ((a >> 60) & 1) == 1:
            a ^= 0x10c710c710c710c7
            y ^= 0x6fb758
        if ((a >> 58) & 1) == 1:
            a ^= 0x070c070c070c070c
            y ^= 0x3cfa8c
        if ((a >> 57) & 1) == 1:
            a ^= 0x03a303a303a303a3
            y ^= 0x59013a
        if ((a >> 56) & 1) == 1:
            a ^= 0x01ec01ec01ec01ec
            y ^= 0x736b29
        if ((a >> 55) & 1) == 1:
            a ^= 0x00d400d400d400d4
            y ^= 0x639334
        if ((a >> 54) & 1) == 1:
            a ^= 0x004b004b004b004b
            y ^= 0x0fd09f
        if ((a >> 53) & 1) == 1:
            a ^= 0x0032003200320032
            y ^= 0x51b3e1
        if ((a >> 52) & 1) == 1:
            a ^= 0x0014001400140014
            y ^= 0x26fdc8
        if ((a >> 51) & 1) == 1:
            a ^= 0x0008000800080008
            y ^= 0x5396ba
        if ((a >> 50) & 1) == 1:
            a ^= 0x0005000500050005
            y ^= 0x09bf72
        if ((a >> 49) & 1) == 1:
            a ^= 0x0003000300030003
            y ^= 0x609c71
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0228000000001c11:
        if c:
            a ^= 0x7b4f7b4f7b4f7b4f
            y ^= 0x6c8496
            c = False
        if ((a >> 61) & 1) == 1:
            a ^= 0x372b372b372b372b
            y ^= 0x6748f3
        if ((a >> 60) & 1) == 1:
            a ^= 0x17e117e117e117e1
            y ^= 0x5e5e1a
        if ((a >> 59) & 1) == 1:
            a ^= 0x0e200e200e200e20
            y ^= 0x3b381d
        if ((a >> 58) & 1) == 1:
            a ^= 0x0547054705470547
            y ^= 0x3f5bc2
        if ((a >> 57) & 1) == 1:
            a ^= 0x0394039403940394
            y ^= 0x010da9
        if ((a >> 56) & 1) == 1:
            a ^= 0x0181018101810181
            y ^= 0x0bf59f
        if ((a >> 55) & 1) == 1:
            a ^= 0x0080008000800080
            y ^= 0x79b4a8
        if ((a >> 54) & 1) == 1:
            a ^= 0x005c005c005c005c
            y ^= 0x49b126
        if ((a >> 53) & 1) == 1:
            a ^= 0x0037003700370037
            y ^= 0x580c93
        if ((a >> 52) & 1) == 1:
            a ^= 0x001a001a001a001a
            y ^= 0x1c4871
        if ((a >> 51) & 1) == 1:
            a ^= 0x000d000d000d000d
            y ^= 0x5a29c8
        if ((a >> 50) & 1) == 1:
            a ^= 0x0006000600060006
            y ^= 0x692303
        if ((a >> 49) & 1) == 1:
            a ^= 0x0003000300030003
            y ^= 0x609c71
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x01080000f8bf1812:
        if c:
            a ^= 0x0101010101010101
            y ^= 0x623341
            c = False
        if ((a >> 59) & 1) == 1:
            a ^= 0x08ce08ce08ce08ce
            y ^= 0x4e1c01
        if ((a >> 58) & 1) == 1:
            a ^= 0x053e053e053e053e
            y ^= 0x6138bc
        if ((a >> 57) & 1) == 1:
            a ^= 0x0355035503550355
            y ^= 0x64177a
        if ((a >> 56) & 1) == 1:
            a ^= 0x012a012a012a012a
            y ^= 0x5f26d6
        if ((a >> 55) & 1) == 1:
            a ^= 0x00a200a200a200a2
            y ^= 0x2731dc
        if ((a >> 54) & 1) == 1:
            a ^= 0x0047004700470047
            y ^= 0x758d78
        if ((a >> 53) & 1) == 1:
            a ^= 0x0038003800380038
            y ^= 0x42cd05
        if ((a >> 52) & 1) == 1:
            a ^= 0x0015001500150015
            y ^= 0x0689e7
        if ((a >> 51) & 1) == 1:
            a ^= 0x000e000e000e000e
            y ^= 0x3ab5b9
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
    elif lane0 == 0x0028000000002c15:
        if c:
            a ^= 0x788c788c788c788c
            y ^= 0x501cdb
            c = False
        if ((a >> 61) & 1) == 1:
            a ^= 0x31c531c531c531c5
            y ^= 0x126cef
        if ((a >> 59) & 1) == 1:
            a ^= 0x0f950f950f950f95
            y ^= 0x085d60
        if ((a >> 58) & 1) == 1:
            a ^= 0x0772077207720772
            y ^= 0x2bcede
        if ((a >> 57) & 1) == 1:
            a ^= 0x0288028802880288
            y ^= 0x2653c3
        if ((a >> 56) & 1) == 1:
            a ^= 0x016d016d016d016d
            y ^= 0x2aabae
        if ((a >> 55) & 1) == 1:
            a ^= 0x009e009e009e009e
            y ^= 0x4c3784
        if ((a >> 54) & 1) == 1:
            a ^= 0x0047004700470047
            y ^= 0x758d78
        if ((a >> 53) & 1) == 1:
            a ^= 0x002c002c002c002c
            y ^= 0x6430cd
        if ((a >> 52) & 1) == 1:
            a ^= 0x0019001900190019
            y ^= 0x7cd400
        if ((a >> 51) & 1) == 1:
            a ^= 0x000f000f000f000f
            y ^= 0x1ac196
        if ((a >> 50) & 1) == 1:
            a ^= 0x0006000600060006
            y ^= 0x692303
        if ((a >> 49) & 1) == 1:
            a ^= 0x0002000200020002
            y ^= 0x40e85e
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0228000000002c17:
        if c:
            a ^= 0x7936793679367936
            y ^= 0x1fb197
            c = False
        if ((a >> 59) & 1) == 1:
            a ^= 0x0fcc0fcc0fcc0fcc
            y ^= 0x485334
        if ((a >> 58) & 1) == 1:
            a ^= 0x06c806c806c806c8
            y ^= 0x026a35
        if ((a >> 57) & 1) == 1:
            a ^= 0x036c036c036c036c
            y ^= 0x06ae50
        if ((a >> 56) & 1) == 1:
            a ^= 0x0160016001600160
            y ^= 0x708266
        if ((a >> 55) & 1) == 1:
            a ^= 0x00f500f500f500f5
            y ^= 0x5d8a31
        if ((a >> 54) & 1) == 1:
            a ^= 0x0072007200720072
            y ^= 0x6d69b5
        if ((a >> 53) & 1) == 1:
            a ^= 0x0020002000200020
            y ^= 0x1e6d2a
        if ((a >> 52) & 1) == 1:
            a ^= 0x0012001200120012
            y ^= 0x4fdecb
        if ((a >> 51) & 1) == 1:
            a ^= 0x000c000c000c000c
            y ^= 0x7a5de7
        if ((a >> 50) & 1) == 1:
            a ^= 0x0006000600060006
            y ^= 0x692303
        if ((a >> 49) & 1) == 1:
            a ^= 0x0002000200020002
            y ^= 0x40e85e
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    elif lane0 == 0x0228000000001311:
        if c:
            a ^= 0x7d727d727d727d72
            y ^= 0x3bb470
            c = False
        if ((a >> 63) & 1) == 1:
            a ^= 0xfff0fff0fff0fff0
            y ^= 0x1dfcf1
        if ((a >> 59) & 1) == 1:
            a ^= 0x09e309e309e309e3
            y ^= 0x586dfb
        if ((a >> 58) & 1) == 1:
            a ^= 0x05c005c005c005c0
            y ^= 0x0fb846
        if ((a >> 57) & 1) == 1:
            a ^= 0x028c028c028c028c
            y ^= 0x0f989e
        if ((a >> 56) & 1) == 1:
            a ^= 0x0185018501850185
            y ^= 0x223ec2
        if ((a >> 55) & 1) == 1:
            a ^= 0x0099009900990099
            y ^= 0x0560a8
        if ((a >> 54) & 1) == 1:
            a ^= 0x005e005e005e005e
            y ^= 0x095978
        if ((a >> 53) & 1) == 1:
            a ^= 0x002d002d002d002d
            y ^= 0x4444e2
        if ((a >> 52) & 1) == 1:
            a ^= 0x0018001800180018
            y ^= 0x5ca02f
        if ((a >> 51) & 1) == 1:
            a ^= 0x000e000e000e000e
            y ^= 0x3ab5b9
        if ((a >> 50) & 1) == 1:
            a ^= 0x0006000600060006
            y ^= 0x692303
        if ((a >> 49) & 1) == 1:
            a ^= 0x0002000200020002
            y ^= 0x40e85e
        if ((a >> 48) & 1) == 1:
            a ^= 0x0001000100010001
            y ^= 0x20742f
        if c or a != 0:
            return None
        return y
    return None


def main():
    # Smoke checks (the full 177-pair verification harness is
    # generated on-device from the source artifacts; see
    # docs/HAILO10H_FAMILY_CENSUS_FREEZE_STOCKTAKE_2026-10-24.md).
    var unknown = ccw_family_datum(0x0528000000000000, 0)
    print("champion via family encoder present:", unknown != None)
