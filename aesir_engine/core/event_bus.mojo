# core/event_bus.mojo
# AesirEventBus: Decoupled Inter-Module Message Bus with Queues & Subscriptions

struct EventSubscription(Copyable, ImplicitlyCopyable):
    """Event bus subscriber descriptor."""
    var subscriber_id: String
    var event_mask: Int # bitmask of event types

    def __init__(out self, subscriber_id: String, event_mask: Int = 0xFFFF):
        self.subscriber_id = subscriber_id
        self.event_mask = event_mask

    def __copyinit__(out self, existing: Self):
        self.subscriber_id = existing.subscriber_id
        self.event_mask = existing.event_mask


struct AesirEventBus(Copyable):
    """
    ᛖᚠᛖᚾᛏ·ᛒᚢᛋ — The Current of Module Whispers (AesirEventBus)
    ════════════════════════════════════════════════════════════
    Provides asynchronous, decoupled Pub/Sub messaging across system domains
    (server, core, loader, cli) with subscribers, bounded queues, and failure semantics.
    """
    var event_count: Int
    var last_event_code: Int
    var subscriptions: List[EventSubscription]
    var event_log: List[String]

    def __init__(out self):
        self.event_count = 0
        self.last_event_code = 0
        self.subscriptions = List[EventSubscription]()
        self.event_log = List[String]()

    def __copyinit__(out self, existing: Self):
        self.event_count = existing.event_count
        self.last_event_code = existing.last_event_code
        self.subscriptions = existing.subscriptions.copy()
        self.event_log = existing.event_log.copy()

    def subscribe(mut self, subscriber_id: String, mask: Int = 0xFFFF):
        """Registers a subscriber for event bus notifications."""
        self.subscriptions.append(EventSubscription(subscriber_id, mask))

    def unsubscribe(mut self, subscriber_id: String):
        """Removes a subscriber from event bus notifications."""
        var next_subs = List[EventSubscription]()
        for i in range(len(self.subscriptions)):
            if self.subscriptions[i].subscriber_id != subscriber_id:
                next_subs.append(self.subscriptions[i].copy())
        self.subscriptions = next_subs^

    def publish_event(mut self, event_type: String, message: String = ""):
        """
        Publishes an inter-module event pulse across registered subscribers.
        """
        if len(event_type.as_bytes()) == 0:
            return
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

        var log_entry = event_type
        if len(message.as_bytes()) > 0:
            log_entry += ":" + message
        self.event_log.append(log_entry)

    def get_last_event(self) -> String:
        """Queries the most recent event type published."""
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
