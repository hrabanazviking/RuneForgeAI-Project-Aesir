#include <hip/hip_runtime_api.h>
#include <hip/hiprtc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#define CK(x) do{hipError_t e=(x); if(e!=hipSuccess){fprintf(stderr,"err %s\n",hipGetErrorString(e)); exit(1);} }while(0)
static double now_s(void){struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec+ts.tv_nsec*1e-9;}
static const char* KSRC = "extern \"C\" __global__ void fillk(float* b, float v, size_t n){ size_t i=blockIdx.x*(size_t)blockDim.x+threadIdx.x; size_t s=gridDim.x*(size_t)blockDim.x; for(size_t j=i;j<n;j+=s) b[j]=v; }\n";
int main(void){ hiprtcProgram pr; hiprtcCreateProgram(&pr,KSRC,"k",0,NULL,NULL); const char* o[]={"--gpu-architecture=gfx1151"}; if(hiprtcCompileProgram(pr,1,o)!=HIPRTC_SUCCESS){fprintf(stderr,"rtc fail\n"); return 3;} size_t cs=0; hiprtcGetCodeSize(pr,&cs); char* code=malloc(cs); hiprtcGetCode(pr,code); hipModule_t m; CK(hipModuleLoadData(&m,code)); hipFunction_t f; CK(hipModuleGetFunction(&f,m,"fillk"));
 const size_t N=(size_t)64*1024*1024, BYTES=N*4; float* mg; CK(hipMallocManaged((void**)&mg,BYTES,hipMemAttachGlobal));
 float v=3.0f; size_t n=N; void* a[]={&mg,&v,&n}; CK(hipModuleLaunchKernel(f,1024,1,1,256,1,1,0,0,a,NULL)); CK(hipDeviceSynchronize());
 for(int r=0;r<4;r++){ double t0=now_s(); double s0=0,s1=0,s2=0,s3=0,s4=0,s5=0,s6=0,s7=0; for(size_t i=0;i+8<=N;i+=8){s0+=mg[i];s1+=mg[i+1];s2+=mg[i+2];s3+=mg[i+3];s4+=mg[i+4];s5+=mg[i+5];s6+=mg[i+6];s7+=mg[i+7];} double s=s0+s1+s2+s3+s4+s5+s6+s7; double dt=now_s()-t0; printf("CPU reread pass %d s=%.4f bw=%.2f GB/s sum_ok=%d\n",r,dt,BYTES/dt/1e9,(s==(double)N*3.0)); }
 // CPU write then read back (does CPU touch restore fast reads?)
 for(size_t i=0;i<N;i++) mg[i]=9.0f; double t0=now_s(); double s0=0,s1=0,s2=0,s3=0,s4=0,s5=0,s6=0,s7=0; for(size_t i=0;i+8<=N;i+=8){s0+=mg[i];s1+=mg[i+1];s2+=mg[i+2];s3+=mg[i+3];s4+=mg[i+4];s5+=mg[i+5];s6+=mg[i+6];s7+=mg[i+7];} double s=s0+s1+s2+s3+s4+s5+s6+s7; double dt=now_s()-t0; printf("CPU read after CPU rewrite s=%.4f bw=%.2f GB/s sum_ok=%d\n",dt,BYTES/dt/1e9,(s==(double)N*9.0)); CK(hipFree(mg)); return 0; }
