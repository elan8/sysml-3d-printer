# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
"""The axis design script: its integration agrees with what the Run42 verification found, and its gains are the firmware's."""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

try:
    import axis_design as design
except ImportError:  # numpy is not installed
    design = None


@unittest.skipIf(design is None, "needs numpy")
class AxisDesign(unittest.TestCase):
    def metrics(self, run, f, accel=None):
        ts, xs = run
        return design.metrics(ts, xs, f, *([accel] if accel else []))

    def test_the_firmware_has_the_gains_of_the_design(self):
        source = (ROOT / "firmware" / "axis-controller" / "src" / "lib.rs").read_text(encoding="utf-8")
        constant = lambda name: float(re.search(rf"const {name}: f64 = ([0-9_.]+);", source).group(1).replace("_", ""))
        self.assertEqual(constant("STEPPER_KP"), design.STEPPER_KP)
        self.assertEqual(constant("STEPPER_KD"), design.STEPPER_KD)
        self.assertEqual(constant("SERVO_KP"), design.SERVO_KP)
        self.assertEqual(constant("SERVO_KD"), design.SERVO_KD)

    def test_without_a_shaper_the_open_loop_stepper_never_settles_and_a_shaper_fixes_it(self):
        bare = self.metrics(design.stepper_open(0.0), 0.0)
        shaped = self.metrics(design.stepper_open(design.SHAPER_OPEN), design.SHAPER_OPEN)
        self.assertGreater(bare["settle"], 150)
        self.assertEqual(shaped["settle"], 0)
        self.assertLess(shaped["residual"], bare["residual"] / 5)

    def test_the_position_loop_damps_the_closed_loop_stepper_so_it_settles_in_time_without_a_shaper(self):
        bare = self.metrics(design.stepper_cl(design.STEPPER_KP, design.STEPPER_KD, 0.0), 0.0)
        self.assertLessEqual(bare["settle"], 50)
        self.assertGreater(bare["tracking"], 100)       # but it still fails the tracking limit

    def test_the_tracking_error_follows_the_belt_stretch_for_every_drive(self):
        for run, f in ((lambda a: design.stepper_open(design.SHAPER_OPEN, a), design.SHAPER_OPEN),
                       (lambda a: design.servo(design.SERVO_KP, design.SERVO_KD, design.SHAPER_SERVO, a), design.SHAPER_SERVO)):
            slow, fast = self.metrics(run(10), f, 10)["tracking"], self.metrics(run(20), f, 20)["tracking"]
            stretch = design.M * 10 / design.KB * 1e6
            self.assertTrue(1.2 < slow / stretch < 1.6, slow)
            self.assertTrue(1.8 < fast / slow < 2.2, (slow, fast))     # it doubles when the acceleration does


if __name__ == "__main__":
    unittest.main()
