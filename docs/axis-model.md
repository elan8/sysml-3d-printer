<!--
SPDX-FileCopyrightText: 2026 Elan8
SPDX-License-Identifier: MIT
-->

# The axis model

One motion axis, built from the Elan8 domain library: a stepper motor on two current-regulated bridges, a 20-tooth
belt pulley, the belt as a spring and the carriage as a mass (`model/70_verification/AxisPlant.sysml`). The numbers
are the lead candidate's: a 0.55 kg carriage with a 0.12 kg hotend on a 1.26e5 N/m belt path, and a NEMA 17 motor
(0.3 N m/A, 1.6 ohm, 3.4 mH, 50 rotor teeth) on 24 V at 1.5 A. A CoreXY pair of motors is modelled as one motor on
the equivalent axis.

The motor is `Elan8::Electronics::Actuation::StepperMotor`, added to the domain library for this model. Its inputs
are the commanded field angle (an open-loop driver gets it from its step count, a closed-loop one from the rotor
angle plus a quarter of a cycle) and the peak phase current. The torque falls with speed once the back-EMF and the
inductance use up the supply.

## Checked against references derived without a simulator

`bash tests/modelica/run.sh` (it needs the Modelica package of the domain library with the stepper, `ELAN8_MODELICA`)
simulates `tests/modelica/AxisTests.mo` with Rumoca and compares it with `check.py`:

| Case | Reference | Result |
| --- | --- | --- |
| Belt and carriage, pulley held | x(t) = x0 cos(sqrt(k/m) t): the trade study's first resonance, 69.02 Hz | matches to 3e-11 m |
| Stepper holding a fixed field angle | a classical fourth-order Runge-Kutta of the two phase currents, the rotor and the carriage | matches to 1e-12 m |
| Same axis | period of the first mode from the two-mass, two-spring eigenvalue problem | within 0.7 % |

The stepper-driven axis composed in SysML and run with Run42 gives the same carriage trajectory as the Modelica test
to 4e-13 m.

## What it shows

The trade study estimated the first resonance from the belt and the moving mass alone: 69 Hz for the lead candidate.
A stepper that holds its position is also a spring, and the rotor is a mass:

- the holding stiffness at the belt is torque constant x current x rotor teeth over the pulley radius squared, 5.5e5 N/m,
  **4.4 times the belt's**;
- the rotor's inertia reflected to the belt is 0.14 kg, a fifth of the carriage.

Together they make the axis a two-mass, two-spring system whose **first resonance is 62 Hz, 10 percent below the
trade study's estimate**, and whose second is 352 Hz. Both clear the 50 Hz requirement (SYS-005), but the estimate
was optimistic, and the margin a shaper has to work with is smaller. A closed-loop or servo drive that does not hold a
stiff position through the field angle does not have this term.

## Not yet

The axis is driven by constant inputs. The motion controller that turns a toolpath into field angles and currents,
with and without input shaping, is the next increment, and with it the verdicts for settling (SYS-007), tracking
(SYS-008), acceleration (SYS-003) and ringing (SYS-006).
