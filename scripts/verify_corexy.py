"""Build the CoreXY guest and run the authored diagonal move with a local Run42 executable."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from _spec42 import REPO_ROOT, domain_library_path


def main() -> int:
    run42 = os.environ.get("RUN42") or shutil.which("run42")
    if not run42:
        raise SystemExit("Set RUN42 to your local Run42 executable.")
    out = REPO_ROOT / "build"
    target = out / "firmware"
    wasm = "wasm32-unknown-unknown"
    subprocess.run(
        ["cargo", "build", "--release", "--target", wasm, "--features", "corexy,shaper6350",
         "--target-dir", str(target)],
        cwd=REPO_ROOT / "firmware" / "axis-controller",
        check=True,
    )
    shutil.copyfile(target / wasm / "release" / "axis_controller.wasm", out / "corexy-diagonal.wasm")
    evidence = out / "corexy"
    evidence.mkdir(exist_ok=True)
    # The development CLI evaluates every test it loads, but applies the driver only to its named case.
    # Keep the physical model in the workspace and run only the CoreXY verification case.
    with tempfile.TemporaryDirectory(prefix="corexy-") as scratch:
        workspace = Path(scratch) / "model"
        shutil.copytree(REPO_ROOT / "model", workspace, ignore=shutil.ignore_patterns("AxisVerification.sysml"))
        shutil.copyfile(
            REPO_ROOT / "verification" / "corexy" / "CoreXYVerification.sysml",
            workspace / "70_verification" / "CoreXYVerification.sysml",
        )
        verification = subprocess.run(
            [run42, "verify", str(workspace), str(domain_library_path() / "model"),
             "--driver", "verification/corexy-diagonal.json",
             "--out", str(evidence / "verdicts.json"), "--trace-dir", str(evidence / "trace"),
             "--trace-signal", "carriageX.s", "--trace-signal", "carriageY.s",
             "--trace-signal", "beltA.flange_a.s", "--trace-signal", "beltB.flange_a.s",
             "--trace-points", "3001"],
            cwd=REPO_ROOT,
        )
    return verification.returncode


if __name__ == "__main__":
    raise SystemExit(main())
