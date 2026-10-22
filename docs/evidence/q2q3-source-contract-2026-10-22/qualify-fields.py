"""Tiny static source-field oracles; CPU backendOFF, no model/graph/context API.
Original independent bit-index hypotheses. Do not claim qualified until checks run.
"""
from pathlib import Path
import ctypes,hashlib,json,struct
library=Path('../ggml-format-study/build/src/libggml-base.so.0.27.0')
assert hashlib.sha256(library.read_bytes()).hexdigest()=='45bd8cc3f12159e7b219a95d185be74a2ad83789045e6359acf49523aee23328'
assert 'GGML_CPU:BOOL=OFF' in Path('../ggml-format-study/build/CMakeCache.txt').read_text()
lib=ctypes.CDLL(str(library.resolve()));records=[]
def check(kind,case,raw,expected):
 fn=getattr(lib,'dequantize_row_q'+str(kind)+'_K');fn.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_int64];fn.restype=None
 src=ctypes.create_string_buffer(bytes(raw));out=(ctypes.c_float*256)();fn(src,out,256)
 assert list(out)==expected,(kind,case,list(out),expected)
 records.append({'kind':kind,'case':case,'source_sha256':hashlib.sha256(raw).hexdigest(),'binary32_sha256':hashlib.sha256(bytes(out)).hexdigest(),'complete_constants':256})
# Qualified public headers give Q2K scale16,quant64,d80,dmin82;
# Q3K high32,quant64,scale12,d108. Everything below is independently tested.
for kind in (2,3):
 raw=bytearray(84 if kind==2 else 110)
 struct.pack_into('<H',raw,80 if kind==2 else 108,0x3c00)
 if kind==2:raw[:16]=bytes([1])*16
 else:
  raw[:32]=bytes([255])*32
  # Raw6bit scale33 means signed1; direct independent plane packing.
  for g in range(16):
   raw[96+g%8] |= 1 << (4*(g//8))
   raw[104+g%4] |= 2 << (2*(g//4))
 qo=16 if kind==2 else 32
 for byte in range(64):
  for bit in range(8):
   sample=raw.copy();sample[qo+byte]|=1<<bit
   block=byte//32;lane=byte%32+(bit//2)*32+block*128
   expected=[0.]*256;expected[lane]=float(1<<(bit%2));check(kind,f'quant_byte{byte}_bit{bit}',sample,expected)
 if kind==2:
  raw[:16]=bytes(16);raw[16:80]=bytes([85])*64
  for group in range(16):
   for bit in range(8):
    sample=raw.copy();sample[group]=1<<bit
    struct.pack_into('<H',sample,82,0x3c00)
    expected=[0.]*256
    for i in range(group*16,(group+1)*16):expected[i]=float(1<<bit) if bit<4 else -float(1<<(bit-4))
    check(kind,f'group{group}_bit{bit}',sample,expected)
 else:
  for byte in range(32):
   for bit in range(8):
    sample=raw.copy();sample[byte]^=1<<bit
    expected=[0.]*256;expected[byte+bit*32]=-4.;check(kind,f'high_byte{byte}_bit{bit}',sample,expected)
  raw[32:96]=bytes([85])*64;raw[96:108]=bytes(12)
  for group in range(16):
   for bit in range(6):
    sample=raw.copy()
    if bit<4:sample[96+group%8]|=1<<(bit+4*(group//8))
    else:sample[104+group%4]|=1<<(bit-4+2*(group//4))
    expected=[-32.]*256
    for i in range(group*16,(group+1)*16):expected[i]+=1<<bit
    check(kind,f'group{group}_scale_bit{bit}',sample,expected)
result={'cases':len(records),'complete_static_constant_comparisons':len(records)*256,'records':records,'production_implementation':False,'numerical_hailo_execution':False,'model_layer_attention_forward':False,'external_production_dependency':False}
Path('../q2q3-source-study/qualified-field-oracles.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='records'}))
