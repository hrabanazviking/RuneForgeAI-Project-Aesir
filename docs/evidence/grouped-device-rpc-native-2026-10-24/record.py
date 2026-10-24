from pathlib import Path
import json,hashlib,re
repo=Path.cwd();work=repo.parent;out=Path(__file__).parent;base=work/'grouped-device-rpc-native-baseline-v2';final=work/'grouped-device-rpc-native-final-v8';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();contract=repo/'docs/evidence/grouped-device-rpc-contract-2026-10-24/archive-identities.json';assert h(contract)=='97825114ea5507bbb2ba31d342c1f99bc821950e5e2a5c90de2dc75fb2ae4ddb'
for r in json.loads(contract.read_text())['paths']:
 p=work/r['path'];assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
compiler=json.loads((base/'compiler.json').read_text());assert h(Path(compiler['path']))==compiler['sha256'];controls=json.loads((base/'controls.json').read_text());assert len(controls)==168
for r in controls:assert h(Path(r['binary']))==r['sha256']
for name,folder,nold,nnew in [('source-hashes.json','source-snapshot',718,722),('test-input-hashes.json','test-snapshot',91,92)]:
 old=json.loads((base/name).read_text());new=json.loads((final/name).read_text());assert len(old)==nold and len(new)==nnew and old.items()<=new.items()
 for p,d in new.items():assert h(repo/p)==h(final/folder/p)==d
rows=json.loads((final/'build-results.json').read_text());crows=json.loads((final/'c-build-results.json').read_text());assert len(rows)==22 and len(crows)==5 and all(r['returncode']==0 and h(Path(r['binary']))==r['sha256'] for r in rows+crows)
for r in json.loads((final/'images.json').read_text()).values():assert h(Path(r['current']))==h(Path(r['frozen']))==r['sha256']
for r in crows:assert h(repo/r['source'])==h(final/Path(r['source']).name)==r['source_sha256']
primary=json.loads((work/'grouped-device-rpc-native-audit-v2/census.json').read_text());selected=json.loads((work/'grouped-device-rpc-native-selected-audit-v8/census.json').read_text());group=json.loads((work/'grouped-device-rpc-native-group-audit-v8/census.json').read_text());worker=json.loads((work/'grouped-device-rpc-native-worker-audit-v8/census.json').read_text());schema=json.loads((work/'grouped-device-rpc-native-schema-replay/census.json').read_text())
assert primary['metrics']['full_pairs']==primary['metrics']['full_fault_state_pairs'];assert selected['metrics']['methods']==68 and selected['metrics']['full_pairs']==4450;assert group['metrics']['full_pairs']==287;assert worker['full_pairs']==53 and schema['full_auxiliary_pairs']==1
host=work/'grouped-device-rpc-native-host-v6';assert json.loads((host/'result.json').read_text())['returncode']==0 and re.search(r'Ran 12 tests in',(host/'suite.stderr').read_text()) and (host/'suite.stderr').read_text().rstrip().endswith('OK')
roots=['grouped-device-rpc-native-baseline','grouped-device-rpc-native-baseline-v2','grouped-device-rpc-native-development','grouped-device-rpc-native-final']+[f'grouped-device-rpc-native-final-v{v}' for v in range(2,9)]+['grouped-device-rpc-native-host']+[f'grouped-device-rpc-native-host-v{v}' for v in range(2,7)]+['grouped-device-rpc-native-selected','grouped-device-rpc-native-selected-v3','grouped-device-rpc-native-selected-audit','grouped-device-rpc-native-group-audit','grouped-device-rpc-native-selected-audit-v8','grouped-device-rpc-native-group-audit-v8','grouped-device-rpc-native-worker-final-v8','grouped-device-rpc-native-worker-audit-v8','grouped-device-rpc-native-worker-replay','grouped-device-rpc-native-worker-final','grouped-device-rpc-native-worker-audit','grouped-device-rpc-native-worker-audit-v2','grouped-device-rpc-native-schema','grouped-device-rpc-native-schema-replay','grouped-device-rpc-native-audit','grouped-device-rpc-native-audit-v2'];entries=[]
for root in roots:
 assert (work/root).exists()
 for p in sorted((work/root).rglob('*')):
  if p.is_file():entries.append(dict(path=str(p.relative_to(work)),bytes=p.stat().st_size,sha256=h(p)))
ev=repo/'docs/evidence/grouped-device-rpc-native-2026-10-24';ev.mkdir(parents=True,exist_ok=False);pages=[]
for i in range(0,len(entries),8000):
 chunk=entries[i:i+8000];p=ev/f'archive-{i//8000+1:03d}.json';p.write_text(json.dumps(chunk,indent=2)+'\n');pages.append(dict(path=p.name,files=len(chunk),source_bytes=sum(r['bytes'] for r in chunk),bytes=p.stat().st_size,sha256=h(p)))
p=ev/'archive-identities.json';p.write_text(json.dumps(dict(path_base='task work directory containing the repository and raw roots',roots=roots,files=len(entries),source_bytes=sum(r['bytes'] for r in entries),pages=pages),indent=2)+'\n')
full_pairs=primary['metrics']['full_pairs']+selected['metrics']['full_pairs']+group['metrics']['full_pairs']+5
summary=dict(roots=roots,files=len(entries),source_bytes=sum(r['bytes'] for r in entries),pages=len(pages),manifest_sha256=h(p),contract_paths=823,controls=168,old_source_inputs=718,final_source_inputs=722,old_test_inputs=91,final_test_inputs=92,old_source_test_edits=0,compiler_sha256=compiler['sha256'],methods=90,full_pairs=full_pairs,accept_pairs=primary['metrics']['accept_pairs']+selected['metrics']['accept_pairs']+group['metrics']['accept_pairs']+1,refuse_pairs=primary['metrics']['refuse_pairs']+selected['metrics']['refuse_pairs']+group['metrics']['refuse_pairs']+4,primary_full_pairs=primary['metrics']['full_pairs'],selected_full_pairs=4450,group_full_pairs=287,schema_full_pairs=1,worker_full_pairs=53,mojo_links=22,c_links=5,elf_tables=58,physical_device_calls=False,numerical_execution=False,legacy_failures_retained=True);(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for name,data in [('primary-census.json',primary),('selected-census.json',selected),('group-census.json',group),('worker-census.json',worker),('schema-census.json',schema),('affected-closure.json',json.loads((final/'affected-closure.json').read_text()))]:(ev/name).write_text(json.dumps(data,indent=2)+'\n')
def relative(value):
 try:return str(Path(value).relative_to(work))
 except ValueError:return value
clean=[]
for r in rows+crows:
 j={k:v for k,v in r.items() if k!='arguments'};j['source']=relative(j['source']);j['binary']=relative(j['binary']);clean.append(j)
(ev/'build-identities.json').write_text(json.dumps(clean,indent=2)+'\n');warnings={}
for p in sorted(final.glob('build-*.stderr')):warnings[p.name]=[s.replace(str(repo)+'/','') for s in re.findall(r'^([^\n]+:\d+:\d+: warning:[^\n]+)',p.read_text(),re.M)]
(ev/'warnings.json').write_text(json.dumps(warnings,indent=2)+'\n')
for name in ['audit-host-v8b.py','audit-selected-v8.py','audit-group-control-v8.py','audit-worker-v8.py','schema-replay.py']:(ev/name).write_text('# Review copy;exact executed script pinned in raw archive.\n'+(work/'grouped-device-rpc-native-development'/name).read_text())
print(json.dumps(summary,indent=2))
