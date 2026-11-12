/* A-015 C probe: vec_add dispatch through the A-014 buffer shim ABI. */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
int aesir_vk_buffer_available(void);
int aesir_vk_dispatch_available(void);
int aesir_vk_buffer_device_info(char*, int, uint32_t*, uint32_t*, uint32_t*, uint32_t*, uint32_t*);
int aesir_vk_buffer_alloc(uint64_t, uint64_t*, uint64_t*, uint64_t*, uint32_t*);
int aesir_vk_buffer_map(uint64_t, uint64_t*);
int aesir_vk_buffer_unmap(uint64_t);
int aesir_vk_buffer_free(uint64_t);
int aesir_vk_buffer_vec_add(uint64_t, uint64_t, uint64_t, uint32_t);
static float fa(uint32_t i){ return (float)((i*37u+11u)%997u) * 0.5f - 100.0f; }
static float fb(uint32_t i){ return (float)((i*91u+7u)%613u) * 0.25f + 3.0f; }
int main(void){
    printf("buffer_available=%d dispatch_available=%d\n", aesir_vk_buffer_available(), aesir_vk_dispatch_available());
    char name[256]={0}; uint32_t v=0,d=0,api=0,t=0,q=0;
    int rc=aesir_vk_buffer_device_info(name,256,&v,&d,&api,&t,&q);
    printf("device rc=%d name=%s vendor=0x%x type=%u qf=%u\n", rc, name, v, t, q);
    if (rc!=0 || v!=0x1002u || strstr(name,"RADV")==NULL || strstr(name,"llvmpipe")!=NULL){ printf("RESULT FAIL identity\n"); return 1; }
    uint32_t sizes[]={1,7,255,256,257,1000,4097,65537};
    int fails=0;
    for (unsigned s=0;s<sizeof(sizes)/sizeof(sizes[0]);s++){
        uint32_t n=sizes[s]; uint64_t bytes=(uint64_t)n*4;
        uint64_t ia=0,ib=0,ic=0,al=0,an=0; uint32_t ti=0;
        if(aesir_vk_buffer_alloc(bytes,&ia,&al,&an,&ti)!=0){printf("n=%u alloc a FAIL\n",n);fails++;continue;}
        if(aesir_vk_buffer_alloc(bytes,&ib,&al,&an,&ti)!=0){printf("n=%u alloc b FAIL\n",n);fails++;continue;}
        if(aesir_vk_buffer_alloc(bytes,&ic,&al,&an,&ti)!=0){printf("n=%u alloc c FAIL\n",n);fails++;continue;}
        uint64_t pa=0,pb=0,pc=0;
        aesir_vk_buffer_map(ia,&pa); aesir_vk_buffer_map(ib,&pb); aesir_vk_buffer_map(ic,&pc);
        float *A=(float*)(uintptr_t)pa, *B=(float*)(uintptr_t)pb, *C=(float*)(uintptr_t)pc;
        for(uint32_t i=0;i<n;i++){A[i]=fa(i);B[i]=fb(i);C[i]=-9999.0f;}
        aesir_vk_buffer_unmap(ia); aesir_vk_buffer_unmap(ib); aesir_vk_buffer_unmap(ic);
        rc=aesir_vk_buffer_vec_add(ia,ib,ic,n);
        if(rc!=0){printf("n=%u dispatch rc=%d FAIL\n",n,rc);fails++;}
        else {
            aesir_vk_buffer_map(ic,&pc); C=(float*)(uintptr_t)pc;
            uint32_t bad=0; for(uint32_t i=0;i<n;i++){ float e=fa(i)+fb(i); if(memcmp(&C[i],&e,4)!=0){ if(bad<3) printf("n=%u i=%u got %f want %f\n",n,i,C[i],e); bad++; } }
            aesir_vk_buffer_unmap(ic);
            printf("n=%u dispatch ok, mismatches=%u %s\n", n, bad, bad?"FAIL":"BYTE-EXACT");
            if(bad) fails++;
        }
        aesir_vk_buffer_free(ia); aesir_vk_buffer_free(ib); aesir_vk_buffer_free(ic);
    }
    printf("RESULT %s fails=%d\n", fails?"FAIL":"PASS", fails);
    return fails?1:0;
}
