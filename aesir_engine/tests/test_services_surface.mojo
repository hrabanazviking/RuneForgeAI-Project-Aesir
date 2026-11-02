"""Services surface (J-112): the pure services layer --
the registry (every inventoried service with its
availability class and reason, refusals stated never
hidden), the catalogue census, the grade delegation
(every verdict equal to core/prefill_grade's own
output on the same records), the bench report
composition, the chat answers, and the tokenize
parse + format.

No number in this suite is a behaviour of a live
engine: no model was loaded, no tokenizer ran, no
device was observed by the layer, and no text was
generated. Live legs are deferred-with-reason in the
J-112 doc (section 5), re-cited at the J-118 gate.
"""
from core.prefill_grade import (
    grade_prefill_cell,
    step_class,
    verdict_name,
)
from core.services_surface import (
    SVC_AVAILABLE,
    SVC_CLI_ONLY,
    SVC_DEFERRED,
    SVC_MODEL_BOUND,
    SVC_NOT_EXPOSED,
    SVC_REFUSED,
    ServiceModelFact,
    services_chat_response,
    svc_availability_name,
    svc_bench_text,
    svc_census_text,
    svc_format_tokenize,
    svc_grade_step_text,
    svc_inventory_text,
    svc_is_tokenize_command,
    svc_mcp_client_disposition,
    svc_parse_tokenize,
    svc_services,
    svc_step_class_name,
)


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "ServicesSurface " + what + ": expected " + String(want)
            + ", got " + String(got)
        )


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "ServicesSurface " + what + ": expected '" + want
            + "', got '" + got + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ServicesSurface " + what + ": expected true")


def expect_false(value: Bool, what: String) raises:
    if value:
        raise Error("ServicesSurface " + what + ": expected false")


def expect_in(haystack: String, needle: String, what: String) raises:
    if needle not in haystack:
        raise Error(
            "ServicesSurface " + what + ": expected '" + needle
            + "' inside '" + haystack + "'"
        )


def facts() -> List[ServiceModelFact]:
    var out = List[ServiceModelFact]()
    out.append(ServiceModelFact("alpha", "q4_k_m", "Q4_K_M", 1000))
    out.append(ServiceModelFact("beta", "q8_0", "Q8_0", 2500))
    out.append(ServiceModelFact("gamma", "q4_k_m", "Q4_K_M", 500))
    return out^


def test_registry() raises:
    var services = svc_services()
    expect_eq_int(len(services), 9, "registry size")
    var by_name = List[String]()
    for entry in services:
        by_name.append(entry.name)
        expect_true(
            entry.reason.byte_length() > 20,
            "every entry states its reason: " + entry.name,
        )
    expect_eq_str(by_name[0], "generate", "row 0")
    expect_eq_str(by_name[1], "tokenize", "row 1")
    expect_eq_str(by_name[2], "grade", "row 2")
    expect_eq_str(by_name[3], "census", "row 3")
    expect_eq_str(by_name[4], "bench_report", "row 4")
    expect_eq_str(by_name[5], "bench_sweep", "row 5")
    expect_eq_str(by_name[6], "embed", "row 6")
    expect_eq_str(by_name[7], "segment", "row 7")
    expect_eq_str(by_name[8], "mcp_client", "row 8")
    expect_eq_int(services[0].availability, SVC_MODEL_BOUND, "generate class")
    expect_eq_int(services[1].availability, SVC_MODEL_BOUND, "tokenize class")
    expect_eq_int(services[2].availability, SVC_AVAILABLE, "grade class")
    expect_eq_int(services[3].availability, SVC_AVAILABLE, "census class")
    expect_eq_int(services[4].availability, SVC_AVAILABLE, "bench report class")
    expect_eq_int(services[5].availability, SVC_CLI_ONLY, "sweep class")
    expect_eq_int(services[6].availability, SVC_REFUSED, "embed class")
    expect_eq_int(services[7].availability, SVC_NOT_EXPOSED, "segment class")
    expect_eq_int(services[8].availability, SVC_DEFERRED, "mcp client class")
    expect_eq_str(
        svc_availability_name(SVC_REFUSED), "REFUSED", "class name refused"
    )
    var text = svc_inventory_text()
    expect_in(text, "aesir services (9 inventoried)", "inventory header")
    expect_in(text, "embed [REFUSED]", "refusal on the face")
    expect_in(text, "mcp_client [DEFERRED]", "deferral on the face")
    expect_in(text, "segment [NOT_EXPOSED]", "non-service on the face")
    expect_in(text, "aesir_grade", "grade tool named")
    print("PASS: registry (9 services, classes + reasons, refusals stated)")


