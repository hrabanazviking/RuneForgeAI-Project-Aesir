#!/usr/bin/env python3
"""Original same-file grouped control tests. HOST MOCKS ONLY;never physical RPC."""
import argparse,hashlib,json,os,signal,struct,subprocess,sys,unittest
from pathlib import Path
CONFIG=argparse.Namespace()
class GroupControl(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.runs=[];cls.bins=json.loads(Path(CONFIG.binaries).read_text());cls.sys=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir();node=cls.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
  for p,s in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]:p.write_text(s+'\n')
  for r in cls.bins.values():
   for name in ('current','frozen'):assert hashlib.sha256(Path(r[name]).read_bytes()).hexdigest()==r['sha256']
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.runs,indent=2)+'\n')
 def invoke(self,role,args,*,fault='none',body=0,input_count=7,output_count=5,generation=0,close='none'):
  results=[]
  for label in ('current','frozen'):
   i=len(self.runs);log=self.out/f'{i}.events';trace=self.out/f'{i}.strace';env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_') and k not in ('LD_PRELOAD','LD_AUDIT','LD_DEBUG')};env.update(LD_PRELOAD=self.bins['faults'][label],AESIR_GROUP_NODE=str(self.dev/'h1x-0'),AESIR_GROUP_LOG=str(log),AESIR_GROUP_FAULT=fault,AESIR_GROUP_CLOSE=close,AESIR_GROUP_BODY=str(body),AESIR_GROUP_INPUT_COUNT=str(input_count),AESIR_GROUP_OUTPUT_COUNT=str(output_count))
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
   events=[json.loads(s) for s in log.read_text().splitlines()] if log.exists() else [];r=dict(role=role,label=label,arguments=cmd,fault=fault,body=body,input_count=input_count,output_count=output_count,fault_generation=generation,close=close,returncode=proc.returncode,events=events,trace=str(trace),timed_out=timed_out,unresolved=unresolved,physical_calls=False);self.runs.append(r);(self.out/'runs.json').write_text(json.dumps(self.runs,indent=2)+'\n')
   self.assertFalse(timed_out or unresolved,(role,fault,stdout,stderr));self.assertFalse(any(e['op'].startswith('unsafe') or e['op']=='forbidden_ioctl' for e in events));self.assertTrue(all(e['tid'] in {int(line.split()[0]) for line in trace.read_text().splitlines() if line.split() and line.split()[0].isdigit()} for e in events))
   results.append((proc.returncode,stdout,stderr,events))
  self.assertEqual(results[0][:3],results[1][:3],(role,args,fault,results))
  return results[0]
 def probe(self,n=0,count=1,**kwargs):return self.invoke('probe',['host-mock',self.sys,self.dev,n,count],body=n,**kwargs)
 def json(self,p):return json.loads(next(s for s in p[1].decode().splitlines() if s.startswith('{')))
 def good(self,n=0,count=1,**kwargs):
  p=self.probe(n,count,**kwargs);self.assertEqual(p[:1]+p[2:3],(0,b''),p[:3]);j=self.json(p);self.assertEqual(j['exchanges'],count);self.assertEqual(j['input_count'],kwargs.get('input_count',7));self.assertEqual(j['output_count'],kwargs.get('output_count',5));self.assertEqual(j['replies'],[bytes((i*29+7)%256 for i in range(n)).hex()]*count);self.assertFalse(j['physical_calls'])
  wires=[e for e in p[3] if e['op']=='wire'];self.assertEqual(len(wires),count)
  for seq,e in enumerate(wires):self.assertEqual(bytes.fromhex(e['hex']),struct.pack('<5I',0x8a554432,n,seq,1,1)+bytes((i*29+7)%256 for i in range(n))+bytes(2048-n))
  self.assertEqual(sum(e['op']=='launch_effect' for e in p[3]),count*2);return p
 def poison(self,fault='none',timeout=1000,retained=0,**kwargs):
  p=self.invoke('api',['poison',self.sys,self.dev,timeout],fault=fault,generation=1,**kwargs);self.assertEqual(p[0],0,p[:3]);j=self.json(p);self.assertEqual(j['poison_refusals'],4);self.assertEqual(j['retained'],retained);self.assertEqual(j['fresh_recovery'],retained==0);self.assertTrue(j['primary_hex']);self.assertFalse(j['physical_calls']);return p
 def test_01_exact_empty_boundary_and_maximum_frames(self):
  for n in (0,1,19,20,21,2047,2048):
   for count in (1,3):self.good(n,count)
 def test_02_actual_asymmetric_count_boundaries(self):
  for i,o in ((1,1),(1,65535),(65535,1),(65535,65535),(7,5)):self.good(input_count=i,output_count=o)
  for name in ('input_count','output_count'):
   for v in (-1,0,65536,2147483647):self.poison(**{name:v});self.good()
 def test_03_all_sync_launch_and_reply_faults(self):
  faults=[f'{stage}{i}' for stage in ('sync_before','sync_after') for i in range(1,5)]+[f'{stage}{i}' for stage in ('launch_before','launch_after') for i in (1,2)]+['enable_before','enable_after','wait_before','wait_after','reply_magic','reply_size','reply_id','reply_action','reply_status']
  for fault in faults:self.poison(fault);self.good()
 def test_04_irq_atomicity_partial_duplicates_and_budget(self):
  self.good(fault='partial',count=3)
  for fault in ('duplicate','empty','irq_foreign','irq_count','irq_error','irq_mask','irq_engine'):
   self.poison(fault);self.good()
 def test_05_total_deadline_at_every_observed_stage(self):
  p=self.good();clocks=sum(e['op']=='clock' for e in p[3]);self.assertGreater(clocks,12)
  for n in range(2,clocks+1):
   for prefix in ('late','back','clock_error'):self.poison(prefix+str(n));self.good()
  self.poison('clock_error1');self.good()
  for timeout in (0,-1,60001):self.poison(timeout=timeout);self.good()
  self.poison('wait_stall');self.good()
 def test_06_partial_construction_and_cleanup_faults(self):
  for fault in ('open','identity','desc0','desc1','connect_before','connect_after','allocate0','allocate1','map_before0','map_before1','map_after0','map_after1','map_reply0','map_reply1'):
   p=self.probe(fault=fault);self.assertNotEqual(p[0],0,p[:3]);self.good()
  for fault in ('channel_before','channel_after','unmap_before0','unmap_before1','unmap_after0','unmap_after1','desc_release0','desc_release1','munmap_before0','munmap_before1','munmap_after0','munmap_after1'):
   p=self.probe(fault=fault);self.assertNotEqual(p[0],0,p[:3]);self.good()
  for fault in ('close_before','close_after'):
   q=self.probe(fault=fault);self.assertNotEqual(q[0],0,q[:3]);self.good()
   p=self.poison(fault,timeout=0,retained=2);self.assertEqual(sum(e['op']=='file_close_attempt' for e in p[3]),1);self.assertFalse(any(e['op']=='release_attempt' for e in p[3]));self.good()
 def test_07_effectful_failure_with_uncertain_close(self):
  for fault in ('launch_after1','launch_after2','wait_before','sync_after4','reply_id'):
   for close in ('before','after'):
    p=self.poison(fault,retained=2,close=close);self.assertEqual(sum(e['op']=='file_close_attempt' for e in p[3]),1);self.assertFalse(any(e['op']=='release_attempt' for e in p[3]));self.good()
 def test_08_direct_move_copy_guard_scope_and_recovery(self):
  p=self.invoke('api',['lifetime',self.sys,self.dev,1000]);self.assertEqual(p[:1]+p[2:3],(0,b''),p[:3]);self.assertEqual(self.json(p),dict(guard_refusals=10,fresh_recovery=True,physical_calls=False))
 def test_09_preflight_poison_and_six_fresh_recoveries(self):
  p=self.invoke('api',['preflight',self.sys,self.dev,1000]);self.assertEqual(p[:1]+p[2:3],(0,b''),p[:3]);j=self.json(p);self.assertEqual(j['preflight_refusals'],6);self.assertEqual(j['fresh_recoveries'],6);self.assertEqual(len(j['errors']),6);self.assertTrue(all(j['errors']))
 def test_10_argument_guards_no_effects(self):
  for args in ([],['host-mock','/sys','/dev','0','1'],['host-mock',self.sys,self.dev,'2049','1'],['host-mock',self.sys,self.dev,'1'*30,'1'],['host-mock',self.sys,self.dev,'0','0'],['host-mock','',self.dev,'0','1']):
   p=self.invoke('probe',args);self.assertNotEqual(p[0],0);self.assertFalse(p[3]);self.good()
if __name__=='__main__':
 p=argparse.ArgumentParser()
 for name in ('binaries','evidence'):p.add_argument('--'+name,required=True)
 CONFIG,remaining=p.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
