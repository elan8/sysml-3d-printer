<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# Verification of one axis by simulation

The motion controller's firmware (`firmware/axis-controller`, WebAssembly, run in the loop by Run42) plays a 20 mm
move at 300 mm/s and 10,000 mm/s^2 on the axis plant (`docs/axis-model.md`). Every 50 us it turns a commanded position
into the stepper's field angle (quantised to 80 microsteps per mm) and a constant 1.5 A. A test bench monitor in the
firmware, which the controller never reads, is given the true carriage position and measures the move. The case is
`AxisVerification::moveTest` and checks SYS-006 (residual vibration at most 0.05 mm), SYS-007 (within 20 um of the
target within 50 ms of the end of the commanded motion) and SYS-008 (within 0.1 mm of the commanded position along the
move), and that the move ends within 20 um of 20 mm.

```bash
RUN42=<run42> bash scripts/verify_axis.sh     # verdicts, traces and plots in build/axis/
```

## Seven controllers on three drives

The firmware has three drives, each run without a shaper and with one tuned to its own axis (the open-loop stepper also with
one tuned to the belt alone): an **open-loop stepper** (the field follows the step count at a constant 1.5 A), a
**closed-loop stepper** (an encoder, a PD position loop that sets the current, the field a quarter cycle ahead of the rotor)
and a **brushless servo** (the same PD loop gives a torque current, a PI current loop with decoupling sets the stator
voltages, limited to the supply; the library's dq-frame PMSM model). The servo axis is `AxisPlant::ServoAxis`.

| Controller | Residual vibration | Settling | Tracking error | Final error | Verdict |
| --- | --- | --- | --- | --- | --- |
| Open-loop stepper, trapezoid | 47.6 um | never (200 ms) | 149 um | -43 um | **fails** settling, tracking, arrival |
| Open-loop stepper, shaper 62.08 Hz | 6.4 um | 0 ms | 80 um | -6 um | passes |
| Open-loop stepper, shaper 69.02 Hz (belt alone) | 10.1 um | 0 ms | 90 um | -8 um | passes |
| Closed-loop stepper, trapezoid | 40.6 um | 40 ms | 127 um | 0 um | **fails** tracking |
| Closed-loop stepper, shaper 63.5 Hz | 1.2 um | 0 ms | 71 um | 0 um | passes |
| Servo, trapezoid | 36.9 um | 97 ms | 137 um | -9 um | **fails** settling and tracking |
| Servo, shaper 61.5 Hz | 2.4 um | 0 ms | 72 um | 0 um | passes |

- **Without a shaper no drive meets the tracking limit**, and only the closed-loop stepper settles in time: its position
  loop has a derivative term, which damps the 63 Hz mode. The open-loop stepper has no damping to speak of and never settles.
- **With a shaper every drive passes**, with 1 to 6 um of residual vibration, which is what the microstep quantisation
  (12.5 um steps at 20 kHz) leaves. The shaper is forgiving: tuned 11 percent off it still leaves 10 um.
- **The closed-loop axes resonate where the stepper's holding stiffness used to be.** The position loop gives a stiffness
  of about 5.6e5 N/m at the belt for the closed-loop stepper and 5.0e5 for the servo, so the first mode is 63.5 and 61.5 Hz,
  close to the open-loop stepper's 62.08 Hz. A softer loop would lower it (a stiffness of 1e5 gives 44 Hz, under the 50 Hz
  required): the gains are chosen to keep it up.

Run42 with the firmware in the loop and an independent Python integration of the whole axis (`scripts/axis_design.py`,
fixed-step Runge-Kutta, where the gains were chosen) agree to under a micrometre on every number, for example 40.6 against
40.8 um and 40.0 against 40.0 ms for the closed-loop stepper without a shaper.

## The belt limits the acceleration, not the drive

`scripts/axis_design.py` also sweeps the acceleration of a shaped 20 mm move at 300 mm/s:

| Acceleration | Open-loop stepper | Closed-loop stepper | Servo | Belt stretch m a / k |
| --- | --- | --- | --- | --- |
| 10 m/s^2 | 80 um | 72 um | 73 um | 53 um |
| 20 m/s^2 | 146 um | 143 um | 144 um | 106 um |
| 40 m/s^2 | 278 um | 253 um | 281 um | 213 um |

(tracking error against the commanded position.) **No drive loses the move**, even at 120 m/s^2, so the motors' force is not
the limit. The tracking error is the stretch of the belt, m a / k, times about 1.4, and it is the same for every drive. The
0.1 mm limit of SYS-008 is reached at about 14 m/s^2: only 40 percent above the 10 m/s^2 of SYS-003. The trade study estimated that
the motors allow 59 to 104 m/s^2 and the ringing limit 78 m/s^2; the belt allows 13. The stiffness of the belt path is the
number that decides how fast this printer can go, which makes a measurement of it the most valuable next step.

## What it means for the architecture

The trade study chose a candidate with input shaping (`ADR-001`), and the simulation agrees: the basic controller cannot
settle the axis. It also shows that the resonance estimate was off by 10 percent and that this does not matter much
to a shaper, so calibration needs to be good but not exact.

## Not yet

One axis and one move. The two axes of a CoreXY acting together, a measured belt stiffness, the heater control and the
reference print time (SYS-020) are still open.
