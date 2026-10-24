// Original test-only public declaration oracle. Synthetic values, no dereference.
#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include "hailo_ioctl_common.h"
static uint64_t number(const char *p){return std::strtoull(p,nullptr,10);}
static void bytes(const void *p,size_t n){const auto *b=static_cast<const unsigned char *>(p);for(size_t i=0;i<n;i++)std::cout<<std::hex<<std::setw(2)<<std::setfill('0')<<unsigned(b[i]);std::cout<<'\n';}
int main(int argc,char **argv){
 static_assert(sizeof(uintptr_t)==8 && sizeof(hailo_vdma_prepare_transfer_params)==139 && sizeof(hailo_vdma_cancel_prepared_transfer_params)==8);
 static_assert(offsetof(hailo_vdma_prepare_transfer_params,channel_index)==0 && offsetof(hailo_vdma_prepare_transfer_params,desc_handle)==1 && offsetof(hailo_vdma_prepare_transfer_params,buffers_count)==9 && offsetof(hailo_vdma_prepare_transfer_params,buffers)==10 && offsetof(hailo_vdma_prepare_transfer_params,is_debug)==138);
 static_assert(offsetof(hailo_vdma_cancel_prepared_transfer_params,desc_handle)==0 && sizeof(hailo_vdma_transfer_buffer)==16 && HAILO_MAX_BUFFERS_PER_SINGLE_TRANSFER==8 && HAILO_DMA_USER_PTR_BUFFER==0);
 if(argc==2 && std::string(argv[1])=="layout"){
  std::cout<<"{\"prepare_bytes\":"<<sizeof(hailo_vdma_prepare_transfer_params)<<",\"cancel_bytes\":"<<sizeof(hailo_vdma_cancel_prepared_transfer_params)<<",\"prepare_ioctl\":"<<uint64_t(HAILO_VDMA_PREPARE_TRANSFER)<<",\"cancel_ioctl\":"<<uint64_t(HAILO_VDMA_CANCEL_PREPARED_TRANSFER)<<",\"span_bytes\":"<<sizeof(hailo_vdma_transfer_buffer)<<"}\n";return 0;
 }
 if(argc==3 && std::string(argv[1])=="cancel"){hailo_vdma_cancel_prepared_transfer_params p{};p.desc_handle=number(argv[2]);bytes(&p,sizeof(p));return 0;}
 if(argc<6||argc>20||argc%2||std::string(argv[1])!="prepare")return 2;
 hailo_vdma_prepare_transfer_params p{};p.channel_index=number(argv[2]);p.desc_handle=number(argv[3]);p.buffers_count=(argc-4)/2;
 for(unsigned i=0;i<p.buffers_count;i++){p.buffers[i].buffer_type=HAILO_DMA_USER_PTR_BUFFER;p.buffers[i].addr_or_fd=number(argv[4+2*i]);p.buffers[i].size=number(argv[5+2*i]);}
 bytes(&p,sizeof(p));return 0;
}
