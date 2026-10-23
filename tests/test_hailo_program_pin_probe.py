#!/usr/bin/env python3
"""Host-only qualification. Mock ioctl results NEVER count as device evidence."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import unittest
CONFIG=argparse.Namespace()

class PinHost(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(exist_ok=False);cls.records=[]
        cls.sysfs=cls.out/'sys';cls.dev=cls.out/'dev';cls.dev.mkdir()
        node=cls.sysfs/'bus/pci/devices/0001:01:00.0/hailo1x/h1x-0';node.mkdir(parents=True)
        (node.parents[1]/'vendor').write_text('0x1e60\n');(node.parents[1]/'device').write_text('0x45c4\n');(node/'dev').write_text('1:3\n')
        lib=Path(CONFIG.oracle).resolve(strict=True);assert hashlib.sha256(lib.read_bytes()).hexdigest()=='eba22de3de8f35b9871675e08b74ee43275e5fa3992d4b8c22ae394b5f184031'
        assert hashlib.sha256(Path(CONFIG.oracle_license).read_bytes()).hexdigest()=='a123c93b07e781919ae996276ac02bb1c8b19dfde88176cd1240ab277c14a4ce'
        cls.lib=ctypes.CDLL(str(lib));cls.lib.XXH3_64bits.argtypes=(ctypes.c_void_p,ctypes.c_size_t);cls.lib.XXH3_64bits.restype=ctypes.c_uint64
    @classmethod
    def tearDownClass(cls):(cls.out/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
    def expected(self,profile,n):
        if profile=='anon-rw':return bytes(n)
        body=bytes((i*37+11)&255 for i in range(n-56));owned=ctypes.create_string_buffer(body);checksum=self.lib.XXH3_64bits(owned,len(body))
        return struct.pack('>IIIQQIQQQ',0x01484546,3,len(body),checksum,0,0,0,0,0)+body
    def call(self,args,mode=None):
        env=os.environ.copy();i=len(self.records)
        if mode is not None:env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_PIN_FAULT=mode,AESIR_PIN_NODE=str(self.dev/'h1x-0'),AESIR_PIN_LOG=str(self.out/f'fault-{i}.jsonl'))
        p=subprocess.run([str(Path(CONFIG.binary).resolve()),*map(str,args)],capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL,env=env)
        events=[json.loads(x) for x in (self.out/f'fault-{i}.jsonl').read_text().splitlines()] if (self.out/f'fault-{i}.jsonl').exists() else []
        self.records.append(dict(arguments=list(map(str,args)),fault=mode,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,events=events,physical_evidence=False));return p,events
    def run_case(self,profile='sealed-cow',n=70,device=False,fault=None):
        return self.call(['device' if device else 'host',profile,n,str(self.sysfs) if device else '-',str(self.dev) if device else '-'],fault)
    def okay(self,result,profile,n,device=False,accepted=True):
        p,events=result;self.assertEqual((p.returncode,p.stderr),(0,''),p.stdout+p.stderr);j=json.loads(p.stdout)
        self.assertEqual(bytes.fromhex(j['bytes_hex']),self.expected(profile,n));self.assertEqual(j['logical_bytes'],n)
        self.assertEqual(j['mapping_bytes'],((n+j['page_size']-1)//j['page_size'])*j['page_size'])
        for k in ('context_finalized','host_released','bytes_verified'):self.assertTrue(j[k])
        self.assertEqual(j['sealed_backing_unchanged'],profile!='anon-rw');self.assertEqual(j['device_context_opened'],device)
        self.assertEqual(j['map_attempted'],device);self.assertEqual(j['map_accepted'],device and accepted)
        self.assertFalse(j['dma_submitted']);self.assertFalse(j['program_submitted']);self.assertFalse(j['execution_tested'])
        self.assertFalse(any(e['op'] in ('unsafe_release','forbidden_ioctl') for e in events))
        if device:
            closed=next(i for i,e in enumerate(events) if e['op']=='driver_closed')
            released=next(i for i,e in enumerate(events) if e['op']=='view_release_attempt') if profile!='anon-rw' else len(events)
            self.assertLess(closed,released)
        return j
    def refused(self,result,text=None):
        p,events=result;self.assertNotEqual(p.returncode,0,p.stdout)
        if text:self.assertIn(text,p.stdout+p.stderr)
        self.assertFalse(any(e['op'] in ('unsafe_release','forbidden_ioctl') for e in events));return events
    def test_host_views_and_returned_complete_bytes(self):
        for profile in ('sealed-ro','sealed-cow'):
            for n in (70,4097,16385):self.okay(self.run_case(profile,n),profile,n)
        self.okay(self.run_case('anon-rw',2068),'anon-rw',2068)
    def test_mocked_file_context_map_unmap_order_all_profiles(self):
        for profile,n in [('anon-rw',2068)]+[(p,n) for p in ('sealed-ro','sealed-cow') for n in (70,4097,16385)]:
            j=self.okay(self.run_case(profile,n,True,'none'),profile,n,True);self.assertTrue(j['unmap_confirmed']);self.assertEqual(j['error_hex'],'')
    def test_uncertain_map_reply_and_unmap_faults_recover(self):
        for fault in ('map_before','map_after','bad_tuple','bad_handle','unmap_before','unmap_after'):
            j=self.okay(self.run_case(device=True,fault=fault),'sealed-cow',70,True,fault.startswith('unmap'))
            self.assertFalse(j['unmap_confirmed']);self.assertTrue(j['error_hex'])
            self.okay(self.run_case(device=True,fault='none'),'sealed-cow',70,True)
    def test_partial_construction_identity_and_release_failures(self):
        for fault in ('page_size','mmap','backing_read','open','identity','munmap_before','munmap_after'):
            events=self.refused(self.run_case(device=True,fault=fault))
            if fault in ('page_size','mmap','backing_read'):self.assertFalse(any(e['op']=='driver_open_attempt' for e in events))
            if fault in ('open','identity'):self.assertFalse(any(e['op']=='map_attempt' for e in events))
            self.okay(self.run_case(device=True,fault='none'),'sealed-cow',70,True)
    def test_unconfirmed_close_retains_backing_and_never_reads_or_releases(self):
        for fault in ('close_before','close_after'):
            events=self.refused(self.run_case(device=True,fault=fault),'cleanup_unconfirmed')
            self.assertTrue(any(e['op']=='driver_close_attempt' for e in events))
            self.assertFalse(any(e['op'] in ('view_release_attempt','sealed_close') for e in events))
            self.okay(self.run_case(device=True,fault='none'),'sealed-cow',70,True)
    def test_enumerated_argument_guards_before_allocation(self):
        for args in ([],['x'],['x','sealed-ro',70,'-','-'],['host','x',70,'-','-'],['host','sealed-ro',69,'-','-'],['host','anon-rw',70,'-','-'],['host','sealed-ro','-1','-','-'],['host','sealed-ro','999999','-','-'],['host','sealed-ro',70,'x','-'],['device','sealed-ro',70,'','x']):
            p,events=self.call(args,'none');self.assertNotEqual(p.returncode,0);self.assertFalse(events)
        self.okay(self.run_case(),'sealed-cow',70)

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for n in ('binary','faults','oracle','oracle-license','evidence'):ap.add_argument('--'+n,required=True)
    CONFIG,rest=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*rest])
