from pathlib import Path
import json
root=Path('../iq4-native-development');out=Path('../iq4-native-acceptance')
commands=json.loads(Path('../q2q3-native-development/commands.json').read_text())
for row in commands:
 row[1]=[x.replace('q2q3-native-final','iq4-native-final').replace('q2q3-native-acceptance','iq4-native-acceptance') for x in row[1]];row[2]=True
q=next(x for x in commands if x[0]=='q2q3');new=['iq4',[x.replace('source_q2q3_constants.py','source_iq4_constants.py').replace('/q2q3-constants','/iq4-constants').replace('/q2q3-api','/iq4-api') for x in q[1]],False];new[1][new[1].index('--evidence')+1]=str(out/'iq4');commands.insert(0,new);assert len(commands)==43
(root/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
s=Path('../q2q3-native-review/pair-reviewed.py').read_text();a=s.index("rows=json.loads(");b=s.index('real=subprocess.run;records=[]')
s=s[:a]+'''rows=json.loads(Path('../iq4-native-final/build-results.json').read_text())
controls=json.loads(Path('../iq4-native-baseline/controls.json').read_text())
old={x['source']:x for x in controls}
pairs={x['binary']:str((root/old[x['source']]['binary']).resolve()) for x in rows if x['source'] in old}
for x in rows:
 if x['binary'] in pairs:pairs[str(Path('../iq4-native-final')/Path(x['binary']).name)]=pairs[x['binary']]
'''+s[b:];(root/'pair-frozen.py').write_text(s)
