/* Original isolated host oracle. All driver replies are mocked,never physical. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include "hailo_ioctl_common.h"
static long (*actual)(long,...);
static long driver=-1,addresses[2];
static int allocations,maps,unmaps,creates,releases,closed;
static const char *stage(void){const char *s=getenv("AESIR_SESSION_STAGE");return s?s:"none";}
static int is(const char *s){return !strcmp(stage(),s);}
static int close_is(const char *s){const char *c=getenv("AESIR_SESSION_CLOSE");return c&&!strcmp(c,s);}
static void event(const char *op,long a,long b){
 const char *path=getenv("AESIR_SESSION_LOG");if(!path)return;FILE *f=fopen(path,"a");if(!f)abort();
 fprintf(f,"{\"op\":\"%s\",\"a\":%ld,\"b\":%ld,\"context_closed\":%d}\n",op,a,b,closed);if(fclose(f))abort();
}
static long fail(const char *op){event(op,0,0);errno=EIO;return -1;}
long syscall(long nr,...){
 va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long),d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
 if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
 const char *node=getenv("AESIR_SESSION_NODE");
 if(nr==SYS_openat&&node&&!strcmp((char *)b,node)){
  event("driver_open_attempt",0,0);if(is("open"))return fail("open_error");
  driver=actual(SYS_openat,AT_FDCWD,"/dev/null",O_RDWR|O_CLOEXEC,0,0,0);event("driver_opened",driver,0);return driver;
 }
 if(nr==SYS_close&&a==driver&&driver>=0){
  event("driver_close_attempt",a,0);if(close_is("before"))return fail("close_error_before");
  long rc=actual(nr,a,b,c,d,e,f);driver=-1;closed=1;event("driver_closed",a,rc);
  if(close_is("after"))return fail("close_error_after");
  return rc;
 }
 if(nr==SYS_mmap&&driver>=0&&b==getpagesize()&&c==(PROT_READ|PROT_WRITE)&&d==(MAP_PRIVATE|MAP_ANONYMOUS)&&e==-1&&allocations<2){
  int i=++allocations;event("owner_alloc_attempt",i,b);
  if((i==1&&is("allocate1"))||(i==2&&is("allocate2")))return fail("allocation_error");
  long rc=actual(nr,a,b,c,d,e,f);if(rc!=-1)addresses[i-1]=rc;event("owner_allocated",rc,b);return rc;
 }
 if(nr==SYS_munmap&&(a==addresses[0]||a==addresses[1])&&a){
  event("owner_release_attempt",a,b);if(!closed&&getenv("AESIR_SESSION_REQUIRE_RETENTION"))abort();
  long rc=actual(nr,a,b,c,d,e,f);event("owner_released",a,rc);if(a==addresses[0])addresses[0]=0;else addresses[1]=0;return rc;
 }
 if(nr==SYS_ioctl&&a==driver&&driver>=0){
  event("mock_ioctl",b,0);
  if(b==(long)HAILO_QUERY_DRIVER_INFO){struct hailo_driver_info *p=(void *)c;memset(p,0,sizeof(*p));p->major_version=is("identity")?4:5;p->minor_version=3;return 0;}
  if(b==(long)HAILO_QUERY_DEVICE_PROPERTIES){struct hailo_device_properties *p=(void *)c;memset(p,0,sizeof(*p));p->desc_max_page_size=4096;p->board_type=2;p->dma_type=0;p->dma_engines_count=1;p->is_fw_loaded=true;return 0;}
  if(b==(long)HAILO_DESC_LIST_CREATE){int i=++creates;event("descriptor_create",i,0);if((i==1&&is("desc_create1"))||(i==2&&is("desc_create2")))return fail("descriptor_create_error");struct hailo_desc_list_create_params *p=(void *)c;if(p->desc_count!=65536||p->desc_page_size!=512||!p->is_circular)abort();p->desc_handle=100+i;p->dma_address=4096*i;return 0;}
  if(b==(long)HAILO_DESC_LIST_RELEASE){int i=++releases;event("descriptor_release",i,0);if((i==1&&is("desc1"))||(i==2&&is("desc2")))return fail("descriptor_release_error");return 0;}
  if(b==(long)HAILO_SOC_CONNECT){event("connect_attempt",0,0);if(is("connect"))return fail("connect_error");struct hailo_soc_connect_params *p=(void *)c;if(p->port_number!=12133||p->input_desc_handle!=101||p->output_desc_handle!=102)abort();p->input_channel_index=0;p->output_channel_index=16;return 0;}
  if(b==(long)HAILO_SOC_CLOSE){event("channel_close",0,0);if(is("channel"))return fail("channel_close_error");return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_MAP){int i=++maps;struct hailo_vdma_buffer_params *p=(void *)c;if(i>2||p->size!=2068||p->type!=0||p->direction!=(enum hailo_dma_data_direction)i||p->addr_or_fd!=(uintptr_t)addresses[i-1])abort();event("map_attempt",p->addr_or_fd,p->size);if((i==1&&is("map1"))||(i==2&&is("map2")))return fail("map_error_before");p->mapped_handle=i;
   if((i==1&&is("map_after1"))||(i==2&&is("map_after2")))return fail("map_error_after");
   if((i==1&&is("bad_reply1"))||(i==2&&is("bad_reply2")))p->size++;
   return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_UNMAP){int i=++unmaps;struct hailo_vdma_buffer_params *p=(void *)c;if(p->size!=2068||p->type!=0||p->direction<1||p->direction>2||p->addr_or_fd!=(uintptr_t)addresses[p->direction-1])abort();event("unmap_attempt",i,0);if((i==1&&is("unmap1"))||(i==2&&is("unmap2")))return fail("unmap_error");return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_SYNC){struct hailo_vdma_buffer_sync_params *p=(void *)c;if(p->handle<1||p->handle>2||p->offset||p->count!=2068||p->sync_type>1)abort();event("mock_sync",0,0);return 0;}
  event("forbidden_mock_ioctl",b,0);abort();
 }
 return actual(nr,a,b,c,d,e,f);
}
