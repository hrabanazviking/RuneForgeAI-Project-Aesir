"""Pure launch-correlated attribution of already-admitted Nsight2023 rows."""
from bisect import bisect_right
from collections import Counter, defaultdict
import re

STAGES = ("query", "key", "value", "output", "gate", "up", "down")
PREFIXES = ("core_packed_turing_matrix_stag", "core_packed_projection_four_ma", "core_packed_projection_block_m")
GEOMETRY = dict(query=(3072,3072),key=(1024,3072),value=(1024,3072),
                output=(3072,3072),gate=(8192,3072),up=(8192,3072),down=(3072,8192),head=(128256,3072))


def attribute(rows, strings, outer, launches, kernels, tiles):
    if set(tiles) != {1,4,32} or any(type(k) is not int or type(v) is not int or not 0 <= v <= 1536 for k,v in tiles.items()) or not 1 <= sum(tiles.values()) <= 1536:
        raise ValueError("Invalid admitted projection tile counts")
    expected = {f"{stage}.b{size}":count*28 for stage in STAGES for size,count in tiles.items() if count}
    expected["head.b1"] = 1
    ranges = []
    for start,end,kind,tid,end_tid,text,text_id in rows:
        label = text if text_id is None else strings.get(text_id)
        if type(label) is not str or not label.startswith("aesir.project."): continue
        match = re.fullmatch(r"aesir\.project\.(query|key|value|output|gate|up|down|head)\.b(1|4|32)", label)
        if not match or type(start) is not int or type(end) is not int or kind != 59 or tid != outer[2] or end_tid not in (None,tid) or not outer[0] <= start < end <= outer[1]:
            raise ValueError("Invalid projection label/range/thread")
        key = label.removeprefix("aesir.project.")
        if key not in expected: raise ValueError("Projection range disagrees with source tile plan")
        ranges.append((start,end,key))
        if len(ranges) > sum(expected.values()): raise ValueError("Excess projection ranges")
    ranges.sort()
    if Counter(r[2] for r in ranges) != Counter(expected):
        raise ValueError("Missing/duplicate projection range counts")
    if any(before[1] > after[0] for before,after in zip(ranges,ranges[1:])):
        raise ValueError("Overlapping projection ranges")
    starts = [r[0] for r in ranges]; used = Counter(); groups = defaultdict(lambda:dict(kernel_count=0,gpu_total_ns=0))
    for correlation,name,start,end in kernels:
        api_start,api_end,tid = launches[correlation]
        i = bisect_right(starts,api_start)-1
        child = ranges[i] if i >= 0 and api_start < ranges[i][1] else None
        projection = name.startswith(PREFIXES)
        if child is None:
            if projection: raise ValueError("Unattributed actual projection kernel")
            continue
        if not projection or tid != outer[2] or not child[0] <= api_start < api_end <= child[1]:
            raise ValueError("Projection launch containment/kernel identity failed")
        used[i] += 1
        group = groups[child[2]]; group["kernel_count"] += 1; group["gpu_total_ns"] += end-start
    for i,(_,_,key) in enumerate(ranges):
        stage,size = key.split(".b");size=int(size)
        count = 8 if size == 32 and stage in ("key","value") else 1
        if used[i] != count: raise ValueError("Projection range actual launch count disagrees with source plan")
    for key,g in groups.items():
        stage,size=key.split(".b")
        g.update(cpu_range_count=expected[key],batch=int(size),rows=GEOMETRY[stage][0],columns=GEOMETRY[stage][1])
    return dict(passed=True,cpu_range_count=len(ranges),kernel_count=sum(g['kernel_count'] for g in groups.values()),
                groups=dict(sorted(groups.items())),tiles=tiles,
                limits="GPU duration projects successful launches through exact CUDA correlations. Child CPU ranges do not synchronize or contain asynchronous GPU intervals. Durations overlap APIs; no service speed score or per-layer timing.")
