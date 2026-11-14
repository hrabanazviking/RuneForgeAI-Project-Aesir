# independent GGUF print parser for census (QC-3 harness style)
import struct, sys
path = sys.argv[1]
d = open(path, 'rb').read()
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
    v = d[off:off+n]; off += n
    return v.decode('utf-8', 'replace')
assert d[0:4] == b'GGUF'
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
            off += sizes[et]*n; v = f'array[{n}]'
    elif t in sizes:
        v = d[off:off+sizes[t]]; off += sizes[t]
        v = struct.unpack({1:'<B',2:'<H',4:'<I',8:'<Q'}[sizes[t]], v)[0] if t!=10 else v
    else:
        v = '?'
    kvs[k] = v
    if k in ('general.file_type','llama.block_count','general.architecture','general.quantization_version','llama.embedding_length','llama.feed_forward_length'):
        print(f'KV {k}={v}')
align = kvs.get('general.alignment', 32)
data_off = (off + align - 1)//align*align
tensors = {}
for _ in range(nt):
    n = s(); nd = r('<I')
    dims = [r('<Q') for _ in range(nd)]
    t = r('<I'); o = r('<Q')
    tensors[n] = (dims, t, o)
print(f'TENSORS {nt} KV {nkv} header_end={off} data_offset={data_off}')
tot = {}
for n,(dims,t,o) in tensors.items():
    els = 1
    for x in dims: els *= x
    tot[t] = tot.get(t,0)+1
    print(f'{n} dims={dims} type={t} elements={els} flat256rem={els%256} row256rem={dims[0]%256}')
print('TYPE COUNTS', tot)
