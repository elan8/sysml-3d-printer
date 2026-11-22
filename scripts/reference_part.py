#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""The reference part of SYS-020: an L-bracket, as an STL and as an isometric drawing.

The part is 100 mm along X, 100 mm along Y and 20 mm high, the bounding box the requirement names. It is an extruded L
profile: a base plate and an upright wall. The same file is what the slicer reads, so the drawing, the toolpath and the
simulation describe one part.

    python3 scripts/reference_part.py            # write docs/reference-part/bracket.stl and bracket.svg
    python3 scripts/reference_part.py --check    # fail if the committed files differ (used by the tests)

Only the standard library is needed.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
OUT = REPO_ROOT / "docs" / "reference-part"

LENGTH = 100.0   # mm along X, the extrusion
DEPTH = 100.0    # mm along Y, the base plate
HEIGHT = 20.0    # mm along Z, the upright
WALL = 3.0       # mm, the thickness of the base plate and the upright
HOLE_DIAMETER = 5.0   # mm, the mounting holes
HOLE_SEGMENTS = 24    # the facets of a hole in the mesh
BASE_HOLES = [(12.0, 20.0), (88.0, 20.0), (12.0, 88.0), (88.0, 88.0)]   # (x, y) of the holes through the base plate
UPRIGHT_HOLES = [(25.0, 12.0), (75.0, 12.0)]                            # (x, z) of the holes through the upright

# The L profile in (Y, Z), counter-clockwise, for the two end faces, and its triangulation.
PROFILE = [(0.0, 0.0), (DEPTH, 0.0), (DEPTH, WALL), (WALL, WALL), (WALL, HEIGHT), (0.0, HEIGHT)]
PROFILE_TRIANGLES = [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 5)]


def circle(cx, cy, clockwise=False):
    radius = HOLE_DIAMETER / 2
    points = [(round(cx + radius * math.cos(2 * math.pi * k / HOLE_SEGMENTS), 6),
               round(cy + radius * math.sin(2 * math.pi * k / HOLE_SEGMENTS), 6)) for k in range(HOLE_SEGMENTS)]
    return points[::-1] if clockwise else points


def cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def segments_cross(p1, p2, p3, p4):
    """True if the open segments p1-p2 and p3-p4 properly cross."""
    d1, d2, d3, d4 = cross(p3, p4, p1), cross(p3, p4, p2), cross(p1, p2, p3), cross(p1, p2, p4)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)) and 0 not in (d1, d2, d3, d4)


def triangulate(outer, holes):
    """Triangles (as point triples) of a counter-clockwise polygon with clockwise holes: bridge each hole to the outline,
    then clip ears."""
    ring = list(outer)
    remaining = [list(h) for h in holes]
    for hole in sorted(remaining, key=lambda h: -max(p[0] for p in h)):
        ih = max(range(len(hole)), key=lambda i: hole[i][0])
        h = hole[ih]
        others = [q for q in remaining if q is not hole]
        edges = [(ring[i], ring[(i + 1) % len(ring)]) for i in range(len(ring))]
        for q in others:
            edges += [(q[i], q[(i + 1) % len(q)]) for i in range(len(q))]
        edges += [(hole[i], hole[(i + 1) % len(hole)]) for i in range(len(hole))]
        for iv in sorted(range(len(ring)), key=lambda i: (ring[i][0] - h[0]) ** 2 + (ring[i][1] - h[1]) ** 2):
            v = ring[iv]
            if not any(segments_cross(h, v, a, b) for a, b in edges):
                break
        ring = ring[:iv + 1] + hole[ih:] + hole[:ih + 1] + ring[iv:]
    triangles_out = []
    points = ring[:]
    guard = 0
    while len(points) > 3 and guard < 100000:
        guard += 1
        count = len(points)
        for i in range(count):
            a, b, c = points[i - 1], points[i], points[(i + 1) % count]
            if cross(a, b, c) <= 1e-12:
                continue
            blocked = False
            for q in points:
                if q in (a, b, c):
                    continue
                if cross(a, b, q) >= -1e-12 and cross(b, c, q) >= -1e-12 and cross(c, a, q) >= -1e-12:
                    blocked = True
                    break
            if not blocked:
                triangles_out.append((a, b, c))
                del points[i]
                break
        else:
            raise RuntimeError("cannot triangulate the face")
    if len(points) == 3 and cross(*points) > 1e-12:
        triangles_out.append(tuple(points))
    return triangles_out


