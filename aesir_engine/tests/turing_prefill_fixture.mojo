"""Isolated matrix-prefill fixture; normal session buffers/policy stay untouched."""
from max.gpu.host import DeviceBuffer, HostBuffer
from core.llama3_cuda import Llama3CUDASession
from core.dense_buffers import DenseBufferLayout, buffer_add, buffer_mul
from core.dense_gqa_execution import DenseGQALayer
from core.dense_normalization import dense_norm_kernel
from core.packed_projection import ProjectionFloats, four_matvec_kernel, block_matvec_kernel
from core.packed_turing_matrix import project_turing_staged
from core.gemma4_kernels import embedding_kernel
from core.llama3_kernels import Halves, llama_residual, llama_rope, llama_scaled_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention_tiled
from core.cuda_sampling import NativeCUDASampler
from core.sampling_config import NativeSamplingConfig, sampling_device_bytes
from loader.packed_gguf import PackedTensor


struct TuringPrefillFixture:
    var native: Llama3CUDASession
    var layout: DenseBufferLayout
    var activations: DeviceBuffer[DType.float32]
    var cache: DeviceBuffer[DType.float16]
    var sampler: NativeCUDASampler
    var output: DeviceBuffer[DType.int32]
    var host_output: HostBuffer[DType.int32]
    var position: Int
    var healthy: Bool
    var committed: List[Int]

    def __init__(out self,path: String) raises:
        self.native = Llama3CUDASession(path,1536,prefix_cache=False,prefill_batch=4)
        if self.native.profile.hidden_size != 3072 or self.native.profile.feed_forward_size != 8192 or self.native.profile.layer_count != 28 or self.native.profile.vocabulary_size != 128256:
            raise Error("Matrix model fixture requires strict3B")
        # This independent test layout never expands normal admission or mutates
        # native.buffers. All per-token offsets remain the validated normal ones.
        self.layout = self.native.buffers
        self.layout.batch = 32
        # Borrowed matrix admission counts the physical16-value guard prefix
        # inside a token stride; keep checked padding beyond the live FFN span.
        self.layout.stride = buffer_add(self.layout.stride,32)
        self.layout.logits = buffer_mul(self.layout.stride,32)
        self.layout.scores = buffer_add(self.layout.logits,128256)
        self.layout.elements = buffer_add(self.layout.scores,buffer_mul(24,1536))
        var a_count = buffer_add(self.layout.elements,32)
        var kv_count = buffer_add(self.native.profile.kv_elements(1536),32)
        var bytes = buffer_add(buffer_mul(a_count,4),buffer_mul(kv_count,2))
        bytes = buffer_add(bytes,buffer_add(sampling_device_bytes(128256),8))
        if buffer_add(bytes,268435456) > Int(self.native.context.get_memory_info()[0]):
            raise Error("Matrix fixture exceeds observed device headroom")
        self.activations = self.native.context.enqueue_create_buffer[DType.float32](a_count)
        self.cache = self.native.context.enqueue_create_buffer[DType.float16](kv_count)
        self.sampler = NativeCUDASampler(self.native.context,128256,NativeSamplingConfig())
        self.output = self.native.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.native.context.enqueue_create_host_buffer[DType.int32](1)
        self.activations.enqueue_fill(-9876)
        self.cache.enqueue_fill(Float16(-9876))
        self.native.context.synchronize()
        self.position = 0
        self.healthy = True
        self.committed = List[Int]()

    def a(self) -> ProjectionFloats:
        return ProjectionFloats(unsafe_from_address=Int(self.activations.unsafe_ptr())).unsafe_offset(16)

    def kv(self) -> Halves:
        return Halves(unsafe_from_address=Int(self.cache.unsafe_ptr())).unsafe_offset(16)

    def norm(self,weight: Int,src: Int,dst: Int) raises:
        self.native.context.enqueue_function[dense_norm_kernel[3072]](self.native.w(),self.a(),Int64(weight),Int64(src),Int64(dst),Int64(1),self.native.profile.normalization_epsilon,grid_dim=1,block_dim=128)

    def project_kind[kind: Int](self,t: PackedTensor,src: Int,dst: Int,count: Int,matrix: Bool) raises:
        if matrix and count == 32:
            project_turing_staged[kind,32,64](self.native.context,self.native.weights,self.activations,t.offset,t.columns,t.rows,src+16,dst+16,self.layout.stride,32)
        elif count == 4 or count == 32:
            for start in range(0,count,4):
                self.native.context.enqueue_function[four_matvec_kernel[kind]](self.native.w(),self.a(),Int64(t.offset),Int64(t.columns),Int64(t.rows),Int64(start*self.layout.stride+src),Int64(start*self.layout.stride+dst),Int64(self.layout.stride),grid_dim=(t.rows+3)//4,block_dim=128)
        else:
            self.native.context.enqueue_function[block_matvec_kernel[kind]](self.native.w(),self.a(),Int64(t.offset),Int64(t.columns),Int64(t.rows),Int64(src),Int64(dst),grid_dim=(t.rows+3)//4,block_dim=128)

    def project(self,t: PackedTensor,src: Int,dst: Int,count: Int,matrix: Bool = False) raises:
        if t.kind == 12: self.project_kind[12](t,src,dst,count,matrix)
        elif t.kind == 13: self.project_kind[13](t,src,dst,count,matrix)
        elif t.kind == 14: self.project_kind[14](t,src,dst,count,matrix)
        else: raise Error("Matrix fixture requires an admitted packed projection")

    def rotate(self,offset: Int,heads: Int,position: Int) raises:
        if self.native.profile.rope_factors:
            self.native.context.enqueue_function[llama_scaled_rope](self.native.w(),self.a(),Int64(offset),Int64(128),Int64(heads),Int64(position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),Int64(self.native.rope_factors_offset),grid_dim=(heads*64+127)//128,block_dim=128)
        else:
            self.native.context.enqueue_function[llama_rope](self.a(),Int64(offset),Int64(128),Int64(heads),Int64(position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),grid_dim=(heads*64+127)//128,block_dim=128)

    def attention(self,layer: Int,count: Int) raises:
        var offset = layer*2*1536*1024
        for token in range(count):
            var base = self.layout.token_base(token)
            var position = self.position+token
            self.rotate(base+self.layout.query,24,position)
            self.rotate(base+self.layout.key,8,position)
            self.native.context.enqueue_function[llama_cache](self.a(),self.kv(),Int64(base+self.layout.key),Int64(base+self.layout.value),Int64(offset),Int64(1536),Int64(1024),Int64(position),grid_dim=8,block_dim=128)
            # Only positions0..position are visible. Shared scores are consumed
            # on this stream before the next token, including inside32 tiles.
            var causal = position+1
            self.native.context.enqueue_function[llama_scores](self.a(),self.kv(),Int64(base+self.layout.query),Int64(self.layout.scores),Int64(offset),Int64(causal),Int64(128),Int64(24),Int64(8),grid_dim=(24*causal+3)//4,block_dim=128)
            self.native.context.enqueue_function[llama_softmax](self.a(),Int64(self.layout.scores),Int64(causal),Int64(24),grid_dim=6,block_dim=128)
            self.native.context.enqueue_function[llama_attention_tiled](self.a(),self.kv(),Int64(self.layout.scores),Int64(base+self.layout.attention),Int64(offset),Int64(1536),Int64(causal),Int64(128),Int64(24),Int64(8),grid_dim=24,block_dim=128)

    def residual(self,base: Int) raises:
        self.native.context.enqueue_function[llama_residual](self.a(),Int64(base),Int64(base+self.layout.temporary),Int64(base),Int64(3072),grid_dim=24,block_dim=128)

    def layer(self,plan: DenseGQALayer,index: Int,count: Int) raises:
        for token in range(count):
            var base = self.layout.token_base(token)
            self.norm(plan.attention_norm,base,base+self.layout.norm)
        self.project(plan.query,self.layout.norm,self.layout.query,count,True)
        self.project(plan.key,self.layout.norm,self.layout.key,count)
        self.project(plan.value,self.layout.norm,self.layout.value,count)
        self.attention(index,count)
        self.project(plan.attention_output,self.layout.attention,self.layout.temporary,count,True)
        for token in range(count):
            var base = self.layout.token_base(token)
            self.residual(base)
            self.norm(plan.feed_forward_norm,base,base+self.layout.norm)
        self.project(plan.gate,self.layout.norm,self.layout.gate,count,True)
        self.project(plan.up,self.layout.norm,self.layout.up,count,True)
        for token in range(count):
            var base = self.layout.token_base(token)
            self.native.context.enqueue_function[llama_silu](self.a(),Int64(base+self.layout.gate),Int64(base+self.layout.up),Int64(8192),grid_dim=64,block_dim=128)
        self.project(plan.down,self.layout.up,self.layout.temporary,count,True)
        for token in range(count): self.residual(self.layout.token_base(token))

    def admit(self,tokens: List[Int],start: Int,count: Int,need_logits: Bool) raises:
        if not self.healthy or not self.native.healthy or (count != 1 and count != 4 and count != 32) or (need_logits and count != 1):
            raise Error("Matrix fixture tile/policy is not admitted")
        if start < 0 or start > len(tokens)-count or self.position < 0 or self.position > 1536-count:
            raise Error("Matrix fixture token/context bounds exceeded")
        if len(self.activations) != self.layout.elements+32 or len(self.cache) != self.native.profile.kv_elements(1536)+32:
            raise Error("Matrix fixture actual buffer span disagrees with plan")
        for i in range(count):
            if tokens[start+i] < 0 or tokens[start+i] >= 128256:
                raise Error("Matrix fixture token outside vocabulary")

    def step(mut self,tokens: List[Int],start: Int,count: Int,need_logits: Bool = False) raises:
        self.admit(tokens,start,count,need_logits)
        self.healthy = False
        for token in range(count):
            self.sampler.record(tokens[start+token])
            self.native.context.enqueue_function[embedding_kernel](self.native.w(),self.a(),Int64(self.native.embedding_tensor.offset),Int64(self.native.embedding_tensor.kind),Int64(3072),Int64(tokens[start+token]),Int64(self.layout.token_base(token)),Float32(1),grid_dim=24,block_dim=128)
        for layer in range(28): self.layer(self.native.layers[layer],layer,count)
        if need_logits:
            self.norm(self.native.output_norm,0,self.layout.norm)
            self.project(self.native.output_tensor,self.layout.norm,self.layout.logits,1)
            self.sampler.select(self.a(),self.layout.logits,self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),self.native.profile.ordinary_token_limit,self.native.profile.eos_token_id,self.native.profile.end_of_turn_token_id)
            self.native.context.enqueue_copy(self.host_output,self.output)
        self.native.context.synchronize()
        if need_logits and (self.host_output[0] < 0 or self.host_output[0] >= 128256):
            raise Error("Matrix model produced nonfinite sampled logits")
        for token in range(count): self.committed.append(tokens[start+token])
        self.position += count
        self.healthy = True

    def reset(mut self) raises:
        if not self.healthy: raise Error("Failed matrix execution requires context recreation")
        self.healthy = False
        self.sampler.clear()
        self.native.context.synchronize()
        self.position = 0
        self.committed.clear()
        self.healthy = True

    def guards(self) raises:
        var a = self.native.context.enqueue_create_host_buffer[DType.float32](len(self.activations))
        var kv = self.native.context.enqueue_create_host_buffer[DType.float16](len(self.cache))
        self.native.context.enqueue_copy(a,self.activations)
        self.native.context.enqueue_copy(kv,self.cache)
        self.native.context.synchronize()
        for i in range(16):
            if a[i] != -9876 or a[len(a)-16+i] != -9876 or kv[i] != Float16(-9876) or kv[len(kv)-16+i] != Float16(-9876):
                raise Error("Matrix model wrote outside its owned guarded buffers")
        for token in range(32):
            for i in range(32):
                if a[16+token*self.layout.stride+self.layout.stride-32+i] != -9876:
                    raise Error("Matrix model mutated unowned token padding")
