#!/usr/bin/env python3
"""Program lifecycle physical-diagnostic qualification (slice 3.3
contract host gates). Host mocks; no Hailo device access. Derived
from the AES-PROG-002 suite harness with the program oracle;
fixtures for the four contract exchanges (device create, action-2
metadata, destroy-infer, device destroy) are computed independently
in this file from the pinned public field contract."""
import argparse, hashlib, json, os, signal, struct, subprocess, sys, unittest
from pathlib import Path
import test_hailo_group_device_aligned as grouped
from test_hailo_hrpc_device import MESSAGES

CONFIG = argparse.Namespace()


class ProgramLifecycleProbe(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.out = Path(CONFIG.evidence).resolve(); cls.out.mkdir(exist_ok=False)
  cls.bins = json.loads(Path(CONFIG.binaries).read_text()); cls.runs = []
  cls.sys = cls.out/'sys'; cls.dev = cls.out/'dev'; cls.dev.mkdir()
  node = cls.sys/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0'; node.mkdir(parents=True)
  for p, text in [(node.parents[1]/'vendor','0x1e60'),(node.parents[1]/'device','0x45c4'),(node/'dev','1:3')]: p.write_text(text+'\n')
  for row in cls.bins.values():
   for label in ('current','frozen'): assert hashlib.sha256(Path(row[label]).read_bytes()).hexdigest() == row['sha256']

 @classmethod
 def tearDownClass(cls): (cls.out/'runs.json').write_text(json.dumps(cls.runs,indent=2)+'\n')

 def fixture(self, handle=0, bad_identity=False, typed=None):
  def varint(v):
   out=bytearray()
   while v>=128: out.append((v&127)|128); v>>=7
   out.append(v); return bytes(out)
  def hb(h): return bytes([0x0A,0x02,0x08])+varint(h)
  def packet(mid,action,body,status): return (struct.pack('<5I',0x8a554432,len(body),mid,action,status)+body+bytes(2048-len(body))).hex()
  create=hb(7)+bytes([0x10])+varint(64)+bytes([0x1A,21])+b'aesir-lifecycle-probe'
  requests=[packet(0,20,b'',1),packet(1,2,create,1),packet(2,3,hb(41),1),packet(3,21,hb(7),1)]
  replies=[packet(0,20,hb(7),0),packet(1,2,hb(41),0),packet(2,3,b'',0),packet(3,21,b'',0)]
  if typed:
   for i,kind in typed.items():
    raw=bytearray.fromhex(replies[int(i)])
    if kind=='id': struct.pack_into('<I',raw,8,struct.unpack_from('<I',raw,8)[0]+1)
    elif kind=='action': struct.pack_into('<I',raw,12,struct.unpack_from('<I',raw,12)[0]+1)
    elif kind=='status': struct.pack_into('<I',raw,16,7)
    replies[int(i)]=bytes(raw).hex()
  env={}
  for i in range(4):
   env['AESIR_PROGRAM_REQUEST'+str(i)]=requests[i];env['AESIR_PROGRAM_REPLY'+str(i)]=replies[i]
  return env

 def run_pair(self, *, fault='none', phase=0, handle=0, counts=(7,5), close='none',
              bad_identity=False, typed=None, logger='normal', cap=512, args=None, role='probe'):
  results=[]
  fixtures=self.fixture(handle,bad_identity,typed)
  for label, observed in [('current',True),('frozen',True),('current',False),('frozen',False)]:
   i=len(self.runs); prefix=self.out/str(i); log=prefix.with_suffix('.observer'); mock=prefix.with_suffix('.mock'); trace=prefix.with_suffix('.strace')
   env={k:v for k,v in os.environ.items() if not k.startswith('AESIR_') and k not in ('LD_PRELOAD','LD_DEBUG','LD_AUDIT')}
   preload=[]
   if observed: preload.append(self.bins['observer'][label])
   if role=='probe': preload.append(self.bins['faults'][label])
   env.update(LD_PRELOAD=':'.join(preload),AESIR_GROUP_NODE=str(self.dev/'h1x-0'),AESIR_GROUP_LOG=str(mock),AESIR_GROUP_FAULT=fault,AESIR_GROUP_CLOSE=close,AESIR_GROUP_INPUT_COUNT=str(counts[0]),AESIR_GROUP_OUTPUT_COUNT=str(counts[1]),AESIR_DEVICE_PHASE=str(phase) if phase else '',AESIR_PROGRAM_PHASE=str(phase) if phase else '',AESIR_OBSERVER_NODE=str(self.dev/'h1x-0') if role=='probe' else '/dev/null',AESIR_OBSERVER_CAPACITY=str(cap))
   env.update(fixtures)
   if logger!='missing': env['AESIR_OBSERVER_LOG']=str(log if logger!='invalid' else self.out/'absent'/'log')
   if logger=='exists' and observed: log.write_text('existing evidence\n')
   cmd=[self.bins[role][label],*(args if args is not None else ['host-mock',str(self.sys),str(self.dev)])]
   process=subprocess.Popen(['strace','-f','-yy','-s','300','-o',str(trace),*cmd],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,start_new_session=True)
   expired=False; unresolved=False
   try: stdout,stderr=process.communicate(timeout=20)
   except subprocess.TimeoutExpired:
    expired=True
    try: os.killpg(process.pid,signal.SIGTERM)
    except ProcessLookupError: pass
    try: stdout,stderr=process.communicate(timeout=3)
    except subprocess.TimeoutExpired:
     try: os.killpg(process.pid,signal.SIGKILL)
     except ProcessLookupError: pass
     try: stdout,stderr=process.communicate(timeout=3)
     except subprocess.TimeoutExpired as exc: stdout=exc.output or b'';stderr=exc.stderr or b'';unresolved=True
   prefix.with_suffix('.stdout').write_bytes(stdout);prefix.with_suffix('.stderr').write_bytes(stderr)
   events=[json.loads(line) for line in mock.read_text().splitlines()] if mock.exists() else []
   observer=[json.loads(line) for line in log.read_text().splitlines()] if log.exists() and logger!='exists' else []
   row=dict(label=label,observed=observed,role=role,arguments=cmd,fault=fault,phase=phase,close=close,counts=counts,logger=logger,capacity=cap,returncode=process.returncode,expired=expired,unresolved=unresolved,trace=str(trace),fixtures=fixtures,events=events,observer=observer,physical_calls=False)
   self.runs.append(row);prefix.with_suffix('.record.json').write_text(json.dumps(row,indent=2)+'\n')
   self.assertFalse(expired or unresolved);self.assertFalse(any(e['op'].startswith('unsafe') or e['op']=='forbidden_ioctl' for e in events))
   if observed and logger=='normal':
    self.assertTrue(observer);self.assertEqual(observer[0]['dropped']==0,cap==512)
    forward=bytes.fromhex(observer[0]['forward']).decode()
    if role=='probe': self.assertEqual(forward,self.bins['faults'][label])
    else: self.assertIn('libc',forward)
   if observed and logger=='exists': self.assertEqual(log.read_text(),'existing evidence\n')
   results.append((process.returncode,stdout,stderr))
  self.assertTrue(all(r==results[0] for r in results),results)
  return results[0],self.runs[-4:]

 def data(self,result):
  # Keep complete stdout in each comparison, including retained-owner notices.
  return [json.loads(line) for line in result[1].splitlines() if line.startswith(b'{')][0]

 def args(self, scenario):
  return ['host-mock-aligned',str(self.sys),str(self.dev),scenario]

 def test_01_branch_b1_full_teardown(self):
  result,rows=self.run_pair()
  self.assertEqual((result[0],result[2]),(0,b''));j=self.data(result);self.assertTrue(j['accepted']);self.assertEqual(j['branch'],'B1');self.assertTrue(j['infer_destroyed'] and j['vdevice_destroyed']);self.assertEqual(j['exchanges'],4);self.assertFalse(j['poisoned'])
  for r in rows[:2]:
   wires=[o['wire'] for o in r['observer'][1:] if o['wire']]
   self.assertEqual(wires,[r['fixtures']['AESIR_PROGRAM_'+kind+str(n)] for n in range(4) for kind in ('REQUEST','REPLY')])

 def test_02_branch_b3_typed_refusal(self):
  result,_=self.run_pair(typed={'1':'status'});j=self.data(result);self.assertEqual(result[0],0);self.assertTrue(j['accepted']);self.assertEqual(j['branch'],'B3');self.assertTrue(j['poisoned']);self.assertFalse(j['infer_destroy_attempted'] or j['vdevice_destroy_attempted']);self.assertEqual(j['exchanges'],2)

 def test_03_branch_b2_no_reply(self):
  result,_=self.run_pair(fault='empty',phase=2);j=self.data(result);self.assertEqual(result[0],0);self.assertTrue(j['accepted']);self.assertEqual(j['branch'],'B2');self.assertTrue(j['poisoned']);self.assertEqual(j['exchanges'],1);self.assertEqual(j['retained_views'],0)

 def test_04_phase_a_failure_admits_nothing(self):
  result,_=self.run_pair(typed={'0':'status'});j=self.data(result);self.assertNotEqual(result[0],0);self.assertFalse(j['accepted']);self.assertEqual(j['branch'],'A-failed');self.assertFalse(j['phase_a_ok']);self.assertEqual(j['exchanges'],1)

 def test_05_close_fault_blocks_acceptance(self):
  result,_=self.run_pair(close='before');j=self.data(result);self.assertNotEqual(result[0],0);self.assertFalse(j['accepted']);self.assertTrue(j['close_failed']);self.assertEqual(j['branch'],'B1')

 def test_06_argument_refusal_without_owner(self):
  for args in ([],['physical-once','extra'],['host-mock','/sys','/dev'],['host-mock','',str(self.dev)]):
   result,rows=self.run_pair(args=args);self.assertNotEqual(result[0],0)

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 for name in ('binaries','evidence'):parser.add_argument('--'+name,required=True)
 CONFIG,remaining=parser.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
