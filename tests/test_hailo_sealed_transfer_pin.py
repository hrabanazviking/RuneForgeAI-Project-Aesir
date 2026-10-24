#!/usr/bin/env python3
"""Independent full two-part bytes and kernel/lifetime checks. Host mocks only."""
import argparse,ctypes,hashlib,json,os,struct,subprocess,sys,unittest
from pathlib import Path
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
CONFIG=argparse.Namespace()
class GroupPin(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.records=[]
  cls.sysfs=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir();node=cls.sysfs/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
  (node.parents[1]/'vendor').write_text('0x1e60\n');(node.parents[1]/'device').write_text('0x45c4\n');(node/'dev').write_text('1:3\n')
  lib=Path(CONFIG.oracle).resolve(strict=True);assert hashlib.sha256(lib.read_bytes()).hexdigest()=='eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031';assert hashlib.sha256(Path(CONFIG.oracle_license).read_bytes()).hexdigest()=='a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
  cls.lib=ctypes.CDLL(str(lib));cls.lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);cls.lib.XXH3_64bits.restype=ctypes.c_uint64
  schema=Path(CONFIG.schema).resolve(strict=True);assert hashlib.sha256(schema.read_bytes()).hexdigest()=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225'
  pb=cls.out/'rpc.pb';subprocess.run([CONFIG.protoc,'-I',str(schema.parent),'--descriptor_set_out='+str(pb),str(schema)],capture_output=True,check=True)
  pool=descriptor_pool.DescriptorPool()
  for f in descriptor_pb2.FileDescriptorSet.FromString(pb.read_bytes()).file:pool.Add(f)
  cls.proto=message_factory.GetMessageClass(pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
 def bytes(self,n):
  body=bytes((i*37+11)&255 for i in range(n-56));buf=ctypes.create_string_buffer(body);checksum=self.lib.XXH3_64bits(buf,len(body));program=struct.pack('>IIIQQIQQQ',0x01484546,3,len(body),checksum,0,0,0,0,0)+body
  p=self.proto();p.vdevice_handle.id=0;p.hef_size=len(program);p.name='two-part-pin';body=p.SerializeToString();metadata=struct.pack('<5I',0x8a554432,len(body),17,2,1)+body+bytes(2048-len(body));return metadata,program
 def call(self,args,fault='none',api=False):
  i=len(self.records);env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_')};env.pop('LD_PRELOAD',None)
  env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_GROUP_PIN_FAULT=fault,AESIR_GROUP_PIN_NODE=str(self.dev/'h1x-0'),AESIR_GROUP_PIN_LOG=str(self.out/f'fault-{i}.jsonl'))
  binary=CONFIG.api if api else CONFIG.binary
  cmd=['strace','-ff','-yy','-o',str(self.out/f'call-{i:04d}.trace'),'-e','trace=process,openat,close,mmap,munmap,fcntl,ioctl,pread64,pwrite64,fstat,newfstatat,connect,memfd_create',str(Path(binary).resolve()),*map(str,args)]
  p=subprocess.run(cmd,env=env,capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=15)
  events=[json.loads(x) for x in (self.out/f'fault-{i}.jsonl').read_text().splitlines()] if (self.out/f'fault-{i}.jsonl').exists() else []
  r=dict(arguments=list(map(str,args)),api=api,fault=fault,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,events=events,physical_evidence=False)
  self.records.append(r);(self.out/f'call-{i:04d}.stdout').write_text(p.stdout);(self.out/f'call-{i:04d}.stderr').write_text(p.stderr)
  self.assertFalse(any(e['op'].startswith('unsafe_') or e['op']=='forbidden_ioctl' for e in events));return p,events
 def invoke(self,n=70,device=False,fault='none'):return self.call(['device' if device else 'host',n,self.sysfs if device else '-',self.dev if device else '-'],fault)
 def good(self,result,n=70,device=False):
  p,events=result;self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);j=json.loads(p.stdout);metadata,program=self.bytes(n)
  self.assertEqual(bytes.fromhex(j['metadata_hex']),metadata);self.assertEqual(bytes.fromhex(j['program_hex']),program)
  self.assertEqual(j['metadata_mapping_bytes'],((2068+j['page_size']-1)//j['page_size'])*j['page_size']);self.assertEqual(j['program_mapping_bytes'],((n+j['page_size']-1)//j['page_size'])*j['page_size'])
  self.assertEqual(j['mapped_parts'],2 if device else 0);self.assertTrue(j['host_released']);self.assertFalse(j['dma_submitted']);self.assertFalse(j['program_submitted']);self.assertFalse(j['execution_tested'])
  self.assertEqual([(e['a'],e['b']) for e in events if e['op']=='actual_kernel_view'],[(0,2068),(1,n)])
  if device:
   self.assertEqual([e['a'] for e in events if e['op']=='map_effect'],[0,1]);self.assertEqual([e['a'] for e in events if e['op']=='unmap_effect'],[1,0])
   close=next(i for i,e in enumerate(events) if e['op']=='driver_closed');self.assertTrue(all(i>close for i,e in enumerate(events) if e['op'] in ('view_release_attempt','sealed_close_attempt')))
  self.assertEqual(sorted(e['a'] for e in events if e['op']=='view_released'),[0,1]);self.assertEqual(sorted(e['a'] for e in events if e['op']=='sealed_closed'),[0,1]);return j
 def refused(self,result,uncertain=False):
  p,events=result;self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
  if uncertain:
   self.assertIn('cleanup_unconfirmed',p.stdout+p.stderr);self.assertFalse(any(e['op'] in ('view_release_attempt','sealed_close_attempt') for e in events));self.assertEqual(sum(e['op']=='driver_close_attempt' for e in events),1)
  return events
 def recover(self):
  self.good(self.invoke(device=True),device=True);self.records[-1]['fresh_recovery_for_call']=len(self.records)-2
 def test_01_complete_two_parts_all_extents_actual_kernel_views(self):
  for n in (70,4097,16385):
   self.good(self.invoke(n),n);self.good(self.invoke(n,True),n,True)
 def test_02_arguments_and_preallocation_guards(self):
  for args in ([],['x'],['x',70,'-','-'],['host',69,'-','-'],['host','-1','-','-'],['host',70,'x','-'],['device',70,'','x']):
   events=self.refused(self.call(args));self.assertFalse(events);self.recover()
  p,events=self.call(['guards','-','-'],api=True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout)['guard_refusals'],12);self.assertFalse(any(e['op']=='driver_open_attempt' for e in events))
 def test_03_defaults_moves_and_independent_copies(self):
  p,events=self.call(['lifetime','-','-'],api=True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout),dict(moves_and_defaults=True,copy_survives_close=True,device_access=False))
 def test_04_partial_maps_replies_and_independent_cleanup(self):
  for fault in ['page_size','open','identity']+[prefix+str(i) for prefix in ('mmap','map_before','map_after','bad_tuple','bad_handle','unmap_before','unmap_after','munmap_before','munmap_after','sealed_close_before','sealed_close_after') for i in range(2)]:
   events=self.refused(self.invoke(device=True,fault=fault));
   if any(e['op']=='driver_opened' for e in events):
    close=next(i for i,e in enumerate(events) if e['op']=='driver_closed');self.assertTrue(all(i>close for i,e in enumerate(events) if e['op'] in ('view_release_attempt','sealed_close_attempt')))
   if fault=='page_size' or fault.startswith('mmap'):self.assertFalse(any(e['op']=='driver_open_attempt' for e in events))
   self.recover()
 def test_05_unconfirmed_finalization_retains_both_parts(self):
  for fault in ('close_before','close_after','identity_close_before','identity_close_after','unmap_close_before','unmap_close_after'):
   self.refused(self.invoke(device=True,fault=fault),True);self.recover()
 def test_06_poisoned_owner_refuses_repeated_use_without_retry(self):
  for fault in ('close_before','close_after','unmap_close_before','unmap_close_after'):
   p,events=self.call(['poison',self.sysfs,self.dev],fault,True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertIn('"poisoned_reuse_refusals":3',p.stdout);self.assertEqual(sum(e['op']=='driver_close_attempt' for e in events),1);self.assertFalse(any(e['op'] in ('view_release_attempt','sealed_close_attempt') for e in events));self.recover()
if __name__=='__main__':
 ap=argparse.ArgumentParser()
 for n in ('binary','api','faults','oracle','oracle-license','schema','protoc','evidence'):ap.add_argument('--'+n,required=True)
 CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
