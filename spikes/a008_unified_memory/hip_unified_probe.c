// A-008: Unified-memory semantics probe (HIP leg) - purpleraider / Strix Halo
// Host: gcc C11 against libamdhip64; kernels compiled at runtime via HIPRTC
// (hipcc absent on this machine; A-011 C-shim pattern). Every GPU number
// below comes from a real kernel launch on the gfx1151 device whose
// identity is asserted and printed first.
#include <hip/hip_runtime_api.h>
#include <hip/hiprtc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#define CK(x) do{hipError_t e=(x); if(e!=hipSuccess){fprintf(stderr,"HIP err %s @%d\n",hipGetErrorString(e),__LINE__); exit(1);} }while(0)
static double now_s(void){struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec+ts.tv_nsec*1e-9;}
static const char* KSRC =
"extern \"C\" __global__ void fillk(float* b, float v, size_t n){\n"
" size_t i = blockIdx.x*(size_t)blockDim.x + threadIdx.x;\n"
" size_t s = gridDim.x*(size_t)blockDim.x;\n"
" for(size_t j=i;j<n;j+=s) b[j]=v; }\n"
"extern \"C\" __global__ void sumk(const float* b, float* part, size_t n){\n"
" __shared__ float sh[256]; size_t i = blockIdx.x*(size_t)blockDim.x + threadIdx.x;\n"
" size_t s = gridDim.x*(size_t)blockDim.x; float acc=0.0f;\n"
" for(size_t j=i;j<n;j+=s) acc+=b[j];\n"
" sh[threadIdx.x]=acc; __syncthreads();\n"
" for(int r=128;r>0;r>>=1){ if(threadIdx.x<r) sh[threadIdx.x]+=sh[threadIdx.x+r]; __syncthreads(); }\n"
" if(threadIdx.x==0) part[blockIdx.x]=sh[0]; }\n";
static hipFunction_t g_fill, g_sum;
static float ktime(hipFunction_t f, void** args, unsigned blocks){
  hipEvent_t a,b; CK(hipEventCreate(&a)); CK(hipEventCreate(&b));
  CK(hipEventRecord(a,0));
  CK(hipModuleLaunchKernel(f,blocks,1,1,256,1,1,0,0,args,NULL));
  CK(hipEventRecord(b,0)); CK(hipEventSynchronize(b));
  float ms=0; CK(hipEventElapsedTime(&ms,a,b));
  CK(hipEventDestroy(a)); CK(hipEventDestroy(b)); return ms/1000.0f; }
static double gpu_sum(float* buf, size_t n, float expect_each, const char* tag){
  static float* part=NULL; if(!part) CK(hipMalloc((void**)&part, 4096*sizeof(float)));
  unsigned blocks=1024; void* args[]={&buf,&part,&n};
  double t=ktime(g_sum,args,blocks); float hp[1024];
  CK(hipMemcpy(hp,part,blocks*sizeof(float),hipMemcpyDeviceToHost));
  double s=0; for(unsigned i=0;i<blocks;i++) s+=hp[i];
  double want=(double)n*expect_each; double rel=fabs(s-want)/want;
  printf("VERIFY %s gpu_sum=%.1f want=%.1f rel=%.2e %s\n",tag,s,want,rel,rel<1e-3?"OK":"MISMATCH");
  return t; }
