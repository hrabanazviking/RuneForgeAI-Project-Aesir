from pathlib import Path
import hashlib,json,subprocess,shutil
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
root=Path('../q2q3-native-development');p=Path('tests/hailo_q2q3_layout_oracle.cpp');before=sha(p)
assert before==json.loads(Path('../q2q3-native-final/input-hashes.json').read_text())[str(p)]
shutil.copyfile(p,root/'layout-oracle-initial-uncompiled.cpp')
s=p.read_text().replace('#include "ggml.h"','#define GGML_COMMON_DECL_CPP\n#include "ggml.h"').replace('offsetof(block_q2_K,d)','offsetof(block_q2_K,data.data.d)').replace('offsetof(block_q2_K,dmin)','offsetof(block_q2_K,data.data.dmin)');p.write_text(s)
(root/'cpp-amendment.json').write_text(json.dumps({'path':str(p),'before_sha256':before,'after_sha256':sha(p),'reason':'Test-only public-header declaration macro and Q2 anonymous-union member paths reviewed after all Mojo closure builds. Initial scaffold was not compiled/executed; all frozen Mojo and Python inputs remain unchanged.'},indent=2)+'\n')
cmd=['c++','-std=c++17','-Wall','-Wextra','-Werror','-I','../ggml-format-study/source/include','-I','../ggml-format-study/source/src',str(p),'-o',str(root/'layout-oracle')]
r=subprocess.run(cmd,capture_output=True,text=True)
(root/'layout-build.txt').write_text(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout+r.stderr,(r.returncode,r.stdout,r.stderr)
r=subprocess.run([str(root/'layout-oracle')],capture_output=True,text=True,check=True)
assert json.loads(r.stdout)==[[10,256,84,0,16,80,82],[11,256,110,0,32,96,108]]
(root/'layout-oracle.json').write_text(r.stdout)
r=subprocess.run(['../model-root-study/layout'],capture_output=True,text=True,check=True)
assert json.loads(r.stdout)['size']==24
(root/'root-layout.json').write_text(r.stdout)
(root/'header-oracles-status.json').write_text(json.dumps({'build_command':cmd,'returncode':0,'diagnostic_bytes':0,'layout_source_sha256':sha(p),'layout_binary_sha256':sha(root/'layout-oracle'),'root_layout_binary_sha256':sha('../model-root-study/layout'),'root_layout_output_sha256':sha(root/'root-layout.json')},indent=2)+'\n')
print('Independent Q2/Q3 public-header object and real public UAPI layout outputs verified')
