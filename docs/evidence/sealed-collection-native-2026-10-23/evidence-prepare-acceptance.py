from pathlib import Path
import hashlib,json
out=Path('../sealed-collection-native-acceptance').resolve();final=Path('../sealed-collection-native-final').resolve();h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=json.load(open(final/'build-results.json'));cur={r['source']:r['binary'] for r in rows};primary=json.load(open('../sealed-collection-native-baseline/controls.json'));frozen={r['source']:r['binary'] for r in primary}
aux=json.load(open('../sealed-safetensors-native-recording/inherited-auxiliary-input-continuity-before-reviewed.json'))
for r in aux:assert h(Path(r['path']))==r['sha256'],r
root_api=next(r for r in aux if r['path']=='../source-root-api');frozen['tests/hailo_source_root_api.mojo']=str(Path(root_api['path']).resolve())
pairs={v:frozen[k] for k,v in cur.items() if k in frozen};assert len(pairs)==12
(out/'universe.json').write_text(json.dumps(dict(current=cur,frozen=frozen,pairs=pairs,additional_historical_root_control=root_api),indent=2)+'\n')
oldmap={r['binary']:cur[r['source']] for r in primary if r['source'] in cur};oldmap.update({str(Path('../source-root-api')):cur['tests/hailo_source_root_api.mojo']})
jobs=[]
for job in json.load(open('../sealed-safetensors-native-acceptance-v2/jobs.json')):
 if job['suite'] not in ('source_root','shard_collection','unindexed_source','sealed-copy','sealed-safetensors'):continue
 job['args']=[oldmap.get(v,v) for v in job['args']]
 for flag,name in [('--copy-faults','source_sealed_copy_faults'),('--mutation-faults','sealed_safetensors_mutation')]:
  if flag in job['args']:job['args'][job['args'].index(flag)+1]=str(final/(name+'.so'))
 if job['suite'] in ('source_root','sealed-copy','sealed-safetensors'):
  flag='--faults';name={'source_root':'source_root_io_faults','sealed-copy':'source_sealed_copy_faults','sealed-safetensors':'sealed_gguf_faults'}[job['suite']];job['args'][job['args'].index(flag)+1]=str(final/(name+'.so'))
 job['args'][job['args'].index('--evidence')+1]=str(out/job['suite']);jobs.append(job)
meta=next(x for x in json.load(open('../sealed-metadata-native-acceptance-v2/jobs.json')) if x['suite']=='sealed-metadata')
meta['args']=[oldmap.get(v,v) for v in meta['args']]
meta['args'][meta['args'].index('--evidence')+1]=str(out/'sealed-metadata')
for flag,name in [('--faults','sealed_metadata_faults'),('--copy-faults','source_sealed_copy_faults'),('--mutation-faults','sealed_safetensors_mutation')]:meta['args'][meta['args'].index(flag)+1]=str(final/(name+'.so'))
jobs.append(meta)
args=['--binary',cur['smidr/tools/sealed_source_collection.mojo'],'--api',cur['tests/hailo_sealed_collection_api.mojo'],'--indexed-control',frozen['smidr/tools/shard_collection.mojo'],'--unindexed-control',frozen['smidr/tools/unindexed_source.mojo'],'--faults',str(final/'sealed_collection_faults.so'),'--strace','/usr/bin/strace','--evidence',str(out/'sealed-collection')]
jobs.append(dict(suite='sealed-collection',python='/usr/bin/python3',script='tests/test_hailo_sealed_source_collection.py',args=args))
(out/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
