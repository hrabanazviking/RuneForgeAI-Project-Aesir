// A-016 probe v3: native XRT C API BO round trip on the NPU device.
// No XRT headers installed (no -dev package); stable xrt.h C ABI declared
// locally, linked directly against versioned libxrt_coreutil.so.2.
// BO type is encoded in bits 24+ of the flags argument of xrtBOAlloc:
// type 1 (1<<24) and type 2 (2<<24) allocate on the xdna shim; type 0
// fails with "unsupported buffer type: none flag".
// Cross-verified paths (no destructive memset between syncs):
//  A) map-write -> sync TO_DEVICE -> xrtBORead  == pattern
//  B) xrtBOWrite -> sync FROM_DEVICE -> map-read == pattern
//  C) xrtBOWrite -> xrtBORead == pattern
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
typedef void* xrtDeviceHandle; typedef void* xrtBOHandle; typedef int xrtMemoryGroup;
enum xclBOSyncDirection { XCL_BO_SYNC_BO_TO_DEVICE=0, XCL_BO_SYNC_BO_FROM_DEVICE=1 };
extern xrtDeviceHandle xrtDeviceOpen(int deviceIndex);
extern int xrtDeviceClose(xrtDeviceHandle handle);
extern xrtBOHandle xrtBOAlloc(xrtDeviceHandle device, size_t size, int flags, xrtMemoryGroup grp);
extern int xrtBOFree(xrtBOHandle bo);
extern void* xrtBOMap(xrtBOHandle bo);
extern int xrtBOSync(xrtBOHandle bo, enum xclBOSyncDirection dir, size_t size, size_t offset);
extern int xrtBOWrite(xrtBOHandle bo, const void* src, size_t size, size_t offset);
extern int xrtBORead(xrtBOHandle bo, void* dst, size_t size, size_t offset);
extern size_t xrtBOSize(xrtBOHandle bo);
static size_t cmpu8(const uint8_t* a, const uint8_t* b, size_t n){ size_t bad=0; for(size_t i=0;i<n;i++) if(a[i]!=b[i]) bad++; return bad; }
int main(int argc, char** argv){
  int flags = argc>1 ? atoi(argv[1]) : (1<<24);
  const size_t SZ=4096;
  uint8_t ref[4096]; uint8_t out[4096];
  for(size_t i=0;i<SZ;i++) ref[i]=(uint8_t)((i*131u+7u)&0xffu);
  xrtDeviceHandle dev = xrtDeviceOpen(0);
  printf("xrtDeviceOpen(0)=%p flags=0x%x\n", dev, flags); fflush(stdout);
  if(!dev){ printf("RESULT OPEN_FAIL\n"); return 3; }
  xrtBOHandle bo = xrtBOAlloc(dev, SZ, flags, (xrtMemoryGroup)0);
  printf("xrtBOAlloc=%p size=%zu\n", bo, bo?xrtBOSize(bo):0); fflush(stdout);
  if(!bo){ printf("RESULT ALLOC_FAIL\n"); xrtDeviceClose(dev); return 4; }
  uint8_t* b=(uint8_t*)xrtBOMap(bo);
  printf("xrtBOMap=%p\n", (void*)b); fflush(stdout);
  if(!b){ printf("RESULT MAP_FAIL\n"); xrtBOFree(bo); xrtDeviceClose(dev); return 5; }
  // Path A: map-write -> sync TO -> API read
  memcpy(b, ref, SZ);
  int s1=xrtBOSync(bo, XCL_BO_SYNC_BO_TO_DEVICE, SZ, 0);
  memset(out,0,SZ); int rA=xrtBORead(bo, out, SZ, 0); size_t badA=cmpu8(out,ref,SZ);
  printf("A map->syncTO(%d)->read(%d) mismatches=%zu\n", s1, rA, badA);
  // Path B: API write (inverted pattern) -> sync FROM -> map read
  uint8_t ref2[4096]; for(size_t i=0;i<SZ;i++) ref2[i]=(uint8_t)(ref[i]^0xa5u);
  int wB=xrtBOWrite(bo, ref2, SZ, 0);
  int s2=xrtBOSync(bo, XCL_BO_SYNC_BO_FROM_DEVICE, SZ, 0);
  size_t badB=cmpu8(b,ref2,SZ);
  printf("B write(%d)->syncFROM(%d)->map mismatches=%zu\n", wB, s2, badB);
  // Path C: API write -> API read
  int wC=xrtBOWrite(bo, ref, SZ, 0); memset(out,0,SZ); int rC=xrtBORead(bo, out, SZ, 0); size_t badC=cmpu8(out,ref,SZ);
  printf("C write(%d)->read(%d) mismatches=%zu\n", wC, rC, badC);
  xrtBOFree(bo); xrtDeviceClose(dev);
  int ok = (s1==0&&rA==0&&badA==0&&wB==0&&s2==0&&badB==0&&wC==0&&rC==0&&badC==0);
  printf(ok?"RESULT BYTE_EXACT_ROUND_TRIP\n":"RESULT FAIL\n");
  return ok?0:6;
}
