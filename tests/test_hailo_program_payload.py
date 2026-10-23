#!/usr/bin/env python3
"""Independent synthetic byte preparation oracles; never submits a program."""
import argparse
from collections import Counter
import ctypes
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
CONFIG=argparse.Namespace()
HEADER=struct.Struct('>IIIQQIQQQ')
RPC=struct.Struct('<5I')
U32=(1<<32)-1
U64=(1<<64)-1

class ProgramPayload(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True));cls.ownership=str(Path(CONFIG.ownership).resolve(strict=True))
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=False);cls.records=[]
        facts=json.loads((Path(__file__).resolve().parents[1]/'docs/evidence/program-integrity-facts-2026-10-20/provenance.json').read_text())
        lib=Path(CONFIG.oracle).resolve(strict=True);license_=Path(CONFIG.oracle_license)
        assert hashlib.sha256(lib.read_bytes()).hexdigest()==facts['sha256']['oracle_library']
        assert hashlib.sha256(license_.read_bytes()).hexdigest()==facts['sha256']['oracle_license']
        cls.lib=ctypes.CDLL(str(lib));cls.lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);cls.lib.XXH3_64bits.restype=ctypes.c_uint64
        schema=Path(CONFIG.schema).resolve(strict=True);assert hashlib.sha256(schema.read_bytes()).hexdigest()=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225'
        descriptor=cls.evidence/'rpc.pb';p=subprocess.run([CONFIG.protoc,'-I',str(schema.parent),'--descriptor_set_out='+str(descriptor),str(schema)],capture_output=True,check=True)
        cls.pool=descriptor_pool.DescriptorPool()
        for f in descriptor_pb2.FileDescriptorSet.FromString(descriptor.read_bytes()).file:cls.pool.Add(f)
        cls.proto=message_factory.GetMessageClass(cls.pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))
    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n');print('Native calls:',dict(Counter(r['scope'] for r in cls.records)))
    def hash(self,data):
        owned=ctypes.create_string_buffer(data);return self.lib.XXH3_64bits(owned,len(data))
    def envelope(self,pb=b'\1\2\3',ccw=b'\4\5\6\7',info=b'\10\11',pad=5,proto_only=False):
        body=pb+bytes(pad)+ccw+info
        return HEADER.pack(0x01484546,3,len(pb),self.hash(body),pad+len(ccw),pad,len(info),self.hash(pb) if proto_only else 0,0)+body
    def metadata(self,data,msg=17,handle=0,name='synthetic'):
        p=self.proto();p.vdevice_handle.id=handle;p.hef_size=len(data);p.name=name;body=p.SerializeToString()
        assert len(body)<=2048
        return RPC.pack(0x8a554432,len(body),msg,2,1)+body+bytes(2048-len(body))
    def call(self,cmd,scope):
        ident=len(self.records);trace=self.evidence/f'call-{ident:05d}.strace'
        p=subprocess.run([CONFIG.strace,'-f','-y','-o',str(trace),'-e','trace=openat,close,mmap,munmap,connect,ioctl,execve',*map(str,cmd)],capture_output=True,text=True,timeout=20,stdin=subprocess.DEVNULL)
        (self.evidence/f'call-{ident:05d}.stdout').write_text(p.stdout);(self.evidence/f'call-{ident:05d}.stderr').write_text(p.stderr)
        self.records.append(dict(scope=scope,arguments=list(map(str,cmd)),returncode=p.returncode,stdout=p.stdout,stderr=p.stderr))
        t=trace.read_text();self.assertEqual(t.count('execve('),1)
        for bad in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libggml','libtorch','libxxhash','libonnxruntime','connect(','ioctl('):self.assertNotIn(bad,t)
        return p
    def invoke(self,data,part=1,first=0,count=None,work=None,msg=17,handle=0,name='synthetic',bound=None,expected=None,accept=True):
        if count is None:count=len(data)
        if work is None:work=count
        if bound is None:bound=len(data)
        if expected is None:expected=name
        args=[self.binary,msg,handle,data.hex(),name,bound,part,first,count,work,expected]
        p=self.call(args,'accept' if accept else 'refuse')
        if not accept:
            self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'');self.assertNotEqual(p.stderr,'');return
        self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'')
        meta=self.metadata(data,msg,handle,name);selected=meta if part==0 else data
        self.assertEqual(json.loads(p.stdout),dict(metadata_hex=meta.hex(),program_hex=data.hex(),window_hex=selected[first:first+count].hex(),metadata_bytes=2068,program_bytes=len(data),device_access=False,program_transferred=False,executable_verified=False))
    def test_sections_and_outer_boundaries(self):
        for n in (0,1,2,3,7,8,15,16,17,31,32,63,64,127,128,129,239,240,241,255,256,1023,1024,1025,4096,8192):
            blob=bytes((i*29+7)&255 for i in range(n))
            for field in range(3):
                sections=[b'',b'',b''];sections[field]=blob
                self.invoke(self.envelope(*sections,pad=n%17))
    def test_part_window_boundaries_and_empty_output(self):
        data=self.envelope()
        for part,size in ((0,2068),(1,len(data))):
            positions=sorted(set([0,1,19,20,size-1,size]))
            for first in positions:
                if first>size:continue
                for count in sorted(set((0,min(1,size-first),size-first))):self.invoke(data,part,first,count,count)
        for first in range(len(data)+1):self.invoke(data,1,first,0,0)
    def test_request_widths_utf8_defaults_and_body_limit(self):
        data=self.envelope()
        for msg in (0,1,U32):
            for handle in (0,1,U32-1):
                for name in ('','name','模型','🙂'):
                    self.invoke(data,0,0,20,20,msg,handle,name,U64)
        # Derive the exact name bound using the independent protobuf oracle.
        for handle in (0,U32-1):
            p=self.proto();p.vdevice_handle.id=handle;p.hef_size=len(data)
            fitting=0
            for n in range(2030,2049):
                p.name='x'*n
                if len(p.SerializeToString())<=2048:fitting=n
            self.invoke(data,name='x'*fitting,handle=handle)
            self.invoke(data,name='x'*(fitting+1),handle=handle,accept=False)
    def test_header_guards_and_valid_header_is_not_identity(self):
        data=self.envelope()
        for i in range(56):
            b=bytearray(data);b[i]^=1
            magic,version,pb,hash_,words,pad,info,proto,reserved=HEADER.unpack(b[:56])
            valid=(magic==0x01484546 and version==3 and reserved==0 and proto==0 and pad<=words and 56+pb+words+info==len(b) and hash_==self.hash(bytes(b[56:])))
            self.invoke(bytes(b),accept=valid)
        b=bytearray(data);struct.pack_into('>I',b,28,4)
        self.invoke(bytes(b)) # valid different layout; no artifact identity claimed
    def test_residue_mutations_rehashed_replacement_and_mode(self):
        data=self.envelope()
        for i in range(56,len(data)):
            b=bytearray(data);b[i]^=1;self.invoke(bytes(b),accept=False)
        self.invoke(self.envelope(ccw=b'\4\5\6\x63'))
        self.invoke(self.envelope(proto_only=True),accept=False)
        for n in range(56):self.invoke(data[:n],count=0,work=0,accept=False)
        for b in (data[:-1],data+b'\0'):self.invoke(b,accept=False)
    def test_part_signed_work_and_host_bounds(self):
        data=self.envelope()
        for part in (-1,2,3,(1<<63)-1,-(1<<63)):self.invoke(data,part=part,accept=False)
        for first,count,work in ((-1,0,0),(0,-1,0),(0,0,-1),(len(data)+1,0,0),(len(data),1,1),(0,2,1),(0,(1<<63)-1,(1<<63)-1),((1<<63)-1,0,0)):
            self.invoke(data,first=first,count=count,work=work,accept=False)
        for bound in (0,len(data)-1):self.invoke(data,bound=bound,accept=False)
        self.invoke(data,bound=U64)
        for msg in (-1,U32+1):self.invoke(data,msg=msg,accept=False)
        for handle in (-1,U32,U32+1):self.invoke(data,handle=handle,accept=False)
        self.invoke(data,expected='different',accept=False)
    def test_diagnostic_bounds_and_malformed_arguments(self):
        data=self.envelope();base=[17,0,data.hex(),'synthetic',len(data),1,0,0,0,'synthetic']
        for field,values in ((0,('','1x',str(U64+1),'0'*21)),(2,('0','xx','00'*32769)),(3,('x'*2049,)),(4,('-1','1x',str(U64+1))),(5,('1x','9223372036854775808')),(9,('x'*2049,))):
            for v in values:
                args=base.copy();args[field]=v;p=self.call([self.binary,*args],'malformed');self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
        for args in ([],base[:-1],base+[0]):
            p=self.call([self.binary,*args],'malformed');self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'')
    def test_direct_owned_mutations_moves_scope_and_nul(self):
        p=self.call([self.ownership],'ownership');self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'')
        lines=p.stdout.splitlines();self.assertEqual(len(lines),2)
        self.assertEqual(lines[0],'nul_metadata_hex='+self.metadata(self.envelope(),name='a\0b').hex())
        self.assertEqual(lines[1],'owned-program-payload-pass;2092-refusal-and-fresh-success-cycles;rehashed-replacement-is-new-wire-intent')

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for n in ('binary','ownership','oracle','oracle-license','schema','protoc','strace','evidence'):ap.add_argument('--'+n,required=True)
    CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
