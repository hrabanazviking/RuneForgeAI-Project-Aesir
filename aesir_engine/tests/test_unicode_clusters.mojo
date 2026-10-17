"""Pure UTF-8 boundary helper regressions independent of draft and terminal."""

from cli.unicode_clusters import (
    _scalar_end, _scalar_start, _scalar_value, _trailing_mark, _hard_break,
    _emoji_base, _regional_indicator, _ri_count_before, _base_before,
    _joined_emoji_end,
)


def main() raises:
    var mixed = String("A界🛡️")
    if (_scalar_value(mixed, 0) != 65
            or _scalar_value(mixed, 1) != 30028
            or _scalar_end(mixed, 1) != 4
            or _scalar_start(mixed, 4) != 1):
        raise Error("UTF-8 scalar boundaries changed during extraction")
    var accent = String("e\u0301")
    if (not _trailing_mark(accent, 1) or _base_before(accent, 3) != 0
            or not _hard_break("\n", 0)):
        raise Error("combining and hard-break classification changed")
    var family = String("👩🏽‍💻")
    if (not _emoji_base(family, 0) or not _trailing_mark(family, 4)
            or _joined_emoji_end(family, 8, 0) != family.byte_length()):
        raise Error("bounded joined-emoji classification changed")
    var flags = String("🇺🇸🇨")
    if (not _regional_indicator(flags, 0)
            or _emoji_base(flags, 0)
            or _ri_count_before(flags, flags.byte_length()) != 3):
        raise Error("regional-indicator boundaries changed")
    print("pure UTF-8 cluster helper boundaries: PASS")
