# core/golden_corpus.mojo
# A-113: Golden corpus -- prompts across lengths, languages,
# code, and unicode edge cases with pinned expectations per
# fixture.
#
# ACCEPTANCE (roadmap A-113): corpus in-repo with hashes;
# harness consumes it unchanged. The in-repo corpus file is
# golden_corpus.json at the repository root, mirrored row for
# row by corpus_fixtures() below (the suite cross-checks the
# two so they cannot drift silently).
#
# RAW-ORACLE DISCIPLINE (standing law): every prompt here is
# stored and used RAW, never template-rendered. A fixture
# carrying a chat-template marker is invalid by construction
# (fixture_is_raw); a rendered prompt is a comparator
# artifact, not an input. Grading against this corpus is
# teacher-forcing rank + logit gap on the raw prompt, CPU
# engine vs CPU comparator only (A-109/A-110/A-111 line).
#
# PINS (A-110 style): every fixture carries the A-110 pin
# triple -- model sha256 (the A-049-class fixture model,
# == the A-067/A-081/A-110 pin), oracle backend
# (cpu-teacher-forcing), oracle build hash -- plus its own
# prompt_hash (sha256 of the RAW prompt bytes). A fixture
# whose pins are incomplete cannot be consumed as judged
# input (fixture_pins_complete is the check).
#
# PINNED EXPECTATIONS per fixture, computed on purpleraider
# at filing time from the raw prompt bytes: byte_length
# (UTF-8 bytes), codepoint_count (UTF-8 codepoints),
# fnv1a64 (FNV-1a 64 over the raw bytes, the tree's digest
# convention). consume_corpus_unchanged() is the harness
# entry point: it re-derives every expectation from the
# stored prompt, refuses any drift, and returns the corpus
# digest, which must equal PINNED_CORPUS_DIGEST.

from core.oracle_pins import (
    ORACLE_BACKEND_CPU_TF,
    is_build_hash,
    is_sha256_hex,
)

comptime GOLDEN_MODEL_SHA256 = "7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c"
comptime GOLDEN_ORACLE_BUILD_HASH = "7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c"
comptime PINNED_CORPUS_DIGEST: UInt64 = 14447871986633844790
comptime GOLDEN_FIXTURE_COUNT = 24


def corpus_fnv1a64(text: String) -> UInt64:
    var hash: UInt64 = 14695981039346656037
    var prime: UInt64 = 1099511628211
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        hash = hash ^ UInt64(bytes[i])
        hash = hash * prime
    return hash


def utf8_codepoint_count(text: String) -> Int:
    """Codepoints in valid UTF-8: count bytes that are not
    continuation bytes (10xxxxxx)."""
    var bytes = text.as_bytes()
    var count = 0
    for i in range(len(bytes)):
        if (bytes[i] & 0xC0) != 0x80:
            count += 1
    return count


def length_class_for_bytes(n: Int) -> String:
    if n == 0:
        return String("empty")
    if n <= 24:
        return String("tiny")
    if n <= 160:
        return String("short")
    if n <= 800:
        return String("medium")
    return String("long")


struct GoldenFixture(Copyable, ImplicitlyCopyable):
    var fixture_id: String
    var category: String
    var language: String
    var length_class: String
    var prompt: String
    var prompt_hash: String
    var byte_length: Int
    var codepoint_count: Int
    var fnv1a64: UInt64

    def __init__(
        out self,
        fixture_id: String,
        category: String,
        language: String,
        length_class: String,
        prompt: String,
        prompt_hash: String,
        byte_length: Int,
        codepoint_count: Int,
        fnv1a64: UInt64,
    ):
        self.fixture_id = fixture_id
        self.category = category
        self.language = language
        self.length_class = length_class
        self.prompt = prompt
        self.prompt_hash = prompt_hash
        self.byte_length = byte_length
        self.codepoint_count = codepoint_count
        self.fnv1a64 = fnv1a64


def fixture_model_sha256() -> String:
    return String(GOLDEN_MODEL_SHA256)


def fixture_oracle_backend() -> String:
    return String(ORACLE_BACKEND_CPU_TF)


