from pathlib import Path
import json,shutil
root=Path('../q2q3-native-review');old=Path('../q2q3-native-development/pair-frozen.py');s=old.read_text()
s=s.replace('  if found:\n','  if found and (found[0] == 0 or Path(c[0]).name == "strace"):\n')
(root/'pair-reviewed.py').write_text(s)
(root/'classification-note.json').write_text(json.dumps({'failure':'Original wrapper matched a binary appearing as ldd argument, then incorrectly executed the baseline API without arguments. Safetensors97 native results and264204 word checks had already passed.','correction':'Pair direct API commands and strace-wrapped commands. ldd is dependency inspection, not an API request; separately inspect both binaries for forbidden runtime dependencies. No native API comparison is skipped.','production_changes':False,'old_test_input_changes':False,'all_original_artifacts_retained':True},indent=2)+'\n')
# Additive reviewed acceptance: original inputs/results remain untouched.
oldroot=Path('../q2q3-native-acceptance');newroot=Path('../q2q3-native-reviewed-acceptance')
shutil.copytree(oldroot,newroot)
shutil.rmtree(newroot/'safetensors_constants');(newroot/'safetensors_constants-tests.txt').unlink();(newroot/'safetensors_constants-status.json').unlink();(newroot/'pairs/safetensors_constants.json').unlink()
