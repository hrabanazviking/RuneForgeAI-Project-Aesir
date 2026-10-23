#!/usr/bin/env python3
"""Independent synthetic transaction bytes and actual sealed metadata,host only."""
import argparse,ctypes,hashlib,json,os,struct,subprocess,sys,unittest
from pathlib import Path
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
CONFIG=argparse.Namespace()
class Transfer(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.records=[]
  lib=Path(CONFIG.oracle).resolve(strict=True);assert hashlib.sha256(lib.read_bytes()).hexdigest()=='eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031';assert hashlib.sha256(Path(CONFIG.oracle_license).read_bytes()).hexdigest()=='a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
  cls.lib=ctypes.CDLL(str(lib));cls.lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);cls.lib.XXH3_64bits.restype=ctypes.c_uint64
  schema=Path(CONFIG.schema).resolve(strict=True);assert hashlib.sha256(schema.read_bytes()).hexdigest()=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225';pb=cls.out/'rpc.pb';subprocess.run([CONFIG.protoc,'-I',str(schema.parent),'--descriptor_set_out='+str(pb),str(schema)],capture_output=True,check=True)
  pool=descriptor_pool.DescriptorPool()
  for f in descriptor_pb2.FileDescriptorSet.FromString(pb.read_bytes()).file:pool.Add(f)
  cls.proto=message_factory.GetMessageClass(pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
 def envelope(self,n=14,proto_only=False):
  body=bytes((i*37+11)&255 for i in range(n));buf=ctypes.create_string_buffer(body);checksum=self.lib.XXH3_64bits(buf,len(body));return struct.pack('>IIIQQIQQQ',0x01484546,3,n,checksum,0,0,0,checksum if proto_only else 0,0)+body
 def metadata(self,data,msg=17,handle=0,name='native'):
  p=self.proto();p.vdevice_handle.id=handle;p.hef_size=len(data);p.name=name;body=p.SerializeToString();return struct.pack('<5I',0x8a554432,len(body),msg,2,1)+body+bytes(2048-len(body))
 def call(self,binary,args,fault=None,expected=None):
  i=len(self.records);env={k:v for k,v in os.environ.items() if not k.startswith(('AESIR_TRANSFER_','AESIR_PROGRAM_'))};env.pop('LD_PRELOAD',None)
  if fault is not None or expected is not None:
   env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_TRANSFER_FAULT=fault or 'none',AESIR_TRANSFER_LOG=str(self.out/f'fault-{i}.jsonl'))
   if expected is not None:env['AESIR_TRANSFER_EXPECTED_HEX']=expected.hex()
  cmd=[str(Path(binary).resolve()),*map(str,args)];p=subprocess.run(cmd,capture_output=True,text=True,env=env,stdin=subprocess.DEVNULL,timeout=90);self.records.append(dict(arguments=cmd,fault=fault,expected_metadata_hex=expected.hex() if expected is not None else None,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr));return p
 def good(self,p):self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);return p.stdout
 def bad(self,p):self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'');self.assertNotIn('TransferAPI:',p.stderr)
 def invoke(self,data,part=1,first=0,count=None,work=None,msg=17,handle=0,name='native',bound=None,pw=4096,pr=4096,mw=4096,mr=4096,arch='aarch64',close='explicit',ok=True,fault=None,kernel=False):
  if count is None:count=len(data)
  if work is None:work=count
  if bound is None:bound=len(data)
  meta=self.metadata(data,msg,handle,name) if ok else None
  p=self.call(CONFIG.binary,[msg,handle,data.hex(),name,bound,part,first,count,work,pw,pr,mw,mr,arch,close],fault,meta if kernel else None)
  if not ok:self.bad(p);return p
  selected=meta if part==0 else data;j=json.loads(self.good(p));self.assertEqual(j,dict(window_hex=selected[first:first+count].hex(),sealed_parts=2,device_access=False,program_transferred=False,execution_tested=False));return p
 def api(self,data,mode='bytes',writes=4096,reads=4096,fault=None,kernel=False):return self.call(CONFIG.api,[data.hex(),writes,reads,mode],fault,self.metadata(data) if kernel else None)
 def test_complete_bytes_windows_and_actual_metadata_kernel_oracle(self):
  for n in (0,1,14,255,4039,4040,4041,8193,16385):
   data=self.envelope(n)
   for part,size in ((0,2068),(1,len(data))):
    for first,count in ((0,size),(0,0),(size,0),(size-1,1)):self.invoke(data,part,first,count,kernel=True)
  for msg in (0,(1<<32)-1):
   for handle in (0,(1<<32)-2):
    for name in ('','模型','🙂'):self.invoke(self.envelope(),part=0,count=2068,msg=msg,handle=handle,name=name,kernel=True)
 def test_ownership_moves_all_actual_metadata_bytes_and_fields(self):
  for n in (0,14,4097,16385):
   data=self.envelope(n)
   for mode in ('bytes','implicit'):
    j=json.loads(self.good(self.api(data,mode,kernel=True)));self.assertEqual(bytes.fromhex(j['program_hex']),data);self.assertEqual(bytes.fromhex(j['metadata_hex']),self.metadata(data));self.assertEqual(j['guard_cycles'],0)
  data=self.envelope();j=json.loads(self.good(self.api(data,'guards',kernel=True)));self.assertEqual(j['guard_cycles'],2099);self.assertEqual(bytes.fromhex(j['metadata_hex']),self.metadata(data));self.assertEqual(bytes.fromhex(j['program_hex']),data)
  self.assertEqual(self.good(self.call(CONFIG.api,['default'])),'default_refused\n');self.assertEqual(self.good(self.api(data,'bad_source',kernel=True)),'source_refused_and_recovered\n')
 def test_signed_bounds_work_host_request_and_preallocation_guards(self):
  data=self.envelope()
  for part in (-1,2,-(1<<63),(1<<63)-1):self.invoke(data,part=part,ok=False)
  for first,count,work in ((-1,0,0),(0,-1,0),(0,0,-1),(71,0,0),(70,1,1),(0,2,1),((1<<63)-1,0,0)):self.invoke(data,first=first,count=count,work=work,ok=False)
  for field in ('pw','pr','mw','mr'):
   for value in (0,-1):self.invoke(data,**{field:value},ok=False)
  for bound in (0,69):self.invoke(data,bound=bound,ok=False)
  for msg,handle in ((-1,0),(1<<32,0),(0,-1),(0,(1<<32)-1),(0,1<<32)):self.invoke(data,msg=msg,handle=handle,ok=False)
  self.invoke(data,name='x'*2049,ok=False);self.invoke(data,arch='x86_64',ok=False);self.invoke(data,close='x',ok=False)
  large=self.envelope(8193)
  for pw,pr in ((2,3),(3,2)):self.invoke(large,pw=pw,pr=pr,ok=False)
  self.invoke(large,pw=3,pr=3)
 def test_integrity_and_malformed_input_refusals(self):
  data=self.envelope()
  for i in range(len(data)):
   if i in (8,9,10,11,28,29,30,31):continue
   bad=bytearray(data);bad[i]^=1;self.invoke(bytes(bad),count=0,work=0,ok=False)
  for n in (0,1,55,56,69):self.invoke(data[:n],count=0,work=0,ok=False)
  self.invoke(data+b'\0',ok=False);self.invoke(self.envelope(proto_only=True),ok=False)
  for args in ([],['x'],[17,0,'g'*140,'native',70,1,0,0,0,1,1,1,1,'aarch64','explicit']):self.bad(self.call(CONFIG.binary,args))
  self.invoke(data)
 def test_faults_partial_owners_and_fresh_in_process_recovery(self):
  data=self.envelope();modes=('create','large_fd','stat_error','stat_extent','stat_extent_late','seal','seal_after','get_seals','get_seals_late','missing_seals','get_flags','missing_flags','read_error','read_zero','read_extra','read_eintr','read_corrupt','read_corrupt_late','write_error','write_zero','write_extra','write_eintr')
  for mode in modes:self.assertEqual(self.good(self.api(data,'recover',writes=3,reads=3,fault=mode,kernel=True)),'refused_and_recovered\n')
  for mode in ('close_before','close_after','close_both_before','close_both_after'):
   text=self.good(self.api(data,'close_error',fault=mode,kernel=True));self.assertIn('metadata descriptor close failed',text)
   if 'both' in mode:self.assertIn('SealedProgramPayload: descriptor close failed',text)
 def test_independent_io_attempt_budgets_and_short_progress(self):
  data=self.envelope()
  for mode in ('read_eintr_once','write_eintr_once'):self.invoke(data,mw=2,mr=2,fault=mode,kernel=True)
  for mode,field in (('write_short','mw'),('read_short','mr')):
   self.invoke(data,**{field:690},fault=mode,kernel=True)
   self.invoke(data,**{field:689},fault=mode,ok=False)
  for mode,field in (('write_eintr','mw'),('read_eintr','mr')):self.invoke(data,**{field:2},fault=mode,ok=False)
if __name__=='__main__':
 ap=argparse.ArgumentParser()
 for n in ('binary','api','faults','oracle','oracle-license','schema','protoc','evidence'):ap.add_argument('--'+n,required=True)
 CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
