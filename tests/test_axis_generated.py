# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""The files generated for the axis verification are current."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import generate_axis_drivers as drivers  # noqa: E402


class GeneratedFiles(unittest.TestCase):
    def test_the_driver_files_are_what_the_generator_writes(self):
        for name, (module, plant, drive) in drivers.CONTROLLERS.items():
            committed = json.loads((ROOT / "verification" / f"axis-{name}.json").read_text(encoding="utf-8"))
            self.assertEqual(committed, drivers.driver(module, plant, drive), f"run scripts/generate_axis_drivers.py ({name})")

    def test_the_corexy_driver_is_what_the_generator_writes(self):
        path = ROOT / "verification" / "corexy-diagonal.json"
        self.assertEqual(json.loads(path.read_text(encoding="utf-8")), drivers.corexy_driver())

    def test_an_open_loop_stepper_controller_provides_only_the_bench_monitor_position(self):
        driver = drivers.driver("axis-open-shaped.wasm")
        self.assertEqual({b["input"] for b in driver["bindings"]}, {"fieldAngle", "currentCommand"})
        self.assertEqual([p["variable"] for p in driver["wasm"]["provides"]], ["carriage.s"])

    def test_a_closed_loop_stepper_reads_an_encoder_and_a_servo_also_its_currents(self):
        closed = drivers.driver("axis-closed-shaped.wasm", drive="closed")
        servo = drivers.driver("axis-servo-shaped.wasm", "AxisPlant::ServoAxis", "servo")
        self.assertEqual([p["variable"] for p in closed["wasm"]["provides"]], ["carriage.s", "belt.flange_a.s"])
        self.assertEqual([p["variable"] for p in servo["wasm"]["provides"]],
                         ["carriage.s", "belt.flange_a.s", "motor.id", "motor.iq"])
        self.assertEqual({b["input"] for b in servo["bindings"]}, {"vd", "vq"})
        self.assertEqual(servo["root"], "AxisPlant::ServoAxis")

    def test_the_shaper_frequencies_in_the_firmware_are_the_axis_and_the_belt(self):
        source = (ROOT / "firmware" / "axis-controller" / "src" / "lib.rs").read_text(encoding="utf-8")
        self.assertIn("SHAPER_FREQUENCY: f64 = 62.08;", source)
        self.assertIn("SHAPER_FREQUENCY: f64 = 69.02;", source)
        self.assertIn("SHAPER_FREQUENCY: f64 = 63.50;", source)
        self.assertIn("SHAPER_FREQUENCY: f64 = 61.50;", source)


if __name__ == "__main__":
    unittest.main()
