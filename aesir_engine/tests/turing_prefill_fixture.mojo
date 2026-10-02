"""Isolated matrix-prefill fixture; normal session buffers/policy stay untouched."""
from max.gpu.host import DeviceBuffer, HostBuffer, DeviceAttribute
from core.llama3_cuda import Llama3CUDASession
from core.dense_buffers import DenseBufferLayout
from tests.turing_fixture_plan import TuringFixturePlan
from tests.turing_fixture_control import FixtureControl
from tests.batched_rope_cache import batched_rope, batched_scaled_rope, batched_cache
from tests.batched_elementwise import batched_residual, batched_silu
from core.dense_gqa_execution import DenseGQALayer
from core.dense_normalization import dense_norm_kernel, dense_norm_strided_kernel
from core.packed_projection import ProjectionFloats, four_matvec_kernel, block_matvec_kernel
from core.packed_turing_matrix import project_turing_staged
from core.gemma4_kernels import embedding_kernel
from core.llama3_kernels import Halves, llama_residual, llama_rope, llama_scaled_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention_tiled
from core.cuda_sampling import NativeCUDASampler
from core.sampling_config import NativeSamplingConfig
from loader.packed_gguf import PackedTensor


def ignore_layer(layer: Int) raises:
    _ = layer


struct TuringPrefillFixture:
    var native: Llama3CUDASession
    var buffer_plan: TuringFixturePlan
    var control: FixtureControl
    var layout: DenseBufferLayout
    var activations: DeviceBuffer[DType.float32]
    var cache: DeviceBuffer[DType.float16]
    var sampler: NativeCUDASampler
    var output: DeviceBuffer[DType.int32]
    var host_output: HostBuffer[DType.int32]
    var position: Int
    var healthy: Bool
    var committed: List[Int]
    var activation_precision: Int
    var batched_rope_cache: Bool
    var rope_cache_calls: Int
    var batched_elementwise: Bool
    var elementwise_calls: Int

    def __init__(out self,path: String,precision: Int = 0,batched: Bool = False,elementwise: Bool = False) raises:
        if precision < 0 or precision > 4: raise Error("Fixture activation precision must be0/1/2/3/4")
        if batched and precision != 0: raise Error("Batched rotary/cache requires original precision0")
        if elementwise and not batched: raise Error("Batched elementwise requires admitted rotary/cache strategy")
        self.batched_elementwise = elementwise
        self.elementwise_calls = 0
        self.activation_precision = precision
        self.batched_rope_cache = batched
        self.rope_cache_calls = 0
        self.control = FixtureControl()
        self.native = Llama3CUDASession(path,1536,prefix_cache=False,prefill_batch=4)
        self.buffer_plan = TuringFixturePlan(self.native.profile,self.native.buffers,
            Int(self.native.context.get_attribute(DeviceAttribute.COMPUTE_CAPABILITY_MAJOR)),
            Int(self.native.context.get_attribute(DeviceAttribute.COMPUTE_CAPABILITY_MINOR)),
            Int(self.native.context.get_memory_info()[0]),precision)
        self.layout = self.buffer_plan.layout
        self.activations = self.native.context.enqueue_create_buffer[DType.float32](self.buffer_plan.activation_elements)
        self.cache = self.native.context.enqueue_create_buffer[DType.float16](self.buffer_plan.cache_elements)
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

    def norm(mut self,weight: Int,src: Int,dst: Int) raises:
        self.native.context.enqueue_function[dense_norm_kernel[3072]](self.native.w(),self.a(),Int64(weight),Int64(src),Int64(dst),Int64(1),self.native.profile.normalization_epsilon,grid_dim=1,block_dim=128)
        self.elementwise_calls += 1

    def norm_rows(mut self,weight: Int,src: Int,dst: Int,count: Int) raises:
        if self.batched_elementwise and count > 1:
            self.native.context.enqueue_function[dense_norm_strided_kernel[3072,33824]](self.native.w(),self.a(),Int64(weight),Int64(src),Int64(dst),Int64(count),self.native.profile.normalization_epsilon,grid_dim=(count+3)//4,block_dim=128)
            self.elementwise_calls += 1
        else:
            for token in range(count):
                var base = self.layout.token_base(token)
                self.norm(weight,base+src,base+dst)

    def execution_strategy(self) -> Int:
        return 2 if self.batched_elementwise else Int(self.batched_rope_cache)

    def project_kind[kind: Int](self,t: PackedTensor,src: Int,dst: Int,count: Int,matrix: Bool) raises:
        if matrix and count == 32:
            if self.activation_precision == 1:
                project_turing_staged[kind,32,64,32,1](self.native.context,self.native.weights,self.activations,t.offset,t.columns,t.rows,src+16,dst+16,self.layout.stride,32)
            elif self.activation_precision == 2:
                project_turing_staged[kind,32,64,32,2](self.native.context,self.native.weights,self.activations,t.offset,t.columns,t.rows,src+16,dst+16,self.layout.stride,32)
            elif self.activation_precision == 3:
                project_turing_staged[kind,32,64,32,3](self.native.context,self.native.weights,self.activations,t.offset,t.columns,t.rows,src+16,dst+16,self.layout.stride,32)
            elif self.activation_precision == 4:
                project_turing_staged[kind,32,64,32,4](self.native.context,self.native.weights,self.activations,t.offset,t.columns,t.rows,src+16,dst+16,self.layout.stride,32)
            else:
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

    def rotate(mut self,offset: Int,heads: Int,position: Int) raises:
        if self.native.profile.rope_factors:
            self.native.context.enqueue_function[llama_scaled_rope](self.native.w(),self.a(),Int64(offset),Int64(128),Int64(heads),Int64(position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),Int64(self.native.rope_factors_offset),grid_dim=(heads*64+127)//128,block_dim=128)
        else:
            self.native.context.enqueue_function[llama_rope](self.a(),Int64(offset),Int64(128),Int64(heads),Int64(position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),grid_dim=(heads*64+127)//128,block_dim=128)
        self.rope_cache_calls += 1

    def rotate_batch(mut self,offset: Int,heads: Int,count: Int) raises:
        if self.native.profile.rope_factors:
            self.native.context.enqueue_function[batched_scaled_rope](self.native.w(),self.a(),Int64(offset),Int64(128),Int64(heads),Int64(self.position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),Int64(self.native.rope_factors_offset),Int64(self.layout.stride),grid_dim=((heads*64+127)//128,count),block_dim=128)
        else:
            self.native.context.enqueue_function[batched_rope](self.a(),Int64(offset),Int64(128),Int64(heads),Int64(self.position),self.native.profile.rope_frequency_base,Int64(1 if self.native.profile.neox_rope else 0),Int64(self.layout.stride),grid_dim=((heads*64+127)//128,count),block_dim=128)
        self.rope_cache_calls += 1

    def attention(mut self,layer: Int,count: Int) raises:
        var offset = layer*2*1536*1024
        var batched = self.batched_rope_cache and count > 1
        if batched:
            self.rotate_batch(self.layout.query,24,count)
            self.rotate_batch(self.layout.key,8,count)
            self.native.context.enqueue_function[batched_cache](self.a(),self.kv(),Int64(self.layout.key),Int64(self.layout.value),Int64(offset),Int64(1536),Int64(1024),Int64(self.position),Int64(self.layout.stride),grid_dim=(8,count),block_dim=128)
            self.rope_cache_calls += 1
        for token in range(count):
            var base = self.layout.token_base(token)
            var position = self.position+token
            if not batched:
                self.rotate(base+self.layout.query,24,position)
                self.rotate(base+self.layout.key,8,position)
                self.native.context.enqueue_function[llama_cache](self.a(),self.kv(),Int64(base+self.layout.key),Int64(base+self.layout.value),Int64(offset),Int64(1536),Int64(1024),Int64(position),grid_dim=8,block_dim=128)
                self.rope_cache_calls += 1
            # Only positions0..position are visible. Shared scores are consumed
            # on this stream before the next token, including inside32 tiles.
            var causal = position+1
            self.native.context.enqueue_function[llama_scores](self.a(),self.kv(),Int64(base+self.layout.query),Int64(self.layout.scores),Int64(offset),Int64(causal),Int64(128),Int64(24),Int64(8),grid_dim=(24*causal+3)//4,block_dim=128)
            self.native.context.enqueue_function[llama_softmax](self.a(),Int64(self.layout.scores),Int64(causal),Int64(24),grid_dim=6,block_dim=128)
            self.native.context.enqueue_function[llama_attention_tiled](self.a(),self.kv(),Int64(self.layout.scores),Int64(base+self.layout.attention),Int64(offset),Int64(1536),Int64(causal),Int64(128),Int64(24),Int64(8),grid_dim=24,block_dim=128)

    def residual(mut self,base: Int) raises:
        self.native.context.enqueue_function[llama_residual](self.a(),Int64(base),Int64(base+self.layout.temporary),Int64(base),Int64(3072),grid_dim=24,block_dim=128)
        self.elementwise_calls += 1

    def residual_rows(mut self,count: Int) raises:
        if self.batched_elementwise and count > 1:
            self.native.context.enqueue_function[batched_residual](self.a(),Int64(0),Int64(self.layout.temporary),Int64(0),Int64(3072),Int64(self.layout.stride),grid_dim=(24,count),block_dim=128)
            self.elementwise_calls += 1
        else:
            for token in range(count): self.residual(self.layout.token_base(token))

    def silu_rows(mut self,count: Int) raises:
        if self.batched_elementwise and count > 1:
            self.native.context.enqueue_function[batched_silu](self.a(),Int64(self.layout.gate),Int64(self.layout.up),Int64(8192),Int64(self.layout.stride),grid_dim=(64,count),block_dim=128)
            self.elementwise_calls += 1
        else:
            for token in range(count):
                var base = self.layout.token_base(token)
                self.native.context.enqueue_function[llama_silu](self.a(),Int64(base+self.layout.gate),Int64(base+self.layout.up),Int64(8192),grid_dim=64,block_dim=128)
                self.elementwise_calls += 1

    def layer(mut self,plan: DenseGQALayer,index: Int,count: Int) raises:
        self.norm_rows(plan.attention_norm,0,self.layout.norm,count)
        self.project(plan.query,self.layout.norm,self.layout.query,count,True)
        self.project(plan.key,self.layout.norm,self.layout.key,count)
        self.project(plan.value,self.layout.norm,self.layout.value,count)
        self.attention(index,count)
        self.project(plan.attention_output,self.layout.attention,self.layout.temporary,count,True)
        if self.batched_elementwise and count > 1:
            self.residual_rows(count)
            self.norm_rows(plan.feed_forward_norm,0,self.layout.norm,count)
        else:
            for token in range(count):
                var base = self.layout.token_base(token)
                self.residual(base)
                self.norm(plan.feed_forward_norm,base,base+self.layout.norm)
        self.project(plan.gate,self.layout.norm,self.layout.gate,count,True)
        self.project(plan.up,self.layout.norm,self.layout.up,count,True)
        self.silu_rows(count)
        self.project(plan.down,self.layout.up,self.layout.temporary,count,True)
        self.residual_rows(count)

    def admit(self,tokens: List[Int],start: Int,count: Int,need_logits: Bool) raises:
        if not self.healthy or not self.native.healthy or (count != 1 and count != 4 and count != 32) or (need_logits and count != 1):
            raise Error("Matrix fixture tile/policy is not admitted")
        if (self.batched_rope_cache and self.activation_precision != 0) or (self.batched_elementwise and not self.batched_rope_cache):
            raise Error("Fixture execution flags drifted outside admitted precision/strategy")
        self.control.admit()
        if start < 0 or start > len(tokens)-count or self.position < 0 or self.position > 1536-count:
            raise Error("Matrix fixture token/context bounds exceeded")
        self.buffer_plan.admit_buffers(self.layout,len(self.activations),len(self.cache))
        for i in range(count):
            if tokens[start+i] < 0 or tokens[start+i] >= 128256:
                raise Error("Matrix fixture token outside vocabulary")

    def configure_control(mut self,timeout_ms: Int = 0,cancel_fd: Int = -1) raises:
        if not self.healthy or not self.native.healthy:
            raise Error("Cannot configure a busy or failed matrix fixture")
        self.control.configure(timeout_ms,cancel_fd)

    def start_control(mut self) raises:
        if not self.healthy or not self.native.healthy:
            raise Error("Cannot start control on a busy or failed matrix fixture")
        self.control.start()

    def drain_control_abort(mut self,reason: String) raises:
        self.healthy = False
        self.native.context.synchronize()
        self.control.aborted(reason)
        self.healthy = True

    def checkpoint(mut self) raises:
        var reason: String
        try: reason = self.control.stop_reason()
        except:
            self.drain_control_abort("control_error")
            raise
        if reason != "":
            self.drain_control_abort(reason)
            raise Error("Matrix fixture "+reason+"; explicit reset required")

    def step(mut self,tokens: List[Int],start: Int,count: Int,need_logits: Bool = False,
        layer_observer: def(Int) thin raises = ignore_layer) raises:
        self.admit(tokens,start,count,need_logits)
        self.control.completed_layers = 0
        if self.control.enabled(): self.checkpoint()
        self.healthy = False
        for token in range(count):
            self.sampler.record(tokens[start+token])
            self.native.context.enqueue_function[embedding_kernel](self.native.w(),self.a(),Int64(self.native.embedding_tensor.offset),Int64(self.native.embedding_tensor.kind),Int64(3072),Int64(tokens[start+token]),Int64(self.layout.token_base(token)),Float32(1),grid_dim=24,block_dim=128)
        for layer in range(28):
            var plan = self.native.layers[layer]
            self.layer(plan,layer,count)
            if self.control.enabled():
                self.native.context.synchronize()
                self.control.completed_layers = layer+1
                layer_observer(layer+1)
                self.checkpoint()
        if need_logits:
            self.norm(self.native.output_norm,0,self.layout.norm)
            self.project(self.native.output_tensor,self.layout.norm,self.layout.logits,1)
            self.sampler.select(self.a(),self.layout.logits,self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),self.native.profile.ordinary_token_limit,self.native.profile.eos_token_id,self.native.profile.end_of_turn_token_id)
            self.native.context.enqueue_copy(self.host_output,self.output)
        self.native.context.synchronize()
        if self.control.enabled(): self.checkpoint()
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
        self.rope_cache_calls = 0
        self.elementwise_calls = 0
        self.control.reset()
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
