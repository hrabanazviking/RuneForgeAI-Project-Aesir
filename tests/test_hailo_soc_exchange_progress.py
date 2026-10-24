#!/usr/bin/env python3
"""Independent event/count/deadline expectations; no device or model calls."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest

CONFIG = argparse.Namespace()


def irq(*records, input_channel=3, output_channel=19):
    result = bytearray(385)
    struct.pack_into('<Q', result, 0, (1 << input_channel) | (1 << output_channel))
    result[24] = len(records)
    for index, record in enumerate(records):
        result[25 + 3 * index:28 + 3 * index] = bytes(record)
    return result.hex()


class ObservedProgress(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary = str(Path(CONFIG.binary).resolve(strict=True))
        cls.api = str(Path(CONFIG.api).resolve(strict=True))

    def invoke(self, events=(), **changes):
        values = dict(input_channel=3, output_channel=19, input_capacity=16,
                      output_capacity=32, start=100, timeout=100, budget=32,
                      input_count=7, output_count=11, launch_time=100)
        values.update(changes)
        args = [self.binary, *map(str, values.values())]
        for time, data in events:
            args.extend((str(time), data))
        return subprocess.run(args, capture_output=True, text=True,
                              stdin=subprocess.DEVNULL, timeout=10, check=False)

    def accept(self, events=(), **changes):
        # This oracle independently consumes transfer-completion records. It
        # never estimates descriptor counts from bytes/pages/spans.
        result = self.invoke(events, **changes)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        input_channel = changes.get('input_channel', 3)
        output_channel = changes.get('output_channel', 19)
        done = {input_channel: False, output_channel: False}
        for _, data in events:
            raw = bytes.fromhex(data)
            for index in range(raw[24]):
                _, channel, count = raw[25+3*index:28+3*index]
                done[channel] |= count == 1
        remaining = changes.get('start', 100) + changes.get('timeout', 100) - (
            events[-1][0] if events else changes.get('launch_time', 100))
        self.assertEqual(json.loads(result.stdout), dict(
            input_descriptors=changes.get('input_count', 7),
            output_descriptors=changes.get('output_count', 11),
            input_done=done[input_channel], output_done=done[output_channel],
            complete=all(done.values()), snapshots=len(events), remaining_ms=remaining))

    def reject(self, events=(), **changes):
        result = self.invoke(events, **changes)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('HailbruError[', result.stdout + result.stderr)
        self.accept([(199, irq((0, 3, 1), (0, 19, 1)))])

    def test_all_directional_pairs_with_distinct_actual_counts(self):
        for input_channel in range(16):
            for output_channel in range(16, 32):
                self.accept([(199, irq((0, input_channel, 1), (0, output_channel, 1),
                    input_channel=input_channel, output_channel=output_channel))],
                    input_channel=input_channel, output_channel=output_channel)

    def test_independent_ring_and_actual_count_edges(self):
        for power in range(1, 17):
            capacity = 1 << power
            for field in ('input', 'output'):
                for count in sorted({1, capacity-1}):
                    self.accept(**{field+'_capacity': capacity, field+'_count': count})
                for count in (-9223372036854775808, -1, 0, capacity, 9223372036854775807):
                    self.reject(**{field+'_capacity': capacity, field+'_count': count})
        for capacity in (0, 1, 3, 63, 65535, 65537, (1 << 64)-1):
            for field in ('input_capacity', 'output_capacity'):
                self.reject(**{field: capacity})
        for field, values in [('input_channel', (16, 32, 255, 256)),
                              ('output_channel', (0, 15, 32, 255, 256))]:
            for value in values:
                self.reject(**{field: value})

    def test_completion_orders_empty_zero_and_combined(self):
        self.accept([(101, irq())])
        self.accept([(101, irq((0,3,0),(0,19,0)))])
        for channels in ((3,19),(19,3)):
            self.accept([(102,irq((0,channels[0],1))), (199,irq((0,channels[1],1)))])
            self.accept([(102,irq((0,channels[0],1)))])
        self.accept([(199,irq((0,19,1),(0,3,1)))])

    def test_all_completion_count_bytes_are_transfers(self):
        for channel in (3,19):
            for count in range(256):
                events = [(101,irq((0,channel,count)))]
                if count in (0,1):
                    self.accept(events)
                else:
                    self.reject(events)

    def test_irq_records_headers_lengths_and_atomic_batches(self):
        for records in (((0,3,1),(0,3,1)), ((1,3,1),), ((0,4,1),),
                        ((0,3,1),(0,19,254)), ((0,3,1),(0,19,255)),
                        ((0,3,1),(0,32,1)), ((4,3,1),)):
            self.reject([(101,irq(*records))])
        self.reject([(101,irq((0,3,1))), (102,irq((0,3,1)))])
        for index in range(24):
            data = bytearray.fromhex(irq())
            data[index] ^= 1
            self.reject([(101,data.hex())])
        for count in (121,127,255):
            data = bytearray.fromhex(irq()); data[24] = count
            self.reject([(101,data.hex())])
        for size in (0,1,24,25,384,386,1024):
            self.reject([(101,'00'*size)])
        self.reject([(101,'z'*770)])

    def test_absolute_deadline_clock_and_overflow_edges(self):
        self.accept([(199,irq((0,3,1),(0,19,1)))])
        for time in (-1,99,200,201,9223372036854775807):
            self.reject([(time,irq((0,3,1),(0,19,1)))])
        self.reject([(150,irq()),(149,irq())])
        for field, values in [('start',(-1,9223372036854775807)),
                              ('timeout',(-1,0,60001)), ('launch_time',(-1,99,200))]:
            for value in values:
                self.reject(**{field:value})
        self.accept(start=0,timeout=1,launch_time=0)
        self.accept(start=9223372036854775806,timeout=1,launch_time=9223372036854775806)
        self.accept(start=0,timeout=60000,launch_time=59999)
        self.reject(start=9223372036854775806,timeout=2,launch_time=9223372036854775806)

    def test_exact_snapshot_budget_and_final_completion(self):
        for budget in (1,2,31,32):
            events=[(101,irq())]*(budget-1)+[(199,irq((0,3,1),(0,19,1)))]
            self.accept(events,budget=budget)
            self.accept([(101,irq())]*budget,budget=budget)
            if budget<32:
                self.reject([(101,irq())]*(budget+1),budget=budget)
        for budget in (-1,0,33,9223372036854775807):
            self.reject(budget=budget)
        self.reject([(101,irq())]*31+[(200,irq((0,3,1),(0,19,1)))])

    def test_bounded_numeric_and_argument_inputs(self):
        for field in ('start','input_count','input_capacity'):
            for text in ('x','-' ,'1'*100,'18446744073709551616'):
                self.reject(**{field:text})
        for args in ([],['0']*76):
            result=subprocess.run([self.binary,*args],capture_output=True,text=True,timeout=10)
            self.assertNotEqual(result.returncode,0)
            self.accept()

    def test_direct_api_poison_atomicity_move_and_recovery(self):
        result=subprocess.run([self.api],capture_output=True,text=True,
                              stdin=subprocess.DEVNULL,timeout=10,check=False)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(json.loads(result.stdout),dict(refusal_recovery_cycles=34,
            poison_retries=24,atomic_refusals=8,physical_calls=False))


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--binary',required=True)
    parser.add_argument('--api',required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
