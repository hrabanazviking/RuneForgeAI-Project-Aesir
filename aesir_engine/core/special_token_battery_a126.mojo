"""A-126: Special-token handling -- EOS/BOS/pad
behaviour per family across backends, with
stop-reason correctness (Wave 14 closer,
Architecture breadth).

The roadmap text: "Special-token handling.
EOS/BOS/pad behaviour per family across
backends. Acceptance: battery judged;
stop-reason correctness included."

THE SURFACE, HONESTLY (what exists to judge):
No filed record anywhere in this tree grades
special-token or stop behaviour per family
(A-109/A-114/A-115/A-118/A-119/A-120 contain
zero EOS/BOS/pad grades; the only adjacent
surfaces are A-050's tokenizer specials and
aesir.mojo's generation_stop_reason). This
slice builds the per-family special-token
surface as a pure, stated module filed from
the banked records below, EXECUTES the banked
rules it can execute (the RuneWeaver BOS gate;
the stop-rule precedence transcribed from
aesir.mojo and cross-verified against the
real function in the suite), and judges every
family x backend row. The filed records:

  * Dense GQA profiles (core/
    dense_gqa_profile.mojo), CALLED, never
    re-typed: llama3_8b_profile and
    llama3_2_3b_profile carry eos 128001 and
    end_of_turn 128009 with add_bos True;
    qwen3_0_6b_profile and qwen2_coder_7b_
    profile carry eos 151645 and end_of_turn
    151645 (the same token) with add_bos
    False.
  * The native BPE tokenizer (loader/
    llama3_tokenizer.mojo) validates the
    Llama 3 control layout by value: BOS
    <|begin_of_text|> = 128000, <|eot_id|> =
    128009, <|end_of_text|> = 128001, and
    metadata eos in (128001, 128009); for
    Qwen it validates <|endoftext|> = 151643,
    <|im_start|> = 151644, <|im_end|> =
    151645, bos 151643, eos 151645.
  * The GGUF/RuneWeaver surface (loader/
    gguf.mojo) parses tokenizer.ggml.
    bos_token_id / eos_token_id /
    add_bos_token, and for qwen2/qwen3/
    qwen35 it forces add_bos_token False
    (its transient bos -1 assignment is
    overwritten by the set_special_tokens
    call from GGUF metadata immediately
    after, so the operative filed facts are:
    BOS is never prepended for Qwen on this
    surface, and the bos id is metadata-
    carried). The native tokenizer instead
    pins bos 151643 <|endoftext|> by value.
    Both surfaces agree add_bos is False
    and eos is 151645 <|im_end|>. The qwen
    specs below therefore file bos as
    SB_FROM_METADATA with the native
    spelling, and judge the add_bos rule.
  * The CUDA dense sessions stop on BOTH
    terminators where a family has two:
    core/llama3_cuda.mojo files finish
    "eos" when token == eos_token_id OR
    token == end_of_turn_token_id;
    core/gemma4_cuda.mojo files finish "eos"
    when token == vocabulary.eos_token_id OR
    token == control("<eos>").
  * The CPU generate path (aesir.mojo)
    stops on ONE id only: the generate loop
    checks next_token == tokenizer.
    eos_token_id, and generation_stop_reason
    takes a single eos_token_id. No caller
    files the turn token into stop_tokens.
  * PAD: no pad surface exists anywhere in
    the engine -- no pad field on any
    tokenizer, no tokenizer.ggml.
    padding_token_id key in the GGUF parser,
    no pad masking in any session. Every
    family's pad is filed -1, NO_PAD_SURFACE.
    (The zero-padded KV rows in core/
    inference.mojo are memory layout, not a
    pad token.)
  * Gemma 4 token ids are METADATA-carried:
    loader/gemma4_tokenizer.mojo calls
    set_special_tokens(unknown, bos, eos)
    straight from the model's GGUF keys and
    pins no numeric ids in code (the filed
    fixture aesir_engine/tests/fixtures/
    gemma4_tokenizer.json states explicit
    GGUF BOS = 2 for unsloth/gemma-4-E4B-it;
    no EOS id is pinned anywhere); its prompt
    turns are token-level (<|turn>/<turn|>,
    loader/gemma4_tokenizer append_message)
    and its generation stop is the eos rule
    above. The gemma4 spec therefore files
    spellings (<bos>/<eos>) and the sentinel
    SB_FROM_METADATA (-2) for its ids.
  * mistral3 is an A-114 matrix arch with NO
    tokenizer surface anywhere in the tree:
    no spec can be filed, so its rows are
    NOT_GRADED / NO_FILED_SURFACE.

THE GENUINE DIVERGENCE THIS BATTERY FILES:
for the llama family the filed stop set is
{eos 128001, turn 128009} (dense profile +
CUDA session), but the CPU generate path's
stop set is the single metadata eos alone,
so whichever terminator is NOT the metadata
eos does NOT stop CPU generation. The filed
A-104 GGUF record (hidden_files/a104/
cpu0_verbose.log, Meta-Llama-3.1-8B-
Instruct) files tokenizer.ggml.eos_token_id
= 128009, so on the tree's own reference
model a generated <|end_of_text|> (128001)
runs on; with eos metadata 128001 the
mirror case holds for <|eot_id|>
(generation_stop_reason(128009, eos=128001)
== "" -- suite-proven in tests/test_special_
token_battery_a126.mojo against the real
function). The llama cpu row is therefore
DIVERGENT / STOP_SET_INCOMPLETE: a genuine
ENGINE row, so A-116 is the named tool for
it and its Wave-14 in-anger condition IS
met by this row (the first Wave-14 battery
to file one). The fix surface is named, not
hidden: give the CPU path the family's
turn token (a second stop id on the
tokenizer surface, populated from the
profile/GGUF record, checked beside
eos_token_id in the loop and in
generation_stop_reason). It is recorded as
the immediate next work in this team's
CAMPAIGN_STATE.md; this battery files the
verdict and does not silently re-wire the
generate path mid-battery.

AXES: families (5: llama, qwen2, qwen3,
gemma4, mistral3 -- the A-118/A-119/A-120
battery families split at the profile level,
plus the orphan A-114 matrix arch) x
backends (4, exactly A-109's
tf_harness_backends: cpu, vulkan, hip, npu,
called, never re-typed) = 20 rows. Every
row carries a verdict and the A-115 policy
obligation of the reference quant (Q4_K_M
-> TOKEN_EXACTNESS_OWED, read from the
banked core/exactness_policy.mojo by call).

THE VERDICT RULE, PRE-REGISTERED. For one
row (family, backend), in order:
  (S1) backend != cpu -> NOT_GRADED, reason
       BACKEND_NO_CPU_COMPARATOR. Grading is
       CPU vs CPU only; no device-execution
       evidence is filed for vulkan/hip/npu,
       and accelerator-visible is NOT
       accelerator-run.
  (S2) cpu + family has no filed surface
       (mistral3) -> NOT_GRADED, reason
       NO_FILED_SURFACE.
  (S3) a cpu row with a surface -> the
       executed checks over the family's
       filed spec:
       (a) BOS rule, EXECUTED on the banked
           RuneWeaver: a proxy weaver
           (unk 0 / bos 1 / eos 2, stated
           proxy ids; the rule, not the ids,
           is what executes) with
           add_bos_token set to the spec's
           filed flag must satisfy
           encode("", True) == [bos] iff
           add_bos else [], and
           encode("", False) == [] always;
       (b) EOS stop: the engine stop
           transcription at the family's eos
           returns "eos", and the engine's
           filed eos equals the spec eos
           (or both are the metadata
           sentinel);
       (c) turn stop: when the spec files a
           turn terminator distinct from
           eos, the engine's filed stop set
           must contain it, else DIVERGENT /
           STOP_SET_INCOMPLETE;
       (d) pad: filed as data on every row
           (pad id and NO_PAD_SURFACE); it
           drives no verdict, because the
           absence IS the filed behaviour.
       All checks pass -> FAITHFUL, reason
       SPECIAL_TOKEN_CHECKS_PASS.

STOP-REASON CORRECTNESS (the acceptance's
second clause) is judged on a scenario grid:
6 scenarios per family (EOS_TOKEN,
TURN_TOKEN, STOP_TOKEN, LENGTH, CONTEXT,
CONTINUE) under the filed precedence of
aesir.mojo generation_stop_reason (eos set
-> stop_token -> length -> context_
exhausted -> continue). The grid compares
the SPEC stop rule (the family's full filed
stop set) against the ENGINE stop
transcription (the single-eos rule exactly
as banked); the transcription is verified
against the real generation_stop_reason in
the suite, so the grid judges banked
behaviour, not a replica's opinion. The
llama TURN_TOKEN scenario is the grid's one
DIVERGENT cell and drives the llama row.

TEACHER-FORCING ACCOUNT, filed not hidden:
no teacher-forcing record grades special
tokens on any family, so the TF account is
total 20, graded 0, not_graded 20
(NO_FILED_RECORDS). This battery grades
behaviour rules, not logits; the near-tie
band (A-111) is not invoked.

RAW-ORACLE DISCIPLINE (standing): RAW
stated inputs only, CPU rule vs CPU filed
record only, comparator artifacts are a
verdict class, and no accelerator claim is
made without device-execution evidence.
The battery executes no model on this
machine and opens no device.
"""

