# TEST-ONLY (PRÓF): independent struct-based safetensors cross-check for H043.
# Parses each corpus file with Python's struct+json (no Mojo) and prints the
# canonical descriptor list in the same format as tests/h043_st_check.mojo.
# Usage: python3 check_safetensors.py <file.st>  (exit 0; REJECT lines on corrupt input)
import struct, sys, json

def main(path):
    try:
        with open(path, "rb") as f:
            d = f.read()
        if len(d) < 8:
            print("REJECT: file smaller than the 8-byte header prefix"); return
        n = struct.unpack("<Q", d[:8])[0]
        if 8 + n > len(d):
            print("REJECT: truncated file or out-of-range offset"); return
        try:
            hj = json.loads(d[8:8+n].decode("utf-8"))
        except Exception:
            print("REJECT: malformed JSON header"); return
        if not isinstance(hj, dict):
            print("REJECT: malformed header object"); return
        descs = []
        for name, desc in hj.items():
            if name == "__metadata__":
                continue
            try:
                dtype = desc["dtype"]; shape = desc["shape"]; offs = desc["data_offsets"]
                if dtype not in ("F16", "BF16", "F32"):
                    print("REJECT: unsupported dtype " + str(dtype)); return
                if any((not isinstance(x, int) or x < 0) for x in shape):
                    print("REJECT: negative shape dimension"); return
                s, e = offs
                if not (0 <= s <= e):
                    print("REJECT: bad data_offsets for " + name); return
                bpe = 4 if dtype == "F32" else 2
                nel = 1
                for x in shape: nel *= x
                if e - s != nel * bpe:
                    print("REJECT: data_offsets size mismatch for " + name); return
                descs.append((name, dtype, shape, 8 + n + s, 8 + n + e))
            except KeyError as ex:
                print("REJECT: tensor descriptor missing " + str(ex) + ": " + name); return
        names = [x[0] for x in descs]
        if len(set(names)) != len(names):
            print("REJECT: duplicate tensor name"); return
        # overlap + EOF checks
        for name, dtype, shape, s, e in descs:
            if e > len(d):
                print("REJECT: truncated file or out-of-range offset"); return
        for i in range(len(descs)):
            for j in range(i+1, len(descs)):
                a0, a1 = descs[i][3], descs[i][4]
                b0, b1 = descs[j][3], descs[j][4]
                if a0 < b1 and b0 < a1:
                    print("REJECT: overlapping data offsets"); return
        for name, dtype, shape, s, e in sorted(descs):
            print("name=%s dtype=%s shape=%s start=%d end=%d" %
                  (name, dtype, ",".join(str(x) for x in shape), s, e))
        print("ST-CHECK-DONE")
    except OSError as ex:
        print("REJECT: failed to open " + str(ex))

if __name__ == "__main__":
    main(sys.argv[1])
