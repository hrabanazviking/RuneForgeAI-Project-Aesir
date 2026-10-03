#!/usr/bin/env python3
"""Bind complete small-score vectors to full-session observed CUDA resources."""
from collections import Counter
import argparse
import json
import math
from pathlib import Path
import re

from check_cuda_trace import analyze
from cuda_projection_ranges import RESOURCE_FIELDS, resource_records
from launch import digest
from profile_native_cuda import read_text
import check_small_fused_attention as attention

PREFIXES = ('core_fused_causal_attention_fu', 'core_fused_small_attention_sma')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate CPU receipt field')
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError('Nonfinite CPU receipt constant: ' + value)


def validate_oracle(data, report):
    """Recompute strict identity/bit/timing summary from bounded CPU receipt."""
    if report.get('oracle_versions') != {'numpy': '2.4.4'} or report.get('speed_scored') is not True:
        raise ValueError('Missing independent unprofiled CPU scope')
    oracle = report.get('oracle')
    if type(oracle) is not list or len(oracle) != len(data['cases']):
        raise ValueError('Incomplete independent CPU cases')
    for case, result in zip(data['cases'], oracle, strict=True):
        if type(result.get('index')) is not int or type(result.get('outputs')) is not int:
            raise ValueError('Noninteger CPU case identity/count')
        for owner in ('native', 'candidate'):
            metric = result[owner]
            for key, limit in (('maximum_scaled_error', .002), ('normalized_rms', .0002)):
                value = metric[key]
                if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= limit:
                    raise ValueError('Independent CPU fixed numeric budget failed')
            if metric['passed'] is not True:
                raise ValueError('Independent CPU owner refused')
    expected = attention.summarize(data, oracle)
    if not expected['passed'] or any(report.get(k) != v for k, v in expected.items()):
        raise ValueError('CPU receipt disagrees with complete original source')


def same_vectors(plain, profiled):
    if plain['values_per_owner'] != profiled['values_per_owner'] or len(plain['cases']) != len(profiled['cases']):
        raise ValueError('Profile source counts changed')
    for a, b in zip(plain['cases'], profiled['cases'], strict=True):
        for key in ('index', 'batch', 'tokens', 'capacity', 'prefix', 'mode', 'guards', 'query_cells', 'kv_cells'):
            if a[key] != b[key]:
                raise ValueError('Profile input/guard/case scope changed')
        for owner in ('native', 'candidate'):
            if a[owner].tobytes() != b[owner].tobytes():
                raise ValueError('Profile complete F32 bits changed')
        if b['original_f32_bits_equal'] is not True:
            raise ValueError('Profile original/candidate F32 bits changed')


