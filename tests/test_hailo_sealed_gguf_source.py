#!/usr/bin/env python3
"""Synthetic source parsing, immutable mapped bytes and isolated constants; no forwards."""
import argparse
from collections import Counter
import hashlib,json,os,random,struct,subprocess,sys,unittest
from pathlib import Path
from test_hailo_source_digest import GEOMETRIES
CONFIG=argparse.Namespace()
def string(value):
    if isinstance(value,str):value=value.encode()
    return struct.pack('<Q',len(value))+value

def fixture(kind=1,alignment=32,columns=None,rows=2,tail=b'\x91',extra=(),rank=None,declare_alignment=True):
    block,size=GEOMETRIES[kind];columns=columns or block*2
    # Original raw source words; deliberately include signed zero/NaN payload bits.
    rng=random.Random(417+kind);payload=rng.randbytes(columns//block*size*rows)
    meta=[('general.architecture',8,string('llama'))]
    if declare_alignment:meta.append(('general.alignment',4,struct.pack('<I',alignment)))
    meta.extend(extra)
    prefix=bytearray(struct.pack('<IIQQ',0x46554747,3,1,len(meta)));fields=[]
    for key,k,value in meta:
        prefix+=string(key)+struct.pack('<I',k);start=len(prefix);prefix+=value
        fields.append((key,k,start,len(prefix),value.hex()))
    axes=[columns] if (rank==1 or rows==1) else [columns,rows]
    prefix+=string('matrix.weight')+struct.pack('<I',len(axes))+b''.join(struct.pack('<Q',x) for x in axes)+struct.pack('<IQ',kind,0)
    origin=(len(prefix)+alignment-1)//alignment*alignment
    raw=bytes(prefix)+bytes(origin-len(prefix))+payload+tail
    return raw,{'fields':fields,'axes':axes,'kind':kind,'origin':origin,'payload':payload,'columns':columns,'rows':rows}

class SealedGGUF(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api=str(Path(CONFIG.api).resolve(strict=True));cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False);cls.fixtures=cls.out/'fixtures';cls.fixtures.mkdir()
        cls.records=[];cls.ids={};cls.traces=[];cls.comparisons=Counter()
    @classmethod
    def tearDownClass(cls):
        for name,obj in [('runs',cls.records),('fixtures',cls.ids),('trace-manifest',cls.traces)]:
            (cls.out/(name+'.json')).write_text(json.dumps(obj,indent=2)+'\n')
        result={'calls':len(cls.records),'outcomes':dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records)),'traces':len(cls.traces),'complete_comparisons':dict(cls.comparisons)}
        (cls.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
    def save(self,raw):
        p=self.fixtures/f'{len(self.ids)}.gguf';p.write_bytes(raw);self.ids[str(p)]={'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'hex':raw.hex()};return p
    def call(self,cmd,path=None,trace=False,fault=None,mutation=None):
        cmd=list(map(str,cmd));env=os.environ.copy();index=len(self.records);tracepath=self.out/f'trace-{index}.strace'
        if fault:
            if fault.startswith('copy:'):
                env.update(LD_PRELOAD=str(Path(CONFIG.copy_faults).resolve()),AESIR_SEAL_FAULT_PATH=str(path),AESIR_SEAL_FAULT_MODE=fault[5:],AESIR_SEAL_FAULT_LOG=str(self.out/f'fault-{index}.jsonl'))
            else:env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_SEALED_GGUF_FAULT=fault)
        if trace:cmd=[CONFIG.strace,'-f','-y','-o',str(tracepath),*cmd]
        before=Path(path).read_bytes() if path and Path(path).is_file() else None
        p=subprocess.run(cmd,capture_output=True,text=True,timeout=60,env=env,stdin=subprocess.DEVNULL)
        self.records.append({'arguments':cmd,'returncode':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'source':str(path) if path else None,'fault':fault,'mutation':mutation})
        if trace:self.traces.append({'trace':str(tracepath),'run_index':index})
        if before is not None and not mutation:self.assertEqual(Path(path).read_bytes(),before)
        return p
    def api_call(self,mode,path,label='/aesir-sealed-provenance-must-not-open',**kw):
        return self.call([self.api,mode,path,label],path=path,**kw)
    def ok(self,p):self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'');return p.stdout
    def no(self,p):
        self.assertGreater(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stdout,'');self.assertNotIn('test:',p.stderr);return p
    def snapshot(self,out,raw,info,digest=True):
        lines=out.splitlines()
        if digest:self.assertEqual(lines.pop(0),'digest '+hashlib.sha256(raw).hexdigest())
        self.assertEqual(lines.pop(0),f"header 3 1 {len(info['fields'])} {info['origin']} {len(raw)}")
        for key,k,start,end,value in info['fields']:
            name=''.join(str(b)+',' for b in key.encode())
            self.assertEqual(lines.pop(0),f'field {name} {k} {start} {end} {value}')
        shape=''.join(str(x)+',' for x in info['axes'])
        self.assertEqual(lines.pop(0),f"tensor matrix.weight {shape} {info['kind']} {info['origin']} {len(info['payload'])} {info['payload'].hex()}")
        self.assertEqual(lines,['bytes '+raw.hex(),'default 97']);self.comparisons['full_metadata_axes_binding_payload_and_file']+=1;self.comparisons['raw_bytes']+=len(raw)
    def test_all_geometries_full_source_constants_and_tiles(self):
        for kind in GEOMETRIES:
            raw,info=fixture(kind);path=self.save(raw)
            self.snapshot(self.ok(self.api_call('sealed',path,trace=True)),raw,info)
            self.snapshot(self.ok(self.api_call('path',path)),raw,info,False)
            expected=self.ok(self.api_call('path_constants',path,'matrix.weight'))
            actual=self.ok(self.api_call('constants',path,'matrix.weight'))
            self.assertEqual(actual,expected);obj=json.loads(actual)
            self.assertEqual(len(obj if isinstance(obj,list) else obj['components']),info['columns']*info['rows'])
            self.comparisons['complete_constant_components']+=info['columns']*info['rows']
            expected=self.ok(self.api_call('path_tiles',path,'matrix.weight'))
            actual=self.ok(self.api_call('tiles',path,'matrix.weight',trace=kind in (0,8,23)))
            self.assertEqual(actual,expected)
            block,size=GEOMETRIES[kind]
            for line in actual.splitlines():
                tile=json.loads(line);self.assertEqual(tile['binding'],[info['origin'],info['columns'],info['rows'],kind,len(info['payload'])])
                selected=bytearray()
                for row,offset,n,covered,elements,prefix,suffix,payloadoffset in tile['spans']:
                    self.assertEqual(payloadoffset,len(selected));self.assertEqual(offset,info['origin']+row*(info['columns']//block*size)+covered//block*size)
                    selected+=raw[offset:offset+n]
                self.assertEqual(bytes(tile['payload']),selected);self.comparisons['complete_byte_tiles']+=1
    def test_semantic_bindings_and_tied_weight_alias(self):
        from test_hailo_semantic_plan import dense_fixture
        for tied in (False,True):
            for layers in (1,2):
                raw,expected,origin=dense_fixture(tied=tied,layers=layers)
                path=self.save(raw)
                for query,past in ((1,0),(2,3)):
                    expected_text=self.ok(self.call([CONFIG.semantic_control,path,query,past,16],path=path))
                    actual=self.ok(self.call([CONFIG.semantic_api,path,query,past,16],path=path,trace=True))
                    self.assertEqual(actual,expected_text)
                    obj=json.loads(actual);self.assertFalse(obj['execution_tested']);self.assertFalse(obj['source_fingerprint_verified'])
                    self.assertEqual(obj['weight_bytes'],sum(v['byte_count'] for v in expected.values()))
                    for name,binding in obj['weights'].items():self.assertEqual(binding,expected[name])
                    if tied:self.assertNotIn('output.weight',obj['weights'])
                    self.comparisons['complete_semantic_graphs_and_weight_bindings']+=1

    def test_metadata_scalars_arrays_unicode_nul_and_alignment(self):
        extra=[('nul\0rune-æ',8,string('value\0雪')),('u8',0,b'\xff'),('i8',1,b'\x80'),('u16',2,b'\xfe\xff'),('i16',3,b'\x00\x80'),('u32',4,struct.pack('<I',0xffffffff)),('i32',5,struct.pack('<i',-7)),('f32',6,struct.pack('<I',0x7fc12345)),('bool',7,b'\x01'),('u64',10,struct.pack('<Q',0xffffffffffffffff)),('i64',11,struct.pack('<q',-17)),('f64',12,struct.pack('<Q',0x7ff812345678abcd)),('a0',9,struct.pack('<IQ',4,0)),('a1',9,struct.pack('<IQIII',4,3,5,5,5)),('astr',9,struct.pack('<IQ',8,2)+string('x\0y')+string('λ'))]
        for alignment in (1,2,16,32,64,4096):
            raw,info=fixture(extra=extra,alignment=alignment);path=self.save(raw)
            self.snapshot(self.ok(self.api_call('sealed',path,trace=alignment==4096)),raw,info)
            self.snapshot(self.ok(self.api_call('path',path)),raw,info,False)
        raw,info=fixture(declare_alignment=False);path=self.save(raw)
        self.snapshot(self.ok(self.api_call('sealed',path,trace=True)),raw,info)
        self.snapshot(self.ok(self.api_call('path',path)),raw,info,False)
        # Legal odd tails and source sizes around kernel-page boundaries.
        for target in (4095,4096,4097,16383,16384,16385):
            raw,info=fixture();raw+=bytes(target-len(raw));path=self.save(raw)
            self.snapshot(self.ok(self.api_call('sealed',path,trace=True)),raw,info)
    def test_original_changes_after_copy_do_not_change_parse(self):
        for mode in ('truncate','mutate','replace'):
            raw,info=fixture(23);path=self.save(raw)
            self.snapshot(self.ok(self.api_call(mode,path,trace=True,mutation=mode)),raw,info)
            expected={'truncate':raw[:1],'mutate':raw[:-1]+b'\xad','replace':b''}[mode]
            self.assertEqual(path.read_bytes(),expected);self.comparisons['complete_original_post_mutation']+=1
    def test_owner_transfer_bounds_refusals_and_recovery(self):
        self.assertEqual(self.ok(self.call([self.api,'default'],trace=True)),'refused\n')
        raw,info=fixture();path=self.save(raw)
        for mode in ('transfer','size_transfer','fd_transfer','arch_transfer','unsealed_transfer','adopt_size','adopt_closed','adopt_unsealed','adopt_negative','adopt_large','capacity','cleanup_capacity','busy_alias','busy_distinct'):
            out=self.ok(self.api_call(mode,path,trace=True))
            if mode.startswith('busy'):self.snapshot(out,raw,info,False)
            else:self.assertEqual(out,('transferred' if mode=='transfer' else 'bounded' if 'capacity' in mode else 'refused')+'\n')
        for mode in ('path_capacity','sealed_reentry'):
            self.assertEqual(self.ok(self.call([CONFIG.semantic_api,path,mode,0,0],path=path,trace=True)),'bounded\n')
        self.no(self.api_call('digest_zero',path,trace=True))
        # Fresh path wrapper success after all failures; public digest claim was forged in API.
        p=self.call([self.binary,path,len(raw),1,1,1],path=path,trace=True);obj=json.loads(self.ok(p))
        self.assertEqual(obj['digest_hex'],hashlib.sha256(raw).hexdigest());self.assertTrue(obj['sealed_input_bytes_bound'])
        for key in ('atomic_original_snapshot_verified','source_fingerprint_verified','immutable_source_verified','binding_identity_verified','execution_tested','device_access'):self.assertFalse(obj[key])
    def test_parser_refusals_budgets_and_fault_cleanup(self):
        raw,info=fixture()
        invalid=[b'',raw[:1],raw[:23],b'FAIL'+raw[4:],raw[:4]+struct.pack('<I',2)+raw[8:],raw[:24],raw[:-len(info['payload'])-1],raw[:8]+struct.pack('<QQ',100001,0)]
        # Existing table/shape/metadata admissions remain shared by both routes.
        for extra in ([('general.architecture',8,string('duplicate'))],[('nested',9,struct.pack('<IQ',9,0))],[('bad',13,b'')]):
            invalid.append(fixture(extra=extra)[0])
        for alignment in (3,8192):invalid.append(fixture(alignment=alignment)[0])
        dims=info['fields'][-1][3]+len(string('matrix.weight'))
        columns=dims+4;rows=columns+8;kind=rows+8;relative=kind+4
        for position,fmt,value in ((dims,'I',0),(dims,'I',3),(columns,'Q',0),(columns,'Q',1048577),(rows,'Q',0),(rows,'Q',1048577),(kind,'I',15),(relative,'Q',2),(relative,'Q',4096),(relative,'Q',1<<63)):
            data=bytearray(raw);struct.pack_into('<'+fmt,data,position,value);invalid.append(bytes(data))
        data=bytearray(raw);data[32]=255;invalid.append(bytes(data))
        invalid.append(fixture(extra=[('overflow-array',9,struct.pack('<IQ',4,(1<<64)-1))])[0])
        for data in invalid:
            path=self.save(data)
            old=self.no(self.api_call('path',path));new=self.no(self.api_call('sealed',path,trace=True))
            import re
            error=lambda p:re.search(r'Unhandled exception caught during execution:\s*([^\n]+)',p.stderr)[1]
            # Sealed admission retains the old undersized-header message.
            self.assertEqual(error(new),error(old));self.comparisons['complete_parser_refusal_pairs']+=1
        raw,info=fixture();path=self.save(raw)
        for bound,reads,writes,digests in ((0,1,1,1),(len(raw)-1,1,1,1),(len(raw),0,1,1),(len(raw),1,0,1),(len(raw),1,1,0)):
            self.no(self.call([self.binary,path,bound,reads,writes,digests],path=path,trace=True))
        for mode in ('parser_digest','transfer','admit','mmap','copy:create','copy:read_error','copy:write_error','copy:seal','copy:digest_error'):
            self.no(self.call([self.binary,path,len(raw),1,1,1],path=path,trace=True,fault=mode))
            self.ok(self.call([self.binary,path,len(raw),1,1,1],path=path))

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','api','semantic-api','semantic-control','faults','copy-faults','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
