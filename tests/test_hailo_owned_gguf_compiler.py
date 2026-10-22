#!/usr/bin/env python3
"""Owned input/compiler/byte lifetime oracles on synthetic files; no forwards."""
import argparse
from collections import Counter
import hashlib,json,os,random,re,struct,subprocess,sys,unittest
from pathlib import Path
from test_hailo_semantic_plan import dense_fixture
import test_hailo_semantic_plan as semantic_oracle
import test_hailo_expanded_graph as expanded_oracle
from test_hailo_source_digest import GEOMETRIES
from test_hailo_source_inventory import string
CONFIG=argparse.Namespace()


def geometry_fixture(kind,tied=False):
    # Re-encode a test-owned ordinary GGUF directory with independent raw payloads.
    raw,weights,_=dense_fixture(hidden=256,heads=4,kv_heads=2,key=64,value=64,ff=256,vocab=2,tied=tied)
    cursor=24
    for _ in range(struct.unpack_from('<Q',raw,16)[0]):
        n=struct.unpack_from('<Q',raw,cursor)[0];cursor+=8+n
        tag=struct.unpack_from('<I',raw,cursor)[0];cursor+=4
        if tag==8:cursor+=8+struct.unpack_from('<Q',raw,cursor)[0]
        else:cursor+={4:4,6:4,10:8}[tag]
    prefix=raw[:cursor];directory=bytearray();payload=bytearray();expected={}
    for name,binding in weights.items():
        cols,rows=binding['columns'],binding['rows'];tag=0 if rows==1 else kind
        block,size=GEOMETRIES[tag];n=cols//block*size*rows
        offset=(len(payload)+31)//32*32;payload+=bytes(offset-len(payload))
        directory+=string(name)+struct.pack('<I',1 if rows==1 else 2)+struct.pack('<Q',cols)
        if rows!=1:directory+=struct.pack('<Q',rows)
        directory+=struct.pack('<IQ',tag,offset)
        payload+=random.Random(300+tag+offset).randbytes(n)
        expected[name]=dict(file_offset=offset,columns=cols,rows=rows,source_kind=tag,byte_count=n)
    origin=(len(prefix)+len(directory)+31)//32*32
    for b in expected.values():b['file_offset']+=origin
    return prefix+directory+bytes(origin-len(prefix)-len(directory))+payload,expected,origin


