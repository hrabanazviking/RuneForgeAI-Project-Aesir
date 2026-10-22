#!/usr/bin/env python3
"""Independent owned header/component/lifetime checks; no model evaluation."""
import argparse
from collections import Counter
import hashlib,json,os,random,re,struct,subprocess,sys,unittest
from pathlib import Path
from test_hailo_safetensors_constants import source,TYPES
from test_hailo_safetensors_inventory import fixture,raw_file
from test_hailo_source_float_constants import oracle16
CONFIG=argparse.Namespace()


class SealedSafetensors(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api=str(Path(CONFIG.api).resolve(strict=True));cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.constants=str(Path(CONFIG.constants).resolve(strict=True));cls.inventory=str(Path(CONFIG.inventory).resolve(strict=True))
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.records=[];cls.ids={};cls.traces=[];cls.comparisons=Counter()
    @classmethod
    def tearDownClass(cls):
        for name,obj in [('runs',cls.records),('fixtures',cls.ids),('trace-manifest',cls.traces)]:
            (cls.out/(name+'.json')).write_text(json.dumps(obj,indent=2)+'\n')
        summary=dict(calls=len(cls.records),outcomes=dict(Counter(r['returncode'] for r in cls.records)),traces=len(cls.traces),comparisons=dict(cls.comparisons))
        (cls.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary)
    def save(self,raw):
        p=self.out/f'fixture-{len(self.ids)}.safetensors';p.write_bytes(raw);self.ids[str(p)]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),hex=raw.hex());return p
    def call(self,cmd,path=None,trace=False,mutation=False,fault=None):
        command=list(map(str,cmd));env=os.environ.copy();index=len(self.records)
        if fault:
            if fault=='same_extent':env.update(LD_PRELOAD=str(Path(CONFIG.mutation_faults).resolve()),AESIR_SAFETENSORS_MUTATION_PATH=str(path))
            elif fault.startswith('copy:'):env.update(LD_PRELOAD=str(Path(CONFIG.copy_faults).resolve()),AESIR_SEAL_FAULT_PATH=str(path),AESIR_SEAL_FAULT_MODE=fault[5:],AESIR_SEAL_FAULT_LOG=str(self.out/f'fault-{index}.jsonl'))
            else:env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_SEALED_GGUF_FAULT=fault)
        if trace:
            tracepath=self.out/f'trace-{index}.strace';command=[CONFIG.strace,'-f','-y','-o',str(tracepath),*command]
            self.traces.append(dict(trace=str(tracepath),run_index=index))
        before=Path(path).read_bytes() if path and Path(path).is_file() else None
        p=subprocess.run(command,capture_output=True,text=True,timeout=90,stdin=subprocess.DEVNULL,env=env)
        self.records.append(dict(arguments=command,returncode=p.returncode,stdout=p.stdout,stderr=p.stderr,path=str(path) if path else None,fault=fault,mutation=mutation))
        if before is not None and not mutation:self.assertEqual(Path(path).read_bytes(),before)
        return p
    def api_call(self,mode,path,name='weight',first=0,count=1,bound=None,policies=(1048576,1024,64,16777216,64),**kw):
        return self.call([self.api,mode,path,name.encode().hex(),first,count,max(1,count) if bound is None else bound,*policies],path=path,**kw)
    def ok(self,p):self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'');return p.stdout
    def no(self,p):self.assertGreater(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stdout,'');self.assertNotIn('test:',p.stderr)
    def snapshot(self,path,raw,mode='snapshot',**kw):
        expected=json.loads(self.ok(self.call([self.inventory,path,1048576,1024,64,16777216,64],path=path)))
        lines=self.ok(self.api_call(mode,path,**kw)).splitlines()
        self.assertEqual(lines[0],hashlib.sha256(raw).hexdigest());self.assertEqual(json.loads(lines[1]),expected);self.assertEqual(lines[2],raw.hex());self.assertEqual(len(lines),3)
        self.comparisons['complete_header_metadata_axes_bindings_and_source']+=1;self.comparisons['exact_source_bytes']+=len(raw)
        return lines
    def window(self,dtype,words,shape=None,name='weight',first=0,count=None,mode='constants',trace=False):
        raw,base=source(dtype,words,shape,name);path=self.save(raw);count=len(words)-first if count is None else count
        actual=json.loads(self.ok(self.api_call(mode,path,name,first,count,trace=trace)))
        expected=json.loads(self.ok(self.call([self.constants,path,name.encode().hex(),first,count,max(1,count),1048576,1024,64,16777216,64],path=path)))
        self.assertEqual(actual,expected)
        selected=words[first:first+count];expanded=selected if dtype=='F32' else [oracle16(1 if dtype=='F16' else 30,w) for w in selected]
        self.assertEqual(actual['raw_words'],selected);self.assertEqual(actual['binary32_words'],expanded)
        self.assertEqual(actual['shape'],[len(words)] if shape is None else shape)
        self.assertEqual(actual['file_offset'],base);self.assertEqual(actual['byte_count'],len(words)*TYPES[dtype][1])
        self.comparisons['complete_component_windows']+=1;self.comparisons['raw_and_binary32_words']+=2*count
        return path,raw,actual
    def test_exhaustive_f16_bf16_and_seeded_f32_complete_words(self):
        for dtype in ('F16','BF16'):self.window(dtype,list(range(65536)),[256,256],trace=True)
        rng=random.Random(4821);words=[0,0x80000000,0x7f800001,0xff800001,0x7fc12345,0xffffffff,1,0x7f800000]+[rng.getrandbits(32) for _ in range(504)]
        self.window('F32',words,[2,4,64],trace=True)
        for first,count in ((0,0),(1,1),(19,11),(511,1),(512,0)):self.window('F32',words,[2,4,64],first=first,count=count,trace=True)
    def test_rank_scalar_empty_metadata_unicode_and_page_boundaries(self):
        for dtype in TYPES:
            for shape,words in (([],[0x8001]),([1]*64,[0x7c01]),([1]*63+[0],[]),([2,0,3],[])):
                self.window(dtype,words,shape,name='Þór\0雪"\\',mode='retained',trace=True)
        generated=[fixture([('a','F16',[]),('雪\0','BF16',[2,3]),('empty','F32',[0,3]),('b','F32',[2,1,2])],{'nul\0':'雪\0value','quote"':'\\'},pad=7,shuffle=True)[0],raw_file('{}'),raw_file('{"__metadata__":{"source":"empty"}}')]
        for raw in generated:self.snapshot(self.save(raw),raw,trace=True)
        raw,_=source('F16',[0,0x8000])
        n=struct.unpack_from('<Q',raw)[0];header=raw[8:8+n];payload=raw[8+n:]
        for target in (4095,4096,4097,16383,16384,16385):
            padded=raw_file(header+b' '*(target-len(raw)),payload);self.assertEqual(len(padded),target)
            self.snapshot(self.save(padded),padded,trace=True)
    def test_moving_busy_owners_close_capacity_and_recovery(self):
        raw,_=source('F16',[0x8001,0x7c01],[2]);path=self.save(raw)
        self.snapshot(path,raw,mode='move',trace=True)
        for mode in ('busy_alias','busy_distinct','retained','recover'):
            actual=self.ok(self.api_call(mode,path,count=2,trace=True));expected=self.ok(self.api_call('path',path,count=2));self.assertEqual(actual,expected)
            self.comparisons['complete_lifetime_component_pairs']+=1
        for mode in ('adopt_unsealed','adopt_size','adopt_closed','adopt_negative','adopt_large','reopen','read_capacity'):
            self.assertEqual(self.ok(self.api_call(mode,path,trace=True)),'refused\n')
        for mode in ('path_capacity','capacity','cleanup_capacity'):
            self.assertEqual(self.ok(self.api_call(mode,path,trace=True)),'bounded\n')
        expected=self.ok(self.api_call('path_snapshot',path));actual=self.ok(self.api_call('path_reopen',path,trace=True));self.assertEqual(actual,expected)
        for mode in ('closed','owner_size','declared','size_before','digest_zero'):
            self.no(self.api_call(mode,path,trace=True))
        big,_=source('F32',list(range(2048)),[2048]);large=self.save(big);self.no(self.api_call('digest_short',large,trace=True))
        self.snapshot(path,raw,trace=True)
    def test_original_changes_after_copy_before_parse(self):
        for mode in ('truncate','mutate','replace'):
            raw,_=source('BF16',[0x8000,0x7fc1,0xffff],[3]);path=self.save(raw)
            expected=self.snapshot(path,raw)
            actual=self.ok(self.api_call(mode,path,trace=True,mutation=True)).splitlines();post=path.read_bytes()
            self.assertEqual(actual,expected);self.assertEqual(post,raw[:1] if mode=='truncate' else b'')
            path.write_bytes(raw);repeat=self.ok(self.api_call(mode,path,mutation=True)).splitlines();self.assertEqual(repeat,actual);self.assertEqual(path.read_bytes(),post)
            self.comparisons['complete_preimage_postimage_output_pairs']+=1
    def test_same_extent_original_write_after_copy_before_parse(self):
        raw,_=source('F32',[0,0x80000000,0x7fc12345],[3]);path=self.save(raw)
        expected=self.snapshot(path,raw)
        actual=self.ok(self.api_call('snapshot',path,trace=True,mutation=True,fault='same_extent')).splitlines();post=path.read_bytes()
        self.assertEqual(actual,expected);self.assertEqual(post,raw[:-1]+bytes([raw[-1]^0x40]))
        path.write_bytes(raw)
        repeat=self.ok(self.api_call('snapshot',path,mutation=True,fault='same_extent')).splitlines()
        self.assertEqual(repeat,actual);self.assertEqual(path.read_bytes(),post)
        self.comparisons['complete_same_extent_mutation_pairs']+=1
    def test_parser_refusals_match_existing_complete_messages(self):
        bad=[b'',b'\x00',bytes(7),struct.pack('<Q',1)+b'{',struct.pack('<Q',999999),raw_file('[]'),raw_file('{'),raw_file('{"x":{"dtype":"I32","shape":[1],"data_offsets":[0,4]}}',bytes(4)),raw_file('{"x":{"dtype":"F16","shape":[1],"data_offsets":[0,1]}}',bytes(1)),raw_file('{"x":{"dtype":"F16","shape":[1],"data_offsets":[2,4]}}',bytes(4)),raw_file('{"x":{"dtype":"F16","shape":[1],"data_offsets":[0,2]},"x":{"dtype":"F16","shape":[1],"data_offsets":[0,2]}}',bytes(2)),raw_file('{"x":{"dtype":"F16","shape":[-1],"data_offsets":[0,0]}}'),raw_file('{"x":{"dtype":"F16","shape":[9223372036854775807,2],"data_offsets":[0,0]}}'),raw_file('{"__metadata__":{"a":1}}'),raw_file(b'{"\xff":1}'),raw_file('{}garbage')]
        for raw in bad:
            path=self.save(raw);old=self.api_call('path_snapshot',path);new=self.api_call('snapshot',path,trace=True);self.no(old);self.no(new)
            message=lambda p:re.search(r'Unhandled exception caught during execution:\s*([^\n]+)',p.stderr)[1]
            self.assertEqual(message(old),message(new));self.comparisons['complete_parser_refusal_pairs']+=1
    def test_parser_policy_window_bounds_and_stale_source_refusals(self):
        raw,_=source('F32',[0,0x80000000,0x7fc12345],[3]);path=self.save(raw)
        for policies in ((0,10,10,1000,10),(65536,0,10,1000,10),(65536,10,0,1000,10),(65536,10,10,0,10),(65536,10,10,1000,0),(65536,10,10,1000,65),(2,10,10,1000,10)):
            self.no(self.api_call('snapshot',path,policies=policies,trace=True))
        for first,count,bound in ((-1,1,1),(0,-1,1),(4,0,1),(3,1,1),(0,1,0),(0,2,1)):
            self.no(self.api_call('constants',path,first=first,count=count,bound=bound,trace=True))
        self.no(self.api_call('constants',path,name='missing',trace=True))
        self.window('F32',[0,0x80000000,0x7fc12345],[3],mode='retained',trace=True)
    def test_path_factory_positive_budgets_flags_and_fault_cleanup(self):
        raw,_=source('F16',[1,0x8001],[2]);path=self.save(raw);args=[path,len(raw),4096,4096,4096,1048576,1024,64,16777216,64]
        obj=json.loads(self.ok(self.call([self.binary,*args],path,trace=True)));self.assertEqual(obj['digest_hex'],hashlib.sha256(raw).hexdigest());self.assertTrue(obj['sealed_input_bytes_bound']);self.assertEqual(obj['source_bytes'],len(raw))
        for key,value in obj.items():
            if key.endswith('_verified') or key in ('device_access','execution_tested'):self.assertFalse(value)
        for index,value in ((1,0),(1,len(raw)-1),(2,0),(3,0),(4,0)):
            bad=args.copy();bad[index]=value;self.no(self.call([self.binary,*bad],path,trace=True))
        for fault in ('parser_digest','transfer','admit','mmap','copy:create','copy:read_error','copy:write_error','copy:seal','copy:digest_error'):
            self.no(self.call([self.binary,*args],path,trace=True,fault=fault));self.ok(self.call([self.binary,*args],path))
            self.comparisons['failure_then_fresh_success']+=1

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','api','constants','inventory','faults','copy-faults','mutation-faults','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
