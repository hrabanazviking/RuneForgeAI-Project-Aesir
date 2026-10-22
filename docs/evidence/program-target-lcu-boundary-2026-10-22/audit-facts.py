"""Original declarative audit of pinned public field facts; no vendor code runs."""
import argparse,hashlib,json,re
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('source');ap.add_argument('output');a=ap.parse_args()
r=Path(a.source)
p=(r/'hailort/libhailort/hef.proto').read_text()
h=(r/'hailort/libhailort/include/hailo/hailort.h').read_text()
d=(r/'hailort/libhailort/src/device_common/device_internal.cpp').read_text()
f=(r/'hailort/libhailort/src/hef/hef.cpp').read_text()
c=(r/'common/include/context_switch_defs.h').read_text()
assert re.search(r'PROTO__HW_ARCH__HAILO1XH\s*=\s*103;',p)
assert re.search(r'//\s*PROTO__HW_ARCH__HAILO10H\s*=\s*5;\s*// Deprecated',p)
assert 'ProtoHEFHwArch hw_arch = 1;' in p
assert 'uint32 partial_clusters_layout_bitmap = 1;' in p
assert 'return {HAILO_ARCH_HAILO15H, HAILO_ARCH_HAILO10H};' in d
assert 'return {HAILO_ARCH_HAILO15M, HAILO_ARCH_HAILO15H, HAILO_ARCH_HAILO10H};' in d
runtime=re.search(r'typedef enum hailo_device_architecture_e\s*\{(.*?)\}',h,re.S)[1]
names=re.findall(r'\b(HAILO_ARCH_HAILO\w+)\b',runtime)
assert names.index('HAILO_ARCH_HAILO10H')==6
multi=re.search(r'bool is_multi_layout\(.*?\{(.*?)\n\}',f,re.S)[1]
assert 'HAILO8L' in multi and 'HAILO15M' in multi and 'HAILO1XH' not in multi
selection=re.search(r'Hef::Impl::get_core_op_per_arch\(.*?\n\}',f,re.S)[0]
assert 'HAILO_ARCH_HAILO15H == device_arch' in selection
assert 'HAILO_ARCH_HAILO10H == device_arch' not in selection
start=c.index('CONTEXT_SWITCH_DEFS__ACTION_TYPE_FETCH_CFG_CHANNEL_DESCRIPTORS = 0,')
end=c.index('CONTEXT_SWITCH_DEFS__ACTION_TYPE_COUNT',start)
kinds=re.findall(r'CONTEXT_SWITCH_DEFS__ACTION_TYPE_\w+',c[start:end])
expected={'ENABLE_LCU_NON_DEFAULT':4,'DISABLE_LCU':5,'SWITCH_LCU_BATCH':36}
assert all(kinds.index('CONTEXT_SWITCH_DEFS__ACTION_TYPE_'+k)==v for k,v in expected.items())
fields={
 'enable_lcu_action_non_default_data_t':[('uint8_t','packed_lcu_id'),('uint8_t','network_index'),('uint16_t','kernel_done_address'),('uint32_t','kernel_done_count')],
 'disable_lcu_action_data_t':[('uint8_t','packed_lcu_id')],
 'switch_lcu_batch_action_data_t':[('uint8_t','packed_lcu_id'),('uint8_t','network_index'),('uint32_t','kernel_done_count')]}
for name,ordered in fields.items():
 body=re.search(r'typedef struct \{([^{}]+)\} CONTEXT_SWITCH_DEFS__'+name+';',c,re.S)[1]
 assert re.findall(r'(uint\d+_t)\s+(\w+);',body)==ordered,name
out={'program_architecture':{'family_1xh':103,'deprecated_h10h':5,'header_field':1},'runtime_h10h_enum':6,'partial_layout_field':1,'multi_layout_architectures':['HAILO8L','HAILO15M'],'h10h_does_not_receive_h15h_partial_layout_bypass':True,'lcu_action_ids':expected,'lcu_ordered_body_fields':fields,'source_bodies_executed':False,'device_access':False,'numerical_encoding_established':False}
Path(a.output).write_text(json.dumps(out,indent=2)+'\n');print('Pinned target/layout and three LCU body declarations verified')
