"""Portable cooperative control policy; physical drain/recovery is separate."""
from core.generation_control import monotonic_milliseconds
from tests.turing_fixture_control import FixtureControl


def test_turing_fixture_control() raises:
    var control = FixtureControl()
    control.admit()
    if control.enabled() or control.stop_reason() != "":
        raise Error("Disabled fixture control changed legacy admission")
    control.configure(10000,-1)
    var rejected = False
    try: control.admit()
    except: rejected = True
    if not rejected: raise Error("Unstarted deadline admitted")
    control.start()
    if control.stop_reason() != "": raise Error("Fresh fixture deadline expired")
    control.generation.deadline_ms = monotonic_milliseconds()-1
    if control.stop_reason() != "timeout": raise Error("Expired fixture deadline ignored")
    for reason in ["timeout","cancelled","control_error"]:
        control.aborted(reason)
        if not control.reset_required or control.started or control.reason != reason:
            raise Error("Fixture abort state was not retained")
        for operation in range(3):
            rejected = False
            try:
                if operation == 0: control.admit()
                elif operation == 1: control.start()
                else: control.configure(0,-1)
            except: rejected = True
            if not rejected or control.reason != reason:
                raise Error("Interrupted fixture was reused without reset")
        control.reset()
        if control.reset_required or control.started or control.reason != "" or control.completed_layers != 0 or control.generation.deadline_ms != 0:
            raise Error("Explicit fixture reset retained abort state")
        control.configure(0,-1)
        control.admit()
    for operation in range(3):
        rejected = False
        try:
            if operation == 0: control.configure(-1,-1)
            elif operation == 1: control.configure(0,-2)
            else: control.aborted("unknown")
        except: rejected = True
        if not rejected or control.enabled() or control.reset_required or control.reason != "":
            raise Error("Invalid control transition mutated disabled policy")


def main() raises:
    test_turing_fixture_control()
    print("PASS: disabled/start/deadline/abort/reset and invalid control transitions")
