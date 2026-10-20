"""Pure fused-attention attribution after complete process/resource admission."""
from bisect import bisect_right
from collections import Counter, defaultdict
import re

from cuda_projection_ranges import RESOURCE_FIELDS, STAGES

FUSED_PREFIX = "core_fused_causal_attention_fu"
SMALL_PREFIX = "core_fused_small_attention_sma"


def attribute(rows, strings, outer, launches, kernels, tiles, resources):
    """Map successful child API launches to whole asynchronous GPU intervals."""
    if (set(tiles) != {1, 4, 32} or
        any(type(k) is not int or type(v) is not int or not 0 <= v <= 1536 for k, v in tiles.items()) or
        not 1 <= sum(tiles.values()) <= 1536 or resources is None):
        raise ValueError("Invalid admitted fused tile/resource scope")
    expected = {f"fused.b{size}": tiles[size]*28 for size in (32, 4) if tiles[size]}
    ranges = []
    chronology = []
    for start, end, kind, tid, end_tid, text, text_id in rows:
        label = text if text_id is None else strings.get(text_id)
        if type(label) is not str:
            continue
        if label.startswith("aesir.project."):
            chronology.append((start, end, label))
        if not label.startswith("aesir.attend."):
            continue
        match = re.fullmatch(r"aesir\.attend\.fused\.b(4|32)", label)
        if (not match or type(start) is not int or type(end) is not int or
            type(kind) is not int or kind != 59 or type(tid) is not int or tid != outer[2] or
            (end_tid is not None and (type(end_tid) is not int or end_tid != tid)) or
            (text_id is not None and type(text_id) is not int) or not outer[0] <= start < end <= outer[1]):
            raise ValueError("Invalid fused attention label/range/thread")
        key = label.removeprefix("aesir.attend.")
        if key not in expected:
            raise ValueError("Fused range disagrees with source tile plan")
        ranges.append((start, end, key))
        chronology.append((start, end, label))
        if len(ranges) > sum(expected.values()):
            raise ValueError("Excess fused attention ranges")
    ranges.sort()
    if Counter(r[2] for r in ranges) != Counter(expected):
        raise ValueError("Missing/duplicate fused attention range counts")
    chronology.sort()
    order = []
    for size in (32, 4, 1):
        for _ in range(tiles[size]):
            for _ in range(28):
                for stage in STAGES:
                    order.append(f"aesir.project.{stage}.b{size}")
                    if stage == "value" and size != 1:
                        order.append(f"aesir.attend.fused.b{size}")
    order.append("aesir.project.head.b1")
    if ([r[2] for r in chronology] != order or
        any(before[1] > after[0] for before, after in zip(chronology, chronology[1:]))):
        raise ValueError("Fused/projection chronological layer/tile order or disjointness failed")
    starts = [r[0] for r in ranges]
    used = Counter()
    seen = set()
    groups = defaultdict(lambda: dict(kernel_count=0, gpu_total_ns=0))
    distributions = defaultdict(dict)
    for correlation, name, start, end in kernels:
        if correlation in seen or correlation not in launches:
            raise ValueError("Duplicate/missing fused launch correlation")
        seen.add(correlation)
        api_start, api_end, tid = launches[correlation]
        i = bisect_right(starts, api_start)-1
        child = ranges[i] if i >= 0 and api_start < ranges[i][1] else None
        fused = name.startswith(FUSED_PREFIX)
        if child is None:
            if fused:
                raise ValueError("Unattributed actual fused attention kernel")
            continue
        if not fused or tid != outer[2] or not child[0] <= api_start < api_end <= child[1]:
            raise ValueError("Fused attention launch containment/kernel identity failed")
        size = int(child[2].split(".b")[1])
        record = resources[correlation]
        geometry = dict(grid_x=24, grid_y=size, grid_z=1, block_x=128, block_y=1, block_z=1)
        if any(type(record[k]) is not int or record[k] != v for k, v in geometry.items()):
            raise ValueError("Fused attention grid/block differs from actual selected wrapper")
        signature = (name, *(record[k] for k in RESOURCE_FIELDS))
        dist = distributions[child[2]].setdefault(signature,
            dict(kernel=name, resources=record.copy(), kernel_count=0, gpu_total_ns=0))
        dist["kernel_count"] += 1
        dist["gpu_total_ns"] += end-start
        used[i] += 1
        groups[child[2]]["kernel_count"] += 1
        groups[child[2]]["gpu_total_ns"] += end-start
    if any(used[i] != 1 for i in range(len(ranges))):
        raise ValueError("Fused range must own exactly one successful actual kernel enqueue")
    for key, group in groups.items():
        group.update(cpu_range_count=expected[key], batch=int(key.split(".b")[1]),
            recorded_resource_distributions=[distributions[key][k] for k in sorted(distributions[key])])
    return dict(passed=True, attention_variant=4, cpu_range_count=len(ranges),
        kernel_count=sum(g["kernel_count"] for g in groups.values()), groups=dict(sorted(groups.items())),
        tiles=tiles, resource_scope="complete capture admitted, owned fused attention distributions only",
        limits="One successful CUDA launch correlation per owned child. Full asynchronous GPU intervals are never clipped to CPU child bounds. Recorded resources and profiled durations do not infer occupancy, spills, uncovered CPU delay, service speed or a provider lead.")


