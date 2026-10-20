// Test-only UAPI oracle. Include the operator's installed header; do not
// duplicate its declarations or call a device. Nothing here ships at runtime.
#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <sys/utsname.h>
#include <sys/syscall.h>
#include <linux/stat.h>
#include <fcntl.h>
#include "hailo_ioctl_common.h"

template<typename T> void bytes(const T &value) {
    const auto *p = reinterpret_cast<const unsigned char *>(&value);
    for (size_t i = 0; i < sizeof(value); ++i)
        std::cout << std::hex << std::setw(2) << std::setfill('0') << unsigned(p[i]);
    std::cout << '\n';
}

int main(int argc, char **argv) {
    static_assert(sizeof(size_t) == 8 && sizeof(uintptr_t) == 8);
    static_assert(sizeof(bool) == 1 && sizeof(hailo_dma_buffer_type) == 4);
    const auto n = [&](int i) { return std::strtoull(argv[i], nullptr, 10); };
    const std::string mode = argc > 1 ? argv[1] : "layout";
    if (mode == "host-layout" && argc == 2) {
        std::cout << "{\"uname_size\":" << sizeof(utsname)
                  << ",\"uname_machine\":" << offsetof(utsname, machine)
                  << ",\"statx_size\":" << sizeof(statx)
                  << ",\"statx_mode\":" << offsetof(statx, stx_mode)
                  << ",\"statx_rdev_major\":" << offsetof(statx, stx_rdev_major)
                  << ",\"statx_rdev_minor\":" << offsetof(statx, stx_rdev_minor)
                  << ",\"statx_syscall\":" << SYS_statx
                  << ",\"o_nofollow\":" << O_NOFOLLOW << "}\n";
    } else if (mode == "layout" && argc == 2) {
        std::cout << "{";
        bool first = true;
        const auto item = [&](const char *key, uint64_t value) {
            if (!first) std::cout << ',';
            first = false;
            std::cout << '"' << key << "\":" << value;
        };
#define SIZE(T) item(#T, sizeof(T))
#define OFF(T, F) item(#T "." #F, offsetof(T, F))
#define IO(N) item(#N, N)
        SIZE(hailo_vdma_buffer_params); OFF(hailo_vdma_buffer_params, addr_or_fd);
        OFF(hailo_vdma_buffer_params, size); OFF(hailo_vdma_buffer_params, direction);
        OFF(hailo_vdma_buffer_params, type); OFF(hailo_vdma_buffer_params, mapped_handle);
        SIZE(hailo_vdma_buffer_sync_params); OFF(hailo_vdma_buffer_sync_params, handle);
        OFF(hailo_vdma_buffer_sync_params, sync_type); OFF(hailo_vdma_buffer_sync_params, offset);
        OFF(hailo_vdma_buffer_sync_params, count);
        IO(HAILO_VDMA_BUFFER_MAP); IO(HAILO_VDMA_BUFFER_UNMAP); IO(HAILO_VDMA_BUFFER_SYNC);
        SIZE(hailo_device_properties); SIZE(hailo_driver_info);
        OFF(hailo_device_properties, board_type); OFF(hailo_device_properties, dma_type);
        OFF(hailo_device_properties, dma_engines_count); OFF(hailo_device_properties, is_fw_loaded);
        SIZE(hailo_desc_list_create_params); OFF(hailo_desc_list_create_params, desc_page_size);
        OFF(hailo_desc_list_create_params, is_circular); OFF(hailo_desc_list_create_params, desc_handle);
        OFF(hailo_desc_list_create_params, dma_address); SIZE(hailo_desc_list_release_params);
        SIZE(hailo_soc_connect_params); OFF(hailo_soc_connect_params, input_channel_index);
        OFF(hailo_soc_connect_params, output_channel_index); OFF(hailo_soc_connect_params, input_desc_handle);
        OFF(hailo_soc_connect_params, output_desc_handle); SIZE(hailo_soc_close_params);
        SIZE(hailo_vdma_enable_channels_params); SIZE(hailo_vdma_disable_channels_params);
        SIZE(hailo_vdma_interrupts_wait_params); OFF(hailo_vdma_interrupts_wait_params, channels_count);
        OFF(hailo_vdma_interrupts_wait_params, irq_data); SIZE(hailo_vdma_interrupts_channel_data);
        SIZE(hailo_vdma_transfer_buffer); OFF(hailo_vdma_transfer_buffer, addr_or_fd);
        OFF(hailo_vdma_transfer_buffer, size); SIZE(hailo_vdma_prepare_transfer_params);
        OFF(hailo_vdma_prepare_transfer_params, desc_handle); OFF(hailo_vdma_prepare_transfer_params, buffers_count);
        OFF(hailo_vdma_prepare_transfer_params, buffers); OFF(hailo_vdma_prepare_transfer_params, is_debug);
        SIZE(hailo_vdma_launch_transfer_params); OFF(hailo_vdma_launch_transfer_params, engine_index);
        OFF(hailo_vdma_launch_transfer_params, is_cyclic); SIZE(hailo_vdma_cancel_prepared_transfer_params);
        IO(HAILO_QUERY_DEVICE_PROPERTIES); IO(HAILO_QUERY_DRIVER_INFO);
        IO(HAILO_DESC_LIST_CREATE); IO(HAILO_DESC_LIST_RELEASE); IO(HAILO_SOC_CONNECT); IO(HAILO_SOC_CLOSE);
        IO(HAILO_VDMA_ENABLE_CHANNELS); IO(HAILO_VDMA_DISABLE_CHANNELS); IO(HAILO_VDMA_INTERRUPTS_WAIT);
        IO(HAILO_VDMA_LAUNCH_TRANSFER); IO(HAILO_VDMA_PREPARE_TRANSFER); IO(HAILO_VDMA_CANCEL_PREPARED_TRANSFER);
        std::cout << "}\n";
    } else if (mode == "buffer" && argc == 5) {
        hailo_vdma_buffer_params p{};
        p.addr_or_fd = n(2); p.size = n(3);
        p.direction = static_cast<hailo_dma_data_direction>(n(4));
        p.type = HAILO_DMA_USER_PTR_BUFFER; bytes(p);
    } else if (mode == "buffer-sync" && argc == 7) {
        hailo_vdma_buffer_sync_params p{};
        p.handle = n(2); p.sync_type = static_cast<hailo_vdma_buffer_sync_type>(n(3));
        p.offset = n(4); p.count = n(5); bytes(p);
    } else if (mode == "desc-create" && argc == 5) {
        hailo_desc_list_create_params p{};
        p.desc_count = n(2); p.desc_page_size = n(3); p.is_circular = n(4); bytes(p);
    } else if (mode == "desc-release" && argc == 3) {
        hailo_desc_list_release_params p{}; p.desc_handle = n(2); bytes(p);
    } else if (mode == "connect" && argc == 5) {
        hailo_soc_connect_params p{};
        p.input_channel_index = 255; p.output_channel_index = 255;
        p.port_number = n(2); p.input_desc_handle = n(3); p.output_desc_handle = n(4); bytes(p);
    } else if (mode == "close" && argc == 4) {
        hailo_soc_close_params p{}; p.input_channel_index = n(2); p.output_channel_index = n(3); bytes(p);
    } else if (mode == "channels" && argc == 5) {
        hailo_vdma_enable_channels_params p{};
        for (int i = 0; i < 3; ++i) p.channels_bitmap_per_engine[i] = n(i + 2);
        bytes(p);
    } else if (mode == "transfer" && argc == 7) {
        hailo_vdma_launch_transfer_params p{};
        p.prepare_transfer_params.channel_index = n(2);
        p.prepare_transfer_params.desc_handle = n(3);
        p.prepare_transfer_params.buffers_count = 1;
        p.prepare_transfer_params.buffers[0].buffer_type = HAILO_DMA_USER_PTR_BUFFER;
        p.prepare_transfer_params.buffers[0].addr_or_fd = n(4);
        p.prepare_transfer_params.buffers[0].size = n(5);
        p.engine_index = 0; p.is_cyclic = n(6); bytes(p);
    } else return 2;
}
