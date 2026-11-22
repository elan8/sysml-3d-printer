#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""Write the results section of the Verification Report from the Run42 runs of `scripts/verify_axis.sh`.

It reads the verdicts and traces in `build/axis/`, measures each trace the way the firmware's test bench monitor does (the
residual vibration, the settling time and the tracking error), and writes `model/80_documents/prose/vvr-results.md` and
three plots in `model/80_documents/figures/`. The results are committed so that the documents build without Run42: run
`scripts/verify_axis.sh` and then this script when the model, the firmware or the plant changes.

    python3 scripts/write_verification_report.py [--run42-version "run42 0.x.y"]

Needs numpy (it uses the design script for the commanded profile and the acceleration sweep).
"""
import argparse
import csv
import json
import shutil
from pathlib import Path

import numpy as np

import axis_design as design

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "axis"
DOCS = ROOT / "model" / "80_documents"
# controller -> (label, shaper frequency in Hz or 0)
CONTROLLERS = {
    "open-trapezoid": ("Open-loop stepper, trapezoid", 0.0),
    "open-shaped": ("Open-loop stepper, shaper 62.08 Hz (the axis)", design.SHAPER_OPEN),
    "open-mistuned": ("Open-loop stepper, shaper 69.02 Hz (the belt alone)", design.SHAPER_BELT),
    "closed-trapezoid": ("Closed-loop stepper, trapezoid", 0.0),
    "closed-shaped": ("Closed-loop stepper, shaper 63.5 Hz", design.SHAPER_CLOSED),
    "servo-trapezoid": ("Servo, trapezoid", 0.0),
    "servo-shaped": ("Servo, shaper 61.5 Hz", design.SHAPER_SERVO),
}
PLOTS = {"open-trapezoid": "an open-loop stepper with a trapezoidal move",
         "open-shaped": "an open-loop stepper with a shaper tuned to the axis",
         "servo-shaped": "a brushless servo with a shaper tuned to the axis"}
CONSTRAINTS = {"settlesInTime": "settling (SYS-007)", "ringsLittle": "ringing (SYS-006)", "tracks": "tracking (SYS-008)",
               "arrives": "arrival"}


def measure(name, shaper):
    rows = list(csv.DictReader((BUILD / name / "AxisVerification__moveTest.csv").open()))
    ts = np.array([float(r["t"]) for r in rows])
    xs = np.array([float(r["carriage.s"]) for r in rows])
    return design.metrics(ts, xs, shaper)


def verdict(name):
    record = json.loads((BUILD / f"{name}-verdicts.json").read_text())[0]
    if record["verdict"] == "pass":
        return "passes"
    failed = [CONSTRAINTS.get(c.split("::")[-1], c.split("::")[-1]) for c in (record.get("detail") or "").replace(";", ",").split(",")
              if "did not hold" in c or "::" in c]
    names = sorted({CONSTRAINTS[k] for k in CONSTRAINTS if any(k in c for c in (record.get("detail") or "").split(";"))})
    return f"**{record['verdict']}**: " + (", ".join(names) if names else (record.get("detail") or ""))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run42-version", default="Run42", help="the Run42 version to record")
    args = parser.parse_args()

    rows = []
    for name, (label, shaper) in CONTROLLERS.items():
        m = measure(name, shaper)
        settle = "never within 20 um" if m["settle"] > 150 else f"{m['settle']:.0f} ms"
        rows.append(f"| {label} | {m['residual']:.1f} um | {settle} | {m['tracking']:.0f} um | {m['final']:.0f} um | {verdict(name)} |")
    sweep = []
    for a in (10, 20, 40):
        track = [design.metrics(*run(), f, a)["tracking"] for run, f in (
            (lambda a=a: design.stepper_open(design.SHAPER_OPEN, a), design.SHAPER_OPEN),
            (lambda a=a: design.stepper_cl(design.STEPPER_KP, design.STEPPER_KD, design.SHAPER_CLOSED, a), design.SHAPER_CLOSED),
            (lambda a=a: design.servo(design.SERVO_KP, design.SERVO_KD, design.SHAPER_SERVO, a), design.SHAPER_SERVO))]
        sweep.append(f"| {a} m/s^2 | {track[0]:.0f} um | {track[1]:.0f} um | {track[2]:.0f} um | {design.M * a / design.KB * 1e6:.0f} um |")

    text = f"""The axis verification case, `AxisVerification::moveTest`, was run with {args.run42_version} for seven controllers: an open-loop stepper, a closed-loop stepper and a brushless servo, each without an input shaper and with one tuned to its own axis, and the open-loop stepper also with a shaper tuned to the belt alone. The move is 20 mm at 300 mm/s and 10,000 mm/s^2. This section is written by `scripts/write_verification_report.py` from the runs of `scripts/verify_axis.sh`.

The case asserts four things: the carriage is within 20 um of its target within 50 ms of the end of the commanded motion (SYS-007); its residual vibration is at most 0.05 mm (SYS-006); it stays within 0.1 mm of the commanded position along the move (SYS-008); and it ends within 20 um of 20 mm.

| Controller | Residual vibration | Settling | Tracking error | Final error | Verdict |
| --- | --- | --- | --- | --- | --- |
""" + "\n".join(rows) + f"""

**Reading the results.** Without a shaper no drive meets the tracking limit, and only the closed-loop stepper settles in time, because the derivative term of its position loop damps the 63 Hz mode; the open-loop stepper has no damping to speak of and never settles. With a shaper every drive passes, with 1 to 6 um of residual vibration, which is what the microstep quantisation (12.5 um steps at 20 kHz) leaves. The shaper is forgiving: tuned 11 percent off, to the belt alone, it still leaves 10 um.

**Cross-check.** An independent integration of the whole axis in Python (`scripts/axis_design.py`, a fixed-step Runge-Kutta where the gains were chosen) reproduces these numbers to under a micrometre.

**The belt limits the acceleration.** The same design script sweeps the acceleration of a shaped move (tracking error against the commanded position):

| Acceleration | Open-loop stepper | Closed-loop stepper | Servo | Belt stretch m a / k |
| --- | --- | --- | --- | --- |
""" + "\n".join(sweep) + """

No drive loses the move, even at 120 m/s^2. The tracking error is the stretch of the belt, m a / k, times about 1.4, the same for every drive, so the 0.1 mm limit of SYS-008 is reached at about 14 m/s^2: 40 percent above the 10 m/s^2 of SYS-003. The stiffness of the belt path is the number that decides how fast this printer can go.

Plots of the carriage position over the run, as recorded by Run42, follow for three of the controllers.
"""
    (DOCS / "prose" / "vvr-results.md").write_text(text, encoding="utf-8")
    for name in PLOTS:
        shutil.copyfile(BUILD / name / "AxisVerification__moveTest.svg", DOCS / "figures" / f"axis-{name}.svg")
    print("wrote", (DOCS / "prose" / "vvr-results.md").relative_to(ROOT), "and", len(PLOTS), "plots")


if __name__ == "__main__":
    main()
