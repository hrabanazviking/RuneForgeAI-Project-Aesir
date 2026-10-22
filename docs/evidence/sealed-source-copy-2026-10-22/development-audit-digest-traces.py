from collections import Counter
from pathlib import Path
import hashlib,json,re
root=Path('../sealed-copy-native-acceptance/digest');out=Path('../sealed-copy-native-acceptance')
manifest=json.load(open(root/'trace-manifest.json'));runs=json.load(open(root/'runs.json'));ids=json.load(open(root/'fixtures.json'))
def logical(raw):
 pending={};rows=[]
 for line in raw.splitlines():
  m=re.match(r'^(\d+)\s+(.*)$',line);assert m,line
  pid,body=m.groups()
  if '<unfinished ...>' in body:
   assert pid not in pending,line;pending[pid]=body.split('<unfinished ...>',1)[0];continue
  resumed=re.match(r'<\.\.\. (\w+) resumed>(.*)',body)
  if resumed:
   prefix=pending.pop(pid);assert prefix.startswith(resumed[1]+'('),(line,prefix);body=prefix+resumed[2]
  rows.append((pid,body))
 assert not pending,pending
 return rows
rows=[]
for m in manifest:
 path=m['path'];trace=Path(m['trace']);text=trace.read_text();opens=[];closes=[];maps=[];unmaps=[];reads=[];stats=[]
 for token in ('/dev/h1x-','/dev/hailo','libhailort','libcuda','libtorch','libonnxruntime','libggml','libcrypto','libssl','connect(','socket(','ioctl('):assert token not in text,(trace,token)
 record=next(r for r in runs if str(trace) in r['arguments']);cmd=record['arguments'][record['arguments'].index(str(trace))+1:];target_size=ids.get(path,{}).get('bytes')
 for pid,line in logical(text):
  match=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if match:unmaps.append((pid,match[1],int(match[2])))
  if not path or path not in line:continue
  match=re.search(r'openat\(.*?"'+re.escape(path)+r'".*?\)\s*= (\d+)<',line)
  if match:
   if not m['mutation']:assert 'O_RDONLY' in line and 'O_RDWR' not in line and 'O_WRONLY' not in line,line
   opens.append((pid,match[1]))
  match=re.search(r'close\((\d+)<'+re.escape(path)+r'>\s*\)\s*= 0',line)
  if match:closes.append((pid,match[1]))
  if 'mmap(' in line:
   match=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, (\d+)<'+re.escape(path)+r'>, 0\s*\)\s*= (0x[0-9a-f]+)',line);assert match,line
   assert int(match[1])==target_size,(line,target_size);maps.append((pid,match[3],target_size))
  if 'pread64(' in line:
   match=re.search(r'pread64\((\d+)<'+re.escape(path)+r'>, .*?, (\d+), (\d+)\s*\)\s*= (-?\d+)',line);assert match,line
   fd,want,offset,n=map(int,match.groups());assert 0<want<=4096 and n<=want,line
   args=record['arguments'];binary=next(i for i,v in enumerate(args) if Path(v).name in ('source-byte-digest','source-digest-api'));args=args[binary:]
   if Path(args[0]).name=='source-byte-digest':first,count=int(args[2]),int(args[3])
   elif args[1]=='borrow':first,count=int(args[4]),int(args[5])
   else:first,count=0,target_size
   assert first<=offset and want<=first+count-offset,(line,first,count)
   reads.append({'pid':pid,'fd':fd,'offset':offset,'requested':want,'returned':n,'window_first':first,'window_count':count})
  if 'statx(' in line:stats.append(line)
 assert Counter(opens)==Counter(closes),(trace,opens,closes)
 assert not Counter(maps)-Counter(unmaps),(trace,maps,unmaps)
 if path:assert opens,trace
 if not m['mutation'] and path in ids:assert hashlib.sha256(Path(path).read_bytes()).hexdigest()==ids[path]['sha256'],path
 # For ordinary successful, nonfault reads, reconstruct exact consecutive coverage.
 if reads and not m['fault'] and not m['mutation']:
  assert reads[0]['offset']==reads[0]['window_first']
  for a,b in zip(reads,reads[1:]):assert b['offset']==a['offset']+a['returned']
  assert reads[-1]['offset']+reads[-1]['returned']==reads[-1]['window_first']+reads[-1]['window_count']
 rows.append({'trace':str(trace),'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'source_opens':len(opens),'source_closes':len(closes),'whole_readonly_maps':len(maps),'matched_unmaps':len(maps),'kernel_positional_reads':reads,'same_descriptor_stat_calls':len(stats),'synthetic_mutation':m['mutation'],'fault':m['fault']})
assert len(rows)==len(list(root.glob('trace-*.strace')))==sum(Path(r['arguments'][0]).name=='strace' for r in runs)
result={'trace_count':len(rows),'totals':{k:sum(r[k] for r in rows) for k in ('source_opens','source_closes','whole_readonly_maps','matched_unmaps','same_descriptor_stat_calls')},'kernel_positional_read_count':sum(len(r['kernel_positional_reads']) for r in rows),'target_device_network_ioctl_external_crypto_matches':0,'traces':rows,'fault_shim_injected_errors_do_not_issue_a_kernel_read':True}
(out/'trace-audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='traces'}))
# Legacy test traces also retain complete open/mmap cleanup evidence; variable
# single-/multi-PID strace formatting is handled with an explicit main PID key.
legacy=[]
for trace in sorted((out/'legacy').rglob('*.strace')):
 text=trace.read_text()
 for token in ('/dev/hailo','/dev/h1x-','libhailort','libcuda','libtorch','libonnxruntime','connect(','ioctl('):assert token not in text,(trace,token)
 opens=[];closes=[];maps=[];unmaps=[]
 normalized='\n'.join(line if re.match(r'^\d+\s+',line) else '0 '+line for line in text.splitlines())
 for pid,line in logical(normalized):
  m=re.search(r'openat\(.*?"([^"]+\.gguf)".*?= (\d+)<',line)
  if m:assert 'O_RDONLY' in line and 'O_RDWR' not in line;opens.append((pid,m[2],m[1]))
  m=re.search(r'close\((\d+)<([^>]+\.gguf)>\s*\)\s*= 0',line)
  if m:closes.append((pid,m[1],m[2]))
  if 'mmap(' in line and '.gguf>' in line:
   m=re.search(r'mmap\(NULL, (\d+), PROT_READ, MAP_SHARED, \d+<[^>]+\.gguf>, 0\s*\)\s*= (0x[0-9a-f]+)',line);assert m,line;maps.append((pid,m[2],int(m[1])))
  m=re.search(r'munmap\((0x[0-9a-f]+), (\d+)\s*\)\s*= 0',line)
  if m:unmaps.append((pid,m[1],int(m[2])))
 assert opens and Counter(opens)==Counter(closes),(trace,opens,closes)
 assert maps and not Counter(maps)-Counter(unmaps),(trace,maps,unmaps)
 legacy.append({'trace':str(trace),'sha256':hashlib.sha256(trace.read_bytes()).hexdigest(),'opens':len(opens),'closes':len(closes),'maps':len(maps),'unmaps':len(maps)})
(out/'legacy-trace-audit.json').write_text(json.dumps(legacy,indent=2)+'\n');print('legacy traces',len(legacy))
mutations=[]
for r in runs:
 args=r['arguments'];i=next((i for i,v in enumerate(args) if Path(v).name=='source-digest-api'),None)
 if i is None or len(args)<=i+3 or args[i+1]!='owner':continue
 path,mode=args[i+2:i+4]
 if mode not in ('truncate','same_size'):continue
 ident=ids[path];kind=ident['kind'];size=4*513
 # Reconstruct the exact independent original fixture bytes from the frozen writer.
 import sys
 sys.path.insert(0,str(Path('tests').resolve()))
 from test_hailo_source_q8_constants import make
 payload=bytes((i*37+kind)%256 for i in range(size));raw=make([('matrix.weight',513,1,kind,payload)])[0]+b'\x91'
 assert hashlib.sha256(raw).hexdigest()==ident['sha256']
 expected=raw[:1] if mode=='truncate' else raw[:-1]+b'\xad'
 assert Path(path).read_bytes()==expected,path
 mutations.append({'path':path,'mode':mode,'original_sha256':ident['sha256'],'final_sha256':hashlib.sha256(expected).hexdigest(),'complete_final_bytes_independently_equal':True})
assert len(mutations)==2
(out/'synthetic-mutation-audit.json').write_text(json.dumps(mutations,indent=2)+'\n');print('both intentional mutations match independently reconstructed complete bytes')
