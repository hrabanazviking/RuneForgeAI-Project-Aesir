from pathlib import Path
import hashlib,json,re
root=Path.cwd();out=Path('../sealed-gguf-contract-study');roots=[Path('.'),Path('aesir_engine'),Path('tests')]
controls=json.load(open(out/'controls.json'));sources=json.load(open(out/'source-hashes.json'));memo={}
def resolve(module):
 result=[];parts=module.split('.')
 if module.startswith('std.') or module=='std':return result
 for base in roots:
  name=base.joinpath(*parts)
  path=name.with_suffix('.mojo')
  if not path.is_file():path=name/'__init__.mojo'
  if path.is_file():
   result.append(str(path))
   for i in range(1,len(parts)):
    package=base.joinpath(*parts[:i])/'__init__.mojo'
    if package.is_file():result.append(str(package))
   return result
 return result
def closure(source,seen=None):
 if seen is None:seen=set()
 if source in seen:return seen
 seen.add(source);text=Path(source).read_text()
 for module in re.findall(r'^\s*(?:from|import)\s+([A-Za-z_][A-Za-z_0-9.]*)',text,re.M):
  for p in resolve(module):closure(p,seen)
 return seen
changed={'aesir_engine/loader/gguf.mojo','aesir_engine/loader/packed_gguf.mojo','hailbru/source_sealed_copy.mojo'}
rows=[]
for r in controls:
 dep=closure(r['source']);rows.append({'source':r['source'],'binary':r['binary'],'affected_by_planned_shared_changes':bool(dep&changed),'shared_dependencies':sorted(dep&changed),'local_import_closure':sorted(dep)})
(out/'consumer-inventory.json').write_text(json.dumps(rows,indent=2)+'\n')
probe=out/'move-probe';assert probe.exists() and not (out/'move-probe-build.txt').read_bytes()
(out/'qualification.json').write_text(json.dumps({'parent':'a0354354c56639277d09c394e10e9fa5e6f90d91','sources_and_actual_snapshots':len(sources),'controls':len(controls),'python_and_actual_snapshots':68,'planned_shared_source_changes':sorted(changed),'static_import_affected_controls':sum(r['affected_by_planned_shared_changes'] for r in rows),'static_import_unaffected_controls':sum(not r['affected_by_planned_shared_changes'] for r in rows),'module_roots':[str(p) for p in roots],'inventory_scope':'Conservative static local import closure including package initializers; recompute after implementation and cover every affected existing entrypoint. No engine/model execution.','movable_wrapper_probe':{'source':'move-probe.mojo','binary_sha256':hashlib.sha256(probe.read_bytes()).hexdigest(),'build_diagnostic_bytes':0,'executed':False},'parser_or_mapping_implementation_added':False,'source_fingerprint_verified':False,'execution_tested':False,'device_access':False},indent=2)+'\n')
print((out/'qualification.json').read_text())
