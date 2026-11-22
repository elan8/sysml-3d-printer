# ADR-001: Lead architecture candidate

**Status:** proposed, for review by the project owner.

## Decision

Take **CoreXYClosedShaped** as the lead architecture: a CoreXY on an aluminium extrusion frame with 6 mm belts,
closed-loop stepper motors, a high-flow hotend (80 W), a 400 W bed, a 600 W supply, and a 32-bit control board
with input shaping, pressure advance and a model-based thermal runaway monitor.

## Why

`docs/trade-study.md` compares six candidates against the 17 requirements the architecture decides (the rest
need a simulation). Findings, all read from the model:

- **A bed-slinger cannot reach the resonance, whatever the electronics.** Its worst axis is the bed and the
  part, 1.6 kg on a single belt, so the first resonance is 38 Hz against the 50 Hz required (SYS-005), and its
  footprint is 12 percent over the limit (SYS-017). With every electronic improvement it still fails those two.
  Input shaping hides the ringing (21 um) but the shaper has to cancel a lower and more sensitive resonance.
- **Input shaping is what meets the ringing limit.** Without it the CoreXY's residual vibration at
  10,000 mm/s^2 is 51 um against 50 um (SYS-006), and the ringing limit alone caps the acceleration at
  9,800 mm/s^2 (SYS-003). With the shaper it is 6 um and the motors become the limit.
- **A basic 8-bit board is out.** It limits the step rate to 30 kHz, which on a CoreXY diagonal is 265 mm/s
  (SYS-002), and its runaway check takes 40 s against 10 s (SYS-015), and it holds the nozzle to 2 K, not 1 K.
- **Open-loop steppers fail only the noise limit** (56 against 55 dB(A), SYS-016) and save 80 EUR. Closed-loop
  steppers also keep the error budget at 71 um instead of 76 um, and cannot lose steps.
- **Servos and a steel frame are the most accurate but not worth it.** The error budget is 40 um instead of 71
  um, but the bill of parts is 887 EUR against 750 (SYS-019) and the servos' peak power overloads the 600 W
  supply by 2 percent (SYS-014).
- **The thermal error is the biggest term of the error budget.** The frame grows 58 um over a 10 K warm-up on
  aluminium and 30 um on steel; it is larger than the motor positioning error of every design.

## What it commits us to

- The shaper is tuned to the measured resonance of the axis, so the printer needs a calibration step, and the
  resonance must stay put (belt tension, toolhead mass).
- The acceleration, ringing and accuracy figures are estimates from a one-mass-on-one-spring model (A-MECH-1).
  The simulation of an axis with its controller (SYS-007, 008, 003, 006) and of a toolpath (SYS-020) is next, and
  tells whether the shaper's delay and the belt's real stiffness change the picture.
- The 600 W supply leaves 7 percent margin; the thermal model of the frame is a first estimate.

## Still open

SYS-007 (settling), SYS-008 (tracking) and SYS-020 (reference print time) are decided by simulation, not by the
architecture.
