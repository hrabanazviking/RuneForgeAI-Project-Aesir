# SKÁLDBRØÐIR — The Doom Loop Annihilation Protocol
## Advanced Runaway Generation Detection & Termination System for Project Æsir

(Skaldbrodir_Doom_Loop_Annihilation_Protocol.md)

**Document ID:** AES-DOOM-001  
**Classification:** Core Safety Subsystem  
**Mythological Analog:** Skáldbrøðir ("Poet's Burden") — the weight that ends endless verse  
**Related Components:** Masking Seidr, BrainForge, HuginnKeeper, BifrostGate  
**Error Codes:** INF-011 (GENERATION_LOOP_STUCK), INF-016 (DOOM_LOOP_DETECTED), INF-017 (DOOM_LOOP_TERMINATED)

---

## Executive Summary

Doom loops (runaway autoregressive generation cycles) represent a critical failure mode in LLM inference where token generation enters a non-terminating or pathologically repetitive state. This document specifies **SKÁLDBRØÐIR**, a multi-layer, sub-millisecond latency detection and termination system designed for Project Æsir's bare-metal Mojo inference engine.

---

## 1. Mathematical Foundation

### 1.1 Loop Detection Metrics

Define the generation trajectory as a sequence of token distributions:

$$\mathcal{T} = \{T_1, T_2, T_3, ..., T_n\}$$

where each $T_i = (t_i, \vec{p}_i)$ contains the selected token $t_i$ and the full probability vector $\vec{p}_i \in \mathbb{R}^V$ over vocabulary $V$.

#### 1.1.1 Entropy Collapse Detection

The Shannon entropy of the token distribution at step $i$:

$$H_i = -\sum_{j=1}^{V} p_{i,j} \log_2(p_{i,j})$$

**Doom Condition — Entropy Collapse:**

$$\exists \, \Delta_H : H_i < H_{min} \land \frac{dH}{dt} < \epsilon_H \text{ for } n > N_{entropy}$$

Where:
- $H_{min} = 0.1$ bits (near-deterministic selection)
- $\epsilon_H = 0.01$ bits/step (entropy decay threshold)
- $N_{entropy} = 32$ consecutive steps

#### 1.1.2 Token Repetition Score (TRS)

For a sliding window of size $W$ (default: 64 tokens):

$$\text{TRS}_i = \frac{1}{W} \sum_{k=1}^{W} \mathbb{1}[t_{i-k} = t_i] \cdot w_k$$

With exponential decay weights:

$$w_k = e^{-\lambda k}, \quad \lambda = \frac{\ln(2)}{W/2}$$

**Doom Condition — Repetition Lock:**

$$\text{TRS}_i > \theta_{rep} \text{ for } n > N_{rep}$$

Where:
- $\theta_{rep} = 0.7$ (70% repetition in weighted window)
- $N_{rep} = 16$ consecutive high-repetition steps

#### 1.1.3 N-gram Trap Detection

For n-gram size $n \in \{2, 3, 4, 5\}$:

$$\text{NGT}_{i,n} = \max_{g \in \mathcal{G}_n} \frac{\text{count}(g, \mathcal{T}_{i-W:i})}{W-n+1}$$

Where $\mathcal{G}_n$ is the set of all n-grams in the window.

**Doom Condition — N-gram Trap:**

$$\exists n : \text{NGT}_{i,n} > \theta_{ngt} \cdot \frac{1}{V^{n-1}}$$

Where $\theta_{ngt} = 100$ (100× above random expectation).

#### 1.1.4 Cosine Similarity Divergence

Measure embedding space stagnation:

$$\text{sim}_{i,j} = \frac{\vec{e}_i \cdot \vec{e}_j}{\|\vec{e}_i\| \|\vec{e}_j\|}$$

Where $\vec{e}_i$ is the hidden state embedding at step $i$.

**Doom Condition — Embedding Stagnation:**

$$\frac{1}{W} \sum_{k=1}^{W} \text{sim}_{i,i-k} > \theta_{embed} \text{ for } n > N_{embed}$$

Where:
- $\theta_{embed} = 0.95$ (95% cosine similarity)
- $N_{embed} = 24$ steps

### 1.2 Composite Doom Score (CDS)

The unified detection metric combining all signals:

$$\text{CDS}_i = \sigma\left(\sum_{m=1}^{4} \alpha_m \cdot \hat{s}_{m,i}\right)$$

Where:
- $\hat{s}_{m,i}$ are normalized metric scores (0-1)
- $\alpha_m$ are learned weights (default: $\alpha = [0.3, 0.3, 0.25, 0.15]$)
- $\sigma(x) = \frac{1}{1+e^{-x}}$ is the sigmoid function

**Critical Threshold:**

