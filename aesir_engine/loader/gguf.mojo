from std.ffi import external_call
from std.memory import Pointer
from std.collections import Dict
from core.mimir_well import MimirWell, RuneTensor, f16
from loader.tokenizer import RuneWeaver

from core.mimir_well import CompressedFormatType

struct GGMLType:
    """
    ᚷᚷᛗᛚ·ᛏᚤᛈᛖ — The Standard Format Inscription Reader (GGMLType)
    ═════════════════════════════════════════════════════════════
    Translates raw GGML/GGUF integer format codes into sovereign CompressedFormatType runes.
    """
    comptime F32 = 0
    comptime F16 = 1
    comptime Q4_0 = 2
    comptime Q4_1 = 3
    comptime Q5_0 = 6
    comptime Q5_1 = 7
    comptime Q8_0 = 8
    comptime Q8_1 = 9
    comptime Q2_K = 10
    comptime Q3_K = 11
    comptime Q4_K = 12
    comptime Q5_K = 13
    comptime Q6_K = 14
    comptime Q8_K = 15
    comptime GPTQ_4BIT = 20
    comptime AWQ_4BIT = 21
    comptime EXL2 = 22
    comptime HQQ = 23
    comptime SMOOTHQUANT = 24

    @staticmethod
    def to_compressed_format(ggml_type: UInt32) -> CompressedFormatType:
        """
        ᚱᛢᚾᛖ·ᚲᛟᚾᚠᛖᚱᛏ — The Runestone Converter (to_compressed_format)
        ══════════════════════════════════════════════════════════════
        Maps GGML/GGUF integer constants to the sovereign CompressedFormatType discriminant tag.
        """
        if ggml_type == 10: return CompressedFormatType(CompressedFormatType.Q2_K)
        elif ggml_type == 11: return CompressedFormatType(CompressedFormatType.Q3_K_M)
        elif ggml_type == 2: return CompressedFormatType(CompressedFormatType.Q4_0)
        elif ggml_type == 3: return CompressedFormatType(CompressedFormatType.Q4_1)
        elif ggml_type == 12: return CompressedFormatType(CompressedFormatType.Q4_K_M)
        elif ggml_type == 6: return CompressedFormatType(CompressedFormatType.Q5_0)
        elif ggml_type == 7: return CompressedFormatType(CompressedFormatType.Q5_1)
        elif ggml_type == 13: return CompressedFormatType(CompressedFormatType.Q5_K_M)
        elif ggml_type == 14: return CompressedFormatType(CompressedFormatType.Q6_K)
        elif ggml_type == 8: return CompressedFormatType(CompressedFormatType.Q8_0)
        elif ggml_type == 9: return CompressedFormatType(CompressedFormatType.Q8_1)
        elif ggml_type == 20: return CompressedFormatType(CompressedFormatType.GPTQ_4BIT)
        elif ggml_type == 21: return CompressedFormatType(CompressedFormatType.AWQ_4BIT)
        elif ggml_type == 22: return CompressedFormatType(CompressedFormatType.EXL2_VARBIT)
        elif ggml_type == 23: return CompressedFormatType(CompressedFormatType.HQQ)
        elif ggml_type == 24: return CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8)
        else: return CompressedFormatType(CompressedFormatType.Q4_K_M)


