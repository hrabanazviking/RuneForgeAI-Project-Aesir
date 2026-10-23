from pathlib import Path
p=Path('../owned-ordinary-binding-native-development/prepare-acceptance.py')
s=p.read_text().replace("Path('../owned-ordinary-binding-native-acceptance')","Path('../owned-ordinary-binding-native-acceptance-v2')")
exec(compile(s,str(p),'exec'))
out=Path('../owned-ordinary-binding-native-acceptance-v2');p=out/'pair-all.py';s=p.read_text()
s=s.replace(" if qualifies:\n  for v in c[found[0]+1:]:", " if qualifies and identities[found[1]]['source'] in ('tests/hailo_sealed_collection_api.mojo','smidr/tools/sealed_source_collection.mojo'):\n  offset=3 if identities[found[1]]['source'].startswith('tests/') else 2\n  path=c[found[0]+offset];trees[path]=tree(path)\n if qualifies:\n  for v in c[found[0]+1:]:")
a=s.index("  if opts.get('env') and 'AESIR_SEAL_FAULT_LOG' in opts['env']:")
b=s.index('  for v in changed:',a)
s=s[:a]+'''  if opts.get('env'):
   control_env=dict(opts['env'])
   for envkey,value in opts['env'].items():
    if envkey.startswith('AESIR_') and envkey.endswith('_LOG') and Path(value).is_file():
     primary_log=Path(value);control_log=Path(str(primary_log)+'.frozen-control')
     assert not control_log.exists(),control_log
     control_env[envkey]=str(control_log)
     control_log_pairs.append((primary_log,control_log,primary_log.read_bytes()))
   opts['env']=control_env
'''+s[b:]
p.write_text(s)
p=Path('../owned-ordinary-binding-native-development/run-acceptance.py');s=p.read_text().replace("Path('../owned-ordinary-binding-native-acceptance')","Path('../owned-ordinary-binding-native-acceptance-v2')").replace(",*job['args'],'-v']",",*job['args']]")
Path('../owned-ordinary-binding-native-development/run-acceptance-v2.py').write_text(s)
