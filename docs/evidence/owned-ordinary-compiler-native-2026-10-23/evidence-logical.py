import re
def logical(raw):
 pending={};pending_raw={};out=[]
 for line in raw.splitlines():
  m=re.match(r'^(\d+)\s+(.*)$',line)
  if m:pid,body=m.groups()
  else:
   assert re.match(r'^(?:[A-Za-z_?][A-Za-z_0-9?]*\(|<\.\.\.|---|\+\+\+)',line),line
   pid,body='unprefixed-single-trace-scope',line
  resumed=re.match(r'<\.\.\. (\w+|\?\?\?) resumed>(.*)',body)
  if resumed:
   before=pending.pop(pid);pending_raw.pop(pid);assert before.startswith(resumed[1]+'('),(line,before)
   body=before+resumed[2]
   # strace can emit a resumed-but-unreturned call at exit_group termination.
   # Keep the literal incomplete tail as opaque; do not invent a return/effect.
   if '<unfinished ...>' in body:
    assert body.rstrip().endswith('= ?'),line
    out.append((pid,body));continue
  elif '<unfinished ...>' in body:
   assert pid not in pending,line
   pending[pid]=body.split('<unfinished ...>',1)[0];pending_raw[pid]=body;continue
  out.append((pid,body))
 # Preserve the literal unfinished tail; no return or effect is inferred.
 for pid in pending:out.append((pid,pending_raw[pid]))
 return out