int main(void){
  hipDeviceProp_t p; CK(hipGetDeviceProperties(&p,0));
  size_t tf=0,tt=0; CK(hipMemGetInfo(&tf,&tt));
  printf("DEVICE name=%s gcnArch=%s totalMem=%zu concurrentManaged=%d pageableMemAccess=%d canMapHost=%d\n",
    p.name,p.gcnArchName,(size_t)p.totalGlobalMem,p.concurrentManagedAccess,p.pageableMemoryAccess,p.canMapHostMemory);
  printf("MEMINFO free=%zu total=%zu\n",tf,tt);
  if(strstr(p.gcnArchName,"gfx1151")==NULL){fprintf(stderr,"NOT gfx1151 - refusing\n"); return 2;}
  hiprtcProgram prog; hiprtcResult hr=hiprtcCreateProgram(&prog,KSRC,"k.hip",0,NULL,NULL);
  if(hr!=HIPRTC_SUCCESS){fprintf(stderr,"rtc create fail\n"); return 3;}
  const char* opts[]={"--gpu-architecture=gfx1151"};
  hr=hiprtcCompileProgram(prog,1,opts);
  if(hr!=HIPRTC_SUCCESS){size_t lsz=0; hiprtcGetProgramLogSize(prog,&lsz); char* lg=malloc(lsz+1); hiprtcGetProgramLog(prog,lg); fprintf(stderr,"rtc log: %s\n",lg); return 3;}
  size_t csz=0; hiprtcGetCodeSize(prog,&csz); char* code=malloc(csz); hiprtcGetCode(prog,code);
  hipModule_t mod; CK(hipModuleLoadData(&mod,code));
  CK(hipModuleGetFunction(&g_fill,mod,"fillk")); CK(hipModuleGetFunction(&g_sum,mod,"sumk"));
  printf("KERNELS compiled via HIPRTC for gfx1151, codeSize=%zu - real GPU execution follows\n",csz);
  const size_t N=(size_t)64*1024*1024; const size_t BYTES=N*sizeof(float); const int REPS=5;
  printf("BUFFER floats=%zu bytes=%zu (%.0f MiB) reps=%d\n",N,BYTES,BYTES/1048576.0,REPS);
  // ---------- MANAGED ----------
  float* mg=NULL; CK(hipMallocManaged((void**)&mg,BYTES,hipMemAttachGlobal));
  // CPU first-touch write on fresh managed alloc (page-fault cost, CPU side)
  double t0=now_s(); for(size_t i=0;i<N;i++) mg[i]=1.0f; double cpu_ft=now_s()-t0;
  printf("MANAGED cpu_first_touch_write_s=%.4f bw=%.2f GB/s\n",cpu_ft,BYTES/cpu_ft/1e9);
  // CPU warm write + GPU read (CPU-written -> GPU-read bandwidth)
  double cw=0; {double a=now_s(); for(size_t i=0;i<N;i++) mg[i]=2.0f; cw=now_s()-a;}
  printf("MANAGED cpu_warm_write_s=%.4f bw=%.2f GB/s\n",cw,BYTES/cw/1e9);
  {double a2=now_s(); double q0=0,q1=0,q2=0,q3=0,q4=0,q5=0,q6=0,q7=0; for(size_t i=0;i+8<=N;i+=8){q0+=mg[i];q1+=mg[i+1];q2+=mg[i+2];q3+=mg[i+3];q4+=mg[i+4];q5+=mg[i+5];q6+=mg[i+6];q7+=mg[i+7];} double qs=q0+q1+q2+q3+q4+q5+q6+q7; double ct=now_s()-a2; printf("MANAGED cpu_read_of_cpu_written_s=%.4f bw=%.2f GB/s sum_ok=%d\n",ct,BYTES/ct/1e9,(qs==(double)N*2.0));}
  double best=1e9; for(int r=0;r<REPS;r++){double t=gpu_sum(mg,N,2.0f,"managed_cpu_written"); if(t<best)best=t;}
  printf("MANAGED gpu_read_of_cpu_written_s=%.4f bw=%.2f GB/s\n",best,BYTES/best/1e9);
  // GPU write -> CPU read
  {float v=3.0f; void* a[]={&mg,&v,(void*)&N}; double t=ktime(g_fill,a,1024);
   printf("MANAGED gpu_fill_s=%.4f bw=%.2f GB/s\n",t,BYTES/t/1e9);}
  CK(hipDeviceSynchronize());
  double a=now_s(); double s0=0,s1=0,s2=0,s3=0,s4=0,s5=0,s6=0,s7=0;
  for(size_t i=0;i+8<=N;i+=8){ s0+=mg[i]; s1+=mg[i+1]; s2+=mg[i+2]; s3+=mg[i+3]; s4+=mg[i+4]; s5+=mg[i+5]; s6+=mg[i+6]; s7+=mg[i+7]; }
  double s=s0+s1+s2+s3+s4+s5+s6+s7; double cr=now_s()-a;
  printf("MANAGED cpu_read_of_gpu_written_s=%.4f bw=%.2f GB/s sum=%.1f %s\n",cr,BYTES/cr/1e9,s,(s==(double)N*3.0)?"OK":"MISMATCH");
  CK(hipFree(mg));
  // ---------- MANAGED GPU first-touch (page faults on GPU side) ----------
  float* m2=NULL; CK(hipMallocManaged((void**)&m2,BYTES,hipMemAttachGlobal));
  {void* a2[]={&m2,&m2}; float* part=NULL; CK(hipMalloc((void**)&part,4096*sizeof(float)));
   size_t n=N; void* args[]={&m2,&part,&n};
   double first=ktime(g_sum,args,1024); double steady=ktime(g_sum,args,1024);
   size_t pages=BYTES/4096;
   printf("MANAGED gpu_first_touch_sum_s=%.4f steady_sum_s=%.4f fault_overhead_s=%.4f pages=%zu per_page_us=%.3f\n",
     first,steady,first-steady,pages,(first-steady)/pages*1e6);
   CK(hipFree(part));}
  CK(hipFree(m2));
  // ---------- DEVICE buffer (explicit-copy control) ----------
  float* dev=NULL; CK(hipMalloc((void**)&dev,BYTES));
  float* host=(float*)malloc(BYTES); for(size_t i=0;i<N;i++) host[i]=4.0f;
  hipEvent_t e1,e2; CK(hipEventCreate(&e1)); CK(hipEventCreate(&e2)); float ms=0;
  double bh=1e9; for(int r=0;r<REPS;r++){CK(hipEventRecord(e1,0)); CK(hipMemcpy(dev,host,BYTES,hipMemcpyHostToDevice)); CK(hipEventRecord(e2,0)); CK(hipEventSynchronize(e2)); CK(hipEventElapsedTime(&ms,e1,e2)); if(ms/1000.0<bh)bh=ms/1000.0;}
  printf("DEVICE memcpy_H2D_pageable_s=%.4f bw=%.2f GB/s\n",bh,BYTES/bh/1e9);
  gpu_sum(dev,N,4.0f,"device_buffer");
  {float v=5.0f; size_t n=N; void* a3[]={&dev,&v,&n}; double t=ktime(g_fill,a3,1024); printf("DEVICE gpu_fill_s=%.4f bw=%.2f GB/s\n",t,BYTES/t/1e9);}
  double bd=1e9; for(int r=0;r<REPS;r++){CK(hipEventRecord(e1,0)); CK(hipMemcpy(host,dev,BYTES,hipMemcpyDeviceToHost)); CK(hipEventRecord(e2,0)); CK(hipEventSynchronize(e2)); CK(hipEventElapsedTime(&ms,e1,e2)); if(ms/1000.0<bd)bd=ms/1000.0;}
  printf("DEVICE memcpy_D2H_pageable_s=%.4f bw=%.2f GB/s verify0=%.1f\n",bd,BYTES/bd/1e9,(double)host[0]);
  // ---------- PINNED host memory ----------
  float* pin=NULL; CK(hipHostMalloc((void**)&pin,BYTES,0));
  for(size_t i=0;i<N;i++) pin[i]=6.0f;
  double bp=1e9; for(int r=0;r<REPS;r++){CK(hipEventRecord(e1,0)); CK(hipMemcpy(dev,pin,BYTES,hipMemcpyHostToDevice)); CK(hipEventRecord(e2,0)); CK(hipEventSynchronize(e2)); CK(hipEventElapsedTime(&ms,e1,e2)); if(ms/1000.0<bp)bp=ms/1000.0;}
  printf("PINNED memcpy_H2D_s=%.4f bw=%.2f GB/s\n",bp,BYTES/bp/1e9);
  gpu_sum(dev,N,6.0f,"device_from_pinned");
  // zero-copy: kernel reads pinned host memory DIRECTLY (no copy call)
  double bz=1e9; for(int r=0;r<REPS;r++){double t=gpu_sum(pin,N,6.0f,"pinned_zerocopy"); if(t<bz)bz=t;}
  printf("PINNED gpu_read_zerocopy_s=%.4f bw=%.2f GB/s\n",bz,BYTES/bz/1e9);
  {float v=7.0f; size_t n=N; void* a4[]={&pin,&v,&n}; double t=ktime(g_fill,a4,1024); printf("PINNED gpu_fill_zerocopy_s=%.4f bw=%.2f GB/s cpu_sees=%.1f\n",t,BYTES/t/1e9,(double)pin[0]);}
  CK(hipFreeHost(pin)); CK(hipFree(dev)); free(host);
  CK(hipEventDestroy(e1)); CK(hipEventDestroy(e2));
  printf("DONE\n"); return 0; }
