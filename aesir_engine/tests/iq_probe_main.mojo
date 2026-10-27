from core.mimir_well import MimirWell, f16


def trial(tag: String, well_bytes: Int, big_elems: Int) raises:
    var well = MimirWell(well_bytes)
    var big = well.allocate(big_elems).unsafe_bitcast[UInt8]()
    for i in range(big_elems * 2):
        big.unsafe_store(i, UInt8((i % 251) + 1))
    var s = UInt64(0)
    for i in range(big_elems * 2):
        s += UInt64(big.unsafe_load(i))
    var small = well.allocate(2048)
    for i in range(2048):
        small.unsafe_store(i, Scalar[f16](1.0))
    print(tag, "sum:", s, "big0 after small-alloc:", big.unsafe_load(0), "big1000:", big.unsafe_load(1000))


def main() raises:
    trial("t1-64MB", 64 * 1024 * 1024, 409602)
    trial("t2-64MB", 64 * 1024 * 1024, 409602)
    trial("t3-8MB", 8 * 1024 * 1024, 409602)
    trial("t4-64MB-small", 64 * 1024 * 1024, 1024)
    print("DONE")
