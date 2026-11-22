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

## Three controllers on the same plant

| Controller | Residual vibration | Settling | Tracking error | Final error | Verdict |
| --- | --- | --- | --- | --- | --- |
| Trapezoidal move, no shaper | 47.6 um | never within 20 um (200 ms) | 149 um | -43 um | **fails** settling, tracking and arrival |
| Zero-vibration shaper at 62.08 Hz (the axis) | 6.4 um | 0 ms | 80 um | -6 um | passes |
| Zero-vibration shaper at 69.02 Hz (the belt alone) | 10.1 um | 0 ms | 90 um | -8 um | passes |

- **Without a shaper the axis rings for the rest of the run.** The residual vibration is just under the ringing limit
  (47.6 um against 50 um; the trade study's estimate was 51 um and failed it), but it decays only slowly, so the carriage
  never settles within 20 um and it is still 43 um off at 0.3 s.
- **A shaper cuts the residual vibration by about a factor of seven** and the carriage is inside the 20 um band at the
  end of the commanded motion.
- **The shaper is forgiving.** Tuned to 69.02 Hz, the frequency the trade study estimated from the belt alone, 11 percent
  above the real 62.08 Hz of the axis with the stepper's own stiffness, it still leaves only 10 um, and passes. The tracking
  error grows from 80 to 90 um, close to the 100 um limit.
- **Microstep quantisation sets the floor.** Each command step is 12.5 um at 20 kHz, which excites the carriage broadly,
  so what is left after a correct shaper is 6 um at the resonance and some at the second mode (352 Hz).

An earlier run left the carriage 12 um short of its target: the plant's pulley radius was 6.37 mm and the firmware assumed
the exact 6.3662 mm of a 20-tooth, 2 mm pitch pulley, which is a 0.06 percent error in steps per mm. The plant now has
the exact radius; the offset is what a wrong steps-per-mm setting would cost on a real printer.

## What it means for the architecture

The trade study chose a candidate with input shaping (`ADR-001`), and the simulation agrees: the basic controller cannot
settle the axis. It also shows that the resonance estimate was off by 10 percent and that this does not matter much
to a shaper, so calibration needs to be good but not exact.

## Not yet

One axis, one move, a constant current and an open-loop stepper. The acceleration the motors allow (SYS-003), a closed-loop
stepper and a servo drive, the heater control and the reference print time (SYS-020) are still open.