$$\text{CDS}_i > \theta_{doom} \Rightarrow \text{Activate Termination Protocol}$$

Default: $\theta_{doom} = 0.85$

---

## 2. Architecture

### 2.1 Detection Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    SKÁLDBRØÐIR Detection Pipeline              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │ Token Stream│───▶│  Metrics    │───▶│  Composite Scoring  │ │
│  │   Input     │    │  Compute    │    │      Engine         │ │
│  └─────────────┘    └──────┬──────┘    └──────────┬──────────┘ │
│                            │                       │             │
│                            ▼                       ▼             │
│                    ┌─────────────┐          ┌─────────────┐      │
│                    │ Entropy     │          │ CDS > θ?    │      │
│                    │ Collapse    │          └──────┬──────┘      │
│                    │ Detector    │                 │             │
│                    └─────────────┘                 │ YES         │
│                            │                       │             │
│                            ▼                       ▼             │
│                    ┌─────────────┐          ┌─────────────┐      │
│                    │ Repetition  │          │ Termination │      │
│                    │ Score (TRS) │          │ Controller  │      │
│                    └─────────────┘          └─────────────┘      │
│                            │                       │             │
│                            ▼                       │             │
│                    ┌─────────────┐                 │             │
│                    │ N-gram Trap │                 │             │
│                    │ Detection   │                 │             │
│                    └─────────────┘                 │             │
│                            │                       │             │
│                            ▼                       │             │
│                    ┌─────────────┐                 │             │
│                    │ Embedding   │                 │             │
│                    │ Stagnation  │                 │             │
│                    └─────────────┘                 │             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Zero-Copy Circular Buffer

The detection system uses a lock-free circular buffer `DoomRing` (part of MimirWell):

```mojo
struct DoomRing:
    var buffer: UnsafePointer[DoomSample]
    var capacity: Int
    var write_idx: Atomic[Int]
    var read_idx: Atomic[Int]
    
    fn __init__(inout self, capacity: Int):
        self.capacity = capacity
        self.buffer = UnsafePointer[DoomSample].alloc(capacity)
        self.write_idx.store(0)
        self.read_idx.store(0)
    
    fn try_write(inout self, sample: DoomSample) -> Bool:
        let idx = self.write_idx.load()
        let next = (idx + 1) % self.capacity
        if next == self.read_idx.load():
            return False  # Buffer full
        self.buffer[idx] = sample
        self.write_idx.store(next)
        return True
    
    fn try_read(inout self) -> Optional[DoomSample]:
        let idx = self.read_idx.load()
        if idx == self.write_idx.load():
            return None  # Buffer empty
        let sample = self.buffer[idx]
        self.read_idx.store((idx + 1) % self.capacity)
        return sample
```

**DoomSample Structure:**

```mojo
struct DoomSample:
    var token_id: Int32
    var entropy: Float32
    var top_prob: Float32
    var embedding_hash: UInt64  # SimHash of hidden state
    var timestamp_ns: Int64
    var generation_step: Int32
```

---

## 3. Detection Algorithms

### 3.1 Fast Path: SIMD Entropy Check

```mojo
fn fast_entropy_check(logits: SIMD[DType.float32, 32768]) -> Float32:
    """
    Compute entropy using 32-wide SIMD lanes.
    Latency target: < 100 microseconds for 32K vocab.
    """
    var max_logit = logits.reduce_max()
    var shifted = logits - max_logit  # Numerical stability
    var exp_shifted = shifted.exp()
    var sum_exp = exp_shifted.reduce_add()
    var probs = exp_shifted / sum_exp
    
    # Entropy: -sum(p * log2(p))
    var log_probs = probs.log2()
    var entropy_vec = probs * log_probs
    var entropy = -entropy_vec.reduce_add()
    
    return entropy
```

### 3.2 Rolling Hash for N-gram Detection

Using cyclic polynomial hashing for O(1) n-gram updates:

$$H_{i+1} = (H_i \cdot a + t_{i+1}) \mod 2^{64}$$

$$H_{i-n+1}^{-1} = (H_i - t_{i-n+1} \cdot a^{n-1}) \cdot a^{-1} \mod 2^{64}$$

```mojo
fn update_rolling_hash(
    old_hash: UInt64,
    outgoing: Int32,
    incoming: Int32,
    power_table: UnsafePointer[UInt64],
    n: Int
) -> UInt64:
    """
    Update n-gram hash in O(1) time.
    """
    let a: UInt64 = 91138233  # Large prime multiplier
    let a_inv: UInt64 = 123456789  # Modular inverse
    
    var new_hash = old_hash * a + UInt64(incoming)
    new_hash -= UInt64(outgoing) * power_table[n-1]
    new_hash *= a_inv
    
    return new_hash
```