def rectangle(u0, v0, u1, v1):
    return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]


def oriented(tri, direction):
    """The triangle, with the winding that makes its normal point along `direction`."""
    n = normal(tri)
    return tri if sum(a * b for a, b in zip(n, direction)) >= 0 else (tri[0], tri[2], tri[1])


def face(outer, holes, place, direction):
    return [oriented(tuple(place(p) for p in t), direction) for t in triangulate(outer, holes)]


def triangles():
    """The closed surface as outward-facing triangles of (x, y, z) points."""
    return [t for _, t in grouped_triangles()]


def grouped_triangles():
    """(group, triangle) pairs. The groups are in painting order for the drawing, from the farthest to the nearest."""
    out = []

    def add(group, triangles_):
        out.extend((group, t) for t in triangles_)

    base_holes = [circle(x, y, clockwise=True) for x, y in BASE_HOLES]
    upright_holes = [circle(x, z, clockwise=True) for x, z in UPRIGHT_HOLES]
    # the base plate: the bottom, the walls of the four holes through it, and the top behind the upright
    add(0, face(rectangle(0, 0, LENGTH, DEPTH), base_holes, lambda p: (p[0], p[1], 0.0), (0, 0, -1)))
    for x, y in BASE_HOLES:
        ring = circle(x, y)
        for i in range(len(ring)):
            (x0, y0), (x1, y1) = ring[i], ring[(i + 1) % len(ring)]
            inward = (x - (x0 + x1) / 2, y - (y0 + y1) / 2, 0.0)
            for t in (((x0, y0, 0.0), (x1, y1, 0.0), (x1, y1, WALL)), ((x0, y0, 0.0), (x1, y1, WALL), (x0, y0, WALL))):
                add(1, [oriented(t, inward)])
    add(2, face(rectangle(0, WALL, LENGTH, DEPTH), base_holes, lambda p: (p[0], p[1], WALL), (0, 0, 1)))
    add(3, face(rectangle(0, 0, LENGTH, WALL), [], lambda p: (p[0], DEPTH, p[1]), (0, 1, 0)))      # the far edge
    # the upright: its top and back, the walls of the two holes, and its front
    add(4, face(rectangle(0, 0, LENGTH, WALL), [], lambda p: (p[0], p[1], HEIGHT), (0, 0, 1)))
    add(4, face(rectangle(0, WALL, LENGTH, HEIGHT), upright_holes, lambda p: (p[0], WALL, p[1]), (0, 1, 0)))
    for x, z in UPRIGHT_HOLES:
        ring = circle(x, z)
        for i in range(len(ring)):
            (x0, z0), (x1, z1) = ring[i], ring[(i + 1) % len(ring)]
            inward = (x - (x0 + x1) / 2, 0.0, z - (z0 + z1) / 2)
            for t in (((x0, 0.0, z0), (x1, 0.0, z1), (x1, WALL, z1)), ((x0, 0.0, z0), (x1, WALL, z1), (x0, WALL, z0))):
                add(5, [oriented(t, inward)])
    add(6, face(rectangle(0, 0, LENGTH, HEIGHT), upright_holes, lambda p: (p[0], 0.0, p[1]), (0, -1, 0)))
    # the two end faces, the L profile
    for a, b, c in PROFILE_TRIANGLES:
        for x, direction in ((0.0, (-1, 0, 0)), (LENGTH, (1, 0, 0))):
            add(7, [oriented(tuple((x, *PROFILE[i]) for i in (a, b, c)), direction)])
    return out


def normal(t):
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = t
    ux, uy, uz = bx - ax, by - ay, bz - az
    vx, vy, vz = cx - ax, cy - ay, cz - az
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx / length, ny / length, nz / length)


def volume(tris):
    """Signed volume of the closed surface, in mm^3."""
    total = 0.0
    for (ax, ay, az), (bx, by, bz), (cx, cy, cz) in tris:
        total += (ax * (by * cz - bz * cy) - ay * (bx * cz - bz * cx) + az * (bx * cy - by * cx)) / 6.0
    return total


