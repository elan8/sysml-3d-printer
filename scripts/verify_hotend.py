"""Run the nominal and weak-heater hotend cases with a local Run42 executable."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from _spec42 import REPO_ROOT, domain_library_path

OUT = REPO_ROOT / "build" / "hotend"
CASES = {
    "nominal": ("NominalWarmup", "NominalHotendVerification::warmupKeepsHeatPermission"),
    "weak-heater": ("WeakHeaterWarmup", "WeakHeaterVerification::weakHeaterRevokesPermission"),
}
PHASES = ("idle", "preparing", "printing", "pausing", "paused", "cooling", "complete", "cancelled", "fault")
SIGNALS = ("hotend.temperature", "controller.commandedPower", "hotend.deliveredPower", "hotend.faultActive",
           "controller.reachedTarget")


def driver(root, case):
    state = "PrinterSoftware::JobSupervisor::job"
    return {
        "schema_version": 1,
        "root": f"HotendThermalPlant::{root}",
        "state": state,
        "case": case,
        "bindings": [
            {"attribute": f"{state}::heatPermitted", "input": "heatPermit", "enum_values": {}},
            {"attribute": f"{state}::phase", "input": "supervisorPhase",
             "enum_values": {f"PrinterInterfaces::JobPhase::{phase}": code for code, phase in enumerate(PHASES)}},
        ],
        "plant_observations": [{"attribute": f"{state}::warmupAlarm", "variable": "controller.warmupAlarm", "unit": None}],
        "initial_inputs": {},
        "rtol": 1e-8,
        "atol": 1e-10,
    }


def main():
    run42 = os.environ.get("RUN42") or shutil.which("run42")
    if not run42:
        raise SystemExit("Set RUN42 to your local Run42 executable.")
    library = domain_library_path() / "model"
    outcomes = []
    for name, (root, case) in CASES.items():
        evidence = OUT / name
        evidence.mkdir(parents=True, exist_ok=True)
        configuration = evidence / "driver.json"
        configuration.write_text(json.dumps(driver(root, case), indent=2) + "\n", encoding="utf-8")
        verdicts = evidence / "verdicts.json"
        verdicts.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix="hotend-") as scratch:
            # Run42 publishes the physical wiring from the workspace and applies one driver to one case.
            workspace = Path(scratch) / "model"
            shutil.copytree(REPO_ROOT / "model", workspace, ignore=shutil.ignore_patterns("AxisVerification.sysml"))
            shutil.copytree(REPO_ROOT / "verification" / "hotend" / name, workspace / "hotend-verification")
            args = [run42, "verify", str(workspace), str(library), "--driver", str(configuration),
                    "--out", str(verdicts), "--trace-dir", str(evidence / "trace")]
            for signal in SIGNALS:
                args.extend(("--trace-signal", signal))
            outcomes.append(subprocess.run(args, cwd=REPO_ROOT).returncode)
    return int(any(outcomes))


if __name__ == "__main__":
    raise SystemExit(main())
