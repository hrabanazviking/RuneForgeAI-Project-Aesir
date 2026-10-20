#!/usr/bin/env python3
"""Structural compiler oracle; no host model forward or device execution."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from test_hailo_source_inventory import fixture

CONFIG = argparse.Namespace()
MAX = (1 << 63) - 1


def dense_fixture(layers=1, hidden=8, heads=4, kv_heads=2, key=2, value=2,
                  ff=12, vocab=10, tied=False, overrides=None, drop=(),
                  extra_tensors=(), architecture='llama', explicit_dims=True,
                  omit=(), matrix_kind=1):
    # Test-owned shape definitions; synthetic weights are arbitrary bytes.
    values = {
        'llama.context_length':(10,64), 'llama.embedding_length':(4,hidden),
        'llama.block_count':(4,layers), 'llama.feed_forward_length':(4,ff),
        'llama.attention.head_count':(10,heads), 'llama.attention.head_count_kv':(10,kv_heads),
        'llama.rope.dimension_count':(10,2), 'llama.rope.freq_base':(6,10000.),
        'llama.attention.layer_norm_rms_epsilon':(6,0.00001),
    }
    if explicit_dims:
        values.update({'llama.attention.key_length':(4,key), 'llama.attention.value_length':(4,value)})
    values.update(overrides or {})
    for name in drop:
        values.pop(name, None)
    tensors = [('token_embd.weight',hidden,vocab,1), ('output_norm.weight',hidden,1,0)]
    if not tied:
        tensors.append(('output.weight',hidden,vocab,1))
    shapes = [('attn_norm',hidden,1), ('ffn_norm',hidden,1), ('attn_q',hidden,heads*key),
              ('attn_k',hidden,kv_heads*key), ('attn_v',hidden,kv_heads*value),
              ('attn_output',heads*value,hidden), ('ffn_gate',hidden,ff),
              ('ffn_up',hidden,ff), ('ffn_down',ff,hidden)]
    for layer in range(layers):
        tensors.extend((f'blk.{layer}.{name}.weight',cols,rows,0 if rows == 1 else 1)
                       for name,cols,rows in shapes)
    tensors.extend(extra_tensors)
    tensors = [(name,cols,rows,matrix_kind if kind == 1 else kind)
               for name,cols,rows,kind in tensors if name not in omit]
    return fixture(architecture,tensors,extra_metadata=[(name,kind,value) for name,(kind,value) in values.items()])


BLOCK = ['rms_norm','linear','linear','linear','rope_query','rope_key',
         'kv_append_keys','kv_append_values','gqa_scaled_dot','causal_mask','softmax',
         'gqa_weighted_values','linear','add','rms_norm','linear','linear','silu',
         'multiply','linear','add']


class SemanticPlan(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.temp = tempfile.TemporaryDirectory(prefix='aesir-semantic-plan-')
        cls.root = Path(cls.temp.name)
        cls.evidence = Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records = []

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'fixture-runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()

    def invoke(self, generated=None, session=(3,0,16), trace=False):
        raw,weights,_ = generated or dense_fixture()
        source = self.root / f'fixture-{len(self.records)}.gguf'
        source.write_bytes(raw)
        fingerprint = hashlib.sha256(raw).hexdigest()
        command = [self.binary,str(source),*map(str,session)]
        trace_path = self.evidence/'source-graph.strace'
        if trace:
            command = [CONFIG.strace,'-y','-o',str(trace_path),'-e',
                       'trace=openat,close,mmap,munmap,ioctl',*command]
        result = subprocess.run(command,capture_output=True,text=True,timeout=15,
                                stdin=subprocess.DEVNULL,check=False)
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),fingerprint)
        self.records.append({'source_sha256':fingerprint,'session':session,
            'returncode':result.returncode,'stdout':result.stdout,'stderr':result.stderr})
        return result,weights

    def accepts(self, generated=None, session=(3,0,16), trace=False):
        result,weights = self.invoke(generated,session,trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan['weights'],weights)
        self.assertEqual(plan['weight_bytes'],sum(w['byte_count'] for w in weights.values()))
        for flag in ('execution_tested','executable_program','source_fingerprint_verified','hardware_fit_verified'):
            self.assertIs(plan[flag],False)
        self.assertTrue(plan['unresolved_gates'])
        return plan

    def refuses(self, generated=None, session=(3,0,16), message=None):
        result,_ = self.invoke(generated,session)
        self.assertNotEqual(result.returncode,0)
        if message:
            self.assertIn(message,result.stdout+result.stderr)
        self.assertEqual(result.stdout,'')  # no successful partial graph

    def check_graph(self, plan):
        ops,tensors = plan['operations'],plan['tensors']
        layers = plan['parameters']['layers']
        self.assertEqual([op['kind'] for op in ops],['embedding_gather']+BLOCK*layers+['rms_norm','linear'])
        uses = {i:[] for i in range(len(tensors))}
        for i,op in enumerate(ops):
            self.assertEqual(op['id'],i)
            out = tensors[op['output']]
            self.assertEqual(out['producer'],i)
            for value in op['inputs']:
                self.assertLess(tensors[value]['producer'],i)
                uses[value].append(i)
            if op['weight']:
                self.assertIn(op['weight'],plan['weights'])
                if op['kind'] == 'linear':
                    weight = plan['weights'][op['weight']]
                    before = tensors[op['inputs'][0]]
                    # Flatten all non-token head axes for weight orientation.
                    self.assertEqual(math.prod(before['shape'][1:]),weight['columns'])
                    self.assertEqual(math.prod(out['shape'][1:]),weight['rows'])
        for i,tensor in enumerate(tensors):
            self.assertEqual(tensor['id'],i)
            self.assertEqual(math.prod(tensor['shape']),tensor['elements'])
            end = len(ops) if tensor['persistent'] or i == plan['logits'] else max(uses[i],default=tensor['producer'])
            self.assertEqual(tensor['last_use'],end)
            if tensor['alias_of'] >= 0:
                base = tensors[tensor['alias_of']]
                self.assertTrue(base['persistent'])
                self.assertEqual(tensor['shape'][1:],base['shape'][1:])
                self.assertLessEqual(tensor['elements'],base['elements'])
        named = {t['name']:t for t in tensors}
        # Independent edge oracle by semantic names, including both residuals.
        def edge(output, *inputs):
            tensor = named[output]
            op = ops[tensor['producer']]
            self.assertEqual(op['inputs'],[named[name]['id'] for name in inputs])
        edge('embedding','tokens')
        previous = 'embedding'
        for layer in range(layers):
            p = f'blk.{layer}.'
            edge(p+'attn_norm',previous)
            for name in ('q','k','v'):
                edge(p+name,p+'attn_norm')
            edge(p+'q_rotary',p+'q','positions')
            edge(p+'k_rotary',p+'k','positions')
            edge(p+'keys_view',p+'key_cache',p+'k_rotary')
            edge(p+'values_view',p+'value_cache',p+'v')
            edge(p+'scores',p+'q_rotary',p+'keys_view')
            edge(p+'masked_scores',p+'scores','positions')
            edge(p+'probabilities',p+'masked_scores')
            edge(p+'attention',p+'probabilities',p+'values_view')
            edge(p+'attn_output',p+'attention')
            edge(p+'attn_residual',previous,p+'attn_output')
            edge(p+'ffn_norm',p+'attn_residual')
            edge(p+'gate',p+'ffn_norm')
            edge(p+'up',p+'ffn_norm')
            edge(p+'gate_silu',p+'gate')
            edge(p+'gated',p+'gate_silu',p+'up')
            edge(p+'down',p+'gated')
            edge(p+'ffn_residual',p+'attn_residual',p+'down')
            previous = p+'ffn_residual'
        edge('output_norm',previous)
        edge('logits','output_norm')
        return named

    def test_prefill_decode_and_chunked_cached_shapes_lifetimes(self):
        for session in ((3,0,16),(1,7,16),(4,5,16),(16,0,16)):
            plan = self.accepts(session=session)
            named = self.check_graph(plan)
            query,past,capacity = session
            self.assertEqual(named['blk.0.q']['shape'],[query,4,2])
            self.assertEqual(named['blk.0.k']['shape'],[query,2,2])
            self.assertEqual(named['blk.0.key_cache']['shape'],[capacity,2,2])
            self.assertEqual(named['blk.0.keys_view']['shape'],[query+past,2,2])
            self.assertEqual(named['blk.0.scores']['shape'],[4,query,query+past])
            self.assertEqual(named['logits']['shape'],[query,10])

    def test_unequal_value_width_multilayer_and_tied_weights(self):
        for tied in (False,True):
            plan = self.accepts(dense_fixture(layers=2,value=3,tied=tied))
            named = self.check_graph(plan)
            self.assertEqual(named['blk.1.v']['shape'],[3,2,3])
            self.assertEqual(named['blk.1.value_cache']['shape'],[16,2,3])
            self.assertEqual(named['blk.1.attention']['shape'],[3,12])
            self.assertEqual(plan['operations'][-1]['weight'],'token_embd.weight' if tied else 'output.weight')
            self.assertEqual(len(plan['weights']),20 if tied else 21)

    def test_defaults_mha_and_architecture_not_hardware_admission(self):
        plan = self.accepts(dense_fixture(kv_heads=4,explicit_dims=False,drop=('llama.attention.head_count_kv',)))
        self.assertEqual(plan['parameters']['key_dim'],2)
        self.assertEqual(plan['parameters']['kv_heads'],4)
        self.check_graph(plan)
        self.refuses(dense_fixture(architecture='qwen3'),message='architecture semantic importer unresolved')
        self.refuses(dense_fixture(hidden=10,explicit_dims=False),message='non-integral default')
        self.check_graph(self.accepts(dense_fixture(hidden=10,value=3)))

    def test_quantized_bindings_preserve_packed_kinds_without_dequantization(self):
        for kind in (12,13,14,30):
            plan = self.accepts(dense_fixture(hidden=256,key=64,value=64,ff=512,matrix_kind=kind))
            self.check_graph(plan)
            for name,binding in plan['weights'].items():
                self.assertEqual(binding['source_kind'],0 if name.endswith('_norm.weight') else kind)

    def test_invalid_context_and_checked_products(self):
        for session in ((0,0,16),(1,-1,16),(1,0,0),(2,15,16),(1,17,16),(1,0,65)):
            self.refuses(session=session,message='invalid session')
        huge = dense_fixture(overrides={'llama.context_length':(10,MAX)})
        self.refuses(huge,(1,0,MAX),message='overflowing positive shape product')
        self.refuses(huge,(MAX//2,0,MAX),message='overflowing positive shape product')
        self.refuses(dense_fixture(overrides={'llama.attention.head_count':(10,MAX),
                     'llama.attention.head_count_kv':(10,1)}),message='overflowing positive shape product')

    def test_metadata_shape_semantics_and_scalar_parameters(self):
        for key,value in (('embedding_length',0),('block_count',0),('block_count',999),
                          ('feed_forward_length',0),('attention.head_count',0),
                          ('attention.head_count_kv',0),('attention.head_count_kv',3),
                          ('attention.key_length',0),('attention.value_length',0),
                          ('rope.dimension_count',1),('rope.dimension_count',4)):
            self.refuses(dense_fixture(overrides={'llama.'+key:(4,value)}))
        for value in (float('inf'),float('nan'),0.,-1.):
            for key in ('rope.freq_base','attention.layer_norm_rms_epsilon'):
                self.refuses(dense_fixture(overrides={'llama.'+key:(6,value)}),message='numerical parameter')
        self.refuses(dense_fixture(drop=('llama.embedding_length',)),message='missing metadata')
        self.refuses(dense_fixture(overrides={'llama.attention.head_count':(7,True)}),message='unsigned integer')
        self.refuses(dense_fixture(overrides={'llama.vocab_size':(4,11)}),message='vocabulary')

    def test_unknown_modifiers_scaling_and_unbound_weights_stay_named(self):
        self.refuses(dense_fixture(overrides={'llama.attention.logit_softcap':(6,50.)}),message='metadata semantics unresolved')
        self.refuses(dense_fixture(overrides={'llama.rope.scaling.type':(8,'yarn')}),message='scaled RoPE recipe unresolved')
        self.refuses(dense_fixture(extra_tensors=[('blk.0.attn_q.bias',8,1,0)]),message='source tensor semantics unresolved')
        self.refuses(dense_fixture(extra_tensors=[('rope_freqs.weight',1,1,0)]),message='source tensor semantics unresolved')
        plan = self.accepts(dense_fixture(overrides={'llama.tensor_data_layout':(8,'future-layout-"\\\n')}))
        self.assertEqual(plan['parameters']['source_layout'],'future-layout-"\\\n')
        self.assertIn('source_layout_and_rope_pairing',plan['unresolved_gates'])

    def test_shape_mismatch_and_no_source_mutation(self):
        raw,_,_ = dense_fixture()
        # Same tensor count and valid file; metadata claims a different width.
        self.refuses(dense_fixture(overrides={'llama.embedding_length':(4,12)}),message='shape mismatch')
        self.refuses((raw[:-1],{},0),message='truncated')
        for name in ('blk.0.attn_q.weight','output_norm.weight','token_embd.weight'):
            self.refuses(dense_fixture(omit=(name,)),message='missing')

    def test_read_only_no_device_or_inference_library(self):
        self.check_graph(self.accepts(trace=True))
        trace = (self.evidence/'source-graph.strace').read_text()
        self.assertIn('O_RDONLY',trace)
        self.assertIn('PROT_READ, MAP_PRIVATE',trace)
        self.assertIn('munmap(',trace)
        for forbidden in ('/dev/h1x-','libcuda','libhailort'):
            self.assertNotIn(forbidden,trace)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary',required=True)
    parser.add_argument('--strace',required=True)
    parser.add_argument('--evidence',required=True)
    CONFIG,remaining = parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
