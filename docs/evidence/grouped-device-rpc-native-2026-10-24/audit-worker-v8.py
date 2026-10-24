# Review copy;exact executed script pinned in raw archive.
from pathlib import Path
from collections import Counter
import json,re,hashlib
repo=Path.cwd();work=repo.parent;root=work/'grouped-device-rpc-native-worker-final-v8';out=work/'grouped-device-rpc-native-worker-audit-v8';out.mkdir(exist_ok=False);records=json.loads((root/'worker-raw/records.json').read_text());assert len(records)==49;records+=json.loads((root/'census-faults-raw/records.json').read_text());assert len(records)==53;counts=Counter();cases=[]
for n,r in enumerate(records):
 raw=root/("worker-raw" if n<49 else "census-faults-raw");index=n if n<49 else n-49
 assert r['equal'] and not r['guard_expired'] and not r['unresolved']
 for label,args in [('current',r['arguments']),('frozen',r['frozen_arguments'])]:
  for channel in ('stdout','stderr'):assert (raw/f'{index}.current.{channel}').read_bytes()==(raw/f'{index}.frozen.{channel}').read_bytes()
  text=Path(args[args.index('-o')+1]).read_text();pending={};calls=[]
  for line in text.splitlines():
   pid,b=line.split(' ',1);b=b.lstrip();assert pid.isdigit()
   if b.endswith('<unfinished ...>'):assert pid not in pending;pending[pid]=b.removesuffix('<unfinished ...>').rstrip()
   elif b.startswith('<... ') and ' resumed>' in b:calls.append((int(pid),pending.pop(pid)+b.split(' resumed>',1)[1]))
   else:calls.append((int(pid),b))
  abandon=args[-1]=='abandon';assert not pending or (abandon and all(b.startswith(('read(','futex(')) for b in pending.values()));assert sum(b.startswith('execve(') for p,b in calls)==1
  assert not any(b.startswith(('ioctl(','connect(')) or re.search(r'openat\(.*"/dev/(?:h1x-|hailo)',b) or b.startswith('syscall_0x') for p,b in calls)
  main=next(p for p,b in calls if b.startswith('execve('));live={};pipe_ids=set();threads={};callbacks=set();proc_observations=0;closes=0
  for p,b in calls:
   assert re.match(r'^(?:\w+\(|--- |\+\+\+ )',b)
   m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
   if m:fd=int(m[1]);assert fd not in live;live[fd]='file';counts['file_fd_generations']+=1
   m=re.match(r'pipe2\(\[(\d+)<pipe:\[(\d+)\]>, (\d+)<pipe:\[\2\]>\], O_CLOEXEC\)\s+= 0$',b)
   if m:
    for fd in (int(m[1]),int(m[3])):assert fd not in live;live[fd]='pipe';counts['file_fd_generations']+=1
    pipe_ids.add(m[2]);counts['owned_pipes']+=1
   m=re.match(r'close\((\d+).*\)\s+= 0$',b)
   if m:fd=int(m[1]);assert fd in live;(closes:=closes+int(live[fd]=='pipe'));live.pop(fd);counts['file_fd_closes']+=1
   m=re.match(r'clone(?:3)?\(.*\)\s+= (\d+)$',b)
   if m:
    tid=int(m[1]);threads[tid]=False;counts['all_native_threads']+=1
    if pipe_ids:callbacks.add(tid);counts['actual_callback_workers']+=1
    else:counts['runtime_pool_threads']+=1
   if p in threads and b.startswith('+++ '):threads[p]=True
   if b.startswith('getdents64('):proc_observations+=1
  assert all(threads.values()) and main not in threads
  if abandon:assert r['returncode']==123 and len(live)==2 and set(live.values())=={'pipe'};counts['pipes_reclaimed_by_process_exit']+=1
  else:assert not live and closes==2*len(pipe_ids)
  if r['source']=='tests/hailo_group_device_worker.mojo' and r['returncode']==0:
   data=json.loads((raw/f'{index}.{label}.stdout').read_text());assert data['worker_threads_remaining']==0 and data['joined'];assert len(callbacks)==1 and proc_observations>=4;counts['successful_bounded_censuses']+=1
  counts['traces']+=1;counts['cancelled_blocking_reads_at_fail_closed_exit']+=len(pending);cases.append(dict(pair=n,label=label,actual_callback_workers=len(callbacks),runtime_pool_threads=len(threads)-len(callbacks),proc_observations=proc_observations,explicit_pipe_closes=closes,remaining_fds_at_exit=len(live),expected_fail_closed=abandon))
result=dict(metrics=dict(counts),full_pairs=53,old_source_test_edits=0,full_syscall_traces=True,all_owned_fds_accounted=True,all_actual_workers_exit=True,physical_calls=False,source_model_execution=False);(out/'cases.json').write_text(json.dumps(cases,indent=2)+'\n');(out/'census.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
