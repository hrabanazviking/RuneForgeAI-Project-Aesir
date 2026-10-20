#!/usr/bin/env python3
"""Test-only strict checker for the private 5.3.0 identify observation.

Checks actual observer records; produces no synthetic device result.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import struct


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def check(rows):
    require(0 < len(rows) <= 20000, "invalid record count")
    meta = rows[0]
    require(meta["kind"] == "observer" and meta["pointer_bytes"] == 8
            and meta["launch_bytes"] == 141, "observer ABI mismatch")
    page = meta["page_size"]
    require(page > 0 and page & (page - 1) == 0, "invalid host page size")
    entered, returned = {}, {}
    for row in rows[1:]:
        require(row["kind"] in ("enter", "return"), "unknown record kind")
        table = entered if row["kind"] == "enter" else returned
        require(row["id"] not in table, "duplicate call record")
        table[row["id"]] = row
    require(set(entered) == set(returned), "unpaired syscall records")
    require(sorted(entered) == list(range(len(entered))), "noncontiguous call IDs")
    for key, entry in entered.items():
        reply = returned[key]
        require(reply["time_ns"] >= entry["time_ns"], "negative call interval")
        require(reply["result"] >= 0 and reply["errno"] == 0, "failed reference ioctl")
        if entry["operation"] != "transfer":
            require(reply["result"] == 0, "unexpected non-transfer return value")

    def calls(op):
        return sorted((row for row in entered.values() if row["operation"] == op), key=lambda r: r["id"])

    connects = calls("connect")
    require(len(connects) == 1 and connects[0]["port"] == 12133, "unexpected service connection")
    connect = connects[0]
    result = returned[connect["id"]]
    incoming, outgoing = result["input_channel"], result["output_channel"]
    require(0 <= incoming < 16 and 16 <= outgoing < 32, "invalid assigned channels")
    handle_by_channel = {incoming: connect["input_handle"], outgoing: connect["output_handle"]}
    creates = calls("desc-create")
    require(len(creates) == 2, "expected two descriptor lists")
    for entry in creates:
        require(entry["count"] == 65536 and entry["page_size"] == 512
                and entry["circular"] is True, "unexpected descriptor profile")
    acquired = [returned[row["id"]]["handle"] for row in creates]
    require(len(set(acquired)) == 2 and set(acquired) == set(handle_by_channel.values()), "descriptor ownership mismatch")
    enables, disables, closes = calls("enable-channels"), calls("disable-channels"), calls("close")
    require(len(enables) == len(disables) == len(closes) == 1, "incomplete channel lifecycle")
    expected_mask = [(1 << incoming) | (1 << outgoing), 0, 0]
    require(enables[0]["masks"] == disables[0]["masks"] == expected_mask, "channel masks exceed assigned resources")
    close = closes[0]
    require(close["input_channel"] == incoming and close["output_channel"] == outgoing, "close of unassigned channels")
    require(disables[0]["id"] < close["id"], "connection closed before interrupt disable")
    releases = calls("desc-release")
    require(len(releases) == 2 and {r["handle"] for r in releases} == set(acquired), "descriptor release mismatch")
    require(all(r["time_ns"] >= returned[close["id"]]["time_ns"] for r in releases), "descriptor released before close completion")

    maps = calls("buffer-map")
    unmapped = calls("buffer-unmap")
    map_handles = [returned[r["id"]]["mapped_handle"] for r in maps]
    require(len(map_handles) == len(set(map_handles)), "duplicate live map handle")
    def map_key(row):
        # Unmap identifies the mapping by original tuple, not output map handle.
        return row["address_or_fd"], row["bytes"], row["direction"], row["buffer_type"]
    require(Counter(map_key(r) for r in maps) == Counter(map_key(r) for r in unmapped), "unmatched buffer unmap")
    mappings = {r["address_or_fd"]: r for r in maps}
    require(all(r["buffer_type"] == 0 and r["address_or_fd"] % page == 0 for r in maps), "unexpected mapped storage profile")
    transfers = calls("transfer")
    require(len(transfers) == 11, "unexpected read-only query transfer count")
    headers, completions = [], Counter()
    directions = Counter()
    for transfer in transfers:
        channel = transfer["channel"]
        require(channel in handle_by_channel and transfer["handle"] == handle_by_channel[channel], "transfer descriptor/channel mismatch")
        require(transfer["engine"] == 0 and transfer["cyclic"] is False
                and len(transfer["buffers"]) == 1, "unexpected transfer profile")
        buffer = transfer["buffers"][0]
        require(buffer["type"] == 0 and buffer["bytes"] == 2068, "unexpected physical message length/type")
        mapping = mappings.get(buffer["address_or_fd"])
        require(mapping is not None and mapping["bytes"] >= buffer["bytes"], "transfer outside observed mapped buffer")
        require(mapping["direction"] == (1 if channel == incoming else 2), "mapped DMA direction mismatch")
        require(buffer["address_or_fd"] % page == 0, "transfer pointer is not host-page aligned")
        require(returned[transfer["id"]]["result"] == (2068 + 511) // 512, "positive ioctl result is not the descriptor count")
        directions[channel] += 1
        if channel == incoming:
            header = bytes.fromhex(buffer["header_hex"])
            require(len(header) == 20, "invalid observed header size")
            magic, body, message, action, status = struct.unpack("<5I", header)
            require(magic == 0x8A554432 and body <= 2048 and status == 1, "unexpected request envelope")
            headers.append({"message_id": message, "action": action, "body_bytes": body, "status": status})
    require([h["message_id"] for h in headers] == list(range(5)), "unexpected request sequence")
    require([h["action"] for h in headers] == [20, 33, 33, 22, 21], "reference process did more than the qualified read-only control sequence")
    for reply in returned.values():
        for interrupt in reply.get("interrupts", []):
            require(interrupt["engine"] == 0 and interrupt["channel"] in handle_by_channel
                    and interrupt["data"] == 1, "unexpected interrupt status")
            completions[interrupt["channel"]] += 1
    require(directions == Counter({incoming: 5, outgoing: 6}), "unexpected H2D/D2H submission counts")
    require(completions == Counter({incoming: 5, outgoing: 5}), "incomplete query completions")
    groups = Counter((r["bytes"], r["direction"]) for r in maps)
    return {"paired_ioctls": len(entered), "host_page_size": page,
            "message_transfer_bytes": 2068, "descriptor_page_size": 512,
            "successful_transfer_return": 5, "h2d_transfers": 5, "d2h_transfers": 6,
            "completed_h2d": 5, "completed_d2h": 5,
            "outstanding_d2h_at_shutdown": 1,
            "shutdown_close_and_all_buffer_unmaps_observed": True,
            "request_headers": headers, "explicit_sync_ioctls": len(calls("buffer-sync")),
            "mapped_buffers": len(maps), "unmapped_buffers": len(unmapped),
            "mapping_groups": [{"bytes": key[0], "direction": key[1], "count": value}
                               for key, value in sorted(groups.items())],
            "independent_mojo_exchange": False, "model_inference": False}


def load(path):
    raw = Path(path).read_bytes()
    require(len(raw) <= 4 * 1024 * 1024, "observation exceeds file limit")
    return [json.loads(line) for line in raw.decode().splitlines()]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("trace")
    args = parser.parse_args()
    print(json.dumps(check(load(args.trace)), indent=2))
