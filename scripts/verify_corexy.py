"""Build CoreXY firmware variants and run the toolpath case with a local Run42 executable."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import argparse
import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from _spec42 import REPO_ROOT, domain_library_path
from generate_axis_drivers import corexy_driver

OUT = REPO_ROOT / "build" / "corexy"
WASM = "wasm32-unknown-unknown"
SIGNALS = (
    "carriageX.s", "carriageY.s", "beltA.flange_a.s", "beltB.flange_a.s",
    "motorA.rotorSpeed", "motorA.currentA", "motorA.currentB",
    "motorB.rotorSpeed", "motorB.currentA", "motorB.currentB",
)


@dataclass(frozen=True)
class Scenario:
    label: str
    feature: str
    target: tuple[float, float]  # metres, independent endpoint reference
    shaped: bool = True


SCENARIOS = {
    "diagonal": Scenario("Diagonal", "corexy", (0.016, 0.012)),
    "x": Scenario("X only", "corexy_x", (0.020, 0.0)),
    "y": Scenario("Y only", "corexy_y", (0.0, 0.020)),
    "opposite": Scenario("Opposite diagonal", "corexy_opposite", (0.016, -0.012)),
    "corner-unshaped": Scenario("Corner, unshaped", "corexy_corner", (0.020, 0.020), shaped=False),
    "corner-shaped": Scenario("Corner, shaped", "corexy_corner", (0.020, 0.020)),
}


def build_guest(name: str) -> Path:
    scenario = SCENARIOS[name]
    features = ",".join((scenario.feature, "shaper6350")) if scenario.shaped else scenario.feature
    target = REPO_ROOT / "build" / "firmware"
    evidence = OUT / name
    evidence.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["cargo", "build", "--release", "--target", WASM, "--features", features,
         "--target-dir", str(target)],
        cwd=REPO_ROOT / "firmware" / "axis-controller",
        check=True,
    )
    shutil.copyfile(target / WASM / "release" / "axis_controller.wasm", evidence / "firmware.wasm")
    driver = evidence / "driver.json"
    configuration = corexy_driver("firmware.wasm")
    driver.write_text(json.dumps(configuration, indent=2) + "\n", encoding="utf-8")
    return driver


def verify(run42: str, workspace: Path, library: Path, driver: Path) -> int:
    evidence = driver.parent
    # A startup error must never leave a previous verdict available for reporting.
    (evidence / "verdicts.json").unlink(missing_ok=True)
    args = [run42, "verify", str(workspace), str(library), "--driver", str(driver),
            "--out", str(evidence / "verdicts.json"), "--trace-dir", str(evidence / "trace"),
            "--trace-points", "6001"]
    for signal in SIGNALS:
        args.extend(("--trace-signal", signal))
    print(f"Running CoreXY {evidence.name}", flush=True)
    run = subprocess.run(args, cwd=REPO_ROOT, capture_output=True, text=True, encoding="utf-8")
    print(f"{evidence.name}: {run.stdout}{run.stderr}".rstrip(), flush=True)
    return run.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--case", action="append", choices=SCENARIOS)
    selection.add_argument("--suite", action="store_true", help="Run all six scenarios")
    parser.add_argument("--jobs", type=int, default=1)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    names = list(SCENARIOS) if args.suite else list(dict.fromkeys(args.case or ["diagonal"]))
    run42 = os.environ.get("RUN42") or shutil.which("run42")
    if not run42:
        raise SystemExit("Set RUN42 to your local Run42 executable.")
    library = domain_library_path() / "model"
    drivers = [build_guest(name) for name in names]
    # The development CLI evaluates every test it loads, but applies the driver only to its named case.
    # Keep the physical model in the workspace and run only the CoreXY verification case.
    with tempfile.TemporaryDirectory(prefix="corexy-") as scratch:
        workspace = Path(scratch) / "model"
        shutil.copytree(REPO_ROOT / "model", workspace, ignore=shutil.ignore_patterns("AxisVerification.sysml"))
        shutil.copyfile(
            REPO_ROOT / "verification" / "corexy" / "CoreXYVerification.sysml",
            workspace / "70_verification" / "CoreXYVerification.sysml",
        )
        with ThreadPoolExecutor(max_workers=args.jobs) as workers:
            runs = [workers.submit(verify, run42, workspace, library, driver) for driver in drivers]
            statuses = [run.result() for run in runs]
    return int(any(statuses))


if __name__ == "__main__":
    raise SystemExit(main())
