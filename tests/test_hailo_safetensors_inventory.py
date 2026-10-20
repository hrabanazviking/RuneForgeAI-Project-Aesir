#!/usr/bin/env python3
"""Independent source metadata fixtures, no framework/model evaluation."""
import argparse
from collections import Counter
import hashlib
import importlib.metadata
import json
import math
import os
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

CONFIG = argparse.Namespace()
DTYPES = {'F16':(0,2),'BF16':(1,2),'F32':(2,4)}
INT_MAX = (1 << 63)-1


def raw_file(header, payload=b''):
    if isinstance(header,str): header = header.encode('utf-8')
    return struct.pack('<Q',len(header))+header+payload


def fixture(tensors, metadata=None, pad=0, shuffle=False):
    entries = []
    payload = bytearray()
    expected = {}
    for name,dtype,shape in tensors:
        elements = math.prod(shape)
        code,width = DTYPES[dtype]
        begin = len(payload)
        size = elements*width
        payload += bytes((i*73+len(entries)*31)%256 for i in range(size))
        entries.append((name,dict(dtype=dtype,shape=shape,data_offsets=[begin,len(payload)])))
        expected[name] = dict(dtype=code,shape=shape,elements=elements,relative=begin,bytes=size)
    if shuffle: entries.reverse()
    obj = dict(entries)
    if metadata is not None: obj['__metadata__'] = metadata
    header = json.dumps(obj,ensure_ascii=False,separators=(',',':')).encode()+b' '*pad
    return raw_file(header,payload),expected,metadata or {}


class SafetensorsInventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=False)
        cls.temp = tempfile.TemporaryDirectory(prefix='aesir-native-safetensors-')
        cls.root = Path(cls.temp.name)
        cls.records = []
        dist = importlib.metadata.distribution('safetensors')
        license_bytes = next(dist.locate_file(p) for p in dist.files if str(p).endswith('licenses/LICENSE')).read_bytes()
        binary = next(dist.locate_file(p) for p in dist.files if str(p).endswith('.so'))
        facts = json.loads((Path(__file__).resolve().parents[1]/'docs/evidence/safetensors-format-2026-10-20/oracle-provenance.json').read_text())
        assert dist.version == '0.7.0'
        assert hashlib.sha256(license_bytes).hexdigest() == facts['license_sha256']
        assert hashlib.sha256(binary.read_bytes()).hexdigest() == facts['binary_sha256']
        import safetensors
        cls.oracle = staticmethod(safetensors.deserialize)
        (cls.evidence/'oracle-provenance.json').write_text(json.dumps(facts,indent=2)+'\n')

    @classmethod
    def tearDownClass(cls):
        counts = dict(Counter('accepted' if r['returncode'] == 0 else 'refused' for r in cls.records))
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        (cls.evidence/'summary.json').write_text(json.dumps(counts,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native outcomes:',counts)

    def invoke(self, raw, bounds=(65536,64,32,16384,32), trace=False):
        path = self.root/('case-'+str(len(self.records))+'.safetensors')
        path.write_bytes(raw)
        command = [self.binary,str(path),*map(str,bounds)]
        if trace:
            command = [CONFIG.strace,'-y','-o',str(self.evidence/'inventory.strace'),
                       '-e','trace=openat,close,mmap,munmap,ioctl',*command]
        result = subprocess.run(command,capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL)
        self.records.append(dict(input_sha256=hashlib.sha256(raw).hexdigest(),input_bytes=len(raw),
            bounds=bounds,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
        self.assertEqual(path.read_bytes(),raw,'source file was modified')
        return result

    def accepted(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        obj = json.loads(result.stdout)
        for key in ('device_access','tensor_values_loaded','execution_tested'):
            self.assertIs(obj[key],False)
        return obj

    def refused(self,result):
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(result.stdout,'')
        self.assertTrue(any(x in result.stderr for x in ('safetensors:','BadArgs','UTF-8','UTF8','utf-8')),result.stderr)

    def check(self, triple, **options):
        raw,expected,metadata = triple
        result = self.accepted(self.invoke(raw,**options))
        n = struct.unpack('<Q',raw[:8])[0]
        self.assertEqual((result['source_bytes'],result['data_offset']),(len(raw),8+n))
        self.assertEqual({bytes.fromhex(k).decode():bytes.fromhex(v).decode() for k,v in result['metadata']},metadata)
        actual = {bytes.fromhex(t['name_utf8_hex']).decode():t for t in result['tensors']}
        self.assertEqual(set(actual),set(expected))
        reference = dict(self.oracle(raw))
        self.assertEqual(set(reference),set(expected))
        for name,want in expected.items():
            item = actual[name]
            for key in ('dtype','shape','elements','bytes'):
                self.assertEqual(item[key],want[key],(name,key))
            self.assertEqual(item['offset'],8+n+want['relative'])
            self.assertEqual(reference[name]['shape'],want['shape'])
            self.assertEqual(DTYPES[reference[name]['dtype']][0],want['dtype'])
            self.assertEqual(len(reference[name]['data']),want['bytes'])
        return result

    def test_float_shapes_scalars_empty_unicode_and_metadata(self):
        for dtype in DTYPES:
            for shape in ([],[0],[1],[2,3],[1,2,1,3],[0,INT_MAX,INT_MAX],[INT_MAX,0,INT_MAX]):
                self.check(fixture([('Þór\0🐦',dtype,shape)],{'a\0b':'välue🐦','':'','format':'pt'},pad=17))
        self.check(fixture([],{}))
        self.check(fixture([]))
        self.check(fixture([('', 'F32', [1]),('empty','F16',[0]),('later','BF16',[2])],shuffle=True))

    def test_seeded_tensor_order_axes_spans_and_byte_widths(self):
        rng = random.Random(17321)
        for _ in range(60):
            tensors = []
            for i in range(rng.randrange(1,13)):
                shape = [rng.randrange(4) for _ in range(rng.randrange(5))]
                tensors.append(('weight_'+str(i),rng.choice(tuple(DTYPES)),shape))
            self.check(fixture(tensors,{'note':'original'},pad=rng.randrange(9),shuffle=bool(rng.randrange(2))))

    def test_exact_policy_boundaries_and_positive_bounds(self):
        raw,expected,meta = fixture([('x','F16',[2,3]),('y','F32',[])])
        n = struct.unpack('<Q',raw[:8])[0]
        self.check((raw,expected,meta),bounds=(n,2,2,16,1))
        for index,value in ((0,n-1),(1,1),(2,1),(3,15)):
            bounds=[n,2,2,16,1];bounds[index]=value
            self.refused(self.invoke(raw,bounds))
        for i in range(5):
            bounds=[n,2,2,16,1];bounds[i]=0
            self.refused(self.invoke(raw,bounds))
        self.refused(self.invoke(raw,(n,2,2,16,65)))
        for i in range(5):
            bounds=[n,2,2,16,1];bounds[i]=-1
            self.refused(self.invoke(raw,bounds))

    def test_header_prefix_truncation_unsigned_overflow_and_padding(self):
        for data in (b'',b'1',b'1'*7,struct.pack('<Q',0),struct.pack('<Q',1)+b'{',
                     struct.pack('<Q',1<<63),struct.pack('<Q',(1<<64)-1),
                     struct.pack('<Q',100)+b'{}',raw_file(' {}'),raw_file('{}x'),raw_file('{}\0')):
            self.refused(self.invoke(data))
        for suffix in ('',' ','  \n\t\r'):
            self.check((raw_file('{}'+suffix),{},{}))

    def test_duplicate_missing_fields_keys_and_json_syntax(self):
        descriptor='"dtype":"F16","shape":[1],"data_offsets":[0,2]'
        good='{'+descriptor+'}'
        headers=['{"x":'+good+',"x":'+good+'}',
                 '{"__metadata__":{},"__metadata__":{}}',
                 '{"x":{'+descriptor+',"dtype":"F16"}}',
                 '{"x":{'+descriptor+',"shape":[1]}}',
                 '{"x":{'+descriptor+',"data_offsets":[0,2]}}',
                 '{"x":{'+descriptor+',"other":1,"other":2}}',
                 '{"x":{'+descriptor+',"other":{"a":1,"a":2}}}',
                 '{"x":'+good+',}',
                 '{"x":{'+descriptor+',}}',
                 '{"x":{}}','[]','null','{"x":'+good+',,"y":'+good+'}']
        for required in ('"dtype":"F16",','"shape":[1],',',"data_offsets":[0,2]'):
            headers.append('{"x":{'+descriptor.replace(required,'')+'}}')
        for header in headers:
            self.refused(self.invoke(raw_file(header,b'ab')))
        for bad in ('01','+1','-1','-0','1.0','1e0','true','null','9223372036854775808'):
            self.refused(self.invoke(raw_file('{"x":{"dtype":"F16","shape":['+bad+'],"data_offsets":[0,2]}}',b'ab')))
        for bad in ('[1,]','[,1]','[1,,2]'):
            self.refused(self.invoke(raw_file('{"x":{"dtype":"F16","shape":'+bad+',"data_offsets":[0,2]}}',b'ab')))

    def test_strict_utf8_escape_nul_and_metadata_string_map(self):
        for key in (b'\x80',b'\xc0\x80',b'\xe0\x80\x80',b'\xed\xa0\x80',b'\xf4\x90\x80\x80',b'\xff',b'\xe2\x82'):
            self.refused(self.invoke(raw_file(b'{"'+key+b'":{"dtype":"F16","shape":[1],"data_offsets":[0,2]}}',b'ab')))
            self.refused(self.invoke(raw_file(b'{"__metadata__":{"a":"'+key+b'"}}')))
        for value in ('true','null','1','[]','{}'):
            self.refused(self.invoke(raw_file('{"__metadata__":{"a":'+value+'}}')))
            if value != '{}':
                self.refused(self.invoke(raw_file('{"__metadata__":'+value+'}')))
        for header in ('{"__metadata__":{"a":"b","a":"c"}}',
                       '{"__metadata__":{"a":"b",}}',
                       '{"__metadata__":{"a":"\\ud800"}}',
                       '{"__metadata__":{"a":"\\udc00"}}',
                       '{"__metadata__":{"a":"\\ud800\\u0041"}}',
                       '{"__metadata__":{"a":"\\x41"}}',
                       '{"__metadata__":{"a":"raw\nnewline"}}'):
            self.refused(self.invoke(raw_file(header)))
        self.check(fixture([('a\\\"b','BF16',[1])],{'escape':'\b\f\n\r\t\0'}))

    def test_shape_product_offsets_overlap_holes_empty_boundaries(self):
        def one(shape,offsets,dtype='F16'):
            return json.dumps({'x':dict(dtype=dtype,shape=shape,data_offsets=offsets)},separators=(',',':'))
        for header,payload in ((one([1<<32,1<<32],[0,0]),b''),
                               (one([INT_MAX],[0,0]),b''),
                               (one([1],[INT_MAX,INT_MAX]),b''),
                               (one([1],[0,INT_MAX]),b''),
                               (one([1],[2,0]),b'ab'),(one([1],[1,3]),b'abc'),
                               (one([1],[0,2]),b'abc'),(one([1],[0,2]),b'a'),
                               (one([0],[1,1]),b''),(one([1],[-1,1]),b'ab'),
                               (one([1],[0,2],'I8'),b'ab')):
            self.refused(self.invoke(raw_file(header,payload)))
        overlap={'a':dict(dtype='F16',shape=[2],data_offsets=[0,4]),
                 'b':dict(dtype='F16',shape=[2],data_offsets=[2,6])}
        self.refused(self.invoke(raw_file(json.dumps(overlap),b'12345678')))
        for offset in range(5):
            obj={'weight':dict(dtype='F32',shape=[1],data_offsets=[0,4]),
                 'empty':dict(dtype='F32',shape=[0],data_offsets=[offset,offset])}
            raw=raw_file(json.dumps(obj),b'1234')
            result=self.invoke(raw)
            if offset in (0,4):
                self.accepted(result);self.oracle(raw)
            else:
                self.refused(result)
                with self.assertRaises(Exception):self.oracle(raw)

    def test_unknown_fields_strict_number_and_nesting_budget(self):
        for value in ('true','false','null','0','-1','1.25','1e-3','{"a":[1,"x",null]}'):
            header='{"x":{"dtype":"F16","shape":[1],"data_offsets":[0,2],"other":'+value+'}}'
            raw=raw_file(header,b'ab')
            self.accepted(self.invoke(raw));self.oracle(raw)
        for value in ('-','1.','1e','1e+','01','1+2','+1','[1,]','{"a":1,}'):
            header='{"x":{"dtype":"F16","shape":[1],"data_offsets":[0,2],"other":'+value+'}}'
            self.refused(self.invoke(raw_file(header,b'ab')))
        header='{"x":{"dtype":"F16","shape":[1],"data_offsets":[0,2],"other":'+('['*8)+'0'+(']'*8)+'}}'
        raw=raw_file(header,b'ab')
        self.accepted(self.invoke(raw,(65536,64,32,16384,9)))
        self.refused(self.invoke(raw,(65536,64,32,16384,8)))

    def test_legacy_reader_defaults_header_only_regression(self):
        binary=str(Path(CONFIG.legacy).resolve(strict=True))
        for dtype,shape in (("F16",[2,3]),("BF16",[2,3]),("F32",[2,3]),("F16",[]),("F32",[0])):
            raw,expected,_=fixture([('legacy',dtype,shape)],{'source':'preserved'})
            path=self.root/('legacy-'+dtype+'-'+str(len(shape))+'.safetensors');path.write_bytes(raw)
            result=subprocess.run([binary,str(path)],capture_output=True,text=True,timeout=10)
            self.records.append(dict(mode='legacy-header-only',returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('ST-CHECK-DONE',result.stdout)
            self.assertIn('name=legacy dtype='+dtype,result.stdout)
            self.assertNotIn('REJECT:',result.stdout)
            self.assertNotIn('cksum ',result.stdout)

    def test_owner_cleanup_reopen_and_independent_snapshot_lifetimes(self):
        good=self.root/'owner-good.safetensors'
        good.write_bytes(fixture([('x','F16',[2,3])],{'original':'yes'})[0])
        for i,raw in enumerate((b'bad',raw_file('{bad'),raw_file('{}',b'x'))):
            bad=self.root/('owner-bad-'+str(i)+'.safetensors');bad.write_bytes(raw)
            command=[self.api,str(good),str(bad)]
            if i == 1:
                command=[CONFIG.strace,'-y','-o',str(self.evidence/'owner.strace'),
                         '-e','trace=openat,close,mmap,munmap,ioctl',*command]
            result=subprocess.run(command,capture_output=True,text=True,timeout=10)
            self.records.append(dict(mode='api-owner',returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
            obj=self.accepted(result)
            self.assertEqual(obj['cleanup_cycles'],20)
        trace=(self.evidence/'owner.strace').read_text()
        for path in (good,self.root/'owner-bad-1.safetensors'):
            opens=[line for line in trace.splitlines() if 'openat(' in line and str(path) in line]
            closes=[line for line in trace.splitlines() if 'close(' in line and '<'+str(path)+'>' in line]
            self.assertEqual(len(opens),len(closes),(path,opens,closes))

    def test_read_only_source_trace_and_special_file_refusal(self):
        self.check(fixture([('x','F32',[2,3])]),trace=True)
        trace=(self.evidence/'inventory.strace').read_text()
        for forbidden in ('h1x-','ioctl(','libhailort','libcuda','libggml','_safetensors_rust','libtorch'):
            self.assertNotIn(forbidden,trace)
        source_lines=[line for line in trace.splitlines() if '.safetensors>' in line or '.safetensors"' in line]
        self.assertTrue(any('O_RDONLY' in line and 'O_NONBLOCK' in line for line in source_lines))
        self.assertTrue(any('mmap(' in line and 'PROT_READ,' in line and 'MAP_PRIVATE' in line for line in source_lines))
        fifo=self.root/'not-a-model';os.mkfifo(fifo)
        result=subprocess.run([self.binary,str(fifo),'1000','10','10','1000','10'],capture_output=True,text=True,timeout=3)
        self.records.append(dict(mode='fifo',returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
        self.refused(result)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','api','legacy','strace','evidence'):
        parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
