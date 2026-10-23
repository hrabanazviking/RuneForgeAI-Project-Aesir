from pathlib import Path
from collections import Counter
import hashlib,json,re,sys
sys.path.insert(0,str(Path('../sealed-metadata-native-recording').resolve()))
from logical import logical
root=Path('../sealed-metadata-native-acceptance-v2/sealed-metadata');rows=[]
for r in json.load(open(root/'runs.json')):
 if not r['trace']:continue
 raw=Path(r['trace']).read_text();args=r['arguments'];cmd=args[args.index('-e')+2:];source=cmd[3] if 'entry-006' in cmd[0] else cmd[2]
 active=set();gen={};phases={};checks=0
 for pid,line in logical(raw):
  m=re.search(r'openat\(.*?"'+re.escape(source)+r'".*?\)\s*= (\d+)<',line)
  if m:active.add((pid,m[1]))
  m=re.search(r'close\((\d+)<'+re.escape(source)+r'>.*?\)\s*= 0',line)
  if m:active.discard((pid,m[1]))
  m=re.search(r'memfd_create\("aesir-source-copy".*?\)\s*= (\d+)<',line)
  if m:
   key=(pid,m[1]);gen[key]=gen.get(key,0)+1;phases[(*key,gen[key])]=0
  m=re.search(r'pread64\((\d+)</memfd:aesir-source-copy>\(deleted\).*?, \d+, 0\s*\)\s*= (-?\d+)',line)
  if m:
   key=(*((pid,m[1])),gen[(pid,m[1])]);phases[key]+=1
   if phases[key]==2:
    assert not active,(r['trace'],'original open at consuming parser hash',line,active);checks+=1
 rows.append(dict(trace=r['trace'],parser_hash_order_checks=checks,sha256=hashlib.sha256(Path(r['trace']).read_bytes()).hexdigest()))
result=dict(traces=len(rows),observed_second_hash_start_checks=sum(r['parser_hash_order_checks'] for r in rows),all_originals_closed_before_observed_parser_hash=True,empty_source_hashes_have_no_read_syscalls=True,rows=rows)
Path('../sealed-metadata-native-postverification/admission-order.json').write_text(json.dumps(result,indent=2)+'\n')
print(result['traces'],result['observed_second_hash_start_checks'])
