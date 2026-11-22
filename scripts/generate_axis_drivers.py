#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""Write the Run42 driver files in verification/ for the axis controllers.

They differ in the firmware they load and in the plant and drive they select: an open-loop stepper, a closed-loop
stepper with an encoder, and a brushless servo, each without an input shaper and with one tuned to its axis; the open-loop
stepper also with a shaper tuned to the belt alone. Generated: do not edit the files, edit this script and run it again.

    python3 scripts/generate_axis_drivers.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# name -> (firmware module, plant, drive)
CONTROLLERS = {
    "open-trapezoid": ("axis-open-trapezoid.wasm", "AxisPlant::BeltAxis", "open"),
    "open-shaped": ("axis-open-shaped.wasm", "AxisPlant::BeltAxis", "open"),
    "open-mistuned": ("axis-open-mistuned.wasm", "AxisPlant::BeltAxis", "open"),
    "closed-trapezoid": ("axis-closed-trapezoid.wasm", "AxisPlant::BeltAxis", "closed"),
    "closed-shaped": ("axis-closed-shaped.wasm", "AxisPlant::BeltAxis", "closed"),
    "servo-trapezoid": ("axis-servo-trapezoid.wasm", "AxisPlant::ServoAxis", "servo"),
    "servo-shaped": ("axis-servo-shaped.wasm", "AxisPlant::ServoAxis", "servo"),
}


def driver(module, plant="AxisPlant::BeltAxis", drive="open"):
    attribute = lambda name: "AxisVerification::AxisController::logic::" + name
    # The controller state has every output of every drive, and a guest has to supply every attribute: the outputs a drive
    # does not use are zero.
    observations = [
        {"attribute": attribute("fieldAngle"), "index": 0, "unit": "rad"},
        {"attribute": attribute("currentCommand"), "index": 1, "unit": "A"},
        {"attribute": attribute("settlingTime"), "index": 2, "unit": None},
        {"attribute": attribute("residualAmplitude"), "index": 3, "unit": None},
        {"attribute": attribute("trackingError"), "index": 4, "unit": None},
        {"attribute": attribute("voltageD"), "index": 5, "unit": "V"},
        {"attribute": attribute("voltageQ"), "index": 6, "unit": "V"},
    ]
    # The true carriage position is for the test bench monitor only; the encoder and the servo's currents are what the
    # controller sees.
    provides = [{"variable": "carriage.s", "index": 0, "unit": "m"}]
    if drive == "servo":
        bindings = [{"attribute": attribute("voltageD"), "input": "vd", "enum_values": {}},
                    {"attribute": attribute("voltageQ"), "input": "vq", "enum_values": {}}]
        provides += [{"variable": "belt.flange_a.s", "index": 1, "unit": "m"},
                     {"variable": "motor.id", "index": 2, "unit": "A"},
                     {"variable": "motor.iq", "index": 3, "unit": "A"}]
    else:
        bindings = [{"attribute": attribute("fieldAngle"), "input": "fieldAngle", "enum_values": {}},
                    {"attribute": attribute("currentCommand"), "input": "currentCommand", "enum_values": {}}]
        if drive == "closed":
            provides += [{"variable": "belt.flange_a.s", "index": 1, "unit": "m"}]
    return {
        "schema_version": 1,
        "root": plant,
        "state": "AxisVerification::AxisController::logic",
        "case": "AxisVerification::moveTest",
        "wasm": {
            "module": f"../build/{module}",
            "fuel": 2000000,
            "memory_bytes": 2097152,
            "exports": {"version": "api", "boot": "initialize", "time": "clock", "next_event": "deadline",
                        "advance_to": "advance", "signal": "receive", "read": "sample", "provide": "provide"},
            "observations": observations,
            "provides": provides,
            "signals": {},
        },
        "bindings": bindings,
        "plant_observations": [{"attribute": attribute("finalPosition"), "variable": "carriage.s", "unit": "m"}],
        "initial_inputs": {},
        "rtol": 1e-8,
        "atol": 1e-10,
    }


def main():
    out = ROOT / "verification"
    out.mkdir(exist_ok=True)
    for name, (module, plant, drive) in CONTROLLERS.items():
        path = out / f"axis-{name}.json"
        path.write_text(json.dumps(driver(module, plant, drive), indent=2) + "\n", encoding="utf-8")
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