from core.dense_gqa_profile import (
    llama3_2_3b_profile,
    llama3_8b_profile,
    qwen2_coder_7b_profile,
    qwen3_0_6b_profile,
)
from core.exactness_policy import (
    POLICY_COHERENCE_ONLY,
    POLICY_TOKEN_EXACTNESS_OWED,
    obligation_name,
    policy_for_quant,
)
from core.matrix_runner import (
    MX_COMPARATOR_ARTIFACT,
    MX_DIVERGENT,
    MX_FAITHFUL,
    MX_FAITHFUL_NEAR_TIE,
    MX_FIXTURE_LIMITED,
    MX_NOT_GRADED,
    matrix_verdict_name,
    mx_fnv1a64,
)
from core.teacher_forcing_harness import tf_harness_backends
from loader.tokenizer import RuneWeaver

comptime SB_MODEL_QUANT = "Q4_K_M"
comptime SB_GRADED_BACKEND = "cpu"
comptime SB_FROM_METADATA = -2
comptime SB_NO_PAD = -1
comptime SB_FIXTURE_STATUS = "SYNTHETIC"
comptime SB_TF_REASON = "NO_FILED_RECORDS"
comptime SB_SCENARIOS = 6


struct SpecialSpec(Copyable, ImplicitlyCopyable):
    """One family's filed special-token spec.

    Ids are the family's own filed ids (or
    SB_FROM_METADATA when the tree carries
    them only in GGUF metadata). engine_eos
    and engine_turn are the CPU generate
    path's filed stop set: the single eos it
    checks, and the turn id it also stops
    on (-1 when it stops on none -- for
    qwen the turn IS the eos, so engine_turn
    files the eos value)."""

    var family: String
    var arch: String
    var has_surface: Bool
    var bos_id: Int
    var bos_spelling: String
    var add_bos: Bool
    var eos_id: Int
    var eos_spelling: String
    var turn_id: Int
    var turn_spelling: String
    var pad_id: Int
    var engine_eos: Int
    var engine_turn: Int

    def __init__(
        out self,
        family: String,
        arch: String,
        has_surface: Bool,
        bos_id: Int,
        bos_spelling: String,
        add_bos: Bool,
        eos_id: Int,
        eos_spelling: String,
        turn_id: Int,
        turn_spelling: String,
        pad_id: Int,
        engine_eos: Int,
        engine_turn: Int,
    ):
        self.family = family
        self.arch = arch
        self.has_surface = has_surface
        self.bos_id = bos_id
        self.bos_spelling = bos_spelling
        self.add_bos = add_bos
        self.eos_id = eos_id
        self.eos_spelling = eos_spelling
        self.turn_id = turn_id
        self.turn_spelling = turn_spelling
        self.pad_id = pad_id
        self.engine_eos = engine_eos
        self.engine_turn = engine_turn