def validate_resources(trace, data):
    """Source-derived complete launch distribution; no occupancy or spill inference."""
    counts = Counter(c['tokens'] for c in data['cases'])
    expected = Counter({(owner, tokens): count * 33 for owner in range(2) for tokens, count in counts.items()})
    total = sum(expected.values())
    if trace.get('scope') != 'complete_capture' or trace.get('owned_nvtx_range') is not None or trace.get('projection_attribution') is not None:
        raise ValueError('Expected entire primitive capture without model ranges')
    if any(type(trace.get(key)) is not int or trace[key] != total for key in ('kernel_count', 'complete_capture_kernel_count', 'recorded_resource_kernel_count')) or trace.get('excluded_kernel_count') != 0:
        raise ValueError('Incomplete source-derived primitive kernels/resources')
    observed = Counter()
    durations = Counter()
    distributions = trace['primitive_resource_distributions']
    if type(distributions) is not list or not distributions:
        raise ValueError('Missing complete primitive resource distributions')
    signatures = set()
    for group in distributions:
        name = group['kernel']
        if type(name) is not str:
            raise ValueError('Invalid primitive kernel name')
        owners = [i for i, prefix in enumerate(PREFIXES) if name.startswith(prefix)]
        if len(owners) != 1:
            raise ValueError('Unexpected primitive kernel identity')
        owner = owners[0]
        r = group['resources']
        if set(r) != set(RESOURCE_FIELDS):
            raise ValueError('Incomplete primitive resource fields')
        resource_records([(1, *(r[k] for k in RESOURCE_FIELDS))], {1})
        if any(r[k] != v for k, v in dict(grid_x=24, grid_z=1, block_x=128, block_y=1, block_z=1,
                                         static_shared_bytes=16384 if owner == 0 else 6144, dynamic_shared_bytes=0).items()):
            raise ValueError('Primitive grid/block/shared score footprint changed')
        key = (owner, r['grid_y'])
        if key not in expected or type(group['kernel_count']) is not int or not 1 <= group['kernel_count'] <= expected[key] or type(group['gpu_total_ns']) is not int or group['gpu_total_ns'] <= 0:
            raise ValueError('Invalid source token/kernel/duration distribution')
        signature = (name, *(r[k] for k in RESOURCE_FIELDS))
        if signature in signatures:
            raise ValueError('Duplicate primitive resource distribution')
        signatures.add(signature)
        observed[key] += group['kernel_count']
        durations[name] += group['gpu_total_ns']
    if observed != expected or set(trace['kernel_groups']) != set(durations) or any(
            trace['kernel_groups'][name] != {'count': sum(g['kernel_count'] for g in distributions if g['kernel'] == name), 'total_ns': duration}
            for name, duration in durations.items()):
        raise ValueError('Resource totals disagree with full source/kernel capture')
    return {'passed': True, 'kernel_count': total, 'static_shared_bytes': {'original': 16384, 'small': 6144},
            'source_launches': [{'owner': PREFIXES[o], 'tokens': t, 'count': n} for (o, t), n in sorted(observed.items())],
            'recorded_resource_distributions': distributions}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('unprofiled', 'profiled', 'reference_report', 'sqlite', 'binary', 'output'):
        p.add_argument('--' + name.replace('_', '-'), type=Path, required=True)
    p.add_argument('--binary-sha256', required=True)
    a = p.parse_args()
    report = {'schema': 1, 'passed': False, 'collection_complete': False, 'speed_scored': False,
              'speed_promoted': False, 'full_model_speed_claim': False}
    with a.output.open('x', encoding='utf-8') as stream:
        try:
            paths = [a.binary, a.unprofiled, a.profiled, a.reference_report, a.sqlite]
            before = [digest(path) for path in paths]
            if not re.fullmatch(r'[0-9a-f]{64}', a.binary_sha256) or before[0] != a.binary_sha256:
                raise ValueError('Actual primitive binary changed before admission')
            cpu = json.loads(read_text(a.reference_report, 4 * 1024**2), object_pairs_hook=unique_object, parse_constant=reject_constant)
            if cpu.get('binary_sha256') != a.binary_sha256:
                raise ValueError('CPU source binary scope changed')
            plain = attention.parse(a.unprofiled)
            profiled = attention.parse(a.profiled)
            validate_oracle(plain, cpu)
            same_vectors(plain, profiled)
            trace = analyze(a.sqlite, a.binary.name, expected_pid=profiled['pid'], record_resources=True, fused_primitive=True)
            resources = validate_resources(trace, profiled)
            report.update(collection_complete=True, values_per_owner=plain['values_per_owner'],
                          binary_sha256=a.binary_sha256, unprofiled_csv_sha256=plain['csv_sha256'],
                          profiled_csv_sha256=profiled['csv_sha256'], cpu_report_sha256=before[3],
                          sqlite_sha256=before[4], resource_validation=resources, trace=trace,
                          limits='Entire actual primitive PID capture, all full source F32 bits/guards/CPU numeric gates. Profile durations diagnostic only. Recorded resources do not certify occupancy, spills, causes, model speed or provider leadership.')
            if before != [digest(path) for path in paths] or before[1:3] != [plain['csv_sha256'], profiled['csv_sha256']]:
                raise ValueError('Primitive source/binary/trace artifact changed during validation')
            report['passed'] = True
        except (Exception, KeyboardInterrupt) as error:
            report.update(passed=False, error=f'{type(error).__name__}: {error}')
        json.dump(report, stream, indent=2, allow_nan=False)
        stream.write('\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
