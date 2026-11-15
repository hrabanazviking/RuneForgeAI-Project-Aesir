import struct, sys, collections
def census(path):
    with open(path,'rb') as f: data = f.read(64*1024*1024)
    magic, ver, nt, nkv = struct.unpack_from('<4sIQQ', data, 0)
    off = 24
    def rd_str(o):
        n, = struct.unpack_from('<Q', data, o); return data[o+8:o+8+n].decode(), o+8+n
    sizes = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:1,10:8,11:8,12:8}
    for _ in range(nkv):
        _, o = rd_str(off); off = o
        vt, = struct.unpack_from('<I', data, off); off += 4
        if vt == 8: _, off = rd_str(off)
        elif vt == 9:
            et, cnt = struct.unpack_from('<IQ', data, off); off += 12
            if et == 8:
                for _ in range(cnt): _, off = rd_str(off)
            else:
                off += cnt*sizes[et]
        else: off += sizes[vt]
    types = {}
    counts = collections.Counter()
    for _ in range(nt):
        name, o = rd_str(off); off = o
        nd, = struct.unpack_from('<I', data, off); off += 4
        off += 8*nd
        gt, rel = struct.unpack_from('<IQ', data, off); off += 12
        types[name] = gt; counts[gt] += 1
    return types, counts
NAMES={0:'F32',1:'F16',2:'Q4_0',3:'Q4_1',6:'Q5_0',7:'Q5_1',8:'Q8_0',9:'Q8_1',10:'Q2_K',11:'Q3_K',12:'Q4_K',13:'Q5_K',14:'Q6_K',15:'Q8_K',16:'IQ2_XXS',29:'BF16'}
a, ca = census(sys.argv[1]); b, cb = census(sys.argv[2])
print('AESIR searched counts:', {NAMES.get(k,k): v for k,v in sorted(ca.items())})
print('LLAMA control counts:  ', {NAMES.get(k,k): v for k,v in sorted(cb.items())})
diff = [(n, NAMES.get(a[n],a[n]), NAMES.get(b[n],b[n])) for n in a if a[n] != b.get(n)]
print('TENSORS WITH DIFFERENT TYPES:', len(diff))
byclass = collections.Counter()
for n, x, y in diff:
    cls = n.split('.')[-2] + '.' + n.split('.')[-1] if 'blk' in n else n
    byclass[(cls, x, y)] += 1
for k, v in sorted(byclass.items()): print(' ', k, v)
for n, x, y in diff[:12]: print('  e.g.', n, x, '->', y)
