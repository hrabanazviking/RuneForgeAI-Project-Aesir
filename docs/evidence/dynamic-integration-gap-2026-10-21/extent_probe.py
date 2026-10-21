"""Existing compiler metadata gates only; synthetic headers, never inference."""
import hashlib,json,struct,subprocess,sys
from pathlib import Path
sys.path.insert(0,'tests')
from test_hailo_ordinary_projection_schema import declared
from test_hailo_safetensors_inventory import fixture
p=Path('../dynamic-context-integration-study'); root=p/'root';root.mkdir(exist_ok=False)
config,roles=declared(heads=2,kv=1,dimension=4,explicit=True)
config.update(max_position_embeddings=8,rope_scaling={'rope_type':'dynamic','factor':2.0,'original_max_position_embeddings':4},no_rope_layers=[1,0])
(root/'config.json').write_text(json.dumps(config,ensure_ascii=False,separators=(',',':')))
raw,_,_=fixture([(name,'BF16',shape) for name,(_,shape) in roles.items()],metadata={'format':'pt'})
(root/'weights').write_bytes(raw)
end=8+struct.unpack_from('<Q',raw)[0]
identity=lambda q:dict(bytes=q.stat().st_size,sha256=hashlib.sha256(q.read_bytes()).hexdigest())
binary=Path('../decoder-dynamic-baseline/scaling-graph'); cases=[('within',1,8,'default',True),('capacity_above_source',1,9,'default',False),('positions_above_source',9,9,'default',False),('dynamic_inside',1,8,'dynamic',False),('dynamic_growth',9,9,'dynamic',False)]
rows=[]
for name,query,capacity,kind,accepted in cases:
 args=list(map(str,[binary,'unindexed',root,'weights','config.json',query,0,capacity,2,'1,0','0,0','0,0','source64','split_half',1000000,'explicit synthetic context separation audit','silu,silu','full_prefix',0,'0,0',kind,64,struct.unpack('<Q',struct.pack('<d',2.0 if kind=='dynamic' else 1.0))[0]]))
 result=subprocess.run(['strace','-f','-y','-qq','-e','trace=%file,%network,ioctl,pread64','-o',str(p/(name+'.strace')),*args],capture_output=True,text=True,timeout=60)
 (p/(name+'.stdout')).write_text(result.stdout);(p/(name+'.stderr')).write_text(result.stderr)
 assert (result.returncode==0)==accepted,(name,result.stderr)
 row=dict(name=name,query=query,capacity=capacity,scaling_kind=kind,returncode=result.returncode,stdout=identity(p/(name+'.stdout')),stderr=result.stderr)
 if accepted:
  j=json.loads(result.stdout);row['parameters']=j['lowered']['source_graph']['parameters'];assert j['ordinary_model_admitted'] is False
 else:
  assert result.stdout==''
  expected='bounded kind/work/provenance' if name=='dynamic_inside' else 'invalid session query/past/context extent'
  assert expected in result.stderr,(name,result.stderr)
 rows.append(row)
print(json.dumps(dict(cases=rows,source_config=config,header_extent=end,source_files={str(q):identity(q) for q in [root/'config.json',root/'weights']},binary=identity(binary),metadata_only=True,model_layer_attention_or_device_execution=False),indent=2))
