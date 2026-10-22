from pathlib import Path
p=Path('aesir_engine/loader/packed_gguf.mojo');s=p.read_text();needle='    if kind == 12:\n        return PackedBlockGeometry(256, 144)';assert s.count(needle)==1
p.write_text(s.replace(needle,'    if kind == 10:\n        return PackedBlockGeometry(256, 84)\n    if kind == 11:\n        return PackedBlockGeometry(256, 110)\n'+needle))
base=Path('smidr/source_classic32_constants.mojo').read_text()
s=base[:base.index('    var geometry = packed_block_geometry(kind)')]
s=s.replace('Classic32','Q2Q3').replace('classic32','q2q3').replace('CLASSIC32','Q2Q3')
s=s.replace('Q4/Q5','Q2_K/Q3_K').replace('    var m_bits: UInt16','    var dmin_bits: UInt16').replace('    var m_binary32_bits: UInt32','    var dmin_binary32_bits: UInt32').replace('    var bias_present: Bool','    var minimum_present: Bool\n    var scale: Int8\n    var minimum: UInt8')
s=s.replace('kind != 2 and kind != 3 and kind != 6 and kind != 7','kind != 10 and kind != 11').replace('classic Q2_K/Q3_K','Q2_K/Q3_K')
s=s.replace('# No floating product/addition, device packing or model evaluation.','# No floating product/subtraction, device packing or model evaluation.')
s+='''    var geometry = packed_block_geometry(kind)
    var minimum_present = kind == 10
    var low_origin = 16 if minimum_present else 32
    var d_origin = 80 if minimum_present else 108
    var result = List[Q2Q3Constant]()
    result.reserve(count)
    for i in range(count):
        var element = first + i
        var block = tensor.offset + (element // geometry.elements) * geometry.bytes
        var lane = element % geometry.elements
        var group = lane // 16
        var low_index = low_origin + 32 * (lane // 128) + lane % 32
        var quant = (_block_byte(source, block, low_index) >> (2 * ((lane % 128) // 32))) & 3
        var scale = 0
        var minimum = 0
        if minimum_present:
            var factors = _block_byte(source, block, group)
            scale = factors & 15
            minimum = factors >> 4
        else:
            var high = (_block_byte(source, block, lane % 32) >> (lane // 32)) & 1
            quant -= 4 if high == 0 else 0
            var low_scale = (_block_byte(source, block, 96 + group % 8) >> (4 * (group // 8))) & 15
            var high_scale = (_block_byte(source, block, 104 + group % 4) >> (2 * (group // 4))) & 3
            scale = low_scale + 16 * high_scale - 32
        var d = source.source._read_u16(block + d_origin)
        var dmin = source.source._read_u16(block + 82) if minimum_present else UInt16(0)
        result.append(Q2Q3Constant(d, dmin, binary16_to_binary32_bits(d),
            binary16_to_binary32_bits(dmin), minimum_present, Int8(scale), UInt8(minimum), Int8(quant)))
    return Q2Q3ConstantWindow(SourceTensorBinding(tensor.offset, tensor.columns,
        tensor.rows, kind, tensor.byte_count), first, result^)


def read_q2q3_constant_window(path: String, name: String, first: Int,
                             count: Int, host_element_bound: Int) raises -> Q2Q3ConstantWindow:
    var source = PackedGGUF(path)
    return read_q2q3_constants(source, name, first, count, host_element_bound)
'''
# All byte accesses use even halfword pairs inside the proven complete block.
pos=s.index('\ndef read_q2q3_constants')
s=s[:pos]+'''\ndef _block_byte(source: PackedGGUF, block: Int, index: Int) raises -> Int:
    var pair = source.source._read_u16(block + (index // 2) * 2)
    return Int((pair >> UInt16((index % 2) * 8)) & 255)

'''+s[pos:]
Path('smidr/source_q2q3_constants.mojo').write_text(s)
s=Path('smidr/tools/source_classic32_constants.mojo').read_text().replace('classic32','q2q3').replace('Classic32','Q2Q3').replace('c.m_bits','c.dmin_bits').replace('c.m_binary32_bits','c.dmin_binary32_bits').replace('c.bias_present','c.minimum_present')
s=s.replace('+ String(Int(c.q))', '+ String(Int(c.scale)) + "," + String(Int(c.minimum)) + "," + String(Int(c.q))')
Path('smidr/tools/source_q2q3_constants.mojo').write_text(s)
s=Path('tests/hailo_source_classic32_api.mojo').read_text().replace('classic32','q2q3').replace('Classic32','Q2Q3').replace('integer digest seam','source field seam').replace('+= 32','+= 256').replace('= 31','= 255').replace('window.components[0].m_bits','window.components[0].dmin_bits').replace('bias_present','minimum_present')
# Extra exact-axis/missing owner shape cases and full component independence.
s=s.replace('    elif mode == "rows":','    elif mode == "shape_missing":\n        del source.tensor_shapes[name]\n    elif mode == "rank":\n        source.tensor_shapes[name].append(1)\n    elif mode == "file_size":\n        source.source.file_size -= 1\n    elif mode == "rows":')
s=s.replace('        window.binding.file_offset = -1','        window.components[0].scale = 0\n        window.components[0].minimum = 0\n        window.binding.file_offset = -1')
Path('tests/hailo_source_q2q3_api.mojo').write_text(s)
