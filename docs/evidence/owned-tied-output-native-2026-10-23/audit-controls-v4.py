from pathlib import Path
from collections import Counter
import hashlib,json
repo=Path.cwd();host=repo.parent/'tied-output-native-host-v4/tied-output';out=repo.parent/'tied-output-native-audit-v4';assert (out/'census.json').exists();rows=json.loads((host/'runs.json').read_text());fixtures={f['root']:f for f in json.loads((host/'fixtures.json').read_text())};count=Counter()
for i,r in enumerate(rows):
 for ch in ('stdout','stderr'):assert (host/('call-%04d.'%i+ch)).read_bytes()==r[ch].encode()
 if r['returncode']:
  assert i+1<len(rows) and rows[i+1].get('fresh_recovery_for_call')==i and rows[i+1]['returncode']==0;count['individual_refusals_followed_by_fresh_success']+=1
 if 'fresh_recovery_for_call' in r:assert r['fresh_recovery_for_call']==i-1 and rows[i-1]['returncode']!=0
assert count['individual_refusals_followed_by_fresh_success']==2027
mutations=json.loads((host/'mutations.json').read_text());assert len(mutations)==36
for a,b in zip(mutations[::2],mutations[1::2]):
 assert a['root']==b['root'] and a['mode']==b['mode'] and a['repeat']==0 and b['repeat']==1
 assert a['complete_before']==b['complete_before']==fixtures[a['root']]['files'] and a['complete_after']==b['complete_after'] and a['complete_before']!=a['complete_after']
 current={p.name:p.read_bytes().hex() for p in Path(a['root']).iterdir()};assert current==a['complete_before'];count['complete_original_mutation_and_restoration_pairs']+=1
faults=json.loads((host/'faults.json').read_text());assert len(faults)==82
seams={'create':('create',None),'read_error':('source_read',None),'read_eof':('source_read',None),'write_error':('copy_write',None),'write_zero':('copy_write',None),'seal':('seal',None),'missing_seals':('missing_seals',None),'map':('map',None),'copy_digest':('sealed_read',1),'parser_digest':('sealed_read',2),'source_close':('original_close',None),'short':('source_read',None)}
for a,b in zip(faults[::2],faults[1::2]):
 assert a['repeat']==0 and b['repeat']==1 and a['mode']==b['mode'] and a['label']==b['label'] and a.get('phase')==b.get('phase') and a.get('family')==b.get('family')
 x=Path(a['path']).read_bytes();y=Path(b['path']).read_bytes();assert x==y==bytes.fromhex(a['hex'])==bytes.fromhex(b['hex']);events=[json.loads(line) for line in x.splitlines()];assert events
 if a.get('family')=='collection':
  op,phase=seams[a['mode']];assert any(e['op']==op and (phase is None or e['phase']==phase) for e in events)
  if a['mode']=='short':assert any(e['op']=='source_read' and e['request']>3 for e in events)
 else:assert any(e['op']==a['mode'] and (a['phase']==0 or e['phase']==a['phase']) for e in events)
 count['independent_complete_fault_log_pairs']+=1
j=json.loads((out/'census.json').read_text());j['independent_control_audit']=dict(count);(out/'census-with-controls.json').write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(count),indent=2))
