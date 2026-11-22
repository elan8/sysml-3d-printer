# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import collections
import math
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import reference_part as part  # noqa: E402


class ReferenceBracket(unittest.TestCase):
    def test_the_surface_is_closed(self):
        edges = collections.Counter()
        for t in part.triangles():
            for i in range(3):
                edges[(t[i], t[(i + 1) % 3])] += 1
        open_edges = [e for e in edges if edges[e] != 1 or edges.get((e[1], e[0])) != 1]
        self.assertEqual(open_edges, [])

    def test_the_bounding_box_is_the_one_sys_020_names(self):
        points = [p for t in part.triangles() for p in t]
        for axis, size in enumerate((100.0, 100.0, 20.0)):
            self.assertAlmostEqual(max(p[axis] for p in points) - min(p[axis] for p in points), size)

    def test_the_volume_is_the_profile_minus_the_holes(self):
        hole = 0.5 * part.HOLE_SEGMENTS * (part.HOLE_DIAMETER / 2) ** 2 * math.sin(2 * math.pi / part.HOLE_SEGMENTS)
        solid = (part.DEPTH * part.WALL + (part.HEIGHT - part.WALL) * part.WALL) * part.LENGTH
        drilled = hole * part.WALL * (len(part.BASE_HOLES) + len(part.UPRIGHT_HOLES))
        self.assertAlmostEqual(part.volume(part.triangles()), solid - drilled, places=3)

    def test_the_committed_files_are_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "reference_part.py"), "--check"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
