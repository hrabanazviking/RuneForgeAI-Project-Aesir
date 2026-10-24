#!/usr/bin/env python3
"""Bounded host preflight or four-child physical map-only batch;never inference."""
import argparse,ctypes,hashlib,json,os,signal,struct,subprocess,sys,unittest
from pathlib import Path
CONFIG=argparse.Namespace()
STATE=None
H=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

class State:
 def __init__(self):
  self.out=Path(CONFIG.evidence).resolve();self.out.mkdir(exist_ok=False);self.runs=[]
  self.bins=json.loads(Path(CONFIG.binaries).read_text());self.expected={};self.codes={}
  for role,r in self.bins['images'].items():
   assert H(r['current'])==r['sha256'];assert H(r['frozen'])==r['frozen_sha256']
  for p,d in self.bins['source_hashes'].items():assert H(p)==d
  if CONFIG.phase=='host':
   self.sys=self.out/'sys';self.dev=self.out/'dev';self.dev.mkdir();node=self.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
   for p,s in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]:p.write_text(s+'\n')
   self.prepare_oracles()
  else:
   ready=Path(CONFIG.ready);r=json.loads(ready.read_text());assert r['host_passed'] and r['binary_manifest_sha256']==H(CONFIG.binaries)
   self.expected=r['expected'];self.codes=r['codes'];self.sys=Path('/sys');self.dev=Path('/dev')
   (self.out/'host-ready-identity.json').write_text(json.dumps(dict(path=str(ready),sha256=H(ready)),indent=2)+'\n')
   kernel=os.uname().release;assert kernel=='6.12.112-v8-16k-hailo+'
   version=Path('/sys/module/hailo1x_pci/version').read_text().strip();srcversion=Path('/sys/module/hailo1x_pci/srcversion').read_text().strip();assert version=='5.3.0' and srcversion=='91195A5A35A8DAAA5717B7D'
   note=Path('/sys/module/hailo1x_pci/notes/.note.gnu.build-id').read_bytes();(self.out/'live-build-id.note').write_bytes(note);namesz,descsz,kind=struct.unpack_from('<III',note);offset=12+(namesz+3)//4*4;buildid=note[offset:offset+descsz].hex();assert buildid=='380557783212772d9b067ff0163631a222c26d64'
   module=Path('/lib/modules')/kernel/'updates/dkms/hailo1x_pci.ko';assert H(module)=='756d58f7ffb51ca5999e09b7ae14b422b3b0450cf29d2cdabf8babc9491481e4'
   (self.out/'module-identity.json').write_text(json.dumps(dict(kernel=kernel,version=version,srcversion=srcversion,build_id=buildid,module_sha256=H(module),metadata_only=True),indent=2)+'\n')
 def prepare_oracles(self):
  from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
  o=self.bins['oracle_inputs'];assert H(o['schema'])=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225';assert H(o['hash_library'])=='eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031';assert H(o['hash_license'])=='a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
  schema=Path(o['schema']);pb=self.out/'rpc.pb';setup=self.call('protoc',['-I',str(schema.parent),'--descriptor_set_out='+str(pb),str(schema)],mock=False,trace=False);assert setup[2]==0 and not setup[1]
  pool=descriptor_pool.DescriptorPool()
  for f in descriptor_pb2.FileDescriptorSet.FromString(pb.read_bytes()).file:pool.Add(f)
  proto=message_factory.GetMessageClass(pool.FindMessageTypeByName('VDevice_CreateInferModel_Request'))
  lib=ctypes.CDLL(o['hash_library']);lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);lib.XXH3_64bits.restype=ctypes.c_uint64
  for n in (70,4097,16385):
   body=bytes((i*37+11)&255 for i in range(n-56));buf=ctypes.create_string_buffer(body);program=struct.pack('>IIIQQIQQQ',0x01484546,3,len(body),lib.XXH3_64bits(buf,len(body)),0,0,0,0,0)+body;p=proto();p.vdevice_handle.id=0;p.hef_size=n;p.name='session-two-part';raw=p.SerializeToString();metadata=struct.pack('<5I',0x8a554432,len(raw),17,2,1)+raw+bytes(2048-len(raw));self.expected[str(n)]=dict(metadata_hex=metadata.hex(),program_hex=program.hex())
  native_result=self.call('abi',['ioctls'],mock=False);header_result=self.call('oracle',['layout'],mock=False);assert native_result[2]==header_result[2]==0 and not native_result[1] and not header_result[1];native=json.loads(native_result[0]);header=json.loads(header_result[0]);names={'driver-info':'HAILO_QUERY_DRIVER_INFO','properties':'HAILO_QUERY_DEVICE_PROPERTIES','desc-create':'HAILO_DESC_LIST_CREATE','desc-release':'HAILO_DESC_LIST_RELEASE','connect':'HAILO_SOC_CONNECT','close':'HAILO_SOC_CLOSE','buffer-map':'HAILO_VDMA_BUFFER_MAP'}
  for k,v in names.items():assert native[k]==header[v]
  self.codes={k:native[k] for k in names}
 def one(self,role,args,label,fault,mock,trace):
  i=len(self.runs);image=self.bins['images'][role]['current' if label=='current' else 'frozen'];env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_') and k not in ('LD_PRELOAD','LD_AUDIT','LD_DEBUG')};log=self.out/f'{i}.events';tracefile=self.out/f'{i}.strace'
  if mock:env.update(LD_PRELOAD=self.bins['images']['faults']['current'],AESIR_SESSION_TRANSFER_FAULT=fault,AESIR_SESSION_TRANSFER_NODE=str(self.dev/'h1x-0'),AESIR_SESSION_TRANSFER_LOG=str(log))
  command=[image,*map(str,args)];actual=['strace','-f','-yy','-s','128','-o',str(tracefile),*command] if trace else command
  proc=subprocess.Popen(actual,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,start_new_session=True);timed_out=False;unresolved=False
  try:stdout,stderr=proc.communicate(timeout=20)
  except subprocess.TimeoutExpired:
   timed_out=True
   try:os.killpg(proc.pid,signal.SIGTERM)
   except ProcessLookupError:pass
   try:stdout,stderr=proc.communicate(timeout=3)
   except subprocess.TimeoutExpired:
    try:os.killpg(proc.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    try:stdout,stderr=proc.communicate(timeout=3)
    except subprocess.TimeoutExpired as error:stdout=error.output or b'';stderr=error.stderr or b'';unresolved=True
  (self.out/f'{i}.stdout').write_bytes(stdout);(self.out/f'{i}.stderr').write_bytes(stderr);events=[json.loads(x) for x in log.read_text().splitlines()] if log.exists() else []
  r=dict(role=role,label=label,arguments=command,returncode=proc.returncode,timed_out=timed_out,unresolved=unresolved,mock=mock,trace=str(tracefile) if trace else None,events=events,pid=proc.pid)
  self.runs.append(r);(self.out/'runs.json').write_text(json.dumps(self.runs,indent=2)+'\n')
  if timed_out or unresolved:raise RuntimeError('bounded child timed out;batch stopped;see exact retained observations')
  return stdout,stderr,proc.returncode,events
 def call(self,role,args,fault='none',mock=True,trace=True):
  p=self.one(role,args,'current',fault,mock,trace)
  if CONFIG.phase=='host':
   q=self.one(role,args,'frozen',fault,mock,trace);assert p[:3]==q[:3],(role,args,p[:3],q[:3])
  return p
 def good_probe(self,n):
  p=self.call('probe',[n,self.sys,self.dev],mock=CONFIG.phase=='host');assert p[2]==0 and not p[1],p[:3];j=json.loads(p[0]);e=self.expected[str(n)];assert all(j[k]==v for k,v in e.items())
  for k in ('same_file_group','context_finalized','host_released','closed_group_refused'):assert j[k]
  for k in ('hardware_idle_confirmed','remote_cleanup_confirmed','dma_submitted','program_submitted','execution_tested'):assert not j[k]
  assert j['group_count']==2 and j['allocated_descriptors_per_direction']==65536 and 0<=j['input_channel']<16 and 16<=j['output_channel']<32 and j['descriptor_page_size']==512
  assert j['driver_info']=={'major':5,'minor':3,'revision':0};assert j['properties']['board_type']==2 and j['properties']['dma_type']==0 and j['properties']['dma_engines_count']==1 and j['properties']['is_fw_loaded']
  page=j['page_size'];assert j['metadata_mapping_bytes']==((2068+page-1)//page)*page and j['program_mapping_bytes']==((n+page-1)//page)*page
  if CONFIG.phase=='host':assert sum(x['op']=='actual_kernel_view' for x in p[3])==2 and sum(x['op']=='both_views_cpu_inaccessible' for x in p[3])==1
  return j

class Host(unittest.TestCase):
 def test_01_baseline_and_all_three_probe_extents(self):
  p=STATE.call('session',[STATE.sys,STATE.dev]);self.assertEqual(p[2],0,p[:3]);self.assertTrue(json.loads(p[0])['connection_closed'])
  for n in (70,4097,16385):STATE.good_probe(n)
 def test_02_bounds_and_fresh_recovery(self):
  for args in ([],[69,STATE.sys,STATE.dev],['-1',STATE.sys,STATE.dev],['1'*100,STATE.sys,STATE.dev],[70,'',STATE.dev],[70,'x'*4096,STATE.dev]):
   p=STATE.call('probe',args);self.assertNotEqual(p[2],0);self.assertFalse(any(x['op']=='driver_opened' for x in p[3]));STATE.good_probe(70)
 def test_03_cleanup_faults_and_retained_actual_resources(self):
  for fault in ('map_after1','bad_tuple0','channel_after','close_before','close_after'):
   p=STATE.call('probe',[70,STATE.sys,STATE.dev],fault);self.assertNotEqual(p[2],0)
   exit_event=next(x for x in p[3] if x['op']=='actual_exit_resources');want=2 if fault.startswith('close_') else 0;self.assertEqual((exit_event['a'],exit_event['b']),(want,want));STATE.good_probe(70)

class Physical(unittest.TestCase):
 def test_single_four_child_map_only_batch(self):
  p=STATE.call('session',[STATE.sys,STATE.dev],mock=False);self.assertEqual(p[2],0,p[:3]);self.assertFalse(p[1]);self.assertTrue(json.loads(p[0])['connection_closed'])
  for n in (70,4097,16385):STATE.good_probe(n)
  self.assertEqual(len(STATE.runs),4)

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 for name in ('phase','binaries','evidence'):parser.add_argument('--'+name,required=True)
 parser.add_argument('--ready');CONFIG=parser.parse_args();assert CONFIG.phase in ('host','physical')
 STATE=State();suite=unittest.defaultTestLoader.loadTestsFromTestCase(Host if CONFIG.phase=='host' else Physical);result=unittest.TextTestRunner(verbosity=2).run(suite)
 if CONFIG.phase=='host' and result.wasSuccessful():
  ready=dict(host_passed=True,binary_manifest_sha256=H(CONFIG.binaries),expected=STATE.expected,codes=STATE.codes,methods=result.testsRun,runs=len(STATE.runs));(STATE.out/'ready.json').write_text(json.dumps(ready,indent=2)+'\n')
 raise SystemExit(0 if result.wasSuccessful() else 1)
