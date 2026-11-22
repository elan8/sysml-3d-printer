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
python3 scripts/verify_corexy.py
```

The script builds the Wasm guest and writes the Run42 verdict, traces and plot to `build/corexy/`. The diagonal case
runs in a workspace separate from the existing one-axis cases, so only the selected case produces a verdict.

With Run42 development revision `02ede8f`, the diagonal case passed all four assertions. The trace sampled at 50 µs
showed a 65.7 µm peak planar tracking error, a 3.0 µm peak error after the move, and a 0.4 µm endpoint error. The carriage
was within the 20 µm settling band when the command ended.

The Modelica reference check in `tests/modelica/run.sh` holds the pulleys at unequal fixed positions. Starting both
masses at rest, it compares the X and Y trajectories with the closed-form spring response about the transformed
equilibrium.
