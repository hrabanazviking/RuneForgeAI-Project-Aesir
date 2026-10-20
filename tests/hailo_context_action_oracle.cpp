// Test-only public-header object oracle. No device or vendor runtime linkage.
#include <bit>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <string>
#include "context_switch_defs.h"

static_assert(std::endian::native == std::endian::little);
static void bytes(const void *data, size_t length) {
    const auto p = static_cast<const unsigned char *>(data);
    for (size_t i=0; i<length; ++i) std::printf("%02x",p[i]);
}
int main(int argc, char **argv) {
    if (argc==2 && std::string(argv[1])=="layout") {
        std::printf("{\"header\":%zu,\"timestamp_offset\":%zu,\"fetch\":%zu,\"lcu\":%zu,\"ccw\":%zu,\"write\":%zu,\"write_offsets\":[%zu,%zu,%zu,%zu,%zu,%zu],\"kinds\":[%u,%u,%u,%u],\"write_types\":[%u,%u]}\n",
            sizeof(CONTEXT_SWITCH_DEFS__common_action_header_t),
            offsetof(CONTEXT_SWITCH_DEFS__common_action_header_t,time_stamp),
            sizeof(CONTEXT_SWITCH_DEFS__fetch_cfg_channel_descriptors_action_data_t),
            sizeof(CONTEXT_SWITCH_DEFS__enable_lcu_action_default_data_t),
            sizeof(CONTEXT_SWITCH_DEFS__fetch_ccw_bursts_action_data_t),
            sizeof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,address),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,data_type),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,data),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,shift),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,mask),
            offsetof(CONTEXT_SWITCH_DEFS__write_data_by_type_action_t,network_index),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_FETCH_CFG_CHANNEL_DESCRIPTORS),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_ENABLE_LCU_DEFAULT),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_FETCH_CCW_BURSTS),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_WRITE_DATA_BY_TYPE),
            unsigned(WRITE_ACTION_TYPE_GENERAL),unsigned(WRITE_ACTION_TYPE_WRITE_BATCH));
        return 0;
    }
    if (argc<4) throw std::runtime_error("kind timestamp typed-fields required");
    auto n=[&](int i)->uint64_t { return std::stoull(argv[i]); };
    auto kind=n(1);
    CONTEXT_SWITCH_DEFS__common_action_header_t header{};
    header.action_type=static_cast<CONTEXT_SWITCH_DEFS__ACTION_TYPE_t>(kind);
    header.time_stamp=static_cast<uint32_t>(n(2));
    bytes(&header,sizeof(header));
    if (kind==0 && argc==6) {
        CONTEXT_SWITCH_DEFS__fetch_cfg_channel_descriptors_action_data_t body{};
        body.descriptors_count=static_cast<uint16_t>(n(3));
        CONTEXT_SWITCH_DEFS__PACKED_VDMA_CHANNEL_ID__SET(body.packed_vdma_channel_id,n(4),n(5));
        bytes(&body,sizeof(body));
    } else if (kind==3 && argc==6) {
        CONTEXT_SWITCH_DEFS__enable_lcu_action_default_data_t body{};
        CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_SET(body.packed_lcu_id,n(3),n(4));
        body.network_index=static_cast<uint8_t>(n(5));
        bytes(&body,sizeof(body));
    } else if (kind==27 && argc==5) {
        CONTEXT_SWITCH_DEFS__fetch_ccw_bursts_action_data_t body{};
        body.ccw_bursts=static_cast<uint16_t>(n(3));
        body.config_stream_index=static_cast<uint8_t>(n(4));
        bytes(&body,sizeof(body));
    } else if (kind==35 && argc==9) {
        CONTEXT_SWITCH_DEFS__write_data_by_type_action_t body{};
        body.address=static_cast<uint32_t>(n(3));
        body.data_type=static_cast<uint8_t>(n(4));
        body.data=static_cast<uint32_t>(n(5));
        body.shift=static_cast<uint8_t>(n(6));
        body.mask=static_cast<uint32_t>(n(7));
        body.network_index=static_cast<uint8_t>(n(8));
        bytes(&body,sizeof(body));
    } else throw std::runtime_error("unsupported oracle vector");
    std::puts("");
}
