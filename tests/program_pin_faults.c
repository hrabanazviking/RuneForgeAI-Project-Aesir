/* Original test-only isolated host state/failure seams;never a device result. */
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
#include <sys/syscall.h>
#include "hailo_ioctl_common.h"
static long (*actual)(long,...);
static int (*actual_close)(int);
static int (*actual_page)(void);
static long sealed=-1,driver=-1,view=0;
static int active;
static const char *mode(void){const char *m=getenv("AESIR_PIN_FAULT");return m?m:"none";}
static int is(const char *m){return !strcmp(mode(),m);}
static void log_event(const char *op,long a,long b,long c){
 const char *path=getenv("AESIR_PIN_LOG");if(!path)return;
 FILE *f=fopen(path,"a");if(!f)abort();
 fprintf(f,"{\"op\":\"%s\",\"a\":%ld,\"b\":%ld,\"c\":%ld,\"map_active\":%d}\n",op,a,b,c,active);
 if(fclose(f))abort();
}
int getpagesize(void){
 if(!actual_page)actual_page=dlsym(RTLD_NEXT,"getpagesize");
 if(sealed>=0&&is("page_size"))return 0;
 return actual_page();
}
int close(int fd){
 if(!actual_close)actual_close=dlsym(RTLD_NEXT,"close");
 if(fd==driver&&driver>=0){
  log_event("driver_close_attempt",fd,0,0);
  if(is("close_before")){errno=EIO;return -1;}
  int rc=actual_close(fd);driver=-1;active=0;log_event("driver_closed",fd,rc,0);
  if(is("close_after")){errno=EIO;return -1;}return rc;
 }
 if(fd==sealed&&sealed>=0){log_event("sealed_close",fd,0,0);sealed=-1;}
 return actual_close(fd);
}
long syscall(long nr,...){
 va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long),d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
 if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
 const char *node=getenv("AESIR_PIN_NODE");
 if(nr==SYS_close&&a==driver&&driver>=0){
  log_event("driver_close_attempt",a,0,0);
  if(is("close_before")){errno=EIO;return -1;}
  long rc=actual(nr,a,b,c,d,e,f);driver=-1;active=0;log_event("driver_closed",a,rc,0);
  if(is("close_after")){errno=EIO;return -1;}return rc;
 }
 if(nr==SYS_memfd_create&&!strcmp((char *)a,"aesir-program-payload")){
  sealed=actual(nr,a,b,c,d,e,f);log_event("sealed_created",sealed,b,0);return sealed;
 }
 if(nr==SYS_openat&&node&&!strcmp((char *)b,node)){
  log_event("driver_open_attempt",0,0,0);
  if(is("open")){errno=EACCES;return -1;}
  driver=actual(SYS_openat,AT_FDCWD,"/dev/null",O_RDWR|O_CLOEXEC,0,0,0);log_event("driver_opened",driver,0,0);return driver;
 }
 if(nr==SYS_mmap&&e==sealed&&sealed>=0){
  log_event("view_attempt",b,c,d);
  if(is("mmap")){errno=ENOMEM;return -1;}
  long rc=actual(nr,a,b,c,d,e,f);if(rc!=-1)view=rc;log_event("view_created",rc,b,0);return rc;
 }
 if(nr==SYS_munmap&&a==view&&view){
  log_event("view_release_attempt",a,b,0);
  if(active){log_event("unsafe_release",a,b,0);abort();}
  if(is("munmap_before")){errno=EIO;return -1;}
  long rc=actual(nr,a,b,c,d,e,f);view=0;log_event("view_released",a,b,rc);
  if(is("munmap_after")){errno=EIO;return -1;}return rc;
 }
 if(nr==SYS_pread64&&a==sealed&&sealed>=0&&is("backing_read")){log_event("backing_read_error",a,c,d);errno=EIO;return -1;}
 if(nr==SYS_ioctl&&a==driver&&driver>=0){
  log_event("mock_ioctl",a,b,0);
  if(b==(long)HAILO_QUERY_DRIVER_INFO){struct hailo_driver_info *p=(void *)c;memset(p,0,sizeof(*p));p->major_version=is("identity")?4:5;p->minor_version=3;return 0;}
  if(b==(long)HAILO_QUERY_DEVICE_PROPERTIES){struct hailo_device_properties *p=(void *)c;memset(p,0,sizeof(*p));p->desc_max_page_size=512;p->board_type=2;p->dma_type=0;p->dma_engines_count=1;p->is_fw_loaded=true;return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_MAP){
   struct hailo_vdma_buffer_params *p=(void *)c;
   if(p->direction!=1||p->type!=0||!p->size||active)abort();
   log_event("map_attempt",p->addr_or_fd,p->size,0);
   if(is("map_before")){errno=EIO;return -1;}
   active=1;p->mapped_handle=0;log_event("map_effect",p->addr_or_fd,p->size,0);
   if(is("map_after")){errno=EIO;return -1;}
   if(is("bad_tuple"))p->size++;
   if(is("bad_handle"))p->mapped_handle=(size_t)-1;
   return 0;
  }
  if(b==(long)HAILO_VDMA_BUFFER_UNMAP){
   if(!active)abort();
   log_event("unmap_attempt",0,0,0);
   if(is("unmap_before")){errno=EIO;return -1;}
   active=0;log_event("unmap_effect",0,0,0);
   if(is("unmap_after")){errno=EIO;return -1;}return 0;
  }
  log_event("forbidden_ioctl",a,b,0);abort();
 }
 return actual(nr,a,b,c,d,e,f);
}