def fixture_oracle_build_hash() -> String:
    return String(GOLDEN_ORACLE_BUILD_HASH)


def fixture_pins_complete(fix: GoldenFixture) -> Bool:
    """A-110-style pins for this fixture: the shared model /
    backend / build pins are well-formed and the fixture's
    own prompt_hash is a full sha256."""
    if not is_sha256_hex(fixture_model_sha256()):
        return False
    if fixture_oracle_backend().byte_length() == 0:
        return False
    if not is_build_hash(fixture_oracle_build_hash()):
        return False
    return is_sha256_hex(fix.prompt_hash)


def fixture_is_raw(fix: GoldenFixture) -> Bool:
    """True iff the stored prompt carries no chat-template
    rendering marker (the A-109 harness marker set) and does
    not open with a BOS rendering."""
    var markers = List[String]()
    markers.append(String("<|im_start|>"))
    markers.append(String("<|im_end|>"))
    markers.append(String("<|end_of_turn|>"))
    markers.append(String("[INST]"))
    markers.append(String("[/INST]"))
    markers.append(String("<<SYS>>"))
    markers.append(String("<start_of_turn>"))
    markers.append(String("<end_of_turn>"))
    markers.append(String("### Instruction:"))
    markers.append(String("### Human:"))
    markers.append(String("### Assistant:"))
    for i in range(len(markers)):
        if markers[i] in fix.prompt:
            return False
    if fix.prompt.startswith("<s>"):
        return False
    return True


def fixture_expectations_match(fix: GoldenFixture) -> Bool:
    """Re-derive the pinned expectations from the stored raw
    prompt; any drift (an edited prompt, a re-rendered
    prompt, a truncated fixture) fails this check."""
    if fix.prompt.byte_length() != fix.byte_length:
        return False
    if utf8_codepoint_count(fix.prompt) != fix.codepoint_count:
        return False
    if corpus_fnv1a64(fix.prompt) != fix.fnv1a64:
        return False
    if length_class_for_bytes(fix.byte_length) != fix.length_class:
        return False
    return True