def stl(tris) -> str:
    lines = ["solid reference_bracket"]
    for t in tris:
        nx, ny, nz = normal(t)
        lines.append(f"  facet normal {nx:.6f} {ny:.6f} {nz:.6f}")
        lines.append("    outer loop")
        for x, y, z in t:
            lines.append(f"      vertex {x:.4f} {y:.4f} {z:.4f}")
        lines.append("    endloop")
        lines.append("  endfacet")
    lines.append("endsolid reference_bracket")
    return "\n".join(lines) + "\n"


def svg(grouped) -> str:
    """An isometric view with flat shading; faces are drawn back to front."""
    # Looking from +x, -y and above: rotate about z by -35 degrees, then tilt about x by 30 degrees.
    yaw, tilt = math.radians(-35.0), math.radians(28.0)
    light = (0.55, -0.35, 0.75)
    norm = math.sqrt(sum(c * c for c in light))
    light = tuple(c / norm for c in light)

    def project(p):
        x, y, z = p
        x, y = x - LENGTH / 2, y - DEPTH / 2
        rx, ry = x * math.cos(yaw) - y * math.sin(yaw), x * math.sin(yaw) + y * math.cos(yaw)
        sx = rx
        sy = -(z * math.cos(tilt) + ry * math.sin(tilt))
        depth = ry * math.cos(tilt) - z * math.sin(tilt)
        return sx, sy, depth

    faces = []
    for group, t in grouped:
        n = normal(t)
        projected = [project(p) for p in t]
        # a face is visible when its projected winding is counter-clockwise on screen (screen y points down)
        (x0, y0, _), (x1, y1, _), (x2, y2, _) = projected
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if area >= 0:
            continue
        shade = max(0.0, sum(a * b for a, b in zip(n, light)))
        depth = (sum(p[2] for p in projected) / 3 + max(p[2] for p in projected)) / 2
        faces.append((group, depth, shade, projected))
    faces.sort(key=lambda f: (f[0], -f[1]))

    xs = [p[0] for _, _, _, pr in faces for p in pr]
    ys = [p[1] for _, _, _, pr in faces for p in pr]
    margin = 14
    min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    width, height = max_x - min_x + 2 * margin, max_y - min_y + 2 * margin + 30

    def colour(shade):
        base = (11, 113, 129)   # the teal of the other drawings
        k = 0.55 + 0.75 * shade
        return "#{:02x}{:02x}{:02x}".format(*(max(0, min(255, int(c * k + (255 * 0.0)))) for c in base))

    body = []
    for _, _, shade, pr in faces:
        points = " ".join(f"{p[0] - min_x + margin:.2f},{p[1] - min_y + margin:.2f}" for p in pr)
        fill = colour(shade)
        body.append(f'    <polygon points="{points}" fill="{fill}" stroke="{fill}" stroke-width="0.7" stroke-linejoin="round"/>')

    label_y = height - 10
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0f} {height:.0f}" role="img" aria-labelledby="title desc">
  <!-- SPDX-FileCopyrightText: 2026 Elan8 -->
  <!-- SPDX-License-Identifier: MIT -->
  <title id="title">The reference bracket of SYS-020</title>
  <desc id="desc">An L-shaped bracket, 100 mm long, 100 mm deep and 20 mm high, with a {WALL:g} mm base plate and a {WALL:g} mm upright wall along one edge.</desc>
  <rect width="{width:.0f}" height="{height:.0f}" fill="#fff"/>
  <g>
{chr(10).join(body)}
  </g>
  <text x="{width / 2:.0f}" y="{label_y:.0f}" text-anchor="middle" font-family="DejaVu Sans, Arial, sans-serif" font-size="13" fill="#425c6a">100 mm x 100 mm x 20 mm, {WALL:g} mm walls</text>
</svg>
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    tris = triangles()
    if volume(tris) <= 0:
        raise SystemExit("the surface is inside out")
    files = {OUT / "bracket.stl": stl(tris), OUT / "bracket.svg": svg(grouped_triangles())}
    if args.check:
        stale = [str(p.relative_to(REPO_ROOT)) for p, text in files.items() if not p.exists() or p.read_text() != text]
        if stale:
            print("out of date: " + ", ".join(stale) + "; run python3 scripts/reference_part.py", file=sys.stderr)
            return 1
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for path, text in files.items():
        path.write_text(text)
    print(f"solid volume {volume(tris) / 1000:.1f} cm^3, {len(tris)} triangles")
    return 0


if __name__ == "__main__":
    sys.exit(main())
