# VÖRÐR error taxonomy — machine-readable classification (H145).
#
# Every error condition the system can raise or decode is classified:
#   TRANSIENT  — retry (bounded, with backoff)
#   PERSISTENT — reset + re-init
#   FATAL      — fail closed, operator needed
# The prose rationale per condition lives in
# docs/vordr/ERROR_TAXONOMY.md. A TEST-ONLY test (prof/vordr/
# test_taxonomy_complete.py) machine-checks that every named error the
# Mojo codebase can raise appears here EXACTLY once.

from hailbru.errors import herror


struct TaxEntry:
    var name: String
    var cls: String

    def __init__(out self, name: String, cls: String):
        self.name = name
        self.cls = cls


def taxonomy_entries() -> List[TaxEntry]:
    var t = List[TaxEntry]()
    # --- Decoded hardware conditions (H144) ---
    t.append(TaxEntry("PciStatus.DetectedParityError", "transient"))
    t.append(TaxEntry("PciStatus.SignaledSystemError", "fatal"))
    t.append(TaxEntry("PciStatus.ReceivedMasterAbort", "persistent"))
    t.append(TaxEntry("PciStatus.ReceivedTargetAbort", "persistent"))
    t.append(TaxEntry("PciStatus.SignaledTargetAbort", "persistent"))
    t.append(TaxEntry("PciStatus.MasterDataParityError", "transient"))
    t.append(TaxEntry("Pmcsr.PmeStatus", "transient"))
    t.append(TaxEntry("UnknownErrorBit", "transient"))
    # --- VÖRÐR runtime conditions ---
    t.append(TaxEntry("HangDetected", "transient"))
    t.append(TaxEntry("ShadowMismatch", "persistent"))
    t.append(TaxEntry("IntegrityCorrupt", "transient"))
    t.append(TaxEntry("RetransferFailed", "fatal"))
    t.append(TaxEntry("RetryExhausted", "persistent"))
    t.append(TaxEntry("ReinitRefused", "fatal"))
    t.append(TaxEntry("ReinitFailed", "fatal"))
    t.append(TaxEntry("ResetFailed", "persistent"))
    t.append(TaxEntry("DeviceRemoved", "fatal"))
    t.append(TaxEntry("ThermalWarning", "transient"))
    t.append(TaxEntry("IllegalTransition", "fatal"))
    t.append(TaxEntry("SpawnFailed", "fatal"))
    t.append(TaxEntry("BadClassification", "fatal"))
    # --- HAILBRÚ named errors (software side) ---
    t.append(TaxEntry("BadBdf", "fatal"))
    t.append(TaxEntry("BadSysfs", "transient"))
    t.append(TaxEntry("BadThresholds", "fatal"))
    t.append(TaxEntry("BadBudgets", "fatal"))
    t.append(TaxEntry("BadPolicy", "fatal"))
    t.append(TaxEntry("BadShadowPlan", "fatal"))
    t.append(TaxEntry("BarParseFailed", "fatal"))
    t.append(TaxEntry("BindError", "persistent"))
    t.append(TaxEntry("BootHang", "persistent"))
    t.append(TaxEntry("ConfigReadFailed", "transient"))
    t.append(TaxEntry("DeviceBusy", "transient"))
    t.append(TaxEntry("DeviceNotFound", "fatal"))
    t.append(TaxEntry("DeviceNotReady", "persistent"))
    t.append(TaxEntry("DmaError", "transient"))
    t.append(TaxEntry("DmaLockFailed", "transient"))
    t.append(TaxEntry("DoubleFree", "fatal"))
    t.append(TaxEntry("DriverBindingMismatch", "persistent"))
    t.append(TaxEntry("FirmwareBootTimeout", "persistent"))
    t.append(TaxEntry("FirmwareCorrupt", "fatal"))
    t.append(TaxEntry("FirmwareMissing", "fatal"))
    t.append(TaxEntry("FirmwareUploadAborted", "persistent"))
    t.append(TaxEntry("FwError", "persistent"))
    t.append(TaxEntry("HeartbeatViolation", "fatal"))
    t.append(TaxEntry("IdentityMismatch", "fatal"))
    t.append(TaxEntry("IrqSetupFailed", "persistent"))
    t.append(TaxEntry("IrqTimeout", "transient"))
    t.append(TaxEntry("MechanismUnavailable", "fatal"))
    t.append(TaxEntry("MultipleDevices", "fatal"))
    t.append(TaxEntry("OsError", "transient"))
    t.append(TaxEntry("PowerManagementUnsupported", "fatal"))
    t.append(TaxEntry("PowerTransitionFailed", "persistent"))
    t.append(TaxEntry("PrivilegeRequired", "fatal"))
    t.append(TaxEntry("ReadbackMismatch", "persistent"))
    t.append(TaxEntry("RegOutOfRange", "fatal"))
    t.append(TaxEntry("RegUnaligned", "fatal"))
    t.append(TaxEntry("StepOmitted", "fatal"))
    t.append(TaxEntry("UioError", "transient"))
    t.append(TaxEntry("UnknownBuffer", "fatal"))
    t.append(TaxEntry("VendorMirrorMismatch", "persistent"))
    t.append(TaxEntry("VfioError", "persistent"))
    t.append(TaxEntry("WrongMechanism", "fatal"))
    return t^


def classify(name: String) raises -> String:
    # The recovery state machine (H149) drives off this.
    var t = taxonomy_entries()
    for i in range(len(t)):
        if t[i].name == name:
            return t[i].cls
    raise herror(
        "BadClassification", "no taxonomy entry for '" + name + "'"
    )


def taxonomy_names() -> List[String]:
    var t = taxonomy_entries()
    var out = List[String]()
    for i in range(len(t)):
        out.append(t[i].name)
    return out^
