// Isolated test-only public declaration object bytes; no vendor implementation.
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
    using Config=CONTEXT_SWITCH_DEFS__sequencer_config_t;
    using Trigger=CONTEXT_SWITCH_DEFS__trigger_sequencer_action_data_t;
    using Done=CONTEXT_SWITCH_DEFS__sequencer_interrupt_data_t;
    if(argc==2 && std::string(argv[1])=="layout") {
        std::printf("{\"header\":%zu,\"timestamp\":%zu,\"configuration\":%zu,\"trigger\":%zu,\"done\":%zu,\"trigger_offsets\":[%zu,%zu],\"done_offset\":%zu,\"configuration_offsets\":[%zu,%zu,%zu,%zu,%zu,%zu,%zu,%zu],\"kinds\":[%u,%u],\"timestamp_initializer\":%u}\n",
            sizeof(CONTEXT_SWITCH_DEFS__common_action_header_t),
            offsetof(CONTEXT_SWITCH_DEFS__common_action_header_t,time_stamp),
            sizeof(Config),sizeof(Trigger),sizeof(Done),offsetof(Trigger,cluster_index),
            offsetof(Trigger,sequencer_config),offsetof(Done,sequencer_index),
            offsetof(Config,initial_l3_cut),offsetof(Config,initial_l3_offset),
            offsetof(Config,active_apu),offsetof(Config,active_ia),offsetof(Config,active_sc),
            offsetof(Config,active_l2),offsetof(Config,l2_offset_0),offsetof(Config,l2_offset_1),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_TRIGGER_SEQUENCER),
            unsigned(CONTEXT_SWITCH_DEFS__ACTION_TYPE_SEQUENCER_DONE_INTERRUPT),
            unsigned(CONTEXT_SWITCH_DEFS__TIMESTAMP_INIT_VALUE));
        return 0;
    }
    if(argc!=12) throw std::runtime_error("eleven scalar fields required");
    auto n=[&](int i){return std::stoull(argv[i]);};
    const auto kind=n(1);
    CONTEXT_SWITCH_DEFS__common_action_header_t header{};
    header.action_type=static_cast<CONTEXT_SWITCH_DEFS__ACTION_TYPE_t>(kind);
    header.time_stamp=static_cast<uint32_t>(n(2));dump(&header,sizeof(header));
    if(kind==1) {
        Trigger body{};body.cluster_index=static_cast<uint8_t>(n(3));
        auto &c=body.sequencer_config;
        c.initial_l3_cut=static_cast<uint8_t>(n(4));
        c.initial_l3_offset=static_cast<uint16_t>(n(5));
        c.active_apu=static_cast<uint32_t>(n(6));c.active_ia=static_cast<uint32_t>(n(7));
        c.active_sc=n(8);c.active_l2=n(9);c.l2_offset_0=n(10);c.l2_offset_1=n(11);
        dump(&body,sizeof(body));
    } else if(kind==17) {
        Done body{};body.sequencer_index=static_cast<uint8_t>(n(3));dump(&body,sizeof(body));
    } else throw std::runtime_error("unsupported oracle kind");
    std::puts("");
}
