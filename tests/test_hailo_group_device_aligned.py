#!/usr/bin/env python3
"""Original typed grouped lifecycle tests over ALIGNED backing. HOST MOCKS ONLY;never physical RPC."""
import argparse,hashlib,json,os,signal,struct,subprocess,sys,unittest
from pathlib import Path
CONFIG=argparse.Namespace()
from test_hailo_hrpc_device import MESSAGES
class GroupDeviceAligned(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.runs=[];cls.bins=json.loads(Path(CONFIG.binaries).read_text());cls.sys=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir();node=cls.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
  for p,s in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]:p.write_text(s+'\n')
  for r in cls.bins.values():
   for name in ('current','frozen'):assert hashlib.sha256(Path(r[name]).read_bytes()).hexdigest()==r['sha256']
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.runs,indent=2)+'\n')
 def invoke(self,role,args,*,fault='none',body=0,input_count=7,output_count=5,generation=1,close='none',handle=0,typed=None,phase=0):
  fixtures=self.fixtures(handle,typed)
  results=[]
  for label in ('current','frozen'):
   i=len(self.runs);log=self.out/f'{i}.events';trace=self.out/f'{i}.strace';env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_') and k not in ('LD_PRELOAD','LD_AUDIT','LD_DEBUG')};env.update(LD_PRELOAD=self.bins['faults'][label],AESIR_GROUP_NODE=str(self.dev/'h1x-0'),AESIR_GROUP_LOG=str(log),AESIR_GROUP_FAULT=fault,AESIR_GROUP_CLOSE=close,AESIR_GROUP_BODY=str(body),AESIR_GROUP_INPUT_COUNT=str(input_count),AESIR_GROUP_OUTPUT_COUNT=str(output_count))
   env.update(fixtures);env['AESIR_DEVICE_PHASE']=str(phase) if phase else '';
   if generation:env['AESIR_GROUP_FAULT_GENERATION']=str(generation)
   cmd=[self.bins[role][label],*map(str,args)];actual=['strace','-f','-yy','-s','300','-o',str(trace),*cmd];proc=subprocess.Popen(actual,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,start_new_session=True);timed_out=False;unresolved=False
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
     except subprocess.TimeoutExpired as exc:stdout=exc.output or b'';stderr=exc.stderr or b'';unresolved=True
   for channel,data in [('stdout',stdout),('stderr',stderr)]:(self.out/f'{i}.{channel}').write_bytes(data)
   events=[json.loads(s) for s in log.read_text().splitlines()] if log.exists() else [];r=dict(role=role,label=label,arguments=cmd,fault=fault,body=body,input_count=input_count,output_count=output_count,fault_generation=generation,close=close,handle=handle,typed=typed,phase=phase,fixtures=fixtures,returncode=proc.returncode,events=events,trace=str(trace),timed_out=timed_out,unresolved=unresolved,physical_calls=False);self.runs.append(r);(self.out/f'{i}.record.json').write_text(json.dumps(r,indent=2)+'\n')
   self.assertFalse(timed_out or unresolved,(role,fault,stdout,stderr));self.assertFalse(any(e['op'].startswith('unsafe') or e['op']=='forbidden_ioctl' for e in events));self.assertTrue(all(e['tid'] in {int(line.split()[0]) for line in trace.read_text().splitlines() if line.split() and line.split()[0].isdigit()} for e in events))
   results.append((proc.returncode,stdout,stderr,events))
  self.assertEqual(results[0][:3],results[1][:3],(role,args,fault,results))
  return results[0]
 def fixtures(self,handle,typed=None):
  def frame(mid,action,body,status=0):return (struct.pack('<5I',0x8a554432,len(body),mid,action,status)+body+bytes(2048-len(body))).hex()
  create=MESSAGES['CreateReply']();create.device_handle.id=handle
  identify=MESSAGES['IdentifyReply']();identity=identify.identity;identity.protocol_version=2;identity.fw_version.major=5;identity.fw_version.minor=3;identity.fw_version.revision=7;identity.logger_version=4;identity.architecture=6
  destroy=MESSAGES['DestroyReply']();handle_request=MESSAGES['HandleRequest']();handle_request.device_handle.id=handle
  requests=[b'',handle_request.SerializeToString(),handle_request.SerializeToString(),handle_request.SerializeToString()]
  replies=[create.SerializeToString(),identify.SerializeToString(),destroy.SerializeToString(),destroy.SerializeToString()]
  actions=[20,22,21,21];env={}
  for i in range(4):env['AESIR_DEVICE_REQUEST'+str(i)]=frame(i,actions[i],requests[i],1);env['AESIR_DEVICE_GOODREPLY'+str(i)]=frame(i,actions[i],replies[i])
  if typed:
   for i,raw in typed.items():replies[int(i)]=bytes.fromhex(raw)
  for i in range(4):env['AESIR_DEVICE_REPLY'+str(i)]=frame(i,actions[i],replies[i])
  return env
 def call(self,*,recover=False,timeout=1000,**kw):
  return self.invoke('api' if recover else 'probe',['recover' if recover else 'host-mock-aligned',self.sys,self.dev,timeout],**kw)
 def data(self,p):return [json.loads(s) for s in p[1].decode().splitlines() if s.startswith('{')]
 def state(self,p,*,success=False,known=False,destroy=False,confirmed=False,cleanup=False,attempts=None,poisoned=False,retained=0):
  j=self.data(p)[0];self.assertEqual(j['success'],success);self.assertEqual(j['handle_known'],known);self.assertEqual(j['destroy_attempted'],destroy);self.assertEqual(j['destroy_confirmed'],confirmed);self.assertEqual(j['cleanup_attempted'],cleanup);self.assertEqual(j['poisoned'],poisoned);self.assertEqual(j['retained_views'],retained)
  if attempts is not None:self.assertEqual(j['attempts'],attempts)
  self.assertLessEqual(j['attempts'],4);self.assertFalse(j['physical_calls']);return j
 def good(self,**kw):
  p=self.call(**kw);self.assertEqual(p[:1]+p[2:3],(0,b''));j=self.state(p,success=True,known=True,destroy=True,confirmed=True,attempts=3);self.assertEqual(j['handle'],kw.get('handle',0));self.assertEqual(j['identity'],[2,5,3,7,4,6]);self.assertTrue(j['identity_present'] and j['firmware_present']);self.assertFalse(j['primary_hex'] or j['cleanup_hex'] or j['close_hex']);self.wires(p);maps=[e for e in p[3] if e['op']=='map_effect' and e['generation']==1];self.assertEqual([(e['a'],e['c']) for e in maps],[(0,2560),(1,2068)]);return p
 def wires(self,p):
  fixtures=self.runs[-2]['fixtures'];events=p[3]
  for key,prefix in [('wire','REQUEST'),('reply_wire','REPLY')]:
   for e in events:
    if e['op']!=key:continue
    packet=bytes.fromhex(e['hex']);mid=struct.unpack_from('<I',packet,8)[0];self.assertEqual(e['hex'],fixtures['AESIR_DEVICE_'+('GOODREPLY' if prefix=='REPLY' and e['generation']>1 else prefix)+str(mid)])
 def test_01_zero_boundary_and_nonzero_handles(self):
  for h in (0,1,127,128,16383,16384,0x7fffffff,0xffffffff):self.good(handle=h)
 def test_02_typed_create_presence_and_corruption(self):
  for raw in ('','00','0a0108','0a0608ffffffff1f','0a0408010802','0a000a00','0a0100'):
   p=self.call(typed={'0':raw},recover=True);j=self.state(p,attempts=1);self.assertTrue(j['primary_hex']);self.assertEqual(len(self.data(p)),2);self.assertTrue(self.data(p)[1]['success']);self.assertEqual(sum(e['op']=='wire' and e['generation']==1 for e in p[3]),1)
 def test_03_identify_typed_failure_and_single_cleanup(self):
  for raw in ('','00','0a0108','0a0408010802','0a021001','0a0412010012','0a0418011802'):
   for h in (0,0xffffffff):
    p=self.call(typed={'1':raw},handle=h,recover=True);j=self.state(p,known=True,destroy=True,confirmed=True,cleanup=True,attempts=3);self.assertTrue(j['primary_hex']);self.assertFalse(j['cleanup_hex']);self.assertTrue(self.data(p)[1]['success']);self.wires(p);self.assertEqual([struct.unpack_from('<I',bytes.fromhex(e['hex']),8)[0] for e in p[3] if e['op']=='wire' and e['generation']==1],[0,1,3])
 def test_04_destroy_attempt_never_retried(self):
  for raw in ('00','08','0b','0a02ff'):
   p=self.call(typed={'2':raw},recover=True);j=self.state(p,known=True,destroy=True,attempts=3);self.assertTrue(j['primary_hex']);self.assertFalse(j['cleanup_hex']);self.assertTrue(self.data(p)[1]['success']);self.assertEqual(sum(e['op']=='wire' and e['generation']==1 for e in p[3]),3)
 def test_05_cleanup_failure_preserves_primary(self):
  for raw in ('00','08','0b'):
   p=self.call(typed={'1':'00','3':raw},recover=True);j=self.state(p,known=True,destroy=True,cleanup=True,attempts=3);self.assertTrue(j['primary_hex'] and j['cleanup_hex']);self.assertTrue(self.data(p)[1]['success'])
 def test_06_each_phase_wire_faults_and_poison(self):
  for phase in (1,2,3):
   for fault in ('reply_magic','reply_size','reply_id','reply_action','reply_status','wait_before','wait_after','enable_before','enable_after','irq_foreign','irq_count','irq_error','irq_mask','irq_engine','empty','duplicate'):
    if phase>1 and fault.startswith('enable_'):continue  # Enable occurs only once,on the fresh owner.
    p=self.call(fault=fault,phase=phase,recover=True);j=self.state(p,known=phase>1,destroy=phase==3,attempts=phase,poisoned=True);self.assertTrue(j['primary_hex']);self.assertFalse(j['cleanup_attempted']);self.assertTrue(self.data(p)[1]['success'])
 def test_07_effect_faults_in_every_exchange(self):
  for phase in (1,2,3):
   for local in range(1,5):
    for prefix in ('sync_before','sync_after'):
     fault=prefix+str((phase-1)*4+local);p=self.call(fault=fault,recover=True);self.assertNotEqual(self.data(p)[0]['primary_hex'],'');self.assertFalse(self.data(p)[0]['destroy_confirmed']);self.assertTrue(self.data(p)[1]['success'])
   for local in (1,2):
    for prefix in ('launch_before','launch_after'):
     p=self.call(fault=prefix+str((phase-1)*2+local),recover=True);self.assertTrue(self.data(p)[0]['poisoned']);self.assertTrue(self.data(p)[1]['success'])
 def test_08_one_total_deadline_all_clocks(self):
  good=self.good();clocks=[e['a'] for e in good[3] if e['op']=='clock'];self.assertGreater(len(clocks),50)
  for n in clocks:
   for prefix in ('late','back','clock_error'):
    # A jump on the initial sample defines a later origin,not an expired budget.
    if n==1 and prefix in ('late','back'):continue
    p=self.call(fault=prefix+str(n),recover=True);j=self.data(p)[0];self.assertTrue(j['primary_hex'],(n,prefix,j));self.assertFalse(j['destroy_confirmed']);self.assertTrue(self.data(p)[1]['success']);self.assertLessEqual(j['attempts'],3)
  for timeout in (0,-1,60001):
   p=self.call(timeout=timeout,recover=True);self.state(p,attempts=0);self.assertTrue(self.data(p)[1]['success'])
 def test_09_cleanup_deadline_and_poisoned_cleanup(self):
  for fault in ('reply_id','launch_after6','wait_before','sync_after12'):
   p=self.call(typed={'1':'00'},fault=fault,phase=3,recover=True);j=self.state(p,known=True,destroy=True,cleanup=True,attempts=3,poisoned=True);self.assertTrue(j['primary_hex'] and j['cleanup_hex']);self.assertTrue(self.data(p)[1]['success'])
  p=self.call(typed={'1':'00'},recover=True);clocks=[e['a'] for e in p[3] if e['op']=='clock' and e['generation']==1]
  for n in clocks:
   q=self.call(typed={'1':'00'},fault='late'+str(n),recover=True)
   if n>1:self.assertFalse(self.data(q)[0]['destroy_confirmed'])
 def test_10_counts_partial_irqs_and_stalled_worker(self):
  self.good(fault='partial')
  for i,o in ((1,65535),(65535,1),(65535,65535)):self.good(input_count=i,output_count=o)
  for key in ('input_count','output_count'):
   for value in (-1,0,65536):
    p=self.call(recover=True,**{key:value});self.assertTrue(self.data(p)[0]['poisoned']);self.assertTrue(self.data(p)[1]['success'])
  p=self.call(fault='wait_stall',recover=True);self.assertTrue(self.data(p)[0]['primary_hex']);self.assertTrue(self.data(p)[1]['success'])
 def test_11_uncertain_close_retains_actual_views(self):
  for fault,typed in (('none',None),('launch_after2',None),('none',{'1':'00'})):
   for close in ('before','after'):
    p=self.call(fault=fault,typed=typed,close=close,recover=True);j=self.data(p)[0];self.assertEqual(len(self.data(p)),1);self.assertTrue(j['close_hex']);self.assertTrue(j['finalization_unconfirmed']);self.assertEqual(j['retained_views'],2);self.assertEqual(sum(e['op']=='file_close_attempt' for e in p[3]),1);self.assertFalse(any(e['op']=='release_attempt' for e in p[3]));self.assertEqual(sum(e['b'] for e in p[3] if e['op']=='exit_view'),2)
 def test_12_local_clock_and_argument_admission(self):
  for start,budget,now,expected in ((10,100,10,100),(10,100,109,1),(0,60000,1,59999),(9223372036854715807,60000,9223372036854775806,1)):
   p=self.invoke('api',['clock',start,budget,now]);self.assertEqual(p[0],0);self.assertEqual(self.data(p)[0]['remaining'],expected);self.assertFalse(p[3])
  for start,budget,now in ((-1,1,0),(0,0,0),(0,-1,0),(0,60001,0),(9223372036854775807,1,0),(10,100,9),(10,100,-1),(10,100,110)):
   p=self.invoke('api',['clock',start,budget,now]);self.assertNotEqual(p[0],0);self.assertFalse(p[3])
  for args in ([],['host-mock-aligned','/sys','/dev','1000'],['host-mock-aligned',self.sys,self.dev,'1'*30],['host-mock-aligned','',self.dev,'1000']):
   p=self.invoke('probe',args);self.assertNotEqual(p[0],0);self.assertFalse(p[3])
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ('binaries','evidence'):p.add_argument('--'+name,required=True)
 CONFIG,remaining=p.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
