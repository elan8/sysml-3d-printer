#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""Check the Run42 verdicts of `scripts/verify_axis.sh` against the ones the model is expected to give.

`verify_axis.sh` records a failing verdict as a result, not as an error of the script. This checks that the right controllers
pass and the right ones fail: a trapezoidal move on an open-loop stepper, a closed-loop stepper or a servo is expected to fail
a requirement (without a shaper the axis rings or does not track), and every shaped move is expected to pass. A run that
errors, or a verdict that is not the expected one, fails the check.

    python3 scripts/check_axis_verdicts.py [build/axis]
"""
import json
import sys
from pathlib import Path

EXPECTED = {
    "open-trapezoid": "fail",
    "open-shaped": "pass",
    "open-mistuned": "pass",
    "closed-trapezoid": "fail",
    "closed-shaped": "pass",
    "servo-trapezoid": "fail",
    "servo-shaped": "pass",
}


def check(directory):
    """The problems found, one text each; empty when every controller gave the expected verdict."""
    problems = []
    for name, expected in EXPECTED.items():
        path = Path(directory) / f"{name}-verdicts.json"
        if not path.is_file():
            problems.append(f"{name}: no verdicts file ({path})")
            continue
        records = json.loads(path.read_text(encoding="utf-8"))
        if len(records) != 1:
            problems.append(f"{name}: {len(records)} verdict records, expected 1")
            continue
        record = records[0]
        if record["verdict"] != expected:
            problems.append(f"{name}: verdict {record['verdict']!r}, expected {expected!r}: {record.get('detail') or ''}")
    return problems


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).resolve().parent.parent / "build" / "axis")
    problems = check(directory)
    for name in EXPECTED:
        print(f"checked {name}")
    for problem in problems:
        print("PROBLEM", problem)
    print("axis verdicts as expected" if not problems else f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
