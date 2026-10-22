// Test-only object representation oracle for pinned public declarations.
// No device or vendor runtime linkage; no vendor implementation included.
#include <bit>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <stdexcept>
#include <string>
#include "context_switch_defs.h"
static_assert(std::endian::native == std::endian::little);
static void dump(const void *data,size_t size) {
    auto p=static_cast<const unsigned char *>(data);
    for(size_t i=0;i<size;++i) std::printf("%02x",p[i]);
}
int main(int argc,char **argv) {
    using Enable=CONTEXT_SWITCH_DEFS__enable_lcu_action_non_default_data_t;
    using Disable=CONTEXT_SWITCH_DEFS__disable_lcu_action_data_t;
    using Batch=CONTEXT_SWITCH_DEFS__switch_lcu_batch_action_data_t;
    if(argc==2 && std::string(argv[1])=="layout") {
        std::printf("{\"header\":%zu,\"timestamp\":%zu,\"sizes\":[%zu,%zu,%zu],\"enable_offsets\":[%zu,%zu,%zu,%zu],\"disable_offsets\":[%zu],\"batch_offsets\":[%zu,%zu,%zu],\"kinds\":[%u,%u,%u],\"masks\":[%u,%u]}\n",
            sizeof(CONTEXT_SWITCH_DEFS__common_action_header_t),
            offsetof(CONTEXT_SWITCH_DEFS__common_action_header_t,time_stamp),
            sizeof(Enable),sizeof(Disable),sizeof(Batch),
            offsetof(Enable,packed_lcu_id),offsetof(Enable,network_index),
            offsetof(Enable,kernel_done_address),offsetof(Enable,kernel_done_count),
            offsetof(Disable,packed_lcu_id),offsetof(Batch,packed_lcu_id),
            offsetof(Batch,network_index),offsetof(Batch,kernel_done_count),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_ENABLE_LCU_NON_DEFAULT),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_DISABLE_LCU),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_SWITCH_LCU_BATCH),
            unsigned(CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_LCU_INDEX_MASK),
            unsigned(CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_CLUSTER_INDEX_MASK));
        return 0;
    }
    if(argc!=8) throw std::runtime_error("seven scalar fields required");
    auto n=[&](int i){return std::stoull(argv[i]);};
    const auto kind=n(1);
    CONTEXT_SWITCH_DEFS__common_action_header_t h{};
    h.action_type=static_cast<CONTEXT_SWITCH_DEFS__ACTION_TYPE_t>(kind);
    h.time_stamp=static_cast<uint32_t>(n(2));
    dump(&h,sizeof(h));
    if(kind==4) {
        Enable b{};
        CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_SET(b.packed_lcu_id,n(3),n(4));
        b.network_index=static_cast<uint8_t>(n(5));
        b.kernel_done_address=static_cast<uint16_t>(n(6));
        b.kernel_done_count=static_cast<uint32_t>(n(7));
        dump(&b,sizeof(b));
    } else if(kind==5) {
        Disable b{};
        CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_SET(b.packed_lcu_id,n(3),n(4));
        dump(&b,sizeof(b));
    } else if(kind==36) {
        Batch b{};
        CONTEXT_SWITCH_DEFS__PACKED_LCU_ID_SET(b.packed_lcu_id,n(3),n(4));
        b.network_index=static_cast<uint8_t>(n(5));
        b.kernel_done_count=static_cast<uint32_t>(n(7));
        dump(&b,sizeof(b));
    } else throw std::runtime_error("unsupported oracle kind");
    std::puts("");
}
