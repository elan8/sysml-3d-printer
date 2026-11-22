#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""Compare the candidate architectures against the system requirements the architecture decides.

The numbers all come from the model: `spec42 model-export` gives the literal design properties of each
subsystem design, the integrations' choices of design, and the limits. The roll-ups here (mass, cost, heat-up) repeat the expressions of `FdmPrinterArchitecture`; Spec42 does not evaluate
expressions through an integration, so they are computed here. Requirements the architecture does not
decide (they need a plant model or a controller) are listed as open.

Usage:
    python3 scripts/trade_study.py            # print the table
    python3 scripts/trade_study.py --write    # also write docs/trade-study.md
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _spec42 import REPO_ROOT, domain_library_args, find_spec42  # noqa: E402

SI = {
    "kg": 1.0, "g": 1e-3, "m": 1.0, "cm": 1e-2, "mm": 1e-3, "km": 1e3, "s": 1.0, "h": 3600.0, "min": 60.0,
    "W": 1.0, "V": 1.0, "A": 1.0, "ohm": 1.0, "N": 1.0, "Hz": 1.0, "micro": 1e-6, "J": 1.0, "K": 1.0, "rad": 1.0, "degree": math.pi / 180.0, "milli": 1e-3, "kilo": 1e3,
}


def to_si(magnitude, unit):
    """Magnitude in SI base units (metre, kilogram, second, watt, kelvin, radian) for a unit text such as
    `km / h`, `W * h / km`, `m / s ^ 2` or `milli * s`."""
    if unit in (None, ""):
        return float(magnitude)
    tokens = unit.replace("^", " ^ ").split()
    value, sign, i = float(magnitude), 1, 0
    while i < len(tokens):
        token = tokens[i]
        if token == "*":
            sign = 1
        elif token == "/":
            sign = -1
        else:
            exponent = 1
            if i + 2 < len(tokens) + 0 and tokens[i + 1] == "^":
                exponent = int(tokens[i + 2])
                i += 2
            if token not in SI:
                raise ValueError(f"unknown unit {token!r} in {unit!r}")
            value *= SI[token] ** (sign * exponent)
        i += 1
    return value


def export():
    spec42 = find_spec42()
    out = subprocess.run(
        [spec42, *domain_library_args(), "model-export", str(REPO_ROOT), "--workspace-root", str(REPO_ROOT)],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)["projection"]["elements"]


class Model:
    def __init__(self, elements):
        self.elements = [e for e in elements if e.get("source") == "workspace"]

    def attributes(self, owner):
        """Literal attribute values owned by `owner`, in SI, by name."""
        found = {}
        for e in self.elements:
            if e["kind"] != "AttributeUsage" or not (e.get("qualified_name") or "").startswith(owner + "::"):
                continue
            if (e.get("qualified_name") or "")[len(owner) + 2:].count("::") > 1:
                continue
            evaluation = e.get("evaluation") or {}
            if evaluation.get("status") != "literal":
                continue
            value = evaluation["value"]
            number = value["magnitude"] if isinstance(value, dict) else value
            unit = value.get("unit") if isinstance(value, dict) else None
            found[e["effective_name"]] = to_si(number, unit)
        return found

    def integrations(self):
        """Candidate name -> {child usage -> design qualified name}."""
        result = {}
        for e in self.elements:
            q = e.get("qualified_name") or ""
            if e["kind"] == "PartUsage" and q.startswith("FdmPrinter::") and "Integration::" in q:
                integration = q.split("::")[1]
                targets = ((e.get("relationships") or {}).get("typing") or {}).get("targets") or []
                if targets:
                    result.setdefault(integration, {})[e["effective_name"]] = targets[0]["qualified_name"]
        return result


# The tracking error of a shaped move is about 1.4 times the stretch of the belt, m a / k: the Run42 verification of one axis
# (docs/axis-verification.md) gives 72 to 80 um at 10 m/s^2 and 143 to 146 um at 20 m/s^2 for every drive, against a stretch
# of 53 and 106 um.
TRACKING_FACTOR = 1.4


