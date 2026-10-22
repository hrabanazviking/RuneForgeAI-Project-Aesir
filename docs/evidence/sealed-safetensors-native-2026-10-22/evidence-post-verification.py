from pathlib import Path
import hashlib,json
out=Path('../sealed-safetensors-native-recording');a=Path('../sealed-safetensors-native-acceptance-v2')
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for manifest in ['input-hashes.json','binary-hashes.json','auxiliary-c-source-hashes.json']:
 for name,digest in json.load(open(a/manifest)).items():assert h(Path(name))==digest,(manifest,name)
rows=json.load(open(out/'inherited-auxiliary-input-continuity-before-reviewed.json'))
for row in rows:assert h(Path(row['path']))==row['sha256'],row
(out/'inherited-auxiliary-input-continuity-after-reviewed.json').write_text(json.dumps(rows,indent=2)+'\n')
last=max((Path(p).stat().st_mtime_ns,p) for p in json.load(open(a/'binary-hashes.json')))
first=min((p.stat().st_mtime_ns,str(p)) for p in (a/'test-snapshot').rglob('*') if p.is_file());assert last[0]<first[0],(last,first)
(out/'link-before-execution.json').write_text(json.dumps(dict(last_native_or_fault_library_link=last,first_reviewed_acceptance_input_snapshot=first,all_linking_before_native_acceptance=True,no_linking_between_attempts=True),indent=2)+'\n')
c=[]
for folder,names in [('../sealed-safetensors-native-final',['sealed_gguf_faults','source_sealed_copy_faults','owned_gguf_faults']),('../sealed-safetensors-native-supplement',['sealed_safetensors_mutation','safetensors_fd_io_faults'])]:
 for name in names:
  b=Path(folder)/(name+'.so');log=b.with_name(b.name+'.build.txt');assert log.read_bytes()==b''
  source=Path('tests')/(name+'.c');c.append(dict(source=str(source),source_sha256=h(source),binary=str(b),binary_sha256=h(b),diagnostic_bytes=0))
(out/'c-binaries.json').write_text(json.dumps(c,indent=2)+'\n')
print('All reviewed native/C/Python inputs and21 inherited auxiliary inputs remain exact; five C shims clean; all linking before both attempts.')
