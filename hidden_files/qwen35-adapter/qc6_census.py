# QC-6 stage 1: header-only census of a GGUF file (mmap, no payload reads).
# Prints every tensor: name, ggml type, dims, elements, dim0 % 256, dim0 % 32.
import mmap, struct, sys
path = sys.argv[1]
f = open(path, 'rb')
d = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
off = 0
def r(fmt):
    global off
    n = struct.calcsize(fmt)
    v = struct.unpack_from(fmt, d, off)
    off += n
    return v[0] if len(v) == 1 else v
def s():
    global off
    n = r('<Q')
    v = bytes(d[off:off+n]); off += n
    return v.decode('utf-8', 'replace')
assert bytes(d[0:4]) == b'GGUF'
off = 4
ver = r('<I'); nt = r('<Q'); nkv = r('<Q')
sizes = {0:1,1:1,2:2,3:2,4:4,5:4,6:4,7:1,10:8,11:8,12:8}
kvs = {}
for _ in range(nkv):
    k = s(); t = r('<I')
    if t == 8:
        v = s()
    elif t == 9:
        et = r('<I'); n = r('<Q')
        if et == 8:
            v = [s() for _ in range(n)]
        else:
            off += sizes[et]*n; v = 'array[%d]' % n
    elif t in sizes:
        raw = bytes(d[off:off+sizes[t]]); off += sizes[t]
        v = struct.unpack({1:'<B',2:'<H',4:'<I',8:'<Q'}[sizes[t]], raw)[0] if t != 10 else raw
    else:
        v = '?'
    kvs[k] = v
    if not k.startswith('tokenizer.'):
        print('KV %s = %r' % (k, v if not isinstance(v, list) else 'list[%d]' % len(v)))
align = kvs.get('general.alignment', 32)
data_off = (off + align - 1)//align*align
print('TENSORS %d KV %d header_end=%d data_offset=%d' % (nt, nkv, off, data_off))
typenames = {0:'F32',1:'F16',8:'Q8_0',12:'Q4_K',13:'Q5_K',14:'Q6_K',30:'BF16'}
tot = {}
for _ in range(nt):
    n = s(); nd = r('<I')
    dims = [r('<Q') for _ in range(nd)]
    t = r('<I'); o = r('<Q')
    els = 1
    for x in dims: els *= x
    tot[t] = tot.get(t, 0) + 1
    print('%s type=%s(%d) dims=%s elements=%d dim0mod256=%d dim0mod32=%d' % (n, typenames.get(t, '?'), t, dims, els, dims[0] % 256, dims[0] % 32))
print('TYPE COUNTS', {typenames.get(k, k): v for k, v in sorted(tot.items())})
