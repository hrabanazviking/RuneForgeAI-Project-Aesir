// A-008 Vulkan leg: host-coherent buffer semantics on RADV / Strix Halo.
// Asserts a real RADV device (llvmpipe refused), then measures CPU<->GPU
// traffic over HOST_VISIBLE|HOST_COHERENT memory with NO copy calls.
#include <vulkan/vulkan.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#define VKC(x) do{VkResult r=(x); if(r!=VK_SUCCESS){fprintf(stderr,"VK err %d @%d\n",(int)r,__LINE__); exit(1);} }while(0)
static double now_s(void){struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec+ts.tv_nsec*1e-9;}
static uint32_t* load_spv(const char* path, size_t* out_sz){ FILE* f=fopen(path,"rb"); if(!f){perror(path); exit(1);} fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); uint32_t* buf=malloc(n); if(fread(buf,1,n,f)!=(size_t)n){fprintf(stderr,"short read\n"); exit(1);} fclose(f); *out_sz=n; return buf; }
static int g_mode=0;
static VkDevice g_dev; static VkPhysicalDevice g_pd; static VkQueue g_q; static VkCommandPool g_pool;
static void mkbuf(VkDeviceSize sz, VkBuffer* buf, VkDeviceMemory* mem, void** mapped){
  VkBufferCreateInfo bi={VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; bi.size=sz; bi.usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT; bi.sharingMode=VK_SHARING_MODE_EXCLUSIVE;
  VKC(vkCreateBuffer(g_dev,&bi,NULL,buf));
  VkMemoryRequirements mr; vkGetBufferMemoryRequirements(g_dev,*buf,&mr);
  VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(g_pd,&mp);
  int idx=-1; for(uint32_t i=0;i<mp.memoryTypeCount;i++){ if((mr.memoryTypeBits>>i)&1){ VkMemoryPropertyFlags f=mp.memoryTypes[i].propertyFlags; if((f&(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))==(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)){ if(g_mode==0 && (f&VK_MEMORY_PROPERTY_HOST_CACHED_BIT)) idx=(int)i; if(g_mode==1 && (f&VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) && !(f&VK_MEMORY_PROPERTY_HOST_CACHED_BIT)) idx=(int)i; } } }
  if(idx<0){fprintf(stderr,"no matching host-coherent type for mode %d\n",g_mode); exit(1);}
  static int printed=0; if(!printed){ { VkPhysicalDeviceMemoryProperties mp2; vkGetPhysicalDeviceMemoryProperties(g_pd,&mp2); for(uint32_t i=0;i<mp2.memoryTypeCount;i++) printf("MEMTYPE_ALL idx=%u flags=0x%x heap=%u\n",i,(unsigned)mp2.memoryTypes[i].propertyFlags,(unsigned)mp2.memoryTypes[i].heapIndex); } printf("MEMTYPE idx=%d flags=0x%x heap=%u\n",idx,(unsigned)mp.memoryTypes[idx].propertyFlags,(unsigned)mp.memoryTypes[idx].heapIndex); printed=1; }
  VkMemoryAllocateInfo ai={VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; ai.allocationSize=mr.size; ai.memoryTypeIndex=idx;
  VKC(vkAllocateMemory(g_dev,&ai,NULL,mem)); VKC(vkBindBufferMemory(g_dev,*buf,*mem,0));
  VKC(vkMapMemory(g_dev,*mem,0,VK_WHOLE_SIZE,0,mapped)); }
int main(int argc, char** argv){
  const char* dir = argc>1?argv[1]:"."; if(argc>2) g_mode=atoi(argv[2]); printf("MODE %d (%s)\n",g_mode,g_mode?"device-local coherent":"host-cached coherent");
  char pf[512], ps[512]; snprintf(pf,sizeof pf,"%s/fill.spv",dir); snprintf(ps,sizeof ps,"%s/sum.spv",dir);
  VkApplicationInfo app={VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.apiVersion=VK_API_VERSION_1_3;
  VkInstanceCreateInfo ici={VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO}; ici.pApplicationInfo=&app;
  VkInstance inst; VKC(vkCreateInstance(&ici,NULL,&inst));
  uint32_t npd=0; VKC(vkEnumeratePhysicalDevices(inst,&npd,NULL)); VkPhysicalDevice* pds=malloc(npd*sizeof(VkPhysicalDevice)); VKC(vkEnumeratePhysicalDevices(inst,&npd,pds));
  g_pd=NULL; VkPhysicalDeviceProperties props;
  for(uint32_t i=0;i<npd;i++){ VkPhysicalDeviceProperties pp; vkGetPhysicalDeviceProperties(pds[i],&pp);
    printf("VKDEV %u: %s type=%d api=%u.%u.%u\n",i,pp.deviceName,(int)pp.deviceType,VK_VERSION_MAJOR(pp.apiVersion),VK_VERSION_MINOR(pp.apiVersion),VK_VERSION_PATCH(pp.apiVersion));
    if(strstr(pp.deviceName,"llvmpipe")||strstr(pp.deviceName,"LLVM")) continue;
    if(strstr(pp.deviceName,"8060S")||strstr(pp.deviceName,"STRIX")||strstr(pp.deviceName,"Radeon")){ g_pd=pds[i]; props=pp; } }
  if(!g_pd){fprintf(stderr,"no RADV device found - refusing llvmpipe-only result\n"); return 2;}
  printf("SELECTED %s (real RADV device, not llvmpipe)\n",props.deviceName);
  uint32_t nq=0; vkGetPhysicalDeviceQueueFamilyProperties(g_pd,&nq,NULL); VkQueueFamilyProperties* qp=malloc(nq*sizeof(VkQueueFamilyProperties)); vkGetPhysicalDeviceQueueFamilyProperties(g_pd,&nq,qp);
  int qf=-1; for(uint32_t i=0;i<nq;i++) if(qp[i].queueFlags&VK_QUEUE_COMPUTE_BIT){qf=i;break;}
  float prio=1.0f; VkDeviceQueueCreateInfo qci={VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO}; qci.queueFamilyIndex=qf; qci.queueCount=1; qci.pQueuePriorities=&prio;
  VkDeviceCreateInfo dci={VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO}; dci.queueCreateInfoCount=1; dci.pQueueCreateInfos=&qci;
  VKC(vkCreateDevice(g_pd,&dci,NULL,&g_dev)); vkGetDeviceQueue(g_dev,qf,0,&g_q);
  VkCommandPoolCreateInfo cpi={VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO}; cpi.queueFamilyIndex=qf; cpi.flags=VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  VKC(vkCreateCommandPool(g_dev,&cpi,NULL,&g_pool));
  const uint32_t N=64*1024*1024; const VkDeviceSize BYTES=(VkDeviceSize)N*4; const uint32_t GROUPS=N/256;
  VkBuffer bin,bout; VkDeviceMemory min_,mout; void *pin,*pout;
  mkbuf(BYTES,&bin,&min_,&pin); mkbuf(GROUPS*4,&bout,&mout,&pout);
  uint32_t* in=(uint32_t*)pin; uint32_t* out=(uint32_t*)pout;
  // CPU write into coherent memory (timed)
  double t0=now_s(); for(uint32_t i=0;i<N;i++) in[i]=(i&0xFFFFu); double cw=now_s()-t0;
  printf("VK cpu_write_coherent_s=%.4f bw=%.2f GB/s\n",cw,(double)BYTES/cw/1e9);
  // descriptor + pipelines
  VkDescriptorSetLayoutBinding binds[2]={}; binds[0].binding=0; binds[0].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; binds[0].descriptorCount=1; binds[0].stageFlags=VK_SHADER_STAGE_COMPUTE_BIT; binds[1]=binds[0]; binds[1].binding=1;
  VkDescriptorSetLayoutCreateInfo dli={VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dli.bindingCount=2; dli.pBindings=binds;
  VkDescriptorSetLayout dsl; VKC(vkCreateDescriptorSetLayout(g_dev,&dli,NULL,&dsl));
  VkPipelineLayoutCreateInfo pli={VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; pli.setLayoutCount=1; pli.pSetLayouts=&dsl;
  VkPipelineLayout pl; VKC(vkCreatePipelineLayout(g_dev,&pli,NULL,&pl));
  VkDescriptorPoolSize dps={VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,4}; VkDescriptorPoolCreateInfo dpi={VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dpi.poolSizeCount=1; dpi.pPoolSizes=&dps; dpi.maxSets=1;
  VkDescriptorPool dp; VKC(vkCreateDescriptorPool(g_dev,&dpi,NULL,&dp));
  VkDescriptorSetAllocateInfo dai={VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; dai.descriptorPool=dp; dai.descriptorSetCount=1; dai.pSetLayouts=&dsl;
  VkDescriptorSet ds; VKC(vkAllocateDescriptorSets(g_dev,&dai,&ds));
  VkDescriptorBufferInfo dbi[2]={}; dbi[0].buffer=bin; dbi[0].range=VK_WHOLE_SIZE; dbi[1].buffer=bout; dbi[1].range=VK_WHOLE_SIZE;
  VkWriteDescriptorSet wr[2]={}; for(int i=0;i<2;i++){ wr[i].sType=VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET; wr[i].dstSet=ds; wr[i].dstBinding=i; wr[i].descriptorCount=1; wr[i].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[i].pBufferInfo=&dbi[i]; }
  vkUpdateDescriptorSets(g_dev,2,wr,0,NULL);
  size_t fsz,ssz; uint32_t* fcode=load_spv(pf,&fsz); uint32_t* scode=load_spv(ps,&ssz);
  VkShaderModuleCreateInfo smi={VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
  VkShaderModule fmod,smod; smi.codeSize=fsz; smi.pCode=fcode; VKC(vkCreateShaderModule(g_dev,&smi,NULL,&fmod));
  smi.codeSize=ssz; smi.pCode=scode; VKC(vkCreateShaderModule(g_dev,&smi,NULL,&smod));
  VkComputePipelineCreateInfo cp[2]={}; for(int i=0;i<2;i++){ cp[i].sType=VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO; cp[i].stage.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; cp[i].stage.stage=VK_SHADER_STAGE_COMPUTE_BIT; cp[i].stage.pName="main"; cp[i].layout=pl; }
  cp[0].stage.module=fmod; cp[1].stage.module=smod;
  VkPipeline pipes[2]; VKC(vkCreateComputePipelines(g_dev,NULL,2,cp,NULL,pipes));
  VkCommandBufferAllocateInfo cai={VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO}; cai.commandPool=g_pool; cai.level=VK_COMMAND_BUFFER_LEVEL_PRIMARY; cai.commandBufferCount=1;
  VkCommandBuffer cb; VKC(vkAllocateCommandBuffers(g_dev,&cai,&cb));
  // dispatch helper: record + submit + wait, host-timed
  // GPU sum over CPU-written coherent buffer -> verifies CPU->GPU visibility
  double best=1e9;
  for(int r=0;r<5;r++){ VkCommandBufferBeginInfo begin={VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}; VKC(vkBeginCommandBuffer(cb,&begin)); vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pipes[1]); vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pl,0,1,&ds,0,NULL); vkCmdDispatch(cb,GROUPS,1,1); VKC(vkEndCommandBuffer(cb));
    VkSubmitInfo si={VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount=1; si.pCommandBuffers=&cb; double a=now_s(); VKC(vkQueueSubmit(g_q,1,&si,VK_NULL_HANDLE)); VKC(vkQueueWaitIdle(g_q)); double dt=now_s()-a; if(dt<best)best=dt; VKC(vkResetCommandBuffer(cb,0)); }
  uint64_t tot=0; for(uint32_t i=0;i<GROUPS;i++) tot+=out[i]; uint64_t want=0; for(uint32_t i=0;i<N;i++) want+=(i&0xFFFFu);
  printf("VK gpu_sum_coherent_s=%.4f bw=%.2f GB/s total=%llu want=%llu %s\n",best,(double)BYTES/best/1e9,(unsigned long long)tot,(unsigned long long)want,tot==want?"OK":"MISMATCH");
  // GPU fill, then CPU reads the same mapping back (GPU->CPU, no copy call)
  { VkCommandBufferBeginInfo begin={VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO}; VKC(vkBeginCommandBuffer(cb,&begin)); vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pipes[0]); vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pl,0,1,&ds,0,NULL); vkCmdDispatch(cb,GROUPS,1,1); VKC(vkEndCommandBuffer(cb));
    VkSubmitInfo si={VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount=1; si.pCommandBuffers=&cb; double a=now_s(); VKC(vkQueueSubmit(g_q,1,&si,VK_NULL_HANDLE)); VKC(vkQueueWaitIdle(g_q)); double dt=now_s()-a;
    printf("VK gpu_fill_coherent_s=%.4f bw=%.2f GB/s\n",dt,(double)BYTES/dt/1e9); }
  double a=now_s(); uint64_t chk=0; int bad=0; for(uint32_t i=0;i<N;i++){ uint32_t e=(uint32_t)(i*2654435761u); if(in[i]!=e) bad++; chk+=in[i]; } double cr=now_s()-a;
  printf("VK cpu_read_of_gpu_written_s=%.4f bw=%.2f GB/s bad=%d %s\n",cr,(double)BYTES/cr/1e9,bad,bad==0?"OK":"MISMATCH");
  printf("DONE\n"); return 0; }
