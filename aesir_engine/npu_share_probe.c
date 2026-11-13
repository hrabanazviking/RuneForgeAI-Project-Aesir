// A-093 probe: NPU memory sharing via XRT BO dma-buf export.
// Sections: S2 export->fd mmap byte-exact both ways; S2b xrtBOImport
// into a second device handle byte-exact; S8 copy-cost table.
// XRT C ABI declared locally (A-016 pattern). Runs via sudo (A-007).
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <sys/mman.h>
typedef void* xrtDeviceHandle; typedef void* xrtBOHandle;
typedef int xrtMemoryGroup; typedef int xrtExportHandle;
enum xclBOSyncDirection { TO_DEV=0, FROM_DEV=1 };
extern xrtDeviceHandle xrtDeviceOpen(int i);
extern int xrtDeviceClose(xrtDeviceHandle h);
extern xrtBOHandle xrtBOAlloc(xrtDeviceHandle d, size_t s, int f, xrtMemoryGroup g);
extern int xrtBOFree(xrtBOHandle bo);
extern void* xrtBOMap(xrtBOHandle bo);
extern int xrtBOSync(xrtBOHandle bo, enum xclBOSyncDirection dir, size_t s, size_t o);
extern int xrtBOWrite(xrtBOHandle bo, const void* src, size_t s, size_t o);
extern int xrtBORead(xrtBOHandle bo, void* dst, size_t s, size_t o);
extern xrtExportHandle xrtBOExport(xrtBOHandle bo);
extern xrtBOHandle xrtBOImport(xrtDeviceHandle d, xrtExportHandle fd);
static uint8_t pat(size_t i, unsigned seed){ return (uint8_t)(((i*131u+seed)&0xffu)); }
static size_t badpat(const uint8_t* p, size_t n, unsigned seed){ size_t b=0; for(size_t i=0;i<n;i++) if(p[i]!=pat(i,seed)) b++; return b; }
static double now_s(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec*1e-9; }
static int cmpd(const void* a, const void* b){ double x=*(const double*)a, y=*(const double*)b; return (x>y)-(x<y); }
int main(void){
  const size_t SZ=65536;
  xrtDeviceHandle dev=xrtDeviceOpen(0);
  printf("S0 device=%p\n", dev); fflush(stdout);
  if(!dev){ printf("RESULT OPEN_FAIL\n"); return 3; }
  xrtBOHandle bo=xrtBOAlloc(dev, SZ, (2<<24), (xrtMemoryGroup)0);
  printf("S0 bo=%p\n", bo); fflush(stdout);
  if(!bo){ printf("RESULT ALLOC_FAIL\n"); return 4; }
  { xrtBOHandle b1=xrtBOAlloc(dev, 4096, (1<<24), (xrtMemoryGroup)0);
    xrtExportHandle f1=b1?xrtBOExport(b1):-1;
    printf("S1 type1_export_fd=%d (type1 export unsupported on amdxdna: PRIME_HANDLE_TO_FD EOPNOTSUPP, run1 log)\n", (int)f1);
    if(f1>=0) close(f1); if(b1) xrtBOFree(b1); }
  uint8_t* m=(uint8_t*)xrtBOMap(bo);
  if(!m){ printf("RESULT MAP_FAIL\n"); return 5; }
  for(size_t i=0;i<SZ;i++) m[i]=pat(i,7u);
  int s1=xrtBOSync(bo, TO_DEV, SZ, 0);
  // S2: export dma-buf, mmap the fd as CPU consumer
  xrtExportHandle fd=xrtBOExport(bo);
  printf("S2 export_fd=%d errno=%d syncTO=%d\n", (int)fd, errno, s1); fflush(stdout);
  int s2ok=0, s2bok=0;
  if(fd>=0){
    uint8_t* fm=(uint8_t*)mmap(NULL, SZ, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    printf("S2 fd_mmap=%p errno=%d\n", (void*)fm, errno); fflush(stdout);
    if(fm!=MAP_FAILED){
      size_t bad=badpat(fm, SZ, 7u);
      printf("S2 fd_read mismatches=%zu\n", bad);
      s2ok = (bad==0);
      for(size_t i=0;i<SZ;i++) fm[i]=pat(i,99u);
      msync(fm, SZ, MS_SYNC);
      int s2=xrtBOSync(bo, FROM_DEV, SZ, 0);
      size_t bad2=badpat(m, SZ, 99u);
      printf("S2 fd_write->syncFROM(%d)->bomap mismatches=%zu\n", s2, bad2);
      s2bok = (s2==0 && bad2==0);
      munmap(fm, SZ);
    }
    // S2b: import into second handle
    xrtDeviceHandle dev2=xrtDeviceOpen(0);
    xrtBOHandle bo2 = dev2 ? xrtBOImport(dev2, fd) : NULL;
    printf("S2b import_bo=%p dev2=%p\n", bo2, dev2); fflush(stdout);
    int s2cok=0;
    if(bo2){
      int si=xrtBOSync(bo2, FROM_DEV, SZ, 0);
      uint8_t* m2=(uint8_t*)xrtBOMap(bo2);
      size_t bad3 = m2 ? badpat(m2, SZ, 99u) : SZ;
      printf("S2b import syncFROM=%d mismatches=%zu\n", si, bad3);
      s2cok = (m2 && bad3==0);
      xrtBOFree(bo2);
    }
    printf("S2b RESULT %s\n", s2cok?"IMPORT_BYTE_EXACT":"IMPORT_FAIL");
    if(dev2) xrtDeviceClose(dev2);
    close(fd);
  }
  printf("S2 RESULT %s fwd=%d rev=%d\n", (s2ok&&s2bok)?"DMABUF_BYTE_EXACT":"DMABUF_FAIL", s2ok, s2bok);
  // S8: copy-cost table, median of 5, sizes 64KiB/1MiB/16MiB
  const size_t sizes[3]={65536, 1048576, 16777216};
  uint8_t* dst=(uint8_t*)malloc(sizes[2]);
  for(int si=0; si<3; si++){
    size_t n=sizes[si];
    xrtBOHandle b2=xrtBOAlloc(dev, n, (2<<24), (xrtMemoryGroup)0);
    if(!b2){ printf("S8 size=%zu ALLOC_FAIL\n", n); continue; }
    uint8_t* mm=(uint8_t*)xrtBOMap(b2);
    for(size_t i=0;i<n;i++) mm[i]=pat(i,7u);
    xrtBOSync(b2, TO_DEV, n, 0);
    double tr[5], tm[5];
    for(int r=0;r<5;r++){ double a=now_s(); xrtBORead(b2, dst, n, 0); tr[r]=now_s()-a; }
    for(int r=0;r<5;r++){ double a=now_s(); memcpy(dst, mm, n); tm[r]=now_s()-a; }
    qsort(tr,5,sizeof(double),cmpd); qsort(tm,5,sizeof(double),cmpd);
    printf("S8 size=%zu boread_med_s=%.6f boread_MBps=%.1f mapcpy_med_s=%.6f mapcpy_MBps=%.1f zerocopy_map_read=direct(no copy)\n",
      n, tr[2], n/tr[2]/1048576.0, tm[2], n/tm[2]/1048576.0);
    fflush(stdout);
    xrtBOFree(b2);
  }
  free(dst);
  xrtBOFree(bo); xrtDeviceClose(dev);
  printf("S2 FINAL %s\n", (s2ok&&s2bok)?"PASS":"FAIL");
  return (s2ok&&s2bok)?0:6;
}
