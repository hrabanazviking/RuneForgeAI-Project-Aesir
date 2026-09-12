"""Truthful, read-mostly system and model diagnosis for Project Aesir."""

from aesir import CUDAGate
from config import validate_model_store_path
from cli.storage import DurableModelStore
from cli.model_inspect import dispatch_model_inspect
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


def dispatch_doctor(args: List[String]) raises:
    """Executes `aesir doctor [model] [--model-store path]`."""
    var model_reference = String("")
    var model_store = String(".aesir/models")
    var seen_store = False
    var index = 1
    while index < len(args):
        var token = args[index]
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
    try:
        disk_available = observe_disk_available_bytes(model_store)
        disk_known = True
    except:
        try:
            disk_available = observe_disk_available_bytes(".")
            disk_known = True
        except:
            pass

    var listener_known = False
    var listener = False
    try:
        listener = observe_tcp_listener(11434)
        listener_known = True
    except:
        pass

    print("Project Aesir Diagnostic\n")
    _print_doctor_row("Mojo runtime", "✓ current process")
    _print_doctor_row("CUDA", ("✓ " if cuda_ready else "✗ ") + cuda_detail)
    _print_doctor_row("GPU", gpu_name)
    _print_doctor_row("VRAM", human_bytes(total_vram))
    _print_doctor_row("Free VRAM", human_bytes(free_vram))
    _print_doctor_row("Model store", store_detail)
    _print_doctor_row("Disk available", human_bytes(disk_available))
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

    var ready = doctor_system_ready(
        cuda_ready,
        store_ok,
        installed_count,
        broken_models,
        disk_known,
        disk_available,
    )
    print("\n" + ("SYSTEM READY" if ready else "SYSTEM NEEDS ATTENTION"))
    print("Scope: CUDA/storage prerequisites only; model execution not tested.")

    if model_reference != "":
        print("\nModel-specific diagnosis\n")
        var inspect_args: List[String] = [
            "inspect", model_reference, "--model-store", model_store
        ]
        dispatch_model_inspect(inspect_args)
