"""Original field hypotheses against two isolated static constant functions."""
from pathlib import Path
import ctypes,hashlib,json,struct
out=Path(__file__).resolve().parent;prior=json.loads(Path('../q2q3-source-study/provenance.json').read_text());sources=[]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
for x in prior['sources']:
 p=Path('../ggml-format-study/LICENSE') if x['path']=='LICENSE' else Path('../ggml-format-study/source')/x['path']
 assert sha(p)==x['sha256'];sources.append(x)
libpath=Path('../ggml-format-study/build/src/libggml-base.so.0.27.0');assert sha(libpath)=='45bd8cc3f12159e7b219a95d185be74a2ad83789045e6359acf49523aee23328'
assert 'GGML_CPU:BOOL=OFF' in Path('../ggml-format-study/build/CMakeCache.txt').read_text()
lib=ctypes.CDLL(str(libpath.resolve()));table=(-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113)
records=[];cases=constants=0
for kind,n,size,origin,name in ((20,32,18,2,'iq4_nl'),(23,256,136,8,'iq4_xs')):
 fn=getattr(lib,'dequantize_row_'+name);fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
 def expected(raw):
  d=struct.unpack_from('<e',raw)[0];high=struct.unpack_from('<H',raw,2)[0] if kind==23 else 0
  values=[]
  for lane in range(n):
   group=lane//32;byte=origin+(16*group if kind==23 else 0)+lane%16;code=(raw[byte]>>(4*((lane%32)//16)))&15
   scale=1 if kind==20 else ((raw[4+group//2]>>(4*(group%2)))&15)+16*((high>>(2*group))&3)-32
   values.append(d*scale*table[code])
  return values
 vectors=[]
 for byte in range(origin,size):
  for bit in range(8):
   raw=bytearray(size);struct.pack_into('<H',raw,0,0x3c00);raw[byte]=1<<bit;vectors.append(('quant-bit',byte,bit,bytes(raw)))
 if kind==23:
  for byte in range(2,8):
   for bit in range(8):
    raw=bytearray(size);struct.pack_into('<H',raw,0,0x3c00);raw[byte]=1<<bit;vectors.append(('scale-bit',byte,bit,bytes(raw)))
 for code in range(16):
  for word in (0x3800,0xbc00):
   raw=bytearray(size);struct.pack_into('<H',raw,0,word);raw[origin:]=bytes([code+16*code])*(size-origin);vectors.append(('codebook',code,word,bytes(raw)))
 for tag,a,b,raw in vectors:
  src=ctypes.create_string_buffer(raw);dest=(ctypes.c_float*n)();fn(src,dest,n);want=expected(raw)
  assert list(dest)==want,(kind,tag,a,b,next((i for i,(x,y) in enumerate(zip(dest,want)) if x!=y),None))
  records.append({'gguf_source_kind':kind,'case':tag,'a':a,'b':b,'constants':n,'complete_value_match':True,'payload_sha256':hashlib.sha256(raw).hexdigest()});cases+=1;constants+=n
(out/'qualified-oracles.json').write_text(json.dumps({'cases':cases,'constant_value_comparisons':constants,'records':records},indent=2)+'\n')
(out/'provenance.json').write_text(json.dumps({'pin':prior['pin'],'license':'MIT re-read before source field declarations; no implementation body copied or translated','sources':sources,'qualified':True,'functions':['dequantize_row_iq4_nl','dequantize_row_iq4_xs'],'library_sha256':sha(libpath),'probe_sha256':sha(__file__),'cpu_backend':'OFF','all_models_contexts_graphs_forwards_excluded':True,'device_access':False,'source_model_execution':False,'production_implementation':False,'codebook_is_published_source_format_data':True},indent=2)+'\n')
print('Qualified',cases,'small static cases;',constants,'complete finite constant values')
