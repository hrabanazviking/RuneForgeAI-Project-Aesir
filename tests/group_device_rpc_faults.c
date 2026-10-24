/* Original typed grouped device host oracle. Extends our own grouped oracle;
 * only packed UAPI declarations come from the independently pinned header. */
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
#include <time.h>
#include <pthread.h>
#include <stdatomic.h>
#include <sys/syscall.h>
#include <sys/mman.h>
#include <unistd.h>
#include "hailo_ioctl_common.h"
static long (*actual)(long,...);
static long driver=-1,addr[2],extent[2];
static int allocations,maps,creates,releases,connected,generation,observed;
static int active_phase;
static int mapped[2],device_owned[2],launches,syncs,irqs,clock_calls,sequence;
static atomic_int pending[2],disabled;
static struct timespec base_clock;
static _Thread_local struct timespec last_virtual_clock;
static _Thread_local int have_virtual_clock;
static pthread_mutex_t lock=PTHREAD_MUTEX_INITIALIZER;
static const char *mode(void){const char *g=getenv("AESIR_GROUP_FAULT_GENERATION");if(g&&atoi(g)!=generation)return "none";const char *phase=getenv("AESIR_DEVICE_PHASE");if(phase&&*phase&&atoi(phase)!=active_phase)return "none";const char *p=getenv("AESIR_GROUP_FAULT");return p?p:"none";}
static int is(const char *s){return !strcmp(mode(),s);}
static int number(const char *name,int fallback){const char *g=getenv("AESIR_GROUP_FAULT_GENERATION");if(g&&atoi(g)!=generation&&strstr(name,"COUNT"))return fallback;const char *p=getenv(name);return p?atoi(p):fallback;}
static int close_is(const char *which){
 const char *g=getenv("AESIR_GROUP_FAULT_GENERATION");if(g&&atoi(g)!=generation)return 0;
 const char *p=getenv("AESIR_GROUP_CLOSE");return p&&!strcmp(p,which);
}
static int at(const char *prefix,int n){char key[80];snprintf(key,sizeof(key),"%s%d",prefix,n);return is(key);}
static void event(const char *op,long a,long b,long c){
 const char *p=getenv("AESIR_GROUP_LOG");if(!p)return;pthread_mutex_lock(&lock);FILE *f=fopen(p,"a");if(!f)abort();
 fprintf(f,"{\"op\":\"%s\",\"a\":%ld,\"b\":%ld,\"c\":%ld,\"generation\":%d,\"pid\":%d,\"tid\":%d}\n",op,a,b,c,generation,(int)getpid(),(int)gettid());if(fclose(f))abort();pthread_mutex_unlock(&lock);
}
static long fail(const char *op){event(op,0,0,0);errno=EIO;return -1;}
static void protection(int i,int prot){if(mprotect((void *)addr[i],(size_t)extent[i],prot))abort();event(prot==PROT_NONE?"cpu_blocked":"cpu_access",i,addr[i],extent[i]);}
static void wire(const unsigned char *data,const char *op){
 const char *p=getenv("AESIR_GROUP_LOG");if(!p)return;pthread_mutex_lock(&lock);FILE *f=fopen(p,"a");if(!f)abort();
 fprintf(f,"{\"op\":\"%s\",\"generation\":%d,\"pid\":%d,\"tid\":%d,\"hex\":\"",op,generation,(int)getpid(),(int)gettid());for(int i=0;i<2068;i++)fprintf(f,"%02x",data[i]);fprintf(f,"\"}\n");if(fclose(f))abort();pthread_mutex_unlock(&lock);
}
static int digit(char c){if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;abort();}
static void fixture(unsigned char *out,const char *prefix,uint32_t id){
 const char *g=getenv("AESIR_GROUP_FAULT_GENERATION");if(g&&atoi(g)!=generation&&!strcmp(prefix,"REPLY"))prefix="GOODREPLY";
 char name[80];snprintf(name,sizeof(name),"AESIR_DEVICE_%s%u",prefix,id);const char *text=getenv(name);
 if(!text||strlen(text)!=4136)abort();
 for(int j=0;j<2068;j++)out[j]=(unsigned char)((digit(text[j*2])<<4)|digit(text[j*2+1]));
}
/* The mock admission clock is synthetic. pthread_clockjoin_np uses the real
 * kernel clock,so translate the just-observed virtual relative budget to real
 * time. The actual thread still joins/exits;no pthread result is fabricated. */
