"""Execute the authored print-supervisor cases with a local Run42 build."""
# SPDX-FileCopyrightText: 2026 Elan8
# SPDX-License-Identifier: MIT
import os
import shutil
import subprocess

from _spec42 import REPO_ROOT, domain_library_path


def main() -> int:
    run42 = os.environ.get("RUN42") or shutil.which("run42")
    if not run42:
        raise SystemExit("Set RUN42 to your local Run42 executable.")
    library = domain_library_path() / "model"
    verdicts = REPO_ROOT / "build" / "supervisor" / "verdicts.json"
    verdicts.unlink(missing_ok=True)
    result = subprocess.run(
        [run42, "verify", "verification/supervisor", "model", str(library), "--out", str(verdicts)],
        cwd=REPO_ROOT,
    )
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