def family_specs() -> List[SpecialSpec]:
    """The filed per-family specs. Dense
    profile values are read BY CALL from the
    banked profiles; the remaining constants
    are the values the banked tokenizers
    validate by value (see the header)."""
    var specs = List[SpecialSpec]()
    var llama = llama3_8b_profile()
    specs.append(
        SpecialSpec(
            String("llama"), String("llama"), True,
            128000, String("<|begin_of_text|>"),
            llama.add_bos,
            llama.eos_token_id, String("<|end_of_text|>"),
            llama.end_of_turn_token_id, String("<|eot_id|>"),
            SB_NO_PAD, llama.eos_token_id, -1,
        )
    )
    var qwen2 = qwen2_coder_7b_profile()
    specs.append(
        SpecialSpec(
            String("qwen2"), String("qwen2"), True,
            SB_FROM_METADATA, String("<|endoftext|>"),
            qwen2.add_bos,
            qwen2.eos_token_id, String("<|im_end|>"),
            qwen2.end_of_turn_token_id, String("<|im_end|>"),
            SB_NO_PAD, qwen2.eos_token_id,
            qwen2.end_of_turn_token_id,
        )
    )
    var qwen3 = qwen3_0_6b_profile()
    specs.append(
        SpecialSpec(
            String("qwen3"), String("qwen3"), True,
            SB_FROM_METADATA, String("<|endoftext|>"),
            qwen3.add_bos,
            qwen3.eos_token_id, String("<|im_end|>"),
            qwen3.end_of_turn_token_id, String("<|im_end|>"),
            SB_NO_PAD, qwen3.eos_token_id,
            qwen3.end_of_turn_token_id,
        )
    )
    specs.append(
        SpecialSpec(
            String("gemma4"), String("gemma4"), True,
            SB_FROM_METADATA, String("<bos>"),
            True,
            SB_FROM_METADATA, String("<eos>"),
            -1, String(""),
            SB_NO_PAD, SB_FROM_METADATA, -1,
        )
    )
    specs.append(
        SpecialSpec(
            String("mistral3"), String("mistral3"), False,
            -1, String(""),
            False,
            -1, String(""),
            -1, String(""),
            SB_NO_PAD, -1, -1,
        )
    )
    return specs^