def corpus_fixtures() -> List[GoldenFixture]:
    var rows = List[GoldenFixture]()
    rows.append(GoldenFixture(
        "GC-001", "plain", "en", "empty",
        "",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0, 0, 14695981039346656037,
    ))
    rows.append(GoldenFixture(
        "GC-002", "plain", "en", "tiny",
        "Hello.",
        "2d8bd7d9bb5f85ba643f0110d50cb506a1fe439e769a22503193ea6046bb87f7",
        6, 6, 10530814372230066751,
    ))
    rows.append(GoldenFixture(
        "GC-003", "plain", "en", "short",
        "The raven flies at dawn over the black fjord, and the tide answers slowly.",
        "97272d7915bb8c6a838677e6b9cfc6c3a2e797e28df8a7e54fb730a9ec93dbfa",
        74, 74, 13212221078221662194,
    ))
    rows.append(GoldenFixture(
        "GC-004", "plain", "en", "medium",
        "The keeper walked the length of the hall before dawn, counting the benches and the spears by touch, because the lamps were not yet lit and the household still slept. Outside, the fjord lay flat and grey under a sky the colour of wet slate, and somewhere above the pine tops a raven called once, twice, and then was silent again.",
        "4277f19fb002f8d0081b07d463c19db4913507a43cdf37a0c18204a2220f250c",
        328, 328, 1200878800070559667,
    ))
    rows.append(GoldenFixture(
        "GC-005", "plain", "en", "long",
        "The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. The tide came in over the black stones and the ravens watched from the pine tops, silent, as they have watched every dawn since the first longship left this fjord. ",
        "f90c54c5d025c12324c620ca7e4e3d89d66be734373bb69a870bb2f42d2729a0",
        1312, 1312, 11148532359315805973,
    ))
    rows.append(GoldenFixture(
        "GC-006", "language", "de", "short",
        "Der Rabe fliegt bei Sonnenaufgang über den dunklen Fjord.",
        "93edd7491e14081732bed54e7d559218c81b729ab1a6940f440e5b45e4312be0",
        58, 57, 2804594990282777538,
    ))
    rows.append(GoldenFixture(
        "GC-007", "language", "fr", "short",
        "Le corbeau vole à l'aube au-dessus du fjord noir et froid.",
        "c2e34d72cbafa13848f66ac8b0b1ecf0189e629b2d84a6231aedcae5a9d890c5",
        59, 58, 11987584407843209521,
    ))
    rows.append(GoldenFixture(
        "GC-008", "language", "es", "short",
        "El cuervo vuela al amanecer sobre el fiordo negro y frío.",
        "8f51a3c5e02133e624e074962b06dbe84d3a77acbd42572c47f9c69fae015abe",
        58, 57, 15351982695618287184,
    ))
    rows.append(GoldenFixture(
        "GC-009", "language", "no", "short",
        "Ravnen flyr ved daggry over den svarte fjorden.",
        "591952babafc058591fb04befb1909fba6591bfc48267cd4976a04978305eea1",
        47, 47, 5797432823157300803,
    ))
    rows.append(GoldenFixture(
        "GC-010", "language", "ja", "short",
        "夜明けにカラスが黒いフィヨルドの上を飛ぶ。",
        "076591001586bab34aec984c932b81275dacdc7daf4637d4b626014dfcc467f0",
        63, 21, 14947894986100975089,
    ))
    rows.append(GoldenFixture(
        "GC-011", "language", "zh", "short",
        "黎明时分，乌鸦飞过黑色的峡湾。",
        "3ffccfcbcbdb01d485bec1efd077e980cf7d5a497f9587e8b7d7768ae86e01c0",
        45, 15, 3326514153748432090,
    ))
    rows.append(GoldenFixture(
        "GC-012", "language", "ar", "short",
        "الغراب يطير عند الفجر فوق المضيق الأسود.",
        "04d1817fd030e000b8ff3e5b6e56069b742c9546e413959d56e5e2dfdb941300",
        73, 40, 12412208634942829717,
    ))
    rows.append(GoldenFixture(
        "GC-013", "language", "mixed", "short",
        "The keeper said: Wir öffnen das Tor bei Tagesanbruch — then added: ドアを開けてください, and everyone understood.",
        "2dd06addb42bcaac40750db5260004508c3e18d1c63c9de82f2e18b665c2ec13",
        126, 103, 1951731965810895971,
    ))
    rows.append(GoldenFixture(
        "GC-014", "code", "python", "short",
        "def greet(name):\n    return f\"Hello, {name}!\"\n\nprint(greet('raven'))",
        "7b0161eed8e35b87514d46e409c205bf99bdd7f0d899326614ac4072dbcbd6ad",
        68, 68, 14922823234729178947,
    ))
    rows.append(GoldenFixture(
        "GC-015", "code", "rust", "short",
        "fn main() {\n    let ravens = 2;\n    println!(\"ravens: {}\", ravens);\n}",
        "644a93511d86cbe370e28919f55524b981a3675607e07d1d13a7f9076fac6765",
        69, 69, 4739103987852947703,
    ))
    rows.append(GoldenFixture(
        "GC-016", "code", "c", "short",
        "#include <stdio.h>\n\nint main(void) {\n    int ravens = 2;\n    printf(\"ravens: %d\\n\", ravens);\n    return 0;\n}",
        "cf650e476cc6619742a9d1c55555e3e42700450f5008229aa509e208ff27bcf7",
        108, 108, 4403437806398011989,
    ))
    rows.append(GoldenFixture(
        "GC-017", "code", "javascript", "short",
        "const ravens = ['Huginn', 'Muninn'];\nconsole.log(ravens.map(r => r.toUpperCase()));",
        "025c8b70d5584158f2e4ea1d0783a33bddf6427a266b842d114fc7a64c73475f",
        83, 83, 1141066897156889397,
    ))
    rows.append(GoldenFixture(
        "GC-018", "code", "shell", "short",
        "#!/bin/sh\nfor f in *.gguf; do\n  echo \"fixture: $f\"\ndone",
        "5d4ee5701d5b9b7046f405943cbca687d3d5477139b35ebecfdf692df2a54fc5",
        55, 55, 9918071306346925900,
    ))
    rows.append(GoldenFixture(
        "GC-019", "formal", "json", "short",
        "{\"model\": \"llama-3.1-8b\", \"quant\": \"Q4_K_M\", \"layers\": 32, \"pinned\": true}",
        "0e094cab1588418dd851db52447e6e98a50437b352d72e14c5155f59f2f1c1cb",
        74, 74, 7543976382298026138,
    ))
    rows.append(GoldenFixture(
        "GC-020", "formal", "markdown", "short",
        "# Golden corpus\n\n- raw prompts only\n- hashes pinned\n- no templates\n",
        "a798048d0b3c9e479ebd6fda7d1862670c0f6052f754108027c9a511190fd132",
        67, 67, 6725086579799491665,
    ))
    rows.append(GoldenFixture(
        "GC-021", "unicode", "runes", "short",
        "ᚠᚢᚦᚨᚱᚲ — the elder futhark opens the row: ᚠ ᚢ ᚦ.",
        "9ce99f36f810a9e7c78e3a5778db50386ab81612d3fff424a2890528501d0920",
        68, 48, 15066409589748817655,
    ))
    rows.append(GoldenFixture(
        "GC-022", "unicode", "fr", "short",
        "Café du fjord: naïve, résumé, ångström.",
        "8ddb942ae411560be2a41830c8ad5903c7343d176a646b987292ec40b92ea74d",
        50, 44, 996661916981053388,
    ))
    rows.append(GoldenFixture(
        "GC-023", "unicode", "emoji", "short",
        "Ravens 🐦, waves 🌊, fire 🔥 — dawn at the fjord, crew 👨‍👩‍👧 cheering.",
        "9af568ea6938760c0310d2dce74dfc24ebddceca1076e0d6dfb2b048ca650535",
        91, 67, 3310733507537903835,
    ))
    rows.append(GoldenFixture(
        "GC-024", "edge", "en", "short",
        "Line one.\n\tIndented line two with 0123456789.\nPrice: 1,024.50 — ratio 3.14159, exponent 1e100, zero 0, word donaustrassenbahnhaltestellenverzeichnis.\n",
        "5e0f8efa65c270f71218ccd47da49697b04e4f259f8fc4a787dd148198df3edb",
        152, 150, 15913316747980143827,
    ))
    return rows^


