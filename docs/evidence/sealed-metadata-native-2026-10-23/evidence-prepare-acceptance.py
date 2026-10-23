from pathlib import Path
import json
out=Path('../sealed-metadata-native-acceptance').resolve();final=Path('../sealed-metadata-native-final').resolve()
rows=json.load(open(final/'build-results.json'));cur={r['source']:r['binary'] for r in rows}
frozen={r['source']:r['binary'] for r in json.load(open('../sealed-metadata-native-baseline/controls.json')) if r['source'] in cur}
universe=dict(current=cur,frozen=frozen,pairs={cur[k]:v for k,v in frozen.items()})
(out/'universe.json').write_text(json.dumps(universe,indent=2)+'\n')
oldmap={r['binary']:cur[r['source']] for r in json.load(open('../sealed-metadata-native-baseline/controls.json')) if r['source'] in cur}
jobs=[]
for job in json.load(open('../sealed-safetensors-native-acceptance-v2/jobs.json')):
 if job['suite'] not in ('source_config','source_index','sealed-copy'):continue
 job['args']=[oldmap.get(v,v) for v in job['args']]
 i=job['args'].index('--evidence');job['args'][i+1]=str(out/job['suite'])
 if '--faults' in job['args']:
  i=job['args'].index('--faults');job['args'][i+1]=str(final/('source_index_io_faults.so' if job['suite']=='source_index' else 'source_sealed_copy_faults.so'))
 jobs.append(job)
args=['--binary',cur['smidr/tools/sealed_source_metadata.mojo'],'--api',cur['tests/hailo_sealed_metadata_api.mojo'],'--config-control',frozen['smidr/tools/source_config.mojo'],'--index-control',frozen['smidr/tools/source_index.mojo'],'--faults',str(final/'sealed_metadata_faults.so'),'--copy-faults',str(final/'source_sealed_copy_faults.so'),'--mutation-faults',str(final/'sealed_safetensors_mutation.so'),'--strace','/usr/bin/strace','--evidence',str(out/'sealed-metadata')]
jobs.append(dict(suite='sealed-metadata',python='/usr/bin/python3',script='tests/test_hailo_sealed_source_metadata.py',args=args))
(out/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