def family_indices() -> List[Int]:
    var idx = List[Int]()
    for i in range(5):
        idx.append(i)
    return idx^


def battery_backends() -> List[String]:
    return tf_harness_backends()


def policy_obligation() raises -> Int:
    """The A-115 obligation of the reference
    quant, read from the banked policy table
    by call."""
    var row = policy_for_quant(String(SB_MODEL_QUANT))
    return row.obligation


def bos_rule_ok(spec: SpecialSpec) raises -> Bool:
    """S3(a), EXECUTED on the banked
    RuneWeaver BOS gate with stated proxy
    ids (unk 0 / bos 1 / eos 2): encode of
    the empty prompt with add_bos requested
    yields exactly [bos] iff the family's
    filed add_bos flag is set, and yields
    [] when BOS is not requested."""
    var w = RuneWeaver()
    w.set_special_tokens(0, 1, 2)
    w.add_bos_token = spec.add_bos
    var with_bos = w.encode(String(""), True)
    var without = w.encode(String(""), False)
    if len(without) != 0:
        return False
    if spec.add_bos:
        return len(with_bos) == 1 and with_bos[0] == 1
    return len(with_bos) == 0


def engine_stop_reason(
    eos_id: Int,
    token: Int,
    count: Int,
    max_new: Int,
    next_pos: Int,
    ctx: Int,
    stop_tokens: List[Int],
) -> String:
    """Transcription of the banked CPU rule
    (aesir.mojo generation_stop_reason),
    value-for-value: a single eos id, then
    caller stop tokens, then length, then
    context. The suite cross-verifies this
    transcription against the real function
    over the whole scenario grid."""
    if eos_id >= 0 and token == eos_id:
        return String("eos")
    if token in stop_tokens:
        return String("stop_token")
    if count >= max_new:
        return String("length")
    if next_pos >= ctx:
        return String("context_exhausted")
    return String("")


def spec_stop_reason(
    spec: SpecialSpec,
    token: Int,
    count: Int,
    max_new: Int,
    next_pos: Int,
    ctx: Int,
    stop_tokens: List[Int],
) -> String:
    """The family's filed stop rule: the
    full filed stop set (eos, plus the turn
    terminator when the family files one)
    under the same precedence as the engine
    rule."""
    if token == spec.eos_id and spec.eos_id >= 0:
        return String("eos")
    if spec.turn_id >= 0 and token == spec.turn_id:
        return String("eos")
    if token in stop_tokens:
        return String("stop_token")
    if count >= max_new:
        return String("length")
    if next_pos >= ctx:
        return String("context_exhausted")
    return String("")


def scenario_token(spec: SpecialSpec, scenario: Int) -> Int:
    """The generated token of scenario
    0..5: EOS_TOKEN, TURN_TOKEN, STOP_TOKEN
    (a caller stop token, filed as 4242 in
    the grid), LENGTH / CONTEXT / CONTINUE
    (an ordinary token, 777). For gemma4
    the metadata sentinel stands in for the
    eos id, stated as such."""
    if scenario == 0:
        return spec.eos_id
    if scenario == 1:
        return spec.turn_id
    if scenario == 2:
        return 4242
    return 777