def metrics(model, designs, limits, reference):
    d = {child: model.attributes(design) for child, design in designs.items()}
    structure, drive, hotend, bed = d["structure"], d["drive"], d["hotend"], d["bed"]
    supply, control = d["supply"], d["control"]
    # The first resonance (A-MECH-1): the moving mass of the worst axis on the stiffness between motor and nozzle.
    moving = structure["movingMass"] + structure["toolheadShare"] * hotend["mass"]
    omega2 = structure["stiffness"] / moving
    omega = math.sqrt(omega2)
    # A step in acceleration of size a leaves a vibration a / omega^2 behind, and the control removes part of it.
    ringing = limits["referenceAcceleration"] / omega2 * control["ringingFactor"]
    # What the motors can give, and what the ringing limit allows.
    from_motors = drive["forceAtSpeed"] * structure["motorForceFactor"] / moving
    from_ringing = limits["ringingLimit"] * omega2 / control["ringingFactor"]
    # And what the tracking limit allows: the belt stretches by m a / k whichever drive pulls on it.
    from_tracking = limits["trackingErrorLimit"] * structure["stiffness"] / (TRACKING_FACTOR * moving)
    tracking = TRACKING_FACTOR * moving * limits["referenceAcceleration"] / structure["stiffness"]
    # The fastest toolhead speed: the controller's step rate or the motor's speed, over the belt speed factor.
    belt_from_control = control["maxStepRate"] / drive["stepsPerMm"] / 1000
    speed = min(belt_from_control, drive["maxBeltSpeed"]) / structure["beltSpeedFactor"]
    thermal = structure["expansionCoefficient"] * reference["frameWarmUp"] * reference["buildLength"]
    budget = math.sqrt(drive["positioningError"] ** 2 + thermal ** 2 + structure["geometryError"] ** 2 + ringing ** 2)
    hotend_heat = hotend["thermalMass"] * reference["hotendTargetRise"] / (hotend["heaterPower"] - reference["hotendLoss"])
    bed_heat = bed["thermalMass"] * reference["bedTargetRise"] / (bed["heaterPower"] - bed["meanLoss"])
    return {
        "build": min(structure["buildX"], structure["buildY"], structure["buildZ"]),
        "speed": speed, "acceleration": min(from_motors, from_ringing, from_tracking), "from_motors": from_motors,
        "from_ringing": from_ringing, "from_tracking": from_tracking, "tracking": tracking, "budget": budget, "thermal": thermal, "resonance": omega / (2 * math.pi),
        "ringing": ringing, "moving": moving,
        "hotend_heat": hotend_heat, "hotend_temp": hotend["maxTemperature"], "flow": hotend["maxFlow"],
        "temp_error": control["hotendTemperatureError"], "bed_heat": bed_heat,
        "peak": hotend["heaterPower"] + bed["heaterPower"] + drive["power"] + control["power"],
        "supply": supply["ratedPower"], "runaway": control["runawayDetectionTime"], "noise": drive["noiseAt1m"],
        "footprint": max(structure["footprintWidth"] / limits["footprintWidthLimit"],
                         structure["footprintDepth"] / limits["footprintDepthLimit"]),
        "mass": structure["mass"] + drive["mass"] + hotend["mass"] + bed["mass"] + supply["mass"] + control["mass"],
        "cost": sum(d[c]["cost"] for c in d),
    }


# id, title, how it is judged: (value of the metric, limit name, direction, display)
CHECKS = [
    ("SYS-001", "Build volume", lambda m: m["build"], "buildRequired", ">=", "{:.0f} mm", 1e3),
    ("SYS-002", "Print speed (estimate)", lambda m: m["speed"], "speedRequired", ">=", "{:.0f} mm/s", 1e3),
    ("SYS-003", "Acceleration (estimate)", lambda m: m["acceleration"], "accelerationRequired", ">=", "{:,.0f} mm/s^2", 1e3),
    ("SYS-004", "Dimensional accuracy (estimate)", lambda m: m["budget"], "positioningErrorLimit", "<=", "{:.0f} um", 1e6),
    ("SYS-005", "First resonance", lambda m: m["resonance"], "resonanceRequired", ">=", "{:.0f} Hz"),
    ("SYS-006", "Ringing (estimate)", lambda m: m["ringing"], "ringingLimit", "<=", "{:.0f} um", 1e6),
    ("SYS-008", "Tracking (estimate)", lambda m: m["tracking"], "trackingErrorLimit", "<=", "{:.0f} um", 1e6),
    ("SYS-009", "Hotend heat-up", lambda m: m["hotend_heat"], "hotendHeatUpLimit", "<=", "{:.0f} s"),
    ("SYS-010", "Hotend temperature", lambda m: m["hotend_temp"], "hotendTemperatureRequired", ">=", "{:.0f} degC", 1, -273.15),
    ("SYS-011", "Melt flow", lambda m: m["flow"], "meltFlowRequired", ">=", "{:.0f} mm^3/s"),
    ("SYS-012", "Nozzle temperature stability", lambda m: m["temp_error"], "hotendTemperatureErrorLimit", "<=", "{:.1f} K"),
    ("SYS-013", "Bed heat-up", lambda m: m["bed_heat"], "bedHeatUpLimit", "<=", "{:.0f} s"),
    ("SYS-014", "Power supply", lambda m: m["peak"] / m["supply"], None, "<=1", "{:.2f} of rating"),
    ("SYS-015", "Thermal runaway detection", lambda m: m["runaway"], "runawayDetectionLimit", "<=", "{:.0f} s"),
    ("SYS-016", "Noise", lambda m: m["noise"], "noiseLimit", "<=", "{:.0f} dB(A)"),
    ("SYS-017", "Footprint", lambda m: m["footprint"], None, "<=1", "{:.2f} of limit"),
    ("SYS-018", "Mass", lambda m: m["mass"], "printerMassLimit", "<=", "{:.1f} kg"),
    ("SYS-019", "Cost", lambda m: m["cost"], "costLimit", "<=", "{:.0f} EUR"),
]
OPEN = [
    ("SYS-007", "Settling", "simulation of an axis with its controller"),
    ("SYS-020", "Reference print time", "simulation of the toolpath with the motion limits of the design"),
    ("SYS-003", "Acceleration (the figure above is an estimate)", "simulation of the axis with a vibration model"),
    ("SYS-004", "Dimensional accuracy (the figure above is an estimate)", "simulation of the axis and a measurement of the frame"),
    ("SYS-008", "Tracking (the figure above is an estimate; one axis simulated: 72 to 80 um at 10 m/s^2)", "simulation of the axis with its controller"),
    ("SYS-006", "Ringing (the figure above is an estimate)", "simulation of a move with and without the shaper"),
]


