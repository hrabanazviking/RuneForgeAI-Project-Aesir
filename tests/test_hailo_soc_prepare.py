#!/usr/bin/env python3
"""Independent complete prepare/cancel objects; synthetic scalar values only."""
import argparse,json,random,struct,subprocess,sys,unittest
from pathlib import Path
CONFIG=argparse.Namespace();MAX=(1<<64)-1

def packed(channel,handle,spans):
 data=bytearray(139);struct.pack_into('<BQB',data,0,channel,handle,len(spans))
 for i,(address,size) in enumerate(spans):struct.pack_into('<IQI',data,10+16*i,0,address,size)
 return bytes(data)

def admitted(data):
 if len(data)!=139:return False
 channel,handle,count=struct.unpack_from('<BQB',data)
 if channel>=40 or handle==MAX or not 1<=count<=8 or data[138]:return False
 for i in range(count):
  kind,address,size=struct.unpack_from('<IQI',data,10+16*i)
  if kind!=0 or address==0 or size==0 or size>MAX-address:return False
 return not any(data[10+16*count:138])

class Prepare(unittest.TestCase):
 @staticmethod
 def call(binary,*args):return subprocess.run([str(Path(binary).resolve(strict=True)),*map(str,args)],capture_output=True,text=True,stdin=subprocess.DEVNULL,timeout=10)
 def okay(self,*args):
  p=self.call(CONFIG.binary,*args);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);return p.stdout.strip()
 def recover(self):self.assertEqual(self.okay('prepare',3,0,65536,2068,196608,70),packed(3,0,[(65536,2068),(196608,70)]).hex())
 def refused(self,*args):
  p=self.call(CONFIG.binary,*args);self.assertNotEqual(p.returncode,0);self.assertEqual(p.stdout,'');self.assertIn('HailbruError[',p.stderr);self.recover()
 def vector(self,channel,handle,spans):
  words=[x for pair in spans for x in pair];expected=packed(channel,handle,spans);self.assertTrue(admitted(expected));actual=self.okay('prepare',channel,handle,*words);self.assertEqual(actual,expected.hex())
  p=self.call(CONFIG.oracle,'prepare',channel,handle,*words);self.assertEqual((p.returncode,p.stdout,p.stderr),(0,expected.hex()+'\n',''))
  self.assertEqual(self.okay('decode-prepare',actual),actual)
  p=self.call(CONFIG.launch,'encode',channel,handle,*words);self.assertEqual((p.returncode,p.stdout,p.stderr),(0,actual+'0000\n',''))
 def test_01_all_counts_slots_order_edges_and_walking_bits(self):
  cases=[(1,1),(MAX-1,1),(MAX-0xffffffff,0xffffffff),(0x1122334455667788,0x89abcdef),(65536,2068),(196608,70)]
  for count in range(1,9):
   for step in range(6):
    spans=[cases[(i+step)%6] for i in range(count)];self.vector((5*count+step)%40,[0,MAX-1,0x123456789abcdef0][step%3],spans);self.vector(39,0,list(reversed(spans)))
  for bit in range(64):
   spans=[(65536+i,i+1) for i in range(8)];spans[bit%8]=(1<<bit,1);self.vector(bit%40,1<<bit,spans)
  for bit in range(32):
   spans=[(65536+i,1) for i in range(8)];spans[bit%8]=(0x1234567890abcdef,1<<bit);self.vector(0,0,spans)
  rng=random.Random(0xA3513)
  for _ in range(32):
   spans=[]
   for _ in range(rng.randrange(1,9)):
    n=rng.randrange(1,1<<32);spans.append((rng.randrange(1,MAX-n+1),n))
   self.vector(rng.randrange(40),rng.randrange(MAX),spans)
 def test_02_cancel_complete_objects_and_all_handle_bits(self):
  for handle in [0,1,MAX-1,0x1122334455667788]+[1<<i for i in range(64)]:
   expected=struct.pack('<Q',handle).hex();self.assertEqual(self.okay('cancel',handle),expected);self.assertEqual(self.okay('decode-cancel',expected),expected)
   p=self.call(CONFIG.oracle,'cancel',handle);self.assertEqual((p.returncode,p.stdout,p.stderr),(0,expected+'\n',''))
   p=self.call(CONFIG.original,'desc-release',handle);self.assertEqual((p.returncode,p.stdout,p.stderr),(0,expected+'\n',''))
  self.refused('cancel',MAX);self.refused('decode-cancel','ff'*8)
 def check_decode(self,data):
  if admitted(data):self.assertEqual(self.okay('decode-prepare',data.hex()),data.hex())
  else:self.refused('decode-prepare',data.hex())
 def test_03_every_byte_counts_types_unused_and_debug(self):
  for count in (1,2,8):
   data=packed(3,0,[(65536+i*131072,2068 if i==0 else 70+i) for i in range(count)])
   for i in range(139):
    bad=bytearray(data);bad[i]^=1;self.check_decode(bad)
  data=packed(3,0,[(65536,2068)])
  for count in range(256):
   bad=bytearray(data);bad[9]=count;self.check_decode(bad)
  for i in range(26,138):
   bad=bytearray(data);bad[i]=1;self.check_decode(bad)
  for debug in (1,2,127,128,254,255):
   bad=bytearray(data);bad[138]=debug;self.check_decode(bad)
  data=packed(3,0,[(65536+i*131072,70+i) for i in range(8)])
  for i in range(8):
   for byte in range(4):
    bad=bytearray(data);bad[10+16*i+byte]=1;self.check_decode(bad)
  bad=bytearray(data);bad[1:9]=b'\xff'*8;self.check_decode(bad)
 def test_04_bad_values_bounds_and_all_trailing_short_lengths(self):
  for channel in (40,255,MAX):self.refused('prepare',channel,0,1,1)
  self.refused('prepare',0,MAX,1,1)
  for pair in [(0,1),(1,0),(1,1<<32),(1,MAX),(MAX,1),(MAX-1,2)]:self.refused('prepare',0,0,*pair)
  for args in [[],['x'],['prepare',0,0],['prepare',0,0,1],['prepare',0,0,*([1,1]*9)],['prepare',-1,0,1,1],['cancel',-1],['cancel',1<<64],['cancel','1'*21],['cancel',1,2],['decode-prepare','g'*278],['decode-cancel','g'*16]]:self.refused(*args)
  for n in range(144):
   if n!=139:self.refused('decode-prepare','00'*n)
   if n!=8:self.refused('decode-cancel','00'*n)
 def test_05_direct_api_lifetimes_mutations_and_exact_bounds(self):
  p=self.call(CONFIG.api);self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);self.assertEqual(json.loads(p.stdout),dict(ownership=True,refusal_recovery_cycles=324,device_access=False))
if __name__=='__main__':
 ap=argparse.ArgumentParser()
 for n in ('binary','api','oracle','launch','original'):ap.add_argument('--'+n,required=True)
 CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
