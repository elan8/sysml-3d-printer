# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""The check of the axis verdicts accepts the expected pattern and rejects any other."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import check_axis_verdicts as checker  # noqa: E402


def write(directory, verdicts):
    for name, verdict in verdicts.items():
        (Path(directory) / f"{name}-verdicts.json").write_text(json.dumps([{"verdict": verdict, "detail": "x"}]), encoding="utf-8")


class Verdicts(unittest.TestCase):
    def test_the_expected_pattern_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            write(directory, checker.EXPECTED)
            self.assertEqual(checker.check(directory), [])

    def test_a_shaped_move_that_fails_and_a_run_that_errors_are_problems(self):
        with tempfile.TemporaryDirectory() as directory:
            write(directory, {**checker.EXPECTED, "open-shaped": "fail", "servo-shaped": "error"})
            problems = checker.check(directory)
            self.assertEqual(len(problems), 2)
            self.assertTrue(problems[0].startswith("open-shaped"))

    def test_a_trapezoidal_move_that_passes_is_a_problem_too(self):
        with tempfile.TemporaryDirectory() as directory:
            write(directory, {**checker.EXPECTED, "open-trapezoid": "pass"})
            self.assertEqual([p.split(":")[0] for p in checker.check(directory)], ["open-trapezoid"])

    def test_a_missing_file_is_a_problem(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(len(checker.check(directory)), len(checker.EXPECTED))


if __name__ == "__main__":
    unittest.main()
