"""Truthful, read-mostly system and model diagnosis for Project Aesir."""

from aesir import CUDAGate
from config import validate_model_store_path
from cli.storage import DurableModelStore
from cli.model_inspect import inspect_model_reference, model_inspection_json, print_model_inspection_text
from core.model_registry import ModelCompatibility
from server.api import json_escape_string
from core.native_diagnostics import (
    human_bytes,
    observe_disk_available_bytes,
    observe_tcp_listener,
)


def doctor_system_ready(
    cuda_ready: Bool,
    store_ok: Bool,
    installed_model_count: Int,
    broken_models: Int,
    disk_known: Bool,
    disk_available_bytes: Int,
) -> Bool:
    """Checks CUDA/storage prerequisites, not model execution compatibility."""
    return (
        cuda_ready
        and store_ok
        and installed_model_count > 0
        and broken_models == 0
        and disk_known
        and disk_available_bytes > 0
    )


def _print_doctor_row(label: String, value: String):
    var padding = String("")
    var width = 23
    for _ in range(max(1, width - len(label.bytes()))):
        padding += " "
    print(label + padding + value)


def _json_string(value: String) -> String:
    return '"' + json_escape_string(value) + '"'


def _json_bool(value: Bool) -> String:
    return "true" if value else "false"


def doctor_json_bytes(value: Int) -> String:
    """Unknown measurements are null, never negative byte counts or zero."""
    return "null" if value < 0 else String(value)


@fieldwise_init
struct DoctorIssue(Copyable):
    var code: String
    var action: String

    def to_json(self) -> String:
        return '{"code":' + _json_string(self.code) + ',"action":' + _json_string(self.action) + '}'


def _doctor_issue(code: String, action: String) -> DoctorIssue:
    return DoctorIssue(code, action)


