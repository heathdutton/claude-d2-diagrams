#!/usr/bin/env python3
"""Scores how knotted a d2-rendered SVG is: edge crossings and total edge length, read straight
from the connection paths d2 writes. It gives the renderer a number to drive down instead of a
judgement call on a PNG.

A diagram is within target when crossings are at most half its edges. That bar is reachable by
folding cross-cutting edges into a note and aggregating fan-in at container level, and it is where
a detailed diagram stops reading as spaghetti. Written for the Python 3.9 that macOS ships.

Usage: tangle.py FILE.svg...
"""
import math
import re
import sys

CONNECTION = re.compile(r'<path d="([^"]+)"[^>]*class="connection')
PATH_TOKEN = re.compile(r"[MLCSQ]|-?[\d.]+(?:e-?\d+)?")
EPS = 1e-6


def flatten(d):
    """Turns d2's absolute M/L/C/S/Q path data into a polyline. Curves are sampled, since d2 only
    uses them to round the corners of otherwise straight routes."""
    toks = PATH_TOKEN.findall(d)
    pts, cur, cmd, i = [], (0.0, 0.0), "", 0

    def num():
        nonlocal i
        i += 1
        return float(toks[i - 1]) if i - 1 < len(toks) else 0.0

    def pair():
        return (num(), num())

    while i < len(toks):
        if toks[i] in "MLCSQ":
            cmd = toks[i]
            i += 1
            continue
        if cmd in ("M", "L"):
            cur = pair()
            pts.append(cur)
        elif cmd == "C":
            c1, c2, p = pair(), pair(), pair()
            for t in (0.25, 0.5, 0.75, 1.0):
                u = 1 - t
                pts.append(tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * e
                                 for a, b, c, e in zip(cur, c1, c2, p)))
            cur = p
        elif cmd in ("S", "Q"):
            c, p = pair(), pair()
            for t in (0.5, 1.0):
                u = 1 - t
                pts.append(tuple(u * u * a + 2 * u * t * b + t * t * e for a, b, e in zip(cur, c, p)))
            cur = p
        else:
            i += 1
    return list(zip(pts, pts[1:]))


def crosses(s, t):
    """Counts only proper crossings, so edges that merely meet at a shared port don't score."""
    def orient(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def opposite(p, q):
        return (p > EPS and q < -EPS) or (p < -EPS and q > EPS)

    return (opposite(orient(t[0], t[1], s[0]), orient(t[0], t[1], s[1]))
            and opposite(orient(s[0], s[1], t[0]), orient(s[0], s[1], t[1])))


def score(path):
    with open(path, encoding="utf-8") as f:
        edges = [flatten(m.group(1)) for m in CONNECTION.finditer(f.read())]
    crossings = sum(1 for i, e in enumerate(edges) for f in edges[i + 1:]
                    for s in e for t in f if crosses(s, t))
    length = sum(math.dist(a, b) for e in edges for a, b in e)
    target = len(edges) // 2
    verdict = "within target" if crossings <= target else "over target"
    return "%d crossings, %d edges, length %.0fk: %s (<= %d)" % (
        crossings, len(edges), length / 1000, verdict, target)


def main(paths):
    if not paths:
        print("usage: tangle.py FILE.svg...", file=sys.stderr)
        return 2
    for path in paths:
        print(score(path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
