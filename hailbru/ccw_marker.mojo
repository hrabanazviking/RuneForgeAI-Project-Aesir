# ccw_marker.mojo — Aesir reference encoder for the skeleton
# marker word (AES-NUM-046).
#
# In the structured small forms of a HEF network group, the
# word at word (words - 3) of a dense-skeleton segment is a
# closed-form function of the preceding strict word (the last
# `01 00 <b2> 00 ...` word before it): copy the word, add 1
# to byte 2, and step byte 4 by -4 in the small forms
# (232-360 B) or by +16 in the 464 B form (AES-NUM-044/045,
# measured 212/212 dense cc9b9d1c segments under the modal-X
# definition, plus all 20 parameter-family segments).
#
# Representation: a word is a UInt64 loaded little-endian
# from its 8 file bytes, so byte k of the file word is
# (word >> (8*k)) & 0xFF. File-order hex in the evidence
# docs is the reverse of the UInt64 hex.
#
# Form codes: 0 = small form (byte 4 step -4), 1 = 464 B
# form (byte 4 step +16), 2 = 464 B form in the 0856a10c
# `0200...` head shape (byte 4 step +16, and the marker's
# byte 0 is 0x02 where the predecessor's is 0x01 — the one
# measured head-byte deviation in the family, AES-NUM-045;
# no discriminator for this variant is established, so the
# caller must select it explicitly).
#
# Honesty contract: a predecessor that is not a strict
# word (byte 0 != 0x01, byte 1 != 0, byte 3 != 0), a byte 2
# of 0xFF, a byte 4 that cannot take the form's step, or an
# unknown form code returns None — the encoder refuses,
# never guesses. What the marker encodes remains NOT
# PROVEN (AES-NUM-045); this module freezes only the
# measured derivation.

def ccw_marker(predecessor: UInt64, form: UInt8) -> Optional[UInt64]:
    var b0 = predecessor & 0xFF
    var b1 = (predecessor >> 8) & 0xFF
    var b2 = (predecessor >> 16) & 0xFF
    var b3 = (predecessor >> 24) & 0xFF
    var b4 = (predecessor >> 32) & 0xFF
    if b0 != 0x01 or b1 != 0 or b3 != 0:
        return None
    if b2 == 0xFF:
        return None
    # Byte 2 +1: no carry out of the byte, since b2 != 0xFF.
    var out = predecessor + (UInt64(1) << 16)
    if form == 0:
        if b4 < 4:
            return None
        out -= UInt64(4) << 32
    elif form == 1 or form == 2:
        if b4 > 0xEF:
            return None
        out += UInt64(16) << 32
        if form == 2:
            # Byte 0: 0x01 -> 0x02 (no other byte affected).
            out += 1
    else:
        return None
    return out


def main():
    # Smoke checks from recorded examples (file-order hex in
    # the comments; literals are the little-endian UInt64s).
    # Small form, modal-0 segment (AES-NUM-045):
    # 010000005001f080 -> 010001004c01f080.
    var small = ccw_marker(0x80f0015000000001, 0)
    print("small present:", small != None, "value:", small.or_else(0))
    # 464 B form, 0a0d378c family (AES-NUM-044/045):
    # 010072008801b000 -> 010073009801b000.
    var large = ccw_marker(0x00b0018800720001, 1)
    print("large present:", large != None, "value:", large.or_else(0))
    # 464 B 0200 shape, 0856a10c (AES-NUM-044/045):
    # 010046008401b080 -> 020047009401b080.
    var shape = ccw_marker(0x80b0018400460001, 2)
    print("shape present:", shape != None, "value:", shape.or_else(0))
    # Refusals: a non-strict word and an unknown form code.
    var bad = ccw_marker(0, 0)
    print("zero refused:", bad == None)
    var badform = ccw_marker(0x80f0015000000001, 9)
    print("form 9 refused:", badform == None)
