#!/usr/bin/env python3
"""Independent same-file provenance and actual-kernel ownership checks;mock only."""
import argparse,ctypes,hashlib,json,os,struct,subprocess,sys,unittest
from pathlib import Path
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
CONFIG=argparse.Namespace()
class SessionPin(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.records=[]
  cls.sys=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir();node=cls.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
  for p,s in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]:p.write_text(s+'\n')
  lib=Path(CONFIG.oracle).resolve(strict=True);assert hashlib.sha256(lib.read_bytes()).hexdigest()=='eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031';assert hashlib.sha256(Path(CONFIG.oracle_license).read_bytes()).hexdigest()=='a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
  cls.lib=ctypes.CDLL(str(lib));cls.lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);cls.lib.XXH3_64bits.restype=ctypes.c_uint64
  schema=Path(CONFIG.schema).resolve(strict=True);assert hashlib.sha256(schema.read_bytes()).hexdigest()=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225'
  pb=cls.out/'rpc.pb';subprocess.run([CONFIG.protoc,'-I',str(schema.parent),'--descriptor_set_out='+str(pb),str(schema)],capture_output=True,check=True)
  pool=descriptor_pool.DescriptorPool()
  for f in descriptor_pb2.FileDescriptorSet.FromString(pb.read_bytes()).file:pool.Add(f)
  cls.proto=message_factory.GetMessageClass(pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
 def call(self,args,fault='none',api=False):
  i=len(self.records);log=self.out/f'{i}.events';trace=self.out/f'{i}.strace';env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_')};env.pop('LD_PRELOAD',None)
  env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_SESSION_TRANSFER_FAULT=fault,AESIR_SESSION_TRANSFER_NODE=str(self.dev/'h1x-0'),AESIR_SESSION_TRANSFER_LOG=str(log))
  cmd=[str(Path(CONFIG.api if api else CONFIG.binary).resolve()),*map(str,args)]
  p=subprocess.run(['strace','-f','-yy','-s','300','-o',str(trace),*cmd],env=env,capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=15)
  events=[json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []
  self.records.append(dict(arguments=cmd,fault=fault,api=api,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,events=events,trace=str(trace),physical_evidence=False))
  self.assertFalse(any(e['op'].startswith('unsafe_') or e['op']=='forbidden_ioctl' for e in events));return p,events
 def invoke(self,n=70,fault='none'):return self.call(['mock',n,self.sys,self.dev],fault)
 def bytes(self,n):
  body=bytes((i*37+11)&255 for i in range(n-56));buf=ctypes.create_string_buffer(body);checksum=self.lib.XXH3_64bits(buf,len(body));program=struct.pack('>IIIQQIQQQ',0x01484546,3,len(body),checksum,0,0,0,0,0)+body
  proto=self.proto();proto.vdevice_handle.id=0;proto.hef_size=n;proto.name='session-two-part';payload=proto.SerializeToString();metadata=struct.pack('<5I',0x8a554432,len(payload),17,2,1)+payload+bytes(2048-len(payload));return metadata,program
 def good(self,result,n=70):
  p,events=result;self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);j=json.loads(p.stdout);metadata,program=self.bytes(n)
  self.assertEqual(bytes.fromhex(j['metadata_hex']),metadata);self.assertEqual(bytes.fromhex(j['program_hex']),program)
  self.assertEqual(j['metadata_mapping_bytes'],((2068+j['page_size']-1)//j['page_size'])*j['page_size']);self.assertEqual(j['program_mapping_bytes'],((n+j['page_size']-1)//j['page_size'])*j['page_size'])
  self.assertTrue(j['same_file_group'] and j['context_finalized'] and j['host_released']);self.assertEqual(j['group_count'],2)
  for key in ('hardware_idle_confirmed','remote_cleanup_confirmed','dma_submitted','execution_tested'):self.assertFalse(j[key])
  self.assertEqual([(e['a'],e['b']) for e in events if e['op']=='actual_kernel_view'],[(0,2068),(1,n)])
  opened=[e for e in events if e['op']=='driver_opened'];self.assertEqual(len(opened),1);generation=opened[0]['b'];fd=opened[0]['a']
  self.assertEqual([(e['a'],e['b'],e['c']) for e in events if e['op']=='map_file_generation'],[(0,fd,generation),(1,fd,generation)])
  self.assertEqual([(e['a'],e['c']) for e in events if e['op']=='connected'],[(3,generation)])
  self.assertEqual(sum(e['op']=='both_views_cpu_inaccessible' for e in events),1)
  close=next(i for i,e in enumerate(events) if e['op']=='driver_closed')
  self.assertTrue(all(i>close for i,e in enumerate(events) if e['op'] in ('view_release_attempt','sealed_close_attempt')))
  exit_event=[e for e in events if e['op']=='actual_exit_resources'];self.assertEqual(len(exit_event),1);self.assertEqual((exit_event[0]['a'],exit_event[0]['b']),(0,0));return j
 def refused(self,result,uncertain=False):
  p,events=result;self.assertNotEqual(p.returncode,0,p.stdout+p.stderr)
  if uncertain:
   self.assertIn('cleanup_unconfirmed',p.stdout+p.stderr);self.assertEqual(sum(e['op']=='driver_close_attempt' for e in events),1)
   self.assertFalse(any(e['op'] in ('view_release_attempt','sealed_close_attempt') for e in events));exit_event=next(e for e in events if e['op']=='actual_exit_resources');self.assertEqual((exit_event['a'],exit_event['b']),(2,2))
   self.assertEqual([(e['a'],e['b'],e['c']) for e in events if e['op']=='actual_exit_part'],[(0,1,1),(1,1,1)])
  return events
 def recover(self):
  self.good(self.invoke());self.records[-1]['fresh_recovery_for_call']=len(self.records)-2
 def test_01_full_bytes_same_file_context_and_cpu_inaccessibility(self):
  for n in (70,4097,16385):self.good(self.invoke(n),n)
 def test_02_arguments_and_direct_constructor_group_guards(self):
  for args in ([],['mock'],['device',70,self.sys,self.dev],['mock',69,self.sys,self.dev],['mock','-1',self.sys,self.dev],['mock','1'*100,self.sys,self.dev],['mock',70,'',self.dev],['mock',70,'x'*4096,self.dev]):
   events=self.refused(self.call(args));self.assertFalse(any(e['op']=='driver_opened' for e in events));self.recover()
  p,events=self.call(['guards',self.sys,self.dev],api=True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout),dict(guard_refusal_recovery_cycles=22,physical_calls=False))
 def test_03_moves_scope_defaults_and_finalized_refusal(self):
  p,events=self.call(['lifetime',self.sys,self.dev],api=True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout),dict(moves_scope_defaults_and_repeat_close=True,finalized_group_refused=True))
 def test_04_partial_open_maps_wrong_replies_and_host_cleanup_faults(self):
  faults=['page_size','open','identity','desc_create0','desc_create1','connect_before','connect_after','foreign_desc','foreign_map','desc_create2_cleanup']+[prefix+str(i) for prefix in ('mmap','map_before','map_after','bad_tuple','bad_handle','munmap_before','munmap_after','sealed_close_before','sealed_close_after') for i in range(2)]
  for fault in faults:
   events=self.refused(self.invoke(fault=fault))
   if any(e['op']=='driver_opened' for e in events):
    closed=next(i for i,e in enumerate(events) if e['op']=='driver_closed');self.assertTrue(all(i>closed for i,e in enumerate(events) if e['op'] in ('view_release_attempt','sealed_close_attempt')))
   if fault=='desc_create2_cleanup':self.assertNotIn('cleanup_unconfirmed',self.records[-1]['stdout']+self.records[-1]['stderr']);self.assertEqual(sum(e['op']=='view_released' for e in events),2)
   self.recover()
 def test_05_confirmed_file_close_preserves_prior_cleanup_error(self):
  for fault in ('channel_before','channel_after','desc_release0','desc_release1'):
   p,events=self.call(['cleanup',self.sys,self.dev],fault,True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout),dict(cleanup_error_preserved=True,file_close_confirmed=True,host_released=True,hardware_idle_confirmed=False));self.assertEqual(sum(e['op']=='driver_close_attempt' for e in events),1);self.recover()
 def test_06_uncertain_file_close_retains_two_actual_fds_and_vmas(self):
  for fault in ('close_before','close_after','identity_close_before','identity_close_after','map_close_before','map_close_after'):
   self.refused(self.invoke(fault=fault),True);self.recover()
 def test_07_poisoned_reuse_never_retries_close_or_releases_backing(self):
  for fault in ('close_before','close_after'):
   p,events=self.call(['poison',self.sys,self.dev],fault,True);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);j=json.loads(next(line for line in p.stdout.splitlines() if line.startswith('{')));self.assertEqual(j,dict(poisoned_reuse_refusals=4,explicit_host_releases=0));self.assertEqual(sum(e['op']=='driver_close_attempt' for e in events),1);exit_event=next(e for e in events if e['op']=='actual_exit_resources');self.assertEqual((exit_event['a'],exit_event['b']),(2,2));self.recover()
if __name__=='__main__':
 ap=argparse.ArgumentParser()
 for n in ('binary','api','faults','oracle','oracle-license','schema','protoc','evidence'):ap.add_argument('--'+n,required=True)
 CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
