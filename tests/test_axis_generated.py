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
        for name, module in drivers.CONTROLLERS.items():
            committed = json.loads((ROOT / "verification" / f"axis-{name}.json").read_text(encoding="utf-8"))
            self.assertEqual(committed, drivers.driver(module), f"run scripts/generate_axis_drivers.py ({name})")

    def test_the_controller_binds_the_stepper_inputs_and_provides_only_the_bench_monitor_position(self):
        driver = drivers.driver("axis-shaped.wasm")
        self.assertEqual({b["input"] for b in driver["bindings"]}, {"fieldAngle", "currentCommand"})
        self.assertEqual([p["variable"] for p in driver["wasm"]["provides"]], ["carriage.s"])

    def test_the_shaper_frequencies_in_the_firmware_are_the_axis_and_the_belt(self):
        source = (ROOT / "firmware" / "axis-controller" / "src" / "lib.rs").read_text(encoding="utf-8")
        self.assertIn("SHAPER_FREQUENCY: f64 = 62.08;", source)
        self.assertIn("SHAPER_FREQUENCY: f64 = 69.02;", source)


if __name__ == "__main__":
    unittest.main()