def test_census() raises:
    var text = svc_census_text(facts())
    expect_in(text, "known-models census: 3 entries", "census count")
    expect_in(text, "4000 bytes total", "census total bytes")
    expect_in(text, "quantization Q4_K_M: 2", "quant count q4")
    expect_in(text, "quantization Q8_0: 1", "quant count q8")
    expect_in(text, "- alpha:q4_k_m (Q4_K_M, 1000 bytes)", "entry line alpha")
    expect_in(text, "- beta:q8_0 (Q8_0, 2500 bytes)", "entry line beta")
    expect_in(text, "not a scan of", "census source honesty")
    var empty = svc_census_text(List[ServiceModelFact]())
    expect_in(empty, "0 entries, 0 bytes total", "empty census")
    print("PASS: census (count, total, per-quantization, per-entry lines)")


def test_grade_delegation() raises:
    # Every service verdict equals the grading layer's own
    # output on the same single-step record.
    var case_ranks = List[Int]()
    case_ranks.append(0)
    case_ranks.append(1)
    case_ranks.append(2)
    case_ranks.append(2)
    case_ranks.append(5)
    var case_gaps = List[Int]()
    case_gaps.append(0)
    case_gaps.append(250)
    case_gaps.append(999)
    case_gaps.append(1000)
    case_gaps.append(3000)
    for ci in range(len(case_ranks)):
        var rank = case_ranks[ci]
        var gap = case_gaps[ci]
        var ranks = List[Int]()
        ranks.append(rank)
        var gaps = List[Int]()
        gaps.append(gap)
        var summary = grade_prefill_cell(ranks, gaps, True)
        var text = svc_grade_step_text(rank, gap, True)
        expect_in(
            text, svc_step_class_name(step_class(rank, gap)),
            "step class delegated",
        )
        expect_in(
            text, verdict_name(summary.verdict), "verdict delegated"
        )
    expect_in(
        svc_grade_step_text(0, 0, True), "verdict FAITHFUL", "faithful cell"
    )
    expect_in(
        svc_grade_step_text(1, 250, True), "verdict NEAR_TIE", "near-tie cell"
    )
    expect_in(
        svc_grade_step_text(1, 250, False),
        "verdict COMPARATOR_ARTIFACT",
        "unstated comparator cell",
    )
    expect_in(
        svc_grade_step_text(3, 1500, True),
        "step DIVERGENT",
        "divergent step",
    )
    # Inconsistent records raise, exactly as the layer raises.
    var raised = False
    try:
        _ = svc_grade_step_text(0, 5, True)
    except:
        raised = True
    expect_true(raised, "rank 0 with a gap raises")
    raised = False
    try:
        _ = svc_grade_step_text(2, 0, True)
    except:
        raised = True
    expect_true(raised, "positive rank with zero gap raises")
    print("PASS: grade delegation (verdicts equal prefill_grade; refusals)")


def test_bench_composition() raises:
    var text = svc_bench_text(
        String("DEVICE-DESCRIBE"), String("MODEL-TABLE")
    )
    expect_in(text, "bench report (the report form", "bench header")
    expect_in(text, "DEVICE-DESCRIBE", "inventory composed")
    expect_in(text, "MODEL-TABLE", "filed table composed")
    expect_in(text, "CLI-only", "sweep reason on the face")
    expect_in(text, "aesir bench", "sweep door named")
    print("PASS: bench composition (inventory + filed table + CLI reason)")