### 3.3 Bloom Filter for N-gram Frequency

Space-efficient n-gram tracking:

```mojo
struct NgramBloomFilter:
    var bits: UnsafePointer[UInt64]
    var size: Int  # Number of 64-bit words
    
    fn __init__(inout self, size_bits: Int):
        self.size = (size_bits + 63) // 64
        self.bits = UnsafePointer[UInt64].alloc(self.size)
        memset_zero(self.bits, self.size)
    
    fn _hash1(self, ngram_hash: UInt64) -> Int:
        return Int((ngram_hash * 0x9e3779b97f4a7c15) >> 32) % (self.size * 64)
    
    fn _hash2(self, ngram_hash: UInt64) -> Int:
        return Int((ngram_hash * 0xbf58476d1ce4e5b9) >> 32) % (self.size * 64)
    
    fn _hash3(self, ngram_hash: UInt64) -> Int:
        return Int((ngram_hash * 0x94d049bb133111eb) >> 32) % (self.size * 64)
    
    fn insert(inout self, ngram_hash: UInt64):
        let h1 = self._hash1(ngram_hash)
        let h2 = self._hash2(ngram_hash)
        let h3 = self._hash3(ngram_hash)
        
        atomic_or(self.bits[h1 // 64], 1 << (h1 % 64))
        atomic_or(self.bits[h2 // 64], 1 << (h2 % 64))
        atomic_or(self.bits[h3 // 64], 1 << (h3 % 64))
    
    fn query(self, ngram_hash: UInt64) -> Bool:
        let h1 = self._hash1(ngram_hash)
        let h2 = self._hash2(ngram_hash)
        let h3 = self._hash3(ngram_hash)
        
        return ((self.bits[h1 // 64] >> (h1 % 64)) & 1) != 0 and \
               ((self.bits[h2 // 64] >> (h2 % 64)) & 1) != 0 and \
               ((self.bits[h3 // 64] >> (h3 % 64)) & 1) != 0
```

---

## 4. Termination Strategies

### 4.1 Graceful Degradation Cascade

When CDS exceeds threshold, execute in order:

| Stage | Action | Latency | Recovery |
|-------|--------|---------|----------|
| 1 | Temperature perturbation | 0 cycles | Automatic |
| 2 | Top-k injection | 0 cycles | Automatic |
| 3 | Diversity penalty boost | 0 cycles | Automatic |
| 4 | Repetition penalty reset | 0 cycles | Automatic |
| 5 | Context window shift | O(n) | Automatic |
| 6 | Hard stop with partial output | Immediate | Manual review |

### 4.2 Temperature Perturbation

$$\hat{T} = T \cdot (1 + \gamma \cdot \text{CDS})$$

Where $\gamma = 0.5$ (50% temperature boost at full doom score).

### 4.3 Stochastic Resampling

Force re-roll of last $k$ tokens with adjusted distribution:

```mojo
fn emergency_resample(
    logits: inout SIMD[DType.float32, _],
    last_tokens: Span[Int32],
    penalty: Float32
) -> Int32:
    """
    Apply aggressive repetition penalty and resample.
    """
    for token in last_tokens:
        logits[token] -= penalty  # Boost diversity
    
    # Renormalize
    let max_logit = logits.reduce_max()
    let exp_logits = (logits - max_logit).exp()
    let probs = exp_logits / exp_logits.reduce_add()
    
    # Gumbel-max sampling for speed
    let gumbel = -(-random_uniform().log()).log()
    return argmax(probs.log() + gumbel)
```

---

## 5. Integration with Æsir Architecture

### 5.1 BrainForge Hook Points

```mojo
struct BrainForge:
    # ... existing fields ...
    
    var doom_detector: DoomDetector
    var doom_config: DoomConfig
    
    fn generate(inout self, request: GenerationRequest) raises -> GenerationResult:
        var tokens = request.prompt_tokens
        var step = 0
        
        while step < request.max_tokens:
            # Forward pass
            let logits = self.forward(tokens)
            
            # SKÁLDBRØÐIR: Check for doom conditions
            let doom_score = self.doom_detector.analyze(
                logits=logits,
                token_history=tokens,
                step=step
            )
            
            if doom_score > self.doom_config.threshold:
                # Attempt recovery
                let recovery = self.doom_detector.attempt_recovery(
                    inout logits,
                    inout tokens,
                    doom_score
                )
                
                if not recovery.success:
                    # Fatal doom - terminate with partial output
                    raise inf_error(
                        code=016,  # DOOM_LOOP_DETECTED
                        message="Generation entered irrecoverable doom loop",
                        context={
                            "doom_score": String(doom_score),
                            "step": String(step),
                            "recovery_attempts": String(recovery.attempts)
                        }
                    )
                
                # Recovery succeeded - continue with modified state
                tokens = recovery.new_tokens
            
            # Normal sampling
            let next_token = self.sampler.sample(logits)
            tokens.append(next_token)
            
            # Check for normal EOS
            if next_token == self.tokenizer.eos_id:
                break
            
            step += 1
        
        return GenerationResult(tokens=tokens, steps=step)
```

