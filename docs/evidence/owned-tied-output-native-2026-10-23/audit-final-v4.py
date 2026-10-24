from pathlib import Path
import hashlib,json,re,subprocess
repo=Path.cwd();base=repo.parent/'tied-output-native-baseline';final=repo.parent/'tied-output-native-final-v3';linked=repo.parent/'tied-output-native-final';extra=repo.parent/'tied-output-native-compatibility';out=repo.parent/'tied-output-native-audit-v4';h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert (out/'census-partial.json').exists()
manifest=Path('docs/evidence/tied-output-contract-2026-10-23/archive-identities.json');assert h(manifest)=='d1915360a2d84a7f7cdc6873535d377e3a27d8bef4795fb7ef1b2d6966308f74';archive=json.loads(manifest.read_text());assert len(archive)==794
for r in archive:p=Path(r['path']);assert p.stat().st_size==r['bytes'] and h(p)==r['sha256']
for folder in (base,final):
 for name,snapshot in [('source-hashes.json','source-snapshot'),('test-input-hashes.json','test-snapshot')]:
  for p,d in json.loads((folder/name).read_text()).items():
   assert h(folder/snapshot/p)==d
   if folder==final:assert h(Path(p))==d
old=json.loads((base/'source-hashes.json').read_text());now=json.loads((final/'source-hashes.json').read_text());allowed={'smidr/semantic_plan.mojo','smidr/bias_graph.mojo','smidr/expanded_graph.mojo','smidr/owned_ordinary_compiler.mojo','smidr/tools/semantic_plan.mojo'}
assert {p for p,d in old.items() if now[p]!=d}==allowed
assert set(now)-set(old)=={'smidr/source_weight_sharing.mojo','smidr/owned_tied_output_compiler.mojo','smidr/tools/owned_tied_output_compiler.mojo','tests/hailo_owned_tied_output_api.mojo'}
for p,d in json.loads((base/'test-input-hashes.json').read_text()).items():assert h(Path(p))==d
for r in json.loads((base/'controls.json').read_text()):assert h(Path(r['binary']))==r['sha256']
assert h(Path('/home/pi/mojo-dev/.pixi/envs/default/bin/mojo'))=='be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39'
builds=json.loads((linked/'build-results.json').read_text())+json.loads((extra/'build-results.json').read_text());cb=json.loads((linked/'c-build-results.json').read_text())+json.loads((extra/'c-build-results.json').read_text());warnings=[]
for folder in (linked,extra):
 for i,r in enumerate(json.loads((folder/'build-results.json').read_text())):
  assert r['returncode']==0 and h(Path(r['binary']))==r['sha256']
  if r['diagnostic_bytes']:
   assert r['source']=='tests/h043_st_check.mojo';text=(folder/('build-%03d.stdout'%i)).read_text()+(folder/('build-%03d.stderr'%i)).read_text();oldtext=(repo.parent/'sealed-safetensors-native-supplement/current-3.txt').read_text()
   def normalized(s):
    lines=s.splitlines();assert len(lines)==4 and lines[0].startswith('Included from ');lines[0]='Included from SOURCE/tests/h043_st_check.mojo:20:';lines[1]=re.sub(r'safetensors.mojo:\d+:25:','safetensors.mojo:UNCHANGED_BODY:25:',lines[1]);return '\n'.join(lines)
   assert normalized(text)==normalized(oldtext);warnings.append(dict(source=r['source'],full_current=text,full_frozen=oldtext,normalized=normalized(text)))
for r in cb:assert r['returncode']==r['diagnostic_bytes']==0 and h(Path(r['binary']))==r['sha256'] and h(Path(r['source']))==r['source_sha256']
for r in json.loads((extra/'additional-acceptance-inputs.json').read_text()):assert h(Path(r['source']))==h(Path(r['copy']))==r['sha256']
mods={str(p.with_suffix('')).replace('/','.'):p for p in Path('.').rglob('*.mojo') if '.git' not in p.parts};edges={m:set(re.findall(r'^from ([\w.]+) import',p.read_text(),re.M))&mods.keys() for m,p in mods.items()};roots={p[:-5].replace('/','.') for p in allowed}|{'smidr.source_weight_sharing','smidr.owned_tied_output_compiler'}
def reaches(m,seen=None):
 seen=set() if seen is None else seen
 if m in seen:return False
 seen.add(m);return m in roots or any(reaches(n,seen) for n in edges[m])
closure=sorted(str(p) for m,p in mods.items() if re.search(r'^def main\(',p.read_text(),re.M) and reaches(m));assert closure==json.loads((final/'consumer-closure.json').read_text())['all_entrypoints']
for i,r in enumerate(builds+cb):
 for flag,label in [('-d','dynamic'),('-Ws','symbols')]:
  p=subprocess.run(['readelf',flag,r['binary']],capture_output=True);assert p.returncode==0 and not p.stderr;(out/('elf-%03d-%s.txt'%(i,label))).write_bytes(p.stdout)
  for bad in (b'hailort',b'libcuda',b'libtorch',b'libggml',b'libxxhash',b'libprotobuf',b'onnxruntime'):assert bad not in p.stdout.lower(),(r['binary'],bad)
summary=json.loads((out/'census-partial.json').read_text());summary['retained_failed_attempts']=['First sharing driver reference inserted an absent NoPE mask','First identity comparison omitted full source directory restoration'];summary['scope']=dict(old_mojo=len(old),final_mojo=len(now),old_python=84,final_python=85,old_modified=sorted(allowed),old_python_edits=0,immutable_controls=152,qualified_affected=101,all_consumer_closure=len(closure),mojo_links=len(builds),c_links=len(cb),elf_tables=2*(len(builds)+len(cb)),inherited_warning_reviews=warnings,physical_calls=False,source_model_execution=False)
(out/'census.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
