from pathlib import Path
# Reuse exact verified predecessor target list and independent regression commands.
base=Path('../decoder-window-final-build.py').read_text()
a=base.index('pairs=');b=base.index('manifest=',a)
base=base[:a]+'''pairs=[(r["source"],Path(r["binary"]).name) for r in json.loads(Path("../decoder-scaling-baseline/build-results.json").read_text())]+[(r["source"],Path(r["binary"]).name) for r in json.loads(Path("../decoder-scaling-initial/build-results.json").read_text())]
assert len(pairs)==64
'''+base[b:]
base=base.replace("../decoder-window-final","../decoder-scaling-final")
Path('../decoder-scaling-final-build.py').write_text(base)
for stem in ('regressions','extra-verify','other-regressions'):
 s=Path('../decoder-window-'+stem+'.py').read_text().replace('decoder-window-final','decoder-scaling-final').replace('decoder-window-regression-accepted','decoder-scaling-regression-accepted').replace('decoder-window-extra-accepted','decoder-scaling-extra-accepted').replace('decoder-window-other-accepted','decoder-scaling-other-accepted')
 Path('../decoder-scaling-'+stem+'.py').write_text(s)
s=Path('../verify-window-final.py').read_text().replace('decoder-window-final','decoder-scaling-final').replace("len(rows)==58","len(rows)==64")
s=s.replace('decoder-window-regressions.py','decoder-scaling-regressions.py').replace('decoder-window-extra-verify.py','decoder-scaling-extra-verify.py').replace('decoder-window-other-regressions.py','decoder-scaling-other-regressions.py').replace('decoder-window-accepted','decoder-scaling-accepted')
a=s.index('\nresults=[]')
new='''
commands.append(('decoder_scaling',['python3','tests/test_hailo_decoder_scaling.py','--binary',str(build/'scaling-graph'),'--api',str(build/'scaling-api'),'--source',str(build/'scaling-source'),'--ownership',str(build/'scaling-ownership'),'--gguf',str(build/'scaling-gguf'),'--policy',str(build/'scaling-policy'),'--frozen-api','../decoder-scaling-baseline/window-api','--frozen-binary','../decoder-scaling-baseline/window-graph','--frozen-gguf','../decoder-scaling-baseline/window-gguf','--oracle','../ordinary-scaling-study/config.json','--constant-oracle','../ordinary-scaling-study/linear-constants.json']))
'''
s=s[:a]+new+s[a:]
Path('../verify-scaling-final.py').write_text(s)
