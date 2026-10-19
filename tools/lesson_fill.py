#!/usr/bin/env python3
"""Fill a guided level's opening ("ore" rows for Sites.gd) around fixed cells.

    python3 tools/lesson_fill.py <rows file> [colours=4] [seed=0]

The rows file holds the site's terrain rows, one per line, cells separated by spaces, using
Board's codes (. ground, @ robot, # bedrock, 1/2/3 rock ...). A ground cell may instead carry
a fixed gem: F C L R (Ferrite Cryo Lumen Ruby). Every other ground cell gets a gem so that the
opening holds no line of 3 and no 2x2 square (the tests check both). Prints the "ore" rows:
gems on ground, "-" on the robot, rock and bedrock.
"""
import random
import sys

GEMS = "FCLR"


def bad(g, w, h):
    for y in range(h):
        for x in range(w):
            v = g[y][x]
            if v not in GEMS:
                continue
            if x + 2 < w and g[y][x + 1] == v and g[y][x + 2] == v:
                return True
            if y + 2 < h and g[y + 1][x] == v and g[y + 2][x] == v:
                return True
            if x + 1 < w and y + 1 < h and g[y][x + 1] == v and g[y + 1][x] == v and g[y + 1][x + 1] == v:
                return True
    return False


def main():
    rows = [line.split() for line in open(sys.argv[1]) if line.strip()]
    opts = dict(a.split("=") for a in sys.argv[2:])
    colours = GEMS[: int(opts.get("colours", 4))]
    h, w = len(rows), len(rows[0])
    for attempt in range(int(opts.get("seed", 0)), 5000):
        random.seed(attempt)
        g = [[None] * w for _ in range(h)]
        for y in range(h):
            for x in range(w):
                c = rows[y][x]
                g[y][x] = c if c in GEMS else ("?" if c[0] in ".:o" else "-")
        ok = True
        for y in range(h):
            for x in range(w):
                if g[y][x] != "?":
                    continue
                opts_ = list(colours)
                random.shuffle(opts_)
                for o in opts_:
                    g[y][x] = o
                    if not bad(g, w, h):
                        break
                else:
                    ok = False
        if ok and not bad(g, w, h):
            print("# seed", attempt)
            for r in g:
                print('"' + " ".join(r) + '",')
            return
    sys.exit("no fill found")


main()