def scenario_engine_reason(spec: SpecialSpec, scenario: Int) -> String:
    """The engine transcription's outcome
    for one grid scenario. Grid constants:
    count 1 of max 16, next_pos 8 of ctx
    128, except LENGTH (count 16) and
    CONTEXT (next_pos 128). The engine eos
    is the family's filed engine_eos (the
    metadata sentinel for gemma4, where the
    scenario token is the same sentinel, so
    the eos scenario still discriminates
    the rule's shape)."""
    var stops = List[Int]()
    stops.append(4242)
    var sp = spec
    if sp.eos_id == SB_FROM_METADATA:
        sp.eos_id = 2
    var engine_eos = spec.engine_eos
    if engine_eos == SB_FROM_METADATA:
        engine_eos = 2
    var token = scenario_token(sp, scenario)
    if scenario == 3:
        return engine_stop_reason(
            engine_eos, token, 16, 16, 8, 128, stops
        )
    if scenario == 4:
        return engine_stop_reason(
            engine_eos, token, 1, 16, 128, 128, stops
        )
    return engine_stop_reason(
        engine_eos, token, 1, 16, 8, 128, stops
    )


def scenario_spec_reason(spec: SpecialSpec, scenario: Int) -> String:
    """The spec rule's outcome for one grid
    scenario, same constants as the engine
    side. A family with no turn terminator
    files TURN_TOKEN as an ordinary token
    (continue), matching its filed surface."""
    var stops = List[Int]()
    stops.append(4242)
    var sp = spec
    if sp.eos_id == SB_FROM_METADATA:
        sp.eos_id = 2
    var token = scenario_token(sp, scenario)
    if scenario == 3:
        return spec_stop_reason(sp, token, 16, 16, 8, 128, stops)
    if scenario == 4:
        return spec_stop_reason(sp, token, 1, 16, 128, 128, stops)
    return spec_stop_reason(sp, token, 1, 16, 8, 128, stops)


def scenario_agrees(spec: SpecialSpec, scenario: Int) -> Bool:
    return scenario_engine_reason(spec, scenario) == scenario_spec_reason(
        spec, scenario
    )


def _verdict_code(name: String) -> Int:
    if name == String("FAITHFUL"):
        return MX_FAITHFUL
    if name == String("FAITHFUL_NEAR_TIE"):
        return MX_FAITHFUL_NEAR_TIE
    if name == String("DIVERGENT"):
        return MX_DIVERGENT
    if name == String("COMPARATOR_ARTIFACT"):
        return MX_COMPARATOR_ARTIFACT
    if name == String("FIXTURE_LIMITED"):
        return MX_FIXTURE_LIMITED
    return MX_NOT_GRADED


struct BatteryRow(Copyable, ImplicitlyCopyable):
    var family: Int
    var family_name: String
    var arch: String
    var backend: String
    var verdict: Int
    var reason: String
    var obligation: Int
    var bos_id: Int
    var eos_id: Int
    var turn_id: Int
    var pad_id: Int
    var add_bos: Bool
    var scenarios: Int
    var scenarios_agree: Int

    def __init__(
        out self,
        family: Int,
        family_name: String,
        arch: String,
        backend: String,
        verdict: Int,
        reason: String,
        obligation: Int,
        bos_id: Int,
        eos_id: Int,
        turn_id: Int,
        pad_id: Int,
        add_bos: Bool,
        scenarios: Int,
        scenarios_agree: Int,
    ):
        self.family = family
        self.family_name = family_name
        self.arch = arch
        self.backend = backend
        self.verdict = verdict
        self.reason = reason
        self.obligation = obligation
        self.bos_id = bos_id
        self.eos_id = eos_id
        self.turn_id = turn_id
        self.pad_id = pad_id
        self.add_bos = add_bos
        self.scenarios = scenarios
        self.scenarios_agree = scenarios_agree


