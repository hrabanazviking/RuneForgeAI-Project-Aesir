#!/usr/bin/env python3
"""Program-object lifecycle owner qualification (AES-PROG-002). Host
mocks; no Hailo device access. Derived from the AES-TRANSFER-004 probe
suite: the same device oracle, aligned observer and harness now carry
program-action fixtures (independently computed in this file from the
pinned public field contract) for the seven-stage lifecycle."""
import argparse, hashlib, json, os, signal, struct, subprocess, sys, unittest
from pathlib import Path
import test_hailo_group_device_aligned as grouped
from test_hailo_hrpc_device import MESSAGES

CONFIG = argparse.Namespace()


class ProgramMock(unittest.TestCase):
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
  create=hb(7)+bytes([0x10])+varint(4096)+bytes([0x1A,13])+b'aesir-program'
  stream=bytes([0x0A,6])+b'stream'+bytes([0x25])+bytes.fromhex('000080bf')+bytes([0x2D])+bytes.fromhex('000080bf')
  for tag in (0x30,0x38,0x40): stream+=bytes([tag])+varint(4294967295)
  configure=hb(41)+bytes([0x12,0x02,0x08,0x07])+bytes([0x1A,len(stream)])+stream+bytes([0x22,len(stream)])+stream+bytes([0x28,0x01])
  requests=[packet(0,2,create,1),packet(1,4,configure,1),packet(2,10,hb(42),1),packet(3,11,hb(42),1),packet(4,12,hb(42),1),packet(5,5,hb(42),1),packet(6,3,hb(41),1)]
  replies=[packet(0,2,hb(41),0),packet(1,4,hb(42)+bytes([0x10,0x03]),0),packet(2,10,b'',0),packet(3,11,b'',0),packet(4,12,b'',0),packet(5,5,b'',0),packet(6,3,b'',0)]
  if typed:
   for i,kind in typed.items():
    raw=bytearray.fromhex(replies[int(i)])
    if kind=='id': struct.pack_into('<I',raw,8,struct.unpack_from('<I',raw,8)[0]+1)
    elif kind=='action': struct.pack_into('<I',raw,12,struct.unpack_from('<I',raw,12)[0]+1)
    elif kind=='status': struct.pack_into('<I',raw,16,7)
    replies[int(i)]=bytes(raw).hex()
  env={}
  for i in range(7):
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
   env.update(LD_PRELOAD=':'.join(preload),AESIR_GROUP_NODE=str(self.dev/'h1x-0'),AESIR_GROUP_LOG=str(mock),AESIR_GROUP_FAULT=fault,AESIR_GROUP_CLOSE=close,AESIR_GROUP_INPUT_COUNT=str(counts[0]),AESIR_GROUP_OUTPUT_COUNT=str(counts[1]),AESIR_DEVICE_PHASE=str(phase) if phase else '',AESIR_OBSERVER_NODE=str(self.dev/'h1x-0') if role=='probe' else '/dev/null',AESIR_OBSERVER_CAPACITY=str(cap))
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

 def test_01_full_lifecycle(self):
  result,rows=self.run_pair(args=self.args('full'))
  self.assertEqual((result[0],result[2]),(0,b''));j=self.data(result);self.assertTrue(j['accepted']);self.assertTrue(j['identity_printed']);self.assertEqual(j['stages_completed'],7);self.assertEqual(j['exchanges'],7);self.assertEqual(j['stage'],0);self.assertFalse(j['poisoned'])
  for r in rows[:2]:
   wires=[o['wire'] for o in r['observer'][1:] if o['wire']]
   self.assertEqual(wires,[r['fixtures']['AESIR_PROGRAM_'+kind+str(n)] for n in range(7) for kind in ('REQUEST','REPLY')])

 def test_02_fail_closed_gates(self):
  for scenario,stages,exchanges in [('no-attest',1,1),('bad-attest',1,1),('early-configure',0,0),('early-destroy',0,0),('double-create',1,1),('teardown-order',2,2)]:
   result,_=self.run_pair(args=self.args(scenario));j=self.data(result);self.assertNotEqual(result[0],0,(scenario,j));self.assertTrue(j['refused'],(scenario,j));self.assertEqual(j['stages_completed'],stages,(scenario,j));self.assertEqual(j['exchanges'],exchanges,(scenario,j));self.assertFalse(j['accepted'])

 def test_03_reply_corruption_poisons(self):
  for typed in [{'0':'id'},{'1':'status'},{'1':'action'}]:
   result,_=self.run_pair(typed=typed,args=self.args('full'));self.assertNotEqual(result[0],0);self.assertTrue(self.data(result)['poisoned'])

 def test_04_sync_and_launch_faults_poison(self):
  for fault in ('sync_before1','sync_after1','launch_before1','launch_after1'):
   result,_=self.run_pair(fault=fault,args=self.args('full'));self.assertNotEqual(result[0],0);self.assertTrue(self.data(result)['poisoned'])

 def test_05_close_faults_block_acceptance(self):
  for close in ('before','after'):
   result,_=self.run_pair(close=close,args=self.args('full'));j=self.data(result);self.assertNotEqual(result[0],0);self.assertTrue(j['close_failed']);self.assertEqual(j['stages_completed'],7)

 def test_06_logging_failure_and_overflow_cannot_change_result(self):
  for logger,cap in [('missing',512),('invalid',512),('exists',512),('normal',0),('normal',1)]:
   result,rows=self.run_pair(logger=logger,cap=cap,args=self.args('full'));self.assertEqual(result[0],0)
   if logger=='normal':
    for r in rows[:2]:self.assertGreater(r['observer'][0]['dropped'],0);self.assertEqual(r['observer'][0]['used'],cap)

 def test_07_independent_errno_passthrough(self):
  for logger in ('normal','missing','invalid','exists'):
   result,_=self.run_pair(role='passthrough',args=[],logger=logger);self.assertEqual(result[0],0);self.assertEqual(result[2],b'')

 def test_08_argument_refusal_without_owner(self):
  for args in ([],['physical-once'],['host-mock-aligned','/sys','/dev','full'],['host-mock-aligned',str(self.sys),str(self.dev),'bogus-scenario']):
   result,rows=self.run_pair(args=args);self.assertNotEqual(result[0],0)

 def test_09_partial_creation_failure_accounting(self):
  # Each stage's reply is corrupted in turn (typed status). The owner
  # must stop at that stage, poison, attempt nothing further, and its
  # printed accounting must name the exact residue tier.
  cases=[
   ('fail-at-create',{'0':'status'},0,'create',False,False,1),
   ('fail-at-configure',{'1':'status'},1,'configure',True,False,2),
   ('fail-at-activate',{'2':'status'},2,'activate',True,True,3),
   ('fail-at-deactivate',{'3':'status'},3,'deactivate',True,True,4),
   ('fail-at-shutdown',{'4':'status'},4,'shutdown',True,True,5),
   ('fail-at-destroy-configured',{'5':'status'},5,'destroy-configured',True,True,6),
   ('fail-at-destroy-infer',{'6':'status'},6,'destroy-infer',True,False,7),
  ]
  for scenario,typed,stages,failed,infer_known,configured_known,exchanges in cases:
   result,_=self.run_pair(typed=typed,args=self.args(scenario));j=self.data(result)
   self.assertNotEqual(result[0],0,(scenario,j));self.assertFalse(j['accepted'])
   self.assertEqual(j['failed_stage'],failed,(scenario,j));self.assertEqual(j['stages_completed'],stages,(scenario,j))
   self.assertEqual(j['infer_known'],infer_known,(scenario,j));self.assertEqual(j['configured_known'],configured_known,(scenario,j))
   self.assertEqual(j['exchanges'],exchanges,(scenario,j));self.assertTrue(j['poisoned'],(scenario,j))

 def test_10_transport_failure_at_create(self):
  result,_=self.run_pair(fault='launch_after1',args=self.args('fail-at-create'));j=self.data(result)
  self.assertNotEqual(result[0],0);self.assertEqual(j['failed_stage'],'create');self.assertEqual(j['stages_completed'],0);self.assertEqual(j['exchanges'],0);self.assertTrue(j['poisoned'])

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 for name in ('binaries','evidence'):parser.add_argument('--'+name,required=True)
 CONFIG,remaining=parser.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
