"""Strict accepted small5 full-model source, default closed to all old consumers."""
import hashlib
import json
import math
import re

from launch import digest
from profile_native_cuda import read_text
from check_turing_model_prefill import parse, reference_fields, summarize, score
from check_llama3_logits import VOCABULARY, MAX_ABSOLUTE_ERROR, MAX_RMS_ERROR


def fixed(value):
    if not isinstance(value,dict) or value.get('passed') is not True or type(value.get('values')) is not int or value['values']!=VOCABULARY:return False
    for key,limit in (('maximum_absolute_error',MAX_ABSOLUTE_ERROR),('rms_error',MAX_RMS_ERROR)):
        number=value.get(key)
        if type(number) not in (int,float) or not math.isfinite(number) or not 0<=number<=limit:return False
    a,b=value.get('native_argmax'),value.get('reference_argmax')
    return type(a) is int and type(b) is int and a==b and 0<=a<VOCABULARY


def validate(data,report,model_sha,binary_sha):
    if any(type(report.get(k)) is not int for k in ('schema','activation_precision','attention_variant','full_model_values_per_mode','invalid_tiles','guards')) or any(report.get(k) is not True for k in ('passed','collection_complete','speed_scored')):
        raise ValueError('Noncanonical small source totals/status/precision')
    for c in report.get('cases',[]):
        if not fixed(c.get('native_comparison')) or any(type(c.get(k)) is not int for k in ('rope_cache_host_enqueues','elementwise_host_enqueues','down128_host_enqueues','small_attention_host_enqueues','fused_attention_host_enqueues','original_attention_queries')) or any(type(i) is not int for i in c.get('input_ids',[])):
            raise ValueError('Noncanonical small source case counts/IDs/numeric proof')
    if type(report.get('schema')) is not int or report['schema']!=1 or report.get('model_sha256')!=model_sha or report.get('binary_sha256')!=binary_sha or report.get('control_capable') is not False:
        raise ValueError('Small source identity/capability mismatch')
    cpu=report.get('independent_reference',{})
    if cpu.get('passed') is not True or type(cpu.get('requested_gpu_layers')) is not int or cpu['requested_gpu_layers']!=0 or any(cpu.get(k)!=v for k,v in dict(context=4096,kv='f16',batch=128,threads=4,weight_mode='dequantized_f32',numpy='2.4.4',llama_cpp_python='0.3.23').items()) or not re.fullmatch(r'[0-9a-f]{64}',cpu.get('library_sha256','')):
        raise ValueError('Small source lacks pinned zero-GPU F32 independent scope')
    independent=cpu.get('cases',[])
    if len(independent)!=4 or any(not fixed(o.get(owner)) for o in independent for owner in ('native','matrix')) or any(not fixed(c['native_comparison']) for c in data['cases']):
        raise ValueError('Small source full independent/native numeric budget failed')
    parent=report.get('fixture_reference',{})
    flags=('input_ids_equal','native_f32_bytes_equal','matrix_f32_bytes_equal','guarded_cache_identity_passed','passed')
    if parent.get('passed') is not True or type(parent.get('attention_variant')) is not int or parent['attention_variant']!=4 or parent.get('control_capable') is not False or parent.get('model_sha256')!=model_sha or any(not re.fullmatch(r'[0-9a-f]{64}',parent.get(k,'')) for k in ('binary_sha256','csv_sha256','report_sha256')) or len(parent.get('cases',[]))!=4 or any(c.get(k) is not True for c in parent['cases'] for k in flags):
        raise ValueError('Small source lacks exact complete default4 byte/cache/ID predecessor')
    expected=summarize(data);expected.update(independent_reference=cpu,fixture_reference=parent);score(expected)
    if not expected['passed'] or any(report.get(k)!=v for k,v in expected.items() if k!='limits'):
        raise ValueError('Small source complete vectors/counters/IDs/cache/timings/report disagree')


def accepted_model(csv_path,report_path,model_sha,*,small=False,binary=None):
    if small is not True or binary is None:raise ValueError('Small source requires explicit capability and actual binary')
    binary_sha=digest(binary)
    data=parse(csv_path,allow_small=True)
    if data['attention_variant']!=5 or data['control_capable'] is not False:raise ValueError('Expected closed original small5 model source')
    text=read_text(report_path,5*1024**2)
    report=json.loads(text,object_pairs_hook=reference_fields,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('Nonfinite small source')))
    validate(data,report,model_sha,binary_sha)
    proof=dict(passed=True,attention_variant=5,control_capable=False,model_sha256=model_sha,binary_sha256=binary_sha,
        csv_sha256=data['csv_sha256'],report_sha256=hashlib.sha256(text.encode()).hexdigest(),source4_binary_sha256=report['fixture_reference']['binary_sha256'])
    if digest(binary)!=binary_sha or digest(csv_path)!=proof['csv_sha256'] or digest(report_path)!=proof['report_sha256']:raise ValueError('Small model source/binary changed during admission')
    return data,proof
