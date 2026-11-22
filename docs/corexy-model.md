<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# CoreXY motion model

The lead printer's XY stage has two fixed [stepper drives and elastic belts](../model/70_verification/CoreXYPlant.sysml).
The [transmission](../model/70_verification/CoreXYTransmission.mo) maps Cartesian displacement to belt displacement as
`a = x + y`, `b = x - y`. Equal belt motion drives X, while opposite belt motion drives Y. The corresponding carriage
forces are the sum and difference of the belt forces, which preserves mechanical power.
[CoreXY principle of operation](https://corexy.com/theory.html)

Each axis uses the existing 0.67 kg worst-axis moving-mass estimate. Two equal 63 kN/m belt paths give the existing
126 kN/m Cartesian stiffness with the pulleys held, since both belts extend by the displacement in a pure-axis move.
The model includes individual rotor inertia, phase currents and belt stretch. Axis-specific gantry mass,
position-dependent belt stiffness, friction and racking remain uncharacterized. The bed is fixed in Z.

## Local Run42 verification

The firmware reuses the closed-loop stepper drive and the 63.5 Hz shaper from the equivalent-axis case. The commanded
20 mm move ends at X = 16 mm and Y = 12 mm, with a path speed of 300 mm/s and acceleration of 10 m/s². The motors
receive unequal belt commands of 28 mm and 4 mm. The controller only reads motor-side encoders. The test bench uses
the true carriage positions to check the planar tracking error, residual vibration and settling time against
SYS-008, SYS-006 and SYS-007, and checks each final coordinate.

Use a local Run42 development build, the unpacked SysML standard library, and Modelica Standard Library 4.1.0.
Set `RUN42` to the executable and `SPEC42_STDLIB_ROOT` to the unpacked SysML library. Set `RUN42_ENGINES` to a
directory containing `msl/` with the Modelica Standard Library and `Elan8/` from the v0.9.0 Modelica release.
From the repository root, run:

```sh
rustup target add wasm32-unknown-unknown
python3 scripts/verify_corexy.py --suite
python3 scripts/report_corexy.py
```

The first script builds the Wasm guests and writes the Run42 verdict and traces for each case to `build/corexy/`.
Use `--case x` to run just one named scenario or `--jobs 3` to run up to three simulations concurrently.
The toolpath case runs in a workspace separate from the existing one-axis cases. The second script, which needs
NumPy and Matplotlib, generates the [design study and charts](corexy-study/README.md) from the six recorded traces.
Run it after all six cases have produced an engineering verdict. A failed requirement makes the verification
command return a nonzero status and still produces evidence for the report.

To render the study PDF with Doc42, set `SPEC42_KPAR_LIBRARY_PATH_DOMAIN` to the unpacked v0.9.0 domain library
directory and run `doc42 build docs/corexy-study --workspace-root . --doc CoreXYStudy::report --out generated/documents`.

The Modelica reference check in `tests/modelica/run.sh` holds the pulleys at unequal fixed positions. Starting both
masses at rest, it compares the X and Y trajectories with the closed-form spring response about the transformed
equilibrium.
