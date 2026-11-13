// A-098 GPU power runner (team-25): Vulkan compute GEMM at the
// A-094 FIT shape 128x1024x1024 on the Radeon 8060S (gfx1151).
// Inputs are the A-092 LCG i16 stream cast to fp32; values in
// [-8,8], K=1024 -> every partial sum is an integer < 2^24, so
// the fp32 result is EXACT vs the int64 CPU oracle (verified).
// RAPL package energy is read in-process around the sustained
// dispatch window (run via sudo -n so energy_uj is readable).
#include <vulkan/vulkan.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <chrono>
#include <cmath>
using clk = std::chrono::steady_clock;
static long long read_euj(){ FILE* f=std::fopen("/sys/class/powercap/intel-rapl:0/energy_uj","r"); if(!f) return -1; long long v=-1; if(std::fscanf(f,"%lld",&v)!=1) v=-1; std::fclose(f); return v; }
#define VKC(x) do{ VkResult r_=(x); if(r_!=VK_SUCCESS){ std::printf("FAIL vk %d at %d\n",(int)r_,__LINE__); return 1; } }while(0)
int main(int argc, char** argv){
  if (argc < 3){ std::printf("usage: %s <gemm.spv> <dispatches>\n", argv[0]); return 2; }
  const int DISP = atoi(argv[2]);
  const int M=128, K=1024, N=1024;
  std::vector<int16_t> Ai((size_t)M*K), Bi((size_t)K*N);
  { uint32_t s=0xA092u; auto nxt=[&s](){ s=s*1664525u+1013904223u; return (int16_t)((int)((s>>16)%17u)-8); };
    for (auto& v: Ai) v=nxt(); for (auto& v: Bi) v=nxt(); }
  std::vector<int32_t> oracle((size_t)M*N,0);
  for (int i=0;i<M;i++) for (int j=0;j<N;j++){ int64_t acc=0; for (int k=0;k<K;k++) acc+=(int64_t)Ai[i*K+k]*Bi[k*N+j]; oracle[i*N+j]=(int32_t)acc; }
  std::vector<float> A(Ai.begin(),Ai.end()), B(Bi.begin(),Bi.end()), C((size_t)M*N,0.0f);
  VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.pApplicationName="a098"; app.apiVersion=VK_API_VERSION_1_1;
  VkInstanceCreateInfo ii{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO}; ii.pApplicationInfo=&app;
  VkInstance inst; VKC(vkCreateInstance(&ii,nullptr,&inst));
  uint32_t npd=0; vkEnumeratePhysicalDevices(inst,&npd,nullptr);
  std::vector<VkPhysicalDevice> pds(npd); vkEnumeratePhysicalDevices(inst,&npd,pds.data());
  VkPhysicalDevice pd=pds[0];
  for (uint32_t i=0;i<npd;i++){ VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(pds[i],&p); std::printf("gpu_candidate[%u]=%s type=%d\n",i,p.deviceName,(int)p.deviceType); if (p.deviceType==VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) pd=pds[i]; }
  { VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(pd,&p); std::printf("gpu_device_name=%s\n",p.deviceName); }
  uint32_t nq=0; vkGetPhysicalDeviceQueueFamilyProperties(pd,&nq,nullptr);
  std::vector<VkQueueFamilyProperties> qfs(nq); vkGetPhysicalDeviceQueueFamilyProperties(pd,&nq,qfs.data());
  uint32_t qf=0; for (uint32_t i=0;i<nq;i++) if (qfs[i].queueFlags & VK_QUEUE_COMPUTE_BIT){ qf=i; break; }
  float prio=1.0f; VkDeviceQueueCreateInfo qci{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO}; qci.queueFamilyIndex=qf; qci.queueCount=1; qci.pQueuePriorities=&prio;
  VkDeviceCreateInfo dci{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO}; dci.queueCreateInfoCount=1; dci.pQueueCreateInfos=&qci;
  VkDevice dev; VKC(vkCreateDevice(pd,&dci,nullptr,&dev));
  VkQueue queue; vkGetDeviceQueue(dev,qf,0,&queue);
  auto mkbuf=[&](VkDeviceSize sz, VkBuffer& buf, VkDeviceMemory& mem, void* src)->int{
    VkBufferCreateInfo bci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; bci.size=sz; bci.usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT; bci.sharingMode=VK_SHARING_MODE_EXCLUSIVE;
    VKC(vkCreateBuffer(dev,&bci,nullptr,&buf));
    VkMemoryRequirements mr; vkGetBufferMemoryRequirements(dev,buf,&mr);
    VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd,&mp);
    uint32_t mt=0; for (uint32_t i=0;i<mp.memoryTypeCount;i++) if ((mr.memoryTypeBits&(1u<<i)) && (mp.memoryTypes[i].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))==(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)){ mt=i; break; }
    VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; mai.allocationSize=mr.size; mai.memoryTypeIndex=mt;
    VKC(vkAllocateMemory(dev,&mai,nullptr,&mem)); VKC(vkBindBufferMemory(dev,buf,mem,0));
    if (src){ void* p; VKC(vkMapMemory(dev,mem,0,sz,0,&p)); std::memcpy(p,src,sz); vkUnmapMemory(dev,mem); }
    return 0; };
  VkBuffer bA,bB,bC; VkDeviceMemory mA,mB,mC;
  if (mkbuf((VkDeviceSize)A.size()*4,bA,mA,A.data())) return 1;
  if (mkbuf((VkDeviceSize)B.size()*4,bB,mB,B.data())) return 1;
  if (mkbuf((VkDeviceSize)C.size()*4,bC,mC,nullptr)) return 1;
  std::ifstream fs(argv[1], std::ios::binary); std::vector<char> spv((std::istreambuf_iterator<char>(fs)), std::istreambuf_iterator<char>());
  VkShaderModuleCreateInfo sci{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; sci.codeSize=spv.size(); sci.pCode=(const uint32_t*)spv.data();
  VkShaderModule sm; VKC(vkCreateShaderModule(dev,&sci,nullptr,&sm));
  VkDescriptorSetLayoutBinding db[3]{};
  for (int i=0;i<3;i++){ db[i].binding=i; db[i].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; db[i].descriptorCount=1; db[i].stageFlags=VK_SHADER_STAGE_COMPUTE_BIT; }
  VkDescriptorSetLayoutCreateInfo dslci{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dslci.bindingCount=3; dslci.pBindings=db;
  VkDescriptorSetLayout dsl; VKC(vkCreateDescriptorSetLayout(dev,&dslci,nullptr,&dsl));
  VkPushConstantRange pcr{}; pcr.stageFlags=VK_SHADER_STAGE_COMPUTE_BIT; pcr.offset=0; pcr.size=4;
  VkPipelineLayoutCreateInfo plci{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; plci.setLayoutCount=1; plci.pSetLayouts=&dsl; plci.pushConstantRangeCount=1; plci.pPushConstantRanges=&pcr;
  VkPipelineLayout pl; VKC(vkCreatePipelineLayout(dev,&plci,nullptr,&pl));
  VkComputePipelineCreateInfo cpci{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpci.stage.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; cpci.stage.stage=VK_SHADER_STAGE_COMPUTE_BIT; cpci.stage.module=sm; cpci.stage.pName="main"; cpci.layout=pl;
  VkPipeline pipe; VKC(vkCreateComputePipelines(dev,nullptr,1,&cpci,nullptr,&pipe));
  VkDescriptorPoolSize dps{}; dps.type=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; dps.descriptorCount=3;
  VkDescriptorPoolCreateInfo dpci{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dpci.maxSets=1; dpci.poolSizeCount=1; dpci.pPoolSizes=&dps;
  VkDescriptorPool dpool; VKC(vkCreateDescriptorPool(dev,&dpci,nullptr,&dpool));
  VkDescriptorSetAllocateInfo dsai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; dsai.descriptorPool=dpool; dsai.descriptorSetCount=1; dsai.pSetLayouts=&dsl;
  VkDescriptorSet dset; VKC(vkAllocateDescriptorSets(dev,&dsai,&dset));
  VkDescriptorBufferInfo dbi[3]={{bA,0,VK_WHOLE_SIZE},{bB,0,VK_WHOLE_SIZE},{bC,0,VK_WHOLE_SIZE}};
  VkWriteDescriptorSet wr[3]{};
  for (int i=0;i<3;i++){ wr[i].sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET; wr[i].dstSet=dset; wr[i].dstBinding=i; wr[i].descriptorCount=1; wr[i].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[i].pBufferInfo=&dbi[i]; }
  vkUpdateDescriptorSets(dev,3,wr,0,nullptr);
  VkCommandPoolCreateInfo cpi{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO}; cpi.queueFamilyIndex=qf; cpi.flags=VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  VkCommandPool cpool; VKC(vkCreateCommandPool(dev,&cpi,nullptr,&cpool));
  VkCommandBufferAllocateInfo cbai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO}; cbai.commandPool=cpool; cbai.level=VK_COMMAND_BUFFER_LEVEL_PRIMARY; cbai.commandBufferCount=1;
  VkCommandBuffer cmd; VKC(vkAllocateCommandBuffers(dev,&cbai,&cmd));
  VkFenceCreateInfo fci{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO}; VkFence fence; VKC(vkCreateFence(dev,&fci,nullptr,&fence));
  auto record=[&](int ndisp)->int{
    VKC(vkResetCommandBuffer(cmd,0));
    VkCommandBufferBeginInfo cbbi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    VKC(vkBeginCommandBuffer(cmd,&cbbi));
    vkCmdBindPipeline(cmd,VK_PIPELINE_BIND_POINT_COMPUTE,pipe);
    vkCmdBindDescriptorSets(cmd,VK_PIPELINE_BIND_POINT_COMPUTE,pl,0,1,&dset,0,nullptr);
    uint32_t one=1; vkCmdPushConstants(cmd,pl,VK_SHADER_STAGE_COMPUTE_BIT,0,4,&one);
    for (int d=0; d<ndisp; d++) vkCmdDispatch(cmd,(M*N)/256,1,1);
    VKC(vkEndCommandBuffer(cmd)); return 0; };
  auto submit_wait=[&]()->int{
    VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount=1; si.pCommandBuffers=&cmd;
    VKC(vkResetFences(dev,1,&fence)); VKC(vkQueueSubmit(queue,1,&si,fence));
    VKC(vkWaitForFences(dev,1,&fence,VK_TRUE,UINT64_MAX)); return 0; };
  // Verify: one dispatch, exact vs int64 oracle.
  if (record(1)) return 1; if (submit_wait()) return 1;
  { void* p; VKC(vkMapMemory(dev,mC,0,(VkDeviceSize)C.size()*4,0,&p)); std::memcpy(C.data(),p,C.size()*4); vkUnmapMemory(dev,mC); }
  long mism=0; double maxerr=0;
  for (size_t i=0;i<C.size();i++){ double e=std::fabs((double)C[i]-(double)oracle[i]); if (e>maxerr) maxerr=e; if (C[i]!=(float)oracle[i]) mism++; }
  std::printf("gpu_verify elements=%zu mismatches=%ld max_abs_err=%.6f\n", C.size(), mism, maxerr);
  if (mism){ std::printf("RESULT FAIL gpu verify\n"); return 1; }
  // Sustained window: DISP dispatches in one submission, RAPL-bracketed.
  if (record(DISP)) return 1;
  long long e0=read_euj(); auto t0=clk::now();
  if (submit_wait()) return 1;
  double wall_us=std::chrono::duration<double,std::micro>(clk::now()-t0).count();
  long long e1=read_euj();
  { void* p; VKC(vkMapMemory(dev,mC,0,(VkDeviceSize)C.size()*4,0,&p)); std::memcpy(C.data(),p,C.size()*4); vkUnmapMemory(dev,mC); }
  long mism2=0; for (size_t i=0;i<C.size();i++) if (C[i]!=(float)oracle[i]) mism2++;
  std::printf("POWER path=GPU energy_uj_delta=%lld wall_us=%.1f dispatches=%d rapl_ok=%d final_mismatches=%ld\n", (e0>=0&&e1>=0)?e1-e0:-1, wall_us, DISP, (e0>=0&&e1>=0)?1:0, mism2);
  std::printf("RESULT %s gpu gemm exact vs CPU oracle on Vulkan device\n", mism2?"FAIL":"PASS");
  return mism2?1:0;
}
