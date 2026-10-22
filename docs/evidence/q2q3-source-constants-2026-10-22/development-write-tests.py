from pathlib import Path
base=Path('tests/test_hailo_source_classic32_constants.py').read_text()
head=base[:base.index('from test_hailo_source_q8_constants import')]
head+='''from test_hailo_source_q8_constants import make
KINDS=(10,11)
SIZES={10:84,11:110}

def block(kind,d,dmin,scales,minimums,quants):
    # Independent logical-bit writer for the qualified source fields.
    assert len(quants)==256 and len(scales)==len(minimums)==16
    out=bytearray(SIZES[kind]);present=kind==10
    struct.pack_into('<H',out,80 if present else 108,d)
    if present:struct.pack_into('<H',out,82,dmin)
    for g,scale in enumerate(scales):
        if present:
            assert 0<=scale<16 and 0<=minimums[g]<16
            out[g]=scale+16*minimums[g]
        else:
            encoded=scale+32;assert 0<=encoded<64
            for bit in range(6):
                dest=(96+g%8,4*(g//8)+bit) if bit<4 else (104+g%4,2*(g//4)+bit-4)
                out[dest[0]] |= ((encoded>>bit)&1)<<dest[1]
    for lane,q in enumerate(quants):
        encoded=q if present else q+4;assert 0<=encoded<(4 if present else 8)
        # Each 128-lane half stores four32-lane low-bit planes.
        byte=(16 if present else 32)+(lane//128)*32+lane%32
        for bit in range(2):out[byte] |= ((encoded>>bit)&1)<<(2*((lane%128)//32)+bit)
        if not present:out[lane%32] |= (1 if q>=0 else 0)<<(lane//32)
    return bytes(out)

def components(kind,d,dmin,scales,minimums,q):
    present=kind==10;dmin=dmin if present else 0
    return [[d,dmin,oracle16(1,d),oracle16(1,dmin),present,scales[i//16],minimums[i//16] if present else 0,x] for i,x in enumerate(q)]

def q2q3_fixture(kind=10,columns=512,rows=2,words=None,name='matrix.weight',seed=0):
    assert columns%256==0
    words=words or [0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7e01,0x7d01,0xffff,0x3ff,0x400]
    rng=random.Random(seed);payload=bytearray();expected=[];present=kind==10
    for i in range(columns*rows//256):
        d=words[i%len(words)];dm=words[(i*3+1)%len(words)]
        scales=[(g+i)%16 if present else (g*7+i)%64-32 for g in range(16)]
        mins=[(g*3+i)%16 if present else 0 for g in range(16)]
        q=[((j+i)%4 if present else (j+i)%8-4) if not seed else rng.randrange(4 if present else 8)-(0 if present else 4) for j in range(256)]
        payload+=block(kind,d,dm,scales,mins,q);expected+=components(kind,d,dm,scales,mins,q)
    return (*make([(name,columns,rows,kind,payload)]),expected)

def dense_fixture(kind):
    hidden,ff,heads,kv,key,value,vocab=256,512,2,1,128,128,4
    tensors=[('token_embd.weight',hidden,vocab,kind),('output_norm.weight',hidden,1,0),('output.weight',hidden,vocab,kind)]
    shapes=[('attn_norm',hidden,1),('ffn_norm',hidden,1),('attn_q',hidden,heads*key),('attn_k',hidden,kv*key),('attn_v',hidden,kv*value),('attn_output',heads*value,hidden),('ffn_gate',hidden,ff),('ffn_up',hidden,ff),('ffn_down',ff,hidden)]
    tensors += [(f'blk.0.{name}.weight',c,r,0 if r==1 else kind) for name,c,r in shapes]
    rows=[]
    for name,c,r,k in tensors:
        data=bytes(c*r*4) if k==0 else q2q3_fixture(k,c,r)[0][q2q3_fixture(k,c,r)[2]:]
        rows.append((name,c,r,k,data))
    metadata=[('llama.context_length',10,64),('llama.embedding_length',4,hidden),('llama.block_count',4,1),('llama.feed_forward_length',4,ff),('llama.attention.head_count',10,heads),('llama.attention.head_count_kv',10,kv),('llama.rope.dimension_count',10,key),('llama.rope.freq_base',6,10000.),('llama.attention.layer_norm_rms_epsilon',6,.00001),('llama.attention.key_length',4,key),('llama.attention.value_length',4,value)]
    return (*make(rows,'llama',metadata),[])

'''
body=base[base.index('class SourceClassic32'):]
body=body.replace('SourceClassic32','SourceQ2Q3').replace('Classic32','Q2Q3').replace('classic32','q2q3').replace('kind=2','kind=10')
a=body.index('    def test_all_quants_');b=body.index('    def test_selection_and_bound_refusals')
body=body[:a]+'''    def test_special_words_and_boundary_windows(self):
        for kind in KINDS:
            self.kind=kind
            f=q2q3_fixture(kind,columns=768,rows=11)
            self.accept(self.invoke(f,count=768*11,bound=768*11))
            for first,count in ((0,1),(1,2),(14,5),(15,2),(30,5),(31,2),(126,5),(127,2),(254,5),(255,2),(256,256),(511,5),(767,3),(768*11-1,1)):
                self.accept(self.invoke(f,first,count),first)
            for c,r in ((256,1),(768,1),(256,9),(768,3)):
                f=q2q3_fixture(kind,c,r);self.accept(self.invoke(f,count=c*r))
    def test_every_quant_scale_minimum_bit_and_group(self):
        for kind in KINDS:
            payload=bytearray();expected=[];present=kind==10
            cases=[]
            # Toggle every logical low/high bit separately; all256 fields checked.
            for lane in range(256):
                for bit in range(2 if present else 3):
                    q=[0 if present else -4]*256;q[lane]+=(1<<bit)
                    cases.append(([1]*16,[0]*16,q))
            for group in range(16):
                for bit in range(4 if present else 6):
                    scales=[0 if present else -32]*16;scales[group]+=(1<<bit)
                    cases.append((scales,[0]*16,[1]*256))
                if present:
                    for bit in range(4):
                        mins=[0]*16;mins[group]=1<<bit
                        cases.append(([1]*16,mins,[0]*256))
            for scales,mins,q in cases:
                payload+=block(kind,0x3c00,0x3800,scales,mins,q)
                expected+=components(kind,0x3c00,0x3800,scales,mins,q)
            f=(*make([('matrix.weight',256,len(cases),kind,payload)]),expected)
            self.accept(self.invoke(f,count=len(expected),bound=len(expected)))
    def test_seeded_complete_components(self):
        for kind in KINDS:
            for seed in (3,17,401):
                f=q2q3_fixture(kind,768,5,seed=seed);self.accept(self.invoke(f,count=3840))
    def test_isolated_static_reference(self):
        library=ctypes.CDLL(str(Path(CONFIG.reference_library).resolve(strict=True)));records=[]
        for kind,name in ((10,'q2_K'),(11,'q3_K')):
            f=q2q3_fixture(kind,512,2,words=[0x3800,0x3c00,0x4000,0xbc00])
            o=self.accept(self.invoke(f,count=1024));payload=f[0][f[2]:]
            src=ctypes.create_string_buffer(payload);dest=(ctypes.c_float*1024)()
            fn=getattr(library,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
            fn(src,dest,1024)
            half=lambda w:struct.unpack('<e',struct.pack('<H',w))[0]
            expected=[half(c[0])*c[5]*c[7]-(half(c[1])*c[6] if c[4] else 0.) for c in o['components']]
            # This isolated static oracle compares full finite constant values.
            self.assertEqual(list(dest),expected)
            records.append({'gguf_source_kind':kind,'constants':1024,'complete_value_match':True,'bits_sha256':hashlib.sha256(bytes(dest)).hexdigest()})
        (self.evidence/'static-reference.json').write_text(json.dumps(records,indent=2)+'\\n')
'''+body[b:]
body=body.replace('(256,1,1),(255,2,2)','(1024,1,1),(1023,2,2)')
body=body.replace("'shape','rows'","'shape','shape_missing','rank','file_size','rows'")
body=body.replace('(0,1,31,33,1048577)','(0,1,255,257,1048577)')
body=body.replace('and_non_q8_kind','and_wrong_source_kind')
body=body.replace('x//32 for x in range(c,c+k)','x//256 for x in range(c,c+k)')
body=body.replace("binding['columns']//32*size","binding['columns']//256*size").replace('covered=32*len(blocks);prefix=c-32*blocks[0]','covered=256*len(blocks);prefix=c-256*blocks[0]').replace('span_size,32*blocks[0]','span_size,256*blocks[0]')
body=body.replace('(1,17,31,32,33,63,64,65)','(1,17,31,32,33,127,128,129,255,256,257)')
body=body.replace('math.ceil(64/tc)','math.ceil(256/tc)').replace('21*count,22*count-1,2*22*count-1','85*count,86*count-1,2*86*count-1')
# Geometry covers all previously admitted formats plus exact newly admitted kinds.
body=body.replace('12:(256,144)','10:(256,84),11:(256,110),12:(256,144)')
Path('tests/test_hailo_source_q2q3_constants.py').write_text(head+body)
