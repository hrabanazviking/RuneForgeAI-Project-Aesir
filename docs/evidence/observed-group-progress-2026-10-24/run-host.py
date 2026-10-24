from pathlib import Path
import json,hashlib,subprocess,os,shutil
repo=Path.cwd();base=repo.parent/'soc-observed-progress-baseline';final=repo.parent/'soc-observed-progress-final-v3';out=repo.parent/'soc-observed-progress-host';out.mkdir(exist_ok=False);h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert (final/'stable.json').exists()
for name in ['source-hashes.json','test-input-hashes.json']:
 for p,d in json.loads((final/name).read_text()).items():assert h(Path(p))==d
rows=json.loads((final/'build-results.json').read_text());old=json.loads((base/'build-results.json').read_text());current={r['source']:r['binary'] for r in rows};frozen={r['source']:r['binary'] for r in old}
pairs={current['tests/hailo_soc_progress.mojo']:frozen['tests/hailo_soc_progress.mojo']}
for i in range(2):pairs[rows[i]['binary']]=str((final/f'frozen-{i:03d}').resolve());assert h(Path(rows[i]['binary']))==h(final/f'frozen-{i:03d}')
known={r['binary']:r['source'] for r in rows};traced=[rows[i]['binary'] for i in range(2)];(out/'meta.json').write_text(json.dumps(dict(known=known,pairs=pairs,traced=traced),indent=2)+'\n')
shutil.copyfile(repo.parent/'soc-prepare-native-host/record.py',out/'record.py')
jobs=[('observed','tests/test_hailo_soc_exchange_progress.py',['--binary',rows[0]['binary'],'--api',rows[1]['binary']]),('legacy','tests/test_hailo_soc_progress.py',['--binary',current['tests/hailo_soc_progress.mojo']])]
results=[]
for name,script,args in jobs:
 cmd=['python3',str(out/'record.py'),str(out/(name+'-raw')),script,*args,'-v']
 with (out/(name+'.stdout')).open('wb') as a,(out/(name+'.stderr')).open('wb') as b:r=subprocess.run(cmd,stdout=a,stderr=b,timeout=600,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
 results.append(dict(suite=name,arguments=cmd,returncode=r.returncode));(out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(name,r.returncode,flush=True)
assert all(r['returncode']==0 for r in results)
