# tests/bench_gpu_pressure_a076.mojo
# A-076: REAL external-pressure driver (not in run_all).
#
# Usage: bench_gpu_pressure_a076 <reserve_bytes> <label>
#
# The wrapper (hidden_files/run_a076_pressure.sh) fixes ONE
# absolute reserve for the whole experiment — (MemAvailable before
# any balloon) - 64 MiB — then runs this driver three times:
#   run A: no balloon        -> GPU room is 64 MiB, weights route GPU
#   run B: balloon process holds a bounded multi-GiB block of the
#          unified pool      -> live room collapses to zero,
#          spillable weights SPILL_CPU, non-spillable REFUSE
#   run C: balloon killed    -> room recovers, weights route GPU
# The balloon is a separate process (real external pressure on the
# shared pool, not a figure fed to the governor), guarded by the
# wrapper: it refuses to start unless MemAvailable exceeds the
# balloon by a wide margin, and the wrapper verifies MemAvailable
# recovery after killing it. Nothing here can OOM the box: the
# balloon is bounded and the governor's reserve is the standing
# guard. Prints A076_* lines the ledger files verbatim.

from std.sys import argv

from core.gpu_pressure import (
    ROUTE_GPU,
    ROUTE_SPILL_CPU,
    GpuPressureConfig,
    GpuPressureGovernor,
    live_pressure,
    pressure_name,
    route_name,
)
from core.observation_integer import bounded_decimal

comptime _MB = 1024 * 1024


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: bench_gpu_pressure_a076 <reserve_bytes> <label>")
    var reserve = bounded_decimal(String(args[1]))
    var label = String(args[2])
    var gov = GpuPressureGovernor(GpuPressureConfig(1024 * _MB, 32 * _MB, reserve))
    var r = live_pressure()
    var room = gov.config.effective_gpu_room(r.available_bytes, gov.gpu_live_bytes)
    print(
        "A076_PRESSURE label=", label, " total=", r.total_bytes,
        " avail=", r.available_bytes, " level=", pressure_name(r.level),
        " reserve=", reserve, " eff_room=", room,
    )
    var v1 = gov.route(8 * _MB, True, r.available_bytes, r.total_bytes)
    print("A076_ROUTE label=", label, " kind=spillable verdict=", route_name(v1))
    if v1 == ROUTE_GPU:
        gov.release_gpu(8 * _MB)
    elif v1 == ROUTE_SPILL_CPU:
        gov.release_spilled(8 * _MB)
    var v2 = gov.route(8 * _MB, False, r.available_bytes, r.total_bytes)
    print("A076_ROUTE label=", label, " kind=nonspillable verdict=", route_name(v2))
    if v2 == ROUTE_GPU:
        gov.release_gpu(8 * _MB)
    if not gov.at_baseline():
        raise Error("governor not at baseline at end of driver run")
    print(
        "A076_DONE label=", label, " baseline=true spills=", gov.spill_count,
        " refusals=", gov.refusal_count, " gpu_admits=", gov.gpu_admit_count,
    )
    for entry in gov.log:
        print("A076_LOG ", entry)
