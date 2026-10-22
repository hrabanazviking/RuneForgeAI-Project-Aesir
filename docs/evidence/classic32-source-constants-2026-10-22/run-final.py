import subprocess,sys
for script in ('build-final.py','verify-final.py'):
 p=subprocess.run([sys.executable,'../classic32-source-development/'+script])
 if p.returncode:sys.exit(p.returncode)
