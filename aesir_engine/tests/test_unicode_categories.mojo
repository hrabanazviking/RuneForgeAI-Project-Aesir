"""Unicode 16.0 L/N table pins: classifier spot checks plus the 821 live-range count."""
from loader.unicode_categories import llama_character_class, STARTS, ENDS, CLASSES


def test_character_class_spots() raises:
    if llama_character_class(ord("A")) != 1:
        raise Error("llama_character_class('A') must be 1 (letter)")
    if llama_character_class(ord("0")) != 2:
        raise Error("llama_character_class('0') must be 2 (number)")
    if llama_character_class(ord(" ")) != 3:
        raise Error("llama_character_class(' ') must be 3 (regex whitespace)")
    if llama_character_class(ord("!")) != 0:
        raise Error("llama_character_class('!') must be 0 (other)")
    if llama_character_class(0x10FFFF) != 0:
        raise Error("llama_character_class(0x10FFFF) must be 0 (other)")


def test_unicode_table_range_count() raises:
    # Runtime mirror of the compile-time pin in _pin_unicode_table_count():
    # exactly 821 live entries at indices 0..820, zero padding from 821 on.
    var live = 0
    for i in range(1024):
        if Int(STARTS[i]) != 0:
            if i != live:
                raise Error("STARTS live entries are not contiguous from index 0")
            live += 1
    if live != 821:
        raise Error("STARTS live range count is not 821")
    if Int(STARTS[820]) == 0 or Int(ENDS[820]) == 0 or Int(CLASSES[820]) == 0:
        raise Error("table entry 820 must be a live range")
    if Int(STARTS[821]) != 0 or Int(ENDS[821]) != 0 or Int(CLASSES[821]) != 0:
        raise Error("table padding at index 821 must be zero")


def main() raises:
    test_character_class_spots()
    test_unicode_table_range_count()
    print("PASS unicode categories: 821 live ranges pinned")
