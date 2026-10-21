import json,hashlib,re,math
from pathlib import Path
p=Path('.'); data=json.loads((p/'meta-constructor-final.json').read_text())
assert data['transformers_version']=='4.57.1' and len(data['cases'])==12
assert data['module_forward_calls']==[] and not data['layer_or_attention_forward']
for c in data['cases']:
    assert 'error' not in c
    dims=c['configuration_dimensions']; h=dims['hidden_size']; ff=dims['intermediate_size']; q=dims['num_attention_heads']; kv=dims['num_key_value_heads']
    d=c['updates'].get('head_dim',h//q)
    assert c['attention_attributes']['head_dim']==d
    assert c['attention_attributes']['num_key_value_groups']==q//kv
    assert c['attention_attributes']['scaling']==d**-0.5
    attention={k+'.weight':v for k,v in {'q_proj':[q*d,h],'k_proj':[kv*d,h],'v_proj':[kv*d,h],'o_proj':[h,q*d]}.items()}
    mlp={k+'.weight':v for k,v in {'gate_proj':[ff,h],'up_proj':[ff,h],'down_proj':[h,ff]}.items()}
    if c['updates'].get('attention_bias',False): attention.update({k.replace('weight','bias'):[s[0]] for k,s in list(attention.items())})
    if c['updates'].get('mlp_bias',False): mlp.update({k.replace('weight','bias'):[s[0]] for k,s in list(mlp.items())})
    for label,expected in [('attention',attention),('mlp',mlp),('norm',{'weight':[h]})]:
        actual=c['parameter_headers'][label]
        assert {k:v['shape'] for k,v in actual.items()}==expected
        assert all(v['is_meta'] and v['device']=='meta' for v in actual.values())
    assert c['norm_constructor_dim']==h
    assert c['activation_class']==('GELUActivation' if c['updates'].get('hidden_act')=='gelu' else 'SiLUActivation')
trace=(p/'meta-constructor-final.strace').read_text()
assert not re.search(r'\bconnect\(',trace)
assert not re.search(r'openat2?\([^\n]*(/dev/h1x|/dev/hailo|[^\" ]+\.safetensors\"|pytorch_model[^\" ]+\.bin|[^\" ]+\.gguf\")',trace)
assert (p/'meta-constructor-final-stderr.txt').stat().st_size==0
licenses=[]
for path in [p/'config-4.57.1-venv/lib/python3.11/site-packages/transformers-4.57.1.dist-info/licenses/LICENSE',Path('/home/pi/.local/lib/python3.11/site-packages/torch-2.11.0+cpu.dist-info/licenses/LICENSE')]:
    if not path.exists() and 'transformers' in str(path): path=path.parent.parent/'LICENSE'
    raw=path.read_bytes(); licenses.append(dict(path=str(path.resolve()),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
assert licenses[0]['sha256']=='77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049'
assert licenses[1]['sha256']=='a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4'
audit=dict(cases=12,parameter_shapes_checked=True,all_parameters_meta=True,module_forward_calls=[],direct_forward_guard=True,connect_calls=0,hailo_device_open=False,source_weights_loaded=False,full_model_instantiated=False,numerical_forward_semantics_verified=False,licenses=licenses)
(p/'meta-constructor-final-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
identities=[]
for path in sorted(p.glob('*constructor*')):
    if path.is_file() and path.name!='meta-constructor-archive-identities.json':
        raw=path.read_bytes(); identities.append(dict(path=str(path.resolve()),bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
(p/'meta-constructor-archive-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
print(json.dumps(audit,indent=2))