def battery_row_verdict(
    family_index: Int,
    spec: SpecialSpec,
    backend: String,
    obligation: Int,
) raises -> BatteryRow:
    if backend != String(SB_GRADED_BACKEND):
        return BatteryRow(
            family_index, spec.family, spec.arch, backend,
            MX_NOT_GRADED,
            String("BACKEND_NO_CPU_COMPARATOR"), obligation,
            spec.bos_id, spec.eos_id, spec.turn_id,
            spec.pad_id, spec.add_bos, 0, 0,
        )
    if not spec.has_surface:
        return BatteryRow(
            family_index, spec.family, spec.arch, backend,
            MX_NOT_GRADED,
            String("NO_FILED_SURFACE"), obligation,
            spec.bos_id, spec.eos_id, spec.turn_id,
            spec.pad_id, spec.add_bos, 0, 0,
        )
    var agree = 0
    for s in range(SB_SCENARIOS):
        if scenario_agrees(spec, s):
            agree += 1
    if not bos_rule_ok(spec):
        return BatteryRow(
            family_index, spec.family, spec.arch, backend,
            MX_DIVERGENT,
            String("BOS_RULE_MISMATCH"), obligation,
            spec.bos_id, spec.eos_id, spec.turn_id,
            spec.pad_id, spec.add_bos, SB_SCENARIOS, agree,
        )
    if spec.turn_id >= 0 and spec.turn_id != spec.eos_id:
        if spec.engine_turn != spec.turn_id and spec.engine_eos != spec.turn_id:
            return BatteryRow(
                family_index, spec.family, spec.arch, backend,
                MX_DIVERGENT,
                String("STOP_SET_INCOMPLETE"), obligation,
                spec.bos_id, spec.eos_id, spec.turn_id,
                spec.pad_id, spec.add_bos, SB_SCENARIOS, agree,
            )
    if agree != SB_SCENARIOS:
        return BatteryRow(
            family_index, spec.family, spec.arch, backend,
            MX_DIVERGENT,
            String("STOP_REASON_MISMATCH"), obligation,
            spec.bos_id, spec.eos_id, spec.turn_id,
            spec.pad_id, spec.add_bos, SB_SCENARIOS, agree,
        )
    return BatteryRow(
        family_index, spec.family, spec.arch, backend,
        MX_FAITHFUL,
        String("SPECIAL_TOKEN_CHECKS_PASS"), obligation,
        spec.bos_id, spec.eos_id, spec.turn_id,
        spec.pad_id, spec.add_bos, SB_SCENARIOS, agree,
    )


def _check_families(idxs: List[Int]) raises:
    if len(idxs) == 0:
        raise Error("SpecialTokenBattery: family axis is empty")
    for i in range(len(idxs)):
        if idxs[i] < 0 or idxs[i] > 4:
            raise Error(
                "SpecialTokenBattery: family index out of range "
                + String(idxs[i])
            )
        for j in range(i + 1, len(idxs)):
            if idxs[i] == idxs[j]:
                raise Error(
                    "SpecialTokenBattery: duplicate family entry "
                    + String(idxs[i])
                )


def _check_backends(backends: List[String]) raises:
    if len(backends) == 0:
        raise Error("SpecialTokenBattery: backend axis is empty")
    for i in range(len(backends)):
        for j in range(i + 1, len(backends)):
            if backends[i] == backends[j]:
                raise Error(
                    "SpecialTokenBattery: duplicate backend entry "
                    + backends[i]
                )


def build_battery(
    idxs: List[Int], backends: List[String]
) raises -> List[BatteryRow]:
    _check_families(idxs)
    _check_backends(backends)
    var obligation = policy_obligation()
    var specs = family_specs()
    var rows = List[BatteryRow]()
    for fi in range(len(idxs)):
        for bi in range(len(backends)):
            rows.append(
                battery_row_verdict(
                    idxs[fi],
                    specs[idxs[fi]],
                    backends[bi],
                    obligation,
                )
            )
    return rows^


# --- The SYNTHETIC fixture (status: SYNTHETIC, never
# hidden). Seeded defect stop rules judged against the
# llama family's filed spec by the same scenario grid;
# every defect is named. ---


struct SynCase(Copyable, ImplicitlyCopyable):
    var name: String
    var verdict: Int
    var reason: String

    def __init__(out self, name: String, verdict: Int, reason: String):
        self.name = name
        self.verdict = verdict
        self.reason = reason


def _grid_all_agree(spec: SpecialSpec) -> Bool:
    for s in range(SB_SCENARIOS):
        if not scenario_agrees(spec, s):
            return False
    return True


