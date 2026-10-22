from pathlib import Path
p=Path('aesir_engine/loader/packed_gguf.mojo');s=p.read_text();needle='    if kind == 14:\n        return PackedBlockGeometry(256, 210)';assert s.count(needle)==1
s=s.replace(needle,needle+'\n    if kind == 20:\n        return PackedBlockGeometry(32, 18)\n    if kind == 23:\n        return PackedBlockGeometry(256, 136)')
needle='    if columns % 256 != 0:\n        raise Error("Packed GGUF: K-quant row is not block aligned")';assert s.count(needle)==1
s=s.replace(needle,'    if kind == 20:\n        if columns % 32 != 0:\n            raise Error("Packed GGUF: IQ4_NL row is not block aligned")\n        return columns // 32 * packed_block_geometry(kind).bytes\n'+needle);p.write_text(s)
s=Path('smidr/source_q2q3_constants.mojo').read_text();s=s[:s.index('    var geometry = packed_block_geometry(kind)')];s=s.replace('Q2Q3','IQ4').replace('q2q3','iq4').replace('Q2_K/Q3_K','IQ4_NL/IQ4_XS').replace('kind != 10 and kind != 11','kind != 20 and kind != 23')
s=s.replace('    var dmin_bits: UInt16\n','').replace('    var dmin_binary32_bits: UInt32\n','').replace('var minimum_present: Bool','var group_scale_present: Bool').replace('    var minimum: UInt8','    var code: UInt8')
pos=s.index('\ndef _block_byte')
codebook=(-127,-104,-83,-65,-49,-35,-22,-10,1,13,25,38,53,69,89,113)
lookup='''\n# Public source-format data, ggml MIT pin a05c9922613c6a2230dbb1d0de679519ecafb4f0.
# Attribution/license: docs/evidence/iq4-source-contract-2026-10-22/LICENSE.
# This original lookup preserves code identity; it performs no floating product.
def _source_code_value(code: Int) -> Int8:
'''
for i,q in enumerate(codebook[:-1]):lookup+=f'    if code == {i}:\n        return Int8({q})\n'
lookup+='    return Int8(113)\n\n'
s=s[:pos]+lookup+s[pos:]
s+='''    var geometry = packed_block_geometry(kind)
    var group_scale_present = kind == 23
    var quant_origin = 8 if group_scale_present else 2
    var result = List[IQ4Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // geometry.elements) * geometry.bytes
        var lane = element % geometry.elements
        var group = lane // 32
        var quant_index = quant_origin + 16 * group + lane % 16
        var code = (_block_byte(source, block, quant_index) >> (4 * ((lane % 32) // 16))) & 15
        var scale = 1
        if group_scale_present:
            var low = (_block_byte(source, block, 4 + group // 2) >> (4 * (group % 2))) & 15
            var high = Int((source.source._read_u16(block + 2) >> UInt16(2 * group)) & 3)
            scale = low + 16 * high - 32
        var d = source.source._read_u16(block)
        result.append(IQ4Constant(d, binary16_to_binary32_bits(d),
            group_scale_present, Int8(scale), UInt8(code), _source_code_value(code)))
    return IQ4ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, kind, tensor.byte_count), first, result^)


def read_iq4_constant_window(path: String, name: String, first: Int,
                            count: Int, host_element_bound: Int) raises -> IQ4ConstantWindow:
    var source = PackedGGUF(path)
    return read_iq4_constants(source, name, first, count, host_element_bound)
'''
Path('smidr/source_iq4_constants.mojo').write_text(s)
s=Path('smidr/tools/source_q2q3_constants.mojo').read_text().replace('Q2Q3','IQ4').replace('q2q3','iq4').replace(' + "," + String(Int(c.dmin_bits))','').replace(' + "," + String(Int(c.dmin_binary32_bits))','').replace('c.minimum_present','c.group_scale_present').replace('c.minimum','c.code');Path('smidr/tools/source_iq4_constants.mojo').write_text(s)
s=Path('tests/hailo_source_q2q3_api.mojo').read_text().replace('Q2Q3','IQ4').replace('q2q3','iq4').replace('        window.components[0].dmin_bits = 0\n','').replace('minimum_present','group_scale_present').replace('window.components[0].minimum = 0','window.components[0].code = 0')
# Coherent overflow axes reach checked product, separately from shape guards.
s=s.replace('        source.tensors[name].rows = 2\n','        source.tensors[name].rows = 2\n        source.tensor_shapes[name][0] = source.tensors[name].columns\n        source.tensor_shapes[name][1] = 2\n')
Path('tests/hailo_source_iq4_api.mojo').write_text(s)