def judge(check, m, limits):
    ident, title, value_of, limit_name, direction, fmt, *scale = check
    offset = scale[1] if len(scale) > 1 else 0.0
    scale = scale[0] if scale else 1.0
    value = value_of(m)
    if direction in (">=1", "<=1"):
        ok = value >= 1.0 if direction == ">=1" else value <= 1.0
        shown = fmt.format(value)
    else:
        limit = limits[limit_name]
        ok = value <= limit + 1e-12 if direction == "<=" else value >= limit - 1e-12
        shown = fmt.format(value * scale + offset)
    return ok, shown


def table(rows, header):
    widths = [max(len(str(r[i])) for r in [header] + rows) for i in range(len(header))]
    line = lambda r: "| " + " | ".join(str(c).ljust(w) for c, w in zip(r, widths)) + " |"
    return "\n".join([line(header), "| " + " | ".join("-" * w for w in widths) + " |"] + [line(r) for r in rows])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true", help="also write docs/trade-study.md")
    args = parser.parse_args()

    model = Model(export())
    limits = model.attributes("FdmPrinter::Limits")
    reference = model.attributes("FdmPrinter::Reference")
    integrations = model.integrations()
    names = sorted(integrations)
    results = {n: metrics(model, integrations[n], limits, reference) for n in names}

    label = lambda n: n.removesuffix("Integration")
    header = ["Requirement"] + [label(n) for n in names]
    rows = []
    failures = {n: 0 for n in names}
    for check in CHECKS:
        row = [f"{check[0]} {check[1]}"]
        for n in names:
            ok, shown = judge(check, results[n], limits)
            failures[n] += not ok
            row.append(("PASS " if ok else "FAIL ") + shown)
        rows.append(row)
    rows.append(["Requirements failed"] + [str(failures[n]) for n in names])
    rows.append(["Moving mass of the worst axis"] + [f"{results[n]['moving']:.2f} kg" for n in names])
    rows.append(["Acceleration the motors allow"] + [f"{results[n]['from_motors']:,.0f} m/s^2" for n in names])
    rows.append(["Acceleration the ringing limit allows"] + [f"{results[n]['from_ringing']:,.0f} m/s^2" for n in names])
    rows.append(["Acceleration the tracking limit allows"] + [f"{results[n]['from_tracking']:,.0f} m/s^2" for n in names])
    rows.append(["Thermal growth over 10 K"] + [f"{results[n]['thermal'] * 1e6:.0f} um" for n in names])
    text = table(rows, header)
    open_text = table([[i, t, why] for i, t, why in OPEN], ["Requirement", "Title", "Decided by"])

    print(text)
    print()
    print("Open requirements (not decided by the architecture):")
    print(open_text)
    if args.write:
        out = REPO_ROOT / "docs" / "trade-study.md"
        out.parent.mkdir(exist_ok=True)
        out.write_text(
            "# Architecture trade study\n\n"
            "Generated by `scripts/trade_study.py` from the model: every design property, limit and the choice of "
            "design in each candidate is read from `spec42 model-export`; the roll-ups repeat the expressions of "
            "`FdmPrinterArchitecture`. Figures are working estimates (see `ProjectAssumptions`).\n\n"
            "## Candidates against the requirements the architecture decides\n\n" + text +
            "\n\n## Requirements still open\n\n" + open_text + "\n",
            encoding="utf-8",
        )
        print(f"\nWrote {out.relative_to(REPO_ROOT)}")
        prose = REPO_ROOT / "model" / "80_documents" / "prose" / "sds-trade-study.md"
        prose.write_text(
            "Six candidate printers, each selecting one design per subsystem, are compared against the system requirements that the "
            "architecture decides. Every design value, limit and choice of design is read from the model; the roll-ups follow the "
            "expressions of the printer architecture and the physical models described above. A figure marked *estimate* is a first "
            "estimate that a simulation is to replace. This section is generated by `scripts/trade_study.py`.\n\n"
            + text + "\n\n"
            "The requirements the architecture does not decide, because they need a simulation or a measurement, are:\n\n"
            + open_text + "\n",
            encoding="utf-8",
        )
        print(f"Wrote {prose.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
