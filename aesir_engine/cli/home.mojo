"""Terminal launcher; each action owns its process and returns to this menu."""
from std.ffi import external_call
from config import validate_model_store_path
from cli.storage import DurableModelStore
from cli.commands import print_general_help
from cli.interrupts import ChatInterrupts, consume_interrupts, prepare_chat_process, read_interruptible_line_result
from core.posix_process import run_attached_argv


def home_terminal_available() -> Bool:
    return external_call["isatty", Int32](Int32(0)) == 1 and external_call["isatty", Int32](Int32(1)) == 1


def print_home_help():
    print("Usage: aesir home [--model-store relative-path]")
    print("Interactive terminal required on stdin and stdout; use explicit CLI commands in scripts.")
    print("No-argument terminal launches open Home; redirected no-argument launches show CLI help.")
    print("Actions: CUDA chat, model catalog, doctor, preference-repair preview, command help, quit.")


def dispatch_home(args: List[String]) raises:
    var model_store = String(".aesir/models")
    var seen_store = False
    if len(args) == 2 and (args[1] == "--help" or args[1] == "-h"):
        print_home_help()
        return
    var index = 1
    while index < len(args):
        if args[index] != "--model-store":
            raise Error("unknown home argument: " + args[index])
        if seen_store or index + 1 >= len(args):
            raise Error("home requires one value for --model-store")
        seen_store = True
        model_store = validate_model_store_path(args[index + 1])
        index += 2
    if not home_terminal_available():
        raise Error("home requires an interactive terminal on stdin and stdout; use help or explicit commands in scripts")
    prepare_chat_process()
    var interrupts = ChatInterrupts()
    while True:
        print("\nAesir Home")
        print("Model store: " + model_store)
        var installed = 0
        var recipes = 0
        var catalog_ok = False
        try:
            var models = DurableModelStore(model_store).list_models()
            for model in models:
                if model.digest.startswith("sha256:"):
                    installed += 1
                else:
                    recipes += 1
            catalog_ok = True
            print("Installed weights: " + String(installed) + " | Recipes: " + String(recipes))
            if installed == 0:
                print("No installed weights. Import local bytes with create --model; recipes cannot run.")
        except error:
            print("Catalog unavailable: " + String(error))
        print("1  Start CUDA chat (choose a model)")
        print("2  List model catalog")
        print("3  Run doctor (rehashes installed weights)")
        print("4  Preview stale preference repair (no changes)")
        print("5  Command help")
        print("q  Quit | Ctrl+C cancels a menu choice")
        print("Choice:")
        var input = read_interruptible_line_result(interrupts.fd)
        if input.interrupted:
            print("Cancelled; home is ready.")
            continue
        if input.eof:
            print("Goodbye.")
            return
        var choice = String(input.text.strip())
        if choice == "q" or choice == "quit" or choice == "exit":
            print("Goodbye.")
            return
        if choice == "5":
            print_general_help()
            continue
        var child: List[String] = ["/proc/self/exe"]
        if choice == "1":
            if not catalog_ok or installed == 0:
                print("No installed weights available for chat; inspect the catalog and import local model bytes first.")
                continue
            child.append("chat")
            child.append("--accel")
            child.append("cuda")
        elif choice == "2":
            child.append("list")
        elif choice == "3":
            child.append("doctor")
        elif choice == "4":
            child.append("repair-preferences")
            child.append("--dry-run")
        else:
            print("Choose 1-5 or q.")
            continue
        child.append("--model-store")
        child.append(model_store)
        try:
            var result = run_attached_argv(child)
            print("Returned to home (command exit " + String(result) + ").")
        except error:
            print("Unable to run command: " + String(error))
        _ = consume_interrupts(interrupts.fd)