def dispatch_doctor(args: List[String]) raises:
    """Collects once, then renders text or versioned JSON diagnostics."""
    var model_reference = String("")
    var model_store = String(".aesir/models")
    var seen_store = False
    var format = String("text")
    var seen_format = False
    var index = 1
    while index < len(args):
        var token = args[index]
        if token == "--format":
            if seen_format or index + 1 >= len(args):
                raise Error("doctor requires one value for --format")
            seen_format = True
            format = args[index + 1]
            if format != "text" and format != "json":
                raise Error("doctor --format must be text or json")
            index += 2
            continue
        if token == "--model-store":
            if seen_store or index + 1 >= len(args):
                raise Error("doctor requires one value for --model-store")
            seen_store = True
            model_store = args[index + 1]
            index += 2
            continue
        if token.startswith("-"):
            raise Error("unknown doctor option: " + token)
        if model_reference != "":
            raise Error("doctor accepts at most one model reference")
        model_reference = token
        index += 1

    model_store = validate_model_store_path(model_store)

    var cuda_ready = False
    var cuda_detail: String
    var gpu_name = String("none observed")
    var total_vram = -1
    var free_vram = -1
    var discovery = CUDAGate.discover_physical_devices()
    try:
        discovery.validate()
        cuda_detail = discovery.status.name() + " — " + discovery.message
        for device in discovery.devices:
            if not cuda_ready and device.capabilities.is_compatible:
                cuda_ready = True
                gpu_name = device.name
                total_vram = Int(device.capabilities.total_memory_bytes)
                free_vram = Int(device.capabilities.free_memory_bytes)
    except error:
        cuda_detail = "invalid discovery result — " + String(error)

    var store_ok = False
    var store_detail: String
    var model_count = 0
    var installed_count = 0
    var recipe_count = 0
    var broken_models = 0
    var broken_names = List[String]()
    try:
        var durable = DurableModelStore(model_store)
        var models = durable.list_models()
        model_count = len(models)
        store_ok = True
        store_detail = "✓ catalog readable at " + model_store
        for manifest in models:
            var identity = manifest.name + ":" + manifest.tag
            if manifest.digest.startswith("sha256:"):
                installed_count += 1
                try:
                    _ = durable.verify_model(identity)
                except error:
                    broken_models += 1
                    broken_names.append(identity + " — " + String(error))
            else:
                recipe_count += 1
    except error:
        store_detail = "✗ " + String(error)

    var disk_known = False
    var disk_available = -1
    var disk_path = model_store
    try:
        disk_available = observe_disk_available_bytes(model_store)
        disk_known = True
    except:
        try:
            disk_available = observe_disk_available_bytes(".")
            disk_known = True
            disk_path = "."
        except:
            pass

    var listener_known = False
    var listener = False
    try:
        listener = observe_tcp_listener(11434)
        listener_known = True
    except:
        pass

    var ready = doctor_system_ready(
        cuda_ready, store_ok, installed_count, broken_models, disk_known, disk_available,
    )
    var model_result = ModelCompatibility()
    var model_ok = False
    var model_error = String("")
    if model_reference != "":
        try:
            model_result = inspect_model_reference(model_reference, model_store)
            model_ok = True
        except error:
            model_error = String(error)

    var issues = List[DoctorIssue]()
    if not cuda_ready:
        issues.append(_doctor_issue("cuda_unavailable", "Check hardware list and the supported NVIDIA/WSL driver setup."))
    if not store_ok:
        issues.append(_doctor_issue("store_unreadable", "Check the model-store path and catalog permissions; preserve files before repair."))
    elif installed_count == 0:
        issues.append(_doctor_issue("no_installed_weights", "Import available local weights with create --model; recipes alone cannot run."))
    if broken_models > 0:
        issues.append(_doctor_issue("broken_weights", "Verify the listed models and restore their exact trusted bytes before use."))
    if not disk_known or disk_available <= 0:
        issues.append(_doctor_issue("disk_unavailable", "Check filesystem capacity and permissions before preparing models."))
    if model_reference != "":
        if not model_ok:
            issues.append(_doctor_issue("model_inspection_failed", "Check the model reference and its readable, verified GGUF bytes."))
        elif not model_result.cuda_support:
            issues.append(_doctor_issue("model_cuda_unsupported", model_result.reason))

    if format == "json":
        var broken_json = String("[")
        for i in range(len(broken_names)):
            if i > 0:
                broken_json += ","
            broken_json += _json_string(broken_names[i])
        broken_json += "]"
        var issues_json = String("[")
        for i in range(len(issues)):
            if i > 0:
                issues_json += ","
            issues_json += issues[i].to_json()
        issues_json += "]"
        var optional_model = String("null")
        if model_reference != "":
            optional_model = (
                '{"reference":' + _json_string(model_reference)
                + ',"inspection_ok":' + _json_bool(model_ok)
                + ',"execution_tested":false,"result":'
                + (model_inspection_json(model_result) if model_ok else "null")
                + ',"error":' + ("null" if model_ok else _json_string(model_error)) + '}'
            )
        var output = String('{"schema_version":1,"scope":"cuda_storage_prerequisites","ready":')
        output += _json_bool(ready) + ',"execution_tested":false,"network_probed":false'
        output += ',"cuda":{"ready":' + _json_bool(cuda_ready)
        output += ',"detail":' + _json_string(cuda_detail)
        output += ',"gpu_name":' + (_json_string(gpu_name) if cuda_ready else "null")
        output += ',"total_vram_bytes":' + doctor_json_bytes(total_vram)
        output += ',"free_vram_bytes":' + doctor_json_bytes(free_vram) + '}'
        output += ',"store":{"path":' + _json_string(model_store)
        output += ',"readable":' + _json_bool(store_ok)
        output += ',"detail":' + _json_string(store_detail)
        output += ',"model_count":' + (String(model_count) if store_ok else "null")
        output += ',"installed_count":' + (String(installed_count) if store_ok else "null")
        output += ',"recipe_count":' + (String(recipe_count) if store_ok else "null")
        output += ',"broken_count":' + (String(broken_models) if store_ok else "null")
        output += ',"broken_models":' + broken_json + '}'
        output += ',"disk":{"available_bytes":' + doctor_json_bytes(disk_available)
        output += ',"observed_path":' + (_json_string(disk_path) if disk_known else "null") + '}'
        output += ',"api":{"port":11434,"listener_observed":'
        output += (_json_bool(listener) if listener_known else "null") + ',"endpoints_probed":false}'
        output += ',"model":' + optional_model + ',"issues":' + issues_json + '}'
        print(output)
        return

    print("Project Aesir Diagnostic\n")
    _print_doctor_row("Mojo runtime", "✓ current process")
    _print_doctor_row("CUDA", ("✓ " if cuda_ready else "✗ ") + cuda_detail)
    _print_doctor_row("GPU", gpu_name)
    _print_doctor_row("VRAM", human_bytes(total_vram))
    _print_doctor_row("Free VRAM", human_bytes(free_vram))
    _print_doctor_row("Model store", store_detail)
    _print_doctor_row("Disk available", human_bytes(disk_available))
    _print_doctor_row("Disk observed path", disk_path if disk_known else "unknown")
    var port_detail = "listener observed :11434 (endpoints not probed)" if listener else "not listening :11434"
    if not listener_known:
        port_detail = "socket observation unavailable"
    _print_doctor_row("Ollama API", port_detail)
    _print_doctor_row("OpenAI API", port_detail)
    _print_doctor_row("Model catalog", String(model_count) + " models")
    _print_doctor_row("Installed weights", String(installed_count))
    _print_doctor_row("Recipe-only entries", String(recipe_count))
    _print_doctor_row("Broken models", String(broken_models))
    for broken in broken_names:
        print("  broken: " + broken)
    _print_doctor_row("Network", "not probed (offline-safe)")

    print("\n" + ("SYSTEM READY" if ready else "SYSTEM NEEDS ATTENTION"))
    print("Scope: CUDA/storage prerequisites only; model execution not tested.")

    if model_reference != "":
        print("\nModel-specific diagnosis\n")
        if model_ok:
            print_model_inspection_text(model_result)
        else:
            print("Inspection failed: " + model_error)
    if len(issues) > 0:
        print("\nSuggested actions:")
        for issue in issues:
            print("  [" + issue.code + "] " + issue.action)
