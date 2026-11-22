#!/usr/bin/env python3
"""Write the Run42 driver files in verification/ for the three axis controllers.

They differ only in the firmware they load: a trapezoidal move, a zero-vibration shaper tuned to the axis and a shaper tuned
to the belt alone. Generated: do not edit the files, edit this script and run it again.

    python3 scripts/generate_axis_drivers.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLLERS = {"trapezoid": "axis-trapezoid.wasm", "shaped": "axis-shaped.wasm", "mistuned": "axis-mistuned.wasm"}


def driver(module):
    attribute = lambda name: "AxisVerification::AxisController::logic::" + name
    return {
        "schema_version": 1,
        "root": "AxisPlant::BeltAxis",
        "state": "AxisVerification::AxisController::logic",
        "case": "AxisVerification::moveTest",
        "wasm": {
            "module": f"../build/{module}",
            "fuel": 2000000,
            "memory_bytes": 2097152,
            "exports": {"version": "api", "boot": "initialize", "time": "clock", "next_event": "deadline",
                        "advance_to": "advance", "signal": "receive", "read": "sample", "provide": "provide"},
            "observations": [
                {"attribute": attribute("fieldAngle"), "index": 0, "unit": "rad"},
                {"attribute": attribute("currentCommand"), "index": 1, "unit": "A"},
                {"attribute": attribute("settlingTime"), "index": 2, "unit": None},
                {"attribute": attribute("residualAmplitude"), "index": 3, "unit": None},
                {"attribute": attribute("trackingError"), "index": 4, "unit": None},
            ],
            # The true carriage position, for the test bench monitor only.
            "provides": [{"variable": "carriage.s", "index": 0, "unit": "m"}],
            "signals": {},
        },
        "bindings": [
            {"attribute": attribute("fieldAngle"), "input": "fieldAngle", "enum_values": {}},
            {"attribute": attribute("currentCommand"), "input": "currentCommand", "enum_values": {}},
        ],
        "plant_observations": [{"attribute": attribute("finalPosition"), "variable": "carriage.s", "unit": "m"}],
        "initial_inputs": {},
        "rtol": 1e-8,
        "atol": 1e-10,
    }


def main():
    out = ROOT / "verification"
    out.mkdir(exist_ok=True)
    for name, module in CONTROLLERS.items():
        path = out / f"axis-{name}.json"
        path.write_text(json.dumps(driver(module), indent=2) + "\n", encoding="utf-8")
        print("wrote", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
