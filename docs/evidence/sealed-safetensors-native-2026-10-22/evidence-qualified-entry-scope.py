from pathlib import Path
import json
root=Path('../sealed-safetensors-native-acceptance-v2');rows=[r for p in root.glob('*-pairs-native-calls.json') for r in json.load(open(p))]
legacy=[r for r in rows if r['source']=='tests/h043_st_check.mojo']
assert legacy
for r in legacy:
 args=r['arguments'];i=next(i for i,v in enumerate(args) if str(Path(v).resolve())==r['binary']);assert len(args[i+1:])==1 and args[-1]!='load',r
# Qualified entry calls are confined to the approved source/structural compiler
# and original control-byte tests, not master/E-REAL/model execution entries.
for r in rows:
 name=r['source'];assert name.startswith(('smidr/tools/','tests/')),name
 assert not any(v in name.lower() for v in ('master','e-real','engine_main','aesir_main')),name
Path('../sealed-safetensors-native-recording/entry-scope-audit.json').write_text(json.dumps(dict(qualified_entry_calls=len(rows),legacy_header_only_calls=len(legacy),legacy_load_mode_calls=0,engine_master_e_real_entry_calls=0),indent=2)+'\n')
print(len(rows),'qualified source/structural/control entry calls;',len(legacy),'legacy header-only calls; no legacy load mode')
