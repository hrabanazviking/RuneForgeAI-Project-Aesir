from pathlib import Path
import json,hashlib,re,subprocess
repo=Path.cwd();work=repo.parent;out=Path(__file__).parent;h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
contract=work/'session-transfer-pin-physical-contract-2026-10-24';final=work/'session-transfer-pin-probe-final'
cm=repo/'docs/evidence/session-transfer-pin-physical-contract-2026-10-24/archive-identities.json';c=json.loads(cm.read_text())
assert h(cm)=='888f6bc22d090f1fdedd7635e90387586218f6debea3ceb944537e9aeb159b10'
for r in c['paths']:
 p=work/r['path'];assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
compiler=json.loads((contract/'compiler.json').read_text());assert h(Path(compiler['path']))==compiler['sha256']
controls=json.loads((contract/'controls.json').read_text());assert len(controls)==163
for r in controls:assert h(Path(r['binary']))==r['sha256']
oldcounts=[];finalcounts=[]
for name,folder in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
 old=json.loads((contract/name).read_text());new=json.loads((final/name).read_text());oldcounts.append(len(old));finalcounts.append(len(new));assert old.items()<=new.items()
 for p,d in new.items():assert h(repo/p)==h(final/folder/p)==d
assert oldcounts==[714,89] and finalcounts==[715,90]
images=json.loads((final/'binaries.json').read_text())['images']
for r in images.values():assert h(Path(r['current']))==r['sha256'] and h(Path(r['frozen']))==r['frozen_sha256']
for name in ['hailo_soc_abi_oracle.cpp','session_transfer_pin_faults.c']:assert h(final/name)==h(contract/'oracle-inputs'/name)==h(repo/'tests'/name)
mojobuilds=json.loads((final/'build-results.json').read_text());cbuilds=json.loads((final/'c-build-results.json').read_text());builds=mojobuilds+cbuilds;assert len(builds)==5 and all(r['returncode']==0 for r in mojobuilds) and all(h(Path(r['binary']))==r['sha256'] for r in builds)
assert not (work/'session-transfer-pin-probe-development/build.stderr').read_bytes()
for name in ['faults.so','abi-oracle']:assert not (final/(name+'.stdout')).read_bytes() and not (final/(name+'.stderr')).read_bytes()
hostaudit=json.loads((work/'session-transfer-pin-probe-host-audit/census.json').read_text());assert hostaudit['metrics']['full_pairs']==29 and hostaudit['all_links_before_host']
host=work/'session-transfer-pin-probe-host';runs=json.loads((host/'runs.json').read_text());assert len(runs)==58
for i in range(0,58,2):
 assert runs[i]['returncode']==runs[i+1]['returncode'] and not any(runs[j]['timed_out'] or runs[j]['unresolved'] for j in [i,i+1])
 for ch in ['stdout','stderr']:assert (host/f'{i}.{ch}').read_bytes()==(host/f'{i+1}.{ch}').read_bytes()
physical=work/'session-transfer-pin-probe-physical';pr=json.loads((physical/'runs.json').read_text());assert len(pr)==4 and all(r['returncode']==0 and not r['mock'] and not r['timed_out'] and not r['unresolved'] for r in pr)
assert all(not (physical/f'{i}.stderr').read_bytes() for i in range(4))
pa=json.loads((work/'session-transfer-pin-probe-physical-audit/census.json').read_text());assert pa['physical']['actual_ioctls']==38 and pa['physical']['actual_device_opens']==pa['physical']['actual_device_closes']==4 and pa['physical']['actual_readonly_private_views']==pa['physical']['actual_owned_unmaps']==6
roots=['session-transfer-pin-probe-development','session-transfer-pin-probe-final','session-transfer-pin-probe-host','session-transfer-pin-probe-host-audit','session-transfer-pin-probe-physical','session-transfer-pin-probe-physical-audit','session-transfer-pin-probe-recording-failure']
ev=repo/'docs/evidence/session-transfer-pin-probe-2026-10-24';ev.mkdir(parents=True,exist_ok=False);rows=[]
for root in roots:
 for p in sorted((work/root).rglob('*')):
  if p.is_file():rows.append(dict(path=str(p.relative_to(work)),bytes=p.stat().st_size,sha256=h(p)))
pages=[]
for i in range(0,len(rows),8000):
 chunk=rows[i:i+8000];p=ev/f'archive-{i//8000+1:03d}.json';p.write_text(json.dumps(chunk,indent=2)+'\n');pages.append(dict(path=p.name,files=len(chunk),source_bytes=sum(r['bytes'] for r in chunk),bytes=p.stat().st_size,sha256=h(p)))
p=ev/'archive-identities.json';p.write_text(json.dumps(dict(path_base='task work directory containing the repository and archive roots',roots=roots,files=len(rows),source_bytes=sum(r['bytes'] for r in rows),pages=pages),indent=2)+'\n')
summary=dict(roots=roots,files=len(rows),source_bytes=sum(r['bytes'] for r in rows),pages=len(pages),manifest_sha256=h(p),contract_files=len(c['paths']),contract_controls=len(controls),old_counts=oldcounts,final_counts=finalcounts,old_source_test_edits=0,compiler_sha256=compiler['sha256']);(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for name,source in [('host-census.json',work/'session-transfer-pin-probe-host-audit/census.json'),('physical-census.json',work/'session-transfer-pin-probe-physical-audit/census.json'),('affected-closure.json',final/'affected-closure.json')]: (ev/name).write_bytes(source.read_bytes())
def relative(v):
 try:return str(Path(v).relative_to(work))
 except ValueError:return v
clean=[]
for r in builds:
 j={k:v for k,v in r.items() if k!='arguments'};j['source']=relative(j['source']);j['binary']=relative(j['binary']);clean.append(j)
(ev/'build-identities.json').write_text(json.dumps(clean,indent=2)+'\n')
warnings={}
for p in sorted(final.glob('build-*.stderr')):warnings[p.name]=[s.replace(str(repo)+'/', '') for s in re.findall(r'^([^\n]+:\d+:\d+: warning:[^\n]+)',p.read_text(),re.M)]
(ev/'warnings.json').write_text(json.dumps(warnings,indent=2)+'\n')
for name in ['audit-host.py','audit-physical.py']:
 s=(work/'session-transfer-pin-probe-development'/name).read_text();(ev/name).write_text('# Review copy; exact executed script is pinned in the raw archive.\n'+s)
print(json.dumps(summary,indent=2))