def corpus_digest() -> UInt64:
    """FNV-1a 64 over fixture_id | prompt_hash lines, in
    corpus order. A pure function of the filed corpus."""
    var text = String("")
    var rows = corpus_fixtures()
    for row in rows:
        text += row.fixture_id + String("|") + row.prompt_hash + String("\n")
    return corpus_fnv1a64(text)


def consume_corpus_unchanged() raises -> Int:
    """The harness consumption point for the A-113
    acceptance: validate every fixture (pins complete, raw,
    pinned expectations re-derived exactly) and return the
    fixture count, having first proven the corpus digest
    still equals the pinned digest -- the corpus reached
    the harness unchanged. Raises, naming the fixture, on
    any drift."""
    var rows = corpus_fixtures()
    if len(rows) != GOLDEN_FIXTURE_COUNT:
        raise Error("A-113: corpus count drifted: " + String(len(rows)))
    if corpus_digest() != PINNED_CORPUS_DIGEST:
        raise Error("A-113: corpus digest drifted from the pinned digest")
    for row in rows:
        if not fixture_pins_complete(row):
            raise Error("A-113: fixture pins incomplete: " + row.fixture_id)
        if not fixture_is_raw(row):
            raise Error("A-113: fixture prompt is template-rendered, not raw: " + row.fixture_id)
        if not fixture_expectations_match(row):
            raise Error("A-113: fixture expectations drifted: " + row.fixture_id)
    return len(rows)


def golden_corpus_summary() -> String:
    return String(
        "A-113 golden corpus: prompts across lengths,"
        " languages, code and unicode edge cases with pinned"
        " expectations per fixture; corpus in-repo with"
        " hashes; harness consumes it unchanged"
    )