def attribute_small(rows, strings, outer, launches, kernels, tiles, resources):
    """Attribute 28 layer-owned child ranges and launches for every strategy5 tile."""
    if (set(tiles) != {1, 4, 32} or
        any(type(k) is not int or type(v) is not int or not 0 <= v <= 1536 for k, v in tiles.items()) or
        not 1 <= sum(tiles.values()) <= 1536 or resources is None):
        raise ValueError("Invalid admitted small-attention tile/resource scope")
    expected = {f"small.b{size}": tiles[size]*28 for size in (32, 4) if tiles[size]}
    ranges = []
    for start, end, kind, tid, end_tid, text, text_id in rows:
        label = text if text_id is None else strings.get(text_id)
        if type(label) is not str:
            continue
        if label.startswith("aesir.project."):
            raise ValueError("Small tracing does not admit projection-stage labels")
        if not label.startswith("aesir.attend."):
            continue
        match = re.fullmatch(r"aesir\.attend\.small\.b(4|32)", label)
        if (not match or type(start) is not int or type(end) is not int or
            type(kind) is not int or kind != 59 or type(tid) is not int or tid != outer[2] or
            (end_tid is not None and (type(end_tid) is not int or end_tid != tid)) or
            (text_id is not None and type(text_id) is not int) or not outer[0] <= start < end <= outer[1]):
            raise ValueError("Invalid small attention label/range/thread")
        key = label.removeprefix("aesir.attend.")
        if key not in expected:
            raise ValueError("Small range disagrees with source tile plan")
        ranges.append((start, end, key))
        if len(ranges) > sum(expected.values()):
            raise ValueError("Excess small attention ranges")
    ranges.sort()
    if Counter(r[2] for r in ranges) != Counter(expected):
        raise ValueError("Missing/duplicate small attention range counts")
    if any(before[1] > after[0] for before, after in zip(sorted(ranges), sorted(ranges)[1:])):
        raise ValueError("Overlapping small attention tile ranges")
    # The fixture drains full 32-row tiles before its final 4-row tile.
    # Counts alone would admit a trace ordering the source cannot emit.
    expected_order = [f"small.b{size}" for size in (32, 4) for _ in range(tiles[size]*28)]
    if [item[2] for item in ranges] != expected_order:
        raise ValueError("Small attention tile order differs from source execution plan")
    starts = [r[0] for r in ranges]
    used = Counter()
    api_counts = Counter()
    seen = set()
    groups = defaultdict(lambda: dict(kernel_count=0, gpu_total_ns=0))
    distributions = defaultdict(dict)
    for correlation, name, start, end in kernels:
        if correlation in seen or correlation not in launches:
            raise ValueError("Duplicate/missing small launch correlation")
        if type(start) is not int or type(end) is not int or not outer[0] <= start < end <= outer[1]:
            raise ValueError("Invalid asynchronous small kernel interval")
        seen.add(correlation)
        api_start, api_end, tid = launches[correlation]
        i = bisect_right(starts, api_start)-1
        child = ranges[i] if i >= 0 and api_start < ranges[i][1] else None
        small = name.startswith(SMALL_PREFIX)
        if child is None:
            if small:
                raise ValueError("Unattributed actual small attention kernel")
            continue
        if not small or tid != outer[2] or not child[0] <= api_start < api_end <= child[1]:
            raise ValueError("Small attention launch containment/kernel identity failed")
        size = int(child[2].split(".b")[1])
        if correlation not in resources or not isinstance(resources[correlation], dict) or any(
            field not in resources[correlation] for field in RESOURCE_FIELDS
        ):
            raise ValueError("Small attention launch is missing its resource record")
        record = resources[correlation]
        geometry = dict(grid_x=24, grid_y=size, grid_z=1, block_x=128, block_y=1, block_z=1)
        if any(type(record[k]) is not int or record[k] != v for k, v in geometry.items()):
            raise ValueError("Small attention grid/block differs from actual selected wrapper")
        signature = (name, *(record[k] for k in RESOURCE_FIELDS))
        dist = distributions[child[2]].setdefault(signature,
            dict(kernel=name, resources=record.copy(), kernel_count=0, gpu_total_ns=0))
        dist["kernel_count"] += 1
        dist["gpu_total_ns"] += end-start
        used[i] += 1
        groups[child[2]]["kernel_count"] += 1
        groups[child[2]]["gpu_total_ns"] += end-start
    # Count all launch APIs inside each child, including successful calls that
    # lack a corresponding kernel row and would otherwise disappear.
    for correlation, (api_start, api_end, tid) in launches.items():
        i = bisect_right(starts, api_start)-1
        child = ranges[i] if i >= 0 and api_start < ranges[i][1] else None
        if child is not None and (tid != outer[2] or not child[0] <= api_start < api_end <= child[1]):
            raise ValueError("Small attention API launch crosses owned range or thread")
        if child is not None:
            api_counts[i] += 1
    if any(used[i] != 1 for i in range(len(ranges))):
        raise ValueError("Each small layer range must own exactly one successful kernel launch")
    if any(api_counts[i] != 1 for i in range(len(ranges))):
        raise ValueError("Each small layer range must own exactly one launch correlation")
    for key, group in groups.items():
        group.update(cpu_range_count=expected[key], batch=int(key.split(".b")[1]), layers_per_tile=28,
            tile_count=tiles[int(key.split(".b")[1])],
            recorded_resource_distributions=[distributions[key][k] for k in sorted(distributions[key])])
    return dict(passed=True, attention_variant=5, cpu_range_count=len(ranges),
        kernel_count=sum(g["kernel_count"] for g in groups.values()), groups=dict(sorted(groups.items())),
        tiles=tiles, resource_scope="complete capture admitted, owned strategy5 small attention distributions only",
        limits="Twenty-eight layer-owned children per tile; each child owns one successful launch correlation and one complete kernel interval. Full asynchronous GPU intervals are never clipped. Resources and timings are diagnostic only.")
