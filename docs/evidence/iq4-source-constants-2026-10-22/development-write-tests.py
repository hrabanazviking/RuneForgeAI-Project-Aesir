from pathlib import Path
base=Path('tests/test_hailo_source_q2q3_constants.py').read_text();head=base[:base.index('from test_hailo_source_q8_constants import make')]
head+='''from test_hailo_source_q8_constants import make
KINDS=(20,23)
SIZES={20:18,23:136}
ELEMENTS={20:32,23:256}
CODEBOOK=(-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113)

def block(kind,d,scales,codes):
    assert len(codes)==ELEMENTS[kind]
    out=bytearray(SIZES[kind]);struct.pack_into('<H',out,0,d)
    present=kind==23;origin=8 if present else 2
    if present:
        assert len(scales)==8
        for g,scale in enumerate(scales):
            raw=scale+32;assert 0<=raw<64
            for bit in range(6):
                byte,shift=(4+g//2,4*(g%2)+bit) if bit<4 else (2+(2*g+bit-4)//8,(2*g+bit-4)%8)
                out[byte] |= ((raw>>bit)&1)<<shift
    for lane,code in enumerate(codes):
        assert 0<=code<16
        byte=origin+16*(lane//32)+lane%16
        for bit in range(4):out[byte] |= ((code>>bit)&1)<<(4*((lane%32)//16)+bit)
    return bytes(out)

def components(kind,d,scales,codes):
    return [[d,oracle16(1,d),kind==23,scales[i//32] if kind==23 else 1,code,CODEBOOK[code]] for i,code in enumerate(codes)]

def iq4_fixture(kind=20,columns=512,rows=2,words=None,name='matrix.weight',seed=0):
    n=ELEMENTS[kind];assert columns%n==0
    words=words or [0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7e01,0x7d01,0xffff,0x3ff,0x400]
    rng=random.Random(seed);payload=bytearray();expected=[]
    for i in range(columns*rows//n):
        d=words[i%len(words)];scales=[(g*7+i)%64-32 for g in range(8)] if kind==23 else [1]
        codes=[(j+i)%16 if not seed else rng.randrange(16) for j in range(n)]
        payload+=block(kind,d,scales,codes);expected+=components(kind,d,scales,codes)
    return (*make([(name,columns,rows,kind,payload)]),expected)

'''
start=base.index('def dense_fixture');end=base.index('class SourceQ2Q3')
head+=base[start:end].replace('q2q3_fixture','iq4_fixture')
body=base[end:].replace('Q2Q3','IQ4').replace('q2q3','iq4').replace('kind=10','kind=20')
a=body.index('    def test_every_quant_scale_minimum_bit_and_group');b=body.index('    def test_seeded_complete_components')
body=body[:a]+'''    def test_every_quant_and_group_scale_bit(self):
        for kind in KINDS:
            n=ELEMENTS[kind];payload=bytearray();expected=[];cases=[]
            for lane in range(n):
                for bit in range(4):
                    codes=[0]*n;codes[lane]=1<<bit;cases.append(([1]*8,codes))
            if kind==23:
                for g in range(8):
                    for bit in range(6):
                        scales=[-32]*8;scales[g]+=1<<bit;cases.append((scales,[8]*n))
            for scales,codes in cases:
                payload+=block(kind,0x3c00,scales,codes);expected+=components(kind,0x3c00,scales,codes)
            f=(*make([('matrix.weight',n,len(cases),kind,payload)]),expected)
            self.accept(self.invoke(f,count=len(expected),bound=len(expected)))
'''+body[b:]
a=body.index('    def test_isolated_static_reference');b=body.index('    def test_selection_and_bound_refusals')
body=body[:a]+'''    def test_isolated_static_reference(self):
        library=ctypes.CDLL(str(Path(CONFIG.reference_library).resolve(strict=True)));records=[]
        for kind,name in ((20,'iq4_nl'),(23,'iq4_xs')):
            f=iq4_fixture(kind,512,2,words=[0x3800,0x3c00,0x4000,0xbc00])
            o=self.accept(self.invoke(f,count=1024));src=ctypes.create_string_buffer(f[0][f[2]:]);dest=(ctypes.c_float*1024)()
            fn=getattr(library,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
            fn(src,dest,1024);half=lambda w:struct.unpack('<e',struct.pack('<H',w))[0]
            expected=[half(c[0])*c[3]*c[5] for c in o['components']]
            self.assertEqual(list(dest),expected)
            records.append({'gguf_source_kind':kind,'constants':1024,'complete_value_match':True,'bits_sha256':hashlib.sha256(bytes(dest)).hexdigest()})
        (self.evidence/'static-reference.json').write_text(json.dumps(records,indent=2)+'\\n')
'''+body[b:]
# Preserve generic graph/test infrastructure, but derive each format's geometry.
body=body.replace("for c,r in ((256,1),(768,1),(256,9),(768,3)):","for c,r in ((ELEMENTS[kind],1),(ELEMENTS[kind]*3,1),(ELEMENTS[kind],9),(ELEMENTS[kind]*3,3)):")
body=body.replace("r,n,c,k=o['rectangle'];blocks=sorted({x//256 for x in range(c,c+k)})","r,n,c,k=o['rectangle'];elements=ELEMENTS[kind];blocks=sorted({x//elements for x in range(c,c+k)})")
body=body.replace("binding['columns']//256*size","binding['columns']//elements*size").replace('covered=256*len(blocks);prefix=c-256*blocks[0]','covered=elements*len(blocks);prefix=c-elements*blocks[0]').replace('span_size,256*blocks[0]','span_size,elements*blocks[0]')
body=body.replace('(0,1,255,257,1048577)','(0,1,ELEMENTS[self.kind]-1,ELEMENTS[self.kind]+1,1048577)')
body=body.replace('14:(256,210)}','14:(256,210),20:(32,18),23:(256,136)}')
# Narrow byte bounds must refuse even a single smallest18-byte touched block.
body=body.replace('for bound in (-1,0,17,35)','for bound in (-1,0,1,17)')
# New geometry-specific direct refusals preserve all prior diagnostic routes.
pos=body.index("if __name__=='__main__':")
body=body[:pos]+'''    def test_iq4_alignment_and_row_limit(self):
        for kind in KINDS:
            for width in (0,-1,ELEMENTS[kind]-1,ELEMENTS[kind]+1,1048577):
                cmd=[self.api,'geometry',str(kind),str(width)]
                p=subprocess.run(cmd,capture_output=True,text=True,timeout=30)
                self.records.append({'tool':'geometry','arguments':cmd,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
                self.assertEqual(p.returncode,1);self.assertEqual(p.stdout,'')
                message='invalid row width' if width<=0 or width>1048576 else 'IQ4_NL row is not block aligned' if kind==20 else 'K-quant row is not block aligned'
                self.assertIn(message,p.stderr)
'''+body[pos:]
Path('tests/test_hailo_source_iq4_constants.py').write_text(head+body)
# Public header oracle is reused as immutable text; no external body.
Path('tests/hailo_iq4_layout_oracle.cpp').write_text(Path('../iq4-source-study/layout-oracle.cpp').read_text())