### 5.2 BifrostGate Error Translation

```mojo
fn translate_doom_error(err: InfError) -> HttpResponse:
    """
    Translate internal doom loop error to HTTP response.
    """
    if err.code == 016:  # DOOM_LOOP_DETECTED
        return HttpResponse(
            status=500,
            body=json({
                "error": {
                    "type": "generation_error",
                    "code": "INF-016",
                    "message": "Generation entered an irrecoverable repetition loop",
                    "param": "max_tokens",
                    "suggestion": "Try increasing temperature, reducing max_tokens, or using a different prompt",
                    "partial_output": err.context.get("partial_output", ""),
                    "doom_metrics": {
                        "final_score": err.context["doom_score"],
                        "steps_before_doom": err.context["step"]
                    }
                }
            })
        )
```

---

## 6. Performance Characteristics

### 6.1 Latency Budget

| Operation | Target Latency | Worst Case |
|-----------|---------------|------------|
| Entropy computation | 50 μs | 100 μs |
| TRS update | 10 μs | 20 μs |
| N-gram hash update | 5 μs | 10 μs |
| CDS computation | 15 μs | 30 μs |
| **Total per token** | **80 μs** | **160 μs** |

### 6.2 Memory Overhead

| Component | Size per Sequence |
|-----------|-----------------|
| DoomRing buffer | 8 KB (1024 samples) |
| N-gram Bloom filter | 4 KB |
| Embedding hash cache | 2 KB |
| **Total** | **14 KB** |

For 64 concurrent sequences: **896 KB** — fits in L3 cache.

---

## 7. Configuration

```toml
[skaldbrothir]
enabled = true
threshold = 0.85                    # CDS trigger threshold
entropy_min = 0.1                   # H_min in bits
entropy_window = 32                 # N_entropy
repetition_threshold = 0.7          # theta_rep
repetition_window = 64              # W
ngram_sizes = [2, 3, 4, 5]          # N-gram sizes to track
ngram_threshold_multiplier = 100    # theta_ngt
embedding_similarity_threshold = 0.95  # theta_embed
embedding_window = 24               # N_embed

[skaldbrothir.recovery]
temperature_boost = 0.5             # gamma
diversity_penalty = 2.0             # Repetition penalty boost
max_recovery_attempts = 3             # Before hard stop
enable_context_shift = true           # Slide context window on doom
```

---

## 8. Testing Protocol

### 8.1 Synthetic Doom Injection

```mojo
fn test_entropy_collapse():
    """
    Verify detection of near-deterministic generation.
    """
    let detector = DoomDetector(DoomConfig())
    
    # Simulate 50 steps of near-zero entropy
    for i in range(50):
        let logits = SIMD[DType.float32, 32768].splat(-100)
        logits[42] = 10.0  # One dominant token
        
        let score = detector.analyze(logits, [], i)
        
        if i > 32:
            assert score > 0.8, "Should detect entropy collapse"
```

### 8.2 Real-World Doom Scenarios

| Test Case | Expected Detection | Recovery |
|-----------|-----------------|----------|
| "The the the the..." repetition | TRS > 0.9 | Temperature boost |
| Fibonacci sequence generation | NGT > threshold | Context shift |
| Single token repetition | TRS = 1.0 | Hard stop |
| Embedding space collapse | Embedding sim > 0.99 | Diversity injection |

---

## 9. Mythological Naming Convention

Per Project Æsir's glossary standards:

| Component | Norse Name | Meaning |
|-----------|-----------|---------|
| Detection ring | **DoomRing** | The circle of fate |
| Entropy monitor | **Skáldkraptr** | Poet's trap |
| Termination controller | **RagnarökTrigger** | The final release |
| Recovery module | **VíðarrShoe** | The prepared escape |
| Metrics aggregator | **NornsThread** | Weaving destiny |

---

## 10. References

- ERROR_TAXONOMY.md: INF-011 (GENERATION_LOOP_STUCK)
- DEBUGGING_PLAYBOOK.md: Section 1.3 (Infinite EOS Suppression)
- CAPABILITY_LEDGER.md: AES-GEN-002 (Greedy Argmax Generation)
- GLOSSARY.md: Seiðr (probability manipulation)

---

*"Even the skald's endless verse must end — the weight of words becomes too heavy for the world to bear."*

---
