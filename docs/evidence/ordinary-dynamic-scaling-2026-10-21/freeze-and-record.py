from pathlib import Path
import hashlib,json,shutil,subprocess
out=Path('../decoder-dynamic-baseline');out.mkdir(exist_ok=False)
rows=json.loads(Path('../decoder-scaling-final/build-results.json').read_text());assert len(rows)==64
frozen=[]
for r in rows:
 p=Path(r['binary']);assert r['returncode']==0 and hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256'];target=out/p.name;shutil.copy2(p,target)
 assert hashlib.sha256(target.read_bytes()).hexdigest()==r['sha256'] and target.stat().st_mode==p.stat().st_mode
 frozen.append(dict(source=r['source'],binary=str(target),sha256=r['sha256'],mode=oct(target.stat().st_mode&0o777),returncode=0))
source=json.loads(Path('../decoder-scaling-final/source-hashes.json').read_text());assert len(source)==197 and all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
(out/'build-results.json').write_text(json.dumps(frozen,indent=2)+'\n');(out/'source-hashes.json').write_text(json.dumps(source,indent=2)+'\n');(out/'baseline.json').write_text(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),entrypoints=64,source_files=197,acceptance_methods=161,acceptance_calls=6387,model_execution=False,device_execution=False),indent=2)+'\n')
p=Path('../ordinary-dynamic-scaling-study');audit=json.loads((p/'audit.json').read_text());assert audit['case_count']==192 and audit['accepted']==144 and audit['refused']==48 and audit['constant_words']==432
for n,d in audit['identities'].items():assert (p/n).stat().st_size==d['bytes'] and hashlib.sha256((p/n).read_bytes()).hexdigest()==d['sha256'],n
receipt=Path('docs/evidence/ordinary-dynamic-scaling-2026-10-21');receipt.mkdir(exist_ok=True)
for n in ('constant_probe.py','constants.json','errors.txt','audit.json'):shutil.copyfile(p/n,receipt/n)
for n in ('build-results.json','source-hashes.json','baseline.json'):shutil.copyfile(out/n,receipt/('frozen-'+n))
shutil.copyfile('../prepare-dynamic-followup.py',receipt/'freeze-and-record.py')
archive=[dict(path=str(f.resolve()),bytes=f.stat().st_size,mode=oct(f.stat().st_mode&0o777),sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in sorted(p.rglob('*')) if f.is_file()];(receipt/'archive-identities.json').write_text(json.dumps(archive,indent=2)+'\n')
(receipt/'README.md').write_text('''# Dynamic constant/context qualification and frozen compiler controls

192 pinned test-only static initializer cases:144 return432 Float32 words,
48 raise width2 division errors inside the public initializer. Errors are separated
from independent candidate checks; the earlier wider exception-scope script and
its matching outputs/traces remain separately archived. This is not model validity,
native dynamic support, cache-transition semantics or device numerical proof.
No weights, module/layer/attention/model forward, network or Hailo access.

All64 accepted compiler controls were copied with modes/hashes before further
production edits;197 Mojo source hashes are unchanged. Prior local acceptance
161 methods/6387 calls. No new native capability is claimed by this receipt.
Full traces/executables/licenses remain outside Git with exact identities.
''')
text=(p/'audit-draft.md').read_text().replace('Draft for the next source-semantic slice after default/linear publication.','Date:2026-10-21. Follow-up after published default/linear implementation5626f2d.')
text+='\n## Frozen controls and next task\n\nAll64 accepted entrypoints and197 current Mojo source identities are frozen\nbefore further code. Parent TASK_hailo10h_ordinary_scaling_semantics.md and\nchild TASK_hailo10h_dynamic_scaling_semantics.md remain active. No new native\ncapability ID, model validity, context-extension quality or hardware result is\nclaimed. Exact scripts/results/negative/trace/control identities are retained\nunder docs/evidence/ordinary-dynamic-scaling-2026-10-21.\n'
Path('docs/HAILO10H_ORDINARY_DYNAMIC_SCALING_AUDIT.md').write_text(text)
Path('TASK_hailo10h_dynamic_scaling_semantics.md').write_text('''# Original dynamic rotary context and cache-basis semantics

Date:2026-10-21. Parent TASK_hailo10h_ordinary_scaling_semantics.md. Owner scope:
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Continue automatically.

Starting public/isolated facts:docs/HAILO10H_ORDINARY_DYNAMIC_SCALING_AUDIT.md.
192 constant-only cases/432 Float32 words qualify a bounded context-dependent
candidate and explicit public-initializer errors, not full source execution.
All64 currently accepted compiler controls and197 Mojo identities are frozen
before further production changes. Preserve them and complete older outputs.

Qualify actual source original/configured/effective context intent, length
None/zero/threshold/growth/shrink, partial widths, exact scalar words, NoPE and
source/default/nested/custom/legacy provenance. Determine the intended relationship
between already cached K and a changed rotary basis using primary declarations
and isolated constant/index/toy mathematical identities only. Static helper calls
cannot qualify a stateful wrapper or source-model cache transition. Public width2
initializer division errors are implementation work, never a permanent model or
hardware eligibility restriction. Keep original raw/unresolved facts intact.

Before native edits publish an exact original owned policy/API/source projection,
mathematical frequency/position/cache-basis rule, recipe maps/domains/lifetimes,
storage/accounting and independent acceptance contract. Do not silently reuse
old-basis keys or turn full-prefix-only support into a permanent target change.
Other architectures/formats/operations/scaling/training modifiers remain required
work toward broad support. Only the owner can change that target.

No model/layer/attention forward, source payload evaluation, CPU/CUDA/cloud LLM
inference, proxy, DFC/outside model compiler/machine or special conversion. Host
parsing/Aesir internal compilation/orchestration and isolated tiny oracles are
permitted. Keep numerical Hailo precision/packing/placement/register/CCW/configuration,
original delivery/activation/results/cleanup active alongside source semantics.
No invented instructions or kernel/firmware/reset/rebind changes. Verify each
slice, publish, verify remote heads, sync main and continue automatically.
''')
p=Path('TASK_hailo10h_ordinary_scaling_semantics.md');p.write_text(p.read_text()+'''
2026-10-21 next child TASK_hailo10h_dynamic_scaling_semantics.md: qualified192
static initializer cases/432 external Float32 words and froze64 controls/197 source
identities. docs/HAILO10H_ORDINARY_DYNAMIC_SCALING_AUDIT.md. No native dynamic or
cache-transition acceptance. Publish exact original contract before next code.
''')
p=Path('docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md');s=p.read_text().replace('`TASK_hailo10h_ordinary_scaling_semantics.md`; dynamic/context/cache-basis, other variants and training semantics require original qualification/contracts/implementation.','`TASK_hailo10h_dynamic_scaling_semantics.md`;192 static initializer cases/432 external words and64 frozen controls. Dynamic/cache-basis/other variants/training require original contracts/implementation.');p.write_text(s)
print('Dynamic qualification/control receipt prepared; source unchanged')
