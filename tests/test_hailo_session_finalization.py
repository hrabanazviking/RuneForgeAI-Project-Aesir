#!/usr/bin/env python3
"""Mock-only original session lifetime qualification;never device evidence."""
import argparse,json,os,subprocess,sys,unittest
from pathlib import Path
CONFIG=argparse.Namespace()
class Finalization(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.records=[];cls.sys=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir();node=cls.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
  for p,s in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]:p.write_text(s+'\n')
  cls.current=json.loads(Path(CONFIG.binaries).read_text());cls.old=json.loads(Path(CONFIG.frozen).read_text())
 @classmethod
 def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
 def invoke(self,binary,args,stage='none',close='none',label='current',retention=True):
  i=len(self.records);log=self.out/f'{i}.events';trace=self.out/f'{i}.strace';env={k:v for k,v in os.environ.items() if not k.startswith(('AESIR_PIN_','AESIR_SESSION_'))};env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_SESSION_NODE=str(self.dev/'h1x-0'),AESIR_SESSION_LOG=str(log),AESIR_SESSION_STAGE=stage,AESIR_SESSION_CLOSE=close)
  if retention:env['AESIR_SESSION_REQUIRE_RETENTION']='1'
  cmd=[str(binary),*map(str,args)];p=subprocess.run(['/usr/bin/strace','-f','-y','-s','300','-o',str(trace),*cmd],capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL,env=env)
  events=[json.loads(x) for x in log.read_text().splitlines()] if log.exists() else [];self.records.append(dict(arguments=cmd,stage=stage,close=close,label=label,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,events=events,physical_evidence=False,trace=str(trace)));return p,events
 def api(self,stage='none',close='none',pending=False):
  p,events=self.invoke(self.current['tests/hailo_session_finalization_api.mojo'],[self.sys,self.dev,'pending' if pending else 'idle','confirmed' if close=='none' else 'uncertain'],stage,close)
  self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);j=json.loads(next(x for x in p.stdout.splitlines() if x.startswith('{')));self.assertFalse(j['physical_evidence']);self.assertFalse(j['dma_submitted']);self.assertEqual(j['uncertain'],close!='none')
  allocated=[e for e in events if e['op']=='owner_allocated' and e['a']!=-1];released=[e for e in events if e['op']=='owner_release_attempt'];attempts=[e for e in events if e['op']=='driver_close_attempt'];self.assertEqual(len(attempts),1)
  if close!='none':
   self.assertFalse(released);self.assertEqual(j['allocated'],len(allocated));self.assertIn('driver fd close',bytes.fromhex(j['cleanup_hex']).decode());self.assertEqual(j['reuse_refusals'],8 if allocated else 6)
  else:
   self.assertEqual(len(allocated),len(released));self.assertTrue(all(e['context_closed'] for e in released))
  self.assertFalse(any(e['op']=='forbidden_mock_ioctl' for e in events));return j
 def test_normal_and_moved_pending_recovery(self):
  for pending in (False,True):self.api(pending=pending)
 def test_close_uncertainty_with_all_cleanup_stages(self):
  for close in ('before','after'):
   for stage in ('none','map1','map2','map_after1','map_after2','bad_reply1','bad_reply2','unmap1','unmap2','channel','desc1','desc2','allocate1','allocate2'):
    j=self.api(stage,close,pending=stage=='none');self.assertTrue(j['cleanup_hex'])
    if stage in ('unmap1','unmap2','channel','desc1','desc2'):self.assertIn('Failed',bytes.fromhex(j['cleanup_hex']).decode())
    self.api()
 def test_partial_storage_cleanup_with_confirmed_close(self):
  for stage in ('allocate1','allocate2','map1','map2','map_after1','map_after2','bad_reply1','bad_reply2','unmap1','unmap2','channel','desc1','desc2'):
   self.api(stage);self.api()
 def test_open_identity_and_partial_session_construction(self):
  for stage in ('open','identity','desc_create1','desc_create2','connect'):
   for close in ('none','before','after'):
    p,events=self.invoke(self.current['tests/hailo_session_finalization_api.mojo'],[self.sys,self.dev,'idle','uncertain' if close!='none' else 'confirmed'],stage,close);self.assertNotEqual(p.returncode,0);self.assertFalse(any(e['op']=='owner_allocated' for e in events));self.assertLessEqual(sum(e['op']=='driver_close_attempt' for e in events),1)
   self.api()
 def test_complete_normal_frozen_consumer_outputs(self):
  for source in ('smidr/tools/soc_session.mojo','smidr/tools/soc_storage.mojo','tests/hailo_soc_storage_unwind.mojo','tests/hailo_soc_pending_storage.mojo','tests/hailo_soc_session_unwind.mojo'):
   p,_=self.invoke(self.current[source],[self.sys,self.dev]);q,_=self.invoke(self.old[source],[self.sys,self.dev],label='frozen');self.assertEqual((p.returncode,p.stdout,p.stderr),(q.returncode,q.stdout,q.stderr));self.assertEqual(p.returncode,0,p.stdout+p.stderr)
  for source in self.old:
   p,_=self.invoke(self.current[source],[]);q,_=self.invoke(self.old[source],[],label='frozen');self.assertEqual((p.returncode,p.stdout,p.stderr),(q.returncode,q.stdout,q.stderr));self.assertNotEqual(p.returncode,0)
 def test_old_close_uncertainty_demonstrates_intentional_correction(self):
  for close in ('before','after'):
   p,events=self.invoke(self.old['smidr/tools/soc_storage.mojo'],[self.sys,self.dev],close=close,label='old-known-gap',retention=False)
   self.assertNotEqual(p.returncode,0);self.assertTrue(any(e['op']=='owner_release_attempt' for e in events));self.api(close=close)
if __name__=='__main__':
 ap=argparse.ArgumentParser()
 for n in ('binaries','frozen','faults','evidence'):ap.add_argument('--'+n,required=True)
 CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
