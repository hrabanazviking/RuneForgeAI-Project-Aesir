"""Pure sealed owning-context replay plan; no persisted-format or security claim."""
from std.memory import bitcast
from core.sampling_config import NativeSamplingConfig


def mix(mut value: UInt64,item: UInt64):
    for shift in range(0,64,8): value = (value ^ ((item >> UInt64(shift)) & 255))*1099511628211


struct FixtureReplayPlan:
    var mode: Int
    var strategy: Int
    var context: Int
    var vocabulary: Int
    var weights: Int
    var activation: Int
    var cache: Int
    var tokens: List[Int]
    var tiles: List[Int]
    var pending: Int
    var config: NativeSamplingConfig
    var draws: UInt64
    var checksum: UInt64

    def __init__(out self,mode: Int,weights: Int,activation: Int,cache: Int,
        tokens: List[Int],tiles: List[Int],pending: Int,config: NativeSamplingConfig,draws: UInt64,strategy: Int = 0) raises:
        self.mode = mode
        self.strategy = strategy
        self.context = 1536
        self.vocabulary = 128256
        self.weights = weights
        self.activation = activation
        self.cache = cache
        self.tokens = tokens.copy()
        self.tiles = tiles.copy()
        self.pending = pending
        self.config = config
        self.draws = draws
        self.checksum = 0
        self.structure()
        self.checksum = self.fingerprint()

    def structure(self) raises:
        self.config.validate()
        if self.strategy < 0 or self.strategy > 1 or (self.mode == 0 and self.strategy != 0):
            raise Error("Replay execution strategy is unsupported")
        if (self.mode != 0 and self.mode != 1) or self.context != 1536 or self.vocabulary != 128256:
            raise Error("Replay mode/context/vocabulary mismatch")
        if self.weights <= 0 or self.activation <= 0 or self.cache <= 0:
            raise Error("Replay plan lacks owning allocation identity")
        if len(self.tokens) < 1 or len(self.tokens) >= self.context or len(self.tiles) < 1 or len(self.tiles) > len(self.tokens):
            raise Error("Replay plan token/tile bounds exceeded")
        if self.pending < 0 or self.pending >= self.vocabulary or self.pending == 128001 or self.pending == 128009:
            raise Error("Replay pending token is invalid or terminal")
        if self.draws > UInt64(len(self.tokens)+1) or (self.config.temperature == 0 and self.draws != 0):
            raise Error("Replay draw count exceeds committed history")
        var total = 0
        for count in self.tiles:
            if count != 1 and count != 4 and (count != 32 or self.mode != 1):
                raise Error("Replay plan contains an unsupported tile")
            if total > len(self.tokens)-count: raise Error("Replay tiles exceed committed IDs")
            total += count
        if total != len(self.tokens): raise Error("Replay tile total differs from committed IDs")
        for token in self.tokens:
            if token < 0 or token >= self.vocabulary: raise Error("Replay committed token is outside vocabulary")

    def fingerprint(self) -> UInt64:
        var value = UInt64(14695981039346656037)
        for item in [self.mode,self.strategy,self.context,self.vocabulary,self.weights,self.activation,self.cache,self.pending,len(self.tokens),len(self.tiles),self.config.top_k,self.config.repeat_last_n]:
            mix(value,UInt64(item))
        for item in [self.config.temperature,self.config.top_p,self.config.min_p,self.config.repetition_penalty]:
            mix(value,UInt64(bitcast[DType.uint32](item)))
        mix(value,self.config.seed)
        mix(value,self.draws)
        for token in self.tokens: mix(value,UInt64(token))
        for count in self.tiles: mix(value,UInt64(count))
        return value

    def admit(self,mode: Int,weights: Int,activation: Int,cache: Int,window: Int,strategy: Int = 0) raises:
        self.structure()
        if self.fingerprint() != self.checksum: raise Error("Replay plan changed after its checkpoint")
        if mode != self.mode or strategy != self.strategy or weights != self.weights or activation != self.activation or cache != self.cache or window != self.config.repeat_last_n:
            raise Error("Replay plan belongs to a different owner or sampler window")
