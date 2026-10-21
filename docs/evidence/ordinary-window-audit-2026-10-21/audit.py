import json,hashlib
from pathlib import Path
p=Path(__file__).resolve().parent;d=json.loads((p/'config.json').read_text());rows=d['cases'];assert len(rows)==46
for r in rows[:36]:
 i=r['input'];o=r['result'];assert o['use_sliding_window']==i['use_sliding_window'] and o['sliding_window']==i['sliding_window']
 assert o['layer_types']==[('sliding_attention' if i['use_sliding_window'] and i['sliding_window'] is not None and flag==0 else 'full_attention') for flag in i['no_rope_layers']]
 if 'max_window_layers' in i:assert o['max_window_layers']==i['max_window_layers']
for r in rows[36:]:
 if r['input']['layer_types']==[]:assert r['error']=='ValueError'
 elif r['input']['layer_types'] is not None:assert r['result']['layer_types']==r['input']['layer_types']
s=(p/'config.strace').read_text();assert not any(x in s for x in ('libtorch','/dev/h1x-','connect('))
report=dict(cases=46,accepted=44,expected_constructor_refusals=2,configuration_only=True,model_execution=False,device_access=False,notes=['Constructor facts do not prove valid numerical masks or complete ordinary adapter semantics.','Explicit layer_types survives flag disagreement; max_window_layers is retained but did not select generated types in these probes.','Generated pattern follows use_sliding_window, non-null window and NoPE bits in this pinned constructor.'],identities={f.name:dict(sha256=hashlib.sha256(f.read_bytes()).hexdigest(),bytes=f.stat().st_size) for f in p.iterdir() if f.is_file() and f.name!='audit.json'})
(p/'audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='identities'},indent=2))