struct GGUFSeer:
    var file_path: String
    var tensors: Dict[String, RuneTensor[f16]]
    var fd: Int32
    var file_size: Int64
    var mmap_ptr: Pointer[Int8, MutUntrackedOrigin]
    
    def __init__(out self, file_path: String):
        self.file_path = file_path
        self.tensors = Dict[String, RuneTensor[f16]]()
        self.fd = -1
        self.file_size = 0
        var null_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1)
        self.mmap_ptr = null_ptr

    def skip_value(self, val_type: UInt32, offset: Int) -> Int:
        var new_offset = offset
        if val_type == 0 or val_type == 1 or val_type == 7:
            new_offset += 1
        elif val_type == 2 or val_type == 3:
            new_offset += 2
        elif val_type == 4 or val_type == 5 or val_type == 6:
            new_offset += 4
        elif val_type == 10 or val_type == 11 or val_type == 12:
            new_offset += 8
        elif val_type == 8: # String
            var str_len = self.mmap_ptr.unsafe_offset(new_offset).unsafe_bitcast[UInt64]().unsafe_load()
            new_offset += 8 + Int(str_len)
        elif val_type == 9: # Array
            var arr_type = self.mmap_ptr.unsafe_offset(new_offset).unsafe_bitcast[UInt32]().unsafe_load()
            new_offset += 4
            var arr_len = self.mmap_ptr.unsafe_offset(new_offset).unsafe_bitcast[UInt64]().unsafe_load()
            new_offset += 8
            for _ in range(arr_len):
                new_offset = self.skip_value(arr_type, new_offset)
        return new_offset

    def mmap_and_load(mut self, mut pool: MimirWell):
        var dummy_weaver = RuneWeaver()
        self.mmap_and_load(pool, dummy_weaver)

    def mmap_and_load(mut self, mut pool: MimirWell, mut weaver: RuneWeaver):
        var path_bytes = List[Int8]()
        var src_bytes = self.file_path.as_bytes()
        for i in range(len(src_bytes)):
            path_bytes.append(Int8(src_bytes[i]))
        path_bytes.append(0)

        self.fd = external_call["open", Int32](path_bytes.unsafe_ptr(), 0)
        if self.fd < 0:
            var fallback_bytes = List[Int8]()
            var f_str = String("aesir_engine/") + self.file_path
            var f_src = f_str.as_bytes()
            for i in range(len(f_src)):
                fallback_bytes.append(Int8(f_src[i]))
            fallback_bytes.append(0)
            self.fd = external_call["open", Int32](fallback_bytes.unsafe_ptr(), 0)
            _ = fallback_bytes
        _ = path_bytes

        if self.fd < 0:
            print("FATAL: Failed to open model file.")
            return

        self.file_size = external_call["lseek", Int64](self.fd, 0, 2)
        _ = external_call["lseek", Int64](self.fd, 0, 0)

        var PROT_READ: Int32 = 1
        var MAP_SHARED: Int32 = 1
        var p_int = external_call["mmap", Int](Int(0), self.file_size, PROT_READ, MAP_SHARED, self.fd, Int64(0))
        if p_int == -1:
            print("FATAL: mmap failed!")
            _ = external_call["close", Int32](self.fd)
            self.fd = -1
            return
            
        self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=p_int)
        
        if self.file_size < 4:
            print("Warning: GGUF file too small, treating as empty.")
            _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
            _ = external_call["close", Int32](self.fd)
            self.fd = -1
            return

        var magic = self.mmap_ptr.unsafe_bitcast[Int32]().unsafe_load()
        if magic != 0x46554747:
            print("FATAL: Invalid GGUF magic bytes!")
            _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
            _ = external_call["close", Int32](self.fd)
            self.fd = -1
            return
            
        print("GGUF Magic Validated: The Runes are true.")
        
        if self.file_size < 24:
            print("Warning: GGUF file too small, treating as empty.")
            _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
            _ = external_call["close", Int32](self.fd)
            self.fd = -1
            return

        var version = self.mmap_ptr.unsafe_offset(4).unsafe_bitcast[UInt32]().unsafe_load()
        var tensor_count = self.mmap_ptr.unsafe_offset(8).unsafe_bitcast[UInt64]().unsafe_load()
        var kv_count = self.mmap_ptr.unsafe_offset(16).unsafe_bitcast[UInt64]().unsafe_load()
        
        print("GGUF Version:", version)
        print("Tensor Count:", tensor_count)
        print("KV Count:", kv_count)
        
        var current_offset = 24
        
        # Walk KV pairs in GGUF dictionary
        for _ in range(kv_count):
            var key_len = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
            current_offset += 8
            
            var key_bytes = List[Int8]()
            for i in range(Int(key_len)):
                key_bytes.append(self.mmap_ptr.unsafe_offset(current_offset + i).unsafe_load())
            key_bytes.append(0) # null terminator
            var key_str = String(key_bytes.unsafe_ptr(), Int(key_len))
            current_offset += Int(key_len)
            
            var val_type = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt32]().unsafe_load()
            current_offset += 4
            
            if key_str == "tokenizer.ggml.tokens" and val_type == 9: # Array
                var arr_type = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt32]().unsafe_load()
                current_offset += 4
                var arr_len = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
                current_offset += 8
                if arr_type == 8: # String Array
                    for tok_idx in range(Int(arr_len)):
                        var tok_len = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
                        current_offset += 8
                        var tok_bytes = List[Int8]()
                        for b in range(Int(tok_len)):
                            tok_bytes.append(self.mmap_ptr.unsafe_offset(current_offset + b).unsafe_load())
                        tok_bytes.append(0) # null terminator
                        var tok_str = String(tok_bytes.unsafe_ptr(), Int(tok_len))
                        current_offset += Int(tok_len)
                        weaver.add_token(tok_str, tok_idx)
                    print("RuneWeaver loaded", weaver.vocab_size, "tokens from GGUF metadata.")
                else:
                    current_offset = self.skip_value(val_type, current_offset - 12)
            else:
                current_offset = self.skip_value(val_type, current_offset)
            
        print("Finished parsing KV Pairs.")
        
        # Walk Tensors
        for _ in range(tensor_count):
            var name_len = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
            current_offset += 8
            
            var name_bytes = List[Int8]()
            for i in range(Int(name_len)):
                name_bytes.append(self.mmap_ptr.unsafe_offset(current_offset + i).unsafe_load())
            name_bytes.append(0) # null terminator
            var name_str = String(name_bytes.unsafe_ptr(), Int(name_len))
            current_offset += Int(name_len)
            
            var n_dims = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt32]().unsafe_load()
            current_offset += 4
            
            var rows = 1
            var cols = 1
            for d in range(n_dims):
                var dim_val = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
                current_offset += 8
                if d == 0:
                    cols = Int(dim_val)
                elif d == 1:
                    rows = Int(dim_val)
                    
            var tensor_type = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt32]().unsafe_load()
            current_offset += 4
            
            var tensor_offset = self.mmap_ptr.unsafe_offset(current_offset).unsafe_bitcast[UInt64]().unsafe_load()
            _ = tensor_offset
            current_offset += 8
            
            var is_quantized = (tensor_type != GGMLType.F16)
            var size = rows * cols
            
            var sim_tensor_ptr = pool.allocate(size)
            var sim_tensor = RuneTensor[f16](rows, cols, sim_tensor_ptr, is_quantized)
            self.tensors[name_str] = sim_tensor^
            
        print("GGUF mapped to MimirWell successfully. Tensors loaded:", tensor_count)
        
    def __deinit__(deinit self):
        if self.fd >= 0:
            _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
            _ = external_call["close", Int32](self.fd)
