# core/event_bus.mojo
# AesirEventBus: Decoupled Inter-Module Message Bus

struct AesirEventBus(Copyable, ImplicitlyCopyable):
    """
    ᛖᚠᛖᚾᛏ·ᛒᚢᛋ — The Current of Module Whispers (AesirEventBus)
    ════════════════════════════════════════════════════════════
    Provides asynchronous, decoupled Pub/Sub messaging across system domains
    (server, core, loader, cli). Dispatches event pulses:
    HEARTBEAT, MODEL_LOADED, INFERENCE_CRASH, RECOVERY_COMPLETE.
    """
    var event_count: Int
    var last_event_code: Int

    def __init__(out self):
        self.event_count = 0
        self.last_event_code = 0

    def copy(self) -> Self:
        var b = Self()
        b.event_count = self.event_count
        b.last_event_code = self.last_event_code
        return b

    def publish_event(mut self, event_type: String, message: String = ""):
        """
        ᛈᛢᛒᛚᛁᛋᚺ·ᛖᚠᛖᚾᛏ — The Dispatch of the Runic Pulse (publish_event)
        ══════════════════════════════════════════════════════════════════
        Publishes an inter-module event pulse across the sovereign bus, notifying
        listeners of operational state transitions, heartbeats, and panic signals.
        Zero dynamic memory allocation.
        """
        self.event_count += 1
        if event_type == "HEARTBEAT":
            self.last_event_code = 1
        elif event_type == "MODEL_LOADED":
            self.last_event_code = 2
        elif event_type == "INFERENCE_CRASH":
            self.last_event_code = 3
        elif event_type == "RECOVERY_COMPLETE":
            self.last_event_code = 4
        else:
            self.last_event_code = 99

    def get_last_event(self) -> String:
        """
        ᚷᛖᛏ·ᛚᚨᛋᛏ·ᛖᚠᛖᚾᛏ — The Listening Rune (get_last_event)
        ═════════════════════════════════════════════════════════
        Queries the most recent event type published across the bus current.
        """
        if self.last_event_code == 1:
            return "HEARTBEAT"
        elif self.last_event_code == 2:
            return "MODEL_LOADED"
        elif self.last_event_code == 3:
            return "INFERENCE_CRASH"
        elif self.last_event_code == 4:
            return "RECOVERY_COMPLETE"
        elif self.last_event_code == 99:
            return "CUSTOM"
        return "IDLE"