int pthread_clockjoin_np(pthread_t thread,void **value,clockid_t clock_id,const struct timespec *deadline){
 static int (*join_actual)(pthread_t,void **,clockid_t,const struct timespec *);
 if(!join_actual)join_actual=dlsym(RTLD_NEXT,"pthread_clockjoin_np");
 if(driver<0||clock_id!=CLOCK_MONOTONIC||!have_virtual_clock)return join_actual(thread,value,clock_id,deadline);
 int64_t remaining=(int64_t)(deadline->tv_sec-last_virtual_clock.tv_sec)*1000000000LL+deadline->tv_nsec-last_virtual_clock.tv_nsec;
 if(remaining<=0||remaining>60000000000LL)abort();
 struct timespec now;if(clock_gettime(CLOCK_MONOTONIC,&now))abort();
 int64_t nanos=now.tv_nsec+remaining;struct timespec real_deadline={now.tv_sec+nanos/1000000000LL,nanos%1000000000LL};
 event("join_budget",remaining/1000000,0,0);int rc=join_actual(thread,value,clock_id,&real_deadline);event("join_result",rc,0,0);return rc;
}
static void exits(void) __attribute__((destructor));
static void exits(void){
 if(!observed){return;}
 int count=0;
 for(int i=0;i<2;i++)if(addr[i]){unsigned char v[16]={0};int present=mincore((void *)addr[i],(size_t)extent[i],v)==0;event("exit_view",i,present,extent[i]);count+=present;}
 event("exit_resources",count,driver>=0&&fcntl((int)driver,F_GETFD)>=0,0);
}
long syscall(long nr,...){
 va_list ap;va_start(ap,nr);long a=va_arg(ap,long),b=va_arg(ap,long),c=va_arg(ap,long),d=va_arg(ap,long),e=va_arg(ap,long),f=va_arg(ap,long);va_end(ap);if(!actual)actual=dlsym(RTLD_NEXT,"syscall");
 const char *node=getenv("AESIR_GROUP_NODE");
 if(nr==SYS_openat&&node&&!strcmp((char *)b,node)){
  observed=1;generation++;event("open_attempt",0,0,0);if(is("open"))return fail("open_error");
  if(driver>=0||addr[0]||addr[1]){abort();}
  have_virtual_clock=0;allocations=maps=creates=releases=connected=launches=syncs=irqs=clock_calls=sequence=0;memset(mapped,0,sizeof(mapped));memset(device_owned,0,sizeof(device_owned));pending[0]=pending[1]=disabled=0;
  driver=actual(SYS_openat,AT_FDCWD,"/dev/null",O_RDWR|O_CLOEXEC,0,0,0);event("opened",driver,0,0);return driver;
 }
 if(nr==SYS_close&&a==driver&&driver>=0){
  event("file_close_attempt",a,0,0);if(is("close_before")||close_is("before"))return fail("close_error_before");long rc=actual(nr,a,b,c,d,e,f);event("file_closed",a,rc,0);driver=-1;pending[0]=pending[1]=0;disabled=1;if(is("close_after")||close_is("after"))return fail("close_error_after");return rc;
 }
 if(nr==SYS_clock_gettime&&driver>=0&&a==CLOCK_MONOTONIC){
  int n=++clock_calls;long rc=actual(nr,a,b,c,d,e,f);if(rc)return rc;if(n==1)base_clock=*(struct timespec *)b;last_virtual_clock=*(struct timespec *)b;have_virtual_clock=1;
  if(at("clock_error",n))return fail("clock_error");
  if(is("wait_stall")&&disabled){event("clock_grace",n,0,0);return 0;}
  long ms=n-1;
  const char *m=mode();if(!strncmp(m,"late",4)&&n>=atoi(m+4))ms+=1000;
  if(!strncmp(m,"back",4)&&n>=atoi(m+4))ms=-10;
  int64_t total_ms=(int64_t)base_clock.tv_sec*1000+base_clock.tv_nsec/1000000+ms;
  struct timespec *t=(void *)b;t->tv_sec=total_ms/1000;t->tv_nsec=(total_ms%1000)*1000000;
  last_virtual_clock=*t;event("clock",n,ms,0);return 0;
 }
 if(nr==SYS_mmap&&driver>=0&&b==getpagesize()&&c==3&&d==(MAP_PRIVATE|MAP_ANONYMOUS)&&e==-1&&allocations<2){
  int i=allocations++;event("allocate_attempt",i,b,0);if(at("allocate",i))return fail("allocate_error");long rc=actual(nr,a,b,c,d,e,f);if(rc!=-1){addr[i]=rc;extent[i]=b;}event("allocated",i,rc,b);return rc;
 }
 if(nr==SYS_munmap){for(int i=0;i<2;i++)if(a==addr[i]&&a){
  if(driver>=0||b!=extent[i]){event("unsafe_release",i,a,b);abort();}event("release_attempt",i,a,b);if(at("munmap_before",i))return fail("munmap_error_before");long rc=actual(nr,a,b,c,d,e,f);addr[i]=0;event("released",i,a,b);if(at("munmap_after",i))return fail("munmap_error_after");return rc;
 }}
 if(nr==SYS_ioctl&&a==driver&&driver>=0){
  event("ioctl",b,driver,0);
  if(b==(long)HAILO_QUERY_DRIVER_INFO){struct hailo_driver_info *p=(void *)c;memset(p,0,sizeof(*p));p->major_version=is("identity")?4:5;p->minor_version=3;return 0;}
  if(b==(long)HAILO_QUERY_DEVICE_PROPERTIES){struct hailo_device_properties *p=(void *)c;memset(p,0,sizeof(*p));p->desc_max_page_size=4096;p->board_type=2;p->dma_type=0;p->dma_engines_count=1;p->is_fw_loaded=true;return 0;}
  if(b==(long)HAILO_DESC_LIST_CREATE){int i=creates++;struct hailo_desc_list_create_params *p=(void *)c;if(i>1||p->desc_count!=65536||p->desc_page_size!=512||!p->is_circular)abort();if(at("desc",i))return fail("descriptor_error");p->desc_handle=101+i;p->dma_address=4096*(i+1);event("descriptor",i,p->desc_handle,0);return 0;}
  if(b==(long)HAILO_DESC_LIST_RELEASE){int i=releases++;if(connected||i>1)abort();if(at("desc_release",i))return fail("descriptor_release_error");return 0;}
  if(b==(long)HAILO_SOC_CONNECT){struct hailo_soc_connect_params *p=(void *)c;if(p->port_number!=12133||p->input_desc_handle!=101||p->output_desc_handle!=102)abort();if(is("connect_before"))return fail("connect_before_error");connected=1;p->input_channel_index=3;p->output_channel_index=19;if(is("connect_after"))return fail("connect_after_error");return 0;}
  if(b==(long)HAILO_SOC_CLOSE){struct hailo_soc_close_params *p=(void *)c;if(p->input_channel_index!=3||p->output_channel_index!=19||!connected)abort();if(is("channel_before"))return fail("channel_before_error");connected=0;pending[0]=pending[1]=0;if(is("channel_after"))return fail("channel_after_error");return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_MAP){int i=maps++;struct hailo_vdma_buffer_params *p=(void *)c;if(i>1||p->size!=2068||p->type!=0||p->direction!=(enum hailo_dma_data_direction)(i+1)||p->addr_or_fd!=(uintptr_t)addr[i])abort();if(at("map_before",i))return fail("map_before_error");mapped[i]=1;p->mapped_handle=i+1;event("map_effect",i,addr[i],2068);if(at("map_after",i))return fail("map_after_error");if(at("map_reply",i))p->size++;return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_UNMAP){struct hailo_vdma_buffer_params *p=(void *)c;int i=(int)p->direction-1;if(i<0||i>1||p->addr_or_fd!=(uintptr_t)addr[i]||pending[i])abort();if(at("unmap_before",i))return fail("unmap_before_error");mapped[i]=0;if(at("unmap_after",i))return fail("unmap_after_error");return 0;}
  if(b==(long)HAILO_VDMA_BUFFER_SYNC){int n=++syncs;if(n%4==1)active_phase=sequence+1;struct hailo_vdma_buffer_sync_params *p=(void *)c;int i=(int)p->handle-1;if(i<0||i>1||!mapped[i]||p->offset||p->count!=2068||p->sync_type>1||pending[i])abort();event("sync_attempt",n,i,p->sync_type);if(at("sync_before",n))return fail("sync_before_error");device_owned[i]=p->sync_type==HAILO_SYNC_FOR_DEVICE;protection(i,device_owned[i]?PROT_NONE:PROT_READ|PROT_WRITE);if(at("sync_after",n))return fail("sync_after_error");return 0;}
  if(b==(long)HAILO_VDMA_ENABLE_CHANNELS){if(is("enable_before"))return fail("enable_before_error");disabled=0;if(is("enable_after"))return fail("enable_after_error");return 0;}
  if(b==(long)HAILO_VDMA_DISABLE_CHANNELS){disabled=1;return 0;}
  if(b==(long)HAILO_VDMA_LAUNCH_TRANSFER){
   int n=++launches;if(n%2==1)active_phase=sequence+1;struct hailo_vdma_launch_transfer_params *p=(void *)c;struct hailo_vdma_prepare_transfer_params *q=&p->prepare_transfer_params;int i=q->channel_index==3?0:1;
   if(!connected||!mapped[i]||!device_owned[i]||p->engine_index||p->is_cyclic||q->is_debug||q->desc_handle!=(uintptr_t)(101+i)||q->channel_index!=(i==0?3:19)||n%2!=(i==0?0:1))abort();
   if(q->buffers_count!=(i==0?2:1))abort();
   for(int j=0;j<q->buffers_count;j++){long offset=i==0&&j==1?20:0;long size=i==0?(j==0?20:2048):2068;if(q->buffers[j].buffer_type!=0||q->buffers[j].addr_or_fd!=(uintptr_t)(addr[i]+offset)||q->buffers[j].size!=(uint32_t)size)abort();}
   for(int j=q->buffers_count;j<8;j++){unsigned char zero[sizeof(q->buffers[j])];memset(zero,0,sizeof(zero));if(memcmp(&q->buffers[j],zero,sizeof(zero)))abort();}
   event("launch_attempt",n,i,q->buffers_count);if(at("launch_before",n))return fail("launch_before_error");pending[i]=1;event("launch_effect",n,i,0);
   if(i==0){
    protection(0,PROT_READ);const unsigned char *in=(void *)addr[0];uint32_t words[5];memcpy(words,in,20);
    unsigned char expected[2068];fixture(expected,"REQUEST",words[2]);if(memcmp(in,expected,2068))abort();
    if(words[0]!=0x8a554432U||words[4]!=1||words[1]>2048||sequence>=4||
       (sequence==0&&(words[2]!=0||words[3]!=20))||
       (sequence==1&&(words[2]!=1||words[3]!=22))||
       (sequence>=2&&((words[2]!=2&&words[2]!=3)||words[3]!=21)))abort();
    wire(in,"wire");protection(1,PROT_READ|PROT_WRITE);fixture((unsigned char *)addr[1],"REPLY",words[2]);
    if(is("reply_magic")){((uint32_t *)addr[1])[0]=0;}
    if(is("reply_size")){((uint32_t *)addr[1])[1]=2049;}
    if(is("reply_id")){((uint32_t *)addr[1])[2]++;}
    if(is("reply_action")){((uint32_t *)addr[1])[3]++;}
    if(is("reply_status")){((uint32_t *)addr[1])[4]=7;}
    wire((unsigned char *)addr[1],"reply_wire");protection(1,PROT_NONE);protection(0,PROT_NONE);sequence++;
   }
   if(at("launch_after",n)){return fail("launch_after_error");}
   long result=number(i==0?"AESIR_GROUP_INPUT_COUNT":"AESIR_GROUP_OUTPUT_COUNT",i==0?7:5);if(result<0)errno=EIO;return result;
  }
  if(b==(long)HAILO_VDMA_INTERRUPTS_WAIT){
   int n=++irqs;event("wait_attempt",n,0,0);if(is("wait_before"))return fail("wait_before_error");if(is("wait_stall")){while(!disabled)usleep(1000);return 0;}
   struct hailo_vdma_interrupts_wait_params *p=(void *)c;uint64_t mask=(1ULL<<3)|(1ULL<<19);if(p->channels_bitmap_per_engine[0]!=mask||p->channels_bitmap_per_engine[1]||p->channels_bitmap_per_engine[2])abort();p->channels_count=0;
   int first=0,last=2;if(is("partial")){first=(n-1)%2;last=first+1;}
   if(is("duplicate")){first=last=0;if(n==1){first=0;last=1;}else{first=0;last=1;}}
   if(is("empty"))first=last=0;
   for(int j=first;j<last;j++){int k=p->channels_count++;p->irq_data[k].engine_index=0;p->irq_data[k].channel_index=j==0?3:19;p->irq_data[k].data=1;pending[j]=0;}
   if(is("irq_foreign")){p->irq_data[0].channel_index=4;}if(is("irq_count"))p->irq_data[0].data=2;if(is("irq_error"))p->irq_data[0].data=255;if(is("irq_mask"))p->channels_bitmap_per_engine[0]=1;if(is("irq_engine"))p->irq_data[0].engine_index=1;
   event("wait_effect",n,p->channels_count,0);if(is("wait_after"))return fail("wait_after_error");return 0;
  }
  event("forbidden_ioctl",b,0,0);abort();
 }
 return actual(nr,a,b,c,d,e,f);
}