def test_chat_answers() raises:
    var f = facts()
    var inv = services_chat_response("/services", f, "DEV", "TAB")
    expect_in(inv, "aesir services (9 inventoried)", "chat inventory")
    var cen = services_chat_response("/services census", f, "DEV", "TAB")
    expect_in(cen, "known-models census: 3 entries", "chat census")
    var grade = services_chat_response(
        "/services grade 1 250 valid", f, "DEV", "TAB"
    )
    expect_in(grade, "step NEAR_TIE", "chat grade step")
    expect_in(grade, "verdict NEAR_TIE", "chat grade verdict")
    var grade_unstated = services_chat_response(
        "/services grade 0 0", f, "DEV", "TAB"
    )
    expect_in(
        grade_unstated, "COMPARATOR_ARTIFACT", "chat grade unstated comparator"
    )
    var grade_bad = services_chat_response(
        "/services grade x 0", f, "DEV", "TAB"
    )
    expect_in(grade_bad, "grade refused", "chat grade bad numbers refused")
    var grade_inconsistent = services_chat_response(
        "/services grade 0 5 valid", f, "DEV", "TAB"
    )
    expect_in(
        grade_inconsistent, "grade refused", "chat grade inconsistent refused"
    )
    var grade_usage = services_chat_response(
        "/services grade 1", f, "DEV", "TAB"
    )
    expect_in(grade_usage, "Usage: /services grade", "chat grade usage")
    var bench = services_chat_response("/services bench", f, "DEV", "TAB")
    expect_in(bench, "bench report (the report form", "chat bench")
    var mcp = services_chat_response("/services mcp", f, "DEV", "TAB")
    expect_eq_str(mcp, svc_mcp_client_disposition(), "chat mcp disposition")
    expect_in(mcp, "DEFERRED", "disposition states its class")
    var unknown = services_chat_response("/services nope", f, "DEV", "TAB")
    expect_in(unknown, "Unknown services form", "unknown form refused")
    expect_in(unknown, "/services tokenize <text>", "refusal names the forms")
    print("PASS: chat answers (inventory/census/grade/bench/mcp/refusals)")


def test_tokenize_parse_format() raises:
    expect_true(
        svc_is_tokenize_command("/services tokenize hello world"),
        "tokenize command recognised",
    )
    expect_true(
        svc_is_tokenize_command("/services tokenize"),
        "bare tokenize recognised (usage-refused at parse)",
    )
    expect_false(
        svc_is_tokenize_command("/services tokenizex"),
        "tokenizex is not tokenize",
    )
    expect_false(
        svc_is_tokenize_command("/services census"), "census is not tokenize"
    )
    expect_eq_str(
        svc_parse_tokenize("/services tokenize hello world"),
        "hello world",
        "tokenize text extracted",
    )
    var raised = False
    try:
        _ = svc_parse_tokenize("/services tokenize")
    except:
        raised = True
    expect_true(raised, "bare tokenize raises usage")
    raised = False
    try:
        _ = svc_parse_tokenize("/services tokenize   ")
    except:
        raised = True
    expect_true(raised, "blank tokenize raises usage")
    var ids = List[Int]()
    ids.append(9707)
    ids.append(25)
    var text = svc_format_tokenize("hi!", ids)
    expect_in(text, "2 tokens", "format count")
    expect_in(text, "ids: [9707, 25]", "format ids exact")
    expect_in(text, "\"hi!\"", "format text")
    var empty = svc_format_tokenize("", List[Int]())
    expect_in(empty, "0 tokens", "format empty count")
    expect_in(empty, "ids: []", "format empty ids")
    print("PASS: tokenize parse + format (usage refusals, exact ids)")


def main() raises:
    test_registry()
    test_census()
    test_grade_delegation()
    test_bench_composition()
    test_chat_answers()
    test_tokenize_parse_format()
    print("ALL PASS: services surface (6 groups)")
