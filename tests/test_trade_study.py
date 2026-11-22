"""Checks of the trade-study script: unit conversion, the physics of the roll-ups, and the outcomes the architecture
is expected to give."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import trade_study as ts  # noqa: E402


class UnitConversion(unittest.TestCase):
    def test_compound_units_reduce_to_si(self):
        self.assertAlmostEqual(ts.to_si(300, "mm / s"), 0.3)
        self.assertAlmostEqual(ts.to_si(10000, "mm / s ^ 2"), 10.0)
        self.assertAlmostEqual(ts.to_si(40, "micro * m"), 40e-6)
        self.assertAlmostEqual(ts.to_si(30, "kilo * Hz"), 30e3)
        self.assertAlmostEqual(ts.to_si(50, "milli * s"), 0.05)
        self.assertAlmostEqual(ts.to_si(60, "min"), 3600)
        self.assertEqual(ts.to_si(0.8, None), 0.8)

    def test_an_unknown_unit_is_an_error(self):
        with self.assertRaises(ValueError):
            ts.to_si(1, "parsec")


class Candidates(unittest.TestCase):
    """The study reads the model, so these also check that the model still says what the analysis assumes."""

    @classmethod
    def setUpClass(cls):
        model = ts.Model(ts.export())
        cls.limits = model.attributes("FdmPrinter::Limits")
        reference = model.attributes("FdmPrinter::Reference")
        cls.integrations = model.integrations()
        cls.results = {
            name.removesuffix("Integration"): ts.metrics(model, designs, cls.limits, reference)
            for name, designs in cls.integrations.items()
        }

    def failures(self, name):
        return [c[0] for c in ts.CHECKS if not ts.judge(c, self.results[name], self.limits)[0]]

    def test_every_candidate_selects_one_design_for_each_subsystem(self):
        self.assertEqual(len(self.results), 6)
        for designs in self.integrations.values():
            self.assertEqual(sorted(designs), ["bed", "control", "drive", "hotend", "structure", "supply"])

    def test_the_first_resonance_is_the_square_root_of_stiffness_over_moving_mass(self):
        lead = self.results["CoreXYClosedShaped"]
        expected = math.sqrt(1.26e5 / (0.55 + 0.12)) / (2 * math.pi)
        self.assertAlmostEqual(lead["resonance"], expected, places=6)
        # the bed-slinger's worst axis is the bed: the hotend's mass is not on it
        slinger = self.results["SlingerClosedShaped"]
        self.assertAlmostEqual(slinger["moving"], 1.6)

    def test_the_lead_candidate_meets_every_requirement_the_architecture_decides(self):
        self.assertEqual(self.failures("CoreXYClosedShaped"), [])

    def test_open_loop_steppers_save_money_but_are_too_loud(self):
        open_loop, closed = self.results["CoreXYOpenShaped"], self.results["CoreXYClosedShaped"]
        self.assertEqual(self.failures("CoreXYOpenShaped"), ["SYS-016"])
        self.assertLess(open_loop["cost"], closed["cost"] - 50)

    def test_servos_and_a_steel_frame_are_the_most_accurate_but_cost_too_much_and_need_a_bigger_supply(self):
        servo, lead = self.results["CoreXYWideServoShaped"], self.results["CoreXYClosedShaped"]
        self.assertEqual(self.failures("CoreXYWideServoShaped"), ["SYS-014", "SYS-019"])
        self.assertLess(servo["budget"], 0.6 * lead["budget"])

    def test_a_bed_slinger_cannot_reach_the_resonance_or_the_footprint_whatever_the_electronics(self):
        self.assertEqual(self.failures("SlingerClosedShaped"), ["SYS-005", "SYS-017"])
        slinger, lead = self.results["SlingerClosedShaped"], self.results["CoreXYClosedShaped"]
        self.assertLess(slinger["resonance"], 0.6 * lead["resonance"])

    def test_input_shaping_is_what_lets_the_ringing_limit_be_met(self):
        shaped, basic = self.results["CoreXYClosedShaped"], self.results["CoreXYClosedBasic"]
        self.assertLess(shaped["ringing"], self.limits["ringingLimit"] / 5)
        self.assertGreater(basic["ringing"], self.limits["ringingLimit"])
        self.assertLess(basic["from_ringing"], self.limits["accelerationRequired"])

    def test_a_basic_8_bit_board_limits_a_corexy_speed_and_cannot_detect_a_runaway_in_time(self):
        failures = self.failures("CoreXYClosedBasic")
        for requirement in ("SYS-002", "SYS-015", "SYS-012"):
            self.assertIn(requirement, failures)
        self.assertLess(self.results["CoreXYClosedBasic"]["speed"], self.limits["speedRequired"])


class AxisPlant(unittest.TestCase):
    """The axis model repeats the lead candidate's mechanical figures: a change in the structure or the hotend has to
    be made in the axis too."""

    @classmethod
    def setUpClass(cls):
        cls.model = ts.Model(ts.export())

    def test_the_axis_has_the_belt_stiffness_and_moving_mass_of_the_lead_candidate(self):
        structure = self.model.attributes("MotionStructureSystem::CoreXYExtrusionArchitecture")
        hotend = self.model.attributes("HotendSystem::HighFlowHotendArchitecture")
        belt = self.model.attributes("AxisPlant::BeltAxis::belt")
        carriage = self.model.attributes("AxisPlant::BeltAxis::carriage")
        self.assertAlmostEqual(belt["stiffness"], structure["stiffness"])
        self.assertAlmostEqual(carriage["mass"], structure["movingMass"] + hotend["mass"])

    def test_the_axis_pulley_is_a_20_tooth_2_mm_pitch_gt2_pulley(self):
        pulley = self.model.attributes("AxisPlant::BeltAxis::pulley")
        self.assertAlmostEqual(pulley["radius"], 20 * 0.002 / (2 * math.pi), places=4)


if __name__ == "__main__":
    unittest.main()
