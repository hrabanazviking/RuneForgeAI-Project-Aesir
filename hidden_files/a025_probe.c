// A-025: Copy-path verdict probe - purpleraider / Strix Halo (gfx1151)
// Measures, at several sizes, on the REAL device (HIPRTC kernels, device
// identity asserted):
//   STAGED  : pageable host -> CPU memcpy into pinned staging buffer ->
//             hipMemcpy H2D -> device buffer -> GPU kernel reads device.
//             (the classic pinned-staging copy path, timed end-to-end AND
//             copy-only; D2H reverse likewise)
//   DIRECT-COPY : hipMemcpy H2D pageable -> device (no staging buffer)
//   DIRECT-MANAGED : CPU writes hipMallocManaged buffer in place (no copy
//             call at all) -> GPU kernel reads it in place.
//   DIRECT-PINNED-ZC : CPU writes hipHostMalloc buffer in place (no copy
//             call) -> GPU kernel reads the pinned allocation in place.
// Every GPU number comes from a real kernel launch verified against the
// expected sum. Warmup runs precede timed reps (A-008 warmup discipline).
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
"extern \"C\" __global__ void sumk(const float* b, float* part, size_t n){\n"
" __shared__ float sh[256]; size_t i = blockIdx.x*(size_t)blockDim.x + threadIdx.x;\n"
" size_t s = gridDim.x*(size_t)blockDim.x; float acc=0.0f;\n"
" for(size_t j=i;j<n;j+=s) acc+=b[j];\n"
" sh[threadIdx.x]=acc; __syncthreads();\n"
" for(int r=128;r>0;r>>=1){ if(threadIdx.x<r) sh[threadIdx.x]+=sh[threadIdx.x+r]; __syncthreads(); }\n"
" if(threadIdx.x==0) part[blockIdx.x]=sh[0]; }\n";
static hipFunction_t g_sum;
static float* g_part=NULL;
static double gpu_sum_timed(const float* buf, size_t n, float expect_each, const char* tag){
  const unsigned blocks=1024;
  if(!g_part) CK(hipMalloc((void**)&g_part, 4096*sizeof(float)));
  void* args[]={(void*)&buf,&g_part,(void*)&n};
  hipEvent_t a,b; CK(hipEventCreate(&a)); CK(hipEventCreate(&b));
  CK(hipEventRecord(a,0));
  CK(hipModuleLaunchKernel(g_sum,blocks,1,1,256,1,1,0,0,args,NULL));
  CK(hipEventRecord(b,0)); CK(hipEventSynchronize(b));
  float ms=0; CK(hipEventElapsedTime(&ms,a,b));
  CK(hipEventDestroy(a)); CK(hipEventDestroy(b));
  float hp[1024]; CK(hipMemcpy(hp,g_part,blocks*sizeof(float),hipMemcpyDeviceToHost));
  double s=0; for(unsigned i=0;i<blocks;i++) s+=hp[i];
  double want=(double)n*expect_each; double rel=fabs(s-want)/want;
  printf("VERIFY %s gpu_sum=%.1f want=%.1f rel=%.2e %s\n",tag,s,want,rel,rel<1e-3?"OK":"MISMATCH");
  if(rel>=1e-3){fprintf(stderr,"VERIFY FAILED %s\n",tag); exit(4);}
  return ms/1000.0;
}
static int cmp_d(const void* x, const void* y){double a=*(const double*)x,b=*(const double*)y; return (a>b)-(a<b);}
static double med(double* v,int n){qsort(v,(size_t)n,sizeof(double),cmp_d); return v[n/2];}
int main(void){
  hipDeviceProp_t p; CK(hipGetDeviceProperties(&p,0));
  printf("DEVICE name=%s gcnArch=%s totalMem=%zu concurrentManaged=%d canMapHost=%d\n",
    p.name,p.gcnArchName,(size_t)p.totalGlobalMem,p.concurrentManagedAccess,p.canMapHostMemory);
  if(strstr(p.gcnArchName,"gfx1151")==NULL){fprintf(stderr,"NOT gfx1151 - refusing\n"); return 2;}
  hiprtcProgram prog; hiprtcResult hr=hiprtcCreateProgram(&prog,KSRC,"k.hip",0,NULL,NULL);
  if(hr!=HIPRTC_SUCCESS){fprintf(stderr,"rtc create fail\n"); return 3;}
  const char* opts[]={"--gpu-architecture=gfx1151"};
  hr=hiprtcCompileProgram(prog,1,opts);
  if(hr!=HIPRTC_SUCCESS){size_t lsz=0; hiprtcGetProgramLogSize(prog,&lsz); char* lg=malloc(lsz+1); hiprtcGetProgramLog(prog,lg); fprintf(stderr,"rtc log: %s\n",lg); return 3;}
  size_t csz=0; hiprtcGetCodeSize(prog,&csz); char* code=malloc(csz); hiprtcGetCode(prog,code);
  hipModule_t mod; CK(hipModuleLoadData(&mod,code));
  CK(hipModuleGetFunction(&g_sum,mod,"sumk"));
  printf("KERNEL sumk compiled via HIPRTC for gfx1151 codeSize=%zu - real GPU execution follows\n",csz);
  const size_t SIZES[]={(size_t)1*1024*1024,(size_t)16*1024*1024,(size_t)64*1024*1024};
  const int REPS=7;
  hipEvent_t e1,e2; CK(hipEventCreate(&e1)); CK(hipEventCreate(&e2));
  for(unsigned si=0; si<sizeof(SIZES)/sizeof(SIZES[0]); si++){
    const size_t BYTES=SIZES[si]; const size_t N=BYTES/sizeof(float);
    printf("=== SIZE bytes=%zu (%.0f MiB) reps=%d ===\n",BYTES,BYTES/1048576.0,REPS);
    float* host=(float*)malloc(BYTES);
    float* back=(float*)malloc(BYTES);
    float* pin=NULL; CK(hipHostMalloc((void**)&pin,BYTES,0));
    float* dev=NULL; CK(hipMalloc((void**)&dev,BYTES));
    float* mg=NULL; CK(hipMallocManaged((void**)&mg,BYTES,hipMemAttachGlobal));
    for(size_t i=0;i<N;i++) host[i]=1.0f;
    // warmup: one full pass of every path (untimed)
    memcpy(pin,host,BYTES); CK(hipMemcpy(dev,pin,BYTES,hipMemcpyHostToDevice));
    (void)gpu_sum_timed(dev,N,1.0f,"warmup_dev");
    for(size_t i=0;i<N;i++) mg[i]=2.0f; (void)gpu_sum_timed(mg,N,2.0f,"warmup_managed");
    for(size_t i=0;i<N;i++) pin[i]=3.0f; (void)gpu_sum_timed(pin,N,3.0f,"warmup_pinned_zc");
    // ---- STAGED end-to-end H2D: cpu memcpy host->pin + hipMemcpy pin->dev
    { double v[7]; for(int r=0;r<REPS;r++){ for(size_t i=0;i<N;i++) host[i]=1.0f;
        double a=now_s(); memcpy(pin,host,BYTES); CK(hipMemcpy(dev,pin,BYTES,hipMemcpyHostToDevice)); v[r]=now_s()-a; }
      double m=med(v,REPS); printf("STAGED_E2E_H2D pageable->pinned->device s=%.5f bw=%.2f GB/s\n",m,BYTES/m/1e9);
      (void)gpu_sum_timed(dev,N,1.0f,"staged_e2e"); }
    // ---- STAGED copy-only: hipMemcpy pinned->dev (staging fill excluded)
    { double v[7]; float ms=0; for(int r=0;r<REPS;r++){ CK(hipEventRecord(e1,0)); CK(hipMemcpy(dev,pin,BYTES,hipMemcpyHostToDevice)); CK(hipEventRecord(e2,0)); CK(hipEventSynchronize(e2)); CK(hipEventElapsedTime(&ms,e1,e2)); v[r]=ms/1000.0; }
      double m=med(v,REPS); printf("STAGED_COPYONLY_H2D hipMemcpy pinned->device s=%.5f bw=%.2f GB/s\n",m,BYTES/m/1e9); }
    // ---- STAGED D2H end-to-end: hipMemcpy dev->pin + cpu memcpy pin->back
    { double v[7]; for(int r=0;r<REPS;r++){ double a=now_s(); CK(hipMemcpy(pin,dev,BYTES,hipMemcpyDeviceToHost)); memcpy(back,pin,BYTES); v[r]=now_s()-a; }
      double m=med(v,REPS); printf("STAGED_E2E_D2H device->pinned->pageable s=%.5f bw=%.2f GB/s verify=%.1f\n",m,BYTES/m/1e9,(double)back[0]); }
    // ---- DIRECT-COPY: hipMemcpy pageable->dev
    { double v[7]; float ms=0; for(int r=0;r<REPS;r++){ CK(hipEventRecord(e1,0)); CK(hipMemcpy(dev,host,BYTES,hipMemcpyHostToDevice)); CK(hipEventRecord(e2,0)); CK(hipEventSynchronize(e2)); CK(hipEventElapsedTime(&ms,e1,e2)); v[r]=ms/1000.0; }
      double m=med(v,REPS); printf("DIRECTCOPY_H2D hipMemcpy pageable->device s=%.5f bw=%.2f GB/s\n",m,BYTES/m/1e9);
      (void)gpu_sum_timed(dev,N,1.0f,"directcopy"); }
    // ---- DIRECT-MANAGED: cpu writes managed in place; GPU reads in place (no copy call)
    { double v[7]; for(int r=0;r<REPS;r++){ for(size_t i=0;i<N;i++) mg[i]=2.0f; v[r]=gpu_sum_timed(mg,N,2.0f,"managed_direct"); }
      double m=med(v,REPS); printf("DIRECT_MANAGED gpu_read_inplace s=%.5f bw=%.2f GB/s (cpu fill excluded; no copy call in path)\n",m,BYTES/m/1e9); }
    // ---- DIRECT-PINNED-ZC: cpu writes pinned in place; GPU reads in place (no copy call)
    { double v[7]; for(int r=0;r<REPS;r++){ for(size_t i=0;i<N;i++) pin[i]=3.0f; v[r]=gpu_sum_timed(pin,N,3.0f,"pinned_zc_direct"); }
      double m=med(v,REPS); printf("DIRECT_PINNED_ZC gpu_read_inplace s=%.5f bw=%.2f GB/s (cpu fill excluded; no copy call in path)\n",m,BYTES/m/1e9); }
    // ---- E2E-LOAD comparison: producer bytes ready in host[] -> GPU has read them once
    { double v[7]; for(int r=0;r<REPS;r++){ for(size_t i=0;i<N;i++) host[i]=1.0f;
        double a=now_s(); memcpy(pin,host,BYTES); CK(hipMemcpy(dev,pin,BYTES,hipMemcpyHostToDevice)); (void)gpu_sum_timed(dev,N,1.0f,"e2e_staged"); v[r]=now_s()-a; }
      double m=med(v,REPS); printf("E2E_LOAD_STAGED host->gpu-read-complete s=%.5f eff_bw=%.2f GB/s\n",m,BYTES/m/1e9); }
    { double v[7]; for(int r=0;r<REPS;r++){ double a=now_s(); for(size_t i=0;i<N;i++) mg[i]=2.0f; (void)gpu_sum_timed(mg,N,2.0f,"e2e_managed"); v[r]=now_s()-a; }
      double m=med(v,REPS); printf("E2E_LOAD_MANAGED host->gpu-read-complete s=%.5f eff_bw=%.2f GB/s\n",m,BYTES/m/1e9); }
    { double v[7]; for(int r=0;r<REPS;r++){ double a=now_s(); for(size_t i=0;i<N;i++) pin[i]=3.0f; (void)gpu_sum_timed(pin,N,3.0f,"e2e_pinned"); v[r]=now_s()-a; }
      double m=med(v,REPS); printf("E2E_LOAD_PINNEDZC host->gpu-read-complete s=%.5f eff_bw=%.2f GB/s\n",m,BYTES/m/1e9); }
    CK(hipFree(mg)); CK(hipFree(dev)); CK(hipFreeHost(pin)); free(host); free(back);
  }
  CK(hipEventDestroy(e1)); CK(hipEventDestroy(e2));
  printf("DONE\n"); return 0;
}
