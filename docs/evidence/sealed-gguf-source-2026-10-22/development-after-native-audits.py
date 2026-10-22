from pathlib import Path
import json,subprocess,sys,time
root=Path('../sealed-gguf-native-development');status=root/'additional-audits-status.json'
def record(state,**kw):status.write_text(json.dumps({'state':state,**kw},indent=2)+'\n')
record('waiting_for_existing_native_verification_and_new_trace_audit')
start=time.monotonic()
while True:
 current=json.loads((root/'continuation-status.json').read_text());state=current['state']
 if state=='native_verification_and_new_trace_audit_complete_review_required':break
 if state.endswith('_failed') or state.endswith('_timeout'):
  record('prior_stage_failed_review_required',prior=current);sys.exit(1)
 if time.monotonic()-start>14400:
  record('wait_timeout_review_required');sys.exit(1)
 time.sleep(10)
for name in ('audit-old-copy.py','audit-old-digest.py','audit-all-legacy.py'):
 record('running',script=name)
 with (root/(name+'.log')).open('w') as f:r=subprocess.run([sys.executable,str(root/name)],stdout=f,stderr=subprocess.STDOUT)
 if r.returncode:
  record('audit_failed_review_required',script=name,returncode=r.returncode);sys.exit(r.returncode)
record('all_legacy_audits_passed_review_and_publication_required',publication_performed=False)
