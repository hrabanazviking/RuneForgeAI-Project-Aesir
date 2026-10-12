## Slice 126 — Define address, alignment, and size constraints (complete; raw-path values unknown)

Official HailoRT driver interfaces expose buffer mapping, descriptor lists, transfer lengths, and platform DMA addresses; their documentation describes page-aligned user buffers for its own API. This describes the vendor-supported runtime interface, which is outside the campaign’s implementation constraints. It does not establish a transferable raw Mojo contract, the integrated Hailo-10H’s required tensor alignment/packing, or limits for an Æsir-generated operation.

Current Æsir requirements therefore retain address width/addressability, page and descriptor alignment, transfer-size maxima, per-channel limits, tensor padding/stride rules, and safe DMA reach as **UNKNOWN**. No numerical constraint is copied from the vendor API into Æsir and no transfer is attempted. Resolve only through a permitted primary specification or a separately approved, safe Hailo proof path.

Sources: https://github.com/hailo-ai/hailort/blob/master/hailort/libhailort/src/vdma/driver/hailort_driver.hpp ; https://github.com/hailo-ai/hailort/blob/master/hailort/libhailort/src/vdma/driver/hailort_driver.cpp ; https://github.com/hailo-ai/hailort-drivers/blob/master/linux/vdma/ioctl.c ; docs/HAILO10H_ACCESS_MECHANISMS.md.
