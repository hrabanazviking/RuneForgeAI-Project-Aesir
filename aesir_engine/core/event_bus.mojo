# core/event_bus.mojo
# AesirEventBus: bounded synchronous local event journal and subscriber mailboxes

from std.collections import Dict

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


struct EventMailbox(Copyable):
    """Bounded pending event records for one local subscriber."""
    var events: List[String]

    def __init__(out self):
        self.events = List[String]()

    def __copyinit__(out self, existing: Self):
        self.events = existing.events.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.events.copy())

    def __init__(out self, events: List[String]):
        self.events = events.copy()


def event_type_mask(event_type: String) -> Int:
    """Maps stable built-in event types to subscriber mask bits."""
    if event_type == "HEARTBEAT":
        return 0x0001
    if event_type == "MODEL_LOADED":
        return 0x0002
    if event_type == "INFERENCE_CRASH":
        return 0x0004
    if event_type == "RECOVERY_COMPLETE":
        return 0x0008
    return 0x8000


struct AesirEventBus(Copyable):
    """
    ᛖᚠᛖᚾᛏ·ᛒᚢᛋ — The Current of Module Whispers (AesirEventBus)
    ════════════════════════════════════════════════════════════
    Provides synchronous in-process publication to bounded subscriber
    mailboxes. It owns no threads and provides no cross-process delivery.
    """
    var event_count: Int
    var last_event_code: Int
    var subscriptions: List[EventSubscription]
    var mailboxes: Dict[String, EventMailbox]
    var event_log: List[String]

    def __init__(out self):
        self.event_count = 0
        self.last_event_code = 0
        self.subscriptions = List[EventSubscription]()
        self.mailboxes = Dict[String, EventMailbox]()
        self.event_log = List[String]()

    def __copyinit__(out self, existing: Self):
        self.event_count = existing.event_count
        self.last_event_code = existing.last_event_code
        self.subscriptions = existing.subscriptions.copy()
        self.mailboxes = existing.mailboxes.copy()
        self.event_log = existing.event_log.copy()

    def subscribe(mut self, subscriber_id: String, mask: Int = 0xFFFF) raises:
        """Registers one unique bounded local subscriber mailbox."""
        if subscriber_id.byte_length() == 0 or subscriber_id.byte_length() > 64:
            raise Error("AesirEventBus subscriber id must be 1..64 bytes")
        if mask <= 0 or mask > 0xFFFF:
            raise Error("AesirEventBus subscriber mask must be 1..65535")
        if subscriber_id in self.mailboxes:
            raise Error("AesirEventBus subscriber id must be unique")
        self.subscriptions.append(EventSubscription(subscriber_id, mask))
        self.mailboxes[subscriber_id] = EventMailbox()

    def unsubscribe(mut self, subscriber_id: String) raises -> Bool:
        """Removes a subscriber from event bus notifications."""
        if subscriber_id not in self.mailboxes:
            return False
        var next_subs = List[EventSubscription]()
        for i in range(len(self.subscriptions)):
            if self.subscriptions[i].subscriber_id != subscriber_id:
                next_subs.append(self.subscriptions[i].copy())
        self.subscriptions = next_subs^
        _ = self.mailboxes.pop(subscriber_id)
        return True

    def publish_event(mut self, event_type: String, message: String = "") raises:
        """
        Synchronously appends one event to the journal and matching mailboxes.
        All capacity checks occur before mutation.
        """
        if event_type.byte_length() == 0 or event_type.byte_length() > 64:
            raise Error("AesirEventBus event type must be 1..64 bytes")
        if message.byte_length() > 4096:
            raise Error("AesirEventBus message exceeds 4096 bytes")
        if len(self.event_log) >= 1024:
            raise Error("AesirEventBus journal capacity reached")

        var log_entry = event_type
        if message.byte_length() > 0:
            log_entry += ":" + message

        var event_mask = event_type_mask(event_type)
        for i in range(len(self.subscriptions)):
            var subscription = self.subscriptions[i]
            if (subscription.event_mask & event_mask) != 0:
                if subscription.subscriber_id not in self.mailboxes:
                    raise Error("AesirEventBus subscriber mailbox invariant failed")
                if len(self.mailboxes[subscription.subscriber_id].events) >= 256:
                    raise Error("AesirEventBus subscriber mailbox capacity reached")

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
        self.event_log.append(log_entry)

        for i in range(len(self.subscriptions)):
            var subscription = self.subscriptions[i]
            if (subscription.event_mask & event_mask) != 0:
                var mailbox = self.mailboxes[subscription.subscriber_id].copy()
                mailbox.events.append(log_entry)
                self.mailboxes[subscription.subscriber_id] = mailbox^

    def pending_count(self, subscriber_id: String) raises -> Int:
        """Returns pending local events for a registered subscriber."""
        if subscriber_id not in self.mailboxes:
            raise Error("AesirEventBus subscriber is not registered")
        return len(self.mailboxes[subscriber_id].events)

    def drain_events(mut self, subscriber_id: String) raises -> List[String]:
        """Moves all pending events out of one registered mailbox in order."""
        if subscriber_id not in self.mailboxes:
            raise Error("AesirEventBus subscriber is not registered")
        var result = self.mailboxes[subscriber_id].events.copy()
        self.mailboxes[subscriber_id] = EventMailbox()
        return result^

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