def syn_cases() -> List[SynCase]:
    var cases = List[SynCase]()
    var specs = family_specs()
    var llama = specs[0]
    if _grid_all_agree(specs[1]):
        cases.append(
            SynCase(
                String("SYN_OK"), MX_FAITHFUL,
                String("SYNTHETIC_SPEC_GRID_MATCH"),
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_OK"), MX_DIVERGENT,
                String("SYNTHETIC_SPEC_GRID_MISMATCH"),
            )
        )
    # Seeded defect: an eos-only stop set judged
    # against the llama spec (whose filed turn
    # terminator it drops).
    if scenario_spec_reason(llama, 1) == String("eos") and engine_stop_reason(
        llama.engine_eos, llama.turn_id, 1, 16, 8, 128, List[Int]()
    ) == String(""):
        cases.append(
            SynCase(
                String("SYN_EOS_ONLY"), MX_DIVERGENT,
                String("STOP_SET_INCOMPLETE"),
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_EOS_ONLY"), MX_FAITHFUL,
                String("SYNTHETIC_EOS_ONLY_UNEXPECTED_PASS"),
            )
        )
    # Seeded defect: the turn terminator decoded
    # as ordinary text (never a stop).
    if spec_stop_reason(llama, llama.turn_id, 1, 16, 8, 128, List[Int]()) == String("eos"):
        cases.append(
            SynCase(
                String("SYN_TURN_AS_TEXT"), MX_DIVERGENT,
                String("TURN_TOKEN_NOT_A_STOP"),
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_TURN_AS_TEXT"), MX_FAITHFUL,
                String("SYNTHETIC_TURN_UNEXPECTED_PASS"),
            )
        )
    # Seeded defect: a rule that stops on token 0
    # as if it were a pad-as-EOS, where the spec
    # files NO pad surface at all.
    if llama.pad_id == SB_NO_PAD and engine_stop_reason(
        0, 0, 1, 16, 8, 128, List[Int]()
    ) == String("eos"):
        cases.append(
            SynCase(
                String("SYN_PAD_AS_EOS"), MX_DIVERGENT,
                String("PAD_TOKEN_AS_STOP"),
            )
        )
    else:
        cases.append(
            SynCase(
                String("SYN_PAD_AS_EOS"), MX_FAITHFUL,
                String("SYNTHETIC_PAD_UNEXPECTED_PASS"),
            )
        )
    cases.append(
        SynCase(
            String("SYN_MISMATCH"), MX_COMPARATOR_ARTIFACT,
            String("BACKEND_MISMATCH"),
        )
    )
    return cases^


struct BatteryReport(Copyable, Movable):
    var rows: List[BatteryRow]
    var syn: List[SynCase]
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int
    var owed: Int
    var coherence: Int
    var tf_total: Int
    var tf_graded: Int
    var tf_not_graded: Int
    var syn_total: Int
    var syn_faithful: Int
    var syn_divergent: Int
    var syn_artifact: Int
    var digest: UInt64

    def __init__(
        out self,
        rows: List[BatteryRow],
        syn: List[SynCase],
        total: Int,
        faithful: Int,
        near_tie: Int,
        divergent: Int,
        artifact: Int,
        fixture_limited: Int,
        not_graded: Int,
        owed: Int,
        coherence: Int,
        tf_total: Int,
        tf_graded: Int,
        tf_not_graded: Int,
        syn_total: Int,
        syn_faithful: Int,
        syn_divergent: Int,
        syn_artifact: Int,
        digest: UInt64,
    ):
        self.rows = rows.copy()
        self.syn = syn.copy()
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded
        self.owed = owed
        self.coherence = coherence
        self.tf_total = tf_total
        self.tf_graded = tf_graded
        self.tf_not_graded = tf_not_graded
        self.syn_total = syn_total
        self.syn_faithful = syn_faithful
        self.syn_divergent = syn_divergent
        self.syn_artifact = syn_artifact
        self.digest = digest