class OwnedCompiler(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.out=Path(CONFIG.evidence).resolve();cls.out.mkdir(parents=True,exist_ok=False)
        cls.records=[];cls.fixtures={};cls.comparisons=Counter();cls.traces=[]
        cls.bins={k:Path(v).resolve(strict=True) for k,v in vars(CONFIG).items() if k not in ('evidence','strace','faults')}
    @classmethod
    def tearDownClass(cls):
        for name,data in [('runs',cls.records),('fixtures',cls.fixtures),('trace-manifest',cls.traces)]:
            (cls.out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
        result=dict(calls=len(cls.records),outcomes=dict(Counter(r['returncode'] for r in cls.records)),comparisons=dict(cls.comparisons),traces=len(cls.traces))
        (cls.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n');print(result)
    def save(self,generated=None):
        raw,bindings,origin=generated or dense_fixture()
        path=self.out/f'fixture-{len(self.fixtures)}.gguf';path.write_bytes(raw)
        self.fixtures[str(path)]=dict(bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),hex=bytes(raw).hex())
        return path,bytes(raw),bindings
    def call(self,key,*args,trace=False,fault=None,mutation=False):
        command=[str(self.bins[key]),*map(str,args)];env=os.environ.copy();index=len(self.records)
        if fault:env.update(LD_PRELOAD=str(Path(CONFIG.faults).resolve()),AESIR_OWNED_COMPILER_FAULT=fault)
        if trace:
            tracepath=self.out/f'trace-{index}.strace';command=[CONFIG.strace,'-f','-y','-o',str(tracepath),*command]
            self.traces.append(dict(trace=str(tracepath),run_index=index))
        files={str(a):Path(a).read_bytes() for a in args if isinstance(a,Path) and a.is_file()}
        result=subprocess.run(command,capture_output=True,text=True,env=env,timeout=90,stdin=subprocess.DEVNULL)
        self.records.append(dict(arguments=command,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr,fault=fault,mutation=mutation))
        if not mutation:
            for p,raw in files.items():self.assertEqual(Path(p).read_bytes(),raw)
        return result
    def api(self,mode,path,session=(2,0,16),**kw):return self.call('api',mode,path,*session,**kw)
    def ok(self,p):self.assertEqual(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stderr,'');return p.stdout
    def no(self,p):self.assertGreater(p.returncode,0,p.stdout+p.stderr);self.assertEqual(p.stdout,'');self.assertNotIn('test:',p.stderr)
    def controls(self,path,session):
        return [json.loads(self.ok(self.call(key,path,*session))) for key in ('semantic','recipes','expanded')]
    def check_all(self,path,raw,bindings,session=(2,0,16),mode='accept',trace=True):
        controls=self.controls(path,session)
        oldconstants=self.ok(self.call('sealed_api','path_constants',path,'output.weight' if 'output.weight' in bindings else 'token_embd.weight'))
        lines=self.ok(self.api(mode,path,session,trace=trace)).splitlines()
        self.assertEqual(lines[0],hashlib.sha256(raw).hexdigest())
        actual=[json.loads(line) for line in lines[1:4]]
        self.assertEqual(actual,controls);self.comparisons['complete_semantic_recipe_global_triples']+=1
        semantic_oracle.SemanticPlan().check_graph(actual[0]);expanded_oracle.ExpandedGraph().check_integration(actual[2],actual[0],actual[1],bindings)
        self.assertEqual(json.loads(lines[4]),json.loads(oldconstants));self.comparisons['complete_source_components']+=len(json.loads(lines[4]) if isinstance(json.loads(lines[4]),list) else json.loads(lines[4])['components'])
        self.check_tile(json.loads(lines[5]),raw,bindings)
        oldtile=json.loads(self.ok(self.call('weight_tiles',path,*session,len(actual[0]['operations'])-1,1,1,130,0,16777216,16777216)))
        self.assertEqual(json.loads(lines[5]),oldtile);self.comparisons['complete_legacy_tile_outputs']+=1
        return lines
    def check_tile(self,tile,raw,bindings):
        b=bindings[tile['weight']];self.assertEqual(tile['binding'],list(b.values()))
        payload=[];block,size=GEOMETRIES[b['source_kind']]
        for row,offset,n,covered,elements,prefix,suffix,start in tile['spans']:
            self.assertEqual(offset,b['file_offset']+row*b['columns']//block*size+covered//block*size)
            self.assertEqual(start,len(payload));self.assertEqual(n,elements//block*size)
            payload+=raw[offset:offset+n]
        self.assertEqual(payload,tile['payload']);self.comparisons['complete_byte_tiles']+=1;self.comparisons['exact_payload_bytes']+=len(payload)
    def test_complete_graphs_ties_sessions_defaults_scalars(self):
        for tied in (False,True):
            for layers in (1,2):
                path,raw,bindings=self.save(dense_fixture(tied=tied,layers=layers))
                for session in ((1,0,1),(2,3,16),(3,0,16)):
                    self.check_all(path,raw,bindings,session)
        for generated in (dense_fixture(kv_heads=4,explicit_dims=False,drop=('llama.attention.head_count_kv',)),dense_fixture(overrides={'llama.rope.freq_base':(6,12345.),'llama.attention.layer_norm_rms_epsilon':(6,0.002)})):
            self.check_all(*self.save(generated))
    def test_all_current_geometries_components_tiles_and_owned_move(self):
        for kind in GEOMETRIES:
            path,raw,bindings=self.save(geometry_fixture(kind))
            self.check_all(path,raw,bindings,mode='move')
            tiles=self.ok(self.api('tiles',path,trace=True)).splitlines()
            for tile in tiles:self.check_tile(json.loads(tile),raw,bindings)
            retained=json.loads(self.ok(self.api('retained',path,trace=True)))
            self.assertEqual(retained,json.loads(tiles[0]));self.check_tile(retained,raw,bindings)
    def test_forged_caches_hashes_and_full_parser_snapshot(self):
        path,raw,bindings=self.save()
        normal=self.check_all(path,raw,bindings)
        forged=self.check_all(path,raw,bindings,mode='cache');self.assertEqual(normal,forged)
        actual=self.ok(self.api('snapshot',path,trace=True))
        expected=self.ok(self.call('sealed_api','path',path,path));self.assertEqual(actual,expected)
        self.comparisons['complete_parser_snapshot']+=1
    def test_original_changes_after_copy_before_compile(self):
        for mode in ('truncate','mutate','replace'):
            path,raw,bindings=self.save();expected=self.check_all(path,raw,bindings)
            actual=self.ok(self.api(mode,path,trace=True,mutation=True)).splitlines();post=path.read_bytes()
            self.assertEqual(actual,expected);self.assertEqual(post,raw[:1] if mode=='truncate' else b'')
            # Restore complete preimage, run separate repeat, compare complete postimage.
            path.write_bytes(raw)
            repeat=self.ok(self.api(mode,path,mutation=True)).splitlines()
            self.assertEqual(repeat,actual);self.assertEqual(path.read_bytes(),post)
            self.comparisons['complete_mutation_preimage_postimage_pairs']+=1
    def test_stale_owner_graph_schedule_bounds_and_recovery(self):
        path,raw,bindings=self.save()
        for mode in ('owner_closed','owner_size','owner_declared','digest_zero','closed','source_size','source_data','source_binding','graph_size','graph_architecture','graph_binding','graph_storage','graph_file','graph_operation','graph_lifetime','schedule_binding','policy','index','bound','operation'):
            self.no(self.api(mode,path,trace=True))
        self.assertEqual(self.ok(self.api('owner_capacity',path,trace=True)),'refused\n')
        # A >4KiB source forces the compiler's one-call digest permit to exhaust.
        path,raw,bindings=self.save(geometry_fixture(1));self.no(self.api('digest_short',path,trace=True))
        actual=self.ok(self.api('recovery',path,trace=True));self.assertEqual(json.loads(actual),self.controls(path,(2,0,16))[2])
        self.check_all(path,raw,bindings)
    def test_compiler_failure_seams_and_fresh_success(self):
        path,raw,bindings=self.save()
        for mode in ('compiler_digest','compiler_seals'):
            self.no(self.api('accept',path,trace=True,fault=mode))
            self.check_all(path,raw,bindings)
        for session in ((0,0,16),(1,-1,16),(2,15,16),(1,0,0)):
            self.no(self.api('accept',path,session,trace=True))
        self.check_all(path,raw,bindings)
    def test_path_factory_diagnostics_and_explicit_budgets(self):
        path,raw,bindings=self.save()
        args=[path,len(raw),4096,4096,4096,2,0,16]
        obj=json.loads(self.ok(self.call('binary',*args,trace=True)))
        self.assertTrue(obj['compiler_input_bytes_bound']);self.assertEqual(obj['digest_hex'],hashlib.sha256(raw).hexdigest())
        for key,value in obj.items():
            if key.endswith('_verified') or key in ('execution_tested','device_access'):self.assertFalse(value)
        self.assertEqual([obj[k] for k in ('semantic','recipes','expanded')],self.controls(path,(2,0,16)))
        for index,value in ((1,len(raw)-1),(1,0),(2,0),(3,0),(4,0)):
            invalid=args.copy();invalid[index]=value;self.no(self.call('binary',*invalid,trace=True))
        self.comparisons['complete_path_factory_outputs']+=1
    def test_current_source_and_lowering_refusals_match_controls(self):
        cases=[dense_fixture(drop=('llama.rope.freq_base',)),dense_fixture(drop=('llama.attention.layer_norm_rms_epsilon',)),dense_fixture(architecture='unknown'),dense_fixture(overrides={'llama.embedding_length':(4,0)}),dense_fixture(omit=('blk.0.attn_q.weight',)),dense_fixture(overrides={'llama.rope.scaling.type':(8,'unsupported')})]
        for generated in cases:
            path,raw,bindings=self.save(generated)
            old=self.call('expanded',path,2,0,16);new=self.api('expanded',path,trace=True)
            self.no(old);self.no(new)
            message=lambda p:re.search(r'Unhandled exception caught during execution:\s*([^\n]+)',p.stderr)[1]
            self.assertEqual(message(old),message(new));self.comparisons['full_handled_refusal_pairs']+=1

if __name__=='__main__':
    ap=argparse.ArgumentParser()
    for name in ('binary','api','semantic','recipes','expanded','sealed-api','weight-tiles','faults','strace','evidence'):ap.add_argument('--'+name,required=True)
    CONFIG,remaining=ap.parse_known_args();unittest.main(argv=[sys.argv[0],*remaining])
