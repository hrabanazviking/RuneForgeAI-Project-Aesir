# tests/test_golden_corpus_a113.mojo
# A-113: Golden corpus -- the filed corpus covers lengths,
# languages, code and unicode edge cases; every fixture is
# raw, fully pinned (A-110 style) and matches its pinned
# expectations; the in-repo corpus file mirrors the module;
# the harness consumes the corpus unchanged.

from core.golden_corpus import (
    GOLDEN_FIXTURE_COUNT,
    PINNED_CORPUS_DIGEST,
    consume_corpus_unchanged,
    corpus_digest,
    corpus_fixtures,
    fixture_expectations_match,
    fixture_is_raw,
    fixture_pins_complete,
    golden_corpus_summary,
    length_class_for_bytes,
)


def _corpus_text() raises -> String:
    try:
        with open("golden_corpus.json", "r") as f:
            return f.read()
    except:
        with open("aesir_engine/../golden_corpus.json", "r") as f:
            return f.read()


def test_corpus_count_and_unique_ids() raises:
    var rows = corpus_fixtures()
    if len(rows) != GOLDEN_FIXTURE_COUNT or len(rows) != 24:
        raise Error("corpus fixture count drifted: " + String(len(rows)))
    for i in range(len(rows)):
        for j in range(len(rows)):
            if i != j and rows[i].fixture_id == rows[j].fixture_id:
                raise Error("duplicate fixture id: " + rows[i].fixture_id)
        if not rows[i].fixture_id.startswith("GC-"):
            raise Error("fixture id off-pattern: " + rows[i].fixture_id)


def test_corpus_coverage() raises:
    var rows = corpus_fixtures()
    var cats = List[String]()
    var langs = List[String]()
    var bands = List[String]()
    for row in rows:
        if row.category not in cats:
            cats.append(row.category)
        if row.language not in langs:
            langs.append(row.language)
        if row.length_class not in bands:
            bands.append(row.length_class)
    var need_cats = List[String]()
    need_cats.append(String("plain"))
    need_cats.append(String("language"))
    need_cats.append(String("code"))
    need_cats.append(String("formal"))
    need_cats.append(String("unicode"))
    need_cats.append(String("edge"))
    for i in range(len(need_cats)):
        if need_cats[i] not in cats:
            raise Error("corpus category missing: " + need_cats[i])
    var need_bands = List[String]()
    need_bands.append(String("empty"))
    need_bands.append(String("tiny"))
    need_bands.append(String("short"))
    need_bands.append(String("medium"))
    need_bands.append(String("long"))
    for i in range(len(need_bands)):
        if need_bands[i] not in bands:
            raise Error("corpus length band missing: " + need_bands[i])
    var need_langs = List[String]()
    need_langs.append(String("en"))
    need_langs.append(String("de"))
    need_langs.append(String("fr"))
    need_langs.append(String("es"))
    need_langs.append(String("no"))
    need_langs.append(String("ja"))
    need_langs.append(String("zh"))
    need_langs.append(String("ar"))
    need_langs.append(String("python"))
    need_langs.append(String("rust"))
    need_langs.append(String("c"))
    need_langs.append(String("javascript"))
    need_langs.append(String("shell"))
    for i in range(len(need_langs)):
        if need_langs[i] not in langs:
            raise Error("corpus language missing: " + need_langs[i])


def test_corpus_pins_complete() raises:
    var rows = corpus_fixtures()
    for row in rows:
        if not fixture_pins_complete(row):
            raise Error("fixture pins incomplete: " + row.fixture_id)


def test_corpus_raw_not_template() raises:
    var rows = corpus_fixtures()
    for row in rows:
        if not fixture_is_raw(row):
            raise Error("fixture prompt is template-rendered: " + row.fixture_id)


def test_corpus_pinned_expectations() raises:
    var rows = corpus_fixtures()
    for row in rows:
        if not fixture_expectations_match(row):
            raise Error("fixture expectations drifted: " + row.fixture_id)
    var empty_ok = False
    for row in rows:
        if row.fixture_id == "GC-001":
            empty_ok = row.byte_length == 0 and row.codepoint_count == 0 and row.fnv1a64 == 14695981039346656037
    if not empty_ok:
        raise Error("empty fixture expectations wrong")


def test_corpus_length_classes() raises:
    if length_class_for_bytes(0) != String("empty"):
        raise Error("band edge: 0")
    if length_class_for_bytes(24) != String("tiny"):
        raise Error("band edge: 24")
    if length_class_for_bytes(25) != String("short"):
        raise Error("band edge: 25")
    if length_class_for_bytes(160) != String("short"):
        raise Error("band edge: 160")
    if length_class_for_bytes(161) != String("medium"):
        raise Error("band edge: 161")
    if length_class_for_bytes(800) != String("medium"):
        raise Error("band edge: 800")
    if length_class_for_bytes(801) != String("long"):
        raise Error("band edge: 801")
    var rows = corpus_fixtures()
    var long_bytes = 0
    for row in rows:
        if row.length_class == "long":
            long_bytes = row.byte_length
    if long_bytes <= 800:
        raise Error("long fixture is not long")


def test_corpus_file_mirrors() raises:
    var text = _corpus_text()
    var rows = corpus_fixtures()
    for row in rows:
        if row.fixture_id not in text:
            raise Error("corpus file missing fixture: " + row.fixture_id)
        if row.prompt_hash not in text:
            raise Error("corpus file missing prompt hash: " + row.fixture_id)
    var needles = List[String]()
    needles.append("golden-corpus")
    needles.append("model_sha256")
    needles.append("oracle_backend")
    needles.append("oracle_build_hash")
    needles.append("prompt_hash")
    needles.append("14447871986633844790")
    needles.append("7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c")
    for i in range(len(needles)):
        if needles[i] not in text:
            raise Error("corpus file missing: " + needles[i])
    if "harness consumes it unchanged" not in golden_corpus_summary():
        raise Error("corpus summary lost the acceptance rule")


def test_corpus_harness_consumes_unchanged() raises:
    var before = corpus_digest()
    if before != PINNED_CORPUS_DIGEST:
        raise Error("corpus digest != pinned digest")
    var n = consume_corpus_unchanged()
    if n != 24:
        raise Error("harness consumed wrong count: " + String(n))
    if corpus_digest() != before:
        raise Error("corpus changed under harness consumption")
