# Additional native GGUF ownership trace; run after all final verification passes.
from pathlib import Path
import hashlib,json,re,subprocess
base=Path('../dynamic-graph-acceptance');rows=json.loads((base/'test-results.json').read_text())
assert len(rows)==5 and all(r['returncode']==0 for r in rows)
out=base/'gguf-owner';out.mkdir(exist_ok=False)
source=(base/'graph/fixtures/explicit.gguf').resolve();before=hashlib.sha256(source.read_bytes()).hexdigest()
original=json.loads((base/'graph/fixture-identities.json').read_text());expected=[h for p,h in original.items() if Path(p).name=='explicit.gguf'];assert expected==[before]
binary=Path('../dynamic-graph-final/dynamic-graph-gguf').resolve()
cmd=[str(binary),str(source),'0,0','0,0','1,0','source32','silu,silu','full_prefix','0','0','32','3,1','dynamic','64','4609434218613702656']
trace=out/'native.strace';wrapped=['strace','-yy','-qq','-o',str(trace),'-e','trace=%file,%network,mmap,munmap,close,ioctl,pread64,read',*cmd]
a=subprocess.run(wrapped,capture_output=True,text=True,timeout=60);assert a.returncode==0,a.stderr
b=subprocess.run(cmd,capture_output=True,text=True,timeout=60);assert b.returncode==0,b.stderr
assert a.stdout==b.stdout and not a.stderr and not b.stderr
(out/'stdout.json').write_text(a.stdout)
assert hashlib.sha256(source.read_bytes()).hexdigest()==before
text=trace.read_text();name=re.escape(str(source))
opens=re.findall(r'openat2?\(.*\)\s*=\s*\d+<'+name+r'>',text)
closes=re.findall(r'close\(\d+<'+name+r'>\)\s*=\s*0',text)
maps=re.findall(r'mmap\([^,]+, (\d+), ([^,]+), ([^,]+), \d+<'+name+r'>, 0\)\s*=\s*(0x[0-9a-f]+)',text)
assert len(opens)==len(closes)==len(maps)==1,(opens,closes,maps)
length,protection,flags,address=maps[0];assert int(length)==source.stat().st_size and protection=='PROT_READ' and flags=='MAP_SHARED',maps
assert re.search(r'munmap\('+address+r', '+length+r'\)\s*=\s*0',text)
assert not re.search(r'\b(connect|ioctl)\(',text)
assert not any('openat' in l and re.search(r'lib(torch|cuda|hailort)|/dev/(h1x|hailo|nvidia)',l) for l in text.splitlines())
summary=dict(native_calls=2,fixture_sha256=before,fixture_opens=1,fixture_closes=1,readonly_whole_file_mappings=1,mapping_bytes=int(length),mapping_flags=flags,mapping_protection=protection,matching_unmaps=1,complete_traced_untraced_stdout_equal=True,stdout_sha256=hashlib.sha256(a.stdout.encode()).hexdigest(),connects=0,ioctls=0,inference_library_or_device_opens=0,tensor_payload_evaluation=False,scope='Existing PackedGGUF metadata path uses a read-only whole-file mapping, including the synthetic payload address range; it constructs descriptors and closes the owner before graph lowering. Payload numerical evaluation is excluded, not the mapping itself.',command=cmd)
(out/'audit.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
