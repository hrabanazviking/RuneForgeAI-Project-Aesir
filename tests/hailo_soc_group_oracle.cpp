// Original test-only public declaration object oracle; no address dereference.
#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include "hailo_ioctl_common.h"
int main(int argc, char **argv) {
    static_assert(sizeof(uintptr_t) == 8 && sizeof(hailo_vdma_launch_transfer_params) == 141);
    static_assert(sizeof(hailo_vdma_transfer_buffer) == 16);
    static_assert(offsetof(hailo_vdma_transfer_buffer, addr_or_fd) == 4);
    static_assert(offsetof(hailo_vdma_transfer_buffer, size) == 12);
    static_assert(offsetof(hailo_vdma_prepare_transfer_params, buffers) == 10);
    static_assert(offsetof(hailo_vdma_prepare_transfer_params, is_debug) == 138);
    static_assert(offsetof(hailo_vdma_launch_transfer_params, engine_index) == 139);
    static_assert(offsetof(hailo_vdma_launch_transfer_params, is_cyclic) == 140);
    static_assert(HAILO_MAX_BUFFERS_PER_SINGLE_TRANSFER == 8 && HAILO_DMA_USER_PTR_BUFFER == 0);
    if (argc < 5 || argc > 19 || argc % 2 != 1) return 2;
    const auto n = [&](int i) { return std::strtoull(argv[i], nullptr, 10); };
    hailo_vdma_launch_transfer_params p{};
    auto &prep = p.prepare_transfer_params;
    prep.channel_index = n(1); prep.desc_handle = n(2);
    prep.buffers_count = (argc - 3) / 2;
    for (unsigned i = 0; i < prep.buffers_count; ++i) {
        prep.buffers[i].buffer_type = HAILO_DMA_USER_PTR_BUFFER;
        prep.buffers[i].addr_or_fd = n(3 + i * 2);
        prep.buffers[i].size = n(4 + i * 2);
    }
    const auto *bytes = reinterpret_cast<const unsigned char *>(&p);
    for (size_t i = 0; i < sizeof(p); ++i)
        std::cout << std::hex << std::setw(2) << std::setfill('0') << unsigned(bytes[i]);
    std::cout << '\n';
}
