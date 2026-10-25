#!/usr/bin/env python3
"""Aligned TRANSFER-probe diagnostic/observer qualification. Host mocks;
no Hailo device access. Derived from the AES-CONTROL-018 probe suite:
the same device oracle, observer and harness now qualify the single-
exchange primitive diagnostic (TASK_hailo10h_grouped_transfer_physical)."""
import argparse, hashlib, json, os, signal, struct, subprocess, sys, unittest
from pathlib import Path
import test_hailo_group_device_aligned as grouped
from test_hailo_hrpc_device import MESSAGES

CONFIG = argparse.Namespace()


class TransferProbe(unittest.TestCase):
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

 def fixture(self, handle, bad_identity=False, typed=None):
  env = grouped.GroupDeviceAligned().fixtures(handle, typed)
  if typed and '1' in typed: return env
  identity = MESSAGES['IdentifyReply'](); identity.identity.protocol_version = 2
  identity.identity.fw_version.major = 5; identity.identity.fw_version.minor = 3
  identity.identity.fw_version.revision = 7 if bad_identity else 0
  identity.identity.architecture = 6
  body = identity.SerializeToString()
  packet = (struct.pack('<5I',0x8a554432,len(body),1,22,0)+body+bytes(2048-len(body))).hex()
  env.update(AESIR_DEVICE_REPLY1=packet,AESIR_DEVICE_GOODREPLY1=packet)
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

 def test_01_single_create_exchange_completes(self):
  for handle in (0,0xffffffff):
   result,rows=self.run_pair(handle=handle)
   self.assertEqual((result[0],result[2]),(0,b''));j=self.data(result);self.assertTrue(j['accepted']);self.assertTrue(j['exchange_completed'] and j['handle_known']);self.assertFalse(j['physical_mode']);self.assertFalse(j['poisoned']);self.assertEqual((j['input_completions'],j['output_completions']),(1,1));self.assertGreaterEqual(j['snapshots'],1)
   for r in rows[:2]:
    wires=[o['wire'] for o in r['observer'][1:] if o['wire']]
    self.assertEqual(wires,[r['fixtures']['AESIR_DEVICE_REQUEST0'],r['fixtures']['AESIR_DEVICE_REPLY0']])
    maps=[e for e in r['events'] if e['op']=='map_effect'];self.assertEqual([(e['a'],e['c']) for e in maps],[(0,2560),(1,2068)])

 def test_02_sync_and_launch_faults_poison(self):
  for prefix,count in [('sync_before',4),('sync_after',4),('launch_before',2),('launch_after',2)]:
   for n in range(1,count+1):
    result,_=self.run_pair(fault=prefix+str(n));self.assertNotEqual(result[0],0);self.assertTrue(self.data(result)['poisoned'])

 def test_03_reply_irq_and_count_refusals(self):
  for fault in ('reply_id','reply_action','reply_status','irq_error','irq_foreign','wait_after'):
   result,_=self.run_pair(fault=fault);self.assertNotEqual(result[0],0);self.assertTrue(self.data(result)['poisoned'])
  for counts in ((0,5),(7,0),(65536,5),(7,65536),(-1,5)):
   result,_=self.run_pair(counts=counts);self.assertNotEqual(result[0],0)

 def test_04_close_faults_retain_and_refuse_acceptance(self):
  for close in ('before','after'):
   result,rows=self.run_pair(close=close);j=self.data(result);self.assertNotEqual(result[0],0);self.assertTrue(j['exchange_completed']);self.assertEqual(j['retained_views'],2);self.assertTrue(j['finalization_unconfirmed'])
   for r in rows:self.assertEqual(sum(e['op']=='file_close_attempt' for e in r['events']),1);self.assertFalse(any(e['op']=='released' for e in r['events']))

 def test_05_logging_failure_and_overflow_cannot_change_result(self):
  for logger,cap in [('missing',512),('invalid',512),('exists',512),('normal',0),('normal',1)]:
   result,rows=self.run_pair(logger=logger,cap=cap);self.assertEqual(result[0],0)
   if logger=='normal':
    for r in rows[:2]:self.assertGreater(r['observer'][0]['dropped'],0);self.assertEqual(r['observer'][0]['used'],cap)

 def test_06_independent_errno_passthrough(self):
  for logger in ('normal','missing','invalid','exists'):
   result,_=self.run_pair(role='passthrough',args=[],logger=logger);self.assertEqual(result[0],0);self.assertEqual(result[2],b'')

 def test_07_argument_refusal_without_owner(self):
  for args in ([],['physical-once','extra'],['host-mock','/sys','/dev'],['host-mock','',str(self.dev)]):
   result,rows=self.run_pair(args=args);self.assertNotEqual(result[0],0)

if __name__=='__main__':
 parser=argparse.ArgumentParser()
 for name in ('binaries','evidence'):parser.add_argument('--'+name,required=True)
 CONFIG,remaining=parser.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