def run_battery() raises -> BatteryReport:
    var rows = build_battery(family_indices(), battery_backends())
    var faithful = 0
    var near_tie = 0
    var divergent = 0
    var artifact = 0
    var fixture_limited = 0
    var not_graded = 0
    var owed = 0
    var coherence = 0
    for i in range(len(rows)):
        var v = rows[i].verdict
        if v == MX_FAITHFUL:
            faithful += 1
        elif v == MX_FAITHFUL_NEAR_TIE:
            near_tie += 1
        elif v == MX_DIVERGENT:
            divergent += 1
        elif v == MX_COMPARATOR_ARTIFACT:
            artifact += 1
        elif v == MX_FIXTURE_LIMITED:
            fixture_limited += 1
        else:
            not_graded += 1
        if rows[i].obligation == POLICY_COHERENCE_ONLY:
            coherence += 1
        else:
            owed += 1
    var syn = syn_cases()
    var syn_faithful = 0
    var syn_divergent = 0
    var syn_artifact = 0
    for i in range(len(syn)):
        if syn[i].verdict == MX_FAITHFUL:
            syn_faithful += 1
        elif syn[i].verdict == MX_DIVERGENT:
            syn_divergent += 1
        elif syn[i].verdict == MX_COMPARATOR_ARTIFACT:
            syn_artifact += 1
    var report = BatteryReport(
        rows.copy(), syn.copy(), len(rows), faithful, near_tie,
        divergent, artifact, fixture_limited, not_graded, owed,
        coherence, len(rows), 0, len(rows), len(syn),
        syn_faithful, syn_divergent, syn_artifact, UInt64(0),
    )
    report.digest = mx_fnv1a64(battery_render(report.copy()))
    return report^


def battery_row_line(row: BatteryRow) -> String:
    var s = String("ST_ROW family=") + row.family_name
    s += String(" arch=") + row.arch
    s += String(" backend=") + row.backend
    s += String(" verdict=") + matrix_verdict_name(row.verdict)
    s += String(" reason=") + row.reason
    s += String(" policy=") + obligation_name(row.obligation)
    s += String(" bos=") + String(row.bos_id)
    s += String(" eos=") + String(row.eos_id)
    s += String(" turn=") + String(row.turn_id)
    s += String(" pad=") + String(row.pad_id)
    s += String(" add_bos=") + (String("true") if row.add_bos else String("false"))
    s += String(" scenarios=") + String(row.scenarios)
    s += String(" scenarios_agree=") + String(row.scenarios_agree)
    return s


def syn_case_line(scase: SynCase) -> String:
    var s = String("ST_SYN case=") + scase.name
    s += String(" status=") + String(SB_FIXTURE_STATUS)
    s += String(" verdict=") + matrix_verdict_name(scase.verdict)
    s += String(" reason=") + scase.reason
    return s


def battery_render(read report: BatteryReport) -> String:
    var s = String("A126_BATTERY families=")
    s += String(len(family_indices()))
    s += String(" backends=") + String(len(battery_backends()))
    s += String(" total=") + String(report.total)
    s += String(" fixture_status=") + String(SB_FIXTURE_STATUS)
    s += String("\n")
    for i in range(len(report.rows)):
        s += battery_row_line(report.rows[i]) + String("\n")
    for i in range(len(report.syn)):
        s += syn_case_line(report.syn[i]) + String("\n")
    s += String("A126_BATTERY_SUMMARY total=") + String(report.total)
    s += String(" faithful=") + String(report.faithful)
    s += String(" near_tie=") + String(report.near_tie)
    s += String(" divergent=") + String(report.divergent)
    s += String(" artifact=") + String(report.artifact)
    s += String(" fixture_limited=") + String(report.fixture_limited)
    s += String(" not_graded=") + String(report.not_graded)
    s += String(" owed=") + String(report.owed)
    s += String(" coherence=") + String(report.coherence)
    s += String("\n")
    s += String("A126_TF_ACCOUNT total=") + String(report.tf_total)
    s += String(" graded=") + String(report.tf_graded)
    s += String(" not_graded=") + String(report.tf_not_graded)
    s += String(" reason=") + String(SB_TF_REASON)
    s += String("\n")
    s += String("A126_SYNTHETIC_SUMMARY status=")
    s += String(SB_FIXTURE_STATUS)
    s += String(" total=") + String(report.syn_total)
    s += String(" faithful=") + String(report.syn_faithful)
    s += String(" divergent=") + String(report.syn_divergent)
    s += String(" artifact=") + String(report.syn_artifact)
    return s


def battery_line() -> String:
    return String(
        "A-126 Special-token handling: 5 families"
        " x 4 Z13 backends judged on filed"
        " EOS/BOS/pad specs (dense profiles by"
        " call, tokenizer validations, session"
        " stop records); BOS rule executed on"
        " the banked RuneWeaver; stop-reason"
        " scenario grid judged (llama cpu row"
        " DIVERGENT, STOP_SET_INCOMPLETE);"
        " synthetic defect fixture labelled"
        " SYNTHETIC in every line; non-cpu rows"
        " NOT_GRADED with a named reason, zero"
        " unexplained"
    )
