"""Pure launch-correlated attribution of already-admitted Nsight2023 rows."""
from bisect import bisect_right
from collections import Counter, defaultdict
import re

STAGES = ("query", "key", "value", "output", "gate", "up", "down")
PREFIXES = ("core_packed_turing_matrix_stag", "core_packed_projection_four_ma", "core_packed_projection_block_m")
LARGE_PREFIX = "core_packed_turing_matrix_larg"
RESOURCE_FIELDS = ("registers_per_thread", "static_shared_bytes", "dynamic_shared_bytes",
                   "local_bytes_per_thread", "legacy_local_bytes_total_deprecated",
                   "grid_x", "grid_y", "grid_z", "block_x", "block_y", "block_z")


def resource_records(rows, correlations):
    """Validate complete recorded CUDA resources, never infer occupancy/spills."""
    records = {}
    for row in rows:
        if len(row) != 12:
            raise ValueError("Incomplete kernel resource record")
        correlation, *values = row
        if type(correlation) is not int or correlation not in correlations or correlation in records:
            raise ValueError("Foreign/duplicate kernel resource correlation")
        limits = (255, 2**32-1, 2**32-1, 2**32-1, 2**64-1, 2**31-1, 65535, 65535, 1024, 1024, 64)
        for i,(value,limit) in enumerate(zip(values,limits,strict=True)):
            if type(value) is not int or not (1 if i >= 5 else 0) <= value <= limit:
                raise ValueError("Invalid bounded integer kernel resource")
        if values[8]*values[9]*values[10] > 1024:
            raise ValueError("Kernel block exceeds CUDA thread bound")
        records[correlation] = dict(zip(RESOURCE_FIELDS,values,strict=True))
    if set(records) != set(correlations):
        raise ValueError("Incomplete kernel resource correlation coverage")
    return records


GEOMETRY = dict(query=(3072,3072),key=(1024,3072),value=(1024,3072),
                output=(3072,3072),gate=(8192,3072),up=(8192,3072),down=(3072,8192),head=(128256,3072))


def attribute(rows, strings, outer, launches, kernels, tiles, *, down128=False, resources=None):
    if type(down128) is not bool or (down128 and resources is None):
        raise ValueError("Explicit down attribution requires recorded resources")
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
        if down128 and (type(kind) is not int or type(tid) is not int or (end_tid is not None and type(end_tid) is not int) or (text_id is not None and type(text_id) is not int)):
            raise ValueError("Noninteger owned projection metadata")
        key = label.removeprefix("aesir.project.")
        if key not in expected: raise ValueError("Projection range disagrees with source tile plan")
        ranges.append((start,end,key))
        if len(ranges) > sum(expected.values()): raise ValueError("Excess projection ranges")
    ranges.sort()
    if Counter(r[2] for r in ranges) != Counter(expected):
        raise ValueError("Missing/duplicate projection range counts")
    if any(before[1] > after[0] for before,after in zip(ranges,ranges[1:])):
        raise ValueError("Overlapping projection ranges")
    if down128:
        order = [f"{stage}.b{size}" for size in (32,4,1) for _ in range(tiles[size]) for _ in range(28) for stage in STAGES] + ["head.b1"]
        if [r[2] for r in ranges] != order:
            raise ValueError("Projection stage order disagrees with actual source plan")
    distributions = defaultdict(dict)
    starts = [r[0] for r in ranges]; used = Counter(); groups = defaultdict(lambda:dict(kernel_count=0,gpu_total_ns=0))
    for correlation,name,start,end in kernels:
        api_start,api_end,tid = launches[correlation]
        i = bisect_right(starts,api_start)-1
        child = ranges[i] if i >= 0 and api_start < ranges[i][1] else None
        projection = name.startswith((*PREFIXES,LARGE_PREFIX))
        if child is None:
            if projection: raise ValueError("Unattributed actual projection kernel")
            continue
        if not projection or tid != outer[2] or not child[0] <= api_start < api_end <= child[1]:
            raise ValueError("Projection launch containment/kernel identity failed")
        if down128:
            stage,size = child[2].split(".b");size=int(size)
            prefix = LARGE_PREFIX if stage == "down" and size == 32 else (
                PREFIXES[0] if size == 32 and stage not in ("key","value") else PREFIXES[1] if size in (4,32) else PREFIXES[2])
            if not name.startswith(prefix): raise ValueError("Projection kernel identity disagrees with explicit selected wrapper")
            r = resources[correlation]
            tile_rows = 128 if prefix == LARGE_PREFIX else 64 if prefix == PREFIXES[0] else 4
            block = 256 if prefix == LARGE_PREFIX else 128
            expected_launch = dict(grid_x=(GEOMETRY[stage][0]+tile_rows-1)//tile_rows,grid_y=1,grid_z=1,block_x=block,block_y=1,block_z=1)
            if any(r[k] != v for k,v in expected_launch.items()): raise ValueError("Projection grid/block disagrees with selected source wrapper")
            signature = (name, *(r[k] for k in RESOURCE_FIELDS))
            group = distributions[child[2]].setdefault(signature, dict(kernel=name,resources=r.copy(),kernel_count=0,gpu_total_ns=0))
            group["kernel_count"] += 1;group["gpu_total_ns"] += end-start
        elif name.startswith(LARGE_PREFIX):
            raise ValueError("Default projection path refuses larger-row kernel")
        used[i] += 1
        group = groups[child[2]]; group["kernel_count"] += 1; group["gpu_total_ns"] += end-start
    for i,(_,_,key) in enumerate(ranges):
        stage,size = key.split(".b");size=int(size)
        count = 8 if size == 32 and stage in ("key","value") else 1
        if used[i] != count: raise ValueError("Projection range actual launch count disagrees with source plan")
    for key,g in groups.items():
        stage,size=key.split(".b")
        if down128: g["recorded_resource_distributions"] = [distributions[key][k] for k in sorted(distributions[key])]
        g.update(cpu_range_count=expected[key],batch=int(size),rows=GEOMETRY[stage][0],columns=GEOMETRY[stage][1])
    return dict(passed=True,cpu_range_count=len(ranges),kernel_count=sum(g['kernel_count'] for g in groups.values()),
                groups=dict(sorted(groups.items())),tiles=tiles,attention_variant=3 if down128 else 2,
                resource_scope="complete capture admitted, projection distributions only" if down128 else None,
                limits="GPU duration projects successful launches through exact CUDA correlations. Child CPU ranges do not synchronize or contain asynchronous GPU intervals. Durations overlap APIs; no service speed score or per-layer timing. Recorded resources do not infer occupancy, spills or the earlier256 resource failure; legacy local total is deprecated.")
