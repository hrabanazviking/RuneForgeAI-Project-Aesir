from pathlib import Path
import hashlib,json,subprocess
out=Path('../owned-ordinary-binding-native-final-v3');src=Path('tests/safetensors_fd_io_faults.c');b=out/'safetensors_fd_io_faults.so';cmd=['cc','-Wall','-Wextra','-Werror','-shared','-fPIC','-O2',str(src),'-ldl','-o',str(b)];r=subprocess.run(cmd,capture_output=True);(out/'safetensors_fd_io_faults-build.txt').write_bytes(r.stdout+r.stderr);assert r.returncode==0 and not r.stdout and not r.stderr,(r.returncode,r.stdout,r.stderr)
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();rows=json.load(open(out/'c-build-results.json'));assert len(rows)==8
rows.append(dict(source=str(src),source_sha256=h(src),binary=str(b.resolve()),binary_sha256=h(b),returncode=r.returncode,diagnostic_bytes=0,arguments=cmd));(out/'c-build-results.json').write_text(json.dumps(rows,indent=2)+'\n');print('Supporting fd fault seam rebuilt from exact current source; 9 clean C builds')
