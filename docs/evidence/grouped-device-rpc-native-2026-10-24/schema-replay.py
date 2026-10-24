# Review copy;exact executed script pinned in raw archive.
from pathlib import Path
from collections import Counter
import json,struct,re
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory
repo=Path.cwd();work=repo.parent;out=work/'grouped-device-rpc-native-schema-replay';out.mkdir(exist_ok=False);schema=work/'grouped-device-rpc-native-schema';pool=descriptor_pool.DescriptorPool()
for f in descriptor_pb2.FileDescriptorSet.FromString((schema/'current.stdout').read_bytes()).file:pool.AddSerializedFile(f.SerializeToString())
def msg(name):return message_factory.GetMessageClass(pool.FindMessageTypeByName(name))()
def packet(mid,action,message,status):
 body=message.SerializeToString();return (struct.pack('<5I',0x8a554432,len(body),mid,action,status)+body+bytes(2048-len(body))).hex()
runs=json.loads((work/'grouped-device-rpc-native-host-v6/runs/runs.json').read_text());n=0;logical=Counter()
for i,r in enumerate(runs):
 if r['label']!='current':continue
 handle=r['handle'];create=msg('Device_Create_Reply');create.device_handle.id=handle;identity=msg('Device_Identify_Reply');v=identity.identity;v.protocol_version=2;v.fw_version.major_value=5;v.fw_version.minor_value=3;v.fw_version.revision_value=7;v.logger_version=4;v.device_architecture=6
 for mid,action in enumerate([20,22,21,21]):
  request=msg('Device_Create_Request' if mid==0 else ('Device_Identify_Request' if mid==1 else 'Device_Destroy_Request'))
  if mid:request.device_handle.id=handle
  reply=create if mid==0 else (identity if mid==1 else msg('Device_Destroy_Reply'))
  expected=packet(mid,action,request,1);assert r['fixtures']['AESIR_DEVICE_REQUEST'+str(mid)]==expected;n+=1
  expected=packet(mid,action,reply,0);assert r['fixtures']['AESIR_DEVICE_GOODREPLY'+str(mid)]==expected;n+=1
  if not r['typed'] or str(mid) not in r['typed']:assert r['fixtures']['AESIR_DEVICE_REPLY'+str(mid)]==expected;n+=1
 stdout=(work/'grouped-device-rpc-native-host-v6/runs'/f'{i}.stdout').read_text();outcomes=[json.loads(s) for s in stdout.splitlines() if s.startswith('{')]
 for generation in sorted({e['generation'] for e in r['events'] if e['op']=='opened'}):
  if generation>len(outcomes):continue  # Failed establishment has its own older client regression gate.
  j=outcomes[generation-1]
  if generation>1:assert j['success'] and j['destroy_confirmed'] and j['attempts']==3
  events=[e for e in r['events'] if e['generation']==generation];wire_ids=[int.from_bytes(bytes.fromhex(e['hex'])[8:12],'little') for e in events if e['op']=='wire'];assert wire_ids in ([],[0],[0,1],[0,1,2],[0,1,3]);assert j['attempts']<=3 and len(wire_ids)<=j['attempts'];logical['outcomes']+=1
  if j['handle_known']:assert j['handle']==handle
  if j['cleanup_attempted']:
   assert j['handle_known'] and j['destroy_attempted'];assert 'BadRpcProtobuf' in bytes.fromhex(j['primary_hex']).decode();assert 2 not in wire_ids;logical['single_cleanup_attempts']+=1
  if j['destroy_confirmed']:
   assert j['destroy_attempted'] and j['handle_known'] and wire_ids[-1] in (2,3);logical['confirmed_logical_destroys']+=1
   clocks=[e['b'] for e in events if e['op']=='clock'];assert clocks and all(0<=t-clocks[0]<1000 for t in clocks)
  if j['finalization_unconfirmed']:
   assert j['retained_views']==2 and j['close_hex'];assert sum(e['op']=='file_close_attempt' for e in events)==1;assert not any(e['op']=='release_attempt' for e in events);logical['unconfirmed_file_contexts']+=1
# Account for actual schema-oracle child file generations independently.
aux=Counter()
for label in ('current','frozen'):
 live={};text=(schema/f'{label}.strace').read_text();pending={};calls=[]
 for line in text.splitlines():
  pid,b=line.split(' ',1);b=b.lstrip();assert pid.isdigit()
  if b.endswith('<unfinished ...>'):pending[pid]=b.removesuffix('<unfinished ...>').rstrip()
  elif b.startswith('<... ') and ' resumed>' in b:calls.append(pending.pop(pid)+b.split(' resumed>',1)[1])
  else:calls.append(b)
 assert not pending and sum(b.startswith('execve(') for b in calls)==1
 for b in calls:
  assert re.match(r'^(?:\w+\(|--- |\+\+\+ )',b) and not b.startswith('syscall_0x');assert not b.startswith(('ioctl(','connect(')) and not re.search(r'openat\(.*"/dev/(?:h1x-|hailo)',b)
  m=re.match(r'(?:openat|memfd_create)\(.*\)\s+= (\d+)<',b)
  if m:fd=int(m[1]);assert fd not in live;live[fd]=b;aux['file_fd_generations']+=1
  m=re.match(r'close\((\d+).*\)\s+= 0$',b)
  if m:fd=int(m[1]);assert fd in live;live.pop(fd);aux['file_fd_closes']+=1
 assert not live;aux['traces']+=1
result=dict(actual_schema_fixture_checks=n,logical_policy=dict(logical),auxiliary=dict(aux),full_auxiliary_pairs=1,field_definitions_from_actual_pinned_proto=True,model_compiler=False,production_protobuf_dependency=False,physical_calls=False);(out/'census.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
