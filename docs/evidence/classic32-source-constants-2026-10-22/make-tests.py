from pathlib import Path
s=Path('tests/test_hailo_source_q8_constants.py').read_text()
start=s.index('def block(');end=s.index('class SourceQ8(')
fixtures='''from test_hailo_source_q8_constants import make, dense_fixture as q8_dense_fixture
KINDS=(2,3,6,7)
SIZES={2:18,3:20,6:22,7:24}

def block(kind,d,m,quants):
    # Independent source byte writer: place each logical quant bit directly.
    assert len(quants)==32
    out=bytearray(SIZES[kind]);struct.pack_into('<H',out,0,d)
    bias=kind in (3,7);high=kind in (6,7)
    if bias:struct.pack_into('<H',out,2,m)
    ho=4 if bias else 2;no=ho+(4 if high else 0)
    center=0 if bias else (16 if high else 8)
    for lane,q in enumerate(quants):
        u=q+center;assert 0<=u<(32 if high else 16)
        out[no+lane%16] |= (u&15) << (4*(lane//16))
        if high:out[ho+lane//8] |= ((u>>4)&1) << (lane%8)
    return bytes(out)

def classic32_fixture(kind=2,columns=64,rows=4,words=None,name='matrix.weight',seed=0):
    assert columns%32==0
    words=words or [0,0x8000,1,0x3c00,0x7c00,0xfc00,0x7e01,0x7d01,0xffff,0x3ff,0x400]
    rng=random.Random(seed);payload=bytearray();expected=[]
    bias=kind in (3,7);center=0 if bias else (16 if kind==6 else 8);levels=32 if kind in (6,7) else 16
    for i in range(columns*rows//32):
        d=words[i%len(words)];m=words[(i*3+1)%len(words)] if bias else 0
        q=[((j+i)%levels if seed==0 else rng.randrange(levels))-center for j in range(32)]
        payload+=block(kind,d,m,q);expected += [[d,m,oracle16(1,d),oracle16(1,m),bias,x] for x in q]
    return (*make([(name,columns,rows,kind,payload)]),expected)

def dense_fixture(kind):
    raw,bindings,origin,_=q8_dense_fixture()
    tensors=[]
    for name,b in bindings.items():
        c,r=b['columns'],b['rows'];k=0 if b['source_kind']==0 else kind
        data=raw[b['file_offset']:b['file_offset']+b['byte_count']] if k==0 else classic32_fixture(k,c,r)[0][classic32_fixture(k,c,r)[2]:]
        tensors.append((name,c,r,k,data))
    # Reuse only independent container header metadata from the synthetic writer.
    from test_hailo_source_q8_constants import dense_fixture as old
    # Metadata values are explicit; no graph/layer or numerical evaluation.
    metadata=[('llama.context_length',10,64),('llama.embedding_length',4,64),('llama.block_count',4,1),('llama.feed_forward_length',4,96),('llama.attention.head_count',10,2),('llama.attention.head_count_kv',10,1),('llama.rope.dimension_count',10,32),('llama.rope.freq_base',6,10000.),('llama.attention.layer_norm_rms_epsilon',6,.00001),('llama.attention.key_length',4,32),('llama.attention.value_length',4,32)]
    return (*make(tensors,'llama',metadata),[])

'''
s=s[:start]+fixtures+s[end:]
s=s.replace('SourceQ8','SourceClassic32').replace('q8_fixture','classic32_fixture')
s=s.replace("source=fixture or classic32_fixture()","source=fixture or classic32_fixture(self.kind)")
s=s.replace("self.assertEqual(o['source_kind'],8)","self.assertEqual(o['source_kind'],b[name]['source_kind'])")
s=s.replace("CONFIG=argparse.Namespace()","CONFIG=argparse.Namespace()")
s=s.replace("    @classmethod\n    def setUpClass(cls):","    kind=2\n    @classmethod\n    def setUpClass(cls):",1)
start=s.index('    def test_all_signed_quants');end=s.index('    def test_selection_and_bound_refusals',start)
s=s[:start]+'''    def test_all_quants_special_words_and_windows(self):
        for kind in KINDS:
            self.kind=kind
            f=classic32_fixture(kind,columns=96,rows=11)
            got=self.accept(self.invoke(f,count=96*11))
            self.assertEqual({x[5] for x in got['components']},set(range(-8,8) if kind==2 else range(-16,16) if kind==6 else range(16) if kind==3 else range(32)))
            for first,count in ((0,1),(1,2),(14,5),(15,2),(30,5),(31,2),(32,32),(61,8),(95,3),(96*11-1,1)):
                self.accept(self.invoke(f,first,count),first)
            for columns,rows in ((32,1),(96,1),(32,9),(96,3)):
                f=classic32_fixture(kind,columns,rows);self.accept(self.invoke(f,count=columns*rows))
    def test_seeded_complete_component_and_high_plane_bits(self):
        for kind in KINDS:
            for seed in (3,17,401):
                f=classic32_fixture(kind,columns=96,rows=13,seed=seed);self.accept(self.invoke(f,count=1248))
            if kind in (6,7):
                for lane in range(32):
                    center=16 if kind==6 else 0
                    quants=[-center]*32;quants[lane]=16-center
                    data=block(kind,0x3c00,0x8000,quants);bias=kind==7;m=0x8000 if bias else 0
                    f=(*make([('matrix.weight',32,1,kind,data)]),[[0x3c00,m,0x3f800000,oracle16(1,m),bias,q] for q in quants])
                    self.accept(self.invoke(f,count=32))
    def test_isolated_static_reference(self):
        library=ctypes.CDLL(str(Path(CONFIG.reference_library).resolve(strict=True)))
        records=[]
        for kind,name in zip(KINDS,('q4_0','q4_1','q5_0','q5_1')):
            f=classic32_fixture(kind,64,8,words=[0x3800,0x3c00,0x4000,0xbc00])
            o=self.accept(self.invoke(f,count=512))
            payload=f[0][f[2]:];src=ctypes.create_string_buffer(payload);dest=(ctypes.c_float*512)()
            fn=getattr(library,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
            fn(src,dest,512)
            def half(word):return struct.unpack('<e',struct.pack('<H',word))[0]
            expected=[struct.unpack('<I',struct.pack('<f',half(c[0])*c[5]+(half(c[1]) if c[4] else 0.)))[0] for c in o['components']]
            # For types without bias the public expression is a product only;
            # preserve negative zero in the independent expected calculation.
            if kind in (2,6):expected=[struct.unpack('<I',struct.pack('<f',half(c[0])*c[5]))[0] for c in o['components']]
            actual=list(struct.unpack('<512I',bytes(dest)));self.assertEqual(actual,expected)
            records.append({'kind':kind,'constants':512,'exact_binary32_match':True,'bits_sha256':hashlib.sha256(bytes(dest)).hexdigest()})
        (self.evidence/'static-reference.json').write_text(json.dumps(records,indent=2)+'\\n')
''' + s[end:]
# Remaining loops formerly only Q8 need all four format paths.
s=s.replace("f=classic32_fixture();raw,b,o,e=f","f=classic32_fixture(self.kind);raw,b,o,e=f")
s=s.replace("('matrix.weight',cols,1,8,bytes(34))","('matrix.weight',cols,1,self.kind,bytes(SIZES[self.kind]))")
s=s.replace("f=classic32_fixture(name=name)","f=classic32_fixture(self.kind,name=name)")
s=s.replace("f=dense_fixture()","f=dense_fixture(self.kind)")
s=s.replace("self.assertEqual(binding['source_kind'],8)","kind=binding['source_kind'];self.assertIn(kind,KINDS);size=SIZES[kind]")
s=s.replace("//32*34","//32*size").replace("+34*blocks[0]","+size*blocks[0]").replace("size=34*len(blocks)","span_size=size*len(blocks)")
s=s.replace("spans.append([row,offset,size,","spans.append([row,offset,span_size,").replace("raw[offset:offset+size]","raw[offset:offset+span_size]")
s=s.replace("for bound in (-1,0,33,67)","for bound in (-1,0,17,35)")
# Trace count is separately derived from actual raw records, not fixed10.
s=s.replace("prefix='aesir-q8-source-'","prefix='aesir-classic32-source-'").replace("Q8 native outcomes","Classic32 native outcomes")
# Add explicit per-format guard and graph/tile probes in a separate method;
# legacy tests are not modified to replace their established format coverage.
pos=s.index("if __name__=='__main__':")
s=s[:pos]+'''    def test_each_format_guards_names_graph_and_tiles(self):
        for kind in KINDS:
            self.kind=kind
            self.test_selection_and_bound_refusals()
            self.test_mutable_descriptors_ownership_and_recovery()
            self.test_malformed_real_source_headers_and_non_q8_kind()
            self.test_original_source_names_and_owned_binding()
            self.test_actual_source_inventory_and_graph_metadata()
            self.test_actual_lazy_matrix_byte_tiles_rows_blocks_and_tails()
            self.test_byte_tile_live_guards_ownership_and_byte_bound()
    def test_shared_geometry_and_new_admission(self):
        known={0:(1,4),1:(1,2),30:(1,2),2:(32,18),3:(32,20),6:(32,22),7:(32,24),8:(32,34),12:(256,144),13:(256,176),14:(256,210)}
        for kind,(elements,bytes_) in known.items():
            for columns in (elements,elements*3,1048576):
                p=subprocess.run([self.api,'geometry',str(kind),str(columns)],capture_output=True,text=True,timeout=30)
                self.records.append({'tool':'geometry','arguments':[self.api,'geometry',str(kind),str(columns)],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
                self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(json.loads(p.stdout),[elements,bytes_,columns//elements*bytes_])
        for kind in (-1,4,5,9,99):
            p=subprocess.run([self.api,'geometry',str(kind),'256'],capture_output=True,text=True,timeout=30)
            self.records.append({'tool':'geometry','arguments':[self.api,'geometry',str(kind),'256'],'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr});self.assertNotEqual(p.returncode,0)
''' + s[pos:]
# inspect original method names before writing correction below
s=s.replace('test_selection_and_bound_refusals','test_selection_and_bound_refusals')
Path('tests/test_hailo_source_classic32_constants.py').write_text(s)
