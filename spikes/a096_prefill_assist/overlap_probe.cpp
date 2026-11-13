// A-096 -- NPU prefill-assist overlap experiment (team-26).
// NPU computes a prefill projection GEMM (128x1024x1024, the A-094
// FIT shape, A-092/A-094 xclbin) while the GPU (Vulkan compute on
// gfx1151) runs decode-shaped GEMV work for the previous token.
// Modes timed per rep: NPU alone, GPU alone, serial (NPU then GPU),
// overlap (NPU start, GPU submit+wait, NPU wait). Exact integer
// verify of the NPU result vs CPU oracle and fp verify of the GPU
// GEMV vs CPU run before timing. Device names printed from live
// handles (XRT device name; VkPhysicalDevice properties).
#include "xrt/xrt_bo.h"
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"
#include <vulkan/vulkan.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>
#include <chrono>
#include <algorithm>
#include <cmath>
using clk = std::chrono::steady_clock;
static double us(clk::duration d){ return std::chrono::duration<double, std::micro>(d).count(); }
static double med(std::vector<double> v){ std::sort(v.begin(), v.end()); return v[v.size()/2]; }
#define VKC(x) do{ VkResult r_=(x); if(r_!=VK_SUCCESS){ std::printf("FAIL vk %d at %d\n",(int)r_,__LINE__); return 1; } }while(0)
int main(int argc, char **argv) {
  if (argc < 4) { std::printf("usage: %s <xclbin> <insts.bin> <gemv.spv> [gpu_reps]\n", argv[0]); return 2; }
  const int M = 128, K = 1024, N = 1024;
  const uint32_t GREPS = argc > 4 ? (uint32_t)atoi(argv[4]) : 64;
  const int32_t SENTINEL = 0x7fffffff;
  std::ifstream fi(argv[2], std::ios::binary);
  if (!fi) { std::printf("FAIL cannot open insts\n"); return 2; }
  std::vector<char> ibytes((std::istreambuf_iterator<char>(fi)), std::istreambuf_iterator<char>());
  const size_t ninstr = ibytes.size() / 4;
  std::printf("insts_bytes=%zu ninstr_words=%zu gpu_reps=%u\n", ibytes.size(), ninstr, GREPS);
  std::vector<int16_t> A(M * K), B(K * N);
  uint32_t s = 0xA092u;
  auto nextv = [&s]() { s = s * 1664525u + 1013904223u; return (int16_t)((int)((s >> 16) % 17u) - 8); };
  for (auto &v : A) v = nextv();
  for (auto &v : B) v = nextv();
  std::vector<int32_t> oracle(M * N, 0);
  for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) { int64_t acc = 0; for (int k = 0; k < K; k++) acc += (int64_t)A[i * K + k] * B[k * N + j]; oracle[i * N + j] = (int32_t)acc; }
  xrt::device device(0);
  std::printf("npu_device_name=%s\n", device.get_info<xrt::info::device::name>().c_str());
  xrt::xclbin xclbin{std::string(argv[1])};
  std::printf("xclbin_uuid=%s\n", xclbin.get_uuid().to_string().c_str());
  device.register_xclbin(xclbin);
  xrt::hw_context context(device, xclbin.get_uuid());
  xrt::kernel kernel(context, "MLIR_AIE");
  auto bo_instr = xrt::bo(device, ibytes.size(), XCL_BO_FLAGS_CACHEABLE, kernel.group_id(1));
  auto bo_a = xrt::bo(device, A.size() * sizeof(int16_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(3));
  auto bo_b = xrt::bo(device, B.size() * sizeof(int16_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(4));
  auto bo_c = xrt::bo(device, oracle.size() * sizeof(int32_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(5));
  std::memcpy(bo_instr.map<void *>(), ibytes.data(), ibytes.size());
  std::memcpy(bo_a.map<int16_t *>(), A.data(), A.size() * sizeof(int16_t));
  std::memcpy(bo_b.map<int16_t *>(), B.data(), B.size() * sizeof(int16_t));
  int32_t *cmap = bo_c.map<int32_t *>();
  for (size_t i = 0; i < oracle.size(); i++) cmap[i] = SENTINEL;
  bo_instr.sync(XCL_BO_SYNC_BO_TO_DEVICE); bo_a.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  bo_b.sync(XCL_BO_SYNC_BO_TO_DEVICE); bo_c.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  auto npu_start = [&]() {
    auto run = xrt::run(kernel);
    run.set_arg(0, 3u); run.set_arg(1, bo_instr); run.set_arg(2, (uint32_t)ninstr);
    run.set_arg(3, bo_a); run.set_arg(4, bo_b); run.set_arg(5, bo_c);
    run.start();
    return run;
  };
  { auto run = npu_start(); ert_cmd_state st = run.wait();
    std::printf("verify ert_cmd_state=%d (COMPLETED=%d)\n", (int)st, (int)ERT_CMD_STATE_COMPLETED);
    if (st != ERT_CMD_STATE_COMPLETED) { std::printf("RESULT FAIL npu verify state\n"); return 1; } }
  bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
  long mism = 0, sent = 0; uint64_t cksum = 0;
  for (int i = 0; i < M * N; i++) { int32_t got = cmap[i]; cksum = cksum * 1099511628211ULL + (uint64_t)(uint32_t)got; if (got == SENTINEL) sent++; if (got != oracle[i]) mism++; }
  std::printf("npu_verify elements=%d mismatches=%ld sentinel_remaining=%ld checksum=%llu\n", M * N, mism, sent, (unsigned long long)cksum);
  if (mism || sent) { std::printf("RESULT FAIL npu verify\n"); return 1; }
  // ---- Vulkan GPU decode-shaped GEMV (dim=1024) ----
  const uint32_t DIM = 1024;
  std::vector<float> hW((size_t)DIM * DIM), hX(DIM), hY(DIM);
  uint32_t s2 = 0xB096u;
  auto nextf = [&s2]() { s2 = s2 * 1664525u + 1013904223u; return ((float)((s2 >> 16) % 200u) - 100.0f) / 100.0f; };
  for (auto &v : hW) v = nextf();
  for (auto &v : hX) v = nextf();
  VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO}; app.pApplicationName = "a096"; app.apiVersion = VK_API_VERSION_1_1;
  VkInstanceCreateInfo ii{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO}; ii.pApplicationInfo = &app;
  VkInstance inst; VKC(vkCreateInstance(&ii, nullptr, &inst));
  uint32_t npd = 0; vkEnumeratePhysicalDevices(inst, &npd, nullptr);
  std::vector<VkPhysicalDevice> pds(npd); vkEnumeratePhysicalDevices(inst, &npd, pds.data());
  VkPhysicalDevice pd = pds[0]; uint32_t best = 0;
  for (uint32_t i = 0; i < npd; i++) { VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(pds[i], &p); std::printf("gpu_candidate[%u]=%s type=%d\n", i, p.deviceName, (int)p.deviceType); if (p.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) { pd = pds[i]; best = i; } }
  { VkPhysicalDeviceProperties p; vkGetPhysicalDeviceProperties(pd, &p); std::printf("gpu_device_name=%s\n", p.deviceName); (void)best; }
  uint32_t nq = 0; vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, nullptr);
  std::vector<VkQueueFamilyProperties> qfs(nq); vkGetPhysicalDeviceQueueFamilyProperties(pd, &nq, qfs.data());
  uint32_t qf = 0; for (uint32_t i = 0; i < nq; i++) if (qfs[i].queueFlags & VK_QUEUE_COMPUTE_BIT) { qf = i; break; }
  float prio = 1.0f; VkDeviceQueueCreateInfo qci{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO}; qci.queueFamilyIndex = qf; qci.queueCount = 1; qci.pQueuePriorities = &prio;
  VkDeviceCreateInfo dci{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO}; dci.queueCreateInfoCount = 1; dci.pQueueCreateInfos = &qci;
  VkDevice dev; VKC(vkCreateDevice(pd, &dci, nullptr, &dev));
  VkQueue queue; vkGetDeviceQueue(dev, qf, 0, &queue);
  auto mkbuf = [&](VkDeviceSize sz, VkBuffer &buf, VkDeviceMemory &mem, void *src) -> int {
    VkBufferCreateInfo bci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO}; bci.size = sz; bci.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT; bci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    VKC(vkCreateBuffer(dev, &bci, nullptr, &buf));
    VkMemoryRequirements mr; vkGetBufferMemoryRequirements(dev, buf, &mr);
    VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd, &mp);
    uint32_t mt = 0; for (uint32_t i = 0; i < mp.memoryTypeCount; i++) if ((mr.memoryTypeBits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) == (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) { mt = i; break; }
    VkMemoryAllocateInfo mai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO}; mai.allocationSize = mr.size; mai.memoryTypeIndex = mt;
    VKC(vkAllocateMemory(dev, &mai, nullptr, &mem)); VKC(vkBindBufferMemory(dev, buf, mem, 0));
    if (src) { void *p; VKC(vkMapMemory(dev, mem, 0, sz, 0, &p)); std::memcpy(p, src, sz); vkUnmapMemory(dev, mem); }
    return 0;
  };
  VkBuffer bW, bX, bY; VkDeviceMemory mW, mX, mY;
  if (mkbuf((VkDeviceSize)DIM * DIM * 4, bW, mW, hW.data())) return 1;
  if (mkbuf((VkDeviceSize)DIM * 4, bX, mX, hX.data())) return 1;
  if (mkbuf((VkDeviceSize)DIM * 4, bY, mY, nullptr)) return 1;
  std::ifstream fs(argv[3], std::ios::binary);
  std::vector<char> spv((std::istreambuf_iterator<char>(fs)), std::istreambuf_iterator<char>());
  VkShaderModuleCreateInfo sci{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO}; sci.codeSize = spv.size(); sci.pCode = (const uint32_t *)spv.data();
  VkShaderModule sm; VKC(vkCreateShaderModule(dev, &sci, nullptr, &sm));
  VkDescriptorSetLayoutBinding db[3]{};
  for (int i = 0; i < 3; i++) { db[i].binding = i; db[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; db[i].descriptorCount = 1; db[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT; }
  VkDescriptorSetLayoutCreateInfo dslci{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO}; dslci.bindingCount = 3; dslci.pBindings = db;
  VkDescriptorSetLayout dsl; VKC(vkCreateDescriptorSetLayout(dev, &dslci, nullptr, &dsl));
  VkPushConstantRange pcr{}; pcr.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT; pcr.offset = 0; pcr.size = 8;
  VkPipelineLayoutCreateInfo plci{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO}; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
  VkPipelineLayout pl; VKC(vkCreatePipelineLayout(dev, &plci, nullptr, &pl));
  VkComputePipelineCreateInfo cpci{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO}; cpci.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO; cpci.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT; cpci.stage.module = sm; cpci.stage.pName = "main"; cpci.layout = pl;
  VkPipeline pipe; VKC(vkCreateComputePipelines(dev, nullptr, 1, &cpci, nullptr, &pipe));
  VkDescriptorPoolSize dps{}; dps.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; dps.descriptorCount = 3;
  VkDescriptorPoolCreateInfo dpci{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO}; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &dps;
  VkDescriptorPool dpool; VKC(vkCreateDescriptorPool(dev, &dpci, nullptr, &dpool));
  VkDescriptorSetAllocateInfo dsai{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO}; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
  VkDescriptorSet dset; VKC(vkAllocateDescriptorSets(dev, &dsai, &dset));
  VkDescriptorBufferInfo dbi[3] = {{bW, 0, VK_WHOLE_SIZE}, {bX, 0, VK_WHOLE_SIZE}, {bY, 0, VK_WHOLE_SIZE}};
  VkWriteDescriptorSet wr[3]{};
  for (int i = 0; i < 3; i++) { wr[i].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET; wr[i].dstSet = dset; wr[i].dstBinding = i; wr[i].descriptorCount = 1; wr[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER; wr[i].pBufferInfo = &dbi[i]; }
  vkUpdateDescriptorSets(dev, 3, wr, 0, nullptr);
  VkCommandPoolCreateInfo cpi{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO}; cpi.queueFamilyIndex = qf; cpi.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  VkCommandPool cpool; VKC(vkCreateCommandPool(dev, &cpi, nullptr, &cpool));
  VkCommandBufferAllocateInfo cbai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO}; cbai.commandPool = cpool; cbai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; cbai.commandBufferCount = 1;
  VkCommandBuffer cmd; VKC(vkAllocateCommandBuffers(dev, &cbai, &cmd));
  VkFenceCreateInfo fci{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  VkFence fence; VKC(vkCreateFence(dev, &fci, nullptr, &fence));
  auto gpu_run = [&]() -> int {
    VKC(vkResetCommandBuffer(cmd, 0));
    VkCommandBufferBeginInfo cbbi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    VKC(vkBeginCommandBuffer(cmd, &cbbi));
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipe);
    vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &dset, 0, nullptr);
    uint32_t pcv[2] = {GREPS, DIM};
    vkCmdPushConstants(cmd, pl, VK_SHADER_STAGE_COMPUTE_BIT, 0, 8, pcv);
    vkCmdDispatch(cmd, DIM / 256, 1, 1);
    VKC(vkEndCommandBuffer(cmd));
    VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO}; si.commandBufferCount = 1; si.pCommandBuffers = &cmd;
    VKC(vkResetFences(dev, 1, &fence));
    VKC(vkQueueSubmit(queue, 1, &si, fence));
    return 0;
  };
  auto gpu_wait = [&]() { vkWaitForFences(dev, 1, &fence, VK_TRUE, UINT64_MAX); };
  if (gpu_run()) return 1; gpu_wait();
  { void *p; VKC(vkMapMemory(dev, mY, 0, (VkDeviceSize)DIM * 4, 0, &p)); std::memcpy(hY.data(), p, (size_t)DIM * 4); vkUnmapMemory(dev, mY); }
  double gmax = 0; for (uint32_t i = 0; i < DIM; i++) { double acc = 0; for (uint32_t k = 0; k < DIM; k++) acc += (double)hW[(size_t)i * DIM + k] * hX[k]; gmax = std::max(gmax, std::fabs(acc - hY[i])); }
  std::printf("gpu_verify dim=%u max_abs_err=%.6f\n", DIM, gmax);
  if (gmax > 0.05) { std::printf("RESULT FAIL gpu verify\n"); return 1; }
  const int REPS = 21;
  std::vector<double> v_npu, v_gpu, v_ser, v_ovl;
  for (int r = 0; r < REPS; r++) { auto t0 = clk::now(); auto run = npu_start(); run.wait(); bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE); v_npu.push_back(us(clk::now() - t0)); }
  for (int r = 0; r < REPS; r++) { auto t0 = clk::now(); if (gpu_run()) return 1; gpu_wait(); v_gpu.push_back(us(clk::now() - t0)); }
  for (int r = 0; r < REPS; r++) { auto t0 = clk::now(); auto run = npu_start(); run.wait(); bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE); if (gpu_run()) return 1; gpu_wait(); v_ser.push_back(us(clk::now() - t0)); }
  for (int r = 0; r < REPS; r++) { auto t0 = clk::now(); auto run = npu_start(); if (gpu_run()) return 1; gpu_wait(); run.wait(); bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE); v_ovl.push_back(us(clk::now() - t0)); }
  double mn = med(v_npu), mg = med(v_gpu), ms = med(v_ser), mo = med(v_ovl);
  double benefit = ms - mo;
  double hide = benefit / std::min(mn, mg) * 100.0;
  std::printf("TIMING npu_alone_us median=%.1f gpu_alone_us median=%.1f serial_us median=%.1f overlap_us median=%.1f reps=%d\n", mn, mg, ms, mo, REPS);
  std::printf("OVERLAP benefit_us=%.1f hidden_pct_of_shorter=%.1f serial_sum_check=%.1f\n", benefit, hide, mn + mg);
  std::printf("RESULT %s\n", benefit > 0 ? "PASS overlap benefit measured" : "NEGATIVE no overlap benefit measured");
  return 0;
}
