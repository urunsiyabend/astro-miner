"""Helpers for editing levels in scripts/core/Sites.gd from Python (level design scripts).

    import sys; sys.path.insert(0, "tools"); from sites_edit import block, rows, webs
A site's block is its leading comment lines plus its "{ ... }," entry.
"""


def block(s, sid):
    """(start, end) of site `sid`'s block in the Sites.gd text s, comments included."""
    i = s.index('\t{\n\t\t"id": "%s"' % sid)
    start = i
    while True:
        prev = s.rfind('\n', 0, start - 1)
        line = s[prev + 1:start - 1] if prev >= 0 else ""
        if line.startswith('\t#'):
            start = prev + 1
        else:
            break
    end = s.index('\n\t},\n', i) + 4
    return start, end


def rows(lines):
    """Board rows as GDScript string lines."""
    return "".join('\t\t\t"%s",\n' % l for l in lines)


def webs(cells, layers=1):
    """An "obstacles" list of webs on cells [(x, y), ...]."""
    suf = ", %d" % layers if layers > 1 else ""
    return ", ".join('[Vector2i(%d, %d), "web"%s]' % (x, y, suf) for x, y in cells)
