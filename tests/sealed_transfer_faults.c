/* Original host-only I/O seams and independent actual-metadata kernel oracle. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <linux/memfd.h>
#include <linux/stat.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
_Static_assert(MFD_CLOEXEC==1&&MFD_ALLOW_SEALING==2,"create flags");
_Static_assert(F_ADD_SEALS==1033&&F_GET_SEALS==1034,"seal controls");
_Static_assert((F_SEAL_SEAL|F_SEAL_SHRINK|F_SEAL_GROW|F_SEAL_WRITE)==15,"seal mask");
static long (*actual)(long,...);
static int (*real_close)(int);
static long metadata=-1,program=-1;
static int creations,active,reads,writes,stats,gets;
static const char *mode(void){const char *s=getenv("AESIR_TRANSFER_FAULT");return s?s:"none";}
static int is(const char *s){return !strcmp(mode(),s);}
static void record(const char *op,long fd,long count,long offset){
 const char *path=getenv("AESIR_TRANSFER_LOG");if(!path)return;FILE *out=fopen(path,"a");if(!out)abort();
 fprintf(out,"{\"op\":\"%s\",\"fd\":%ld,\"count\":%ld,\"offset\":%ld,\"active\":%d}\n",op,fd,count,offset,active);if(fclose(out))abort();
}
static void kernel_oracle(long fd){
 const char *hex=getenv("AESIR_TRANSFER_EXPECTED_HEX");if(!hex)return;
 if(strlen(hex)!=4136)abort();
 unsigned char bytes[2068],expected[2068];
 for(size_t i=0;i<2068;i++){unsigned x;if(sscanf(hex+2*i,"%2x",&x)!=1)abort();expected[i]=(unsigned char)x;}
 if(actual(SYS_pread64,fd,bytes,2068,0,0,0)!=2068||memcmp(bytes,expected,2068))abort();
 if(actual(SYS_fcntl,fd,F_GET_SEALS,0,0,0,0)!=15||actual(SYS_fcntl,fd,F_GETFD,0,0,0,0)!=1)abort();
 if(actual(SYS_pwrite64,fd,bytes,1,0,0,0)!=-1||errno!=EPERM)abort();
 if(ftruncate((int)fd,2069)!=-1||errno!=EPERM)abort();
 if(ftruncate((int)fd,2067)!=-1||errno!=EPERM)abort();
 void *p=mmap(NULL,2068,PROT_READ|PROT_WRITE,MAP_SHARED,(int)fd,0);
 if(p!=MAP_FAILED||errno!=EPERM)abort();
 record("kernel_oracle",fd,2068,4);
}
int close(int fd){
 if(!real_close)real_close=dlsym(RTLD_NEXT,"close");
 int meta=fd==metadata&&metadata>=0,prog=fd==program&&program>=0;
 if(meta||prog)record(meta?"metadata_close":"program_close",fd,0,0);
 int inject=active&&(meta||((is("close_both_before")||is("close_both_after"))&&prog));
 if(meta)metadata=-1;
 if(prog)program=-1;
 if(inject&&(is("close_before")||is("close_both_before"))){errno=EIO;return -1;}
 int rc=real_close(fd);
 if(inject&&(is("close_after")||is("close_both_after"))){errno=EIO;return -1;}
 return rc;
}
long syscall(long nr,...){
 va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long),d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);
 if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
 if(nr==SYS_memfd_create&&!strcmp((char *)a,"aesir-program-payload")){program=actual(nr,a,b,c,d,e,f);return program;}
 if(nr==SYS_memfd_create&&!strcmp((char *)a,"aesir-transfer-metadata")){
  active=++creations==1;reads=writes=stats=gets=0;record("create",-1,b,0);
  if(active&&is("create")){errno=ENOMEM;return -1;}
  if(active&&is("large_fd"))return 2147483648L;
  metadata=actual(nr,a,b,c,d,e,f);record("created",metadata,b,0);return metadata;
 }
 if(a!=metadata||metadata<0)return actual(nr,a,b,c,d,e,f);
 if(nr==SYS_statx){
  stats++;record("stat",a,stats,0);if(active&&is("stat_error")){errno=EIO;return -1;}
  long rc=actual(nr,a,b,c,d,e,f);if(!rc&&active&&(is("stat_extent")||(is("stat_extent_late")&&stats>2)))((struct statx *)e)->stx_size++;return rc;
 }
 if(nr==SYS_pwrite64||nr==SYS_pread64){
  int writing=nr==SYS_pwrite64;int n=writing?++writes:++reads;record(writing?"write":"read",a,c,d);
  if(active){
   const char *prefix=writing?"write":"read";char label[64];
#define MODE(suffix) (snprintf(label,sizeof(label),"%s_%s",prefix,suffix),!strcmp(mode(),label))
   if(MODE("eintr")||(MODE("eintr_once")&&n==1)){errno=EINTR;return -1;}
   if(MODE("error")){errno=EIO;return -1;}
   if(MODE("zero"))return 0;
   if(MODE("extra"))return c+1;
   if(MODE("short")&&c>3)c=3;
#undef MODE
  }
  long rc=actual(nr,a,b,c,d,e,f);if(active&&!writing&&rc>0&&(is("read_corrupt")||(is("read_corrupt_late")&&reads>1)))((unsigned char *)b)[0]^=1;return rc;
 }
 if(nr==SYS_fcntl){
  record("fcntl",a,b,c);
  if(b==F_ADD_SEALS&&active&&is("seal")){errno=EIO;return -1;}
  if(b==F_GET_SEALS){gets++;if(active&&(is("get_seals")||(is("get_seals_late")&&gets>1))){errno=EIO;return -1;}if(active&&is("missing_seals"))return 0;}
  if(b==F_GETFD&&active&&is("get_flags")){errno=EIO;return -1;}
  if(b==F_GETFD&&active&&is("missing_flags"))return 0;
  long rc=actual(nr,a,b,c,d,e,f);
  if(b==F_ADD_SEALS&&rc==0)kernel_oracle(a);
  if(b==F_ADD_SEALS&&active&&is("seal_after")){errno=EIO;return -1;}return rc;
 }
 return actual(nr,a,b,c,d,e,f);
}
