# Explicit authorized sequencing: all linking completes before native execution.
from pathlib import Path
import json,subprocess,sys,time
root=Path('../sealed-gguf-native-development');status=root/'continuation-status.json'
def record(state,**kw):status.write_text(json.dumps({'state':state,**kw},indent=2)+'\n')
record('waiting_for_all_broad_builds',build_log=str(root/'build-final.log'))
start=time.monotonic()
while True:
 text=(root/'build-final.log').read_text()
 if '108 stable clean builds; no native tests executed during linking.' in text:break
 if 'Traceback (most recent call last):' in text:
  record('broad_build_failed',build_log=str(root/'build-final.log'));sys.exit(1)
 if time.monotonic()-start>10800:
  record('broad_build_wait_timeout');sys.exit(1)
 time.sleep(10)
for name,script in [('additional_semantic_leaf','build-semantic.py'),('native_verification','verify-final.py'),('new_trace_audit','audit-traces.py')]:
 record(name)
 with (root/(name+'.log')).open('w') as out:
  r=subprocess.run([sys.executable,str(root/script)],stdout=out,stderr=subprocess.STDOUT)
 if r.returncode:
  record(name+'_failed',returncode=r.returncode,log=str(root/(name+'.log')));sys.exit(r.returncode)
record('native_verification_and_new_trace_audit_complete_review_required',publication_performed=False,additional_legacy_audits_and_recording_required=True)
