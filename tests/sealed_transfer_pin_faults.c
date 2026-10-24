/* Original test-only kernel/driver lifetime oracle. Never physical evidence. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <unistd.h>
#include "hailo_ioctl_common.h"
static long (*actual)(long,...);
static int (*actual_close)(int);
static int (*actual_page)(void);
static long sealed[2]={-1,-1},driver=-1,view[2],extent[2],logical[2];
static int maps,views,unmaps,active[2],closed;
static const char *mode(void){const char *p=getenv("AESIR_GROUP_PIN_FAULT");return p?p:"none";}
static int is(const char *s){return !strcmp(mode(),s);}
static void log_event(const char *op,long a,long b,long c){
 const char *path=getenv("AESIR_GROUP_PIN_LOG");if(!path)return;
 FILE *f=fopen(path,"a");if(!f)abort();
 fprintf(f,"{\"op\":\"%s\",\"a\":%ld,\"b\":%ld,\"c\":%ld,\"active0\":%d,\"active1\":%d}\n",op,a,b,c,active[0],active[1]);if(fclose(f))abort();
}
static int selected(const char *prefix,int i){char key[80];snprintf(key,sizeof(key),"%s%d",prefix,i);return is(key);}
static void kernel_view(int index,long addr,long bytes){
 int fd=(int)sealed[index];
 if(fd<0||fcntl(fd,F_GET_SEALS)!=15||(fcntl(fd,F_GETFD)&FD_CLOEXEC)==0)abort();
 unsigned char disk[4096];long done=0;
 while(done<bytes){size_t n=(size_t)(bytes-done);if(n>sizeof(disk))n=sizeof(disk);ssize_t got=pread(fd,disk,n,done);if(got!=(ssize_t)n||memcmp(disk,(void *)(addr+done),n))abort();done+=got;}
 FILE *f=fopen("/proc/self/maps","r");if(!f)abort();char line[512];int found=0;
 while(fgets(line,sizeof(line),f)){unsigned long lo,hi;char perm[5];if(sscanf(line,"%lx-%lx %4s",&lo,&hi,perm)==3&&(unsigned long)addr>=lo&&(unsigned long)(addr+bytes)<=hi){if(strcmp(perm,"r--p"))abort();found=1;break;}}
 if(fclose(f)||!found){abort();}
 log_event("actual_kernel_view",index,bytes,15);
}
int getpagesize(void){if(!actual_page)actual_page=dlsym(RTLD_NEXT,"getpagesize");if(is("page_size")&&sealed[0]>=0&&sealed[1]>=0)return 0;return actual_page();}
int close(int fd){
 if(!actual_close)actual_close=dlsym(RTLD_NEXT,"close");
 for(int i=0;i<2;i++)if(fd==sealed[i]&&fd>=0){
  if(driver>=0&&!closed) {log_event("unsafe_sealed_close",i,fd,0);abort();}
  log_event("sealed_close_attempt",i,fd,0);if(selected("sealed_close_before",i)){errno=EIO;return -1;}
  int rc=actual_close(fd);sealed[i]=-1;log_event("sealed_closed",i,fd,rc);if(selected("sealed_close_after",i)){errno=EIO;return -1;}return rc;
 }
 return actual_close(fd);
}
long syscall(long nr,...){
 va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long),d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
 if(nr==SYS_memfd_create&&(!strcmp((char *)a,"aesir-program-payload")||!strcmp((char *)a,"aesir-transfer-metadata"))){int i=!strcmp((char *)a,"aesir-program-payload")?1:0;long rc=actual(nr,a,b,c,d,e,f);sealed[i]=rc;log_event("sealed_created",i,rc,0);return rc;}
 if(nr==SYS_openat&&getenv("AESIR_GROUP_PIN_NODE")&&!strcmp((char *)b,getenv("AESIR_GROUP_PIN_NODE"))){
  log_event("driver_open_attempt",0,0,0);if(is("open")){errno=EACCES;return -1;}driver=actual(SYS_openat,AT_FDCWD,"/dev/null",O_RDWR|O_CLOEXEC,0,0,0);closed=0;log_event("driver_opened",driver,0,0);return driver;
 }
 if(nr==SYS_close&&a==driver&&driver>=0){
  log_event("driver_close_attempt",a,0,0);if(is("close_before")||is("identity_close_before")||is("unmap_close_before")){errno=EIO;return -1;}
  long rc=actual(nr,a,b,c,d,e,f);closed=1;driver=-1;active[0]=active[1]=0;log_event("driver_closed",a,rc,0);if(is("close_after")||is("identity_close_after")||is("unmap_close_after")){errno=EIO;return -1;}return rc;
 }
 if(nr==SYS_mmap&&(e==sealed[0]||e==sealed[1])&&e>=0){
  int i=e==sealed[0]?0:1;log_event("view_attempt",i,b,c);if(selected("mmap",i)){errno=ENOMEM;return -1;}
  if(c!=1||d!=2||f!=0){abort();}
  long rc=actual(nr,a,b,c,d,e,f);if(rc!=-1){view[i]=rc;extent[i]=b;logical[i]=lseek((int)e,0,SEEK_END);views++;kernel_view(i,rc,logical[i]);}log_event("view_created",i,rc,b);return rc;
 }
 if(nr==SYS_munmap){for(int i=0;i<2;i++)if(view[i]&&a==view[i]){
  log_event("view_release_attempt",i,a,b);if((driver>=0&&!closed)||b!=extent[i]){log_event("unsafe_release",i,a,b);abort();}
  if(selected("munmap_before",i)){errno=EIO;return -1;}long rc=actual(nr,a,b,c,d,e,f);view[i]=0;log_event("view_released",i,a,rc);if(selected("munmap_after",i)){errno=EIO;return -1;}return rc;
 }}
 if(nr==SYS_ioctl&&a==driver&&driver>=0){
  if(b==(long)HAILO_QUERY_DRIVER_INFO){struct hailo_driver_info *p=(void *)c;memset(p,0,sizeof(*p));p->major_version=(is("identity")||is("identity_close_before")||is("identity_close_after"))?4:5;p->minor_version=3;log_event("identity",p->major_version,0,0);return 0;}
  if(b==(long)HAILO_QUERY_DEVICE_PROPERTIES){struct hailo_device_properties *p=(void *)c;memset(p,0,sizeof(*p));p->desc_max_page_size=512;p->board_type=2;p->dma_type=0;p->dma_engines_count=1;p->is_fw_loaded=true;log_event("properties",0,0,0);return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_MAP){
   struct hailo_vdma_buffer_params *p=(void *)c;int i=maps++;if(i>=2||views!=2||p->direction!=1||p->type!=0||p->addr_or_fd!=(uintptr_t)view[i]||p->size!=(size_t)logical[i])abort();log_event("map_attempt",i,p->addr_or_fd,p->size);
   if(selected("map_before",i)){errno=EIO;return -1;}active[i]=1;p->mapped_handle=(uintptr_t)i;log_event("map_effect",i,p->addr_or_fd,p->size);
   if(selected("map_after",i)){errno=EIO;return -1;}if(selected("bad_tuple",i))p->size++;if(selected("bad_handle",i))p->mapped_handle=(uintptr_t)-1;return 0;
  }
  if(b==(long)HAILO_VDMA_BUFFER_UNMAP){
   struct hailo_vdma_buffer_params *p=(void *)c;int i=p->addr_or_fd==(uintptr_t)view[1]?1:0;
   if(p->addr_or_fd!=(uintptr_t)view[i]||p->size!=(size_t)logical[i]||p->direction!=1||p->type!=0||!active[i]){abort();}
   unmaps++;log_event("unmap_attempt",i,p->addr_or_fd,p->size);
   if(selected("unmap_before",i)||is("unmap_close_before")||is("unmap_close_after")){errno=EIO;return -1;}active[i]=0;log_event("unmap_effect",i,0,0);if(selected("unmap_after",i)){errno=EIO;return -1;}return 0;
  }
  log_event("forbidden_ioctl",a,b,0);abort();
 }
 return actual(nr,a,b,c,d,e,f);
}
